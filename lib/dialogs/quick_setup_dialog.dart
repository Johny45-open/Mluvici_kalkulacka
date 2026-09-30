part of '../main.dart';

/// Jednotné přístupné „Rychlé nastavení kalkulačky".
///
/// Drží POUZE [QuickSetupDraft] – žádný duplicitní config model.
/// Každá změna upraví jen draft; persistence nastane až v `onApply`.
/// Bez sliderů: přepínače, segmented tlačítka, dropdowny, steppery ±.
/// Oznámení změn jedinou cestou přes [announce] (TTS XOR screen-reader).
class QuickSetupDialog extends StatefulWidget {
  final QuickSetupDraft initialDraft;
  final Future<List<Map<String, String>>> availableVoices;
  final ValueChanged<QuickSetupDraft> onApply;
  final VoidCallback onCancel;
  final void Function(String message) announce;
  final String Function(String cs, String en) tr;
  final bool isFirstRun;

  const QuickSetupDialog({
    super.key,
    required this.initialDraft,
    required this.availableVoices,
    required this.onApply,
    required this.onCancel,
    required this.announce,
    required this.tr,
    this.isFirstRun = false,
  });

  @override
  State<QuickSetupDialog> createState() => _QuickSetupDialogState();
}

class _QuickSetupDialogState extends State<QuickSetupDialog> {
  late QuickSetupDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
  }

  String _t(String cs, String en) => widget.tr(cs, en);

  void _update(QuickSetupDraft next, String announcement) {
    setState(() => _draft = next);
    if (announcement.isNotEmpty) widget.announce(announcement);
  }

  void _updateSettings(
    AccessibilitySettings Function(AccessibilitySettings s) upd,
    String announcement,
  ) {
    _update(_draft.copyWith(settings: upd(_draft.settings)), announcement);
  }

  // --- Stepper řádek (− / hodnota / +), stejný vzor jako editor profilu.
  Widget _stepperRow({
    required String label,
    required String valueText,
    required String minusSemantics,
    required String plusSemantics,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Semantics(
            label: minusSemantics,
            button: true,
            child: IconButton(
              icon: const Icon(Icons.remove),
              onPressed: onMinus,
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(valueText),
          ),
          Semantics(
            label: plusSemantics,
            button: true,
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: onPlus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _draft.settings;
    return AlertDialog(
      title: Semantics(
        header: true,
        child: Text(_t('Rychlé nastavení kalkulačky', 'Quick calculator setup')),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle(_t('Předvolba', 'Preset')),
                Semantics(
                  label: _t('Předvolba nastavení', 'Settings preset'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<QuickSetupPreset>(
                    segments: [
                      ButtonSegment(
                        value: QuickSetupPreset.standard,
                        label: Text(_t('Standardní', 'Standard')),
                      ),
                      ButtonSegment(
                        value: QuickSetupPreset.blind,
                        label: Text(_t('Nevidomý', 'Blind')),
                      ),
                      ButtonSegment(
                        value: QuickSetupPreset.lowVision,
                        label: Text(_t('Slabozraký', 'Low vision')),
                      ),
                      ButtonSegment(
                        value: QuickSetupPreset.custom,
                        label: Text(_t('Vlastní', 'Custom')),
                        enabled: _draft.detectedPreset ==
                            QuickSetupPreset.custom,
                      ),
                    ],
                    selected: {
                      _draft.detectedPreset == QuickSetupPreset.custom
                          ? QuickSetupPreset.custom
                          : _draft.detectedPreset,
                    },
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) {
                      final p = sel.first;
                      if (p == QuickSetupPreset.custom) return;
                      _update(
                        _draft.applyPreset(p),
                        _t('Předvolba: ${_presetName(p)}', 'Preset: ${_presetName(p)}'),
                      );
                    },
                  ),
                ),
                _sectionTitle(_t('Hlasový výstup (TTS)', 'Voice output (TTS)')),
                Semantics(
                  label: _t('Hlasový výstup zapnut nebo vypnut', 'Voice output on or off'),
                  child: SwitchListTile(
                    title: Text(_t('Hlas zapnut', 'Voice enabled')),
                    value: s.ttsEnabled,
                    onChanged: (v) => _updateSettings(
                      (x) => x.copyWith(ttsEnabled: v),
                      _t(
                        v ? 'Hlas zapnut' : 'Hlas vypnut',
                        v ? 'Voice on' : 'Voice off',
                      ),
                    ),
                  ),
                ),
                FutureBuilder<List<Map<String, String>>>(
                  future: widget.availableVoices,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return Semantics(
                        label: _t('Hlas: načítám dostupné hlasy', 'Voice: loading available voices'),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: _t('Hlas', 'Voice'),
                            hintText: _t('Načítám hlasy…', 'Loading voices…'),
                          ),
                          items: const [],
                          onChanged: null,
                        ),
                      );
                    }
                    final voices = snap.data!;
                    const defaultKey = '__default__';
                    final currentKey = s.ttsVoice == null
                        ? defaultKey
                        : '${s.ttsVoice!['name']}|${s.ttsVoice!['locale']}';
                    final keys = <String>{defaultKey};
                    for (final v in voices) {
                      keys.add('${v['name']}|${v['locale']}');
                    }
                    final effectiveKey =
                        keys.contains(currentKey) ? currentKey : defaultKey;
                    return Semantics(
                      label: _t('Výběr hlasu zařízení', 'Device voice selection'),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: _t('Hlas', 'Voice'),
                        ),
                        value: effectiveKey,
                        items: [
                          DropdownMenuItem(
                            value: defaultKey,
                            child: Text(_t('Výchozí hlas', 'Default voice')),
                          ),
                          for (final v in voices)
                            DropdownMenuItem(
                              value: '${v['name']}|${v['locale']}',
                              child: Text('${v['name']} (${v['locale']})'),
                            ),
                        ],
                        onChanged: (key) {
                          if (key == null || key == defaultKey) {
                            _updateSettings(
                              (x) => x.copyWith(
                                clearTtsVoice: true,
                                clearTtsVoiceName: true,
                              ),
                              _t('Výchozí hlas', 'Default voice'),
                            );
                          } else {
                            final v = voices.firstWhere(
                              (e) =>
                                  '${e['name']}|${e['locale']}' == key,
                              orElse: () => voices.first,
                            );
                            _updateSettings(
                              (x) => x.copyWith(
                                ttsVoice: {
                                  'name': v['name']!,
                                  'locale': v['locale']!,
                                },
                                ttsVoiceName: v['name'],
                              ),
                              _t('Hlas ${v['name']}', 'Voice ${v['name']}'),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
                _stepperRow(
                  label: _t('Rychlost', 'Speech rate'),
                  valueText: '${(s.speechRate * 100).toInt()} %',
                  minusSemantics: _t('Snížit rychlost', 'Decrease rate'),
                  plusSemantics: _t('Zvýšit rychlost', 'Increase rate'),
                  onMinus: () {
                    final nv = (s.speechRate - 0.1).clamp(0.1, 1.0);
                    _updateSettings(
                      (x) => x.copyWith(speechRate: nv),
                      _t('Rychlost ${(nv * 100).toInt()} procent', 'Rate ${(nv * 100).toInt()} percent'),
                    );
                  },
                  onPlus: () {
                    final nv = (s.speechRate + 0.1).clamp(0.1, 1.0);
                    _updateSettings(
                      (x) => x.copyWith(speechRate: nv),
                      _t('Rychlost ${(nv * 100).toInt()} procent', 'Rate ${(nv * 100).toInt()} percent'),
                    );
                  },
                ),
                _stepperRow(
                  label: _t('Hlasitost', 'Volume'),
                  valueText: '${(s.speechVolume * 100).toInt()} %',
                  minusSemantics: _t('Snížit hlasitost', 'Decrease volume'),
                  plusSemantics: _t('Zvýšit hlasitost', 'Increase volume'),
                  onMinus: () {
                    final nv = (s.speechVolume - 0.1).clamp(0.0, 1.0);
                    _updateSettings(
                      (x) => x.copyWith(speechVolume: nv),
                      _t('Hlasitost ${(nv * 100).toInt()} procent', 'Volume ${(nv * 100).toInt()} percent'),
                    );
                  },
                  onPlus: () {
                    final nv = (s.speechVolume + 0.1).clamp(0.0, 1.0);
                    _updateSettings(
                      (x) => x.copyWith(speechVolume: nv),
                      _t('Hlasitost ${(nv * 100).toInt()} procent', 'Volume ${(nv * 100).toInt()} percent'),
                    );
                  },
                ),
                _sectionTitle(_t('Přístupnost', 'Accessibility')),
                Semantics(
                  label: _t('Typ přístupnosti', 'Accessibility type'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<AccessibilityType>(
                    segments: [
                      ButtonSegment(
                        value: AccessibilityType.none,
                        label: Text(_t('Standardní', 'Standard')),
                      ),
                      ButtonSegment(
                        value: AccessibilityType.blind,
                        label: Text(_t('Nevidomý', 'Blind')),
                      ),
                      ButtonSegment(
                        value: AccessibilityType.visuallyImpaired,
                        label: Text(_t('Slabozraký', 'Low vision')),
                      ),
                    ],
                    selected: {s.accessibilityType},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => _updateSettings(
                      (x) => x.copyWith(accessibilityType: sel.first),
                      _t('Typ přístupnosti', 'Accessibility type'),
                    ),
                  ),
                ),
                Semantics(
                  label: _t('Režim čtečky obrazovky', 'Screen reader mode'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<ScreenReaderMode>(
                    segments: [
                      ButtonSegment(
                        value: ScreenReaderMode.auto,
                        label: Text(_t('Auto', 'Auto')),
                      ),
                      ButtonSegment(
                        value: ScreenReaderMode.on,
                        label: Text(_t('Zapnuto', 'On')),
                      ),
                      ButtonSegment(
                        value: ScreenReaderMode.off,
                        label: Text(_t('Vypnuto', 'Off')),
                      ),
                    ],
                    selected: {s.screenReaderMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => _updateSettings(
                      (x) => x.copyWith(screenReaderMode: sel.first),
                      _t('Režim čtečky', 'Screen reader mode'),
                    ),
                  ),
                ),
                _sectionTitle(_t('Písmo a zoom', 'Fonts and zoom')),
                _stepperRow(
                  label: _t('Písmo tlačítek', 'Button font'),
                  valueText: '${(s.fontSizeMultiplier * 100).toInt()} %',
                  minusSemantics: _t('Zmenšit písmo tlačítek', 'Decrease button font'),
                  plusSemantics: _t('Zvětšit písmo tlačítek', 'Increase button font'),
                  onMinus: () {
                    final nv =
                        (s.fontSizeMultiplier - 0.1).clamp(0.7, 2.5);
                    _updateSettings(
                      (x) => x.copyWith(fontSizeMultiplier: nv),
                      _t('Písmo tlačítek ${(nv * 100).toInt()} procent', 'Button font ${(nv * 100).toInt()} percent'),
                    );
                  },
                  onPlus: () {
                    final nv =
                        (s.fontSizeMultiplier + 0.1).clamp(0.7, 2.5);
                    _updateSettings(
                      (x) => x.copyWith(fontSizeMultiplier: nv),
                      _t('Písmo tlačítek ${(nv * 100).toInt()} procent', 'Button font ${(nv * 100).toInt()} percent'),
                    );
                  },
                ),
                _stepperRow(
                  label: _t('Písmo dialogů', 'Dialog font'),
                  valueText: '${(s.dialogFontScale * 100).toInt()} %',
                  minusSemantics: _t('Zmenšit písmo dialogů', 'Decrease dialog font'),
                  plusSemantics: _t('Zvětšit písmo dialogů', 'Increase dialog font'),
                  onMinus: () {
                    final nv = (s.dialogFontScale - 0.1).clamp(0.5, 5.0);
                    _updateSettings(
                      (x) => x.copyWith(dialogFontScale: nv),
                      _t('Písmo dialogů ${(nv * 100).toInt()} procent', 'Dialog font ${(nv * 100).toInt()} percent'),
                    );
                  },
                  onPlus: () {
                    final nv = (s.dialogFontScale + 0.1).clamp(0.5, 5.0);
                    _updateSettings(
                      (x) => x.copyWith(dialogFontScale: nv),
                      _t('Písmo dialogů ${(nv * 100).toInt()} procent', 'Dialog font ${(nv * 100).toInt()} percent'),
                    );
                  },
                ),
                _stepperRow(
                  label: _t('Zoom výsledku', 'Result zoom'),
                  valueText: '${(s.resultZoom * 100).toInt()} %',
                  minusSemantics: _t('Zmenšit výsledek', 'Decrease result zoom'),
                  plusSemantics: _t('Zvětšit výsledek', 'Increase result zoom'),
                  onMinus: () {
                    final nv = (s.resultZoom - 0.1).clamp(0.5, 5.0);
                    _updateSettings(
                      (x) => x.copyWith(resultZoom: nv),
                      _t('Zoom výsledku ${(nv * 100).toInt()} procent', 'Result zoom ${(nv * 100).toInt()} percent'),
                    );
                  },
                  onPlus: () {
                    final nv = (s.resultZoom + 0.1).clamp(0.5, 5.0);
                    _updateSettings(
                      (x) => x.copyWith(resultZoom: nv),
                      _t('Zoom výsledku ${(nv * 100).toInt()} procent', 'Result zoom ${(nv * 100).toInt()} percent'),
                    );
                  },
                ),
                Semantics(
                  label: _t('Velikost dialogů', 'Dialog size'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<DialogSize>(
                    segments: [
                      ButtonSegment(
                        value: DialogSize.compact,
                        label: Text(_t('Kompaktní', 'Compact')),
                      ),
                      ButtonSegment(
                        value: DialogSize.wide,
                        label: Text(_t('Široký', 'Wide')),
                      ),
                      ButtonSegment(
                        value: DialogSize.fullscreen,
                        label: Text(_t('Celý', 'Full')),
                      ),
                    ],
                    selected: {s.dialogSize},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => _updateSettings(
                      (x) => x.copyWith(dialogSize: sel.first),
                      _t('Velikost dialogů', 'Dialog size'),
                    ),
                  ),
                ),
                _sectionTitle(_t('Displeje', 'Displays')),
                Semantics(
                  label: _t('Šestnáctisegmentový displej', 'Sixteen-segment display'),
                  child: SwitchListTile(
                    title: Text(_t('16segmentový displej', '16-segment display')),
                    value: s.useSixteenSegment,
                    onChanged: (v) => _updateSettings(
                      (x) => x.copyWith(useSixteenSegment: v),
                      v ? _t('16segment zapnut', '16-segment on') : _t('16segment vypnut', '16-segment off'),
                    ),
                  ),
                ),
                Semantics(
                  label: _t('Periodický zápis', 'Repeating decimal notation'),
                  child: SwitchListTile(
                    title: Text(_t('Periodický zápis', 'Repeating notation')),
                    value: s.usePeriodicNotation,
                    onChanged: (v) => _updateSettings(
                      (x) => x.copyWith(usePeriodicNotation: v),
                      v ? _t('Periodický zápis zapnut', 'Repeating notation on') : _t('Periodický zápis vypnut', 'Repeating notation off'),
                    ),
                  ),
                ),
                Semantics(
                  label: _t('Formát inverzních funkcí', 'Inverse functions format'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<int?>(
                    segments: [
                      ButtonSegment<int?>(
                        value: null,
                        label: Text(_t('Auto', 'Auto')),
                      ),
                      ButtonSegment<int?>(
                        value: 0,
                        label: const Text('DMS'),
                      ),
                      ButtonSegment<int?>(
                        value: 1,
                        label: Text(_t('Desetinný', 'Decimal')),
                      ),
                    ],
                    selected: {s.inverseFormatPreference},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => _updateSettings(
                      (x) => x.copyWith(
                        inverseFormatPreference: sel.first,
                        clearInverseFormatPreference: sel.first == null,
                      ),
                      _t('Formát inverzních funkcí', 'Inverse format'),
                    ),
                  ),
                ),
                _sectionTitle(_t('Úhly', 'Angles')),
                Semantics(
                  label: _t('Režim úhlů', 'Angle mode'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(_t('Stupně', 'Degrees')),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(_t('Radiány', 'Radians')),
                      ),
                    ],
                    selected: {_draft.isDegreeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => _update(
                      _draft.copyWith(isDegreeMode: sel.first),
                      sel.first ? _t('Stupně', 'Degrees') : _t('Radiány', 'Radians'),
                    ),
                  ),
                ),
                _sectionTitle(_t('Výsledky', 'Results')),
                Semantics(
                  label: _t('Režim zobrazení výsledku, globální nastavení', 'Result display mode, global setting'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<ResultDisplayMode>(
                    segments: [
                      ButtonSegment(
                        value: ResultDisplayMode.segment,
                        label: Text(_t('Segment', 'Segment')),
                      ),
                      ButtonSegment(
                        value: ResultDisplayMode.text,
                        label: Text(_t('Text', 'Text')),
                      ),
                      ButtonSegment(
                        value: ResultDisplayMode.auto,
                        label: Text(_t('Auto', 'Auto')),
                      ),
                    ],
                    selected: {_draft.resultDisplayMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => _update(
                      _draft.copyWith(resultDisplayMode: sel.first),
                      _t('Zobrazení výsledku', 'Result display'),
                    ),
                  ),
                ),
                _sectionTitle(_t('Výchozí režim', 'Default mode')),
                Semantics(
                  label: _t('Výchozí režim kalkulačky', 'Default calculator mode'),
                  child: DropdownButtonFormField<CalculatorMode>(
                    decoration: InputDecoration(
                      labelText: _t('Výchozí režim', 'Default mode'),
                    ),
                    value: _draft.defaultMode,
                    items: [
                      for (final m in CalculatorMode.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text(_modeName(m)),
                        ),
                    ],
                    onChanged: (m) {
                      if (m == null) return;
                      _update(
                        _draft.copyWith(defaultMode: m),
                        _t('Výchozí režim ${_modeName(m)}', 'Default mode ${_modeName(m)}'),
                      );
                    },
                  ),
                ),
                _sectionTitle(_t('Téma', 'Theme')),
                Semantics(
                  label: _t('Barevné téma', 'Color theme'),
                  container: true,
                  explicitChildNodes: true,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(_t('Světlé', 'Light')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(_t('Tmavé', 'Dark')),
                      ),
                    ],
                    selected: {_draft.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => _update(
                      _draft.copyWith(themeMode: sel.first),
                      sel.first == ThemeMode.dark
                          ? _t('Tmavé téma', 'Dark theme')
                          : _t('Světlé téma', 'Light theme'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(_t('Storno', 'Cancel')),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => widget.onApply(_draft),
          child: Text(_t('Použít nastavení', 'Apply settings')),
        ),
      ],
    );
  }

  String _presetName(QuickSetupPreset p) {
    switch (p) {
      case QuickSetupPreset.standard:
        return _t('Standardní', 'Standard');
      case QuickSetupPreset.blind:
        return _t('Nevidomý', 'Blind');
      case QuickSetupPreset.lowVision:
        return _t('Slabozraký', 'Low vision');
      case QuickSetupPreset.custom:
        return _t('Vlastní', 'Custom');
    }
  }

  String _modeName(CalculatorMode m) {
    switch (m) {
      case CalculatorMode.basic:
        return _t('Základní', 'Basic');
      case CalculatorMode.scientific:
        return _t('Vědecká', 'Scientific');
      case CalculatorMode.statistics:
        return _t('Statistika', 'Statistics');
      case CalculatorMode.electrician:
        return _t('Elektrikář', 'Electrician');
      case CalculatorMode.unitConversion:
        return _t('Převody', 'Conversion');
      case CalculatorMode.time:
        return _t('Čas', 'Time');
      case CalculatorMode.currency:
        return _t('Měna', 'Currency');
    }
  }
}
