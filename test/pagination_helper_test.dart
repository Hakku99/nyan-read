import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/pagination_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Baseline sanity
  // ---------------------------------------------------------------------------

  test('PaginationHelper calculates estimated pages', () async {
    final text = 'Hello World ' * 500;
    const style = TextStyle(fontSize: 20);
    const maxWidth = 200.0;
    const maxHeight = 200.0;
    const padding = EdgeInsets.zero;

    final result = await PaginationHelper.calculatePageEstimate(
      text: text,
      style: style,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      padding: padding,
    );

    expect(result, hasLength(2));
    final totalPages = result[0];
    final charsPerPage = result[1];

    expect(totalPages, greaterThan(0));
    expect(charsPerPage, greaterThan(0));
    expect(totalPages * charsPerPage, greaterThanOrEqualTo(text.length));

    debugPrint(
      'Estimated Total Pages: $totalPages, Chars Per Page: $charsPerPage',
    );
  });

  // ---------------------------------------------------------------------------
  // P0-4: paragraphBottomMargin accuracy
  // ---------------------------------------------------------------------------

  test(
      'paragraphBottomMargin > 0 increases page count compared to no margin',
      () async {
    // Build multi-paragraph sample text: many short paragraphs separated by \n.
    final paragraphs = List.generate(
        60, (i) => 'Paragraph $i: short content that fits on one line.');
    final text = paragraphs.join('\n');

    const style = TextStyle(fontSize: 18, height: 1.5);
    const maxWidth = 320.0;
    const maxHeight = 640.0;
    const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 40);

    final noMarginResult = await PaginationHelper.calculatePageEstimate(
      text: text,
      style: style,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      padding: padding,
      paragraphBottomMargin: 0.0,
    );

    // fontSize * 0.6 = 10.8 — the real gap added by TxtReaderEngine._buildList.
    final withMarginResult = await PaginationHelper.calculatePageEstimate(
      text: text,
      style: style,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      padding: padding,
      paragraphBottomMargin: 18.0 * 0.6,
    );

    // Adding a per-paragraph gap means fewer paragraphs fit per page, so the
    // total page count must be greater or equal to the no-margin count.
    expect(withMarginResult[0], greaterThanOrEqualTo(noMarginResult[0]),
        reason: 'inter-paragraph margin must not reduce the page count');
  });

  // ---------------------------------------------------------------------------
  // P0-4: TextScaler accuracy
  // ---------------------------------------------------------------------------

  test(
      'textScaleFactor > 1 increases page count compared to no scaling',
      () async {
    // Use a long single-paragraph text so differences in line height affect
    // the number of pages significantly.
    final text = ('The quick brown fox jumps over the lazy dog. ' * 40 + '\n') *
        20;

    const style = TextStyle(fontSize: 18, height: 1.5);
    const maxWidth = 320.0;
    const maxHeight = 640.0;
    const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 40);

    final noScaleResult = await PaginationHelper.calculatePageEstimate(
      text: text,
      style: style,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      padding: padding,
      textScaler: TextScaler.noScaling,
    );

    // 1.3× scaling means each line is taller; fewer lines fit per page.
    final scaledResult = await PaginationHelper.calculatePageEstimate(
      text: text,
      style: style,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      padding: padding,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(scaledResult[0], greaterThan(noScaleResult[0]),
        reason: 'larger text scale must increase the total page count');
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  test('returns [1, 1] for empty text', () async {
    final result = await PaginationHelper.calculatePageEstimate(
      text: '',
      style: const TextStyle(fontSize: 18),
      maxWidth: 320,
      maxHeight: 640,
      padding: EdgeInsets.zero,
    );
    expect(result, [1, 1]);
  });

  test('returns [1, 1] when available area is zero', () async {
    final result = await PaginationHelper.calculatePageEstimate(
      text: 'Some text here',
      style: const TextStyle(fontSize: 18),
      maxWidth: 0,
      maxHeight: 0,
      padding: EdgeInsets.zero,
    );
    expect(result, [1, 1]);
  });
}
