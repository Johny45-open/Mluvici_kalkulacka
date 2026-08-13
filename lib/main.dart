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

class _MathDomainException implements Exception {
  final String message;

  const _MathDomainException(this.message);

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
  final double? wmean;
  final Map<double, int> frequencies;

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
    this.wmean,
    required this.frequencies,
  });
}

class StatisticsRecord {
  final List<double> values;

  StatisticsRecord({required this.values});

  Map<String, dynamic> toJson() => {'values': values};

  factory StatisticsRecord.fromJson(Map<String, dynamic> json) {
    return StatisticsRecord(
      values: (json['values'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  StatisticsRecord copyWith({List<double>? values}) {
    return StatisticsRecord(values: values ?? this.values);
  }
}

class StatisticsSet {
  String name;
  final List<String> fieldNames;
  final List<String?> fieldUnits;
  final List<StatisticsRecord> records;

  StatisticsSet({
    required this.name,
    required this.fieldNames,
    required this.records,
    List<String?>? fieldUnits,
  }) : fieldUnits = fieldUnits ?? List.filled(fieldNames.length, null);

  Map<String, dynamic> toJson() => {
    'name': name,
    'fieldNames': fieldNames,
    'fieldUnits': fieldUnits,
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
        records: data.map((v) => StatisticsRecord(values: [v])).toList(),
      );
    }
    final fieldNames = (json['fieldNames'] as List).cast<String>();
    final fieldUnits = json['fieldUnits'] != null
        ? (json['fieldUnits'] as List).map((e) => e as String?).toList()
        : List<String?>.filled(fieldNames.length, null);
    return StatisticsSet(
      name: json['name'] as String,
      fieldNames: fieldNames,
      fieldUnits: fieldUnits,
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
  static const MethodChannel _accessibilityChannel = MethodChannel(
    'com.example.mluvici_kalkulacka/accessibility',
  );

  final FlutterTts tts = FlutterTts();
  final FocusNode _mainFocusNode = FocusNode();
  String display = '';
  int _cursorPosition = 0;
  String _lastResult = '0.';
  CalculatorMode _currentMode = CalculatorMode.scientific;
  CalculatorMode _defaultMode = CalculatorMode.scientific;
  List<int> _modeUsageCounts = List<int>.filled(
    CalculatorMode.values.length,
    0,
  );
  int _totalModeSwitches = 0;
  String? _lastSeenNewsVersion;
  int? _lastSuggestedMode;

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
  Map<String, String>? _ttsVoice;
  String? _ttsVoiceName;
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
  bool _statsSummaryInitialized = false;

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
    'Čas': {'s': 1.0, 'min': 60.0, 'h': 3600.0, 'd': 86400.0},
    'Napětí': {
      'V': 1.0,
      'mV': 0.001,
      'µV': 0.000001,
      'kV': 1000.0,
      'MV': 1000000.0,
    },
    'Proud': {'A': 1.0, 'mA': 0.001, 'µA': 0.000001, 'kA': 1000.0},
    'Odpor': {'Ω': 1.0, 'mΩ': 0.001, 'kΩ': 1000.0, 'MΩ': 1000000.0},
    'Výkon': {
      'W': 1.0,
      'mW': 0.001,
      'kW': 1000.0,
      'MW': 1000000.0,
      'GW': 1000000000.0,
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
    's': {
      'base': 'sekunda',
      'z': 'sekund',
      'na': 'sekundy',
      'forms': ['sekunda', 'sekundy', 'sekund', 'sekundy'],
    },
    'min': {
      'base': 'minuta',
      'z': 'minut',
      'na': 'minuty',
      'forms': ['minuta', 'minuty', 'minut', 'minuty'],
    },
    'h': {
      'base': 'hodina',
      'z': 'hodin',
      'na': 'hodiny',
      'forms': ['hodina', 'hodiny', 'hodin', 'hodiny'],
    },
    'd': {
      'base': 'den',
      'z': 'dní',
      'na': 'dny',
      'forms': ['den', 'dny', 'dní', 'dne'],
    },
    'V': {
      'base': 'volt',
      'z': 'voltů',
      'na': 'volty',
      'forms': ['volt', 'volty', 'voltů', 'voltu'],
    },
    'mV': {
      'base': 'milivolt',
      'z': 'milivoltů',
      'na': 'milivolty',
      'forms': ['milivolt', 'milivolty', 'milivoltů', 'milivoltu'],
    },
    'µV': {
      'base': 'mikrovolt',
      'z': 'mikrovoltů',
      'na': 'mikrovolty',
      'forms': ['mikrovolt', 'mikrovolty', 'mikrovoltů', 'mikrovoltu'],
    },
    'kV': {
      'base': 'kilovolt',
      'z': 'kilovoltů',
      'na': 'kilovolty',
      'forms': ['kilovolt', 'kilovolty', 'kilovoltů', 'kilovoltu'],
    },
    'MV': {
      'base': 'megavolt',
      'z': 'megavoltů',
      'na': 'megavolty',
      'forms': ['megavolt', 'megavolty', 'megavoltů', 'megavoltu'],
    },
    'A': {
      'base': 'ampér',
      'z': 'ampérů',
      'na': 'ampéry',
      'forms': ['ampér', 'ampéry', 'ampérů', 'ampéru'],
    },
    'mA': {
      'base': 'miliampér',
      'z': 'miliampérů',
      'na': 'miliampéry',
      'forms': ['miliampér', 'miliampéry', 'miliampérů', 'miliampéru'],
    },
    'µA': {
      'base': 'mikroampér',
      'z': 'mikroampérů',
      'na': 'mikroampéry',
      'forms': ['mikroampér', 'mikroampéry', 'mikroampérů', 'mikroampéru'],
    },
    'kA': {
      'base': 'kiloampér',
      'z': 'kiloampérů',
      'na': 'kiloampéry',
      'forms': ['kiloampér', 'kiloampéry', 'kiloampérů', 'kiloampéru'],
    },
    'Ω': {
      'base': 'ohm',
      'z': 'ohmů',
      'na': 'ohmy',
      'forms': ['ohm', 'ohmy', 'ohmů', 'ohmu'],
    },
    'mΩ': {
      'base': 'miliohm',
      'z': 'miliohmů',
      'na': 'miliohmy',
      'forms': ['miliohm', 'miliohmy', 'miliohmů', 'miliohmu'],
    },
    'kΩ': {
      'base': 'kiloohm',
      'z': 'kiloohmů',
      'na': 'kiloohmy',
      'forms': ['kiloohm', 'kiloohmy', 'kiloohmů', 'kiloohmu'],
    },
    'MΩ': {
      'base': 'megaohm',
      'z': 'megaohmů',
      'na': 'megaohmy',
      'forms': ['megaohm', 'megaohmy', 'megaohmů', 'megaohmu'],
    },
    'W': {
      'base': 'watt',
      'z': 'wattů',
      'na': 'watty',
      'forms': ['watt', 'watty', 'wattů', 'wattu'],
    },
    'mW': {
      'base': 'miliwatt',
      'z': 'miliwattů',
      'na': 'miliwatty',
      'forms': ['miliwatt', 'miliwatty', 'miliwattů', 'miliwattu'],
    },
    'kW': {
      'base': 'kilowatt',
      'z': 'kilowattů',
      'na': 'kilowatty',
      'forms': ['kilowatt', 'kilowatty', 'kilowattů', 'kilowattu'],
    },
    'MW': {
      'base': 'megawatt',
      'z': 'megawattů',
      'na': 'megawatty',
      'forms': ['megawatt', 'megawatty', 'megawattů', 'megawattu'],
    },
    'GW': {
      'base': 'gigawatt',
      'z': 'gigawattů',
      'na': 'gigawatty',
      'forms': ['gigawatt', 'gigawatty', 'gigawattů', 'gigawattu'],
    },
  };

  final Map<String, Map<String, String>> _unitSpeechDataEn = {
    'm': {'base': 'meter', 'plural': 'meters'},
    'km': {'base': 'kilometer', 'plural': 'kilometers'},
    'cm': {'base': 'centimeter', 'plural': 'centimeters'},
    'mm': {'base': 'millimeter', 'plural': 'millimeters'},
    'mi': {'base': 'mile', 'plural': 'miles'},
    'yd': {'base': 'yard', 'plural': 'yards'},
    'ft': {'base': 'foot', 'plural': 'feet'},
    'in': {'base': 'inch', 'plural': 'inches'},
    'kg': {'base': 'kilogram', 'plural': 'kilograms'},
    'g': {'base': 'gram', 'plural': 'grams'},
    'mg': {'base': 'milligram', 'plural': 'milligrams'},
    't': {'base': 'tonne', 'plural': 'tonnes'},
    'lb': {'base': 'pound', 'plural': 'pounds'},
    'oz': {'base': 'ounce', 'plural': 'ounces'},
    'm²': {'base': 'square meter', 'plural': 'square meters'},
    'km²': {'base': 'square kilometer', 'plural': 'square kilometers'},
    'ha': {'base': 'hectare', 'plural': 'hectares'},
    'cm²': {'base': 'square centimeter', 'plural': 'square centimeters'},
    'akr': {'base': 'acre', 'plural': 'acres'},
    'l': {'base': 'liter', 'plural': 'liters'},
    'ml': {'base': 'milliliter', 'plural': 'milliliters'},
    'm³': {'base': 'cubic meter', 'plural': 'cubic meters'},
    'gal': {'base': 'gallon', 'plural': 'gallons'},
    'pt': {'base': 'pint', 'plural': 'pints'},
    'Pa': {'base': 'pascal', 'plural': 'pascals'},
    'hPa': {'base': 'hectopascal', 'plural': 'hectopascals'},
    'kPa': {'base': 'kilopascal', 'plural': 'kilopascals'},
    'bar': {'base': 'bar', 'plural': 'bars'},
    'atm': {'base': 'atmosphere', 'plural': 'atmospheres'},
    'psi': {'base': 'psi', 'plural': 'psi'},
    's': {'base': 'second', 'plural': 'seconds'},
    'min': {'base': 'minute', 'plural': 'minutes'},
    'h': {'base': 'hour', 'plural': 'hours'},
    'd': {'base': 'day', 'plural': 'days'},
    'V': {'base': 'volt', 'plural': 'volts'},
    'mV': {'base': 'millivolt', 'plural': 'millivolts'},
    'µV': {'base': 'microvolt', 'plural': 'microvolts'},
    'kV': {'base': 'kilovolt', 'plural': 'kilovolts'},
    'MV': {'base': 'megavolt', 'plural': 'megavolts'},
    'A': {'base': 'ampere', 'plural': 'amperes'},
    'mA': {'base': 'milliampere', 'plural': 'milliamperes'},
    'µA': {'base': 'microampere', 'plural': 'microamperes'},
    'kA': {'base': 'kiloampere', 'plural': 'kiloamperes'},
    'Ω': {'base': 'ohm', 'plural': 'ohms'},
    'mΩ': {'base': 'milliohm', 'plural': 'milliohms'},
    'kΩ': {'base': 'kilohm', 'plural': 'kilohms'},
    'MΩ': {'base': 'megohm', 'plural': 'megohms'},
    'W': {'base': 'watt', 'plural': 'watts'},
    'mW': {'base': 'milliwatt', 'plural': 'milliwatts'},
    'kW': {'base': 'kilowatt', 'plural': 'kilowatts'},
    'MW': {'base': 'megawatt', 'plural': 'megawatts'},
    'GW': {'base': 'gigawatt', 'plural': 'gigawatts'},
  };

  String _selectedUnitCategory = 'Délka';
  String _unitFrom = 'm';
  String _unitTo = 'km';
  List<String> _history = [];
  bool _isStoreMode = false;
  bool _isRecallMode = false;
  bool _hasResult = false;

  final Map<String, List<String>> _buttonNames = {
    'SIN': ['Sinus', 'Sine'],
    'COS': ['Kosinus', 'Cosine'],
    'TAN': ['Tangens', 'Tangent'],
    'ASIN': ['Arkus sinus', 'Arcsine'],
    'ACOS': ['Arkus kosinus', 'Arccosine'],
    'ATAN': ['Arkus tangens', 'Arctangent'],
    'ABS': ['Absolutní hodnota', 'Absolute value'],
    '°→\'': ['Převod na DMS', 'Convert to DMS'],
    '\'→°': ['Převod na stupně', 'Convert to degrees'],
    'DMS': ['Vložit DMS', 'Insert DMS'],
    '=': ['Rovná se', 'Equals'],
    '/': ['Lomeno', 'Over'],
    '*': ['Krát', 'Times'],
    '-': ['Mínus', 'Minus'],
    '+': ['Plus', 'Plus'],
    '(': ['Závorka otevřená', 'Open parenthesis'],
    ')': ['Závorka zavřená', 'Close parenthesis'],
    '.': ['Tečka', 'Decimal point'],
    '^': ['Mocnina', 'Power'],
    '√': ['Odmocnina', 'Square root'],
    'ⁿ√': ['En-tá odmocnina', 'Nth root'],
    'x²': ['Na druhou', 'Squared'],
    'x³': ['Na třetí', 'Cubed'],
    '∛': ['Třetí odmocnina', 'Cube root'],
    '1/x': ['Převrácená hodnota', 'Reciprocal'],
    'LOG': ['Logaritmus', 'Logarithm'],
    'LN': ['Přirozený logaritmus', 'Natural logarithm'],
    'X': ['Proměnná X', 'Variable X'],
    'Y': ['Proměnná Y', 'Variable Y'],
    'A': ['Proměnná A', 'Variable A'],
    'B': ['Proměnná B', 'Variable B'],
    'D': ['Proměnná D', 'Variable D'],
    'E': ['Proměnná E', 'Variable E'],
    'F': ['Proměnná F', 'Variable F'],
    'M': ['Proměnná M', 'Variable M'],
    'ANS': ['Poslední výsledek', 'Last answer'],
    'STO': ['Uložit do paměti', 'Store in memory'],
    'DEL': ['Smazat poslední', 'Delete last'],
    'RCL': ['Vyvolat z paměti', 'Recall from memory'],
    'CLR': ['Smazat celou paměť', 'Clear memory'],
    'C': ['Smazat displej', 'Clear display'],
    'DEG': ['Stupně', 'Degrees'],
    'RAD': ['Radiány', 'Radians'],
    '%': ['Procenta', 'Percent'],
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
    'WMEAN': ['Vážený průměr', 'Weighted mean'],
    'SETS': ['Správa sad', 'Manage sets'],
    'PCT': ['Kolik procent', 'What percent'],
    'SUM': ['Součet hodnot', 'Sum of values'],
    ';': ['Oddělovač dat', 'Data separator'],
    '!': ['Faktoriál', 'Factorial'],
    '(-)': ['Záporné číslo se závorkou', 'Negative in parentheses'],
    'EXP': ['krát deset na', 'times ten to'],
    'OHM_V': ['Napětí', 'Voltage'],
    'OHM_I': ['Proud', 'Current'],
    'OHM_R': ['Odpor', 'Resistance'],
    'PWR_P': ['Výkon', 'Power'],
    'PAR': ['Paralelně', 'In parallel'],
    'SER': ['Sériově', 'In series'],
    'Hz': ['Hertz', 'Hertz'],
    'μ': ['Mikro', 'Micro'],
    'n': ['Nano', 'Nano'],
    'p': ['Piko', 'Pico'],
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

  bool _statsRecordsEqual(StatisticsRecord a, StatisticsRecord b) {
    if (a.values.length != b.values.length) return false;
    for (int i = 0; i < a.values.length; i++) {
      if (a.values[i] != b.values[i]) return false;
    }
    return true;
  }

  List<List<int>> _groupStatsRecords(List<StatisticsRecord> records) {
    final groups = <List<int>>[];
    final reps = <StatisticsRecord>[];
    for (int i = 0; i < records.length; i++) {
      int? match;
      for (int g = 0; g < groups.length; g++) {
        if (_statsRecordsEqual(reps[g], records[i])) {
          match = g;
          break;
        }
      }
      if (match == null) {
        groups.add([i]);
        reps.add(records[i]);
      } else {
        groups[match].add(i);
      }
    }
    return groups;
  }

  String _statsEmptyMessage() {
    if (_statsSets.isEmpty) {
      return _s(
        'Není vytvořena žádná statistická sada.',
        'No statistics set created.',
      );
    }
    final setName = _statsSets[_currentStatsSetIndex].name;
    return _s(
      'Statistická sada "$setName" je prázdná. Přidejte data pomocí tlačítka M plus.',
      'Statistics set "$setName" is empty. Add data using the M+ button.',
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  bool _isEnglish([BuildContext? ctx]) {
    final code = ctx != null
        ? Localizations.localeOf(ctx).languageCode
        : WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'en';
  }

  String _s(String cs, String en) => _isEnglish() ? en : cs;

  String _getModeSpeechNameForL10n(CalculatorMode mode, AppLocalizations l10n) {
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
    if (_ttsVoice != null) {
      _ttsVoice = null;
      _ttsVoiceName = null;
      tts.clearVoice();
      _saveSettings();
    }
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
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final frequencies = Map<double, int>.fromIterable(
      sortedEntries,
      key: (e) => e.key,
      value: (e) => e.value,
    );

    double? wmean;
    if (_currentFieldCount >= 2) {
      final values = _getFieldValues(0);
      final weights = _getFieldValues(1);
      double sumW = 0;
      double sumVW = 0;
      for (int i = 0; i < values.length; i++) {
        sumVW += values[i] * weights[i];
        sumW += weights[i];
      }
      if (sumW != 0) wmean = sumVW / sumW;
    }

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
      wmean: wmean,
      frequencies: frequencies,
    );
  }

  String _formatSpokenNumber(double value) =>
      _formatNumber(value).replaceAll('.', ',');

  String _getButtonName(String label) {
    final pair = _buttonNames[label];
    if (pair != null) {
      return _isEnglish() ? pair[1] : pair[0];
    }
    return label;
  }

  String _getCategorySpeech(String category) {
    switch (category) {
      case 'Délka':
        return _s('Délka', 'Length');
      case 'Hmotnost':
        return _s('Hmotnost', 'Mass');
      case 'Plocha':
        return _s('Plocha', 'Area');
      case 'Objem':
        return _s('Objem', 'Volume');
      case 'Tlak':
        return _s('Tlak', 'Pressure');
      case 'Čas':
        return _s('Čas', 'Time');
      case 'Napětí':
        return _s('Napětí', 'Voltage');
      case 'Proud':
        return _s('Proud', 'Current');
      case 'Odpor':
        return _s('Odpor', 'Resistance');
      case 'Výkon':
        return _s('Výkon', 'Power');
      default:
        return category;
    }
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
        return _l10n.calcNameVoltage;
      case ElectricianCalculation.current:
        return _l10n.calcNameCurrent;
      case ElectricianCalculation.resistance:
        return _l10n.calcNameResistance;
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
        return _l10n.calcInputVoltage;
      case ElectricianCalculation.current:
        return _l10n.calcInputCurrent;
      case ElectricianCalculation.resistance:
        return _l10n.calcInputResistance;
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

    if (_isEnglish()) {
      String unit;
      switch (calculation) {
        case ElectricianCalculation.voltage:
          unit = 'volt';
          break;
        case ElectricianCalculation.current:
          unit = 'ampere';
          break;
        case ElectricianCalculation.resistance:
          unit = 'ohm';
          break;
      }
      switch (prefix) {
        case 'mili':
          unit = 'milli$unit';
          break;
        case 'mikro':
          unit = 'micro$unit';
          break;
        case 'nano':
          unit = 'nano$unit';
          break;
        case 'piko':
          unit = 'pico$unit';
          break;
        case 'kilo':
          unit = 'kilo$unit';
          break;
        case 'mega':
          unit = 'mega$unit';
          break;
        case 'giga':
          unit = 'giga$unit';
          break;
      }
      if (isWholeNumber && wholeValue == 1) {
        return unit;
      }
      return '${unit}s';
    }

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
    if (prefix == 'mili')
      unit = 'mili${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'mikro')
      unit = 'mikro${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'nano')
      unit = 'nano${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'piko')
      unit = 'piko${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'kilo')
      unit = 'kilo${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'mega')
      unit = 'mega${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'giga')
      unit = 'giga${unit == 'ohm' ? 'ohm' : unit}';

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
    speak(_l10n.calcIntro(calculationName, inputDescription));
  }

  List<double> _parseElectricianInputValues(String input) {
    final parts = input.split(';');
    if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
      throw _ElectricianInputException(_l10n.elecTwoValuesError);
    }

    try {
      return parts.map((part) => _evaluateExpression(part.trim())).toList();
    } catch (e) {
      throw _ElectricianInputException(_l10n.elecFormatError);
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

    final baseLabel = _getButtonName(label);
    if (calculation == _selectedElectricianCalculation) {
      return '${baseLabel}, ${_s('vybráno', 'selected')}';
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
      _checkForNews();
    }
  }

  String get _currentNumericVersion {
    return _currentAppVersion.split('+').first;
  }

  Future<void> _checkForNews() async {
    if (!mounted || _updateDialogShown) {
      return;
    }
    if (_lastSeenNewsVersion == null) {
      return;
    }
    final currentNumeric = _currentNumericVersion;
    if (_lastSeenNewsVersion == currentNumeric) {
      return;
    }

    await _markNewsSeen(currentNumeric);

    final checker = GitHubReleaseChecker();
    final releases = await checker.fetchRecentReleases(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      perPage: 10,
    );
    checker.close();
    if (!mounted) return;

    final currentRelease = _findReleaseForVersion(releases, currentNumeric);
    if (currentRelease == null) {
      return;
    }

    await _showNewsDialog(initialFocusVersion: currentRelease);
  }

  GitHubReleaseInfo? _findReleaseForVersion(
    List<GitHubReleaseInfo> releases,
    String numericVersion,
  ) {
    for (final release in releases) {
      if (release.normalizedVersion == numericVersion) {
        return release;
      }
    }
    return null;
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

  Future<void> _checkForUpdatesManually() async {
    if (!mounted) return;
    final checker = GitHubReleaseChecker();
    final release = await checker.checkForUpdates(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      currentVersion: _currentAppVersion,
    );
    checker.close();
    if (!mounted) return;
    if (release != null) {
      await _showUpdateDialog(release);
    } else {
      speak(_l10n.appIsCurrent);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.appIsCurrent)));
    }
  }

  Future<void> _showUpdateDialog(GitHubReleaseInfo release) async {
    setState(() {
      _updateDialogShown = true;
    });

    await showDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Dostupná aktualizace'),
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        semanticLabel: _l10n.updateAvailableTitle,
        title: Semantics(header: true, child: Text(_l10n.updateAvailableTitle)),
        content: Semantics(
          label: _l10n.newVersionSemantics(
            release.normalizedVersion,
            _currentAppVersion,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.newVersionText(
                  release.normalizedVersion,
                  _currentAppVersion,
                ),
              ),
              if (release.releaseSummary.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _l10n.whatIsNew,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(release.releaseSummary),
              ],
            ],
          ),
        ),
        actions: [
          Semantics(
            label: _l10n.later,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.later),
            ),
          ),
          Semantics(
            label: _l10n.showRelease,
            child: FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final url = release.htmlUrl;
                if (url != null) {
                  final uri = Uri.parse(url);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _s(
                            'Nelze otevřít prohlížeč: $e',
                            'Could not open browser: $e',
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(_l10n.showRelease),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewsDialog({GitHubReleaseInfo? initialFocusVersion}) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Novinky'),
      builder: (dialogContext) =>
          _NewsDialog(parent: this, initialFocusVersion: initialFocusVersion),
    );
  }

  void _initTts() async {
    try {
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final l10n = lookupAppLocalizations(locale);
      _lastTtsLocale = locale.languageCode == 'en' ? 'en-US' : 'cs-CZ';
      if (_ttsEngine != null) await tts.setEngine(_ttsEngine!);
      await tts.setLanguage(_lastTtsLocale!);
      if (_ttsVoice != null) await tts.setVoice(_ttsVoice!);
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_speechVolume);
      if (_sayWelcome) {
        speak(
          l10n.welcomeMessage(_getModeSpeechNameForL10n(_currentMode, l10n)),
        );
      }
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
    Future.delayed(const Duration(milliseconds: 1000), () async {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('accessibilityType')) {
        _showInitialAccessibilityDialog();
      }
      if (!prefs.containsKey('modeQuestionAsked')) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showInitialModeDialog();
        });
      }
    });
  }

  void _showInitialModeDialog() {
    speak(
      _s(
        'Jaký režim nejčastěji používáte?',
        'Which mode do you use most often?',
      ),
    );
    showDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Výběr režimu'),
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        semanticLabel: _s(
          'Jaký režim nejčastěji používáte?',
          'Which mode do you use most often?',
        ),
        title: Semantics(
          header: true,
          child: Text(
            _s(
              'Jaký režim nejčastěji používáte?',
              'Which mode do you use most often?',
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CalculatorMode.values.map((mode) {
            final modeName = _getModeName(mode);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Semantics(
                label: '$modeName',
                child: ElevatedButton(
                  onPressed: () {
                    _setDefaultMode(mode);
                    setState(() => _currentMode = mode);
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setBool('modeQuestionAsked', true);
                    });
                    Navigator.of(dialogContext).pop();
                    speak(
                      _s(
                        'Výchozí režim nastaven na $modeName',
                        'Default mode set to $modeName',
                      ),
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _mainFocusNode.requestFocus();
                    });
                  },
                  child: Text(modeName),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
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
          _accessibleNavigation = WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .accessibleNavigation;
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
    if (text.isEmpty ||
        !ttsEnabled ||
        !mounted ||
        (_isScreenReaderActive && !force)) {
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
    final l10n = _l10n;
    String processed = text
        .replaceAll('.', ',')
        .replaceAll('\u03C0', l10n.piSpoken);
    processed = processed.replaceAllMapped(
      RegExp(r"(\d+(?:,\d+)?)E([+-])(\d+)"),
      (m) {
        int exp = int.parse(m[3]!);
        return '${m[1]} ${l10n.timesTenTo} '
            '${m[2] == '-' ? '${l10n.minusWord} ' : ''}$exp';
      },
    );
    return processed;
  }

  String _formatDmsSpeech(String dmsStr) {
    if (_isEnglish()) {
      return dmsStr
          .replaceAll('°', ', degrees, ')
          .replaceAll("'", ' minutes and ')
          .replaceAll('"', ' seconds');
    }
    return dmsStr
        .replaceAll('°', ' stupňů, ')
        .replaceAll("'", ' minut a ')
        .replaceAll('"', ' sekund')
        .replaceAll('.', ',');
  }

  void _handleKeyboardInput(KeyEvent event) {
    if (event is KeyDownEvent) {
      final char = event.character;
      final isControl = HardwareKeyboard.instance.isControlPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      // Když je aktivní screen reader (NVDA, JAWS, TalkBack),
      // jednoznakové klávesy (S, C, T, A, P, atd.) se předávají čtečce.
      // Zpracovávají se pouze Ctrl+ kombinace, čísla, operátory a navigační klávesy.
      if (_isScreenReaderActive && char != null && !isControl) {
        final String singleChar = char.toUpperCase();
        // Povolit číslice, desetinnou tečku a operátory + - * / ^ %
        if (RegExp(r'^[0-9.+\-*/^%]$').hasMatch(singleChar)) {
          _handleButtonPressed(singleChar, silent: true);
          return;
        }
        // Všechny ostatní jednoznakové klávesy nechat projít do screen readeru
        return;
      }

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
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyM) {
        if (_currentMode == CalculatorMode.statistics) {
          _handleMultipleStatisticsAddition();
        } else {
          _handleButtonPressed('M+');
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        if (_currentMode == CalculatorMode.statistics) {
          _addSingleValueToStats();
        } else {
          _insertMinute();
        }
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit1) {
        _changeMode(CalculatorMode.basic);
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit2) {
        _changeMode(CalculatorMode.scientific);
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit3) {
        _changeMode(CalculatorMode.statistics);
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit4) {
        _changeMode(CalculatorMode.electrician);
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit5) {
        _changeMode(CalculatorMode.unitConversion);
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.comma) {
        _showAccessibilityDialog();
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.tab) {
        if (isShift) {
          _cycleMode(-1);
        } else {
          _cycleMode(1);
        }
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
    speak(_l10n.degreesUnit);
  }

  void _insertMinute() {
    // Pokud je kurzor na konci a poslední znak je číslo, doplníme '
    RegExp lastDigit = RegExp(r'\d$');
    if (display.isNotEmpty &&
        lastDigit.hasMatch(display.substring(0, _cursorPosition))) {
      append("'", silent: true);
      speak(_l10n.minutesUnit);
      return;
    }
    append("'", silent: true);
    speak(_l10n.minutesUnit);
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
    speak(_l10n.cleared);
  }

  void append(String value, {bool silent = false}) {
    _insertAtCursor(value);
    if (!silent) speak(_getButtonName(value));
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
      speak(_l10n.savedToVariable(name));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.savedToVariable(name))));
      }
    } else if (_isRecallMode) {
      String valStr = _formatNumber(_memory[name]!).replaceAll('.', ',');
      append(_formatNumber(_memory[name]!), silent: true);
      speak(_l10n.recalledFromVariable(name, valStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.recalledFromVariable(name, valStr))),
        );
      }
      _isRecallMode = false;
    } else {
      append(name, silent: true);
      speak(_l10n.variableName(name));
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
      speak(_l10n.deleted);
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
          speak(_statsEmptyMessage());
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
          throw _ElectricianInputException(_l10n.elecInvalidResult);
        }

        final calculation = _selectedElectricianCalculation;

        final scaledData = _getScaledValueAndPrefix(result);
        final scaledValue = scaledData['value'] as double;
        final prefix = scaledData['prefix'] as String;

        // Formátování pro zobrazení s předponou
        String formattedValue = _formatNumber(scaledValue);
        String unit = '';
        switch (calculation) {
          case ElectricianCalculation.voltage:
            unit = 'V';
            break;
          case ElectricianCalculation.current:
            unit = 'A';
            break;
          case ElectricianCalculation.resistance:
            unit = '\u03A9';
            break; // Omega symbol
        }
        resStr = '$formattedValue $prefix$unit';

        final spokenResult = _formatSpokenNumber(scaledValue);
        final calculationName = _getElectricianCalculationName(calculation);
        final unitSpeech = _getElectricianUnitSpeech(
          calculation,
          scaledValue,
          prefix,
        );
        spoken = _l10n.elecResult(calculationName, spokenResult, unitSpeech);
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
          spoken = _l10n.resultIs(_formatDmsSpeech(resStr));
        } else {
          spoken = _l10n.resultIs(resStr.replaceAll('.', ','));
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
      String msg = _l10n.expressionNotUnderstood;
      if (e is _ElectricianInputException) {
        msg = e.message;
      } else if (e is _MathDomainException) {
        msg = e.message;
      } else {
        String errStr = e.toString().toLowerCase();
        if (errStr.contains('division by zero') ||
            errStr.contains('infinity')) {
          msg = _l10n.cannotDivideByZero;
        } else if (errStr.contains('range') ||
            errStr.contains('invalid argument')) {
          msg = _l10n.valueOutOfRange;
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
      processed = processed.replaceAllMapped(RegExp(r'_TAN_\((.+)\)'), (m) {
        final arg = m[1]!;
        // Tangens není definovaný pro 90° + k*180°. Díky chybě plovoucí
        // řádové čárky by jinak vrátil obrovské číslo místo chyby.
        final argDegrees = _evaluateExpression(arg);
        final normalized = ((argDegrees % 180) + 180) % 180;
        if ((normalized - 90).abs() < 1e-9) {
          throw _MathDomainException(
            _s(
              'Tangens není definovaný pro ${_formatNumber(argDegrees)} stupňů.',
              'Tangent is not defined for ${_formatNumber(argDegrees)} degrees.',
            ),
          );
        }
        return 'tan($arg*($PI_VAL/180))';
      });

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

    // PROCENTA: % jako postfixový operátor "/100"
    processed = processed.replaceAllMapped(RegExp(r'((?:\d+(?:\.\d+)?)|\))%'), (
      m,
    ) {
      final n = m[1]!;
      return n == ')' ? '$n/100' : '($n/100)';
    });

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
      hPrev = hCurr;
      hCurr = hNext;
      kPrev = kCurr;
      kCurr = kNext;
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
    // Normalizace zaokrouhlovacích artefaktů plovoucí řádové čárky,
    // aby např. ASIN(0,5) bylo 30°0'0", nikoli 29°59'60".
    double roundedTotal = totalSeconds.roundToDouble();
    int wholeSeconds;
    double fracSeconds;
    if ((totalSeconds - roundedTotal).abs() < 1e-6) {
      wholeSeconds = roundedTotal.toInt();
      fracSeconds = 0.0;
    } else {
      wholeSeconds = totalSeconds.floor();
      fracSeconds = totalSeconds - wholeSeconds;
    }
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
        _l10n.unitConverted(
          _getUnitSpeech(_unitFrom, context: 'z'),
          _getUnitSpeech(_unitTo, context: 'na'),
          resStr,
          _getUnitSpeech(_unitTo, value: result),
        ),
        force: true,
      );
    } catch (e) {
      speak(_l10n.conversionError, force: true);
    }
  }

  String _getUnitSpeech(
    String unitCode, {
    double? value,
    String context = 'base',
  }) {
    if (_isEnglish()) {
      final en = _unitSpeechDataEn[unitCode];
      if (en == null) {
        return unitCode;
      }
      if (value != null) {
        return value.abs() == 1 ? en['base']! : en['plural']!;
      }
      return context == 'base' ? en['base']! : en['plural']!;
    }
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
    _modeUsageCounts[mode.index]++;
    _totalModeSwitches++;
    _saveModeUsage();
    _maybeSuggestFavoriteMode();
    String speech = _l10n.switchedToMode(_getModeSpeechName(mode));
    if (mode == CalculatorMode.statistics) {
      if (!_hasStatsSet) {
        speech +=
            '. ' +
            _s(
              'Zatím nemáte vytvořenou žádnou statistickou sadu. Vytvořte ji stisknutím tlačítka SETS.',
              'You have no statistical sets created yet. Create one by pressing the SETS button.',
            );
      } else if (_statsMemory.isEmpty) {
        final setName = _statsSets[_currentStatsSetIndex].name;
        speech +=
            '. ' +
            _s(
              'Aktivní sada "$setName" je prázdná. Přidejte data pomocí tlačítka M plus.',
              'The active set "$setName" is empty. Add data using the M+ button.',
            );
      } else {
        final set = _statsSets[_currentStatsSetIndex];
        final count = _statsMemory.length;
        final countForm = _getStatsCountForm(count);
        final fieldsLabel = set.fieldNames
            .asMap()
            .entries
            .map((e) {
              final unitCode = e.key < set.fieldUnits.length
                  ? set.fieldUnits[e.key]
                  : null;
              return unitCode != null
                  ? '${e.value}, ${_getUnitSpeech(unitCode)}'
                  : e.value;
            })
            .join(', ');
        speech +=
            '. ' +
            _s(
              'Aktivní sada "${set.name}" obsahuje $count $countForm. Pole: $fieldsLabel.',
              'The active set "${set.name}" contains $count $countForm. Fields: $fieldsLabel.',
            );
      }
    }
    speak(speech);
  }

  void _cycleMode(int direction) {
    final values = CalculatorMode.values;
    final currentIndex = values.indexOf(_currentMode);
    final newIndex = (currentIndex + direction) % values.length;
    _changeMode(values[newIndex]);
  }

  void _maybeSuggestFavoriteMode() {
    if (!mounted || _totalModeSwitches < 20) {
      return;
    }

    int topIndex = 0;
    for (var i = 1; i < _modeUsageCounts.length; i++) {
      if (_modeUsageCounts[i] > _modeUsageCounts[topIndex]) {
        topIndex = i;
      }
    }

    final topCount = _modeUsageCounts[topIndex];
    if (topIndex == _defaultMode.index || topCount <= 0) {
      return;
    }

    final sortedCounts = List<int>.from(_modeUsageCounts)
      ..sort((a, b) => b.compareTo(a));
    final secondCount = sortedCounts.length > 1 ? sortedCounts[1] : 0;

    final clearlyAhead =
        topCount >= (_totalModeSwitches * 0.4) && topCount >= secondCount * 2;

    if (!clearlyAhead || _lastSuggestedMode == topIndex) {
      return;
    }

    _showFavoriteModeSuggestionDialog(CalculatorMode.values[topIndex]);
  }

  void _showFavoriteModeSuggestionDialog(CalculatorMode mode) {
    final modeName = _getModeName(mode);
    _saveSuggestedMode(mode.index);
    showDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Nejpoužívanější režim'),
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        semanticLabel: _s('Nejpoužívanější režim', 'Most used mode'),
        title: Semantics(
          header: true,
          child: Text(_s('Nejpoužívanější režim', 'Most used mode')),
        ),
        content: Focus(
          autofocus: true,
          child: Semantics(
            label: _s(
              'Nejvíce používáte režim $modeName. Chcete ho nastavit jako výchozí režim po spuštění?',
              'You most often use the $modeName. Do you want to set it as the default mode on startup?',
            ),
            child: Text(
              _s(
                'Nejvíce používáte režim $modeName.\nChcete ho nastavit jako výchozí režim po spuštění?',
                'You most often use the $modeName.\nDo you want to set it as the default mode on startup?',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _saveSuggestedMode(mode.index);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _mainFocusNode.requestFocus();
              });
            },
            child: Text(_s('Ne', 'No')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _setDefaultMode(mode);
              speak(
                _s(
                  'Výchozí režim nastaven na $modeName',
                  'Default mode set to $modeName',
                ),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _mainFocusNode.requestFocus();
              });
            },
            child: Text(_s('Ano, nastavit', 'Yes, set it')),
          ),
        ],
      ),
    );
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
      final ttsVoiceJson = prefs.getString('ttsVoice');
      if (ttsVoiceJson != null) {
        try {
          final voiceMap = Map<String, dynamic>.from(jsonDecode(ttsVoiceJson));
          _ttsVoice = voiceMap.cast<String, String>();
          _ttsVoiceName = voiceMap['name'] as String?;
        } catch (e) {
          _ttsVoice = null;
          _ttsVoiceName = null;
        }
      } else {
        _ttsVoice = null;
        _ttsVoiceName = null;
      }
      _inverseFormatPreference = prefs.getInt('inverseFormatPreference');
      final savedDefaultMode = prefs.getInt('defaultMode');
      if (savedDefaultMode != null &&
          savedDefaultMode >= 0 &&
          savedDefaultMode < CalculatorMode.values.length) {
        _defaultMode = CalculatorMode.values[savedDefaultMode];
        _currentMode = _defaultMode;
      }
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
      final savedUsageJson = prefs.getString('modeUsageCounts');
      if (savedUsageJson != null) {
        try {
          final counts = (jsonDecode(savedUsageJson) as List<dynamic>)
              .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
              .toList();
          while (counts.length < CalculatorMode.values.length) {
            counts.add(0);
          }
          _modeUsageCounts = List<int>.from(
            counts.sublist(0, CalculatorMode.values.length),
          );
        } catch (e) {
          _modeUsageCounts = List<int>.filled(CalculatorMode.values.length, 0);
        }
      }
      _totalModeSwitches = _modeUsageCounts.fold(0, (a, b) => a + b);
      _lastSeenNewsVersion = prefs.getString('lastSeenNewsVersion');
      final savedSuggestedMode = prefs.getInt('lastSuggestedMode');
      if (savedSuggestedMode != null &&
          savedSuggestedMode >= 0 &&
          savedSuggestedMode < CalculatorMode.values.length) {
        _lastSuggestedMode = savedSuggestedMode;
      }
    });
    await tts.setSpeechRate(_speechRate);
    await tts.setVolume(_speechVolume);
    if (_ttsEngine != null) await tts.setEngine(_ttsEngine!);
    if (_ttsVoice != null) await tts.setVoice(_ttsVoice!);
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
    if (_ttsVoice != null) {
      await prefs.setString('ttsVoice', jsonEncode(_ttsVoice));
    } else {
      await prefs.remove('ttsVoice');
    }
    await prefs.setInt('screenReaderModeState', _screenReaderMode.index);
    await prefs.setInt('dialogSize', _dialogSize.index);
    await prefs.setInt('defaultMode', _defaultMode.index);
  }

  void _setDefaultMode(CalculatorMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultMode', mode.index);
    setState(() => _defaultMode = mode);
  }

  Future<void> _saveModeUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('modeUsageCounts', jsonEncode(_modeUsageCounts));
  }

  Future<void> _markNewsSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSeenNewsVersion', version);
    _lastSeenNewsVersion = version;
  }

  Future<void> _saveSuggestedMode(int modeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSuggestedMode', modeIndex);
    _lastSuggestedMode = modeIndex;
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
    speak(ttsEnabled ? _l10n.voiceOn : _l10n.voiceOff);
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
        decoded.forEach(
          (key, value) => _memory[key] = (value as num).toDouble(),
        );
      }
    });
  }

  void _saveStatsData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'statsSets',
      jsonEncode(_statsSets.map((s) => s.toJson()).toList()),
    );
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
        ShareParams(files: [XFile(file.path)], subject: _l10n.backupData),
      );

      speak(_l10n.backupSuccess, force: true);
    } catch (e) {
      debugPrint('Chyba při vytváření zálohy: $e');
      speak(_l10n.backupError, force: true);
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
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
            entry.key,
            value.map((e) => e.toString()).toList(),
          );
        }
      }

      _loadSettings();
      _loadHistory();
      _loadStatsData();
      setState(() {});
      speak(_l10n.restoreSuccess, force: true);
    } catch (e) {
      debugPrint('Chyba při obnově dat: $e');
      speak(_l10n.restoreError, force: true);
    }
  }

  void _showInitialAccessibilityDialog() {
    showDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Vítejte'),
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        semanticLabel: _s('Vítejte', 'Welcome'),
        title: Semantics(header: true, child: Text(_s('Vítejte', 'Welcome'))),
        content: Text(
          _s(
            'Vyberte požadovanou úroveň usnadnění. Toto nastavení můžete kdykoliv změnit v nastavení.',
            'Select the desired accessibility level. You can change this at any time in the settings.',
          ),
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
            child: Text(_s('STANDARDNÍ', 'STANDARD')),
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
            child: Text(_s('PRO NEVIDOMÉ', 'FOR THE BLIND')),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Nastavení přístupnosti'),
      builder: (context) => _AccessibilityDialog(parent: this),
    );
  }

  void _openTtsSystemSettings() async {
    try {
      if (Platform.isAndroid) {
        const channel = MethodChannel(
          'com.example.mluvici_kalkulacka/tts_settings',
        );
        await channel.invokeMethod('openTtsSettings');
      } else if (Platform.isWindows) {
        await launchUrl(Uri.parse('ms-settings:speech'));
      }
    } catch (e) {
      debugPrint('openTtsSettings Error: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Chyba'),
        builder: (context) => AlertDialog(
          semanticLabel: _s('Chyba', 'Error'),
          title: Semantics(header: true, child: Text(_s('Chyba', 'Error'))),
          content: Focus(
            autofocus: true,
            child: Semantics(
              label: _s(
                'Nelze otevřít systémové nastavení TTS.',
                'Could not open system TTS settings.',
              ),
              child: Text(
                _s(
                  'Nelze otevřít systémové nastavení TTS.',
                  'Could not open system TTS settings.',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showTtsEngineDialog() async {
    try {
      final engines = await tts.getEngines;
      if (!mounted) return;

      showDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Vybrat TTS engine'),
        builder: (context) => AlertDialog(
          semanticLabel: 'Vybrat TTS engine',
          title: const Text('Vybrat TTS engine'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: engines.length,
              itemBuilder: (context, index) {
                final engine = engines[index].toString();
                final isSelected = _ttsEngine == engine;
                return Semantics(
                  container: true,
                  label:
                      '${_s("Engine", "Engine")}: $engine${isSelected ? _s(", vybráno", ", selected") : ""}',
                  selected: isSelected,
                  child: ListTile(
                    title: Text(engine),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _ttsEngine = engine);
                      _saveSettings();
                      tts.setEngine(engine);
                      Navigator.pop(context);
                    },
                  ),
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
        routeSettings: const RouteSettings(name: 'Chyba'),
        builder: (context) => AlertDialog(
          semanticLabel: _s('Chyba', 'Error'),
          title: Semantics(header: true, child: Text(_s('Chyba', 'Error'))),
          content: Focus(
            autofocus: true,
            child: Semantics(
              label: _s(
                'Výběr TTS enginu není na tomto zařízení nebo verzi aplikace podporován.',
                'TTS engine selection is not supported on this device or app version.',
              ),
              child: Text(
                _s(
                  'Výběr TTS enginu není na tomto zařízení nebo verzi aplikace podporován.',
                  'TTS engine selection is not supported on this device or app version.',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_s('Zavřít', 'Close')),
            ),
          ],
        ),
      );
    }
  }

  void _showTtsVoiceDialog() async {
    try {
      final voices = await tts.getVoices;
      if (!mounted) return;

      if (voices == null || voices is! List || voices.isEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          routeSettings: const RouteSettings(name: 'Info'),
          builder: (context) => AlertDialog(
            semanticLabel: _s('Info', 'Info'),
            title: Semantics(header: true, child: Text(_s('Info', 'Info'))),
            content: Focus(
              autofocus: true,
              child: Semantics(
                label: _s(
                  'Nejsou k dispozici žádné hlasy pro aktuální jazyk.',
                  'No voices are available for the current language.',
                ),
                child: Text(
                  _s(
                    'Nejsou k dispozici žádné hlasy pro aktuální jazyk.',
                    'No voices are available for the current language.',
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_s('OK', 'OK')),
              ),
            ],
          ),
        );
        return;
      }

      final currentLang = _isEnglish() ? 'en-US' : 'cs-CZ';
      final filteredVoices = voices
          .cast<Map<dynamic, dynamic>>()
          .where((v) => v['locale'] == currentLang)
          .toList();

      if (filteredVoices.isEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          routeSettings: const RouteSettings(name: 'Info'),
          builder: (context) => AlertDialog(
            semanticLabel: _s('Info', 'Info'),
            title: Semantics(header: true, child: Text(_s('Info', 'Info'))),
            content: Focus(
              autofocus: true,
              child: Semantics(
                label: _s(
                  'Nejsou k dispozici žádné hlasy pro aktuální jazyk.',
                  'No voices are available for the current language.',
                ),
                child: Text(
                  _s(
                    'Nejsou k dispozici žádné hlasy pro aktuální jazyk.',
                    'No voices are available for the current language.',
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_s('OK', 'OK')),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Vybrat hlas'),
        builder: (context) => AlertDialog(
          semanticLabel: _s('Vybrat hlas', 'Select voice'),
          title: Text(_s('Vybrat hlas', 'Select voice')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredVoices.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _ttsVoice == null;
                  return Semantics(
                    container: true,
                    label:
                        '${_s("Výchozí hlas", "Default voice")}${isSelected ? _s(", vybráno", ", selected") : ""}',
                    selected: isSelected,
                    child: ListTile(
                      title: Text(_s('Výchozí', 'Default')),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _ttsVoice = null;
                          _ttsVoiceName = null;
                        });
                        _saveSettings();
                        tts.clearVoice();
                        Navigator.pop(context);
                      },
                    ),
                  );
                }
                final voice = filteredVoices[index - 1];
                final name = voice['name']?.toString() ?? '';
                String label = name;
                final quality = voice['quality']?.toString();
                final gender = voice['gender']?.toString();
                if (quality != null && quality.isNotEmpty) {
                  label += ' ($quality';
                  if (gender != null && gender.isNotEmpty) {
                    label += ', $gender';
                  }
                  label += ')';
                } else if (gender != null && gender.isNotEmpty) {
                  label += ' ($gender)';
                }
                final isSelected =
                    _ttsVoice?['name'] == name &&
                    _ttsVoice?['locale'] == voice['locale'];
                return Semantics(
                  container: true,
                  label:
                      '${_s("Hlas", "Voice")}: $label${isSelected ? _s(", vybráno", ", selected") : ""}',
                  selected: isSelected,
                  child: ListTile(
                    title: Text(label),
                    selected: isSelected,
                    onTap: () {
                      final voiceMap = <String, String>{
                        'name': name,
                        'locale': voice['locale']?.toString() ?? '',
                      };
                      setState(() {
                        _ttsVoice = voiceMap;
                        _ttsVoiceName = name;
                      });
                      _saveSettings();
                      tts.setVoice(voiceMap);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('TTS Voice Error: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Chyba'),
        builder: (context) => AlertDialog(
          semanticLabel: _s('Chyba', 'Error'),
          title: Semantics(header: true, child: Text(_s('Chyba', 'Error'))),
          content: Focus(
            autofocus: true,
            child: Semantics(
              label: _s(
                'Výběr hlasu není na tomto zařízení nebo verzi aplikace podporován.',
                'Voice selection is not supported on this device or app version.',
              ),
              child: Text(
                _s(
                  'Výběr hlasu není na tomto zařízení nebo verzi aplikace podporován.',
                  'Voice selection is not supported on this device or app version.',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_s('OK', 'OK')),
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
      routeSettings: RouteSettings(name: l10n.helpTitle),
      builder: (context) => AlertDialog(
        semanticLabel: l10n.helpTitle,
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

  void _showStatisticsHelpDialog() {
    final l10n = _l10n;

    Widget _section(String title, List<String> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(t),
            ),
          ),
        ],
      );
    }

    final ttsText = l10n.statsHelpText;

    showDialog(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsHelpTitle),
      builder: (context) => AlertDialog(
        semanticLabel: l10n.statsHelpTitle,
        title: Semantics(header: true, child: Text(l10n.statsHelpTitle)),
        content: Semantics(
          container: true,
          label: ttsText,
          liveRegion: true,
          child: Focus(
            autofocus: true,
            onFocusChange: (hasFocus) {
              if (hasFocus && !_isScreenReaderActive) speak(ttsText);
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _section(l10n.statsHelpKeyboardSection, [
                    l10n.statsHelpKeyboardSets,
                    l10n.statsHelpKeyboardMPlus,
                    l10n.statsHelpKeyboardMc,
                    l10n.statsHelpKeyboardMr,
                    l10n.statsHelpKeyboardStats,
                    l10n.statsHelpKeyboardSemicolon,
                  ]),
                  const Divider(),
                  _section(l10n.statsHelpAdvancedSection, [
                    l10n.statsHelpAdvancedMean,
                    l10n.statsHelpAdvancedSd,
                    l10n.statsHelpAdvancedVar,
                    l10n.statsHelpAdvancedSum,
                    l10n.statsHelpAdvancedMed,
                    l10n.statsHelpAdvancedMode,
                    l10n.statsHelpAdvancedCv,
                    l10n.statsHelpAdvancedWmean,
                  ]),
                  const Divider(),
                  _section(l10n.statsHelpFieldsSection, [
                    l10n.statsHelpFieldsDesc,
                  ]),
                  const Divider(),
                  _section(l10n.statsHelpWeightedMeanSection, [
                    l10n.statsHelpWeightedMeanDesc,
                  ]),
                  const Divider(),
                  _section(l10n.statsHelpTipsSection, [
                    '• ${l10n.statsHelpTip1}',
                    '• ${l10n.statsHelpTip2}',
                    '• ${l10n.statsHelpTip3}',
                    '• ${l10n.statsHelpTip4}',
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocusNode.requestFocus();
      });
    });
  }

  void _showPrecisionDialog(DisplayFormat format) {
    showDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Nastavení přesnosti'),
      builder: (context) => AlertDialog(
        semanticLabel: _l10n.precisionTitle,
        title: Semantics(header: true, child: Text(_l10n.precisionTitle)),
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
                speak(_l10n.decimalPlacesSet(i));
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
            child: Text(_l10n.cancel.toUpperCase()),
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
      descriptiveName += _isEnglish()
          ? ', tap to add value, long press to set repetition'
          : ', krátký stisk pro přidání hodnoty, dlouhý stisk pro zadání opakování';
      if (Platform.isWindows) {
        descriptiveName += _isEnglish()
            ? '. Press M to add, Ctrl+M for repetition'
            : '. Stiskněte M pro přidání, Ctrl+M pro opakování';
      }
    }
    if (label == 'PCT') {
      descriptiveName += _isEnglish()
          ? '. Enter value and whole separated by a semicolon, e.g. 30;200.'
          : '. Zadejte hodnotu a celek oddělené středníkem, např. 30;200.';
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).textScaleFactor;

    Widget buttonBody = Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.grey[800] : Colors.grey[300]),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black54, width: 0.5),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ExcludeSemantics(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20 * _fontSizeMultiplier * textScale,
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
      throw FormatException(
        _s(
          'Počet hodnot musí být násobkem počtu polí ($fieldCount).',
          'Number of values must be a multiple of field count ($fieldCount).',
        ),
      );
    }
    return records;
  }

  void _addSingleValueToStats() {
    if (!_hasStatsSet) {
      speak(
        _s(
          'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
          'No statistics set created. Enter a name for a new set first.',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _s(
                'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
                'No statistics set created. Enter a name for a new set first.',
              ),
            ),
          ),
        );
      }
      _showCreateStatsSetDialog(context, () {
        _addSingleValueToStats();
      });
      return;
    }
    if (display.isEmpty) {
      speak(
        _s(
          'Displej je prázdný. Zadejte číslo k uložení.',
          'Display is empty. Enter a number to store.',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _s(
                'Displej je prázdný. Zadejte číslo k uložení.',
                'Display is empty. Enter a number to store.',
              ),
            ),
          ),
        );
      }
      return;
    }
    try {
      final recordsToAdd = _parseDisplayToRecords(display);

      if (recordsToAdd.isEmpty) {
        speak(
          _s('Žádná platná čísla k uložení.', 'No valid numbers to store.'),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _s(
                  'Žádná platná čísla k uložení.',
                  'No valid numbers to store.',
                ),
              ),
            ),
          );
        }
        return;
      }

      _addValuesToStats(recordsToAdd, 1);
    } catch (e) {
      final msg = e is FormatException
          ? e.message
          : _s(
              'Chyba při ukládání do statistické paměti. Zkontrolujte formát dat.',
              'Error storing to statistics memory. Check the data format.',
            );
      speak(msg);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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
            final name = _getButtonName(label);
            if (['ASIN', 'ACOS', 'ATAN'].contains(label)) {
              speak(_l10n.inverseResult(name));
            } else {
              speak(_l10n.resultOf(name));
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
        speak(
          _s(
            'Tlačítko M plus je dostupné pouze ve statistickém režimu.',
            'The M+ button is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'MC') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          speak(_s('Není vytvořena žádná sada.', 'No set created.'));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _s('Není vytvořena žádná sada.', 'No set created.'),
                ),
              ),
            );
          }
          return;
        }
        setState(() {
          _statsMemory.clear();
        });
        _saveStatsData();
        final setName = _statsSets[_currentStatsSetIndex].name;
        speak(
          _s(
            'Paměť sady $setName byla smazána.',
            'Memory of set $setName was cleared.',
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _s(
                  'Paměť sady $setName byla smazána.',
                  'Memory of set $setName was cleared.',
                ),
              ),
            ),
          );
        }
      } else {
        speak(
          _s(
            'Tlačítko M C je dostupné pouze ve statistickém režimu.',
            'The MC button is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'MR') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          speak(_s('Není vytvořena žádná sada.', 'No set created.'));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _s('Není vytvořena žádná sada.', 'No set created.'),
                ),
              ),
            );
          }
          return;
        }
        if (_statsMemory.isEmpty) {
          speak(_statsEmptyMessage());
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_statsEmptyMessage())));
          }
        } else {
          _showStatisticsMemoryDialog();
        }
      } else {
        speak(
          _s(
            'Tlačítko M R je dostupné pouze ve statistickém režimu.',
            'The MR button is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'STATS') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          speak(_s('Není vytvořena žádná sada.', 'No set created.'));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _s('Není vytvořena žádná sada.', 'No set created.'),
                ),
              ),
            );
          }
          return;
        }
        if (_statsMemory.isEmpty) {
          speak(_statsEmptyMessage());
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_statsEmptyMessage())));
          }
        } else {
          _showStatisticsSummaryDialog();
        }
      } else {
        speak(
          _s(
            'Statistický souhrn je dostupný pouze ve statistickém režimu.',
            'Statistics summary is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'SETS') {
      if (_currentMode == CalculatorMode.statistics) {
        _showStatsSetsDialog();
      } else {
        speak(
          _s(
            'Správa sad je dostupná pouze ve statistickém režimu.',
            'Manage sets is available only in statistics mode.',
          ),
        );
      }
    } else if (_electricianCalculationFromButton(label) != null) {
      if (_currentMode == CalculatorMode.electrician) {
        _selectElectricianCalculation(
          _electricianCalculationFromButton(label)!,
        );
      } else {
        append(label, silent: silent);
      }
    } else if ([
      'MEAN',
      'SD',
      'VAR',
      'MED',
      'MODE',
      'CV',
      'SUM',
      'WMEAN',
    ].contains(label)) {
      if (_currentMode == CalculatorMode.statistics) {
        try {
          if (_statsMemory.isEmpty) {
            speak(_statsEmptyMessage());
            return;
          }

          final fieldNames = _statsSets[_currentStatsSetIndex].fieldNames;

          if (label == 'WMEAN') {
            if (_currentFieldCount < 2) {
              speak(
                _s(
                  'Vážený průměr vyžaduje alespoň 2 pole (hodnoty a váhy).',
                  'Weighted mean requires at least 2 fields (values and weights).',
                ),
              );
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
              speak(
                _s(
                  'Součet vah je nulový, nelze vypočítat vážený průměr.',
                  'Sum of weights is zero, cannot calculate weighted mean.',
                ),
              );
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
          final fieldUnit =
              _statsSets.isNotEmpty &&
                  _selectedFieldIndex <
                      _statsSets[_currentStatsSetIndex].fieldUnits.length
              ? _statsSets[_currentStatsSetIndex]
                    .fieldUnits[_selectedFieldIndex]
              : null;
          final fieldUnitSpoken = fieldUnit != null
              ? _s(
                  ' v ${_getUnitSpeech(fieldUnit, context: 'z')}',
                  ' in ${_getUnitSpeech(fieldUnit)}',
                )
              : '';
          final fieldLabelSpoken = _currentFieldCount > 1
              ? _s(
                  ' pro pole ${fieldNames[_selectedFieldIndex]}$fieldUnitSpoken',
                  ' for field ${fieldNames[_selectedFieldIndex]}$fieldUnitSpoken',
                )
              : fieldUnitSpoken;

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
              resStr = _formatNumber(
                _getFieldValues(_selectedFieldIndex).first,
              );
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
          speak(
            _s('Chyba statistického výpočtu.', 'Statistics calculation error.'),
            force: true,
          );
        }
      } else {
        append(label, silent: silent);
      }
    } else if (label == 'STO') {
      _isStoreMode = true;
      speak(_l10n.selectMemory);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.selectMemory)));
      }
    } else if (label == 'RCL') {
      _isRecallMode = true;
      speak(_l10n.selectMemoryRecall);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.selectMemoryRecall)));
      }
    } else if (label == 'CLR') {
      setState(() {
        _memory.updateAll((key, value) => 0);
      });
      _saveStatsData();
      speak(_l10n.memoryCleared);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.memoryCleared)));
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
      if (!silent) speak(_getButtonName(label));
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
          String spoken = _l10n.degreesUnit;
          if (symbol == '°') {
            nextSymbol = "'";
            spoken = _l10n.minutesUnit;
          } else if (symbol == "'") {
            nextSymbol = '"';
            spoken = _l10n.secondsUnit;
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
          String spoken = _l10n.degreesUnit;

          if (symbol == '°') {
            toInsert = "'";
            spoken = _l10n.minutesUnit;
          } else if (symbol == "'") {
            toInsert = '"';
            spoken = _l10n.secondsUnit;
          }

          append(toInsert, silent: true);
          speak(spoken);
        }
      } else {
        // Nenalezeno žádné číslo před kurzorem, vložíme výchozí stupně
        append('°', silent: true);
        speak(_l10n.degreesUnit);
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
          String spokenDms = _formatDmsSpeech(dmsStr);
          speak(_l10n.resultIs(spokenDms), force: true);
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
          speak(
            _l10n.resultIs(
              '${decimalStr.replaceAll('.', ',')} ${_l10n.degreesUnit}',
            ),
            force: true,
          );
        }
      } catch (e) {
        speak(_l10n.conversionError, force: true);
      }
    } else if (label == '\u03C0') {
      append(label, silent: silent);
    } else if (label == 'PCT') {
      _calculatePercentOf();
    } else {
      append(label, silent: silent);
    }
  }

  void _calculatePercentOf() {
    if (display.isEmpty) {
      speak(
        _s(
          'Displej je prázdný. Zadejte hodnotu a celek oddělené středníkem, např. 30;200.',
          'Display is empty. Enter value and whole separated by a semicolon, e.g. 30;200.',
        ),
        force: true,
      );
      return;
    }
    final originalDisplay = display;
    final parts = display
        .split(';')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length != 2) {
      speak(
        _s(
          'Zadejte dvě hodnoty oddělené středníkem: hodnota;celek.',
          'Enter two values separated by a semicolon: value;whole.',
        ),
        force: true,
      );
      return;
    }
    try {
      final value = _evaluateExpression(parts[0]);
      final whole = _evaluateExpression(parts[1]);
      if (whole == 0) {
        speak(
          _s('Celek nesmí být nula.', 'The whole must not be zero.'),
          force: true,
        );
        return;
      }
      final percent = value / whole * 100;
      final resStr = _formatNumber(percent);
      final spoken = _s(
        '${_formatSpokenNumber(value)} je ${_formatSpokenNumber(percent)} procent z ${_formatSpokenNumber(whole)}',
        '${_formatSpokenNumber(value)} is ${_formatSpokenNumber(percent)} percent of ${_formatSpokenNumber(whole)}',
      );
      setState(() {
        _lastResult = resStr;
        _hasResult = true;
        display = resStr;
        _cursorPosition = display.length;
        _lastNumericValue = percent;
      });
      speak(spoken, force: true);
      _addToHistory('PCT($originalDisplay)', resStr);
    } catch (e) {
      speak(
        _s(
          'Chyba výpočtu procent. Zkontrolujte zadané hodnoty.',
          'Percentage calculation error. Check the entered values.',
        ),
        force: true,
      );
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
          '%',
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
          '%',
          'DEL',
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
      child: FocusTraversalGroup(
        child: Column(
          children: rows.map((row) {
            return Expanded(
              child: FocusTraversalGroup(
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
                    } else if ([
                      'M+',
                      'MC',
                      'MR',
                      'STATS',
                      'SETS',
                    ].contains(b)) {
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
                        if (b == 'M+' &&
                            _currentMode == CalculatorMode.statistics) {
                          _addSingleValueToStats();
                        } else {
                          _handleButtonPressed(b);
                        }
                      },
                      onLongPressed:
                          (b == 'M+' &&
                              _currentMode == CalculatorMode.statistics)
                          ? _handleMultipleStatisticsAddition
                          : null,
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Semantics(
      label: _s('Přepínač režimů', 'Mode selector'),
      container: true,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: CalculatorMode.values.map((mode) {
              String label = _getModeName(mode);
              final isSelected = _currentMode == mode;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  label:
                      '$label${isSelected ? _s(', vybráno', ', selected') : ''}',
                  selected: isSelected,
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (s) {
                      if (s) {
                        _changeMode(mode);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showAdvancedFunctionsDialog() {
    showDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Pokročilé funkce'),
      builder: (context) => _AdvancedFunctionsDialog(parent: this),
    );
  }

  void _insertFromHistory(String value) {
    _insertAtCursor(value.replaceAll(',', '.'));
    speak(
      _s(
        'Vloženo ${value.replaceAll('.', ',')}',
        'Inserted ${value.replaceAll('.', ',')}',
      ),
    );
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mainFocusNode.requestFocus();
    });
  }

  void _removeStatsRecord(
    List<int> indices,
    StateSetter setStateDialog,
    BuildContext dialogContext,
  ) {
    setState(() {
      final sorted = List<int>.from(indices)..sort((a, b) => b.compareTo(a));
      for (final idx in sorted) {
        _statsSets[_currentStatsSetIndex].records.removeAt(idx);
      }
      if (_selectedFieldIndex >= _currentFieldCount) {
        _selectedFieldIndex = 0;
      }
    });
    _saveStatsData();
    setStateDialog(() {});
    final removedMsg = indices.length > 1
        ? _s(
            'Odebráno ${indices.length} ${_getStatsCountForm(indices.length)}',
            'Removed ${indices.length} ${_getStatsCountForm(indices.length)}',
          )
        : _s(
            'Odebrán záznam ${indices.first + 1}',
            'Removed record ${indices.first + 1}',
          );
    speak(removedMsg);
    if (mounted) {
      ScaffoldMessenger.of(
        dialogContext,
      ).showSnackBar(SnackBar(content: Text(removedMsg)));
    }
    if (_statsMemory.isEmpty) {
      speak(_statsEmptyMessage());
      if (mounted) {
        ScaffoldMessenger.of(
          dialogContext,
        ).showSnackBar(SnackBar(content: Text(_statsEmptyMessage())));
      }
      Navigator.pop(dialogContext);
    }
  }

  void _showEditStatsRecordDialog(
    List<int> recordIndices,
    BuildContext dialogContext,
    StateSetter setStateDialog,
  ) {
    final recordIndex = recordIndices.first;
    final record = _statsMemory[recordIndex];
    final currentSet = _statsSets[_currentStatsSetIndex];
    final fieldNames = currentSet.fieldNames;
    final fieldUnits = currentSet.fieldUnits;
    final controllers = record.values
        .map(
          (v) => TextEditingController(
            text: _formatNumber(v).replaceAll(',', '.'),
          ),
        )
        .toList();

    showDialog<void>(
      context: dialogContext,
      routeSettings: RouteSettings(
        name: _s(
          'Upravit záznam ${recordIndex + 1}',
          'Edit record ${recordIndex + 1}',
        ),
      ),
      builder: (ctx) {
        return AlertDialog(
          semanticLabel: _s(
            'Upravit záznam ${recordIndex + 1}',
            'Edit record ${recordIndex + 1}',
          ),
          title: Text(
            _s(
              'Upravit záznam ${recordIndex + 1}',
              'Edit record ${recordIndex + 1}',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(fieldNames.length, (i) {
                final unitCode = i < fieldUnits.length ? fieldUnits[i] : null;
                final label = unitCode != null
                    ? '${fieldNames[i]} (${_getUnitSpeech(unitCode)})'
                    : fieldNames[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    label: '$label (${_s("Pole ${i + 1}", "Field ${i + 1}")})',
                    child: TextField(
                      controller: controllers[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: label,
                        isDense: true,
                      ),
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
                    for (final idx in recordIndices) {
                      _statsSets[_currentStatsSetIndex].records[idx] =
                          StatisticsRecord(values: newValues);
                    }
                  });
                  _saveStatsData();
                  setStateDialog(() {});
                  Navigator.pop(ctx);
                  final editedMsg = recordIndices.length > 1
                      ? _s(
                          'Záznam ${recordIndex + 1} upraven. Změněno ${recordIndices.length} ${_getStatsCountForm(recordIndices.length)}.',
                          'Record ${recordIndex + 1} edited. Changed ${recordIndices.length} ${_getStatsCountForm(recordIndices.length)}.',
                        )
                      : _s(
                          'Záznam ${recordIndex + 1} upraven',
                          'Record ${recordIndex + 1} edited',
                        );
                  speak(editedMsg);
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(editedMsg)));
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
      routeSettings: RouteSettings(name: _l10n.statsMemoryTitle),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final currentSet = _statsSets[_currentStatsSetIndex];
            final currentSetName = currentSet.name;
            final fieldNames = currentSet.fieldNames;
            final fieldUnits = currentSet.fieldUnits;
            final totalCount = _statsMemory.length;
            final totalCountForm = _getStatsCountForm(totalCount);
            final records = List<StatisticsRecord>.from(_statsMemory);
            final groups = _groupStatsRecords(records);
            final freqFieldIndex = _selectedFieldIndex < fieldNames.length
                ? _selectedFieldIndex
                : 0;
            final freqSnapshot = records.isNotEmpty
                ? _computeStatisticsSnapshot(freqFieldIndex)
                : null;
            final showFrequencies =
                freqSnapshot != null &&
                (freqSnapshot.frequencies.length > 1 ||
                    freqSnapshot.frequencies.entries.first.value > 1);

            String spokenSummary;
            if (records.isEmpty) {
              spokenSummary = _s(
                'Statistická paměť sady $currentSetName je prázdná.',
                'Statistics memory for set $currentSetName is empty.',
              );
            } else {
              final fieldsSummary = fieldNames
                  .asMap()
                  .entries
                  .map((fe) {
                    final unitCode = fe.key < fieldUnits.length
                        ? fieldUnits[fe.key]
                        : null;
                    final vals = groups
                        .map((g) {
                          final r = records[g.first];
                          final v = _formatSpokenNumber(r.values[fe.key]);
                          final u = unitCode != null
                              ? ' ${_getUnitSpeech(unitCode, value: r.values[fe.key])}'
                              : '';
                          final countPart = g.length > 1
                              ? _s(
                                  ' ${g.length} ${_getStatsCountForm(g.length)}',
                                  ' ${g.length} ${_getStatsCountForm(g.length)}',
                                )
                              : '';
                          return '$v$u$countPart';
                        })
                        .join(_s('; ', '; '));
                    return '${fe.value}: $vals';
                  })
                  .join('. ');
              spokenSummary = _s(
                'Statistická paměť, sada $currentSetName. Obsahuje $totalCount $totalCountForm. '
                    'Pole: $fieldsSummary.',
                'Statistics memory, set $currentSetName. Contains $totalCount $totalCountForm. '
                    'Fields: $fieldsSummary.',
              );
              if (showFrequencies) {
                final freqUnit = freqFieldIndex < fieldUnits.length
                    ? fieldUnits[freqFieldIndex]
                    : null;
                final frequencySpoken = freqSnapshot.frequencies.entries
                    .map((e) {
                      final valStr = _formatSpokenNumber(e.key);
                      final unitStr = freqUnit != null
                          ? ' ${_getUnitSpeech(freqUnit, value: e.key)}'
                          : '';
                      return _s(
                        '$valStr$unitStr se vyskytuje ${e.value} krát',
                        '$valStr$unitStr occurs ${e.value} times',
                      );
                    })
                    .join(_s('; ', '; '));
                spokenSummary += _s(
                  ' Počet výskytů pole ${fieldNames[freqFieldIndex]}: $frequencySpoken.',
                  ' Occurrences for field ${fieldNames[freqFieldIndex]}: $frequencySpoken.',
                );
              }
            }

            return AlertDialog(
              semanticLabel: l10n.statsMemoryTitle,
              title: Semantics(
                header: true,
                child: Text(l10n.statsMemoryTitle),
              ),
              content: Semantics(
                container: true,
                label: spokenSummary,
                liveRegion: true,
                child: Focus(
                  autofocus: true,
                  onFocusChange: (hasFocus) {
                    if (hasFocus && !_isScreenReaderActive)
                      speak(spokenSummary);
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 8),
                            ExcludeSemantics(
                              child: Text(
                                _s(
                                  'Záznamů: $totalCount, Polí: ${fieldNames.length}',
                                  'Records: $totalCount, Fields: ${fieldNames.length}',
                                ),
                              ),
                            ),
                            if (records.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                header: true,
                                label: _s(
                                  'Sloupce: číslo, ${fieldNames.join(', ')}, počet',
                                  'Columns: number, ${fieldNames.join(', ')}, count',
                                ),
                                child: ExcludeSemantics(
                                  child: DefaultTextStyle.merge(
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    child: _buildMemoryHeaderRow(
                                      fieldNames,
                                      fieldUnits,
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(height: 16),
                              ...groups.asMap().entries.map((gEntry) {
                                final groupIndex = gEntry.key;
                                final group = gEntry.value;
                                final record = records[group.first];
                                final count = group.length;
                                final spokenValues = record.values
                                    .asMap()
                                    .entries
                                    .map((ve) {
                                      final unitCode =
                                          ve.key < fieldUnits.length
                                          ? fieldUnits[ve.key]
                                          : null;
                                      final unitStr = unitCode != null
                                          ? ' ${_getUnitSpeech(unitCode, value: ve.value)}'
                                          : '';
                                      return '${fieldNames[ve.key]}: ${_formatSpokenNumber(ve.value)}$unitStr';
                                    })
                                    .join(', ');

                                final rowLabel = _s(
                                  'Záznam ${groupIndex + 1}: $spokenValues. Počet výskytů: $count',
                                  'Record ${groupIndex + 1}: $spokenValues. Occurrences: $count',
                                );
                                return Semantics(
                                  container: true,
                                  label: rowLabel,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        ExcludeSemantics(
                                          child: SizedBox(
                                            width: 28,
                                            child: Text(
                                              '${groupIndex + 1}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        ...record.values.asMap().entries.map((
                                          ve,
                                        ) {
                                          final unitCode =
                                              ve.key < fieldUnits.length
                                              ? fieldUnits[ve.key]
                                              : null;
                                          final unitStr = unitCode != null
                                              ? ' ${_getUnitSpeech(unitCode, value: ve.value)}'
                                              : '';
                                          return Expanded(
                                            child: ExcludeSemantics(
                                              child: Text(
                                                '${_formatNumber(ve.value)}$unitStr',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                        Expanded(
                                          child: ExcludeSemantics(
                                            child: Text(
                                              '$count×',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Semantics(
                                          label: rowLabel,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                  color: Colors.blue,
                                                ),
                                                tooltip: _s(
                                                  'Upravit záznam ${groupIndex + 1}',
                                                  'Edit record ${groupIndex + 1}',
                                                ),
                                                onPressed: () =>
                                                    _showEditStatsRecordDialog(
                                                      group,
                                                      dialogContext,
                                                      setStateDialog,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: const Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                                tooltip: _s(
                                                  'Smazat záznam ${groupIndex + 1}',
                                                  'Delete record ${groupIndex + 1}',
                                                ),
                                                onPressed: () =>
                                                    _removeStatsRecord(
                                                      group,
                                                      setStateDialog,
                                                      dialogContext,
                                                    ),
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

  Widget _buildMemoryHeaderRow(
    List<String> fieldNames, [
    List<String?>? fieldUnits,
  ]) {
    return Row(
      children: [
        const SizedBox(
          width: 28,
          child: Text('#', style: TextStyle(fontSize: 12)),
        ),
        ...fieldNames.asMap().entries.map((e) {
          final name = e.value;
          final unitCode = fieldUnits != null && e.key < fieldUnits.length
              ? fieldUnits[e.key]
              : null;
          final label = unitCode != null
              ? '$name (${_getUnitSpeech(unitCode)})'
              : name;
          return Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          );
        }),
        Expanded(
          child: Text(
            _s('Počet', 'Count'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ),
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

  String _buildStatsSummarySpeech(int fieldIndex) {
    final snapshot = _computeStatisticsSnapshot(fieldIndex);
    if (snapshot == null) return '';
    final currentSetName = _statsSets[_currentStatsSetIndex].name;
    final fieldNames = _statsSets[_currentStatsSetIndex].fieldNames;
    final selectedFieldName = fieldNames[fieldIndex];
    final fieldUnit =
        fieldIndex < _statsSets[_currentStatsSetIndex].fieldUnits.length
        ? _statsSets[_currentStatsSetIndex].fieldUnits[fieldIndex]
        : null;
    final rawValues = _getFieldValues(fieldIndex);
    final allValuesSpoken = rawValues
        .map((v) {
          final numStr = _formatSpokenNumber(v);
          final unitStr = fieldUnit != null
              ? ' ${_getUnitSpeech(fieldUnit, value: v)}'
              : '';
          return '$numStr$unitStr';
        })
        .join(_isEnglish() ? ', ' : '; ');
    final dataCount = rawValues.length;
    final modeSpoken = snapshot.modeExists
        ? snapshot.modes
              .map((m) => _formatSpokenNumber(m))
              .join(_s(' a ', ' and '))
        : _l10n.statsModeNone;
    final cvSpoken = snapshot.cv == null
        ? _s('nelze vypočítat', 'cannot calculate')
        : '${_formatSpokenNumber(snapshot.cv!)} ${_s('procent', 'percent')}';
    final wmeanSpoken = snapshot.wmean == null
        ? null
        : _formatSpokenNumber(snapshot.wmean!);

    String spokenSummary = _s(
      'Statistický souhrn pro sadu $currentSetName, pole $selectedFieldName. '
          'Počet hodnot: $dataCount. '
          'Všechny hodnoty: $allValuesSpoken. '
          'Průměr: ${_formatSpokenNumber(snapshot.mean)}. '
          'Součet: ${_formatSpokenNumber(snapshot.sum)}. '
          'Rozptyl: ${_formatSpokenNumber(snapshot.variance)}. '
          'Směrodatná odchylka: ${_formatSpokenNumber(snapshot.sd)}. '
          'Medián: ${_formatSpokenNumber(snapshot.median)}. '
          'Modus: $modeSpoken. '
          'Variační koeficient: $cvSpoken.',
      'Statistics summary for set $currentSetName, field $selectedFieldName. '
          'Count: $dataCount. '
          'All values: $allValuesSpoken. '
          'Mean: ${_formatSpokenNumber(snapshot.mean)}. '
          'Sum: ${_formatSpokenNumber(snapshot.sum)}. '
          'Variance: ${_formatSpokenNumber(snapshot.variance)}. '
          'Standard deviation: ${_formatSpokenNumber(snapshot.sd)}. '
          'Median: ${_formatSpokenNumber(snapshot.median)}. '
          'Mode: $modeSpoken. '
          'Coefficient of variation: $cvSpoken.',
    );
    if (snapshot.wmean != null) {
      final fieldNamesForWmean = _statsSets[_currentStatsSetIndex].fieldNames;
      spokenSummary += _s(
        ' Vážený průměr: $wmeanSpoken (pole ${fieldNamesForWmean[0]} váženo polem ${fieldNamesForWmean[1]}).',
        ' Weighted mean: $wmeanSpoken (field ${fieldNamesForWmean[0]} weighted by field ${fieldNamesForWmean[1]}).',
      );
    }
    return spokenSummary;
  }

  void _showStatisticsSummaryDialog() {
    _statsSummaryInitialized = false;
    final l10n = _l10n;
    final fieldNames = _statsSets.isNotEmpty
        ? _statsSets[_currentStatsSetIndex].fieldNames
        : <String>['Hodnota'];

    showDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsSummaryTitle),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSummaryState) {
            final snapshot = _computeStatisticsSnapshot(_selectedFieldIndex);
            if (snapshot == null) {
              speak(_statsEmptyMessage());
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(_statsEmptyMessage())));
              }
              Navigator.pop(dialogContext);
              return const SizedBox.shrink();
            }
            final currentSetName = _statsSets[_currentStatsSetIndex].name;
            final selectedFieldName = fieldNames[_selectedFieldIndex];
            final fieldUnit =
                _statsSets.isNotEmpty &&
                    _selectedFieldIndex <
                        _statsSets[_currentStatsSetIndex].fieldUnits.length
                ? _statsSets[_currentStatsSetIndex]
                      .fieldUnits[_selectedFieldIndex]
                : null;
            final rawValues = _getFieldValues(_selectedFieldIndex);
            final allValues = rawValues
                .map((v) {
                  final numStr = _formatNumber(v);
                  final unitStr = fieldUnit != null
                      ? ' ${_getUnitSpeech(fieldUnit, value: v)}'
                      : '';
                  return '$numStr$unitStr';
                })
                .join(_isEnglish() ? ', ' : '; ');
            final allValuesSpoken = rawValues
                .map((v) {
                  final numStr = _formatSpokenNumber(v);
                  final unitStr = fieldUnit != null
                      ? ' ${_getUnitSpeech(fieldUnit, value: v)}'
                      : '';
                  return '$numStr$unitStr';
                })
                .join(_isEnglish() ? ', ' : '; ');
            final dataCount = rawValues.length;

            final modeText = snapshot.modeExists
                ? snapshot.modes.map((m) => _formatNumber(m)).join('; ')
                : l10n.statsModeNone;

            final cvText = snapshot.cv == null
                ? 'Err'
                : '${_formatNumber(snapshot.cv!)} %';

            final wmeanText = snapshot.wmean == null
                ? null
                : _formatNumber(snapshot.wmean!);

            final statRows = <MapEntry<String, String>>[
              MapEntry(l10n.statsN, dataCount.toString()),
              MapEntry(l10n.statsMean, _formatNumber(snapshot.mean)),
              if (snapshot.wmean != null)
                MapEntry(l10n.statsWeightedMean, wmeanText!),
              MapEntry(l10n.statsSum, _formatNumber(snapshot.sum)),
              MapEntry(l10n.statsVariance, _formatNumber(snapshot.variance)),
              MapEntry(l10n.statsStdDev, _formatNumber(snapshot.sd)),
              MapEntry(l10n.statsMedian, _formatNumber(snapshot.median)),
              MapEntry(l10n.statsMode, modeText),
              MapEntry(l10n.statsCv, cvText),
            ];

            final spokenSummary = _buildStatsSummarySpeech(_selectedFieldIndex);

            if (!_statsSummaryInitialized) {
              _statsSummaryInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isScreenReaderActive) speak(spokenSummary);
              });
            }

            return AlertDialog(
              semanticLabel: l10n.statsSummaryTitle,
              title: Semantics(
                header: true,
                child: Text(l10n.statsSummaryTitle),
              ),
              content: Semantics(
                container: true,
                label: spokenSummary,
                liveRegion: true,
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (fieldNames.length > 1) ...[
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                final nextIndex =
                                    (_selectedFieldIndex + 1) %
                                    fieldNames.length;
                                final nextSummary = _buildStatsSummarySpeech(
                                  nextIndex,
                                );
                                setState(() => _selectedFieldIndex = nextIndex);
                                setSummaryState(() {});
                                speak(
                                  _s(
                                        'Vybráno pole ${fieldNames[nextIndex]}. ',
                                        'Selected field ${fieldNames[nextIndex]}. ',
                                      ) +
                                      nextSummary,
                                );
                              },
                              child: Semantics(
                                liveRegion: true,
                                label: _s(
                                  'Pole: ${fieldNames[_selectedFieldIndex]}${fieldUnit != null ? ', ${_getUnitSpeech(fieldUnit)}' : ''}',
                                  'Field: ${fieldNames[_selectedFieldIndex]}${fieldUnit != null ? ', ${_getUnitSpeech(fieldUnit)}' : ''}',
                                ),
                                excludeSemantics: true,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(_s('Pole: ', 'Field: ')),
                                      const SizedBox(width: 4),
                                      Text(
                                        fieldNames[_selectedFieldIndex],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (fieldUnit != null) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${_getUnitSpeech(fieldUnit)})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 4),
                                      Icon(Icons.swap_horiz, size: 14),
                                    ],
                                  ),
                                ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(row.key)),
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
      routeSettings: RouteSettings(name: l10n.statsSetsTitle),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              semanticLabel: l10n.statsSetsTitle,
              title: Semantics(header: true, child: Text(l10n.statsSetsTitle)),
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

                            final fieldsLabel = set.fieldNames
                                .asMap()
                                .entries
                                .map((e) {
                                  final unitCode = e.key < set.fieldUnits.length
                                      ? set.fieldUnits[e.key]
                                      : null;
                                  final name = e.value;
                                  return unitCode != null
                                      ? '$name, ${_getUnitSpeech(unitCode)}'
                                      : name;
                                })
                                .join(', ');
                            final semanticsLabel = isCurrent
                                ? '${set.name}, $count $countForm. Pole: $fieldsLabel. Vybráno jako aktivní sada.'
                                : '${set.name}, $count $countForm. Pole: $fieldsLabel. Poklepáním vyberete jako aktivní sadu.';

                            final fieldsText = set.fieldNames
                                .asMap()
                                .entries
                                .map((e) {
                                  final unitCode = e.key < set.fieldUnits.length
                                      ? set.fieldUnits[e.key]
                                      : null;
                                  return unitCode != null
                                      ? '${e.value} (${_getUnitSpeech(unitCode)})'
                                      : e.value;
                                })
                                .join(', ');

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
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                subtitle: ExcludeSemantics(
                                  child: Text(
                                    fieldsText,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.view_list),
                                      tooltip: _s(
                                        'Upravit pole',
                                        'Edit fields',
                                      ),
                                      onPressed: () {
                                        _showEditStatsSetDialog(
                                          context,
                                          index,
                                          () {
                                            setStateDialog(() {});
                                            setState(() {});
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: l10n.statsSetsRename,
                                      onPressed: () {
                                        _showRenameStatsSetDialog(
                                          context,
                                          index,
                                          () {
                                            setStateDialog(() {});
                                            setState(() {});
                                          },
                                        );
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
                                  setState(() {
                                    if (_selectedFieldIndex >=
                                        _currentFieldCount) {
                                      _selectedFieldIndex = 0;
                                    }
                                  });
                                  final announcement = l10n
                                      .statsSetSelectedAnnouncement(
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

  void _showRenameStatsSetDialog(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final l10n = _l10n;
    final controller = TextEditingController(text: _statsSets[index].name);

    showDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsSetsRename),
      builder: (ctx) {
        return AlertDialog(
          semanticLabel: l10n.statsSetsRename,
          title: Text(l10n.statsSetsRename),
          content: Semantics(
            label: l10n.statsSetNameLabel,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.statsSetNameLabel),
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

  void _showEditStatsSetDialog(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final l10n = _l10n;
    final set = _statsSets[index];

    final fieldNameControllers = <TextEditingController>[
      for (var i = 0; i < set.fieldNames.length; i++)
        TextEditingController(text: set.fieldNames[i]),
    ];
    final fieldUnitValues = <String>[
      for (var i = 0; i < set.fieldUnits.length; i++) set.fieldUnits[i] ?? '--',
    ];

    void commitChanges(StateSetter setDialogState) {
      setState(() {
        for (var i = 0; i < set.fieldNames.length; i++) {
          final trimmed = fieldNameControllers[i].text.trim();
          if (trimmed.isNotEmpty) {
            set.fieldNames[i] = trimmed;
          }
          set.fieldUnits[i] = fieldUnitValues[i] == '--'
              ? null
              : fieldUnitValues[i];
        }
        if (_selectedFieldIndex >= set.fieldNames.length) {
          _selectedFieldIndex = 0;
        }
      });
      _saveStatsData();
      _statsSummaryInitialized = false;
      setDialogState(() {});
      onUpdated();
    }

    showDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Upravit pole', 'Edit fields')),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              semanticLabel: _s(
                'Upravit pole sady ${set.name}',
                'Edit fields of set ${set.name}',
              ),
              title: Semantics(
                header: true,
                child: Text(
                  _s('Pole sady', 'Fields of set') + ' "${set.name}"',
                ),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...List.generate(set.fieldNames.length, (i) {
                        final isLast = set.fieldNames.length == 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Semantics(
                                  label:
                                      _s('Název pole', 'Field name') +
                                      ' ${i + 1}',
                                  child: TextField(
                                    controller: fieldNameControllers[i],
                                    decoration: InputDecoration(
                                      labelText:
                                          _s('Pole', 'Field') + ' ${i + 1}',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                    ),
                                    onChanged: (_) {
                                      commitChanges(setDialogState);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 2,
                                child: Semantics(
                                  label:
                                      _s('Jednotka pole', 'Unit for field') +
                                      ' ${i + 1}',
                                  child: DropdownButtonFormField<String>(
                                    value: fieldUnitValues[i],
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: _statsFieldUnitOptions.map((u) {
                                      return DropdownMenuItem(
                                        value: u,
                                        child: Text(
                                          _getUnitOptionLabel(u),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        fieldUnitValues[i] = val;
                                        commitChanges(setDialogState);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip:
                                    _s('Smazat pole', 'Delete field') +
                                    ' ${i + 1}',
                                onPressed: isLast
                                    ? null
                                    : () {
                                        setState(() {
                                          fieldNameControllers
                                              .removeAt(i)
                                              .dispose();
                                          fieldUnitValues.removeAt(i);
                                          set.fieldNames.removeAt(i);
                                          set.fieldUnits.removeAt(i);
                                          for (final record in set.records) {
                                            if (i < record.values.length) {
                                              record.values.removeAt(i);
                                            }
                                          }
                                          if (_selectedFieldIndex >=
                                              set.fieldNames.length) {
                                            _selectedFieldIndex = 0;
                                          }
                                        });
                                        _saveStatsData();
                                        _statsSummaryInitialized = false;
                                        onUpdated();
                                        setDialogState(() {});
                                        speak(
                                          _s('Pole smazáno.', 'Field deleted.'),
                                        );
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
                          final newIndex = set.fieldNames.length;
                          setState(() {
                            set.fieldNames.add(
                              _s(
                                'Pole ${newIndex + 1}',
                                'Field ${newIndex + 1}',
                              ),
                            );
                            set.fieldUnits.add(null);
                            fieldNameControllers.add(
                              TextEditingController(text: set.fieldNames.last),
                            );
                            fieldUnitValues.add('--');
                            for (final record in set.records) {
                              record.values.add(0.0);
                            }
                          });
                          _saveStatsData();
                          _statsSummaryInitialized = false;
                          onUpdated();
                          setDialogState(() {});
                          speak(
                            _s(
                              'Pole přidáno. Stávajícím záznamům byla doplněna hodnota 0.',
                              'Field added. Existing records were filled with value 0.',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (final c in fieldNameControllers) {
                      c.dispose();
                    }
                    Navigator.pop(dialogContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _mainFocusNode.requestFocus();
                    });
                  },
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> get _statsFieldUnitOptions {
    final units = <String>['--'];
    for (final category in _unitCategories.keys) {
      units.addAll(_unitCategories[category]!.keys);
    }
    return units;
  }

  String _getUnitOptionLabel(String unitCode) {
    if (unitCode == '--') return _s('-- bez jednotky --', '-- no unit --');
    return '$unitCode (${_getUnitSpeech(unitCode)})';
  }

  void _showCreateStatsSetDialog(
    BuildContext context,
    VoidCallback onUpdated, {
    List<StatisticsRecord>? recordsToRepeat,
  }) {
    final l10n = _l10n;
    final defaultName = l10n.statsSetDefaultName(_statsSets.length + 1);
    final controller = TextEditingController(text: defaultName);
    final fieldControllers = <TextEditingController>[
      TextEditingController(text: 'Hodnota'),
    ];
    final fieldUnitValues = <String>['--'];

    showDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsSetsCreate),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              semanticLabel: l10n.statsSetsCreate,
              title: Text(l10n.statsSetsCreate),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: l10n.statsSetNameLabel,
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: l10n.statsSetNameLabel,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _s('Názvy a jednotky polí:', 'Field names and units:'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(fieldControllers.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Semantics(
                                label: '${_s("Pole", "Field")} ${i + 1}',
                                child: TextField(
                                  controller: fieldControllers[i],
                                  decoration: InputDecoration(
                                    labelText:
                                        '${_s("Pole", "Field")} ${i + 1}',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: Semantics(
                                label: _s(
                                  'Jednotka pole ${i + 1}',
                                  'Unit for field ${i + 1}',
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: fieldUnitValues[i],
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: _statsFieldUnitOptions.map((u) {
                                    return DropdownMenuItem(
                                      value: u,
                                      child: Text(
                                        _getUnitOptionLabel(u),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        fieldUnitValues[i] = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            if (fieldControllers.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: _s(
                                  'Odebrat pole ${i + 1}',
                                  'Remove field ${i + 1}',
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    fieldControllers[i].dispose();
                                    fieldUnitValues.removeAt(i);
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
                          fieldControllers.add(
                            TextEditingController(
                              text: _s(
                                'Pole ${fieldControllers.length + 1}',
                                'Field ${fieldControllers.length + 1}',
                              ),
                            ),
                          );
                          fieldUnitValues.add('--');
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
                      final fieldUnits = List<String?>.generate(
                        fieldNames.length,
                        (i) {
                          final unit = i < fieldUnitValues.length
                              ? fieldUnitValues[i]
                              : '--';
                          return unit == '--' ? null : unit;
                        },
                      );
                      setState(() {
                        _statsSets.add(
                          StatisticsSet(
                            name: newName,
                            fieldNames: fieldNames,
                            fieldUnits: fieldUnits,
                            records: [],
                          ),
                        );
                        _currentStatsSetIndex = _statsSets.length - 1;
                        _selectedFieldIndex = 0;
                      });
                      _saveStatsData();
                      onUpdated();
                      Navigator.pop(ctx);

                      if (recordsToRepeat != null) {
                        speak(
                          _s(
                            'Sada $newName vytvořena. Nyní můžete zadat počet opakování pro vložení hodnot.',
                            'Set $newName created. You can now enter the number of repetitions to insert the values.',
                          ),
                        );
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
      speak(
        _s(
          'Sada $deletedName byla smazána. Nejsou vytvořeny žádné sady.',
          'Set $deletedName was deleted. No sets created.',
        ),
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.infoNoResult)));
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
    String percentSpoken =
        '${_formatSpokenNumber(value * 100)} '
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
      routeSettings: RouteSettings(name: l10n.numberInfo),
      builder: (dialogContext) {
        DialogSize currentSize = _dialogSize;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool isInfoFullscreen = currentSize == DialogSize.fullscreen;
            return AlertDialog(
              semanticLabel: l10n.numberInfo,
              title: Semantics(
                header: true,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.numberInfo)),
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
                  label: _s(
                    'Přečíst všechny informace hlasem',
                    'Read all information aloud',
                  ),
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
      routeSettings: const RouteSettings(name: 'Historie výpočtů'),
      builder: (context) => AlertDialog(
        semanticLabel: _l10n.historyTitle,
        title: Semantics(header: true, child: Text(_l10n.historyTitle)),
        content: _applyDialogSize(
          _history.isEmpty
              ? Semantics(container: true, child: Text(_l10n.emptyHistory))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
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

                      String semanticDescription = _s(
                        "Výpočet: $expression, výsledek: $result. Poklepáním vložíte výsledek, přidržením vložíte celý výpočet.",
                        "Calculation: $expression, result: $result. Tap to insert the result, hold to insert the whole calculation.",
                      );

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
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showClearHistoryConfirmation();
            },
            child: Text(_l10n.clearHistory),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _mainFocusNode.requestFocus();
              });
            },
            child: Text(_l10n.close),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryConfirmation() {
    String question = _l10n.deleteConfirmation;
    showDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Potvrzení'),
      builder: (context) => AlertDialog(
        semanticLabel: _l10n.confirmationTitle,
        title: Semantics(header: true, child: Text(_l10n.confirmationTitle)),
        content: Focus(
          autofocus: true,
          onFocusChange: (hasFocus) {
            if (hasFocus) speak(question);
          },
          child: Semantics(
            container: true,
            label: _s('Otázka', 'Question'),
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
              speak(_l10n.historyCleared);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(_l10n.historyCleared)));
              }
              Navigator.pop(context);
            },
            child: Semantics(
              label: _l10n.yesConfirmHistory,
              child: Text(_l10n.yesDelete),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Semantics(
              label: _l10n.noCancelHistory,
              child: Text(_l10n.noStay),
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
      _lastAddedBatch = records
          .map((r) => StatisticsRecord(values: List.from(r.values)))
          .toList();
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
          .map(
            (r) => r.values
                .map((v) => _formatNumber(v).replaceAll('.', ','))
                .join(';'),
          )
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(spoken)));
    }
  }

  void _showRepeatDialog(List<StatisticsRecord> records) {
    final l10n = _l10n;
    TextEditingController controller = TextEditingController(text: '1');

    showDialog(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsRepeatTitle),
      builder: (context) => AlertDialog(
        semanticLabel: l10n.statsRepeatTitle,
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
      speak(
        _s(
          'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
          'No statistics set created. Enter a name for a new set first.',
        ),
      );

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
      speak(
        _s(
          'Displej je prázdný. Zadejte číslo k uložení.',
          'Display is empty. Enter a number to store.',
        ),
      );
      return;
    }
    try {
      final recordsToAdd = _parseDisplayToRecords(display);

      if (recordsToAdd.isEmpty) {
        speak(
          _s('Žádná platná čísla k uložení.', 'No valid numbers to store.'),
        );
        return;
      }

      _showRepeatDialog(recordsToAdd);
    } catch (e) {
      speak(
        e is FormatException
            ? e.message
            : _s(
                'Chyba při ukládání do statistické paměti. Zkontrolujte formát dat.',
                'Error storing to statistics memory. Check the data format.',
              ),
      );
    }
  }

  void _showMoreOptionsDialog() {
    final l10n = _l10n;
    showDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.moreOptions),
      builder: (dialogContext) => AlertDialog(
        semanticLabel: l10n.moreOptions,
        title: Semantics(header: true, child: Text(l10n.moreOptions)),
        content: _applyDialogSize(
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMoreOptionTile(
                  icon: Icons.help_outline,
                  label: l10n.helpTooltip,
                  autofocus: true,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showTutorialDialog();
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.info_outline,
                  label: l10n.numberInfo,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showNumberInfoDialog();
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.campaign,
                  label: l10n.news,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showNewsDialog();
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.update,
                  label: l10n.checkForUpdates,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _checkForUpdatesManually();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionTile({
    required IconData icon,
    required String label,
    bool autofocus = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        autofocus: autofocus,
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
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
              icon: Icon(ttsEnabled ? Icons.volume_up : Icons.volume_off),
              tooltip: ttsEnabled ? l10n.muteVoice : l10n.unmuteVoice,
              onPressed: _toggleTts,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: l10n.accessibility,
              onPressed: _showAccessibilityDialog,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.moreOptions,
              onPressed: _showMoreOptionsDialog,
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
                          value:
                              '${_getModeName(_currentMode)}. ${display.isEmpty ? (_hasResult ? _lastResult.replaceAll('.', ',') : l10n.displayEmpty) : display.replaceAll('.', ',')}',
                          onTap: () {
                            _mainFocusNode.requestFocus();
                            speak(
                              display.isEmpty
                                  ? (_hasResult
                                        ? _lastResult.replaceAll('.', ',')
                                        : l10n.displayEmpty)
                                  : display.replaceAll('.', ','),
                            );
                          },
                          // Když je čtečka aktivní, vnitřní CustomPaint je pro ni neviditelný
                          // a vše se přečte z tohoto Semantics widgetu
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

class _AdvancedFunctionsDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _AdvancedFunctionsDialog({required this.parent});

  @override
  State<_AdvancedFunctionsDialog> createState() =>
      _AdvancedFunctionsDialogState();
}

class _AdvancedFunctionsDialogState extends State<_AdvancedFunctionsDialog> {
  late _CalculatorScreenState parent;

  @override
  void initState() {
    super.initState();
    parent = widget.parent;
  }

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
                  ElevatedButton.icon(
                    onPressed: () => parent._showStatisticsHelpDialog(),
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: Text(parent._l10n.statsHelpButton),
                  ),
                  const SizedBox(height: 8),
                  if (parent._hasStatsSet)
                    Semantics(
                      label: parent._l10n.statsCurrentSetLabel(
                        parent._statsSets[parent._currentStatsSetIndex].name,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        color: Colors.blue.withOpacity(0.1),
                        child: Column(
                          children: [
                            Text(
                              parent._l10n.statsCurrentSetLabel(
                                    parent
                                        ._statsSets[parent
                                            ._currentStatsSetIndex]
                                        .name,
                                  ) +
                                  ' (${parent._statsMemory.length} ${parent._getStatsCountForm(parent._statsMemory.length)})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (parent._currentFieldCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: StatefulBuilder(
                                  builder: (ctx, setLocalState) {
                                    final fieldNames = parent
                                        ._statsSets[parent
                                            ._currentStatsSetIndex]
                                        .fieldNames;
                                    return InkWell(
                                      onTap: () {
                                        final nextIndex =
                                            (parent._selectedFieldIndex + 1) %
                                            parent._currentFieldCount;
                                        parent.setState(
                                          () => parent._selectedFieldIndex =
                                              nextIndex,
                                        );
                                        setLocalState(() {});
                                        parent.speak(
                                          parent._s(
                                            'Vybráno pole ${fieldNames[nextIndex]}',
                                            'Selected field ${fieldNames[nextIndex]}',
                                          ),
                                        );
                                      },
                                      child: Semantics(
                                        liveRegion: true,
                                        label: parent._s(
                                          'Pole: ${fieldNames[parent._selectedFieldIndex]}',
                                          'Field: ${fieldNames[parent._selectedFieldIndex]}',
                                        ),
                                        excludeSemantics: true,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                parent._s('Pole: ', 'Field: '),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                fieldNames[parent
                                                    ._selectedFieldIndex],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.swap_horiz, size: 14),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
                          parent.speak(
                            parent._s(
                              'Není vytvořena žádná sada. Vytvořte novou sadu tlačítkem SETS na hlavní klávesnici.',
                              'No set created. Create a new set using the SETS button on the main keyboard.',
                            ),
                          );
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
                    children:
                        [
                          'MEAN',
                          'SD',
                          'VAR',
                          'SUM',
                          'MED',
                          'MODE',
                          'CV',
                          'WMEAN',
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
                        parent.speak(
                          parent._s(
                            'Žádná data v poslední dávce.',
                            'No data in the last batch.',
                          ),
                          force: true,
                        );
                      } else {
                        String valuesStr = parent._lastAddedBatch
                            .map(
                              (r) => r.values
                                  .map(
                                    (v) => parent
                                        ._formatNumber(v)
                                        .replaceAll('.', ','),
                                  )
                                  .join(';'),
                            )
                            .join(' ');
                        parent.speak(
                          parent._s(
                            'Poslední vložená data: $valuesStr',
                            'Last added data: $valuesStr',
                          ),
                          force: true,
                        );
                      }
                    },
                    child: Text(
                      parent._s(
                        'Přečíst naposledy vložená data',
                        'Read last added data',
                      ),
                    ),
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
                    decoration: InputDecoration(
                      labelText: parent._s('Kategorie', 'Category'),
                    ),
                    items: parent._unitCategories.keys
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(parent._getCategorySpeech(cat)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      // ignore: invalid_use_of_protected_member
                      parent.setState(() {
                        parent._selectedUnitCategory = val;
                        parent._unitFrom =
                            parent._unitCategories[val]!.keys.first;
                        parent._unitTo = parent._unitCategories[val]!.keys
                            .elementAt(1);
                      });
                      setState(() {});
                      parent.speak(
                        parent._s(
                          'Kategorie ${parent._getCategorySpeech(val)}',
                          'Category ${parent._getCategorySpeech(val)}',
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: parent._s(
                            'Převod z jednotky',
                            'Convert from unit',
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: parent._unitFrom,
                            decoration: InputDecoration(
                              labelText: parent._s('Z', 'From'),
                            ),
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
                              if (val == null) return;
                              // ignore: invalid_use_of_protected_member
                              parent.setState(() => parent._unitFrom = val);
                              parent.speak(
                                parent._s(
                                  'Z jednotky ${parent._getUnitSpeech(val)}',
                                  'From unit ${parent._getUnitSpeech(val)}',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward),
                      Expanded(
                        child: Semantics(
                          label: parent._s(
                            'Převod na jednotku',
                            'Convert to unit',
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: parent._unitTo,
                            decoration: InputDecoration(
                              labelText: parent._s('Na', 'To'),
                            ),
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
                              if (val == null) return;
                              // ignore: invalid_use_of_protected_member
                              parent.setState(() => parent._unitTo = val);
                              parent.speak(
                                parent._s(
                                  'Na jednotku ${parent._getUnitSpeech(val)}',
                                  'To unit ${parent._getUnitSpeech(val)}',
                                ),
                              );
                            },
                          ),
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
                      label: Text(parent._s('PŘEVÉST', 'CONVERT')),
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

    if (parent._currentMode == CalculatorMode.scientific) {
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
                children: ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN'].map((
                  b,
                ) {
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
                    'PCT',
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
        title: parent._s('Paměť', 'Memory'),
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
                        semanticLabel: parent._s('Proměnná $b', 'Variable $b'),
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
        title: parent._s('Zobrazení', 'Display'),
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
                    semanticLabel: parent._s(
                      'Standardní zobrazení',
                      'Standard display',
                    ),
                    onPressed: () {
                      // ignore: invalid_use_of_protected_member
                      parent.setState(
                        () => parent._displayFormat = DisplayFormat.standard,
                      );
                      parent.speak(
                        parent._s(
                          'Nastaveno standardní zobrazení',
                          'Standard display set',
                        ),
                      );
                      if (parent.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              parent._s(
                                'Nastaveno standardní zobrazení',
                                'Standard display set',
                              ),
                            ),
                          ),
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
                    semanticLabel: parent._s(
                      'Zobrazení s pevným počtem desetinných míst',
                      'Fixed decimal places display',
                    ),
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
                    semanticLabel: parent._s(
                      'Vědecký zápis',
                      'Scientific notation',
                    ),
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
                    semanticLabel: parent._s(
                      'Inženýrský zápis',
                      'Engineering notation',
                    ),
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
      semanticLabel: parent._s('Pokročilé funkce', 'Advanced functions'),
      title: Semantics(
        header: true,
        child: Text(parent._s('Pokročilé funkce', 'Advanced functions')),
      ),
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
          child: Text(parent._s('ZAVŘÍT', 'CLOSE')),
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
            button: true,
            expanded: _isExpanded,
            label: '${_isExpanded ? 'Sbalit' : 'Rozbalit'} ${widget.title}',
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
    this.disabledColor = const Color(0x30FF5252),
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
    this.disabledColor = const Color(0x30FF5252),
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

class _NewsDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  final GitHubReleaseInfo? initialFocusVersion;

  const _NewsDialog({required this.parent, this.initialFocusVersion});

  @override
  State<_NewsDialog> createState() => _NewsDialogState();
}

class _NewsDialogState extends State<_NewsDialog> {
  bool _loading = true;
  String? _error;
  List<GitHubReleaseInfo> _releases = [];

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final checker = GitHubReleaseChecker();
    final releases = await checker.fetchRecentReleases(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      perPage: 10,
    );
    checker.close();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _releases = releases;
      if (releases.isEmpty) {
        _error = widget.parent._s(
          'Novinky se nepodařilo načíst. Zkontrolujte připojení k internetu.',
          'News could not be loaded. Check your internet connection.',
        );
      }
    });

    final focused = widget.initialFocusVersion;
    if (focused != null && releases.isNotEmpty) {
      final matching = _findVersion(releases, focused.normalizedVersion);
      if (matching != null && matching.plainTextBody.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            widget.parent.speak(
              widget.parent._s(
                'Novinky v této verzi. ${matching.plainTextBody}',
                'What is new in this version. ${matching.plainTextBody}',
              ),
              force: true,
            );
          }
        });
      }
    }
  }

  GitHubReleaseInfo? _findVersion(
    List<GitHubReleaseInfo> releases,
    String normalizedVersion,
  ) {
    for (final release in releases) {
      if (release.normalizedVersion == normalizedVersion) {
        return release;
      }
    }
    return null;
  }

  void _readRelease(GitHubReleaseInfo release) {
    final text = release.plainTextBody;
    if (text.isEmpty) {
      widget.parent.speak(
        widget.parent._s(
          'Tato verze nemá zveřejněné novinky.',
          'This version has no published release notes.',
        ),
        force: true,
      );
      return;
    }
    widget.parent.speak(
      widget.parent._s(
        'Verze ${release.normalizedVersion}. $text',
        'Version ${release.normalizedVersion}. $text',
      ),
      force: true,
    );
  }

  void _readAll() {
    if (_releases.isEmpty) {
      widget.parent.speak(
        widget.parent._s('Nemám co přečíst.', 'There is nothing to read.'),
        force: true,
      );
      return;
    }
    final buffer = StringBuffer();
    for (final release in _releases) {
      buffer.write(
        '${widget.parent._s('Verze', 'Version')} ${release.normalizedVersion}. ',
      );
      buffer.write(release.plainTextBody);
      buffer.write('. ');
    }
    widget.parent.speak(buffer.toString(), force: true);
  }

  Widget _buildReleaseTile(GitHubReleaseInfo release) {
    final body = release.plainTextBody;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Verze ${release.normalizedVersion}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        if (body.isEmpty)
          Text(widget.parent._s('Bez popisu novinek.', 'No release notes.'))
        else
          Text(body),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: widget.parent._s(
              'Přečíst novinky verze ${release.normalizedVersion}',
              'Read release notes of version ${release.normalizedVersion}',
            ),
            child: ElevatedButton.icon(
              onPressed: () => _readRelease(release),
              icon: const Icon(Icons.volume_up),
              label: Text(widget.parent._s('Přečíst novinky', 'Read news')),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      semanticLabel: widget.parent._s('Novinky', 'What is new'),
      title: Semantics(
        header: true,
        child: Text(widget.parent._s('Novinky', 'What is new')),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(label: _error, child: Text(_error!)),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        label: widget.parent._s(
                          'Přečíst všechny novinky',
                          'Read all release notes',
                        ),
                        child: FilledButton.icon(
                          onPressed: _readAll,
                          icon: const Icon(Icons.volume_up),
                          label: Text(
                            widget.parent._s('Přečíst vše', 'Read all'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.initialFocusVersion != null) ...[
                      Semantics(
                        header: true,
                        child: Text(
                          widget.parent._s(
                            'Co je nového v této verzi',
                            'What is new in this version',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildReleaseTile(widget.initialFocusVersion!),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: Text(
                          widget.parent._s('Starší verze', 'Older versions'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ..._releases
                        .where(
                          (release) =>
                              widget.initialFocusVersion == null ||
                              release.normalizedVersion !=
                                  widget.initialFocusVersion!.normalizedVersion,
                        )
                        .map(_buildReleaseTile),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.parent._s('Zavřít', 'Close')),
        ),
      ],
    );
  }
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
      semanticLabel: widget.parent._l10n.accessibilitySettings,
      title: Semantics(
        header: true,
        child: Text(widget.parent._l10n.accessibilitySettings),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: widget.parent._s(
                'Přepnutí typu displeje',
                'Switch display type',
              ),
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
                        ? widget.parent._l10n.segment16On
                        : widget.parent._l10n.segment7On,
                  );
                },
                child: Text(
                  widget.parent._l10n.displayType(
                    widget.parent._useSixteenSegment
                        ? widget.parent._s('16-segmentový', '16-segment')
                        : widget.parent._s('7-segmentový', '7-segment'),
                  ),
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Přepnutí hlasového výstupu',
                'Switch voice output',
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () =>
                          widget.parent.ttsEnabled = !widget.parent.ttsEnabled,
                    );
                    widget.parent._saveSettings();
                  });
                  widget.parent.speak(
                    widget.parent.ttsEnabled
                        ? widget.parent._l10n.voiceOn
                        : widget.parent._l10n.voiceOff,
                  );
                },
                child: Text(
                  widget.parent._l10n.voiceOutput(
                    widget.parent.ttsEnabled
                        ? widget.parent._s('Zapnuto', 'On')
                        : widget.parent._s('Vypnuto', 'Off'),
                  ),
                ),
              ),
            ),
            const Divider(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._s(
                    'Režim čtečky obrazovky',
                    'Screen reader mode',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s(
                        'Režim čtečky obrazovky',
                        'Screen reader mode',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ScreenReaderMode>(
                  segments: [
                    ButtonSegment(
                      value: ScreenReaderMode.auto,
                      label: Semantics(
                        label: widget.parent._s(
                          'Automaticky podle čtečky',
                          'Automatic according to screen reader',
                        ),
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Auto', 'Auto')),
                        ),
                      ),
                      tooltip: widget.parent._s(
                        'Automaticky podle čtečky',
                        'Automatic according to screen reader',
                      ),
                    ),
                    ButtonSegment(
                      value: ScreenReaderMode.on,
                      label: Semantics(
                        label: widget.parent._s(
                          'Režim čtečky obrazovky zapnut',
                          'Screen reader mode on',
                        ),
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Zapnuto', 'On')),
                        ),
                      ),
                      tooltip: widget.parent._s(
                        'Režim čtečky obrazovky zapnut',
                        'Screen reader mode on',
                      ),
                    ),
                    ButtonSegment(
                      value: ScreenReaderMode.off,
                      label: Semantics(
                        label: widget.parent._s(
                          'Režim čtečky obrazovky vypnut',
                          'Screen reader mode off',
                        ),
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Vypnuto', 'Off')),
                        ),
                      ),
                      tooltip: widget.parent._s(
                        'Režim čtečky obrazovky vypnut',
                        'Screen reader mode off',
                      ),
                    ),
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
                          ? widget.parent._s(
                              'Režim čtečky: automaticky',
                              'Screen reader mode: automatic',
                            )
                          : mode == ScreenReaderMode.on
                          ? widget.parent._s(
                              'Režim čtečky obrazovky zapnut',
                              'Screen reader mode on',
                            )
                          : widget.parent._s(
                              'Režim čtečky obrazovky vypnut',
                              'Screen reader mode off',
                            ),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Nastavení hlasového engine',
                'Voice engine settings',
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.parent._showTtsEngineDialog();
                },
                child: Text(
                  '${widget.parent._s('Engine', 'Engine')}: ${widget.parent._ttsEngine ?? widget.parent._s('Výchozí', 'Default')}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Otevřít systémové nastavení TTS',
                'Open system TTS settings',
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.parent._openTtsSystemSettings();
                },
                child: Text(widget.parent._s('Nastavení TTS', 'TTS settings')),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s('Nastavení hlasu', 'Voice settings'),
              child: ElevatedButton(
                onPressed: () {
                  widget.parent._showTtsVoiceDialog();
                },
                child: Text(
                  '${widget.parent._s('Hlas', 'Voice')}: ${widget.parent._ttsVoiceName ?? widget.parent._s('Výchozí', 'Default')}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Přepnutí formátu úhlů',
                'Switch angle format',
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Pokud je null nebo 1, nastavíme na 0 (DMS). Pokud je 0, nastavíme na 1 (Desetinné).
                  final current = widget.parent._inverseFormatPreference ?? 1;
                  final newFormat = (current == 0) ? 1 : 0;

                  widget.parent._saveInversePreference(newFormat);

                  widget.parent.speak(
                    newFormat == 0
                        ? widget.parent._l10n.formatDms
                        : widget.parent._l10n.formatDecimalDegrees,
                  );
                  // Vynucené překreslení dialogu
                  setState(() {});
                },
                child: Text(
                  widget.parent._s(
                    'Úhly: ${(widget.parent._inverseFormatPreference == 0) ? 'DMS' : 'Desetinné'}',
                    'Angles: ${(widget.parent._inverseFormatPreference == 0) ? 'DMS' : 'Decimal'}',
                  ),
                ),
              ),
            ),
            const Divider(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._s(
                    'Výběr motivu aplikace',
                    'App theme selection',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s('Motiv aplikace', 'App theme'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Semantics(
                        label: widget.parent._l10n.themeSystemLabel,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Systém', 'System')),
                        ),
                      ),
                      icon: Icon(Icons.brightness_auto),
                      tooltip: widget.parent._l10n.themeSystemLabel,
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Semantics(
                        label: widget.parent._l10n.themeLightLabel,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Světlý', 'Light')),
                        ),
                      ),
                      icon: Icon(Icons.light_mode),
                      tooltip: widget.parent._l10n.themeLightLabel,
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Semantics(
                        label: widget.parent._l10n.themeDarkLabel,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Tmavý', 'Dark')),
                        ),
                      ),
                      icon: Icon(Icons.dark_mode),
                      tooltip: widget.parent._l10n.themeDarkLabel,
                    ),
                  ],
                  selected: {widget.parent.widget.themeMode},
                  onSelectionChanged: (Set<ThemeMode> selection) {
                    ThemeMode mode = selection.first;
                    widget.parent.widget.onThemeModeChanged(mode);
                    String modeName;
                    if (mode == ThemeMode.light) {
                      modeName = widget.parent._l10n.themeLight;
                    } else if (mode == ThemeMode.dark) {
                      modeName = widget.parent._l10n.themeDark;
                    } else {
                      modeName = widget.parent._l10n.themeSystem;
                    }
                    widget.parent.speak(widget.parent._l10n.themeSet(modeName));
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Výchozí režim po spuštění
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._s(
                    'Výchozí režim po spuštění',
                    'Default mode on startup',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s(
                        'Výchozí režim po spuštění',
                        'Default mode on startup',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<CalculatorMode>(
                    showSelectedIcon: false,
                    segments: CalculatorMode.values.map((mode) {
                      final modeName = widget.parent._getModeName(mode);
                      return ButtonSegment(
                        value: mode,
                        label: Semantics(
                          label: modeName,
                          child: ExcludeSemantics(child: Text(modeName)),
                        ),
                        tooltip: modeName,
                      );
                    }).toList(),
                    selected: {widget.parent._defaultMode},
                    onSelectionChanged: (Set<CalculatorMode> selected) {
                      final mode = selected.first;
                      widget.parent._setDefaultMode(mode);
                      widget.parent.speak(
                        widget.parent._s(
                          'Výchozí režim nastaven na ${widget.parent._getModeSpeechName(mode)}',
                          'Default mode set to ${widget.parent._getModeSpeechName(mode)}',
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Velikost dialogů
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.dialogSizeSetting,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.dialogSizeSetting),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<DialogSize>(
                  segments: [
                    ButtonSegment(
                      value: DialogSize.compact,
                      label: Semantics(
                        label: widget.parent._l10n.dialogSizeCompact,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._l10n.dialogSizeCompact),
                        ),
                      ),
                      icon: const Icon(Icons.phone_android),
                      tooltip: widget.parent._l10n.dialogSizeCompact,
                    ),
                    ButtonSegment(
                      value: DialogSize.wide,
                      label: Semantics(
                        label: widget.parent._l10n.dialogSizeWide,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._l10n.dialogSizeWide),
                        ),
                      ),
                      icon: const Icon(Icons.phone_iphone),
                      tooltip: widget.parent._l10n.dialogSizeWide,
                    ),
                    ButtonSegment(
                      value: DialogSize.fullscreen,
                      label: Semantics(
                        label: widget.parent._l10n.dialogSizeFullscreen,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._l10n.dialogSizeFullscreen),
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen),
                      tooltip: widget.parent._l10n.dialogSizeFullscreen,
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
            const SizedBox(height: 16),

            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.zoomUpperControls,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.zoomUpper),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      container: true,
                      label: widget.parent._s(
                        'Zmenšit zoom horního řádku',
                        'Decrease upper line zoom',
                      ),
                      child: ElevatedButton(
                        onPressed: () => _adjustDotMatrixZoom(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
                        label: widget.parent._s(
                          'Hodnota zoomu: ${(widget.parent._dotMatrixZoom * 100).toInt()} %',
                          'Zoom value: ${(widget.parent._dotMatrixZoom * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._dotMatrixZoom * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      container: true,
                      label: widget.parent._s(
                        'Zvětšit zoom horního řádku',
                        'Increase upper line zoom',
                      ),
                      child: ElevatedButton(
                        onPressed: () => _adjustDotMatrixZoom(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.zoomLowerControls,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.zoomLower),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      container: true,
                      label: widget.parent._s(
                        'Zmenšit zoom dolního řádku',
                        'Decrease lower line zoom',
                      ),
                      child: ElevatedButton(
                        onPressed: () => _adjustResultZoom(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
                        label: widget.parent._s(
                          'Hodnota zoomu: ${(widget.parent._resultZoom * 100).toInt()} %',
                          'Zoom value: ${(widget.parent._resultZoom * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._resultZoom * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      container: true,
                      label: widget.parent._s(
                        'Zvětšit zoom dolního řádku',
                        'Increase lower line zoom',
                      ),
                      child: ElevatedButton(
                        onPressed: () => _adjustResultZoom(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.speechRateControls,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.speechRate),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      container: true,
                      label: widget.parent._l10n.decreaseSpeechRate,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechRate(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
                        label: widget.parent._l10n.speechRateValue(
                          (widget.parent._speechRate * 100).toInt(),
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._speechRate * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      container: true,
                      label: widget.parent._l10n.increaseSpeechRate,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechRate(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._s(
                    'Ovládání hlasitosti',
                    'Volume controls',
                  ),
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.volume),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      container: true,
                      label: widget.parent._l10n.decreaseVolume,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechVolume(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
                        label: widget.parent._s(
                          'Aktuální hlasitost: ${(widget.parent._speechVolume * 100).toInt()} %',
                          'Current volume: ${(widget.parent._speechVolume * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._speechVolume * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      container: true,
                      label: widget.parent._l10n.increaseVolume,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechVolume(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.dataManagementSection,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.dataManagementTitle),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._l10n.backupData,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.backup),
                        onPressed: () {
                          widget.parent._exportBackup();
                          Navigator.pop(context);
                        },
                        label: Text(widget.parent._l10n.backupData),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Semantics(
                      label: widget.parent._l10n.restoreData,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restore),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            routeSettings: const RouteSettings(
                              name: 'Potvrzení',
                            ),
                            builder: (ctx) => AlertDialog(
                              semanticLabel:
                                  widget.parent._l10n.confirmationTitle,
                              title: Text(
                                widget.parent._l10n.confirmationTitle,
                              ),
                              content: Text(widget.parent._l10n.restoreConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(widget.parent._l10n.noShort),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(widget.parent._l10n.yesShort),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            widget.parent._importBackup();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        label: Text(widget.parent._l10n.restoreData),
                      ),
                    ),
                  ],
                ),
              ],
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
          child: Text(widget.parent._l10n.done),
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
      widget.parent._l10n.zoomUpperPct(
        (widget.parent._dotMatrixZoom * 100).toInt(),
      ),
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
      widget.parent._l10n.zoomLowerPct(
        (widget.parent._resultZoom * 100).toInt(),
      ),
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
      widget.parent._l10n.speechRatePct(
        (widget.parent._speechRate * 100).toInt(),
      ),
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
      widget.parent._l10n.volumePct(
        (widget.parent._speechVolume * 100).toInt(),
      ),
    );
  }
}
