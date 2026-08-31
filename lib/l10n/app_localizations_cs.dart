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
  String get tutorialText => 'Vítejte v Mluvící kalkulačce. \n\nZákladní ovládání:\n- Aplikace se ovládá primárně tlačítky na obrazovce nebo klávesnicí.\n- Se čtečkou obrazovky (TalkBack/NVDA) se pohybujte pomocí gest nebo kláves tabulátoru.\n- Každé tlačítko po aktivaci ohlásí svou funkci hlasem.\n- Výsledek se ohlásí automaticky po stisknutí tlačítka \'=\' (nebo klávesy Enter).\n\nRežimy a funkce:\n- Režimy (Vědecký, Statistika atd.) mění rozložení klávesnice.\n- Pokročilé funkce jsou dostupné v menu pod tlačítkem \'Pokročilé funkce\'.\n\nStatistika:\n- V režimu Statistika můžete vytvářet sady dat pro výpočty.\n- Tlačítkem SETS spravujete jednotlivé sady (vytvoření, přejmenování, mazání).\n- Tlačítkem M+ přidáte hodnotu do aktuální sady.\n- Statistické výpočty (průměr, směrodatná odchylka atd.) zobrazíte tlačítkem STATS.\n- Pokud vkládáte mnoho hodnot najednou, aplikace ohlásí pouze počet. Detailní seznam posledních vložených hodnot si můžete nechat přečíst v menu \'Pokročilé funkce\' pod volbou \'Přečíst naposledy vložená data\'.\n\nKlávesové zkratky:\n- Enter: Výsledek\n- Backspace: Smazat poslední znak\n- Escape/Delete: Vymazat displej\n- S, C, T: Sinus, Kosinus, Tangens (Shift pro inverzní funkce)\n- P: Pí, Q: Odmocnina, A: Absolutní hodnota\n- Ctrl+PageDown/PageUp: přepnutí stránky funkcí a čísel ve vědeckém režimu';

  @override
  String get tutorialTabIntro => 'Úvod';

  @override
  String get tutorialTabBasic => 'Základní';

  @override
  String get tutorialTabScientific => 'Vědecká';

  @override
  String get tutorialTabStatistics => 'Statistika';

  @override
  String get tutorialTabElectrician => 'Elektro';

  @override
  String get tutorialTabUnit => 'Převody';

  @override
  String get tutorialTabTime => 'Čas';

  @override
  String get tutorialTabCurrency => 'Měna';

  @override
  String get tutorialTabStatsManagement => 'Sady & čtení';

  @override
  String get tutorialIntro => 'Vítejte v Mluvící kalkulačce.\n\nZákladní ovládání:\n- Tlačítka na obrazovce nebo klávesnice.\n- S TalkBack/NVDA gesty nebo Tab.\n- Každé tlačítko ohlásí funkci hlasem.\n- Výsledek po \'=\' / Enter se ohlásí automaticky.\n- Historie, Pokročilé funkce a Nastavení přístupnosti v horní liště.\n\nKlávesové zkratky (všechny režimy):\n- Enter: =  • Backspace: DEL  • Esc/Delete: C  • Ctrl+1 až Ctrl+7: přepnutí režimu  • Ctrl+, : přístupnost  • Ctrl+Tab / Shift+Ctrl+Tab: další/předchozí režim\n\nNápověda ke statistice: Podrobný popis statistického režimu najdete v záložkách Statistika a Sady & čtení. Rychlou nápovědu otevřete i z Pokročilých funkcí tlačítkem Nápověda ke statistice. Pořadí čtení statistického souhrnu se nastavuje přímo v dialogu STATS tlačítkem Pořadí čtení.';

  @override
  String get tutorialBasic => 'Režim Základní – běžné výpočty.\n\nTlačítka: C (vymazat), ( ) závorky, / * - + operátory, 0-9 . desetinná tečka, … perioda (krátký stisk přepne periodu, dlouhý otevře editor), % procenta, DEL, =.\n\nTip: Pro opakující se desetinná čísla zadejte např. 0,1(6) a pokračujte ve výpočtu. Krátký stisk … posune periodu vlevo, dlouhý otevře ruční editor.';

  @override
  String get tutorialScientific => 'Režim Vědecká – dvě stránky.\n\nČíselná stránka: C ( ), / 7 8 9 * 4 5 6 - 1 2 3 + 0 . … EXP % DEL =.\nFunkční stránka (FUNKCE): SIN COS TAN ASIN ACOS ATAN √ ∛ ⁿ√ ! LOG LN x² x³ ^ π DMS °→\' \'→° ABS ANS C DEL =.\nPřepínač ČÍSLA/FUNKCE dole, klávesově Ctrl+PageUp/PageDown. Tl. DEG/RAD přepíná stupně/radiány (oznamuje se). Paměť STO/RCL/CLR + proměnné A-F,X,Y,M a Pokročilé funkce (Goniometrie, Funkce, Paměť, Perioda, Zobrazení NORM/FIX/SCI/ENG).';

  @override
  String get tutorialStatistics => 'Režim Statistika – práce se sadami.\n\nTlačítka: SETS MC MR M+ STATS C DEL / 7 8 9 * 4 5 6 - 1 2 3 + 0 . ; =.\nSETS: správa sad a složek – viz záložka Sady & čtení.\nM+ krátce: uloží čísla z displeje (oddělovač ;) do aktivní sady. M+ dlouze / Ctrl+M: zadá počet opakování. Při ≥2 záznamech se zobrazí Kontrola dat před uložením s možností potvrdit.\nMC: vymaže sadu. MR: přehled/editace dat (seskupené hodnoty s počtem výskytů, mazání záznamů).\nSTATS: souhrn pro vybrané pole – nahoře přepínač pole (je-li více polí), zaškrtávátko Číst hodnoty v paměti (skryje/přidá sekci Všechny hodnoty v paměti a ovlivní hlasové čtení), tabulka vypočtených statistik (N, MIN, MAX, SUM, MEAN, VAR, SD, MED, MODE, CV, WMEAN) a tlačítko Pořadí čtení pro přizpůsobení čtení.\nPokročilé funkce: MEAN/SD/VAR/SUM/MED/MODE/CV/WMEAN/MIN/MAX + čtení poslední dávky. Více polí: hodnoty zadávej jako např. 80;2 pro WMEAN (hodnota;váha). Jednotky polí lze nastavit při vytváření/editaci sady a zobrazují se v souhrnu.';

  @override
  String get tutorialElectrician => 'Režim Elektro – Ohmův zákon a výkon.\n\nTlačítka: OHM_V (U) OHM_I (I) OHM_R (R) C ; 7 8 9 / 4 5 6 * 1 2 3 - 0 . DEL + ANS =.\nNejprve zvolte co počítat (OHM_V/I/R, zvýrazní se), pak zadejte dvě hodnoty oddělené ; např. 12;4 a =.\nU = I×R, I = U/R, R = U/I. Výsledek se ohlásí s jednotkou a prefixem (mili/kilo/mega). Chyba dělení nulou se ohlásí.';

  @override
  String get tutorialUnit => 'Režim Převody jednotek.\n\nKategorie: Délka, Hmotnost, Plocha, Objem, Tlak, Čas, Napětí, Proud, Odpor, Výkon.\nV Pokročilých funkcích vyberte kategorii, jednotku Z a Na (např. m → km), zadejte číslo a PŘEVÉST. Výsledek se ohlásí i zapíše do historie (\"Převedeno z … na …\").\nKlávesnice v tomto režimu jen číselná (C 0-9 . DEL =).';

  @override
  String get tutorialTime => 'Režim Čas – práce s HH:MM[:SS].\n\nTlačítka: C : DEL / 7 8 9 * 4 5 6 - 1 2 3 + 0 ; NOW =.\nFormát: 12:34 nebo 12:34:56. Operátory + - přičítají/odečítají časy, ; = ROZDÍL (absolutní rozdíl). NOW/TEĎ vloží aktuální čas. Pokročilé: TO_SEC (čas→sekundy), TO_HMS/NA ČAS (sekundy→čas), DIFF. Příklad: 02:30 + 01:45 = 04:15:00.';

  @override
  String get tutorialCurrency => 'Režim Měna – kurzy vztažené k CZK.\n\nKlávesnice číselná, volba Z měny / Na měnu v Pokročilých funkcích, PŘEVÉST. Tlačítka SPRÁVA KURZŮ (editace/přidání/smazání, CZK=1 pevně) a AKTUALIZOVAT KURZY (online ČNB, hlásí \"Aktualizuji…\" / \"Kurzy aktualizovány\" / offline chybu). Poslední aktualizace se zobrazuje. Výsledek: \"Převedeno X EUR na Y USD. Výsledek …\". Kurzy se ukládají.';

  @override
  String get tutorialStatsManagement => 'Správa statistických sad a čtení souhrnu.\n\nDialog SETS:\n- Hledání podle názvu, řazení Poslední použití / Název / Počet, filtr Vše / Bez složky / konkrétní složka, přepínač Zobrazit archivované.\n- Každá sada má kartu s barvou (8 barev) a ikonou (8 ikon), odznak připnuto/archivováno, počet hodnot a název složky.\n- Menu ⋮ u sady: Vybrat, Přejmenovat, Upravit pole (+jednotky), Barva a ikona, Přesunout do složky, Kopírovat do složky, Duplikovat, Připnout/Odepnout (připnuté jsou vždy nahoře), Archivovat/Obnovit, Smazat (s potvrzením).\n- Tlačítka: Vytvořit novou sadu a Více (Rychlé vytvoření, Průvodce, Hlasové vytvoření) a Složky (Nová složka / Správa složek – přejmenovat/smazat, barva+ikona složky, sady zůstanou v Bez složky).\n- Vytvoření sady: název, počet polí, názvy polí a volitelné jednotky (kategorie Délka…Výkon). Jednotky se zobrazují v souhrnu a při hlasovém čtení.\n\nDialog STATS – Statistický souhrn:\n- Hlavička s názvem aktivní sady a přepínačem pole (klepnutím cykluje, ohlásí se hlasem i pro čtečku).\n- Zaškrtávátko Číst hodnoty v paměti – vypnutím se skryje sekce Všechny hodnoty v paměti a nečte se.\n- Sekce Všechny hodnoty v paměti (seřazené, s jednotkou) a Vypočtené statistiky (tabulka N + položky podle nastaveného pořadí).\n- Tlačítko Pořadí čtení (ikona reorder) otevře samostatný dialog pro nastavení pořadí čtení. Dříve bylo v Nastavení přístupnosti, nyní je přímo v souhrnu.\n\nDialog Pořadí čtení statistického souhrnu:\n- Horní část: Pořadí čtení statistického souhrnu – tři položky Hlavička souhrnu / Hodnoty v paměti / Vypočtené statistiky, tlačítka Posunout výše/níže a Obnovit výchozí. Čte se shora dolů.\n- Dolní část: Pořadí položek uvnitř Vypočtené statistiky (synchronizováno s tabulkou) – MEAN, SUM, VAR, SD, MED, MIN, MAX, MODE, CV, WMEAN, opět Posunout výše/níže a Obnovit výchozí.\n- Změny se ukládají automaticky a oznamují hlasem i pro čtečku obrazovky.\n\nPřístupnost: Všechna důležitá oznámení (uložení, smazání, změna pořadí) se oznamují hlasem kalkulačky i přes čtečku (liveRegion/announce), podle Režimu čtečky obrazovky.';

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
  String get modeTime => 'Čas';

  @override
  String get modeCurrency => 'Měna';

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
  String get modeSpeechTime => 'časový režim';

  @override
  String get modeSpeechCurrency => 'měnový režim';

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
  String get statsReviewTitle => 'Kontrola dat před uložením';

  @override
  String statsReviewSummary(Object count, Object name) {
    return 'Připraveno $count záznamů k uložení do sady $name.';
  }

  @override
  String get statsAllValuesSection => 'Všechny hodnoty v paměti';

  @override
  String get statsComputedSection => 'Vypočtené statistiky';

  @override
  String get statsN => 'Počet hodnot';

  @override
  String get statsMin => 'Minimum';

  @override
  String get statsMax => 'Maximum';

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
  String get statsHelpTitle => 'Nápověda ke statistice';

  @override
  String get statsHelpButton => 'Nápověda k ovládání';

  @override
  String get statsHelpText => '=== NÁPOVĚDA KE STATISTICE ===\n\nTLAČÍTKA NA KLÁVESNICI:\n\nSETS – Správa statistických sad a složek. Umožňuje vytvořit, přejmenovat, smazat, přepínat, duplikovat, připnout, archivovat a přesouvat sady mezi složkami. Obsahuje hledání, řazení (Poslední použití/Název/Počet), filtr Vše/Bez složky/složka a přepínač archivovaných. V menu Více: Rychlé vytvoření, Průvodce a Hlasové vytvoření. Složky se spravují tlačítkem Složky (Nová složka / Správa složek – barva a ikona, sady zůstanou v Bez složky po smazání).\n\nM+ (krátké stisknutí) – Přidá zadanou hodnotu (nebo více hodnot oddělených středníkem) do aktivní sady. Při ≥2 záznamech se zobrazí Kontrola dat před uložením.\n\nM+ (dlouhé stisknutí / Ctrl+M) – Přidá hodnoty a umožní zadat počet opakování pro hromadné vložení.\n\nMC – Smaže všechna data v aktivní sadě.\n\nMR – Zobrazí všechna uložená data v editovatelném seznamu (seskupené hodnoty s počtem výskytů, možnost mazat záznamy, tlačítko Správa sad).\n\nSTATS – Zobrazí statistický souhrn: hlavička s názvem sady a přepínačem pole, zaškrtávátko Číst hodnoty v paměti, sekce Všechny hodnoty v paměti (seřazené, s jednotkou) a Vypočtené statistiky (tabulka N, MIN, MAX, SUM, MEAN, VAR, SD, MED, MODE, CV, WMEAN podle nastaveného pořadí). Tlačítko Pořadí čtení otevře nastavení čtení. Přepínač pole cykluje klepnutím a oznamuje se hlasem i pro čtečku.\n\n; (středník) – Oddělovač hodnot při zadávání více hodnot najednou (např. 5;10;15 nebo 80;2 pro dvě pole).\n\nPOKROČILÉ FUNKCE (dostupné z tlačítka se seznamem v horní liště):\n\nMEAN – Aritmetický průměr všech hodnot.\nSD – Směrodatná odchylka (míra rozptylu hodnot kolem průměru).\nVAR – Rozptyl (průměrná čtvercová odchylka od průměru).\nSUM – Součet všech hodnot.\nMED – Medián (prostřední hodnota seřazených dat).\nMODE – Modus (nejčastější hodnota).\nMIN – Minimální hodnota všech hodnot.\nMAX – Maximální hodnota všech hodnot.\nCV – Variační koeficient (SD v procentech průměru).\nWMEAN – Vážený průměr (vyžaduje 2 pole: hodnoty a váhy).\n\nPOŘADÍ ČTENÍ SOUHRNU (tlačítko Pořadí čtení v dialogu STATS):\nHorní část nastavuje pořadí sekcí Hlavička souhrnu / Hodnoty v paměti / Vypočtené statistiky (čte se shora dolů, tlačítka Posunout výše/níže, Obnovit výchozí). Dolní část nastavuje pořadí položek uvnitř Vypočtené statistiky (MEAN, SUM, VAR, SD, MED, MIN, MAX, MODE, CV, WMEAN) synchronizované s tabulkou. Změny se oznamují hlasem i pro čtečku. Dříve bylo v Nastavení přístupnosti, nyní přímo v souhrnu.\n\nPOLÍ V SADĚ:\n\nKaždá sada může mít více polí (např. \"Hodnota\" a \"Váha\") s volitelnou jednotkou (kategorie Délka…Výkon). Při vytváření sady (SETS → Vytvořit novou sadu nebo Více → Rychlé/Průvodce/Hlasem) přidáš pole tlačítkem \"Přidat pole\" a vybereš jednotku. Jednotky se zobrazují v souhrnu a při hlasovém čtení. Přepínat pole lze v dialogu STATS nebo v Pokročilých funkcích. Každá sada má barvu (8) a ikonu (8), lze ji připnout (vždy nahoře) nebo archivovat.\n\nVÁŽENÝ PRŮMĚR (WMEAN):\n\nVyžaduje sadu s alespoň 2 poli. Pole 0 = hodnoty, pole 1 = váhy. Postup: 1) Vytvoř sadu se 2 poli (např. \"Hodnota\" a \"Váha\"). 2) Zadávej hodnoty a váhy oddělené středníkem, např. \"80;2\" (hodnota 80 s váhou 2). 3) Po zadání všech dat klepni v Pokročilých funkcích na WMEAN. 4) Aplikace vypočte: (hodnota1 × váha1 + hodnota2 × váha2 + ...) / (váha1 + váha2 + ...).\n\nTIPY:\n- Lze vytvářet více sad pro různé skupiny dat a organizovat je do složek.\n- Každá sada může mít více polí (např. hodnoty, váhy) s jednotkami.\n- Nová sada se vytvoří automaticky při prvním vložení dat.\n- Data, pořadí čtení a nastavení Číst hodnoty v paměti se automaticky ukládají.\n- Všechna důležitá oznámení se oznamují hlasem i přes čtečku obrazovky podle Režimu čtečky.';

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
  String get statsHelpKeyboardSets => 'SETS – Správa statistických sad a složek. Hledání, řazení, filtr, barva/ikona, připnutí/archiv, přesun/kopie/duplikace, složky a 3 způsoby vytvoření (Rychlé, Průvodce, Hlasem).';

  @override
  String get statsHelpKeyboardMPlus => 'M+ (krátké stisknutí) – Přidá hodnoty do aktivní sady. Při ≥2 záznamech zobrazí Kontrolu dat před uložením. Dlouhé stisknutí / Ctrl+M – zadá počet opakování pro hromadné vložení.';

  @override
  String get statsHelpKeyboardMc => 'MC – Smaže všechna data v aktivní sadě.';

  @override
  String get statsHelpKeyboardMr => 'MR – Zobrazí všechna uložená data v editovatelném seznamu (seskupené hodnoty s počtem výskytů, mazání záznamů, Správa sad).';

  @override
  String get statsHelpKeyboardStats => 'STATS – Statistický souhrn: hlavička s přepínačem pole, zaškrtávátko Číst hodnoty v paměti, sekce Všechny hodnoty a Vypočtené statistiky (N, MIN, MAX, SUM, MEAN, VAR, SD, MED, MODE, CV, WMEAN) a tlačítko Pořadí čtení.';

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
  String get statsHelpAdvancedMin => 'MIN – Minimální hodnota všech hodnot.';

  @override
  String get statsHelpAdvancedMax => 'MAX – Maximální hodnota všech hodnot.';

  @override
  String get statsHelpAdvancedCv => 'CV – Variační koeficient (SD v procentech průměru).';

  @override
  String get statsHelpAdvancedWmean => 'WMEAN – Vážený průměr (vyžaduje 2 pole: hodnoty a váhy).';

  @override
  String get statsHelpFieldsDesc => 'Každá sada může mít více polí (např. \"Hodnota\" a \"Váha\") s volitelnou jednotkou (kategorie Délka…Výkon). Barva (8) a ikona (8), připnutí (vždy nahoře) / archiv. Pole přidáš při vytváření sady tlačítkem \"Přidat pole\" a vybereš jednotku. Přepínat pole lze v dialogu STATS nebo v Pokročilých funkcích.';

  @override
  String get statsHelpWeightedMeanDesc => 'Vyžaduje sadu s alespoň 2 poli. Pole 0 = hodnoty, pole 1 = váhy.\\n\\nPostup:\\n1) Vytvoř sadu se 2 poli (např. \"Hodnota\" a \"Váha\").\\n2) Zadávej hodnoty a váhy oddělené středníkem, např. \"80;2\" (hodnota 80 s váhou 2).\\n3) Po zadání všech dat klepni v Pokročilých funkcích na WMEAN.\\n4) Aplikace vypočte: (hodnota1 × váha1 + hodnota2 × váha2 + ...) / (váha1 + váha2 + ...).';

  @override
  String get statsHelpTip1 => 'Lze vytvářet více sad a organizovat je do složek (barva, ikona, připnutí, archiv).';

  @override
  String get statsHelpTip2 => 'Každá sada může mít více polí s jednotkami (např. hodnoty, váhy).';

  @override
  String get statsHelpTip3 => 'Nová sada se vytvoří automaticky při prvním vložení dat.';

  @override
  String get statsHelpTip4 => 'Data, pořadí čtení a nastavení Číst hodnoty v paměti se ukládají automaticky. Oznámení jdou hlasem i přes čtečku.';

  @override
  String get statsWeightedMean => 'Vážený průměr';

  @override
  String get backupData => 'Zálohovat data';

  @override
  String get restoreData => 'Obnovit data';

  @override
  String get backupSuccess => 'Záloha vytvořena';

  @override
  String get restoreSuccess => 'Data obnovena';

  @override
  String get restoreConfirm => 'Opravdu chcete obnovit všechna data ze zálohy?';

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

  @override
  String get voiceOn => 'Hlas zapnut';

  @override
  String get voiceOff => 'Hlas vypnut';

  @override
  String get cleared => 'Vymazat';

  @override
  String get deleted => 'Smazáno';

  @override
  String get historyCleared => 'Historie smazána';

  @override
  String get appIsCurrent => 'Aplikace je aktuální.';

  @override
  String get degreesUnit => 'stupňů';

  @override
  String get minutesUnit => 'minut';

  @override
  String get secondsUnit => 'sekund';

  @override
  String get piSpoken => 'pí';

  @override
  String get minusWord => 'mínus';

  @override
  String get timesTenTo => 'krát deset na';

  @override
  String get expressionNotUnderstood => 'Výrazu nerozumím, zkuste zkontrolovat závorky nebo znaménka';

  @override
  String get cannotDivideByZero => 'Nulou nelze dělit';

  @override
  String get valueOutOfRange => 'Hodnota je mimo povolený rozsah funkce';

  @override
  String resultIs(String value) {
    return 'Výsledek je $value';
  }

  @override
  String get conversionError => 'Chyba převodu';

  @override
  String unitConverted(String from, String to, String value, String toUnit) {
    return 'Převedeno z $from na $to. Výsledek je $value $toUnit';
  }

  @override
  String get backupError => 'Chyba při vytváření zálohy';

  @override
  String get restoreError => 'Chyba při obnově dat';

  @override
  String decimalPlacesSet(int count) {
    return 'Nastaveno $count desetinných míst';
  }

  @override
  String savedToVariable(String name, String value) {
    return 'Uloženo do proměnné $name: $value';
  }

  @override
  String get cannotStoreExpression => 'Výraz nelze vypočítat, do paměti se neuložilo nic.';

  @override
  String recalledFromVariable(String name, String value) {
    return 'Vyvoláno z proměnné $name: $value';
  }

  @override
  String variableName(String name) {
    return 'Proměnná $name';
  }

  @override
  String get selectMemory => 'Vyberte paměť';

  @override
  String get selectMemoryRecall => 'Vyberte paměť pro vyvolání';

  @override
  String get memoryCleared => 'Paměť smazána';

  @override
  String insertedValue(String value) {
    return 'Vloženo $value';
  }

  @override
  String inverseResult(String name) {
    return 'Inverzní $name z výsledku';
  }

  @override
  String resultOf(String name) {
    return '$name z výsledku';
  }

  @override
  String get standardDisplaySet => 'Nastaveno standardní zobrazení';

  @override
  String get segment16On => 'Zapnut 16-segmentový displej';

  @override
  String get segment7On => 'Zapnut 7-segmentový displej';

  @override
  String get screenReaderAuto => 'Režim čtečky: automaticky';

  @override
  String get screenReaderOn => 'Režim čtečky obrazovky zapnut';

  @override
  String get screenReaderOff => 'Režim čtečky obrazovky vypnut';

  @override
  String get angleFormatDms => 'Formát nastaven na stupně, minuty a sekundy';

  @override
  String get angleFormatDecimal => 'Formát nastaven na desetinné stupně';

  @override
  String themeSet(String mode) {
    return 'Motiv nastaven na $mode';
  }

  @override
  String get themeSystem => 'systémový';

  @override
  String get themeLight => 'světlý';

  @override
  String get themeDark => 'tmavý';

  @override
  String zoomUpperPct(int percent) {
    return 'Zoom horního řádku $percent procent';
  }

  @override
  String zoomLowerPct(int percent) {
    return 'Zoom dolního řádku $percent procent';
  }

  @override
  String speechRatePct(int percent) {
    return 'Rychlost $percent procent';
  }

  @override
  String volumePct(int percent) {
    return 'Hlasitost $percent procent';
  }

  @override
  String categorySelected(String category) {
    return 'Kategorie $category';
  }

  @override
  String fromUnitSelected(String unit) {
    return 'Z jednotky $unit';
  }

  @override
  String toUnitSelected(String unit) {
    return 'Na jednotku $unit';
  }

  @override
  String get calcNameVoltage => 'napětí';

  @override
  String get calcNameCurrent => 'proud';

  @override
  String get calcNameResistance => 'odpor';

  @override
  String get calcInputVoltage => 'proud a odpor';

  @override
  String get calcInputCurrent => 'napětí a odpor';

  @override
  String get calcInputResistance => 'napětí a proud';

  @override
  String calcIntro(String name, String input) {
    return 'Výpočet $name. Zadejte $input oddělené středníkem.';
  }

  @override
  String elecResult(String name, String value, String unit) {
    return '$name je $value $unit';
  }

  @override
  String get elecTwoValuesError => 'Zadejte dvě hodnoty oddělené středníkem.';

  @override
  String get elecFormatError => 'Zadané hodnoty v elektro režimu nemají platný číselný formát.';

  @override
  String get elecInvalidResult => 'Výsledek elektro výpočtu není platné číslo.';

  @override
  String get formatDms => 'Formát nastaven na stupně, minuty a sekundy.';

  @override
  String get formatDecimalDegrees => 'Formát nastaven na desetinné stupně.';

  @override
  String get errorSegment => 'CHYBA';

  @override
  String get confirmationTitle => 'Potvrzení';

  @override
  String get yesConfirmHistory => 'Ano, potvrdit smazání celé historie výpočtů';

  @override
  String get noCancelHistory => 'Ne, zrušit smazání a ponechat historii';

  @override
  String get precisionTitle => 'Nastavení přesnosti';

  @override
  String get updateAvailableTitle => 'Dostupná aktualizace';

  @override
  String newVersionSemantics(String version, String current) {
    return 'Je dostupná nová verze $version. Vaše verze je $current.';
  }

  @override
  String newVersionText(String version, String current) {
    return 'Je dostupná nová verze $version.\n\nVaše verze: $current';
  }

  @override
  String get whatIsNew => 'Co je nového:';

  @override
  String get later => 'Později';

  @override
  String get showRelease => 'Zobrazit release';

  @override
  String cannotOpenBrowser(String error) {
    return 'Nelze otevřít prohlížeč: $error';
  }

  @override
  String get checkForUpdates => 'Zkontrolovat aktualizace';

  @override
  String get sectionTrigonometry => 'Goniometrie';

  @override
  String get sectionFunctions => 'Funkce';

  @override
  String get sectionMemory => 'Paměť';

  @override
  String get sectionDisplay => 'Zobrazení';

  @override
  String get collapse => 'Sbalit';

  @override
  String get expand => 'Rozbalit';

  @override
  String get convertButton => 'PŘEVÉST';

  @override
  String get standardDisplayLabel => 'Standardní zobrazení';

  @override
  String get fixedDecimalLabel => 'Zobrazení s pevným počtem desetinných míst';

  @override
  String get scientificNotationLabel => 'Vědecký zápis';

  @override
  String get engineeringNotationLabel => 'Inženýrský zápis';

  @override
  String get categoryLabel => 'Kategorie';

  @override
  String get fromLabel => 'Z';

  @override
  String get toLabel => 'Na';

  @override
  String get segment16Name => '16-segmentový';

  @override
  String get segment7Name => '7-segmentový';

  @override
  String get switchDisplayType => 'Přepnutí typu displeje';

  @override
  String get toggleVoiceOutput => 'Přepnutí hlasového výstupu';

  @override
  String get enabledState => 'Zapnuto';

  @override
  String get disabledState => 'Vypnuto';

  @override
  String get screenReaderSection => 'Režim čtečky obrazovky';

  @override
  String get screenReaderAutoLabel => 'Automaticky podle čtečky';

  @override
  String get ttsEngineSettings => 'Nastavení hlasového engine';

  @override
  String engineLabel(String engine) {
    return 'Engine: $engine';
  }

  @override
  String get defaultEngine => 'Výchozí';

  @override
  String get openTtsSystemSettings => 'Otevřít systémové nastavení TTS';

  @override
  String get ttsSettingsButton => 'Nastavení TTS';

  @override
  String get voiceSettings => 'Nastavení hlasu';

  @override
  String voiceLabel(String voice) {
    return 'Hlas: $voice';
  }

  @override
  String get toggleAngleFormat => 'Přepnutí formátu úhlů';

  @override
  String get themeSectionLabel => 'Výběr motivu aplikace';

  @override
  String get themeTitle => 'Motiv aplikace';

  @override
  String get themeSystemLabel => 'Systémový motiv';

  @override
  String get themeLightLabel => 'Světlý motiv';

  @override
  String get themeDarkLabel => 'Tmavý motiv';

  @override
  String get defaultStartupMode => 'Výchozí režim po spuštění';

  @override
  String get zoomUpperControls => 'Ovládání zoomu horního řádku';

  @override
  String get zoomLowerControls => 'Ovládání zoomu dolního řádku';

  @override
  String get decreaseUpperZoom => 'Zmenšit zoom horního řádku';

  @override
  String get increaseUpperZoom => 'Zvětšit zoom horního řádku';

  @override
  String get decreaseLowerZoom => 'Zmenšit zoom dolního řádku';

  @override
  String get increaseLowerZoom => 'Zvětšit zoom dolního řádku';

  @override
  String zoomValuePct(int value) {
    return 'Hodnota zoomu: $value %';
  }

  @override
  String get speechRateControls => 'Ovládání rychlosti hlasu';

  @override
  String get decreaseSpeechRate => 'Snížit rychlost';

  @override
  String get increaseSpeechRate => 'Zvýšit rychlost';

  @override
  String speechRateValue(int value) {
    return 'Aktuální rychlost: $value %';
  }

  @override
  String get volumeControls => 'Ovládání hlasitosti';

  @override
  String get decreaseVolume => 'Snížit hlasitost';

  @override
  String get increaseVolume => 'Zvýšit hlasitost';

  @override
  String volumeValue(int value) {
    return 'Aktuální hlasitost: $value %';
  }

  @override
  String get dataManagementSection => 'Záloha a obnova dat';

  @override
  String get dataManagementTitle => 'Správa dat';

  @override
  String get yesShort => 'ANO';

  @override
  String get noShort => 'NE';

  @override
  String get moreOptions => 'Další možnosti';

  @override
  String get news => 'Novinky';

  @override
  String get currencyFromLabel => 'Z měny';

  @override
  String get currencyToLabel => 'Na měnu';

  @override
  String currencyRateLabel(String code) {
    return 'Kurz (CZK za 1 $code)';
  }

  @override
  String get currencyManageTitle => 'Správa kurzů';

  @override
  String get currencyManageButton => 'SPRÁVA KURZŮ';

  @override
  String get currencyUpdateButton => 'AKTUALIZOVAT KURZY';

  @override
  String get currencyUpdating => 'Aktualizuji kurzy…';

  @override
  String get currencyUpdated => 'Kurzy aktualizovány';

  @override
  String currencyLastUpdate(String date) {
    return 'Poslední aktualizace: $date';
  }

  @override
  String get currencyNoRates => 'Žádné kurzy k zobrazení.';

  @override
  String get currencyOfflineError => 'Nepodařilo se aktualizovat kurzy. Zkontrolujte připojení. Zachovány poslední kurzy.';

  @override
  String get currencyParseError => 'Nepodařilo se zpracovat kurzy ČNB.';

  @override
  String currencyConverted(String value, String from, String to, String result, String toUnit, String rate) {
    return 'Převedeno $value $from na $to. Výsledek je $result $toUnit. Kurz $rate';
  }

  @override
  String get currencyInvalidRate => 'Neplatný kurz';

  @override
  String get currencyCzkLocked => 'Kurz koruny je pevně 1,00';

  @override
  String get currencyAddTitle => 'Přidat měnu';

  @override
  String get currencyCodeLabel => 'Kód měny (např. EUR)';

  @override
  String get currencyAddButton => 'PŘIDAT';

  @override
  String get timeNow => 'TEĎ';

  @override
  String get timeNowHint => 'Vložit aktuální čas';

  @override
  String get timeDiff => 'ROZDÍL';

  @override
  String get timeDiffHint => 'Rozdíl dvou časů';

  @override
  String get timeToSec => 'NA SEKUNDY';

  @override
  String get timeToHms => 'NA ČAS';

  @override
  String timeCurrentIs(String time) {
    return 'Aktuální čas je $time';
  }

  @override
  String get timeInvalidFormat => 'Neplatný formát času. Použijte HH:MM nebo HH:MM:SS.';

  @override
  String timeResult(String time) {
    return 'Výsledek je $time';
  }

  @override
  String timeDiffResult(String time) {
    return 'Rozdíl je $time';
  }

  @override
  String timeToSecResult(String hms, String sec) {
    return '$hms je $sec sekund';
  }

  @override
  String timeToHmsResult(String sec, String hms) {
    return '$sec sekund je $hms';
  }

  @override
  String get timeHelp => 'Zadejte čas ve formátu HH:MM nebo HH:MM:SS. Použijte + nebo - mezi časy. Tlačítko ROZDÍL spočítá absolutní rozdíl. TEĎ vloží aktuální čas.';

  @override
  String expressionResultIs(String expression, String result) {
    return 'Příklad $expression, $result';
  }

  @override
  String announceExpressionState(String state) {
    return 'Oznamování příkladu: $state';
  }
}
