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
  String get tutorialText => 'Vítejte v Mluvící kalkulačce. \n\nZákladní ovládání:\n- Aplikace se ovládá primárně tlačítky na obrazovce nebo klávesnicí.\n- Se čtečkou obrazovky (TalkBack/NVDA) se pohybujte pomocí gest nebo kláves tabulátoru.\n- Každé tlačítko po aktivaci ohlásí svou funkci hlasem.\n- Výsledek se ohlásí automaticky po stisknutí tlačítka \'=\' (nebo klávesy Enter).\n\nRežimy a funkce:\n- Režimy (Vědecký, Statistika atd.) mění rozložení klávesnice.\n- Pokročilé funkce jsou dostupné v menu pod tlačítkem \'Pokročilé funkce\'.\n\nKlávesové zkratky:\n- Enter: Výsledek\n- Backspace: Smazat poslední znak\n- Escape/Delete: Vymazat displej\n- S, C, T: Sinus, Kosinus, Tangens (Shift pro inverzní funkce)\n- P: Pí, Q: Odmocnina, A: Absolutní hodnota';

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
  String switchedToMode(Object mode) {
    return 'Přepnuto na $mode';
  }

  @override
  String welcomeMessage(Object mode) {
    return 'Vítejte v mluvící kalkulačce, aktivní je $mode';
  }

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
  String statsTotalValues(Object count) {
    return 'Celkem hodnot: $count';
  }

  @override
  String statsDistinctValues(Object count) {
    return 'Různých hodnot: $count';
  }

  @override
  String get statsColumnsLabel => 'Sloupce: hodnota a počet výskytů';

  @override
  String get statsRepeatTitle => 'Počet opakování';

  @override
  String get statsRepeatHint => 'Zadejte, kolikrát se mají hodnoty vložit do statistické paměti';

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
  String get statsMemoryEmptyHint => 'Statistická paměť je prázdná. Nejprve přidejte data pomocí tlačítka M plus.';

  @override
  String get statsMemoryCleared => 'Statistická paměť byla smazána.';

  @override
  String statsRowSemantics(Object count, Object value) {
    return 'Hodnota $value, počet výskytů: $count.';
  }

  @override
  String statsTotalSemantics(Object count, Object countLabel, Object distinct) {
    return 'Celkem $count $countLabel. Počet různých hodnot: $distinct.';
  }

  @override
  String get statsSetsTitle => 'Statistické sady';

  @override
  String get statsSetsManage => 'Správa sad';

  @override
  String get statsSetsCreate => 'Vytvořit novou sadu';

  @override
  String get statsSetsRename => 'Přejmenovat sadu';

  @override
  String get statsSetsDelete => 'Smazat sadu';

  @override
  String get statsSetNameLabel => 'Název sady';

  @override
  String statsSetCreatedAnnouncement(String name) {
    return 'Vytvořena a vybrána nová prázdná sada $name';
  }

  @override
  String statsSetRenamedAnnouncement(String name) {
    return 'Sada přejmenována na $name';
  }

  @override
  String statsSetDeletedAnnouncement(String name, String activeName) {
    return 'Sada $name smazána. Aktivní je nyní sada $activeName';
  }

  @override
  String statsSetSelectedAnnouncement(String name, int count, String countForm) {
    return 'Vybrána sada $name, obsahuje $count $countForm';
  }

  @override
  String statsSetDefaultName(int index) {
    return 'Sada $index';
  }

  @override
  String statsCurrentSetLabel(String name) {
    return 'Aktivní sada: $name';
  }

  @override
  String get backupData => 'Zálohovat data';

  @override
  String get restoreData => 'Obnovit data';

  @override
  String get backupSuccess => 'Záloha vytvořena';

  @override
  String get restoreSuccess => 'Data obnovena';

  @override
  String get restoreConfirm =>
      'Opravdu chcete obnovit všechna data ze zálohy?';

  @override
  String get numberInfo => 'Info o čísle';

  @override
  String get infoValue => 'Hodnota';

  @override
  String get infoFraction => 'Zlomek';

  @override
  String get infoDms => 'DMS (stupně/minuty/vteřiny)';

  @override
  String get infoPercentage => 'Procenta';

  @override
  String get infoPrimeFactors => 'Rozklad na prvočísla';

  @override
  String get infoDivisors => 'Dělitele';

  @override
  String get infoRead => 'PŘEČÍST';

  @override
  String get infoNoResult => 'Nejprve vypočítejte výsledek.';

  @override
  String get infoNotInteger => 'Pouze pro celá kladná čísla';

  @override
  String get infoNotApplicable => 'nedostupné';

  @override
  String get dialogSizeSetting => 'Velikost dialogů';

  @override
  String get dialogSizeCompact => 'Kompaktní';

  @override
  String get dialogSizeWide => 'Široký';

  @override
  String get dialogSizeFullscreen => 'Celá obrazovka';
}
