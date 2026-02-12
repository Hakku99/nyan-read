import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import '../../../../core/models/book.dart';
import '../reader_engine.dart';
import 'epub_position.dart';

class EpubReaderEngine implements ReaderEngine {
  final Book book;
  late EpubController _epubController;
  bool _isInit = false;

  EpubReaderEngine(this.book);

  @override
  Future<void> initialize() async {
    if (_isInit) return;

    final file = File(book.filePath);
    if (!await file.exists()) {
      throw const FileSystemException("File not found");
    }

    try {
      _epubController = EpubController(
        document: EpubDocument.openFile(file),
      );
      _isInit = true;
    } catch (e) {
      throw FormatException("Failed to open EPUB: $e");
    }
  }

  @override
  void setConfig(ReaderConfig config) {
    // EpubView handles its own styling usually, or we need to rebuild it with builders.
    // For MVP, we might not support dynamic font change inside EpubView easily without rebuilding.
  }

  @override
  double? getProgress() {
    // Parsing CFI to percentage is complex without EpubController exposing it directly.
    return 0.0;
  }

  @override
  Future<void> seekToProgress(double progress) async {
    // TODO: Implement EPUB seeking based on spine/progress mapping.
    debugPrint("EPUB seeking not yet supported.");
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
      // If controller is attached (approximated by _isInit for now, but really depends on View)
      // Since we don't have isAttached, we'll try to set it.
      // Ideally, EpubView should expose 'onCreated'.
      // For now, we rely on onDocumentLoaded to consume the pending CFI.
      // If we are already loaded, we can just jump?
      // Since we can't easily check if View is mounted, we just set the pending CFI always
      // and let onDocumentLoaded handle it IF it fires again?
      // No, onDocumentLoaded fires once.

      // Better strategy: Try to jump. If it fails (exception), queue it?
      // Or just queue it if we think we haven't loaded?
      // We'll set _pendingCfi. If the view is building, onDocumentLoaded will pick it up.
      // If the view is ALREADY built and loaded, onDocumentLoaded won't fire again.
      // So we need to know if we are "ready".

      _pendingCfi = position.cfi;
      // Try to jump immediately as well, in case we are already loaded.
      try {
        _epubController.gotoEpubCfi(position.cfi);
        _pendingCfi = null; // If success, clear pending
      } catch (e) {
        // Ignore error, assume view not ready, leave _pendingCfi set for onDocumentLoaded
      }
    }
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
    if (!_isInit) return [];

    try {
      // EpubController provides access to table of contents
      // We'll extract chapter information from the controller
      final document = await _epubController.document;
      if (document == null) return [];

      final chapters = <Map<String, dynamic>>[];
      int index = 0;

      // Extract chapters from EPUB table of contents
      for (final chapter in document.Chapters ?? []) {
        chapters.add({
          'title': chapter.Title ?? 'Chapter ${index + 1}',
          'index': index,
          'anchor': chapter.Anchor,
        });
        index++;
      }

      return chapters;
    } catch (e) {
      debugPrint('Error extracting EPUB chapters: $e');
      return [];
    }
  }

  @override
  Future<void> nextPage() async {
    // EpubView handles its own gestures.
    // TODO: Implement programmatic navigation if supported by controller.
  }

  @override
  Future<void> previousPage() async {
    // EpubView handles its own gestures.
    // TODO: Implement programmatic navigation if supported by controller.
  }

  @override
  int getPageCount() {
    return 0; // Not supported yet
  }

  @override
  int getCurrentPageIndex() {
    return 0; // Not supported yet
  }

  @override
  bool get hasBottomBar => false;

  @override
  void dispose() {
    if (_isInit) {
      _epubController.dispose();
    }
  }
}
