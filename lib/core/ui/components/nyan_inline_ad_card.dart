import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../nyan_icons.dart';
import '../nyan_theme_context.dart';

/// U22 "Option B" — Discover block: a clearly-labelled sponsored recommendation
/// anchored below the user's own books. Matches `BottomDiscover` in the spec.
class NyanShelfDiscoverBlock extends StatelessWidget {
  final String title;
  final String providerName;
  final List<NyanMiniSuggest> suggestions;
  final VoidCallback? onDismiss;

  const NyanShelfDiscoverBlock({
    super.key,
    required this.title,
    required this.providerName,
    required this.suggestions,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isDark = nyan.brightness == Brightness.dark;

    final borderColor = isDark
        ? nyan.borderColor.withValues(alpha: 0.88)
        : nyan.divider.withValues(alpha: 0.16);

    return Container(
      decoration: BoxDecoration(
        color: nyan.surface,
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: NyanShadows.subtle(nyan),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DiscoverHeader(
            title: title,
            providerName: providerName,
            onDismiss: onDismiss,
            nyan: nyan,
          ),
          Container(
            height: 0.5,
            color: nyan.divider.withValues(alpha: 0.6),
          ),
          _SuggestionsRow(suggestions: suggestions, nyan: nyan),
        ],
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  final String title;
  final String providerName;
  final VoidCallback? onDismiss;
  final dynamic nyan;

  const _DiscoverHeader({
    required this.title,
    required this.providerName,
    required this.onDismiss,
    required this.nyan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ponytail: asymmetric L/R per spec: "13px 12px 13px 14px" (T/R/B/L)
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          _CompassIcon(nyan: nyan),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.discoverBlockTitle,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: nyan.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                _SponsoredRow(providerName: providerName, nyan: nyan),
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: NyanSpacing.space8),
            _DismissButton(onDismiss: onDismiss!, nyan: nyan),
          ],
        ],
      ),
    );
  }
}

class _CompassIcon extends StatelessWidget {
  final dynamic nyan;
  const _CompassIcon({required this.nyan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: nyan.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        NyanIcons.compassFilled,
        size: 17,
        color: nyan.accent,
      ),
    );
  }
}

class _SponsoredRow extends StatelessWidget {
  final String providerName;
  final dynamic nyan;
  const _SponsoredRow({required this.providerName, required this.nyan});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'SPONSORED',
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: NyanTypography.sponsoredBadge,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            height: 1.0,
            color: nyan.accent,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: nyan.textMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          providerName,
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: NyanTypography.caption,
            fontWeight: FontWeight.w400,
            height: 1.0,
            color: nyan.textMuted,
          ),
        ),
      ],
    );
  }
}

class _DismissButton extends StatelessWidget {
  final VoidCallback onDismiss;
  final dynamic nyan;
  const _DismissButton({required this.onDismiss, required this.nyan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Icon(
          NyanIcons.close,
          size: 14,
          color: nyan.textMuted,
        ),
      ),
    );
  }
}

class _SuggestionsRow extends StatelessWidget {
  final List<NyanMiniSuggest> suggestions;
  final dynamic nyan;
  const _SuggestionsRow({required this.suggestions, required this.nyan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ponytail: "14px 16px 16px" = T/L-R/B per spec
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _MiniSuggestTile(data: suggestions[i], nyan: nyan)),
          ],
        ],
      ),
    );
  }
}

class _MiniSuggestTile extends StatelessWidget {
  final NyanMiniSuggest data;
  final dynamic nyan;
  const _MiniSuggestTile({required this.data, required this.nyan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CoverCard(nyan: nyan),
        const SizedBox(height: 8),
        Text(
          data.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: NyanTypography.miniSuggestTitle,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: nyan.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: NyanTypography.miniSuggestAuthor,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: nyan.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CoverCard extends StatelessWidget {
  final dynamic nyan;
  const _CoverCard({required this.nyan});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // ponytail: gradient per spec "150deg, primary@19% → primary@7%"
            colors: [
              Color.lerp(nyan.surface, nyan.primary, 0.19)!,
              Color.lerp(nyan.surface, nyan.primary, 0.07)!,
            ],
          ),
          border: Border.all(
            color: nyan.divider.withValues(alpha: 0.42),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: -8,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Left accent strip
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      nyan.accent.withValues(alpha: 0.34),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Icon(
                NyanIcons.book,
                size: 21,
                color: nyan.accent.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class for a mini book suggestion tile.
class NyanMiniSuggest {
  final String title;
  final String author;

  const NyanMiniSuggest({required this.title, required this.author});
}
