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
}
