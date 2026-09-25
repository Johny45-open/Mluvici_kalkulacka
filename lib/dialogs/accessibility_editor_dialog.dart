part of '../main.dart';

class _AccessibilityProfileEditorDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _AccessibilityProfileEditorDialog({required this.parent});
  @override
  State<_AccessibilityProfileEditorDialog> createState() =>
      _AccessibilityProfileEditorDialogState();
}

class _AccessibilityProfileEditorDialogState
    extends State<_AccessibilityProfileEditorDialog> {
  _CalculatorScreenState get parent => widget.parent;
  AccessibilitySettings get editingSettings {
    final d = parent.editingProfile;
    assert(d != null, 'Editor invariant violated: _editingDraft is null');
    if (d == null) {
      // Fallback to active only for graceful degradation, but log
      debugPrint(
        '_AccessibilityProfileEditorDialog: editingProfile is null, using active',
      );
      return parent.activeAccessibilitySettings;
    }
    return d.settings;
  }

  bool get hasValidDraft =>
      parent.editingProfile != null && parent.editingProfileId != null;
  String get editingId {
    final id = parent.editingProfileId;
    assert(id != null, 'Editor invariant: editingProfileId is null');
    return id ?? parent._activeProfileId;
  }

  String get editingName {
    final d = parent.editingProfile;
    if (d != null) return parent._displayProfileName(d);
    return parent._displayProfileName(parent._getActiveAccessibilityProfile());
  }

  void _onUpdate(AccessibilitySettings Function(AccessibilitySettings) upd) {
    parent.updateEditingSettings(upd);
    setState(() {});
  }

  // Lidský název režimu vzhledu výsledkového displeje (použito pro label,
  // oznámení i souhrn změn — jeden zdroj, žádné duplicity).
  String _resultDisplayModeName(ResultDisplayMode m) {
    switch (m) {
      case ResultDisplayMode.segment:
        return parent._s('Segmentový', 'Segment');
      case ResultDisplayMode.text:
        return parent._s('Matematický text', 'Math text');
      case ResultDisplayMode.auto:
        return parent._s('Automatický', 'Automatic');
    }
  }

  void _setResultDisplayMode(ResultDisplayMode m) {
    _onUpdate((v) => v.copyWith(resultDisplayMode: m));
    parent.speak(
      parent._s(
        'Vzhled výsledku: ${_resultDisplayModeName(m)}',
        'Result display: ${_resultDisplayModeName(m)}',
      ),
      force: true,
    );
    setState(() {});
  }

  void _adjustDotMatrixZoom(double delta) {
    final nv = (editingSettings.dotMatrixZoom + delta).clamp(0.5, 5.0);
    _onUpdate((s) => s.copyWith(dotMatrixZoom: nv));
  }

  void _adjustResultZoom(double delta) {
    final nv = (editingSettings.resultZoom + delta).clamp(0.5, 5.0);
    _onUpdate((s) => s.copyWith(resultZoom: nv));
    setState(() {});
  }

  void _adjustSpeechRate(double delta) {
    final nv = (editingSettings.speechRate + delta).clamp(0.1, 1.0);
    _onUpdate((s) => s.copyWith(speechRate: nv));
    setState(() {});
    parent.speak(parent._l10n.speechRatePct((nv * 100).toInt()), force: true);
  }

  void _adjustSpeechVolume(double delta) {
    final nv = (editingSettings.speechVolume + delta).clamp(0.0, 1.0);
    _onUpdate((s) => s.copyWith(speechVolume: nv));
    setState(() {});
    parent.speak(parent._l10n.volumePct((nv * 100).toInt()), force: true);
  }

  void _adjustDialogFontScale(double delta) {
    final nv = (editingSettings.dialogFontScale + delta).clamp(0.5, 5.0);
    _onUpdate((s) => s.copyWith(dialogFontScale: nv));
    setState(() {});
    parent.speak(
      parent._s(
        'Velikost písma dialogů ${(nv * 100).toInt()} procent',
        'Dialog font size ${(nv * 100).toInt()} percent',
      ),
      force: true,
    );
  }

  void _adjustKeyboardFontScale(double delta) {
    final nv = (editingSettings.fontSizeMultiplier + delta).clamp(0.7, 2.5);
    _onUpdate((s) => s.copyWith(fontSizeMultiplier: nv));
    setState(() {});
    parent.speak(
      parent._s(
        'Velikost písma tlačítek ${(nv * 100).toInt()} procent',
        'Keyboard button font size ${(nv * 100).toInt()} percent',
      ),
      force: true,
    );
  }

  void _adjustOverlineHeight(double delta) {
    final nv = (editingSettings.overlineHeight + delta).clamp(0.5, 2.0);
    _onUpdate((s) => s.copyWith(overlineHeight: (nv as double)));
    setState(() {});
    parent.speak(
      parent._s(
        'Výška periodické čáry ${(nv * 100).toInt()} procent',
        'Repeating bar height ${(nv * 100).toInt()} percent',
      ),
      force: true,
    );
  }

  void _adjustOverlineThickness(double delta) {
    final nv = (editingSettings.overlineThickness + delta).clamp(0.8, 4.0);
    _onUpdate((s) => s.copyWith(overlineThickness: (nv as double)));
    setState(() {});
    parent.speak(
      parent._s(
        'Tloušťka periodické čáry ${(nv * 100).toInt()} procent',
        'Repeating bar thickness ${(nv * 100).toInt()} percent',
      ),
      force: true,
    );
  }

  void _resetOverlineStyle() {
    _onUpdate((s) => s.copyWith(overlineHeight: 1.0, overlineThickness: 1.0));
    setState(() {});
    parent.speak(
      parent._s(
        'Vzhled periodické čáry obnoven',
        'Repeating bar appearance reset',
      ),
      force: true,
    );
  }

  List<String> _collectChanges() {
    final draft = editingSettings;
    AccessibilitySettings? orig;
    if (parent._editingPreviewSnapshot != null) {
      orig = parent._editingPreviewSnapshot;
    } else {
      try {
        final idx = parent._profiles.indexWhere((p) => p.id == editingId);
        if (idx != -1) orig = parent._profiles[idx].settings;
      } catch (_) {}
    }
    if (orig == null)
      return [
        parent._s(
          'Změny v profilu $editingName',
          'Changes in profile $editingName',
        ),
      ];
    final out = <String>[];
    void add(String cs, String en, bool changed) {
      if (changed) out.add(parent._s(cs, en));
    }

    add(
      'Typ displeje: ${draft.useSixteenSegment ? '16-segment' : '7-segment'}',
      'Display type: ${draft.useSixteenSegment ? '16-segment' : '7-segment'}',
      draft.useSixteenSegment != orig.useSixteenSegment,
    );
    if (draft.resultDisplayMode != orig.resultDisplayMode) {
      out.add(
        parent._s(
          'Vzhled výsledku: ${_resultDisplayModeName(draft.resultDisplayMode)}',
          'Result display: ${_resultDisplayModeName(draft.resultDisplayMode)}',
        ),
      );
    }
    add(
      'Periodický zápis: ${draft.usePeriodicNotation ? 'Zapnuto' : 'Vypnuto'}',
      'Repeating notation: ${draft.usePeriodicNotation ? 'On' : 'Off'}',
      draft.usePeriodicNotation != orig.usePeriodicNotation,
    );
    add(
      'Hlasový výstup: ${draft.ttsEnabled ? 'Zapnuto' : 'Vypnuto'}',
      'Voice output: ${draft.ttsEnabled ? 'On' : 'Off'}',
      draft.ttsEnabled != orig.ttsEnabled,
    );
    add(
      'Oznamování příkladu: ${draft.announceExpression ? 'Zapnuto' : 'Vypnuto'}',
      'Announce expression: ${draft.announceExpression ? 'On' : 'Off'}',
      draft.announceExpression != orig.announceExpression,
    );
    add(
      'Auto-čtení souhrnu: ${draft.autoReadStatsSummary ? 'Zapnuto' : 'Vypnuto'}',
      'Auto-read summary: ${draft.autoReadStatsSummary ? 'On' : 'Off'}',
      draft.autoReadStatsSummary != orig.autoReadStatsSummary,
    );
    add(
      'Nápověda Tab: ${draft.showStatsNavigationHint ? 'Zapnuto' : 'Vypnuto'}',
      'Tab hint: ${draft.showStatsNavigationHint ? 'On' : 'Off'}',
      draft.showStatsNavigationHint != orig.showStatsNavigationHint,
    );
    if (draft.screenReaderMode != orig.screenReaderMode)
      out.add(
        parent._s(
          'Režim čtečky: ${draft.screenReaderMode.name}',
          'Screen reader: ${draft.screenReaderMode.name}',
        ),
      );
    if (draft.dialogSize != orig.dialogSize)
      out.add(
        parent._s(
          'Velikost dialogů: ${draft.dialogSize.name}',
          'Dialog size: ${draft.dialogSize.name}',
        ),
      );
    if ((draft.fontSizeMultiplier - orig.fontSizeMultiplier).abs() > 0.001)
      out.add(
        parent._s(
          'Písmo tlačítek: ${(draft.fontSizeMultiplier * 100).toInt()}%',
          'Button font: ${(draft.fontSizeMultiplier * 100).toInt()}%',
        ),
      );
    if ((draft.dialogFontScale - orig.dialogFontScale).abs() > 0.001)
      out.add(
        parent._s(
          'Písmo dialogů: ${(draft.dialogFontScale * 100).toInt()}%',
          'Dialog font: ${(draft.dialogFontScale * 100).toInt()}%',
        ),
      );
    if ((draft.dotMatrixZoom - orig.dotMatrixZoom).abs() > 0.001)
      out.add(
        parent._s(
          'Zoom horního displeje: ${(draft.dotMatrixZoom * 100).toInt()}%',
          'Upper zoom: ${(draft.dotMatrixZoom * 100).toInt()}%',
        ),
      );
    if ((draft.resultZoom - orig.resultZoom).abs() > 0.001)
      out.add(
        parent._s(
          'Zoom výsledku: ${(draft.resultZoom * 100).toInt()}%',
          'Result zoom: ${(draft.resultZoom * 100).toInt()}%',
        ),
      );
    if ((draft.speechRate - orig.speechRate).abs() > 0.001)
      out.add(
        parent._s(
          'Rychlost řeči: ${(draft.speechRate * 100).toInt()}%',
          'Speech rate: ${(draft.speechRate * 100).toInt()}%',
        ),
      );
    if ((draft.speechVolume - orig.speechVolume).abs() > 0.001)
      out.add(
        parent._s(
          'Hlasitost: ${(draft.speechVolume * 100).toInt()}%',
          'Volume: ${(draft.speechVolume * 100).toInt()}%',
        ),
      );
    if ((draft.overlineHeight - orig.overlineHeight).abs() > 0.001 ||
        (draft.overlineThickness - orig.overlineThickness).abs() > 0.001)
      out.add(
        parent._s(
          'Periodická čára: výška ${(draft.overlineHeight * 100).toInt()}% tloušťka ${(draft.overlineThickness * 100).toInt()}%',
          'Repeating bar: height ${(draft.overlineHeight * 100).toInt()}% thickness ${(draft.overlineThickness * 100).toInt()}%',
        ),
      );
    if (draft.thousandGroupGap != orig.thousandGroupGap)
      out.add(
        parent._s(
          'Mezera skupin: ${draft.thousandGroupGap.name}',
          'Group gap: ${draft.thousandGroupGap.name}',
        ),
      );
    if (draft.alignInputLeft != orig.alignInputLeft)
      out.add(
        parent._s(
          'Zarovnání vstupu: ${draft.alignInputLeft ? 'vlevo' : 'střed'}',
          'Input align: ${draft.alignInputLeft ? 'left' : 'center'}',
        ),
      );
    if (draft.accessibilityType != orig.accessibilityType)
      out.add(
        parent._s(
          'Typ přístupnosti: ${draft.accessibilityType.name}',
          'Accessibility: ${draft.accessibilityType.name}',
        ),
      );
    if (draft.ttsEngine != orig.ttsEngine)
      out.add(
        parent._s(
          'Engine: ${draft.ttsEngine ?? 'Výchozí'}',
          'Engine: ${draft.ttsEngine ?? 'Default'}',
        ),
      );
    if (draft.ttsVoiceName != orig.ttsVoiceName)
      out.add(
        parent._s(
          'Hlas: ${draft.ttsVoiceName ?? 'Výchozí'}',
          'Voice: ${draft.ttsVoiceName ?? 'Default'}',
        ),
      );
    if (draft.inverseFormatPreference != orig.inverseFormatPreference)
      out.add(
        parent._s(
          'Formát úhlů: ${draft.inverseFormatPreference == 0 ? 'DMS' : 'Desetinné'}',
          'Angle format: ${draft.inverseFormatPreference == 0 ? 'DMS' : 'Decimal'}',
        ),
      );
    if (out.isEmpty) out.add(parent._s('Žádné změny', 'No changes'));
    return out;
  }

  Future<void> _confirmAndSave() async {
    final changes = _collectChanges();
    final isNoChange =
        changes.length == 1 &&
        (changes.first.contains('Žádné změny') ||
            changes.first.contains('No changes'));
    final summary = changes.join('; ');
    final spoken = parent._s(
      'Potvrdit uložení profilu $editingName. Změny: $summary',
      'Confirm saving profile $editingName. Changes: $summary',
    );
    final confirmed = await parent.showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      routeSettings: RouteSettings(name: 'Potvrdit uložení $editingName'),
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          parent.speak(spoken, force: true);
          parent._announce(spoken, ctx);
        });
        return AlertDialog(
          insetPadding: parent._dialogInsetPadding(),
          title: Semantics(
            header: true,
            child: Text(parent._s('Potvrdit uložení', 'Confirm save')),
          ),
          content: SingleChildScrollView(
            child: Semantics(
              liveRegion: true,
              label: spoken,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parent._s('Profil: $editingName', 'Profile: $editingName'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (isNoChange)
                    Text(
                      changes.first,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    )
                  else
                    ...changes.map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(c)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    parent._s('Uložit změny?', 'Save changes?'),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(parent._l10n.cancel),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(parent._s('Uložit', 'Save')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final ok = await parent.saveEditingProfile();
    if (!ok) return;
    if (mounted) Navigator.pop(context);
    parent.speak(
      parent._s('Profil $editingName uložen', 'Profile $editingName saved'),
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasValidDraft) {
      return AlertDialog(
        insetPadding: parent._dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(parent._s('Chyba', 'Error')),
        ),
        content: Text(
          parent._s(
            'Editor nelze otevřít – chybí draft profilu.',
            'Editor cannot be opened – profile draft missing.',
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
    final s = editingSettings;
    final isActiveEditing = editingId == parent._activeProfileId;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Pokud byl dialog zavřen křížkem/Esc bez Save, musíme revertnout preview
          // saveEditingProfile by mezitím vyčistil draft, takže tento discard je no-op po Save
          if (parent.editingProfile != null) {
            parent.discardEditingProfile();
          }
        }
      },
      child: AlertDialog(
        insetPadding: parent._dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(
            parent._s(
              'Upravit profil: $editingName',
              'Edit profile: $editingName',
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  parent._s(
                    'Změny se projeví po Uložení. Aktivace je samostatná.',
                    'Changes apply after Save. Activation is separate.',
                  ),
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
              if (isActiveEditing)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    parent._s(
                      'Upravujete aktivní profil – náhled se mění živě. Zrušit vrátí původní stav.',
                      'Editing active profile – live preview. Cancel will revert.',
                    ),
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      color: Colors.orange,
                    ),
                  ),
                ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Přepnutí typu displeje',
                  'Switch display type',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _onUpdate(
                      (v) =>
                          v.copyWith(useSixteenSegment: !v.useSixteenSegment),
                    );
                    final nv = editingSettings.useSixteenSegment;
                    parent.speak(
                      nv ? parent._l10n.segment16On : parent._l10n.segment7On,
                      force: true,
                    );
                    setState(() {});
                  },
                  child: Text(
                    parent._l10n.displayType(
                      s.useSixteenSegment
                          ? parent._s('16-segmentový', '16-segment')
                          : parent._s('7-segmentový', '7-segment'),
                    ),
                  ),
                ),
              ),
              const Divider(),
              Semantics(
                header: true,
                child: Text(
                  parent._s(
                    'Vzhled výsledkového displeje',
                    'Result display appearance',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Semantics(
                label: parent._s(
                  'Vzhled výsledkového displeje, aktuálně ${_resultDisplayModeName(s.resultDisplayMode)}',
                  'Result display appearance, currently ${_resultDisplayModeName(s.resultDisplayMode)}',
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in ResultDisplayMode.values)
                      RadioListTile<ResultDisplayMode>(
                        title: Text(_resultDisplayModeName(m)),
                        value: m,
                        groupValue: s.resultDisplayMode,
                        onChanged: (v) {
                          if (v != null) _setResultDisplayMode(v);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Přepnutí periodického zápisu výsledků',
                  'Switch repeating decimal notation for results',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _onUpdate(
                      (v) => v.copyWith(
                        usePeriodicNotation: !v.usePeriodicNotation,
                      ),
                    );
                    final nv = editingSettings.usePeriodicNotation;
                    parent.speak(
                      parent._s(
                        'Periodický zápis: ${nv ? 'Zapnuto' : 'Vypnuto'}',
                        'Repeating notation: ${nv ? 'On' : 'Off'}',
                      ),
                      force: true,
                    );
                    setState(() {});
                  },
                  child: Text(
                    parent._s(
                          'Periodický zápis výsledků',
                          'Repeating decimal notation for results',
                        ) +
                        ': ' +
                        (s.usePeriodicNotation
                            ? parent._s('Zapnuto', 'On')
                            : parent._s('Vypnuto', 'Off')),
                  ),
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Přepnutí hlasového výstupu',
                  'Switch voice output',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _onUpdate((v) => v.copyWith(ttsEnabled: !v.ttsEnabled));
                    final nv = editingSettings.ttsEnabled;
                    parent.speak(
                      nv ? parent._l10n.voiceOn : parent._l10n.voiceOff,
                      force: true,
                    );
                    setState(() {});
                  },
                  child: Text(
                    parent._l10n.voiceOutput(
                      s.ttsEnabled
                          ? parent._s('Zapnuto', 'On')
                          : parent._s('Vypnuto', 'Off'),
                    ),
                  ),
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Přepnutí oznamování příkladu před výpočtem',
                  'Switch announcing expression before calculation',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _onUpdate(
                      (v) =>
                          v.copyWith(announceExpression: !v.announceExpression),
                    );
                    final nv = editingSettings.announceExpression;
                    parent.speak(
                      parent._l10n.announceExpressionState(
                        nv
                            ? parent._s('Zapnuto', 'On')
                            : parent._s('Vypnuto', 'Off'),
                      ),
                      force: true,
                    );
                    setState(() {});
                  },
                  child: Text(
                    parent._l10n.announceExpressionState(
                      s.announceExpression
                          ? parent._s('Zapnuto', 'On')
                          : parent._s('Vypnuto', 'Off'),
                    ),
                  ),
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Přepnutí automatického čtení statistického souhrnu při otevření',
                  'Toggle auto-read of statistics summary on open',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _onUpdate(
                      (v) => v.copyWith(
                        autoReadStatsSummary: !v.autoReadStatsSummary,
                      ),
                    );
                    final nv = editingSettings.autoReadStatsSummary;
                    parent.speak(
                      parent._l10n.autoReadStatsSummaryState(
                        nv
                            ? parent._s('Zapnuto', 'On')
                            : parent._s('Vypnuto', 'Off'),
                      ),
                      force: true,
                    );
                    setState(() {});
                  },
                  child: Text(
                    parent._l10n.autoReadStatsSummaryState(
                      s.autoReadStatsSummary
                          ? parent._s('Zapnuto', 'On')
                          : parent._s('Vypnuto', 'Off'),
                    ),
                  ),
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Přepnutí nápovědy pro pohyb ve statistickém souhrnu',
                  'Toggle stats summary navigation hint',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _onUpdate(
                      (v) => v.copyWith(
                        showStatsNavigationHint: !v.showStatsNavigationHint,
                      ),
                    );
                    final nv = editingSettings.showStatsNavigationHint;
                    parent.speak(
                      parent._l10n.statsNavigationHintState(
                        nv
                            ? parent._s('Zapnuto', 'On')
                            : parent._s('Vypnuto', 'Off'),
                      ),
                      force: true,
                    );
                    setState(() {});
                  },
                  child: Text(
                    parent._l10n.statsNavigationHintState(
                      s.showStatsNavigationHint
                          ? parent._s('Zapnuto', 'On')
                          : parent._s('Vypnuto', 'Off'),
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
                    child: Text(
                      parent._s('Režim čtečky obrazovky', 'Screen reader mode'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ScreenReaderMode>(
                    segments: [
                      ButtonSegment(
                        value: ScreenReaderMode.auto,
                        label: Text(parent._s('Auto', 'Auto')),
                        tooltip: parent._s(
                          'Automaticky podle čtečky',
                          'Automatic according to screen reader',
                        ),
                      ),
                      ButtonSegment(
                        value: ScreenReaderMode.on,
                        label: Text(parent._s('Zapnuto', 'On')),
                        tooltip: parent._s(
                          'Režim čtečky obrazovky zapnut',
                          'Screen reader mode on',
                        ),
                      ),
                      ButtonSegment(
                        value: ScreenReaderMode.off,
                        label: Text(parent._s('Vypnuto', 'Off')),
                        tooltip: parent._s(
                          'Režim čtečky obrazovky vypnut',
                          'Screen reader mode off',
                        ),
                      ),
                    ],
                    selected: {s.screenReaderMode},
                    onSelectionChanged: (Set<ScreenReaderMode> sel) {
                      _onUpdate((v) => v.copyWith(screenReaderMode: sel.first));
                      parent.speak(
                        parent._s(
                          'Režim čtečky: ${sel.first.name}',
                          'Screen reader: ${sel.first.name}',
                        ),
                        force: true,
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Nastavení hlasového engine',
                  'Voice engine settings',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    parent._showTtsEngineDialog();
                  },
                  child: Text(
                    '${parent._s('Engine', 'Engine')}: ${s.ttsEngine ?? parent._s('Výchozí', 'Default')}',
                  ),
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Otevřít systémové nastavení TTS',
                  'Open system TTS settings',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    parent._openTtsSystemSettings();
                  },
                  child: Text(parent._s('Nastavení TTS', 'TTS settings')),
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s('Nastavení hlasu', 'Voice settings'),
                child: ElevatedButton(
                  onPressed: () {
                    parent._showTtsVoiceDialog();
                  },
                  child: Text(
                    '${parent._s('Hlas', 'Voice')}: ${s.ttsVoiceName ?? parent._s('Výchozí', 'Default')}',
                  ),
                ),
              ),
              const Divider(),
              Semantics(
                label: parent._s(
                  'Přepnutí formátu úhlů',
                  'Switch angle format',
                ),
                child: ElevatedButton(
                  onPressed: () {
                    final cur = s.inverseFormatPreference ?? 1;
                    final nf = cur == 0 ? 1 : 0;
                    _onUpdate((v) => v.copyWith(inverseFormatPreference: nf));
                    parent.speak(
                      parent._s(
                        'Úhly: ${nf == 0 ? 'DMS' : 'Desetinné'}',
                        'Angles: ${nf == 0 ? 'DMS' : 'Decimal'}',
                      ),
                      force: true,
                    );
                    setState(() {});
                  },
                  child: Text(
                    parent._s(
                      'Úhly: ${(s.inverseFormatPreference == 0) ? 'DMS' : 'Desetinné'}',
                      'Angles: ${(s.inverseFormatPreference == 0) ? 'DMS' : 'Decimal'}',
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
                    child: Text(parent._l10n.dialogSizeSetting),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<DialogSize>(
                    segments: [
                      ButtonSegment(
                        value: DialogSize.compact,
                        label: Text(parent._l10n.dialogSizeCompact),
                        icon: Icon(Icons.phone_android),
                      ),
                      ButtonSegment(
                        value: DialogSize.wide,
                        label: Text(parent._l10n.dialogSizeWide),
                        icon: Icon(Icons.phone_iphone),
                      ),
                      ButtonSegment(
                        value: DialogSize.fullscreen,
                        label: Text(parent._l10n.dialogSizeFullscreen),
                        icon: Icon(Icons.fullscreen),
                      ),
                    ],
                    selected: {s.dialogSize},
                    onSelectionChanged: (Set<DialogSize> sel) {
                      _onUpdate((v) => v.copyWith(dialogSize: sel.first));
                      parent.speak(
                        parent._s(
                          'Velikost dialogů: ${sel.first.name}',
                          'Dialog size: ${sel.first.name}',
                        ),
                        force: true,
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Semantics(header: true, child: Text(parent._l10n.zoomUpper)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _adjustDotMatrixZoom(-0.1),
                        child: Text('-'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text('${(s.dotMatrixZoom * 100).toInt()}%'),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _adjustDotMatrixZoom(0.1),
                        child: Text('+'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Semantics(header: true, child: Text(parent._l10n.zoomLower)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _adjustResultZoom(-0.1),
                        child: Text('-'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text('${(s.resultZoom * 100).toInt()}%'),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _adjustResultZoom(0.1),
                        child: Text('+'),
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
                    child: Text(parent._s('Periodická čára', 'Repeating bar')),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    label: parent._s(
                      'Náhled periodické čáry s aktuální výškou a tloušťkou',
                      'Preview of repeating bar with current height and thickness',
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF121212),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: Column(
                        children: [
                          CustomDotMatrixDisplay(
                            text: '1.2345̅̅',
                            ledSize: 2.5,
                            ledSpacing: 0.6,
                            overlineThickness: s.overlineThickness,
                            overlineHeight: s.overlineHeight,
                          ),
                          const SizedBox(height: 6),
                          CustomSegmentDisplay(
                            value: '1.2345̅̅',
                            size: 12,
                            characterCount: 7,
                            isSixteenSegment: s.useSixteenSegment,
                            overlineThickness: s.overlineThickness,
                            overlineHeight: s.overlineHeight,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(
                      parent._s(
                        'Výška periodické čáry',
                        'Repeating bar height',
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: parent._s(
                          'Snížit výšku periodické čáry',
                          'Decrease repeating bar height',
                        ),
                        child: ElevatedButton(
                          onPressed: () => _adjustOverlineHeight(-0.1),
                          child: Text('-'),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text('${(s.overlineHeight * 100).toInt()}%'),
                        ),
                      ),
                      Semantics(
                        label: parent._s(
                          'Zvýšit výšku periodické čáry',
                          'Increase repeating bar height',
                        ),
                        child: ElevatedButton(
                          onPressed: () => _adjustOverlineHeight(0.1),
                          child: Text('+'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(
                      parent._s(
                        'Tloušťka periodické čárky',
                        'Repeating bar thickness',
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: parent._s(
                          'Zmenšit tloušťku periodické čárky',
                          'Decrease repeating bar thickness',
                        ),
                        child: ElevatedButton(
                          onPressed: () => _adjustOverlineThickness(-0.2),
                          child: Text('-'),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            '${(s.overlineThickness * 100).toInt()}%',
                          ),
                        ),
                      ),
                      Semantics(
                        label: parent._s(
                          'Zvětšit tloušťku periodické čárky',
                          'Increase repeating bar thickness',
                        ),
                        child: ElevatedButton(
                          onPressed: () => _adjustOverlineThickness(0.2),
                          child: Text('+'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: parent._s(
                      'Obnovit výchozí vzhled periodické čáry',
                      'Reset repeating bar appearance',
                    ),
                    child: ElevatedButton.icon(
                      key: Key('resetOverlineButton'),
                      icon: Icon(Icons.restart_alt),
                      onPressed: _resetOverlineStyle,
                      label: Text(
                        parent._s(
                          'Obnovit výchozí vzhled periodické čáry',
                          'Reset repeating bar appearance',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(parent._l10n.thousandGroupGapSection),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThousandGroupGap>(
                    segments: [
                      ButtonSegment(
                        value: ThousandGroupGap.small,
                        label: Text(parent._l10n.thousandGapSmall),
                      ),
                      ButtonSegment(
                        value: ThousandGroupGap.medium,
                        label: Text(parent._l10n.thousandGapMedium),
                      ),
                      ButtonSegment(
                        value: ThousandGroupGap.large,
                        label: Text(parent._l10n.thousandGapLarge),
                      ),
                    ],
                    selected: {s.thousandGroupGap},
                    onSelectionChanged: (Set<ThousandGroupGap> sel) {
                      _onUpdate((v) => v.copyWith(thousandGroupGap: sel.first));
                      parent.speak(
                        parent._s(
                          'Mezera skupin: ${sel.first.name}',
                          'Group gap: ${sel.first.name}',
                        ),
                        force: true,
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                label: parent._s(
                  'Přepnout zarovnání vstupního řádku vlevo',
                  'Toggle left alignment of input line',
                ),
                child: ElevatedButton.icon(
                  icon: Icon(
                    s.alignInputLeft
                        ? Icons.format_align_left
                        : Icons.format_align_center,
                  ),
                  onPressed: () {
                    _onUpdate(
                      (v) => v.copyWith(alignInputLeft: !v.alignInputLeft),
                    );
                    final nv = editingSettings.alignInputLeft;
                    parent.speak(
                      nv
                          ? parent._s(
                              'Vstupní řádek: vlevo',
                              'Input line: left',
                            )
                          : parent._s(
                              'Vstupní řádek: na střed',
                              'Input line: centered',
                            ),
                      force: true,
                    );
                    setState(() {});
                  },
                  label: Text(
                    s.alignInputLeft
                        ? parent._s('Vstupní řádek: vlevo', 'Input line: left')
                        : parent._s(
                            'Vstupní řádek: na střed',
                            'Input line: centered',
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      parent._s('Velikost písma dialogů', 'Dialog font size'),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _adjustDialogFontScale(-0.1),
                        child: Text('-'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text('${(s.dialogFontScale * 100).toInt()}%'),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _adjustDialogFontScale(0.1),
                        child: Text('+'),
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
                    child: Text(
                      parent._s(
                        'Velikost písma tlačítek',
                        'Keyboard button font size',
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _adjustKeyboardFontScale(-0.1),
                        child: Text('-'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            '${(s.fontSizeMultiplier * 100).toInt()}%',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _adjustKeyboardFontScale(0.1),
                        child: Text('+'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Semantics(header: true, child: Text(parent._l10n.speechRate)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _adjustSpeechRate(-0.1),
                        child: Text('-'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('${(s.speechRate * 100).toInt()}%'),
                      ),
                      ElevatedButton(
                        onPressed: () => _adjustSpeechRate(0.1),
                        child: Text('+'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Semantics(header: true, child: Text(parent._l10n.volume)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _adjustSpeechVolume(-0.1),
                        child: Text('-'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('${(s.speechVolume * 100).toInt()}%'),
                      ),
                      ElevatedButton(
                        onPressed: () => _adjustSpeechVolume(0.1),
                        child: Text('+'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Semantics(
            label: parent._s(
              'Zrušit změny profilu $editingName',
              'Discard changes for profile $editingName',
            ),
            button: true,
            child: TextButton(
              onPressed: () {
                parent.discardEditingProfile();
                Navigator.pop(context);
              },
              child: Text(parent._l10n.cancel),
            ),
          ),
          Semantics(
            label: parent._s(
              'Uložit změny profilu $editingName',
              'Save changes for profile $editingName',
            ),
            button: true,
            child: FilledButton(
              autofocus: true,
              onPressed: () async {
                await _confirmAndSave();
              },
              child: Text(parent._s('Uložit', 'Save')),
            ),
          ),
        ],
      ),
    );
  }
}
