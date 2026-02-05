import 'package:flutter/material.dart';

abstract class ReadingPosition {
  String toJson();
}

class ReaderConfig {
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final double lineHeight;

  const ReaderConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.lineHeight,
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

  /// Called when the reader is disposed.
  void dispose();
}
