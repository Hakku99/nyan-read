import 'package:flutter/material.dart';

/// A segmented control widget with pill-style design and sliding indicator animation.
/// Used for the Public/Private shelf tabs in HomeScreen.
class SegmentedTabControl extends StatefulWidget {
  final List<SegmentedTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;

  const SegmentedTabControl({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  State<SegmentedTabControl> createState() => _SegmentedTabControlState();
}

class _SegmentedTabControlState extends State<SegmentedTabControl> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.surface;
    final selectedColor = widget.selectedColor ?? theme.colorScheme.primary;
    final unselectedColor = widget.unselectedColor ??
        theme.textTheme.bodySmall?.color ??
        Colors.grey;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final tabWidth = totalWidth / widget.tabs.length;
          final indicatorLeft = widget.selectedIndex * tabWidth;

          return Stack(
            children: [
              // Sliding indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: indicatorLeft,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              // Tab buttons
              Row(
                children: List.generate(widget.tabs.length, (index) {
                  final tab = widget.tabs[index];
                  final isSelected = index == widget.selectedIndex;

                  return SizedBox(
                    width: tabWidth,
                    child: GestureDetector(
                      onTap: () => widget.onTabChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (tab.icon != null) ...[
                              Icon(
                                tab.icon,
                                size: 16,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : unselectedColor,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : unselectedColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Data class for a single tab in the segmented control
class SegmentedTab {
  final String label;
  final IconData? icon;

  const SegmentedTab({
    required this.label,
    this.icon,
  });
}
