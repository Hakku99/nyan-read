// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themePreset => 'Theme Preset';

  @override
  String get themePresetSubtitle => 'How Nyan Read looks while you read.';

  @override
  String get readingSettings => 'Reading Settings';

  @override
  String get reading => 'Reading';

  @override
  String get readerQuickProgressSubtitle => 'Chapter seek and position';

  @override
  String get readerQuickToolsSubtitle => 'Bookmarks, notes, and full settings';

  @override
  String get readerQuickOpenFullSettings => 'All settings';

  @override
  String get readerMenuBackToQuick => 'Quick';

  @override
  String get readerEdgeBrightnessOn => 'Left edge brightness: on';

  @override
  String get readerEdgeBrightnessOff => 'Left edge brightness: off';

  @override
  String get pageTurnMode => 'Page Turn Mode';

  @override
  String get pageTurnModeSubtitle => 'The direction pages move as you read.';

  @override
  String get pageTurnModeTap => 'Tap to turn pages';

  @override
  String get pageTurnModeSwipe => 'Swipe to turn pages';

  @override
  String get pageTurnModeDisabled => 'Page turning disabled';

  @override
  String get pageTurnModeLeftRight => 'Left-right';

  @override
  String get pageTurnModeUpDown => 'Up-down';

  @override
  String get pageTurnTap => 'Tap';

  @override
  String get pageTurnSwipe => 'Swipe';

  @override
  String get pageTurnDisabled => 'Disabled';

  @override
  String get readerFontFamily => 'Font';

  @override
  String get readerFontFamilySans => 'Sans';

  @override
  String get readerFontFamilySerif => 'Serif';

  @override
  String get pageAnimation => 'Page Animation';

  @override
  String get pageAnimationFade => 'Directional fade transition';

  @override
  String get pageAnimationPaper => 'Subtle paper effect';

  @override
  String get pageAnimationNone => 'No animation';

  @override
  String get pageAnimFade => 'Directional Fade';

  @override
  String get pageAnimPaper => 'Paper';

  @override
  String get pageAnimNone => 'None';

  @override
  String get readingReminder => 'Reading Reminder';

  @override
  String get readingReminderSubtitle => 'Chapter seek and position';

  @override
  String get reminderInterval => 'Reminder Interval';

  @override
  String get reminderIntervalSubtitle =>
      'How often to nudge you back to reading.';

  @override
  String reminderMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderEvery15min => 'Every 15 min';

  @override
  String get reminderEvery30min => 'Every 30 min';

  @override
  String get reminderEveryHour => 'Every hour';

  @override
  String get reminderEvery2hours => 'Every 2 hours';

  @override
  String get reminderDaily => 'Daily';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get deleteFilesOnRemove => 'Delete Files on Remove';

  @override
  String get deleteFilesOnRemoveSubtitle =>
      'Remove source files when deleting a book';

  @override
  String get lockPrivateShelf => 'Lock Private Shelf';

  @override
  String get tts => 'TTS (Text-to-Speech)';

  @override
  String get ads => 'Ads';

  @override
  String get adsSubtitle => 'Shown in the free version';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get upgradeToProSubtitle => 'Unlock Privacy Shelf and more';

  @override
  String get pro => 'Pro';

  @override
  String get about => 'About';

  @override
  String get lockPrivacyShelfSubtitle => 'Require PIN to open';

  @override
  String get adminPanel => 'Admin Panel';

  @override
  String get adminPanelTitle => 'Admin / Manager Mode';

  @override
  String get adminPanelModeSection => 'Mode Control';

  @override
  String get adminProModeEnabled => 'Pro Mode Enabled';

  @override
  String get adminProModeSubtitle => 'Unlocks Privacy Shelf and disables ads';

  @override
  String get adminForceUnlockPrivacyShelf => 'Force Unlock Privacy Shelf';

  @override
  String get adminForceUnlockPrivacyShelfSubtitle =>
      'Bypass password verification';

  @override
  String get adminFeatureFlagsSection => 'Feature Flags';

  @override
  String get adminStateOn => 'On';

  @override
  String get adminStateOff => 'Off';

  @override
  String get adminPanelHintTitle => 'Internal control panel';

  @override
  String get adminPanelHintSubtitle =>
      'Use this page for debugging and capability verification.';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'App display language.';

  @override
  String get bookDetails => 'Book Details';

  @override
  String get bookDetailsOverviewSection => 'Overview';

  @override
  String get bookDetailsSourceSection => 'Source';

  @override
  String get originalPath => 'Original Path';

  @override
  String get unknownAuthor => 'Unknown author';

  @override
  String get readyToStart => 'Ready to start';

  @override
  String get title => 'Title';

  @override
  String get author => 'Author';

  @override
  String get format => 'Format';

  @override
  String get bookFormatEpub => 'EPUB';

  @override
  String get bookFormatTxt => 'TXT';

  @override
  String get bookFormatPdf => 'PDF';

  @override
  String get privacy => 'Privacy';

  @override
  String get privateShelf => 'Private Shelf';

  @override
  String get publicShelf => 'Public Shelf';

  @override
  String get readingProgress => 'Reading Progress';

  @override
  String get added => 'Added';

  @override
  String get lastRead => 'Last Read';

  @override
  String get lastOpened => 'Last Opened';

  @override
  String get bookDetailsSourceSummaryDownloads => 'Saved from Downloads';

  @override
  String get bookDetailsSourceSummaryImported => 'Imported file';

  @override
  String get bookDetailsFullTitle => 'Full Title';

  @override
  String get fileLocation => 'File Location';

  @override
  String get startReading => 'Start Reading';

  @override
  String get continueReading => 'Continue Reading';

  @override
  String get copyPath => 'Copy Path';

  @override
  String get filePathCopied => 'File path copied to clipboard';

  @override
  String get fileExists => 'File exists';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get fileUnavailableCta => 'File unavailable';

  @override
  String get unknown => 'Unknown';

  @override
  String get never => 'Never';

  @override
  String get backToBookshelf => 'Back to Bookshelf';

  @override
  String get retry => 'Retry';

  @override
  String get reportToDeveloper => 'Report to developer';

  @override
  String get showTechnicalDetails => 'Show technical details';

  @override
  String get hideTechnicalDetails => 'Hide technical details';

  @override
  String get couldNotLaunchEmail => 'Could not launch email client';

  @override
  String failedToOpenEmail(String error) {
    return 'Failed to open email: $error';
  }

  @override
  String get addNote => 'Add Note';

  @override
  String get editNote => 'Edit Note';

  @override
  String get addNoteHint => 'Add a note...';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get selected => 'Selected';

  @override
  String get viewDetails => 'View Details';

  @override
  String get moveToPublic => 'Move to Public';

  @override
  String get moveToPrivate => 'Move to Private';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get appTitle => 'Nyan Read ฅ^•ﻌ•^ฅ';

  @override
  String get enjoyReading => 'Enjoy your reading';

  @override
  String get bookshelf => 'Bookshelf';

  @override
  String get listView => 'List View';

  @override
  String get gridView => 'Grid View';

  @override
  String get sort => 'Sort';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortShelfBy => 'Sort shelf by';

  @override
  String get sortOrderAsc => 'Ascending';

  @override
  String get sortOrderDesc => 'Descending';

  @override
  String get lastReadAsc => 'Last Read Ascending';

  @override
  String get lastReadDesc => 'Last Read Descending';

  @override
  String get addedAsc => 'Added Ascending';

  @override
  String get addedDesc => 'Added Descending';

  @override
  String get titleAsc => 'Title Ascending';

  @override
  String get titleDesc => 'Title Descending';

  @override
  String get sortLastReadAscSub => 'Oldest opened first';

  @override
  String get sortLastReadDescSub => 'Recently opened first';

  @override
  String get sortTitleAscSub => 'A → Z';

  @override
  String get sortTitleDescSub => 'Z → A';

  @override
  String get sortAddedAscSub => 'Oldest first';

  @override
  String get sortAddedDescSub => 'Newest first';

  @override
  String get lockPrivacyShelf => 'Lock Privacy Shelf';

  @override
  String get unlockPrivacyShelf => 'Unlock Privacy Shelf';

  @override
  String deleteBooksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count books?',
      one: 'Remove $count book?',
    );
    return '$_temp0';
  }

  @override
  String get actionCannotBeUndone =>
      'They will be removed from the current shelf.';

  @override
  String get alsoDeleteLocalFiles => 'Also delete local files';

  @override
  String deletedBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count books',
      one: 'Removed $count book',
    );
    return '$_temp0';
  }

  @override
  String movedBooks(int count, String shelf) {
    return 'Moved $count books into $shelf';
  }

  @override
  String get emptyPrivateShelf =>
      'This private space is empty.\nSelect books from the public shelf and tap the Lock icon to move them here.';

  @override
  String get emptyShelfInstructions =>
      'Your shelf is empty!\nTap the + button below to import some books.';

  @override
  String get importFiles => 'Import Files';

  @override
  String get importBooksTitle => 'Import Books';

  @override
  String get importBooksSubtitle => 'Add more books to your shelf.';

  @override
  String get importBooksEmptySubtitle => 'Add your first book to get started.';

  @override
  String get importFilesSubtitle => 'Browse and open .txt, .epub or .pdf';

  @override
  String get supportedFormats => 'Supported Formats';

  @override
  String get supportedFormatsSubtitle =>
      'Plain text, e-book, and document files.';

  @override
  String get supportedFormatsDescription =>
      'Nyan Read currently supports importing TXT, EPUB, and PDF files from your device.';

  @override
  String get importingBooksTitle => 'Importing';

  @override
  String get importingBooksSubtitle => 'Placing books onto your shelf...';

  @override
  String importedBooks(int count, String shelf) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count books',
      one: 'Imported $count book',
    );
    return '$_temp0';
  }

  @override
  String get emptyShelfMessage => 'It\'s empty here. Import a book?';

  @override
  String get privacyShelfLocked => 'Privacy Shelf Locked';

  @override
  String get setPrivacyPassword => 'Set Privacy Password';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get unlockPrivacyShelfTitle => 'Unlock Privacy Shelf';

  @override
  String get invalidPassword => 'Invalid Password';

  @override
  String get unlock => 'Unlock';

  @override
  String get pinEnter => 'Enter PIN';

  @override
  String get pinSet => 'Set PIN';

  @override
  String get pinConfirm => 'Confirm PIN';

  @override
  String get pinMismatch => 'PINs don\'t match — try again';

  @override
  String get fontSize => 'Font Size';

  @override
  String get lineHeight => 'Line Height';

  @override
  String get themeCream => 'Cream';

  @override
  String get themeSepia => 'Sepia';

  @override
  String get themeSumi => 'Sumi';

  @override
  String get themeCharcoal => 'Charcoal';

  @override
  String get readerMenuDisplay => 'Display';

  @override
  String get readerMenuText => 'Text';

  @override
  String get readerMenuTheme => 'Theme';

  @override
  String get readingTheme => 'Reading Theme';

  @override
  String readerSheetProgressSubtitle(String percent) {
    return 'Reading progress $percent';
  }

  @override
  String get readerBrightness => 'Brightness';

  @override
  String get readerSoftwareDimModeActive => 'Screen dim active';

  @override
  String get readerBrightnessHint => 'Adjust the reading light';

  @override
  String get readerWarmth => 'Warmth';

  @override
  String get readerWarmthHint => 'Reduce glare at night';

  @override
  String get readerFollowSystemBrightness => 'Follow system brightness';

  @override
  String get readerAutoBrightness => 'Auto';

  @override
  String get readerBrightnessFollowingSystem => 'Following system brightness';

  @override
  String get readerTypographyFineTune => 'Fine-tune';

  @override
  String get readerTypographyFineTuneSubtitle => 'Font size and line height';

  @override
  String get readerFontSizeHint => 'Larger or smaller';

  @override
  String get readerLineHeightHint => 'Line spacing rhythm';

  @override
  String get readerBrightnessDim => 'Dim';

  @override
  String get readerBrightnessNormal => 'Normal';

  @override
  String get readerBrightnessBright => 'Bright';

  @override
  String get readerWarmthLow => 'Low';

  @override
  String get readerWarmthMedium => 'Medium';

  @override
  String get readerWarmthHigh => 'High';

  @override
  String get readerTypographyCompact => 'Compact';

  @override
  String get readerTypographyStandard => 'Standard';

  @override
  String get readerTypographyComfortable => 'Comfortable';

  @override
  String get readerTypographyPreviewSample =>
      'The quick brown fox jumps over the lazy dog.';

  @override
  String readerResetSection(String section) {
    return 'Reset $section';
  }

  @override
  String get readerResetAppearance => 'Reset to defaults';

  @override
  String get readerResetAppearanceHint =>
      'Font, spacing, theme, warmth, and brightness mode';

  @override
  String get readerResetCurrentTab => 'Reset this tab';

  @override
  String get readerResetCurrentTabHint => 'Only the current section';

  @override
  String get readerResetAll => 'Reset all';

  @override
  String get readerResetAllConfirmTitle => 'Reset all reading appearance?';

  @override
  String get readerResetAllConfirmMessage =>
      'This restores defaults for font, spacing, theme, warmth, and brightness.';

  @override
  String get readerResetAllConfirmAction => 'Reset all';

  @override
  String get tableOfContents => 'Table of Contents';

  @override
  String readerSettingsProgressHint(Object pct) {
    return 'Reading progress $pct%';
  }

  @override
  String chapterOfCount(int current, int total) {
    return 'Chapter $current of $total';
  }

  @override
  String get readerDockChapters => 'Chapters';

  @override
  String get readerDockHighlights => 'Highlights';

  @override
  String get jumpToCurrentChapter => 'Jump to current';

  @override
  String chapterListProgressLabel(int current, int total) {
    return '$current / $total chapters';
  }

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get highlightsAndNotes => 'Highlights & Notes';

  @override
  String allBooksInLibrary(int count) {
    return 'All books already in library ($count duplicates skipped).';
  }

  @override
  String duplicatesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skipped $count duplicate items.',
      one: 'Skipped $count duplicate item.',
    );
    return '$_temp0';
  }

  @override
  String get noChaptersDetected => 'No chapters detected';

  @override
  String chapterCount(int count) {
    return '$count chapters';
  }

  @override
  String chapterName(int index) {
    return 'Chapter $index';
  }

  @override
  String bookmarksTitle(int count) {
    return 'Bookmarks ($count)';
  }

  @override
  String bookmarksSavedCount(int count) {
    return '$count saved';
  }

  @override
  String get noBookmarksYet => 'No bookmarks yet';

  @override
  String get bookmarkContextTitle => 'Reading marks';

  @override
  String get bookmarkContextDescription =>
      'Tap a passage to return. Swipe left to delete.';

  @override
  String get bookmarkEmptyDescription =>
      'Passages worth returning to will gather here.';

  @override
  String get bookmarkEmptyHint => 'Tap the bookmark while reading to save one.';

  @override
  String get bookmarkNoteTag => 'Note';

  @override
  String bookmarkName(int index) {
    return 'Bookmark #$index';
  }

  @override
  String failedToDeleteBookmark(String error) {
    return 'Failed to delete bookmark: $error';
  }

  @override
  String get bookmarkAdded => 'Bookmark added';

  @override
  String notesAndHighlightsTitle(int count) {
    return 'Notes & Highlights ($count)';
  }

  @override
  String get noHighlightsYet => 'No highlights yet';

  @override
  String get longPressToCreateHighlight =>
      'Long-press on text to create highlights';

  @override
  String highlightName(int index) {
    return 'Highlight #$index';
  }

  @override
  String paragraphIndex(int index) {
    return 'Paragraph $index';
  }

  @override
  String get themeCreamLight => 'Cream Light';

  @override
  String get themeCreamLightHint => 'Warm paper — the default';

  @override
  String get themeSumiDark => 'Sumi Dark';

  @override
  String get themeSumiDarkHint => 'Ink night for low light';

  @override
  String get themeMatchSystem => 'Match System';

  @override
  String get themeMatchSystemHint => 'Follow your device setting';

  @override
  String get pageTurnLeftRight => 'Left & Right';

  @override
  String get pageTurnLeftRightHint => 'Turn pages horizontally';

  @override
  String get pageTurnUpDown => 'Up & Down';

  @override
  String get pageTurnUpDownHint => 'Turn pages vertically';

  @override
  String get languageEnglishHint => 'English';

  @override
  String get languageChineseHint => 'Chinese · 简体中文';

  @override
  String get timeToday => 'Today';

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get timeThreeDaysAgo => '3 days ago';

  @override
  String get timeSevenDaysAgo => '7 days ago';

  @override
  String get timeLongAgo => 'Long ago';

  @override
  String get neverRead => 'Never read';

  @override
  String get errorFileNotFoundTitle => 'This book lost its way';

  @override
  String get errorFileNotFoundBody =>
      'The file can\'t be found — it may have been moved or deleted.';

  @override
  String get errorUnsupportedFormatTitle => 'Nyan can\'t read this format';

  @override
  String get errorUnsupportedFormatBody =>
      'This file type isn\'t supported yet.';

  @override
  String get errorParseFailedTitle => 'These pages are stuck together';

  @override
  String get errorParseFailedBody =>
      'We couldn\'t open this file. It might be corrupted.';

  @override
  String get errorUnknownTitle => 'Something went wrong';

  @override
  String get errorUnknownBody =>
      'An unexpected error occurred. Please try again.';

  @override
  String get emptyShelfTitle => 'Bookshelf is waiting for stories';

  @override
  String get emptyShelfSubtitle => 'Import a book to start reading';

  @override
  String get exportData => 'Export Data';

  @override
  String get exportDataSubtitle => 'Save to device or share';

  @override
  String get exportDataSheetSubtitle => 'Choose where your reading data goes.';

  @override
  String get saveToDevice => 'Save to Device';

  @override
  String get saveToDeviceSubtitle => 'Store a JSON backup in your Files';

  @override
  String get shareVia => 'Share...';

  @override
  String get shareViaSubtitle => 'Send via Gmail, Drive or another app';

  @override
  String get importData => 'Import Data';

  @override
  String get importDataSubtitle => 'Restore from a backup file';

  @override
  String importSuccess(int count) {
    return 'Successfully restored $count books!';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }
}
