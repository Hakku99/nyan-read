// Development-only entry point: exercises the real app, controller and SQLite.
// Launch twice without clearing app data; the second launch verifies recovery.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/router/app_router.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/services/riverpod_providers.dart';
import 'package:nyan_read/core/services/service_locator.dart';
import 'package:nyan_read/main.dart' show NyanApp;
import 'package:nyan_read/modules/reader/controllers/reader_controller.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

const _bookId = 'reader-restoration-baseline';

final class _ReaderObserver extends ProviderObserver {
  final ready = Completer<ReaderController>();

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (value is ReaderController &&
        value.book.id == _bookId &&
        !ready.isCompleted) {
      ready.complete(value);
    }
  }
}

void _emit(Map<String, Object?> value) =>
    debugPrint('NYAN_RESTORE ${jsonEncode(value)}');

Future<String> _writeSource() async {
  final file = File('${Directory.systemTemp.path}/nyan-restore-fixture.txt');
  final paragraphs = List.generate(
      100,
      (index) => index % 20 == 0
          ? 'Chapter ${index ~/ 20 + 1}'
          : 'A quiet paragraph with words to keep the reading position stable. ' *
              20);
  await file.writeAsString(paragraphs.join('\n'));
  return file.path;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await setupServiceLocator();
    final observer = _ReaderObserver();
    final container = ProviderContainer(observers: [observer]);
    final db = container.read(databaseServiceRpProvider);
    final preferences = container.read(readerPreferencesRpProvider);
    await preferences.setPageTurnMode(PageTurnMode.swipe);
    if (await db.getBookById(_bookId) == null) {
      final path = await Isolate.run(_writeSource);
      await db.insertBook(Book(
              id: _bookId,
              title: 'Restoration baseline',
              author: '',
              filePath: path,
              format: 'txt')
          .toMap());
    }
    final saved = await db.getBookPosition(_bookId);
    appRouter.go('/reader/$_bookId');
    runApp(UncontrolledProviderScope(
        container: container, child: const NyanApp()));
    final controller =
        await observer.ready.future.timeout(const Duration(seconds: 30));
    for (var attempt = 0;
        attempt < 300 && controller.renderEpoch < 3;
        attempt++) {
      if (controller.errorState != null) {
        throw StateError('Reader failed to initialize');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (controller.renderEpoch < 3) {
      throw StateError('Reader initialization timed out');
    }
    await WidgetsBinding.instance.endOfFrame;
    if (saved == null) {
      await controller.jumpToChapter(1, controller.chapters[1].locator);
      await controller.nextPage();
      await controller.nextPage();
      final target = controller.engine.getCurrentPosition()!;
      if (target.paragraphLeadingEdge == null ||
          target.paragraphLeadingEdge! >= -.1) {
        throw StateError('Fixture must save a clipped paragraph');
      }
      await controller.seekTo(.8);
      await controller.restorePosition({
        'position_type': 'txt',
        'position_payload': target.toJson(),
      });
      await controller.saveBeforeExit();
      final stored = await db.getBookPosition(_bookId);
      if (stored?['position_payload'] !=
          controller.engine.getCurrentPosition()!.toJson()) {
        throw StateError('Database did not retain the visible anchor');
      }
      _emit({
        'event': 'saved',
        'target': jsonDecode(target.toJson()),
        'stored': jsonDecode(stored!['position_payload'] as String),
        'chapter': controller.currentChapterIndex
      });
      appRouter.go('/');
    } else {
      final expected =
          ReadingPosition.fromJson('txt', saved['position_payload'] as String);
      final actual = controller.engine.getCurrentPosition()!;
      final logicalHeight = WidgetsBinding
              .instance.platformDispatcher.views.first.physicalSize.height /
          WidgetsBinding
              .instance.platformDispatcher.views.first.devicePixelRatio;
      final errorUpperBound = ((expected.paragraphLeadingEdge ?? 0) -
                  (actual.paragraphLeadingEdge ?? 0))
              .abs() *
          logicalHeight;
      if (actual.paragraphIndex != expected.paragraphIndex ||
          errorUpperBound > 2 ||
          controller.currentChapterIndex != 1) {
        throw StateError('Cold restore position/chapter mismatch');
      }
      await controller.saveBeforeExit();
      _emit({
        'event': 'restored',
        'expected': jsonDecode(expected.toJson()),
        'actual': jsonDecode(actual.toJson()),
        'errorUpperBoundLogicalPx': errorUpperBound,
        'chapter': controller.currentChapterIndex,
        'passed': true
      });
    }
  } catch (error, stack) {
    _emit({
      'event': 'error',
      'type': error.runtimeType.toString(),
      'stack': stack.toString().split('\n').take(6).join('\n')
    });
  }
}
