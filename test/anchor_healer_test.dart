import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/highlight.dart';
import 'package:nyan_read/core/utils/anchor_healer.dart';

void main() {
  test('heals highlight offset after a small text shift', () {
    const originalText = 'Alpha beta gamma shared marker DELTA epsilon zeta.';
    const selectedText = 'DELTA';
    final start = originalText.indexOf(selectedText);
    final end = start + selectedText.length;

    final highlight = Highlight(
      id: 'h1',
      bookId: 'book-1',
      paragraphIndex: 3,
      startOffset: start,
      endOffset: end,
      selectedText: selectedText,
      colorCode: HighlightColors.yellow,
      createdAt: DateTime(2024, 1, 1),
      preContext: originalText.substring((start - 15).clamp(0, start), start),
      postContext: originalText.substring(
        end,
        (end + 15).clamp(end, originalText.length),
      ),
    );

    const modifiedText =
        'Alpha beta gamma shared marker tiny DELTA epsilon zeta.';

    final healedOffset = AnchorHealer.findHealedOffset(
      modifiedText,
      highlight.preContext,
      highlight.selectedText,
      highlight.postContext,
    );

    expect(healedOffset, modifiedText.indexOf(selectedText));
  });

  test('uses surrounding context to recover the correct duplicate match', () {
    const originalText =
        'Intro DELTA wrong ending. Shared anchor before DELTA right ending.';
    const selectedText = 'DELTA';
    final start = originalText.lastIndexOf(selectedText);
    final end = start + selectedText.length;

    final highlight = Highlight(
      id: 'h2',
      bookId: 'book-1',
      paragraphIndex: 7,
      startOffset: start,
      endOffset: end,
      selectedText: selectedText,
      colorCode: HighlightColors.green,
      createdAt: DateTime(2024, 1, 1),
      preContext: originalText.substring((start - 15).clamp(0, start), start),
      postContext: originalText.substring(
        end,
        (end + 15).clamp(end, originalText.length),
      ),
    );

    const modifiedText =
        'Intro DELTA wrong ending. Shared anchor before tiny DELTA right ending.';

    final healedOffset = AnchorHealer.findHealedOffset(
      modifiedText,
      highlight.preContext,
      highlight.selectedText,
      highlight.postContext,
    );

    expect(healedOffset, modifiedText.lastIndexOf(selectedText));
  });

  group('findHealedInWindow', () {
    const pre = 'the quick brown ';
    const exact = 'FOX';
    const post = ' jumps over';
    const text = 'the quick brown FOX jumps over the lazy dog';

    // 7-slot window centred on index 3 (the stored paragraph).
    List<String?> window(Map<int, String?> slots) =>
        List<String?>.generate(7, (i) => slots[i]);

    test('same paragraph wins (delta 0)', () {
      final result = AnchorHealer.findHealedInWindow(
          window({3: text}), pre, exact, post);
      expect(result, (delta: 0, offset: text.indexOf(exact)));
    });

    test('finds text shifted forward by an inserted slot', () {
      // Stored index 3 is now an image slot (null); the text moved to 4.
      final result = AnchorHealer.findHealedInWindow(
          window({3: null, 4: text}), pre, exact, post);
      expect(result, (delta: 1, offset: text.indexOf(exact)));
    });

    test('finds text shifted backward and further away', () {
      expect(
          AnchorHealer.findHealedInWindow(window({1: text}), pre, exact, post),
          (delta: -2, offset: text.indexOf(exact)));
      expect(
          AnchorHealer.findHealedInWindow(window({6: text}), pre, exact, post),
          (delta: 3, offset: text.indexOf(exact)));
    });

    test('prefers the nearest neighbour, forward before backward', () {
      final result = AnchorHealer.findHealedInWindow(
          window({2: text, 4: text}), pre, exact, post);
      expect(result?.delta, 1);
    });

    test('neighbours need the full signature: exact-only is not enough', () {
      const lookalike = 'a FOX appeared somewhere else entirely';
      expect(
          AnchorHealer.findHealedInWindow(
              window({4: lookalike}), pre, exact, post),
          isNull);
    });

    test('a strict neighbour hit beats a lenient hit in the stored paragraph',
        () {
      // The stored paragraph merely contains the same word once; the real
      // anchor moved one paragraph forward.
      const decoy = 'He said hello to them';
      const real = 'I said no more.';
      final result = AnchorHealer.findHealedInWindow(
          window({3: decoy, 4: real}), 'I ', 'said', ' no more.');
      expect(result, (delta: 1, offset: real.indexOf('said')));
    });

    test('lenient same-paragraph healing still works when pre/post drifted',
        () {
      // No full signature anywhere, but the word is unique in the stored
      // paragraph (the original decode-shift scenario).
      const edited = 'the quick brown FOX leaps over the lazy dog';
      final result = AnchorHealer.findHealedInWindow(
          window({3: edited}), pre, exact, post);
      expect(result, (delta: 0, offset: edited.indexOf(exact)));
    });

    test('context-free rows heal only when the text is unique in the window',
        () {
      expect(
          AnchorHealer.findHealedInWindow(
              window({3: 'unrelated', 5: 'a lone FOX here'}), '', exact, ''),
          (delta: 2, offset: 'a lone FOX here'.indexOf(exact)));
      // Two hits (even in one paragraph) are ambiguous.
      expect(
          AnchorHealer.findHealedInWindow(
              window({3: 'FOX and FOX'}), '', exact, ''),
          isNull);
      expect(
          AnchorHealer.findHealedInWindow(
              window({2: 'a FOX', 4: 'another FOX'}), '', exact, ''),
          isNull);
      expect(
          AnchorHealer.findHealedInWindow(window({3: 'nothing'}), '', exact, ''),
          isNull);
    });

    test('the window edge is inclusive', () {
      // 41-slot window (+-20), like ContentMetaManager uses.
      List<String?> wide(int slot) =>
          List<String?>.generate(41, (i) => i == slot ? text : null);
      expect(AnchorHealer.findHealedInWindow(wide(40), pre, exact, post)?.delta,
          20);
      expect(AnchorHealer.findHealedInWindow(wide(0), pre, exact, post)?.delta,
          -20);
    });

    test('returns null when nothing in the window matches', () {
      expect(
          AnchorHealer.findHealedInWindow(
              window({3: 'unrelated', 5: 'also unrelated'}), pre, exact, post),
          isNull);
    });
  });
}
