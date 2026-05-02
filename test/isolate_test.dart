import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Isolate.run completes pure Dart work', () async {
    final result = await Isolate.run(() {
      return 'Hello World'.length == 11;
    });
    expect(result, isTrue);
  });

  test('TextPainter lays out on root isolate with binding', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final painter = TextPainter(
      text: const TextSpan(
        text: 'Hello World',
        style: TextStyle(fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: 100);
    expect(painter.height, greaterThan(0));
  });
}
