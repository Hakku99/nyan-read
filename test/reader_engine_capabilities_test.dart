import 'package:flutter_test/flutter_test.dart';

import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/pdf/pdf_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

Book _buildBook(String format) => Book(
      id: '$format-book',
      title: '$format book',
      author: 'tester',
      filePath: '/tmp/$format',
      format: format,
    );

void main() {
  test('TXT engine declares full text-reader capabilities', () {
    final engine = TxtReaderEngine(_buildBook('txt'));

    expect(
      engine.capabilities,
      const ReaderCapabilities(
        typography: CapabilityLevel.full,
        theme: CapabilityLevel.full,
        highlights: CapabilityLevel.full,
        annotations: CapabilityLevel.full,
        pageAnimation: CapabilityLevel.none,
        chapterNavigation: ReaderChapterNavigation.semantic,
      ),
    );
  });

  test('EPUB engine declares only supported capabilities', () {
    final engine = EpubReaderEngine(_buildBook('epub'));

    expect(
      engine.capabilities,
      const ReaderCapabilities(
        typography: CapabilityLevel.none,
        theme: CapabilityLevel.none,
        highlights: CapabilityLevel.none,
        annotations: CapabilityLevel.none,
        pageAnimation: CapabilityLevel.none,
        chapterNavigation: ReaderChapterNavigation.semantic,
      ),
    );
  });

  test('PDF engine declares only supported capabilities', () {
    final engine = PdfReaderEngine(_buildBook('pdf'));

    expect(
      engine.capabilities,
      const ReaderCapabilities(
        typography: CapabilityLevel.none,
        theme: CapabilityLevel.none,
        highlights: CapabilityLevel.none,
        annotations: CapabilityLevel.none,
        pageAnimation: CapabilityLevel.none,
        chapterNavigation: ReaderChapterNavigation.synthetic,
      ),
    );
  });
}
