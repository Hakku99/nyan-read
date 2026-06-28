import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/nyan_typography.dart';
import '../../../core/ui/nyan_icons.dart';

/// Full-screen eye-rest nudge shown over the reader after the configured
/// reading interval. The scrim is the same dark wash in both themes so white
/// text always reads correctly against it — intentionally ignores NyanTheme
/// background colours here (same as the design spec's deliberate choice).
///
/// [remaining] counts down from [total] (seconds). [onSkip] is called when
/// the user taps "Continue reading" before the countdown completes; the reader
/// page also calls it when [remaining] reaches zero.
class RestReminderOverlay extends StatelessWidget {
  const RestReminderOverlay({
    super.key,
    required this.remaining,
    required this.total,
    required this.onSkip,
  });

  final int remaining;
  final int total;
  final VoidCallback onSkip;

  // Spec hardcodes this matcha green in both cream and dark themes — the rest
  // overlay has its own scrim so the ring must always read on dark.
  static const Color _kRingColor = Color(0xFFA9B690);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark scrim + blur — same gradient in both themes so white reads.
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xBD1C201E), // rgba(28,32,30,.74)
                  Color(0xD1141715), // rgba(20,23,21,.82)
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),

        // Content column — centred, not scrollable.
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Countdown ring ───────────────────────────────────────
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(168, 168),
                          painter: _RingPainter(
                            progress: remaining / total,
                            ringColor: _kRingColor,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontFamily: NyanTypography.uiFontFamily,
                                // sole w300 exception — see AGENTS.md §4.2.5
                                fontSize: NyanTypography.restReminderTimer,
                                fontWeight: FontWeight.w300,
                                height: 1.0,
                                letterSpacing: -1,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'REMAINING',
                              style: TextStyle(
                                fontFamily: NyanTypography.uiFontFamily,
                                fontSize: NyanTypography.caption, // 11pt
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.6,
                                color: Color(0x99FFFFFF), // white@60%
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Title ────────────────────────────────────────────────
                  const Text(
                    'Rest your eyes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: NyanTypography.restReminderTitle, // 21pt
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 9),

                  // ── Body ─────────────────────────────────────────────────
                  const SizedBox(
                    width: 244,
                    child: Text(
                      'Eyes off the page for a bit — go watch the world go by.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: 14, // body (§4.2.5 exception — matches reader error view)
                        fontWeight: FontWeight.w400,
                        height: 1.55,
                        color: Color(0xB8FFFFFF), // white@72%
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── "Continue reading" button ────────────────────────────
                  // Stadium 999 is a deliberate spec exception for this
                  // full-screen overlay CTA — see AGENTS.md §4.3.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onSkip,
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          decoration: BoxDecoration(
                            color: const Color(0xEBFFFFFF), // white@92%
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                NyanIcons.fastForward,
                                size: 15,
                                color: Color(0xFF3A3A36),
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Continue reading',
                                style: TextStyle(
                                  fontFamily: NyanTypography.uiFontFamily,
                                  fontSize: NyanTypography.buttonCompact, // 14pt
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                  color: Color(0xFF3A3A36),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.ringColor});

  final double progress; // 0.0–1.0 (fraction of rest time remaining)
  final Color ringColor;

  static const double _strokeWidth = 9;
  static const double _radius = 64;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const sweepAngle = 2 * math.pi;

    // Track arc — full circle, white@18%.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: _radius),
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0x2DFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc — covers the remaining fraction, matcha primary.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _radius),
        -math.pi / 2,
        sweepAngle * progress,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
