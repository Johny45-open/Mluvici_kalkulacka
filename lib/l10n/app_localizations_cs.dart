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

  @override
  String get helpTooltip => 'Nápověda k ovládání';

  @override
  String get muteVoice => 'Ztlumit hlas';

  @override
  String get unmuteVoice => 'Zapnout hlas';

  @override
  String get modeBasic => 'Základní';

  @override
  String get modeScientific => 'Vědecká';

  @override
  String get modeStatistics => 'Statistika';

  @override
  String get modeElectrician => 'Elektro';

  @override
  String get modeUnitConversion => 'Převody jednotek';

  @override
  String get modeSpeechBasic => 'základní režim';

  @override
  String get modeSpeechScientific => 'vědecký režim';

  @override
  String get modeSpeechStatistics => 'statistický režim';

  @override
  String get modeSpeechElectrician => 'elektrotechnický režim';

  @override
  String get modeSpeechUnitConversion => 'režim převodů jednotek';

  @override
  String switchedToMode(String mode) => 'Přepnuto na $mode';

  @override
  String welcomeMessage(String mode) =>
      'Vítejte v mluvící kalkulačce, aktivní je $mode';

  @override
  String get displayEmpty => 'Prázdno';

  @override
  String get displayLabel => 'Displej';

  @override
  String get displayHint => 'Zoomujte dvěma prsty, posouvejte tahem';

  @override
  String get cancel => 'Zrušit';

  @override
  String get confirmAction => 'Potvrdit';

  @override
  String get statsMemoryTitle => 'Statistická paměť';

  @override
  String get statsSummaryTitle => 'Statistický souhrn';

  @override
  String get statsValue => 'Hodnota';

  @override
  String get statsOccurrenceCount => 'Počet výskytů';

  @override
  String statsTotalValues(int count) => 'Celkem hodnot: $count';

  @override
  String statsDistinctValues(int count) => 'Různých hodnot: $count';

  @override
  String get statsColumnsLabel => 'Sloupce: hodnota a počet výskytů';

  @override
  String get statsRepeatTitle => 'Počet opakování';

  @override
  String get statsRepeatHint =>
      'Zadejte, kolikrát se mají hodnoty vložit do statistické paměti';

  @override
  String get statsRepeatLabel => 'Počet vložení';

  @override
  String get statsAllValuesSection => 'Všechny hodnoty v paměti';

  @override
  String get statsComputedSection => 'Vypočtené statistiky';

  @override
  String get statsMean => 'Průměr';

  @override
  String get statsSum => 'Součet';

  @override
  String get statsVariance => 'Rozptyl';

  @override
  String get statsStdDev => 'Směrodatná odchylka';

  @override
  String get statsMedian => 'Medián';

  @override
  String get statsMode => 'Modus';

  @override
  String get statsCv => 'Variační koeficient';

  @override
  String get statsModeNone => 'Modus neexistuje';

  @override
  String get statsMemoryEmpty => 'Statistická paměť je prázdná.';

  @override
  String get statsMemoryEmptyHint =>
      'Statistická paměť je prázdná. Nejprve přidejte data pomocí tlačítka M plus.';

  @override
  String get statsMemoryCleared => 'Statistická paměť byla smazána.';

  @override
  String statsRowSemantics(String value, int count) =>
      'Hodnota $value, počet výskytů: $count.';

  @override
  String statsTotalSemantics(int count, String countLabel, int distinct) =>
      'Celkem $count $countLabel. Počet různých hodnot: $distinct.';
}
