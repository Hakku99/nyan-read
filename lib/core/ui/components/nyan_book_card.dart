import 'package:flutter/material.dart';

import '../../../modules/bookshelf/widgets/animated_book_card.dart';
import '../../models/book.dart';

class NyanBookCard extends StatelessWidget {
  final Book book;
  final Map<String, dynamic> bookData;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSelectionToggle;

  const NyanBookCard({
    super.key,
    required this.book,
    required this.bookData,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBookCardList(
      book: book,
      bookData: bookData,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      onTap: onTap,
      onLongPress: onLongPress,
      onSelectionToggle: onSelectionToggle,
    );
  }
}
