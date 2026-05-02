import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/pagination_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PaginationHelper calculates estimated pages', () async {
    final text = 'Hello World ' * 500; // Long text
    final style = const TextStyle(fontSize: 20);
    final maxWidth = 200.0;
    final maxHeight = 200.0; // Small page
    final padding = EdgeInsets.zero;

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

    // Roughly check if total pages * chars per page >= text length
    expect(totalPages * charsPerPage, greaterThanOrEqualTo(text.length));

    debugPrint(
      'Estimated Total Pages: $totalPages, Chars Per Page: $charsPerPage',
    );
  });
}
