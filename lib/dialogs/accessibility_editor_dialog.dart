part of '../main.dart';

class _AccessibilityProfileEditorDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _AccessibilityProfileEditorDialog({required this.parent});
  @override
  State<_AccessibilityProfileEditorDialog> createState() => _AccessibilityProfileEditorDialogState();
}

class _AccessibilityProfileEditorDialogState extends State<_AccessibilityProfileEditorDialog> {
  _CalculatorScreenState get parent => widget.parent;
  AccessibilitySettings get editingSettings {
    final d = parent.editingProfile;
    assert(d != null, 'Editor invariant violated: _editingDraft is null');
    if (d == null) {
      // Fallback to active only for graceful degradation, but log
      debugPrint('_AccessibilityProfileEditorDialog: editingProfile is null, using active');
      return parent.activeAccessibilitySettings;
    }
    return d.settings;
  }
  bool get hasValidDraft => parent.editingProfile != null && parent.editingProfileId != null;
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
    setState((){});
  }
  void _adjustDotMatrixZoom(double delta) {
    final nv = (editingSettings.dotMatrixZoom + delta).clamp(0.5, 5.0);
    _onUpdate((s)=> s.copyWith(dotMatrixZoom: nv));
  }
  void _adjustResultZoom(double delta) {
    final nv = (editingSettings.resultZoom + delta).clamp(0.5, 5.0);
    _onUpdate((s)=> s.copyWith(resultZoom: nv));
    setState((){});
  }
  void _adjustSpeechRate(double delta) {
    final nv = (editingSettings.speechRate + delta).clamp(0.1, 1.0);
    _onUpdate((s)=> s.copyWith(speechRate: nv));
    setState((){});
    parent.speak(parent._l10n.speechRatePct((nv*100).toInt()));
  }
  void _adjustSpeechVolume(double delta) {
    final nv = (editingSettings.speechVolume + delta).clamp(0.0, 1.0);
    _onUpdate((s)=> s.copyWith(speechVolume: nv));
    setState((){});
    parent.speak(parent._l10n.volumePct((nv*100).toInt()));
  }
  void _adjustDialogFontScale(double delta) {
    final nv = (editingSettings.dialogFontScale + delta).clamp(0.5, 5.0);
    _onUpdate((s)=> s.copyWith(dialogFontScale: nv));
    setState((){});
    parent.speak(parent._s('Velikost písma dialogů ${(nv*100).toInt()} procent','Dialog font size ${(nv*100).toInt()} percent'));
  }
  void _adjustKeyboardFontScale(double delta) {
    final nv = (editingSettings.fontSizeMultiplier + delta).clamp(0.7, 2.5);
    _onUpdate((s)=> s.copyWith(fontSizeMultiplier: nv));
    setState((){});
    parent.speak(parent._s('Velikost písma tlačítek ${(nv*100).toInt()} procent','Keyboard button font size ${(nv*100).toInt()} percent'));
  }
  void _adjustOverlineHeight(double delta) {
    final nv = (editingSettings.overlineHeight + delta).clamp(0.5, 2.0);
    _onUpdate((s)=> s.copyWith(overlineHeight: nv));
    setState((){});
  }
  void _adjustOverlineThickness(double delta) {
    final nv = (editingSettings.overlineThickness + delta).clamp(0.8, 4.0);
    _onUpdate((s)=> s.copyWith(overlineThickness: nv));
    setState((){});
  }
  void _resetOverlineStyle() {
    _onUpdate((s)=> s.copyWith(overlineHeight: 1.0, overlineThickness: 1.0));
    setState((){});
    parent.speak(parent._s('Vzhled periodické čáry obnoven','Repeating bar appearance reset'));
  }
  @override
  Widget build(BuildContext context) {
    if (!hasValidDraft) {
      return AlertDialog(
        insetPadding: parent._dialogInsetPadding(),
        title: Semantics(header: true, child: Text(parent._s('Chyba','Error'))),
        content: Text(parent._s('Editor nelze otevřít – chybí draft profilu.','Editor cannot be opened – profile draft missing.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(parent._l10n.close)),
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
      title: Semantics(header:true, child: Text(parent._s('Upravit profil: $editingName','Edit profile: $editingName'))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(liveRegion:true, child: Text(parent._s('Změny se projeví po Uložení. Aktivace je samostatná.','Changes apply after Save. Activation is separate.'), style: TextStyle(fontStyle: FontStyle.italic, fontSize:12))),
            if (isActiveEditing) Semantics(liveRegion:true, child: Text(parent._s('Upravujete aktivní profil – náhled se mění živě. Zrušit vrátí původní stav.','Editing active profile – live preview. Cancel will revert.'), style: TextStyle(fontStyle: FontStyle.italic, fontSize:11, color: Colors.orange))),
            const Divider(),
            Semantics(label: parent._s('Přepnutí typu displeje','Switch display type'), child: ElevatedButton(onPressed: () { _onUpdate((v)=> v.copyWith(useSixteenSegment: !v.useSixteenSegment)); parent.speak(s.useSixteenSegment ? parent._l10n.segment16On : parent._l10n.segment7On); }, child: Text(parent._l10n.displayType(s.useSixteenSegment ? parent._s('16-segmentový','16-segment') : parent._s('7-segmentový','7-segment'))))),
            const Divider(),
            Semantics(label: parent._s('Přepnutí periodického zápisu výsledků','Switch repeating decimal notation for results'), child: ElevatedButton(onPressed: () { _onUpdate((v)=> v.copyWith(usePeriodicNotation: !v.usePeriodicNotation)); setState((){}); }, child: Text(parent._s('Periodický zápis výsledků','Repeating decimal notation for results') + ': ' + (s.usePeriodicNotation ? parent._s('Zapnuto','On') : parent._s('Vypnuto','Off'))))),
            const Divider(),
            Semantics(label: parent._s('Přepnutí hlasového výstupu','Switch voice output'), child: ElevatedButton(onPressed: () { _onUpdate((v)=> v.copyWith(ttsEnabled: !v.ttsEnabled)); setState((){}); parent.speak(s.ttsEnabled ? parent._l10n.voiceOn : parent._l10n.voiceOff); }, child: Text(parent._l10n.voiceOutput(s.ttsEnabled ? parent._s('Zapnuto','On') : parent._s('Vypnuto','Off'))))),
            const Divider(),
            Semantics(label: parent._s('Přepnutí oznamování příkladu před výpočtem','Switch announcing expression before calculation'), child: ElevatedButton(onPressed: () { _onUpdate((v)=> v.copyWith(announceExpression: !v.announceExpression)); setState((){}); }, child: Text(parent._l10n.announceExpressionState(s.announceExpression ? parent._s('Zapnuto','On') : parent._s('Vypnuto','Off'))))),
            const Divider(),
            Semantics(label: parent._s('Přepnutí automatického čtení statistického souhrnu při otevření','Toggle auto-read of statistics summary on open'), child: ElevatedButton(onPressed: () { _onUpdate((v)=> v.copyWith(autoReadStatsSummary: !v.autoReadStatsSummary)); setState((){}); }, child: Text(parent._l10n.autoReadStatsSummaryState(s.autoReadStatsSummary ? parent._s('Zapnuto','On') : parent._s('Vypnuto','Off'))))),
            const Divider(),
            Semantics(label: parent._s('Přepnutí nápovědy pro pohyb ve statistickém souhrnu','Toggle stats summary navigation hint'), child: ElevatedButton(onPressed: () { _onUpdate((v)=> v.copyWith(showStatsNavigationHint: !v.showStatsNavigationHint)); setState((){}); }, child: Text(parent._l10n.statsNavigationHintState(s.showStatsNavigationHint ? parent._s('Zapnuto','On') : parent._s('Vypnuto','Off'))))),
            const Divider(),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Semantics(header:true, child: Text(parent._s('Režim čtečky obrazovky','Screen reader mode'))), const SizedBox(height:8), SegmentedButton<ScreenReaderMode>(segments: [ButtonSegment(value: ScreenReaderMode.auto, label: Text(parent._s('Auto','Auto')), tooltip: parent._s('Automaticky podle čtečky','Automatic according to screen reader')), ButtonSegment(value: ScreenReaderMode.on, label: Text(parent._s('Zapnuto','On')), tooltip: parent._s('Režim čtečky obrazovky zapnut','Screen reader mode on')), ButtonSegment(value: ScreenReaderMode.off, label: Text(parent._s('Vypnuto','Off')), tooltip: parent._s('Režim čtečky obrazovky vypnut','Screen reader mode off'))], selected: {s.screenReaderMode}, onSelectionChanged: (Set<ScreenReaderMode> sel){ _onUpdate((v)=> v.copyWith(screenReaderMode: sel.first)); setState((){}); })]),
            const Divider(),
            Semantics(label: parent._s('Nastavení hlasového engine','Voice engine settings'), child: ElevatedButton(onPressed: (){ parent._showTtsEngineDialog(); }, child: Text('${parent._s('Engine','Engine')}: ${s.ttsEngine ?? parent._s('Výchozí','Default')}'))),
            const Divider(),
            Semantics(label: parent._s('Otevřít systémové nastavení TTS','Open system TTS settings'), child: ElevatedButton(onPressed: (){ parent._openTtsSystemSettings(); }, child: Text(parent._s('Nastavení TTS','TTS settings')))),
            const Divider(),
            Semantics(label: parent._s('Nastavení hlasu','Voice settings'), child: ElevatedButton(onPressed: (){ parent._showTtsVoiceDialog(); }, child: Text('${parent._s('Hlas','Voice')}: ${s.ttsVoiceName ?? parent._s('Výchozí','Default')}'))),
            const Divider(),
            Semantics(label: parent._s('Přepnutí formátu úhlů','Switch angle format'), child: ElevatedButton(onPressed: (){ final cur = s.inverseFormatPreference ?? 1; final nf = cur==0?1:0; _onUpdate((v)=> v.copyWith(inverseFormatPreference: nf)); setState((){}); }, child: Text(parent._s('Úhly: ${(s.inverseFormatPreference==0)?'DMS':'Desetinné'}','Angles: ${(s.inverseFormatPreference==0)?'DMS':'Decimal'}')))),
            const Divider(),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Semantics(header:true, child: Text(parent._l10n.dialogSizeSetting)), const SizedBox(height:8), SegmentedButton<DialogSize>(segments: [ButtonSegment(value: DialogSize.compact, label: Text(parent._l10n.dialogSizeCompact), icon: Icon(Icons.phone_android)), ButtonSegment(value: DialogSize.wide, label: Text(parent._l10n.dialogSizeWide), icon: Icon(Icons.phone_iphone)), ButtonSegment(value: DialogSize.fullscreen, label: Text(parent._l10n.dialogSizeFullscreen), icon: Icon(Icons.fullscreen))], selected: {s.dialogSize}, onSelectionChanged: (Set<DialogSize> sel){ _onUpdate((v)=> v.copyWith(dialogSize: sel.first)); setState((){}); })]),
            const SizedBox(height:16),
            Column(children:[Semantics(header:true, child: Text(parent._l10n.zoomUpper)), Row(mainAxisAlignment: MainAxisAlignment.center, children:[ElevatedButton(onPressed: ()=> _adjustDotMatrixZoom(-0.1), child: Text('-')), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Semantics(liveRegion:true, child: Text('${(s.dotMatrixZoom*100).toInt()}%'))), ElevatedButton(onPressed: ()=> _adjustDotMatrixZoom(0.1), child: Text('+'))])]),
            const SizedBox(height:16),
            Column(children:[Semantics(header:true, child: Text(parent._l10n.zoomLower)), Row(mainAxisAlignment: MainAxisAlignment.center, children:[ElevatedButton(onPressed: ()=> _adjustResultZoom(-0.1), child: Text('-')), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Semantics(liveRegion:true, child: Text('${(s.resultZoom*100).toInt()}%'))), ElevatedButton(onPressed: ()=> _adjustResultZoom(0.1), child: Text('+'))])]),
            const SizedBox(height:16),
            Column(children:[Semantics(header:true, child: Text(parent._s('Periodická čára','Repeating bar'))), const SizedBox(height:4),
              Semantics(label: parent._s('Náhled periodické čáry s aktuální výškou a tloušťkou','Preview of repeating bar with current height and thickness'), child: Container(padding: EdgeInsets.symmetric(horizontal:8, vertical:6), decoration: BoxDecoration(color: Color(0xFF121212), border: Border.all(color: Colors.black, width:1)), child: Column(children:[CustomDotMatrixDisplay(text: '1.2345̅̅', ledSize:2.5, ledSpacing:0.6, overlineThickness: s.overlineThickness, overlineHeight: s.overlineHeight), const SizedBox(height:6), CustomSegmentDisplay(value: '1.2345̅̅', size:12, characterCount:7, isSixteenSegment: s.useSixteenSegment, overlineThickness: s.overlineThickness, overlineHeight: s.overlineHeight)]))),
              const SizedBox(height:8),
              Semantics(header:true, child: Text(parent._s('Výška periodické čáry','Repeating bar height'))), Row(mainAxisAlignment: MainAxisAlignment.center, children:[Semantics(label: parent._s('Snížit výšku periodické čáry','Decrease repeating bar height'), child: ElevatedButton(onPressed: ()=> _adjustOverlineHeight(-0.1), child: Text('-'))), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Semantics(liveRegion:true, child: Text('${(s.overlineHeight*100).toInt()}%'))), Semantics(label: parent._s('Zvýšit výšku periodické čáry','Increase repeating bar height'), child: ElevatedButton(onPressed: ()=> _adjustOverlineHeight(0.1), child: Text('+')))]), const SizedBox(height:8), Semantics(header:true, child: Text(parent._s('Tloušťka periodické čárky','Repeating bar thickness'))), Row(mainAxisAlignment: MainAxisAlignment.center, children:[Semantics(label: parent._s('Zmenšit tloušťku periodické čárky','Decrease repeating bar thickness'), child: ElevatedButton(onPressed: ()=> _adjustOverlineThickness(-0.2), child: Text('-'))), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Semantics(liveRegion:true, child: Text('${(s.overlineThickness*100).toInt()}%'))), Semantics(label: parent._s('Zvětšit tloušťku periodické čárky','Increase repeating bar thickness'), child: ElevatedButton(onPressed: ()=> _adjustOverlineThickness(0.2), child: Text('+')))]), const SizedBox(height:8), Semantics(label: parent._s('Obnovit výchozí vzhled periodické čáry','Reset repeating bar appearance'), child: ElevatedButton.icon(key: Key('resetOverlineButton'), icon: Icon(Icons.restart_alt), onPressed: _resetOverlineStyle, label: Text(parent._s('Obnovit výchozí vzhled periodické čáry','Reset repeating bar appearance'))))]),
            const SizedBox(height:16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Semantics(header:true, child: Text(parent._l10n.thousandGroupGapSection)), const SizedBox(height:8), SegmentedButton<ThousandGroupGap>(segments: [ButtonSegment(value: ThousandGroupGap.small, label: Text(parent._l10n.thousandGapSmall)), ButtonSegment(value: ThousandGroupGap.medium, label: Text(parent._l10n.thousandGapMedium)), ButtonSegment(value: ThousandGroupGap.large, label: Text(parent._l10n.thousandGapLarge))], selected: {s.thousandGroupGap}, onSelectionChanged: (Set<ThousandGroupGap> sel){ _onUpdate((v)=> v.copyWith(thousandGroupGap: sel.first)); setState((){}); })]),
            const SizedBox(height:16),
            Semantics(label: parent._s('Přepnout zarovnání vstupního řádku vlevo','Toggle left alignment of input line'), child: ElevatedButton.icon(icon: Icon(s.alignInputLeft ? Icons.format_align_left : Icons.format_align_center), onPressed: (){ _onUpdate((v)=> v.copyWith(alignInputLeft: !v.alignInputLeft)); setState((){}); }, label: Text(s.alignInputLeft ? parent._s('Vstupní řádek: vlevo','Input line: left') : parent._s('Vstupní řádek: na střed','Input line: centered')))),
            const SizedBox(height:16),
            Column(children:[Semantics(header:true, child: Text(parent._s('Velikost písma dialogů','Dialog font size'))), Row(mainAxisAlignment: MainAxisAlignment.center, children:[ElevatedButton(onPressed: ()=> _adjustDialogFontScale(-0.1), child: Text('-')), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Semantics(liveRegion:true, child: Text('${(s.dialogFontScale*100).toInt()}%'))), ElevatedButton(onPressed: ()=> _adjustDialogFontScale(0.1), child: Text('+'))])]),
            const SizedBox(height:16),
            Column(children:[Semantics(header:true, child: Text(parent._s('Velikost písma tlačítek','Keyboard button font size'))), Row(mainAxisAlignment: MainAxisAlignment.center, children:[ElevatedButton(onPressed: ()=> _adjustKeyboardFontScale(-0.1), child: Text('-')), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Semantics(liveRegion:true, child: Text('${(s.fontSizeMultiplier*100).toInt()}%'))), ElevatedButton(onPressed: ()=> _adjustKeyboardFontScale(0.1), child: Text('+'))])]),
            const SizedBox(height:16),
            Column(children:[Semantics(header:true, child: Text(parent._l10n.speechRate)), Row(mainAxisAlignment: MainAxisAlignment.center, children:[ElevatedButton(onPressed: ()=> _adjustSpeechRate(-0.1), child: Text('-')), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Text('${(s.speechRate*100).toInt()}%')), ElevatedButton(onPressed: ()=> _adjustSpeechRate(0.1), child: Text('+'))])]),
            const SizedBox(height:16),
            Column(children:[Semantics(header:true, child: Text(parent._l10n.volume)), Row(mainAxisAlignment: MainAxisAlignment.center, children:[ElevatedButton(onPressed: ()=> _adjustSpeechVolume(-0.1), child: Text('-')), Padding(padding: EdgeInsets.symmetric(horizontal:16), child: Text('${(s.speechVolume*100).toInt()}%')), ElevatedButton(onPressed: ()=> _adjustSpeechVolume(0.1), child: Text('+'))])]),
          ],
        ),
      ),
      actions: [
        Semantics(label: parent._s('Zrušit změny profilu $editingName','Discard changes for profile $editingName'), button:true, child: TextButton(onPressed: (){ parent.discardEditingProfile(); Navigator.pop(context); }, child: Text(parent._l10n.cancel))),
        Semantics(label: parent._s('Uložit změny profilu $editingName','Save changes for profile $editingName'), button:true, child: FilledButton(autofocus:true, onPressed: () async { final ok = await parent.saveEditingProfile(); if (!ok) return; if(context.mounted) Navigator.pop(context); parent.speak(parent._s('Profil $editingName uložen','Profile $editingName saved')); }, child: Text(parent._s('Uložit','Save')))),
      ],
      ),
    );
  }
}
