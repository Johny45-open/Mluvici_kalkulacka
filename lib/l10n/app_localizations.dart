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
  /// **'This calculator supports scientific calculations, statistics, electrical formulas, and unit conversions. \n\nKeyboard shortcuts:\nS - Sine (Shift+S for Arcsine)\nC - Cosine (Shift+C for Arccosine)\nT - Tangent (Shift+T for Arctangent)\nP - Pi\nQ - Square root\nEnter - Result\nCtrl+PageDown/PageUp - Switch between functions and numbers page in scientific mode'**
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

  /// No description provided for @statsReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review data before saving'**
  String get statsReviewTitle;

  /// No description provided for @statsReviewSummary.
  ///
  /// In en, this message translates to:
  /// **'Ready to save {count} records to set {name}.'**
  String statsReviewSummary(Object count, Object name);

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

  /// No description provided for @statsN.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get statsN;

  /// No description provided for @statsMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get statsMin;

  /// No description provided for @statsMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get statsMax;

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
  /// **'=== STATISTICS HELP ===\n\nKEYBOARD BUTTONS:\n\nSETS – Manage statistics sets. Create, rename, delete or switch between sets.\n\nM+ (short press) – Add the entered value (or multiple values separated by semicolons) to the active set.\n\nM+ (long press) – Add values and specify a repeat count for bulk insertion.\n\nMC – Clear all data in the active set.\n\nMR – Show all stored data in an editable list.\n\nSTATS – Show the statistics summary for the selected field: mean, sum, variance, standard deviation, median, mode and coefficient of variation.\n\n; (semicolon) – Separator for multiple values (e.g. 5;10;15).\n\nADVANCED FUNCTIONS (available from the list button in the top bar):\n\nMEAN – Arithmetic mean of all values.\nSD – Standard deviation (measure of dispersion around the mean).\nVAR – Variance (average squared deviation from the mean).\nSUM – Sum of all values.\nMED – Median (middle value of sorted data).\nMODE – Mode (most frequent value).\nMIN – Minimum of all values.\nMAX – Maximum of all values.\nCV – Coefficient of variation (SD as percentage of the mean).\nWMEAN – Weighted mean (requires 2 fields: values and weights).\n\nFIELDS IN A SET:\n\nEach set can have multiple fields (e.g. \"Value\" and \"Weight\"). When creating a set (SETS → Create new set) you can add fields using the \"Add field\" button. You can then switch which field statistics are calculated for – either in the STATS dialog or in Advanced Functions.\n\nWEIGHTED MEAN (WMEAN):\n\nRequires a set with at least 2 fields. Field 0 = values, field 1 = weights. Steps: 1) Create a set with 2 fields (e.g. \"Value\" and \"Weight\"). 2) Enter values and weights separated by a semicolon, e.g. \"80;2\" (value 80 with weight 2). 3) After entering all data, tap WMEAN in Advanced Functions. 4) The app calculates: (value1 × weight1 + value2 × weight2 + ...) / (weight1 + weight2 + ...).\n\nTIPS:\n- Create multiple sets for different data groups.\n- Each set can have multiple fields (e.g. values, weights).\n- A new set is created automatically on first data entry.\n- Data is saved automatically to the device memory.'**
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
  /// **'SETS – Manage statistics sets. Create, rename, delete or switch between sets.'**
  String get statsHelpKeyboardSets;

  /// No description provided for @statsHelpKeyboardMPlus.
  ///
  /// In en, this message translates to:
  /// **'M+ (short press) – Add the entered value (or multiple values separated by semicolons) to the active set. Long press – Add values and specify a repeat count for bulk insertion.'**
  String get statsHelpKeyboardMPlus;

  /// No description provided for @statsHelpKeyboardMc.
  ///
  /// In en, this message translates to:
  /// **'MC – Clear all data in the active set.'**
  String get statsHelpKeyboardMc;

  /// No description provided for @statsHelpKeyboardMr.
  ///
  /// In en, this message translates to:
  /// **'MR – Show all stored data in an editable list.'**
  String get statsHelpKeyboardMr;

  /// No description provided for @statsHelpKeyboardStats.
  ///
  /// In en, this message translates to:
  /// **'STATS – Show the statistics summary for the selected field: mean, sum, variance, standard deviation, median, mode and coefficient of variation.'**
  String get statsHelpKeyboardStats;

  /// No description provided for @statsHelpKeyboardSemicolon.
  ///
  /// In en, this message translates to:
  /// **'; (semicolon) – Separator for multiple values (e.g. 5;10;15).'**
  String get statsHelpKeyboardSemicolon;

  /// No description provided for @statsHelpAdvancedMean.
  ///
  /// In en, this message translates to:
  /// **'MEAN – Arithmetic mean of all values.'**
  String get statsHelpAdvancedMean;

  /// No description provided for @statsHelpAdvancedSd.
  ///
  /// In en, this message translates to:
  /// **'SD – Standard deviation (measure of dispersion around the mean).'**
  String get statsHelpAdvancedSd;

  /// No description provided for @statsHelpAdvancedVar.
  ///
  /// In en, this message translates to:
  /// **'VAR – Variance (average squared deviation from the mean).'**
  String get statsHelpAdvancedVar;

  /// No description provided for @statsHelpAdvancedSum.
  ///
  /// In en, this message translates to:
  /// **'SUM – Sum of all values.'**
  String get statsHelpAdvancedSum;

  /// No description provided for @statsHelpAdvancedMed.
  ///
  /// In en, this message translates to:
  /// **'MED – Median (middle value of sorted data).'**
  String get statsHelpAdvancedMed;

  /// No description provided for @statsHelpAdvancedMode.
  ///
  /// In en, this message translates to:
  /// **'MODE – Mode (most frequent value).'**
  String get statsHelpAdvancedMode;

  /// No description provided for @statsHelpAdvancedMin.
  ///
  /// In en, this message translates to:
  /// **'MIN – Minimum of all values.'**
  String get statsHelpAdvancedMin;

  /// No description provided for @statsHelpAdvancedMax.
  ///
  /// In en, this message translates to:
  /// **'MAX – Maximum of all values.'**
  String get statsHelpAdvancedMax;

  /// No description provided for @statsHelpAdvancedCv.
  ///
  /// In en, this message translates to:
  /// **'CV – Coefficient of variation (SD as percentage of the mean).'**
  String get statsHelpAdvancedCv;

  /// No description provided for @statsHelpAdvancedWmean.
  ///
  /// In en, this message translates to:
  /// **'WMEAN – Weighted mean (requires 2 fields: values and weights).'**
  String get statsHelpAdvancedWmean;

  /// No description provided for @statsHelpFieldsDesc.
  ///
  /// In en, this message translates to:
  /// **'Each set can have multiple fields (e.g. \"Value\" and \"Weight\"). When creating a set (SETS → Create new set) you can add fields using the \"Add field\" button. You can then switch which field statistics are calculated for – either in the STATS dialog or in Advanced Functions.'**
  String get statsHelpFieldsDesc;

  /// No description provided for @statsHelpWeightedMeanDesc.
  ///
  /// In en, this message translates to:
  /// **'Requires a set with at least 2 fields. Field 0 = values, field 1 = weights.\\n\\nSteps:\\n1) Create a set with 2 fields (e.g. \"Value\" and \"Weight\").\\n2) Enter values and weights separated by a semicolon, e.g. \"80;2\" (value 80 with weight 2).\\n3) After entering all data, tap WMEAN in Advanced Functions.\\n4) The app calculates: (value1 × weight1 + value2 × weight2 + ...) / (weight1 + weight2 + ...).'**
  String get statsHelpWeightedMeanDesc;

  /// No description provided for @statsHelpTip1.
  ///
  /// In en, this message translates to:
  /// **'Create multiple sets for different data groups.'**
  String get statsHelpTip1;

  /// No description provided for @statsHelpTip2.
  ///
  /// In en, this message translates to:
  /// **'Each set can have multiple fields (e.g. values, weights).'**
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

  /// No description provided for @statsWeightedMean.
  ///
  /// In en, this message translates to:
  /// **'Weighted mean'**
  String get statsWeightedMean;

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
  /// **'DMS (degrees/minutes/seconds)'**
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

  /// No description provided for @voiceOn.
  ///
  /// In en, this message translates to:
  /// **'Voice on'**
  String get voiceOn;

  /// No description provided for @voiceOff.
  ///
  /// In en, this message translates to:
  /// **'Voice off'**
  String get voiceOff;

  /// No description provided for @cleared.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get cleared;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @historyCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyCleared;

  /// No description provided for @appIsCurrent.
  ///
  /// In en, this message translates to:
  /// **'The app is up to date.'**
  String get appIsCurrent;

  /// No description provided for @degreesUnit.
  ///
  /// In en, this message translates to:
  /// **'degrees'**
  String get degreesUnit;

  /// No description provided for @minutesUnit.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutesUnit;

  /// No description provided for @secondsUnit.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get secondsUnit;

  /// No description provided for @piSpoken.
  ///
  /// In en, this message translates to:
  /// **'pi'**
  String get piSpoken;

  /// No description provided for @minusWord.
  ///
  /// In en, this message translates to:
  /// **'minus'**
  String get minusWord;

  /// No description provided for @timesTenTo.
  ///
  /// In en, this message translates to:
  /// **'times ten to the'**
  String get timesTenTo;

  /// No description provided for @expressionNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'I don\'t understand the expression, please check the parentheses or signs'**
  String get expressionNotUnderstood;

  /// No description provided for @cannotDivideByZero.
  ///
  /// In en, this message translates to:
  /// **'Cannot divide by zero'**
  String get cannotDivideByZero;

  /// No description provided for @valueOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Value is outside the valid range of the function'**
  String get valueOutOfRange;

  /// No description provided for @resultIs.
  ///
  /// In en, this message translates to:
  /// **'The result is {value}'**
  String resultIs(String value);

  /// No description provided for @conversionError.
  ///
  /// In en, this message translates to:
  /// **'Conversion error'**
  String get conversionError;

  /// No description provided for @unitConverted.
  ///
  /// In en, this message translates to:
  /// **'Converted from {from} to {to}. The result is {value} {toUnit}'**
  String unitConverted(String from, String to, String value, String toUnit);

  /// No description provided for @backupError.
  ///
  /// In en, this message translates to:
  /// **'Error creating the backup'**
  String get backupError;

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'Error restoring the data'**
  String get restoreError;

  /// No description provided for @decimalPlacesSet.
  ///
  /// In en, this message translates to:
  /// **'Set to {count} decimal places'**
  String decimalPlacesSet(int count);

  /// No description provided for @savedToVariable.
  ///
  /// In en, this message translates to:
  /// **'Saved to variable {name}: {value}'**
  String savedToVariable(String name, String value);

  /// Error announced when the user tries to store an expression that cannot be evaluated into memory.
  ///
  /// In en, this message translates to:
  /// **'The expression cannot be calculated, nothing was saved to memory.'**
  String get cannotStoreExpression;

  /// No description provided for @recalledFromVariable.
  ///
  /// In en, this message translates to:
  /// **'Recalled from variable {name}: {value}'**
  String recalledFromVariable(String name, String value);

  /// No description provided for @variableName.
  ///
  /// In en, this message translates to:
  /// **'Variable {name}'**
  String variableName(String name);

  /// No description provided for @selectMemory.
  ///
  /// In en, this message translates to:
  /// **'Select memory'**
  String get selectMemory;

  /// No description provided for @selectMemoryRecall.
  ///
  /// In en, this message translates to:
  /// **'Select a memory to recall'**
  String get selectMemoryRecall;

  /// No description provided for @memoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Memory cleared'**
  String get memoryCleared;

  /// No description provided for @insertedValue.
  ///
  /// In en, this message translates to:
  /// **'Inserted {value}'**
  String insertedValue(String value);

  /// No description provided for @inverseResult.
  ///
  /// In en, this message translates to:
  /// **'Inverse {name} of the result'**
  String inverseResult(String name);

  /// No description provided for @resultOf.
  ///
  /// In en, this message translates to:
  /// **'{name} of the result'**
  String resultOf(String name);

  /// No description provided for @standardDisplaySet.
  ///
  /// In en, this message translates to:
  /// **'Standard display set'**
  String get standardDisplaySet;

  /// No description provided for @segment16On.
  ///
  /// In en, this message translates to:
  /// **'16-segment display on'**
  String get segment16On;

  /// No description provided for @segment7On.
  ///
  /// In en, this message translates to:
  /// **'7-segment display on'**
  String get segment7On;

  /// No description provided for @screenReaderAuto.
  ///
  /// In en, this message translates to:
  /// **'Screen reader mode: automatic'**
  String get screenReaderAuto;

  /// No description provided for @screenReaderOn.
  ///
  /// In en, this message translates to:
  /// **'Screen reader mode on'**
  String get screenReaderOn;

  /// No description provided for @screenReaderOff.
  ///
  /// In en, this message translates to:
  /// **'Screen reader mode off'**
  String get screenReaderOff;

  /// No description provided for @angleFormatDms.
  ///
  /// In en, this message translates to:
  /// **'Angle format set to degrees, minutes and seconds'**
  String get angleFormatDms;

  /// No description provided for @angleFormatDecimal.
  ///
  /// In en, this message translates to:
  /// **'Angle format set to decimal degrees'**
  String get angleFormatDecimal;

  /// No description provided for @themeSet.
  ///
  /// In en, this message translates to:
  /// **'Theme set to {mode}'**
  String themeSet(String mode);

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'dark'**
  String get themeDark;

  /// No description provided for @zoomUpperPct.
  ///
  /// In en, this message translates to:
  /// **'Upper line zoom {percent} percent'**
  String zoomUpperPct(int percent);

  /// No description provided for @zoomLowerPct.
  ///
  /// In en, this message translates to:
  /// **'Lower line zoom {percent} percent'**
  String zoomLowerPct(int percent);

  /// No description provided for @speechRatePct.
  ///
  /// In en, this message translates to:
  /// **'Speech rate {percent} percent'**
  String speechRatePct(int percent);

  /// No description provided for @volumePct.
  ///
  /// In en, this message translates to:
  /// **'Volume {percent} percent'**
  String volumePct(int percent);

  /// No description provided for @categorySelected.
  ///
  /// In en, this message translates to:
  /// **'Category {category}'**
  String categorySelected(String category);

  /// No description provided for @fromUnitSelected.
  ///
  /// In en, this message translates to:
  /// **'From unit {unit}'**
  String fromUnitSelected(String unit);

  /// No description provided for @toUnitSelected.
  ///
  /// In en, this message translates to:
  /// **'To unit {unit}'**
  String toUnitSelected(String unit);

  /// No description provided for @calcNameVoltage.
  ///
  /// In en, this message translates to:
  /// **'voltage'**
  String get calcNameVoltage;

  /// No description provided for @calcNameCurrent.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get calcNameCurrent;

  /// No description provided for @calcNameResistance.
  ///
  /// In en, this message translates to:
  /// **'resistance'**
  String get calcNameResistance;

  /// No description provided for @calcInputVoltage.
  ///
  /// In en, this message translates to:
  /// **'current and resistance'**
  String get calcInputVoltage;

  /// No description provided for @calcInputCurrent.
  ///
  /// In en, this message translates to:
  /// **'voltage and resistance'**
  String get calcInputCurrent;

  /// No description provided for @calcInputResistance.
  ///
  /// In en, this message translates to:
  /// **'voltage and current'**
  String get calcInputResistance;

  /// No description provided for @calcIntro.
  ///
  /// In en, this message translates to:
  /// **'Calculate {name}. Enter {input} separated by semicolons.'**
  String calcIntro(String name, String input);

  /// No description provided for @elecResult.
  ///
  /// In en, this message translates to:
  /// **'{name} is {value} {unit}'**
  String elecResult(String name, String value, String unit);

  /// No description provided for @elecTwoValuesError.
  ///
  /// In en, this message translates to:
  /// **'Enter two values separated by semicolons.'**
  String get elecTwoValuesError;

  /// No description provided for @elecFormatError.
  ///
  /// In en, this message translates to:
  /// **'The values entered in electrical mode are not in a valid numeric format.'**
  String get elecFormatError;

  /// No description provided for @elecInvalidResult.
  ///
  /// In en, this message translates to:
  /// **'The electrical calculation result is not a valid number.'**
  String get elecInvalidResult;

  /// No description provided for @formatDms.
  ///
  /// In en, this message translates to:
  /// **'Format set to degrees, minutes and seconds.'**
  String get formatDms;

  /// No description provided for @formatDecimalDegrees.
  ///
  /// In en, this message translates to:
  /// **'Format set to decimal degrees.'**
  String get formatDecimalDegrees;

  /// No description provided for @errorSegment.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get errorSegment;

  /// No description provided for @confirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmationTitle;

  /// No description provided for @yesConfirmHistory.
  ///
  /// In en, this message translates to:
  /// **'Yes, confirm clearing the entire calculation history'**
  String get yesConfirmHistory;

  /// No description provided for @noCancelHistory.
  ///
  /// In en, this message translates to:
  /// **'No, cancel and keep the history'**
  String get noCancelHistory;

  /// No description provided for @precisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Precision settings'**
  String get precisionTitle;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @newVersionSemantics.
  ///
  /// In en, this message translates to:
  /// **'A new version {version} is available. Your version is {current}.'**
  String newVersionSemantics(String version, String current);

  /// No description provided for @newVersionText.
  ///
  /// In en, this message translates to:
  /// **'A new version {version} is available.\n\nYour version: {current}'**
  String newVersionText(String version, String current);

  /// No description provided for @whatIsNew.
  ///
  /// In en, this message translates to:
  /// **'What is new:'**
  String get whatIsNew;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @showRelease.
  ///
  /// In en, this message translates to:
  /// **'Show release'**
  String get showRelease;

  /// No description provided for @cannotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Cannot open browser: {error}'**
  String cannotOpenBrowser(String error);

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @sectionTrigonometry.
  ///
  /// In en, this message translates to:
  /// **'Trigonometry'**
  String get sectionTrigonometry;

  /// No description provided for @sectionFunctions.
  ///
  /// In en, this message translates to:
  /// **'Functions'**
  String get sectionFunctions;

  /// No description provided for @sectionMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get sectionMemory;

  /// No description provided for @sectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get sectionDisplay;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @convertButton.
  ///
  /// In en, this message translates to:
  /// **'CONVERT'**
  String get convertButton;

  /// No description provided for @standardDisplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard display'**
  String get standardDisplayLabel;

  /// No description provided for @fixedDecimalLabel.
  ///
  /// In en, this message translates to:
  /// **'Display with a fixed number of decimal places'**
  String get fixedDecimalLabel;

  /// No description provided for @scientificNotationLabel.
  ///
  /// In en, this message translates to:
  /// **'Scientific notation'**
  String get scientificNotationLabel;

  /// No description provided for @engineeringNotationLabel.
  ///
  /// In en, this message translates to:
  /// **'Engineering notation'**
  String get engineeringNotationLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// No description provided for @segment16Name.
  ///
  /// In en, this message translates to:
  /// **'16-segment'**
  String get segment16Name;

  /// No description provided for @segment7Name.
  ///
  /// In en, this message translates to:
  /// **'7-segment'**
  String get segment7Name;

  /// No description provided for @switchDisplayType.
  ///
  /// In en, this message translates to:
  /// **'Switch display type'**
  String get switchDisplayType;

  /// No description provided for @toggleVoiceOutput.
  ///
  /// In en, this message translates to:
  /// **'Toggle voice output'**
  String get toggleVoiceOutput;

  /// No description provided for @enabledState.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get enabledState;

  /// No description provided for @disabledState.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get disabledState;

  /// No description provided for @screenReaderSection.
  ///
  /// In en, this message translates to:
  /// **'Screen reader mode'**
  String get screenReaderSection;

  /// No description provided for @screenReaderAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatic based on screen reader'**
  String get screenReaderAutoLabel;

  /// No description provided for @ttsEngineSettings.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech engine settings'**
  String get ttsEngineSettings;

  /// No description provided for @engineLabel.
  ///
  /// In en, this message translates to:
  /// **'Engine: {engine}'**
  String engineLabel(String engine);

  /// No description provided for @defaultEngine.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultEngine;

  /// No description provided for @openTtsSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system TTS settings'**
  String get openTtsSystemSettings;

  /// No description provided for @ttsSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'TTS settings'**
  String get ttsSettingsButton;

  /// No description provided for @voiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Voice settings'**
  String get voiceSettings;

  /// No description provided for @voiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice: {voice}'**
  String voiceLabel(String voice);

  /// No description provided for @toggleAngleFormat.
  ///
  /// In en, this message translates to:
  /// **'Toggle angle format'**
  String get toggleAngleFormat;

  /// No description provided for @themeSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose app theme'**
  String get themeSectionLabel;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get themeTitle;

  /// No description provided for @themeSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'System theme'**
  String get themeSystemLabel;

  /// No description provided for @themeLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get themeLightLabel;

  /// No description provided for @themeDarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get themeDarkLabel;

  /// No description provided for @defaultStartupMode.
  ///
  /// In en, this message translates to:
  /// **'Default mode on startup'**
  String get defaultStartupMode;

  /// No description provided for @zoomUpperControls.
  ///
  /// In en, this message translates to:
  /// **'Upper line zoom controls'**
  String get zoomUpperControls;

  /// No description provided for @zoomLowerControls.
  ///
  /// In en, this message translates to:
  /// **'Lower line zoom controls'**
  String get zoomLowerControls;

  /// No description provided for @decreaseUpperZoom.
  ///
  /// In en, this message translates to:
  /// **'Decrease upper line zoom'**
  String get decreaseUpperZoom;

  /// No description provided for @increaseUpperZoom.
  ///
  /// In en, this message translates to:
  /// **'Increase upper line zoom'**
  String get increaseUpperZoom;

  /// No description provided for @decreaseLowerZoom.
  ///
  /// In en, this message translates to:
  /// **'Decrease lower line zoom'**
  String get decreaseLowerZoom;

  /// No description provided for @increaseLowerZoom.
  ///
  /// In en, this message translates to:
  /// **'Increase lower line zoom'**
  String get increaseLowerZoom;

  /// No description provided for @zoomValuePct.
  ///
  /// In en, this message translates to:
  /// **'Zoom value: {value} %'**
  String zoomValuePct(int value);

  /// No description provided for @speechRateControls.
  ///
  /// In en, this message translates to:
  /// **'Speech rate controls'**
  String get speechRateControls;

  /// No description provided for @decreaseSpeechRate.
  ///
  /// In en, this message translates to:
  /// **'Decrease speech rate'**
  String get decreaseSpeechRate;

  /// No description provided for @increaseSpeechRate.
  ///
  /// In en, this message translates to:
  /// **'Increase speech rate'**
  String get increaseSpeechRate;

  /// No description provided for @speechRateValue.
  ///
  /// In en, this message translates to:
  /// **'Current speech rate: {value} %'**
  String speechRateValue(int value);

  /// No description provided for @volumeControls.
  ///
  /// In en, this message translates to:
  /// **'Volume controls'**
  String get volumeControls;

  /// No description provided for @decreaseVolume.
  ///
  /// In en, this message translates to:
  /// **'Decrease volume'**
  String get decreaseVolume;

  /// No description provided for @increaseVolume.
  ///
  /// In en, this message translates to:
  /// **'Increase volume'**
  String get increaseVolume;

  /// No description provided for @volumeValue.
  ///
  /// In en, this message translates to:
  /// **'Current volume: {value} %'**
  String volumeValue(int value);

  /// No description provided for @dataManagementSection.
  ///
  /// In en, this message translates to:
  /// **'Data backup and restore'**
  String get dataManagementSection;

  /// No description provided for @dataManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Data management'**
  String get dataManagementTitle;

  /// No description provided for @yesShort.
  ///
  /// In en, this message translates to:
  /// **'YES'**
  String get yesShort;

  /// No description provided for @noShort.
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get noShort;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'What is new'**
  String get news;
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
