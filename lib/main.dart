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
  bool _isUnitConvExpanded = true;

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
    'RCL': 'Vyvolat z paměti', 'CLR': 'Smazat celou paměť', 'C': 'Proměnná C',
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

  void _convertUnits() {
    try {
      // Získáme číselnou hodnotu z posledního výsledku
      double value = double.parse(_lastResult.replaceAll(',', '.'));
      double fromFactor = _unitCategories[_selectedUnitCategory]![_unitFrom]!;
      double toFactor = _unitCategories[_selectedUnitCategory]![_unitTo]!;
      double result = value * (fromFactor / toFactor);
      
      String resStr = _formatNumber(result);
      setState(() {
        _lastResult = resStr;
        _hasResult = true;
      });
      speak('Převedeno z $_unitFrom na $_unitTo. Výsledek je ${resStr.replaceAll('.', ',')}');
      _addToHistory('Převod $value $_unitFrom na $_unitTo', resStr);
    } catch (e) {
      speak('Chyba při převodu. Ujistěte se, že na displeji je číslo.');
    }
  }

  Widget _buildScientificTripleDisplay(String text) {
    // Rozdělíme 1.23E+05 na "1.23" a "+05"
    List<String> parts = text.split('E');
    String mantissa = parts[0];
    String exponent = parts[1];
    
    // Formátování exponentu na 3 místa (např. +05 -> 005, -3 -> -03)
    // Pokud je kladný, odstraníme plus. Pokud záporný, necháme mínus.
    String formattedExp = exponent.replaceAll('+', '');
    if (!formattedExp.startsWith('-')) {
      formattedExp = formattedExp.padLeft(3, '0');
    } else {
      // Pro záporná čísla jako -3 chceme -03 nebo -003
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
              segmentStyle: DefaultSegmentStyle(
                enabledColor: Colors.redAccent,
                disabledColor: Colors.red.withOpacity(0.05),
              ),
            )
          : SevenSegmentDisplay(
              value: _normalizeForSegmentDisplay(mantissa),
              size: 16 * _fontSizeMultiplier,
              characterSpacing: 4,
              characterCount: 8,
              segmentStyle: DefaultSegmentStyle(
                enabledColor: Colors.redAccent,
                disabledColor: Colors.red.withOpacity(0.05),
              ),
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
              segmentStyle: DefaultSegmentStyle(
                enabledColor: Colors.redAccent,
                disabledColor: Colors.red.withOpacity(0.05),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainResultDisplay() {
    String res = _lastResult.isEmpty ? '0.' : _lastResult;
    
    // Pokud je zapnutý vědecký formát a výsledek obsahuje exponent
    if (_displayFormat == DisplayFormat.sci && res.contains('E') && res.toLowerCase() != 'error') {
      return _buildScientificTripleDisplay(res);
    }

    return _useSixteenSegment 
      ? SixteenSegmentDisplay(
          value: _normalizeForSegmentDisplay(res),
          size: 16 * _fontSizeMultiplier,
          characterSpacing: 8,
          characterCount: 12,
          segmentStyle: DefaultSegmentStyle(
            enabledColor: Colors.redAccent,
            disabledColor: Colors.red.withOpacity(0.05),
          ),
        )
      : SevenSegmentDisplay(
          value: _normalizeForSegmentDisplay(res),
          size: 16 * _fontSizeMultiplier,
          characterSpacing: 8,
          characterCount: 12,
          segmentStyle: DefaultSegmentStyle(
            enabledColor: Colors.redAccent,
            disabledColor: Colors.red.withOpacity(0.05),
          ),
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
      _preferDMSForInverse = prefs.getBool('preferDMSForInverse');
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
    if (_preferDMSForInverse != null) await prefs.setBool('preferDMSForInverse', _preferDMSForInverse!);
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
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  String _formatForSpeech(String text) {
    String processed = text.replaceAll('.', ',');
    
    // Převede vědecký zápis (např. 1,23E+05 nebo 1,23E-03) na srozumitelnou češtinu
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:,\d+)?)E([+-])(\d+)'), (m) {
      String mantissa = m[1]!;
      String sign = m[2] == '-' ? 'mínus ' : '';
      int exponent = int.parse(m[3]!); // Odstraní úvodní nuly pro řeč
      return '$mantissa krát deset na $sign$exponent';
    });
    
    return processed;
  }

  void _showInitialAccessibilityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Vítejte'),
        content: const Text('Vyberte prosím režim usnadnění.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () { setState(() => _accessibilityType = AccessibilityType.none); _saveSettings(); Navigator.pop(context); }, 
            child: const Text('STANDARDNÍ')
          ),
          TextButton(
            onPressed: () { setState(() { _accessibilityType = AccessibilityType.blind; ttsEnabled = true; }); _saveSettings(); Navigator.pop(context); }, 
            child: const Text('PRO NEVIDOMÉ')
          ),
        ],
      ),
    );
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AccessibilityDialog(parent: this),
    );
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nápověda'),
        content: const Text('Kalkulačka podporuje vědecké, elektro a statistické výpočty. Nově můžete využít režim PŘEVODY pro převod aktuálního výsledku. Ve vědeckém režimu (SCI) uvidíte výsledek s odděleným exponentem (např. x10 005).'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context), 
            child: const Text('ROZUMÍM')
          )
        ],
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
    // Zabezpečení pozice kurzoru proti přetečení/podtečení
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
  void append(String value) { _insertAtCursor(value); speak(_buttonNames[value] ?? value); }

  String _formatAsDMS(double value) {
    double absVal = value.abs();
    int d = absVal.floor();
    double mVal = (absVal - d) * 60;
    int mm = mVal.floor();
    double sVal = (mVal - mm) * 60;
    // Zaokrouhlíme vteřiny na 2 desetinná místa
    String sStr = sVal.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return "${value < 0 ? '-' : ''}$d°$mm'$sStr\"";
  }

  void calculateResult() {
    try {
      if (display.isEmpty) return;
      
      bool wantsDMS = display.contains('°→\'');
      double result = _evaluateExpression(display);
      
      if (result.isNaN || result.isInfinite || (display.contains('TAN') && result.abs() > 1e15)) {
        setState(() {
          _lastResult = 'Error';
          _hasResult = true;
        });
        speak('Výsledek není definován');
        return;
      }

      String resStr = wantsDMS ? _formatAsDMS(result) : _formatNumber(result);
      
      setState(() { 
        _lastResult = resStr;
        _hasResult = true;
      });
      
      if (wantsDMS) {
        speak('Výsledek je ${resStr.replaceAll('°', ' stupňů, ').replaceAll('\'', ' minut a ').replaceAll('"', ' vteřin')}');
      } else {
        speak('Výsledek je ${resStr.replaceAll('.', ',')}');
      }
      _addToHistory(display, resStr);
    } catch (e) { 
      setState(() {
        _lastResult = 'Error';
        _hasResult = true;
      });
      speak('Chyba ve výrazu'); 
    }
  }

  double _evaluateExpression(String expr) {
    // 1. Předzpracování: nahradíme problematické znaky bezpečnými značkami
    String processed = expr.replaceAll(',', '.');
    
    // Detekce speciálního požadavku na převod do DMS pro ohlášení
    bool isDmsConversion = processed.contains('°→\'');

    processed = processed.replaceAll('°→\'', '');
    processed = processed.replaceAll('\'→°', '_DMS_TO_DEG_');
    processed = processed.replaceAll('°', '_D_');
    processed = processed.replaceAll('\'', '_M_');
    processed = processed.replaceAll('"', '_S_');

    // Zpracování DMS -> Desetinné stupně
    processed = processed.replaceAllMapped(RegExp(r'(\d+)_D_(\d+)_M_(\d+(?:\.\d+)?)_S__DMS_TO_DEG_'), (m) {
      double d = double.parse(m[1]!);
      double mm = double.parse(m[2]!);
      double s = double.parse(m[3]!);
      return (d + mm / 60 + s / 3600).toString();
    });

    // Zpracování samotného DMS zápisu pro výpočty
    processed = processed.replaceAllMapped(RegExp(r'(\d+)_D_(\d+)_M_(\d+(?:\.\d+)?)_S_'), (m) {
      double d = double.parse(m[1]!);
      double mm = double.parse(m[2]!);
      double s = double.parse(m[3]!);
      return (d + mm / 60 + s / 3600).toString();
    });

    processed = processed.replaceAll('x²', '^2');
    processed = processed.replaceAll('x³', '^3');
    processed = processed.replaceAll('(-)', '-');
    
    processed = processed.replaceAll('μ', '*10^-6');
    processed = processed.replaceAll('n', '*10^-9');
    processed = processed.replaceAll('p', '*10^-12');
    processed = processed.replaceAll('Hz', '');

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
    processed = processed.replaceAll('√(', 'sqrt(');
    processed = processed.replaceAllMapped(RegExp(r'∛\(([^)]+)\)'), (m) => '((${m[1]})^(1/3))');
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)[eE]([+-]?\d+)'), (m) => '(${m[1]}*10^${m[2]})');
    processed = processed.replaceAll('ABS(', 'abs(');
    
    double degToRad = _isDegreeMode ? math.pi / 180.0 : 1.0;
    double radToDeg = _isDegreeMode ? 180.0 / math.pi : 1.0;

    processed = processed.replaceAll('ASIN(', 'ARC_S(');
    processed = processed.replaceAll('ACOS(', 'ARC_C(');
    processed = processed.replaceAll('ATAN(', 'ARC_T(');

    if (_isDegreeMode) {
      processed = processed.replaceAll('SIN(', 'sin($degToRad*');
      processed = processed.replaceAll('COS(', 'cos($degToRad*');
      processed = processed.replaceAll('TAN(', 'tan($degToRad*');
    } else {
      processed = processed.replaceAll('SIN(', 'sin(');
      processed = processed.replaceAll('COS(', 'cos(');
      processed = processed.replaceAll('TAN(', 'tan(');
    }

    if (_isDegreeMode) {
      processed = processed.replaceAll('ARC_S(', '($radToDeg*arcsin(');
      processed = processed.replaceAll('ARC_C(', '($radToDeg*arccos(');
      processed = processed.replaceAll('ARC_T(', '($radToDeg*arctan(');
    } else {
      processed = processed.replaceAll('ARC_S(', 'arcsin(');
      processed = processed.replaceAll('ARC_C(', 'arccos(');
      processed = processed.replaceAll('ARC_T(', 'arctan(');
    }

    processed = processed.replaceAll('π', '${math.pi}');
    processed = processed.replaceAll(RegExp(r'\be\b'), '${math.e}');

    _memory.forEach((key, value) => processed = processed.replaceAll(RegExp('\\b$key\\b'), '($value)'));
    
    String ansValue = _lastResult.toLowerCase() == 'error' ? '0' : _lastResult;
    processed = processed.replaceAll(RegExp(r'\bANS\b'), '($ansValue)');
    processed = processed.replaceAll(' ', '');

    int openParentheses = '('.allMatches(processed).length;
    int closeParentheses = ')'.allMatches(processed).length;
    if (openParentheses > closeParentheses) processed += ')' * (openParentheses - closeParentheses);

    math_expr.Parser p = math_expr.Parser();
    try {
      math_expr.Expression exp = p.parse(processed);
      double result = exp.evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());
      
      if (isDmsConversion) {
        // Pokud byl požadován převod na DMS, "zneužijeme" návratovou hodnotu pro speciální formátování
        // Ve skutečnosti bychom měli vrátit double, ale my to ošetříme v calculateResult
      }
      return result;
    } catch (e, st) {
      debugPrint('Expression parse/eval error: $e');
      debugPrint('Processed expression: $processed');
      debugPrint('$st');
      rethrow;
    }
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return value.toString();
    
    switch (_displayFormat) {
      case DisplayFormat.fix:
        return value.toStringAsFixed(_precision);
      case DisplayFormat.sci:
        return value.toStringAsExponential(_precision).toUpperCase();
      case DisplayFormat.eng:
        if (value == 0) return "0.00E+00";
        double sign = value < 0 ? -1 : 1;
        double absVal = value.abs();
        int exp = (math.log(absVal) / math.ln10).floor();
        int engExp = (exp / 3).floor() * 3;
        double mantissa = absVal / math.pow(10, engExp);
        String mStr = mantissa.toStringAsFixed(_precision);
        String eStr = engExp >= 0 ? "+${engExp.toString().padLeft(2, '0')}" : engExp.toString().padLeft(3, '0');
        return "${sign < 0 ? '-' : ''}${mStr}E$eStr";
      case DisplayFormat.standard:
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
          spacing: 8,
          runSpacing: 8,
          children: List.generate(10, (i) => ElevatedButton(
            onPressed: () {
              setState(() {
                _displayFormat = format;
                _precision = i;
              });
              speak('Nastaveno na $i míst');
              Navigator.pop(context);
            },
            child: Text(i.toString()),
          )),
        ),
      ),
    );
  }

  String _normalizeForSegmentDisplay(String text) {
    if (text.toLowerCase() == 'error') {
      return _useSixteenSegment ? 'CHYBA' : 'Err';
    }
    
    // Specifické mapování pro 7-segmentový displej (pro 16-seg ponecháme originály)
    if (!_useSixteenSegment) {
      if (text == 'Err') return 'Err';
      
      // Mapování symbolů na dostupné znaky 7-segmentové sady, které vypadají podobně
      // ° -> použijeme symbol, který knihovna interpretuje jako horní kroužek
      // ' -> horní segment
      // " -> dva horní segmenty
      text = text.replaceAll('°', 'o'); // 'o' na 7-segmentu vypadá jako horní kroužek/čtvereček
      text = text.replaceAll('\'', 'I'); // 'I' jako svislá čárka
      text = text.replaceAll('"', 'H'); // 'H' (vypadá jako dva svislé segmenty, pokud jsou jen nahoře)
      // Alternativně, pokud knihovna nepodporuje tyto mapování, zkusíme standardní ASCII:
    }

    // Mapa pro převod českých znaků na jejich základní tvary
    const map = {
      'á': 'A', 'č': 'C', 'ď': 'D', 'é': 'E', 'ě': 'E', 'í': 'I', 'ň': 'N',
      'ó': 'O', 'ř': 'R', 'š': 'S', 'ť': 'T', 'ú': 'U', 'ů': 'U', 'ý': 'Y', 'ž': 'Z',
      'Á': 'A', 'Č': 'C', 'Ď': 'D', 'É': 'E', 'Ě': 'E', 'Í': 'I', 'Ň': 'N',
      'Ó': 'O', 'Ř': 'R', 'Š': 'S', 'Ť': 'T', 'Ú': 'U', 'Ů': 'U', 'Ý': 'Y', 'Ž': 'Z',
    };
    
    String result = text;
    map.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    
    // Pro 7-segment nepoužíváme toUpperCase plošně, abychom nezničili 'Err'
    return _useSixteenSegment ? result.toUpperCase() : result;
  }

  void _handleButtonPressed(String label) {
    if (_hasResult) {
      if (['+', '-', '*', '/', '^', '%', 'x²', 'x³'].contains(label)) {
        setState(() {
          display = 'ANS';
          _hasResult = false;
        });
      } else if (RegExp(r'^[0-9.]$').hasMatch(label) || ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '√', '∛', 'ABS', '('].contains(label)) {
        setState(() {
          display = '';
          _hasResult = false;
        });
      } else {
        setState(() => _hasResult = false);
      }
    }

    if (label == 'C') {
      clear();
    } else if (label == 'DEL') {
      backspace();
    } else if (label == '=') {
      calculateResult();
    } else if (label == 'STO') {
      setState(() => _isStoreMode = true);
      speak('Vyberte paměť pro uložení');
    } else if (label == 'RCL') {
      speak('Vyberte paměť pro vyvolání');
    } else if (label == 'CLR') {
      setState(() {
        _memory.updateAll((key, value) => 0);
      });
      speak('Paměť vymazána');
    } else if (_memory.containsKey(label)) {
      if (_isStoreMode) {
        setState(() {
          double val = 0;
          try {
            val = double.parse(_lastResult.replaceAll(',', '.'));
          } catch (_) {}
          _memory[label] = val;
          _isStoreMode = false;
        });
        speak('Uloženo do paměti $label');
      } else {
        append(label);
      }
    } else if (['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '√', '∛', 'ABS', '1/x'].contains(label)) {
      String insertText = '';
      int offset = 0;
      if (label == '1/x') {
        insertText = '1/()';
        offset = -1;
      } else {
        insertText = '$label()';
        offset = -1;
      }
      _insertAtCursor(insertText, cursorOffset: offset);
      speak(_buttonNames[label] ?? label);
    } else if (['°→\'', '\'→°', 'DMS', 'π', 'e'].contains(label)) {
       String text = label;
       if (label == 'DMS') text = '°\'"'; // Vloží šablonu pro stupně
       _insertAtCursor(text);
       speak(_buttonNames[label] ?? label);
    } else {
      append(label);
    }
  }

  Widget _buildDotMatrixDisplay() {
    String textWithCursor = display;
    if (_cursorPosition >= 0 && _cursorPosition <= display.length) {
      textWithCursor = display.substring(0, _cursorPosition) + "_" + display.substring(_cursorPosition);
    }
    return DotMatrixText(
      text: textWithCursor.isEmpty ? "_" : textWithCursor,
      textStyle: const TextStyle(
        fontSize: 48,
        color: Colors.redAccent,
        fontWeight: FontWeight.bold,
      ),
      ledSize: 3.0,
      ledSpacing: 0.8,
    );
  }

  Widget buildButton(String label, {Color? color, String? semanticLabel, VoidCallback? onPressed}) {
    String effectiveSemanticLabel = semanticLabel ?? (_buttonNames[label] ?? label);
    
    // Pro čísla a operátory přidáme kontext, aby NVDA vědělo, o co jde
    if (RegExp(r'^[0-9]$').hasMatch(label)) {
      effectiveSemanticLabel = 'Číslo $label';
    } else if (['+', '-', '*', '/', '='].contains(label)) {
      effectiveSemanticLabel = 'Tlačítko ${_buttonNames[label] ?? label}';
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color != null ? Colors.white : null,
          padding: EdgeInsets.zero,
          elevation: 2,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        onPressed: onPressed ?? () => _handleButtonPressed(label),
        child: Semantics(
          button: true,
          label: effectiveSemanticLabel,
          child: ExcludeSemantics(
            child: Text(
              label, 
              style: TextStyle(fontSize: 18 * _fontSizeMultiplier, fontWeight: FontWeight.bold)
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required List<String> buttons,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    List<Widget>? extraButtons,
    double aspectRatio = 1.3,
  }) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      initiallyExpanded: isExpanded,
      onExpansionChanged: (expanded) {
        onExpansionChanged(expanded);
        speak(expanded ? '$title rozbaleno' : '$title zabaleno');
      },
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: aspectRatio,
          children: [
            ...buttons.map((b) => buildButton(b)).toList(),
            ...?(extraButtons),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isWideScreen = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mluvící kalkulačka'), 
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline), 
            onPressed: _showTutorialDialog,
            tooltip: 'Nápověda',
          ),
          IconButton(
            icon: const Icon(Icons.accessibility_new), 
            onPressed: _showAccessibilityDialog,
            tooltip: 'Nastavení usnadnění',
          ),
        ]
      ),
      body: Column(
        children: [
          Expanded(
            flex: (1000 * _displaySizeFactor).toInt(),
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF121212), 
                border: const Border(
                  top: BorderSide(color: Colors.black, width: 3),
                  left: BorderSide(color: Colors.black, width: 3),
                  bottom: BorderSide(color: Colors.white10, width: 2),
                  right: BorderSide(color: Colors.white10, width: 2),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.bottomRight,
              child: Focus(
                child: Semantics(
                  container: true,
                  focusable: true,
                  liveRegion: true,
                  label: 'Displej kalkulačky',
                  value: display.isEmpty ? 'Prázdno' : display.replaceAll('.', ','),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          flex: 1,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                            child: _buildDotMatrixDisplay(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          flex: 1,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                            child: _buildMainResultDisplay(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildModeSelector(),
          Expanded(
            flex: 1000,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableHeight = constraints.maxHeight;
                final double availableWidth = constraints.maxWidth;
                
                if (isWideScreen) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: _buildFunctionSections(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: _buildMainKeyboard(
                          aspectRatio: (availableWidth / 2 / 4) / (availableHeight / 5),
                        ),
                      ),
                    ],
                  );
                } else {
                  double keyboardHeight = availableHeight * 0.65; 
                  if (_fontSizeMultiplier > 1.5) keyboardHeight = availableHeight * 0.75;

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: _buildFunctionSections(),
                        ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: keyboardHeight,
                        child: _buildMainKeyboard(
                          aspectRatio: (availableWidth / 4) / (keyboardHeight / 5),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitConversionSection() {
    return Column(
      children: [
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
          },
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _unitFrom,
                decoration: const InputDecoration(labelText: 'Z jednotky'),
                items: _unitCategories[_selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) {
                  setState(() => _unitFrom = val!);
                  speak('Z jednotky $val');
                },
              ),
            ),
            const Icon(Icons.arrow_forward),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _unitTo,
                decoration: const InputDecoration(labelText: 'Na jednotku'),
                items: _unitCategories[_selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) {
                  setState(() => _unitTo = val!);
                  speak('Na jednotku $val');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _convertUnits,
            icon: const Icon(Icons.sync),
            label: const Text('PŘEVÉST AKTUÁLNÍ VÝSLEDEK'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ),
      ],
    );
  }

  // Sjednocená klávesnice 4x5 obsahující všechna důležitá tlačítka
  Widget _buildMainKeyboard({double aspectRatio = 1.0}) {
    List<String> btns = [
      'C', '(', ')', '/', 
      '7', '8', '9', '*', 
      '4', '5', '6', '-', 
      '1', '2', '3', '+', 
      'DEL', '0', '.', '='
    ];
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
          return buildButton('DEL', color: Colors.redAccent, semanticLabel: 'Smazat poslední znak', onPressed: () => backspace());
        }
        if (b == '=') {
          return buildButton('=', color: Colors.green, semanticLabel: 'Vypočítat výsledek', onPressed: () => calculateResult());
        }
        Color? color;
        if (['/', '*', '-', '+'].contains(b)) color = Colors.blue;
        return buildButton(b, color: color);
      }).toList(),
    );
  }

  Widget _buildModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: CalculatorMode.values.map((mode) {
          final isSelected = _currentMode == mode;
          String label = '';
          switch (mode) {
            case CalculatorMode.basic: label = 'Základní'; break;
            case CalculatorMode.scientific: label = 'Vědecká'; break;
            case CalculatorMode.statistics: label = 'Statistika'; break;
            case CalculatorMode.electrician: label = 'Elektro'; break;
            case CalculatorMode.unitConversion: label = 'Převody'; break;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) _changeMode(mode);
              },
            ),
          );
        }).toList(),
      ),
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
            child: _buildUnitConversionSection(),
          ),
        ),
      ));
    }

    // Základní funkce (Matematické) jsou dostupné ve všech režimech kromě úplně základního, 
    // kde mohou být také, nebo je omezíme.
    
    if (_currentMode == CalculatorMode.scientific || _currentMode == CalculatorMode.electrician) {
      sections.add(_buildExpandableSection(
        title: 'Goniometrické funkce',
        buttons: ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN'],
        isExpanded: _isGonioExpanded,
        onExpansionChanged: (v) => setState(() => _isGonioExpanded = v),
        extraButtons: [
           buildButton(_isDegreeMode ? 'DEG' : 'RAD', color: Colors.indigo, onPressed: () {
             setState(() => _isDegreeMode = !_isDegreeMode);
             speak(_isDegreeMode ? 'Stupně' : 'Radiány');
             _saveSettings();
           }),
        ]
      ));
    }

    if (_currentMode != CalculatorMode.basic) {
      sections.add(_buildExpandableSection(
        title: 'Matematické funkce',
        buttons: ['^', '√', 'ⁿ√', 'x²', 'x³', '∛', '1/x', 'ABS', '%', 'EXP', '(-)', '°→\'', '\'→°', 'DMS', 'π', 'e'],
        isExpanded: _isFunctionsExpanded,
        onExpansionChanged: (v) => setState(() => _isFunctionsExpanded = v),
      ));
    }

    if (_currentMode == CalculatorMode.statistics) {
      sections.add(_buildExpandableSection(
        title: 'Statistika',
        buttons: ['SD', 'VAR', 'MEAN', 'STATS', 'CV', ';'],
        isExpanded: _isStatsExpanded,
        onExpansionChanged: (v) => setState(() => _isStatsExpanded = v),
      ));
    }

    if (_currentMode == CalculatorMode.electrician) {
      sections.add(_buildExpandableSection(
        title: 'Elektrotechnika',
        buttons: ['OHM_V', 'OHM_I', 'OHM_R', 'PWR_P', 'PAR', 'SER', 'XL', 'XC', 'Hz', 'μ', 'n', 'p'],
        isExpanded: _isElectricianExpanded,
        onExpansionChanged: (v) => setState(() => _isElectricianExpanded = v),
      ));
    }

    sections.add(_buildExpandableSection(
      title: 'Navigace a úpravy',
      buttons: [],
      isExpanded: true,
      onExpansionChanged: (v) {},
      extraButtons: [
        buildButton('←', semanticLabel: 'Posunout kurzor doleva', onPressed: () {
          if (_cursorPosition > 0) setState(() => _cursorPosition--);
        }),
        buildButton('→', semanticLabel: 'Posunout kurzor doprava', onPressed: () {
          if (_cursorPosition < display.length) setState(() => _cursorPosition++);
        }),
      ],
    ));

    sections.add(_buildExpandableSection(
      title: 'Zobrazení výsledku',
      buttons: [],
      isExpanded: true,
      onExpansionChanged: (v) {},
      extraButtons: [
        buildButton('NORM', semanticLabel: 'Standardní zobrazení', onPressed: () {
          setState(() => _displayFormat = DisplayFormat.standard);
          speak('Standardní zobrazení');
        }),
        buildButton('FIX', semanticLabel: 'Pevný počet míst', onPressed: () => _showPrecisionDialog(DisplayFormat.fix)),
        buildButton('SCI', semanticLabel: 'Vědecký zápis', onPressed: () => _showPrecisionDialog(DisplayFormat.sci)),
        buildButton('ENG', semanticLabel: 'Technický zápis', onPressed: () => _showPrecisionDialog(DisplayFormat.eng)),
      ],
    ));

    sections.add(_buildExpandableSection(
      title: 'Proměnné a paměti',
      buttons: ['A', 'B', 'D', 'E', 'F', 'X', 'Y', 'M'],
      isExpanded: _isVariablesExpanded,
      onExpansionChanged: (v) => setState(() => _isVariablesExpanded = v),
      extraButtons: [
        buildButton('Var C', semanticLabel: 'Proměnná C', onPressed: () => _handleButtonPressed('C')),
      ],
    ));

    sections.add(_buildExpandableSection(
      title: 'Paměť a historie',
      buttons: ['STO', 'RCL', 'CLR', 'ANS'],
      isExpanded: _isMemoryExpanded,
      onExpansionChanged: (v) => setState(() => _isMemoryExpanded = v),
    ));

    return sections;
  }

  // Odstraněna redundantní metoda _buildBottomActions, vše je nyní v hlavní mřížce

}

class _AccessibilityDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _AccessibilityDialog({required this.parent});

  @override
  State<_AccessibilityDialog> createState() => _AccessibilityDialogState();
}

class _AccessibilityDialogState extends State<_AccessibilityDialog> {
  late FocusNode _focusSlider;
  late FocusNode _focusSwitch;
  late FocusNode _focusDone;

  @override
  void initState() {
    super.initState();
    _focusSlider = FocusNode();
    _focusSwitch = FocusNode();
    _focusDone = FocusNode();
  }

  @override
  void dispose() {
    _focusSlider.dispose();
    _focusSwitch.dispose();
    _focusDone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nastavení usnadnění'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AccessibilityType>(
              autofocus: true,
              title: const Text('Standardní režim'),
              value: AccessibilityType.none,
              groupValue: widget.parent._accessibilityType,
              onChanged: (v) => setState(() {
                widget.parent.setState(() => widget.parent._accessibilityType = v!);
                widget.parent._saveSettings();
              }),
            ),
            RadioListTile<AccessibilityType>(
              title: const Text('Režim pro nevidomé'),
              value: AccessibilityType.blind,
              groupValue: widget.parent._accessibilityType,
              onChanged: (v) => setState(() {
                widget.parent.setState(() {
                  widget.parent._accessibilityType = v!;
                  widget.parent.ttsEnabled = true;
                  widget.parent._fontSizeMultiplier = 1.0;
                });
                widget.parent._saveSettings();
              }),
            ),
            const Divider(),
            ListTile(
              title: const Text('Velikost písma'),
              subtitle: Slider(
                focusNode: _focusSlider,
                value: widget.parent._fontSizeMultiplier,
                min: 0.8,
                max: 3.0,
                divisions: 22,
                label: '${(widget.parent._fontSizeMultiplier * 100).toInt()}%',
                onChanged: (v) => setState(() => widget.parent.setState(() => widget.parent._fontSizeMultiplier = v)),
                onChangeEnd: (v) => widget.parent._saveSettings(),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Velikost oblasti displeje'),
              subtitle: Slider(
                value: widget.parent._displaySizeFactor,
                min: 1.0,
                max: 5.0,
                divisions: 20,
                label: '${(widget.parent._displaySizeFactor * 100).toInt()}%',
                onChanged: (v) => setState(() => widget.parent.setState(() => widget.parent._displaySizeFactor = v)),
                onChangeEnd: (v) => widget.parent._saveSettings(),
              ),
            ),
            SwitchListTile(
              title: const Text('Vícesegmentový displej (16 seg)'),
              subtitle: const Text('Lepší čitelnost písmen a textu'),
              value: widget.parent._useSixteenSegment,
              onChanged: (v) => setState(() {
                widget.parent.setState(() => widget.parent._useSixteenSegment = v);
                widget.parent._saveSettings();
              }),
            ),
            SwitchListTile(
              title: const Text('Uvítací zpráva při startu'),
              value: widget.parent._sayWelcome,
              onChanged: (v) => setState(() {
                widget.parent.setState(() => widget.parent._sayWelcome = v);
                widget.parent._saveSettings();
              }),
            ),
            const Divider(),
            SwitchListTile(
              focusNode: _focusSwitch,
              title: const Text('Hlas kalkulačky'),
              value: widget.parent.ttsEnabled,
              onChanged: (v) => setState(() {
                widget.parent.setState(() => widget.parent.ttsEnabled = v);
                widget.parent._saveSettings();
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          focusNode: _focusDone,
          onPressed: () => Navigator.pop(context),
          child: const Text('HOTOVO'),
        ),
      ],
    );
  }
}
