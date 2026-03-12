import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores saved TXT reading position by paragraph index', () async {
    final tempDir = await Directory.systemTemp.createTemp('nyan_txt_restore');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final txtFile = File('${tempDir.path}/restore_sample.txt');
    final content = List<String>.generate(
      180,
      (index) =>
          'Paragraph $index ' * 10 +
          'with enough content to keep the list scrollable.',
    ).join('\n');
    await txtFile.writeAsString(content);

    final book = Book(
      id: 'txt-restore-book',
      title: 'TXT Restore Test',
      author: 'Tester',
      filePath: txtFile.path,
      format: 'txt',
    );

    final firstSession = TxtReaderEngine(book);
    addTearDown(firstSession.dispose);
    await firstSession.initialize();
    firstSession.setConfig(const ReaderConfig(
      backgroundColor: Colors.white,
      textColor: Colors.black,
      fontSize: 18,
      lineHeight: 1.5,
    ));

    await firstSession.goToPosition(TxtReadingPosition(paragraphIndex: 96));
    final savedPosition =
        firstSession.getCurrentPosition() as TxtReadingPosition;
    expect(savedPosition.paragraphIndex, 96);

    final serializedPosition = savedPosition.toJson();

    final secondSession = TxtReaderEngine(book);
    addTearDown(secondSession.dispose);
    await secondSession.initialize();
    secondSession.setConfig(const ReaderConfig(
      backgroundColor: Colors.white,
      textColor: Colors.black,
      fontSize: 18,
      lineHeight: 1.5,
    ));

    await secondSession.goToPosition(
      TxtReadingPosition.fromJson(serializedPosition),
    );
    final restoredPosition =
        secondSession.getCurrentPosition() as TxtReadingPosition;
    expect(restoredPosition.paragraphIndex, 96);
  });
}
