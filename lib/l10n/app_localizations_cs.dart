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
  String get statsN => 'Počet hodnot';

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
  String get statsWeightedMean => 'Vážený průměr';

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
  String get statsHelpTitle => 'Nápověda ke statistice';

  @override
  String get statsHelpButton => 'Nápověda k ovládání';

  @override
  String get statsHelpText => '=== NÁPOVĚDA KE STATISTICE ===\n\nTLAČÍTKA NA KLÁVESNICI:\n\nSETS – Správa statistických sad. Umožňuje vytvořit novou sadu, přejmenovat ji, smazat nebo přepínat mezi sadami.\n\nM+ (krátké stisknutí) – Přidá zadanou hodnotu (nebo více hodnot oddělených středníkem) do aktivní sady.\n\nM+ (dlouhé stisknutí) – Přidá hodnoty a umožní zadat počet opakování pro hromadné vložení stejných dat.\n\nMC – Smaže všechna data v aktivní sadě.\n\nMR – Zobrazí všechna uložená data v editovatelném seznamu.\n\nSTATS – Zobrazí statistický souhrn pro vybrané pole: průměr, součet, rozptyl, směrodatnou odchylku, medián, modus a variační koeficient.\n\n; (středník) – Oddělovač hodnot při zadávání více hodnot najednou (např. 5;10;15).\n\nPOKROČILÉ FUNKCE (dostupné z tlačítka se seznamem v horní liště):\n\nMEAN – Aritmetický průměr všech hodnot.\nSD – Směrodatná odchylka (míra rozptylu hodnot kolem průměru).\nVAR – Rozptyl (průměrná čtvercová odchylka od průměru).\nSUM – Součet všech hodnot.\nMED – Medián (prostřední hodnota seřazených dat).\nMODE – Modus (nejčastější hodnota).\nCV – Variační koeficient (SD v procentech průměru).\nWMEAN – Vážený průměr (vyžaduje 2 pole: hodnoty a váhy).\n\nPOLÍ V SADĚ:\n\nKaždá sada může mít více polí (např. "Hodnota" a "Váha"). Při vytváření sady (SETS → Vytvořit novou sadu) přidáš další pole tlačítkem "Přidat pole". Poté můžeš přepínat, pro které pole se statistiky počítají – buď v dialogu STATS, nebo v Pokročilých funkcích.\n\nVÁŽENÝ PRŮMĚR (WMEAN):\n\nVyžaduje sadu s alespoň 2 poli. Pole 0 = hodnoty, pole 1 = váhy. Postup: 1) Vytvoř sadu se 2 poli (např. "Hodnota" a "Váha"). 2) Zadávej hodnoty a váhy oddělené středníkem, např. "80;2" (hodnota 80 s váhou 2). 3) Po zadání všech dat klepni v Pokročilých funkcích na WMEAN. 4) Aplikace vypočte: (hodnota1 × váha1 + hodnota2 × váha2 + ...) / (váha1 + váha2 + ...).\n\nTIPY:\n- Lze vytvářet více sad pro různé skupiny dat.\n- Každá sada může mít více polí (např. hodnoty, váhy).\n- Nová sada se vytvoří automaticky při prvním vložení dat.\n- Data se automaticky ukládají do paměti telefonu.';

  @override
  String get statsHelpKeyboardSection => 'Tlačítka na klávesnici';

  @override
  String get statsHelpAdvancedSection => 'Pokročilé funkce';

  @override
  String get statsHelpFieldsSection => 'Pole v sadě';

  @override
  String get statsHelpWeightedMeanSection => 'Vážený průměr (WMEAN)';

  @override
  String get statsHelpTipsSection => 'Tipy';

  @override
  String get statsHelpKeyboardSets => 'SETS – Správa statistických sad. Umožňuje vytvořit novou sadu, přejmenovat ji, smazat nebo přepínat mezi sadami.';

  @override
  String get statsHelpKeyboardMPlus => 'M+ (krátké stisknutí) – Přidá zadanou hodnotu (nebo více hodnot oddělených středníkem) do aktivní sady. Dlouhé stisknutí – Přidá hodnoty a umožní zadat počet opakování pro hromadné vložení stejných dat.';

  @override
  String get statsHelpKeyboardMc => 'MC – Smaže všechna data v aktivní sadě.';

  @override
  String get statsHelpKeyboardMr => 'MR – Zobrazí všechna uložená data v editovatelném seznamu.';

  @override
  String get statsHelpKeyboardStats => 'STATS – Zobrazí statistický souhrn pro vybrané pole: průměr, součet, rozptyl, směrodatnou odchylku, medián, modus a variační koeficient.';

  @override
  String get statsHelpKeyboardSemicolon => '; (středník) – Oddělovač hodnot při zadávání více hodnot najednou (např. 5;10;15).';

  @override
  String get statsHelpAdvancedMean => 'MEAN – Aritmetický průměr všech hodnot.';

  @override
  String get statsHelpAdvancedSd => 'SD – Směrodatná odchylka (míra rozptylu hodnot kolem průměru).';

  @override
  String get statsHelpAdvancedVar => 'VAR – Rozptyl (průměrná čtvercová odchylka od průměru).';

  @override
  String get statsHelpAdvancedSum => 'SUM – Součet všech hodnot.';

  @override
  String get statsHelpAdvancedMed => 'MED – Medián (prostřední hodnota seřazených dat).';

  @override
  String get statsHelpAdvancedMode => 'MODE – Modus (nejčastější hodnota).';

  @override
  String get statsHelpAdvancedCv => 'CV – Variační koeficient (SD v procentech průměru).';

  @override
  String get statsHelpAdvancedWmean => 'WMEAN – Vážený průměr (vyžaduje 2 pole: hodnoty a váhy).';

  @override
  String get statsHelpFieldsDesc => 'Každá sada může mít více polí (např. "Hodnota" a "Váha"). Při vytváření sady (SETS → Vytvořit novou sadu) přidáš další pole tlačítkem "Přidat pole". Poté můžeš přepínat, pro které pole se statistiky počítají – buď v dialogu STATS, nebo v Pokročilých funkcích.';

  @override
  String get statsHelpWeightedMeanDesc => 'Vyžaduje sadu s alespoň 2 poli. Pole 0 = hodnoty, pole 1 = váhy.\n\nPostup:\n1) Vytvoř sadu se 2 poli (např. "Hodnota" a "Váha").\n2) Zadávej hodnoty a váhy oddělené středníkem, např. "80;2" (hodnota 80 s váhou 2).\n3) Po zadání všech dat klepni v Pokročilých funkcích na WMEAN.\n4) Aplikace vypočte: (hodnota1 × váha1 + hodnota2 × váha2 + ...) / (váha1 + váha2 + ...).';

  @override
  String get statsHelpTip1 => 'Lze vytvářet více sad pro různé skupiny dat.';

  @override
  String get statsHelpTip2 => 'Každá sada může mít více polí (např. hodnoty, váhy).';

  @override
  String get statsHelpTip3 => 'Nová sada se vytvoří automaticky při prvním vložení dat.';

  @override
  String get statsHelpTip4 => 'Data se automaticky ukládají do paměti telefonu.';

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
