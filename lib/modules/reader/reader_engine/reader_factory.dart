import 'package:flutter/widgets.dart';

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
        // Deliberately NOT falling back to TxtReaderEngine: parsing a PDF
        // (or anything binary) as TXT renders mojibake instead of telling
        // the user what's wrong. The stub throws from initialize(), which
        // ReaderController._loadBook maps to ReaderErrorType.unsupportedFormat.
        return _UnsupportedFormatEngine(book.format);
    }
  }
}

/// Placeholder engine for formats no real engine claims. Construction must
/// succeed (ReaderController builds engines in its constructor, before any
/// error handling exists); the failure surfaces on [initialize].
class _UnsupportedFormatEngine implements ReaderEngine {
  _UnsupportedFormatEngine(this._format);

  final String _format;

  @override
  ReaderCapabilities get capabilities => const ReaderCapabilities(
        typography: CapabilityLevel.none,
        theme: CapabilityLevel.none,
        highlights: CapabilityLevel.none,
        annotations: CapabilityLevel.none,
        pageAnimation: CapabilityLevel.none,
        chapterNavigation: ReaderChapterNavigation.none,
      );

  @override
  Future<void> initialize() async {
    throw UnsupportedError('Unsupported book format: "$_format"');
  }

  @override
  Widget buildReader(BuildContext context) => const SizedBox.shrink();

  @override
  Future<void> goToPosition(ReadingPosition position) async {}

  @override
  ReadingPosition? getCurrentPosition() => null;

  @override
  void setConfig(ReaderConfig config) {}

  @override
  double? getProgress() => null;

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<List<ReaderChapter>> getChapters() async => const [];

  @override
  Future<void> goToChapter(ChapterLocator locator) async {}

  @override
  Future<void> nextPage() async {}

  @override
  Future<void> previousPage() async {}

  @override
  bool get hasBottomBar => false;

  @override
  void dispose() {}
}
