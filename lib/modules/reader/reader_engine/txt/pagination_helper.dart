import 'dart:async';
import 'package:flutter/material.dart';

class PaginationHelper {
  /// Calculates estimated total pages based on a sample layout.
  /// Returns [totalPages, averageCharactersPerPage].
  ///
  /// [text] may be either the full book text or a small sample (first few kB).
  /// Pass [totalTextLength] when the caller already knows the book length so
  /// the estimate extrapolates correctly rather than treating the sample as
  /// the full book.
  ///
  /// [textScaler] applies the device accessibility text-scale factor to the
  /// TextPainter measurements so the estimate reflects the actual rendered
  /// line heights rather than the nominal [style.fontSize].
  ///
  /// [paragraphBottomMargin] models the inter-paragraph gap added by the
  /// ScrollablePositionedList layout (`fontSize * 0.6` per item).  Omitting
  /// this causes the estimator to fit more paragraphs on a "page" than the
  /// real renderer does, under-counting total pages.
  static Future<List<int>> calculatePageEstimate({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required EdgeInsets padding,
    TextScaler? textScaler,
    double? paragraphBottomMargin,
    int? totalTextLength,
  }) async {
    final int textLength = totalTextLength ?? text.length;
    if (textLength == 0) return [1, 1];

    final double availableWidth = maxWidth - padding.horizontal;
    final double availableHeight = maxHeight - padding.vertical;

    if (availableWidth <= 0 || availableHeight <= 0) {
      return [1, 1];
    }

    final TextScaler scaler = textScaler ?? TextScaler.noScaling;
    final double bottomMargin = paragraphBottomMargin ?? 0.0;

    // §3.4: callers invoke this from LayoutBuilder during build, and a Dart
    // async function runs synchronously up to its first await — without this
    // yield the TextPainter.layout below would execute inside the build
    // frame. Deferring to the event queue moves the ~ms layout after the
    // frame; the caller re-validates its layout key when we return, so the
    // result cannot be applied stale.
    await Future<void>.delayed(Duration.zero);

    // Sample size: 3000 chars or full text if smaller.
    int sampleSize = 3000;
    if (sampleSize > text.length) sampleSize = text.length;
    final String sampleText = text.substring(0, sampleSize);

    // Layout the sample as a single continuous block.  This preserves the
    // original per-character resolution of getPositionForOffset (which gives
    // a monotonically-correct answer for any change in fontSize, lineHeight,
    // viewport height, or textScaler), while [textScaler] is now forwarded so
    // the measurement reflects actual accessibility-scaled metrics.
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: sampleText, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    );
    try {
      textPainter.layout(maxWidth: availableWidth);

      // Model inter-paragraph margins:
      // The list renderer inserts [bottomMargin] after every paragraph.  We
      // reduce the "effective" available height by the fraction that margins
      // consume, so the position lookup accounts for that overhead.
      // When bottomMargin == 0 this is a no-op and matches the original
      // algorithm exactly.
      double effectiveHeight = availableHeight;
      if (bottomMargin > 0 && textPainter.height > 0) {
        final int paragraphsInSample =
            '\n'.allMatches(sampleText).length + 1;
        final double totalMarginInSample = paragraphsInSample * bottomMargin;
        // Fraction of sample height consumed by text (vs. margins).
        final double textFraction =
            textPainter.height / (textPainter.height + totalMarginInSample);
        effectiveHeight = (availableHeight * textFraction).clamp(
          1.0,
          availableHeight,
        );
      }

      final position =
          textPainter.getPositionForOffset(Offset(0, effectiveHeight));
      int charsPerPage = position.offset;

      if (charsPerPage <= 0) charsPerPage = 1;

      int totalPages = (textLength / charsPerPage).ceil();
      if (totalPages < 1) totalPages = 1;

      return [totalPages, charsPerPage];
    } finally {
      // TextPainter owns native Paragraph resources; leaking one per
      // pagination pass adds up over a long reading session.
      textPainter.dispose();
    }
  }
}
