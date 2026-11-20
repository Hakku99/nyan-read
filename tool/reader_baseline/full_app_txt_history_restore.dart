// Development-only entry point: exercises the real app, controller and SQLite.
// Launch twice without clearing app data; the second launch verifies recovery.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

const _bookId = 'txt-history-restoration-baseline';

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

ScrollPosition _readerScroll() {
  ScrollPosition? found;
  void visit(Element element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      if (state.widget.axisDirection == AxisDirection.down) {
        found ??= state.position;
      }
    }
    element.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return found ?? (throw StateError('Reader scrollable not attached'));
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
      const path = String.fromEnvironment('BASELINE_TXT');
      if (path.isEmpty || !await File(path).exists()) {
        throw StateError('Authorized TXT sample is required');
      }
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
      await controller.handleBookmarkSelection({
        'position_type': 'txt',
        'position_payload':
            const ReadingPosition(paragraphIndex: 12544).toJson(),
      });
      await controller.nextPage();
      final scroll = _readerScroll();
      final oldEndpoint = scroll.pixels;
      // ADB sends real touchscreen drags while this marker is visible.
      _emit({'event': 'ready-for-drag', 'waitSeconds': 25});
      await Future<void>.delayed(const Duration(seconds: 25));
      final before = controller.engine.getCurrentPosition()!;
      final beforePixels = scroll.pixels;
      if (beforePixels - oldEndpoint < scroll.viewportDimension * 1.2) {
        throw StateError(
            'Required external touchscreen movement did not occur');
      }
      await controller.previousPage();
      final distance = beforePixels - scroll.pixels;
      final limit = scroll.viewportDimension *
              (1 -
                  (before.paragraphLeadingEdge ?? 0)
                      .clamp(-double.infinity, 0)) +
          2;
      if (distance < 0 || distance > limit) {
        throw StateError(
            'Previous used an obsolete turn instead of the current viewport');
      }
      _emit({
        'event': 'manual-history',
        'passed': true,
        'movementBeforePreviousViewports':
            (beforePixels - oldEndpoint) / scroll.viewportDimension,
        'previousDistanceViewports': distance / scroll.viewportDimension,
        'allowedDistanceViewports': limit / scroll.viewportDimension,
        'before': jsonDecode(before.toJson()),
        'after': jsonDecode(controller.engine.getCurrentPosition()!.toJson())
      });
      final target = controller.engine.getCurrentPosition()!;
      if (target.paragraphLeadingEdge == null ||
          !target.paragraphLeadingEdge!.isFinite) {
        throw StateError('Fixture must save valid geometry');
      }
      await controller.seekTo(.8);
      await controller.handleBookmarkSelection({
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
        'format': 'txt',
        'target': jsonDecode(target.toJson()),
        'stored': jsonDecode(stored!['position_payload'] as String),
        'chapter': controller.currentChapterIndex
      });
      appRouter.go('/');
    } else {
      final expected =
          ReadingPosition.fromJson('txt', saved['position_payload'] as String);
      final actual = controller.engine.getCurrentPosition()!;
      var expectedChapter = 0;
      var bestStart = -1;
      for (var i = 0; i < controller.chapters.length; i++) {
        final start = controller.chapters[i].locator.chapterIndex ?? -1;
        if (start >= 0 &&
            start <= actual.paragraphIndex! &&
            start >= bestStart) {
          bestStart = start;
          expectedChapter = i;
        }
      }
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
          controller.currentChapterIndex != expectedChapter) {
        throw StateError('Cold restore position/chapter mismatch');
      }
      await controller.saveBeforeExit();
      _emit({
        'event': 'restored',
        'format': 'txt',
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
