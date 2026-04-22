import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:math_expressions/math_expressions.dart' as math_expr;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

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
    processed = processed.replaceAllMapped(RegExp(r"(\d+(?:,\d+)?)E([+-])(\d+)"), (m) {
      int exp = int.parse(m[3]!);
      return '${m[1]} krát deset na ${m[2] == '-' ? 'mínus ' : ''}$exp';
    });
    return processed;
  }

  void _handleKeyboardInput(KeyEvent event) {
    if (event is KeyDownEvent) {
      final char = event.character;
      final isControl = HardwareKeyboard.instance.isControlPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        calculateResult();
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        backspace();
      } else if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.delete) {
        clear();
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyD) {
        if (isShift) {
          _handleButtonPressed("'→°");
        } else {
          _handleButtonPressed("°→'");
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyD || event.logicalKey == LogicalKeyboardKey.keyM) {
        _handleButtonPressed("DMS");
      } else if (char != null) {
        String toAppend = char == ',' ? '.' : char;
        if (RegExp(r'[0-9.+\-*/^%()eE]').hasMatch(toAppend)) {
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
      
      bool isDms = display.contains('°→\'') || display.contains('°') || display.contains('\'') || display.contains('"');
      
      double result = _evaluateExpression(display);
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
    String ansValue = _lastResult.toLowerCase() == 'error' ? '0' : _lastResult;
    String processed = expr.replaceAll('ANS', '($ansValue)').replaceAll(' ', '');
    processed = processed.replaceAll(',', '.').replaceAll('π', '3.141592653589793');
    processed = processed.replaceAll('°→\'', '').replaceAll('\'→°', '');
    
    processed = processed.replaceAllMapped(RegExp(r'''(-?\d+(?:\.\d+)?)°(?:(\d+(?:\.\d+)?)\')?(?:(\d+(?:\.\d+)?)\")?'''), (m) {
      double d = double.parse(m[1]!);
      double mn = m[2] != null ? double.parse(m[2]!) : 0.0;
      double sc = m[3] != null ? double.parse(m[3]!) : 0.0;
      double sign = d < 0 ? -1.0 : 1.0;
      return '(${sign * (d.abs() + mn / 60.0 + sc / 3600.0)})';
    });

    processed = processed.replaceAllMapped(RegExp(r"(\d+(?:\.\d+)?)[eE]([+-]?\d+)"), (m) => '(${m[1]}*10^(${m[2]}))');
    processed = processed.replaceAll('x²', '^2').replaceAll('x³', '^3').replaceAll('(-)', '-');
    
    if (_isDegreeMode) {
      processed = processed.replaceAll('SIN(', 'sin((3.141592653589793/180)*');
      processed = processed.replaceAll('COS(', 'cos((3.141592653589793/180)*');
      processed = processed.replaceAll('TAN(', 'tan((3.141592653589793/180)*');
      processed = processed.replaceAll('ASIN(', '(180/3.141592653589793)*asin(');
      processed = processed.replaceAll('ACOS(', '(180/3.141592653589793)*acos(');
      processed = processed.replaceAll('ATAN(', '(180/3.141592653589793)*atan(');
    } else {
      processed = processed.replaceAll('SIN(', 'sin(').replaceAll('COS(', 'cos(').replaceAll('TAN(', 'tan(');
      processed = processed.replaceAll('ASIN(', 'asin(').replaceAll('ACOS(', 'acos(').replaceAll('ATAN(', 'atan(');
    }
    processed = processed.replaceAll('ABS(', 'abs(').replaceAll('√(', 'sqrt(');

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
    String sStr = s.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return "${value < 0 ? '-' : ''}$d°$m'$sStr\"";
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
    return CustomSegmentDisplay(
      value: _normalizeForSegmentDisplay(res),
      size: 16 * _fontSizeMultiplier,
      characterCount: 16,
      isSixteenSegment: _useSixteenSegment,
    );
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
        CustomSegmentDisplay(
          value: formattedExp,
          size: 8 * _fontSizeMultiplier,
          characterCount: 3,
          isSixteenSegment: false,
        ),
      ]),
    ]);
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
    speak('Aktivní je ${_getModeSpeechName(mode)}');
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
    return CustomDotMatrixDisplay(text: txt, ledSize: 3.0, ledSpacing: 0.8);
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
    } else if (label == 'DMS') {
      if (display.isEmpty) {
        append('°');
      } else {
        // Hledáme poslední číslo na displeji (od konce)
        RegExp dmsRegex = RegExp(r'(\d+(?:\.\d+)?)(°|\'|")?$');
        Match? match = dmsRegex.firstMatch(display);
        if (match != null) {
          String? suffix = match.group(2);
          if (suffix == '°') {
            append("'");
          } else if (suffix == "'") {
            append('"');
          } else if (suffix == '"') {
            append('°');
          } else {
            append('°');
          }
        } else {
          append('°');
        }
      }
    } else if (['°→\'', '\'→°', 'π'].contains(label)) {
      append(label);
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
              final bool isWideScreen = constraints.maxWidth > 600;
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
          padding: EdgeInsets.only(right: index == characterCount - 1 ? 0 : characterSpacing),
          child: SizedBox(
            width: size * 1.5,
            height: size * 1.8,
            child: CustomPaint(
              painter: isSixteenSegment
                  ? _CustomSixteenSegmentPainter(chars[index].char, chars[index].hasDot, enabledColor, disabledColor)
                  : _CustomSevenSegmentPainter(chars[index].char, chars[index].hasDot, enabledColor, disabledColor),
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

  _CustomSevenSegmentPainter(this.char, this.showDot, this.enabledColor, this.disabledColor);

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
    '"': [false, true, false, false, false, true, false],
    '.': [false, false, false, false, false, false, false],
    '_': [false, false, false, true, false, false, false],
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
    canvas.drawCircle(Offset(w + thickness * 1.5, h), thickness * 0.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CustomSixteenSegmentPainter extends CustomPainter {
  final String char;
  final bool showDot;
  final Color enabledColor;
  final Color disabledColor;

  _CustomSixteenSegmentPainter(this.char, this.showDot, this.enabledColor, this.disabledColor);

  // A1, A2, B, C, D2, D1, E, F, G2, G1, H, I, J, K, L, M
  static const Map<String, List<bool>> _map = {
    '0': [true, true, true, true, true, true, true, true, false, false, false, false, true, true, false, false],
    '1': [false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false],
    '2': [true, true, true, false, true, true, true, false, true, true, false, false, false, false, false, false],
    '3': [true, true, true, true, true, true, false, false, true, false, false, false, false, false, false, false],
    '4': [false, false, true, true, false, false, false, true, true, true, false, false, false, false, false, false],
    '5': [true, true, false, true, true, true, false, true, true, true, false, false, false, false, false, false],
    '6': [true, true, false, true, true, true, true, true, true, true, false, false, false, false, false, false],
    '7': [true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false],
    '8': [true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false],
    '9': [true, true, true, true, false, false, false, true, true, true, false, false, false, false, false, false],
    'A': [true, true, true, true, false, false, true, true, true, true, false, false, false, false, false, false],
    'B': [true, true, true, true, true, true, false, false, true, false, false, true, false, false, true, false],
    'C': [true, true, false, false, true, true, true, true, false, false, false, false, false, false, false, false],
    'D': [true, true, true, true, true, true, false, false, false, false, false, true, false, false, true, false],
    'E': [true, true, false, false, true, true, true, true, true, true, false, false, false, false, false, false],
    'F': [true, true, false, false, false, false, true, true, true, true, false, false, false, false, false, false],
    'H': [false, false, true, true, false, false, true, true, true, true, false, false, false, false, false, false],
    'I': [true, true, false, false, true, true, false, false, false, false, false, true, false, false, true, false],
    'J': [false, false, true, true, true, true, true, false, false, false, false, false, false, false, false, false],
    'K': [false, false, false, false, false, false, true, true, false, true, false, false, true, true, false, false],
    'L': [false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false],
    'M': [false, false, true, true, false, false, true, true, false, false, true, false, true, false, false, false],
    'N': [false, false, true, true, false, false, true, true, false, false, true, false, false, false, false, true],
    'O': [true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false],
    'P': [true, true, true, false, false, false, true, true, true, true, false, false, false, false, false, false],
    'Q': [true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, true],
    'R': [true, true, true, false, false, false, true, true, true, true, false, false, false, false, false, true],
    'S': [true, true, false, true, true, true, false, true, true, true, false, false, false, false, false, false],
    'T': [true, true, false, false, false, false, false, false, false, false, false, true, false, false, true, false],
    'U': [false, false, true, true, true, true, true, true, false, false, false, false, false, false, false, false],
    'V': [false, false, false, false, false, false, true, true, false, false, false, false, true, true, false, false],
    'W': [false, false, true, true, false, false, true, true, false, false, false, false, false, true, false, true],
    'X': [false, false, false, false, false, false, false, false, false, false, true, false, true, true, false, true],
    'Y': [false, false, false, false, false, false, false, false, false, false, true, false, true, false, true, false],
    'Z': [true, true, false, false, true, true, false, false, false, false, false, false, true, true, false, false],
    '-': [false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false],
    '°': [true, true, true, false, false, false, false, true, true, true, false, false, false, false, false, false],
    "'": [false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false],
    '"': [false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false],
    '_': [false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false],
    ' ': [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
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
    draw(8, Offset(w / 2 + thickness / 4, h / 2), Offset(w - thickness, h / 2)); // G2
    draw(9, Offset(thickness, h / 2), Offset(w / 2 - thickness / 4, h / 2)); // G1
    draw(10, Offset(thickness, thickness), Offset(w / 2 - thickness / 2, h / 2 - thickness / 2)); // H
    draw(11, Offset(w / 2, thickness), Offset(w / 2, h / 2 - thickness / 2)); // I
    draw(12, Offset(w - thickness, thickness), Offset(w / 2 + thickness / 2, h / 2 - thickness / 2)); // J
    draw(13, Offset(thickness, h - thickness), Offset(w / 2 - thickness / 2, h / 2 + thickness / 2)); // K
    draw(14, Offset(w / 2, h - thickness), Offset(w / 2, h / 2 + thickness / 2)); // L
    draw(15, Offset(w - thickness, h - thickness), Offset(w / 2 + thickness / 2, h / 2 + thickness / 2)); // M

    // Decimální tečka (DP) - odsazená od číslice
    final dotPaint = Paint()..color = showDot ? enabledColor : disabledColor;
    canvas.drawCircle(Offset(w + thickness * 1.5, h), thickness * 0.8, dotPaint);
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
            size: Size(ledSize * 5 + ledSpacing * 4, ledSize * 7 + ledSpacing * 6),
            painter: _CustomDotMatrixPainter(char, ledSize, ledSpacing, enabledColor, disabledColor),
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

  _CustomDotMatrixPainter(this.char, this.ledSize, this.ledSpacing, this.enabledColor, this.disabledColor);

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
    '(': [0x00, 0x0E, 0x11, 0x00, 0x00],
    ')': [0x00, 0x00, 0x11, 0x0E, 0x00],
    '+': [0x04, 0x04, 0x1F, 0x04, 0x04],
    '*': [0x00, 0x0A, 0x04, 0x0A, 0x00],
    '/': [0x10, 0x08, 0x04, 0x02, 0x01],
    '%': [0x19, 0x05, 0x02, 0x14, 0x13],
    '^': [0x02, 0x01, 0x02, 0x00, 0x00],
    ',': [0x00, 0x00, 0x18, 0x00, 0x00],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final data = _font[char.toUpperCase()] ?? [0x1F, 0x1F, 0x1F, 0x1F, 0x1F];
    final paint = Paint()..style = PaintingStyle.fill;

    for (int col = 0; col < 5; col++) {
      for (int row = 0; row < 7; row++) {
        bool enabled = (data[col] >> row) & 1 == 1;
        paint.color = enabled ? enabledColor : disabledColor;
        canvas.drawCircle(
          Offset(col * (ledSize + ledSpacing) + ledSize / 2, row * (ledSize + ledSpacing) + ledSize / 2),
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
