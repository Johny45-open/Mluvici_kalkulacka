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
  /// In cs, this message translates to:
  /// **'Mluvící kalkulačka'**
  String get appTitle;

  /// No description provided for @history.
  ///
  /// In cs, this message translates to:
  /// **'Historie'**
  String get history;

  /// No description provided for @advancedFunctions.
  ///
  /// In cs, this message translates to:
  /// **'Pokročilé funkce'**
  String get advancedFunctions;

  /// No description provided for @help.
  ///
  /// In cs, this message translates to:
  /// **'Nápověda'**
  String get help;

  /// No description provided for @accessibility.
  ///
  /// In cs, this message translates to:
  /// **'Nastavení přístupnosti'**
  String get accessibility;

  /// No description provided for @historyTitle.
  ///
  /// In cs, this message translates to:
  /// **'Historie výpočtů'**
  String get historyTitle;

  /// No description provided for @emptyHistory.
  ///
  /// In cs, this message translates to:
  /// **'Historie je prázdná.'**
  String get emptyHistory;

  /// No description provided for @clearHistory.
  ///
  /// In cs, this message translates to:
  /// **'VYMAZAT HISTORII'**
  String get clearHistory;

  /// No description provided for @close.
  ///
  /// In cs, this message translates to:
  /// **'ZAVŘÍT'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In cs, this message translates to:
  /// **'Potvrzení'**
  String get confirm;

  /// No description provided for @deleteConfirmation.
  ///
  /// In cs, this message translates to:
  /// **'Opravdu chcete smazat celou historii výpočtů?'**
  String get deleteConfirmation;

  /// No description provided for @yesDelete.
  ///
  /// In cs, this message translates to:
  /// **'ANO, SMAZAT'**
  String get yesDelete;

  /// No description provided for @noStay.
  ///
  /// In cs, this message translates to:
  /// **'NE, ZŮSTAT'**
  String get noStay;

  /// No description provided for @helpTitle.
  ///
  /// In cs, this message translates to:
  /// **'Nápověda'**
  String get helpTitle;

  /// No description provided for @understand.
  ///
  /// In cs, this message translates to:
  /// **'ROZUMÍM'**
  String get understand;

  /// No description provided for @tutorialText.
  ///
  /// In cs, this message translates to:
  /// **'Tato kalkulačka podporuje vědecké výpočty, statistiku, elektrotechnické vzorce a převody jednotek. \n\nKlávesové zkratky:\nS - Sinus (Shift+S pro Arkus)\nC - Kosinus (Shift+C pro Arkus)\nT - Tangens (Shift+T pro Arkus)\nP - Pí\nQ - Odmocnina\nEnter - Výsledek'**
  String get tutorialText;

  /// No description provided for @accessibilitySettings.
  ///
  /// In cs, this message translates to:
  /// **'Nastavení přístupnosti'**
  String get accessibilitySettings;

  /// No description provided for @displayType.
  ///
  /// In cs, this message translates to:
  /// **'Displej: {type}'**
  String displayType(Object type);

  /// No description provided for @voiceOutput.
  ///
  /// In cs, this message translates to:
  /// **'Hlasový výstup: {state}'**
  String voiceOutput(Object state);

  /// No description provided for @angles.
  ///
  /// In cs, this message translates to:
  /// **'Úhly: {type}'**
  String angles(Object type);

  /// No description provided for @zoomUpper.
  ///
  /// In cs, this message translates to:
  /// **'Zoom horního řádku'**
  String get zoomUpper;

  /// No description provided for @zoomLower.
  ///
  /// In cs, this message translates to:
  /// **'Zoom dolního řádku'**
  String get zoomLower;

  /// No description provided for @speechRate.
  ///
  /// In cs, this message translates to:
  /// **'Rychlost hlasu'**
  String get speechRate;

  /// No description provided for @volume.
  ///
  /// In cs, this message translates to:
  /// **'Hlasitost'**
  String get volume;

  /// No description provided for @done.
  ///
  /// In cs, this message translates to:
  /// **'HOTOVO'**
  String get done;

  /// No description provided for @display.
  ///
  /// In cs, this message translates to:
  /// **'Zobrazení'**
  String get display;

  /// No description provided for @dms.
  ///
  /// In cs, this message translates to:
  /// **'DMS'**
  String get dms;

  /// No description provided for @decimal.
  ///
  /// In cs, this message translates to:
  /// **'Desetinné'**
  String get decimal;

  String get helpTooltip;

  String get muteVoice;

  String get unmuteVoice;

  String get modeBasic;

  String get modeScientific;

  String get modeStatistics;

  String get modeElectrician;

  String get modeUnitConversion;

  String get modeSpeechBasic;

  String get modeSpeechScientific;

  String get modeSpeechStatistics;

  String get modeSpeechElectrician;

  String get modeSpeechUnitConversion;

  String switchedToMode(String mode);

  String welcomeMessage(String mode);

  String get displayEmpty;

  String get displayLabel;

  String get displayHint;

  String get cancel;

  String get confirmAction;

  String get statsMemoryTitle;

  String get statsSummaryTitle;

  String get statsValue;

  String get statsOccurrenceCount;

  String statsTotalValues(int count);

  String statsDistinctValues(int count);

  String get statsColumnsLabel;

  String get statsRepeatTitle;

  String get statsRepeatHint;

  String get statsRepeatLabel;

  String get statsAllValuesSection;

  String get statsComputedSection;

  String get statsMean;

  String get statsSum;

  String get statsVariance;

  String get statsStdDev;

  String get statsMedian;

  String get statsMode;

  String get statsCv;

  String get statsModeNone;

  String get statsMemoryEmpty;

  String get statsMemoryEmptyHint;

  String get statsMemoryCleared;

  String statsRowSemantics(String value, int count);

  String statsTotalSemantics(int count, String countLabel, int distinct);
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
