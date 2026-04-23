import 'package:flutter/material.dart';

class NyanColors {
  const NyanColors._();

  static const Color creamBackground = Color(0xFFF6F3EA);
  static const Color creamSurface = Color(0xFFFFFDF8);
  static const Color creamSurfaceMuted = Color(0xFFF1ECDD);
  static const Color creamPrimary = Color(0xFF98A27C);
  static const Color creamPrimaryDeep = Color(0xFF7E8B61);
  static const Color creamTextMain = Color(0xFF3F3A34);
  static const Color creamTextSecondary = Color(0xFF8A8377);
  static const Color creamDivider = Color(0xFFE5DED2);

  static const Color inkNightBackground = Color(0xFF1D211E);
  static const Color inkNightSurface = Color(0xFF262B27);
  static const Color inkNightPrimary = Color(0xFF93A07C);
  static const Color inkNightPrimaryDeep = Color(0xFF9AAD86);
  static const Color inkNightTextMain = Color(0xFFE8E1D5);
  static const Color inkNightTextSecondary = Color(0xFFAAA396);
  static const Color inkNightDivider = Color(0xFF3A3F3A);

  static const Color highlightYellow = Color(0xFFF2E58A);
  static const Color highlightGreen = Color(0xFFA8D18D);
  static const Color highlightBlue = Color(0xFF9EC5E8);
  static const Color highlightPink = Color(0xFFE8A0BF);
  static const Color highlightOrange = Color(0xFFF2BE7E);

  // ===========================================================================
  // Reader runtime defaults (出厂默认的阅读画布色；用户可在阅读设置中覆盖)
  // ===========================================================================
  static const Color readerPaperDefault = Color(0xFFFDFCF8);
  static const Color readerInkDefault = Color(0xFF4A453E);
  static const Color readerInkDark = Color(0xFFE6E2D8);

  // ===========================================================================
  // Reader theme swatches (阅读主题选择面板的 4 张卡，每卡为 bg/preview/ink 三元组)
  // 与 App 的 NyanTheme 预设解耦——这组是"纸面颜色"，不是"App 界面色"。
  // ===========================================================================
  static const Color readerBgCream = Color(0xFFF7F5EF);
  static const Color readerPreviewCream = Color(0xFFFFFCF5);
  static const Color readerInkCream = readerInkDefault;

  static const Color readerBgSepia = Color(0xFFEDE3C7);
  static const Color readerPreviewSepia = Color(0xFFF5ECD8);
  static const Color readerInkSepia = Color(0xFF5C4F3F);

  static const Color readerBgSumi = Color(0xFF262422);
  static const Color readerPreviewSumi = Color(0xFF302D2B);
  static const Color readerInkSumi = Color(0xFFE5DED3);

  static const Color readerBgCharcoal = Color(0xFF141312);
  static const Color readerPreviewCharcoal = Color(0xFF1B1A19);
  static const Color readerInkCharcoal = Color(0xFFF1EBDD);

  // ===========================================================================
  // Highlight dialog ink-tinted variants (HighlightNoteDialog 预览区专用)
  // 比 highlight* 原色更暗、更饱和，模拟"纸上墨迹"的视觉效果。
  // ===========================================================================
  static const Color highlightInkYellow = Color(0xFFD8C06B);
  static const Color highlightInkBlue = Color(0xFFB9C1C2);
  static const Color highlightInkPink = Color(0xFFCDA2A8);
  static const Color highlightInkOrange = Color(0xFFDBB686);
  static const Color highlightInkGreen = Color(0xFFA9C08E);
  static const Color highlightInkSepia = Color(0xFFA88D7E);
  static const Color highlightPreviewBar = Color(0xFFD4BA53);

  // ===========================================================================
  // Highlight dialog paper tones (HighlightNoteDialog 的四层连续表面色)
  // ===========================================================================
  static const Color highlightPaperDialog = Color(0xFFF8F5EE);
  static const Color highlightPaperPicker = Color(0xFFF4F0E8);
  static const Color highlightPaperPreview = Color(0xFFF3EEE3);
  static const Color highlightPaperInput = Color(0xFFF6F0E5);
  /// 半透明暖白叠加层，用于在 highlight 原色上增加"纸面"白雾效果。
  static const Color highlightPaperLiftTint = Color(0x55FFF8EF);

  // ===========================================================================
  // Inline shadow tints (用于 const BoxShadow 初始化；非 const 场景请用
  // NyanShadows.subtle / lightCard 工具)
  // ===========================================================================
  /// ~7% 纯黑，用于 HighlightNoteDialog 主阴影。
  static const Color shadowSoft = Color(0x12000000);
  /// ~2% 纯黑，用于 HighlightNoteDialog 辅助阴影。
  static const Color shadowHairline = Color(0x05000000);
  /// ~8% 纯黑 — NyanOverlayStyle.dialogShadow 外层。
  static const Color overlayShadowDialogOuter = Color(0x14000000);
  /// ~3% 纯黑 — NyanOverlayStyle.dialogShadow 内层。
  static const Color overlayShadowDialogInner = Color(0x08000000);
  /// ~6% 纯黑 — NyanOverlayStyle.loadingShadow 外层。
  static const Color overlayShadowLoadingOuter = Color(0x10000000);
  /// ~2% 纯黑 — NyanOverlayStyle.loadingShadow 内层。
  static const Color overlayShadowLoadingInner = Color(0x06000000);
  /// ~5% 纯黑 — NyanOverlayStyle.noticeShadow（单层）。
  static const Color overlayShadowNotice = Color(0x0D000000);

  // ===========================================================================
  // Overlay micro-palette (NyanOverlayStyle + NyanConfirmDialog + NyanDialogOptionRow)
  // 这些是"顶层浮层"专属的暖米色 + 朴素褐的微调色，独立于主题 surface/divider。
  // ===========================================================================
  /// 顶层浮层的纸面基色（creamSurface 之上再加一层暖白）。
  static const Color overlayCreamSurface = Color(0xFFFCFBF7);
  /// 嵌入式凹陷层表面（选项行、展开区）。
  static const Color overlayRecessedSurface = Color(0xFFF8F6F0);
  /// 未选中项的边框/分隔线。
  static const Color overlayOptionBorder = Color(0xFFEAE5DD);
  /// 危险/破坏动作强调色 — 暗色主题用暖褐。
  static const Color destructiveWarmDark = Color(0xFFB69A8D);
  /// 危险/破坏动作强调色 — 亮色主题用深一级的暖褐。
  static const Color destructiveWarmLight = Color(0xFFA4877C);
  /// NyanConfirmDialog 的破坏按钮底色（抹茶暖一级）。
  static const Color confirmOliveFill = Color(0xFFA3AB8B);
  /// NyanConfirmDialog badge 图标色。
  static const Color confirmBadgeIcon = Color(0xFF9A8578);
  /// NyanConfirmDialog badge 薄荷描边（~42% alpha）。
  static const Color confirmBadgeBorder = Color(0x6BDCE4D3);

  // ===========================================================================
  // Misc fallbacks
  // ===========================================================================
  static const Color readerLabelFallbackDark = Color(0xFF3D3D3D);

  static const Color white = Colors.white;
  static const Color transparent = Colors.transparent;
}
