import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/models/book.dart';
import '../../../../core/models/highlight.dart';
import '../../../../core/services/reader_preferences_service.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/utils/book_source_access.dart';
import '../../../../l10n/app_localizations.dart';
// Same architectural tension as the TXT engine: buildReader(BuildContext)
// makes engines half-a-View by contract, so the highlight render widget
// lives in the UI layer but is consumed here (documented in AGENTS §3.2
// analysis — contract-level, not a one-off violation).
import '../../widgets/highlightable_text.dart';
import '../reader_engine.dart';
import '../page_turn_request.dart';
import '../page_presentation.dart';
import '../text_layout_anchor.dart';
import 'epub_parse_helpers.dart';

/// Self-hosted EPUB renderer (2026-07, "EPUB 自研" P1).
///
/// Replaces the epub_view widget with the same ScrollablePositionedList
/// machinery the TXT engine uses: the parse isolate flattens every chapter
/// into paragraphs (UTF-8 bytes + ranges), and this engine renders them as
/// plain styled text blocks. Publisher CSS is deliberately dropped — the
/// paper-like house typography overrides book styling by design.
///
/// Position model: absolute paragraph index plus same-layout viewport edges.
/// Legacy positions were
/// persisted as CFI + paragraphIndex pairs, so restoring by paragraphIndex
/// covers every existing book; new positions no longer carry a CFI.
///
/// P2 (2026-07): typography + theme live — the renderer draws through
/// [ReaderConfig], so the settings sheet's Text/Theme tabs apply like TXT.
/// P3 (2026-07): highlights/annotations live — paragraphs render through
/// the shared [HighlightableText] machinery (selection, recognizer pool,
/// span cache) and the engine exposes [TextReaderCapability] +
/// [TextExtractionCapability], which also arms ContentMetaManager's
/// AnchorHealer for EPUB rows. Rollback: admin panel → legacy renderer
/// (which keeps its historical all-`none` surface).
class EpubReaderEngine
    implements
        ReaderEngine,
        TextReaderCapability,
        TextExtractionCapability,
        PagePresentationCapability {
  final _imagePresentations = <int, Future<bool> Function(PageTurnRequest)>{};
  static const ReaderCapabilities _capabilities = ReaderCapabilities(
    typography: CapabilityLevel.full,
    theme: CapabilityLevel.full,
    highlights: CapabilityLevel.full,
    annotations: CapabilityLevel.full,
    pageAnimation: CapabilityLevel.none,
    chapterNavigation: ReaderChapterNavigation.semantic,
  );

  final Book book;

  final ItemScrollController _itemScrollController = ItemScrollController();
  ScrollPosition? _scrollPosition;
  ReadingPosition? _pendingRestore;
  final _textLayouts = TextLayoutAnchors();
  Locale? _textLocale;
  TextDirection? _textDirection;
  String? get _layoutIdentity => _viewportSize == null
      ? null
      : jsonEncode([
          1,
          'epub',
          defaultTargetPlatform.name,
          _textLocale?.toLanguageTag(),
          _textDirection?.name,
          _viewportSize!.width,
          _viewportSize!.height,
          _config.fontSize,
          _config.lineHeight,
          _config.useSerif,
          _textScaler?.scale(_config.fontSize),
          _textScaler?.scale(_config.fontSize * 1.3),
        ]);
  ReadingPosition? _committedPosition;
  double? _committedPixels;
  ReadingPosition? _settledAnchor;
  double? _settledPixels;
  final ValueNotifier<bool> _restoreCover = ValueNotifier(false);
  int _navigationSerial = 0;
  int? _applyingRestore;
  bool _disposed = false;
  Size? _viewportSize;
  TextScaler? _textScaler;
  final List<_EpubTurn> _turns = [];
  // Retain bounded roundtrip anchors, including a shortened turn at EOF.
  static const _historyLimit = 48;
  static const _viewportStep = .92;
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  bool _isInit = false;
  int _paragraphCount = 0;
  Uint8List _paragraphBytes = Uint8List(0);
  List<int> _paragraphRanges = const [];
  Uint8List _paragraphKinds = Uint8List(0);
  List<ReaderChapter> _chapters = const [];
  int _initialIndex = 0;
  double _lastKnownProgress = 0.0;

  /// One zip extraction per distinct image href per session; the Future is
  /// cached so concurrent item builds share the same load.
  final Map<String, Future<Uint8List?>> _imageFutures = {};

  // ── Highlights (P3) ───────────────────────────────────────────────────
  List<Highlight> _renderHighlights = const [];
  final ValueNotifier<int> _highlightRenderVersion = ValueNotifier(0);
  ReaderTextHighlightCallback? _onTextHighlighted;
  ReaderHighlightTapCallback? _onHighlightTapped;
  ReaderContentTapCallback? _onContentTap;

  /// Readable file path for the book, resolved ONCE per session. For SAF
  /// (`content://`) sources this materializes a temp copy — kept alive for
  /// the whole session (parse + every image load) and deleted in [dispose];
  /// re-copying 100+ MB per image was the alternative.
  Future<PdfCompatibleSource>? _readableSource;

  Future<PdfCompatibleSource> _resolveReadableSource() => _readableSource ??=
      BookSourceAccess.prepareReadableFile(book, extension: '.epub');

  final ValueNotifier<ReaderConfig> _configNotifier =
      ValueNotifier<ReaderConfig>(const ReaderConfig(
    backgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 18,
    lineHeight: 1.5,
  ));

  ReaderConfig get _config => _configNotifier.value;

  EpubReaderEngine(this.book) {
    _itemPositionsListener.itemPositions.addListener(_updateCommittedPosition);
  }

  void _updateCommittedPosition() {
    if (_disposed || _pendingRestore != null) return;
    if (_settledPixels != _scrollPosition?.pixels) _settledAnchor = null;
    _committedPosition = getCurrentPosition();
    _committedPixels = _scrollPosition?.pixels;
  }

  @override
  ReaderCapabilities get capabilities => _capabilities;

  @override
  Future<void> initialize() async {
    if (_isInit) return;

    try {
      // The parse isolate reads the file ITSELF (dart:io works off the main
      // isolate); the book bytes never exist on the main isolate and are
      // never copied across the isolate boundary. The old
      // read-then-compute(bytes) shape held 2× the book size on tight
      // devices — the exact "Out of Memory" failure the legacy engine hit.
      // Unlike the legacy engine there is also NO second
      // EpubDocument.openData on the main isolate.
      final source = await _resolveReadableSource();
      final parseResult =
          await Isolate.run(() => parseEpubFileInIsolate(source.path));

      if (parseResult.missingResourcePaths.isNotEmpty) {
        debugPrint(
          '--- [EpubReaderEngine] Auto-healed missing EPUB resources: '
          '${parseResult.missingResourcePaths.join(', ')} ---',
        );
      }

      _paragraphCount = parseResult.paragraphCount;
      _paragraphBytes = parseResult.paragraphBytes;
      _paragraphRanges = parseResult.paragraphRanges;
      _paragraphKinds = parseResult.paragraphKinds;
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
      _isInit = true;
      final initial = _readInitialPositionFromBook();
      if (initial != null) await goToPosition(initial);
    } catch (e) {
      throw FormatException('Failed to open EPUB: $e');
    }
  }

  String _paragraphText(int index) {
    final start = _paragraphRanges[index * 2];
    final end = _paragraphRanges[index * 2 + 1];
    return utf8.decode(_paragraphBytes.sublist(start, end),
        allowMalformed: true);
  }

  bool _isImageParagraph(int index) =>
      index < _paragraphKinds.length &&
      _paragraphKinds[index] == EpubParagraphKind.image;

  bool _isHeadingParagraph(int index) =>
      index < _paragraphKinds.length &&
      _paragraphKinds[index] == EpubParagraphKind.heading;

  @override
  void setConfig(ReaderConfig config) {
    if (_config.fontSize != config.fontSize ||
        _config.lineHeight != config.lineHeight ||
        _config.useSerif != config.useSerif ||
        _config.pageTurnMode != config.pageTurnMode) {
      _invalidateLayout(
          preservePaint: _config.fontSize == config.fontSize &&
              _config.lineHeight == config.lineHeight &&
              _config.useSerif == config.useSerif);
    }
    _configNotifier.value = config;
  }

  @override
  Widget buildReader(BuildContext context) {
    if (!_isInit) return const Center(child: CircularProgressIndicator());
    if (_paragraphCount == 0) {
      return Center(
        child: Text(AppLocalizations.of(context)!.readerNoContentLoaded),
      );
    }

    return _EpubViewport(
      key: ObjectKey(this),
      engine: this,
      child: LayoutBuilder(builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final locale = Localizations.maybeLocaleOf(context);
        final direction = Directionality.of(context);
        if (_viewportSize != constraints.biggest ||
            _textScaler != scaler ||
            _textLocale != locale ||
            _textDirection != direction) {
          _invalidateLayout();
          _viewportSize = constraints.biggest;
          _textScaler = scaler;
          _textLocale = locale;
          _textDirection = direction;
        }
        return ValueListenableBuilder<ReaderConfig>(
          valueListenable: _configNotifier,
          builder: (context, config, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _highlightRenderVersion,
              builder: (context, _, __) {
                return Container(
                  color: config.backgroundColor,
                  child: ScrollablePositionedList.builder(
                    itemCount: _paragraphCount,
                    initialScrollIndex: _initialIndex.clamp(
                        0, _paragraphCount > 0 ? _paragraphCount - 1 : 0),
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    itemBuilder: (context, index) =>
                        _buildParagraph(context, index, config),
                  ),
                );
              },
            );
          },
        );
      }),
    );
  }

  Widget _buildParagraph(BuildContext context, int index, ReaderConfig config) {
    // Same rhythm as the TXT canvas: 16pt gutters + fontSize*0.6 paragraph gap.
    final padding = EdgeInsets.fromLTRB(16, 0, 16, config.fontSize * 0.6);

    if (_isImageParagraph(index)) {
      return Padding(
        padding: padding,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _onContentTap?.call(details.globalPosition),
          child: SizeChangedLayoutNotifier(
              child: _EpubImageBlock(
            key: ValueKey(index),
            index: index,
            presentations: _imagePresentations,
            loadBytes: () => _imageBytesFor(_paragraphText(index)),
            config: config,
          )),
        ),
      );
    }

    final text = _paragraphText(index);
    if (text.isEmpty) {
      // The linearizer drops empty runs, so this is unreachable in practice;
      // keep the slot 1:1 with the parse regardless.
      return SizedBox(height: config.fontSize * 0.6);
    }

    // House heading scale: 1.3× body size, w600, extra breathing room above.
    // Ratio-based so it tracks the user's font-size setting.
    final isHeading = _isHeadingParagraph(index);
    return HighlightableText(
      layoutAnchors: _textLayouts,
      text: text,
      paragraphIndex: index,
      highlights: _renderHighlights,
      style: TextStyle(
        fontSize: isHeading ? config.fontSize * 1.3 : config.fontSize,
        height: config.lineHeight,
        color: config.textColor,
        fontWeight: isHeading ? FontWeight.w600 : FontWeight.w400,
        fontFamily: config.useSerif
            ? NyanTypography.readingSerifFontFamily
            : NyanTypography.uiFontFamily,
      ),
      backgroundColor: config.backgroundColor,
      padding:
          isHeading ? padding.copyWith(top: config.fontSize * 0.8) : padding,
      onTextSelected: (paragraphIdx, start, end, selectedText, colorCode) {
        _onTextHighlighted?.call(
            paragraphIdx, start, end, selectedText, colorCode);
      },
      onHighlightTap: _onHighlightTapped,
      onTap: _onContentTap,
    );
  }

  Future<Uint8List?> _imageBytesFor(String rawSrc) {
    return _imageFutures.putIfAbsent(rawSrc, () async {
      try {
        // Per-image zip extraction inside an isolate: InputFileStream
        // inflates only the requested entry, so peak memory is the decoded
        // image — the book is never loaded into RAM to serve a figure.
        final source = await _resolveReadableSource();
        // A top-level callback sends only strings. An instance closure can
        // capture this engine's live ScrollPosition/Futures, which isolates
        // cannot receive once the reader is mounted.
        return await compute(_extractEpubImage, (source.path, rawSrc));
      } catch (e) {
        debugPrint('[EpubReaderEngine] Image load failed (${e.runtimeType}).');
        return null;
      }
    });
  }

  @override
  Future<bool> waitForPagePresentation(PageTurnRequest request) async {
    await request.wait(WidgetsBinding.instance.endOfFrame);
    final waits = <Future<bool>>[];
    for (final row in _itemPositionsListener.itemPositions.value) {
      if (row.itemTrailingEdge <= 0 || row.itemLeadingEdge >= 1) continue;
      final wait = _imagePresentations[row.index];
      if (wait != null) waits.add(wait(request));
    }
    final results = await Future.wait(waits);
    await request.wait(WidgetsBinding.instance.endOfFrame);
    return !_disposed && results.every((ready) => ready);
  }

  // ── TextReaderCapability / TextExtractionCapability (P3) ─────────────

  @override
  void configureInteractions({
    ReaderTextHighlightCallback? onTextHighlighted,
    ReaderHighlightTapCallback? onHighlightTapped,
    ReaderContentTapCallback? onContentTap,
  }) {
    _onTextHighlighted = onTextHighlighted;
    _onHighlightTapped = onHighlightTapped;
    _onContentTap = onContentTap;
  }

  @override
  void setHighlights(List<Highlight> highlights) {
    _renderHighlights = List<Highlight>.unmodifiable(highlights);
    _highlightRenderVersion.value++;
  }

  /// Must return the EXACT string [HighlightableText] renders for the slot —
  /// highlight offsets and the AnchorHealer's context matching both address
  /// into it. Image paragraphs carry an href, not display text → null.
  @override
  String? getParagraphText(int paragraphIndex) {
    if (!_isInit ||
        paragraphIndex < 0 ||
        paragraphIndex >= _paragraphCount ||
        _isImageParagraph(paragraphIndex)) {
      return null;
    }
    return _paragraphText(paragraphIndex);
  }

  @override
  Future<String?> getSnippet() async {
    final pos = getCurrentPosition();
    return getTextAtPosition(pos ?? const ReadingPosition(paragraphIndex: 0));
  }

  @override
  Future<String?> getTextAtPosition(ReadingPosition position) async {
    final anchor = position.paragraphIndex;
    if (anchor == null || _paragraphCount == 0) return null;
    // The anchor may sit on an image slot (illustration pages); scan a few
    // paragraphs forward for the nearest prose so bookmark snippets stay
    // human-readable.
    final start = anchor.clamp(0, _paragraphCount - 1);
    for (var i = start; i < _paragraphCount && i < start + 8; i++) {
      final text = getParagraphText(i);
      if (text != null && text.isNotEmpty) return text.trim();
    }
    return null;
  }

  // ── Position & navigation ─────────────────────────────────────────────

  /// Topmost visible paragraph — same anchor rule as the TXT engine so the
  /// chapter label, progress and persisted position all agree (§3.6).
  ItemPosition? _currentViewportAnchor() {
    if (_paragraphCount == 0) return null;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return null;

    ItemPosition? topmost;
    for (final p in positions) {
      if (p.itemTrailingEdge <= 0 || p.itemLeadingEdge >= 1.0) continue;
      if (topmost == null || p.itemLeadingEdge < topmost.itemLeadingEdge) {
        topmost = p;
      }
    }
    // Reflow can clamp at the book boundary while the reading line stays visible.
    if (_settledAnchor?.textOffset != null &&
        _settledPixels == _scrollPosition?.pixels) {
      for (final p in positions) {
        if (p.index == _settledAnchor!.paragraphIndex &&
            p.itemTrailingEdge > 0 &&
            p.itemLeadingEdge < 1) {
          return p;
        }
      }
    }
    return topmost ?? positions.reduce((a, b) => a.index < b.index ? a : b);
  }

  int _viewportAnchorIndex() {
    if (_paragraphCount == 0) return 0;
    if (_pendingRestore != null) return _pendingRestore!.paragraphIndex!;
    final anchor = _currentViewportAnchor();
    return (anchor?.index ?? _initialIndex).clamp(0, _paragraphCount - 1);
  }

  @override
  ReadingPosition? getCurrentPosition() {
    if (!_isInit || _paragraphCount == 0) return null;
    // Saves during restoration must never observe the temporary index anchor.
    if (_pendingRestore != null) return _pendingRestore;
    final anchor = _currentViewportAnchor();
    // Paragraph-index anchoring (no CFIs): legacy rows always persisted
    // paragraphIndex alongside their CFI, so both directions restore through
    // the same field. Viewport edges refine restore to sub-paragraph
    // precision (same scheme as TXT).
    final position = ReadingPosition(
      paragraphIndex:
          (anchor?.index ?? _initialIndex).clamp(0, _paragraphCount - 1),
      paragraphLeadingEdge: anchor?.itemLeadingEdge,
      paragraphTrailingEdge: anchor?.itemTrailingEdge,
      // Marks the payload as measured against the spine-primary enumeration
      // (2026-07); pre-switch payloads have no marker. Forensic only.
      enumVersion: kEpubEnumerationVersion,
    );
    return _textLayouts.capture(
        position, _scrollPosition?.viewportDimension ?? 0,
        layoutIdentity: _layoutIdentity,
        preferredOffset: _settledPixels == _scrollPosition?.pixels &&
                _settledAnchor?.paragraphIndex == position.paragraphIndex
            ? _settledAnchor?.textOffset
            : null);
  }

  @override
  double? getProgress() {
    if (!_isInit || _paragraphCount <= 1) {
      return _lastKnownProgress.clamp(0.0, 1.0);
    }
    final progress = _viewportAnchorIndex() / (_paragraphCount - 1);
    _lastKnownProgress = progress.clamp(0.0, 1.0);
    return _lastKnownProgress;
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    final index = position.paragraphIndex;
    if (index == null || _disposed || _paragraphCount == 0) {
      // CFI-only positions cannot exist in practice (legacy always dual-
      // wrote paragraphIndex); if one shows up, the caller's progress
      // fallback takes over.
      return;
    }
    _turns.clear();
    final clamped = index.clamp(0, _paragraphCount - 1);
    final leading = position.paragraphLeadingEdge;
    final trailing = position.paragraphTrailingEdge;
    final validEdges = clamped == index &&
        leading != null &&
        trailing != null &&
        leading.isFinite &&
        trailing.isFinite &&
        (trailing - leading).isFinite &&
        leading < 1 &&
        trailing > 0 &&
        trailing > leading;
    _navigationSerial++;
    _initialIndex = clamped;
    _pendingRestore = ReadingPosition(
        paragraphIndex: clamped,
        paragraphLeadingEdge: validEdges ? leading : null,
        textOffset:
            clamped == position.paragraphIndex ? position.textOffset : null,
        textViewportOffset: position.textViewportOffset,
        layoutIdentity: position.layoutIdentity,
        anchorVersion: position.anchorVersion,
        paragraphTrailingEdge: validEdges ? trailing : null,
        enumVersion: kEpubEnumerationVersion);
    if (_scrollPosition == null || !_itemScrollController.isAttached) {
      _restoreCover.value = true;
      return;
    }
    await _applyPendingRestore();
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (_disposed || _paragraphCount <= 0 || !progress.isFinite) return;
    final clamped = progress.clamp(0.0, 1.0);
    final targetIndex = (clamped * (_paragraphCount - 1)).round();
    await goToPosition(ReadingPosition(paragraphIndex: targetIndex));
  }

  Future<void> jumpToChapterStart(int startIndex) =>
      goToPosition(ReadingPosition(paragraphIndex: startIndex));

  @override
  Future<void> goToChapter(ChapterLocator locator) async {
    if (locator.contentIndex != null) {
      await jumpToChapterStart(locator.contentIndex!);
    }
  }

  @override
  Future<List<ReaderChapter>> getChapters() async {
    if (!_isInit) return [];
    return _chapters;
  }

  @override
  Future<void> nextPage() => _stepByViewport(forward: true);

  @override
  Future<void> previousPage() => _stepByViewport(forward: false);

  /// Pixel motion retains unread tails regardless of paragraph height.
  Future<void> _stepByViewport({required bool forward}) async {
    final scroll = _scrollPosition;
    if (_disposed ||
        _pendingRestore != null ||
        scroll == null ||
        !scroll.hasContentDimensions ||
        _paragraphCount == 0) {
      return;
    }
    final before = getCurrentPosition();
    if (before == null) return;
    final start = scroll.pixels;
    final last = _turns.isEmpty ? null : _turns.last;
    if (last != null && !last.endsAt(start, before, scroll.viewportDimension)) {
      _turns.clear();
    }
    final reverse = _turns.isNotEmpty && _turns.last.forward != forward;
    final requested = reverse
        ? _turns.last.start
        : start +
            (forward ? _viewportStep : -_viewportStep) *
                scroll.viewportDimension;
    final target =
        requested.clamp(scroll.minScrollExtent, scroll.maxScrollExtent);
    if ((target - start).abs() < .01) return;
    final serial = ++_navigationSerial;
    if (_config.pageTurnMode == PageTurnMode.tap) {
      scroll.jumpTo(target);
    } else {
      await scroll.animateTo(target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed ||
        serial != _navigationSerial ||
        !identical(scroll, _scrollPosition)) {
      return;
    }
    // Interrupted motion must not create a valid-looking historical turn.
    if ((scroll.pixels - target).abs() > 2) {
      _turns.clear();
      return;
    }
    if (reverse) {
      _turns.removeLast();
    } else {
      _turns.add(_EpubTurn(
          start: start,
          end: scroll.pixels,
          position: getCurrentPosition()!,
          forward: forward));
      if (_turns.length > _historyLimit) _turns.removeAt(0);
    }
  }

  Future<void> _applyPendingRestore() async {
    final target = _pendingRestore;
    final scroll = _scrollPosition;
    final serial = _navigationSerial;
    if (_disposed ||
        target == null ||
        scroll == null ||
        !_itemScrollController.isAttached ||
        _applyingRestore == serial) {
      return;
    }
    _applyingRestore = serial;
    _itemScrollController.jumpTo(index: target.paragraphIndex!);
    var offset = -(target.paragraphLeadingEdge ?? 0) * scroll.viewportDimension;
    if (target.anchorVersion == 1 &&
        target.textOffset != null &&
        target.layoutIdentity != _layoutIdentity) {
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || serial != _navigationSerial) return;
      offset =
          _textLayouts.restoreOffset(target, scroll.viewportDimension) ?? 0;
    }
    final destination = scroll.pixels + offset;
    if (destination.isFinite) scroll.jumpTo(destination);
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || serial != _navigationSerial) return;
    // The new extent may start a boundary correction after jumpTo.
    while (scroll.isScrollingNotifier.value) {
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || serial != _navigationSerial) return;
    }
    _settledAnchor = target;
    _settledPixels = scroll.pixels;
    _pendingRestore = null;
    _applyingRestore = null;
    _restoreCover.value = false;
    _updateCommittedPosition();
  }

  void _attachScrollPosition(ScrollPosition position) {
    if (_disposed) return;
    if (_scrollPosition != null && !identical(_scrollPosition, position)) {
      _detachViewport();
    }
    _scrollPosition = position;
    if (_pendingRestore != null) {
      // Metrics own completion of a restore accepted before mounting.
      unawaited(_applyPendingRestore());
    }
  }

  void _interruptGesture() {
    _navigationSerial++;
    _settledAnchor = null;
    _turns.clear();
    _pendingRestore = null;
    _applyingRestore = null;
    _restoreCover.value = false;
  }

  void _detachViewport() {
    _navigationSerial++;
    _turns.clear();
    _scrollPosition = null;
    _applyingRestore = null;
  }

  void _invalidateLayout({bool preservePaint = false}) {
    if (_scrollPosition != null) {
      _pendingRestore ??= _committedPixels == _scrollPosition?.pixels
          ? (_committedPosition ?? getCurrentPosition())
          : getCurrentPosition();
      _initialIndex = _pendingRestore?.paragraphIndex ?? _initialIndex;
      if (!preservePaint && _pendingRestore?.textOffset != null) {
        _restoreCover.value = true;
      }
    }
    _turns.clear();
    final serial = ++_navigationSerial;
    _applyingRestore = null;
    if (_scrollPosition == null) return;
    // Layout notifications can arrive during build/layout, so cancel motion
    // after layout rather than mutating a ScrollPosition from build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || serial != _navigationSerial) return;
      final scroll = _scrollPosition;
      if (scroll == null) return;
      scroll.jumpTo(scroll.pixels);
      if (_pendingRestore != null) {
        // This frame owns retrying the accepted target after a layout change.
        unawaited(_applyPendingRestore());
      }
    });
  }

  ReadingPosition? _readInitialPositionFromBook() {
    if (book.lastPositionType != 'epub') return null;
    final payload = book.lastPositionPayload;
    if (payload == null || payload.isEmpty) return null;
    try {
      return ReadingPosition.fromJson('epub', payload);
    } catch (error) {
      // The visible fallback is the book start; never log a user's payload.
      debugPrint(
          'EPUB saved position unavailable (${error.runtimeType}); opening at start.');
      return null;
    }
  }

  @override
  bool get hasBottomBar => false;

  @override
  void dispose() {
    _disposed = true;
    _imagePresentations.clear();
    _itemPositionsListener.itemPositions
        .removeListener(_updateCommittedPosition);
    _detachViewport();
    _pendingRestore = null;
    _restoreCover.dispose();
    _configNotifier.dispose();
    _highlightRenderVersion.dispose();
    // Reclaim the session temp copy for SAF sources. Fire-and-forget: a
    // missed delete ages out via the 24h cache scavenger.
    final pending = _readableSource;
    if (pending != null) {
      unawaited(pending.then((source) async {
        if (source.isTemporary) {
          try {
            await File(source.path).delete();
          } catch (_) {}
        }
      }).catchError((_) {}));
    }
  }
}

Uint8List? _extractEpubImage((String, String) source) =>
    extractEpubImageBytesFromFile(source.$1, source.$2);

class _EpubTurn {
  const _EpubTurn(
      {required this.start,
      required this.end,
      required this.position,
      required this.forward});
  final double start;
  final double end;
  final ReadingPosition position;
  final bool forward;

  bool endsAt(double pixels, ReadingPosition current, double height) =>
      (pixels - end).abs() <= 2 &&
      position.paragraphIndex == current.paragraphIndex &&
      ((position.paragraphLeadingEdge ?? 0) -
                      (current.paragraphLeadingEdge ?? 0))
                  .abs() *
              height <=
          2 &&
      ((position.paragraphTrailingEdge ?? 0) -
                      (current.paragraphTrailingEdge ?? 0))
                  .abs() *
              height <=
          2;
}

// The viewport owns attachment only. Positions and navigation remain in the
// engine, including targets accepted before this widget exists.
class _EpubViewport extends StatefulWidget {
  const _EpubViewport({super.key, required this.engine, required this.child});
  final EpubReaderEngine engine;
  final Widget child;

  @override
  State<_EpubViewport> createState() => _EpubViewportState();
}

class _EpubViewportState extends State<_EpubViewport> {
  @override
  void dispose() {
    widget.engine._detachViewport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          widget.engine._invalidateLayout();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth == 0 &&
                notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              widget.engine._interruptGesture();
            }
            return false;
          },
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) {
                final scrollable = Scrollable.maybeOf(notification.context);
                if (scrollable != null) {
                  widget.engine._attachScrollPosition(scrollable.position);
                }
              }
              return false;
            },
            child: RestoreVisibility(
                covered: widget.engine._restoreCover, child: widget.child),
          ),
        ),
      );
}

/// Async image block: shows a neutral placeholder while the zip extraction
/// runs, the bitmap on success, and a quiet fallback box on failure.
class _EpubImageBlock extends StatefulWidget {
  const _EpubImageBlock(
      {super.key,
      required this.loadBytes,
      required this.config,
      required this.index,
      required this.presentations});

  final int index;
  final Map<int, Future<bool> Function(PageTurnRequest)> presentations;

  final Future<Uint8List?> Function() loadBytes;
  final ReaderConfig config;

  @override
  State<_EpubImageBlock> createState() => _EpubImageBlockState();
}

class _EpubImageBlockState extends State<_EpubImageBlock> {
  late final Future<Uint8List?> _future = widget.loadBytes();

  @override
  void initState() {
    super.initState();
    widget.presentations[widget.index] = _waitForFrame;
  }

  @override
  void dispose() {
    if (widget.presentations[widget.index] == _waitForFrame) {
      widget.presentations.remove(widget.index);
    }
    super.dispose();
  }

  Future<bool> _waitForFrame(PageTurnRequest request) async {
    final bytes = await request.wait(_future);
    if (!mounted || bytes == null || bytes.isEmpty) return false;
    return waitForImageFrame(MemoryImage(bytes), request);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            bytes != null &&
            bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        }
        return Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: config.textColor.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: snapshot.connectionState != ConnectionState.done
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                        config.textColor.withValues(alpha: 0.5)),
                  ),
                )
              : Text(
                  AppLocalizations.of(context)!.readerImageLoadFailed(
                      AppLocalizations.of(context)!.readerImageDefaultAlt),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: config.textColor.withValues(alpha: 0.7),
                  ),
                ),
        );
      },
    );
  }
}
