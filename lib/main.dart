import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:math_expressions/math_expressions.dart' as math_expr;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:segment_display/segment_display.dart';
import 'package:dot_matrix_text/dot_matrix_text.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScientificCalculatorApp());
}

class ScientificCalculatorApp extends StatefulWidget {
  const ScientificCalculatorApp({super.key});

  @override
  State<ScientificCalculatorApp> createState() => _ScientificCalculatorAppState();
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
      title: 'Mluvící kalkulačka',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('cs', 'CZ'),
      ],
      locale: const Locale('cs', 'CZ'),
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

enum CalculatorMode { basic, scientific, statistics, electrician, unitConversion }
enum AccessibilityType { none, blind, visuallyImpaired }
enum DisplayFormat { standard, fix, sci, eng }

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

class _CalculatorScreenState extends State<CalculatorScreen> {
  final FlutterTts tts = FlutterTts();
  final FocusNode _mainFocusNode = FocusNode();
  String display = '';
  int _cursorPosition = 0;
  String _lastResult = '0.';
  CalculatorMode _currentMode = CalculatorMode.scientific;
  
  bool ttsEnabled = true;
  bool _isDegreeMode = true;
  bool _useSixteenSegment = false;
  final bool _sayWelcome = true;
  AccessibilityType _accessibilityType = AccessibilityType.none;
  double _fontSizeMultiplier = 1.0;
  final double _displaySizeFactor = 1.0;
  final double _speechRate = 0.5;
  final double _speechVolume = 1.0;
  
  DisplayFormat _displayFormat = DisplayFormat.standard;
  int _precision = 2;

  DateTime? _lastSpeakTime;
  final Duration _speakThrottle = const Duration(milliseconds: 300);

  final Map<String, double> _memory = {
    'A': 0, 'B': 0, 'C': 0, 'D': 0, 'E': 0, 'F': 0,
    'X': 0, 'Y': 0, 'M': 0,
  };

  final Map<String, Map<String, double>> _unitCategories = {
    'Délka': { 'm': 1.0, 'km': 1000.0, 'cm': 0.01, 'mm': 0.001, 'mi': 1609.344, 'yd': 0.9144, 'ft': 0.3048, 'in': 0.0254 },
    'Hmotnost': { 'kg': 1.0, 'g': 0.001, 'mg': 0.000001, 't': 1000.0, 'lb': 0.45359237, 'oz': 0.028349523125 },
    'Plocha': { 'm²': 1.0, 'km²': 1000000.0, 'ha': 10000.0, 'cm²': 0.0001, 'akr': 4046.856 },
    'Objem': { 'l': 1.0, 'ml': 0.001, 'm³': 1000.0, 'gal': 3.78541, 'pt': 0.473176 },
    'Tlak': { 'Pa': 1.0, 'hPa': 100.0, 'kPa': 1000.0, 'bar': 100000.0, 'atm': 101325.0, 'psi': 6894.76 },
  };

  final Map<String, Map<String, dynamic>> _unitSpeechData = {
    'm': {'base': 'metr', 'z': 'metrů', 'na': 'metry', 'forms': ['metr', 'metry', 'metrů', 'metru']},
    'km': {'base': 'kilometr', 'z': 'kilometrů', 'na': 'kilometry', 'forms': ['kilometr', 'kilometry', 'kilometrů', 'kilometru']},
    'cm': {'base': 'centimetr', 'z': 'centimetrů', 'na': 'centimetry', 'forms': ['centimetr', 'centimetry', 'centimetrů', 'centimetru']},
    'mm': {'base': 'milimetr', 'z': 'milimetrů', 'na': 'milimetry', 'forms': ['milimetr', 'milimetry', 'milimetrů', 'milimetru']},
    'mi': {'base': 'míle', 'z': 'mil', 'na': 'míle', 'forms': ['míle', 'míle', 'mil', 'míle']},
    'yd': {'base': 'yard', 'z': 'yardů', 'na': 'yardy', 'forms': ['yard', 'yardy', 'yardů', 'yardu']},
    'ft': {'base': 'stopa', 'z': 'stop', 'na': 'stopy', 'forms': ['stopa', 'stopy', 'stop', 'stopy']},
    'in': {'base': 'palec', 'z': 'palců', 'na': 'palce', 'forms': ['palec', 'palce', 'palců', 'palce']},
    'kg': {'base': 'kilogram', 'z': 'kilogramů', 'na': 'kilogramy', 'forms': ['kilogram', 'kilogramy', 'kilogramů', 'kilogramu']},
    'g': {'base': 'gram', 'z': 'gramů', 'na': 'gramy', 'forms': ['gram', 'gramy', 'gramů', 'gramu']},
    'mg': {'base': 'miligram', 'z': 'miligramů', 'na': 'miligramy', 'forms': ['miligram', 'miligramy', 'miligramů', 'miligramu']},
    't': {'base': 'tuna', 'z': 'tun', 'na': 'tuny', 'forms': ['tuna', 'tuny', 'tun', 'tuny']},
    'lb': {'base': 'libra', 'z': 'liber', 'na': 'libry', 'forms': ['libra', 'libry', 'liber', 'libry']},
    'oz': {'base': 'unce', 'z': 'uncí', 'na': 'unce', 'forms': ['unce', 'unce', 'uncí', 'unce']},
    'm²': {'base': 'metr čtvereční', 'z': 'metrů čtverečních', 'na': 'metry čtvereční', 'forms': ['metr čtvereční', 'metry čtvereční', 'metrů čtverečních', 'metru čtverečního']},
    'km²': {'base': 'kilometr čtvereční', 'z': 'kilometrů čtverečních', 'na': 'kilometry čtvereční', 'forms': ['kilometr čtvereční', 'kilometry čtvereční', 'kilometrů čtverečních', 'kilometru čtverečního']},
    'ha': {'base': 'hektar', 'z': 'hektarů', 'na': 'hektary', 'forms': ['hektar', 'hektary', 'hektarů', 'hektaru']},
    'cm²': {'base': 'centimetr čtvereční', 'z': 'centimetrů čtverečních', 'na': 'centimetry čtvereční', 'forms': ['centimetr čtvereční', 'centimetry čtvereční', 'centimetrů čtverečních', 'centimetru čtverečního']},
    'akr': {'base': 'akr', 'z': 'akrů', 'na': 'akry', 'forms': ['akr', 'akry', 'akrů', 'akru']},
    'l': {'base': 'litr', 'z': 'litrů', 'na': 'litry', 'forms': ['litr', 'litry', 'litrů', 'litru']},
    'ml': {'base': 'mililitr', 'z': 'mililitrů', 'na': 'mililitry', 'forms': ['mililitr', 'mililitry', 'mililitrů', 'mililitru']},
    'm³': {'base': 'metr krychlový', 'z': 'metrů krychlových', 'na': 'metry krychlové', 'forms': ['metr krychlový', 'metry krychlové', 'metrů krychlových', 'metru krychlového']},
    'gal': {'base': 'galon', 'z': 'galonů', 'na': 'galony', 'forms': ['galon', 'galony', 'galonů', 'galonu']},
    'pt': {'base': 'pinta', 'z': 'pint', 'na': 'pinty', 'forms': ['pinta', 'pinty', 'pint', 'pinty']},
    'Pa': {'base': 'pascal', 'z': 'pascalů', 'na': 'pascaly', 'forms': ['pascal', 'pascaly', 'pascalů', 'pascalu']},
    'hPa': {'base': 'hektopascal', 'z': 'hektopascalů', 'na': 'hektopascaly', 'forms': ['hektopascal', 'hektopascaly', 'hektopascalů', 'hektopascalu']},
    'kPa': {'base': 'kilopascal', 'z': 'kilopascalů', 'na': 'kilopascaly', 'forms': ['kilopascal', 'kilopascaly', 'kilopascalů', 'kilopascalu']},
    'bar': {'base': 'bar', 'z': 'barů', 'na': 'bary', 'forms': ['bar', 'bary', 'barů', 'baru']},
    'atm': {'base': 'atmosféra', 'z': 'atmosfér', 'na': 'atmosféry', 'forms': ['atmosféra', 'atmosféry', 'atmosfér', 'atmosféry']},
    'psi': {'base': 'libra na čtvereční palec', 'z': 'liber na čtvereční palec', 'na': 'libry na čtvereční palec', 'forms': ['libra na čtvereční palec', 'libry na čtvereční palec', 'liber na čtvereční palec', 'libry na čtvereční palec']},
  };

  String _selectedUnitCategory = 'Délka';
  String _unitFrom = 'm';
  String _unitTo = 'km';
  List<String> _history = [];
  bool _isStoreMode = false;
  bool _hasResult = false;

  final Map<String, String> _buttonNames = {
    'SIN': 'Sinus', 'COS': 'Kosinus', 'TAN': 'Tangens', 'ASIN': 'Arkus sinus', 'ACOS': 'Arkus kosinus', 'ATAN': 'Arkus tangens',
    'ABS': 'Absolutní hodnota', '°→\'': 'Převod na DMS', '\'→°': 'Převod na stupně', 'DMS': 'Vložit DMS',
    '=': 'Rovná se', '/': 'Lomeno', '*': 'Krát', '-': 'Mínus', '+': 'Plus', '(': 'Závorka otevřená', ')': 'Závorka zavřená', '.': 'Tečka',
    '^': 'Mocnina', '√': 'Odmocnina', 'ⁿ√': 'Odmocnina en', 'x²': 'Na druhou', 'x³': 'Na třetí', '∛': 'Třetí odmocnina', '1/x': 'Převrácená hodnota',
    'ANS': 'Poslední výsledek', 'STO': 'Uložit do paměti', 'DEL': 'Smazat poslední', 'RCL': 'Vyvolat z paměti', 'CLR': 'Smazat celou paměť', 'C': 'Smazat displej',
    'DEG': 'Stupně', 'RAD': 'Radiány', '%': 'Procenta', 'SD': 'Směrodatná odchylka', 'VAR': 'Rozptyl', 'MEAN': 'Průměr', 'STATS': 'Statistický souhrn',
    'CV': 'Variační koeficient', ';': 'Oddělovač dat', '(-)': 'Záporné číslo se závorkou', 'EXP': 'krát deset na',
    'OHM_V': 'Napětí', 'OHM_I': 'Proud', 'OHM_R': 'Odpor', 'PWR_P': 'Výkon', 'PAR': 'Paralelně', 'SER': 'Sériově', 'Hz': 'Hertz', 'μ': 'Mikro', 'n': 'Nano', 'p': 'Piko',
  };

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSettings();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mainFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    super.dispose();
  }

  void _initTts() async {
    try {
      await tts.setLanguage("cs-CZ");
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_speechVolume);
      if (_sayWelcome) {
        speak('Vítejte v mluvící kalkulačce, aktivní je ${_getModeSpeechName(_currentMode)}');
      }
    } catch (e) { debugPrint('TTS Error: $e'); }
    Future.delayed(const Duration(milliseconds: 1000), () async {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('accessibilityType')) _showInitialAccessibilityDialog();
    });
  }

  String _getModeName(CalculatorMode mode) {
    switch (mode) {
      case CalculatorMode.basic: return 'Základní';
      case CalculatorMode.scientific: return 'Vědecká';
      case CalculatorMode.statistics: return 'Statistika';
      case CalculatorMode.electrician: return 'Elektro';
      case CalculatorMode.unitConversion: return 'Převody jednotek';
    }
  }

  String _getModeSpeechName(CalculatorMode mode) {
    switch (mode) {
      case CalculatorMode.basic: return 'základní režim';
      case CalculatorMode.scientific: return 'vědecký režim';
      case CalculatorMode.statistics: return 'statistický režim';
      case CalculatorMode.electrician: return 'elektrotechnický režim';
      case CalculatorMode.unitConversion: return 'režim převodů jednotek';
    }
  }

  void speak(String text) async {
    if (text.isEmpty || !ttsEnabled || !mounted) {
      return;
    }
    final now = DateTime.now();
    if (_lastSpeakTime != null && now.difference(_lastSpeakTime!) < _speakThrottle) {
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
    String processed = text.replaceAll('.', ',');
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:,\d+)?)E([+-])(\d+)'), (m) {
      int exp = int.parse(m[3]!);
      return '${m[1]} krát deset na ${m[2] == '-' ? 'mínus ' : ''}$exp';
    });
    return processed;
  }

  void _handleKeyboardInput(KeyEvent event) {
    if (event is KeyDownEvent) {
      final char = event.character;
      if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        calculateResult();
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        backspace();
      } else if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.delete) {
        clear();
      } else if (char != null) {
        String toAppend = char == ',' ? '.' : char;
        if (RegExp(r'[0-9.+\-*/^%()eEa-zA-Z]').hasMatch(toAppend)) {
          append(toAppend.toUpperCase(), silent: true);
        }
      }
    }
  }

  void backspace() { _deleteAtCursor(); }
  void clear() { setState(() { display = ''; _cursorPosition = 0; _lastResult = '0.'; _isStoreMode = false; _hasResult = false; }); speak('Vymazat'); }
  void append(String value, {bool silent = false}) { _insertAtCursor(value); if (!silent) speak(_buttonNames[value] ?? value); }

  void _insertAtCursor(String text, {int cursorOffset = 0}) {
    setState(() {
      display = display.substring(0, _cursorPosition) + text + display.substring(_cursorPosition);
      _cursorPosition = (_cursorPosition + text.length + cursorOffset).clamp(0, display.length);
    });
  }

  void _deleteAtCursor() {
    if (_cursorPosition > 0) {
      setState(() {
        display = display.substring(0, _cursorPosition - 1) + display.substring(_cursorPosition);
        _cursorPosition--;
      });
      speak('Smazáno');
    }
  }

  void calculateResult() {
    try {
      if (display.isEmpty) {
        return;
      }
      double result = _evaluateExpression(display);
      bool isDms = display.contains('°→\'');
      String resStr = isDms ? _formatAsDMS(result) : _formatNumber(result);
      
      setState(() {
        _lastResult = resStr;
        _hasResult = true;
        display = '';
        _cursorPosition = 0;
      });

      if (isDms) {
        String spoken = resStr
            .replaceAll('°', ' stupňů, ')
            .replaceAll('\'', ' minut a ')
            .replaceAll('"', ' sekund')
            .replaceAll('.', ',');
        speak('Výsledek je $spoken');
      } else {
        speak('Výsledek je ${resStr.replaceAll('.', ',')}');
      }
      _addToHistory(display, resStr);
    } catch (e) {
      setState(() {
        _lastResult = 'Error';
        _hasResult = true;
      });
      speak('Chyba');
    }
  }

  double _evaluateExpression(String expr) {
    String processed = expr.replaceAll(',', '.').replaceAll('°→\'', '').replaceAll('\'→°', '').replaceAll('°', '').replaceAll('\'', '').replaceAll('"', '');
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)[eE]([+-]?\d+)'), (m) => '(${m[1]}*10^(${m[2]}))');
    processed = processed.replaceAll('x²', '^2').replaceAll('x³', '^3').replaceAll('(-)', '-');
    _memory.forEach((key, value) => processed = processed.replaceAll(RegExp('\\b$key\\b'), '($value)'));
    String ansValue = _lastResult.toLowerCase() == 'error' ? '0' : _lastResult;
    processed = processed.replaceAll('ANS', '($ansValue)').replaceAll(' ', '');
    try {
      final p = math_expr.ShuntingYardParser();
      return p.parse(processed).evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());
    } catch (e) {
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
        int engExp = ((math.log(value.abs()) / math.ln10).floor() / 3).floor() * 3;
        return "${(value / math.pow(10, engExp)).toStringAsFixed(_precision)}E${engExp >= 0 ? '+' : ''}${engExp.toString().padLeft(2, '0')}";
      default:
        return value.toString().contains('.') ? value.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : value.toInt().toString();
    }
  }

  String _formatAsDMS(double value) {
    double absVal = value.abs();
    int d = absVal.floor();
    int m = ((absVal - d) * 60).floor();
    double s = ((absVal - d - m / 60) * 3600);
    return "${value < 0 ? '-' : ''}$d°$m'${s.toStringAsFixed(1)}\"";
  }

  void _convertUnits() {
    try {
      double value = display.isNotEmpty ? _evaluateExpression(display) : double.parse(_lastResult.replaceAll(',', '.'));
      double fromFactor = _unitCategories[_selectedUnitCategory]![_unitFrom]!;
      double toFactor = _unitCategories[_selectedUnitCategory]![_unitTo]!;
      double result = value * (fromFactor / toFactor);
      String resStr = _formatNumber(result);
      setState(() {
        _lastResult = resStr;
        display = '';
        _hasResult = true;
      });
      speak('Převedeno z ${_getUnitSpeech(_unitFrom, context: 'z')} na ${_getUnitSpeech(_unitTo, context: 'na')}. Výsledek je $resStr ${_getUnitSpeech(_unitTo, value: result)}');
    } catch (e) {
      speak('Chyba převodu');
    }
  }

  String _getUnitSpeech(String unitCode, {double? value, String context = 'base'}) {
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
    const map = {'á': 'A', 'č': 'C', 'ď': 'D', 'é': 'E', 'ě': 'E', 'í': 'I', 'ň': 'N', 'ó': 'O', 'ř': 'R', 'š': 'S', 'ť': 'T', 'ú': 'U', 'ů': 'U', 'ý': 'Y', 'ž': 'Z'};
    String result = text;
    map.forEach((key, value) => result = result.replaceAll(key, value).replaceAll(key.toUpperCase(), value));
    return result;
  }

  Widget _buildMainResultDisplay() {
    String res = _lastResult.isEmpty ? '0.' : _lastResult;
    if (res.contains('°')) {
      return _buildDmsDisplay(res);
    }
    if ((_displayFormat != DisplayFormat.standard) && res.toLowerCase() != 'error') {
      return _buildScientificTripleDisplay(res);
    }
    return _buildStandardDisplay(res);
  }

  Widget _buildStandardDisplay(String res) {
    return _useSixteenSegment
        ? SixteenSegmentDisplay(value: _normalizeForSegmentDisplay(res), size: 16 * _fontSizeMultiplier, characterSpacing: 8, characterCount: 16, segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withValues(alpha: 0.05)))
        : SevenSegmentDisplay(value: _normalizeForSegmentDisplay(res), size: 16 * _fontSizeMultiplier, characterSpacing: 8, characterCount: 16, segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withValues(alpha: 0.05)));
  }

  Widget _buildScientificTripleDisplay(String text) {
    List<String> parts = text.contains('E') ? text.split('E') : [text, '00'];
    String mantissa = parts[0];
    String exponent = parts[1].replaceAll('+', '');
    String formattedExp = exponent.startsWith('-') ? '-${exponent.substring(1).padLeft(2, '0')}' : exponent.padLeft(3, '0');
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      _buildStandardDisplay(mantissa),
      const SizedBox(width: 8),
      Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        const Text('x10', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        SevenSegmentDisplay(value: formattedExp, size: 8 * _fontSizeMultiplier, characterSpacing: 2, characterCount: 3, segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withValues(alpha: 0.05))),
      ]),
    ]);
  }

  Widget _buildDmsDisplay(String text) {
    List<Widget> children = [];
    bool hasMinus = text.startsWith('-');
    String cleanText = hasMinus ? text.substring(1) : text;

    RegExp dmsRegex = RegExp(r'''(\d+(?:\.\d+)?)([°'"])''');
    Iterable<RegExpMatch> matches = dmsRegex.allMatches(cleanText);
    if (matches.isEmpty) {
      return _buildStandardDisplay(text);
    }

    int slotsUsed = hasMinus ? 1 : 0;
    for (var m in matches) {
      slotsUsed += m.group(1)!.length + 1;
    }

    int padding = (16 - slotsUsed).clamp(0, 16);
    for (int i = 0; i < padding; i++) {
      children.add(Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 12 * _fontSizeMultiplier,
          height: 16 * _fontSizeMultiplier,
          child: CustomPaint(painter: _SegmentPainter(List.filled(7, false), Colors.redAccent))));
    }

    if (hasMinus) {
      children.add(SevenSegmentDisplay(
          value: '-',
          size: 16 * _fontSizeMultiplier,
          characterSpacing: 4,
          characterCount: 1,
          segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withValues(alpha: 0.05))));
    }

    for (var m in matches) {
      String val = m.group(1)!;
      children.add(SevenSegmentDisplay(
          value: val,
          size: 16 * _fontSizeMultiplier,
          characterSpacing: 4,
          characterCount: val.length,
          segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withValues(alpha: 0.05))));

      String sym = m.group(2)!;
      List<bool> segs = sym == '°' ? [true, true, false, false, false, true, true] : (sym == '\'' ? [false, false, false, false, false, true, false] : [false, true, false, false, false, true, false]);

      children.add(Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 12 * _fontSizeMultiplier,
          height: 16 * _fontSizeMultiplier,
          child: CustomPaint(painter: _SegmentPainter(segs, Colors.redAccent))));
    }
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: children);
  }

  void _changeMode(CalculatorMode mode) {
    setState(() {
      _currentMode = mode;
      display = '';
    });
    speak('Aktivní režim ${_getModeName(mode)}');
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDegreeMode = prefs.getBool('isDegreeMode') ?? true;
      _fontSizeMultiplier = prefs.getDouble('fontSizeMultiplier') ?? 1.0;
      ttsEnabled = prefs.getBool('ttsEnabled') ?? true;
      _useSixteenSegment = prefs.getBool('useSixteenSegment') ?? false;
      _accessibilityType = AccessibilityType.values[prefs.getInt('accessibilityType') ?? 0];
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDegreeMode', _isDegreeMode);
    await prefs.setDouble('fontSizeMultiplier', _fontSizeMultiplier);
    await prefs.setBool('ttsEnabled', ttsEnabled);
    await prefs.setBool('useSixteenSegment', _useSixteenSegment);
    await prefs.setInt('accessibilityType', _accessibilityType.index);
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList('history') ?? []);
  }

  void _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history);
  }

  void _addToHistory(String exp, String res) {
    setState(() {
      _history.insert(0, '$exp = $res');
      if (_history.length > 20) _history.removeLast();
    });
    _saveHistory();
  }

  void _showInitialAccessibilityDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(title: const Text('Vítejte'), content: const Text('Vyberte usnadnění'), actions: [
              TextButton(
                  onPressed: () {
                    setState(() => _accessibilityType = AccessibilityType.none);
                    _saveSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('STANDARD')),
              TextButton(
                  onPressed: () {
                    setState(() {
                      _accessibilityType = AccessibilityType.blind;
                      ttsEnabled = true;
                    });
                    _saveSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('NEVIDOMÍ')),
            ]));
  }

  void _showAccessibilityDialog() {
    showDialog(context: context, builder: (context) => _AccessibilityDialog(parent: this));
  }

  void _showTutorialDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Nápověda'), content: const Text('Kalkulačka s převody a vědeckým displejem.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  }

  void _showPrecisionDialog(DisplayFormat format) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Přesnost'), content: Wrap(spacing: 8, children: List.generate(10, (i) => ElevatedButton(onPressed: () { setState(() { _displayFormat = format; _precision = i; }); speak('Nastaveno $i'); Navigator.pop(context); }, child: Text('$i'))))));
  }

  Widget _buildDotMatrixDisplay() {
    String txt = display.isEmpty ? "_" : "${display.substring(0, _cursorPosition)}_${display.substring(_cursorPosition)}";
    return DotMatrixText(text: txt, textStyle: const TextStyle(fontSize: 48, color: Colors.redAccent, fontWeight: FontWeight.bold), ledSize: 3.0, ledSpacing: 0.8);
  }

  Widget buildButton(String label, {Color? color, String? semanticLabel, VoidCallback? onPressed}) {
    return Padding(
        padding: const EdgeInsets.all(2),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: color != null ? Colors.white : null, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
          onPressed: onPressed ??
              () {
                speak(_buttonNames[label] ?? label);
                _handleButtonPressed(label);
              },
          child: Semantics(button: true, label: semanticLabel ?? (_buttonNames[label] ?? label), child: ExcludeSemantics(child: Text(label, style: TextStyle(fontSize: 18 * _fontSizeMultiplier, fontWeight: FontWeight.bold)))),
        ));
  }

  void _handleButtonPressed(String label) {
    if (_hasResult) {
      if (['+', '-', '*', '/', '^'].contains(label)) {
        display = 'ANS';
        _hasResult = false;
      } else if (RegExp(r'[0-9.]').hasMatch(label) || ['SIN', 'COS', 'TAN', '('].contains(label)) {
        display = '';
        _hasResult = false;
      } else {
        _hasResult = false;
      }
    }
    if (label == 'C') {
      clear();
    } else if (label == 'DEL') {
      backspace();
    } else if (label == '=') {
      calculateResult();
    } else if (label == 'STO') {
      _isStoreMode = true;
      speak('Vyberte paměť');
    } else if (_memory.containsKey(label)) {
      if (_isStoreMode) {
        double val = 0;
        try {
          val = double.parse(_lastResult.replaceAll(',', '.'));
        } catch (_) {}
        setState(() {
          _memory[label] = val;
          _isStoreMode = false;
        });
        speak('Uloženo');
      } else {
        append(label);
      }
    } else if (label == 'EXP') {
      append('E');
    } else if (['SIN', 'COS', 'TAN', '√', 'ABS'].contains(label)) {
      _insertAtCursor('$label(', cursorOffset: 0);
    } else if (['°→\'', 'DMS', 'π'].contains(label)) {
      append(label == 'DMS' ? '°\'"' : label);
    } else {
      append(label);
    }
  }

  Widget _buildMainKeyboard({double aspectRatio = 1.0}) {
    List<String> btns = ['C', '(', ')', '/', '7', '8', '9', '*', '4', '5', '6', '-', '1', '2', '3', '+', 'DEL', '0', '.', '='];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: aspectRatio,
      children: btns.map((b) {
        if (b == 'C') {
          return buildButton('C', color: Colors.orange, semanticLabel: 'Vymazat displej', onPressed: () => clear());
        }
        if (b == 'DEL') {
          return buildButton('DEL', color: Colors.redAccent, semanticLabel: 'Smazat poslední', onPressed: () => backspace());
        }
        if (b == '=') {
          return buildButton('=', color: Colors.green, semanticLabel: 'Rovná se', onPressed: () => calculateResult());
        }
        return buildButton(b, color: ['/', '*', '-', '+'].contains(b) ? Colors.blue : null);
      }).toList(),
    );
  }

  Widget _buildModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
          children: CalculatorMode.values.map((mode) {
        String label = _getModeName(mode);
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
                label: Text(label),
                selected: _currentMode == mode,
                onSelected: (s) {
                  if (s) {
                    _changeMode(mode);
                  }
                }));
      }).toList()),
    );
  }

  List<Widget> _buildFunctionSections() {
    List<Widget> sections = [];
    if (_currentMode == CalculatorMode.unitConversion) {
      sections.add(Padding(
          padding: const EdgeInsets.all(12.0),
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(children: [
                    DropdownButtonFormField<String>(
                        value: _selectedUnitCategory,
                        decoration: const InputDecoration(labelText: 'Kategorie'),
                        items: _unitCategories.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedUnitCategory = val!;
                            _unitFrom = _unitCategories[val]!.keys.first;
                            _unitTo = _unitCategories[val]!.keys.elementAt(1);
                          });
                          speak('Kategorie $val');
                        }),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              value: _unitFrom,
                              decoration: const InputDecoration(labelText: 'Z'),
                              items: _unitCategories[_selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(_getUnitSpeech(u)))).toList(),
                              onChanged: (val) {
                                setState(() => _unitFrom = val!);
                                speak('Z jednotky ${_getUnitSpeech(val!)}');
                              })),
                      const Icon(Icons.arrow_forward),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              value: _unitTo,
                              decoration: const InputDecoration(labelText: 'Na'),
                              items: _unitCategories[_selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(_getUnitSpeech(u)))).toList(),
                              onChanged: (val) {
                                setState(() => _unitTo = val!);
                                speak('Na jednotku ${_getUnitSpeech(val!)}');
                              })),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _convertUnits, icon: const Icon(Icons.sync), label: const Text('PŘEVÉST'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)))),
                  ])))));
    }
    sections.add(ExpansionTile(
        title: const Text('Funkce', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, childAspectRatio: 1.3, children: ['SIN', 'COS', 'TAN', '√', 'EXP', 'π', '°→\'', 'DMS', 'STO', 'RCL', 'ANS'].map((b) => buildButton(b)).toList())]));
    sections.add(ExpansionTile(title: const Text('Zobrazení', style: TextStyle(fontWeight: FontWeight.bold)), children: [
      Padding(
        padding: const EdgeInsets.all(4.0),
        child: Wrap(alignment: WrapAlignment.start, spacing: 4, runSpacing: 4, children: [
          buildButton('NORM', onPressed: () {
            setState(() => _displayFormat = DisplayFormat.standard);
            speak('Standardní');
          }),
          buildButton('FIX', onPressed: () => _showPrecisionDialog(DisplayFormat.fix)),
          buildButton('SCI', onPressed: () => _showPrecisionDialog(DisplayFormat.sci)),
          buildButton('ENG', onPressed: () => _showPrecisionDialog(DisplayFormat.eng))
        ]),
      )
    ]));
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isWideScreen = size.width > 600;
    return KeyboardListener(
      focusNode: _mainFocusNode,
      onKeyEvent: _handleKeyboardInput,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mluvící kalkulačka'), actions: [IconButton(icon: const Icon(Icons.help_outline), onPressed: _showTutorialDialog), IconButton(icon: const Icon(Icons.settings), onPressed: _showAccessibilityDialog)]),
        body: Column(
          children: [
            Expanded(
                flex: (1000 * _displaySizeFactor).toInt(),
                child: GestureDetector(
                  onTap: () => _mainFocusNode.requestFocus(),
                  child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF121212), border: Border.all(color: Colors.black, width: 3)),
                      alignment: Alignment.bottomRight,
                      child: Semantics(
                          liveRegion: true,
                          label: 'Displej',
                          value: display.isEmpty ? 'Prázdno' : display.replaceAll('.', ','),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_getModeName(_currentMode).toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Flexible(child: FittedBox(child: _buildDotMatrixDisplay())),
                                const SizedBox(height: 12),
                                Flexible(child: FittedBox(child: _buildMainResultDisplay()))
                              ]))),
                )),
            _buildModeSelector(),
            Expanded(flex: 1000, child: LayoutBuilder(builder: (context, constraints) {
              if (isWideScreen) {
                return Row(children: [
                  Expanded(child: ListView(children: _buildFunctionSections())),
                  const VerticalDivider(),
                  Expanded(child: _buildMainKeyboard(aspectRatio: (constraints.maxWidth / 2 / 4) / (constraints.maxHeight / 5)))
                ]);
              }
              return Column(children: [
                Expanded(child: ListView(children: _buildFunctionSections())),
                const Divider(),
                SizedBox(height: constraints.maxHeight * 0.65, child: _buildMainKeyboard(aspectRatio: (constraints.maxWidth / 4) / (constraints.maxHeight * 0.65 / 5)))
              ]);
            })),
          ],
        ),
      ),
    );
  }
}

class _SegmentPainter extends CustomPainter {
  final List<bool> segments;
  final Color color;
  _SegmentPainter(this.segments, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = color
      ..strokeWidth = size.width / 5
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = size.width / 5
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    void draw(int index, Offset p1, Offset p2) {
      canvas.drawLine(p1, p2, segments[index] ? activePaint : inactivePaint);
    }

    draw(0, Offset(w * 0.2, 0), Offset(w * 0.8, 0)); // a
    draw(1, Offset(w, h * 0.05), Offset(w, h * 0.45)); // b
    draw(2, Offset(w, h * 0.55), Offset(w, h * 0.95)); // c
    draw(3, Offset(w * 0.2, h), Offset(w * 0.8, h)); // d
    draw(4, Offset(0, h * 0.55), Offset(0, h * 0.95)); // e
    draw(5, Offset(0, h * 0.05), Offset(0, h * 0.45)); // f
    draw(6, Offset(w * 0.2, h * 0.5), Offset(w * 0.8, h * 0.5)); // g
  }

  @override
  bool shouldRepaint(CustomPainter old) => true;
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
        title: const Text('Nastavení'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
              title: const Text('Hlas'),
              value: widget.parent.ttsEnabled,
              onChanged: (v) {
                setState(() {
                  widget.parent.setState(() => widget.parent.ttsEnabled = v);
                  widget.parent._saveSettings();
                });
              }),
          SwitchListTile(
              title: const Text('16 seg'),
              value: widget.parent._useSixteenSegment,
              onChanged: (v) {
                setState(() {
                  widget.parent.setState(() => widget.parent._useSixteenSegment = v);
                  widget.parent._saveSettings();
                });
              }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HOTOVO'))
        ]);
  }
}
