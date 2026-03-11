import 'dart:typed_data';

import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/epub_parser.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/book.dart';
import '../../../../core/utils/book_source_access.dart';
import '../reader_engine.dart';
import 'epub_position.dart';

class EpubReaderEngine implements ReaderEngine {
  final Book book;
  late EpubController _epubController;
  bool _isInit = false;
  EpubBook? _document;
  List<Map<String, dynamic>> _chapters = const [];

  EpubReaderEngine(this.book);

  @override
  Future<void> initialize() async {
    if (_isInit) return;

    try {
      final bytes = Uint8List.fromList(await BookSourceAccess.readBytes(book));
      final document = await EpubDocument.openData(bytes);
      final parsedChapters = parseChapters(document);
      final paragraphResult = parseParagraphs(parsedChapters, document.Content);

      _document = document;
      _chapters = List<Map<String, dynamic>>.generate(
        parsedChapters.length,
        (index) {
          final chapter = parsedChapters[index];
          final startIndex = index < paragraphResult.chapterIndexes.length
              ? paragraphResult.chapterIndexes[index]
              : 0;
          return {
            'title': chapter.Title ?? 'Chapter ${index + 1}',
            'index': index,
            'startIndex': startIndex,
            'anchor': chapter.Anchor,
          };
        },
        growable: false,
      );

      _epubController = EpubController(
        document: Future<EpubBook>.value(document),
      );
      _isInit = true;
    } catch (e) {
      throw FormatException('Failed to open EPUB: $e');
    }
  }

  @override
  void setConfig(ReaderConfig config) {}

  @override
  double? getProgress() {
    return 0.0;
  }

  @override
  Future<void> seekToProgress(double progress) async {
    debugPrint('EPUB seeking not yet supported.');
  }

  String? _pendingCfi;

  @override
  Widget buildReader(BuildContext context) {
    if (!_isInit) return const Center(child: CircularProgressIndicator());
    return EpubView(
      controller: _epubController,
      onDocumentLoaded: (document) {
        if (_pendingCfi != null) {
          _epubController.gotoEpubCfi(_pendingCfi!);
          _pendingCfi = null;
        }
      },
      onExternalLinkPressed: (link) {},
    );
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    if (position is EpubReadingPosition) {
      _pendingCfi = position.cfi;
      try {
        _epubController.gotoEpubCfi(position.cfi);
        _pendingCfi = null;
      } catch (_) {
        // Leave _pendingCfi queued until the document finishes loading.
      }
    }
  }

  Future<void> jumpToChapterStart(int startIndex) async {
    _epubController.jumpTo(index: startIndex, alignment: 0);
  }

  @override
  ReadingPosition? getCurrentPosition() {
    final cfi = _epubController.generateEpubCfi();
    if (cfi != null) {
      return EpubReadingPosition(cfi: cfi);
    }
    return null;
  }

  @override
  Future<List<dynamic>> getChapters() async {
    if (!_isInit || _document == null) return [];
    return _chapters;
  }

  @override
  Future<void> nextPage() async {}

  @override
  Future<void> previousPage() async {}

  @override
  int getPageCount() => 0;

  @override
  int getCurrentPageIndex() => 0;

  @override
  bool get hasBottomBar => false;

  @override
  Future<String?> getSnippet() async => null;

  @override
  Future<String?> getTextAtPosition(ReadingPosition position) async => null;

  @override
  void dispose() {
    if (_isInit) {
      _epubController.dispose();
    }
  }
}
