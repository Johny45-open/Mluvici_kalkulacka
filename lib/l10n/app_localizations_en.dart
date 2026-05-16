// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Talking Calculator';

  @override
  String get history => 'History';

  @override
  String get advancedFunctions => 'Advanced Functions';

  @override
  String get help => 'Help';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get historyTitle => 'Calculation History';

  @override
  String get emptyHistory => 'History is empty.';

  @override
  String get clearHistory => 'CLEAR HISTORY';

  @override
  String get close => 'CLOSE';

  @override
  String get confirm => 'Confirm';

  @override
  String get deleteConfirmation => 'Are you sure you want to clear the entire history?';

  @override
  String get yesDelete => 'YES, CLEAR';

  @override
  String get noStay => 'NO, KEEP';

  @override
  String get helpTitle => 'Help';

  @override
  String get understand => 'UNDERSTAND';

  @override
  String get tutorialText => 'This calculator supports scientific calculations, statistics, electrical formulas, and unit conversions. \n\nKeyboard shortcuts:\nS - Sine (Shift+S for Arcsine)\nC - Cosine (Shift+C for Arccosine)\nT - Tangent (Shift+T for Arctangent)\nP - Pi\nQ - Square root\nEnter - Result';

  @override
  String get accessibilitySettings => 'Accessibility Settings';

  @override
  String displayType(Object type) {
    return 'Display: $type';
  }

  @override
  String voiceOutput(Object state) {
    return 'Voice output: $state';
  }

  @override
  String angles(Object type) {
    return 'Angles: $type';
  }

  @override
  String get zoomUpper => 'Upper line zoom';

  @override
  String get zoomLower => 'Lower line zoom';

  @override
  String get speechRate => 'Speech rate';

  @override
  String get volume => 'Volume';

  @override
  String get done => 'DONE';

  @override
  String get display => 'Display';

  @override
  String get dms => 'DMS';

  @override
  String get decimal => 'Decimal';
}
