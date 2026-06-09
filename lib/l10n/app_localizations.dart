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

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themePreset.
  ///
  /// In en, this message translates to:
  /// **'Theme Preset'**
  String get themePreset;

  /// No description provided for @themePresetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How Nyan Read looks while you read.'**
  String get themePresetSubtitle;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading Settings'**
  String get readingSettings;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @readerQuickProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter seek and position'**
  String get readerQuickProgressSubtitle;

  /// No description provided for @readerQuickToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks, notes, and full settings'**
  String get readerQuickToolsSubtitle;

  /// No description provided for @readerQuickOpenFullSettings.
  ///
  /// In en, this message translates to:
  /// **'All settings'**
  String get readerQuickOpenFullSettings;

  /// No description provided for @readerMenuBackToQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get readerMenuBackToQuick;

  /// No description provided for @readerEdgeBrightnessOn.
  ///
  /// In en, this message translates to:
  /// **'Left edge brightness: on'**
  String get readerEdgeBrightnessOn;

  /// No description provided for @readerEdgeBrightnessOff.
  ///
  /// In en, this message translates to:
  /// **'Left edge brightness: off'**
  String get readerEdgeBrightnessOff;

  /// No description provided for @pageTurnMode.
  ///
  /// In en, this message translates to:
  /// **'Page Turn Mode'**
  String get pageTurnMode;

  /// No description provided for @pageTurnModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The direction pages move as you read.'**
  String get pageTurnModeSubtitle;

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

  /// No description provided for @pageTurnModeLeftRight.
  ///
  /// In en, this message translates to:
  /// **'Left-right'**
  String get pageTurnModeLeftRight;

  /// No description provided for @pageTurnModeUpDown.
  ///
  /// In en, this message translates to:
  /// **'Up-down'**
  String get pageTurnModeUpDown;

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

  /// No description provided for @readerFontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get readerFontFamily;

  /// No description provided for @readerFontFamilySans.
  ///
  /// In en, this message translates to:
  /// **'Sans'**
  String get readerFontFamilySans;

  /// No description provided for @readerFontFamilySerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get readerFontFamilySerif;

  /// No description provided for @pageAnimation.
  ///
  /// In en, this message translates to:
  /// **'Page Animation'**
  String get pageAnimation;

  /// No description provided for @pageAnimationFade.
  ///
  /// In en, this message translates to:
  /// **'Directional fade transition'**
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
  /// **'Directional Fade'**
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
  /// **'Chapter seek and position'**
  String get readingReminderSubtitle;

  /// No description provided for @reminderInterval.
  ///
  /// In en, this message translates to:
  /// **'Reminder Interval'**
  String get reminderInterval;

  /// No description provided for @reminderIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often to nudge you back to reading.'**
  String get reminderIntervalSubtitle;

  /// No description provided for @reminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String reminderMinutes(int minutes);

  /// No description provided for @reminderEvery15min.
  ///
  /// In en, this message translates to:
  /// **'Every 15 min'**
  String get reminderEvery15min;

  /// No description provided for @reminderEvery30min.
  ///
  /// In en, this message translates to:
  /// **'Every 30 min'**
  String get reminderEvery30min;

  /// No description provided for @reminderEveryHour.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get reminderEveryHour;

  /// No description provided for @reminderEvery2hours.
  ///
  /// In en, this message translates to:
  /// **'Every 2 hours'**
  String get reminderEvery2hours;

  /// No description provided for @reminderDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get reminderDaily;

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
  /// **'Remove source files when deleting a book'**
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
  /// **'Shown in the free version'**
  String get adsSubtitle;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @upgradeToProSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Privacy Shelf and more'**
  String get upgradeToProSubtitle;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @lockPrivacyShelfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require PIN to open'**
  String get lockPrivacyShelfSubtitle;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel;

  /// No description provided for @adminPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin / Manager Mode'**
  String get adminPanelTitle;

  /// No description provided for @adminPanelModeSection.
  ///
  /// In en, this message translates to:
  /// **'Mode Control'**
  String get adminPanelModeSection;

  /// No description provided for @adminProModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Pro Mode Enabled'**
  String get adminProModeEnabled;

  /// No description provided for @adminProModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlocks Privacy Shelf and disables ads'**
  String get adminProModeSubtitle;

  /// No description provided for @adminForceUnlockPrivacyShelf.
  ///
  /// In en, this message translates to:
  /// **'Force Unlock Privacy Shelf'**
  String get adminForceUnlockPrivacyShelf;

  /// No description provided for @adminForceUnlockPrivacyShelfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bypass password verification'**
  String get adminForceUnlockPrivacyShelfSubtitle;

  /// No description provided for @adminFeatureFlagsSection.
  ///
  /// In en, this message translates to:
  /// **'Feature Flags'**
  String get adminFeatureFlagsSection;

  /// No description provided for @adminStateOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get adminStateOn;

  /// No description provided for @adminStateOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get adminStateOff;

  /// No description provided for @adminPanelHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Internal control panel'**
  String get adminPanelHintTitle;

  /// No description provided for @adminPanelHintSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this page for debugging and capability verification.'**
  String get adminPanelHintSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App display language.'**
  String get languageSubtitle;

  /// No description provided for @bookDetails.
  ///
  /// In en, this message translates to:
  /// **'Book Details'**
  String get bookDetails;

  /// No description provided for @bookDetailsOverviewSection.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get bookDetailsOverviewSection;

  /// No description provided for @bookDetailsSourceSection.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get bookDetailsSourceSection;

  /// No description provided for @originalPath.
  ///
  /// In en, this message translates to:
  /// **'Original Path'**
  String get originalPath;

  /// No description provided for @unknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get unknownAuthor;

  /// No description provided for @readyToStart.
  ///
  /// In en, this message translates to:
  /// **'Ready to start'**
  String get readyToStart;

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

  /// No description provided for @bookFormatEpub.
  ///
  /// In en, this message translates to:
  /// **'EPUB'**
  String get bookFormatEpub;

  /// No description provided for @bookFormatTxt.
  ///
  /// In en, this message translates to:
  /// **'TXT'**
  String get bookFormatTxt;

  /// No description provided for @bookFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get bookFormatPdf;

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

  /// No description provided for @lastOpened.
  ///
  /// In en, this message translates to:
  /// **'Last Opened'**
  String get lastOpened;

  /// No description provided for @bookDetailsSourceSummaryDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved from Downloads'**
  String get bookDetailsSourceSummaryDownloads;

  /// No description provided for @bookDetailsSourceSummaryImported.
  ///
  /// In en, this message translates to:
  /// **'Imported file'**
  String get bookDetailsSourceSummaryImported;

  /// No description provided for @bookDetailsFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Title'**
  String get bookDetailsFullTitle;

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

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get continueReading;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
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

  /// No description provided for @fileUnavailableCta.
  ///
  /// In en, this message translates to:
  /// **'File unavailable'**
  String get fileUnavailableCta;

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
  /// **'Report to developer'**
  String get reportToDeveloper;

  /// No description provided for @showTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Show technical details'**
  String get showTechnicalDetails;

  /// No description provided for @hideTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide technical details'**
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
  /// **'Add a note...'**
  String get addNoteHint;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get deleteNote;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

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
  /// **'Enjoy your reading'**
  String get enjoyReading;

  /// No description provided for @bookshelf.
  ///
  /// In en, this message translates to:
  /// **'Bookshelf'**
  String get bookshelf;

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

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortOrderAsc.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortOrderAsc;

  /// No description provided for @sortOrderDesc.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortOrderDesc;

  /// No description provided for @lastReadAsc.
  ///
  /// In en, this message translates to:
  /// **'Last Read Ascending'**
  String get lastReadAsc;

  /// No description provided for @lastReadDesc.
  ///
  /// In en, this message translates to:
  /// **'Last Read Descending'**
  String get lastReadDesc;

  /// No description provided for @addedAsc.
  ///
  /// In en, this message translates to:
  /// **'Added Ascending'**
  String get addedAsc;

  /// No description provided for @addedDesc.
  ///
  /// In en, this message translates to:
  /// **'Added Descending'**
  String get addedDesc;

  /// No description provided for @titleAsc.
  ///
  /// In en, this message translates to:
  /// **'Title Ascending'**
  String get titleAsc;

  /// No description provided for @titleDesc.
  ///
  /// In en, this message translates to:
  /// **'Title Descending'**
  String get titleDesc;

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
  /// **'{count, plural, one{Remove {count} book?} other{Remove {count} books?}}'**
  String deleteBooksTitle(int count);

  /// No description provided for @actionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'They will be removed from the current shelf.'**
  String get actionCannotBeUndone;

  /// No description provided for @alsoDeleteLocalFiles.
  ///
  /// In en, this message translates to:
  /// **'Also delete local files'**
  String get alsoDeleteLocalFiles;

  /// No description provided for @deletedBooks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Removed {count} book} other{Removed {count} books}}'**
  String deletedBooks(int count);

  /// No description provided for @movedBooks.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} books into {shelf}'**
  String movedBooks(int count, String shelf);

  /// No description provided for @emptyPrivateShelf.
  ///
  /// In en, this message translates to:
  /// **'This private space is empty.\nSelect books from the public shelf and tap the Lock icon to move them here.'**
  String get emptyPrivateShelf;

  /// No description provided for @emptyShelfInstructions.
  ///
  /// In en, this message translates to:
  /// **'Your shelf is empty!\nTap the + button below to import some books.'**
  String get emptyShelfInstructions;

  /// No description provided for @importFiles.
  ///
  /// In en, this message translates to:
  /// **'Import Files'**
  String get importFiles;

  /// No description provided for @importBooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Books'**
  String get importBooksTitle;

  /// No description provided for @importBooksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add more books to your shelf.'**
  String get importBooksSubtitle;

  /// No description provided for @importBooksEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first book to get started.'**
  String get importBooksEmptySubtitle;

  /// No description provided for @importFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and open .txt, .epub or .pdf'**
  String get importFilesSubtitle;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported Formats'**
  String get supportedFormats;

  /// No description provided for @supportedFormatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plain text, e-book, and document files.'**
  String get supportedFormatsSubtitle;

  /// No description provided for @supportedFormatsDescription.
  ///
  /// In en, this message translates to:
  /// **'Nyan Read currently supports importing TXT, EPUB, and PDF files from your device.'**
  String get supportedFormatsDescription;

  /// No description provided for @importingBooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get importingBooksTitle;

  /// No description provided for @importingBooksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Placing books onto your shelf...'**
  String get importingBooksSubtitle;

  /// No description provided for @importedBooks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Imported {count} book} other{Imported {count} books}}'**
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

  /// No description provided for @pinEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get pinEnter;

  /// No description provided for @pinSet.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get pinSet;

  /// No description provided for @pinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirm;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match — try again'**
  String get pinMismatch;

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

  /// No description provided for @readerMenuDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get readerMenuDisplay;

  /// No description provided for @readerMenuText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get readerMenuText;

  /// No description provided for @readerMenuTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get readerMenuTheme;

  /// No description provided for @readingTheme.
  ///
  /// In en, this message translates to:
  /// **'Reading Theme'**
  String get readingTheme;

  /// No description provided for @readerSheetProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reading progress {percent}'**
  String readerSheetProgressSubtitle(String percent);

  /// No description provided for @readerBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get readerBrightness;

  /// No description provided for @readerSoftwareDimModeActive.
  ///
  /// In en, this message translates to:
  /// **'Screen dim active'**
  String get readerSoftwareDimModeActive;

  /// No description provided for @readerBrightnessHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust the reading light'**
  String get readerBrightnessHint;

  /// No description provided for @readerWarmth.
  ///
  /// In en, this message translates to:
  /// **'Warmth'**
  String get readerWarmth;

  /// No description provided for @readerWarmthHint.
  ///
  /// In en, this message translates to:
  /// **'Reduce glare at night'**
  String get readerWarmthHint;

  /// No description provided for @readerFollowSystemBrightness.
  ///
  /// In en, this message translates to:
  /// **'Follow system brightness'**
  String get readerFollowSystemBrightness;

  /// No description provided for @readerAutoBrightness.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get readerAutoBrightness;

  /// No description provided for @readerBrightnessFollowingSystem.
  ///
  /// In en, this message translates to:
  /// **'Following system brightness'**
  String get readerBrightnessFollowingSystem;

  /// No description provided for @readerTypographyFineTune.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune'**
  String get readerTypographyFineTune;

  /// No description provided for @readerTypographyFineTuneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Font size and line height'**
  String get readerTypographyFineTuneSubtitle;

  /// No description provided for @readerFontSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Larger or smaller'**
  String get readerFontSizeHint;

  /// No description provided for @readerLineHeightHint.
  ///
  /// In en, this message translates to:
  /// **'Line spacing rhythm'**
  String get readerLineHeightHint;

  /// No description provided for @readerBrightnessDim.
  ///
  /// In en, this message translates to:
  /// **'Dim'**
  String get readerBrightnessDim;

  /// No description provided for @readerBrightnessNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get readerBrightnessNormal;

  /// No description provided for @readerBrightnessBright.
  ///
  /// In en, this message translates to:
  /// **'Bright'**
  String get readerBrightnessBright;

  /// No description provided for @readerWarmthLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get readerWarmthLow;

  /// No description provided for @readerWarmthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get readerWarmthMedium;

  /// No description provided for @readerWarmthHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get readerWarmthHigh;

  /// No description provided for @readerTypographyCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get readerTypographyCompact;

  /// No description provided for @readerTypographyStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get readerTypographyStandard;

  /// No description provided for @readerTypographyComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get readerTypographyComfortable;

  /// No description provided for @readerTypographyPreviewSample.
  ///
  /// In en, this message translates to:
  /// **'The quick brown fox jumps over the lazy dog.'**
  String get readerTypographyPreviewSample;

  /// Per-tab reset button label in the reader settings sheet. {section} is the tab name (Display / Text / Theme).
  ///
  /// In en, this message translates to:
  /// **'Reset {section}'**
  String readerResetSection(String section);

  /// No description provided for @readerResetAppearance.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get readerResetAppearance;

  /// No description provided for @readerResetAppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Font, spacing, theme, warmth, and brightness mode'**
  String get readerResetAppearanceHint;

  /// No description provided for @readerResetCurrentTab.
  ///
  /// In en, this message translates to:
  /// **'Reset this tab'**
  String get readerResetCurrentTab;

  /// No description provided for @readerResetCurrentTabHint.
  ///
  /// In en, this message translates to:
  /// **'Only the current section'**
  String get readerResetCurrentTabHint;

  /// No description provided for @readerResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get readerResetAll;

  /// No description provided for @readerResetAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all reading appearance?'**
  String get readerResetAllConfirmTitle;

  /// No description provided for @readerResetAllConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This restores defaults for font, spacing, theme, warmth, and brightness.'**
  String get readerResetAllConfirmMessage;

  /// No description provided for @readerResetAllConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get readerResetAllConfirmAction;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get tableOfContents;

  /// Meta text shown on the right of the Reader Settings sheet header. {pct} is replaced with the rounded reading-progress percentage.
  ///
  /// In en, this message translates to:
  /// **'Reading progress {pct}%'**
  String readerSettingsProgressHint(Object pct);

  /// No description provided for @chapterOfCount.
  ///
  /// In en, this message translates to:
  /// **'Chapter {current} of {total}'**
  String chapterOfCount(int current, int total);

  /// Short label for the Chapters tile in the reader bottom dock (must fit alongside 4 other tiles in a narrow strip).
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get readerDockChapters;

  /// Short label for the Highlights tile in the reader bottom dock (must fit alongside 3 other tiles in a narrow strip).
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get readerDockHighlights;

  /// No description provided for @jumpToCurrentChapter.
  ///
  /// In en, this message translates to:
  /// **'Jump to current'**
  String get jumpToCurrentChapter;

  /// No description provided for @chapterListProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total} chapters'**
  String chapterListProgressLabel(int current, int total);

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

  /// No description provided for @allBooksInLibrary.
  ///
  /// In en, this message translates to:
  /// **'All books already in library ({count} duplicates skipped).'**
  String allBooksInLibrary(int count);

  /// No description provided for @duplicatesSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Skipped {count} duplicate item.} other{Skipped {count} duplicate items.}}'**
  String duplicatesSkipped(int count);

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

  /// No description provided for @bookmarksSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved'**
  String bookmarksSavedCount(int count);

  /// No description provided for @noBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get noBookmarksYet;

  /// No description provided for @bookmarkContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading marks'**
  String get bookmarkContextTitle;

  /// No description provided for @bookmarkContextDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap a passage to return. Swipe left to delete.'**
  String get bookmarkContextDescription;

  /// No description provided for @bookmarkEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Passages worth returning to will gather here.'**
  String get bookmarkEmptyDescription;

  /// No description provided for @bookmarkEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark while reading to save one.'**
  String get bookmarkEmptyHint;

  /// No description provided for @bookmarkNoteTag.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get bookmarkNoteTag;

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

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmark added'**
  String get bookmarkAdded;

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

  /// No description provided for @themeCreamLightHint.
  ///
  /// In en, this message translates to:
  /// **'Warm paper — the default'**
  String get themeCreamLightHint;

  /// No description provided for @themeSumiDark.
  ///
  /// In en, this message translates to:
  /// **'Sumi Dark'**
  String get themeSumiDark;

  /// No description provided for @themeSumiDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Ink night for low light'**
  String get themeSumiDarkHint;

  /// No description provided for @themeMatchSystem.
  ///
  /// In en, this message translates to:
  /// **'Match System'**
  String get themeMatchSystem;

  /// No description provided for @themeMatchSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Follow your device setting'**
  String get themeMatchSystemHint;

  /// No description provided for @pageTurnLeftRight.
  ///
  /// In en, this message translates to:
  /// **'Left & Right'**
  String get pageTurnLeftRight;

  /// No description provided for @pageTurnLeftRightHint.
  ///
  /// In en, this message translates to:
  /// **'Turn pages horizontally'**
  String get pageTurnLeftRightHint;

  /// No description provided for @pageTurnUpDown.
  ///
  /// In en, this message translates to:
  /// **'Up & Down'**
  String get pageTurnUpDown;

  /// No description provided for @pageTurnUpDownHint.
  ///
  /// In en, this message translates to:
  /// **'Turn pages vertically'**
  String get pageTurnUpDownHint;

  /// No description provided for @languageEnglishHint.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishHint;

  /// No description provided for @languageChineseHint.
  ///
  /// In en, this message translates to:
  /// **'Chinese · 简体中文'**
  String get languageChineseHint;

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

  /// No description provided for @errorFileNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'This book lost its way'**
  String get errorFileNotFoundTitle;

  /// No description provided for @errorFileNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The file can\'t be found — it may have been moved or deleted.'**
  String get errorFileNotFoundBody;

  /// No description provided for @errorUnsupportedFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Nyan can\'t read this format'**
  String get errorUnsupportedFormatTitle;

  /// No description provided for @errorUnsupportedFormatBody.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported yet.'**
  String get errorUnsupportedFormatBody;

  /// No description provided for @errorParseFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'These pages are stuck together'**
  String get errorParseFailedTitle;

  /// No description provided for @errorParseFailedBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open this file. It might be corrupted.'**
  String get errorParseFailedBody;

  /// No description provided for @errorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknownTitle;

  /// No description provided for @errorUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorUnknownBody;

  /// No description provided for @emptyShelfTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookshelf is waiting for stories'**
  String get emptyShelfTitle;

  /// No description provided for @emptyShelfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a book to start reading'**
  String get emptyShelfSubtitle;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save to device or share'**
  String get exportDataSubtitle;

  /// No description provided for @exportDataSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose where your reading data goes.'**
  String get exportDataSheetSubtitle;

  /// No description provided for @saveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to Device'**
  String get saveToDevice;

  /// No description provided for @saveToDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store a JSON backup in your Files'**
  String get saveToDeviceSubtitle;

  /// No description provided for @shareVia.
  ///
  /// In en, this message translates to:
  /// **'Share...'**
  String get shareVia;

  /// No description provided for @shareViaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send via Gmail, Drive or another app'**
  String get shareViaSubtitle;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @importDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup file'**
  String get importDataSubtitle;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully restored {count} books!'**
  String importSuccess(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);
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
