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
  String get statsAllValuesSection => 'All values in memory';

  @override
  String get statsComputedSection => 'Computed statistics';

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
  String get backupData => 'Backup data';

  @override
  String get restoreData => 'Restore data';

  @override
  String get backupSuccess => 'Backup created';

  @override
  String get restoreSuccess => 'Data restored';

  @override
  String get restoreConfirm =>
      'Are you sure you want to restore all data from backup?';

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
}
