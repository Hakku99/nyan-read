import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/folder_import_service.dart';
import '../../core/services/database_service.dart';
import '../../core/models/book.dart';

/// Preview page for folder import
/// Shows list of files to import with statistics
class FolderImportPreviewPage extends StatefulWidget {
  final List<File> files;
  final bool isPrivate;

  const FolderImportPreviewPage({
    Key? key,
    required this.files,
    this.isPrivate = false,
  }) : super(key: key);

  @override
  State<FolderImportPreviewPage> createState() =>
      _FolderImportPreviewPageState();
}

class _FolderImportPreviewPageState extends State<FolderImportPreviewPage> {
  final _importService = FolderImportService.instance;
  late List<File> _displayedFiles;
  late Set<String> _selectedFiles;
  Set<String> _existingFilenames = {};
  bool _isLoadingExisting = true;
  bool _showHidden = false;
  bool _isImporting = false;
  int _importProgress = 0;

  @override
  void initState() {
    super.initState();
    _displayedFiles =
        widget.files.where((f) => !_importService.isHiddenFile(f)).toList();
    _loadExistingBooks();
  }

  Future<void> _loadExistingBooks() async {
    final existing = await DatabaseService().getAllBookFilenames();
    if (mounted) {
      setState(() {
        // Store lowercase filenames for case-insensitive comparison
        _existingFilenames = existing.map((e) => e.toLowerCase()).toSet();
        _isLoadingExisting = false;

        // Initialize selected files, excluding existing ones
        _selectedFiles = {};
        for (final file in _displayedFiles) {
          final fileName = path.basename(file.path);
          // Only select if NOT already in library (case-insensitive)
          if (!_existingFilenames.contains(fileName.toLowerCase())) {
            _selectedFiles.add(file.path);
          }
        }
      });
    }
  }

  void _toggleShowHidden() {
    setState(() {
      _showHidden = !_showHidden;
      if (_showHidden) {
        _displayedFiles = widget.files;
      } else {
        _displayedFiles =
            widget.files.where((f) => !_importService.isHiddenFile(f)).toList();
        // Remove hidden files from selection
        _selectedFiles.removeWhere((path) {
          final file = File(path);
          return _importService.isHiddenFile(file);
        });
      }
    });
  }

  Future<void> _startImport() async {
    setState(() {
      _isImporting = true;
      _importProgress = 0;
    });

    final selectedFileObjects =
        _displayedFiles.where((f) => _selectedFiles.contains(f.path)).toList();

    int successCount = 0;
    int failedCount = 0;
    int skippedCount = 0;
    final errors = <String>[];

    final appDir = await getApplicationDocumentsDirectory();

    for (int i = 0; i < selectedFileObjects.length; i++) {
      final file = selectedFileObjects[i];
      final fileName = path.basename(file.path);

      // Skip if already exists (case-insensitive check)
      if (_existingFilenames.contains(fileName.toLowerCase())) {
        skippedCount++;
        setState(() {
          _importProgress = i + 1;
        });
        continue;
      }

      try {
        final savedFile = await file.copy(path.join(appDir.path, fileName));

        final book = Book(
          id: const Uuid().v4(),
          title: path.basenameWithoutExtension(fileName),
          author: "Unknown",
          filePath: savedFile.path,
          format: path.extension(fileName).replaceAll('.', ''),
          isPrivate: widget.isPrivate,
        );

        await DatabaseService().insertBook(book.toMap());
        successCount++;
      } catch (e) {
        failedCount++;
        errors.add('${path.basename(file.path)}: $e');
      }

      setState(() {
        _importProgress = i + 1;
      });
    }

    if (mounted) {
      _showImportResult(successCount, failedCount, skippedCount, errors);
    }
  }

  void _showImportResult(
      int success, int failed, int skipped, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✓ Imported: $success'),
            if (skipped > 0)
              Text('• Skipped (Already exists): $skipped',
                  style: const TextStyle(color: Colors.orange)),
            if (failed > 0) Text('✗ Failed: $failed'),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...errors.take(5).map(
                  (e) => Text('• $e', style: const TextStyle(fontSize: 12))),
              if (errors.length > 5) Text('... and ${errors.length - 5} more'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Return to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _importService.getFileStatistics(_displayedFiles);
    final selectedCount = _selectedFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Books'),
        actions: [
          // Show/Hide hidden files toggle
          IconButton(
            icon: Icon(_showHidden ? Icons.visibility_off : Icons.visibility),
            onPressed: _toggleShowHidden,
            tooltip: _showHidden ? 'Hide hidden files' : 'Show hidden files',
          ),
          // Select all / Deselect all
          IconButton(
            icon: Icon(
              selectedCount == _displayedFiles.length
                  ? Icons.deselect
                  : Icons.select_all,
            ),
            onPressed: () {
              setState(() {
                if (selectedCount == _displayedFiles.length) {
                  _selectedFiles.clear();
                } else {
                  // Select all, even existing ones if user explicitly clicks select all
                  _selectedFiles = Set.from(_displayedFiles.map((f) => f.path));
                }
              });
            },
            tooltip: selectedCount == _displayedFiles.length
                ? 'Deselect all'
                : 'Select all',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', stats['total'].toString()),
                _buildStat('Selected', selectedCount.toString()),
                if (stats['byExtension'] != null)
                  ...(stats['byExtension'] as Map<String, int>).entries.map(
                        (e) =>
                            _buildStat(e.key.toUpperCase(), e.value.toString()),
                      ),
              ],
            ),
          ),

          // File list
          Expanded(
            child: _isImporting ? _buildImportProgress() : _buildFileList(),
          ),

          // Import button
          if (!_isImporting)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedCount > 0 ? _startImport : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                      'Import $selectedCount ${selectedCount == 1 ? "Book" : "Books"}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFileList() {
    if (_isLoadingExisting) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _displayedFiles.length,
      itemBuilder: (context, index) {
        final file = _displayedFiles[index];
        final fileName = path.basename(file.path);
        final isHidden = _importService.isHiddenFile(file);
        final isSelected = _selectedFiles.contains(file.path);

        return CheckboxListTile(
          title: Text(
            fileName,
            style: TextStyle(
              color: isHidden ? Colors.grey : null,
              fontStyle: isHidden ? FontStyle.italic : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.path,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_existingFilenames.contains(fileName.toLowerCase()))
                const Text(
                  'Already in library',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          secondary: Icon(
            Icons.book,
            color: isHidden ? Colors.grey : Colors.pink,
          ),
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedFiles.add(file.path);
              } else {
                _selectedFiles.remove(file.path);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildImportProgress() {
    final total = _selectedFiles.length;
    final progress = _importProgress / total;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Importing $_importProgress of $total',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: LinearProgressIndicator(value: progress),
          ),
        ],
      ),
    );
  }
}
