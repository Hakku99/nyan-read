import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/book.dart';
import '../../core/utils/snackbar_utils.dart';

class BookDetailsPage extends StatelessWidget {
  final Book book;
  final Map<String, dynamic> bookData;

  const BookDetailsPage({
    Key? key,
    required this.book,
    required this.bookData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Calculate progress
    final progress = (bookData['current_progress'] as num?)?.toDouble() ?? 0.0;
    final progressPercent = (progress * 100).toInt();

    // Format dates
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
          IconButton(
            icon: const Icon(Icons.menu_book),
            onPressed: () {
              context.pushReplacement('/reader/${book.id}');
            },
            tooltip: loc.startReading,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Icon/Cover
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

            // Title
            _buildInfoSection(
              loc.title,
              book.title,
              icon: Icons.title,
            ),

            const Divider(),

            // Author
            _buildInfoSection(
              loc.author,
              book.author,
              icon: Icons.person,
            ),

            const Divider(),

            // Format
            _buildInfoSection(
              loc.format,
              book.format.toUpperCase(),
              icon: Icons.description,
            ),

            const Divider(),

            // Privacy Status
            _buildInfoSection(
              loc.privacy,
              book.isPrivate ? loc.privateShelf : loc.publicShelf,
              icon: book.isPrivate ? Icons.lock : Icons.lock_open,
            ),

            const Divider(),

            // Reading Progress
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

            // Added Date
            _buildInfoSection(
              loc.added,
              addedAt,
              icon: Icons.add_circle_outline,
            ),

            const Divider(),

            // Last Read
            _buildInfoSection(
              loc.lastRead,
              lastReadAt,
              icon: Icons.access_time,
            ),

            const Divider(),

            // File Path (with copy button)
            _buildFilePathSection(context),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.pushReplacement('/reader/${book.id}');
                    },
                    icon: const Icon(Icons.menu_book),
                    label: Text(loc.startReading),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
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
                    book.filePath,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: book.filePath));
                    SnackBarUtils.show(context, loc.filePathCopied);
                  },
                  tooltip: loc.copyPath,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // File existence check
          FutureBuilder<bool>(
            future: File(book.filePath).exists(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final exists = snapshot.data!;
                return Row(
                  children: [
                    Icon(
                      exists ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: exists ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      exists ? loc.fileExists : loc.fileNotFound,
                      style: TextStyle(
                        fontSize: 12,
                        color: exists ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
