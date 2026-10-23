// Item 08/13 development-only entry point. Launch twice to verify SQLite and cold recovery.
import 'dart:async';
import 'dart:convert';

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
import 'package:nyan_read/modules/reader/reader_engine/text_layout_anchor.dart';
import 'package:nyan_read/modules/reader/widgets/highlightable_text.dart';

import 'turn_input_probe.dart';

final class _Observer extends ProviderObserver {
  final readers = <String, Completer<ReaderController>>{};
  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (value is ReaderController) {
      final ready = readers[value.book.id];
      if (ready != null && !ready.isCompleted) ready.complete(value);
    }
  }
}

void _emit(Map<String, Object?> event) =>
    debugPrint('NYAN_TURN ${jsonEncode(event)}');

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 100));
  for (var i = 0; i < 120; i++) {
    var covered = false;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is RestoreVisibility && widget.covered.value) covered = true;
      element.visitChildren(visit);
    }

    visit(WidgetsBinding.instance.rootElement!);
    if (!covered) return;
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  throw StateError('Restore did not settle');
}

double _checkText(ReadingPosition anchor) {
  EditableTextState? editable;
  double? viewportTop;
  void visit(Element element, bool target) {
    final widget = element.widget;
    final inside = target ||
        widget is HighlightableText &&
            widget.paragraphIndex == anchor.paragraphIndex;
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      if (state.widget.axisDirection == AxisDirection.down) {
        final box = element.findRenderObject() as RenderBox;
        viewportTop ??= box.localToGlobal(Offset.zero).dy;
      }
    }
    if (inside &&
        element is StatefulElement &&
        element.state is EditableTextState) {
      editable = element.state as EditableTextState;
    }
    element.visitChildren((child) => visit(child, inside));
  }

  visit(WidgetsBinding.instance.rootElement!, false);
  if (editable == null || viewportTop == null || anchor.textOffset == null) {
    throw StateError('Text anchor is not mounted');
  }
  final render = editable!.renderEditable;
  final caret =
      render.getLocalRectForCaret(TextPosition(offset: anchor.textOffset!));
  final y = render.localToGlobal(Offset(0, caret.top)).dy - viewportTop!;
  if (y < -2 || y > caret.height + 2) {
    throw StateError('Text escaped first reading line');
  }
  return y;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await setupServiceLocator();
    final observer = _Observer();
    final container = ProviderContainer(observers: [observer]);
    final db = container.read(databaseServiceRpProvider);
    final preferences = container.read(readerPreferencesRpProvider);
    runApp(UncontrolledProviderScope(
        container: container, child: const NyanApp()));
    const sources = {
      'txt': String.fromEnvironment('BASELINE_TXT'),
      'epub': String.fromEnvironment('BASELINE_EPUB'),
    };
    for (final format in sources.keys) {
      final id = 'turn-0813-acceptance-$format';
      if (await db.getBookById(id) == null) {
        await db.insertBook(Book(
                id: id,
                title: 'Reflow baseline',
                author: '',
                filePath: sources[format]!,
                format: format)
            .toMap());
      }
      final stored = await db.getBookPosition(id);
      await preferences.setFontSize(18);
      await preferences.setLineHeight(1.5);
      await preferences.setUseSerif(false);
      await preferences.setPageTurnMode(PageTurnMode.swipe);
      final ready = observer.readers[id] = Completer<ReaderController>();
      appRouter.go('/reader/$id');
      final controller =
          await ready.future.timeout(const Duration(seconds: 30));
      for (var attempt = 0;
          controller.renderEpoch < 3 && attempt < 600;
          attempt++) {
        if (controller.errorState != null) {
          throw StateError('Reader failed to open');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (controller.renderEpoch < 3) {
        throw StateError('Reader initialization timed out');
      }
      await _settle();
      if (stored == null) {
        await controller.handleBookmarkSelection({
          'position_type': format,
          'position_payload':
              ReadingPosition(paragraphIndex: format == 'txt' ? 34455 : 149859)
                  .toJson(),
        });
        await controller.nextPage();
        await _settle();
        final inputChecks = await verifyTurnInputs(controller);
        _emit({'event': 'inputs', 'format': format, ...inputChecks});
        final anchor = controller.engine.getCurrentPosition()!;
        if ((anchor.textOffset ?? 0) <= 0) {
          throw StateError('Expected a mid-paragraph anchor');
        }
        for (final mode in PageTurnMode.values) {
          controller.setPageTurnMode(mode);
          await _settle();
          _checkText(anchor);
        }
        for (var step = 0; step < 6; step++) {
          controller.setFontSize(step.isEven ? 16 : 24);
          controller.setLineHeight(step.isEven ? 1.3 : 1.8);
          controller.setUseSerif(step.isOdd);
          await _settle();
          _checkText(anchor);
        }
        await controller.saveBeforeExit();
        final saved = await db.getBookPosition(id);
        final actual = controller.engine.getCurrentPosition()!;
        if (saved?['position_payload'] != actual.toJson() ||
            actual.textOffset != anchor.textOffset) {
          throw StateError('Database did not retain visible text');
        }
        _emit({
          'event': 'saved',
          'format': format,
          'passed': true,
          'position': jsonDecode(actual.toJson()),
          'lineY': _checkText(anchor)
        });
      } else {
        final expected = ReadingPosition.fromJson(
            format, stored['position_payload'] as String);
        final actual = controller.engine.getCurrentPosition()!;
        if (actual.textOffset != expected.textOffset ||
            actual.paragraphIndex != expected.paragraphIndex) {
          throw StateError('Cold restore changed text anchor');
        }
        final lineY = _checkText(expected);
        controller.progressManager.refreshFromEngine();
        var expectedChapter = 0;
        for (var i = 0; i < controller.chapters.length; i++) {
          final locator = controller.chapters[i].locator;
          final start =
              format == 'txt' ? locator.chapterIndex : locator.contentIndex;
          if (start != null && start <= actual.paragraphIndex!) {
            expectedChapter = i;
          }
        }
        if (controller.currentChapterIndex != expectedChapter) {
          throw StateError('Chapter mismatch');
        }
        _emit({
          'event': 'restored',
          'format': format,
          'passed': true,
          'position': jsonDecode(actual.toJson()),
          'lineY': lineY,
          'chapter': controller.currentChapterIndex
        });
      }
      appRouter.go('/');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    _emit({'event': 'complete', 'passed': true});
  } catch (error, stack) {
    _emit({
      'event': 'error',
      'type': error.runtimeType.toString(),
      'stack': stack.toString().split('\n').take(8).join('\n')
    });
  }
}
