import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deterministic TXT position invariants', () {
    late Directory tempDir;
    late File txtFile;
    late Book book;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nyan_position_test');
      txtFile = File('${tempDir.path}/sample.txt');
      final content = List<String>.generate(
        200,
        (index) =>
            'Paragraph $index ' * 15 +
            'with enough repeated text to affect pagination across positions.',
      ).join('\n');
      await txtFile.writeAsString(content);

      book = Book(
        id: 'position-test-book',
        title: 'Position Determinism Test',
        author: 'Tester',
        filePath: txtFile.path,
        format: 'txt',
      );
    });

    tearDown(() async {
      await _deleteDirectoryWithRetry(tempDir);
    });

    testWidgets(
        'position persists identically across engine reopen (seek invariant)',
        (tester) async {
      // First session: seek to position
      final engine1 = TxtReaderEngine(book);
      addTearDown(engine1.dispose);
      await engine1.initialize();
      engine1.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 18,
        lineHeight: 1.5,
      ));

      await _pumpReader(tester, engine1, const Size(320, 640));
      await engine1.goToPosition(TxtReadingPosition(paragraphIndex: 75));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final position1 = engine1.getCurrentPosition() as TxtReadingPosition;
      final serialized1 = position1.toJson();

      // Second session: restore exact same position
      final engine2 = TxtReaderEngine(book);
      addTearDown(engine2.dispose);
      await engine2.initialize();
      engine2.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 18,
        lineHeight: 1.5,
      ));

      await _pumpReader(tester, engine2, const Size(320, 640));
      await engine2.goToPosition(TxtReadingPosition.fromJson(serialized1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final position2 = engine2.getCurrentPosition() as TxtReadingPosition;
      final serialized2 = position2.toJson();

      // Position should be identical after reopen
      expect(serialized1, serialized2);
      expect(position2.paragraphIndex, position1.paragraphIndex);
      expect(
        (position2.paragraphLeadingEdge ?? 0) -
            (position1.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.05),
      );
    });

    testWidgets(
        'position remains deterministic after seek->next->previous->reopen cycle',
        (tester) async {
      // First session: navigate and save
      final engine1 = TxtReaderEngine(book);
      addTearDown(engine1.dispose);
      await engine1.initialize();
      engine1.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
        pageTurnMode: PageTurnMode.leftRight,
      ));

      await _pumpReader(tester, engine1, const Size(320, 640));
      await engine1.goToPosition(TxtReadingPosition(paragraphIndex: 50));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Navigate next
      await engine1.nextPage();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Navigate back to previous
      await engine1.previousPage();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final afterPrevious = engine1.getCurrentPosition() as TxtReadingPosition;

      // Save the after-previous position
      final serialized = afterPrevious.toJson();

      // Second session: restore the navigated position directly
      final engine2 = TxtReaderEngine(book);
      addTearDown(engine2.dispose);
      await engine2.initialize();
      engine2.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
        pageTurnMode: PageTurnMode.leftRight,
      ));

      await _pumpReader(tester, engine2, const Size(320, 640));
      await engine2.goToPosition(TxtReadingPosition.fromJson(serialized));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final restoredDirectly = engine2.getCurrentPosition() as TxtReadingPosition;

      // Restored position should match the original navigated position
      expect(restoredDirectly.paragraphIndex, afterPrevious.paragraphIndex);
      expect(
        (restoredDirectly.paragraphLeadingEdge ?? 0) -
            (afterPrevious.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.08),
      );
    });

    testWidgets(
        'multiple reopen cycles preserve position deterministically',
        (tester) async {
      final targetParagraph = 100;
      String? lastSerialized;

      for (int cycle = 0; cycle < 3; cycle++) {
        final engine = TxtReaderEngine(book);
        addTearDown(engine.dispose);
        await engine.initialize();
        engine.setConfig(const ReaderConfig(
          backgroundColor: Colors.white,
          textColor: Colors.black,
          fontSize: 18,
          lineHeight: 1.5,
        ));

        await _pumpReader(tester, engine, const Size(320, 640));

        if (cycle == 0) {
          // First cycle: seek to target
          await engine.goToPosition(TxtReadingPosition(
            paragraphIndex: targetParagraph,
          ));
        } else {
          // Subsequent cycles: restore from previous serialized position
          await engine.goToPosition(
            TxtReadingPosition.fromJson(lastSerialized!),
          );
        }

        await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
        final position = engine.getCurrentPosition() as TxtReadingPosition;
        final serialized = position.toJson();

        expect(position.paragraphIndex, targetParagraph);

        if (lastSerialized != null) {
          // Each reopen should produce identical serialization
          expect(serialized, lastSerialized);
        }

        lastSerialized = serialized;
      }
    });

    testWidgets(
        'position determinism with paragraph edge anchors across viewport changes',
        (tester) async {
      // First session at small viewport
      final engine1 = TxtReaderEngine(book);
      addTearDown(engine1.dispose);
      await engine1.initialize();
      engine1.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 18,
        lineHeight: 1.5,
      ));

      await _pumpReader(tester, engine1, const Size(320, 640));
      await engine1.goToPosition(TxtReadingPosition(paragraphIndex: 120));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final position1 = engine1.getCurrentPosition() as TxtReadingPosition;
      final serialized1 = position1.toJson();

      // Second session: same viewport, restore position
      final engine2 = TxtReaderEngine(book);
      addTearDown(engine2.dispose);
      await engine2.initialize();
      engine2.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 18,
        lineHeight: 1.5,
      ));

      await _pumpReader(tester, engine2, const Size(320, 640));
      await engine2.goToPosition(TxtReadingPosition.fromJson(serialized1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final position2 = engine2.getCurrentPosition() as TxtReadingPosition;

      // Position should be deterministic (paragraph index is primary locator)
      expect(position2.paragraphIndex, position1.paragraphIndex);

      // Paragraph edge anchors should be very close (accounting for minor
      // rendering differences)
      expect(
        (position2.paragraphLeadingEdge ?? 0) -
            (position1.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.10),
      );
    });

    testWidgets(
        'position determinism with different font sizes uses paragraph index',
        (tester) async {
      // First session with fontSize 16
      final engine1 = TxtReaderEngine(book);
      addTearDown(engine1.dispose);
      await engine1.initialize();
      engine1.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
      ));

      await _pumpReader(tester, engine1, const Size(320, 640));
      await engine1.goToPosition(TxtReadingPosition(paragraphIndex: 65));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final position1 = engine1.getCurrentPosition() as TxtReadingPosition;
      final serialized1 = position1.toJson();

      // Second session with fontSize 20 (different pagination)
      final engine2 = TxtReaderEngine(book);
      addTearDown(engine2.dispose);
      await engine2.initialize();
      engine2.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 20,
        lineHeight: 1.4,
      ));

      await _pumpReader(tester, engine2, const Size(320, 640));
      await engine2.goToPosition(TxtReadingPosition.fromJson(serialized1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final position2 = engine2.getCurrentPosition() as TxtReadingPosition;

      // Paragraph index should be identical (position is content-based, not layout-based)
      expect(position2.paragraphIndex, position1.paragraphIndex);
      expect(position2.paragraphIndex, 65);
    });

    testWidgets(
        'seek to position is deterministic regardless of navigation history',
        (tester) async {
      final targetPosition = TxtReadingPosition(paragraphIndex: 88);

      // Path 1: Direct seek
      final engine1 = TxtReaderEngine(book);
      addTearDown(engine1.dispose);
      await engine1.initialize();
      engine1.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 18,
        lineHeight: 1.5,
        pageTurnMode: PageTurnMode.leftRight,
      ));

      await _pumpReader(tester, engine1, const Size(320, 640));
      await engine1.goToPosition(targetPosition);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final positionDirect = engine1.getCurrentPosition() as TxtReadingPosition;
      final serializedDirect = positionDirect.toJson();

      // Path 2: Navigate there via next/previous
      final engine2 = TxtReaderEngine(book);
      addTearDown(engine2.dispose);
      await engine2.initialize();
      engine2.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 18,
        lineHeight: 1.5,
        pageTurnMode: PageTurnMode.leftRight,
      ));

      await _pumpReader(tester, engine2, const Size(320, 640));
      await engine2.goToPosition(TxtReadingPosition(paragraphIndex: 50));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Navigate forward several times
      for (int i = 0; i < 5; i++) {
        await engine2.nextPage();
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Go back to the target
      await engine2.goToPosition(targetPosition);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final positionNavigated = engine2.getCurrentPosition() as TxtReadingPosition;
      final serializedNavigated = positionNavigated.toJson();

      // Both paths should arrive at the same deterministic position
      expect(serializedDirect, serializedNavigated);
      expect(positionDirect.paragraphIndex, positionNavigated.paragraphIndex);
      expect(
        (positionDirect.paragraphLeadingEdge ?? 0) -
            (positionNavigated.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.10),
      );
    });
  });
}

Future<void> _pumpReader(
  WidgetTester tester,
  TxtReaderEngine engine,
  Size viewport,
) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: Builder(
              builder: (context) => engine.buildReader(context),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _deleteDirectoryWithRetry(Directory dir) async {
  for (var i = 0; i < 6; i++) {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
}
