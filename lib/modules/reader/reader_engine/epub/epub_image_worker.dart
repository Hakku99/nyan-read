import 'dart:async';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';

import 'epub_package_parser.dart';

/// One long-lived isolate per open EPUB that answers image requests by entry
/// path.
///
/// The previous shape (`compute()` per image) spawned an isolate for every
/// picture — hundreds of spawns while scrolling an illustrated book. Keyed by
/// file path because the engine hands the same readable path to every request
/// in a session.
///
/// ponytail: the zip is reopened per request and the file handle is NOT held
/// between requests, so a disposed engine never pins the EPUB (Windows cannot
/// delete an open file) and shutdown needs no handshake. The cost left is one
/// central-directory parse per image; keep an open archive in the worker if
/// that ever shows up in a profile.
class EpubImageWorker {
  EpubImageWorker._(this._path) {
    _start();
  }

  static final Map<String, EpubImageWorker> _workers = {};

  /// Extracts [entryPath] from the EPUB at [path]; null when missing or
  /// unreadable. Spawns the worker on first use.
  static Future<Uint8List?> extract(String path, String entryPath) =>
      (_workers[path] ??= EpubImageWorker._(path))._request(entryPath);

  /// Stops the worker for [path] (engine dispose). Safe when none exists.
  static void close(String path) => _workers.remove(path)?._shutdown();

  final String _path;
  final Map<int, Completer<Uint8List?>> _pending = {};
  final ReceivePort _replies = ReceivePort();
  final ReceivePort _exitPort = ReceivePort();
  final Completer<SendPort?> _ready = Completer<SendPort?>();
  Isolate? _isolate;
  SendPort? _port;
  int _nextId = 0;
  bool _closed = false;

  // Handshake, replies and exit are port callbacks, not awaited continuations:
  // in a widget test's fake zone a continuation after `await Isolate.spawn`
  // may never run, and a worker closed while still spawning must still stop.
  Future<void> _start() async {
    _exitPort.listen((message) {
      // onExit sends null; onError sends [error, stack] and, because errors
      // are fatal by default, is followed by exit.
      if (message is List) {
        debugPrint('[EpubImageWorker] worker error: ${message.first.runtimeType}');
      } else {
        _gone();
      }
    });
    _replies.listen((message) {
      if (message is SendPort) {
        _port = message;
        if (_closed) {
          message.send(null); // closed while still spawning: stop it now
        } else if (!_ready.isCompleted) {
          _ready.complete(message);
        }
      } else if (message is List && message.length == 2) {
        final data = message[1];
        _pending.remove(message[0] as int)?.complete(
            data is TransferableTypedData
                ? data.materialize().asUint8List()
                : null);
      }
    });
    try {
      _isolate = await Isolate.spawn(_workerMain, (_path, _replies.sendPort),
          onExit: _exitPort.sendPort, onError: _exitPort.sendPort);
    } catch (e) {
      debugPrint('[EpubImageWorker] spawn failed: ${e.runtimeType}');
      _gone();
    }
  }

  /// The worker is no longer running (clean stop, crash or failed spawn):
  /// fail everything still waiting so no image slot hangs, and drop it from
  /// the registry so the next request spawns a fresh one.
  void _gone() {
    _closed = true;
    if (identical(_workers[_path], this)) _workers.remove(_path);
    _replies.close();
    _exitPort.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
    if (!_ready.isCompleted) _ready.complete(null);
  }

  Future<Uint8List?> _request(String entryPath) async {
    final port = await _ready.future;
    if (port == null || _closed) return null;
    final id = _nextId++;
    final done = _pending[id] = Completer<Uint8List?>();
    port.send([id, entryPath]);
    return done.future;
  }

  void _shutdown() {
    if (_closed) return;
    _closed = true;
    _port?.send(null); // the worker closes its port and exits; _gone follows
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
    if (!_ready.isCompleted) _ready.complete(null);
  }

  /// Simulates a crashed worker.
  @visibleForTesting
  static void killForTest(String path) =>
      _workers[path]?._isolate?.kill(priority: Isolate.immediate);
}

void _workerMain((String, SendPort) args) {
  final (path, reply) = args;
  final commands = ReceivePort();
  reply.send(commands.sendPort);

  commands.listen((message) {
    if (message == null) {
      commands.close();
      return;
    }
    final [id as int, entryPath as String] = message as List;
    Uint8List? bytes;
    InputFileStream? input;
    try {
      if (entryPath.isNotEmpty) {
        input = InputFileStream(path);
        final entry = ZipDecoder().decodeStream(input).findFile(entryPath);
        if (entry != null && entry.isFile) bytes = readZipEntryBytes(entry);
      }
    } catch (_) {
      // null reply: the engine marks this image failed.
    } finally {
      input?.closeSync();
    }
    reply.send([
      id,
      bytes == null ? null : TransferableTypedData.fromList([bytes]),
    ]);
  });
}
