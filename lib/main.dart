import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:math_expressions/math_expressions.dart' as math_expr;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
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
double _dotMatrixZoom = 1.0;
double _resultZoom = 1.0;
final double _displaySizeFactor = 1.0;
double _speechRate = 0.5;
double _speechVolume = 1.0;
int? _inverseFormatPreference; // 0: DMS, 1: Desetinné

DisplayFormat _displayFormat = DisplayFormat.standard;
int _precision = 2;
double? _lastNumericValue;

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

final ScrollController _scrollControllerH = ScrollController();
final ScrollController _scrollControllerV = ScrollController();

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
bool _isRecallMode = false;
bool _hasResult = false;

final Map<String, String> _buttonNames = {
'SIN': 'Sinus', 'COS': 'Kosinus', 'TAN': 'Tangens', 'ASIN': 'Arkus sinus', 'ACOS': 'Arkus kosinus', 'ATAN': 'Arkus tangens',
'ABS': 'Absolutní hodnota', '°→\'': 'Převod na DMS', '\'→°': 'Převod na stupně', 'DMS': 'Vložit DMS',
'=': 'Rovná se', '/': 'Lomeno', '*': 'Krát', '-': 'Mínus', '+': 'Plus', '(': 'Závorka otevřená', ')': 'Závorka zavřená', '.': 'Tečka',
'^': 'Mocnina', '√': 'Odmocnina', 'ⁿ√': 'En-tá odmocnina', 'x²': 'Na druhou', 'x³': 'Na třetí', '∛': 'Třetí odmocnina', '1/x': 'Převrácená hodnota',
'LOG': 'Logaritmus', 'LN': 'Přirozený logaritmus',
'A': 'Proměnná A', 'B': 'Proměnná B', 'C': 'Proměnná C', 'D': 'Proměnná D', 'E': 'Proměnná E', 'F': 'Proměnná F',
'X': 'Proměnná X', 'Y': 'Proměnná Y', 'M': 'Proměnná M',
'ANS': 'Poslední výsledek', 'STO': 'Uložit do paměti', 'DEL': 'Smazat poslední', 'RCL': 'Vyvolat z paměti', 'CLR': 'Smazat celou paměť', 'C': 'Smazat displej',
'DEG': 'Stupně', 'RAD': 'Radiány', '%': 'Procenta', 'SD': 'Směrodatná odchylka', 'VAR': 'Rozptyl', 'MEAN': 'Průměr', 'STATS': 'Statistický souhrn',
'CV': 'Variační koeficient', ';': 'Oddělovač dat', '!': 'Faktoriál', '(-)': 'Záporné číslo se závorkou', 'EXP': 'krát deset na',
'OHM_V': 'Napětí', 'OHM_I': 'Proud', 'OHM_R': 'Odpor', 'PWR_P': 'Výkon', 'PAR': 'Paralelně', 'SER': 'Sériově', 'Hz': 'Hertz', 'μ': 'Mikro', 'n': 'Nano', 'p': 'Piko',
};

double _factorial(int n) {
  if (n < 0) return double.nan;
  if (n == 0) return 1;
  if (n > 20) return double.infinity; // Omezení pro double přesnost a prevenci záseku
  double res = 1;
  for (int i = 1; i <= n; i++) {
    res *= i;
  }
  return res;
}

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
String processed = text.replaceAll('.', ',').replaceAll('\u03C0', 'pí');
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
if (display.isNotEmpty && lastDigit.hasMatch(display.substring(0, _cursorPosition))) {
append("'", silent: true);
speak('minut');
return;
}
append("'", silent: true);
speak('minut');
}

void _insertDmsChar() {
  _handleButtonPressed('DMS');
}

void backspace() { _deleteAtCursor(); }
void clear() { setState(() { display = ''; _cursorPosition = 0; _lastResult = '0.'; _isStoreMode = false; _isRecallMode = false; _hasResult = false; }); speak('Vymazat'); }
void append(String value, {bool silent = false}) { _insertAtCursor(value); if (!silent) speak(_buttonNames[value] ?? value); }

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
speak('Uloženo do proměnné $name');
} else if (_isRecallMode) {
String valStr = _formatNumber(_memory[name]!).replaceAll('.', ',');
append(_formatNumber(_memory[name]!), silent: true);
speak('Vyvoláno $valStr');
_isRecallMode = false;
} else {
append(name);
}
}

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
    if (display.isEmpty) return;
    String currentExpression = display; // Uložíme výraz před vymazáním displeje

    String resStr = '0';
    String spoken = '';

    if (_currentMode == CalculatorMode.statistics) {
      List<double> data = display.split(';').map((s) => double.parse(s.replaceAll(',', '.'))).toList();
      if (data.isEmpty) throw Exception('Prázdná data');
      
      double sum = data.reduce((a, b) => a + b);
      double mean = sum / data.length;
      double variance = data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
      double sd = math.sqrt(variance);

      // Zjednodušená implementace pro demo účely: vrací průměr
      resStr = _formatNumber(mean);
      spoken = 'Průměr je ${_formatNumber(mean).replaceAll('.', ',')}, směrodatná odchylka je ${_formatNumber(sd).replaceAll('.', ',')}';
    } else if (_currentMode == CalculatorMode.electrician) {
      // Implementace Ohmova zákona: pokud je na displeji "V;I", vypočítá R atd.
      List<String> parts = display.split(';');
      if (parts.length >= 2) {
        double v1 = double.parse(parts[0].replaceAll(',', '.'));
        double v2 = double.parse(parts[1].replaceAll(',', '.'));
        // Zde by byla komplexnější logika, pro teď základní Ohmův zákon V/I
        double r = v1 / v2;
        resStr = _formatNumber(r);
        spoken = 'Výsledek je ${_formatNumber(r).replaceAll('.', ',')}';
      } else {
        throw Exception('Chybějící data');
      }
    } else {
      bool isDms = RegExp(r'''\d+(?:\.\d+)?[°'"]''').hasMatch(display);
      bool isTrig = display.toUpperCase().contains('SIN') || 
                    display.toUpperCase().contains('COS') || 
                    display.toUpperCase().contains('TAN');
      bool isInverse = display.toUpperCase().contains('ASIN') || 
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
        spoken = 'Výsledek je ${resStr.replaceAll('°', ' stupňů, ').replaceAll('\'', ' minut a ').replaceAll('"', ' sekund').replaceAll('.', ',')}';
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

    speak(spoken);
    _addToHistory(currentExpression, resStr);
  } catch (e) {
    String msg = 'Výrazu nerozumím, zkuste zkontrolovat závorky nebo znaménka';
    String errStr = e.toString().toLowerCase();
    if (errStr.contains('division by zero') || errStr.contains('infinity')) msg = 'Nulou nelze dělit';
    else if (errStr.contains('range') || errStr.contains('invalid argument')) msg = 'Hodnota je mimo povolený rozsah funkce';

    setState(() {
      _lastResult = 'Error';
      _hasResult = true;
    });
    speak(msg);
  }
}
double _evaluateExpression(String expr) {
  debugPrint("Evaluating expression: '$expr'");
  String ansValue = _lastNumericValue?.toString() ?? '0';
  String processed = expr.replaceAll('ANS', '($ansValue)').replaceAll(' ', '');

  // 0. NAHRAZENÍ PROMĚNNÝCH
  _memory.forEach((key, value) {
    processed = processed.replaceAll(RegExp('\\b$key\\b'), '(${value.toString()})');
  });

  // 1. DMS ZPRACOVÁNÍ (přesunuto na začátek)
  processed = processed.replaceAllMapped(RegExp(r'''(?<![\d.])(-?\d+(?:\.\d+)?)°(?:(\d+(?:\.\d+)?)\')?(?:(\d+(?:\.\d+)?)\")?'''), (m) {
    double d = double.parse(m[1]!);
    double mn = m[2] != null ? double.parse(m[2]!) : 0.0;
    double sc = m[3] != null ? double.parse(m[3]!) : 0.0;
    double sign = d < 0 ? -1.0 : 1.0;
    return '(${sign * (d.abs() + mn / 60.0 + sc / 3600.0)})';
  });

  // 2. ZÁKLADNÍ PŘÍPRAVA
  const String PI_VAL = '3.14159265358979323846';
  processed = processed.replaceAll('\u03C0', '($PI_VAL)');
  processed = processed.replaceAll(',', '.');
  processed = processed.replaceAll('°→\'', '').replaceAll('\'→°', '');

  // 2.1 PRE-PROCESSING FAKTORIÁLU
  // Najde čísla následovaná vykřičníkem (např. 5!) a nahradí je vypočtenou hodnotou.
  processed = processed.replaceAllMapped(RegExp(r'(\d+)!'), (m) {
    int n = int.parse(m[1]!);
    return _factorial(n).toString();
  });

  if (processed.isEmpty) return 0.0;

  processed = processed.replaceAllMapped(RegExp(r"(\d+(?:\.\d+)?|\))E([+-]?\d+)"), (m) => '${m[1]}*10^(${m[2]})');
  processed = processed.replaceAll('x²', '^2').replaceAll('x³', '^3').replaceAll('(-)', '-');
  processed = processed.replaceAll('∛', '#CBRT#');

  // 3. IMPLICITNÍ NÁSOBENÍ
  processed = processed.replaceAllMapped(RegExp(r'(\d)(\(|[A-Z√#])'), (m) => '${m[1]}*${m[2]}');
  processed = processed.replaceAllMapped(RegExp(r'\)(\d)'), (m) => ')*${m[1]}');
  processed = processed.replaceAll(')(', ')*(');

  // 4. TOKENIZACE FUNKCÍ
  final Map<String, String> markers = {
    'ASIN': '#ASIN#', 'ACOS': '#ACOS#', 'ATAN': '#ATAN#',
    'SIN': '#SIN#', 'COS': '#COS#', 'TAN': '#TAN#',
    'ABS': '#ABS#', 'LOG': '#LOG#', 'LN': '#LN#', '√': '#SQRT#',
  };

  markers.forEach((name, marker) {
    String pattern = (name == '√') ? '√' : '\\b$name';
    processed = processed.replaceAll(RegExp(pattern, caseSensitive: false), marker);
  });

  // Speciální zpracování pro n-tou odmocninu: xⁿ√y -> (x)^(1/y)
  // Podporuje čísla, proměnné i výrazy v závorkách (včetně nahrazeného ANS)
  processed = processed.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))ⁿ√(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))'), (m) {
    return '(${m[1]})^(1/(${m[2]}))';
  });

  // 5. BALANCOVÁNÍ ZÁVOREK (přesunuto před expanzi pro stabilitu)
  int openCount = '('.allMatches(processed).length;
  int closeCount = ')'.allMatches(processed).length;
  if (openCount > closeCount) {
    processed += ')' * (openCount - closeCount);
  } else if (closeCount > openCount) {
    // Odstranit přebytečné zavírací závorky z konce nebo začátku
    processed = processed.replaceAll(RegExp(r'^\)+|\)+$'), '');
  }

  // 6. EXPANZE MARKERŮ (opraveno pro vnořené závorky)
  if (_isDegreeMode) {
    processed = processed.replaceAllMapped(RegExp(r'#SIN#\((([^()]*|\([^()]*\))*)\)'), (m) => 'sin((${m[1]}*$PI_VAL/180))');
    processed = processed.replaceAllMapped(RegExp(r'#COS#\((([^()]*|\([^()]*\))*)\)'), (m) => 'cos((${m[1]}*$PI_VAL/180))');
    processed = processed.replaceAllMapped(RegExp(r'#TAN#\((([^()]*|\([^()]*\))*)\)'), (m) => 'tan((${m[1]}*$PI_VAL/180))');
    processed = processed.replaceAllMapped(RegExp(r'#ASIN#\((([^()]*|\([^()]*\))*)\)'), (m) => '(180/$PI_VAL)*arcsin(${m[1]})');
    processed = processed.replaceAllMapped(RegExp(r'#ACOS#\((([^()]*|\([^()]*\))*)\)'), (m) => '(180/$PI_VAL)*arccos(${m[1]})');
    processed = processed.replaceAllMapped(RegExp(r'#ATAN#\((([^()]*|\([^()]*\))*)\)'), (m) => '(180/$PI_VAL)*arctan(${m[1]})');
  } else {
    processed = processed.replaceAll('#SIN#', 'sin').replaceAll('#COS#', 'cos').replaceAll('#TAN#', 'tan');
    processed = processed.replaceAll('#ASIN#', 'arcsin').replaceAll('#ACOS#', 'arccos').replaceAll('#ATAN#', 'arctan');
  }

  processed = processed.replaceAll('#ABS#', 'abs').replaceAll('#SQRT#', 'sqrt').replaceAll('#LN#', 'ln');
  processed = processed.replaceAllMapped(RegExp(r'#CBRT#\((([^()]*|\([^()]*\))*)\)'), (m) => '(${m[1]})^(1/3)');
  processed = processed.replaceAll('#CBRT#', '('); // Fallback
  processed = processed.replaceAll('#LOG#(', 'log(10,');

  // 7. FINÁLNÍ VYHODNOCENÍ
  if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(processed)) {
    processed = '$processed+0';
  }

  try {
    final p = math_expr.ShuntingYardParser();
    debugPrint("Parsing expression: $processed");
    return p.parse(processed).evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());
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
int engExp = ((math.log(value.abs()) / math.ln10).floor() / 3).floor() * 3;
return "${(value / math.pow(10, engExp)).toStringAsFixed(_precision)}E${engExp >= 0 ? '+' : ''}${engExp.toString().padLeft(2, '0')}";
default:
return value.toString().contains('.') ? value.toStringAsFixed(10).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : value.toInt().toString();
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
size: 16 * _resultZoom,
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
size: 8 * _resultZoom,
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
      _dotMatrixZoom = prefs.getDouble('dotMatrixZoom') ?? 1.0;
      _resultZoom = prefs.getDouble('resultZoom') ?? 1.0;
      ttsEnabled = prefs.getBool('ttsEnabled') ?? true;
      _useSixteenSegment = prefs.getBool('useSixteenSegment') ?? false;
      _accessibilityType = AccessibilityType.values[prefs.getInt('accessibilityType') ?? 0];
      _speechRate = prefs.getDouble('speechRate') ?? 0.5;
      _speechVolume = prefs.getDouble('speechVolume') ?? 1.0;
      _inverseFormatPreference = prefs.getInt('inverseFormatPreference');
    });
    await tts.setSpeechRate(_speechRate);
    await tts.setVolume(_speechVolume);
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
}

void _saveInversePreference(int val) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('inverseFormatPreference', val);
  setState(() => _inverseFormatPreference = val);
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
    // Používáme oddělovač |, který se v matematických výrazech nevyskytuje
    _history.insert(0, '$exp|$res');
    if (_history.length > 20) _history.removeLast();
  });
  _saveHistory();
}

void _showInitialAccessibilityDialog() {
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => AlertDialog(
title: Semantics(header: true, child: Text('Vítejte')),
content: Text('Vyberte požadovanou úroveň usnadnění. Toto nastavení můžete kdykoliv změnit v nastavení.'),
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
child: Text('STANDARDNÍ')),
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
child: Text('PRO NEVIDOMÉ')),
]));
}

void _showAccessibilityDialog() {
showDialog(context: context, builder: (context) => _AccessibilityDialog(parent: this));
}

void _showTutorialDialog() {
  final l10n = AppLocalizations.of(context)!;
  String tutorialText = l10n.tutorialText;
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    tutorialText = tutorialText.split('\n\n').first; // Odstranit sekci zkratek
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
          child: SingleChildScrollView(
            child: Text(tutorialText),
          ),
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
child: Text('$i')))),
actions: [
TextButton(onPressed: () {
Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mainFocusNode.requestFocus();
                });
}, child: Text('ZRUŠIT'))
]));
}

Widget _buildDotMatrixDisplay() {
  String txt = display.isEmpty ? (_hasResult ? "" : "_") : "${display.substring(0, _cursorPosition)}_${display.substring(_cursorPosition)}";
  return CustomDotMatrixDisplay(text: txt, ledSize: 3.0 * _dotMatrixZoom, ledSpacing: 0.8 * _dotMatrixZoom);
}

Widget buildButton(String label, {Color? color, String? semanticLabel, VoidCallback? onPressed}) {
final String descriptiveName = semanticLabel ?? (_buttonNames[label] ?? label);
return Padding(
padding: const EdgeInsets.all(2),
child: MergeSemantics(
child: ElevatedButton(
style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: color != null ? Colors.white : null, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
onFocusChange: (hasFocus) {
if (hasFocus) speak(descriptiveName);
},
onPressed: onPressed ??
() {
if (!['°→\'', '\'→°', 'DMS'].contains(label)) {
speak(descriptiveName);
}
_handleButtonPressed(label);
},
child: Semantics(
  label: descriptiveName,
  child: ExcludeSemantics(
    child: Text(label, style: TextStyle(fontSize: 18 * _fontSizeMultiplier, fontWeight: FontWeight.bold)),
  ),
),),),);
}

void _handleButtonPressed(String label, {bool silent = false}) {
  bool alreadyHandled = false;
  if (_hasResult) {
    setState(() {
      if (['+', '-', '*', '/', '^', '%', 'EXP', 'x²', 'x³'].contains(label)) {
        display = 'ANS';
        _cursorPosition = 3;
        _hasResult = false;
      } else if (['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '√', '∛', 'ABS', 'LOG', 'LN'].contains(label)) {
        display = '$label(ANS)';
        _cursorPosition = display.length;
        _hasResult = false;
        if (!silent) speak('${_buttonNames[label] ?? label} z výsledku');
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
  } else if (['MEAN', 'SD', 'VAR'].contains(label)) {
    if (_currentMode == CalculatorMode.statistics) {
      try {
        List<double> data = display.split(';').where((s) => s.isNotEmpty).map((s) => double.parse(s.replaceAll(',', '.'))).toList();
        if (data.isEmpty) throw Exception('Prázdná data');
        
        double sum = data.reduce((a, b) => a + b);
        double mean = sum / data.length;
        double variance = data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
        double sd = math.sqrt(variance);

        String resStr = '0';
        String spoken = '';
        if (label == 'MEAN') {
          resStr = _formatNumber(mean);
          spoken = 'Průměr je ${resStr.replaceAll('.', ',')}';
        } else if (label == 'VAR') {
          resStr = _formatNumber(variance);
          spoken = 'Rozptyl je ${resStr.replaceAll('.', ',')}';
        } else if (label == 'SD') {
          resStr = _formatNumber(sd);
          spoken = 'Směrodatná odchylka je ${resStr.replaceAll('.', ',')}';
        }

        setState(() {
          _lastResult = resStr;
          _hasResult = true;
          display = '';
          _cursorPosition = 0;
          _lastNumericValue = double.tryParse(resStr.replaceAll(',', '.'));
        });
        speak(spoken);
        _addToHistory('STATS($label)', resStr);
      } catch (e) {
        speak('Chyba statistického výpočtu. Zkontrolujte formát dat s oddělovačem středník.');
      }
    } else {
      append(label, silent: silent);
    }
  } else if (label == 'STO') {
    _isStoreMode = true;
    speak('Vyberte paměť');
  } else if (label == 'RCL') {
    _isRecallMode = true;
    speak('Vyberte paměť pro vyvolání');
  } else if (label == 'CLR') {
    setState(() {
      _memory.updateAll((key, value) => 0);
    });
    speak('Paměť smazána');
  } else if (_memory.containsKey(label)) {
    _handleMemoryVariable(label);
  } else if (label == 'EXP') {
    append('E', silent: silent);
  } else if (['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '√', '∛', 'ABS', 'LOG', 'LN'].contains(label)) {
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
          display = display.substring(0, _cursorPosition - 1) + nextSymbol + display.substring(_cursorPosition);
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
      double val = display.isNotEmpty ? _evaluateExpression(display) : (_lastNumericValue ?? 0.0);
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
        speak('Výsledek je $spokenDms');
      } else {
        // Převod na desetinné stupně
        String decimalStr = val.toStringAsFixed(4).replaceAll(RegExp(r'\.0+$'), '').replaceAll(RegExp(r'0+$'), '');
        setState(() {
          _lastResult = decimalStr;
          _hasResult = true;
          display = '';
          _cursorPosition = 0;
          _lastNumericValue = val;
        });
        speak('Výsledek je ${decimalStr.replaceAll('.', ',')} stupňů');
      }
    } catch (e) {
      speak('Chyba při převodu');
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
      btns = ['C', '(', ')', '/', '7', '8', '9', '*', '4', '5', '6', '-', '1', '2', '3', '+', 'DEL', '0', '.', '='];
      break;
    case CalculatorMode.scientific:
      btns = ['C', '(', ')', '/', '7', '8', '9', '*', '4', '5', '6', '-', '1', '2', '3', '+', '0', '.', 'EXP', '='];
      break;
    case CalculatorMode.statistics:
      btns = ['SD', 'VAR', 'MEAN', 'C', '7', '8', '9', '/', '4', '5', '6', '*', '1', '2', '3', '-', '0', ';', 'DEL', '='];
      break;
    case CalculatorMode.electrician:
      btns = ['OHM_V', 'OHM_I', 'OHM_R', 'C', '7', '8', '9', '/', '4', '5', '6', '*', '1', '2', '3', '-', '0', '.', 'DEL', '='];
      break;
    case CalculatorMode.unitConversion:
      btns = ['C', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '.', 'DEL', '='];
      break;
  }
  return LayoutBuilder(builder: (context, constraints) {
    double itemWidth = constraints.maxWidth / 4;
    double itemHeight = constraints.maxHeight / 5;
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: itemWidth / itemHeight,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: btns.length,
      itemBuilder: (context, index) {
        String b = btns[index];
        Color? color;
        if (['/', '*', '-', '+'].contains(b)) color = Colors.blue;
        else if (b == 'C') color = Colors.orange;
        else if (b == 'DEL') color = Colors.redAccent;
        else if (b == '=') color = Colors.green;
        
        return buildButton(b, color: color, onPressed: () => _handleButtonPressed(b));
      },
    );
  });
}

Widget _buildModeSelector() {
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 8.0,
    runSpacing: 4.0,
    children: CalculatorMode.values.map((mode) {
      String label = _getModeName(mode);
      return ChoiceChip(
        label: Text(label),
        selected: _currentMode == mode,
        onSelected: (s) {
          if (s) {
            _changeMode(mode);
            speak('Přepnuto na ${_getModeSpeechName(mode)}');
          }
        },
      );
    }).toList(),
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

void _showHistoryDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Semantics(header: true, child: const Text('Historie výpočtů')),
      content: SizedBox(
        width: double.maxFinite,
        child: _history.isEmpty 
            ? Semantics(container: true, child: const Text('Historie je prázdná.'))
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

                    String semanticDescription = "Výpočet: $expression, výsledek: $result. Poklepáním vložíte výsledek, přidržením vložíte celý výpočet.";
                    
                    return Semantics(
                      label: semanticDescription,
                      container: true,
                      child: MergeSemantics(
                        child: ListTile(
                          title: Text(expression, style: const TextStyle(fontSize: 14)),
                          subtitle: result.isNotEmpty 
                              ? Text(result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)) 
                              : null,
                          onTap: () => _insertFromHistory(result.isNotEmpty ? result : expression),
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
        TextButton(onPressed: () {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mainFocusNode.requestFocus();
          });
        }, child: const Text('ZAVŘÍT')),
      ],
    ),
  );
}

void _showClearHistoryConfirmation() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Semantics(header: true, child: const Text('Potvrzení')),
      content: Semantics(
        container: true,
        label: 'Otázka',
        child: const Text('Opravdu chcete smazat celou historii výpočtů?'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _history.clear();
              _saveHistory();
            });
            speak('Historie smazána');
            Navigator.pop(context);
          },
          child: const Text('ANO, SMAZAT'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('NE, ZŮSTAT')),
      ],
    ),
  );
}

@override
Widget build(BuildContext context) {
return KeyboardListener(
focusNode: _mainFocusNode,
onKeyEvent: _handleKeyboardInput,
child: Scaffold(
appBar: AppBar(
title: const Text('Mluvící kalkulačka'),
actions: [
IconButton(
icon: const Icon(Icons.history),
tooltip: 'Historie',
onPressed: _showHistoryDialog,
),
IconButton(
icon: const Icon(Icons.list),
tooltip: 'Pokročilé funkce',
onPressed: _showAdvancedFunctionsDialog,
),
IconButton(
icon: const Icon(Icons.help_outline),
tooltip: 'Nápověda k ovládání',
onPressed: _showTutorialDialog,
),
IconButton(
icon: const Icon(Icons.settings),
tooltip: 'Nastavení přístupnosti',
onPressed: _showAccessibilityDialog,
)
],
),
body: Column(
        children: [
          Expanded(
            flex: (800 * _displaySizeFactor).toInt(),
            child: GestureDetector(
              onScaleUpdate: (ScaleUpdateDetails details) {
                if (details.scale != 1.0) {
                  setState(() {
                    _dotMatrixZoom = (_dotMatrixZoom * details.scale).clamp(0.5, 5.0);
                    _resultZoom = (_resultZoom * details.scale).clamp(0.5, 5.0);
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF121212), border: Border.all(color: Colors.black, width: 3)),
                child: Semantics(
                  liveRegion: true,
                  label: 'Displej (zoomujte dvěma prsty, posouvejte tahem)',
                  value: display.isEmpty ? 'Prázdno' : display.replaceAll('.', ','),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Text(_getModeName(_currentMode).toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
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
          _buildModeSelector(),
          Expanded(
            flex: 1200,
            child: _buildMainKeyboard(),
          ),
        ],
      ),),
);
}
}

class _AdvancedFunctionsDialog extends StatelessWidget {
final _CalculatorScreenState parent;
const _AdvancedFunctionsDialog({required this.parent});

List<Widget> _buildSections() {
List<Widget> sections = [];
if (parent._currentMode == CalculatorMode.unitConversion) {
sections.add(Padding(
padding: const EdgeInsets.all(12.0),
child: Card(
child: Padding(
padding: const EdgeInsets.all(12.0),
child: Column(children: [
DropdownButtonFormField<String>(
value: parent._selectedUnitCategory,
decoration: const InputDecoration(labelText: 'Kategorie'),
items: parent._unitCategories.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
onChanged: (val) {
parent.setState(() {
parent._selectedUnitCategory = val!;
parent._unitFrom = parent._unitCategories[val]!.keys.first;
parent._unitTo = parent._unitCategories[val]!.keys.elementAt(1);
});
parent.speak('Kategorie $val');
}),
Row(children: [
Expanded(
child: DropdownButtonFormField<String>(
value: parent._unitFrom,
decoration: const InputDecoration(labelText: 'Z'),
items: parent._unitCategories[parent._selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(parent._getUnitSpeech(u)))).toList(),
onChanged: (val) {
parent.setState(() => parent._unitFrom = val!);
parent.speak('Z jednotky ${parent._getUnitSpeech(val!)}');
})),
const Icon(Icons.arrow_forward),
Expanded(
child: DropdownButtonFormField<String>(
value: parent._unitTo,
decoration: const InputDecoration(labelText: 'Na'),
items: parent._unitCategories[parent._selectedUnitCategory]!.keys.map((u) => DropdownMenuItem(value: u, child: Text(parent._getUnitSpeech(u)))).toList(),
onChanged: (val) {
parent.setState(() => parent._unitTo = val!);
parent.speak('Na jednotku ${parent._getUnitSpeech(val!)}');
})),
]),
const SizedBox(height: 8),
SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: parent._convertUnits, icon: const Icon(Icons.sync), label: const Text('PŘEVÉST'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)))),
])))));
}

sections.add(ExpansionTile(
title: const Text('Goniometrie', style: TextStyle(fontWeight: FontWeight.bold)),
children: [
GridView.count(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
addSemanticIndexes: false,
crossAxisCount: 4,
childAspectRatio: 1.3,
children: ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN'].map((b) => parent.buildButton(b)).toList())
]));

sections.add(ExpansionTile(
title: const Text('Funkce', style: TextStyle(fontWeight: FontWeight.bold)),
children: [
GridView.count(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
addSemanticIndexes: false,
crossAxisCount: 4,
childAspectRatio: 1.3,
children: ['√', '∛', 'ⁿ√', '!', 'LOG', 'LN', 'EXP', 'x²', 'x³', '^', '\u03C0', 'DMS', '°→\'', '\'→°', 'ANS', 'ABS'].map((b) => parent.buildButton(b)).toList())
]));

sections.add(ExpansionTile(
title: const Text('Paměť', style: TextStyle(fontWeight: FontWeight.bold)),
children: [
GridView.count(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
addSemanticIndexes: false,
crossAxisCount: 4,
childAspectRatio: 1.3,
children: ['STO', 'RCL', 'CLR'].map((b) => parent.buildButton(b)).toList()),
const Divider(),
GridView.count(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
addSemanticIndexes: false,
crossAxisCount: 4,
childAspectRatio: 1.3,
children: ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'].map((b) {
if (b == 'C') {
return parent.buildButton('C', semanticLabel: 'Proměnná C', onPressed: () => parent._handleMemoryVariable('C'));
}
return parent.buildButton(b);
}).toList())
]));

sections.add(ExpansionTile(title: const Text('Zobrazení', style: TextStyle(fontWeight: FontWeight.bold)), children: [
Padding(
padding: const EdgeInsets.all(4.0),
child: Wrap(alignment: WrapAlignment.start, spacing: 4, runSpacing: 4, children: [
parent.buildButton('NORM', semanticLabel: 'Standardní zobrazení', onPressed: () {
parent.setState(() => parent._displayFormat = DisplayFormat.standard);
parent.speak('Nastaveno standardní zobrazení');
}),
parent.buildButton('FIX', semanticLabel: 'Zobrazení s pevným počtem desetinných míst', onPressed: () => parent._showPrecisionDialog(DisplayFormat.fix)),
parent.buildButton('SCI', semanticLabel: 'Vědecký zápis', onPressed: () => parent._showPrecisionDialog(DisplayFormat.sci)),
parent.buildButton('ENG', semanticLabel: 'Inženýrský zápis', onPressed: () => parent._showPrecisionDialog(DisplayFormat.eng))
]),
)
]));
return sections;
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: Semantics(header: true, child: const Text('Pokročilé funkce')),
content: SizedBox(
width: double.maxFinite,
child: ListView(
children: _buildSections(),
),
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(context);
Future.delayed(const Duration(milliseconds: 100), () {
if (parent.mounted) parent._mainFocusNode.requestFocus();
});
},
child: const Text('ZAVŘÍT'))
]);
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
'ⁿ': [false, false, false, false, false, false, false], // Symbolicky prázdné nebo specifické
'∛': [true, false, false, true, true, true, true], // Symbolicky jako root s horním segmentem
'√': [false, false, false, true, true, true, false],
'.': [false, false, false, false, false, false, false],
'_': [false, false, false, true, false, false, false],
';': [false, false, true, true, false, false, false], // Jako spodní tečka a čárka
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
'ⁿ': [false, false, false, false, false, false, false, false, false, false, true, true, false, false, false, false],
'∛': [true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false],
'√': [false, true, false, false, false, false, false, true, false, false, false, false, false, true, false, true],
"'": [false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false],
'"': [false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false],
'_': [false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false],
';': [false, false, false, true, true, false, false, false, false, false, false, false, false, false, true, false], // Symbolicky jako spodní čárka a tečka
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
';': [0x00, 0x00, 0x14, 0x00, 0x00],
};

@override
void paint(Canvas canvas, Size size) {
final data = _font[char] ?? _font[char.toUpperCase()] ?? [0x1F, 0x1F, 0x1F, 0x1F, 0x1F];
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
_AccessibilityDialog({required this.parent});
@override
State<_AccessibilityDialog> createState() => _AccessibilityDialogState();
}

class _AccessibilityDialogState extends State<_AccessibilityDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('Nastavení přístupnosti'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      widget.parent.setState(() => widget.parent._useSixteenSegment = !widget.parent._useSixteenSegment);
                      widget.parent._saveSettings();
                    });
                    widget.parent.speak(widget.parent._useSixteenSegment ? 'Zapnut 16-segmentový displej' : 'Zapnut 7-segmentový displej');
                  },
                  child: Text('Displej: ${widget.parent._useSixteenSegment ? '16-segmentový' : '7-segmentový'}')),
              const Divider(),
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      widget.parent.setState(() => widget.parent.ttsEnabled = !widget.parent.ttsEnabled);
                      widget.parent._saveSettings();
                    });
                    widget.parent.speak(widget.parent.ttsEnabled ? 'Hlas zapnut' : 'Hlas vypnut');
                  },
                  child: Text('Hlasový výstup: ${widget.parent.ttsEnabled ? 'Zapnuto' : 'Vypnuto'}')),
              const Divider(),
              ElevatedButton(
                  onPressed: () {
                    final newFormat = (widget.parent._inverseFormatPreference == 0) ? 1 : 0;
                    widget.parent._saveInversePreference(newFormat);
                    widget.parent.speak(newFormat == 0 
                        ? 'Formát nastaven na stupně, minuty a sekundy' 
                        : 'Formát nastaven na desetinné stupně');
                    setState(() {});
                  },
                  child: Text('Úhly: ${widget.parent._inverseFormatPreference == 0 ? 'DMS' : 'Desetinné'}')),
              const SizedBox(height: 16),

              // Seskupená Rychlost
              Semantics(
                container: true,
                label: 'Ovládání zoomu horního řádku',
                child: Column(children: [
                  const Text('Zoom horního řádku'),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Semantics(label: 'Zmenšit zoom', button: true, child: ElevatedButton(onPressed: () => _adjustDotMatrixZoom(-0.1), child: const Text('-'))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${(widget.parent._dotMatrixZoom * 100).toInt()}%')),
                    Semantics(label: 'Zvětšit zoom', button: true, child: ElevatedButton(onPressed: () => _adjustDotMatrixZoom(0.1), child: const Text('+'))),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Semantics(
                container: true,
                label: 'Ovládání zoomu dolního řádku',
                child: Column(children: [
                  const Text('Zoom dolního řádku'),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Semantics(label: 'Zmenšit zoom', button: true, child: ElevatedButton(onPressed: () => _adjustResultZoom(-0.1), child: const Text('-'))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${(widget.parent._resultZoom * 100).toInt()}%')),
                    Semantics(label: 'Zvětšit zoom', button: true, child: ElevatedButton(onPressed: () => _adjustResultZoom(0.1), child: const Text('+'))),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              // Seskupená Rychlost
              Semantics(
                container: true,
                label: 'Ovládání rychlosti hlasu',
                child: Column(children: [
                  const Text('Rychlost hlasu'),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Semantics(label: 'Snížit rychlost', button: true, child: ElevatedButton(onPressed: () => _adjustSpeechRate(-0.1), child: const Text('-'))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${(widget.parent._speechRate * 100).toInt()}%')),
                    Semantics(label: 'Zvýšit rychlost', button: true, child: ElevatedButton(onPressed: () => _adjustSpeechRate(0.1), child: const Text('+'))),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // Seskupená Hlasitost
              Semantics(
                container: true,
                label: 'Ovládání hlasitosti',
                child: Column(children: [
                  const Text('Hlasitost'),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Semantics(label: 'Snížit hlasitost', button: true, child: ElevatedButton(onPressed: () => _adjustSpeechVolume(-0.1), child: const Text('-'))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${(widget.parent._speechVolume * 100).toInt()}%')),
                    Semantics(label: 'Zvýšit hlasitost', button: true, child: ElevatedButton(onPressed: () => _adjustSpeechVolume(0.1), child: const Text('+'))),
                  ]),
                ]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (widget.parent.mounted) widget.parent._mainFocusNode.requestFocus();
                });
              },
              child: const Text('HOTOVO'))
        ]);
  }

  void _adjustDotMatrixZoom(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._dotMatrixZoom = (widget.parent._dotMatrixZoom + delta).clamp(0.5, 5.0);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak('Zoom horního řádku ${(widget.parent._dotMatrixZoom * 100).toInt()} procent');
  }

  void _adjustResultZoom(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._resultZoom = (widget.parent._resultZoom + delta).clamp(0.5, 5.0);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak('Zoom dolního řádku ${(widget.parent._resultZoom * 100).toInt()} procent');
  }

  void _adjustSpeechRate(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._speechRate = (widget.parent._speechRate + delta).clamp(0.1, 1.0);
        widget.parent.tts.setSpeechRate(widget.parent._speechRate);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak('Rychlost ${(widget.parent._speechRate * 100).toInt()} procent');
  }

  void _adjustSpeechVolume(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._speechVolume = (widget.parent._speechVolume + delta).clamp(0.0, 1.0);
        widget.parent.tts.setVolume(widget.parent._speechVolume);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak('Hlasitost ${(widget.parent._speechVolume * 100).toInt()} procent');
  }
}