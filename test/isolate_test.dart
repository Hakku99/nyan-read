import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TextPainter in Isolate', () async {
    final result = await Isolate.run(() {
      try {
        final painter = TextPainter(
          text: const TextSpan(
              text: 'Hello World', style: TextStyle(fontSize: 20)),
          textDirection: TextDirection.ltr,
        );
        painter.layout(maxWidth: 100);
        return painter.height > 0;
      } catch (e) {
        return false;
      }
    });
    expect(result, isTrue);
  });
}
