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
  String get themePreset => 'Theme Preset';

  @override
  String get readingSettings => 'Reading Settings';

  @override
  String get pageTurnMode => 'Page Turn Mode';

  @override
  String get pageTurnModeTap => 'Tap to turn pages';

  @override
  String get pageTurnModeSwipe => 'Swipe to turn pages';

  @override
  String get pageTurnModeDisabled => 'Page turning disabled';

  @override
  String get pageTurnTap => 'Tap';

  @override
  String get pageTurnSwipe => 'Swipe';

  @override
  String get pageTurnDisabled => 'Disabled';

  @override
  String get pageAnimation => 'Page Animation';

  @override
  String get pageAnimationFade => 'Smooth fade transition';

  @override
  String get pageAnimationPaper => 'Subtle paper effect';

  @override
  String get pageAnimationNone => 'No animation';

  @override
  String get pageAnimFade => 'Fade';

  @override
  String get pageAnimPaper => 'Paper';

  @override
  String get pageAnimNone => 'None';

  @override
  String get readingReminder => 'Reading Reminder';

  @override
  String get readingReminderSubtitle => 'Remind me to take a break';

  @override
  String get reminderInterval => 'Reminder Interval';

  @override
  String reminderMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get dataManagement => 'Data Management';

  @override
  String get deleteFilesOnRemove => 'Delete Files on Remove';

  @override
  String get deleteFilesOnRemoveSubtitle =>
      'Also delete local files when deleting books';

  @override
  String get lockPrivateShelf => 'Lock Private Shelf';

  @override
  String get tts => 'TTS (Text-to-Speech)';

  @override
  String get ads => 'Ads';

  @override
  String get adsSubtitle => 'Show Ads (Free Version)';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get adminPanel => 'Admin Panel';

  @override
  String get language => 'Language';

  @override
  String get bookDetails => 'Book Details';

  @override
  String get title => 'Title';

  @override
  String get author => 'Author';

  @override
  String get format => 'Format';

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
  String get fileLocation => 'File Location';

  @override
  String get startReading => 'Start Reading';

  @override
  String get copyPath => 'Copy path';

  @override
  String get filePathCopied => 'File path copied to clipboard';

  @override
  String get fileExists => 'File exists';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get unknown => 'Unknown';

  @override
  String get never => 'Never';

  @override
  String get backToBookshelf => 'Back to Bookshelf';

  @override
  String get retry => 'Retry';

  @override
  String get reportToDeveloper => 'Report to Developer';

  @override
  String get showTechnicalDetails => 'Show Technical Details';

  @override
  String get hideTechnicalDetails => 'Hide Technical Details';

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
  String get addNoteHint => 'Add your note here...';

  @override
  String get delete => 'Delete';

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
  String get enjoyReading => 'Enjoy reading time';

  @override
  String get listView => 'List View';

  @override
  String get gridView => 'Grid View';

  @override
  String get sort => 'Sort';

  @override
  String get lockPrivacyShelf => 'Lock Privacy Shelf';

  @override
  String get unlockPrivacyShelf => 'Unlock Privacy Shelf';

  @override
  String deleteBooksTitle(int count) {
    return '⚠️ Delete $count Books?';
  }

  @override
  String get actionCannotBeUndone => 'This action cannot be undone.';

  @override
  String get alsoDeleteLocalFiles => 'Also delete local files';

  @override
  String deletedBooks(int count) {
    return 'Deleted $count books';
  }

  @override
  String movedBooks(int count, String shelf) {
    return 'Moved $count books into $shelf';
  }

  @override
  String get importFiles => 'Import Files';

  @override
  String get importFolder => 'Import Folder';

  @override
  String importedBooks(int count, String shelf) {
    return 'Imported $count books into $shelf!';
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
  String get tableOfContents => 'Table of Contents';

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get highlightsAndNotes => 'Highlights & Notes';

  @override
  String get noSupportedBooksFound => 'No supported books found.';

  @override
  String scannedFiles(int count) {
    return 'Scanned $count.';
  }

  @override
  String skippedExtensions(String extensions) {
    return 'Skipped: $extensions';
  }

  @override
  String allBooksInLibrary(int count) {
    return 'All books already in library ($count duplicates skipped).';
  }

  @override
  String duplicatesSkipped(int count) {
    return '$count duplicates skipped.';
  }

  @override
  String errorScanningFolder(String error) {
    return 'Error scanning folder: $error';
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
  String get noBookmarksYet => 'No bookmarks yet';

  @override
  String bookmarkName(int index) {
    return 'Bookmark #$index';
  }

  @override
  String failedToDeleteBookmark(String error) {
    return 'Failed to delete bookmark: $error';
  }

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
  String get themeSumiDark => 'Sumi Dark';

  @override
  String get themeSepiaWarm => 'Sepia Warm';

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
  String get errorFileNotFound =>
      'This book seems to have lost its way.\nThe file cannot be found, it may have been moved or deleted.';

  @override
  String get errorUnsupportedFormat =>
      'Nyan cannot read this format.\nThis file type is not supported yet.';

  @override
  String get errorParseFailed =>
      'The pages are stuck together.\nFailed to parse file, it might be corrupted.';

  @override
  String get errorUnknown =>
      'Something unexpected happened.\nPlease try again later.';
}
