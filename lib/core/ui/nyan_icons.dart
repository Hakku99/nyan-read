import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Nyan Read's canonical icon set. Every Widget that draws an icon MUST import
/// this class instead of `package:flutter/material.dart` `Icons.*`.
///
/// The project standardised on **Phosphor Regular** (1.5px stroke, MIT-licensed)
/// per the design-system handoff. Phosphor's lighter rhythm sits better against
/// Noto Sans SC than Material Round and keeps the paper-book quietness intact.
///
/// Fill weight is reserved for "set" / "selected" affordances. Only these
/// four glyphs use Phosphor Fill — anything else MUST stay Regular:
///   • [bookmarkFilled] / [bookmarkAdded] — page currently has a bookmark
///                                          (the two names are aliases)
///   • [checkFilled]                       — matcha selected-card badge
///   • [playFilled]                        — "currently reading" chapter indicator
///   • [sortDirectionIndicator]            — selected sort-field direction arrow
///
/// When adding an icon, prefer reusing an existing semantic name. If a brand-new
/// glyph is needed, add it in the matching section below and reference the
/// Phosphor catalogue at <https://phosphoricons.com> — pick the closest match
/// to the Material name it replaces so call-site intent stays readable.
class NyanIcons {
  const NyanIcons._();

  // ── Navigation ──────────────────────────────────────────────────────────
  static const IconData back = PhosphorIconsRegular.arrowLeft;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData chevronRight = PhosphorIconsRegular.caretRight;
  static const IconData chevronLeft = PhosphorIconsRegular.caretLeft;
  static const IconData chevronUp = PhosphorIconsRegular.caretUp;
  static const IconData chevronDown = PhosphorIconsRegular.caretDown;
  static const IconData moreHorizontal = PhosphorIconsRegular.dotsThree;

  // ── Books & Reading ─────────────────────────────────────────────────────
  /// Generic "book" glyph — replaces Material `Icons.menu_book`, `book_open`,
  /// any book cover placeholder. Use `books` (plural) for a library/shelf.
  static const IconData book = PhosphorIconsRegular.bookOpen;

  /// Plain closed-book outline (`ph-book`). Used where the design spec calls
  /// for a single-volume icon without the open-pages silhouette — e.g. the
  /// "Supported Formats" leading icon in ImportBookSheet.
  static const IconData bookClosed = PhosphorIconsRegular.book;
  static const IconData books = PhosphorIconsRegular.books;
  static const IconData bookCollection = PhosphorIconsRegular.bookBookmark;
  static const IconData bookmark = PhosphorIconsRegular.bookmarkSimple;

  /// Used only when a bookmark IS set on the current page (overlay top bar).
  static const IconData bookmarkFilled = PhosphorIconsFill.bookmarkSimple;

  /// Alias for [bookmarkFilled] — explicit name for the "newly added" toast /
  /// confirmation state (replaces Material `Icons.bookmark_added_rounded`).
  static const IconData bookmarkAdded = PhosphorIconsFill.bookmarkSimple;
  static const IconData bookmarks = PhosphorIconsRegular.bookmarksSimple;
  static const IconData tableOfContents = PhosphorIconsRegular.listBullets;
  static const IconData highlights = PhosphorIconsRegular.highlighter;

  /// Empty-state hero for the Notes & Highlights page (ph-highlighter-circle).
  static const IconData highlighterCircle = PhosphorIconsRegular.highlighterCircle;

  // ── Common actions ──────────────────────────────────────────────────────
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData remove = PhosphorIconsRegular.minus;
  static const IconData delete = PhosphorIconsRegular.trash;
  static const IconData check = PhosphorIconsRegular.check;

  /// Success status glyph for the shared response toast (ph-check-circle).
  static const IconData checkCircle = PhosphorIconsRegular.checkCircle;

  /// Indeterminate loading glyph for the response toast (ph-circle-notch);
  /// rendered spinning. See [NyanResponse].
  static const IconData circleNotch = PhosphorIconsRegular.circleNotch;

  /// Used only for the matcha selected-card badge (reader theme picker, etc).
  static const IconData checkFilled = PhosphorIconsFill.check;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData copy = PhosphorIconsRegular.copy;
  static const IconData refresh = PhosphorIconsRegular.arrowsClockwise;
  static const IconData restart = PhosphorIconsRegular.arrowCounterClockwise;
  static const IconData share = PhosphorIconsRegular.shareNetwork;

  /// iOS-style share glyph (square with up arrow). Use [share] elsewhere.
  static const IconData shareIos = PhosphorIconsRegular.shareFat;

  /// Export action — settings "Export Data" row (spec `bundle4.jsx`: icon="export").
  // ignore: library_private_types_in_public_api
  static const IconData exportData = PhosphorIconsRegular.export;
  static const IconData download = PhosphorIconsRegular.downloadSimple;
  static const IconData upload = PhosphorIconsRegular.uploadSimple;
  static const IconData save = PhosphorIconsRegular.floppyDisk;
  static const IconData folderOpen = PhosphorIconsRegular.folderOpen;
  static const IconData editNote = PhosphorIconsRegular.pencilLine;

  /// Covers Material `Icons.format_quote_rounded` — pull-quote glyph used in
  /// the highlight note dialog and similar excerpt UIs.
  static const IconData quote = PhosphorIconsRegular.quotes;
  static const IconData file = PhosphorIconsRegular.file;
  static const IconData backspace = PhosphorIconsRegular.backspace;
  static const IconData selectAll = PhosphorIconsRegular.selectionPlus;
  static const IconData deselect = PhosphorIconsRegular.selectionSlash;

  // ── System / Settings ───────────────────────────────────────────────────
  static const IconData settings = PhosphorIconsRegular.gearSix;
  static const IconData tune = PhosphorIconsRegular.slidersHorizontal;
  static const IconData dashboard = PhosphorIconsRegular.squaresFour;
  // Spec `bundle4.jsx` settings row: icon="wrench".
  static const IconData adminPanel = PhosphorIconsRegular.wrench;
  static const IconData sparkle = PhosphorIconsRegular.sparkle;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData warning = PhosphorIconsRegular.warning;
  static const IconData error = PhosphorIconsRegular.warningCircle;
  static const IconData bug = PhosphorIconsRegular.bug;

  /// Used for the "Report to developer" button in error screens (ph-bug-beetle).
  static const IconData bugBeetle = PhosphorIconsRegular.bugBeetle;

  /// Used for the "File not found" error state icon (ph-compass).
  static const IconData compass = PhosphorIconsRegular.compass;

  /// Used for the "Unsupported format" error state icon (ph-file-dashed).
  static const IconData fileDashed = PhosphorIconsRegular.fileDashed;

  static const IconData block = PhosphorIconsRegular.prohibit;

  // ── View / Visual ───────────────────────────────────────────────────────
  static const IconData viewList = PhosphorIconsRegular.listBullets;
  static const IconData viewGrid = PhosphorIconsRegular.squaresFour;
  static const IconData sort = PhosphorIconsRegular.arrowsDownUp;
  static const IconData sortAscending = PhosphorIconsRegular.sortAscending;

  /// Fill arrow-up used as the direction indicator on the selected row of the
  /// bookshelf sort sheet (spec: `ph-fill ph-arrow-up`, flipped via
  /// `Transform.scale(scaleY: -1)` when descending).
  /// This is the 4th Phosphor Fill exception; see the class-level comment.
  static const IconData sortDirectionIndicator = PhosphorIconsFill.arrowUp;
  static const IconData visibility = PhosphorIconsRegular.eye;
  static const IconData visibilityOff = PhosphorIconsRegular.eyeSlash;
  static const IconData palette = PhosphorIconsRegular.palette;

  // ── Privacy ─────────────────────────────────────────────────────────────
  static const IconData lock = PhosphorIconsRegular.lockSimple;
  static const IconData lockOpen = PhosphorIconsRegular.lockSimpleOpen;

  // ── Reader / Display ────────────────────────────────────────────────────
  static const IconData sun = PhosphorIconsRegular.sun;
  static const IconData moon = PhosphorIconsRegular.moon;

  /// Theme-mode "light" toggle alias for [sun] — kept explicit so migration
  /// from `Icons.light_mode_rounded` is unambiguous.
  static const IconData lightMode = PhosphorIconsRegular.sun;

  /// Theme-mode "dark" toggle alias for [moon] — paired with [lightMode].
  static const IconData darkMode = PhosphorIconsRegular.moon;

  /// Sleepy-mascot / nightlight glyph (replaces `Icons.nightlight_round`).
  /// Distinct from plain [moon]: carries the "stars" character.
  static const IconData nightlight = PhosphorIconsRegular.moonStars;
  static const IconData brightness = PhosphorIconsRegular.sunDim;
  static const IconData brightnessAuto = PhosphorIconsRegular.sunHorizon;
  static const IconData fontSize = PhosphorIconsRegular.textAa;
  static const IconData phone = PhosphorIconsRegular.deviceMobile;
  static const IconData thermostat = PhosphorIconsRegular.thermometer;

  // ── Time ────────────────────────────────────────────────────────────────
  // Spec `bundle4.jsx` reading reminder row: icon="bell".
  static const IconData bell = PhosphorIconsRegular.bell;
  static const IconData alarm = PhosphorIconsRegular.alarm;
  static const IconData clock = PhosphorIconsRegular.clock;
  static const IconData inbox = PhosphorIconsRegular.tray;

  // ── Localization ────────────────────────────────────────────────────────
  static const IconData language = PhosphorIconsRegular.translate;

  // ── Cloud ───────────────────────────────────────────────────────────────
  static const IconData cloudDownload = PhosphorIconsRegular.cloudArrowDown;
  static const IconData cloudUpload = PhosphorIconsRegular.cloudArrowUp;

  // ── Playback ────────────────────────────────────────────────────────────
  static const IconData play = PhosphorIconsRegular.play;
  // Filled play — used as the "currently reading" indicator inside ChapterListItem
  // (spec: `ph-fill ph-play`; §4.6 delivery-package takes priority over the
  // regular-only icon rule in §4.3 for this specific affordance).
  static const IconData playFilled = PhosphorIconsFill.play;
  static const IconData skipNext = PhosphorIconsRegular.skipForward;
  static const IconData skipPrevious = PhosphorIconsRegular.skipBack;

  // ── Page turn ────────────────────────────────────────────────────────────
  /// Horizontal arrows (↔) — "Left & Right" page turn mode in Settings picker.
  static const IconData pageTurnHorizontal = PhosphorIconsRegular.arrowsHorizontal;
  /// Vertical arrows (↕) — "Up & Down" page turn mode in Settings picker.
  static const IconData pageTurnVertical = PhosphorIconsRegular.arrowsVertical;

  // ── System / device ──────────────────────────────────────────────────────
  /// Half-light/half-dark device icon — "Match System" theme option.
  static const IconData matchSystem = PhosphorIconsRegular.circleHalfTilt;

  // ── Misc ────────────────────────────────────────────────────────────────
  static const IconData pets = PhosphorIconsRegular.pawPrint;
  static const IconData myLocation = PhosphorIconsRegular.crosshair;

  /// Compact crosshair (no outer ring) — used by the "Jump to current" FAB
  /// in the Chapters sheet. `ph-crosshair-simple` per design spec.
  static const IconData jumpToCurrent = PhosphorIconsRegular.crosshairSimple;
}
