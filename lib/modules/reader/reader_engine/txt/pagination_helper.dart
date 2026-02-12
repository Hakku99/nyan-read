import 'dart:async';
import 'package:flutter/material.dart';

class PaginationHelper {
  /// Calculates page offsets for the given text and layout constraints.
  /// returns a List of int, where each int is the start index of a page.
  ///
  /// Uses time-slicing to avoid blocking the UI thread.
  static Future<List<int>> calculatePageOffsets({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required EdgeInsets padding,
  }) async {
    final List<int> pageOffsets = [];
    int currentOffset = 0;
    final int textLength = text.length;

    // Safety check
    if (textLength == 0) return [0];

    final double availableWidth = maxWidth - padding.horizontal;
    final double availableHeight = maxHeight - padding.vertical;

    if (availableWidth <= 0 || availableHeight <= 0) {
      return [0];
    }

    // Create a TextPainter
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Stopwatch to track execution time for time-slicing
    final stopwatch = Stopwatch()..start();

    while (currentOffset < textLength) {
      pageOffsets.add(currentOffset);

      // Time-slicing: Yield to event loop if we've been running too long (e.g. > 12ms)
      // This keeps the UI responsive (60fps is ~16ms per frame)
      if (stopwatch.elapsedMilliseconds > 12) {
        await Future.delayed(Duration.zero);
        stopwatch.reset();
      }

      // Take a chunk that is likely to cover the page
      int chunkEnd =
          currentOffset + 3000; // 3000 chars should cover most screens
      if (chunkEnd > textLength) chunkEnd = textLength;

      String chunk = text.substring(currentOffset, chunkEnd);

      textPainter.text = TextSpan(text: chunk, style: style);
      textPainter.layout(maxWidth: availableWidth);

      // Find the character at the bottom-left of the available space
      // We look slightly inside the bound to catch the line just within the limit
      // or exactly at the limit.
      final offsetToCheck = Offset(0, availableHeight);
      final position = textPainter.getPositionForOffset(offsetToCheck);

      // Get the line metrics/boundary for this position
      final lineRange = textPainter.getLineBoundary(position);

      // Check if this line is fully visible
      // We get the caret visual offset at the start of this line
      final caretOffset = textPainter.getOffsetForCaret(
          TextPosition(offset: lineRange.start), Rect.zero);
      final lineHeight = textPainter.getFullHeightForCaret(
          TextPosition(offset: lineRange.start), Rect.zero);

      final lineTop = caretOffset.dy;
      final lineBottom = lineTop + lineHeight;

      int splitIndex;

      // If the line at the bottom boundary extends beyond the available height,
      // we must push it to the next page.
      // We allow a tiny floating point error tolerance (0.5 pixel)
      if (lineBottom > availableHeight + 0.5) {
        // Line is clipped, start next page at this line's start
        splitIndex = lineRange.start;
      } else {
        // Line fits.
        // We want the split point to be the START of the NEXT line.
        splitIndex = lineRange.end;
      }

      // Edge Case: Logic Loop Protection
      // If splitIndex <= 0 (relative to chunk), we aren't advancing.
      // This happens if the first line is taller than the screen.
      if (splitIndex <= 0) {
        // Force advance to end of first line if possible, or at least 1 char
        final firstLineRange =
            textPainter.getLineBoundary(const TextPosition(offset: 0));
        if (firstLineRange.end > 0) {
          splitIndex = firstLineRange.end;
        } else {
          splitIndex = 1;
        }
      }

      // Absolute index update
      currentOffset += splitIndex;

      // Guard against infinite loop
      if (currentOffset == pageOffsets.last) {
        currentOffset++;
      }
    }

    stopwatch.stop();
    return pageOffsets;
  }
}
