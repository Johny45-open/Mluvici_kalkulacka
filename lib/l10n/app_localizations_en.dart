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
  String get statsHelpText => '=== STATISTICS HELP ===\n\nKEYBOARD BUTTONS:\n\nSETS – Manage statistics sets. Create, rename, delete or switch between sets.\n\nM+ (short press) – Add the entered value (or multiple values separated by semicolons) to the active set.\n\nM+ (long press) – Add values and specify a repeat count for bulk insertion.\n\nMC – Clear all data in the active set.\n\nMR – Show all stored data in an editable list.\n\nSTATS – Show the statistics summary for the selected field: mean, sum, variance, standard deviation, median, mode and coefficient of variation.\n\n; (semicolon) – Separator for multiple values (e.g. 5;10;15).\n\nADVANCED FUNCTIONS (available from the list button in the top bar):\n\nMEAN – Arithmetic mean of all values.\nSD – Standard deviation (measure of dispersion around the mean).\nVAR – Variance (average squared deviation from the mean).\nSUM – Sum of all values.\nMED – Median (middle value of sorted data).\nMODE – Mode (most frequent value).\nMIN – Minimum of all values.\nMAX – Maximum of all values.\nCV – Coefficient of variation (SD as percentage of the mean).\nWMEAN – Weighted mean (requires 2 fields: values and weights).\n\nFIELDS IN A SET:\n\nEach set can have multiple fields (e.g. \"Value\" and \"Weight\"). When creating a set (SETS → Create new set) you can add fields using the \"Add field\" button. You can then switch which field statistics are calculated for – either in the STATS dialog or in Advanced Functions.\n\nWEIGHTED MEAN (WMEAN):\n\nRequires a set with at least 2 fields. Field 0 = values, field 1 = weights. Steps: 1) Create a set with 2 fields (e.g. \"Value\" and \"Weight\"). 2) Enter values and weights separated by a semicolon, e.g. \"80;2\" (value 80 with weight 2). 3) After entering all data, tap WMEAN in Advanced Functions. 4) The app calculates: (value1 × weight1 + value2 × weight2 + ...) / (weight1 + weight2 + ...).\n\nTIPS:\n- Create multiple sets for different data groups.\n- Each set can have multiple fields (e.g. values, weights).\n- A new set is created automatically on first data entry.\n- Data is saved automatically to the device memory.';

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
  String get statsHelpKeyboardSets => 'SETS – Manage statistics sets. Create, rename, delete or switch between sets.';

  @override
  String get statsHelpKeyboardMPlus => 'M+ (short press) – Add the entered value (or multiple values separated by semicolons) to the active set. Long press – Add values and specify a repeat count for bulk insertion.';

  @override
  String get statsHelpKeyboardMc => 'MC – Clear all data in the active set.';

  @override
  String get statsHelpKeyboardMr => 'MR – Show all stored data in an editable list.';

  @override
  String get statsHelpKeyboardStats => 'STATS – Show the statistics summary for the selected field: mean, sum, variance, standard deviation, median, mode and coefficient of variation.';

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
  String get statsHelpFieldsDesc => 'Each set can have multiple fields (e.g. \"Value\" and \"Weight\"). When creating a set (SETS → Create new set) you can add fields using the \"Add field\" button. You can then switch which field statistics are calculated for – either in the STATS dialog or in Advanced Functions.';

  @override
  String get statsHelpWeightedMeanDesc => 'Requires a set with at least 2 fields. Field 0 = values, field 1 = weights.\\n\\nSteps:\\n1) Create a set with 2 fields (e.g. \"Value\" and \"Weight\").\\n2) Enter values and weights separated by a semicolon, e.g. \"80;2\" (value 80 with weight 2).\\n3) After entering all data, tap WMEAN in Advanced Functions.\\n4) The app calculates: (value1 × weight1 + value2 × weight2 + ...) / (weight1 + weight2 + ...).';

  @override
  String get statsHelpTip1 => 'Create multiple sets for different data groups.';

  @override
  String get statsHelpTip2 => 'Each set can have multiple fields (e.g. values, weights).';

  @override
  String get statsHelpTip3 => 'A new set is created automatically on first data entry.';

  @override
  String get statsHelpTip4 => 'Data is saved automatically to the device memory.';

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
}
