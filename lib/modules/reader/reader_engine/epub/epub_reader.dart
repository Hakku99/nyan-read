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
import 'epub_parse_helpers.dart';

/// Self-hosted EPUB renderer (2026-07, "EPUB 自研" P1).
///
/// Replaces the epub_view widget with the same ScrollablePositionedList
/// machinery the TXT engine uses: the parse isolate flattens every chapter
/// into paragraphs (UTF-8 bytes + ranges), and this engine renders them as
/// plain styled text blocks. Publisher CSS is deliberately dropped — the
/// paper-like house typography overrides book styling by design.
///
/// Position model: absolute paragraph index only. Legacy positions were
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
    implements ReaderEngine, TextReaderCapability, TextExtractionCapability {
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

  Future<PdfCompatibleSource> _resolveReadableSource() =>
      _readableSource ??=
          BookSourceAccess.prepareReadableFile(book, extension: '.epub');

  final ValueNotifier<ReaderConfig> _configNotifier =
      ValueNotifier<ReaderConfig>(const ReaderConfig(
    backgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 18,
    lineHeight: 1.5,
  ));

  ReaderConfig get _config => _configNotifier.value;

  EpubReaderEngine(this.book);

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
      _initialIndex = _readInitialParagraphIndexFromBook();
      _isInit = true;
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
          child: _EpubImageBlock(
            loadBytes: () => _imageBytesFor(_paragraphText(index)),
            config: config,
          ),
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
      padding: isHeading
          ? padding.copyWith(top: config.fontSize * 0.8)
          : padding,
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
        return await Isolate.run(
            () => extractEpubImageBytesFromFile(source.path, rawSrc));
      } catch (e) {
        debugPrint('[EpubReaderEngine] image load failed for $rawSrc: $e');
        return null;
      }
    });
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
    return getTextAtPosition(
        pos ?? const ReadingPosition(paragraphIndex: 0));
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
    return topmost ?? positions.reduce((a, b) => a.index < b.index ? a : b);
  }

  int _viewportAnchorIndex() {
    if (_paragraphCount == 0) return 0;
    final anchor = _currentViewportAnchor();
    return (anchor?.index ?? _initialIndex).clamp(0, _paragraphCount - 1);
  }

  /// Mirrors TxtReaderEngine._alignmentFromEdges: converts a captured
  /// leading/trailing edge pair back into a ScrollablePositionedList
  /// alignment so restore lands mid-paragraph exactly where the reader
  /// left off, not snapped to the paragraph top.
  double? _alignmentFromEdges({
    required double leadingEdge,
    required double trailingEdge,
  }) {
    final ratio = trailingEdge - leadingEdge;
    final denominator = 1.0 - ratio;
    if (denominator.abs() < 0.0001) {
      return null;
    }
    return (leadingEdge / denominator).clamp(0.0, 1.0);
  }

  int _visibleParagraphCount() {
    final positions = _itemPositionsListener.itemPositions.value;
    var visible = 0;
    for (final p in positions) {
      if (p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1.0) visible++;
    }
    return visible;
  }

  @override
  ReadingPosition? getCurrentPosition() {
    if (!_isInit || _paragraphCount == 0) return null;
    final anchor = _currentViewportAnchor();
    // Paragraph-index anchoring (no CFIs): legacy rows always persisted
    // paragraphIndex alongside their CFI, so both directions restore through
    // the same field. Viewport edges refine restore to sub-paragraph
    // precision (same scheme as TXT).
    return ReadingPosition(
      paragraphIndex:
          (anchor?.index ?? _initialIndex).clamp(0, _paragraphCount - 1),
      paragraphLeadingEdge: anchor?.itemLeadingEdge,
      paragraphTrailingEdge: anchor?.itemTrailingEdge,
    );
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
    if (index == null) {
      // CFI-only positions cannot exist in practice (legacy always dual-
      // wrote paragraphIndex); if one shows up, the caller's progress
      // fallback takes over.
      return;
    }
    final leading = position.paragraphLeadingEdge;
    final trailing = position.paragraphTrailingEdge;
    final alignment = (leading != null && trailing != null)
        ? _alignmentFromEdges(leadingEdge: leading, trailingEdge: trailing)
        : null;
    await _jumpToIndex(index, alignment: alignment ?? 0.0);
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (_paragraphCount <= 0) return;
    final clamped = progress.clamp(0.0, 1.0);
    final targetIndex = (clamped * (_paragraphCount - 1)).round();
    if (_config.pageTurnMode == PageTurnMode.tap) {
      await _jumpToIndex(targetIndex);
    } else {
      await _scrollToIndex(targetIndex);
    }
    _lastKnownProgress = clamped;
  }

  Future<void> jumpToChapterStart(int startIndex) => _jumpToIndex(startIndex);

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

  /// Steps by the actually-visible paragraph count — the self-hosted list
  /// exposes its ItemPositionsListener, so no single-item extrapolation is
  /// needed anymore (the legacy engine could only estimate).
  Future<void> _stepByViewport({required bool forward}) async {
    if (_paragraphCount == 0) return;
    final maxIndex = _paragraphCount - 1;
    final current = _viewportAnchorIndex();
    final step = _visibleParagraphCount().clamp(1, 200);
    final target =
        (forward ? current + step : current - step).clamp(0, maxIndex);
    await seekToProgress(maxIndex == 0 ? 0.0 : target / maxIndex);
  }

  Future<void> _jumpToIndex(int index, {double alignment = 0.0}) async {
    if (_paragraphCount == 0) return;
    final clamped = index.clamp(0, _paragraphCount - 1);
    _initialIndex = clamped;
    await _waitForViewAttached();
    if (_itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: clamped, alignment: alignment);
      // One frame for the positions listener to observe the jump before
      // callers read getCurrentPosition (mirrors the legacy 60ms settle).
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  Future<void> _scrollToIndex(int index) async {
    if (_paragraphCount == 0) return;
    final clamped = index.clamp(0, _paragraphCount - 1);
    _initialIndex = clamped;
    await _waitForViewAttached();
    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: clamped,
        alignment: 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// The list attaches on its first frame; restore paths can race it.
  Future<void> _waitForViewAttached() async {
    if (_itemScrollController.isAttached) return;
    for (var waited = 0; waited < 5000; waited += 50) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_itemScrollController.isAttached) return;
    }
  }

  int _readInitialParagraphIndexFromBook() {
    if (book.lastPositionType != 'epub') return 0;
    final payload = book.lastPositionPayload;
    if (payload == null || payload.isEmpty) return 0;
    try {
      return ReadingPosition.fromJson('epub', payload).paragraphIndex ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  bool get hasBottomBar => false;

  @override
  void dispose() {
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

/// Async image block: shows a neutral placeholder while the zip extraction
/// runs, the bitmap on success, and a quiet fallback box on failure.
class _EpubImageBlock extends StatefulWidget {
  const _EpubImageBlock({required this.loadBytes, required this.config});

  final Future<Uint8List?> Function() loadBytes;
  final ReaderConfig config;

  @override
  State<_EpubImageBlock> createState() => _EpubImageBlockState();
}

class _EpubImageBlockState extends State<_EpubImageBlock> {
  late final Future<Uint8List?> _future = widget.loadBytes();

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
            border: Border.all(
                color: config.textColor.withValues(alpha: 0.25)),
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
