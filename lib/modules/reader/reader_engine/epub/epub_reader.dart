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
  // Reader and shelf labels round to whole percentages. Reserve 100% for EOF.
  static const _maxIncompleteProgress = .9949;
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

  // Cap only idle encoded data. Mounted blocks and presentation waits can
  // outlive a cache trim, and in-flight loads must remain single-flight.
  static const _idleImageLimit = 32;
  static const _idleImageByteLimit = 16 * 1024 * 1024;
  final Map<String, Future<_EpubImageData?>> _imageFutures = {};
  final _imageUsers = <String, int>{};
  final _activeImages = <String, _EpubImageData>{};
  final _idleImages = <String, _EpubImageData>{};
  int _idleImageBytes = 0;
  final _imageSizes = <String, Size>{};
  final _failedImages = <String>{};
  final _cancelImageDecodes = <VoidCallback>{};
  final _imageHandoffs = <String, VoidCallback>{};
  final Future<Uint8List?> Function(String, String) _extractImage;

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

  EpubReaderEngine(Book book) : this._(book, _extractImageInIsolate);

  @visibleForTesting
  EpubReaderEngine.withImageLoader(
    Book book,
    Future<Uint8List?> Function(String path, String entryPath) extractImage,
  ) : this._(book, extractImage);

  EpubReaderEngine._(this.book, this._extractImage) {
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
            // Empty when untitled: no l10n here; the UI fills it via readerChapterTitle().
            title: title ?? '',
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
            engine: this,
            entryPath: _paragraphText(index),
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

  _EpubImageData? _retainImage(String entryPath) {
    if (_disposed) return null;
    _imageUsers.update(entryPath, (count) => count + 1, ifAbsent: () => 1);
    final idle = _idleImages.remove(entryPath);
    if (idle != null) {
      _idleImageBytes -= idle.bytes.lengthInBytes;
      _activeImages[entryPath] = idle;
    }
    return _activeImages[entryPath];
  }

  void _releaseImage(String entryPath) {
    if (_disposed) return;
    final users = _imageUsers[entryPath]!;
    if (users > 1) {
      _imageUsers[entryPath] = users - 1;
      return;
    }
    _imageUsers.remove(entryPath);
    _imageHandoffs.remove(entryPath)?.call();
    final image = _activeImages.remove(entryPath);
    if (image != null) _cacheIdleImage(entryPath, image);
  }

  void _cacheIdleImage(String entryPath, _EpubImageData image) {
    final bytes = image.bytes.lengthInBytes;
    if (bytes > _idleImageByteLimit) {
      _evictIdleBitmap(image);
      return;
    }
    _idleImages[entryPath] = image;
    _idleImageBytes += bytes;
    // The insertion order tracks when an image last finished being used.
    while (_idleImages.length > _idleImageLimit ||
        _idleImageBytes > _idleImageByteLimit) {
      final oldest = _idleImages.remove(_idleImages.keys.first)!;
      _idleImageBytes -= oldest.bytes.lengthInBytes;
      _evictIdleBitmap(oldest);
    }
  }

  Future<_EpubImageData?> _imageBytesFor(String entryPath) {
    if (_disposed || entryPath.isEmpty || _failedImages.contains(entryPath)) {
      return Future.value();
    }
    return _imageFutures.putIfAbsent(entryPath, () => _loadImage(entryPath));
  }

  Future<_EpubImageData?> _loadImage(String entryPath) async {
    try {
      final source = await _resolveReadableSource();
      if (_disposed) return null;
      final bytes = await _extractImage(source.path, entryPath);
      if (_disposed) return null;
      if (bytes == null || bytes.isEmpty) {
        _failedImages.add(entryPath);
        return null;
      }
      final image = await _resolveImageData(entryPath, bytes);
      if (_disposed) {
        if (image != null) _evictIdleBitmap(image);
        return null;
      }
      if (image == null) return null;
      _imageSizes[entryPath] = image.size;
      if (_imageUsers.containsKey(entryPath)) {
        _activeImages[entryPath] = image;
      } else {
        _cacheIdleImage(entryPath, image);
      }
      return image;
    } catch (error) {
      if (!_disposed) _failedImages.add(entryPath);
      debugPrint(
          '[EpubReaderEngine] Image load failed (${error.runtimeType}).');
      return null;
    } finally {
      _imageFutures.remove(entryPath);
    }
  }

  Future<_EpubImageData?> _resolveImageData(
      String entryPath, Uint8List bytes) async {
    // Reuse Flutter's decode (including orientation) and the exact paint key.
    final ready = Completer<_EpubImageData?>();
    final provider = MemoryImage(bytes);
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, synchronous) {
      if (!ready.isCompleted) {
        ready.complete(_EpubImageData(bytes,
            Size(info.image.width.toDouble(), info.image.height.toDouble())));
      }
      info.dispose();
    }, onError: (Object error, StackTrace? stack) {
      if (!ready.isCompleted) ready.completeError(error, stack);
    });
    // A session-wide Future.any would keep the winning result reachable
    // through its losing cancellation callback until the reader closes.
    void cancel() {
      if (!ready.isCompleted) ready.complete(null);
    }

    void detach() => stream.removeListener(listener);

    var handedOff = false;
    _cancelImageDecodes.add(cancel);
    try {
      stream.addListener(listener);
      final image = await ready.future;
      if (image != null &&
          !_disposed &&
          _imageUsers.containsKey(entryPath) &&
          !PaintingBinding.instance.imageCache
              .statusForKey(provider)
              .keepAlive) {
        // Without an idle cache entry, removing the last listener here would
        // make the mounted Image resolve the same bytes through a new codec.
        _imageHandoffs[entryPath] = detach;
        handedOff = true;
      }
      return image;
    } finally {
      if (!handedOff) detach();
      _cancelImageDecodes.remove(cancel);
    }
  }

  void _finishImageHandoffAfterBuild(String entryPath) {
    final detach = _imageHandoffs[entryPath];
    if (detach == null) return;
    // The Image gets to subscribe during this build. Use the current frame
    // even when Flutter defers listening, so a hidden row cannot pin a bitmap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!identical(_imageHandoffs[entryPath], detach)) return;
      _imageHandoffs.remove(entryPath);
      detach();
    });
  }

  @override
  Future<bool> waitForPagePresentation(PageTurnRequest request) async {
    await request.wait(WidgetsBinding.instance.endOfFrame);
    final checked = <Future<bool> Function(PageTurnRequest), bool>{};
    var painted = false;
    while (!_disposed) {
      final waits = <Future<void>>[];
      var allChecked = true;
      var allReady = true;
      for (final row in _itemPositionsListener.itemPositions.value) {
        if (row.itemTrailingEdge <= 0 ||
            row.itemLeadingEdge >= 1 ||
            !_isImageParagraph(row.index)) {
          continue;
        }
        final wait = _imagePresentations[row.index];
        final ready = checked[wait];
        if (ready == null) {
          allChecked = false;
          if (wait != null) {
            waits.add(wait(request).then<void>((ready) {
              checked[wait] = ready;
            }));
          }
        } else {
          allReady = allReady && ready;
        }
      }
      if (painted && allChecked && _pendingRestore == null) return allReady;
      await Future.wait(waits);
      // First decode can resize a row, move the restore anchor and reveal
      // another image. Only the visible blocks in the painted frame count.
      await request.wait(WidgetsBinding.instance.endOfFrame);
      painted = true;
    }
    return false;
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
    // Reflow can clamp at the book boundary while the target stays visible.
    final settled = _settledAnchor;
    final settledIndex = settled?.paragraphIndex;
    if (settled != null &&
        settledIndex != null &&
        _settledPixels == _scrollPosition?.pixels &&
        (settled.textOffset != null ||
            (_isImageParagraph(settledIndex) &&
                settled.paragraphLeadingEdge != null))) {
      for (final p in positions) {
        if (p.index == settledIndex &&
            p.itemTrailingEdge > 0 &&
            p.itemLeadingEdge < 1) {
          return p;
        }
      }
    }
    return topmost ?? positions.reduce((a, b) => a.index < b.index ? a : b);
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
    if (!_isInit || _paragraphCount == 0) return 0.0;
    final pending = _pendingRestore;
    if (pending != null) {
      // The temporary viewport is not authoritative during a restore.
      return _lastKnownProgress = _estimateProgress(pending.paragraphIndex!,
          pending.paragraphLeadingEdge, pending.paragraphTrailingEdge);
    }
    final scroll = _scrollPosition;
    if (scroll == null || !scroll.hasContentDimensions) {
      return _lastKnownProgress;
    }
    final anchor = _currentViewportAnchor();
    if (anchor == null) return _lastKnownProgress;

    // Positioned lists can have a temporary scroll limit before the last
    // paragraph is laid out. Confirm the actual tail is in the viewport too.
    if (scroll.maxScrollExtent > scroll.minScrollExtent &&
        scroll.extentAfter == 0 &&
        _itemPositionsListener.itemPositions.value.any((item) =>
            item.index == _paragraphCount - 1 &&
            item.itemTrailingEdge > 0 &&
            item.itemTrailingEdge <= 1)) {
      return _lastKnownProgress = 1.0;
    }
    return _lastKnownProgress = _estimateProgress(
        anchor.index, anchor.itemLeadingEdge, anchor.itemTrailingEdge);
  }

  double _estimateProgress(int index, double? leading, double? trailing) {
    var fraction = 0.0;
    if (leading != null && trailing != null && leading < 0 && trailing > 0) {
      final extent = trailing - leading;
      if (extent.isFinite) fraction = -leading / extent;
    }
    return ((index + fraction) / _paragraphCount)
        .clamp(0.0, _maxIncompleteProgress);
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
    final index = target.paragraphIndex!;
    _itemScrollController.jumpTo(index: index);
    var offset = -(target.paragraphLeadingEdge ?? 0) * scroll.viewportDimension;
    final imageFraction = _clippedImageFraction(target);
    if (imageFraction != null) {
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || serial != _navigationSerial) return;
      // Use row-relative progress so a taller viewport cannot scroll past
      // the image. A cold placeholder supplies provisional geometry until
      // its size notification reapplies the anchor to the decoded row.
      offset =
          _imageRestoreOffset(index, imageFraction, scroll.viewportDimension);
    } else if (target.anchorVersion == 1 &&
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

  double? _clippedImageFraction(ReadingPosition? position) {
    final index = position?.paragraphIndex;
    final leading = position?.paragraphLeadingEdge ?? 0;
    final trailing = position?.paragraphTrailingEdge ?? 0;
    final extent = trailing - leading;
    if (index == null ||
        !_isImageParagraph(index) ||
        !(leading < 0 && trailing > 0 && extent.isFinite)) {
      return null;
    }
    return -leading / extent;
  }

  double _imageRestoreOffset(int index, double fraction, double viewport) {
    for (final row in _itemPositionsListener.itemPositions.value) {
      if (row.index != index) continue;
      final extent = (row.itemTrailingEdge - row.itemLeadingEdge) * viewport;
      if (extent <= 1 || !extent.isFinite) break;
      // Item positions are rounded to pixels. Keep one pixel in the row so
      // the next anchor capture cannot select its successor at the seam.
      return (fraction * extent).clamp(0, extent - 1);
    }
    return 0;
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
    final pixels = _scrollPosition?.pixels;
    if (pixels != null) {
      if (_pendingRestore == null) {
        final committed =
            _committedPixels == pixels ? _committedPosition : null;
        final settled = _settledAnchor;
        // A cold placeholder rounds to whole pixels, and an EOF clamp can
        // leave the image fully visible. Keep the requested fraction through
        // either correction until an actual scroll or newer navigation.
        final keepImageFraction = _settledPixels == pixels &&
            settled?.paragraphIndex == committed?.paragraphIndex &&
            _clippedImageFraction(settled) != null;
        _pendingRestore =
            (keepImageFraction ? settled : committed) ?? getCurrentPosition();
      }
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
    for (final cancel in _cancelImageDecodes) {
      cancel();
    }
    _cancelImageDecodes.clear();
    for (final detach in _imageHandoffs.values) {
      detach();
    }
    _imageHandoffs.clear();
    _imagePresentations.clear();
    for (final image in _idleImages.values) {
      _evictIdleBitmap(image);
    }
    for (final image in _activeImages.values) {
      _evictIdleBitmap(image);
    }
    _idleImages.clear();
    _idleImageBytes = 0;
    _activeImages.clear();
    _imageUsers.clear();
    _imageSizes.clear();
    _failedImages.clear();
    _imageFutures.clear();
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

// Send only the book and entry paths to the isolate. Capturing the engine would
// also send its live ScrollPosition and Futures.
Future<Uint8List?> _extractImageInIsolate(String path, String entryPath) =>
    compute(_extractEpubImage, (path, entryPath));

final class _EpubImageData {
  const _EpubImageData(this.bytes, this.size);
  final Uint8List bytes;
  final Size size;
}

void _evictIdleBitmap(_EpubImageData image) {
  final cache = PaintingBinding.instance.imageCache;
  final key = MemoryImage(image.bytes);
  // The key itself owns the encoded bytes. Drop its completed cache entry
  // without disturbing listeners or a pending framework decode.
  if (cache.statusForKey(key).keepAlive) {
    cache.evict(key, includeLive: false);
  }
}

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
      required this.engine,
      required this.entryPath,
      required this.config,
      required this.index});

  final EpubReaderEngine engine;
  final String entryPath;
  final int index;
  final ReaderConfig config;

  @override
  State<_EpubImageBlock> createState() => _EpubImageBlockState();
}

class _EpubImageBlockState extends State<_EpubImageBlock> {
  static const _imageConstraints = BoxConstraints(maxHeight: 420);
  late final Future<_EpubImageData?> _future;
  late final _EpubImageData? _initialImage;
  late final Size? _knownSize;

  @override
  void initState() {
    super.initState();
    final engine = widget.engine;
    final entryPath = widget.entryPath;
    _initialImage = engine._retainImage(entryPath);
    _knownSize = engine._imageSizes[entryPath];
    _future = _initialImage == null
        ? engine._imageBytesFor(entryPath)
        : Future.value(_initialImage);
    engine._imagePresentations[widget.index] = _waitForFrame;
  }

  @override
  void dispose() {
    final engine = widget.engine;
    if (engine._imagePresentations[widget.index] == _waitForFrame) {
      engine._imagePresentations.remove(widget.index);
    }
    engine._releaseImage(widget.entryPath);
    super.dispose();
  }

  Future<bool> _waitForFrame(PageTurnRequest request) async {
    final image = await request.wait(_future);
    if (!mounted || image == null || widget.engine._disposed) return false;
    final engine = widget.engine;
    final entryPath = widget.entryPath;
    engine._retainImage(entryPath);
    try {
      return await waitForImageFrame(MemoryImage(image.bytes), request);
    } finally {
      engine._releaseImage(entryPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return FutureBuilder<_EpubImageData?>(
      future: _future,
      initialData: _initialImage,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image != null) {
          widget.engine._finishImageHandoffAfterBuild(widget.entryPath);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: _imageConstraints,
              child: Image.memory(image.bytes,
                  width: image.size.width,
                  height: image.size.height,
                  fit: BoxFit.contain),
            ),
          );
        }
        final knownSize = _knownSize;
        final feedback = Container(
          height: knownSize == null ? 120 : null,
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
        if (knownSize == null) return feedback;
        // Match Image's explicit dimensions under the current constraints.
        // Falling back to the first-load height would invalidate turn anchors.
        return ConstrainedBox(
          constraints: _imageConstraints,
          child: SizedBox(
            width: knownSize.width,
            height: knownSize.height,
            child: feedback,
          ),
        );
      },
    );
  }
}
