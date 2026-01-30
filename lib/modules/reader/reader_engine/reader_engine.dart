import 'package:flutter/material.dart';

abstract class ReadingPosition {
  String toJson();
}

abstract class ReaderEngine {
  /// Builds the widget that renders the book content.
  Widget buildReader(BuildContext context);

  /// Navigates to a specific position.
  Future<void> goToPosition(ReadingPosition position);

  /// Returns the current reading position.
  ReadingPosition? getCurrentPosition();

  /// Called when the reader is disposed.
  void dispose();
}
