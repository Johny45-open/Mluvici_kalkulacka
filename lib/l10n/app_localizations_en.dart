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
  String get tutorialText => 'This calculator supports scientific calculations, statistics, electrical formulas, and unit conversions. \n\nKeyboard shortcuts:\nS - Sine (Shift+S for Arcsine)\nC - Cosine (Shift+C for Arccosine)\nT - Tangent (Shift+T for Arctangent)\nP - Pi\nQ - Square root\nEnter - Result\nCtrl+PageDown/PageUp - Switch between functions and numbers page in scientific mode';

  @override
  String get tutorialTabIntro => 'Intro';

  @override
  String get tutorialTabBasic => 'Basic';

  @override
  String get tutorialTabScientific => 'Scientific';

  @override
  String get tutorialTabStatistics => 'Statistics';

  @override
  String get tutorialTabElectrician => 'Electrical';

  @override
  String get tutorialTabUnit => 'Units';

  @override
  String get tutorialTabTime => 'Time';

  @override
  String get tutorialTabCurrency => 'Currency';

  @override
  String get tutorialTabStatsManagement => 'Sets & Reading';

  @override
  String get tutorialIntro => 'Welcome to Talking Calculator.\n\nBasic controls:\n- On-screen buttons or keyboard.\n- With TalkBack/NVDA use gestures or Tab.\n- Each button announces its function.\n- Result after \'=\' / Enter is announced automatically.\n- History, Advanced functions and Accessibility in the top bar.\n\nGlobal shortcuts:\n- Enter: =  • Backspace: DEL  • Esc/Delete: C  • Ctrl+1 to Ctrl+7: switch mode  • Ctrl+, : accessibility  • Ctrl+Tab / Shift+Ctrl+Tab: next/previous mode\n\nStatistics help: See tabs Statistics and Sets & Reading for details. Quick help is also in Advanced functions via Statistics Help. Reading order of the summary is set directly in the STATS dialog with the Reading order button.';

  @override
  String get tutorialBasic => 'Basic mode – everyday calculations.\n\nButtons: C (clear), ( ) parentheses, / * - + operators, 0-9 . decimal point, … repeating decimal (tap toggles period, long press opens editor), % percent, DEL, =.\n\nTip: Enter repeating decimals as e.g. 0.1(6) and continue. Short press … moves period left, long press opens manual editor.';

  @override
  String get tutorialScientific => 'Scientific mode – two pages.\n\nNumbers page: C ( ) / 7 8 9 * 4 5 6 - 1 2 3 + 0 . … EXP % DEL =.\nFunctions page (FUNCTIONS): SIN COS TAN ASIN ACOS ATAN √ ∛ ⁿ√ ! LOG LN x² x³ ^ π DMS °→\' \'→° ABS ANS C DEL =.\nToggle NUMBERS/FUNCTIONS at bottom, Ctrl+PageUp/PageDown. DEG/RAD switches degrees/radians. Memory STO/RCL/CLR + variables A-F,X,Y,M and Advanced functions (Trigonometry, Functions, Memory, Repeating, Display NORM/FIX/SCI/ENG).';

  @override
  String get tutorialStatistics => 'Statistics mode – data sets.\n\nButtons: SETS MC MR M+ STATS C DEL / 7 8 9 * 4 5 6 - 1 2 3 + 0 . ; =.\nSETS: manage sets and folders – see Sets & Reading tab.\nM+ short: stores display numbers (separator ;) to active set. M+ long / Ctrl+M: enter repeat count. With ≥2 records a Review before saving dialog appears for confirmation.\nMC: clear set. MR: view/edit data (grouped values with occurrence counts, delete records).\nSTATS: summary for selected field – field switcher at top (if multiple fields), checkbox Read values in memory (hides/shows All values section and affects speech), table of computed statistics (N, MIN, MAX, SUM, MEAN, VAR, SD, MED, MODE, CV, WMEAN) and Reading order button for customization.\nAdvanced: MEAN/SD/VAR/SUM/MED/MODE/CV/WMEAN/MIN/MAX + read last batch. Multiple fields: enter as e.g. 80;2 for WMEAN (value;weight). Field units can be set when creating/editing a set and appear in the summary.';

  @override
  String get tutorialElectrician => 'Electrical mode – Ohm\'s law & power.\n\nButtons: OHM_V (U) OHM_I (I) OHM_R (R) C ; 7 8 9 / 4 5 6 * 1 2 3 - 0 . DEL + ANS =.\nFirst choose what to calculate (OHM_V/I/R, highlighted), then enter two values separated by ; e.g. 12;4 and =.\nU = I×R, I = U/R, R = U/I. Result is announced with unit and prefix (milli/kilo/mega). Division by zero is announced.';

  @override
  String get tutorialUnit => 'Unit conversion mode.\n\nCategories: Length, Mass, Area, Volume, Pressure, Time, Voltage, Current, Resistance, Power.\nIn Advanced functions pick category, From and To units (e.g. m → km), enter number and CONVERT. Result is announced and added to history (\"Converted from … to …\").\nKeyboard is numeric only (C 0-9 . DEL =).';

  @override
  String get tutorialTime => 'Time mode – HH:MM[:SS].\n\nButtons: C : DEL / 7 8 9 * 4 5 6 - 1 2 3 + 0 ; NOW =.\nFormat: 12:34 or 12:34:56. Operators + - add/subtract, ; = DIFF (absolute difference). NOW inserts current time. Advanced: TO_SEC (time→seconds), TO_HMS (seconds→time), DIFF. Example: 02:30 + 01:45 = 04:15:00.';

  @override
  String get tutorialCurrency => 'Currency mode – rates relative to CZK.\n\nNumeric keyboard, pick From / To currency in Advanced functions, CONVERT. Buttons MANAGE RATES (edit/add/delete, CZK=1 fixed) and UPDATE RATES (online CNB, announces \"Updating…\" / \"Rates updated\" / offline error). Last update is shown. Result: \"Converted X EUR to Y USD. Result …\". Rates are persisted.';

  @override
  String get tutorialStatsManagement => 'Managing statistics sets and reading order.\n\nSETS dialog:\n- Search by name, sort by Last used / Name / Count, filter All / No folder / specific folder, toggle Show archived.\n- Each set card has color (8) and icon (8), pinned/archived badge, value count and folder name.\n- ⋮ menu: Select, Rename, Edit fields (+units), Color & icon, Move to folder, Copy to folder, Duplicate, Pin/Unpin (pinned stay on top), Archive/Restore, Delete (with confirmation).\n- Buttons: Create new set and More (Quick create, Guided wizard, Voice creation) and Folders (New folder / Manage folders – rename/delete, folder color+icon; sets stay in No folder after deletion).\n- Creating a set: name, field count, field names and optional units (categories Length…Power). Units appear in the summary and are spoken.\n\nSTATS – Statistics summary:\n- Header with active set name and field switcher (tap cycles, announced via voice and screen reader).\n- Checkbox Read values in memory – off hides the All values in memory section and skips it in speech.\n- Sections All values in memory (sorted, with unit) and Computed statistics (table N + items in custom order).\n- Reading order button (reorder icon) opens the dedicated dialog. Previously in Accessibility settings, now directly in the summary.\n\nReading order dialog:\n- Top: Reading order of the summary – three items Summary header / Values in memory / Computed statistics, buttons Move up/down and Restore default. Read top to bottom.\n- Bottom: Order inside Computed statistics (synced with table) – MEAN, SUM, VAR, SD, MED, MIN, MAX, MODE, CV, WMEAN, again Move up/down and Restore default.\n- Changes are saved automatically and announced via voice and screen reader.\n\nAccessibility: All important announcements (save, delete, order change) go via calculator voice and screen reader (liveRegion/announce) according to Screen reader mode.';

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

  @override
  String get helpTooltip => 'Usage help';

  @override
  String get muteVoice => 'Mute voice';

  @override
  String get unmuteVoice => 'Enable voice';

  @override
  String get modeBasic => 'Basic';

  @override
  String get modeScientific => 'Scientific';

  @override
  String get modeStatistics => 'Statistics';

  @override
  String get modeElectrician => 'Electrical';

  @override
  String get modeUnitConversion => 'Unit conversion';

  @override
  String get modeTime => 'Time';

  @override
  String get modeCurrency => 'Currency';

  @override
  String get modeSpeechBasic => 'basic mode';

  @override
  String get modeSpeechScientific => 'scientific mode';

  @override
  String get modeSpeechStatistics => 'statistics mode';

  @override
  String get modeSpeechElectrician => 'electrical mode';

  @override
  String get modeSpeechUnitConversion => 'unit conversion mode';

  @override
  String get modeSpeechTime => 'time mode';

  @override
  String get modeSpeechCurrency => 'currency mode';

  @override
  String switchedToMode(Object mode) {
    return 'Switched to $mode';
  }

  @override
  String welcomeMessage(Object mode) {
    return 'Welcome to the talking calculator, active mode is $mode';
  }

  @override
  String get displayEmpty => 'Empty';

  @override
  String get displayLabel => 'Display';

  @override
  String get displayHint => 'Pinch to zoom, drag to scroll';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get statsMemoryTitle => 'Statistics memory';

  @override
  String get statsSummaryTitle => 'Statistics summary';

  @override
  String get statsValue => 'Value';

  @override
  String get statsOccurrenceCount => 'Occurrences';

  @override
  String statsTotalValues(Object count) {
    return 'Total values: $count';
  }

  @override
  String statsDistinctValues(Object count) {
    return 'Distinct values: $count';
  }

  @override
  String get statsColumnsLabel => 'Columns: value and occurrence count';

  @override
  String get statsRepeatTitle => 'Repeat count';

  @override
  String get statsRepeatHint => 'Enter how many times the values should be added to statistics memory';

  @override
  String get statsRepeatLabel => 'Insert count';

  @override
  String get statsReviewTitle => 'Review data before saving';

  @override
  String statsReviewSummary(Object count, Object name) {
    return 'Ready to save $count records to set $name.';
  }

  @override
  String get statsAllValuesSection => 'All values in memory';

  @override
  String get statsComputedSection => 'Computed statistics';

  @override
  String get statsN => 'N';

  @override
  String get statsMin => 'Minimum';

  @override
  String get statsMax => 'Maximum';

  @override
  String get statsMean => 'Mean';

  @override
  String get statsSum => 'Sum';

  @override
  String get statsVariance => 'Variance';

  @override
  String get statsStdDev => 'Standard deviation';

  @override
  String get statsMedian => 'Median';

  @override
  String get statsMode => 'Mode';

  @override
  String get statsCv => 'Coefficient of variation';

  @override
  String get statsModeNone => 'No mode';

  @override
  String get statsMemoryEmpty => 'Statistics memory is empty.';

  @override
  String get statsMemoryEmptyHint => 'Statistics memory is empty. Add data first using the M+ button.';

  @override
  String get statsMemoryCleared => 'Statistics memory was cleared.';

  @override
  String statsRowSemantics(Object count, Object value) {
    return 'Value $value, occurrences: $count.';
  }

  @override
  String statsTotalSemantics(Object count, Object countLabel, Object distinct) {
    return 'Total $count $countLabel. Distinct values: $distinct.';
  }

  @override
  String get statsSetsTitle => 'Statistics Sets';

  @override
  String get statsSetsManage => 'Manage Sets';

  @override
  String get statsSetsCreate => 'Create new set';

  @override
  String get statsSetsRename => 'Rename set';

  @override
  String get statsSetsDelete => 'Delete set';

  @override
  String get statsSetNameLabel => 'Set name';

  @override
  String statsSetCreatedAnnouncement(String name) {
    return 'Created and selected new empty set $name';
  }

  @override
  String statsSetRenamedAnnouncement(String name) {
    return 'Set renamed to $name';
  }

  @override
  String statsSetDeletedAnnouncement(String name, String activeName) {
    return 'Set $name deleted. Active set is now $activeName';
  }

  @override
  String statsSetSelectedAnnouncement(String name, int count, String countForm) {
    return 'Selected set $name, contains $count $countForm';
  }

  @override
  String statsSetDefaultName(int index) {
    return 'Set $index';
  }

  @override
  String statsCurrentSetLabel(String name) {
    return 'Active set: $name';
  }

  @override
  String get statsHelpTitle => 'Statistics Help';

  @override
  String get statsHelpButton => 'Help with controls';

  @override
  String get statsHelpText => '=== STATISTICS HELP ===\n\nKEYBOARD BUTTONS:\n\nSETS – Manage statistics sets and folders. Create, rename, delete, switch, duplicate, pin, archive and move sets between folders. Includes search, sort (Last used/Name/Count), filter All/No folder/folder and Show archived toggle. More menu: Quick create, Guided wizard, Voice creation. Folders via Folders button (New folder / Manage folders – color and icon; sets remain in No folder after deletion).\n\nM+ (short press) – Add the entered value (or multiple values separated by semicolons) to the active set. With ≥2 records a Review before saving dialog appears.\n\nM+ (long press / Ctrl+M) – Add values and specify a repeat count for bulk insertion.\n\nMC – Clear all data in the active set.\n\nMR – Show all stored data in an editable list (grouped values with occurrence counts, delete records, Manage sets button).\n\nSTATS – Show the statistics summary: header with set name and field switcher, checkbox Read values in memory, section All values in memory (sorted, with unit) and Computed statistics (table N, MIN, MAX, SUM, MEAN, VAR, SD, MED, MODE, CV, WMEAN in custom order). Reading order button opens the reading settings. Field switcher cycles on tap and is announced via voice and screen reader.\n\n; (semicolon) – Separator for multiple values (e.g. 5;10;15 or 80;2 for two fields).\n\nADVANCED FUNCTIONS (available from the list button in the top bar):\n\nMEAN – Arithmetic mean of all values.\nSD – Standard deviation (measure of dispersion around the mean).\nVAR – Variance (average squared deviation from the mean).\nSUM – Sum of all values.\nMED – Median (middle value of sorted data).\nMODE – Mode (most frequent value).\nMIN – Minimum of all values.\nMAX – Maximum of all values.\nCV – Coefficient of variation (SD as percentage of the mean).\nWMEAN – Weighted mean (requires 2 fields: values and weights).\n\nREADING ORDER (Reading order button in STATS dialog):\nTop sets order of Summary header / Values in memory / Computed statistics (read top to bottom, Move up/down, Restore default). Bottom sets order inside Computed statistics (MEAN, SUM, VAR, SD, MED, MIN, MAX, MODE, CV, WMEAN) synced with the table. Changes are announced via voice and screen reader. Previously in Accessibility settings, now directly in the summary.\n\nFIELDS IN A SET:\n\nEach set can have multiple fields (e.g. \"Value\" and \"Weight\") with optional unit (categories Length…Power). When creating a set (SETS → Create new set or More → Quick/Guided/Voice) add fields with \"Add field\" and pick a unit. Units appear in the summary and spoken output. Switch fields in the STATS dialog or Advanced Functions. Each set has color (8) and icon (8), can be pinned (always on top) or archived.\n\nWEIGHTED MEAN (WMEAN):\n\nRequires a set with at least 2 fields. Field 0 = values, field 1 = weights. Steps: 1) Create a set with 2 fields (e.g. \"Value\" and \"Weight\"). 2) Enter values and weights separated by a semicolon, e.g. \"80;2\" (value 80 with weight 2). 3) After entering all data, tap WMEAN in Advanced Functions. 4) The app calculates: (value1 × weight1 + value2 × weight2 + ...) / (weight1 + weight2 + ...).\n\nTIPS:\n- Create multiple sets for different data groups and organize them into folders.\n- Each set can have multiple fields with units (e.g. values, weights).\n- A new set is created automatically on first data entry.\n- Data, reading order and Read values setting are saved automatically.\n- All important announcements go via voice and screen reader according to Screen reader mode.';

  @override
  String get statsHelpKeyboardSection => 'Keyboard buttons';

  @override
  String get statsHelpAdvancedSection => 'Advanced functions';

  @override
  String get statsHelpFieldsSection => 'Fields in a set';

  @override
  String get statsHelpWeightedMeanSection => 'Weighted mean (WMEAN)';

  @override
  String get statsHelpTipsSection => 'Tips';

  @override
  String get statsHelpKeyboardSets => 'SETS – Manage statistics sets and folders. Search, sort, filter, color/icon, pin/archive, move/copy/duplicate, folders and 3 creation methods (Quick, Guided, Voice).';

  @override
  String get statsHelpKeyboardMPlus => 'M+ (short) – Add values to active set. With ≥2 records shows Review before saving. Long press / Ctrl+M – enter repeat count for bulk insertion.';

  @override
  String get statsHelpKeyboardMc => 'MC – Clear all data in the active set.';

  @override
  String get statsHelpKeyboardMr => 'MR – Show all stored data in editable list (grouped values with occurrence counts, delete records, Manage sets).';

  @override
  String get statsHelpKeyboardStats => 'STATS – Summary: header with field switcher, checkbox Read values in memory, All values and Computed statistics sections (N, MIN, MAX, SUM, MEAN, VAR, SD, MED, MODE, CV, WMEAN) and Reading order button.';

  @override
  String get statsHelpKeyboardSemicolon => '; (semicolon) – Separator for multiple values (e.g. 5;10;15).';

  @override
  String get statsHelpAdvancedMean => 'MEAN – Arithmetic mean of all values.';

  @override
  String get statsHelpAdvancedSd => 'SD – Standard deviation (measure of dispersion around the mean).';

  @override
  String get statsHelpAdvancedVar => 'VAR – Variance (average squared deviation from the mean).';

  @override
  String get statsHelpAdvancedSum => 'SUM – Sum of all values.';

  @override
  String get statsHelpAdvancedMed => 'MED – Median (middle value of sorted data).';

  @override
  String get statsHelpAdvancedMode => 'MODE – Mode (most frequent value).';

  @override
  String get statsHelpAdvancedMin => 'MIN – Minimum of all values.';

  @override
  String get statsHelpAdvancedMax => 'MAX – Maximum of all values.';

  @override
  String get statsHelpAdvancedCv => 'CV – Coefficient of variation (SD as percentage of the mean).';

  @override
  String get statsHelpAdvancedWmean => 'WMEAN – Weighted mean (requires 2 fields: values and weights).';

  @override
  String get statsHelpFieldsDesc => 'Each set can have multiple fields (e.g. \"Value\" and \"Weight\") with optional unit (categories Length…Power). Color (8) and icon (8), pin (always on top) / archive. Add fields when creating a set with \"Add field\" and pick a unit. Switch fields in STATS or Advanced Functions.';

  @override
  String get statsHelpWeightedMeanDesc => 'Requires a set with at least 2 fields. Field 0 = values, field 1 = weights.\\n\\nSteps:\\n1) Create a set with 2 fields (e.g. \"Value\" and \"Weight\").\\n2) Enter values and weights separated by a semicolon, e.g. \"80;2\" (value 80 with weight 2).\\n3) After entering all data, tap WMEAN in Advanced Functions.\\n4) The app calculates: (value1 × weight1 + value2 × weight2 + ...) / (weight1 + weight2 + ...).';

  @override
  String get statsHelpTip1 => 'Create multiple sets and organize them into folders (color, icon, pin, archive).';

  @override
  String get statsHelpTip2 => 'Each set can have multiple fields with units (e.g. values, weights).';

  @override
  String get statsHelpTip3 => 'A new set is created automatically on first data entry.';

  @override
  String get statsHelpTip4 => 'Data, reading order and Read values setting are saved automatically. Announcements go via voice and screen reader.';

  @override
  String get statsWeightedMean => 'Weighted mean';

  @override
  String get backupData => 'Backup data';

  @override
  String get restoreData => 'Restore data';

  @override
  String get backupSuccess => 'Backup created';

  @override
  String get restoreSuccess => 'Data restored';

  @override
  String get restoreConfirm => 'Are you sure you want to restore all data from backup?';

  @override
  String get numberInfo => 'Number Info';

  @override
  String get infoValue => 'Value';

  @override
  String get infoFraction => 'Fraction';

  @override
  String get infoDms => 'DMS (degrees/minutes/seconds)';

  @override
  String get infoPercentage => 'Percentage';

  @override
  String get infoPrimeFactors => 'Prime factors';

  @override
  String get infoDivisors => 'Divisors';

  @override
  String get infoRead => 'READ ALOUD';

  @override
  String get infoNoResult => 'Calculate a result first.';

  @override
  String get infoNotInteger => 'Positive integers only';

  @override
  String get infoNotApplicable => 'N/A';

  @override
  String get dialogSizeSetting => 'Dialog size';

  @override
  String get dialogSizeCompact => 'Compact';

  @override
  String get dialogSizeWide => 'Wide';

  @override
  String get dialogSizeFullscreen => 'Full screen';

  @override
  String get voiceOn => 'Voice on';

  @override
  String get voiceOff => 'Voice off';

  @override
  String get cleared => 'Clear';

  @override
  String get deleted => 'Deleted';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get appIsCurrent => 'The app is up to date.';

  @override
  String get degreesUnit => 'degrees';

  @override
  String get minutesUnit => 'minutes';

  @override
  String get secondsUnit => 'seconds';

  @override
  String get piSpoken => 'pi';

  @override
  String get minusWord => 'minus';

  @override
  String get timesTenTo => 'times ten to the';

  @override
  String get expressionNotUnderstood => 'I don\'t understand the expression, please check the parentheses or signs';

  @override
  String get cannotDivideByZero => 'Cannot divide by zero';

  @override
  String get valueOutOfRange => 'Value is outside the valid range of the function';

  @override
  String resultIs(String value) {
    return 'The result is $value';
  }

  @override
  String get conversionError => 'Conversion error';

  @override
  String unitConverted(String from, String to, String value, String toUnit) {
    return 'Converted from $from to $to. The result is $value $toUnit';
  }

  @override
  String get backupError => 'Error creating the backup';

  @override
  String get restoreError => 'Error restoring the data';

  @override
  String decimalPlacesSet(int count) {
    return 'Set to $count decimal places';
  }

  @override
  String savedToVariable(String name, String value) {
    return 'Saved to variable $name: $value';
  }

  @override
  String get cannotStoreExpression => 'The expression cannot be calculated, nothing was saved to memory.';

  @override
  String recalledFromVariable(String name, String value) {
    return 'Recalled from variable $name: $value';
  }

  @override
  String variableName(String name) {
    return 'Variable $name';
  }

  @override
  String get selectMemory => 'Select memory';

  @override
  String get selectMemoryRecall => 'Select a memory to recall';

  @override
  String get memoryCleared => 'Memory cleared';

  @override
  String insertedValue(String value) {
    return 'Inserted $value';
  }

  @override
  String inverseResult(String name) {
    return 'Inverse $name of the result';
  }

  @override
  String resultOf(String name) {
    return '$name of the result';
  }

  @override
  String get standardDisplaySet => 'Standard display set';

  @override
  String get segment16On => '16-segment display on';

  @override
  String get segment7On => '7-segment display on';

  @override
  String get screenReaderAuto => 'Screen reader mode: automatic';

  @override
  String get screenReaderOn => 'Screen reader mode on';

  @override
  String get screenReaderOff => 'Screen reader mode off';

  @override
  String get angleFormatDms => 'Angle format set to degrees, minutes and seconds';

  @override
  String get angleFormatDecimal => 'Angle format set to decimal degrees';

  @override
  String themeSet(String mode) {
    return 'Theme set to $mode';
  }

  @override
  String get themeSystem => 'system';

  @override
  String get themeLight => 'light';

  @override
  String get themeDark => 'dark';

  @override
  String zoomUpperPct(int percent) {
    return 'Upper line zoom $percent percent';
  }

  @override
  String zoomLowerPct(int percent) {
    return 'Lower line zoom $percent percent';
  }

  @override
  String speechRatePct(int percent) {
    return 'Speech rate $percent percent';
  }

  @override
  String volumePct(int percent) {
    return 'Volume $percent percent';
  }

  @override
  String categorySelected(String category) {
    return 'Category $category';
  }

  @override
  String fromUnitSelected(String unit) {
    return 'From unit $unit';
  }

  @override
  String toUnitSelected(String unit) {
    return 'To unit $unit';
  }

  @override
  String get calcNameVoltage => 'voltage';

  @override
  String get calcNameCurrent => 'current';

  @override
  String get calcNameResistance => 'resistance';

  @override
  String get calcInputVoltage => 'current and resistance';

  @override
  String get calcInputCurrent => 'voltage and resistance';

  @override
  String get calcInputResistance => 'voltage and current';

  @override
  String calcIntro(String name, String input) {
    return 'Calculate $name. Enter $input separated by semicolons.';
  }

  @override
  String elecResult(String name, String value, String unit) {
    return '$name is $value $unit';
  }

  @override
  String get elecTwoValuesError => 'Enter two values separated by semicolons.';

  @override
  String get elecFormatError => 'The values entered in electrical mode are not in a valid numeric format.';

  @override
  String get elecInvalidResult => 'The electrical calculation result is not a valid number.';

  @override
  String get formatDms => 'Format set to degrees, minutes and seconds.';

  @override
  String get formatDecimalDegrees => 'Format set to decimal degrees.';

  @override
  String get errorSegment => 'ERROR';

  @override
  String get confirmationTitle => 'Confirmation';

  @override
  String get yesConfirmHistory => 'Yes, confirm clearing the entire calculation history';

  @override
  String get noCancelHistory => 'No, cancel and keep the history';

  @override
  String get precisionTitle => 'Precision settings';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String newVersionSemantics(String version, String current) {
    return 'A new version $version is available. Your version is $current.';
  }

  @override
  String newVersionText(String version, String current) {
    return 'A new version $version is available.\n\nYour version: $current';
  }

  @override
  String get whatIsNew => 'What is new:';

  @override
  String get later => 'Later';

  @override
  String get showRelease => 'Show release';

  @override
  String cannotOpenBrowser(String error) {
    return 'Cannot open browser: $error';
  }

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get sectionTrigonometry => 'Trigonometry';

  @override
  String get sectionFunctions => 'Functions';

  @override
  String get sectionMemory => 'Memory';

  @override
  String get sectionDisplay => 'Display';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get convertButton => 'CONVERT';

  @override
  String get standardDisplayLabel => 'Standard display';

  @override
  String get fixedDecimalLabel => 'Display with a fixed number of decimal places';

  @override
  String get scientificNotationLabel => 'Scientific notation';

  @override
  String get engineeringNotationLabel => 'Engineering notation';

  @override
  String get categoryLabel => 'Category';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get segment16Name => '16-segment';

  @override
  String get segment7Name => '7-segment';

  @override
  String get switchDisplayType => 'Switch display type';

  @override
  String get toggleVoiceOutput => 'Toggle voice output';

  @override
  String get enabledState => 'On';

  @override
  String get disabledState => 'Off';

  @override
  String get screenReaderSection => 'Screen reader mode';

  @override
  String get screenReaderAutoLabel => 'Automatic based on screen reader';

  @override
  String get ttsEngineSettings => 'Text-to-speech engine settings';

  @override
  String engineLabel(String engine) {
    return 'Engine: $engine';
  }

  @override
  String get defaultEngine => 'Default';

  @override
  String get openTtsSystemSettings => 'Open system TTS settings';

  @override
  String get ttsSettingsButton => 'TTS settings';

  @override
  String get voiceSettings => 'Voice settings';

  @override
  String voiceLabel(String voice) {
    return 'Voice: $voice';
  }

  @override
  String get toggleAngleFormat => 'Toggle angle format';

  @override
  String get themeSectionLabel => 'Choose app theme';

  @override
  String get themeTitle => 'App theme';

  @override
  String get themeSystemLabel => 'System theme';

  @override
  String get themeLightLabel => 'Light theme';

  @override
  String get themeDarkLabel => 'Dark theme';

  @override
  String get defaultStartupMode => 'Default mode on startup';

  @override
  String get zoomUpperControls => 'Upper line zoom controls';

  @override
  String get zoomLowerControls => 'Lower line zoom controls';

  @override
  String get decreaseUpperZoom => 'Decrease upper line zoom';

  @override
  String get increaseUpperZoom => 'Increase upper line zoom';

  @override
  String get decreaseLowerZoom => 'Decrease lower line zoom';

  @override
  String get increaseLowerZoom => 'Increase lower line zoom';

  @override
  String zoomValuePct(int value) {
    return 'Zoom value: $value %';
  }

  @override
  String get speechRateControls => 'Speech rate controls';

  @override
  String get decreaseSpeechRate => 'Decrease speech rate';

  @override
  String get increaseSpeechRate => 'Increase speech rate';

  @override
  String speechRateValue(int value) {
    return 'Current speech rate: $value %';
  }

  @override
  String get volumeControls => 'Volume controls';

  @override
  String get decreaseVolume => 'Decrease volume';

  @override
  String get increaseVolume => 'Increase volume';

  @override
  String volumeValue(int value) {
    return 'Current volume: $value %';
  }

  @override
  String get dataManagementSection => 'Data backup and restore';

  @override
  String get dataManagementTitle => 'Data management';

  @override
  String get yesShort => 'YES';

  @override
  String get noShort => 'NO';

  @override
  String get moreOptions => 'More options';

  @override
  String get news => 'What is new';

  @override
  String get currencyFromLabel => 'From currency';

  @override
  String get currencyToLabel => 'To currency';

  @override
  String currencyRateLabel(String code) {
    return 'Rate (CZK per 1 $code)';
  }

  @override
  String get currencyManageTitle => 'Manage rates';

  @override
  String get currencyManageButton => 'MANAGE RATES';

  @override
  String get currencyUpdateButton => 'UPDATE RATES';

  @override
  String get currencyUpdating => 'Updating rates…';

  @override
  String get currencyUpdated => 'Rates updated';

  @override
  String currencyLastUpdate(String date) {
    return 'Last update: $date';
  }

  @override
  String get currencyNoRates => 'No rates to display.';

  @override
  String get currencyOfflineError => 'Failed to update rates. Check connection. Keeping last rates.';

  @override
  String get currencyParseError => 'Failed to parse CNB rates.';

  @override
  String currencyConverted(String value, String from, String to, String result, String toUnit, String rate) {
    return 'Converted $value $from to $to. Result is $result $toUnit. Rate $rate';
  }

  @override
  String get currencyInvalidRate => 'Invalid rate';

  @override
  String get currencyCzkLocked => 'Koruna rate is fixed at 1.00';

  @override
  String get currencyAddTitle => 'Add currency';

  @override
  String get currencyCodeLabel => 'Currency code (e.g. EUR)';

  @override
  String get currencyAddButton => 'ADD';

  @override
  String get timeNow => 'NOW';

  @override
  String get timeNowHint => 'Insert current time';

  @override
  String get timeDiff => 'DIFF';

  @override
  String get timeDiffHint => 'Difference of two times';

  @override
  String get timeToSec => 'TO SEC';

  @override
  String get timeToHms => 'TO HMS';

  @override
  String timeCurrentIs(String time) {
    return 'Current time is $time';
  }

  @override
  String get timeInvalidFormat => 'Invalid time format. Use HH:MM or HH:MM:SS.';

  @override
  String timeResult(String time) {
    return 'Result is $time';
  }

  @override
  String timeDiffResult(String time) {
    return 'Difference is $time';
  }

  @override
  String timeToSecResult(String hms, String sec) {
    return '$hms is $sec seconds';
  }

  @override
  String timeToHmsResult(String sec, String hms) {
    return '$sec seconds is $hms';
  }

  @override
  String get timeHelp => 'Enter time as HH:MM or HH:MM:SS. Use + or - between times. DIFF gives absolute difference. NOW inserts current time.';

  @override
  String expressionResultIs(String expression, String result) {
    return 'Expression $expression, $result';
  }

  @override
  String announceExpressionState(String state) {
    return 'Announce expression: $state';
  }
}
