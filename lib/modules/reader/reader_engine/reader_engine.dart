import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/models/highlight.dart';
import '../../../core/services/reader_preferences_service.dart';

class ReadingPosition {
  final int? paragraphIndex;
  final double? paragraphLeadingEdge;
  final double? paragraphTrailingEdge;
  final int? pageNumber;
  final String? cfi;
  final int? chapterIndex;

  /// EPUB content-enumeration version the anchor was measured against
  /// (kEpubEnumerationVersion). Null for TXT/PDF and for EPUB payloads
  /// written before the 2026-07 spine-primary switch — a forensic marker,
  /// never consulted on restore today.
  final int? enumVersion;

  const ReadingPosition({
    this.paragraphIndex,
    this.paragraphLeadingEdge,
    this.paragraphTrailingEdge,
    this.pageNumber,
    this.cfi,
    this.chapterIndex,
    this.enumVersion,
  });

  factory ReadingPosition.fromJson(String type, String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return ReadingPosition(
      paragraphIndex: type == 'txt'
          ? (map['paragraphIndex'] as int? ?? 0)
          : map['paragraphIndex'] as int?,
      paragraphLeadingEdge: (map['paragraphLeadingEdge'] as num?)?.toDouble(),
      paragraphTrailingEdge: (map['paragraphTrailingEdge'] as num?)?.toDouble(),
      pageNumber: type == 'pdf'
          ? (map['pageNumber'] as int? ?? 1)
          : map['pageNumber'] as int?,
      cfi: map['cfi'] as String?,
      chapterIndex: map['chapterIndex'] as int?,
      enumVersion: map['enumVersion'] as int?,
    );
  }

  bool get hasLocation =>
      paragraphIndex != null ||
      pageNumber != null ||
      (cfi != null && cfi!.isNotEmpty);

  String toJson() {
    final map = <String, dynamic>{};
    if (paragraphIndex != null) {
      map['paragraphIndex'] = paragraphIndex;
    }
    if (paragraphLeadingEdge != null) {
      map['paragraphLeadingEdge'] = paragraphLeadingEdge;
    }
    if (paragraphTrailingEdge != null) {
      map['paragraphTrailingEdge'] = paragraphTrailingEdge;
    }
    if (pageNumber != null) {
      map['pageNumber'] = pageNumber;
    }
    if (cfi != null) {
      map['cfi'] = cfi;
    }
    if (chapterIndex != null) {
      map['chapterIndex'] = chapterIndex;
    }
    if (enumVersion != null) {
      map['enumVersion'] = enumVersion;
    }
    return jsonEncode(map);
  }
}

typedef ReaderTextHighlightCallback = void Function(
  int paragraphIndex,
  int start,
  int end,
  String text,
  String colorCode,
);

typedef ReaderHighlightTapCallback = void Function(Highlight highlight);

/// Global position in logical pixels (same as [PointerEvent.globalPosition]).
typedef ReaderContentTapCallback = void Function(Offset globalPosition);

class ChapterLocator {
  final int? chapterIndex;
  final int? pageNumber;
  final int? contentIndex;

  const ChapterLocator({
    this.chapterIndex,
    this.pageNumber,
    this.contentIndex,
  });

}

class ReaderChapter {
  final String title;
  final ChapterLocator locator;
  final int? index;
  final bool isSynthetic;

  const ReaderChapter({
    required this.title,
    required this.locator,
    this.index,
    this.isSynthetic = false,
  });
}

enum ReaderChapterNavigation {
  none,
  semantic,
  synthetic,
}

enum CapabilityLevel {
  none,
  limited,
  full,
}

class ReaderConfig {
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final double lineHeight;
  final PageTurnMode pageTurnMode;
  final PageAnimation pageAnimation;

  /// When true, engines render reading body text in Source Han Serif SC
  /// rather than Noto Sans SC.  Engines that do not control body font
  /// (e.g. PDF) may ignore this field.
  final bool useSerif;

  const ReaderConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.lineHeight,
    this.pageTurnMode = PageTurnMode.swipe,
    this.pageAnimation = PageAnimation.fade,
    this.useSerif = false,
  });
}

class ReaderCapabilities {
  final CapabilityLevel typography;
  final CapabilityLevel theme;
  final CapabilityLevel highlights;
  final CapabilityLevel annotations;
  final CapabilityLevel pageAnimation;
  final ReaderChapterNavigation chapterNavigation;

  const ReaderCapabilities({
    required this.typography,
    required this.theme,
    required this.highlights,
    required this.annotations,
    required this.pageAnimation,
    required this.chapterNavigation,
  });

  bool get supportsTypography => typography != CapabilityLevel.none;
  bool get supportsTheme => theme != CapabilityLevel.none;
  bool get supportsHighlights => highlights != CapabilityLevel.none;
  bool get supportsAnnotations => annotations != CapabilityLevel.none;
  bool get supportsPageAnimation => pageAnimation != CapabilityLevel.none;

  bool get supportsChapterNavigation =>
      chapterNavigation != ReaderChapterNavigation.none;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderCapabilities &&
        other.typography == typography &&
        other.theme == theme &&
        other.highlights == highlights &&
        other.annotations == annotations &&
        other.pageAnimation == pageAnimation &&
        other.chapterNavigation == chapterNavigation;
  }

  @override
  int get hashCode => Object.hash(
        typography,
        theme,
        highlights,
        annotations,
        pageAnimation,
        chapterNavigation,
      );
}

abstract class TextReaderCapability {
  void configureInteractions({
    ReaderTextHighlightCallback? onTextHighlighted,
    ReaderHighlightTapCallback? onHighlightTapped,
    ReaderContentTapCallback? onContentTap,
  });

  void setHighlights(List<Highlight> highlights);

  String? getParagraphText(int paragraphIndex);
}

abstract class TextExtractionCapability {
  Future<String?> getSnippet();

  Future<String?> getTextAtPosition(ReadingPosition position);
}

abstract class PageMetricsCapability {
  int getPageCount();

  int getCurrentPageIndex();
}

extension ReaderEngineCapabilityAccess on ReaderEngine {
  TextReaderCapability? get textCapability =>
      this is TextReaderCapability ? this as TextReaderCapability : null;

  TextExtractionCapability? get textExtractionCapability =>
      this is TextExtractionCapability ? this as TextExtractionCapability : null;

  PageMetricsCapability? get pageMetricsCapability =>
      this is PageMetricsCapability ? this as PageMetricsCapability : null;
}

abstract class ReaderEngine {
  ReaderCapabilities get capabilities;

  /// Initializes the engine (loads file, parses content, etc).
  /// Should throw specific exceptions on failure.
  Future<void> initialize();

  /// Builds the widget that renders the book content.
  Widget buildReader(BuildContext context);

  /// Navigates to a specific position.
  Future<void> goToPosition(ReadingPosition position);

  /// Returns the current reading position.
  ReadingPosition? getCurrentPosition();

  /// Updates the reader configuration (theme, font, etc).
  void setConfig(ReaderConfig config);

  /// Returns current progress (0.0 to 1.0).
  double? getProgress();

  /// Seeks to a specific progress (0.0 to 1.0).
  Future<void> seekToProgress(double progress);

  /// Returns list of chapters/table of contents.
  /// Returns empty list if chapters cannot be extracted.
  Future<List<ReaderChapter>> getChapters();

  /// Navigates to a chapter described by a typed locator.
  Future<void> goToChapter(ChapterLocator locator);

  /// Navigates to the next page/screen.
  Future<void> nextPage();

  /// Navigates to the previous page/screen.
  Future<void> previousPage();

  /// Whether the engine provides its own bottom information bar.
  bool get hasBottomBar;

  /// Called when the reader is disposed.
  void dispose();
}
