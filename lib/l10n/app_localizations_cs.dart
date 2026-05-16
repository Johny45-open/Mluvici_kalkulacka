// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Mluvící kalkulačka';

  @override
  String get history => 'Historie';

  @override
  String get advancedFunctions => 'Pokročilé funkce';

  @override
  String get help => 'Nápověda';

  @override
  String get accessibility => 'Nastavení přístupnosti';

  @override
  String get historyTitle => 'Historie výpočtů';

  @override
  String get emptyHistory => 'Historie je prázdná.';

  @override
  String get clearHistory => 'VYMAZAT HISTORII';

  @override
  String get close => 'ZAVŘÍT';

  @override
  String get confirm => 'Potvrzení';

  @override
  String get deleteConfirmation => 'Opravdu chcete smazat celou historii výpočtů?';

  @override
  String get yesDelete => 'ANO, SMAZAT';

  @override
  String get noStay => 'NE, ZŮSTAT';

  @override
  String get helpTitle => 'Nápověda';

  @override
  String get understand => 'ROZUMÍM';

  @override
  String get tutorialText => 'Tato kalkulačka podporuje vědecké výpočty, statistiku, elektrotechnické vzorce a převody jednotek. \n\nKlávesové zkratky:\nS - Sinus (Shift+S pro Arkus)\nC - Kosinus (Shift+C pro Arkus)\nT - Tangens (Shift+T pro Arkus)\nP - Pí\nQ - Odmocnina\nEnter - Výsledek';

  @override
  String get accessibilitySettings => 'Nastavení přístupnosti';

  @override
  String displayType(Object type) {
    return 'Displej: $type';
  }

  @override
  String voiceOutput(Object state) {
    return 'Hlasový výstup: $state';
  }

  @override
  String angles(Object type) {
    return 'Úhly: $type';
  }

  @override
  String get zoomUpper => 'Zoom horního řádku';

  @override
  String get zoomLower => 'Zoom dolního řádku';

  @override
  String get speechRate => 'Rychlost hlasu';

  @override
  String get volume => 'Hlasitost';

  @override
  String get done => 'HOTOVO';

  @override
  String get display => 'Zobrazení';

  @override
  String get dms => 'DMS';

  @override
  String get decimal => 'Desetinné';
}
