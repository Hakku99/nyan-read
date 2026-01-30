import 'package:flutter/material.dart';
import '../../../core/models/book.dart';
import 'reader_engine.dart';
import 'epub/epub_reader.dart';
import 'pdf/pdf_reader.dart';
import 'txt/txt_reader.dart';

class ReaderEngineFactory {
  static ReaderEngine create(Book book) {
    switch (book.format.toLowerCase()) {
      case 'epub':
        return EpubReaderEngine(book);
      case 'pdf':
        return PdfReaderEngine(book);
      case 'txt':
        return TxtReaderEngine(book);
      default:
        // Default to TXT if unknown, or maybe a simple ErrorEngine
        return TxtReaderEngine(book);
    }
  }
}
