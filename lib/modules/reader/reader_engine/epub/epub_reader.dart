import 'dart:async';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/book.dart';
import '../../../../core/utils/book_source_access.dart';
import '../reader_engine.dart';
import 'epub_parse_helpers.dart';
import 'epub_position.dart';

class EpubReaderEngine implements ReaderEngine {
  static const ReaderCapabilities _capabilities = ReaderCapabilities(
    supportsTypography: false,
    supportsTheme: false,
    supportsHighlights: false,
    supportsAnnotations: false,
    supportsPageAnimation: false,
    chapterNavigation: ReaderChapterNavigation.semantic,
  );

  static const double _minTrailingEdge = 0.55;
  static const double _minLeadingEdge = -0.05;

  final Book book;
  late EpubController _epubController;
  bool _isInit = false;
  EpubBook? _document;
  List<ReaderChapter> _chapters = const [];
  int _paragraphCount = 0;
  double _lastKnownProgress = 0.0;
  String? _pendingCfi;
  String? _lastKnownCfi;
  String? _initialCfi;
  Completer<void>? _viewReadyCompleter;
  VoidCallback? _currentValueListener;

  EpubReaderEngine(this.book);

  @override
  ReaderCapabilities get capabilities => _capabilities;

  @override
  Future<void> initialize() async {
    if (_isInit) return;

    try {
      final bytes = Uint8List.fromList(await BookSourceAccess.readBytes(book));

      // Phase 2 · P0-5 (AGENTS.md §3.5.1): move the CPU-bound pipeline
      // (openData + chapter flattening + paragraph enumeration + DOM
      // traversal) to a helper isolate via [compute].  A 50 MB EPUB used to
      // block the UI thread long enough to trigger Android's ANR watchdog;
      // now the main isolate only waits for a lightweight DTO (paragraph
      // count + chapter start indexes + chapter titles).
      //
      // We then re-open the document on the main isolate to feed the
      // EpubController — a single extra zip+XML parse that is cheap
      // compared to the paragraph walk we just offloaded, and it avoids
      // shipping the entire EpubBook graph back across the isolate
      // boundary (which can fail on unsendable nested fields).
      final parseResult = await compute(parseEpubBytesInIsolate, bytes);
      final document = await EpubDocument.openData(bytes);

      _document = document;
      _paragraphCount = parseResult.paragraphCount;
      _initialCfi = _readInitialCfiFromBook();
      _lastKnownCfi = _initialCfi;
      _pendingCfi = _initialCfi;
      _viewReadyCompleter = Completer<void>();
      _chapters = List<ReaderChapter>.generate(
        parseResult.chapters.length,
        (index) {
          final title = parseResult.chapters[index].title;
          final startIndex = index < parseResult.chapterStartIndexes.length
              ? parseResult.chapterStartIndexes[index]
              : 0;
          return ReaderChapter(
            title: title ?? 'Chapter ${index + 1}',
            index: index,
            locator: ChapterLocator(contentIndex: startIndex),
          );
        },
        growable: false,
      );

      _epubController = EpubController(
        document: Future<EpubBook>.value(document),
        epubCfi: _initialCfi,
      );
      _currentValueListener = _handleCurrentValueChanged;
      _epubController.currentValueListenable
          .addListener(_currentValueListener!);
      _isInit = true;
    } catch (e) {
      throw FormatException('Failed to open EPUB: $e');
    }
  }

  @override
  void setConfig(ReaderConfig config) {}

  @override
  double? getProgress() {
    final value = _epubController.currentValueListenable.value ??
        _epubController.currentValue;
    if (value == null || _paragraphCount <= 1) {
      return _lastKnownProgress.clamp(0.0, 1.0);
    }

    final absoluteIndex = _absoluteParagraphIndexFrom(value.position);
    final progress = absoluteIndex / (_paragraphCount - 1);
    _lastKnownProgress = progress.clamp(0.0, 1.0);
    return _lastKnownProgress;
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (_paragraphCount <= 0) {
      return;
    }

    await _waitForViewReady();
    final clamped = progress.clamp(0.0, 1.0);
    final targetIndex = (clamped * (_paragraphCount - 1)).round();
    final scrollFuture = _epubController.scrollTo(
      index: targetIndex,
      duration: const Duration(milliseconds: 250),
      alignment: 0,
      curve: Curves.easeOutCubic,
    );
    if (scrollFuture != null) {
      await scrollFuture;
    } else {
      _epubController.jumpTo(index: targetIndex, alignment: 0);
    }
    _lastKnownProgress = clamped;
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  @override
  Widget buildReader(BuildContext context) {
    if (!_isInit) return const Center(child: CircularProgressIndicator());
    return EpubView(
      controller: _epubController,
      onDocumentLoaded: (document) {
        _completeViewReady();
        unawaited(_applyPendingCfi());
      },
      onDocumentError: (_) {
        _completeViewReady();
      },
      onExternalLinkPressed: (link) {},
    );
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    final cfi = position.cfi;
    if (cfi == null || cfi.isEmpty) {
      return;
    }

    _pendingCfi = cfi;
    _lastKnownCfi = cfi;
    await _waitForViewReady();
    await _applyPendingCfi();
  }

  Future<void> jumpToChapterStart(int startIndex) async {
    await _waitForViewReady();
    _epubController.jumpTo(index: startIndex, alignment: 0);
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  @override
  ReadingPosition? getCurrentPosition() {
    final cfi = _epubController.generateEpubCfi() ?? _lastKnownCfi;
    if (cfi != null && cfi.isNotEmpty) {
      _lastKnownCfi = cfi;
      int? paragraphIndex;
      final value = _epubController.currentValueListenable.value ??
          _epubController.currentValue;
      if (value != null && _paragraphCount > 0) {
        paragraphIndex = _absoluteParagraphIndexFrom(value.position);
      }
      return EpubReadingPosition(
        cfi: cfi,
        paragraphIndex: paragraphIndex,
      );
    }
    return null;
  }

  @override
  Future<void> goToChapter(ChapterLocator locator) async {
    if (locator.contentIndex != null) {
      await jumpToChapterStart(locator.contentIndex!);
    }
  }

  @override
  Future<List<ReaderChapter>> getChapters() async {
    if (!_isInit || _document == null) return [];
    return _chapters;
  }

  @override
  Future<void> nextPage() async {
    final maxIndex = _paragraphCount > 0 ? _paragraphCount - 1 : 0;
    final value = _epubController.currentValueListenable.value ??
        _epubController.currentValue;
    final currentIndex = value != null
        ? _absoluteParagraphIndexFrom(value.position)
        : (_lastKnownProgress * maxIndex).round();
    final targetIndex = (currentIndex + 1).clamp(0, maxIndex) as int;
    await seekToProgress(maxIndex == 0 ? 0.0 : targetIndex / maxIndex);
  }

  @override
  Future<void> previousPage() async {
    final maxIndex = _paragraphCount > 0 ? _paragraphCount - 1 : 0;
    final value = _epubController.currentValueListenable.value ??
        _epubController.currentValue;
    final currentIndex = value != null
        ? _absoluteParagraphIndexFrom(value.position)
        : (_lastKnownProgress * maxIndex).round();
    final targetIndex = (currentIndex - 1).clamp(0, maxIndex) as int;
    await seekToProgress(maxIndex == 0 ? 0.0 : targetIndex / maxIndex);
  }
  @override
  bool get hasBottomBar => false;


  void _handleCurrentValueChanged() {
    final cfi = _epubController.generateEpubCfi();
    if (cfi != null && cfi.isNotEmpty) {
      _lastKnownCfi = cfi;
    }
    getProgress();
  }

  String? _readInitialCfiFromBook() {
    if (book.lastPositionType != 'epub') {
      return null;
    }

    final payload = book.lastPositionPayload;
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      return EpubReadingPosition.fromJson(payload).cfi;
    } catch (_) {
      return null;
    }
  }

  Future<void> _waitForViewReady() async {
    final completer = _viewReadyCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  void _completeViewReady() {
    final completer = _viewReadyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _applyPendingCfi() async {
    final cfi = _pendingCfi;
    if (cfi == null || cfi.isEmpty) {
      return;
    }

    await Future<void>.delayed(Duration.zero);
    _epubController.gotoEpubCfi(
      cfi,
      alignment: 0,
      duration: const Duration(milliseconds: 1),
      curve: Curves.linear,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _pendingCfi = null;
  }

  int _absoluteParagraphIndexFrom(dynamic position) {
    var index = position.index as int;
    final trailingEdge = position.itemTrailingEdge as double?;
    final leadingEdge = position.itemLeadingEdge as double?;
    if (trailingEdge != null &&
        leadingEdge != null &&
        trailingEdge < _minTrailingEdge &&
        leadingEdge < _minLeadingEdge) {
      index += 1;
    }

    if (_paragraphCount <= 0) {
      return 0;
    }
    return index.clamp(0, _paragraphCount - 1);
  }

  @override
  void dispose() {
    if (_isInit) {
      if (_currentValueListener != null) {
        _epubController.currentValueListenable
            .removeListener(_currentValueListener!);
      }
      _epubController.dispose();
    }
  }
}
