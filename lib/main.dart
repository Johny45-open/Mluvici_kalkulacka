import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:math_expressions/math_expressions.dart' as math_expr;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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
  bool? _preferDMSForInverse;
  bool _preferExponential = false;
  bool _useSixteenSegment = false;
  bool _sayWelcome = true;
  AccessibilityType _accessibilityType = AccessibilityType.none;
  double _fontSizeMultiplier = 1.0;
  double _displaySizeFactor = 1.0;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  
  DisplayFormat _displayFormat = DisplayFormat.standard;
  int _precision = 2;

  DateTime? _lastSpeakTime;
  final Duration _speakThrottle = const Duration(milliseconds: 300);

  bool _isGonioExpanded = false;
  bool _isFunctionsExpanded = false;
  bool _isMemoryExpanded = false;
  bool _isElectricianExpanded = true;
  bool _isStatsExpanded = true;
  bool _isVariablesExpanded = false;

  final Map<String, double> _memory = {
    'A': 0, 'B': 0, 'C': 0, 'D': 0, 'E': 0, 'F': 0,
    'X': 0, 'Y': 0, 'M': 0,
  };

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
  };

  String _selectedUnitCategory = 'Délka';
  String _unitFrom = 'm';
  String _unitTo = 'km';

  List<String> _history = [];

  final Map<String, String> _buttonNames = {
    'SIN': 'Sinus', 'COS': 'Kosinus', 'TAN': 'Tangens',
    'ASIN': 'Arkus sinus', 'ACOS': 'Arkus kosinus', 'ATAN': 'Arkus tangens',
    'ABS': 'Absolutní hodnota',
    '°→\'': 'Převod na DMS', '\'→°': 'Převod na stupně', 'DMS': 'Vložit DMS',
    '=': 'Rovná se', '/': 'Lomeno', '*': 'Krát', '-': 'Mínus', '+': 'Plus',
    '(': 'Závorka otevřená', ')': 'Závorka zavřená', '.': 'Tečka',
    '^': 'Mocnina', '√': 'Odmocnina', 'ⁿ√': 'Odmocnina en',
    'x²': 'Na druhou', 'x³': 'Na třetí', '∛': 'Třetí odmocnina', '1/x': 'Převrácená hodnota',
    'ANS': 'Poslední výsledek', 'STO': 'Uložit do paměti', 'DEL': 'Smazat poslední',
    'RCL': 'Vyvolat z paměti', 'CLR': 'Smazat celou paměť', 'C': 'Smazat displej',
    'DEG': 'Stupně', 'RAD': 'Radiány', '%': 'Procenta',
    'SD': 'Směrodatná odchylka', 'VAR': 'Rozptyl', 'MEAN': 'Průměr', 'STATS': 'Statistický souhrn',
    'CV': 'Variační koeficient',
    ';': 'Oddělovač dat',
    '(-)': 'Záporné číslo se závorkou',
    'EXP': 'krát deset na',
    'OHM_V': 'Napětí', 'OHM_I': 'Proud', 'OHM_R': 'Odpor',
    'PWR_P': 'Výkon', 'PAR': 'Paralelně', 'SER': 'Sériově',
    'XL': 'Indukčnost', 'XC': 'Kapacita', 'Hz': 'Hertz',
    'μ': 'Mikro', 'n': 'Nano', 'p': 'Piko',
  };

  bool _isStoreMode = false;
  bool _hasResult = false;

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

  void _handleKeyboardInput(KeyEvent event) {
    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;
      final char = event.character;

      if (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.numpadEnter) {
        calculateResult();
      } else if (logicalKey == LogicalKeyboardKey.backspace) {
        backspace();
      } else if (logicalKey == LogicalKeyboardKey.escape || logicalKey == LogicalKeyboardKey.delete) {
        clear();
      } else if (char != null) {
        String toAppend = char;
        if (char == ',') toAppend = '.';
        if (RegExp(r'[0-9.+\-*/^%()eEa-zA-Z]').hasMatch(toAppend)) {
          append(toAppend.toUpperCase(), silent: true);
        }
      }
    }
  }

  void _initTts() async {
    try {
      await tts.setLanguage("cs-CZ");
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_speechVolume);
      await tts.awaitSpeakCompletion(false);
      if (_sayWelcome) {
        speak('Kalkulačka připravena k práci');
      }
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }

    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('accessibilityType')) {
        _showInitialAccessibilityDialog();
      }
    });
  }

  void _changeMode(CalculatorMode mode) {
    setState(() {
      _currentMode = mode;
      display = '';
    });
    String modeName = '';
    switch (mode) {
      case CalculatorMode.basic: modeName = 'Základní režim'; break;
      case CalculatorMode.scientific: modeName = 'Vědecký režim'; break;
      case CalculatorMode.statistics: modeName = 'Statistický režim'; break;
      case CalculatorMode.electrician: modeName = 'Elektrotechnický režim'; break;
      case CalculatorMode.unitConversion: modeName = 'Režim převodu jednotek'; break;
    }
    speak(modeName);
  }

  String _getUnitSpeech(String unitCode, {double? value, String context = 'base'}) {
    final data = _unitSpeechData[unitCode];
    if (data == null) return unitCode;
    if (value != null) {
      double absVal = value.abs();
      if (absVal % 1 != 0) return data['forms'][3]; 
      if (absVal == 1) return data['forms'][0];
      if (absVal >= 2 && absVal <= 4) return data['forms'][1];
      return data['forms'][2];
    }
    return data[context] ?? data['base'];
  }

  void _convertUnits() {
    try {
      double value;
      if (display.isNotEmpty) {
        value = _evaluateExpression(display);
      } else {
        value = double.parse(_lastResult.replaceAll(',', '.'));
      }

      double fromFactor = _unitCategories[_selectedUnitCategory]![_unitFrom]!;
      double toFactor = _unitCategories[_selectedUnitCategory]![_unitTo]!;
      double result = value * (fromFactor / toFactor);
      
      String resStr = _formatNumber(result);
      setState(() {
        _lastResult = resStr;
        display = '';
        _hasResult = true;
      });

      String unitFromName = _getUnitSpeech(_unitFrom, context: 'z');
      String unitToName = _getUnitSpeech(_unitTo, context: 'na');
      String resultUnitName = _getUnitSpeech(_unitTo, value: result);

      speak('Převedeno z $unitFromName na $unitToName. Výsledek je ${resStr.replaceAll('.', ',')} $resultUnitName');
      _addToHistory('Převod ${value.toString().replaceAll('.', ',')} $_unitFrom na $_unitTo', resStr);
    } catch (e) {
      speak('Chyba při převodu. Ujistěte se, že na displeji je platné číslo.');
    }
  }

  Widget _buildScientificTripleDisplay(String text) {
    String mantissa;
    String exponent;

    if (text.contains('E')) {
      List<String> parts = text.split('E');
      mantissa = parts[0];
      exponent = parts[1];
    } else {
      // Pokud text nemá E (např. v režimu FIX), mantisa je celé číslo a exponent je 0
      mantissa = text;
      exponent = '00';
    }
    
    String formattedExp = exponent.replaceAll('+', '');
    if (!formattedExp.startsWith('-')) {
      formattedExp = formattedExp.padLeft(3, '0');
    } else {
      String digits = formattedExp.substring(1).padLeft(2, '0');
      formattedExp = '-$digits';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _useSixteenSegment 
          ? SixteenSegmentDisplay(
              value: _normalizeForSegmentDisplay(mantissa),
              size: 16 * _fontSizeMultiplier,
              characterSpacing: 4,
              characterCount: 8,
              segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withOpacity(0.05)),
            )
          : SevenSegmentDisplay(
              value: _normalizeForSegmentDisplay(mantissa),
              size: 16 * _fontSizeMultiplier,
              characterSpacing: 4,
              characterCount: 8,
              segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withOpacity(0.05)),
            ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('x10', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            SevenSegmentDisplay(
              value: formattedExp,
              size: 8 * _fontSizeMultiplier,
              characterSpacing: 2,
              characterCount: 3,
              segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withOpacity(0.05)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainResultDisplay() {
    String res = _lastResult.isEmpty ? '0.' : _lastResult;
    
    // Pokud je zapnutý jakýkoliv profi formát (FIX, SCI, ENG), použijeme Triple-Display
    if ((_displayFormat == DisplayFormat.sci || 
         _displayFormat == DisplayFormat.eng || 
         _displayFormat == DisplayFormat.fix) && 
        res.toLowerCase() != 'error') {
      return _buildScientificTripleDisplay(res);
    }

    return _useSixteenSegment 
      ? SixteenSegmentDisplay(
          value: _normalizeForSegmentDisplay(res),
          size: 16 * _fontSizeMultiplier,
          characterSpacing: 8,
          characterCount: 12,
          segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withOpacity(0.05)),
        )
      : SevenSegmentDisplay(
          value: _normalizeForSegmentDisplay(res),
          size: 16 * _fontSizeMultiplier,
          characterSpacing: 8,
          characterCount: 12,
          segmentStyle: DefaultSegmentStyle(enabledColor: Colors.redAccent, disabledColor: Colors.red.withOpacity(0.05)),
        );
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDegreeMode = prefs.getBool('isDegreeMode') ?? true;
      _fontSizeMultiplier = prefs.getDouble('fontSizeMultiplier') ?? 1.0;
      _displaySizeFactor = prefs.getDouble('displaySizeFactor') ?? 1.0;
      ttsEnabled = prefs.getBool('ttsEnabled') ?? true;
      _speechRate = prefs.getDouble('speechRate') ?? 0.5;
      _speechVolume = prefs.getDouble('speechVolume') ?? 1.0;
      _preferExponential = prefs.getBool('preferExponential') ?? false;
      _useSixteenSegment = prefs.getBool('useSixteenSegment') ?? false;
      _sayWelcome = prefs.getBool('sayWelcome') ?? true;
      final accTypeIndex = prefs.getInt('accessibilityType') ?? AccessibilityType.none.index;
      _accessibilityType = AccessibilityType.values[accTypeIndex];
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDegreeMode', _isDegreeMode);
    await prefs.setDouble('fontSizeMultiplier', _fontSizeMultiplier);
    await prefs.setDouble('displaySizeFactor', _displaySizeFactor);
    await prefs.setBool('ttsEnabled', ttsEnabled);
    await prefs.setDouble('speechRate', _speechRate);
    await prefs.setDouble('speechVolume', _speechVolume);
    await prefs.setBool('preferExponential', _preferExponential);
    await prefs.setBool('useSixteenSegment', _useSixteenSegment);
    await prefs.setBool('sayWelcome', _sayWelcome);
    await prefs.setInt('accessibilityType', _accessibilityType.index);
  }

  void speak(String text) async {
    if (text.isEmpty || !ttsEnabled || !mounted) return;
    final now = DateTime.now();
    if (_lastSpeakTime != null && now.difference(_lastSpeakTime!) < _speakThrottle) return;
    _lastSpeakTime = now;
    try {
      await tts.stop();
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_speechVolume);
      await tts.speak(_formatForSpeech(text));
    } catch (e) { debugPrint('TTS Error: $e'); }
  }

  String _formatForSpeech(String text) {
    String processed = text.replaceAll('.', ',');
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:,\d+)?)E([+-])(\d+)'), (m) {
      String mantissa = m[1]!;
      String sign = m[2] == '-' ? 'mínus ' : '';
      int exponent = int.parse(m[3]!);
      return '$mantissa krát deset na $sign$exponent';
    });
    return processed;
  }

  void _showInitialAccessibilityDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Vítejte'), content: const Text('Vyberte režim usnadnění.'),
        actions: [
          TextButton(onPressed: () { setState(() => _accessibilityType = AccessibilityType.none); _saveSettings(); Navigator.pop(context); }, child: const Text('STANDARDNÍ')),
          TextButton(onPressed: () { setState(() { _accessibilityType = AccessibilityType.blind; ttsEnabled = true; }); _saveSettings(); Navigator.pop(context); }, child: const Text('PRO NEVIDOMÉ')),
        ],
      ),
    );
  }

  void _showAccessibilityDialog() {
    showDialog(context: context, builder: (context) => _AccessibilityDialog(parent: this));
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nápověda'),
        content: const Text('Kalkulačka podporuje vědecké, elektro a statistické výpočty. Nově můžete využít režim PŘEVODY. Ve vědeckém režimu (SCI) uvidíte výsledek s odděleným exponentem (např. x10 005).'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ROZUMÍM'))],
      ),
    );
  }

  void _toggleAngleMode() {
    setState(() => _isDegreeMode = !_isDegreeMode);
    _saveSettings();
    speak(_isDegreeMode ? 'Režim stupňů' : 'Režim radiánů');
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList('history') ?? []);
  }

  void _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history);
  }

  void _addToHistory(String expression, String result) {
    setState(() {
      _history.insert(0, '$expression = $result');
      if (_history.length > 20) _history.removeLast();
    });
    _saveHistory();
  }

  void _insertAtCursor(String text, {int cursorOffset = 0}) {
    _cursorPosition = _cursorPosition.clamp(0, display.length);
    setState(() {
      display = display.substring(0, _cursorPosition) + text + display.substring(_cursorPosition);
      _cursorPosition = (_cursorPosition + text.length + cursorOffset).clamp(0, display.length);
    });
  }

  void _deleteAtCursor() {
    _cursorPosition = _cursorPosition.clamp(0, display.length);
    if (_cursorPosition > 0) {
      setState(() {
        display = display.substring(0, _cursorPosition - 1) + display.substring(_cursorPosition);
        _cursorPosition--;
      });
      speak('Smazáno');
    }
  }

  void backspace() { _deleteAtCursor(); }
  void clear() { setState(() { display = ''; _cursorPosition = 0; _lastResult = '0.'; _isStoreMode = false; _hasResult = false; }); speak('Vymazat'); }
  void append(String value, {bool silent = false}) { 
    _insertAtCursor(value); 
    if (!silent) speak(_buttonNames[value] ?? value); 
  }

  String _formatAsDMS(double value) {
    double absVal = value.abs();
    int d = absVal.floor();
    double mVal = (absVal - d) * 60;
    int mm = mVal.floor();
    double sVal = (mVal - mm) * 60;
    String sStr = sVal.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return "${value < 0 ? '-' : ''}$d°$mm'$sStr\"";
  }

  void calculateResult() {
    try {
      if (display.isEmpty) return;
      bool wantsDMS = display.contains('°→\'');
      double result = _evaluateExpression(display);
      if (result.isNaN || result.isInfinite || (display.contains('TAN') && result.abs() > 1e15)) {
        setState(() { _lastResult = 'Error'; _hasResult = true; });
        speak('Výsledek není definován');
        return;
      }
      String resStr = wantsDMS ? _formatAsDMS(result) : _formatNumber(result);
      setState(() { _lastResult = resStr; _hasResult = true; });
      if (wantsDMS) {
        speak('Výsledek je ${resStr.replaceAll('°', ' stupňů, ').replaceAll('\'', ' minut a ').replaceAll('"', ' vteřin')}');
      } else {
        speak('Výsledek je ${resStr.replaceAll('.', ',')}');
      }
      _addToHistory(display, resStr);
    } catch (e) { 
      setState(() { _lastResult = 'Error'; _hasResult = true; });
      speak('Chyba ve výrazu'); 
    }
  }

  double _evaluateExpression(String expr) {
    String processed = expr.replaceAll(',', '.');
    bool isDmsConversion = processed.contains('°→\'');
    processed = processed.replaceAll('°→\'', '');
    processed = processed.replaceAll('\'→°', '_DMS_TO_DEG_');
    processed = processed.replaceAll('°', '_D_');
    processed = processed.replaceAll('\'', '_M_');
    processed = processed.replaceAll('"', '_S_');
    processed = processed.replaceAllMapped(RegExp(r'(\d+)_D_(\d+)_M_(\d+(?:\.\d+)?)_S__DMS_TO_DEG_'), (m) {
      double d = double.parse(m[1]!); double mm = double.parse(m[2]!); double s = double.parse(m[3]!);
      return (d + mm / 60 + s / 3600).toString();
    });
    processed = processed.replaceAllMapped(RegExp(r'(\d+)_D_(\d+)_M_(\d+(?:\.\d+)?)_S_'), (m) {
      double d = double.parse(m[1]!); double mm = double.parse(m[2]!); double s = double.parse(m[3]!);
      return (d + mm / 60 + s / 3600).toString();
    });
    processed = processed.replaceAll('x²', '^2').replaceAll('x³', '^3').replaceAll('(-)', '-');
    processed = processed.replaceAll('μ', '*10^-6').replaceAll('n', '*10^-9').replaceAll('p', '*10^-12');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)OHM_R'), (m) => '((${m[1]})/(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)OHM_V'), (m) => '((${m[1]})*(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)OHM_I'), (m) => '((${m[1]})/(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)PWR_P'), (m) => '((${m[1]})*(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+(?:;[^;]+)+)PAR'), (m) {
      List<String> parts = m[1]!.split(';');
      return '1/(${parts.map((p) => "1/($p)").join("+")})';
    });
    processed = processed.replaceAllMapped(RegExp(r'([^;]+(?:;[^;]+)+)SER'), (m) {
      List<String> parts = m[1]!.split(';');
      return '(${parts.join("+")})';
    });
    processed = processed.replaceAllMapped(RegExp(r'(\d+(\.\d+)?)ⁿ√(\d+(\.\d+)?)'), (m) => '(${m[3]}^(1/${m[1]}))');
    processed = processed.replaceAll('√(', 'sqrt(').replaceAllMapped(RegExp(r'∛\(([^)]+)\)'), (m) => '((${m[1]})^(1/3))');
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)[eE]([+-]?\d+)'), (m) => '(${m[1]}*10^(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)[eE](\d+)'), (m) => '(${m[1]}*10^(${m[2]}))');
    processed = processed.replaceAll('ABS(', 'abs(');
    double degToRad = _isDegreeMode ? math.pi / 180.0 : 1.0;
    double radToDeg = _isDegreeMode ? 180.0 / math.pi : 1.0;
    processed = processed.replaceAll('ASIN(', 'ARC_S(').replaceAll('ACOS(', 'ARC_C(').replaceAll('ATAN(', 'ARC_T(');
    if (_isDegreeMode) {
      processed = processed.replaceAll('SIN(', 'sin($degToRad*').replaceAll('COS(', 'cos($degToRad*').replaceAll('TAN(', 'tan($degToRad*');
      processed = processed.replaceAll('ARC_S(', '($radToDeg*arcsin(').replaceAll('ARC_C(', '($radToDeg*arccos(').replaceAll('ARC_T(', '($radToDeg*arctan(');
    } else {
      processed = processed.replaceAll('SIN(', 'sin(').replaceAll('COS(', 'cos(').replaceAll('TAN(', 'tan(');
      processed = processed.replaceAll('ARC_S(', 'arcsin(').replaceAll('ARC_C(', 'arccos(').replaceAll('ARC_T(', 'arctan(');
    }
    processed = processed.replaceAll('π', '${math.pi}').replaceAll(RegExp(r'\be\b'), '${math.e}');
    _memory.forEach((key, value) => processed = processed.replaceAll(RegExp('\\b$key\\b'), '($value)'));
    String ansValue = _lastResult.toLowerCase() == 'error' ? '0' : _lastResult;
    processed = processed.replaceAll(RegExp(r'\bANS\b'), '($ansValue)').replaceAll(' ', '');
    int openParentheses = '('.allMatches(processed).length;
    int closeParentheses = ')'.allMatches(processed).length;
    if (openParentheses > closeParentheses) processed += ')' * (openParentheses - closeParentheses);
    try {
      math_expr.Parser p = math_expr.Parser();
      math_expr.Expression exp = p.parse(processed);
      return exp.evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());
    } catch (e) { rethrow; }
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return value.toString();
    switch (_displayFormat) {
      case DisplayFormat.fix: return value.toStringAsFixed(_precision);
      case DisplayFormat.sci: return value.toStringAsExponential(_precision).toUpperCase();
      case DisplayFormat.eng:
        if (value == 0) return "0.00E+00";
        double absVal = value.abs();
        int exp = (math.log(absVal) / math.ln10).floor();
        int engExp = (exp / 3).floor() * 3;
        double mantissa = absVal / math.pow(10, engExp);
        String eStr = engExp >= 0 ? "+${engExp.toString().padLeft(2, '0')}" : engExp.toString().padLeft(3, '0');
        return "${value < 0 ? '-' : ''}${mantissa.toStringAsFixed(_precision)}E$eStr";
      default:
        if (value == value.toInt().toDouble()) return value.toInt().toString();
        return value.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  void _showPrecisionDialog(DisplayFormat format) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nastavit přesnost pro ${format.name.toUpperCase()}'),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(10, (i) => ElevatedButton(
            onPressed: () { setState(() { _displayFormat = format; _precision = i; }); speak('Nastaveno na $i míst'); Navigator.pop(context); },
            child: Text(i.toString()),
          )),
        ),
      ),
    );
  }

  String _normalizeForSegmentDisplay(String text) {
    if (text.toLowerCase() == 'error') return _useSixteenSegment ? 'CHYBA' : 'Err';
    
    // Mapování speciálních symbolů pro segmentový displej
    String result = text;
    if (!_useSixteenSegment) {
      result = result.replaceAll('°', 'o'); // Stupeň jako malý kroužek
      result = result.replaceAll('\'', 'i'); // Minuta jako horní čárka
      result = result.replaceAll('"', 'u'); // Vteřina (improvizace)
    }

    const map = {
      'á': 'A', 'č': 'C', 'ď': 'D', 'é': 'E', 'ě': 'E', 'í': 'I', 'ň': 'N',
      'ó': 'O', 'ř': 'R', 'š': 'S', 'ť': 'T', 'ú': 'U', 'ů': 'U', 'ý': 'Y', 'ž': 'Z',
    };
    
    map.forEach((key, value) => result = result.replaceAll(key, value).replaceAll(key.toUpperCase(), value));
    return _useSixteenSegment ? result.toUpperCase() : result;
  }

  void _handleButtonPressed(String label) {
    if (_hasResult) {
      if (['+', '-', '*', '/', '^', '%', 'x²', 'x³'].contains(label)) {
        setState(() { display = 'ANS'; _hasResult = false; });
      } else if (RegExp(r'^[0-9.]$').hasMatch(label) || ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '√', '∛', 'ABS', '('].contains(label)) {
        setState(() { display = ''; _hasResult = false; });
      } else {
        setState(() => _hasResult = false);
      }
    }
    if (label == 'C') clear();
    else if (label == 'DEL') backspace();
    else if (label == '=') calculateResult();
    else if (label == 'STO') { setState(() => _isStoreMode = true); speak('Vyberte paměť'); }
    else if (label == 'RCL') speak('Vyberte paměť');
    else if (label == 'CLR') { setState(() => _memory.updateAll((k, v) => 0)); speak('Paměť vymazána'); }
    else if (_memory.containsKey(label)) {
      if (_isStoreMode) {
        double val = 0; try { val = double.parse(_lastResult.replaceAll(',', '.')); } catch (_) {}
        setState(() { _memory[label] = val; _isStoreMode = false; }); speak('Uloženo do $label');
      } else append(label);
    } else if (label == 'EXP') {
      append('E');
    } else if (['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '√', '∛', 'ABS', '1/x'].contains(label)) {
      String insertText = label == '1/x' ? '1/()' : '$label()';
      _insertAtCursor(insertText, cursorOffset: -1); speak(_buttonNames[label] ?? label);
    } else if (['°→\'', '\'→°', 'DMS', 'π', 'e'].contains(label)) {
       _insertAtCursor(label == 'DMS' ? '°\'"' : label); speak(_buttonNames[label] ?? label);
    } else append(label);
  }

  Widget _buildDotMatrixDisplay() {
    String textWithCursor = display;
    if (_cursorPosition >= 0 && _cursorPosition <= display.length) {
      textWithCursor = display.substring(0, _cursorPosition) + "_" + display.substring(_cursorPosition);
    }
    return DotMatrixText(text: textWithCursor.isEmpty ? "_" : textWithCursor, textStyle: const TextStyle(fontSize: 48, color: Colors.redAccent, fontWeight: FontWeight.bold), ledSize: 3.0, ledSpacing: 0.8);
  }

  Widget buildButton(String label, {Color? color, String? semanticLabel, VoidCallback? onPressed}) {
    String effectiveSemanticLabel = semanticLabel ?? (_buttonNames[label] ?? label);
    if (RegExp(r'^[0-9]$').hasMatch(label)) effectiveSemanticLabel = 'Číslo $label';
    return Padding(
      padding: const EdgeInsets.all(2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: color != null ? Colors.white : null, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
        onPressed: onPressed ?? () => _handleButtonPressed(label),
        child: Semantics(button: true, label: effectiveSemanticLabel, child: ExcludeSemantics(child: Text(label, style: TextStyle(fontSize: 18 * _fontSizeMultiplier, fontWeight: FontWeight.bold)))),
      ),
    );
  }

  Widget _buildExpandableSection({required String title, required List<String> buttons, required bool isExpanded, required ValueChanged<bool> onExpansionChanged, List<Widget>? extraButtons}) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      initiallyExpanded: isExpanded,
      onExpansionChanged: (expanded) { onExpansionChanged(expanded); speak(expanded ? '$title rozbaleno' : '$title zabaleno'); },
      children: [ GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, childAspectRatio: 1.3, children: [...buttons.map((b) => buildButton(b)).toList(), ...?(extraButtons)]) ],
    );
  }

  Widget _buildUnitConversionSection() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedUnitCategory,
          decoration: const InputDecoration(labelText: 'Kategorie'),
          items: _unitCategories.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
          onChanged: (val) { setState(() { _selectedUnitCategory = val!; _unitFrom = _unitCategories[val]!.keys.first; _unitTo = _unitCategories[val]!.keys.elementAt(1); }); speak('Kategorie $val'); },
        ),
        Row(
          children: [
            Expanded(child: DropdownButtonFormField<String>(value: _unitFrom, decoration: const InputDecoration(labelText: 'Z'), items: _unitCategories[_selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(_getUnitSpeech(u)))).toList(), onChanged: (val) { setState(() => _unitFrom = val!); speak('Z jednotky ${_getUnitSpeech(val!)}'); })),
            const Icon(Icons.arrow_forward),
            Expanded(child: DropdownButtonFormField<String>(value: _unitTo, decoration: const InputDecoration(labelText: 'Na'), items: _unitCategories[_selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(_getUnitSpeech(u)))).toList(), onChanged: (val) { setState(() => _unitTo = val!); speak('Na jednotku ${_getUnitSpeech(val!)}'); })),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _convertUnits, icon: const Icon(Icons.sync), label: const Text('PŘEVÉST'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)))),
      ],
    );
  }

  Widget _buildMainKeyboard({double aspectRatio = 1.0}) {
    List<String> btns = ['C', '(', ')', '/', '7', '8', '9', '*', '4', '5', '6', '-', '1', '2', '3', '+', 'DEL', '0', '.', '='];
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, childAspectRatio: aspectRatio,
      children: btns.map((b) {
        if (b == 'C') return buildButton('C', color: Colors.orange, semanticLabel: 'Vymazat displej', onPressed: () => clear());
        if (b == 'DEL') return buildButton('DEL', color: Colors.redAccent, semanticLabel: 'Smazat poslední', onPressed: () => backspace());
        if (b == '=') return buildButton('=', color: Colors.green, semanticLabel: 'Rovná se', onPressed: () => calculateResult());
        return buildButton(b, color: ['/', '*', '-', '+'].contains(b) ? Colors.blue : null);
      }).toList(),
    );
  }

  Widget _buildModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: CalculatorMode.values.map((mode) {
        String label = '';
        switch (mode) {
          case CalculatorMode.basic: label = 'Základní'; break;
          case CalculatorMode.scientific: label = 'Vědecká'; break;
          case CalculatorMode.statistics: label = 'Statistika'; break;
          case CalculatorMode.electrician: label = 'Elektro'; break;
          case CalculatorMode.unitConversion: label = 'Převody'; break;
        }
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ChoiceChip(label: Text(label), selected: _currentMode == mode, onSelected: (s) { if (s) _changeMode(mode); }));
      }).toList()),
    );
  }

  List<Widget> _buildFunctionSections() {
    List<Widget> sections = [];
    if (_currentMode == CalculatorMode.unitConversion) sections.add(Padding(padding: const EdgeInsets.all(12.0), child: Card(child: Padding(padding: const EdgeInsets.all(12.0), child: _buildUnitConversionSection()))));
    if (_currentMode == CalculatorMode.scientific || _currentMode == CalculatorMode.electrician) {
      sections.add(_buildExpandableSection(title: 'Gonio', buttons: ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN'], isExpanded: _isGonioExpanded, onExpansionChanged: (v) => setState(() => _isGonioExpanded = v), extraButtons: [ buildButton(_isDegreeMode ? 'DEG' : 'RAD', color: Colors.indigo, onPressed: _toggleAngleMode) ]));
    }
    if (_currentMode != CalculatorMode.basic) sections.add(_buildExpandableSection(title: 'Funkce', buttons: ['^', '√', 'ⁿ√', 'x²', 'x³', '∛', '1/x', 'ABS', '%', 'EXP', '(-)', '°→\'', '\'→°', 'DMS', 'π', 'e'], isExpanded: _isFunctionsExpanded, onExpansionChanged: (v) => setState(() => _isFunctionsExpanded = v)));
    if (_currentMode == CalculatorMode.statistics) sections.add(_buildExpandableSection(title: 'Statistika', buttons: ['SD', 'VAR', 'MEAN', 'STATS', 'CV', ';'], isExpanded: _isStatsExpanded, onExpansionChanged: (v) => setState(() => _isStatsExpanded = v)));
    if (_currentMode == CalculatorMode.electrician) sections.add(_buildExpandableSection(title: 'Elektro', buttons: ['OHM_V', 'OHM_I', 'OHM_R', 'PWR_P', 'PAR', 'SER', 'XL', 'XC', 'Hz', 'μ', 'n', 'p'], isExpanded: _isElectricianExpanded, onExpansionChanged: (v) => setState(() => _isElectricianExpanded = v)));
    sections.add(_buildExpandableSection(title: 'Navigace', buttons: [], isExpanded: true, onExpansionChanged: (v) {}, extraButtons: [ buildButton('←', onPressed: () { if (_cursorPosition > 0) setState(() => _cursorPosition--); }), buildButton('→', onPressed: () { if (_cursorPosition < display.length) setState(() => _cursorPosition++); }) ]));
    sections.add(_buildExpandableSection(title: 'Zobrazení', buttons: [], isExpanded: true, onExpansionChanged: (v) {}, extraButtons: [ buildButton('NORM', onPressed: () { setState(() => _displayFormat = DisplayFormat.standard); speak('Standardní'); }), buildButton('FIX', onPressed: () => _showPrecisionDialog(DisplayFormat.fix)), buildButton('SCI', onPressed: () => _showPrecisionDialog(DisplayFormat.sci)), buildButton('ENG', onPressed: () => _showPrecisionDialog(DisplayFormat.eng)) ]));
    sections.add(_buildExpandableSection(title: 'Paměť', buttons: ['STO', 'RCL', 'CLR', 'ANS'], isExpanded: _isMemoryExpanded, onExpansionChanged: (v) => setState(() => _isMemoryExpanded = v)));
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
        appBar: AppBar(title: const Text('Mluvící kalkulačka'), actions: [ IconButton(icon: const Icon(Icons.help_outline), onPressed: _showTutorialDialog), IconButton(icon: const Icon(Icons.accessibility_new), onPressed: _showAccessibilityDialog) ]),
        body: Column(
          children: [
            Expanded(flex: (1000 * _displaySizeFactor).toInt(), child: GestureDetector(
              onTap: () => _mainFocusNode.requestFocus(),
              child: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF121212), border: Border.all(color: Colors.black, width: 3)), alignment: Alignment.bottomRight, child: Semantics(liveRegion: true, label: 'Displej', value: display.isEmpty ? 'Prázdno' : display.replaceAll('.', ','), child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [ Flexible(child: FittedBox(child: _buildDotMatrixDisplay())), const SizedBox(height: 12), Flexible(child: FittedBox(child: _buildMainResultDisplay())) ]))),
            )),
            _buildModeSelector(),
            Expanded(flex: 1000, child: LayoutBuilder(builder: (context, constraints) {
              if (isWideScreen) return Row(children: [ Expanded(child: ListView(children: _buildFunctionSections())), const VerticalDivider(), Expanded(child: _buildMainKeyboard(aspectRatio: (constraints.maxWidth / 2 / 4) / (constraints.maxHeight / 5))) ]);
              return Column(children: [ Expanded(child: ListView(children: _buildFunctionSections())), const Divider(), SizedBox(height: constraints.maxHeight * 0.65, child: _buildMainKeyboard(aspectRatio: (constraints.maxWidth / 4) / (constraints.maxHeight * 0.65 / 5))) ]);
            })),
          ],
        ),
      ),
    );
  }
}

class _AccessibilityDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _AccessibilityDialog({required this.parent, super.key});
  @override
  State<_AccessibilityDialog> createState() => _AccessibilityDialogState();
}

class _AccessibilityDialogState extends State<_AccessibilityDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nastavení'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(title: const Text('Hlas'), value: widget.parent.ttsEnabled, onChanged: (v) => setState(() { widget.parent.setState(() => widget.parent.ttsEnabled = v); widget.parent._saveSettings(); })),
            ListTile(title: const Text('Písmo'), subtitle: Slider(value: widget.parent._fontSizeMultiplier, min: 0.8, max: 3.0, onChanged: (v) => setState(() { widget.parent.setState(() => widget.parent._fontSizeMultiplier = v); widget.parent._saveSettings(); }))),
            SwitchListTile(title: const Text('16 seg'), value: widget.parent._useSixteenSegment, onChanged: (v) => setState(() { widget.parent.setState(() => widget.parent._useSixteenSegment = v); widget.parent._saveSettings(); })),
          ],
        ),
      ),
      actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('HOTOVO')) ],
    );
  }
}
  }
}
