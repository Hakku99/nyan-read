import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/models/highlight.dart';
import '../../../core/services/reader_preferences_service.dart';

class ReadingPosition {
  final int? paragraphIndex;
  final int? pageNumber;
  final String? cfi;
  final int? chapterIndex;

  const ReadingPosition({
    this.paragraphIndex,
    this.pageNumber,
    this.cfi,
    this.chapterIndex,
  });

  factory ReadingPosition.fromJson(String type, String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return ReadingPosition(
      paragraphIndex: type == 'txt'
          ? (map['paragraphIndex'] as int? ?? 0)
          : map['paragraphIndex'] as int?,
      pageNumber: type == 'pdf'
          ? (map['pageNumber'] as int? ?? 1)
          : map['pageNumber'] as int?,
      cfi: map['cfi'] as String?,
      chapterIndex: map['chapterIndex'] as int?,
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
    if (pageNumber != null) {
      map['pageNumber'] = pageNumber;
    }
    if (cfi != null) {
      map['cfi'] = cfi;
    }
    if (chapterIndex != null) {
      map['chapterIndex'] = chapterIndex;
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
typedef ReaderContentTapCallback = void Function(Offset position);

class ChapterLocator {
  final int? chapterIndex;
  final int? pageNumber;
  final int? contentIndex;

  const ChapterLocator({
    this.chapterIndex,
    this.pageNumber,
    this.contentIndex,
  });

  factory ChapterLocator.fromChapterData(Map<String, dynamic> chapterData) {
    return ChapterLocator(
      chapterIndex: chapterData['paragraphIndex'] as int?,
      pageNumber: chapterData['pageNumber'] as int?,
      contentIndex: chapterData['startIndex'] as int?,
    );
  }
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

class ReaderConfig {
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final double lineHeight;
  final PageTurnMode pageTurnMode;
  final PageAnimation pageAnimation;

  const ReaderConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.lineHeight,
    this.pageTurnMode = PageTurnMode.swipe,
    this.pageAnimation = PageAnimation.fade,
  });
}

class ReaderCapabilities {
  final bool supportsTypography;
  final bool supportsTheme;
  final bool supportsHighlights;
  final bool supportsAnnotations;
  final bool supportsPageAnimation;
  final bool supportsSemanticChapters;

  const ReaderCapabilities({
    required this.supportsTypography,
    required this.supportsTheme,
    required this.supportsHighlights,
    required this.supportsAnnotations,
    required this.supportsPageAnimation,
    required this.supportsSemanticChapters,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderCapabilities &&
        other.supportsTypography == supportsTypography &&
        other.supportsTheme == supportsTheme &&
        other.supportsHighlights == supportsHighlights &&
        other.supportsAnnotations == supportsAnnotations &&
        other.supportsPageAnimation == supportsPageAnimation &&
        other.supportsSemanticChapters == supportsSemanticChapters;
  }

  @override
  int get hashCode => Object.hash(
        supportsTypography,
        supportsTheme,
        supportsHighlights,
        supportsAnnotations,
        supportsPageAnimation,
        supportsSemanticChapters,
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
  Future<void> goToChapter(ChapterLocator locator) async {}

  /// Navigates to the next page/screen.
  Future<void> nextPage();

  /// Navigates to the previous page/screen.
  Future<void> previousPage();

  /// Whether the engine provides its own bottom information bar.
  bool get hasBottomBar;

  /// Called when the reader is disposed.
  void dispose();
}
