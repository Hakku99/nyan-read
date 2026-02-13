import 'package:flutter/material.dart';
import '../../../core/services/reader_preferences_service.dart';

abstract class ReadingPosition {
  String toJson();
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

abstract class ReaderEngine {
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

  /// Returns a snippet of text from the current position.
  Future<String?> getSnippet(); // New method

  /// Returns text at a specific position (used for backfilling).
  Future<String?> getTextAtPosition(ReadingPosition position);

  /// Returns list of chapters/table of contents.
  /// Returns empty list if chapters cannot be extracted.
  Future<List<dynamic>> getChapters();

  /// Navigates to the next page/screen.
  Future<void> nextPage();

  /// Navigates to the previous page/screen.
  Future<void> previousPage();

  /// Returns total calculated pages.
  int getPageCount();

  /// Returns current page index (0-based).
  int getCurrentPageIndex();

  /// Whether the engine provides its own bottom information bar.
  bool get hasBottomBar;

  /// Called when the reader is disposed.
  void dispose();
}
