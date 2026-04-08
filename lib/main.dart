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
      title: 'Vědecká kalkulačka',
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

enum CalculatorMode { basic, scientific, statistics, electrician }
enum AccessibilityType { none, blind, visuallyImpaired }

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
  String _lastResult = '0';
  CalculatorMode _currentMode = CalculatorMode.scientific;
  
  bool ttsEnabled = true;
  bool _isDegreeMode = true;
  bool? _preferDMSForInverse;
  bool _preferExponential = false;
  AccessibilityType _accessibilityType = AccessibilityType.none;
  double _fontSizeMultiplier = 1.0;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  List<dynamic> _availableVoices = [];
  List<dynamic> _availableEngines = [];
  Map<String, String>? _selectedVoice;
  String? _selectedEngine;
  
  // Proměnné pro prevenci NVDA zmrazení na Windows
  DateTime? _lastSpeakTime;
  final Duration _speakThrottle = const Duration(milliseconds: 300);

  // Test flag: dočasně potlačit TTS při ladění AXTree problémů
  bool _disableTtsForTesting = false;
  
  bool _isGonioExpanded = false;
  bool _isMemoryExpanded = false;
  bool _isHistoryExpanded = false;
  bool _isElectricianExpanded = true;

  final Map<String, double> _memory = {
    'A': 0, 'B': 0, 'C': 0, 'D': 0, 'E': 0, 'F': 0,
    'X': 0, 'Y': 0, 'M': 0,
  };

  List<String> _history = [];

  final Map<String, String> _buttonNames = {
    'SIN': 'Sinus', 'COS': 'Kosinus', 'TAN': 'Tangens',
    'ASIN': 'Arkus sinus', 'ACOS': 'Arkus kosinus', 'ATAN': 'Arkus tangens',
    'ABS': 'Absolutní hodnota',
    '°→\'': 'Převod na DMS', '\'→°': 'Převod na stupně', 'DMS': 'Vložit DMS',
    '=': 'Rovná se', '/': 'Lomeno', '*': 'Krát', '-': 'Mínus', '+': 'Plus',
    '(': 'Závorka otevřená', ')': 'Závorka zavřená', '.': 'Tečka',
    '^': 'Mocnina', '√': 'Odmocnina', 'ⁿ√': 'Odmocnina en',
    'x²': 'Na druhou', 'x³': 'Na třetí', '∛': 'Třetí odmocnina',
    'ANS': 'Poslední výsledek', 'STO': 'Uložit', 'DEL': 'Smazat poslední',
    'RCL': 'Vyvolat', 'CLR': 'Smazat paměť', 'C': 'Vymazat displej',
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

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSettings();
    _loadHistory();
  }

  void _initTts() async {
    try {
      if (!Platform.isWindows) {
        _availableEngines = await tts.getEngines;
      }
      
      await tts.setLanguage("cs-CZ");
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_speechVolume);
      await tts.setPitch(1.0);
      await tts.awaitSpeakCompletion(false);

      if (_selectedEngine != null && !Platform.isWindows) {
        await tts.setEngine(_selectedEngine!);
      }
      _updateAvailableVoices();
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }

    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('accessibilityType')) {
        _showInitialAccessibilityDialog();
        return;
      }

      String modeName = '';
      switch (_currentMode) {
        case CalculatorMode.basic: modeName = 'základní režim'; break;
        case CalculatorMode.scientific: modeName = 'vědecký režim'; break;
        case CalculatorMode.statistics: modeName = 'režim statistiky'; break;
        case CalculatorMode.electrician: modeName = 'elektrikářský režim'; break;
      }
      speak('Vítejte v mluvící kalkulačce. Aktivní je $modeName.');
    });
  }

  void _updateAvailableVoices() async {
    try {
      List<dynamic> voices = await tts.getVoices;
      setState(() {
        _availableVoices = voices.where((voice) {
          if (voice is! Map) return false;
          final locale = voice['locale']?.toString() ?? voice['name']?.toString() ?? '';
          return locale.toLowerCase().startsWith('cs');
        }).toList();
      });
    } catch (e) {
      debugPrint('Chyba při aktualizaci hlasů: $e');
    }
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
      case CalculatorMode.statistics: modeName = 'Režim statistiky'; break;
      case CalculatorMode.electrician: modeName = 'Elektrikářský režim'; break;
    }
    speak(modeName);
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDegreeMode = prefs.getBool('isDegreeMode') ?? true;
      _fontSizeMultiplier = prefs.getDouble('fontSizeMultiplier') ?? 1.0;
      ttsEnabled = prefs.getBool('ttsEnabled') ?? true;
      _speechRate = prefs.getDouble('speechRate') ?? 0.5;
      _speechVolume = prefs.getDouble('speechVolume') ?? 1.0;
      _preferExponential = prefs.getBool('preferExponential') ?? false;
      
      final accTypeIndex = prefs.getInt('accessibilityType') ?? AccessibilityType.none.index;
      _accessibilityType = AccessibilityType.values[accTypeIndex];

      if (prefs.containsKey('preferDMSForInverse')) {
        _preferDMSForInverse = prefs.getBool('preferDMSForInverse');
      }
      
      _selectedEngine = prefs.getString('selectedEngine');
      String? voiceName = prefs.getString('selectedVoiceName');
      String? voiceLocale = prefs.getString('selectedVoiceLocale');
      if (voiceName != null && voiceLocale != null) {
        _selectedVoice = {"name": voiceName, "locale": voiceLocale};
        tts.setVoice(_selectedVoice!);
      }
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDegreeMode', _isDegreeMode);
    await prefs.setDouble('fontSizeMultiplier', _fontSizeMultiplier);
    await prefs.setBool('ttsEnabled', ttsEnabled);
    await prefs.setDouble('speechRate', _speechRate);
    await prefs.setDouble('speechVolume', _speechVolume);
    await prefs.setBool('preferExponential', _preferExponential);
    await prefs.setInt('accessibilityType', _accessibilityType.index);

    if (_preferDMSForInverse != null) {
      await prefs.setBool('preferDMSForInverse', _preferDMSForInverse!);
    }
    if (_selectedEngine != null) await prefs.setString('selectedEngine', _selectedEngine!);
    if (_selectedVoice != null) {
      await prefs.setString('selectedVoiceName', _selectedVoice!['name']!);
      await prefs.setString('selectedVoiceLocale', _selectedVoice!['locale']!);
    }
  }

  void speak(String text, {BuildContext? context}) async {
    if (text.isEmpty) return;
    
    // ⚠️ KRITICKÉ: Zkontroluj mounted HNED na začátku
    if (!mounted) {
      debugPrint('⚠️ DEBUG: Widget unmounted! Text se nečte: "$text"');
      return;
    }
    
    final String speechText = _formatForSpeech(text);

    // ✅ OPRAVA: Throttling - zabránění spamování NVDA
    final now = DateTime.now();
    if (_lastSpeakTime != null && now.difference(_lastSpeakTime!) < _speakThrottle) {
      debugPrint('⏱️ DEBUG: Speak() zablokován (throttle) - text: "$text"');
      return;
    }
    _lastSpeakTime = now;

    if (!ttsEnabled) {
      debugPrint('🔇 DEBUG: TTS vypnuta - text se nečte: "$text"');
      return;
    }

    if (_disableTtsForTesting) {
      debugPrint('🔇 DEBUG: TTS dočasně potlačeno pro testování AXTree - text se nečte: "${text}"');
      return;
    }

    debugPrint('🔊 DEBUG: Začínám mluvit - ttsEnabled=$ttsEnabled, text="$speechText"');

    try {
      // ⚠️ KRITICKÉ: Bezpečnostní kontroly během async operací
      if (!mounted) {
        debugPrint('⚠️ DEBUG: Widget se unmountl během speak() start');
        return;
      }
      
      await tts.stop();
      
      // ⚠️ KRITICKÉ: Znovu zkontrolovat mounted po await
      if (!mounted) {
        debugPrint('⚠️ DEBUG: Widget se unmountl během tts.stop()');
        return;
      }
      
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_speechVolume);
      
      // ⚠️ KRITICKÉ: Znovu zkontrolovat mounted před mluvením
      if (!mounted) {
        debugPrint('⚠️ DEBUG: Widget se unmountl během nastavení parametrů');
        return;
      }
      
      if (_selectedVoice != null) await tts.setVoice(_selectedVoice!);
      final ttsResult = await tts.speak(speechText);
      debugPrint('✅ DEBUG: TTS.speak() vrátilo: $ttsResult, text="$speechText"');
    } catch (e) {
      debugPrint('❌ TTS Chyba (možná thread issue): $e');
    }
  }

  String _formatForSpeech(String text) {
    String processed = text.replaceAll('.', ',');
    processed = processed.replaceAllMapped(RegExp(r'(\d+(?:,\d+)?)[eE]\+?(-?\d+)'), (match) {
      return '${match[1]} krát deset na ${match[2]}';
    });
    return processed;
  }

  void _showInitialAccessibilityDialog() {
    speak('Vítejte v mluvící kalkulačce. Vyberte prosím režim usnadnění.');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Vítejte'),
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'VYBERTE REŽIM USNADNĚNÍ', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  autofocus: true,
                  onPressed: () { 
                    setState(() { _accessibilityType = AccessibilityType.blind; ttsEnabled = true; }); 
                    _saveSettings(); 
                    Navigator.pop(context);
                    // ✅ OPRAVA: Zpoždění před speak() - dialog se musí zavřít
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) speak('Režim pro nevidomé nastaven.'); 
                    });
                  }, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 70), textStyle: const TextStyle(fontSize: 20)),
                  child: const Text('1. PRO NEVIDOMÉ')
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () { 
                    setState(() { _accessibilityType = AccessibilityType.visuallyImpaired; _fontSizeMultiplier = 1.5; ttsEnabled = true; }); 
                    _saveSettings(); 
                    Navigator.pop(context);
                    // ✅ OPRAVA: Zpoždění před speak() - dialog se musí zavřít
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) speak('Režim pro slabozraké nastaven.'); 
                    });
                  }, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 70), textStyle: const TextStyle(fontSize: 20)),
                  child: const Text('2. PRO SLABOZRAKÉ')
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () { 
                    setState(() => _accessibilityType = AccessibilityType.none); 
                    _saveSettings(); 
                    Navigator.pop(context);
                    // ✅ OPRAVA: Zpoždění před speak() - dialog se musí zavřít
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) speak('Standardní režim nastaven.'); 
                    });
                  }, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 70), textStyle: const TextStyle(fontSize: 20)),
                  child: const Text('3. STANDARDNÍ')
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (builderContext, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nastavení usnadnění',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        label: 'Výběr režimu usnadnění',
                        child: Text(
                          'Režim usnadnění',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      RadioListTile<AccessibilityType>(
                        autofocus: true,
                        title: const Text('Standard'),
                        subtitle: const Text('Běžné zobrazení'),
                        value: AccessibilityType.none,
                        groupValue: _accessibilityType,
                        onChanged: (value) {
                          setState(() => _accessibilityType = value ?? AccessibilityType.none);
                          setDialogState(() {});
                          _saveSettings();
                          speak('Nastaven standardní režim');
                        },
                      ),
                      RadioListTile<AccessibilityType>(
                        title: const Text('Nevidomý'),
                        subtitle: const Text('Hlasový výstup, standardní písmo'),
                        value: AccessibilityType.blind,
                        groupValue: _accessibilityType,
                        onChanged: (value) {
                          setState(() {
                            _accessibilityType = value ?? AccessibilityType.blind;
                            ttsEnabled = true;
                            _speechVolume = 1.0;
                            _fontSizeMultiplier = 1.0;
                          });
                          setDialogState(() {});
                          _saveSettings();
                          speak('Nastaven režim pro nevidomé');
                        },
                      ),
                      RadioListTile<AccessibilityType>(
                        title: const Text('Slabozraký'),
                        subtitle: const Text('Hlasový výstup a velké písmo'),
                        value: AccessibilityType.visuallyImpaired,
                        groupValue: _accessibilityType,
                        onChanged: (value) {
                          setState(() {
                            _accessibilityType = value ?? AccessibilityType.visuallyImpaired;
                            _fontSizeMultiplier = 1.8;
                            ttsEnabled = true;
                          });
                          setDialogState(() {});
                          _saveSettings();
                          speak('Nastaven režim pro slabozraké, písmo zvětšeno na 180 procent');
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Posuvník pro velikost písma a tlačítek. Aktuálně ${(_fontSizeMultiplier * 100).toInt()} procent',
                        child: Text(
                          'Velikost textu a tlačítek',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Slider(
                        value: _fontSizeMultiplier,
                        min: 0.8,
                        max: 3.0,
                        divisions: 22,
                        label: '${(_fontSizeMultiplier * 100).toInt()}%',
                        onChanged: (val) {
                          setState(() => _fontSizeMultiplier = val);
                          setDialogState(() {});
                        },
                        onChangeEnd: (val) {
                          _saveSettings();
                          speak('Velikost nastavena na ${(val * 100).toInt()} procent');
                        },
                      ),
                      Center(
                        child: Text(
                          '${(_fontSizeMultiplier * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Posuvník pro rychlost hlasu. Aktuálně ${(_speechRate * 100).toInt()} procent',
                        child: Text(
                          'Rychlost hlasu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Slider(
                        value: _speechRate,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: '${(_speechRate * 100).toInt()}%',
                        onChanged: (val) {
                          setState(() => _speechRate = val);
                          setDialogState(() {});
                        },
                        onChangeEnd: (val) {
                          _saveSettings();
                          speak('Rychlost nastavena na ${(val * 100).toInt()} procent');
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Posuvník pro hlasitost hlasu. Aktuálně ${(_speechVolume * 100).toInt()} procent',
                        child: Text(
                          'Hlasitost hlasu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Slider(
                        value: _speechVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(_speechVolume * 100).toInt()}%',
                        onChanged: (val) {
                          setState(() => _speechVolume = val);
                          setDialogState(() {});
                        },
                        onChangeEnd: (val) {
                          _saveSettings();
                          speak('Hlasitost nastavena na ${(val * 100).toInt()} procent');
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Hlas kalkulačky'),
                        subtitle: Text(ttsEnabled ? 'Zapnuto' : 'Vypnuto'),
                        value: ttsEnabled,
                        onChanged: (val) {
                          setState(() => ttsEnabled = val);
                          setDialogState(() {});
                          _saveSettings();
                          speak(val ? 'Hlas zapnut' : 'Hlas vypnut');
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Výsledky v DMS'),
                        subtitle: const Text('Stupně, minuty a vteřiny u inverzních funkcí'),
                        value: _preferDMSForInverse ?? false,
                        onChanged: (val) {
                          setState(() => _preferDMSForInverse = val);
                          setDialogState(() {});
                          _saveSettings();
                          speak(val ? 'Výsledky budou v minutách' : 'Výsledky budou v desítkových stupních');
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('HOTOVO'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showTutorialDialog() {
    speak('Otevírám nápovědu');
    const String title = 'Jak používat kalkulačku';
    const String tutorialText = '• Režimy: Přepínejte mezi základní, vědeckou a elektro kalkulačkou v horním menu.\n\n'
        '• Paměť: Tlačítko STO aktivuje režim ukládání. Poté stiskněte písmeno paměti (A-M).\n\n'
        '• Historie: Poslední výpočty najdete v sekci Historie pod displejem.\n\n'
        '• Usnadnění: Upravte velikost písma a hlas v menu pod ikonou panáčka vpravo nahoře.';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    tutorialText,
                    style: TextStyle(fontSize: 16),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      autofocus: true,
                      onPressed: () {
                        debugPrint('📤 Zavírám nápovědu');
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'ROZUMÍM',
                        semanticsLabel: '$title. $tutorialText. Rozumím',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  void backspace() { if (display.isNotEmpty) { setState(() => display = display.substring(0, display.length - 1)); speak('Smazáno'); } }
  void clear() { setState(() { display = ''; _isStoreMode = false; }); speak('Vymazat'); }
  void append(String value) { setState(() => display += value); speak(_buttonNames[value] ?? value); }

  String _toDMS(double decimalDegrees) {
    int d = decimalDegrees.abs().floor();
    double minFloating = (decimalDegrees.abs() - d) * 60;
    int m = minFloating.floor();
    double secFloating = (minFloating - m) * 60;
    int s = secFloating.round();

    if (s == 60) { m++; s = 0; }
    if (m == 60) { d++; m = 0; }
    
    String sign = decimalDegrees < 0 ? '-' : '';
    return '$sign$d° $m\' $s"';
  }

  double _fromDMS(String dmsStr) {
    // Očekává formát např. 30° 15' 10"
    final regex = RegExp(r'''(-?\d+)°\s*(\d+)'\s*(\d+)"''');
    final match = regex.firstMatch(dmsStr);
    if (match != null) {
      double d = double.parse(match.group(1)!);
      double m = double.parse(match.group(2)!);
      double s = double.parse(match.group(3)!);
      double result = d.abs() + (m / 60.0) + (s / 3600.0);
      return d < 0 ? -result : result;
    }
    return double.nan;
  }

  void _showDmsPreferenceDialog(VoidCallback onComplete) {
    speak('Vyberte, jak chcete zobrazovat výsledky inverzních funkcí.');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Nastavení výsledků'),
        content: const Text('U funkcí jako Arkus Sinus (ASIN) chcete výsledek v desítkových stupních (např. 30.5°) nebo ve stupních a minutách (30° 30\')?'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _preferDMSForInverse = false);
              _saveSettings();
              Navigator.pop(context);
              onComplete();
            },
            child: const Text('STUPNĚ'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _preferDMSForInverse = true);
              _saveSettings();
              Navigator.pop(context);
              onComplete();
            },
            child: const Text('DMS (STUPNĚ A MINUTY)'),
          ),
        ],
      ),
    );
  }

  void calculateResult() {
    try {
      if (display.isEmpty) return;

      // Kontrola, zda je potřeba se zeptat na DMS
      bool isInverseTrig = display.contains('ASIN') || display.contains('ACOS') || display.contains('ATAN');
      if (isInverseTrig && _preferDMSForInverse == null && _isDegreeMode) {
        _showDmsPreferenceDialog(calculateResult);
        return;
      }

      double result = _evaluateExpression(display);
      String resStr;
      
      if (isInverseTrig && _preferDMSForInverse == true && _isDegreeMode) {
        resStr = _toDMS(result);
      } else {
        resStr = _formatNumber(result);
      }

      setState(() { 
        _lastResult = _formatNumber(result); // Do paměti vždy číslo
        display = resStr; 
      });
      
      speak('Výsledek je ${resStr.replaceAll('.', ',')}');
      _addToHistory(display, resStr);
    } catch (e) { 
      speak('Chyba ve výrazu'); 
      debugPrint('Chyba výpočtu: $e');
    }
  }

  double _evaluateExpression(String expr) {
    String processed = expr.replaceAll(',', '.');
    processed = processed.replaceAll('x²', '^2');
    processed = processed.replaceAll('x³', '^3');
    processed = processed.replaceAll('(-)', '-');
    
    // Elektro prefixy a jednotky
    processed = processed.replaceAll('μ', '*10^-6');
    processed = processed.replaceAll('n', '*10^-9');
    processed = processed.replaceAll('p', '*10^-12');
    processed = processed.replaceAll('Hz', '');

    // Ohmův zákon a Výkon (musí být před goniometrií kvůli názvům)
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)OHM_R'), (m) => '((${m[1]})/(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)OHM_V'), (m) => '((${m[1]})*(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)OHM_I'), (m) => '((${m[1]})/(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)PWR_P'), (m) => '((${m[1]})*(${m[2]}))');

    // Paralelní a sériové řazení
    processed = processed.replaceAllMapped(RegExp(r'([^;]+(?:;[^;]+)+)PAR'), (m) {
      List<String> parts = m[1]!.split(';');
      return '1/(${parts.map((p) => "1/($p)").join("+")})';
    });
    processed = processed.replaceAllMapped(RegExp(r'([^;]+(?:;[^;]+)+)SER'), (m) {
      List<String> parts = m[1]!.split(';');
      return '(${parts.join("+")})';
    });

    // Reaktivance (XL = 2*pi*f*L, XC = 1/(2*pi*f*C))
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)XL'), (m) => '(2*3.14159265*(${m[1]})*(${m[2]}))');
    processed = processed.replaceAllMapped(RegExp(r'([^;]+);([^;]+)XC'), (m) => '(1/(2*3.14159265*(${m[1]})*(${m[2]})))');

    // Zpracování enté odmocniny n√x na x^(1/n)
    processed = processed.replaceAllMapped(RegExp(r'(\d+(\.\d+)?)ⁿ√(\d+(\.\d+)?)'), (m) {
      return '(${m[3]}^(1/${m[1]}))';
    });

    // Odmocniny
    processed = processed.replaceAll('√(', 'sqrt(');
    processed = processed.replaceAllMapped(RegExp(r'∛\(([^)]+)\)'), (m) => '((${m[1]})^(1/3))');

    processed = processed.replaceAll('E', '*10^');
    processed = processed.replaceAll('ABS(', 'abs(');
    
    double degToRad = _isDegreeMode ? math.pi / 180.0 : 1.0;
    double radToDeg = _isDegreeMode ? 180.0 / math.pi : 1.0;

    // Goniometrie
    if (_isDegreeMode) {
      processed = processed.replaceAll('SIN(', 'sin($degToRad*');
      processed = processed.replaceAll('COS(', 'cos($degToRad*');
      processed = processed.replaceAll('TAN(', 'tan($degToRad*');
      
      int openInverse = 0;
      processed = processed.replaceAllMapped(RegExp(r'A(SIN|COS|TAN)\('), (m) {
        openInverse++;
        String func = m[1]!.toLowerCase(); // sin, cos, tan
        return '($radToDeg*a$func(';
      });
      processed += ')' * openInverse;
    } else {
      processed = processed.replaceAll('SIN(', 'sin(');
      processed = processed.replaceAll('COS(', 'cos(');
      processed = processed.replaceAll('TAN(', 'tan(');
      processed = processed.replaceAll('ASIN(', 'asin(');
      processed = processed.replaceAll('ACOS(', 'acos(');
      processed = processed.replaceAll('ATAN(', 'atan(');
    }

    _memory.forEach((key, value) => processed = processed.replaceAll(RegExp('\\b$key\\b'), '($value)'));
    processed = processed.replaceAll(RegExp(r'\bANS\b'), '($_lastResult)');

    processed = processed.replaceAll(' ', '');

    // Automatické uzavření závorek
    int openParentheses = '('.allMatches(processed).length;
    int closeParentheses = ')'.allMatches(processed).length;
    if (openParentheses > closeParentheses) {
      processed += ')' * (openParentheses - closeParentheses);
    }

    math_expr.Parser p = math_expr.Parser();
    math_expr.Expression exp = p.parse(processed);
    return exp.evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return value.toString();
    if (_preferExponential) return value.toStringAsExponential(4);
    if (value == value.toInt().toDouble()) return value.toInt().toString();
    return value.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWindows = Theme.of(context).platform == TargetPlatform.windows;
    final double maxContentWidth = screenWidth > 900 ? 600 : double.infinity;

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
          )
        ]
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    alignment: Alignment.bottomRight,
                    child: Semantics(
                      liveRegion: true,
                      container: isWindows,
                      label: 'Displej, obsah je $display',
                      child: SelectableText(display, textAlign: TextAlign.right, style: TextStyle(fontSize: 38 * _fontSizeMultiplier, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                _buildModeSelector(),
                _buildMemoryBar(),
                const Divider(height: 1),
                Expanded(
                  flex: 10,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (_currentMode == CalculatorMode.scientific) ...[
                        _buildCollapsibleSection(key: const ValueKey('gonio'), title: 'Goniometrie', icon: Icons.architecture, isExpanded: _isGonioExpanded, onExpansionChanged: (val) => setState(() => _isGonioExpanded = val), buttons: ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '°→\'', '\'→°'], crossAxisCount: 4),
                        _buildCollapsibleSection(key: const ValueKey('scientific'), title: 'Vědecké funkce', icon: Icons.functions, isExpanded: _isMemoryExpanded, onExpansionChanged: (val) => setState(() => _isMemoryExpanded = val), buttons: ['STO', 'RCL', 'ABS', '^', '√', 'x²', 'x³', '∛', 'ⁿ√', 'EXP'], crossAxisCount: 4),
                      ],
                      if (_currentMode == CalculatorMode.electrician) ...[
                        _buildCollapsibleSection(key: const ValueKey('electrician'), title: 'Elektro výpočty', icon: Icons.bolt, isExpanded: _isElectricianExpanded, onExpansionChanged: (val) => setState(() => _isElectricianExpanded = val), buttons: ['OHM_V', 'OHM_I', 'OHM_R', 'PWR_P', 'PAR', 'SER', 'XL', 'XC', 'Hz', 'μ', 'n', 'p', ';'], crossAxisCount: 4),
                      ],
                      _buildHistorySection(),
                      _buildMainKeyboard(),
                      Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: buildButton('DEL', height: 55, color: Colors.redAccent)), const SizedBox(width: 8), Expanded(child: buildButton('=', height: 55, color: Colors.green))])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(height: 60, color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), child: ListView(scrollDirection: Axis.horizontal, children: [
      _buildModeButton('Základní', CalculatorMode.basic, Icons.calculate),
      _buildModeButton('Vědecká', CalculatorMode.scientific, Icons.science),
      _buildModeButton('Statistika', CalculatorMode.statistics, Icons.bar_chart),
      _buildModeButton('Elektro', CalculatorMode.electrician, Icons.bolt),
    ]));
  }

  Widget _buildModeButton(String label, CalculatorMode mode, IconData icon) {
    bool isSel = _currentMode == mode;
    final semanticLabel = 'Režim $label';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4), 
      child: ElevatedButton.icon(
        onPressed: () => _changeMode(mode), 
        icon: Icon(icon, size: 18), 
        label: Text(label, semanticsLabel: semanticLabel), 
        style: ElevatedButton.styleFrom(backgroundColor: isSel ? Theme.of(context).colorScheme.primary : null, foregroundColor: isSel ? Colors.white : null),
        onFocusChange: (f) { if (f) speak(semanticLabel); },
      )
    );
  }

  Widget _buildMemoryBar() {
    return Container(height: 55, color: Colors.grey.withOpacity(0.1), child: ListView(scrollDirection: Axis.horizontal, children: [
      Padding(
        padding: const EdgeInsets.all(4), 
        child: ElevatedButton(
          onPressed: _toggleAngleMode, 
          onFocusChange: (f) { if (f) speak(_isDegreeMode ? 'Stupně' : 'Radiány'); },
          child: Text(_isDegreeMode ? 'DEG' : 'RAD', semanticsLabel: _isDegreeMode ? 'Aktuálně stupně, přepnout na radiány' : 'Aktuálně radiány, přepnout na stupně'),
        )
      ),
      ..._memory.keys.map((k) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2), 
        child: OutlinedButton(
          onPressed: () { if (_isStoreMode) { setState(() { _memory[k] = double.tryParse(display) ?? 0; _isStoreMode = false; }); speak('Uloženo do $k'); } else { append(k); } }, 
          onFocusChange: (f) { if (f) speak('Paměť $k'); },
          child: Text(k, semanticsLabel: 'Paměť $k, hodnota ${_memory[k]}'),
        )
      )).toList(),
      IconButton(
        icon: const Icon(Icons.delete_sweep, color: Colors.red), 
        onPressed: () { setState(() => _memory.updateAll((k, v) => 0)); speak('Paměť smazána'); },
        tooltip: 'Smazat celou paměť',
      ),
    ]));
  }

  Widget _buildMainKeyboard() {
    List<String> btns = ['C', '(', ')', '/', '7', '8', '9', '*', '4', '5', '6', '-', '1', '2', '3', '+', '(-)', '0', '.', 'ANS'];
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, padding: const EdgeInsets.all(10), mainAxisSpacing: 8, crossAxisSpacing: 8, children: btns.map((b) => buildButton(b, color: (b == 'C' ? Colors.orange : (['/', '*', '-', '+'].contains(b) ? Colors.blue : null)))).toList());
  }

  Widget _buildHistorySection() {
    return ExpansionTile(
      leading: const Icon(Icons.history), 
      title: const Text('Historie'), 
      children: _history.map((h) => Material(
        child: ListTile(
          title: Text(h), 
          onTap: () {
            setState(() => display = h.split(' = ')[0]);
            speak('Načteno z historie: ${h.split(' = ')[0]}');
          }
        ),
      )).toList()
    );
  }

  Widget _buildCollapsibleSection({required Key key, required String title, required IconData icon, required List<String> buttons, required int crossAxisCount, required bool isExpanded, required Function(bool) onExpansionChanged}) {
    return ExpansionTile(key: key, leading: Icon(icon), title: Text(title), initiallyExpanded: isExpanded, onExpansionChanged: onExpansionChanged, children: [GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: crossAxisCount, padding: const EdgeInsets.all(8), mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.0, children: buttons.map((b) => buildButton(b)).toList())]);
  }

  void _handleButtonPressed(String label) {
    if (label == 'C') clear();
    else if (label == 'DEL') backspace();
    else if (label == '=') calculateResult();
    else if (label == 'STO') { setState(() => _isStoreMode = !_isStoreMode); speak(_isStoreMode ? 'Vyberte paměť' : 'Zrušeno'); }
    else if (label == 'PAR' || label == 'SER') {
      if (display.isNotEmpty && !display.endsWith(';')) setState(() => display += ';');
      append(label);
    }
    else if (['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', '√', '∛', 'ABS'].contains(label)) {
      setState(() => display += '$label(');
      speak(_buttonNames[label] ?? label);
    }
    else if (label == 'EXP') {
      setState(() => display += 'E');
      speak('krát deset na');
    }
    else append(label);
  }

  Widget buildButton(String label, {double? height, Color? color}) {
    final semanticLabel = _buttonNames[label] ?? label;
    // Základní výška tlačítka se škáluje s multiplikátorem
    final double adjustedHeight = (height ?? 65) * (_fontSizeMultiplier > 1.0 ? (_fontSizeMultiplier * 0.8) : 1.0);
    
    return SizedBox(
      height: adjustedHeight, 
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          foregroundColor: color != null ? Colors.white : null, 
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        ),
        onPressed: () => _handleButtonPressed(label),
        onFocusChange: (f) { 
          if (f) {
            Future.delayed(const Duration(milliseconds: 100), () => speak(semanticLabel));
          }
        },
        child: Text(
          label, 
          semanticsLabel: semanticLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18 * _fontSizeMultiplier,
          )
        ),
      ),
    );
  }
}
