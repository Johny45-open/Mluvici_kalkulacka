part of 'main.dart';

class _DevModeDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _DevModeDialog({required this.parent});
  @override
  State<_DevModeDialog> createState() => _DevModeDialogState();
}

class _DevModeDialogState extends State<_DevModeDialog> {
  _CalculatorScreenState get parent => widget.parent;

  void _adjustDuration(int delta) {
    final newVal = (parent._devDiagnosticDurationMs + delta).clamp(200, 3000);
    parent.setState(() => parent._devDiagnosticDurationMs = newVal);
    parent._saveSettings();
    parent.speak(
      parent._s(
        'Délka zobrazení $newVal milisekund',
        'Display duration $newVal milliseconds',
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      semanticLabel: parent._s('Vývojářský režim', 'Developer mode'),
      title: Semantics(
        header: true,
        child: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.orange),
            const SizedBox(width: 8),
            Text(parent._s('Vývojářský režim', 'Developer mode')),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Build info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verze: ${parent._currentAppVersion}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Režim: ${parent._getModeName(parent._currentMode)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Platforma: ${Platform.operatingSystem}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Autodiagnostika při spuštění
            Semantics(
              label: parent._s(
                'Přepnout autodiagnostiku displejů při spuštění',
                'Toggle display autodiagnostics on startup',
              ),
              child: SwitchListTile(
                title: Text(
                  parent._s(
                    'Autodiagnostika při spuštění',
                    'Autodiagnostics on startup',
                  ),
                ),
                subtitle: Text(
                  parent._s(
                    'Zobrazí čísla 0 až 9 při startu',
                    'Shows numbers 0 to 9 on startup',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                value: parent._devAutoDiagnosticEnabled,
                onChanged: (v) {
                  parent.setState(() => parent._devAutoDiagnosticEnabled = v);
                  parent._saveSettings();
                  parent.speak(
                    v
                        ? parent._s('Autodiagnostika zapnuta', 'Autodiagnostics on')
                        : parent._s('Autodiagnostika vypnuta', 'Autodiagnostics off'),
                  );
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 8),
            // Délka zobrazení +/- jako v Nastavení přístupnosti
            Semantics(
              header: true,
              label: parent._s(
                'Ovládání délky zobrazení jednoho znaku',
                'Display duration controls',
              ),
              child: ExcludeSemantics(
                child: Text(
                  parent._s(
                    'Délka zobrazení jednoho znaku',
                    'Single character display duration',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: parent._s(
                    'Zmenšit délku zobrazení',
                    'Decrease display duration',
                  ),
                  button: true,
                  child: ElevatedButton(
                    onPressed: parent._devDiagnosticDurationMs > 200
                        ? () => _adjustDuration(-100)
                        : null,
                    child: const ExcludeSemantics(child: Text('-')),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    liveRegion: true,
                    label: parent._s(
                      'Hodnota délky: ${parent._devDiagnosticDurationMs} milisekund',
                      'Duration value: ${parent._devDiagnosticDurationMs} milliseconds',
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        '${parent._devDiagnosticDurationMs} ms',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  label: parent._s(
                    'Zvětšit délku zobrazení',
                    'Increase display duration',
                  ),
                  button: true,
                  child: ElevatedButton(
                    onPressed: parent._devDiagnosticDurationMs < 3000
                        ? () => _adjustDuration(100)
                        : null,
                    child: const ExcludeSemantics(child: Text('+')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              parent._s(
                'Rozsah 200 až 3000 ms, krok 100 ms',
                'Range 200 to 3000 ms, step 100 ms',
              ),
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            // Akční tlačítka
            Semantics(
              label: parent._s(
                'Spustit autodiagnostiku displejů, zobrazí čísla 0 až 9',
                'Run display autodiagnostics, shows numbers 0 to 9',
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.display_settings),
                label: Text(
                  parent._s(
                    'Spustit autodiagnostiku displejů (0–9)',
                    'Run display diagnostics (0–9)',
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (parent.mounted) parent._runDisplayDiagnostics();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: parent._s('Test hlasu', 'Voice test'),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.record_voice_over),
                label: Text(parent._s('Test hlasu', 'Voice test')),
                onPressed: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (parent.mounted) parent._showVoiceTestDialog();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: parent._s(
                'Zobrazit uložená data SharedPreferences',
                'Show stored SharedPreferences data',
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.storage),
                label: Text(parent._s('Zobrazit uložená data', 'Show stored data')),
                onPressed: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (parent.mounted) parent._showPrefsDumpDialog();
                  });
                },
              ),
            ),
            const Divider(height: 24),
            Semantics(
              label: parent._s('Změnit PIN', 'Change PIN'),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_reset),
                label: Text(parent._s('Změnit PIN', 'Change PIN')),
                onPressed: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (parent.mounted) parent._showDevPinChangeDialog();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: parent._s(
                'Deaktivovat vývojářský režim, vyžaduje PIN',
                'Deactivate developer mode, requires PIN',
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_open, color: Colors.red),
                label: Text(
                  parent._s('Deaktivovat vývojářský režim', 'Deactivate developer mode'),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (parent.mounted) parent._confirmDeactivateDevMode();
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            // Další dev nástroje
            Semantics(
              header: true,
              child: Text(
                parent._s('Další nástroje', 'More tools'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    parent._saveSettings();
                    parent.speak(parent._s('Nastavení uloženo', 'Settings saved'));
                    if (parent.mounted) {
                      parent._showAccessibleSnackBar(
                        parent._s('Nastavení uloženo', 'Settings saved'),
                        scaffoldContext: context,
                      );
                    }
                  },
                  child: Text(parent._s('Uložit', 'Save')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('modeQuestionAsked');
                    await prefs.remove('accessibilityType');
                    if (parent.mounted) {
                      parent._showAccessibleSnackBar(
                        parent._s('Onboarding resetován', 'Onboarding reset'),
                        scaffoldContext: context,
                      );
                    }
                    parent.speak(parent._s('Onboarding resetován', 'Onboarding reset'));
                  },
                  child: Text(parent._s('Reset onboarding', 'Reset onboarding')),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(parent._l10n.close),
        ),
      ],
    );
  }
}

class _DisplayDiagnosticsDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _DisplayDiagnosticsDialog({required this.parent});
  @override
  State<_DisplayDiagnosticsDialog> createState() =>
      _DisplayDiagnosticsDialogState();
}

class _DisplayDiagnosticsDialogState extends State<_DisplayDiagnosticsDialog> {
  _CalculatorScreenState get parent => widget.parent;
  int _currentIndex = 0;
  Timer? _timer;
  bool _paused = false;

  static const List<String> _sequence = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    ' ',
    '.',
    '-',
    '0.(3)',
    'Error',
  ];

  String get _currentValue => _sequence[_currentIndex];

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Oznámit první znak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speakCurrent();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: parent._devDiagnosticDurationMs),
      (_) => _next(),
    );
  }

  void _next() {
    if (_paused) return;
    if (!mounted) return;
    setState(() {
      if (_currentIndex < _sequence.length - 1) {
        _currentIndex++;
        _speakCurrent();
      } else {
        _timer?.cancel();
        parent.speak(
          parent._s(
            'Autodiagnostika dokončena',
            'Autodiagnostics finished',
          ),
          force: true,
        );
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  void _speakCurrent() {
    final v = _currentValue;
    String spoken;
    if (v == ' ') {
      spoken = parent._s('mezera', 'space');
    } else if (v == 'Error') {
      spoken = parent._s('Chyba', 'Error');
    } else if (v.contains('(')) {
      spoken = parent._spokenForDisplay(v);
    } else {
      spoken = v;
    }
    parent.speak(spoken, force: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = parent._responsiveScale(context);
    final displayValue = _currentValue == '0.(3)'
        ? parent._toBarNotation(_currentValue)
        : _currentValue;
    final normalized = parent._normalizeForSegmentDisplay(displayValue);

    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      semanticLabel: parent._s('Autodiagnostika displejů', 'Display diagnostics'),
      title: Semantics(
        header: true,
        child: Text(
          parent._s('Autodiagnostika displejů', 'Display diagnostics'),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              label: parent._s(
                'Test ${_currentIndex + 1} z ${_sequence.length}: $_currentValue',
                'Test ${_currentIndex + 1} of ${_sequence.length}: $_currentValue',
              ),
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text(
                      parent._s(
                        'Znak ${_currentIndex + 1} z ${_sequence.length}',
                        'Character ${_currentIndex + 1} of ${_sequence.length}',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_currentValue',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8 * s),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                children: [
                  // Horní řádek - dot matrix
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: CustomDotMatrixDisplay(
                      text: displayValue,
                      ledSize: 2.5 * s,
                      ledSpacing: 0.6 * s,
                      overlineThickness: parent._overlineThickness,
                    ),
                  ),
                  SizedBox(height: 8 * s),
                  // Dolní řádek - segment
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: CustomSegmentDisplay(
                      value: normalized,
                      size: 14 * s,
                      characterCount: 8,
                      isSixteenSegment: parent._useSixteenSegment,
                      overlineThickness: parent._overlineThickness,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _sequence.length,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  label: Text(
                    _paused
                        ? parent._s('Pokračovat', 'Resume')
                        : parent._s('Pozastavit', 'Pause'),
                  ),
                  onPressed: () {
                    setState(() => _paused = !_paused);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context);
                  },
                  child: Text(parent._s('Ukončit', 'Close')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceTestDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _VoiceTestDialog({required this.parent});
  @override
  State<_VoiceTestDialog> createState() => _VoiceTestDialogState();
}

class _VoiceTestDialogState extends State<_VoiceTestDialog> {
  _CalculatorScreenState get parent => widget.parent;

  void _speakSample(String lang) async {
    if (lang == 'cs') {
      await parent.tts.setLanguage('cs-CZ');
      parent.speak(
        'Toto je test hlasu. Čísla 0 1 2 3 4 5 6 7 8 9. Kalkulačka mluví česky.',
        force: true,
      );
    } else {
      await parent.tts.setLanguage('en-US');
      parent.speak(
        'This is a voice test. Numbers 0 1 2 3 4 5 6 7 8 9. Calculator speaks English.',
        force: true,
      );
    }
    // Vrátit jazyk zpět
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) parent._updateTtsLanguage();
    });
  }

  void _speakNumbers() {
    final text = List.generate(10, (i) => '$i').join(' ');
    parent.speak(text, force: true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      semanticLabel: parent._s('Test hlasu', 'Voice test'),
      title: Semantics(
        header: true,
        child: Text(parent._s('Test hlasu', 'Voice test')),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Engine: ${parent._ttsEngine ?? parent._s('Výchozí', 'Default')}',
                      style: const TextStyle(fontSize: 12)),
                  Text('Hlas: ${parent._ttsVoiceName ?? parent._s('Výchozí', 'Default')}',
                      style: const TextStyle(fontSize: 12)),
                  Text(
                    'Rychlost: ${(parent._speechRate * 100).toInt()} %',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Hlasitost: ${(parent._speechVolume * 100).toInt()} %',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'TTS zapnuto: ${parent.ttsEnabled ? parent._s('Ano', 'Yes') : parent._s('Ne', 'No')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Jazyk: ${parent._isEnglish() ? 'en-US' : 'cs-CZ'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.volume_up),
              label: Text(parent._s('Přečíst česky', 'Read in Czech')),
              onPressed: () => _speakSample('cs'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.volume_up),
              label: Text(parent._s('Read in English', 'Přečíst anglicky')),
              onPressed: () => _speakSample('en'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.numbers),
              label: Text(parent._s('Přečíst čísla 0–9', 'Read numbers 0–9')),
              onPressed: _speakNumbers,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings_voice),
              label: Text(parent._s('Nastavení hlasu', 'Voice settings')),
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (parent.mounted) parent._showTtsVoiceDialog();
                });
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.engineering),
              label: Text(parent._s('Nastavení enginu', 'Engine settings')),
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (parent.mounted) parent._showTtsEngineDialog();
                });
              },
            ),
            const SizedBox(height: 8),
            Semantics(
              label: parent._s(
                'Test přerušení: spustí dvě věty rychle po sobě, druhá má přerušit první',
                'Interruption test: plays two sentences quickly, second should interrupt first',
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cut),
                label: Text(parent._s('Test přerušení', 'Interruption test')),
                onPressed: () async {
                  parent.speak('První věta, která by měla být přerušena druhou větou.', force: true);
                  await Future.delayed(const Duration(milliseconds: 400));
                  parent.speak('Druhá věta přerušila první.', force: true);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(parent._l10n.close),
        ),
      ],
    );
  }
}

class _PrefsDumpDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _PrefsDumpDialog({required this.parent});
  @override
  State<_PrefsDumpDialog> createState() => _PrefsDumpDialogState();
}

class _PrefsDumpDialogState extends State<_PrefsDumpDialog> {
  _CalculatorScreenState get parent => widget.parent;
  bool _showRaw = false;
  late DialogSize _currentSize = parent._dialogSize;
  Map<String, Object?>? _data;

  final Map<String, Map<String, String>> _labels = {
    "isDegreeMode": {"cs": "Režim úhlů (DEG/RAD)", "en": "Angle mode"},
    "ttsEnabled": {"cs": "Hlasový výstup", "en": "Voice output"},
    "speechRate": {"cs": "Rychlost hlasu", "en": "Speech rate"},
    "speechVolume": {"cs": "Hlasitost", "en": "Volume"},
    "dotMatrixZoom": {"cs": "Zoom horního displeje", "en": "Upper display zoom"},
    "resultZoom": {"cs": "Zoom dolního displeje", "en": "Lower display zoom"},
    "overlineThickness": {"cs": "Tloušťka čárky periody", "en": "Repeating bar thickness"},
    "alignInputLeft": {"cs": "Zarovnání vstupu vlevo", "en": "Input alignment left"},
    "dialogFontScale": {"cs": "Velikost písma dialogů", "en": "Dialog font scale"},
    "usePeriodicNotation": {"cs": "Periodický zápis", "en": "Periodic notation"},
    "useSixteenSegment": {"cs": "16-segmentový displej", "en": "16-segment display"},
    "announceExpression": {"cs": "Oznamování příkladu", "en": "Announce expression"},
    "accessibilityType": {"cs": "Typ usnadnění", "en": "Accessibility type"},
    "defaultMode": {"cs": "Výchozí režim", "en": "Default mode"},
    "screenReaderModeState": {"cs": "Režim čtečky", "en": "Screen reader mode"},
    "devModeEnabled": {"cs": "Vývojářský režim", "en": "Developer mode"},
    "devAutoDiagnosticEnabled": {"cs": "Autodiagnostika při startu", "en": "Autodiagnostics on startup"},
    "devDiagnosticDurationMs": {"cs": "Délka diagnostiky (ms)", "en": "Diagnostics duration (ms)"},
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, Object?>{};
    for (final k in prefs.getKeys()) {
      if (k == 'devPinCode') {
        map[k] = '****';
      } else {
        map[k] = prefs.get(k);
      }
    }
    if (mounted) setState(() => _data = map);
  }

  String _labelFor(String k) => _labels[k]?[parent._isEnglish() ? "en" : "cs"] ?? k;

  String _spokenValue(String k, Object? v) {
    if (v == null) return parent._s('prázdné', 'empty');
    if (v is bool) return v ? parent._s('Zapnuto', 'On') : parent._s('Vypnuto', 'Off');
    if (v is List) return parent._s('${v.length} položek', '${v.length} items');
    return v.toString();
  }

  String _buildSummary() {
    if (_data == null) return '';
    final buffer = StringBuffer(parent._s('Uložená data. Celkem ', 'Stored data. Total '));
    buffer.write('${_data!.length} položek. ');
    for (final entry in _data!.entries) {
      buffer.write('${_labelFor(entry.key)}: ${_spokenValue(entry.key, entry.value)}. ');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return AlertDialog(
        content: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final keys = _data!.keys.toList()..sort();
    final summary = _buildSummary();

    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      title: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Text(parent._s('Uložená data', 'Stored data'))),
            IconButton(
              icon: Icon(_currentSize == DialogSize.fullscreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen),
              onPressed: () => setState(() => _currentSize =
                  _currentSize == DialogSize.fullscreen
                      ? DialogSize.compact
                      : DialogSize.fullscreen),
            ),
          ],
        ),
      ),
      content: parent._applyDialogSize(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text(parent._s('Zobrazit technické klíče', 'Show raw keys')),
              value: _showRaw,
              onChanged: (v) => setState(() => _showRaw = v),
            ),
            const Divider(),
            Expanded(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: summary,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: keys.length,
                  itemBuilder: (c, i) {
                    final k = keys[i];
                    final v = _data![k];
                    return Semantics(
                      container: true,
                      label: '${_labelFor(k)}: ${_spokenValue(k, v)}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_labelFor(k)}: ${v ?? 'null'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (_showRaw)
                              Text(
                                '($k)',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Semantics(
          label: parent._s('Přečíst vše', 'Read all'),
          child: FilledButton.icon(
            icon: const Icon(Icons.volume_up),
            label: Text(parent._s('Přečíst vše', 'Read all')),
            onPressed: () => parent.speak(summary, force: true),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(parent._l10n.close),
        ),
      ],
    );
  }
}

// PIN dialogs
enum _DevPinMode { create, verify, change }

class _DevPinDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  final _DevPinMode mode;
  final VoidCallback? onVerified;
  const _DevPinDialog({
    required this.parent,
    required this.mode,
    this.onVerified,
  });
  @override
  State<_DevPinDialog> createState() => _DevPinDialogState();
}

class _DevPinDialogState extends State<_DevPinDialog> {
  _CalculatorScreenState get parent => widget.parent;
  final _ctrl1 = TextEditingController();
  final _ctrl2 = TextEditingController();
  final _ctrlOld = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _obscureOld = true;
  String? _error;

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrlOld.dispose();
    super.dispose();
  }

  String _pinPatternError(String pin) {
    if (pin.length != 4) return parent._s('PIN musí mít 4 číslice', 'PIN must be 4 digits');
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return parent._s('PIN musí obsahovat pouze číslice', 'PIN must contain digits only');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final isCreate = mode == _DevPinMode.create;
    final isVerify = mode == _DevPinMode.verify;
    final isChange = mode == _DevPinMode.change;

    String title;
    if (isCreate) {
      title = parent._s('Nastavit PIN', 'Set PIN');
    } else if (isChange) {
      title = parent._s('Změnit PIN', 'Change PIN');
    } else {
      title = parent._s('Zadejte PIN', 'Enter PIN');
    }

    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      semanticLabel: title,
      title: Semantics(header: true, child: Text(title)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isChange) ...[
              Semantics(
                label: parent._s('Starý PIN', 'Old PIN'),
                child: TextField(
                  controller: _ctrlOld,
                  obscureText: _obscureOld,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: parent._s('Starý PIN', 'Old PIN'),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureOld ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureOld = !_obscureOld),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Semantics(
              label: isVerify
                  ? parent._s('PIN', 'PIN')
                  : parent._s('Nový PIN (4 číslice)', 'New PIN (4 digits)'),
              child: TextField(
                controller: _ctrl1,
                obscureText: _obscure1,
                keyboardType: TextInputType.number,
                maxLength: 4,
                autofocus: isChange ? false : true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: isVerify
                      ? parent._s('PIN', 'PIN')
                      : parent._s('Nový PIN (4 číslice)', 'New PIN (4 digits)'),
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
              ),
            ),
            if (!isVerify) ...[
              const SizedBox(height: 12),
              Semantics(
                label: parent._s('Potvrďte PIN', 'Confirm PIN'),
                child: TextField(
                  controller: _ctrl2,
                  obscureText: _obscure2,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: parent._s('Potvrďte PIN', 'Confirm PIN'),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
            if (parent._devPinLockUntil != null &&
                DateTime.now().isBefore(parent._devPinLockUntil!)) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  parent._s(
                    'Příliš mnoho pokusů. Zkuste za chvíli.',
                    'Too many attempts. Try again later.',
                  ),
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(parent._l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            // Lock check
            if (parent._devPinLockUntil != null &&
                DateTime.now().isBefore(parent._devPinLockUntil!)) {
              setState(() {
                _error = parent._s(
                  'Příliš mnoho pokusů. Zkuste za chvíli.',
                  'Too many attempts. Try again later.',
                );
              });
              return;
            }
            if (isCreate) {
              final pin1 = _ctrl1.text.trim();
              final pin2 = _ctrl2.text.trim();
              final err1 = _pinPatternError(pin1);
              if (err1.isNotEmpty) {
                setState(() => _error = err1);
                return;
              }
              if (pin1 != pin2) {
                setState(
                  () => _error = parent._s('PINy se neshodují', 'PINs do not match'),
                );
                return;
              }
              parent.setState(() => parent._devPinCode = pin1);
              parent._saveSettings();
              // Also enable dev mode
              parent.setState(() => parent._devModeEnabled = true);
              parent._saveSettings();
              Navigator.pop(context);
              parent.speak(parent._s('PIN nastaven. Vývojářský režim aktivován', 'PIN set. Developer mode activated'));
              if (parent.mounted) {
                parent._showAccessibleSnackBar(
                  parent._s('PIN nastaven', 'PIN set'),
                  scaffoldContext: parent.context,
                );
              }
              widget.onVerified?.call();
            } else if (isVerify) {
              final pin = _ctrl1.text.trim();
              if (pin != parent._devPinCode) {
                parent._devPinFails++;
                if (parent._devPinFails >= 5) {
                  parent._devPinLockUntil = DateTime.now().add(const Duration(seconds: 30));
                  parent._devPinFails = 0;
                }
                setState(
                  () => _error = parent._s('Nesprávný PIN', 'Incorrect PIN'),
                );
                return;
              }
              parent._devPinFails = 0;
              parent._devPinLockUntil = null;
              Navigator.pop(context);
              widget.onVerified?.call();
            } else if (isChange) {
              final oldPin = _ctrlOld.text.trim();
              final pin1 = _ctrl1.text.trim();
              final pin2 = _ctrl2.text.trim();
              if (oldPin != parent._devPinCode) {
                setState(() => _error = parent._s('Nesprávný starý PIN', 'Incorrect old PIN'));
                return;
              }
              final err1 = _pinPatternError(pin1);
              if (err1.isNotEmpty) {
                setState(() => _error = err1);
                return;
              }
              if (pin1 != pin2) {
                setState(() => _error = parent._s('PINy se neshodují', 'PINs do not match'));
                return;
              }
              parent.setState(() => parent._devPinCode = pin1);
              parent._saveSettings();
              Navigator.pop(context);
              parent.speak(parent._s('PIN změněn', 'PIN changed'));
              if (parent.mounted) {
                parent._showAccessibleSnackBar(
                  parent._s('PIN změněn', 'PIN changed'),
                  scaffoldContext: parent.context,
                );
              }
            }
          },
          child: Text(parent._l10n.confirmAction),
        ),
      ],
    );
  }
}
