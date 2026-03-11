import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/book.dart';
import '../../core/utils/book_source_access.dart';
import '../../core/utils/snackbar_utils.dart';

class BookDetailsPage extends StatelessWidget {
  final Book book;
  final Map<String, dynamic> bookData;

  const BookDetailsPage({
    Key? key,
    required this.book,
    required this.bookData,
  }) : super(key: key);

  void _openReader(BuildContext context) {
    context.pushReplacement('/reader/${book.id}');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final progress = (bookData['current_progress'] as num?)?.toDouble() ?? 0.0;
    final progressPercent = (progress * 100).toInt();

    String addedAt = loc.unknown;
    if (bookData['added_at'] != null) {
      addedAt = dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(bookData['added_at'] as int),
      );
    }

    String lastReadAt = loc.never;
    if (bookData['last_read_at'] != null) {
      lastReadAt = dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(bookData['last_read_at'] as int),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.bookDetails),
        actions: [
          FutureBuilder<bool>(
            future: BookSourceAccess.isAvailable(book),
            builder: (context, snapshot) {
              final isAvailable = snapshot.data ?? true;
              return IconButton(
                icon: const Icon(Icons.menu_book),
                onPressed: isAvailable ? () => _openReader(context) : null,
                tooltip: loc.startReading,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.pink.shade200),
                ),
                child: const Icon(
                  Icons.book,
                  size: 80,
                  color: Colors.pink,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoSection(loc.title, book.title, icon: Icons.title),
            const Divider(),
            _buildInfoSection(loc.author, book.author, icon: Icons.person),
            const Divider(),
            _buildInfoSection(
              loc.format,
              book.format.toUpperCase(),
              icon: Icons.description,
            ),
            const Divider(),
            _buildInfoSection(
              loc.privacy,
              book.isPrivate ? loc.privateShelf : loc.publicShelf,
              icon: book.isPrivate ? Icons.lock : Icons.lock_open,
            ),
            const Divider(),
            _buildInfoSection(
              loc.readingProgress,
              '$progressPercent%',
              icon: Icons.trending_up,
              trailing: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
              ),
            ),
            const Divider(),
            _buildInfoSection(
              loc.added,
              addedAt,
              icon: Icons.add_circle_outline,
            ),
            const Divider(),
            _buildInfoSection(
              loc.lastRead,
              lastReadAt,
              icon: Icons.access_time,
            ),
            const Divider(),
            _buildFilePathSection(context),
            const SizedBox(height: 24),
            _buildStartReadingButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    String label,
    String value, {
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (trailing == null)
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                else
                  trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePathSection(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text(
                loc.fileLocation,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    book.sourceLocator,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: book.sourceLocator));
                    SnackBarUtils.show(context, loc.filePathCopied);
                  },
                  tooltip: loc.copyPath,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<bool>(
            future: BookSourceAccess.isAvailable(book),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final isAvailable = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: isAvailable ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isAvailable ? loc.fileExists : loc.fileNotFound,
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isAvailable) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        BookSourceAccess.unavailableMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStartReadingButton(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<bool>(
      future: BookSourceAccess.isAvailable(book),
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: isAvailable ? () => _openReader(context) : null,
              icon: const Icon(Icons.menu_book),
              label: Text(loc.startReading),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (snapshot.hasData && !isAvailable) ...[
              const SizedBox(height: 8),
              Text(
                BookSourceAccess.unavailableMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

