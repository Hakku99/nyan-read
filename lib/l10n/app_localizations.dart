import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @themePreset.
  ///
  /// In en, this message translates to:
  /// **'Theme Preset'**
  String get themePreset;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading Settings'**
  String get readingSettings;

  /// No description provided for @pageTurnMode.
  ///
  /// In en, this message translates to:
  /// **'Page Turn Mode'**
  String get pageTurnMode;

  /// No description provided for @pageTurnModeTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to turn pages'**
  String get pageTurnModeTap;

  /// No description provided for @pageTurnModeSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe to turn pages'**
  String get pageTurnModeSwipe;

  /// No description provided for @pageTurnModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Page turning disabled'**
  String get pageTurnModeDisabled;

  /// No description provided for @pageTurnTap.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get pageTurnTap;

  /// No description provided for @pageTurnSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe'**
  String get pageTurnSwipe;

  /// No description provided for @pageTurnDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get pageTurnDisabled;

  /// No description provided for @pageAnimation.
  ///
  /// In en, this message translates to:
  /// **'Page Animation'**
  String get pageAnimation;

  /// No description provided for @pageAnimationFade.
  ///
  /// In en, this message translates to:
  /// **'Smooth fade transition'**
  String get pageAnimationFade;

  /// No description provided for @pageAnimationPaper.
  ///
  /// In en, this message translates to:
  /// **'Subtle paper effect'**
  String get pageAnimationPaper;

  /// No description provided for @pageAnimationNone.
  ///
  /// In en, this message translates to:
  /// **'No animation'**
  String get pageAnimationNone;

  /// No description provided for @pageAnimFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get pageAnimFade;

  /// No description provided for @pageAnimPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get pageAnimPaper;

  /// No description provided for @pageAnimNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get pageAnimNone;

  /// No description provided for @readingReminder.
  ///
  /// In en, this message translates to:
  /// **'Reading Reminder'**
  String get readingReminder;

  /// No description provided for @readingReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remind me to take a break'**
  String get readingReminderSubtitle;

  /// No description provided for @reminderInterval.
  ///
  /// In en, this message translates to:
  /// **'Reminder Interval'**
  String get reminderInterval;

  /// No description provided for @reminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String reminderMinutes(int minutes);

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @deleteFilesOnRemove.
  ///
  /// In en, this message translates to:
  /// **'Delete Files on Remove'**
  String get deleteFilesOnRemove;

  /// No description provided for @deleteFilesOnRemoveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Also delete local files when deleting books'**
  String get deleteFilesOnRemoveSubtitle;

  /// No description provided for @lockPrivateShelf.
  ///
  /// In en, this message translates to:
  /// **'Lock Private Shelf'**
  String get lockPrivateShelf;

  /// No description provided for @tts.
  ///
  /// In en, this message translates to:
  /// **'TTS (Text-to-Speech)'**
  String get tts;

  /// No description provided for @ads.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get ads;

  /// No description provided for @adsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show Ads (Free Version)'**
  String get adsSubtitle;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @bookDetails.
  ///
  /// In en, this message translates to:
  /// **'Book Details'**
  String get bookDetails;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privateShelf.
  ///
  /// In en, this message translates to:
  /// **'Private Shelf'**
  String get privateShelf;

  /// No description provided for @publicShelf.
  ///
  /// In en, this message translates to:
  /// **'Public Shelf'**
  String get publicShelf;

  /// No description provided for @readingProgress.
  ///
  /// In en, this message translates to:
  /// **'Reading Progress'**
  String get readingProgress;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @lastRead.
  ///
  /// In en, this message translates to:
  /// **'Last Read'**
  String get lastRead;

  /// No description provided for @fileLocation.
  ///
  /// In en, this message translates to:
  /// **'File Location'**
  String get fileLocation;

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Start Reading'**
  String get startReading;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @filePathCopied.
  ///
  /// In en, this message translates to:
  /// **'File path copied to clipboard'**
  String get filePathCopied;

  /// No description provided for @fileExists.
  ///
  /// In en, this message translates to:
  /// **'File exists'**
  String get fileExists;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @backToBookshelf.
  ///
  /// In en, this message translates to:
  /// **'Back to Bookshelf'**
  String get backToBookshelf;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @reportToDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Report to Developer'**
  String get reportToDeveloper;

  /// No description provided for @showTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Show Technical Details'**
  String get showTechnicalDetails;

  /// No description provided for @hideTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide Technical Details'**
  String get hideTechnicalDetails;

  /// No description provided for @couldNotLaunchEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not launch email client'**
  String get couldNotLaunchEmail;

  /// No description provided for @failedToOpenEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to open email: {error}'**
  String failedToOpenEmail(String error);

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get editNote;

  /// No description provided for @addNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add your note here...'**
  String get addNoteHint;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @moveToPublic.
  ///
  /// In en, this message translates to:
  /// **'Move to Public'**
  String get moveToPublic;

  /// No description provided for @moveToPrivate.
  ///
  /// In en, this message translates to:
  /// **'Move to Private'**
  String get moveToPrivate;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Nyan Read ฅ^•ﻌ•^ฅ'**
  String get appTitle;

  /// No description provided for @enjoyReading.
  ///
  /// In en, this message translates to:
  /// **'Enjoy reading time'**
  String get enjoyReading;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid View'**
  String get gridView;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @lockPrivacyShelf.
  ///
  /// In en, this message translates to:
  /// **'Lock Privacy Shelf'**
  String get lockPrivacyShelf;

  /// No description provided for @unlockPrivacyShelf.
  ///
  /// In en, this message translates to:
  /// **'Unlock Privacy Shelf'**
  String get unlockPrivacyShelf;

  /// No description provided for @deleteBooksTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Delete {count} Books?'**
  String deleteBooksTitle(int count);

  /// No description provided for @actionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get actionCannotBeUndone;

  /// No description provided for @alsoDeleteLocalFiles.
  ///
  /// In en, this message translates to:
  /// **'Also delete local files'**
  String get alsoDeleteLocalFiles;

  /// No description provided for @deletedBooks.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} books'**
  String deletedBooks(int count);

  /// No description provided for @movedBooks.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} books to {shelf} Shelf'**
  String movedBooks(int count, String shelf);

  /// No description provided for @importFiles.
  ///
  /// In en, this message translates to:
  /// **'Import Files'**
  String get importFiles;

  /// No description provided for @importFolder.
  ///
  /// In en, this message translates to:
  /// **'Import Folder'**
  String get importFolder;

  /// No description provided for @importedBooks.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} books to {shelf} Shelf!'**
  String importedBooks(int count, String shelf);

  /// No description provided for @emptyShelfMessage.
  ///
  /// In en, this message translates to:
  /// **'It\'s empty here. Import a book?'**
  String get emptyShelfMessage;

  /// No description provided for @privacyShelfLocked.
  ///
  /// In en, this message translates to:
  /// **'Privacy Shelf Locked'**
  String get privacyShelfLocked;

  /// No description provided for @setPrivacyPassword.
  ///
  /// In en, this message translates to:
  /// **'Set Privacy Password'**
  String get setPrivacyPassword;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @unlockPrivacyShelfTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Privacy Shelf'**
  String get unlockPrivacyShelfTitle;

  /// No description provided for @invalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid Password'**
  String get invalidPassword;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @lineHeight.
  ///
  /// In en, this message translates to:
  /// **'Line Height'**
  String get lineHeight;

  /// No description provided for @themeCream.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get themeCream;

  /// No description provided for @themeSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get themeSepia;

  /// No description provided for @themeSumi.
  ///
  /// In en, this message translates to:
  /// **'Sumi'**
  String get themeSumi;

  /// No description provided for @themeCharcoal.
  ///
  /// In en, this message translates to:
  /// **'Charcoal'**
  String get themeCharcoal;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get tableOfContents;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add Bookmark'**
  String get addBookmark;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @highlightsAndNotes.
  ///
  /// In en, this message translates to:
  /// **'Highlights & Notes'**
  String get highlightsAndNotes;

  /// No description provided for @noSupportedBooksFound.
  ///
  /// In en, this message translates to:
  /// **'No supported books found.'**
  String get noSupportedBooksFound;

  /// No description provided for @scannedFiles.
  ///
  /// In en, this message translates to:
  /// **'Scanned {count}.'**
  String scannedFiles(int count);

  /// No description provided for @skippedExtensions.
  ///
  /// In en, this message translates to:
  /// **'Skipped: {extensions}'**
  String skippedExtensions(String extensions);

  /// No description provided for @allBooksInLibrary.
  ///
  /// In en, this message translates to:
  /// **'All books already in library ({count} duplicates skipped).'**
  String allBooksInLibrary(int count);

  /// No description provided for @duplicatesSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates skipped.'**
  String duplicatesSkipped(int count);

  /// No description provided for @errorScanningFolder.
  ///
  /// In en, this message translates to:
  /// **'Error scanning folder: {error}'**
  String errorScanningFolder(String error);

  /// No description provided for @noChaptersDetected.
  ///
  /// In en, this message translates to:
  /// **'No chapters detected'**
  String get noChaptersDetected;

  /// No description provided for @chapterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String chapterCount(int count);

  /// No description provided for @chapterName.
  ///
  /// In en, this message translates to:
  /// **'Chapter {index}'**
  String chapterName(int index);

  /// No description provided for @bookmarksTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks ({count})'**
  String bookmarksTitle(int count);

  /// No description provided for @noBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get noBookmarksYet;

  /// No description provided for @bookmarkName.
  ///
  /// In en, this message translates to:
  /// **'Bookmark #{index}'**
  String bookmarkName(int index);

  /// No description provided for @failedToDeleteBookmark.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete bookmark: {error}'**
  String failedToDeleteBookmark(String error);

  /// No description provided for @notesAndHighlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes & Highlights ({count})'**
  String notesAndHighlightsTitle(int count);

  /// No description provided for @noHighlightsYet.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet'**
  String get noHighlightsYet;

  /// No description provided for @longPressToCreateHighlight.
  ///
  /// In en, this message translates to:
  /// **'Long-press on text to create highlights'**
  String get longPressToCreateHighlight;

  /// No description provided for @highlightName.
  ///
  /// In en, this message translates to:
  /// **'Highlight #{index}'**
  String highlightName(int index);

  /// No description provided for @paragraphIndex.
  ///
  /// In en, this message translates to:
  /// **'Paragraph {index}'**
  String paragraphIndex(int index);

  /// No description provided for @themeCreamLight.
  ///
  /// In en, this message translates to:
  /// **'Cream Light'**
  String get themeCreamLight;

  /// No description provided for @themeSumiDark.
  ///
  /// In en, this message translates to:
  /// **'Sumi Dark'**
  String get themeSumiDark;

  /// No description provided for @themeSepiaWarm.
  ///
  /// In en, this message translates to:
  /// **'Sepia Warm'**
  String get themeSepiaWarm;

  /// No description provided for @timeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get timeToday;

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @timeThreeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'3 days ago'**
  String get timeThreeDaysAgo;

  /// No description provided for @timeSevenDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'7 days ago'**
  String get timeSevenDaysAgo;

  /// No description provided for @timeLongAgo.
  ///
  /// In en, this message translates to:
  /// **'Long ago'**
  String get timeLongAgo;

  /// No description provided for @neverRead.
  ///
  /// In en, this message translates to:
  /// **'Never read'**
  String get neverRead;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
