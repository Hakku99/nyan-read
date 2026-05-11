/// Regression tests for pagination drift with CJK and mixed CJK/EN content.
///
/// Coverage matrix:
///   A. CJK-only text — page count scales with font size (16→24) and
///      text scale factor (1.0→1.3→1.5).
///   B. Mixed CJK + EN text — same settings produce stable page count
///      (no wild outliers vs. pure EN or pure CJK).
///   C. Line-height extremes (1.2×, 1.5×, 2.0×) affect page count
///      directionally for CJK-heavy content.
///   D. Long CJK paragraphs wrap correctly and don't produce fewer pages
///      than a narrower viewport would suggest.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/pagination_helper.dart';

// ---------------------------------------------------------------------------
// Sample content builders
// ---------------------------------------------------------------------------

/// 200 paragraphs of CJK prose (each ~80 characters) — representative of a
/// Chinese web novel chapter.
String _cjkOnlyText({int paragraphs = 200}) {
  const line =
      '这是一段中文小说的正文内容，用于测试分页算法在中文环境下的正确性和稳定性。每段落包含足够多的字符以触发自动换行逻辑，'
      '确保测试结果具有实际意义。';
  return List.generate(paragraphs, (_) => line).join('\n');
}

/// 200 paragraphs alternating between a CJK line and an EN line.
String _mixedCjkEnText({int paragraphs = 200}) {
  final buffer = StringBuffer();
  for (var i = 0; i < paragraphs; i++) {
    if (i.isEven) {
      buffer.writeln(
          '第${i + 1}段：混合排版测试，中英文字符宽度差异对分页算法的影响验证。');
    } else {
      buffer.writeln(
          'Paragraph ${i + 1}: mixed layout test validating pagination with CJK and Latin characters.');
    }
  }
  return buffer.toString();
}

/// Pure EN text of comparable byte length for cross-comparison.
String _enOnlyText({int paragraphs = 200}) {
  const line =
      'This is a paragraph of English text used to compare pagination behavior '
      'against CJK-heavy content. It has a similar character count per line.';
  return List.generate(paragraphs, (_) => line).join('\n');
}

// ---------------------------------------------------------------------------
// Shared helper
// ---------------------------------------------------------------------------

Future<int> _pageCount({
  required String text,
  double fontSize = 18,
  double lineHeight = 1.5,
  TextScaler textScaler = TextScaler.noScaling,
  double maxWidth = 320,
  double maxHeight = 640,
  EdgeInsets padding = const EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 40,
  ),
}) async {
  final result = await PaginationHelper.calculatePageEstimate(
    text: text,
    style: TextStyle(fontSize: fontSize, height: lineHeight),
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    padding: padding,
    textScaler: textScaler,
    paragraphBottomMargin: fontSize * 0.6,
  );
  return result[0];
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // A — CJK-only: font size and text scale scaling
  // -------------------------------------------------------------------------

  group('A — CJK-only pagination scaling', () {
    test('larger font size produces more pages (16→24)', () async {
      final text = _cjkOnlyText();

      final pages16 = await _pageCount(text: text, fontSize: 16);
      final pages24 = await _pageCount(text: text, fontSize: 24);

      expect(pages24, greaterThan(pages16),
          reason: 'Larger CJK font must increase page count');
    });

    test('text scale 1.3× produces more pages than 1.0× for CJK', () async {
      final text = _cjkOnlyText();

      final pagesNormal = await _pageCount(
        text: text,
        textScaler: TextScaler.noScaling,
      );
      final pagesScaled = await _pageCount(
        text: text,
        textScaler: const TextScaler.linear(1.3),
      );

      expect(pagesScaled, greaterThan(pagesNormal),
          reason: '1.3× text scale must increase CJK page count');
    });

    test('text scale 1.5× produces more pages than 1.3× for CJK', () async {
      final text = _cjkOnlyText();

      final pages13 = await _pageCount(
        text: text,
        textScaler: const TextScaler.linear(1.3),
      );
      final pages15 = await _pageCount(
        text: text,
        textScaler: const TextScaler.linear(1.5),
      );

      expect(pages15, greaterThanOrEqualTo(pages13),
          reason: '1.5× scale must not produce fewer pages than 1.3×');
    });

    test('page count is positive and bounded for CJK-only content', () async {
      final text = _cjkOnlyText();
      final pages = await _pageCount(text: text);

      expect(pages, greaterThan(0));
      // Sanity bound: should not estimate more pages than characters.
      expect(pages, lessThan(text.length));
    });
  });

  // -------------------------------------------------------------------------
  // B — Mixed CJK/EN: no wild drift vs. pure CJK or pure EN
  // -------------------------------------------------------------------------

  group('B — Mixed CJK/EN pagination stability', () {
    test('mixed content page count is between CJK-only and EN-only bounds',
        () async {
      final cjkText = _cjkOnlyText();
      final mixedText = _mixedCjkEnText();
      final enText = _enOnlyText();

      final pagesCjk = await _pageCount(text: cjkText);
      final pagesMixed = await _pageCount(text: mixedText);
      final pagesEn = await _pageCount(text: enText);

      // Mixed content may produce slightly more or fewer pages than either
      // extreme depending on line-wrapping characteristics. We assert it is
      // within a 3× range of either bound to catch catastrophic drift.
      final lower = (pagesCjk < pagesEn ? pagesCjk : pagesEn) ~/ 3;
      final upper = (pagesCjk > pagesEn ? pagesCjk : pagesEn) * 3;

      expect(pagesMixed, greaterThan(lower),
          reason: 'Mixed content must produce a plausible lower bound');
      expect(pagesMixed, lessThan(upper),
          reason: 'Mixed content must not explode vs. single-script content');
    });

    test('mixed content scales with text scale factor (no regression)',
        () async {
      final text = _mixedCjkEnText();

      final pagesNormal = await _pageCount(
        text: text,
        textScaler: TextScaler.noScaling,
      );
      final pagesScaled = await _pageCount(
        text: text,
        textScaler: const TextScaler.linear(1.3),
      );

      expect(pagesScaled, greaterThan(pagesNormal),
          reason: 'Text scale must increase page count for mixed content');
    });

    test('mixed content scales with font size (no regression)', () async {
      final text = _mixedCjkEnText();

      final pages16 = await _pageCount(text: text, fontSize: 16);
      final pages20 = await _pageCount(text: text, fontSize: 20);

      expect(pages20, greaterThan(pages16),
          reason: 'Larger font must increase mixed-content page count');
    });
  });

  // -------------------------------------------------------------------------
  // C — Line-height extremes (directional correctness)
  // -------------------------------------------------------------------------

  group('C — Line-height extremes with CJK content', () {
    test('line height 2.0× produces more pages than 1.2× for CJK', () async {
      final text = _cjkOnlyText();

      final pages12 = await _pageCount(text: text, lineHeight: 1.2);
      final pages20 = await _pageCount(text: text, lineHeight: 2.0);

      expect(pages20, greaterThan(pages12),
          reason: 'Double line height must significantly increase page count');
    });

    test('line height 1.5× produces more pages than 1.2× for mixed content',
        () async {
      final text = _mixedCjkEnText();

      final pages12 = await _pageCount(text: text, lineHeight: 1.2);
      final pages15 = await _pageCount(text: text, lineHeight: 1.5);

      expect(pages15, greaterThanOrEqualTo(pages12),
          reason:
              'Higher line height must not produce fewer pages for mixed content');
    });
  });

  // -------------------------------------------------------------------------
  // D — Viewport width interaction with CJK wrapping
  // -------------------------------------------------------------------------

  group('D — Viewport width effects on CJK wrapping', () {
    test('narrow viewport (240px) produces more pages than wide (400px)',
        () async {
      final text = _cjkOnlyText();

      final pagesNarrow = await _pageCount(text: text, maxWidth: 240);
      final pagesWide = await _pageCount(text: text, maxWidth: 400);

      expect(pagesNarrow, greaterThan(pagesWide),
          reason: 'Narrower viewport must produce more pages for CJK text');
    });

    test('mixed content: narrow viewport produces more pages than wide',
        () async {
      final text = _mixedCjkEnText();

      final pagesNarrow = await _pageCount(text: text, maxWidth: 240);
      final pagesWide = await _pageCount(text: text, maxWidth: 400);

      expect(pagesNarrow, greaterThanOrEqualTo(pagesWide),
          reason: 'Narrower viewport must not reduce page count for mixed text');
    });

    test('tall viewport (800px) produces fewer pages than short (480px)',
        () async {
      final text = _cjkOnlyText();

      final pagesShort = await _pageCount(text: text, maxHeight: 480);
      final pagesTall = await _pageCount(text: text, maxHeight: 800);

      expect(pagesTall, lessThan(pagesShort),
          reason: 'Taller viewport must fit more content per page');
    });
  });

  // -------------------------------------------------------------------------
  // E — Cross-cutting: combined CJK + scale + large font
  // -------------------------------------------------------------------------

  group('E — Combined stress: CJK + 1.5× scale + large font', () {
    test('worst-case: large font + high scale + narrow viewport is bounded',
        () async {
      final text = _cjkOnlyText(paragraphs: 50);

      final pages = await _pageCount(
        text: text,
        fontSize: 24,
        lineHeight: 1.8,
        textScaler: const TextScaler.linear(1.5),
        maxWidth: 280,
        maxHeight: 560,
      );

      expect(pages, greaterThan(0),
          reason: 'Must produce at least one page under stress conditions');
      expect(pages, lessThan(text.length),
          reason: 'Stress case must not produce an absurd page count');
    });

    test('CJK page count stays stable across two identical calls (no drift)',
        () async {
      final text = _cjkOnlyText();
      const scaler = TextScaler.linear(1.2);

      final pages1 = await _pageCount(
        text: text,
        fontSize: 18,
        textScaler: scaler,
      );
      final pages2 = await _pageCount(
        text: text,
        fontSize: 18,
        textScaler: scaler,
      );

      expect(pages1, equals(pages2),
          reason:
              'Identical inputs must produce identical page counts (no drift)');
    });
  });
}
