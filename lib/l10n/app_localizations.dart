import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Talking Calculator'**
  String get appTitle;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @advancedFunctions.
  ///
  /// In en, this message translates to:
  /// **'Advanced Functions'**
  String get advancedFunctions;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Calculation History'**
  String get historyTitle;

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'History is empty.'**
  String get emptyHistory;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'CLEAR HISTORY'**
  String get clearHistory;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear the entire history?'**
  String get deleteConfirmation;

  /// No description provided for @yesDelete.
  ///
  /// In en, this message translates to:
  /// **'YES, CLEAR'**
  String get yesDelete;

  /// No description provided for @noStay.
  ///
  /// In en, this message translates to:
  /// **'NO, KEEP'**
  String get noStay;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @understand.
  ///
  /// In en, this message translates to:
  /// **'UNDERSTAND'**
  String get understand;

  /// No description provided for @tutorialText.
  ///
  /// In en, this message translates to:
  /// **'This calculator supports scientific calculations, statistics, electrical formulas, and unit conversions. \n\nKeyboard shortcuts:\nS - Sine (Shift+S for Arcsine)\nC - Cosine (Shift+C for Arccosine)\nT - Tangent (Shift+T for Arctangent)\nP - Pi\nQ - Square root\nEnter - Result'**
  String get tutorialText;

  /// No description provided for @accessibilitySettings.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Settings'**
  String get accessibilitySettings;

  /// No description provided for @displayType.
  ///
  /// In en, this message translates to:
  /// **'Display: {type}'**
  String displayType(Object type);

  /// No description provided for @voiceOutput.
  ///
  /// In en, this message translates to:
  /// **'Voice output: {state}'**
  String voiceOutput(Object state);

  /// No description provided for @angles.
  ///
  /// In en, this message translates to:
  /// **'Angles: {type}'**
  String angles(Object type);

  /// No description provided for @zoomUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper line zoom'**
  String get zoomUpper;

  /// No description provided for @zoomLower.
  ///
  /// In en, this message translates to:
  /// **'Lower line zoom'**
  String get zoomLower;

  /// No description provided for @speechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get speechRate;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get done;

  /// No description provided for @display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// No description provided for @dms.
  ///
  /// In en, this message translates to:
  /// **'DMS'**
  String get dms;

  /// No description provided for @decimal.
  ///
  /// In en, this message translates to:
  /// **'Decimal'**
  String get decimal;

  /// No description provided for @helpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Usage help'**
  String get helpTooltip;

  /// No description provided for @muteVoice.
  ///
  /// In en, this message translates to:
  /// **'Mute voice'**
  String get muteVoice;

  /// No description provided for @unmuteVoice.
  ///
  /// In en, this message translates to:
  /// **'Enable voice'**
  String get unmuteVoice;

  /// No description provided for @modeBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get modeBasic;

  /// No description provided for @modeScientific.
  ///
  /// In en, this message translates to:
  /// **'Scientific'**
  String get modeScientific;

  /// No description provided for @modeStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get modeStatistics;

  /// No description provided for @modeElectrician.
  ///
  /// In en, this message translates to:
  /// **'Electrical'**
  String get modeElectrician;

  /// No description provided for @modeUnitConversion.
  ///
  /// In en, this message translates to:
  /// **'Unit conversion'**
  String get modeUnitConversion;

  /// No description provided for @modeSpeechBasic.
  ///
  /// In en, this message translates to:
  /// **'basic mode'**
  String get modeSpeechBasic;

  /// No description provided for @modeSpeechScientific.
  ///
  /// In en, this message translates to:
  /// **'scientific mode'**
  String get modeSpeechScientific;

  /// No description provided for @modeSpeechStatistics.
  ///
  /// In en, this message translates to:
  /// **'statistics mode'**
  String get modeSpeechStatistics;

  /// No description provided for @modeSpeechElectrician.
  ///
  /// In en, this message translates to:
  /// **'electrical mode'**
  String get modeSpeechElectrician;

  /// No description provided for @modeSpeechUnitConversion.
  ///
  /// In en, this message translates to:
  /// **'unit conversion mode'**
  String get modeSpeechUnitConversion;

  /// No description provided for @switchedToMode.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode}'**
  String switchedToMode(Object mode);

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the talking calculator, active mode is {mode}'**
  String welcomeMessage(Object mode);

  /// No description provided for @displayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get displayEmpty;

  /// No description provided for @displayLabel.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displayLabel;

  /// No description provided for @displayHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom, drag to scroll'**
  String get displayHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @statsMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics memory'**
  String get statsMemoryTitle;

  /// No description provided for @statsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics summary'**
  String get statsSummaryTitle;

  /// No description provided for @statsValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get statsValue;

  /// No description provided for @statsOccurrenceCount.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get statsOccurrenceCount;

  /// No description provided for @statsTotalValues.
  ///
  /// In en, this message translates to:
  /// **'Total values: {count}'**
  String statsTotalValues(Object count);

  /// No description provided for @statsDistinctValues.
  ///
  /// In en, this message translates to:
  /// **'Distinct values: {count}'**
  String statsDistinctValues(Object count);

  /// No description provided for @statsColumnsLabel.
  ///
  /// In en, this message translates to:
  /// **'Columns: value and occurrence count'**
  String get statsColumnsLabel;

  /// No description provided for @statsRepeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Repeat count'**
  String get statsRepeatTitle;

  /// No description provided for @statsRepeatHint.
  ///
  /// In en, this message translates to:
  /// **'Enter how many times the values should be added to statistics memory'**
  String get statsRepeatHint;

  /// No description provided for @statsRepeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Insert count'**
  String get statsRepeatLabel;

  /// No description provided for @statsAllValuesSection.
  ///
  /// In en, this message translates to:
  /// **'All values in memory'**
  String get statsAllValuesSection;

  /// No description provided for @statsComputedSection.
  ///
  /// In en, this message translates to:
  /// **'Computed statistics'**
  String get statsComputedSection;

  /// No description provided for @statsMean.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get statsMean;

  /// No description provided for @statsSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get statsSum;

  /// No description provided for @statsVariance.
  ///
  /// In en, this message translates to:
  /// **'Variance'**
  String get statsVariance;

  /// No description provided for @statsStdDev.
  ///
  /// In en, this message translates to:
  /// **'Standard deviation'**
  String get statsStdDev;

  /// No description provided for @statsMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get statsMedian;

  /// No description provided for @statsMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get statsMode;

  /// No description provided for @statsCv.
  ///
  /// In en, this message translates to:
  /// **'Coefficient of variation'**
  String get statsCv;

  /// No description provided for @statsWeightedMean.
  ///
  /// In en, this message translates to:
  /// **'Weighted mean'**
  String get statsWeightedMean;

  /// No description provided for @statsModeNone.
  ///
  /// In en, this message translates to:
  /// **'No mode'**
  String get statsModeNone;

  /// No description provided for @statsMemoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Statistics memory is empty.'**
  String get statsMemoryEmpty;

  /// No description provided for @statsMemoryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Statistics memory is empty. Add data first using the M+ button.'**
  String get statsMemoryEmptyHint;

  /// No description provided for @statsMemoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Statistics memory was cleared.'**
  String get statsMemoryCleared;

  /// No description provided for @statsRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'Value {value}, occurrences: {count}.'**
  String statsRowSemantics(Object count, Object value);

  /// No description provided for @statsTotalSemantics.
  ///
  /// In en, this message translates to:
  /// **'Total {count} {countLabel}. Distinct values: {distinct}.'**
  String statsTotalSemantics(Object count, Object countLabel, Object distinct);

  /// No description provided for @statsSetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics Sets'**
  String get statsSetsTitle;

  /// No description provided for @statsSetsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage Sets'**
  String get statsSetsManage;

  /// No description provided for @statsSetsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create new set'**
  String get statsSetsCreate;

  /// No description provided for @statsSetsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename set'**
  String get statsSetsRename;

  /// No description provided for @statsSetsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete set'**
  String get statsSetsDelete;

  /// No description provided for @statsSetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Set name'**
  String get statsSetNameLabel;

  /// No description provided for @statsSetCreatedAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Created and selected new empty set {name}'**
  String statsSetCreatedAnnouncement(String name);

  /// No description provided for @statsSetRenamedAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Set renamed to {name}'**
  String statsSetRenamedAnnouncement(String name);

  /// No description provided for @statsSetDeletedAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Set {name} deleted. Active set is now {activeName}'**
  String statsSetDeletedAnnouncement(String name, String activeName);

  /// No description provided for @statsSetSelectedAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Selected set {name}, contains {count} {countForm}'**
  String statsSetSelectedAnnouncement(String name, int count, String countForm);

  /// No description provided for @statsSetDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Set {index}'**
  String statsSetDefaultName(int index);

  /// No description provided for @statsCurrentSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Active set: {name}'**
  String statsCurrentSetLabel(String name);

  /// No description provided for @statsHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics Help'**
  String get statsHelpTitle;

  /// No description provided for @statsHelpButton.
  ///
  /// In en, this message translates to:
  /// **'Help with controls'**
  String get statsHelpButton;

  /// No description provided for @statsHelpText.
  ///
  /// In en, this message translates to:
  /// **'...'**
  String get statsHelpText;

  /// No description provided for @statsHelpKeyboardSection.
  ///
  /// In en, this message translates to:
  /// **'Keyboard buttons'**
  String get statsHelpKeyboardSection;

  /// No description provided for @statsHelpAdvancedSection.
  ///
  /// In en, this message translates to:
  /// **'Advanced functions'**
  String get statsHelpAdvancedSection;

  /// No description provided for @statsHelpFieldsSection.
  ///
  /// In en, this message translates to:
  /// **'Fields in a set'**
  String get statsHelpFieldsSection;

  /// No description provided for @statsHelpWeightedMeanSection.
  ///
  /// In en, this message translates to:
  /// **'Weighted mean (WMEAN)'**
  String get statsHelpWeightedMeanSection;

  /// No description provided for @statsHelpTipsSection.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get statsHelpTipsSection;

  /// No description provided for @statsHelpKeyboardSets.
  ///
  /// In en, this message translates to:
  /// **'SETS – Manage statistics sets...'**
  String get statsHelpKeyboardSets;

  /// No description provided for @statsHelpKeyboardMPlus.
  ///
  /// In en, this message translates to:
  /// **'M+ ...'**
  String get statsHelpKeyboardMPlus;

  /// No description provided for @statsHelpKeyboardMc.
  ///
  /// In en, this message translates to:
  /// **'MC ...'**
  String get statsHelpKeyboardMc;

  /// No description provided for @statsHelpKeyboardMr.
  ///
  /// In en, this message translates to:
  /// **'MR ...'**
  String get statsHelpKeyboardMr;

  /// No description provided for @statsHelpKeyboardStats.
  ///
  /// In en, this message translates to:
  /// **'STATS ...'**
  String get statsHelpKeyboardStats;

  /// No description provided for @statsHelpKeyboardSemicolon.
  ///
  /// In en, this message translates to:
  /// **'; ...'**
  String get statsHelpKeyboardSemicolon;

  /// No description provided for @statsHelpAdvancedMean.
  ///
  /// In en, this message translates to:
  /// **'MEAN ...'**
  String get statsHelpAdvancedMean;

  /// No description provided for @statsHelpAdvancedSd.
  ///
  /// In en, this message translates to:
  /// **'SD ...'**
  String get statsHelpAdvancedSd;

  /// No description provided for @statsHelpAdvancedVar.
  ///
  /// In en, this message translates to:
  /// **'VAR ...'**
  String get statsHelpAdvancedVar;

  /// No description provided for @statsHelpAdvancedSum.
  ///
  /// In en, this message translates to:
  /// **'SUM ...'**
  String get statsHelpAdvancedSum;

  /// No description provided for @statsHelpAdvancedMed.
  ///
  /// In en, this message translates to:
  /// **'MED ...'**
  String get statsHelpAdvancedMed;

  /// No description provided for @statsHelpAdvancedMode.
  ///
  /// In en, this message translates to:
  /// **'MODE ...'**
  String get statsHelpAdvancedMode;

  /// No description provided for @statsHelpAdvancedCv.
  ///
  /// In en, this message translates to:
  /// **'CV ...'**
  String get statsHelpAdvancedCv;

  /// No description provided for @statsHelpAdvancedWmean.
  ///
  /// In en, this message translates to:
  /// **'WMEAN ...'**
  String get statsHelpAdvancedWmean;

  /// No description provided for @statsHelpFieldsDesc.
  ///
  /// In en, this message translates to:
  /// **'Each set can have multiple fields...'**
  String get statsHelpFieldsDesc;

  /// No description provided for @statsHelpWeightedMeanDesc.
  ///
  /// In en, this message translates to:
  /// **'Requires a set with at least 2 fields...'**
  String get statsHelpWeightedMeanDesc;

  /// No description provided for @statsHelpTip1.
  ///
  /// In en, this message translates to:
  /// **'Create multiple sets...'**
  String get statsHelpTip1;

  /// No description provided for @statsHelpTip2.
  ///
  /// In en, this message translates to:
  /// **'Each set can have multiple fields...'**
  String get statsHelpTip2;

  /// No description provided for @statsHelpTip3.
  ///
  /// In en, this message translates to:
  /// **'A new set is created automatically on first data entry.'**
  String get statsHelpTip3;

  /// No description provided for @statsHelpTip4.
  ///
  /// In en, this message translates to:
  /// **'Data is saved automatically to the device memory.'**
  String get statsHelpTip4;

  /// No description provided for @backupData.
  ///
  /// In en, this message translates to:
  /// **'Backup data'**
  String get backupData;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore data'**
  String get restoreData;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupSuccess;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data restored'**
  String get restoreSuccess;

  /// No description provided for @restoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to restore all data from backup?'**
  String get restoreConfirm;

  /// No description provided for @numberInfo.
  ///
  /// In en, this message translates to:
  /// **'Number Info'**
  String get numberInfo;

  /// No description provided for @infoValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get infoValue;

  /// No description provided for @infoFraction.
  ///
  /// In en, this message translates to:
  /// **'Fraction'**
  String get infoFraction;

  /// No description provided for @infoDms.
  ///
  /// In en, this message translates to:
  /// **'DMS'**
  String get infoDms;

  /// No description provided for @infoPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get infoPercentage;

  /// No description provided for @infoPrimeFactors.
  ///
  /// In en, this message translates to:
  /// **'Prime factors'**
  String get infoPrimeFactors;

  /// No description provided for @infoDivisors.
  ///
  /// In en, this message translates to:
  /// **'Divisors'**
  String get infoDivisors;

  /// No description provided for @infoRead.
  ///
  /// In en, this message translates to:
  /// **'READ ALOUD'**
  String get infoRead;

  /// No description provided for @infoNoResult.
  ///
  /// In en, this message translates to:
  /// **'Calculate a result first.'**
  String get infoNoResult;

  /// No description provided for @infoNotInteger.
  ///
  /// In en, this message translates to:
  /// **'Positive integers only'**
  String get infoNotInteger;

  /// No description provided for @infoNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get infoNotApplicable;

  /// No description provided for @dialogSizeSetting.
  ///
  /// In en, this message translates to:
  /// **'Dialog size'**
  String get dialogSizeSetting;

  /// No description provided for @dialogSizeCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get dialogSizeCompact;

  /// No description provided for @dialogSizeWide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get dialogSizeWide;

  /// No description provided for @dialogSizeFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get dialogSizeFullscreen;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs': return AppLocalizationsCs();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
