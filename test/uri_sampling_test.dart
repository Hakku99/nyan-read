/// Import fingerprinting of content/tree URIs reads only size + head + tail
/// from the provider; the signature must equal the whole-file one, and any
/// failure must fall back to the whole-file path.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/utils/book_import_fingerprint.dart';
import 'package:nyan_read/core/utils/book_source_platform.dart';

const _channel = MethodChannel('com.example.nyan_read/book_source');
const _n = 64 * 1024; // mirrors BookImportFingerprint._sampleBytes

Uint8List _bytes(int length) => Uint8List.fromList(
    List.generate(length, (i) => math.Random(i).nextInt(256)));

/// What a correct native handler returns for [data].
Map<String, Object> _reply(Uint8List data, {int n = _n}) => {
      'size': data.length,
      'head': Uint8List.sublistView(data, 0, math.min(data.length, n)),
      'tail': data.length > n
          ? Uint8List.sublistView(data, data.length - n)
          : Uint8List(0),
    };

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late List<String> calls;

  void mockNative({
    Object? Function(MethodCall call)? onSample,
    File? copyFile,
  }) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel,
        (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'sampleUri':
          return onSample!(call);
        case 'copyUriToTempFile':
          return copyFile!.path;
      }
      throw MissingPluginException();
    });
  }

  Future<String?> fingerprint(String type) =>
      BookImportFingerprint.computeForSource(
        sourceType: type,
        sourceLocator: 'content://doc',
        locatorHint: 'book.epub',
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nyan_uri_sample_test');
    calls = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
    try {
      await tempDir.delete(recursive: true);
    } catch (e) {
      debugPrint('tearDown: temp dir cleanup failed: $e');
    }
  });

  // Boundaries around the head/tail split: empty, tiny, == n, n + 1, 2n, big.
  for (final length in [0, 1000, _n, _n + 1, 2 * _n, 300 * 1024]) {
    for (final type in [
      BookSourceType.androidTreeUri,
      BookSourceType.androidContentUri
    ]) {
      test('sampled signature equals the whole-file one ($length B, $type)',
          () async {
        final data = _bytes(length);
        mockNative(onSample: (call) {
          expect((call.arguments as Map)['sampleBytes'], _n);
          return _reply(data);
        });

        expect(await fingerprint(type),
            BookImportFingerprint.computeBytes(data, locatorHint: 'book.epub'));
        expect(calls, ['sampleUri'], reason: 'must not read the whole book');
      });
    }
  }

  group('falls back to the whole-file read with the same signature', () {
    final data = _bytes(200 * 1024);
    late String expected;

    setUp(() {
      expected =
          BookImportFingerprint.computeBytes(data, locatorHint: 'book.epub')!;
    });

    Future<void> expectFallback(Object? Function(MethodCall) onSample) async {
      final copy = File('${tempDir.path}/copy.tmp')..writeAsBytesSync(data);
      mockNative(onSample: onSample, copyFile: copy);
      expect(await fingerprint(BookSourceType.androidTreeUri), expected);
      expect(calls, contains('copyUriToTempFile'));
    }

    test(
        'provider error',
        () => expectFallback(
            (_) => throw PlatformException(code: 'book_source_error')));

    test('stale APK without the handler', () async {
      final copy = File('${tempDir.path}/copy.tmp')..writeAsBytesSync(data);
      // Handler knows only copyUriToTempFile: sampleUri => MissingPlugin.
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel,
          (call) async {
        calls.add(call.method);
        if (call.method == 'copyUriToTempFile') return copy.path;
        throw MissingPluginException();
      });
      expect(await fingerprint(BookSourceType.androidTreeUri), expected);
    });

    test(
        'reply with a short head',
        () => expectFallback((_) {
              final r = _reply(data);
              r['head'] = Uint8List(10);
              return r;
            }));

    // Head is correct in both cases so only the tail-length guard can reject.
    test(
        'reply with a tail where none is expected',
        () => expectFallback((_) {
              final r = _reply(_bytes(1000));
              r['tail'] = Uint8List(5);
              return r;
            }));

    test(
        'reply with a short tail',
        () => expectFallback((_) {
              final r = _reply(data);
              r['tail'] = Uint8List(10);
              return r;
            }));

    test('null reply', () => expectFallback((_) => null));
  });

  test('sampleUri does nothing off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mockNative(onSample: (_) => _reply(_bytes(10)));
    expect(await BookSourcePlatform.sampleUri('content://x', sampleBytes: _n),
        isNull);
    expect(calls, isEmpty);
  });

  test('file-path sources never ask the provider', () async {
    final file = File('${tempDir.path}/b.epub')..writeAsBytesSync(_bytes(5000));
    mockNative(onSample: (_) => fail('must not be called'));
    final sig = await BookImportFingerprint.computeForSource(
      sourceType: BookSourceType.filePath,
      sourceLocator: file.path,
      locatorHint: 'b.epub',
    );
    expect(sig, isNotNull);
    expect(calls, isEmpty);
  });
}
