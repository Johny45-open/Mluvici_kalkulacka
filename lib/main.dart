import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:math_expressions/math_expressions.dart' as math_expr;
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'update_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScientificCalculatorApp());
}

class ScientificCalculatorApp extends StatefulWidget {
  final Locale? locale;

  const ScientificCalculatorApp({super.key, this.locale});

  @override
  State<ScientificCalculatorApp> createState() =>
      _ScientificCalculatorAppState();
}

class _ScientificCalculatorAppState extends State<ScientificCalculatorApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
    });
  }

  void _updateThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: widget.locale,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: CalculatorScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _updateThemeMode,
      ),
    );
  }
}

enum CalculatorMode {
  basic,
  scientific,
  statistics,
  electrician,
  unitConversion,
}

enum AccessibilityType { none, blind, visuallyImpaired }

enum DisplayFormat { standard, fix, sci, eng }

enum ElectricianCalculation { voltage, current, resistance }

enum ScreenReaderMode { auto, on, off }

enum DialogSize { compact, wide, fullscreen }

class _ElectricianInputException implements Exception {
  final String message;

  const _ElectricianInputException(this.message);

  @override
  String toString() => message;
}

class _StatisticsSnapshot {
  final double sum;
  final double mean;
  final double variance;
  final double sd;
  final double median;
  final List<double> modes;
  final int modeOccurrenceCount;
  final bool modeExists;
  final double? cv;

  const _StatisticsSnapshot({
    required this.sum,
    required this.mean,
    required this.variance,
    required this.sd,
    required this.median,
    required this.modes,
    required this.modeOccurrenceCount,
    required this.modeExists,
    required this.cv,
  });
}

class StatisticsRecord {
  final List<double> values;

  StatisticsRecord({required this.values});

  Map<String, dynamic> toJson() => {
        'values': values,
      };

  factory StatisticsRecord.fromJson(Map<String, dynamic> json) {
    return StatisticsRecord(
      values: (json['values'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  StatisticsRecord copyWith({List<double>? values}) {
    return StatisticsRecord(values: values ?? this.values);
  }
}

class StatisticsSet {
  String name;
  final List<String> fieldNames;
  final List<StatisticsRecord> records;

  StatisticsSet({
    required this.name,
    required this.fieldNames,
    required this.records,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'fieldNames': fieldNames,
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory StatisticsSet.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) {
      final data = (json['data'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      return StatisticsSet(
        name: json['name'] as String,
        fieldNames: ['Hodnota'],
        records:
            data.map((v) => StatisticsRecord(values: [v])).toList(),
      );
    }
    return StatisticsSet(
      name: json['name'] as String,
      fieldNames: (json['fieldNames'] as List).cast<String>(),
      records: (json['records'] as List)
          .map((e) => StatisticsRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const CalculatorScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with WidgetsBindingObserver {
  late final String _currentAppVersion;
  static const MethodChannel _accessibilityChannel =
      MethodChannel('com.example.mluvici_kalkulacka/accessibility');

  final FlutterTts tts = FlutterTts();
  final FocusNode _mainFocusNode = FocusNode();
  String display = '';
  int _cursorPosition = 0;
  String _lastResult = '0.';
  CalculatorMode _currentMode = CalculatorMode.scientific;

  bool ttsEnabled = true;
  bool _updateDialogShown = false;
  bool _isDegreeMode = true;
  bool _useSixteenSegment = false;
  final bool _sayWelcome = true;
  AccessibilityType _accessibilityType = AccessibilityType.none;
  double _fontSizeMultiplier = 1.0;
  double _dotMatrixZoom = 1.0;
  double _resultZoom = 1.0;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  ScreenReaderMode _screenReaderMode = ScreenReaderMode.auto;
  bool _accessibleNavigation = false;
  String? _ttsEngine;
  int? _inverseFormatPreference; // 0: DMS, 1: Desetinné

  DialogSize _dialogSize = DialogSize.compact;
  DisplayFormat _displayFormat = DisplayFormat.standard;
  int _precision = 2;
  double? _lastNumericValue;
  ElectricianCalculation _selectedElectricianCalculation =
      ElectricianCalculation.resistance;

  DateTime? _lastSpeakTime;
  final Duration _speakThrottle = const Duration(milliseconds: 300);
  String? _lastTtsLocale;

  final Map<String, double> _memory = {
    'A': 0,
    'B': 0,
    'C': 0,
    'D': 0,
    'E': 0,
    'F': 0,
    'X': 0,
    'Y': 0,
    'M': 0,
  };

  final List<StatisticsSet> _statsSets = [];
  int _currentStatsSetIndex = 0;
  int _selectedFieldIndex = 0;
  List<StatisticsRecord> _lastAddedBatch = [];

  bool get _hasStatsSet => _statsSets.isNotEmpty;

  List<StatisticsRecord> get _statsMemory {
    if (_statsSets.isEmpty) return const [];
    return _statsSets[_currentStatsSetIndex].records;
  }

  int get _currentFieldCount {
    if (_statsSets.isEmpty) return 1;
    return _statsSets[_currentStatsSetIndex].fieldNames.length;
  }

  List<double> _getFieldValues(int fieldIndex) {
    return _statsMemory.map((r) => r.values[fieldIndex]).toList();
  }

  final Map<String, Map<String, double>> _unitCategories = {
    'Délka': {
      'm': 1.0,
      'km': 1000.0,
      'cm': 0.01,
      'mm': 0.001,
      'mi': 1609.344,
      'yd': 0.9144,
      'ft': 0.3048,
      'in': 0.0254,
    },
    'Hmotnost': {
      'kg': 1.0,
      'g': 0.001,
      'mg': 0.000001,
      't': 1000.0,
      'lb': 0.45359237,
      'oz': 0.028349523125,
    },
    'Plocha': {
      'm²': 1.0,
      'km²': 1000000.0,
      'ha': 10000.0,
      'cm²': 0.0001,
      'akr': 4046.856,
    },
    'Objem': {
      'l': 1.0,
      'ml': 0.001,
      'm³': 1000.0,
      'gal': 3.78541,
      'pt': 0.473176,
    },
    'Tlak': {
      'Pa': 1.0,
      'hPa': 100.0,
      'kPa': 1000.0,
      'bar': 100000.0,
      'atm': 101325.0,
      'psi': 6894.76,
    },
  };

  final ScrollController _scrollControllerH = ScrollController();
  final ScrollController _scrollControllerV = ScrollController();

  final Map<String, Map<String, dynamic>> _unitSpeechData = {
    'm': {
      'base': 'metr',
      'z': 'metrů',
      'na': 'metry',
      'forms': ['metr', 'metry', 'metrů', 'metru'],
    },
    'km': {
      'base': 'kilometr',
      'z': 'kilometrů',
      'na': 'kilometry',
      'forms': ['kilometr', 'kilometry', 'kilometrů', 'kilometru'],
    },
    'cm': {
      'base': 'centimetr',
      'z': 'centimetrů',
      'na': 'centimetry',
      'forms': ['centimetr', 'centimetry', 'centimetrů', 'centimetru'],
    },
    'mm': {
      'base': 'milimetr',
      'z': 'milimetrů',
      'na': 'milimetry',
      'forms': ['milimetr', 'milimetry', 'milimetrů', 'milimetru'],
    },
    'mi': {
      'base': 'míle',
      'z': 'mil',
      'na': 'míle',
      'forms': ['míle', 'míle', 'mil', 'míle'],
    },
    'yd': {
      'base': 'yard',
      'z': 'yardů',
      'na': 'yardy',
      'forms': ['yard', 'yardy', 'yardů', 'yardu'],
    },
    'ft': {
      'base': 'stopa',
      'z': 'stop',
      'na': 'stopy',
      'forms': ['stopa', 'stopy', 'stop', 'stopy'],
    },
    'in': {
      'base': 'palec',
      'z': 'palců',
      'na': 'palce',
      'forms': ['palec', 'palce', 'palců', 'palce'],
    },
    'kg': {
      'base': 'kilogram',
      'z': 'kilogramů',
      'na': 'kilogramy',
      'forms': ['kilogram', 'kilogramy', 'kilogramů', 'kilogramu'],
    },
    'g': {
      'base': 'gram',
      'z': 'gramů',
      'na': 'gramy',
      'forms': ['gram', 'gramy', 'gramů', 'gramu'],
    },
    'mg': {
      'base': 'miligram',
      'z': 'miligramů',
      'na': 'miligramy',
      'forms': ['miligram', 'miligramy', 'miligramů', 'miligramu'],
    },
    't': {
      'base': 'tuna',
      'z': 'tun',
      'na': 'tuny',
      'forms': ['tuna', 'tuny', 'tun', 'tuny'],
    },
    'lb': {
      'base': 'libra',
      'z': 'liber',
      'na': 'libry',
      'forms': ['libra', 'libry', 'liber', 'libry'],
    },
    'oz': {
      'base': 'unce',
      'z': 'uncí',
      'na': 'unce',
      'forms': ['unce', 'unce', 'uncí', 'unce'],
    },
    'm²': {
      'base': 'metr čtvereční',
      'z': 'metrů čtverečních',
      'na': 'metry čtvereční',
      'forms': [
        'metr čtvereční',
        'metry čtvereční',
        'metrů čtverečních',
        'metru čtverečního',
      ],
    },
    'km²': {
      'base': 'kilometr čtvereční',
      'z': 'kilometrů čtverečních',
      'na': 'kilometry čtvereční',
      'forms': [
        'kilometr čtvereční',
        'kilometry čtvereční',
        'kilometrů čtverečních',
        'kilometru čtverečního',
      ],
    },
    'ha': {
      'base': 'hektar',
      'z': 'hektarů',
      'na': 'hektary',
      'forms': ['hektar', 'hektary', 'hektarů', 'hektaru'],
    },
    'cm²': {
      'base': 'centimetr čtvereční',
      'z': 'centimetrů čtverečních',
      'na': 'centimetry čtvereční',
      'forms': [
        'centimetr čtvereční',
        'centimetry čtvereční',
        'centimetrů čtverečních',
        'centimetru čtverečního',
      ],
    },
    'akr': {
      'base': 'akr',
      'z': 'akrů',
      'na': 'akry',
      'forms': ['akr', 'akry', 'akrů', 'akru'],
    },
    'l': {
      'base': 'litr',
      'z': 'litrů',
      'na': 'litry',
      'forms': ['litr', 'litry', 'litrů', 'litru'],
    },
    'ml': {
      'base': 'mililitr',
      'z': 'mililitrů',
      'na': 'mililitry',
      'forms': ['mililitr', 'mililitry', 'mililitrů', 'mililitru'],
    },
    'm³': {
      'base': 'metr krychlový',
      'z': 'metrů krychlových',
      'na': 'metry krychlové',
      'forms': [
        'metr krychlový',
        'metry krychlové',
        'metrů krychlových',
        'metru krychlového',
      ],
    },
    'gal': {
      'base': 'galon',
      'z': 'galonů',
      'na': 'galony',
      'forms': ['galon', 'galony', 'galonů', 'galonu'],
    },
    'pt': {
      'base': 'pinta',
      'z': 'pint',
      'na': 'pinty',
      'forms': ['pinta', 'pinty', 'pint', 'pinty'],
    },
    'Pa': {
      'base': 'pascal',
      'z': 'pascalů',
      'na': 'pascaly',
      'forms': ['pascal', 'pascaly', 'pascalů', 'pascalu'],
    },
    'hPa': {
      'base': 'hektopascal',
      'z': 'hektopascalů',
      'na': 'hektopascaly',
      'forms': ['hektopascal', 'hektopascaly', 'hektopascalů', 'hektopascalu'],
    },
    'kPa': {
      'base': 'kilopascal',
      'z': 'kilopascalů',
      'na': 'kilopascaly',
      'forms': ['kilopascal', 'kilopascaly', 'kilopascalů', 'kilopascalu'],
    },
    'bar': {
      'base': 'bar',
      'z': 'barů',
      'na': 'bary',
      'forms': ['bar', 'bary', 'barů', 'baru'],
    },
    'atm': {
      'base': 'atmosféra',
      'z': 'atmosfér',
      'na': 'atmosféry',
      'forms': ['atmosféra', 'atmosféry', 'atmosfér', 'atmosféry'],
    },
    'psi': {
      'base': 'libra na čtvereční palec',
      'z': 'liber na čtvereční palec',
      'na': 'libry na čtvereční palec',
      'forms': [
        'libra na čtvereční palec',
        'libry na čtvereční palec',
        'liber na čtvereční palec',
        'libry na čtvereční palec',
      ],
    },
  };

  String _selectedUnitCategory = 'Délka';
  String _unitFrom = 'm';
  String _unitTo = 'km';
  List<String> _history = [];
  bool _isStoreMode = false;
  bool _isRecallMode = false;
  bool _hasResult = false;

  final Map<String, String> _buttonNames = {
    'SIN': 'Sinus',
    'COS': 'Kosinus',
    'TAN': 'Tangens',
    'ASIN': 'Arkus sinus',
    'ACOS': 'Arkus kosinus',
    'ATAN': 'Arkus tangens',
    'ABS': 'Absolutní hodnota',
    '°→\'': 'Převod na DMS',
    '\'→°': 'Převod na stupně',
    'DMS': 'Vložit DMS',
    '=': 'Rovná se',
    '/': 'Lomeno',
    '*': 'Krát',
    '-': 'Mínus',
    '+': 'Plus',
    '(': 'Závorka otevřená',
    ')': 'Závorka zavřená',
    '.': 'Tečka',
    '^': 'Mocnina',
    '√': 'Odmocnina',
    'ⁿ√': 'En-tá odmocnina',
    'x²': 'Na druhou',
    'x³': 'Na třetí',
    '∛': 'Třetí odmocnina',
    '1/x': 'Převrácená hodnota',
    'LOG': 'Logaritmus',
    'LN': 'Přirozený logaritmus',
    'X': 'Proměnná X',
    'Y': 'Proměnná Y',
    'A': 'Proměnná A',
    'B': 'Proměnná B',
    'D': 'Proměnná D',
    'E': 'Proměnná E',
    'F': 'Proměnná F',
    'M': 'Proměnná M',
    'ANS': 'Poslední výsledek',
    'STO': 'Uložit do paměti',
    'DEL': 'Smazat poslední',
    'RCL': 'Vyvolat z paměti',
    'CLR': 'Smazat celou paměť',
    'C': 'Smazat displej',
    'DEG': 'Stupně',
    'RAD': 'Radiány',
    '%': 'Procenta',
    'SD': 'Směrodatná odchylka',
    'VAR': 'Rozptyl',
    'MEAN': 'Průměr',
    'STATS': 'Statistický souhrn',
    'M+': 'Přidat do statistické paměti',
    'MC': 'Smazat statistickou paměť',
    'MR': 'Vyvolat ze statistické paměti',
    'MED': 'Medián',
    'MODE': 'Modus',
    'CV': 'Variační koeficient',
    'SUM': 'Součet hodnot',
    ';': 'Oddělovač dat',
    '!': 'Faktoriál',
    '(-)': 'Záporné číslo se závorkou',
    'EXP': 'krát deset na',
    'OHM_V': 'Napětí',
    'OHM_I': 'Proud',
    'OHM_R': 'Odpor',
    'PWR_P': 'Výkon',
    'PAR': 'Paralelně',
    'SER': 'Sériově',
    'Hz': 'Hertz',
    'μ': 'Mikro',
    'n': 'Nano',
    'p': 'Piko',
  };

  double _factorial(int n) {
    if (n < 0) return double.nan;
    if (n == 0) return 1;
    if (n > 20)
      return double.infinity; // Omezení pro double přesnost a prevenci záseku
    double res = 1;
    for (int i = 1; i <= n; i++) {
      res *= i;
    }
    return res;
  }

  Map<String, dynamic> _getScaledValueAndPrefix(double value) {
    double absValue = value.abs();
    if (absValue == 0) return {'value': value, 'prefix': ''};
    if (absValue >= 1e9) return {'value': value / 1e9, 'prefix': 'giga'};
    if (absValue >= 1e6) return {'value': value / 1e6, 'prefix': 'mega'};
    if (absValue >= 1e3) return {'value': value / 1e3, 'prefix': 'kilo'};
    if (absValue >= 1) return {'value': value, 'prefix': ''};
    if (absValue >= 1e-3) return {'value': value * 1e3, 'prefix': 'mili'};
    if (absValue >= 1e-6) return {'value': value * 1e6, 'prefix': 'mikro'};
    if (absValue >= 1e-9) return {'value': value * 1e9, 'prefix': 'nano'};
    return {'value': value * 1e12, 'prefix': 'piko'};
  }

  String _getStatsCountForm(int count) {
    if (_isEnglish()) {
      return count == 1 ? 'value' : 'values';
    }
    if (count == 1) {
      return 'hodnota';
    } else if (count >= 2 && count <= 4) {
      return 'hodnoty';
    } else {
      return 'hodnot';
    }
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  bool _isEnglish([BuildContext? ctx]) {
    final code = ctx != null
        ? Localizations.localeOf(ctx).languageCode
        : WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'en';
  }

  String _s(String cs, String en) => _isEnglish() ? en : cs;

  String _getModeSpeechNameForL10n(
    CalculatorMode mode,
    AppLocalizations l10n,
  ) {
    switch (mode) {
      case CalculatorMode.basic:
        return l10n.modeSpeechBasic;
      case CalculatorMode.scientific:
        return l10n.modeSpeechScientific;
      case CalculatorMode.statistics:
        return l10n.modeSpeechStatistics;
      case CalculatorMode.electrician:
        return l10n.modeSpeechElectrician;
      case CalculatorMode.unitConversion:
        return l10n.modeSpeechUnitConversion;
    }
  }

  void _updateTtsLanguage() {
    if (!mounted) return;
    final lang = _isEnglish() ? 'en-US' : 'cs-CZ';
    if (_lastTtsLocale == lang) return;
    _lastTtsLocale = lang;
    tts.setLanguage(lang);
  }

  _StatisticsSnapshot? _computeStatisticsSnapshot([int fieldIndex = -1]) {
    if (fieldIndex < 0) fieldIndex = _selectedFieldIndex;
    if (_statsMemory.isEmpty) return null;
    final data = List<double>.from(_getFieldValues(fieldIndex));
    final sum = data.reduce((a, b) => a + b);
    final mean = sum / data.length;
    final variance =
        data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
        data.length;
    final sd = math.sqrt(variance);

    final sorted = List<double>.from(data)..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length % 2 == 1
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;

    final counts = <double, int>{};
    for (final x in data) {
      counts[x] = (counts[x] ?? 0) + 1;
    }
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final modeExists = maxCount > 1;
    final modes = counts.entries
        .where((e) => e.value == maxCount)
        .map((e) => e.key)
        .toList();

    return _StatisticsSnapshot(
      sum: sum,
      mean: mean,
      variance: variance,
      sd: sd,
      median: median,
      modes: modes,
      modeOccurrenceCount: maxCount,
      modeExists: modeExists,
      cv: mean == 0 ? null : (sd / mean) * 100,
    );
  }

  String _formatSpokenNumber(double value) =>
      _formatNumber(value).replaceAll('.', ',');

  String _getButtonName(String label) {
    const localized = {
      'SD': ['Směrodatná odchylka', 'Standard deviation'],
      'VAR': ['Rozptyl', 'Variance'],
      'MEAN': ['Průměr', 'Mean'],
      'STATS': ['Statistický souhrn', 'Statistics summary'],
      'M+': ['Přidat do statistické paměti', 'Add to statistics memory'],
      'MC': ['Smazat statistickou paměť', 'Clear statistics memory'],
      'MR': ['Vyvolat ze statistické paměti', 'Recall statistics memory'],
      'MED': ['Medián', 'Median'],
      'MODE': ['Modus', 'Mode'],
      'CV': ['Variační koeficient', 'Coefficient of variation'],
      'SUM': ['Součet hodnot', 'Sum of values'],
      'WMEAN': ['Vážený průměr', 'Weighted mean'],
      ';': ['Oddělovač dat', 'Data separator'],
      'SETS': ['Správa sad', 'Manage sets'],
    };
    if (localized.containsKey(label)) {
      final pair = localized[label]!;
      return _isEnglish() ? pair[1] : pair[0];
    }
    return _buttonNames[label] ?? label;
  }

  ElectricianCalculation? _electricianCalculationFromButton(String label) {
    switch (label) {
      case 'OHM_V':
        return ElectricianCalculation.voltage;
      case 'OHM_I':
        return ElectricianCalculation.current;
      case 'OHM_R':
        return ElectricianCalculation.resistance;
      default:
        return null;
    }
  }

  String _getElectricianCalculationName(ElectricianCalculation calculation) {
    switch (calculation) {
      case ElectricianCalculation.voltage:
        return 'napětí';
      case ElectricianCalculation.current:
        return 'proud';
      case ElectricianCalculation.resistance:
        return 'odpor';
    }
  }

  String _getElectricianHistoryName(ElectricianCalculation calculation) {
    switch (calculation) {
      case ElectricianCalculation.voltage:
        return 'OHM_V';
      case ElectricianCalculation.current:
        return 'OHM_I';
      case ElectricianCalculation.resistance:
        return 'OHM_R';
    }
  }

  String _getElectricianInputDescription(ElectricianCalculation calculation) {
    switch (calculation) {
      case ElectricianCalculation.voltage:
        return 'proud a odpor';
      case ElectricianCalculation.current:
        return 'napětí a odpor';
      case ElectricianCalculation.resistance:
        return 'napětí a proud';
    }
  }

  String _getElectricianUnitSpeech(
    ElectricianCalculation calculation,
    double value,
    String prefix,
  ) {
    // Prefix je např. 'mili', 'kilo', ''
    // value je jiż přeškálovaná hodnota
    final absValue = value.abs();
    final isWholeNumber = absValue == absValue.roundToDouble();
    final wholeValue = absValue.toInt();

    String unit = '';
    switch (calculation) {
      case ElectricianCalculation.voltage:
        unit = 'volt';
        break;
      case ElectricianCalculation.current:
        unit = 'ampér';
        break;
      case ElectricianCalculation.resistance:
        unit = 'ohm';
        break;
    }

    // Aplikace prefixu na základní jednotku
    if (prefix == 'mili') unit = 'mili${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'mikro') unit = 'mikro${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'nano') unit = 'nano${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'piko') unit = 'piko${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'kilo') unit = 'kilo${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'mega') unit = 'mega${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'giga') unit = 'giga${unit == 'ohm' ? 'ohm' : unit}';

    // Gramatické tvary
    if (isWholeNumber && wholeValue == 1) {
       // Základní jednotka, např. 1 volt, 1 kiloampér
       return unit;
    }

    if (isWholeNumber && wholeValue >= 2 && wholeValue <= 4) {
      // Plural 2-4, např. 2 volty, 2 kiloampéry
      if (unit.endsWith('volt')) return '${unit}y';
      if (unit.endsWith('ampér')) return '${unit}y';
      if (unit.endsWith('ohm')) return '${unit}y';
      return '${unit}y'; // Default
    }

    // Genitiv plural, např. 5 voltů, 5 kiloampérů
    if (unit.endsWith('volt')) return '${unit}ů';
    if (unit.endsWith('ampér')) return '${unit}ů';
    if (unit.endsWith('ohm')) return '${unit}ů';
    return '${unit}ů';
  }

  void _selectElectricianCalculation(ElectricianCalculation calculation) {
    setState(() {
      _selectedElectricianCalculation = calculation;
    });
    final calculationName = _getElectricianCalculationName(calculation);
    final inputDescription = _getElectricianInputDescription(calculation);
    speak(
      'Výpočet $calculationName. Zadejte $inputDescription oddělené středníkem.',
    );
  }

  List<double> _parseElectricianInputValues(String input) {
    final parts = input.split(';');
    if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
      throw const _ElectricianInputException(
        'Zadejte dvě hodnoty oddělené středníkem.',
      );
    }

    try {
      return parts.map((part) => _evaluateExpression(part.trim())).toList();
    } catch (e) {
      throw const _ElectricianInputException(
        'Zadané hodnoty v elektro režimu nemají platný číselný formát.',
      );
    }
  }

  double _calculateElectricianResult(String input) {
    final values = _parseElectricianInputValues(input);
    final first = values[0];
    final second = values[1];

    switch (_selectedElectricianCalculation) {
      case ElectricianCalculation.voltage:
        return first * second;
      case ElectricianCalculation.current:
        if (second == 0) {
          throw const _ElectricianInputException(
            'Odpor nesmí být nula při výpočtu proudu.',
          );
        }
        return first / second;
      case ElectricianCalculation.resistance:
        if (second == 0) {
          throw const _ElectricianInputException(
            'Proud nesmí být nula při výpočtu odporu.',
          );
        }
        return first / second;
    }
  }

  bool _isSelectedElectricianButton(String label) {
    final calculation = _electricianCalculationFromButton(label);
    return calculation != null &&
        calculation == _selectedElectricianCalculation;
  }

  String? _getElectricianButtonSemanticLabel(String label) {
    final calculation = _electricianCalculationFromButton(label);
    if (calculation == null) {
      return null;
    }

    final baseLabel = _buttonNames[label] ?? label;
    if (calculation == _selectedElectricianCalculation) {
      return '$baseLabel, vybráno';
    }
    return baseLabel;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccessibilityState();
    _initTts();
    _loadSettings();
    _loadHistory();
    _loadStatsData();
    _initAppVersion();
  }

  Future<void> _initAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    _currentAppVersion = '${info.version}+${info.buildNumber}';
    if (mounted) {
      _mainFocusNode.requestFocus();
      _checkForUpdates();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    _refreshAccessibilityState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAccessibilityState();
    }
  }

  Future<void> _checkForUpdates() async {
    if (_updateDialogShown || !mounted) {
      return;
    }

    final checker = GitHubReleaseChecker();
    final release = await checker.checkForUpdates(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      currentVersion: _currentAppVersion,
    );

    if (!mounted || release == null || _updateDialogShown) {
      return;
    }

    await _showUpdateDialog(release);
  }

  Future<void> _showUpdateDialog(GitHubReleaseInfo release) async {
    setState(() {
      _updateDialogShown = true;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Semantics(header: true, child: Text('Dostupná aktualizace')),
        content: Semantics(
          label: 'Je dostupná nová verze ${release.normalizedVersion}. Vaše verze je $_currentAppVersion.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Je dostupná nová verze ${release.normalizedVersion}.\n\nVaše verze: $_currentAppVersion',
              ),
              if (release.releaseSummary.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Co je nového:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(release.releaseSummary),
              ],
            ],
          ),
        ),
        actions: [
          Semantics(
            label: 'Později, zavřít dialog bez aktualizace',
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Později'),
            ),
          ),
          Semantics(
            label: 'Zobrazit detail release na GitHubu',
            child: FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final url = release.htmlUrl;
                if (url != null) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
              child: const Text('Zobrazit release'),
            ),
          ),
        ],
      ),
    );
  }

  void _initTts() async {
    try {
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final l10n = lookupAppLocalizations(locale);
      _lastTtsLocale = locale.languageCode == 'en' ? 'en-US' : 'cs-CZ';
      if (_ttsEngine != null) await tts.setEngine(_ttsEngine!);
      await tts.setLanguage(_lastTtsLocale!);
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_speechVolume);
      if (_sayWelcome) {
        speak(
          l10n.welcomeMessage(
            _getModeSpeechNameForL10n(_currentMode, l10n),
          ),
        );
      }
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
    Future.delayed(const Duration(milliseconds: 1000), () async {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('accessibilityType'))
        _showInitialAccessibilityDialog();
    });
  }

  String _getModeName(CalculatorMode mode) {
    switch (mode) {
      case CalculatorMode.basic:
        return _l10n.modeBasic;
      case CalculatorMode.scientific:
        return _l10n.modeScientific;
      case CalculatorMode.statistics:
        return _l10n.modeStatistics;
      case CalculatorMode.electrician:
        return _l10n.modeElectrician;
      case CalculatorMode.unitConversion:
        return _l10n.modeUnitConversion;
    }
  }

  String _getModeSpeechName(CalculatorMode mode) {
    return _getModeSpeechNameForL10n(mode, _l10n);
  }

  Future<void> _refreshAccessibilityState() async {
    try {
      final result = await _accessibilityChannel.invokeMethod<bool>(
        'isTalkBackEnabled',
      );
      if (result != null && mounted) {
        setState(() {
          _accessibleNavigation = result;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accessibleNavigation = WidgetsBinding.instance
              .platformDispatcher.accessibilityFeatures.accessibleNavigation;
        });
      }
    }
  }

  bool get _isScreenReaderActive {
    switch (_screenReaderMode) {
      case ScreenReaderMode.on:
        return true;
      case ScreenReaderMode.off:
        return false;
      case ScreenReaderMode.auto:
        return _accessibleNavigation;
    }
  }

  void speak(String text, {bool force = false}) async {
    // Pokud je aktivní čtečka, vypneme vlastní TTS kalkulačky,
    // pokud není vynuceno (např. systémové hlášení výsledku).
    if (text.isEmpty || !ttsEnabled || !mounted || (_isScreenReaderActive && !force)) {
      return;
    }
    final now = DateTime.now();
    if (_lastSpeakTime != null &&
        now.difference(_lastSpeakTime!) < _speakThrottle) {
      return;
    }
    _lastSpeakTime = now;
    try {
      await tts.stop();
      await tts.speak(_formatForSpeech(text));
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  String _formatForSpeech(String text) {
    String processed = text.replaceAll('.', ',').replaceAll('\u03C0', 'pí');
    processed = processed.replaceAllMapped(
      RegExp(r"(\d+(?:,\d+)?)E([+-])(\d+)"),
      (m) {
        int exp = int.parse(m[3]!);
        return '${m[1]} krát deset na ${m[2] == '-' ? 'mínus ' : ''}$exp';
      },
    );
    return processed;
  }

  void _handleKeyboardInput(KeyEvent event) {
    if (event is KeyDownEvent) {
      final char = event.character;
      final isControl = HardwareKeyboard.instance.isControlPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        calculateResult();
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        backspace();
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        clear();
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyD) {
        if (isShift) {
          _handleButtonPressed("'→°");
        } else {
          _handleButtonPressed("°→'");
        }
      } else if (!isControl && event.logicalKey == LogicalKeyboardKey.keyS) {
        _handleButtonPressed(isShift ? "ASIN" : "SIN");
      } else if (!isControl && event.logicalKey == LogicalKeyboardKey.keyC) {
        _handleButtonPressed(isShift ? "ACOS" : "COS");
      } else if (!isControl && event.logicalKey == LogicalKeyboardKey.keyT) {
        _handleButtonPressed(isShift ? "ATAN" : "TAN");
      } else if (event.logicalKey == LogicalKeyboardKey.keyQ) {
        _handleButtonPressed("√");
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        _handleButtonPressed("ABS");
      } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
        _handleButtonPressed("\u03C0");
      } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _handleButtonPressed("ANS");
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        _insertDegree();
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _insertMinute();
      } else if (char != null) {
        String toAppend = char == ',' ? '.' : char;
        if (RegExp(r'''[0-9.+\-*/^%()eE°'"a-zA-Z]''').hasMatch(toAppend)) {
          _handleButtonPressed(toAppend.toUpperCase(), silent: true);
        }
      }
    }
  }

  void _insertDegree() {
    append('°', silent: true);
    speak('stupňů');
  }

  void _insertMinute() {
    // Pokud je kurzor na konci a poslední znak je číslo, doplníme '
    RegExp lastDigit = RegExp(r'\d$');
    if (display.isNotEmpty &&
        lastDigit.hasMatch(display.substring(0, _cursorPosition))) {
      append("'", silent: true);
      speak('minut');
      return;
    }
    append("'", silent: true);
    speak('minut');
  }

  void backspace() {
    _deleteAtCursor();
  }

  void clear() {
    setState(() {
      display = '';
      _cursorPosition = 0;
      _lastResult = '0.';
      _isStoreMode = false;
      _isRecallMode = false;
      _hasResult = false;
    });
    speak('Vymazat');
  }

  void append(String value, {bool silent = false}) {
    _insertAtCursor(value);
    if (!silent) speak(_buttonNames[value] ?? value);
  }

  void _handleMemoryVariable(String name) {
    if (_isStoreMode) {
      double val = 0;
      try {
        val = double.parse(_lastResult.replaceAll(',', '.'));
      } catch (_) {}
      setState(() {
        _memory[name] = val;
        _isStoreMode = false;
      });
      _saveStatsData();
      speak('Uloženo do proměnné $name');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uloženo do proměnné $name')),
        );
      }
    } else if (_isRecallMode) {
      String valStr = _formatNumber(_memory[name]!).replaceAll('.', ',');
      append(_formatNumber(_memory[name]!), silent: true);
      speak('Vyvoláno z proměnné $name: $valStr');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vyvoláno z proměnné $name: $valStr')),
        );
      }
      _isRecallMode = false;
    } else {
      append(name, silent: true);
      speak('Proměnná $name');
    }
  }

  void _insertAtCursor(String text, {int cursorOffset = 0}) {
    setState(() {
      display =
          display.substring(0, _cursorPosition) +
          text +
          display.substring(_cursorPosition);
      _cursorPosition = (_cursorPosition + text.length + cursorOffset).clamp(
        0,
        display.length,
      );
    });
  }

  void _deleteAtCursor() {
    if (_cursorPosition > 0) {
      setState(() {
        display =
            display.substring(0, _cursorPosition - 1) +
            display.substring(_cursorPosition);
        _cursorPosition--;
      });
      speak('Smazáno');
    }
  }

  void calculateResult() {
    try {
      if (display.isEmpty) return;
      String currentExpression =
          display; // Uložíme výraz před vymazáním displeje

      String resStr = '0';
      String spoken = '';

      if (_currentMode == CalculatorMode.statistics) {
        if (_statsMemory.isEmpty) {
          speak(_l10n.statsMemoryEmptyHint);
          return;
        }
        List<double> data = List.from(_statsMemory);

        double sum = data.reduce((a, b) => a + b);
        double mean = sum / data.length;
        double variance =
            data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
            data.length;
        double sd = math.sqrt(variance);

        resStr = _formatNumber(mean);
        spoken = _s(
          'Průměr z paměti je ${_formatSpokenNumber(mean)}, směrodatná odchylka je ${_formatSpokenNumber(sd)}',
          'Mean from memory is ${_formatSpokenNumber(mean)}, standard deviation is ${_formatSpokenNumber(sd)}',
        );
      } else if (_currentMode == CalculatorMode.electrician) {
        final result = _calculateElectricianResult(display);
        if (!result.isFinite) {
          throw const _ElectricianInputException(
            'Výsledek elektro výpočtu není platné číslo.',
          );
        }

        final calculation = _selectedElectricianCalculation;
        
        final scaledData = _getScaledValueAndPrefix(result);
        final scaledValue = scaledData['value'] as double;
        final prefix = scaledData['prefix'] as String;

        // Formátování pro zobrazení s předponou
        String formattedValue = _formatNumber(scaledValue);
        String unit = '';
        switch (calculation) {
          case ElectricianCalculation.voltage: unit = 'V'; break;
          case ElectricianCalculation.current: unit = 'A'; break;
          case ElectricianCalculation.resistance: unit = '\u03A9'; break; // Omega symbol
        }
        resStr = '$formattedValue $prefix$unit';

        final spokenResult = _formatSpokenNumber(scaledValue);
        final calculationName = _getElectricianCalculationName(calculation);
        final unitSpeech = _getElectricianUnitSpeech(calculation, scaledValue, prefix);
        spoken = '$calculationName je $spokenResult $unitSpeech';
        currentExpression =
            '${_getElectricianHistoryName(calculation)}($display)';
        _lastNumericValue = result;
      } else {
        bool isDms = RegExp(r'''\d+(?:\.\d+)?[°'"]''').hasMatch(display);
        bool isTrig =
            display.toUpperCase().contains('SIN') ||
            display.toUpperCase().contains('COS') ||
            display.toUpperCase().contains('TAN');
        bool isInverse =
            display.toUpperCase().contains('ASIN') ||
            display.toUpperCase().contains('ACOS') ||
            display.toUpperCase().contains('ATAN');

        if (_hasResult && display.toUpperCase().contains('ANS')) {
          isInverse = true;
        }

        double result = _evaluateExpression(display);
        _lastNumericValue = result;

        bool userWantsDms = (_inverseFormatPreference == 0 && _isDegreeMode);
        // DMS formát použijeme pouze pokud:
        // 1. Uživatel to má v nastavení (userWantsDms)
        // 2. A ZÁROVEŇ: buď jde o inverzní funkci (výsledek je úhel), nebo šlo o čistý DMS bez SIN/COS/TAN
        if (userWantsDms && (isInverse || (isDms && !isTrig))) {
          resStr = _formatAsDMS(result);
        } else {
          resStr = _formatNumber(result);
        }

        if (resStr.contains('°')) {
          spoken =
              'Výsledek je ${resStr.replaceAll('°', ' stupňů, ').replaceAll('\'', ' minut a ').replaceAll('"', ' sekund').replaceAll('.', ',')}';
        } else {
          spoken = 'Výsledek je ${resStr.replaceAll('.', ',')}';
        }
      }

      setState(() {
        _lastResult = resStr;
        _hasResult = true;
        display = '';
        _cursorPosition = 0;
      });

      speak(spoken, force: true);
      _addToHistory(currentExpression, resStr);
    } catch (e) {
      String msg =
          'Výrazu nerozumím, zkuste zkontrolovat závorky nebo znaménka';
      if (e is _ElectricianInputException) {
        msg = e.message;
      } else {
        String errStr = e.toString().toLowerCase();
        if (errStr.contains('division by zero') ||
            errStr.contains('infinity')) {
          msg = 'Nulou nelze dělit';
        } else if (errStr.contains('range') ||
            errStr.contains('invalid argument')) {
          msg = 'Hodnota je mimo povolený rozsah funkce';
        }
      }

      setState(() {
        _lastResult = 'Error';
        _hasResult = true;
      });
      speak(msg, force: true);
    }
  }

  double _evaluateExpression(String expr) {
    debugPrint("Evaluating expression: '$expr'");
    String ansValue = _lastNumericValue?.toString() ?? '0';
    String processed = expr
        .replaceAll('ANS', '($ansValue)')
        .replaceAll(' ', '');

    // 1. PŘÍPRAVA SYMBOLŮ
    processed = processed.replaceAll('x²', '^2').replaceAll('x³', '^3');
    processed = processed.replaceAll('\u03C0', '(3.14159265358979323846)');
    processed = processed.replaceAll('(-)', '-');
    processed = processed.replaceAll(',', '.');
    processed = processed.replaceAll('°→\'', '').replaceAll('\'→°', '');

    // 1.5. N-TÁ ODMOCNINA: xⁿ√y -> (y)^(1/x) (POZOR: toto musí být před náhradou √)
    processed = processed.replaceAllMapped(
      RegExp(
        r'(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))ⁿ√(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))',
      ),
      (m) {
        return '(${m[2]})^(1/(${m[1]}))';
      },
    );

    // 2. FUNKCE -> MARKERY (První krok, aby názvy funkcí byly chráněny)
    final Map<String, String> markers = {
      'ASIN': '_ASIN_',
      'ACOS': '_ACOS_',
      'ATAN': '_ATAN_',
      'SIN': '_SIN_',
      'COS': '_COS_',
      'TAN': '_TAN_',
      'ABS': '_ABS_',
      'LOG': '_LOG_',
      'LN': '_LN_',
      '√': '_SQRT_',
      '∛': '_CBRT_',
    };
    markers.forEach((name, marker) {
      String pattern = (name == '√' || name == '∛') ? name : '\\b$name';
      processed = processed.replaceAll(
        RegExp(pattern, caseSensitive: false),
        marker,
      );
    });

    // 3. NAHRAZENÍ PROMĚNNÝCH
    _memory.forEach((key, value) {
      processed = processed.replaceAll(
        RegExp('\\b$key\\b'),
        '(${value.toString()})',
      );
    });

    // 4. E-NOTACE
    processed = processed.replaceAllMapped(
      RegExp(r"(\d+(?:\.\d+)?|\))E([+-]?\d+)"),
      (m) => '${m[1]}*10^(${m[2]})',
    );

    // 5. ROBUSTNÍ IMPLICITNÍ NÁSOBENÍ
    processed = processed.replaceAllMapped(
      RegExp(r'(\d|[A-Z])(?=[A-Z\(])(?![^_]*_)'),
      (m) => '${m[1]}*',
    );
    processed = processed.replaceAllMapped(
      RegExp(r'(\))(?=[\d[A-Z])(?![^_]*_)'),
      (m) => '${m[1]}*',
    );
    processed = processed.replaceAll(')(', ')*(');

    // DMS ZPRACOVÁNÍ
    processed = processed.replaceAllMapped(
      RegExp(
        r'''(?<![\d.])(-?\d+(?:\.\d+)?)°(?:(\d+(?:\.\d+)?)\')?(?:(\d+(?:\.\d+)?)\")?''',
      ),
      (m) {
        double d = double.parse(m[1]!);
        double mn = m[2] != null ? double.parse(m[2]!) : 0.0;
        double sc = m[3] != null ? double.parse(m[3]!) : 0.0;
        double sign = d < 0 ? -1.0 : 1.0;
        return '(${sign * (d.abs() + mn / 60.0 + sc / 3600.0)})';
      },
    );

    // FAKTORIÁL
    processed = processed.replaceAllMapped(RegExp(r'(\d+)!'), (m) {
      int n = int.parse(m[1]!);
      return _factorial(n).toString();
    });

    if (processed.isEmpty) return 0.0;

    // E-NOTACE
    processed = processed.replaceAllMapped(
      RegExp(r"(\d+(?:\.\d+)?|\))E([+-]?\d+)"),
      (m) => '${m[1]}*10^(${m[2]})',
    );

    // N-TÁ ODMOCNINA: xⁿ√y -> root(x, y)
    processed = processed.replaceAllMapped(
      RegExp(
        r'(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))ⁿ√(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))',
      ),
      (m) {
        return 'root(${m[1]},${m[2]})';
      },
    );

    // 6. BALANCOVÁNÍ ZÁVOREK
    int openCount = '('.allMatches(processed).length;
    int closeCount = ')'.allMatches(processed).length;
    if (openCount > closeCount) {
      processed += ')' * (openCount - closeCount);
    } else if (closeCount > openCount) {
      processed = processed.replaceAll(RegExp(r'^\)+|\)+$'), '');
    }

    // =========================================================================
    // 7. EXPANZE MARKERŮ A DEG/RAD KONVERZE
    // =========================================================================
    const String PI_VAL = '3.14159265358979323846';

    // KROK A: Ostatní standardní funkce musíme z markerů expandovat jako PRVNÍ!
    // Tím zmizí matoucí vnitřní závorky typu _SQRT_(5) a nahradí se za čisté sqrt(5).
    processed = processed.replaceAll('_ABS_', 'abs');
    processed = processed.replaceAll('_SQRT_', 'sqrt');
    processed = processed.replaceAll('_LN_', 'ln');

    // Vyčištění speciálních funkcí
    processed = processed.replaceAllMapped(
      RegExp(r'_CBRT_\(([^()]+)\)'),
      (m) => '(${m[1]})^(1/3)',
    );
    processed = processed.replaceAll('_CBRT_', '(');
    processed = processed.replaceAll('_LOG_(', 'log(10,');

    // KROK B: Nyní zpracujeme goniometrické funkce podle zvoleného režimu úhlů
    if (_isDegreeMode) {
      // Pro sin, cos, tan: argument ve stupních * (PI/180)
      processed = processed.replaceAllMapped(
        RegExp(r'_SIN_\((.+)\)'),
        (m) => 'sin(${m[1]}*($PI_VAL/180))',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'_COS_\((.+)\)'),
        (m) => 'cos(${m[1]}*($PI_VAL/180))',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'_TAN_\((.+)\)'),
        (m) => 'tan(${m[1]}*($PI_VAL/180))',
      );

      // Pro asin, acos, atan: ZMĚNA na arcsin, arccos, arctan pro knihovnu math_expressions!
      // Přidány otevírací závorky na začátek pro správnou vyváženost
      processed = processed.replaceAllMapped(
        RegExp(r'_ASIN_\((.+)\)'),
        (m) => '(arcsin(${m[1]})*(180/$PI_VAL))',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'_ACOS_\((.+)\)'),
        (m) => '(arccos(${m[1]})*(180/$PI_VAL))',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'_ATAN_\((.+)\)'),
        (m) => '(arctan(${m[1]})*(180/$PI_VAL))',
      );
    } else {
      // RAD mód: knihovna vyžaduje arcsin, arccos, arctan i v radiánech
      processed = processed.replaceAll('_SIN_', 'sin');
      processed = processed.replaceAll('_COS_', 'cos');
      processed = processed.replaceAll('_TAN_', 'tan');
      processed = processed.replaceAll('_ASIN_', 'arcsin');
      processed = processed.replaceAll('_ACOS_', 'arccos');
      processed = processed.replaceAll('_ATAN_', 'arctan');
    }

    // Odstranění případných zdvojených závorek po dosazení ANS, pokud by vznikly
    processed = processed.replaceAll('arcsin((', 'arcsin(');
    processed = processed.replaceAll('arccos((', 'arccos(');
    processed = processed.replaceAll('arctan((', 'arctan(');

    // Robustní vyvážení závorek
    openCount = '('.allMatches(processed).length;
    closeCount = ')'.allMatches(processed).length;

    if (openCount > closeCount) {
      processed += ')' * (openCount - closeCount);
    } else if (closeCount > openCount) {
      // Odstranění přebytečných ')' na konci
      while (closeCount > openCount && processed.endsWith(')')) {
        processed = processed.substring(0, processed.length - 1);
        closeCount--;
      }
    }

    debugPrint("Parsing expression: $processed");

    // 8. FINÁLNÍ VYHODNOCENÍ
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(processed)) {
      processed = '$processed+0';
    }

    try {
      final p = math_expr.ShuntingYardParser();
      debugPrint("Parsing expression: $processed");
      math_expr.Expression exp = p.parse(processed);
      math_expr.ContextModel cm = math_expr.ContextModel();

      return exp.evaluate(math_expr.EvaluationType.REAL, cm);
    } catch (e) {
      debugPrint("Parse error: $e for expression: $processed");
      rethrow;
    }
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) {
      return value.toString();
    }
    switch (_displayFormat) {
      case DisplayFormat.fix:
        return value.toStringAsFixed(_precision);
      case DisplayFormat.sci:
        return value.toStringAsExponential(_precision).toUpperCase();
      case DisplayFormat.eng:
        if (value == 0) {
          return "0.00E+00";
        }
        int engExp =
            ((math.log(value.abs()) / math.ln10).floor() / 3).floor() * 3;
        return "${(value / math.pow(10, engExp)).toStringAsFixed(_precision)}E${engExp >= 0 ? '+' : ''}${engExp.toString().padLeft(2, '0')}";
      default:
        return value.toString().contains('.')
            ? value
                  .toStringAsFixed(10)
                  .replaceAll(RegExp(r'0+$'), '')
                  .replaceAll(RegExp(r'\.$'), '')
            : value.toInt().toString();
    }
  }

  String _decimalToFraction(double val) {
    if (val.isNaN || val.isInfinite || val == 0) {
      return _s('nedostupné', 'N/A');
    }
    bool negative = val < 0;
    val = val.abs();
    double intPart = val.floorToDouble();
    double frac = val - intPart;
    if (frac < 1e-10) {
      return '${negative ? '-' : ''}${intPart.toInt()}/1';
    }
    double hPrev = 1, hCurr = 0;
    double kPrev = 0, kCurr = 1;
    double remaining = frac;
    const int maxIter = 10000;
    int iter = 0;
    while (iter < maxIter && kCurr <= 10000) {
      double a = remaining.floorToDouble();
      double hNext = a * hCurr + hPrev;
      double kNext = a * kCurr + kPrev;
      if (kNext > 10000) {
        break;
      }
      hPrev = hCurr; hCurr = hNext;
      kPrev = kCurr; kCurr = kNext;
      double approx = (intPart * kCurr + hCurr) / kCurr;
      if ((val - approx).abs() < 1e-10) {
        break;
      }
      double diff = remaining - a;
      if (diff < 1e-10) break;
      remaining = 1.0 / diff;
      iter++;
    }
    int num = (intPart * kCurr + hCurr).round();
    int den = kCurr.round();
    if (negative) num = -num;
    return '$num/$den';
  }

  List<int> _primeFactors(int n) {
    List<int> factors = [];
    int m = n;
    while (m % 2 == 0) {
      factors.add(2);
      m ~/= 2;
    }
    for (int i = 3; i * i <= m; i += 2) {
      while (m % i == 0) {
        factors.add(i);
        m ~/= i;
      }
    }
    if (m > 1) {
      factors.add(m);
    }
    return factors;
  }

  List<int> _getDivisors(int n) {
    List<int> divs = [];
    for (int i = 1; i * i <= n; i++) {
      if (n % i == 0) {
        divs.add(i);
        if (i != n ~/ i) {
          divs.add(n ~/ i);
        }
      }
    }
    divs.sort();
    return divs;
  }

  String _formatAsDMS(double value) {
    double absVal = value.abs();
    double totalSeconds = absVal * 3600;
    int wholeSeconds = totalSeconds.floor();
    double fracSeconds = totalSeconds - wholeSeconds;
    int s = wholeSeconds % 60;
    int totalMinutes = wholeSeconds ~/ 60;
    int m = totalMinutes % 60;
    int d = totalMinutes ~/ 60;

    String sStr;
    if (fracSeconds > 0) {
      sStr = (s + fracSeconds)
          .toStringAsFixed(6)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    } else {
      sStr = s.toString();
    }

    return "${value < 0 ? '-' : ''}$d°$m'$sStr\"";
  }

  void _convertUnits() {
    try {
      double value = display.isNotEmpty
          ? _evaluateExpression(display)
          : double.parse(_lastResult.replaceAll(',', '.'));
      double fromFactor = _unitCategories[_selectedUnitCategory]![_unitFrom]!;
      double toFactor = _unitCategories[_selectedUnitCategory]![_unitTo]!;
      double result = value * (fromFactor / toFactor);
      String resStr = _formatNumber(result);
      setState(() {
        _lastResult = resStr;
        display = '';
        _hasResult = true;
      });
      speak(
        'Převedeno z ${_getUnitSpeech(_unitFrom, context: 'z')} na ${_getUnitSpeech(_unitTo, context: 'na')}. Výsledek je $resStr ${_getUnitSpeech(_unitTo, value: result)}',
        force: true,
      );
    } catch (e) {
      speak('Chyba převodu', force: true);
    }
  }

  String _getUnitSpeech(
    String unitCode, {
    double? value,
    String context = 'base',
  }) {
    final data = _unitSpeechData[unitCode];
    if (data == null) {
      return unitCode;
    }
    if (value != null) {
      double absVal = value.abs();
      if (absVal % 1 != 0) {
        return data['forms'][3];
      }
      if (absVal == 1) {
        return data['forms'][0];
      }
      if (absVal >= 2 && absVal <= 4) {
        return data['forms'][1];
      }
      return data['forms'][2];
    }
    return data[context] ?? data['base'];
  }

  String _normalizeForSegmentDisplay(String text) {
    if (text.toLowerCase() == 'error') {
      return _useSixteenSegment ? 'CHYBA' : 'Err';
    }
    const map = {
      'á': 'A',
      'č': 'C',
      'ď': 'D',
      'é': 'E',
      'ě': 'E',
      'í': 'I',
      'ň': 'N',
      'ó': 'O',
      'ř': 'R',
      'š': 'S',
      'ť': 'T',
      'ú': 'U',
      'ů': 'U',
      'ý': 'Y',
      'ž': 'Z',
    };
    String result = text;
    map.forEach(
      (key, value) => result = result
          .replaceAll(key, value)
          .replaceAll(key.toUpperCase(), value),
    );
    return result;
  }

  Widget _buildMainResultDisplay() {
    String res = _lastResult.isEmpty ? '0.' : _lastResult;
    if (res.contains('°')) {
      return _buildDmsDisplay(res);
    }
    if ((_displayFormat != DisplayFormat.standard) &&
        res.toLowerCase() != 'error') {
      return _buildScientificTripleDisplay(res);
    }
    return _buildStandardDisplay(res);
  }

  Widget _buildStandardDisplay(String res) {
    return CustomSegmentDisplay(
      value: _normalizeForSegmentDisplay(res),
      size: 16 * _resultZoom,
      characterCount: 16,
      isSixteenSegment: _useSixteenSegment,
    );
  }

  Widget _buildScientificTripleDisplay(String text) {
    List<String> parts = text.contains('E') ? text.split('E') : [text, '00'];
    String mantissa = parts[0];
    String exponent = parts[1].replaceAll('+', '');
    String formattedExp = exponent.startsWith('-')
        ? '-${exponent.substring(1).padLeft(2, '0')}'
        : exponent.padLeft(3, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildStandardDisplay(mantissa),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'x10',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            CustomSegmentDisplay(
              value: formattedExp,
              size: 8 * _resultZoom,
              characterCount: 3,
              isSixteenSegment: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDmsDisplay(String text) {
    // DMS už zobrazujeme na jednom řádku přímo pomocí CustomSegmentDisplay
    return _buildStandardDisplay(text);
  }

  void _changeMode(CalculatorMode mode) {
    setState(() {
      _currentMode = mode;
      display = '';
    });
    String speech = _l10n.switchedToMode(_getModeSpeechName(mode));
    if (mode == CalculatorMode.statistics && !_hasStatsSet) {
      speech += '. ' + _s(
        'Zatím nemáte vytvořenou žádnou statistickou sadu. Vytvořte ji stisknutím tlačítka SETS.',
        'You have no statistical sets created yet. Create one by pressing the SETS button.'
      );
    }
    speak(speech);
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDegreeMode = prefs.getBool('isDegreeMode') ?? true;
      _fontSizeMultiplier = prefs.getDouble('fontSizeMultiplier') ?? 1.0;
      _dotMatrixZoom = prefs.getDouble('dotMatrixZoom') ?? 1.0;
      _resultZoom = prefs.getDouble('resultZoom') ?? 1.0;
      ttsEnabled = prefs.getBool('ttsEnabled') ?? true;
      _useSixteenSegment = prefs.getBool('useSixteenSegment') ?? false;
      _accessibilityType =
          AccessibilityType.values[prefs.getInt('accessibilityType') ?? 0];
      _speechRate = prefs.getDouble('speechRate') ?? 0.5;
      _speechVolume = prefs.getDouble('speechVolume') ?? 1.0;
      _ttsEngine = prefs.getString('ttsEngine');
      _inverseFormatPreference = prefs.getInt('inverseFormatPreference');
      final savedMode = prefs.getInt('screenReaderModeState');
      if (savedMode != null) {
        _screenReaderMode = ScreenReaderMode.values[savedMode];
      } else {
        _screenReaderMode = prefs.getBool('screenReaderMode') == true
            ? ScreenReaderMode.on
            : ScreenReaderMode.auto;
      }
      final savedDialogSize = prefs.getInt('dialogSize');
      if (savedDialogSize != null) {
        _dialogSize = DialogSize.values[savedDialogSize];
      }
    });
    await tts.setSpeechRate(_speechRate);
    await tts.setVolume(_speechVolume);
    if (_ttsEngine != null) await tts.setEngine(_ttsEngine!);
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDegreeMode', _isDegreeMode);
    await prefs.setDouble('fontSizeMultiplier', _fontSizeMultiplier);
    await prefs.setDouble('dotMatrixZoom', _dotMatrixZoom);
    await prefs.setDouble('resultZoom', _resultZoom);
    await prefs.setBool('ttsEnabled', ttsEnabled);
    await prefs.setBool('useSixteenSegment', _useSixteenSegment);
    await prefs.setInt('accessibilityType', _accessibilityType.index);
    await prefs.setDouble('speechRate', _speechRate);
    await prefs.setDouble('speechVolume', _speechVolume);
    if (_ttsEngine != null) await prefs.setString('ttsEngine', _ttsEngine!);
    await prefs.setInt('screenReaderModeState', _screenReaderMode.index);
    await prefs.setInt('dialogSize', _dialogSize.index);
  }

  void _saveInversePreference(int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inverseFormatPreference', val);
    setState(() => _inverseFormatPreference = val);
  }

  void _toggleTts() {
    setState(() {
      ttsEnabled = !ttsEnabled;
    });
    _saveSettings();
    speak(ttsEnabled ? 'Hlas zapnut' : 'Hlas vypnut');
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList('history') ?? []);
  }

  void _loadStatsData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final statsJson = prefs.getString('statsSets');
      if (statsJson != null) {
        _statsSets.clear();
        _statsSets.addAll(
          (jsonDecode(statsJson) as List)
              .map((e) => StatisticsSet.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
      _currentStatsSetIndex = prefs.getInt('currentStatsSetIndex') ?? 0;
      final memJson = prefs.getString('memoryVariables');
      if (memJson != null) {
        final decoded = jsonDecode(memJson) as Map<String, dynamic>;
        decoded.forEach((key, value) => _memory[key] = (value as num).toDouble());
      }
    });
  }

  void _saveStatsData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'statsSets', jsonEncode(_statsSets.map((s) => s.toJson()).toList()));
    await prefs.setInt('currentStatsSetIndex', _currentStatsSetIndex);
    await prefs.setString('memoryVariables', jsonEncode(_memory));
  }

  void _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history);
  }

  void _addToHistory(String exp, String res) {
    setState(() {
      // Používáme oddělovač |, který se v matematických výrazech nevyskytuje
      _history.insert(0, '$exp|$res');
      if (_history.length > 20) _history.removeLast();
    });
    _saveHistory();
  }

  Future<void> _exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {};
      for (final key in prefs.getKeys()) {
        data[key] = prefs.get(key);
      }
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/kalkulacka_zaloha.json');
      await file.writeAsString(jsonStr);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: _l10n.backupData,
        ),
      );

      speak(_l10n.backupSuccess, force: true);
    } catch (e) {
      debugPrint('Chyba při vytváření zálohy: $e');
      speak('Chyba při vytváření zálohy', force: true);
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return;
      }

      final data = jsonDecode(content) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      for (final entry in data.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is List) {
          await prefs.setStringList(
              entry.key, value.map((e) => e.toString()).toList());
        }
      }

      _loadSettings();
      _loadHistory();
      _loadStatsData();
      setState(() {});
      speak(_l10n.restoreSuccess, force: true);
    } catch (e) {
      debugPrint('Chyba při obnově dat: $e');
      speak('Chyba při obnově dat', force: true);
    }
  }

  void _showInitialAccessibilityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text('Vítejte')),
        content: Text(
          'Vyberte požadovanou úroveň usnadnění. Toto nastavení můžete kdykoliv změnit v nastavení.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _accessibilityType = AccessibilityType.none);
              _saveSettings();
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mainFocusNode.requestFocus();
              });
            },
            child: Text('STANDARDNÍ'),
          ),
          TextButton(
            autofocus: true,
            onPressed: () {
              setState(() {
                _accessibilityType = AccessibilityType.blind;
                ttsEnabled = true;
              });
              _saveSettings();
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mainFocusNode.requestFocus();
              });
            },
            child: Text('PRO NEVIDOMÉ'),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => _AccessibilityDialog(parent: this),
    );
  }

  void _showTtsEngineDialog() async {
    try {
      final engines = await tts.getEngines;
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vybrat TTS engine'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: engines.length,
              itemBuilder: (context, index) {
                final engine = engines[index].toString();
                return ListTile(
                  title: Text(engine),
                  selected: _ttsEngine == engine,
                  onTap: () {
                    setState(() => _ttsEngine = engine);
                    _saveSettings();
                    tts.setEngine(engine);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('TTS Engine Error: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Semantics(header: true, child: const Text('Chyba')),
          content: Focus(
            autofocus: true,
            child: Semantics(
              label: 'Výběr TTS enginu není na tomto zařízení nebo verzi aplikace podporován.',
              child: const Text(
                'Výběr TTS enginu není na tomto zařízení nebo verzi aplikace podporován.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zavřít'),
            ),
          ],
        ),
      );
    }
  }

  void _showTutorialDialog() {
    final l10n = AppLocalizations.of(context)!;
    String tutorialText = l10n.tutorialText;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final sections = tutorialText.split('\n\n');
      if (sections.length > 1) {
        tutorialText = sections.take(sections.length - 1).join('\n\n');
      }
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text(l10n.helpTitle)),
        content: Focus(
          autofocus: true,
          onFocusChange: (hasFocus) {
            if (hasFocus) speak(tutorialText);
          },
          child: Semantics(
            container: true,
            child: SingleChildScrollView(child: Text(tutorialText)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _mainFocusNode.requestFocus();
              });
            },
            child: Text(l10n.understand),
          ),
        ],
      ),
    );
  }

  void _showPrecisionDialog(DisplayFormat format) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text('Nastavení přesnosti')),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            15,
            (i) => ElevatedButton(
              autofocus: i == _precision,
              onPressed: () {
                setState(() {
                  _displayFormat = format;
                  _precision = i;
                  if (_lastNumericValue != null) {
                    _lastResult = _formatNumber(_lastNumericValue!);
                  }
                });
                speak('Nastaveno $i desetinných míst');
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mainFocusNode.requestFocus();
                });
              },
              child: Text('$i'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mainFocusNode.requestFocus();
              });
            },
            child: Text('ZRUŠIT'),
          ),
        ],
      ),
    );
  }

  Widget _buildDotMatrixDisplay() {
    String txt = display.isEmpty
        ? (_hasResult ? "" : "_")
        : "${display.substring(0, _cursorPosition)}_${display.substring(_cursorPosition)}";
    return CustomDotMatrixDisplay(
      text: txt,
      ledSize: 3.0 * _dotMatrixZoom,
      ledSpacing: 0.8 * _dotMatrixZoom,
    );
  }

  Widget buildButton(
    String label, {
    Color? color,
    String? semanticLabel,
    VoidCallback? onPressed,
    VoidCallback? onLongPressed,
    bool expanded = true,
  }) {
    String descriptiveName = semanticLabel ?? _getButtonName(label);
    if (label == 'M+' && _currentMode == CalculatorMode.statistics) {
      descriptiveName +=
          ', krátký stisk pro přidání hodnoty, dlouhý stisk pro zadání opakování';
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget buttonBody = Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.grey[800] : Colors.grey[300]),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ExcludeSemantics(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20 * _fontSizeMultiplier,
              fontWeight: FontWeight.bold,
              color: color != null
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black),
            ),
          ),
        ),
      ),
    );

    Widget buttonWidget = Semantics(
      label: descriptiveName,
      button: true,
      enabled: true,
      onTap:
          onPressed ??
          () {
              if (!['°→\'', '\'→°', 'DMS'].contains(label)) {
              if (!_isScreenReaderActive) speak(descriptiveName);
            }
            _handleButtonPressed(label);
          },
      child: InkWell(
        excludeFromSemantics:
            true, // Zamezí TalkBacku vidět InkWell jako samostatný prvek
        onFocusChange: (hasFocus) {
          // Mluvíme pouze pokud není aktivní TalkBack, aby nedocházelo k dvojitému čtení
          if (hasFocus && !_isScreenReaderActive) speak(descriptiveName);
        },
        onTap:
            onPressed ??
            () {
              if (!['°→\'', '\'→°', 'DMS'].contains(label)) {
                // Pokud je aktivní čtečka, nevoláme speak, protože čtečka přečte label sama.
                if (!_isScreenReaderActive) speak(descriptiveName);
              }
              _handleButtonPressed(label);
            },
        onLongPress: onLongPressed,
        child: buttonBody,
      ),
    );

    if (expanded) {
      return Expanded(child: buttonWidget);
    } else {
      return buttonWidget;
    }
  }

  List<StatisticsRecord> _parseDisplayToRecords(String text) {
    final parts = text
        .split(';')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => double.parse(s.trim().replaceAll(',', '.')))
        .toList();
    final fieldCount = _currentFieldCount;
    if (fieldCount == 1) {
      return parts.map((v) => StatisticsRecord(values: [v])).toList();
    }
    final records = <StatisticsRecord>[];
    for (int i = 0; i + fieldCount <= parts.length; i += fieldCount) {
      records.add(StatisticsRecord(values: parts.sublist(i, i + fieldCount)));
    }
    if (records.isEmpty || records.length * fieldCount != parts.length) {
      throw FormatException(_s(
        'Počet hodnot musí být násobkem počtu polí ($fieldCount).',
        'Number of values must be a multiple of field count ($fieldCount).',
      ));
    }
    return records;
  }

  void _addSingleValueToStats() {
    if (!_hasStatsSet) {
      speak(_s(
        'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
        'No statistics set created. Enter a name for a new set first.',
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_s(
            'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
            'No statistics set created. Enter a name for a new set first.',
          ))),
        );
      }
      _showCreateStatsSetDialog(context, () {
        _addSingleValueToStats();
      });
      return;
    }
    if (display.isEmpty) {
      speak(_s(
        'Displej je prázdný. Zadejte číslo k uložení.',
        'Display is empty. Enter a number to store.',
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_s(
            'Displej je prázdný. Zadejte číslo k uložení.',
            'Display is empty. Enter a number to store.',
          ))),
        );
      }
      return;
    }
    try {
      final recordsToAdd = _parseDisplayToRecords(display);

      if (recordsToAdd.isEmpty) {
        speak(_s(
          'Žádná platná čísla k uložení.',
          'No valid numbers to store.',
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_s(
              'Žádná platná čísla k uložení.',
              'No valid numbers to store.',
            ))),
          );
        }
        return;
      }

      _addValuesToStats(recordsToAdd, 1);
    } catch (e) {
      speak(_s(
        'Chyba při ukládání do statistické paměti. Zkontrolujte formát dat.',
        'Error storing to statistics memory. Check the data format.',
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_s(
            'Chyba při ukládání do statistické paměti. Zkontrolujte formát dat.',
            'Error storing to statistics memory. Check the data format.',
          ))),
        );
      }
    }
  }

  void _handleButtonPressed(String label, {bool silent = false}) {
    bool alreadyHandled = false;
    if (_hasResult) {
      setState(() {
        if (['+', '-', '*', '/', '^', '%', 'EXP', 'x²', 'x³'].contains(label)) {
          display = 'ANS';
          _cursorPosition = 3;
          _hasResult = false;
        } else if ([
          'SIN',
          'COS',
          'TAN',
          'ASIN',
          'ACOS',
          'ATAN',
          '√',
          '∛',
          'ABS',
          'LOG',
          'LN',
        ].contains(label)) {
          display = '$label(ANS)';
          _cursorPosition = display.length;
          _hasResult = false;
          if (!silent) {
            final name = _buttonNames[label] ?? label;
            if (['ASIN', 'ACOS', 'ATAN'].contains(label)) {
              speak('Inverzní $name z výsledku');
            } else {
              speak('$name z výsledku');
            }
          }
          alreadyHandled = true;
        } else if (label == 'ⁿ√') {
          display = 'ANSⁿ√';
          _cursorPosition = 5;
          _hasResult = false;
          alreadyHandled = true;
        } else if (label == '(') {
          display = 'ANS';
          _cursorPosition = 3;
          _hasResult = false;
        } else if (RegExp(r'[0-9.]').hasMatch(label)) {
          display = '';
          _cursorPosition = 0;
          _hasResult = false;
        } else if (label == '°→\'' || label == '\'→°') {
          display = 'ANS';
          _cursorPosition = 3;
          _hasResult = false;
        } else if (label != 'C' && label != 'DEL' && label != '=') {
          display = '';
          _cursorPosition = 0;
          _hasResult = false;
        }
      });
      if (alreadyHandled) return;
    }

    if (label == 'C') {
      clear();
    } else if (label == 'DEL') {
      backspace();
    } else if (label == '=') {
      calculateResult();
    } else if (label == 'M+') {
      if (_currentMode == CalculatorMode.statistics) {
        // Logika pro krátký a dlouhý stisk je obsloužena v `buildButton`
        // Pokud je vyvoláno zde (např. klávesnice), defaultně provedeme krátký stisk
        _addSingleValueToStats();
      } else {
        speak(_s(
          'Tlačítko M plus je dostupné pouze ve statistickém režimu.',
          'The M+ button is available only in statistics mode.',
        ));
      }
    } else if (label == 'MC') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          speak(_s('Není vytvořena žádná sada.', 'No set created.'));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_s('Není vytvořena žádná sada.', 'No set created.'))),
            );
          }
          return;
        }
        setState(() {
          _statsMemory.clear();
        });
        _saveStatsData();
        final setName = _statsSets[_currentStatsSetIndex].name;
        speak(_s(
          'Paměť sady $setName byla smazána.',
          'Memory of set $setName was cleared.',
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_s(
              'Paměť sady $setName byla smazána.',
              'Memory of set $setName was cleared.',
            ))),
          );
        }
      } else {
        speak(_s(
          'Tlačítko M C je dostupné pouze ve statistickém režimu.',
          'The MC button is available only in statistics mode.',
        ));
      }
    } else if (label == 'MR') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          speak(_s('Není vytvořena žádná sada.', 'No set created.'));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_s('Není vytvořena žádná sada.', 'No set created.'))),
            );
          }
          return;
        }
        if (_statsMemory.isEmpty) {
          speak(_l10n.statsMemoryEmpty);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_l10n.statsMemoryEmpty)),
            );
          }
        } else {
          _showStatisticsMemoryDialog();
        }
      } else {
        speak(_s(
          'Tlačítko M R je dostupné pouze ve statistickém režimu.',
          'The MR button is available only in statistics mode.',
        ));
      }
    } else if (label == 'STATS') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          speak(_s('Není vytvořena žádná sada.', 'No set created.'));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_s('Není vytvořena žádná sada.', 'No set created.'))),
            );
          }
          return;
        }
        if (_statsMemory.isEmpty) {
          speak(_l10n.statsMemoryEmptyHint);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_l10n.statsMemoryEmptyHint)),
            );
          }
        } else {
          _showStatisticsSummaryDialog();
        }
      } else {
        speak(_s(
          'Statistický souhrn je dostupný pouze ve statistickém režimu.',
          'Statistics summary is available only in statistics mode.',
        ));
      }
    } else if (label == 'SETS') {
      if (_currentMode == CalculatorMode.statistics) {
        _showStatsSetsDialog();
      } else {
        speak(_s(
          'Správa sad je dostupná pouze ve statistickém režimu.',
          'Manage sets is available only in statistics mode.',
        ));
      }
    } else if (_electricianCalculationFromButton(label) != null) {
      if (_currentMode == CalculatorMode.electrician) {
        _selectElectricianCalculation(
          _electricianCalculationFromButton(label)!,
        );
      } else {
        append(label, silent: silent);
      }
    } else if (['MEAN', 'SD', 'VAR', 'MED', 'MODE', 'CV', 'SUM', 'WMEAN'].contains(label)) {
      if (_currentMode == CalculatorMode.statistics) {
        try {
          if (_statsMemory.isEmpty) {
            speak(_l10n.statsMemoryEmptyHint);
            return;
          }

          final fieldNames = _statsSets[_currentStatsSetIndex].fieldNames;

          if (label == 'WMEAN') {
            if (_currentFieldCount < 2) {
              speak(_s(
                'Vážený průměr vyžaduje alespoň 2 pole (hodnoty a váhy).',
                'Weighted mean requires at least 2 fields (values and weights).',
              ));
              return;
            }
            final values = _getFieldValues(0);
            final weights = _getFieldValues(1);
            double sumW = 0;
            double sumVW = 0;
            for (int i = 0; i < values.length; i++) {
              sumVW += values[i] * weights[i];
              sumW += weights[i];
            }
            if (sumW == 0) {
              speak(_s(
                'Součet vah je nulový, nelze vypočítat vážený průměr.',
                'Sum of weights is zero, cannot calculate weighted mean.',
              ));
              return;
            }
            final wmean = sumVW / sumW;
            final resStr = _formatNumber(wmean);
            final spoken = _s(
              'Vážený průměr z paměti je ${_formatSpokenNumber(wmean)} '
              '(pole ${fieldNames[0]} váženo polem ${fieldNames[1]})',
              'Weighted mean from memory is ${_formatSpokenNumber(wmean)} '
              '(field ${fieldNames[0]} weighted by field ${fieldNames[1]})',
            );
            setState(() {
              _lastResult = resStr;
              _hasResult = true;
              display = resStr;
              _cursorPosition = display.length;
              _lastNumericValue = double.tryParse(resStr.replaceAll(',', '.'));
            });
            speak(spoken, force: true);
            _addToHistory('STATS($label)', resStr);
            return;
          }

          final snapshot = _computeStatisticsSnapshot()!;

          String resStr = '0';
          String spoken = '';
          final fieldLabelSpoken = _currentFieldCount > 1
              ? _s(' pro pole ${fieldNames[_selectedFieldIndex]}', ' for field ${fieldNames[_selectedFieldIndex]}')
              : '';

          if (label == 'MEAN') {
            resStr = _formatNumber(snapshot.mean);
            spoken = _s(
              'Průměr${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.mean)}',
              'Mean${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.mean)}',
            );
          } else if (label == 'SUM') {
            resStr = _formatNumber(snapshot.sum);
            spoken = _s(
              'Součet hodnot${fieldLabelSpoken} je ${_formatSpokenNumber(snapshot.sum)}',
              'Sum of values${fieldLabelSpoken} is ${_formatSpokenNumber(snapshot.sum)}',
            );
          } else if (label == 'VAR') {
            resStr = _formatNumber(snapshot.variance);
            spoken = _s(
              'Rozptyl${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.variance)}',
              'Variance${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.variance)}',
            );
          } else if (label == 'SD') {
            resStr = _formatNumber(snapshot.sd);
            spoken = _s(
              'Směrodatná odchylka${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.sd)}',
              'Standard deviation${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.sd)}',
            );
          } else if (label == 'MED') {
            resStr = _formatNumber(snapshot.median);
            spoken = _s(
              'Medián${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.median)}',
              'Median${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.median)}',
            );
          } else if (label == 'MODE') {
            if (!snapshot.modeExists) {
              resStr = _formatNumber(_getFieldValues(_selectedFieldIndex).first);
              spoken = _s(
                'Modus${fieldLabelSpoken} neexistuje, všechny hodnoty se vyskytují pouze jednou.',
                'No mode${fieldLabelSpoken} exists, all values occur only once.',
              );
            } else {
              resStr = snapshot.modes.map((m) => _formatNumber(m)).join(';');
              final modesSpoken = snapshot.modes
                  .map((m) => _formatSpokenNumber(m))
                  .join(_s(' a ', ' and '));
              if (snapshot.modes.length == 1) {
                spoken = _s(
                  'Modus${fieldLabelSpoken} z paměti je $modesSpoken, vyskytuje se ${snapshot.modeOccurrenceCount} krát',
                  'Mode${fieldLabelSpoken} from memory is $modesSpoken, occurs ${snapshot.modeOccurrenceCount} times',
                );
              } else {
                spoken = _s(
                  'Modusy${fieldLabelSpoken} z paměti jsou $modesSpoken, vyskytují se ${snapshot.modeOccurrenceCount} krát',
                  'Modes${fieldLabelSpoken} from memory are $modesSpoken, occur ${snapshot.modeOccurrenceCount} times',
                );
              }
            }
          } else if (label == 'CV') {
            if (snapshot.cv == null) {
              spoken = _s(
                'Nelze vypočítat variační koeficient${fieldLabelSpoken}, průměr je nula.',
                'Cannot calculate coefficient of variation${fieldLabelSpoken}, mean is zero.',
              );
              resStr = 'Err';
            } else {
              resStr = _formatNumber(snapshot.cv!);
              spoken = _s(
                'Variační koeficient${fieldLabelSpoken} je ${_formatSpokenNumber(snapshot.cv!)} procent',
                'Coefficient of variation${fieldLabelSpoken} is ${_formatSpokenNumber(snapshot.cv!)} percent',
              );
            }
          }

          setState(() {
            _lastResult = resStr;
            _hasResult = true;
            display = resStr;
            _cursorPosition = display.length;
            _lastNumericValue = double.tryParse(resStr.replaceAll(',', '.'));
          });
          speak(spoken, force: true);
          _addToHistory('STATS($label)', resStr);
        } catch (e) {
          speak(_s(
            'Chyba statistického výpočtu.',
            'Statistics calculation error.',
          ), force: true);
        }
      } else {
        append(label, silent: silent);
      }
    } else if (label == 'STO') {
      _isStoreMode = true;
      speak('Vyberte paměť');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Vyberte paměť')),
        );
      }
    } else if (label == 'RCL') {
      _isRecallMode = true;
      speak('Vyberte paměť pro vyvolání');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Vyberte paměť pro vyvolání')),
        );
      }
    } else if (label == 'CLR') {
      setState(() {
        _memory.updateAll((key, value) => 0);
      });
      _saveStatsData();
      speak('Paměť smazána');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Paměť smazána')),
        );
      }
    } else if (_memory.containsKey(label)) {
      _handleMemoryVariable(label);
    } else if (label == 'EXP') {
      append('E', silent: silent);
    } else if ([
      'SIN',
      'COS',
      'TAN',
      'ASIN',
      'ACOS',
      'ATAN',
      '√',
      '∛',
      'ABS',
      'LOG',
      'LN',
    ].contains(label)) {
      _insertAtCursor('$label(', cursorOffset: 0);
      if (!silent) speak(_buttonNames[label] ?? label);
    } else if (label == 'DMS') {
      // 1. Získat text PŘED kurzorem
      String textBefore = display.substring(0, _cursorPosition);

      // 2. Hledáme poslední číselný blok a případný existující DMS symbol
      // Regex hledá: (číslo)(volitelný symbol)(volitelné další číslice na konci)
      RegExp dmsSearch = RegExp(r'''(\d+(?:\.\d+)?)([°'\"])?(\d+)?$''');
      Match? match = dmsSearch.firstMatch(textBefore);

      if (match != null) {
        String? symbol = match.group(2);
        String? trailingDigits = match.group(3);

        if (trailingDigits == null && symbol != null) {
          // Jsme těsně za symbolem (např. "36°"), budeme ho cyklovat
          String nextSymbol = '°';
          String spoken = 'stupňů';
          if (symbol == '°') {
            nextSymbol = "'";
            spoken = 'minut';
          } else if (symbol == "'") {
            nextSymbol = '"';
            spoken = 'sekund';
          }

          setState(() {
            display =
                display.substring(0, _cursorPosition - 1) +
                nextSymbol +
                display.substring(_cursorPosition);
          });
          speak(spoken);
        } else {
          // Jsme za číslem (např. "36°25" nebo jen "36"), určíme co vložit
          String toInsert = '°';
          String spoken = 'stupňů';

          if (symbol == '°') {
            toInsert = "'";
            spoken = 'minut';
          } else if (symbol == "'") {
            toInsert = '"';
            spoken = 'sekund';
          }

          append(toInsert, silent: true);
          speak(spoken);
        }
      } else {
        // Nenalezeno žádné číslo před kurzorem, vložíme výchozí stupně
        append('°', silent: true);
        speak('stupňů');
      }
    } else if (['°→\'', '\'→°'].contains(label)) {
      try {
        double val = display.isNotEmpty
            ? _evaluateExpression(display)
            : (_lastNumericValue ?? 0.0);
        if (label == '°→\'') {
          // Převod na DMS
          String dmsStr = _formatAsDMS(val);
          setState(() {
            _lastResult = dmsStr;
            _hasResult = true;
            display = '';
            _cursorPosition = 0;
            _lastNumericValue = val;
          });
          // Formátování pro TTS: "12°34'5\"" -> "12 stupňů, 34 minut a 5 sekund"
          String spokenDms = dmsStr
              .replaceAll('°', ' stupňů, ')
              .replaceAll("'", ' minut a ')
              .replaceAll('"', ' sekund')
              .replaceAll('.', ',');
          speak('Výsledek je $spokenDms', force: true);
        } else {
          // Převod na desetinné stupně
          String decimalStr = val
              .toStringAsFixed(4)
              .replaceAll(RegExp(r'\.0+$'), '')
              .replaceAll(RegExp(r'0+$'), '');
          setState(() {
            _lastResult = decimalStr;
            _hasResult = true;
            display = '';
            _cursorPosition = 0;
            _lastNumericValue = val;
          });
          speak('Výsledek je ${decimalStr.replaceAll('.', ',')} stupňů', force: true);
        }
      } catch (e) {
        speak('Chyba při převodu', force: true);
      }
    } else if (label == '\u03C0') {
      append(label, silent: silent);
    } else {
      append(label, silent: silent);
    }
  }

  Widget _buildMainKeyboard() {
    List<String> btns = [];
    switch (_currentMode) {
      case CalculatorMode.basic:
        btns = [
          'C',
          '(',
          ')',
          '/',
          '7',
          '8',
          '9',
          '*',
          '4',
          '5',
          '6',
          '-',
          '1',
          '2',
          '3',
          '+',
          'DEL',
          '0',
          '.',
          '=',
        ];
        break;
      case CalculatorMode.scientific:
        btns = [
          'C',
          '(',
          ')',
          '/',
          '7',
          '8',
          '9',
          '*',
          '4',
          '5',
          '6',
          '-',
          '1',
          '2',
          '3',
          '+',
          '0',
          '.',
          'EXP',
          '=',
        ];
        break;
      case CalculatorMode.statistics:
        btns = [
          'SETS',
          'MC',
          'MR',
          'M+',
          'STATS',
          'C',
          'DEL',
          '/',
          '7',
          '8',
          '9',
          '*',
          '4',
          '5',
          '6',
          '-',
          '1',
          '2',
          '3',
          '+',
          '0',
          '.',
          ';',
          '=',
        ];
        break;
      case CalculatorMode.electrician:
        btns = [
          'OHM_V',
          'OHM_I',
          'OHM_R',
          'C',
          ';',
          '7',
          '8',
          '9',
          '/',
          '4',
          '5',
          '6',
          '*',
          '1',
          '2',
          '3',
          '-',
          '0',
          '.',
          'DEL',
          '+',
          'ANS',
          '=',
        ];
        break;
      case CalculatorMode.unitConversion:
        btns = [
          'C',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '0',
          '.',
          'DEL',
          '=',
        ];
        break;
    }

    List<List<String>> rows = [];
    for (var i = 0; i < btns.length; i += 4) {
      rows.add(btns.sublist(i, i + 4 > btns.length ? btns.length : i + 4));
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: rows.map((row) {
          return Expanded(
            child: Row(
              children: row.map((b) {
                Color? color;
                if (['/', '*', '-', '+'].contains(b)) {
                  color = Colors.blue;
                } else if (b == 'C') {
                  color = Colors.orange;
                } else if (b == 'DEL') {
                  color = Colors.redAccent;
                } else if (b == '=') {
                  color = Colors.green;
                } else if (['M+', 'MC', 'MR', 'STATS', 'SETS'].contains(b)) {
                  color = Colors.deepPurple;
                } else if (_electricianCalculationFromButton(b) != null) {
                  color = _isSelectedElectricianButton(b)
                      ? Colors.green
                      : Colors.teal;
                } else if (b == ';') {
                  color = Colors.deepPurple;
                }
                return buildButton(
                  b,
                  color: color,
                  semanticLabel: _getElectricianButtonSemanticLabel(b),
                  onPressed: () {
                    if (b == 'M+' && _currentMode == CalculatorMode.statistics) {
                      _addSingleValueToStats();
                    } else {
                      _handleButtonPressed(b);
                    }
                  },
                  onLongPressed: (b == 'M+' && _currentMode == CalculatorMode.statistics)
                      ? _handleMultipleStatisticsAddition
                      : null,
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: CalculatorMode.values.map((mode) {
            String label = _getModeName(mode);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(label),
                selected: _currentMode == mode,
                onSelected: (s) {
                  if (s) {
                    _changeMode(mode);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAdvancedFunctionsDialog() {
    showDialog(
      context: context,
      builder: (context) => _AdvancedFunctionsDialog(parent: this),
    );
  }

  void _insertFromHistory(String value) {
    _insertAtCursor(value.replaceAll(',', '.'));
    speak('Vloženo ${value.replaceAll('.', ',')}');
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mainFocusNode.requestFocus();
    });
  }

  void _removeStatsRecord(int index, StateSetter setStateDialog, BuildContext dialogContext) {
    setState(() {
      _statsSets[_currentStatsSetIndex].records.removeAt(index);
      if (_selectedFieldIndex >= _currentFieldCount) {
        _selectedFieldIndex = 0;
      }
    });
    _saveStatsData();
    setStateDialog(() {});
    speak(_s(
      'Odebrán záznam ${index + 1}',
      'Removed record ${index + 1}',
    ));
    if (mounted) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text(_s(
          'Odebrán záznam ${index + 1}',
          'Removed record ${index + 1}',
        ))),
      );
    }
    if (_statsMemory.isEmpty) {
      speak(_l10n.statsMemoryEmpty);
      if (mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(content: Text(_l10n.statsMemoryEmpty)),
        );
      }
      Navigator.pop(dialogContext);
    }
  }

  void _showEditStatsRecordDialog(int recordIndex, BuildContext dialogContext, StateSetter setStateDialog) {
    final record = _statsMemory[recordIndex];
    final fieldNames = _statsSets[_currentStatsSetIndex].fieldNames;
    final controllers = record.values
        .map((v) => TextEditingController(text: _formatNumber(v).replaceAll(',', '.')))
        .toList();

    showDialog<void>(
      context: dialogContext,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_s('Upravit záznam ${recordIndex + 1}', 'Edit record ${recordIndex + 1}')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(fieldNames.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: controllers[i],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: '${fieldNames[i]} (${_s("Pole ${i + 1}", "Field ${i + 1}")})',
                      isDense: true,
                    ),
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final newValues = <double>[];
                bool valid = true;
                for (int i = 0; i < controllers.length; i++) {
                  final text = controllers[i].text.trim().replaceAll(',', '.');
                  final val = double.tryParse(text);
                  if (val != null) {
                    newValues.add(val);
                  } else {
                    valid = false;
                    break;
                  }
                }
                if (valid) {
                  setState(() {
                    _statsSets[_currentStatsSetIndex].records[recordIndex] =
                        StatisticsRecord(values: newValues);
                  });
                  _saveStatsData();
                  setStateDialog(() {});
                  Navigator.pop(ctx);
                  speak(_s(
                    'Záznam ${recordIndex + 1} upraven',
                    'Record ${recordIndex + 1} edited',
                  ));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_s(
                        'Záznam ${recordIndex + 1} upraven',
                        'Record ${recordIndex + 1} edited',
                      ))),
                    );
                  }
                } else {
                  speak(_s('Neplatná hodnota', 'Invalid value'));
                }
              },
              child: Text(_l10n.confirmAction),
            ),
          ],
        );
      },
    );
  }

  void _showStatisticsMemoryDialog() {
    final l10n = _l10n;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final currentSetName = _statsSets[_currentStatsSetIndex].name;
            final fieldNames = _statsSets[_currentStatsSetIndex].fieldNames;
            final totalCount = _statsMemory.length;
            final totalCountForm = _getStatsCountForm(totalCount);
            final records = List<StatisticsRecord>.from(_statsMemory);

            String spokenSummary;
            if (records.isEmpty) {
              spokenSummary = _s(
                'Statistická paměť sady $currentSetName je prázdná.',
                'Statistics memory for set $currentSetName is empty.',
              );
            } else {
              final fieldsSummary = fieldNames.asMap().entries.map((fe) {
                final vals = records.map((r) => _formatSpokenNumber(r.values[fe.key])).join('; ');
                return '${fe.value}: $vals';
              }).join('. ');
              spokenSummary = _s(
                'Statistická paměť, sada $currentSetName. Obsahuje $totalCount $totalCountForm. '
                'Pole: $fieldsSummary.',
                'Statistics memory, set $currentSetName. Contains $totalCount $totalCountForm. '
                'Fields: $fieldsSummary.',
              );
            }

            return AlertDialog(
              title: Semantics(
                header: true,
                child: Text(l10n.statsMemoryTitle),
              ),
              content: Focus(
                autofocus: true,
                onFocusChange: (hasFocus) {
                  if (hasFocus && !_isScreenReaderActive) speak(spokenSummary);
                },
                child: SizedBox(
                  width: double.maxFinite,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: l10n.statsCurrentSetLabel(currentSetName),
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  l10n.statsCurrentSetLabel(currentSetName),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 8),
                          ExcludeSemantics(
                            child: Text(
                              _s('Záznamů: $totalCount, Polí: ${fieldNames.length}', 'Records: $totalCount, Fields: ${fieldNames.length}'),
                            ),
                          ),
                          if (records.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              header: true,
                              label: _s('Sloupce: číslo, ${fieldNames.join(', ')}', 'Columns: number, ${fieldNames.join(', ')}'),
                              child: ExcludeSemantics(
                                child: DefaultTextStyle.merge(
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  child: _buildMemoryHeaderRow(fieldNames),
                                ),
                              ),
                            ),
                            const Divider(height: 16),
                            ...records.asMap().entries.map((entry) {
                              final index = entry.key;
                              final record = entry.value;
                              final spokenValues = record.values
                                  .asMap()
                                  .entries
                                  .map((ve) => '${fieldNames[ve.key]}: ${_formatSpokenNumber(ve.value)}')
                                  .join(', ');

                              final rowLabel = _s(
                                'Záznam ${index + 1}: $spokenValues',
                                'Record ${index + 1}: $spokenValues',
                              );
                              return Semantics(
                                container: true,
                                label: rowLabel,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      ExcludeSemantics(
                                        child: SizedBox(
                                          width: 28,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      ...record.values.asMap().entries.map((ve) {
                                        return Expanded(
                                          child: ExcludeSemantics(
                                            child: Text(
                                              _formatNumber(ve.value),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        );
                                      }),
                                      Semantics(
                                        label: rowLabel,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                              tooltip: _s(
                                                'Upravit záznam ${index + 1}',
                                                'Edit record ${index + 1}',
                                              ),
                                              onPressed: () => _showEditStatsRecordDialog(index, dialogContext, setStateDialog),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                              tooltip: _s(
                                                'Smazat záznam ${index + 1}',
                                                'Delete record ${index + 1}',
                                              ),
                                              onPressed: () => _removeStatsRecord(index, setStateDialog, dialogContext),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showStatsSetsDialog();
                  },
                  child: Text(l10n.statsSetsManage),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocusNode.requestFocus();
      });
    });
  }

  Widget _buildMemoryHeaderRow(List<String> fieldNames) {
    return Row(
      children: [
        const SizedBox(
          width: 28,
          child: Text('#', style: TextStyle(fontSize: 12)),
        ),
        ...fieldNames.map((name) => Expanded(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            )),
        SizedBox(
          width: 72,
          child: Text(
            _s('Akce', 'Actions'),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _showStatisticsSummaryDialog() {
    final l10n = _l10n;
    final fieldNames = _statsSets.isNotEmpty
        ? _statsSets[_currentStatsSetIndex].fieldNames
        : <String>['Hodnota'];

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        int localFieldIndex = _selectedFieldIndex;

        return StatefulBuilder(
          builder: (context, setSummaryState) {
            final snapshot = _computeStatisticsSnapshot(localFieldIndex);
            if (snapshot == null) {
              speak(l10n.statsMemoryEmpty);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.statsMemoryEmpty)),
                );
              }
              Navigator.pop(dialogContext);
              return const SizedBox.shrink();
            }
            final currentSetName = _statsSets[_currentStatsSetIndex].name;
            final selectedFieldName = fieldNames[localFieldIndex];
            final allValues = _getFieldValues(localFieldIndex)
                .map((v) => _formatNumber(v))
                .join(_isEnglish() ? ', ' : '; ');
            final allValuesSpoken = _getFieldValues(localFieldIndex)
                .map((v) => _formatSpokenNumber(v))
                .join(_isEnglish() ? ', ' : '; ');

            final modeText = snapshot.modeExists
                ? snapshot.modes.map((m) => _formatNumber(m)).join('; ')
                : l10n.statsModeNone;
            final modeSpoken = snapshot.modeExists
                ? snapshot.modes.map((m) => _formatSpokenNumber(m)).join(_s(' a ', ' and '))
                : l10n.statsModeNone;

            final cvText = snapshot.cv == null
                ? 'Err'
                : '${_formatNumber(snapshot.cv!)} %';
            final cvSpoken = snapshot.cv == null
                ? _s('nelze vypočítat', 'cannot calculate')
                : '${_formatSpokenNumber(snapshot.cv!)} ${_s('procent', 'percent')}';

            final statRows = <MapEntry<String, String>>[
              MapEntry(l10n.statsMean, _formatNumber(snapshot.mean)),
              MapEntry(l10n.statsSum, _formatNumber(snapshot.sum)),
              MapEntry(l10n.statsVariance, _formatNumber(snapshot.variance)),
              MapEntry(l10n.statsStdDev, _formatNumber(snapshot.sd)),
              MapEntry(l10n.statsMedian, _formatNumber(snapshot.median)),
              MapEntry(l10n.statsMode, modeText),
              MapEntry(l10n.statsCv, cvText),
            ];

            final spokenSummary = _s(
              'Statistický souhrn pro sadu $currentSetName, pole $selectedFieldName. '
              'Všechny hodnoty: $allValuesSpoken. '
              'Průměr: ${_formatSpokenNumber(snapshot.mean)}. '
              'Součet: ${_formatSpokenNumber(snapshot.sum)}. '
              'Rozptyl: ${_formatSpokenNumber(snapshot.variance)}. '
              'Směrodatná odchylka: ${_formatSpokenNumber(snapshot.sd)}. '
              'Medián: ${_formatSpokenNumber(snapshot.median)}. '
              'Modus: $modeSpoken. '
              'Variační koeficient: $cvSpoken.',
              'Statistics summary for set $currentSetName, field $selectedFieldName. '
              'All values: $allValuesSpoken. '
              'Mean: ${_formatSpokenNumber(snapshot.mean)}. '
              'Sum: ${_formatSpokenNumber(snapshot.sum)}. '
              'Variance: ${_formatSpokenNumber(snapshot.variance)}. '
              'Standard deviation: ${_formatSpokenNumber(snapshot.sd)}. '
              'Median: ${_formatSpokenNumber(snapshot.median)}. '
              'Mode: $modeSpoken. '
              'Coefficient of variation: $cvSpoken.',
            );

            return AlertDialog(
              title: Semantics(
                header: true,
                child: Text(l10n.statsSummaryTitle),
              ),
              content: Focus(
                autofocus: true,
                onFocusChange: (hasFocus) {
                  if (hasFocus && !_isScreenReaderActive) speak(spokenSummary);
                },
                child: SizedBox(
                  width: double.maxFinite,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: l10n.statsCurrentSetLabel(currentSetName),
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  l10n.statsCurrentSetLabel(currentSetName),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          if (fieldNames.length > 1) ...[
                            const SizedBox(height: 4),
                            Semantics(
                              label: _s(
                                'Pole: ${fieldNames[localFieldIndex]}',
                                'Field: ${fieldNames[localFieldIndex]}',
                              ),
                              child: Row(
                                children: [
                                  ExcludeSemantics(
                                    child: Text(_s('Pole: ', 'Field: ')),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<int>(
                                      value: localFieldIndex,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: List.generate(fieldNames.length, (i) {
                                        return DropdownMenuItem(
                                          value: i,
                                          child: Text(fieldNames[i]),
                                        );
                                      }),
                                      onChanged: (val) {
                                        if (val != null) {
                                          localFieldIndex = val;
                                          setSummaryState(() {});
                                          speak(_s(
                                            'Vybráno pole ${fieldNames[val]}',
                                            'Selected field ${fieldNames[val]}',
                                          ));
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Divider(height: 8),
                          Semantics(
                            header: true,
                            label: l10n.statsAllValuesSection,
                            child: ExcludeSemantics(
                              child: Text(
                                l10n.statsAllValuesSection,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Semantics(
                            label: _s(
                              'Všechny hodnoty pole $selectedFieldName: $allValuesSpoken',
                              'All values of field $selectedFieldName: $allValuesSpoken',
                            ),
                            child: ExcludeSemantics(child: Text(allValues)),
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            header: true,
                            label: l10n.statsComputedSection,
                            child: ExcludeSemantics(
                              child: Text(
                                l10n.statsComputedSection,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...statRows.map((row) {
                            final spokenValue = row.value.replaceAll('.', ',');
                            return Semantics(
                              container: true,
                              label: '${row.key}: $spokenValue',
                              child: ExcludeSemantics(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(row.key),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          row.value,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showStatsSetsDialog();
                  },
                  child: Text(l10n.statsSetsManage),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocusNode.requestFocus();
      });
    });
  }

  void _showStatsSetsDialog() {
    final l10n = _l10n;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Semantics(
                header: true,
                child: Text(l10n.statsSetsTitle),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _statsSets.length,
                          itemBuilder: (ctx, index) {
                            final set = _statsSets[index];
                            final isCurrent = index == _currentStatsSetIndex;
                            final count = set.records.length;
                            final countForm = _getStatsCountForm(count);
                            final titleText = '${set.name} ($count $countForm)';

                            final semanticsLabel = isCurrent
                                ? '${set.name}, $count $countForm, vybráno jako aktivní sada.'
                                : '${set.name}, $count $countForm. Poklepáním vyberete jako aktivní sadu.';

                            return Semantics(
                              container: true,
                              label: semanticsLabel,
                              child: ListTile(
                                selected: isCurrent,
                                selectedTileColor: Colors.blue.withOpacity(0.1),
                                title: ExcludeSemantics(
                                  child: Text(
                                    titleText,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: l10n.statsSetsRename,
                                      onPressed: () {
                                        _showRenameStatsSetDialog(context, index, () {
                                          setStateDialog(() {});
                                          setState(() {});
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: l10n.statsSetsDelete,
                                      onPressed: () {
                                              setStateDialog(() {
                                                _deleteStatsSet(index);
                                              });
                                              setState(() {});
                                            },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setStateDialog(() {
                                    _currentStatsSetIndex = index;
                                  });
                                  setState(() {});
                                  final announcement = l10n.statsSetSelectedAnnouncement(
                                    set.name,
                                    count,
                                    _getStatsCountForm(count),
                                  );
                                  speak(announcement);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l10n.statsSetsCreate),
                        onPressed: () {
                          _showCreateStatsSetDialog(context, () {
                            setStateDialog(() {});
                            setState(() {});
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocusNode.requestFocus();
      });
    });
  }

  void _showRenameStatsSetDialog(BuildContext context, int index, VoidCallback onUpdated) {
    final l10n = _l10n;
    final controller = TextEditingController(text: _statsSets[index].name);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.statsSetsRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.statsSetNameLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    _statsSets[index].name = newName;
                  });
                  _saveStatsData();
                  onUpdated();
                  Navigator.pop(ctx);
                  speak(l10n.statsSetRenamedAnnouncement(newName));
                }
              },
              child: Text(l10n.confirmAction),
            ),
          ],
        );
      },
    );
  }

  void _showCreateStatsSetDialog(BuildContext context, VoidCallback onUpdated, {List<StatisticsRecord>? recordsToRepeat}) {
    final l10n = _l10n;
    final defaultName = l10n.statsSetDefaultName(_statsSets.length + 1);
    final controller = TextEditingController(text: defaultName);
    final fieldControllers = <TextEditingController>[TextEditingController(text: 'Hodnota')];

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.statsSetsCreate),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.statsSetNameLabel,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_s('Názvy polí:', 'Field names:'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...List.generate(fieldControllers.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fieldControllers[i],
                                decoration: InputDecoration(
                                  labelText: '${_s("Pole", "Field")} ${i + 1}',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                            if (fieldControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                tooltip: _s('Odebrat pole ${i + 1}', 'Remove field ${i + 1}'),
                                onPressed: () {
                                  setDialogState(() {
                                    fieldControllers[i].dispose();
                                    fieldControllers.removeAt(i);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(_s('Přidat pole', 'Add field')),
                      onPressed: () {
                        setDialogState(() {
                          fieldControllers.add(TextEditingController(
                              text: _s('Pole ${fieldControllers.length + 1}', 'Field ${fieldControllers.length + 1}')));
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      final fieldNames = fieldControllers
                          .map((c) => c.text.trim())
                          .where((n) => n.isNotEmpty)
                          .toList();
                      if (fieldNames.isEmpty) fieldNames.add('Hodnota');
                      setState(() {
                        _statsSets.add(StatisticsSet(
                          name: newName,
                          fieldNames: fieldNames,
                          records: [],
                        ));
                        _currentStatsSetIndex = _statsSets.length - 1;
                        _selectedFieldIndex = 0;
                      });
                      _saveStatsData();
                      onUpdated();
                      Navigator.pop(ctx);
                      
                      if (recordsToRepeat != null) {
                        speak(_s(
                          'Sada $newName vytvořena. Nyní můžete zadat počet opakování pro vložení hodnot.',
                          'Set $newName created. You can now enter the number of repetitions to insert the values.',
                        ));
                        _showRepeatDialog(recordsToRepeat);
                      } else {
                        speak(l10n.statsSetCreatedAnnouncement(newName));
                      }
                    }
                  },
                  child: Text(l10n.confirmAction),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteStatsSet(int index) {
    final l10n = _l10n;

    final deletedName = _statsSets[index].name;
    _statsSets.removeAt(index);
    _saveStatsData();

    if (_statsSets.isEmpty) {
      _currentStatsSetIndex = 0;
      speak(_s(
        'Sada $deletedName byla smazána. Nejsou vytvořeny žádné sady.',
        'Set $deletedName was deleted. No sets created.',
      ));
      return;
    }

    if (_currentStatsSetIndex >= _statsSets.length) {
      _currentStatsSetIndex = _statsSets.length - 1;
    } else if (_currentStatsSetIndex == index) {
      if (_currentStatsSetIndex >= _statsSets.length) {
        _currentStatsSetIndex = _statsSets.length - 1;
      }
    } else if (_currentStatsSetIndex > index) {
      _currentStatsSetIndex--;
    }

    final activeSetName = _statsSets[_currentStatsSetIndex].name;
    speak(l10n.statsSetDeletedAnnouncement(deletedName, activeSetName));
  }

  Widget _applyDialogSize(Widget child) {
    switch (_dialogSize) {
      case DialogSize.compact:
        return child;
      case DialogSize.wide:
        return SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: child,
          ),
        );
      case DialogSize.fullscreen:
        return SizedBox.expand(child: child);
    }
  }

  void _showNumberInfoDialog() {
    final l10n = _l10n;
    final value = _lastNumericValue;
    if (value == null) {
      speak(l10n.infoNoResult);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.infoNoResult)),
        );
      }
      return;
    }

    bool isInteger = value == value.roundToDouble() && value.isFinite;
    bool isPosInt = isInteger && value > 0;
    int intVal = value.round();

    String fraction = _decimalToFraction(value);
    String fractionSpoken = fraction
        .replaceAll('/', _s(' lomeno ', ' over '))
        .replaceAll('.', ',');

    String dmsStr = _formatAsDMS(value);
    String dmsSpoken = dmsStr
        .replaceAll('°', _s(' stupňů ', ' degrees '))
        .replaceAll('\'', _s(' minut ', ' minutes '))
        .replaceAll('"', _s(' sekund', ' seconds'))
        .replaceAll('.', ',');

    String percent = '${_formatNumber(value * 100)} %';
    String percentSpoken = '${_formatSpokenNumber(value * 100)} '
        '${_s('procent', 'percent')}';

    String factorsStr = '';
    String factorsSpoken = '';
    if (isPosInt && intVal >= 2) {
      List<int> factors = _primeFactors(intVal);
      factorsStr = factors.join(' × ');
      factorsSpoken = factors.join(_s(' krát ', ' times '));
    }

    String divisorsStr = '';
    String divisorsSpoken = '';
    if (isPosInt) {
      List<int> divs = _getDivisors(intVal);
      divisorsStr = divs.join(', ');
      divisorsSpoken = divs.join(', ');
    }

    String formattedValue = _formatNumber(value);
    String spokenValue = _formatSpokenNumber(value);

    final spokenText = _s(
      'Info o čísle. Hodnota: $spokenValue. '
      'Zlomek: $fractionSpoken. '
      'DMS: $dmsSpoken. '
      'Procenta: $percentSpoken. '
      '${factorsSpoken.isNotEmpty ? 'Rozklad na prvočísla: $factorsSpoken. ' : ''}'
      '${divisorsSpoken.isNotEmpty ? 'Dělitele: $divisorsSpoken.' : ''}',
      'Number info. Value: $spokenValue. '
      'Fraction: $fractionSpoken. '
      'DMS: $dmsSpoken. '
      'Percentage: $percentSpoken. '
      '${factorsSpoken.isNotEmpty ? 'Prime factors: $factorsSpoken. ' : ''}'
      '${divisorsSpoken.isNotEmpty ? 'Divisors: $divisorsSpoken.' : ''}',
    );

    String notIntMsg = l10n.infoNotInteger;
    String naMsg = l10n.infoNotApplicable;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        DialogSize currentSize = _dialogSize;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool isInfoFullscreen = currentSize == DialogSize.fullscreen;
            return AlertDialog(
              title: Semantics(
                header: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.numberInfo),
                    ),
                    Semantics(
                      label: isInfoFullscreen
                          ? _s('Zmenšit dialog', 'Minimize dialog')
                          : _s('Zvětšit dialog', 'Maximize dialog'),
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          isInfoFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                        ),
                        tooltip: isInfoFullscreen
                            ? _s('Zmenšit', 'Minimize')
                            : _s('Zvětšit', 'Maximize'),
                        onPressed: () {
                          setDialogState(() {
                            currentSize = isInfoFullscreen
                                ? DialogSize.wide
                                : DialogSize.fullscreen;
                          });
                          speak(
                            isInfoFullscreen
                                ? _s('Dialog zmenšen', 'Dialog minimized')
                                : _s('Dialog zvětšen', 'Dialog maximized'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              content: Focus(
                autofocus: true,
                onFocusChange: (hasFocus) {
                  if (hasFocus && !_isScreenReaderActive) {
                    speak(spokenText);
                  }
                },
                child: _applyDialogSize(
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInfoCard(
                          label: l10n.infoValue,
                          value: formattedValue,
                          spoken: '${l10n.infoValue}: $spokenValue',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          label: l10n.infoFraction,
                          value: fraction,
                          spoken: '${l10n.infoFraction}: $fractionSpoken',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          label: l10n.infoDms,
                          value: dmsStr,
                          spoken: '${l10n.infoDms}: $dmsSpoken',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          label: l10n.infoPercentage,
                          value: percent,
                          spoken: '${l10n.infoPercentage}: $percentSpoken',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          label: l10n.infoPrimeFactors,
                          value: factorsStr.isNotEmpty ? factorsStr : naMsg,
                          spoken: factorsSpoken.isNotEmpty
                              ? '${l10n.infoPrimeFactors}: $factorsSpoken'
                              : '${l10n.infoPrimeFactors}: $notIntMsg',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          label: l10n.infoDivisors,
                          value: divisorsStr.isNotEmpty ? divisorsStr : naMsg,
                          spoken: divisorsSpoken.isNotEmpty
                              ? '${l10n.infoDivisors}: $divisorsSpoken'
                              : '${l10n.infoDivisors}: $notIntMsg',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                Semantics(
                  label: _s('Přečíst všechny informace hlasem',
                      'Read all information aloud'),
                  button: true,
                  child: TextButton(
                    onPressed: () => speak(spokenText),
                    child: Text(l10n.infoRead),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocusNode.requestFocus();
      });
    });
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required String spoken,
  }) {
    return Semantics(
      container: true,
      label: spoken,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: ExcludeSemantics(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: const Text('Historie výpočtů')),
        content: _applyDialogSize(
          _history.isEmpty
              ? Semantics(
                  container: true,
                  child: const Text('Historie je prázdná.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    String item = _history[index];
                    String expression = item;
                    String result = "";

                    if (item.contains('|')) {
                      List<String> parts = item.split('|');
                      expression = parts[0];
                      result = parts[1];
                    } else if (item.contains('=')) {
                      // Zpětná kompatibilita pro starý formát "exp = res"
                      int eqIdx = item.lastIndexOf('=');
                      expression = item.substring(0, eqIdx).trim();
                      result = item.substring(eqIdx + 1).trim();
                    }

                    String semanticDescription =
                        "Výpočet: $expression, výsledek: $result. Poklepáním vložíte výsledek, přidržením vložíte celý výpočet.";

                    return Semantics(
                      label: semanticDescription,
                      container: true,
                      child: MergeSemantics(
                        child: ListTile(
                          title: Text(
                            expression,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: result.isNotEmpty
                              ? Text(
                                  result,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.blue,
                                  ),
                                )
                              : null,
                          onTap: () => _insertFromHistory(
                            result.isNotEmpty ? result : expression,
                          ),
                          onLongPress: () => _insertFromHistory(expression),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showClearHistoryConfirmation();
            },
            child: const Text('VYMAZAT HISTORII'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _mainFocusNode.requestFocus();
              });
            },
            child: const Text('ZAVŘÍT'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryConfirmation() {
    String question = 'Opravdu chcete smazat celou historii výpočtů?';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text('Potvrzení')),
        content: Focus(
          autofocus: true,
          onFocusChange: (hasFocus) {
            if (hasFocus) speak(question);
          },
          child: Semantics(
            container: true,
            label: 'Otázka',
            child: Text(question),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _history.clear();
                _saveHistory();
              });
              speak('Historie smazána');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historie smazána')),
                );
              }
              Navigator.pop(context);
            },
            child: Semantics(
              label: 'Ano, potvrdit smazání celé historie výpočtů',
              child: Text('ANO, SMAZAT'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Semantics(
              label: 'Ne, zrušit smazání a ponechat historii',
              child: Text('NE, ZŮSTAT'),
            ),
          ),
        ],
      ),
    );
    speak(question);
  }

  void _addValuesToStats(List<StatisticsRecord> records, int count) {
    setState(() {
      for (int i = 0; i < count; i++) {
        _statsMemory.addAll(records.map((r) => r.copyWith()));
      }
      _lastAddedBatch =
          records.map((r) => StatisticsRecord(values: List.from(r.values))).toList();
      display = '';
      _cursorPosition = 0;
    });
    _saveStatsData();

    final setName = _statsSets[_currentStatsSetIndex].name;
    final int totalAdded = records.length * count;
    final int fieldCount = _currentFieldCount;
    String spoken;

    if (totalAdded > 3 || fieldCount > 1) {
      spoken = _s(
        'Přidáno $totalAdded záznamů do sady $setName. V paměti je celkem ${_statsMemory.length} ${_getStatsCountForm(_statsMemory.length)}.',
        'Added $totalAdded records to set $setName. Memory now contains ${_statsMemory.length} ${_getStatsCountForm(_statsMemory.length)}.',
      );
    } else {
      String valuesStr = records
          .map((r) => r.values
              .map((v) => _formatNumber(v).replaceAll('.', ','))
              .join(';'))
          .join(' ');
      String countForm = _getStatsCountForm(_statsMemory.length);

      String countPartCs = count == 1 ? '' : ', $count krát';
      String countPartEn = count == 1 ? '' : ', $count times';

      spoken = _s(
        'Přidáno $valuesStr$countPartCs do sady $setName. V paměti je celkem ${_statsMemory.length} $countForm.',
        'Added $valuesStr$countPartEn to set $setName. Memory now contains ${_statsMemory.length} $countForm.',
      );
    }
    speak(spoken);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(spoken)),
      );
    }
  }

  void _showRepeatDialog(List<StatisticsRecord> records) {
    final l10n = _l10n;
    TextEditingController controller = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text(l10n.statsRepeatTitle)),
        content: Semantics(
          label: l10n.statsRepeatHint,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.statsRepeatLabel),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              int count = int.tryParse(controller.text) ?? 1;
              _addValuesToStats(records, count);
              Navigator.pop(context);
            },
            child: Text(l10n.confirmAction),
          ),
        ],
      ),
    );
  }

  void _handleMultipleStatisticsAddition() {
    if (!_hasStatsSet) {
      speak(_s(
        'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
        'No statistics set created. Enter a name for a new set first.',
      ));
      
      List<StatisticsRecord>? recordsToRepeat;
      if (display.isNotEmpty) {
        try {
          recordsToRepeat = _parseDisplayToRecords(display);
        } catch (_) {}
      }
      
      _showCreateStatsSetDialog(context, () {
        _handleMultipleStatisticsAddition();
      }, recordsToRepeat: recordsToRepeat);
      return;
    }
    if (display.isEmpty) {
      speak(_s(
        'Displej je prázdný. Zadejte číslo k uložení.',
        'Display is empty. Enter a number to store.',
      ));
      return;
    }
    try {
      final recordsToAdd = _parseDisplayToRecords(display);

      if (recordsToAdd.isEmpty) {
        speak(_s(
          'Žádná platná čísla k uložení.',
          'No valid numbers to store.',
        ));
        return;
      }

      _showRepeatDialog(recordsToAdd);
    } catch (e) {
      speak(_s(
        'Chyba při ukládání do statistické paměti. Zkontrolujte formát dat.',
        'Error storing to statistics memory. Check the data format.',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateTtsLanguage();
    final l10n = _l10n;

    return KeyboardListener(
      focusNode: _mainFocusNode,
      onKeyEvent: _handleKeyboardInput,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: l10n.history,
              onPressed: _showHistoryDialog,
            ),
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: l10n.advancedFunctions,
              onPressed: _showAdvancedFunctionsDialog,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: l10n.helpTooltip,
              onPressed: _showTutorialDialog,
            ),
            IconButton(
              icon: Icon(ttsEnabled ? Icons.volume_up : Icons.volume_off),
              tooltip: ttsEnabled ? l10n.muteVoice : l10n.unmuteVoice,
              onPressed: _toggleTts,
            ),
            IconButton(
              icon: const Icon(Icons.update),
              tooltip: 'Zkontrolovat aktualizace',
              onPressed: () async {
                final checker = GitHubReleaseChecker();
                final release = await checker.checkForUpdates(
                  owner: 'Johny45-open',
                  repo: 'Mluvici_kalkulacka',
                  currentVersion: _currentAppVersion,
                );
                if (mounted) {
                  if (release != null) {
                    _showUpdateDialog(release);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aplikace je aktuální.')),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: l10n.numberInfo,
              onPressed: _showNumberInfoDialog,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: l10n.accessibility,
              onPressed: _showAccessibilityDialog,
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Výpočet dostupného prostoru
              final double totalHeight = constraints.maxHeight;

              // Rozdělení zbývajícího prostoru mezi displej a klávesnici
              // Na malých displejích dáme klávesnici víc prostoru
              final double displayFlex = (totalHeight < 600) ? 1.0 : 1.5;
              final double keyboardFlex = 3.0;

              return Column(
                children: [
                  // Displej
                  Expanded(
                    flex: (displayFlex * 100).toInt(),
                    child: GestureDetector(
                      onScaleUpdate: (ScaleUpdateDetails details) {
                        if (details.scale != 1.0) {
                          setState(() {
                            _dotMatrixZoom = (_dotMatrixZoom * details.scale)
                                .clamp(0.5, 5.0);
                            _resultZoom = (_resultZoom * details.scale).clamp(
                              0.5,
                              5.0,
                            );
                          });
                          _saveSettings();
                        }
                      },
                      onDoubleTap: () {
                        setState(() {
                          _dotMatrixZoom = 1.0;
                          _resultZoom = 1.0;
                        });
                        _saveSettings();
                      },
                      onTap: () => _mainFocusNode.requestFocus(),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: Semantics(
                          liveRegion: true,
                          label: l10n.displayLabel,
                          hint: l10n.displayHint,
                          value: display.isEmpty
                              ? l10n.displayEmpty
                              : display.replaceAll('.', ','),
                          // Pokud běží TalkBack, vnitřní prvky sémantiku nepotřebují, přečte je tento Semantics widget
                          explicitChildNodes: !_isScreenReaderActive,
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  _getModeName(_currentMode).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    controller: _scrollControllerH,
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      controller: _scrollControllerV,
                                      scrollDirection: Axis.vertical,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          _buildDotMatrixDisplay(),
                                          const SizedBox(height: 12),
                                          _buildMainResultDisplay(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Přepínač režimů
                  _buildModeSelector(),
                  // Klávesnice
                  Expanded(
                    flex: (keyboardFlex * 100).toInt(),
                    child: _buildMainKeyboard(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdvancedFunctionsDialog extends StatelessWidget {
  final _CalculatorScreenState parent;
  const _AdvancedFunctionsDialog({required this.parent});

  List<Widget> _buildSections(BuildContext ctx) {
    List<Widget> sections = [];
    if (parent._currentMode == CalculatorMode.statistics) {
      sections.add(
        _CollapsibleSection(
          title: parent._l10n.modeStatistics,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (parent._hasStatsSet)
                    Semantics(
                      label: parent._l10n.statsCurrentSetLabel(parent._statsSets[parent._currentStatsSetIndex].name),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        color: Colors.blue.withOpacity(0.1),
                        child: Column(
                          children: [
                            Text(
                              parent._l10n.statsCurrentSetLabel(parent._statsSets[parent._currentStatsSetIndex].name) +
                                  ' (${parent._statsMemory.length} ${parent._getStatsCountForm(parent._statsMemory.length)})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            if (parent._currentFieldCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Semantics(
                                  label: parent._s(
                                    'Pole: ${parent._statsSets[parent._currentStatsSetIndex].fieldNames[parent._selectedFieldIndex]}',
                                    'Field: ${parent._statsSets[parent._currentStatsSetIndex].fieldNames[parent._selectedFieldIndex]}',
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ExcludeSemantics(
                                        child: Text(parent._s('Pole: ', 'Field: '), style: const TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(width: 4),
                                      DropdownButton<int>(
                                        value: parent._selectedFieldIndex,
                                        underline: const SizedBox(),
                                        isDense: true,
                                        style: const TextStyle(fontSize: 12, color: Colors.black),
                                        items: List.generate(parent._currentFieldCount, (i) {
                                          return DropdownMenuItem(
                                            value: i,
                                            child: Text(parent._statsSets[parent._currentStatsSetIndex].fieldNames[i]),
                                          );
                                        }),
                                        onChanged: (val) {
                                          if (val != null) {
                                            parent.setState(() => parent._selectedFieldIndex = val);
                                            parent.speak(parent._s(
                                              'Vybráno pole ${parent._statsSets[parent._currentStatsSetIndex].fieldNames[val]}',
                                              'Selected field ${parent._statsSets[parent._currentStatsSetIndex].fieldNames[val]}',
                                            ));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Focus(
                      autofocus: true,
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          parent.speak(parent._s(
                            'Není vytvořena žádná sada. Vytvořte novou sadu tlačítkem SETS na hlavní klávesnici.',
                            'No set created. Create a new set using the SETS button on the main keyboard.',
                          ));
                        }
                      },
                      child: Semantics(
                        container: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            parent._s(
                              'Není vytvořena žádná sada. Vytvořte novou sadu tlačítkem SETS na hlavní klávesnici.',
                              'No set created. Create a new set using the SETS button on the main keyboard.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      'MEAN', 'SD', 'VAR', 'SUM',
                      'MED', 'MODE', 'CV', 'WMEAN'
                    ].map((b) {
                      return SizedBox(
                        width: (MediaQuery.of(ctx).size.width - 80) / 4,
                        height: 50,
                        child: parent.buildButton(
                          b,
                          onPressed: () {
                            parent._handleButtonPressed(b);
                          },
                          expanded: false,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (parent._lastAddedBatch.isEmpty) {
                      parent.speak(parent._s('Žádná data v poslední dávce.', 'No data in the last batch.'), force: true);
                    } else {
                      String valuesStr = parent._lastAddedBatch
                          .map((r) => r.values
                              .map((v) => parent._formatNumber(v).replaceAll('.', ','))
                              .join(';'))
                          .join(' ');
                      parent.speak(parent._s(
                        'Poslední vložená data: $valuesStr',
                        'Last added data: $valuesStr',
                      ), force: true);
                    }
                    },
                    child: Text(parent._s('Přečíst naposledy vložená data', 'Read last added data')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (parent._currentMode == CalculatorMode.unitConversion) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: parent._selectedUnitCategory,
                    decoration: const InputDecoration(labelText: 'Kategorie'),
                    items: parent._unitCategories.keys
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (val) {
                      // ignore: invalid_use_of_protected_member
                      parent.setState(() {
                        parent._selectedUnitCategory = val!;
                        parent._unitFrom =
                            parent._unitCategories[val]!.keys.first;
                        parent._unitTo = parent._unitCategories[val]!.keys
                            .elementAt(1);
                      });
                      parent.speak('Kategorie $val');
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: parent._unitFrom,
                          decoration: const InputDecoration(labelText: 'Z'),
                          items: parent
                              ._unitCategories[parent._selectedUnitCategory]!
                              .keys
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(parent._getUnitSpeech(u)),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            // ignore: invalid_use_of_protected_member
                            parent.setState(() => parent._unitFrom = val!);
                            parent.speak(
                              'Z jednotky ${parent._getUnitSpeech(val!)}',
                            );
                          },
                        ),
                      ),
                      const Icon(Icons.arrow_forward),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: parent._unitTo,
                          decoration: const InputDecoration(labelText: 'Na'),
                          items: parent
                              ._unitCategories[parent._selectedUnitCategory]!
                              .keys
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(parent._getUnitSpeech(u)),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            // ignore: invalid_use_of_protected_member
                            parent.setState(() => parent._unitTo = val!);
                            parent.speak(
                              'Na jednotku ${parent._getUnitSpeech(val!)}',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: parent._convertUnits,
                      icon: const Icon(Icons.sync),
                      label: const Text('PŘEVÉST'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (parent._currentMode != CalculatorMode.statistics) {
      sections.add(
        _CollapsibleSection(
          title: 'Goniometrie',
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN'].map((b) {
                  return SizedBox(
                    width: (MediaQuery.of(ctx).size.width - 80) / 4,
                    height: 50,
                    child: parent.buildButton(b, expanded: false),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    sections.add(
      _CollapsibleSection(
        title: 'Funkce',
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children:
                  [
                    '√',
                    '∛',
                    'ⁿ√',
                    '!',
                    'LOG',
                    'LN',
                    'EXP',
                    'x²',
                    'x³',
                    '^',
                    '\u03C0',
                    'DMS',
                    '°→\'',
                    '\'→°',
                    'ANS',
                    'ABS',
                  ].map((b) {
                    return SizedBox(
                      width: (MediaQuery.of(ctx).size.width - 80) / 4,
                      height: 50,
                      child: parent.buildButton(b, expanded: false),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );

    sections.add(
      _CollapsibleSection(
        title: 'Paměť',
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: ['STO', 'RCL', 'CLR'].map((b) {
                    return SizedBox(
                      width: (MediaQuery.of(ctx).size.width - 80) / 3.2,
                      height: 50,
                      child: parent.buildButton(b, expanded: false),
                    );
                  }).toList(),
                ),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'].map((
                    b,
                  ) {
                    return SizedBox(
                      width: (MediaQuery.of(ctx).size.width - 80) / 4,
                      height: 50,
                      child: parent.buildButton(
                        b,
                        semanticLabel: 'Proměnná $b',
                        onPressed: () => parent._handleMemoryVariable(b),
                        expanded: false,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    sections.add(
      _CollapsibleSection(
        title: 'Zobrazení',
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                SizedBox(
                  width: 80,
                  height: 50,
                  child: parent.buildButton(
                    'NORM',
                    semanticLabel: 'Standardní zobrazení',
                    onPressed: () {
                      // ignore: invalid_use_of_protected_member
                      parent.setState(
                        () => parent._displayFormat = DisplayFormat.standard,
                      );
                      parent.speak('Nastaveno standardní zobrazení');
                      if (parent.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Nastaveno standardní zobrazení')),
                        );
                      }
                    },
                    expanded: false,
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 50,
                  child: parent.buildButton(
                    'FIX',
                    semanticLabel: 'Zobrazení s pevným počtem desetinných míst',
                    onPressed: () =>
                        parent._showPrecisionDialog(DisplayFormat.fix),
                    expanded: false,
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 50,
                  child: parent.buildButton(
                    'SCI',
                    semanticLabel: 'Vědecký zápis',
                    onPressed: () =>
                        parent._showPrecisionDialog(DisplayFormat.sci),
                    expanded: false,
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 50,
                  child: parent.buildButton(
                    'ENG',
                    semanticLabel: 'Inženýrský zápis',
                    onPressed: () =>
                        parent._showPrecisionDialog(DisplayFormat.eng),
                    expanded: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Semantics(header: true, child: const Text('Pokročilé funkce')),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(children: _buildSections(context)),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (parent.mounted) parent._mainFocusNode.requestFocus();
            });
          },
          child: const Text('ZAVŘÍT'),
        ),
      ],
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final List<Widget> children;
  const _CollapsibleSection({required this.title, required this.children});
  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.title,
      child: Column(
        children: [
          Semantics(
            label: _isExpanded ? 'Sbalit ${widget.title}' : 'Rozbalit ${widget.title}',
            child: ListTile(
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          if (_isExpanded) ...widget.children,
        ],
      ),
    );
  }
}

class CustomSegmentDisplay extends StatelessWidget {
  final String value;
  final double size;
  final int characterCount;
  final double characterSpacing;
  final bool isSixteenSegment;
  final Color enabledColor;
  final Color disabledColor;

  const CustomSegmentDisplay({
    super.key,
    required this.value,
    this.size = 24,
    this.characterCount = 16,
    this.characterSpacing = 8,
    this.isSixteenSegment = false,
    this.enabledColor = Colors.redAccent,
    this.disabledColor = const Color(0x0DFF5252),
  });

  @override
  Widget build(BuildContext context) {
    // Rozklad na znaky a informaci o tečce
    List<_SegmentCharData> chars = [];
    int valIdx = 0;
    while (chars.length < characterCount && valIdx < value.length) {
      String char = value[valIdx];
      bool hasDot = false;
      if (valIdx + 1 < value.length && value[valIdx + 1] == '.') {
        hasDot = true;
        valIdx++;
      }
      chars.add(_SegmentCharData(char, hasDot));
      valIdx++;
    }

    // Doplnění mezerami
    while (chars.length < characterCount) {
      chars.add(_SegmentCharData(' ', false));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(characterCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == characterCount - 1 ? 0 : characterSpacing,
          ),
          child: SizedBox(
            width: size * 1.5,
            height: size * 1.8,
            child: CustomPaint(
              painter: isSixteenSegment
                  ? _CustomSixteenSegmentPainter(
                      chars[index].char,
                      chars[index].hasDot,
                      enabledColor,
                      disabledColor,
                    )
                  : _CustomSevenSegmentPainter(
                      chars[index].char,
                      chars[index].hasDot,
                      enabledColor,
                      disabledColor,
                    ),
            ),
          ),
        );
      }),
    );
  }
}

class _SegmentCharData {
  final String char;
  final bool hasDot;
  _SegmentCharData(this.char, this.hasDot);
}

class _CustomSevenSegmentPainter extends CustomPainter {
  final String char;
  final bool showDot;
  final Color enabledColor;
  final Color disabledColor;

  _CustomSevenSegmentPainter(
    this.char,
    this.showDot,
    this.enabledColor,
    this.disabledColor,
  );

  static const Map<String, List<bool>> _map = {
    '0': [true, true, true, true, true, true, false],
    '1': [false, true, true, false, false, false, false],
    '2': [true, true, false, true, true, false, true],
    '3': [true, true, true, true, false, false, true],
    '4': [false, true, true, false, false, true, true],
    '5': [true, false, true, true, false, true, true],
    '6': [true, false, true, true, true, true, true],
    '7': [true, true, true, false, false, false, false],
    '8': [true, true, true, true, true, true, true],
    '9': [true, true, true, true, false, true, true],
    '-': [false, false, false, false, false, false, true],
    'E': [true, false, false, true, true, true, true],
    'R': [false, false, false, false, true, false, true],
    'H': [false, true, true, false, true, true, true],
    'A': [true, true, true, false, true, true, true],
    'C': [true, false, false, true, true, true, false],
    'B': [false, false, true, true, true, true, true],
    'Y': [false, true, true, true, false, true, true],
    '°': [true, true, false, false, false, true, true],
    "'": [false, false, false, false, false, true, false],
    'ⁿ': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ], // Symbolicky prázdné nebo specifické
    '∛': [
      true,
      false,
      false,
      true,
      true,
      true,
      true,
    ], // Symbolicky jako root s horním segmentem
    '√': [false, false, false, true, true, true, false],
    '.': [false, false, false, false, false, false, false],
    '_': [false, false, false, true, false, false, false],
    ';': [
      false,
      false,
      true,
      true,
      false,
      false,
      false,
    ], // Jako spodní tečka a čárka
    ' ': [false, false, false, false, false, false, false],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _map[char.toUpperCase()] ?? List.filled(7, false);
    final w = size.width / 1.5; // Číslice zabírá 2/3 šířky
    final h = size.height;
    final thickness = w * 0.15;

    void draw(int index, Offset p1, Offset p2) {
      final paint = Paint()
        ..color = segments[index] ? enabledColor : disabledColor
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
    }

    draw(0, Offset(thickness, 0), Offset(w - thickness, 0)); // a
    draw(1, Offset(w, thickness), Offset(w, h / 2 - thickness / 2)); // b
    draw(2, Offset(w, h / 2 + thickness / 2), Offset(w, h - thickness)); // c
    draw(3, Offset(thickness, h), Offset(w - thickness, h)); // d
    draw(4, Offset(0, h / 2 + thickness / 2), Offset(0, h - thickness)); // e
    draw(5, Offset(0, thickness), Offset(0, h / 2 - thickness / 2)); // f
    draw(6, Offset(thickness, h / 2), Offset(w - thickness, h / 2)); // g

    // Decimální tečka (DP) - odsazená od číslice
    final dotPaint = Paint()..color = showDot ? enabledColor : disabledColor;
    canvas.drawCircle(
      Offset(w + thickness * 1.5, h),
      thickness * 0.8,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CustomSixteenSegmentPainter extends CustomPainter {
  final String char;
  final bool showDot;
  final Color enabledColor;
  final Color disabledColor;

  _CustomSixteenSegmentPainter(
    this.char,
    this.showDot,
    this.enabledColor,
    this.disabledColor,
  );

  // A1, A2, B, C, D2, D1, E, F, G2, G1, H, I, J, K, L, M
  static const Map<String, List<bool>> _map = {
    '0': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    '1': [
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '2': [
      true,
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '3': [
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '4': [
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '5': [
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '6': [
      true,
      true,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '7': [
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '8': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '9': [
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'A': [
      true,
      true,
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'B': [
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'C': [
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'D': [
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'E': [
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'F': [
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'H': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'I': [
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'J': [
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'K': [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    'L': [
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'M': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      false,
      true,
      false,
      false,
      false,
    ],
    'N': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
      true,
    ],
    'O': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'P': [
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'Q': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
    ],
    'R': [
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
    ],
    'S': [
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'T': [
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'U': [
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'V': [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    'W': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
    ],
    'X': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
      true,
      false,
      true,
    ],
    'Y': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
      false,
      true,
      false,
    ],
    'Z': [
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    '-': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '°': [
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'ⁿ': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
    ],
    '∛': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '√': [
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
    ],
    "'": [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      false,
    ],
    '"': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
      false,
      false,
      false,
    ],
    '_': [
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    ';': [
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
    ], // Symbolicky jako spodní čárka a tečka
    ' ': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _map[char.toUpperCase()] ?? List.filled(16, false);
    final w = size.width / 1.5; // Číslice zabírá 2/3 šířky
    final h = size.height;
    final thickness = w * 0.12;

    void draw(int index, Offset p1, Offset p2) {
      final paint = Paint()
        ..color = segments[index] ? enabledColor : disabledColor
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
    }

    // A1, A2, B, C, D2, D1, E, F, G2, G1, H, I, J, K, L, M
    draw(0, Offset(thickness, 0), Offset(w / 2 - thickness / 4, 0)); // A1
    draw(1, Offset(w / 2 + thickness / 4, 0), Offset(w - thickness, 0)); // A2
    draw(2, Offset(w, thickness), Offset(w, h / 2 - thickness / 2)); // B
    draw(3, Offset(w, h / 2 + thickness / 2), Offset(w, h - thickness)); // C
    draw(4, Offset(w / 2 + thickness / 4, h), Offset(w - thickness, h)); // D2
    draw(5, Offset(thickness, h), Offset(w / 2 - thickness / 4, h)); // D1
    draw(6, Offset(0, h / 2 + thickness / 2), Offset(0, h - thickness)); // E
    draw(7, Offset(0, thickness), Offset(0, h / 2 - thickness / 2)); // F
    draw(
      8,
      Offset(w / 2 + thickness / 4, h / 2),
      Offset(w - thickness, h / 2),
    ); // G2
    draw(
      9,
      Offset(thickness, h / 2),
      Offset(w / 2 - thickness / 4, h / 2),
    ); // G1
    draw(
      10,
      Offset(thickness, thickness),
      Offset(w / 2 - thickness / 2, h / 2 - thickness / 2),
    ); // H
    draw(
      11,
      Offset(w / 2, thickness),
      Offset(w / 2, h / 2 - thickness / 2),
    ); // I
    draw(
      12,
      Offset(w - thickness, thickness),
      Offset(w / 2 + thickness / 2, h / 2 - thickness / 2),
    ); // J
    draw(
      13,
      Offset(thickness, h - thickness),
      Offset(w / 2 - thickness / 2, h / 2 + thickness / 2),
    ); // K
    draw(
      14,
      Offset(w / 2, h - thickness),
      Offset(w / 2, h / 2 + thickness / 2),
    ); // L
    draw(
      15,
      Offset(w - thickness, h - thickness),
      Offset(w / 2 + thickness / 2, h / 2 + thickness / 2),
    ); // M

    // Decimální tečka (DP) - odsazená od číslice
    final dotPaint = Paint()..color = showDot ? enabledColor : disabledColor;
    canvas.drawCircle(
      Offset(w + thickness * 1.5, h),
      thickness * 0.8,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomDotMatrixDisplay extends StatelessWidget {
  final String text;
  final double ledSize;
  final double ledSpacing;
  final Color enabledColor;
  final Color disabledColor;

  const CustomDotMatrixDisplay({
    super.key,
    required this.text,
    this.ledSize = 3.0,
    this.ledSpacing = 1.0,
    this.enabledColor = Colors.redAccent,
    this.disabledColor = const Color(0x0DFF5252),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: text.split('').map((char) {
        return Container(
          margin: EdgeInsets.only(right: ledSpacing * 2),
          child: CustomPaint(
            size: Size(
              ledSize * 5 + ledSpacing * 4,
              ledSize * 7 + ledSpacing * 6,
            ),
            painter: _CustomDotMatrixPainter(
              char,
              ledSize,
              ledSpacing,
              enabledColor,
              disabledColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomDotMatrixPainter extends CustomPainter {
  final String char;
  final double ledSize;
  final double ledSpacing;
  final Color enabledColor;
  final Color disabledColor;

  _CustomDotMatrixPainter(
    this.char,
    this.ledSize,
    this.ledSpacing,
    this.enabledColor,
    this.disabledColor,
  );

  static const Map<String, List<int>> _font = {
    '0': [0x1F, 0x11, 0x11, 0x11, 0x1F],
    '1': [0x00, 0x12, 0x1F, 0x10, 0x00],
    '2': [0x19, 0x15, 0x15, 0x15, 0x13],
    '3': [0x11, 0x15, 0x15, 0x15, 0x1F],
    '4': [0x07, 0x04, 0x04, 0x04, 0x1F],
    '5': [0x17, 0x15, 0x15, 0x15, 0x19],
    '6': [0x1F, 0x15, 0x15, 0x15, 0x19],
    '7': [0x01, 0x01, 0x01, 0x01, 0x1F],
    '8': [0x1F, 0x15, 0x15, 0x15, 0x1F],
    '9': [0x17, 0x15, 0x15, 0x15, 0x1F],
    'A': [0x1E, 0x05, 0x05, 0x05, 0x1E],
    'B': [0x1F, 0x15, 0x15, 0x15, 0x0A],
    'C': [0x0E, 0x11, 0x11, 0x11, 0x11],
    'D': [0x1F, 0x11, 0x11, 0x11, 0x0E],
    'E': [0x1F, 0x15, 0x15, 0x15, 0x11],
    'F': [0x1F, 0x05, 0x05, 0x05, 0x01],
    'G': [0x0E, 0x11, 0x15, 0x15, 0x1D],
    'H': [0x1F, 0x04, 0x04, 0x04, 0x1F],
    'I': [0x11, 0x11, 0x1F, 0x11, 0x11],
    'J': [0x10, 0x10, 0x10, 0x11, 0x0F],
    'K': [0x1F, 0x04, 0x0A, 0x11, 0x00],
    'L': [0x1F, 0x10, 0x10, 0x10, 0x10],
    'M': [0x1F, 0x02, 0x04, 0x02, 0x1F],
    'N': [0x1F, 0x02, 0x04, 0x08, 0x1F],
    'O': [0x0E, 0x11, 0x11, 0x11, 0x0E],
    'P': [0x1F, 0x05, 0x05, 0x05, 0x02],
    'Q': [0x0E, 0x11, 0x19, 0x11, 0x2E],
    'R': [0x1F, 0x05, 0x05, 0x0D, 0x12],
    'S': [0x12, 0x15, 0x15, 0x15, 0x09],
    'T': [0x01, 0x01, 0x1F, 0x01, 0x01],
    'U': [0x0F, 0x10, 0x10, 0x10, 0x0F],
    'V': [0x07, 0x08, 0x10, 0x08, 0x07],
    'W': [0x1F, 0x08, 0x04, 0x08, 0x1F],
    'X': [0x11, 0x0A, 0x04, 0x0A, 0x11],
    'Y': [0x03, 0x04, 0x18, 0x04, 0x03],
    'Z': [0x11, 0x19, 0x15, 0x13, 0x11],
    '-': [0x04, 0x04, 0x04, 0x04, 0x04],
    '°': [0x00, 0x03, 0x03, 0x00, 0x00],
    "'": [0x00, 0x01, 0x02, 0x00, 0x00],
    '"': [0x01, 0x02, 0x00, 0x01, 0x02],
    '_': [0x10, 0x10, 0x10, 0x10, 0x10],
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00],
    '.': [0x00, 0x00, 0x10, 0x00, 0x00],
    '\u03C0': [0x12, 0x1F, 0x12, 0x1F, 0x12],
    '\u03A0': [0x12, 0x1F, 0x12, 0x1F, 0x12],
    '(': [0x00, 0x0E, 0x11, 0x00, 0x00],
    ')': [0x00, 0x00, 0x11, 0x0E, 0x00],
    '+': [0x04, 0x04, 0x1F, 0x04, 0x04],
    '*': [0x00, 0x0A, 0x04, 0x0A, 0x00],
    '/': [0x10, 0x08, 0x04, 0x02, 0x01],
    '%': [0x19, 0x05, 0x02, 0x14, 0x13],
    '^': [0x02, 0x01, 0x02, 0x00, 0x00],
    '√': [0x02, 0x04, 0x08, 0x10, 0x1E],
    '∛': [0x22, 0x24, 0x28, 0x30, 0x2E],
    'ⁿ': [0x00, 0x03, 0x01, 0x03, 0x00],
    ',': [0x00, 0x00, 0x18, 0x00, 0x00],
    '!': [0x00, 0x16, 0x16, 0x00, 0x00],
    ';': [0x00, 0x00, 0x14, 0x00, 0x00],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final data =
        _font[char] ??
        _font[char.toUpperCase()] ??
        [0x1F, 0x1F, 0x1F, 0x1F, 0x1F];
    final paint = Paint()..style = PaintingStyle.fill;

    for (int col = 0; col < 5; col++) {
      for (int row = 0; row < 7; row++) {
        bool enabled = (data[col] >> row) & 1 == 1;
        paint.color = enabled ? enabledColor : disabledColor;
        canvas.drawCircle(
          Offset(
            col * (ledSize + ledSpacing) + ledSize / 2,
            row * (ledSize + ledSpacing) + ledSize / 2,
          ),
          ledSize / 2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AccessibilityDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _AccessibilityDialog({required this.parent});
  @override
  State<_AccessibilityDialog> createState() => _AccessibilityDialogState();
}

class _AccessibilityDialogState extends State<_AccessibilityDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Semantics(header: true, child: const Text('Nastavení přístupnosti')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Přepnutí typu displeje',
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () => widget.parent._useSixteenSegment =
                          !widget.parent._useSixteenSegment,
                    );
                    widget.parent._saveSettings();
                  });
                  widget.parent.speak(
                    widget.parent._useSixteenSegment
                        ? 'Zapnut 16-segmentový displej'
                        : 'Zapnut 7-segmentový displej',
                  );
                },
                child: Text(
                  'Displej: ${widget.parent._useSixteenSegment ? '16-segmentový' : '7-segmentový'}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: 'Přepnutí hlasového výstupu',
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () => widget.parent.ttsEnabled = !widget.parent.ttsEnabled,
                    );
                    widget.parent._saveSettings();
                  });
                  widget.parent.speak(
                    widget.parent.ttsEnabled ? 'Hlas zapnut' : 'Hlas vypnut',
                  );
                },
                child: Text(
                  'Hlasový výstup: ${widget.parent.ttsEnabled ? 'Zapnuto' : 'Vypnuto'}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              container: true,
              label: 'Režim čtečky obrazovky',
              child: Column(
                children: [
                  const Text('Režim čtečky obrazovky'),
                  const SizedBox(height: 8),
                  SegmentedButton<ScreenReaderMode>(
                    segments: const [
                      ButtonSegment(value: ScreenReaderMode.auto, label: Text('Auto')),
                      ButtonSegment(value: ScreenReaderMode.on, label: Text('Zapnuto')),
                      ButtonSegment(value: ScreenReaderMode.off, label: Text('Vypnuto')),
                    ],
                    selected: {widget.parent._screenReaderMode},
                    onSelectionChanged: (Set<ScreenReaderMode> selected) {
                      final mode = selected.first;
                      setState(() {
                        widget.parent.setState(() {
                          widget.parent._screenReaderMode = mode;
                        });
                        widget.parent._saveSettings();
                      });
                      widget.parent.speak(
                        mode == ScreenReaderMode.auto
                            ? 'Režim čtečky: automaticky'
                            : mode == ScreenReaderMode.on
                                ? 'Režim čtečky obrazovky zapnut'
                                : 'Režim čtečky obrazovky vypnut',
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Semantics(
              label: 'Nastavení hlasového engine',
              child: ElevatedButton(
                onPressed: () {
                  widget.parent._showTtsEngineDialog();
                },
                child: Text(
                  'Engine: ${widget.parent._ttsEngine ?? 'Výchozí'}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: 'Přepnutí formátu úhlů',
              child: ElevatedButton(
                onPressed: () {
                  // Pokud je null nebo 1, nastavíme na 0 (DMS). Pokud je 0, nastavíme na 1 (Desetinné).
                  final current = widget.parent._inverseFormatPreference ?? 1;
                  final newFormat = (current == 0) ? 1 : 0;
                  
                  widget.parent._saveInversePreference(newFormat);
                  
                  widget.parent.speak(
                    newFormat == 0
                        ? 'Formát nastaven na stupně, minuty a sekundy'
                        : 'Formát nastaven na desetinné stupně',
                  );
                  // Vynucené překreslení dialogu
                  setState(() {});
                },
                child: Text(
                  'Úhly: ${(widget.parent._inverseFormatPreference == 0) ? 'DMS' : 'Desetinné'}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              container: true,
              label: 'Výběr motivu aplikace',
              child: Column(
                children: [
                  const Text('Motiv aplikace'),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Systém'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Světlý'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Tmavý'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {widget.parent.widget.themeMode},
              onSelectionChanged: (Set<ThemeMode> selection) {
                ThemeMode mode = selection.first;
                widget.parent.widget.onThemeModeChanged(mode);
                String modeName = 'systémový';
                if (mode == ThemeMode.light) modeName = 'světlý';
                if (mode == ThemeMode.dark) modeName = 'tmavý';
                widget.parent.speak('Motiv nastaven na $modeName');
                setState(() {});
              },
            ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Velikost dialogů
            Semantics(
              container: true,
              label: widget.parent._l10n.dialogSizeSetting,
              child: Column(
                children: [
                  Text(widget.parent._l10n.dialogSizeSetting),
                  const SizedBox(height: 8),
                  SegmentedButton<DialogSize>(
                    segments: [
                      ButtonSegment(
                        value: DialogSize.compact,
                        label: Text(widget.parent._l10n.dialogSizeCompact),
                        icon: const Icon(Icons.phone_android),
                      ),
                      ButtonSegment(
                        value: DialogSize.wide,
                        label: Text(widget.parent._l10n.dialogSizeWide),
                        icon: const Icon(Icons.phone_iphone),
                      ),
                      ButtonSegment(
                        value: DialogSize.fullscreen,
                        label: Text(widget.parent._l10n.dialogSizeFullscreen),
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                    selected: {widget.parent._dialogSize},
                    onSelectionChanged: (Set<DialogSize> selected) {
                      final size = selected.first;
                      setState(() {
                        widget.parent.setState(() {
                          widget.parent._dialogSize = size;
                        });
                        widget.parent._saveSettings();
                      });
                      String sizeName = widget.parent._l10n.dialogSizeCompact;
                      if (size == DialogSize.wide) {
                        sizeName = widget.parent._l10n.dialogSizeWide;
                      } else if (size == DialogSize.fullscreen) {
                        sizeName = widget.parent._l10n.dialogSizeFullscreen;
                      }
                      widget.parent.speak(
                        '${widget.parent._l10n.dialogSizeSetting}: $sizeName',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seskupená Rychlost
            Semantics(
              container: true,
              label: 'Ovládání zoomu horního řádku',
              child: Column(
                children: [
                  const Text('Zoom horního řádku'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Zmenšit zoom',
                        child: ElevatedButton(
                          onPressed: () => _adjustDotMatrixZoom(-0.1),
                          child: const Text('-'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${(widget.parent._dotMatrixZoom * 100).toInt()}%',
                        ),
                      ),
                      Semantics(
                        label: 'Zvětšit zoom',
                        child: ElevatedButton(
                          onPressed: () => _adjustDotMatrixZoom(0.1),
                          child: const Text('+'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              container: true,
              label: 'Ovládání zoomu dolního řádku',
              child: Column(
                children: [
                  const Text('Zoom dolního řádku'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Zmenšit zoom',
                        child: ElevatedButton(
                          onPressed: () => _adjustResultZoom(-0.1),
                          child: const Text('-'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${(widget.parent._resultZoom * 100).toInt()}%',
                        ),
                      ),
                      Semantics(
                        label: 'Zvětšit zoom',
                        child: ElevatedButton(
                          onPressed: () => _adjustResultZoom(0.1),
                          child: const Text('+'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Seskupená Rychlost
            Semantics(
              container: true,
              label: 'Ovládání rychlosti hlasu',
              child: Column(
                children: [
                  const Text('Rychlost hlasu'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Snížit rychlost',
                        child: ElevatedButton(
                          onPressed: () => _adjustSpeechRate(-0.1),
                          child: const Text('-'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${(widget.parent._speechRate * 100).toInt()}%',
                        ),
                      ),
                      Semantics(
                        label: 'Zvýšit rychlost',
                        child: ElevatedButton(
                          onPressed: () => _adjustSpeechRate(0.1),
                          child: const Text('+'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seskupená Hlasitost
            Semantics(
              container: true,
              label: 'Ovládání hlasitosti',
              child: Column(
                children: [
                  const Text('Hlasitost'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Snížit hlasitost',
                        child: ElevatedButton(
                          onPressed: () => _adjustSpeechVolume(-0.1),
                          child: const Text('-'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${(widget.parent._speechVolume * 100).toInt()}%',
                        ),
                      ),
                      Semantics(
                        label: 'Zvýšit hlasitost',
                        child: ElevatedButton(
                          onPressed: () => _adjustSpeechVolume(0.1),
                          child: const Text('+'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Semantics(
              container: true,
              label: 'Záloha a obnova dat',
              child: Column(
                children: [
                  const Text('Správa dat'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Zálohovat data',
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.backup),
                          onPressed: () {
                            widget.parent._exportBackup();
                            Navigator.pop(context);
                          },
                          label: const Text('Zálohovat'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Semantics(
                        label: 'Obnovit data',
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.restore),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Potvrzení'),
                                content: Text(
                                  widget.parent._l10n.restoreConfirm,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('NE'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('ANO'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              widget.parent._importBackup();
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          label: const Text('Obnovit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (widget.parent.mounted)
                widget.parent._mainFocusNode.requestFocus();
            });
          },
          child: const Text('HOTOVO'),
        ),
      ],
    );
  }

  void _adjustDotMatrixZoom(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._dotMatrixZoom = (widget.parent._dotMatrixZoom + delta)
            .clamp(0.5, 5.0);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      'Zoom horního řádku ${(widget.parent._dotMatrixZoom * 100).toInt()} procent',
    );
  }

  void _adjustResultZoom(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._resultZoom = (widget.parent._resultZoom + delta).clamp(
          0.5,
          5.0,
        );
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      'Zoom dolního řádku ${(widget.parent._resultZoom * 100).toInt()} procent',
    );
  }

  void _adjustSpeechRate(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._speechRate = (widget.parent._speechRate + delta).clamp(
          0.1,
          1.0,
        );
        widget.parent.tts.setSpeechRate(widget.parent._speechRate);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      'Rychlost ${(widget.parent._speechRate * 100).toInt()} procent',
    );
  }

  void _adjustSpeechVolume(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._speechVolume = (widget.parent._speechVolume + delta)
            .clamp(0.0, 1.0);
        widget.parent.tts.setVolume(widget.parent._speechVolume);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      'Hlasitost ${(widget.parent._speechVolume * 100).toInt()} procent',
    );
  }
}