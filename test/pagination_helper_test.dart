import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/pagination_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PaginationHelper calculates offsets', () async {
    final text = 'Hello World ' * 500; // Long text
    final style = const TextStyle(fontSize: 20);
    final maxWidth = 200.0;
    final maxHeight = 200.0; // Small page
    final padding = EdgeInsets.zero;

    final offsets = await PaginationHelper.calculatePageOffsets(
      text: text,
      style: style,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      padding: padding,
    );

    expect(offsets, isNotEmpty);
    expect(offsets[0], 0);
    if (offsets.length > 1) {
      expect(offsets[1], greaterThan(0));
      expect(offsets[1], lessThan(text.length));
    }

    print('Offsets: $offsets');
  });
}
