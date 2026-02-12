import 'dart:async';
import 'package:flutter/material.dart';

class PaginationHelper {
  /// Calculates estimated total pages based on a sample layout.
  /// Returns a tuple of (totalPages, averageCharactersPerPage).
  static Future<List<int>> calculatePageEstimate({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required EdgeInsets padding,
  }) async {
    final int textLength = text.length;
    if (textLength == 0) return [1, 1];

    final double availableWidth = maxWidth - padding.horizontal;
    final double availableHeight = maxHeight - padding.vertical;

    if (availableWidth <= 0 || availableHeight <= 0) {
      return [1, 1];
    }

    // Sample size: 3000 chars or full text if smaller
    // This is usually enough to fill one or two screens to get a good average
    int sampleSize = 3000;
    if (sampleSize > textLength) sampleSize = textLength;

    final String sampleText = text.substring(0, sampleSize);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: sampleText, style: style),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: availableWidth);

    // Calculate how much text fits in one page height
    // We find the position at the bottom-left of the available space
    final offsetToCheck = Offset(0, availableHeight);
    final position = textPainter.getPositionForOffset(offsetToCheck);

    // Get the character offset at that position
    int charsPerPage = position.offset;

    // Safety: if for some reason we get 0 (e.g. font too big for screen), default to 1
    if (charsPerPage <= 0) charsPerPage = 1;

    // Estimate total pages
    int totalPages = (textLength / charsPerPage).ceil();
    if (totalPages < 1) totalPages = 1;

    // Return [totalPages, charsPerPage]
    // We keep the return type List<int> for simplicity in signature,
    // where index 0 is totalPages, index 1 is charsPerPage.
    return [totalPages, charsPerPage];
  }
}
