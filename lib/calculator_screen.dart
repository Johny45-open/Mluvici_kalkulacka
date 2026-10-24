part of 'main.dart';

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

/// Z1-dokončení: důvod vypnutí režimu ovládání výrazu. Určuje, zda smí
/// první stisk šipky/Home/End po návratu primárního fokusu režim znovu
/// aktivovat (`traversal`), nebo je vyžadován výslovný tap na displej
/// (`dialog`). `none` = režim aktivní nebo výchozí stav. Není zdrojem
/// pozice kurzoru (tou zůstává `_cursorPosition`).
enum _ExpressionControlOffReason { none, traversal, dialog }

/// Cíl příštího stisku zlomkového přepínače (jediný autoritativní zdroj pro
/// popisek, přístupný stav i hlas; žádná část UI cíl neodhaduje samostatně).
/// - fraction: po stisku se ukáže zlomek.
/// - numeric: po stisku se ukáže desetinná numerika.
/// - surd: po stisku se ukáže exaktní surd tvar základu.
enum _FractionTargetKind { fraction, numeric, surd }

class _CalculatorScreenState extends State<CalculatorScreen>
    with WidgetsBindingObserver {
  static const int _kKeypadColumns = 4;
  static const int _kKeypadReferenceRows = 7;
  static const int _kKeypadCellCount = _kKeypadColumns * _kKeypadReferenceRows;

  /// Maximální počet opakování v dialogu počtu vložení (M+ dlouhý stisk).
  /// Chrání před neúměrnou dávkou záznamů (překlep typu 1000000 by jinak
  /// synchronně zablokoval UI a nafoukl perzistovaná data). 1000 je
  /// velkorysé pro legitimní hromadné vkládání (typicky desítky) a drží
  /// jednu dávku hluboko pod prahem zrcadlení do SharedPreferences.
  static const int kMaxStatsRepeatCount = 1000;

  /// Jediné autoritativní úložiště verze aplikace (formát
  /// 'version+buildNumber' z PackageInfo). Notifier, aby se již otevřený
  /// dialog Nastavení přístupnosti překreslil po dokončení async načtení.
  /// Počáteční '' = ještě nenačteno (žádný odhad, žádné hardcoded číslo).
  final ValueNotifier<String> _appVersionNotifier = ValueNotifier<String>('');
  String get _currentAppVersion => _appVersionNotifier.value;
  static const MethodChannel _accessibilityChannel = MethodChannel(
    'com.example.mluvici_kalkulacka/accessibility',
  );

  final FlutterTts tts = FlutterTts();
  final FocusNode _mainFocusNode = FocusNode();

  /// Režim ovládání výrazu (Z1): zda smějí fyzické šipky/Home/End měnit
  /// [_cursorPosition]. NENÍ druhým zdrojem pozice kurzoru — pouze brána
  /// klávesového handleru. Platí společně s
  /// `_mainFocusNode.hasPrimaryFocus` (samotné `hasFocus` by pouštělo šipky
  /// i při fokusovaném potomkovi, např. tlačítku klávesnice). Výchozí `true`
  /// odpovídá počátečnímu `_mainFocusNode.requestFocus()` ve
  /// [_initPrimaryFocus]; explicitní aktivace je vyžadována až po každé
  /// deaktivaci (odchod primárního fokusu, otevření dialogu, ztráta
  /// přístupného fokusu proxy). Listener režim nikdy sám nezapíná.
  bool _expressionControlActive = true;

  /// Z1-dokončení: proč je režim momentálně vypnutý (viz
  /// [_ExpressionControlOffReason]). Diagnostická hodnota; samotnou
  /// reaktivaci řídí [_dialogDepth] spolu s primárním fokusem (viz
  /// [_tryReactivateExpressionControl]).
  _ExpressionControlOffReason _expressionControlOffReason =
      _ExpressionControlOffReason.none;

  /// Z1-reaktivace-po-dialogu: počet právě otevřených dialogů (vnořené se
  /// sčítají). Dokud je > 0, nesmí žádná klávesa obejít dialog ani armovat
  /// ovládání výrazu za ním; reaktivace je možná až po úplném zavření
  /// (spolu s obnoveným primárním fokusem, viz [_tryReactivateExpressionControl]).
  /// Není zdrojem pravdy o fokusu ani kurzoru — pouze strážce.
  int _dialogDepth = 0;
  late final FocusNode _readingOrderFocusNode = FocusNode(
    debugLabel: 'readingOrderButton',
  );

  /// Skrytá accessibility proxy vstupního výrazu (stabilní BUILD spike:
  /// proxy je ve stromě vždy, i při prázdném výrazu).
  /// Jediný standardní textový prvek displeje: při editaci publikuje do
  /// Semantics stromu `value == display` + `textSelection ==
  /// collapsed(_cursorPosition)` přes `RenderEditable`; při prázdném výrazu
  /// nese wrapper hodnotu prázdného stavu (řeč výsledku / "Prázdno"). Vizuál zůstává `CustomDotMatrixDisplay` s `_` markerem.
  /// Controller je POUZE derivace `display`/`_cursorPosition` (viz
  /// [_syncA11yProxy]), nikdy zdroj pravdy. Proxy si nikdy sama nebere
  /// input focus (`autofocus: false`); `readOnly: true`
  /// brání otevření softwarové klávesnice (`_shouldCreateInputConnection`).
  /// `canRequestFocus` zůstává záměrně true — s false by `RenderEditable`
  /// nikdy nepublikoval `onSetSelection` (ověřeno v SDK).
  ///
  /// Z6: `skipTraversal: false` — vstupní řádek je skutečnou zastávkou
  /// klávesnicového traversálu (Tab/Shift+Tab) ještě PŘED výsledkem.
  /// Důvod (oprava NVDA): NVDA na Windows sleduje klávesnicový fokus přes
  /// UIA stav `focused`; uzel, který Flutterův traversál přeskakuje, nemůže
  /// zaměření získat, a NVDA proto při Tab-navigaci přeskakovalo horní
  /// vstupní řádek a dosahovalo pouze na výsledek. Při získání fokusu
  /// `RenderEditable` sám publikuje skutečné `isFocused` i akci
  /// `onSetSelection` (ověřeno v SDK — `rendering/editable.dart`), takže
  /// žádný fokusový stav se nepředstírá. Pohyb virtuálního kurzoru NVDA
  /// v Browse Mode fokusový uzel nemění — obrys ani `focused` se tím
  /// nespustí. Vzor zrcadlí [_resultFocusNode] (Z5).
  final TextEditingController _displayA11yController = TextEditingController();
  late final FocusNode _displayA11yFocusNode = FocusNode(
    debugLabel: 'displayA11yProxy',
    skipTraversal: false,
  );

  /// Z5: klávesnicový fokus dolního výsledkového řádku (Tab/Shift+Tab).
  /// Dlouhodobě spravovaný uzel (stejně jako [_mainFocusNode]): `skipTraversal`
  /// záměrně false, aby byl výsledek dosažitelný Tabem; `canRequestFocus`
  /// true, aby šel fokusovat. Žádný `autofocus` — počáteční fokus drží
  /// [_mainFocusNode]. Vlastní `onKeyEvent` NENÍ: události propadnou
  /// kořenovému [_handleKeyboardInput] (předek), viz [_buildResultA11yNode].
  final FocusNode _resultFocusNode = FocusNode(
    debugLabel: 'resultDisplay',
    skipTraversal: false,
    canRequestFocus: true,
  );

  /// Z5: zda má [_resultFocusNode] právě klávesnicový fokus. Zdroj pravdy je
  /// fokusový strom (`onFocusChange`); tato hodnota pouze řídí publikaci
  /// `focused:` na existujícím sémantickém uzlu výsledku a viditelnou
  /// indikaci (viz [_buildResultA11yNode]).
  bool _resultHasFocus = false;

  /// Zda je naplánován post-frame sync proxy (ochrana před frontou duplicit).
  bool _a11ySyncScheduled = false;

  void _returnFocusToKeyboard() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _mainFocusNode.hasFocus == false) {
        _mainFocusNode.requestFocus();
      }
    });
  }

  /// Z1: odchod primárního fokusu z [_mainFocusNode] vypíná režim ovládání
  /// výrazu. Pouze vypíná, nikdy nezapíná (opětovné zapnutí patří výhradně
  /// aktivační cestě displeje nebo reaktivaci šipkou). Návrat fokusu
  /// z dialogu proto režim sám neaktivuje. Listener čte čerstvý
  /// `FocusManager.instance.primaryFocus` při každém oznámení — reaguje
  /// tedy na změnu primárního fokusu, nikoli pouze na `hasFocus` (to je
  /// pravdivé i pro předka fokusovaného potomka). Dialogový důvod se zde
  /// nikdy nepřepisuje traversálovým (`showAppDialog` jej nastavil dřív,
  /// než route přesune fokus do dialogu). Registrováno v [initState],
  /// odregistrováno v [dispose].
  void _handlePrimaryFocusChanged() {
    if (!mounted) return;
    if (FocusManager.instance.primaryFocus == _mainFocusNode) return;
    if (!_expressionControlActive) return;
    _expressionControlActive = false;
    if (_expressionControlOffReason != _ExpressionControlOffReason.dialog) {
      _expressionControlOffReason = _ExpressionControlOffReason.traversal;
    }
  }

  String display = '';
  int _cursorPosition = 0;
  String _lastResult = '0.';
  // Exaktní částečně odmocněný výsledek (např. √72 -> 6√2) jako vedlejší
  // prezentační metadata. _lastResult zůstává VŽDY numerický string a je
  // zdrojem pravdy pro výpočty, historii i ANS. _lastExactKey říká, ke
  // kterému _lastResult exact patří — všechny ostatní výpočetní cesty mění
  // _lastResult, takže zastaralý exact se klíčem automaticky zneplatní
  // a není potřeba nulovat ho na desítkách míst.
  CalcValue? _lastExact;
  String _lastExactKey = '';
  // Vrací text skutečně zobrazený na výsledkovém displeji: exaktní surd
  // či racionální tvar, pokud patří k aktuálnímu výsledku (klíč + generace),
  // jinak numerický _lastResult. Přesnost se nikdy neodvozuje parsováním
  // numerického řetězce.
  String get _displayedResultString {
    final exact = _lastExact;
    if (_isLastExactValid && _lastResult.isNotEmpty) {
      if (exact is SurdValue) return formatSurd(exact);
      final r = _validRationalNonTrivial;
      if (r != null) return r.toDisplayString();
    }
    return _lastResult.isEmpty ? '0.' : _lastResult;
  }

  // Aktivní reprezentace výsledku mimo zlomkový pohled podle skutečně
  // zvoleného ResultDisplayMode. Jediná mode-aware pravda pro displej
  // i hlas: text -> exaktní tvar pokud validní, auto -> exaktní tvar pokud
  // validní, segment -> vždy numerika. Nemění _lastResult/_lastNumericValue/
  // _lastExact/_lastExactKey, nic nepřepočítává, neřeší TTS ani focus.
  // Fraction view má vyšší prioritu a řeší se v místě použití.
  // Vynucené desetinné (override false při platném RationalValue) základ
  // obchází ve vykreslovací cestě — nikdy zde.
  String _activeResultString() {
    switch (_globalResultDisplayMode) {
      case ResultDisplayMode.text:
        return _displayedResultString;
      case ResultDisplayMode.auto:
        if (_isSurdValid || _validRationalNonTrivial != null) {
          return _displayedResultString;
        }
        return _lastResult.isEmpty ? '0.' : _lastResult;
      case ResultDisplayMode.segment:
        return _lastResult.isEmpty ? '0.' : _lastResult;
    }
  }

  // Platnost exaktních metadat: vyžaduje shodu klíče i generace výsledku.
  // Samotný řetězec nestačí — dva různé výpočty (např. 1/3 racionálně
  // a 0.3333333333 numericky) mohou vytvořit stejný _lastResult.
  bool get _isLastExactValid =>
      _lastExact != null &&
      _lastExactKey == _lastResult &&
      _lastExactGeneration == _resultGeneration;

  bool get _isSurdValid =>
      _isLastExactValid &&
      _lastExact is SurdValue &&
      _lastResult.isNotEmpty;

  // Platný přesný racionální výsledek pro matematiku (ANS, paměť).
  // Bez ohledu na zobrazovací způsobilost (plain-numeric) — matematika
  // není závislá na formátu displeje.
  Rational? get _validRational =>
      (_isLastExactValid && _lastExact is RationalValue)
          ? (_lastExact as RationalValue).value
          : null;

  // Platný netriviální racionální tvar pro zobrazení (d != 1, plain-numeric
  // kontext). Triviální n/1 (včetně 0/1) není zlomek a vrací null.
  Rational? get _validRationalNonTrivial {
    final r = _validRational;
    if (r == null) return null;
    if (!_lastResultIsPlainNumeric) return null;
    if (r.denominator == BigInt.one) return null;
    return r;
  }

  // Čistě prezentační helper: říká, zda se právě teď (bez zlomkového
  // překryvu) zobrazuje exaktní surd tvar v režimu text/auto. Kopíruje
  // podmínku _activeResultString()/_displayedResultString pro surd,
  // nic nepřepočítává, nemění _lastResult/_lastExact/_lastExactKey.
  // Záměrně pouze surd: racionální základ se v text/auto sice ukazuje jako
  // n/d automaticky, ale popisek přepínače se ve všech větvích odvozuje
  // od cíle příštího stisku (_fractionTargetKindAfterNextPress), nikdy
  // odsud. Tato funkce nikdy nerozhoduje o cíli akce.
  bool get _fractionBaseIsExact {
    if (_globalResultDisplayMode != ResultDisplayMode.text &&
        _globalResultDisplayMode != ResultDisplayMode.auto) {
      return false;
    }
    return _isSurdValid;
  }

  // Stack pozic '(' vložených tlačítkem NEG (±) – pro auto-uzavření
  final List<int> _pendingNegOpens = [];
  CalculatorMode _currentMode = CalculatorMode.scientific;
  CalculatorMode _defaultMode = CalculatorMode.scientific;
  List<int> _modeUsageCounts = List<int>.filled(
    CalculatorMode.values.length,
    0,
  );
  int _totalModeSwitches = 0;
  String? _lastSeenNewsVersion;
  int? _lastSuggestedMode;

  bool _updateDialogShown = false;
  bool _isDegreeMode = true;
  List<StatsSummarySection> _statsSummaryOrder = [
    StatsSummarySection.header,
    StatsSummarySection.dataValues,
    StatsSummarySection.computed,
  ];
  List<StatsComputedItem> _statsComputedOrder = [
    StatsComputedItem.mean,
    StatsComputedItem.sum,
    StatsComputedItem.variance,
    StatsComputedItem.sd,
    StatsComputedItem.median,
    StatsComputedItem.min,
    StatsComputedItem.max,
    StatsComputedItem.mode,
    StatsComputedItem.cv,
    StatsComputedItem.wmean,
  ];
  final bool _sayWelcome = true;
  bool _welcomeAnnounced = false;
  final Completer<bool> _ttsReady = Completer<bool>();
  // Dokončeno po načtení globálů + profilů (před stats/TTS). Startup draft
  // smí číst runtime stav teprve po tomto markeru, nikdy dřív.
  final Completer<void> _configLoaded = Completer<void>();
  void _markConfigLoaded() {
    if (!_configLoaded.isCompleted) _configLoaded.complete();
  }

  Future<void> get _waitForTtsReady async {
    if (_ttsReady.isCompleted) return;
    try {
      await _ttsReady.future.timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // --- Per-profile accessibility (nový model) ---
  String _activeProfileId = 'standard';
  List<AccessibilityProfile> _profiles = [];
  bool _profilesLoaded = false;

  // --- Globální nastavení vzhledu (nezávislé na profilu) ---
  // Jediný runtime source of truth pro výsledkový displej i historii
  // je _globalResultDisplayMode. Profily ho nikdy nečtou ani nezapisují
  // (pouze jednorázová migrace).
  ResultDisplayMode _globalResultDisplayMode = ResultDisplayMode.segment;
  // Legacy persistovaný údaj (persistence/contract/UI zachováno pro zpětnou
  // kompatibilitu). Není zdrojem pravdy pro aktivní renderer — aktivní
  // vykreslování historie řídí výhradně _globalResultDisplayMode.
  HistoryExactFormat _historyExactFormat = HistoryExactFormat.numeric;

  // --- Editing draft (oddělení aktivace × editace) ---
  String? _editingProfileId;
  AccessibilityProfile? _editingDraft;
  AccessibilitySettings? _editingPreviewSnapshot;
  ThemeMode? _editingPreviewThemeSnapshot;

  // Editing getters (pro UI / testy)
  AccessibilityProfile? get editingProfile => _editingDraft;
  String? get editingProfileId => _editingProfileId;

  // Aktivní nastavení – jediný zdroj pravdy (s preview když se edituje aktivní)
  AccessibilitySettings get activeAccessibilitySettings {
    if (_editingDraft != null && _editingProfileId == _activeProfileId) {
      return _editingDraft!.settings;
    }
    final p = _getActiveAccessibilityProfile();
    return p.settings;
  }

  // Bezpečné rozlišení aktivního profilu (s fallbackem)
  AccessibilityProfile _getActiveAccessibilityProfile() {
    for (final p in _profiles) {
      if (p.id == _activeProfileId) return p;
    }
    if (_profiles.isNotEmpty) return _profiles.first;
    try {
      final defaults = _defaultAccessibilityProfiles();
      for (final p in defaults) {
        if (p.id == _activeProfileId) return p;
      }
      if (defaults.isNotEmpty) return defaults.first;
    } catch (_) {}
    return _fallbackStandardProfile();
  }

  // Aktualizace nastavení aktivního profilu – jediný zápisový bod (zachován pro rychlé toggly mimo editor)
  // Pokud je otevřen draft aktivního profilu, přesměruje se do draftu aby nevznikla desynchronizace
  void updateActiveAccessibilitySettings(
    AccessibilitySettings Function(AccessibilitySettings current) update,
  ) {
    if (_editingDraft != null && _editingProfileId == _activeProfileId) {
      updateEditingSettings(update);
      return;
    }
    final idx = _profiles.indexWhere((p) => p.id == _activeProfileId);
    if (idx == -1) return;
    final current = _profiles[idx].settings;
    final updated = update(current);
    // deep copy ochrana je v copyWith
    setState(() {
      _profiles[idx] = _profiles[idx].copyWith(settings: updated);
    });
    _applySettingsToRuntime(updated, previous: current);
    _saveProfilesV2();
  }

  // Sjednocená aplikace runtime efektů (TTS, notifier, theme) – bez perzistence
  void _applySettingsToRuntime(
    AccessibilitySettings updated, {
    AccessibilitySettings? previous,
  }) {
    final prev = previous;
    _dialogFontScaleNotifier.value = updated.dialogFontScale;
    if (prev == null || updated.speechRate != prev.speechRate) {
      tts.setSpeechRate(updated.speechRate).catchError((e) {
        debugPrint('TTS setSpeechRate Error: $e');
      });
    }
    if (prev == null || updated.speechVolume != prev.speechVolume) {
      tts.setVolume(updated.speechVolume).catchError((e) {
        debugPrint('TTS setVolume Error: $e');
      });
    }
    if (prev == null || updated.ttsEngine != prev.ttsEngine) {
      if (!Platform.isWindows && updated.ttsEngine != null) {
        tts.setEngine(updated.ttsEngine!).catchError((e) {
          debugPrint('TTS setEngine Error: $e');
        });
      } else if (!Platform.isWindows &&
          updated.ttsEngine == null &&
          prev != null &&
          prev.ttsEngine != null) {
        // reset na výchozí engine není podporován, ponechat
      }
    }
    if (prev == null || updated.ttsVoice != prev.ttsVoice) {
      if (updated.ttsVoice != null) {
        tts.setVoice(updated.ttsVoice!).catchError((e) {
          debugPrint('TTS setVoice Error: $e');
        });
      } else {
        if (prev == null || prev.ttsVoice != null) {
          tts.clearVoice();
        }
      }
    }
    if (updated.accessibilityType == AccessibilityType.visuallyImpaired) {
      if (prev == null ||
          prev.accessibilityType != AccessibilityType.visuallyImpaired) {
        widget.onThemeModeChanged(ThemeMode.dark);
      }
    }
  }

  // === Editing draft API – 8 operací ===

  bool startEditingProfile(String id) {
    if (!_profilesLoaded) {
      debugPrint('startEditingProfile: profiles not loaded yet, id=$id');
      _showAccessibleSnackBar(
        _s(
          'Profily se ještě načítají, zkuste to znovu.',
          'Profiles are still loading, please try again.',
        ),
      );
      return false;
    }
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx == -1) {
      debugPrint('startEditingProfile: id not found: $id');
      _showAccessibleSnackBar(
        _s('Profil $id neexistuje.', 'Profile $id does not exist.'),
      );
      return false;
    }
    final src = _profiles[idx];
    _editingProfileId = src.id;
    _editingDraft = src.copyWith();
    if (src.id == _activeProfileId) {
      _editingPreviewSnapshot = src.settings.copyWith();
      _editingPreviewThemeSnapshot = widget.themeMode;
    } else {
      _editingPreviewSnapshot = null;
      _editingPreviewThemeSnapshot = null;
    }
    if (mounted) setState(() {});
    return true;
  }

  void updateEditingSettings(
    AccessibilitySettings Function(AccessibilitySettings current) update,
  ) {
    if (_editingDraft == null || _editingProfileId == null) return;
    final prevDraftSettings = _editingDraft!.settings;
    final updated = update(prevDraftSettings);
    _editingDraft = _editingDraft!.copyWith(settings: updated);
    if (_editingProfileId == _activeProfileId) {
      _applySettingsToRuntime(updated, previous: prevDraftSettings);
      if (mounted) setState(() {});
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<bool> saveEditingProfile() async {
    if (_editingDraft == null || _editingProfileId == null) {
      debugPrint('saveEditingProfile: no draft');
      return false;
    }
    final idx = _profiles.indexWhere((p) => p.id == _editingProfileId);
    if (idx == -1) {
      debugPrint('saveEditingProfile: id not found: $_editingProfileId');
      _showAccessibleSnackBar(
        _s(
          'Uložení selhalo – profil neexistuje.',
          'Save failed – profile does not exist.',
        ),
      );
      return false;
    }
    if (_profiles[idx].id != _editingProfileId) {
      debugPrint('saveEditingProfile: id mismatch');
      _showAccessibleSnackBar(
        _s(
          'Uložení selhalo – nesoulad profilu.',
          'Save failed – profile mismatch.',
        ),
      );
      return false;
    }
    final savedId = _editingProfileId!;
    final wasActive = savedId == _activeProfileId;
    setState(() {
      _profiles[idx] = _editingDraft!;
    });
    await _saveProfilesV2();
    if (wasActive) {
      _applySettingsToRuntime(_editingDraft!.settings);
      _applyActiveProfileToState();
    }
    _editingDraft = null;
    _editingProfileId = null;
    _editingPreviewSnapshot = null;
    _editingPreviewThemeSnapshot = null;
    if (mounted) setState(() {});
    return true;
  }

  void discardEditingProfile() {
    if (_editingProfileId == _activeProfileId &&
        _editingPreviewSnapshot != null) {
      _applySettingsToRuntime(
        _editingPreviewSnapshot!,
        previous: _editingDraft?.settings,
      );
      if (_editingPreviewThemeSnapshot != null &&
          _editingPreviewThemeSnapshot != widget.themeMode) {
        widget.onThemeModeChanged(_editingPreviewThemeSnapshot!);
      }
      _dialogFontScaleNotifier.value = _editingPreviewSnapshot!.dialogFontScale;
      if (mounted) setState(() {});
    }
    _editingDraft = null;
    _editingProfileId = null;
    _editingPreviewSnapshot = null;
    _editingPreviewThemeSnapshot = null;
    if (mounted) setState(() {});
  }

  Future<void> renameProfile(String id, String newName) async {
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    if (_profiles[idx].isBuiltIn) return;
    if (newName.trim().isEmpty) return;
    setState(
      () => _profiles[idx] = _profiles[idx].copyWith(name: newName.trim()),
    );
    await _saveProfilesV2();
    if (mounted) setState(() {});
  }

  Future<void> resetProfile(String id) async {
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    if (_editingProfileId == id && _editingDraft != null) {
      AccessibilitySettings defaults;
      if (id == 'blind') {
        defaults = AccessibilitySettings.defaultsBlind();
      } else if (id == 'lowvision') {
        defaults = AccessibilitySettings.defaultsLowVision();
      } else if (id == 'standard') {
        defaults = AccessibilitySettings.defaultsStandard();
      } else {
        defaults = AccessibilitySettings.defaultsStandard();
      }
      final prevDraftSettings = _editingDraft!.settings;
      _editingDraft = _editingDraft!.copyWith(settings: defaults.copyWith());
      if (id == _activeProfileId) {
        _applySettingsToRuntime(defaults, previous: prevDraftSettings);
      }
      // Snapshot zůstává původní před editací – Cancel vrátí původní stav (dokumentováno).
      // Save po resetu uloží defaults. Runtime již odpovídá draftu (defaults).
      if (mounted) setState(() {});
      return;
    }
    AccessibilitySettings defaults;
    if (id == 'blind') {
      defaults = AccessibilitySettings.defaultsBlind();
    } else if (id == 'lowvision') {
      defaults = AccessibilitySettings.defaultsLowVision();
    } else if (id == 'standard') {
      defaults = AccessibilitySettings.defaultsStandard();
    } else {
      defaults = AccessibilitySettings.defaultsStandard();
    }
    if (id == _activeProfileId) {
      updateActiveAccessibilitySettings((_) => defaults.copyWith());
    } else {
      setState(
        () => _profiles[idx] = _profiles[idx].copyWith(
          settings: defaults.copyWith(),
        ),
      );
      await _saveProfilesV2();
      if (mounted) setState(() {});
    }
  }

  void _applyActiveProfileToState() {
    final s = activeAccessibilitySettings;
    _dialogFontScaleNotifier.value = s.dialogFontScale;
  }

  // Read-only aliasy pro minimalizaci diffu (všechna čtení zůstanou funkční)
  AccessibilityType get _accessibilityType =>
      activeAccessibilitySettings.accessibilityType;
  ScreenReaderMode get _screenReaderMode =>
      activeAccessibilitySettings.screenReaderMode;
  double get _fontSizeMultiplier =>
      activeAccessibilitySettings.fontSizeMultiplier;
  double get _keyboardFontScale => _fontSizeMultiplier;
  double get _dotMatrixZoom => activeAccessibilitySettings.dotMatrixZoom;
  double get _resultZoom => activeAccessibilitySettings.resultZoom;
  ThousandGroupGap get _thousandGroupGap =>
      activeAccessibilitySettings.thousandGroupGap;
  double _thousandGroupGapBase() {
    switch (_thousandGroupGap) {
      case ThousandGroupGap.small:
        return 1.5;
      case ThousandGroupGap.medium:
        return 3.0;
      case ThousandGroupGap.large:
        return 6.0;
    }
  }

  double get _overlineThickness =>
      activeAccessibilitySettings.overlineThickness;
  double get _overlineHeight => activeAccessibilitySettings.overlineHeight;
  bool get _alignInputLeft => activeAccessibilitySettings.alignInputLeft;
  double get _dialogFontScale => activeAccessibilitySettings.dialogFontScale;
  late final ValueNotifier<double> _dialogFontScaleNotifier =
      ValueNotifier<double>(1.0);
  double get _speechRate => activeAccessibilitySettings.speechRate;
  double get _speechVolume => activeAccessibilitySettings.speechVolume;
  String? get _ttsEngine => activeAccessibilitySettings.ttsEngine;
  Map<String, String>? get _ttsVoice => activeAccessibilitySettings.ttsVoice;
  String? get _ttsVoiceName => activeAccessibilitySettings.ttsVoiceName;
  int? get _inverseFormatPreference =>
      activeAccessibilitySettings.inverseFormatPreference;
  bool get _useSixteenSegment => activeAccessibilitySettings.useSixteenSegment;
  // Globál je jediný zdroj pravdy — profilová hodnota se ignoruje.
  ResultDisplayMode get _resultDisplayMode => _globalResultDisplayMode;

  void setGlobalResultDisplayMode(ResultDisplayMode m) {
    if (_globalResultDisplayMode == m) return;
    setState(() => _globalResultDisplayMode = m);
    unawaited(_saveGlobalSettings());
  }

  void setHistoryExactFormat(HistoryExactFormat f) {
    if (_historyExactFormat == f) return;
    setState(() => _historyExactFormat = f);
    unawaited(_saveGlobalSettings());
  }

  String _resultDisplayModeName(ResultDisplayMode m) {
    switch (m) {
      case ResultDisplayMode.segment:
        return _s('Segmentový', 'Segment');
      case ResultDisplayMode.text:
        return _s('Matematický text', 'Math text');
      case ResultDisplayMode.auto:
        return _s('Automatický', 'Automatic');
    }
  }

  String _historyExactFormatName(HistoryExactFormat f) {
    switch (f) {
      case HistoryExactFormat.numeric:
        return _s('Číselně', 'Numeric');
      case HistoryExactFormat.exact:
        return _s('Exaktně (6√2)', 'Exact (6√2)');
    }
  }

  /// Jednotné přístupné oznámení: čtečka -> Semantics kanál, jinak vlastní TTS.
  /// Nikdy obojí (prevence duplicit na TalkBacku/NVDA).
  /// Tenká obálka nad [announceEvent] pro zpětnou kompatibilitu.
  void say(String message, [BuildContext? ctx]) {
    if (message.isEmpty || !mounted) return;
    unawaited(
      announceEvent(message, category: SpeechCategory.actionConfirm),
    );
  }

  bool get _announceExpression =>
      activeAccessibilitySettings.announceExpression;
  bool get _readStatsMemoryValues =>
      activeAccessibilitySettings.readStatsMemoryValues;
  bool get _autoReadStatsSummary =>
      activeAccessibilitySettings.autoReadStatsSummary;
  bool get _showStatsNavigationHint =>
      activeAccessibilitySettings.showStatsNavigationHint;
  DialogSize get _dialogSize => activeAccessibilitySettings.dialogSize;
  bool get ttsEnabled => activeAccessibilitySettings.ttsEnabled;
  // pro zpětnou kompatibilitu s testy / starým voláním setteru
  set _keyboardFontScale(double v) => updateActiveAccessibilitySettings(
    (s) => s.copyWith(fontSizeMultiplier: v),
  );

  /// Detekce čtečky (R5): null = UNKNOWN (ještě neproběhla detekce).
  /// Při UNKNOWN se vlastní TTS nespouští, aby nemohlo dojít k double-speech.
  bool? _accessibleNavigation;
  int _srRefreshSeq = 0;
  bool? _lastMqAccessibleNavigation;

  /// Dedikovaný oznamovací liveRegion (primární kanál při aktivní čtečce
  /// na Androidu; fallback na Windows). Změna hodnoty = jedno oznámení.
  String _lastAnnouncement = '';

  /// Poslední publikované oznámení bez ohledu na kanál (i pro testy).
  String _lastPublishedAnnouncement = '';

  /// Počet publikování Semantics kanálem (Z3-krok 0, pouze pro testy).
  /// Inkrementuje se při každém zveřejnění v [_publishSemanticsAnnouncement],
  /// včetně opakovaného zveřejnění stejného textu. Nemá vliv na výběr
  /// kanálu, obsah zpráv ani chování čtečky — měří publikování na straně
  /// aplikace, nikoli skutečný počet vyslovení NVDA/TalkBack.
  int _publishedAnnouncementCount = 0;

  bool _scientificFunctionsPage = false;
  String? _scientificPageAnnouncement;

  DisplayFormat _displayFormat = DisplayFormat.standard;

  // Vývojářský režim (skrytý)
  bool _devModeEnabled = false;
  bool _devAutoDiagnosticEnabled = false;
  int _devDiagnosticDurationMs = 700;
  String? _devPinCode;
  int _devTapCount = 0;
  Timer? _devTapTimer;
  int _devPinFails = 0;
  DateTime? _devPinLockUntil;
  bool _devAutoDiagShown = false;

  double _responsiveScale(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final s = shortest / 360.0;
    // Horní mez 1.15 (dříve 1.7): na desktopovém okně je nejmenší strana
    // VÝŠKA okna (685+), takže starý clamp 1.7 inflated rám displeje
    // (margin 8*s + padding 8*s + border + název 12*s + mezera 4*s ≈ 93 log)
    // nad skutečný slot displeje ≈ 92,5 log -> availableH ≈ 0 a obsah
    // displeje (bodová mřížka + segmentový výsledek) se nevykreslil.
    // Telefony se stranou <= 414 dp (414/360 = 1.15) zůstávají beze změny.
    return s.clamp(1.0, 1.15);
  }

  void _scheduleInputAutoscroll() {
    if (!_alignInputLeft) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollControllerH.hasClients) return;
      final pos = _scrollControllerH.position;
      if (pos.maxScrollExtent <= 0) return;
      // Scroll to cursor position proportionally; if cursor at end -> maxExtent
      // For visual thousands grouping we use a gap-aware estimate so that
      // extra spacing between digit groups shifts the target correctly.
      final totalLen = display.length + 1; // +1 for cursor marker
      double progress;
      if (_cursorPosition == display.length) {
        progress = 1.0;
      } else {
        // Estimate visual width proportion accounting for thousand gaps.
        final gaps = computeThousandGapIndicesForDisplay(display);
        final gapsBeforeCursor = gaps.where((g) => g < _cursorPosition).length;
        final totalGaps = gaps.length;
        // Each gap adds extra visual width: approximate as 0.6 of a char
        // width for the default (medium) gap (calibrated for base 3.0);
        // scale linearly with the selected group-gap base.
        final gapWeight = 0.6 * _thousandGroupGapBase() / 3.0;
        final visualCursor = _cursorPosition + gapsBeforeCursor * gapWeight;
        final visualTotal = totalLen + totalGaps * gapWeight;
        progress = visualTotal == 0 ? 1.0 : visualCursor / visualTotal;
      }
      final target = (pos.maxScrollExtent * progress).clamp(
        0.0,
        pos.maxScrollExtent,
      );
      // Prefer maxExtent when cursor at end for typical typing
      final finalTarget = _cursorPosition == display.length
          ? pos.maxScrollExtent
          : target;
      if ((pos.pixels - finalTarget).abs() > 1) {
        _scrollControllerH.animateTo(
          finalTarget,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _usePeriodicNotation = true;
  int _precision = 2;
  double? _lastNumericValue;
  // Monotónní generace výsledku: razítko platnosti _lastExact a zlomkového
  // override. NENÍ zdrojem hodnoty — hodnota žije v _lastExact, resp.
  // v _lastNumericValue. Každý zápis nového výsledku/chyby/vymazání generaci
  // inkrementuje; čistě formátová změna (dialog přesnosti) ji nemění a pouze
  // překlíčuje _lastExactKey.
  int _resultGeneration = 0;
  int _lastExactGeneration = -1;
  // --- Prezentační zlomkový náhled (DEC <-> a/b) ---
  // Čistě prezentační stav: _fractionOverride nikdy nepřepisuje _lastResult,
  // _lastNumericValue, ANS, historii ani exact metadata. Význam:
  // null = řídit se základem režimu (segment vždy desetinně, text/auto
  // ukazují platný netriviální RationalValue jako n/d), true = vynutit
  // zlomek, false = vynutit desetinné. Zastaralý override (jiný klíč nebo
  // generace výsledku) se chová jako null — samotné false bez platného
  // klíče nikdy nevynucuje zastaralou reprezentaci.
  // _fractionViewKey + _fractionViewGeneration vážou override ke konkrétnímu
  // výsledku, takže jakýkoliv nový výsledek záměr automaticky zneplatní.
  bool? _fractionOverride;
  String _fractionViewKey = '';
  int _fractionViewGeneration = -1;
  // Stavový příznak způsobilosti: true pouze pro běžný numerický výsledek
  // (basic/scientific, standardní formát, bez DMS/jednotek/měny/času).
  // Nikdy se neodvozuje parsováním textu _lastResult.
  bool _lastResultIsPlainNumeric = false;
  ElectricianCalculation _selectedElectricianCalculation =
      ElectricianCalculation.resistance;

  // --- Měnový režim ---
  Map<String, double> _currencyRates = {
    'CZK': 1.0,
    'EUR': 24.55,
    'USD': 22.10,
    'GBP': 28.30,
    'PLN': 5.60,
    'HUF': 0.064,
    'CHF': 26.00,
    'JPY': 0.15,
  };
  String _currencyFrom = 'CZK';
  String _currencyTo = 'EUR';
  DateTime? _currencyLastUpdate;
  bool _currencyLoading = false;

  final Map<String, Map<String, dynamic>> _currencySpeechData = {
    'CZK': {
      'base': 'koruna',
      'forms': ['koruna', 'koruny', 'korun', 'koruny'],
    },
    'EUR': {
      'base': 'euro',
      'forms': ['euro', 'eura', 'eur', 'eura'],
    },
    'USD': {
      'base': 'dolar',
      'forms': ['dolar', 'dolary', 'dolarů', 'dolaru'],
    },
    'GBP': {
      'base': 'libra',
      'forms': ['libra', 'libry', 'liber', 'libry'],
    },
    'PLN': {
      'base': 'zlotý',
      'forms': ['zlotý', 'zloté', 'zlotých', 'zlotého'],
    },
    'HUF': {
      'base': 'forint',
      'forms': ['forint', 'forinty', 'forintů', 'forintu'],
    },
    'CHF': {
      'base': 'frank',
      'forms': ['frank', 'franky', 'franků', 'franku'],
    },
    'JPY': {
      'base': 'jen',
      'forms': ['jen', 'jeny', 'jenů', 'jenu'],
    },
  };

  final Map<String, Map<String, String>> _currencySpeechDataEn = {
    'CZK': {'base': 'koruna', 'plural': 'korunas'},
    'EUR': {'base': 'euro', 'plural': 'euros'},
    'USD': {'base': 'dollar', 'plural': 'dollars'},
    'GBP': {'base': 'pound', 'plural': 'pounds'},
    'PLN': {'base': 'zloty', 'plural': 'zlotys'},
    'HUF': {'base': 'forint', 'plural': 'forints'},
    'CHF': {'base': 'franc', 'plural': 'francs'},
    'JPY': {'base': 'yen', 'plural': 'yen'},
  };

  String? _lastTtsLocale;

  final Map<String, double> _memory = {
    'A': 0,
    'B': 0,
    'C': 0,
    'D': 0,
    'E': 0,
    'F': 0,
    'X': 0,
    'Y': 0,
    'M': 0,
  };

  /// Evidence obsazenosti paměťových proměnných (včetně explicitně uložené 0).
  /// Samotná číselná hodnota v [_memory] prázdnou proměnnou od uložené nuly
  /// nerozliší, proto se při každém úspěšném uložení přidá jméno proměnné sem.
  /// Maže se společně s [_memory]. Persistuje se samostatným klíčem
  /// 'memoryOccupied' (formát `memoryVariables` se nemění).
  final Set<String> _memoryOccupied = {};

  /// Kanonické pořadí paměťových proměnných A,B,C,D,E,F,X,Y,M.
  static const List<String> _memoryOrder = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'X',
    'Y',
    'M',
  ];

  // Paralelní racionální vazba paměťových proměnných (pouze pro hodnoty
  // uložené z platného exaktního výsledku). _memory zůstává jediným
  // persistovaným úložištěm (double); tato mapa je runtime-only a po
  // restartu se bezpečně chová jako prázdná (fallback na double).
  // Mazána společně s _memory, klíčována jménem proměnné (nepřetrvává
  // napříč přepsáním hodnoty jiným zdrojem).
  final Map<String, Rational> _rationalMemory = {};

  final List<StatisticsSet> _statsSets = [];
  final List<StatisticsFolder> _statsFolders = [];
  int _currentStatsSetIndex = 0;
  int _selectedFieldIndex = 0;
  List<StatisticsRecord> _lastAddedBatch = [];
  bool _statsSummaryInitialized = false;
  _VoiceSetCreationSession? _voiceCreationSession;

  // --- Organizace sad: barvy, ikony, složky ---
  static const List<Color> _statsPalette = [
    Color(0xFF42A5F5), // modrá
    Color(0xFF66BB6A), // zelená
    Color(0xFFFFA726), // oranžová
    Color(0xFFEF5350), // červená
    Color(0xFFAB47BC), // fialová
    Color(0xFF26C6DA), // tyrkysová
    Color(0xFFFFCA28), // žlutá
    Color(0xFF8D6E63), // hnědá
  ];
  static const List<String> _statsIconNames = [
    'dataset',
    'school',
    'work',
    'home',
    'lab',
    'chart',
    'folder',
    'star',
  ];
  static const Map<String, IconData> _statsIconMap = {
    'dataset': Icons.dataset,
    'school': Icons.school,
    'work': Icons.work,
    'home': Icons.home,
    'lab': Icons.science,
    'chart': Icons.bar_chart,
    'folder': Icons.folder,
    'star': Icons.star,
  };
  Color _statsColorFor(int idx) =>
      _statsPalette[idx.clamp(0, _statsPalette.length - 1)];
  IconData _statsIconFor(String name) => _statsIconMap[name] ?? Icons.dataset;
  String _statsFolderName(String? folderId) {
    if (folderId == null) return _s('Bez složky', 'No folder');
    final f = _statsFolders.where((e) => e.id == folderId).toList();
    if (f.isEmpty) return _s('Bez složky', 'No folder');
    return f.first.name;
  }

  bool get _hasStatsSet => _statsSets.isNotEmpty;

  List<StatisticsRecord> get _statsMemory {
    if (_statsSets.isEmpty) return const [];
    return _statsSets[_currentStatsSetIndex].records;
  }

  int get _currentFieldCount {
    if (_statsSets.isEmpty) return 1;
    return _statsSets[_currentStatsSetIndex].fieldNames.length;
  }

  List<double> _getFieldValues(int fieldIndex) {
    return _statsMemory.map((r) => r.values[fieldIndex]).toList();
  }

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
    'Objem': {
      'l': 1.0,
      'ml': 0.001,
      'm³': 1000.0,
      'gal': 3.78541,
      'pt': 0.473176,
    },
    'Tlak': {
      'Pa': 1.0,
      'hPa': 100.0,
      'kPa': 1000.0,
      'bar': 100000.0,
      'atm': 101325.0,
      'psi': 6894.76,
    },
    'Čas': {'s': 1.0, 'min': 60.0, 'h': 3600.0, 'd': 86400.0},
    'Napětí': {
      'V': 1.0,
      'mV': 0.001,
      'µV': 0.000001,
      'kV': 1000.0,
      'MV': 1000000.0,
    },
    'Proud': {'A': 1.0, 'mA': 0.001, 'µA': 0.000001, 'kA': 1000.0},
    'Odpor': {'Ω': 1.0, 'mΩ': 0.001, 'kΩ': 1000.0, 'MΩ': 1000000.0},
    'Výkon': {
      'W': 1.0,
      'mW': 0.001,
      'kW': 1000.0,
      'MW': 1000000.0,
      'GW': 1000000000.0,
    },
  };

  final ScrollController _scrollControllerH = ScrollController();
  final ScrollController _scrollControllerResultH = ScrollController();
  final ScrollController _scrollControllerV = ScrollController();

  final Map<String, Map<String, dynamic>> _unitSpeechData = {
    'm': {
      'base': 'metr',
      'z': 'metrů',
      'na': 'metry',
      'forms': ['metr', 'metry', 'metrů', 'metru'],
    },
    'km': {
      'base': 'kilometr',
      'z': 'kilometrů',
      'na': 'kilometry',
      'forms': ['kilometr', 'kilometry', 'kilometrů', 'kilometru'],
    },
    'cm': {
      'base': 'centimetr',
      'z': 'centimetrů',
      'na': 'centimetry',
      'forms': ['centimetr', 'centimetry', 'centimetrů', 'centimetru'],
    },
    'mm': {
      'base': 'milimetr',
      'z': 'milimetrů',
      'na': 'milimetry',
      'forms': ['milimetr', 'milimetry', 'milimetrů', 'milimetru'],
    },
    'mi': {
      'base': 'míle',
      'z': 'mil',
      'na': 'míle',
      'forms': ['míle', 'míle', 'mil', 'míle'],
    },
    'yd': {
      'base': 'yard',
      'z': 'yardů',
      'na': 'yardy',
      'forms': ['yard', 'yardy', 'yardů', 'yardu'],
    },
    'ft': {
      'base': 'stopa',
      'z': 'stop',
      'na': 'stopy',
      'forms': ['stopa', 'stopy', 'stop', 'stopy'],
    },
    'in': {
      'base': 'palec',
      'z': 'palců',
      'na': 'palce',
      'forms': ['palec', 'palce', 'palců', 'palce'],
    },
    'kg': {
      'base': 'kilogram',
      'z': 'kilogramů',
      'na': 'kilogramy',
      'forms': ['kilogram', 'kilogramy', 'kilogramů', 'kilogramu'],
    },
    'g': {
      'base': 'gram',
      'z': 'gramů',
      'na': 'gramy',
      'forms': ['gram', 'gramy', 'gramů', 'gramu'],
    },
    'mg': {
      'base': 'miligram',
      'z': 'miligramů',
      'na': 'miligramy',
      'forms': ['miligram', 'miligramy', 'miligramů', 'miligramu'],
    },
    't': {
      'base': 'tuna',
      'z': 'tun',
      'na': 'tuny',
      'forms': ['tuna', 'tuny', 'tun', 'tuny'],
    },
    'lb': {
      'base': 'libra',
      'z': 'liber',
      'na': 'libry',
      'forms': ['libra', 'libry', 'liber', 'libry'],
    },
    'oz': {
      'base': 'unce',
      'z': 'uncí',
      'na': 'unce',
      'forms': ['unce', 'unce', 'uncí', 'unce'],
    },
    'm²': {
      'base': 'metr čtvereční',
      'z': 'metrů čtverečních',
      'na': 'metry čtvereční',
      'forms': [
        'metr čtvereční',
        'metry čtvereční',
        'metrů čtverečních',
        'metru čtverečního',
      ],
    },
    'km²': {
      'base': 'kilometr čtvereční',
      'z': 'kilometrů čtverečních',
      'na': 'kilometry čtvereční',
      'forms': [
        'kilometr čtvereční',
        'kilometry čtvereční',
        'kilometrů čtverečních',
        'kilometru čtverečního',
      ],
    },
    'ha': {
      'base': 'hektar',
      'z': 'hektarů',
      'na': 'hektary',
      'forms': ['hektar', 'hektary', 'hektarů', 'hektaru'],
    },
    'cm²': {
      'base': 'centimetr čtvereční',
      'z': 'centimetrů čtverečních',
      'na': 'centimetry čtvereční',
      'forms': [
        'centimetr čtvereční',
        'centimetry čtvereční',
        'centimetrů čtverečních',
        'centimetru čtverečního',
      ],
    },
    'akr': {
      'base': 'akr',
      'z': 'akrů',
      'na': 'akry',
      'forms': ['akr', 'akry', 'akrů', 'akru'],
    },
    'l': {
      'base': 'litr',
      'z': 'litrů',
      'na': 'litry',
      'forms': ['litr', 'litry', 'litrů', 'litru'],
    },
    'ml': {
      'base': 'mililitr',
      'z': 'mililitrů',
      'na': 'mililitry',
      'forms': ['mililitr', 'mililitry', 'mililitrů', 'mililitru'],
    },
    'm³': {
      'base': 'metr krychlový',
      'z': 'metrů krychlových',
      'na': 'metry krychlové',
      'forms': [
        'metr krychlový',
        'metry krychlové',
        'metrů krychlových',
        'metru krychlového',
      ],
    },
    'gal': {
      'base': 'galon',
      'z': 'galonů',
      'na': 'galony',
      'forms': ['galon', 'galony', 'galonů', 'galonu'],
    },
    'pt': {
      'base': 'pinta',
      'z': 'pint',
      'na': 'pinty',
      'forms': ['pinta', 'pinty', 'pint', 'pinty'],
    },
    'Pa': {
      'base': 'pascal',
      'z': 'pascalů',
      'na': 'pascaly',
      'forms': ['pascal', 'pascaly', 'pascalů', 'pascalu'],
    },
    'hPa': {
      'base': 'hektopascal',
      'z': 'hektopascalů',
      'na': 'hektopascaly',
      'forms': ['hektopascal', 'hektopascaly', 'hektopascalů', 'hektopascalu'],
    },
    'kPa': {
      'base': 'kilopascal',
      'z': 'kilopascalů',
      'na': 'kilopascaly',
      'forms': ['kilopascal', 'kilopascaly', 'kilopascalů', 'kilopascalu'],
    },
    'bar': {
      'base': 'bar',
      'z': 'barů',
      'na': 'bary',
      'forms': ['bar', 'bary', 'barů', 'baru'],
    },
    'atm': {
      'base': 'atmosféra',
      'z': 'atmosfér',
      'na': 'atmosféry',
      'forms': ['atmosféra', 'atmosféry', 'atmosfér', 'atmosféry'],
    },
    'psi': {
      'base': 'libra na čtvereční palec',
      'z': 'liber na čtvereční palec',
      'na': 'libry na čtvereční palec',
      'forms': [
        'libra na čtvereční palec',
        'libry na čtvereční palec',
        'liber na čtvereční palec',
        'libry na čtvereční palec',
      ],
    },
    's': {
      'base': 'sekunda',
      'z': 'sekund',
      'na': 'sekundy',
      'forms': ['sekunda', 'sekundy', 'sekund', 'sekundy'],
    },
    'min': {
      'base': 'minuta',
      'z': 'minut',
      'na': 'minuty',
      'forms': ['minuta', 'minuty', 'minut', 'minuty'],
    },
    'h': {
      'base': 'hodina',
      'z': 'hodin',
      'na': 'hodiny',
      'forms': ['hodina', 'hodiny', 'hodin', 'hodiny'],
    },
    'd': {
      'base': 'den',
      'z': 'dní',
      'na': 'dny',
      'forms': ['den', 'dny', 'dní', 'dne'],
    },
    'V': {
      'base': 'volt',
      'z': 'voltů',
      'na': 'volty',
      'forms': ['volt', 'volty', 'voltů', 'voltu'],
    },
    'mV': {
      'base': 'milivolt',
      'z': 'milivoltů',
      'na': 'milivolty',
      'forms': ['milivolt', 'milivolty', 'milivoltů', 'milivoltu'],
    },
    'µV': {
      'base': 'mikrovolt',
      'z': 'mikrovoltů',
      'na': 'mikrovolty',
      'forms': ['mikrovolt', 'mikrovolty', 'mikrovoltů', 'mikrovoltu'],
    },
    'kV': {
      'base': 'kilovolt',
      'z': 'kilovoltů',
      'na': 'kilovolty',
      'forms': ['kilovolt', 'kilovolty', 'kilovoltů', 'kilovoltu'],
    },
    'MV': {
      'base': 'megavolt',
      'z': 'megavoltů',
      'na': 'megavolty',
      'forms': ['megavolt', 'megavolty', 'megavoltů', 'megavoltu'],
    },
    'A': {
      'base': 'ampér',
      'z': 'ampérů',
      'na': 'ampéry',
      'forms': ['ampér', 'ampéry', 'ampérů', 'ampéru'],
    },
    'mA': {
      'base': 'miliampér',
      'z': 'miliampérů',
      'na': 'miliampéry',
      'forms': ['miliampér', 'miliampéry', 'miliampérů', 'miliampéru'],
    },
    'µA': {
      'base': 'mikroampér',
      'z': 'mikroampérů',
      'na': 'mikroampéry',
      'forms': ['mikroampér', 'mikroampéry', 'mikroampérů', 'mikroampéru'],
    },
    'kA': {
      'base': 'kiloampér',
      'z': 'kiloampérů',
      'na': 'kiloampéry',
      'forms': ['kiloampér', 'kiloampéry', 'kiloampérů', 'kiloampéru'],
    },
    'Ω': {
      'base': 'ohm',
      'z': 'ohmů',
      'na': 'ohmy',
      'forms': ['ohm', 'ohmy', 'ohmů', 'ohmu'],
    },
    'mΩ': {
      'base': 'miliohm',
      'z': 'miliohmů',
      'na': 'miliohmy',
      'forms': ['miliohm', 'miliohmy', 'miliohmů', 'miliohmu'],
    },
    'kΩ': {
      'base': 'kiloohm',
      'z': 'kiloohmů',
      'na': 'kiloohmy',
      'forms': ['kiloohm', 'kiloohmy', 'kiloohmů', 'kiloohmu'],
    },
    'MΩ': {
      'base': 'megaohm',
      'z': 'megaohmů',
      'na': 'megaohmy',
      'forms': ['megaohm', 'megaohmy', 'megaohmů', 'megaohmu'],
    },
    'W': {
      'base': 'watt',
      'z': 'wattů',
      'na': 'watty',
      'forms': ['watt', 'watty', 'wattů', 'wattu'],
    },
    'mW': {
      'base': 'miliwatt',
      'z': 'miliwattů',
      'na': 'miliwatty',
      'forms': ['miliwatt', 'miliwatty', 'miliwattů', 'miliwattu'],
    },
    'kW': {
      'base': 'kilowatt',
      'z': 'kilowattů',
      'na': 'kilowatty',
      'forms': ['kilowatt', 'kilowatty', 'kilowattů', 'kilowattu'],
    },
    'MW': {
      'base': 'megawatt',
      'z': 'megawattů',
      'na': 'megawatty',
      'forms': ['megawatt', 'megawatty', 'megawattů', 'megawattu'],
    },
    'GW': {
      'base': 'gigawatt',
      'z': 'gigawattů',
      'na': 'gigawatty',
      'forms': ['gigawatt', 'gigawatty', 'gigawattů', 'gigawattu'],
    },
  };

  final Map<String, Map<String, String>> _unitSpeechDataEn = {
    'm': {'base': 'meter', 'plural': 'meters'},
    'km': {'base': 'kilometer', 'plural': 'kilometers'},
    'cm': {'base': 'centimeter', 'plural': 'centimeters'},
    'mm': {'base': 'millimeter', 'plural': 'millimeters'},
    'mi': {'base': 'mile', 'plural': 'miles'},
    'yd': {'base': 'yard', 'plural': 'yards'},
    'ft': {'base': 'foot', 'plural': 'feet'},
    'in': {'base': 'inch', 'plural': 'inches'},
    'kg': {'base': 'kilogram', 'plural': 'kilograms'},
    'g': {'base': 'gram', 'plural': 'grams'},
    'mg': {'base': 'milligram', 'plural': 'milligrams'},
    't': {'base': 'tonne', 'plural': 'tonnes'},
    'lb': {'base': 'pound', 'plural': 'pounds'},
    'oz': {'base': 'ounce', 'plural': 'ounces'},
    'm²': {'base': 'square meter', 'plural': 'square meters'},
    'km²': {'base': 'square kilometer', 'plural': 'square kilometers'},
    'ha': {'base': 'hectare', 'plural': 'hectares'},
    'cm²': {'base': 'square centimeter', 'plural': 'square centimeters'},
    'akr': {'base': 'acre', 'plural': 'acres'},
    'l': {'base': 'liter', 'plural': 'liters'},
    'ml': {'base': 'milliliter', 'plural': 'milliliters'},
    'm³': {'base': 'cubic meter', 'plural': 'cubic meters'},
    'gal': {'base': 'gallon', 'plural': 'gallons'},
    'pt': {'base': 'pint', 'plural': 'pints'},
    'Pa': {'base': 'pascal', 'plural': 'pascals'},
    'hPa': {'base': 'hectopascal', 'plural': 'hectopascals'},
    'kPa': {'base': 'kilopascal', 'plural': 'kilopascals'},
    'bar': {'base': 'bar', 'plural': 'bars'},
    'atm': {'base': 'atmosphere', 'plural': 'atmospheres'},
    'psi': {'base': 'psi', 'plural': 'psi'},
    's': {'base': 'second', 'plural': 'seconds'},
    'min': {'base': 'minute', 'plural': 'minutes'},
    'h': {'base': 'hour', 'plural': 'hours'},
    'd': {'base': 'day', 'plural': 'days'},
    'V': {'base': 'volt', 'plural': 'volts'},
    'mV': {'base': 'millivolt', 'plural': 'millivolts'},
    'µV': {'base': 'microvolt', 'plural': 'microvolts'},
    'kV': {'base': 'kilovolt', 'plural': 'kilovolts'},
    'MV': {'base': 'megavolt', 'plural': 'megavolts'},
    'A': {'base': 'ampere', 'plural': 'amperes'},
    'mA': {'base': 'milliampere', 'plural': 'milliamperes'},
    'µA': {'base': 'microampere', 'plural': 'microamperes'},
    'kA': {'base': 'kiloampere', 'plural': 'kiloamperes'},
    'Ω': {'base': 'ohm', 'plural': 'ohms'},
    'mΩ': {'base': 'milliohm', 'plural': 'milliohms'},
    'kΩ': {'base': 'kilohm', 'plural': 'kilohms'},
    'MΩ': {'base': 'megohm', 'plural': 'megohms'},
    'W': {'base': 'watt', 'plural': 'watts'},
    'mW': {'base': 'milliwatt', 'plural': 'milliwatts'},
    'kW': {'base': 'kilowatt', 'plural': 'kilowatts'},
    'MW': {'base': 'megawatt', 'plural': 'megawatts'},
    'GW': {'base': 'gigawatt', 'plural': 'gigawatts'},
  };

  String _selectedUnitCategory = 'Délka';
  String _unitFrom = 'm';
  String _unitTo = 'km';
  List<CalculationHistoryEntry> _history = [];
  bool _isStoreMode = false;
  bool _isRecallMode = false;
  bool _hasResult = false;

  final Map<String, List<String>> _buttonNames = {
    'SIN': ['Sinus', 'Sine'],
    'COS': ['Kosinus', 'Cosine'],
    'TAN': ['Tangens', 'Tangent'],
    'ASIN': ['Arkus sinus', 'Arcsine'],
    'ACOS': ['Arkus kosinus', 'Arccosine'],
    'ATAN': ['Arkus tangens', 'Arctangent'],
    'ABS': ['Absolutní hodnota', 'Absolute value'],
    '°→\'': ['Převod na DMS', 'Convert to DMS'],
    '\'→°': ['Převod na stupně', 'Convert to degrees'],
    '°→RAD': ['Převod stupňů na radiány', 'Convert degrees to radians'],
    'RAD→°': ['Převod radiánů na stupně', 'Convert radians to degrees'],
    'DMS': ['Vložit DMS', 'Insert DMS'],
    '=': ['Rovná se', 'Equals'],
    '/': ['Lomeno', 'Over'],
    '*': ['Krát', 'Times'],
    '-': ['Mínus', 'Minus'],
    '+': ['Plus', 'Plus'],
    '(': ['Závorka otevřená', 'Open parenthesis'],
    ')': ['Závorka zavřená', 'Close parenthesis'],
    '.': ['Tečka', 'Decimal point'],
    '…': ['Periodické číslo', 'Repeating decimal'],
    '^': ['Mocnina', 'Power'],
    '√': ['Odmocnina', 'Square root'],
    'ⁿ√': ['En-tá odmocnina', 'Nth root'],
    'x²': ['Na druhou', 'Squared'],
    'x³': ['Na třetí', 'Cubed'],
    '∛': ['Třetí odmocnina', 'Cube root'],
    '1/x': ['Převrácená hodnota', 'Reciprocal'],
    'LOG': ['Logaritmus', 'Logarithm'],
    'LN': ['Přirozený logaritmus', 'Natural logarithm'],
    'X': ['Proměnná X', 'Variable X'],
    'Y': ['Proměnná Y', 'Variable Y'],
    'A': ['Proměnná A', 'Variable A'],
    'B': ['Proměnná B', 'Variable B'],
    'D': ['Proměnná D', 'Variable D'],
    'E': ['Proměnná E', 'Variable E'],
    'F': ['Proměnná F', 'Variable F'],
    'M': ['Proměnná M', 'Variable M'],
    'ANS': ['Poslední výsledek', 'Last answer'],
    'STO': ['Uložit do paměti', 'Store in memory'],
    'DEL': ['Smazat poslední', 'Delete last'],
    'RCL': ['Vyvolat z paměti', 'Recall from memory'],
    'CLR': ['Smazat celou paměť', 'Clear memory'],
    'C': ['Smazat displej', 'Clear display'],
    'DEG': ['Stupně', 'Degrees'],
    'RAD': ['Radiány', 'Radians'],
    '%': ['Procenta', 'Percent'],
    'SD': ['Směrodatná odchylka', 'Standard deviation'],
    'VAR': ['Rozptyl', 'Variance'],
    'MEAN': ['Průměr', 'Mean'],
    'STATS': ['Statistický souhrn', 'Statistics summary'],
    'M+': ['Přidat do statistické paměti', 'Add to statistics memory'],
    'MC': ['Smazat statistickou paměť', 'Clear statistics memory'],
    'MR': ['Vyvolat ze statistické paměti', 'Recall statistics memory'],
    'MED': ['Medián', 'Median'],
    'MODE': ['Modus', 'Mode'],
    'CV': ['Variační koeficient', 'Coefficient of variation'],
    'WMEAN': ['Vážený průměr', 'Weighted mean'],
    'MIN': ['Minimum', 'Minimum'],
    'MAX': ['Maximum', 'Maximum'],
    'SETS': ['Správa sad', 'Manage sets'],
    'PCT': ['Kolik procent', 'What percent'],
    'SUM': ['Součet hodnot', 'Sum of values'],
    ';': ['Oddělovač dat', 'Data separator'],
    '!': ['Faktoriál', 'Factorial'],
    '(-)': ['Záporné číslo se závorkou', 'Negative in parentheses'],
    '±': ['Záporné číslo', 'Negative number'],
    'EXP': ['krát deset na', 'times ten to'],
    'OHM_V': ['Napětí', 'Voltage'],
    'OHM_I': ['Proud', 'Current'],
    'OHM_R': ['Odpor', 'Resistance'],
    'PWR_P': ['Výkon', 'Power'],
    'PAR': ['Paralelně', 'In parallel'],
    'SER': ['Sériově', 'In series'],
    'Hz': ['Hertz', 'Hertz'],
    'μ': ['Mikro', 'Micro'],
    'n': ['Nano', 'Nano'],
    'p': ['Piko', 'Pico'],
    ':': ['Dvojtečka', 'Colon'],
    'NOW': ['Aktuální čas', 'Current time'],
    'TEĎ': ['Aktuální čas', 'Current time'],
    'DIFF': ['Rozdíl časů', 'Time difference'],
    'ROZDÍL': ['Rozdíl časů', 'Time difference'],
    'TO_SEC': ['Na sekundy', 'To seconds'],
    'NA SEKUNDY': ['Na sekundy', 'To seconds'],
    'TO_HMS': ['Na čas', 'To time'],
    'NA ČAS': ['Na čas', 'To time'],
  };

  double _factorial(int n) {
    if (n < 0) return double.nan;
    if (n == 0) return 1;
    if (n > 20)
      return double.infinity; // Omezení pro double přesnost a prevenci záseku
    double res = 1;
    for (int i = 1; i <= n; i++) {
      res *= i;
    }
    return res;
  }

  Map<String, dynamic> _getScaledValueAndPrefix(double value) {
    double absValue = value.abs();
    if (absValue == 0) return {'value': value, 'prefix': ''};
    if (absValue >= 1e9) return {'value': value / 1e9, 'prefix': 'giga'};
    if (absValue >= 1e6) return {'value': value / 1e6, 'prefix': 'mega'};
    if (absValue >= 1e3) return {'value': value / 1e3, 'prefix': 'kilo'};
    if (absValue >= 1) return {'value': value, 'prefix': ''};
    if (absValue >= 1e-3) return {'value': value * 1e3, 'prefix': 'mili'};
    if (absValue >= 1e-6) return {'value': value * 1e6, 'prefix': 'mikro'};
    if (absValue >= 1e-9) return {'value': value * 1e9, 'prefix': 'nano'};
    return {'value': value * 1e12, 'prefix': 'piko'};
  }

  String _getStatsCountForm(int count) {
    if (_isEnglish()) {
      return count == 1 ? 'value' : 'values';
    }
    if (count == 1) {
      return 'hodnota';
    } else if (count >= 2 && count <= 4) {
      return 'hodnoty';
    } else {
      return 'hodnot';
    }
  }

  bool _statsRecordsEqual(StatisticsRecord a, StatisticsRecord b) {
    if (a.values.length != b.values.length) return false;
    for (int i = 0; i < a.values.length; i++) {
      if (a.values[i] != b.values[i]) return false;
    }
    return true;
  }

  List<List<int>> _groupStatsRecords(List<StatisticsRecord> records) {
    final groups = <List<int>>[];
    final reps = <StatisticsRecord>[];
    for (int i = 0; i < records.length; i++) {
      int? match;
      for (int g = 0; g < groups.length; g++) {
        if (_statsRecordsEqual(reps[g], records[i])) {
          match = g;
          break;
        }
      }
      if (match == null) {
        groups.add([i]);
        reps.add(records[i]);
      } else {
        groups[match].add(i);
      }
    }
    return groups;
  }

  String _statsEmptyMessage() {
    if (_statsSets.isEmpty) {
      return _s(
        'Není vytvořena žádná statistická sada.',
        'No statistics set created.',
      );
    }
    final setName = _statsSets[_currentStatsSetIndex].name;
    return _s(
      'Statistická sada "$setName" je prázdná. Přidejte data pomocí tlačítka M plus.',
      'Statistics set "$setName" is empty. Add data using the M+ button.',
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  bool _isEnglish([BuildContext? ctx]) {
    final code = ctx != null
        ? Localizations.localeOf(ctx).languageCode
        : WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'en';
  }

  String _s(String cs, String en) => _isEnglish() ? en : cs;

  String _getModeSpeechNameForL10n(CalculatorMode mode, AppLocalizations l10n) {
    switch (mode) {
      case CalculatorMode.basic:
        return l10n.modeSpeechBasic;
      case CalculatorMode.scientific:
        return l10n.modeSpeechScientific;
      case CalculatorMode.statistics:
        return l10n.modeSpeechStatistics;
      case CalculatorMode.electrician:
        return l10n.modeSpeechElectrician;
      case CalculatorMode.unitConversion:
        return l10n.modeSpeechUnitConversion;
      case CalculatorMode.time:
        return l10n.modeSpeechTime;
      case CalculatorMode.currency:
        return l10n.modeSpeechCurrency;
    }
  }

  void _updateTtsLanguage() {
    if (!mounted) return;
    final lang = _isEnglish() ? 'en-US' : 'cs-CZ';
    if (_lastTtsLocale == lang) return;
    _lastTtsLocale = lang;
    tts.setLanguage(lang);
    if (_ttsVoice != null) {
      updateActiveAccessibilitySettings(
        (s) => s.copyWith(clearTtsVoice: true, clearTtsVoiceName: true),
      );
      tts.clearVoice();
    }
  }

  _StatisticsSnapshot? _computeStatisticsSnapshot([int fieldIndex = -1]) {
    if (fieldIndex < 0) fieldIndex = _selectedFieldIndex;
    if (_statsMemory.isEmpty) return null;
    final data = List<double>.from(_getFieldValues(fieldIndex));
    final sum = data.reduce((a, b) => a + b);
    final mean = sum / data.length;
    final variance =
        data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
        data.length;
    final sd = math.sqrt(variance);

    final sorted = List<double>.from(data)..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length % 2 == 1
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final min = sorted.first;
    final max = sorted.last;

    final counts = <double, int>{};
    for (final x in data) {
      counts[x] = (counts[x] ?? 0) + 1;
    }
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final modeExists = maxCount > 1;
    final modes = counts.entries
        .where((e) => e.value == maxCount)
        .map((e) => e.key)
        .toList();
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final frequencies = Map<double, int>.fromIterable(
      sortedEntries,
      key: (e) => e.key,
      value: (e) => e.value,
    );

    double? wmean;
    if (_currentFieldCount >= 2) {
      final values = _getFieldValues(0);
      final weights = _getFieldValues(1);
      double sumW = 0;
      double sumVW = 0;
      for (int i = 0; i < values.length; i++) {
        sumVW += values[i] * weights[i];
        sumW += weights[i];
      }
      if (sumW != 0) wmean = sumVW / sumW;
    }

    return _StatisticsSnapshot(
      sum: sum,
      mean: mean,
      variance: variance,
      sd: sd,
      median: median,
      min: min,
      max: max,
      modes: modes,
      modeOccurrenceCount: maxCount,
      modeExists: modeExists,
      cv: mean == 0 ? null : (sd / mean) * 100,
      wmean: wmean,
      frequencies: frequencies,
    );
  }

  String _toBarNotation(String text) {
    const bar = '\u0305';
    return text.replaceAllMapped(RegExp(r'(\d+)([.,])(\d*)\((\d+)\)'), (m) {
      final intPart = m.group(1)!;
      final sep = m.group(2)!;
      final nonRepeating = m.group(3) ?? '';
      final period = m.group(4)!;
      final periodBars = period.split('').map((d) => '$d$bar').join();
      return '$intPart$sep$nonRepeating$periodBars';
    });
  }

  String? _czechExponentOrdinal(int absExp) {
    switch (absExp) {
      case 0:
        return 'nultou';
      case 1:
        return 'první';
      case 2:
        return 'druhou';
      case 3:
        return 'třetí';
      case 4:
        return 'čtvrtou';
      case 5:
        return 'pátou';
      case 6:
        return 'šestou';
      case 7:
        return 'sedmou';
      case 8:
        return 'osmou';
      case 9:
        return 'devátou';
      case 10:
        return 'desátou';
      case 11:
        return 'jedenáctou';
      case 12:
        return 'dvanáctou';
      case 13:
        return 'třináctou';
      case 14:
        return 'čtrnáctou';
      case 15:
        return 'patnáctou';
      case 16:
        return 'šestnáctou';
      case 17:
        return 'sedmnáctou';
      case 18:
        return 'osmnáctou';
      case 19:
        return 'devatenáctou';
      case 20:
        return 'dvacátou';
      case 30:
        return 'třicátou';
      default:
        if (absExp > 20 && absExp < 30) {
          // 21-29: dvacátou první etc. – fallback to kardinál + ordinál sufix approximation
          return null;
        }
        return null;
    }
  }

  String _speakExponentialPart(String mantissa, String sign, String expDigits) {
    final l10n = _l10n;
    final exp = int.tryParse(expDigits) ?? 0;
    final isEnglishLocale = l10n.localeName.startsWith('en');
    if (isEnglishLocale) {
      return '$mantissa ${l10n.timesTenTo} ${sign == '-' ? '${l10n.minusWord} ' : ''}$exp';
    }
    final ordinal = _czechExponentOrdinal(exp.abs());
    if (ordinal != null) {
      final minusPart = sign == '-' ? '${l10n.minusWord} ' : '';
      return '$mantissa ${l10n.timesTenTo} $minusPart$ordinal';
    }
    return '$mantissa ${l10n.timesTenTo} ${sign == '-' ? '${l10n.minusWord} ' : ''}$exp';
  }

  /// Centrální převod exponenciálního zápisu pro češtinu/angličtinu.
  /// Používá strukturovaná data když jsou k dispozici, jinak parsuje display string.
  String _speakForAutoExpValue(double value) {
    final dec = _decomposeAutoExp(value);
    if (dec != null) {
      final mantissa = (dec.negative ? '-' : '') + dec.mantissa;
      final sign = dec.exponent >= 0 ? '+' : '-';
      final expDigits = dec.exponent.abs().toString().padLeft(1, '0');
      // R6: desetinný oddělovač mantisy podle jazyka.
      final mantissaSpoken = _localizeDecimalSeparator(mantissa);
      return _speakExponentialPart(mantissaSpoken, sign, expDigits);
    }
    return '';
  }

  /// Číselný formatter: číslo / matematický zápis → slova pro řeč (R6).
  /// Jediné místo, kde se smí převádět desetinné oddělovače, periodický
  /// zápis a exponent. Idempotentní – opakovaný průchod výstup nemění.
  String _numberToSpeech(String text) {
    // Částečně odmocněné tvary ("6√2", "3∛2", "2⁴√3"): čtou se slovně,
    // např. "šest odmocnina ze dvou". Nejdřív celý řetězec ...
    final surdSpeech = _trySpeakSurd(text);
    if (surdSpeech != null) return surdSpeech;
    // ... pak i surd vložený do delšího zápisu ("2+6√2", "Výsledek je 6√2").
    // Znaky √/∛ se v běžných větách nevyskytují, takže je to bezpečné.
    String result = _speakSurdsInSentence(text);
    result = result.replaceAllMapped(
      RegExp(r'(\d+)(?:[.,](\d*))?\((\d+)\)'),
      (m) {
        final intPart = m.group(1)!;
        final nonRepeating = m.group(2) ?? '';
        final period = m.group(3)!;
        final suffix = _s('periodických', 'repeating');
        if (nonRepeating.isEmpty) return '$intPart,$period $suffix';
        return '$intPart,$nonRepeating, $period $suffix';
      },
    );
    // Centrální exponenciální převod (mantisa E±exponent) – používá ordinál
    // pro češtinu. Mantisa s tečkou i čárkou ("1.5E+03" i "1,5E+03").
    result = result.replaceAllMapped(
      RegExp(r"(\d+(?:[.,]\d+)?)E([+-])(\d+)"),
      (m) {
        final mantissa = _localizeDecimalSeparator(m.group(1)!);
        return _speakExponentialPart(mantissa, m.group(2)!, m.group(3)!);
      },
    );
    return _localizeDecimalSeparator(result);
  }

  /// Původní název zachován pro zpětnou kompatibilitu (volající, testy).
  String _spokenForDisplay(String text) => _numberToSpeech(text);

  /// Větný formatter: běžná věta → řeč (R6).
  /// NESMÍ měnit tečky/čárky/exponenty – pouze symboly, které TTS neumí (π).
  String _sentenceToSpeech(String text) {
    return text.replaceAll('\u03C0', _l10n.piSpoken);
  }

  /// Desetinný oddělovač pouze v číselném kontextu (číslice-oddělovač-číslice)
  /// a podle jazyka: CZ čárka, EN tečka. Větná interpunkce se nikdy nemění.
  String _localizeDecimalSeparator(String text) {
    if (_isEnglish()) {
      return text.replaceAllMapped(
        RegExp(r'(\d),(\d)'),
        (m) => '${m.group(1)}.${m.group(2)}',
      );
    }
    return text.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (m) => '${m.group(1)},${m.group(2)}',
    );
  }

  /// Surd vložený do delšího textu ("2+6√2" → "2+ šest odmocnina ze dvou").
  /// Pořadí: nejdřív n-tá odmocnina (obsahuje √), pak ∛, pak √.
  String _speakSurdsInSentence(String text) {
    var result = text.replaceAllMapped(
      RegExp(r'(\d*)([⁰¹²³⁴⁵⁶⁷⁸⁹]+)√(\d+)'),
      (m) =>
          ' ${_speakSurd(coef: m.group(1)!, radicand: m.group(3)!, index: _desuperscript(m.group(2)!))} ',
    );
    result = result.replaceAllMapped(
      RegExp(r'(\d*)∛(\d+)'),
      (m) =>
          ' ${_speakSurd(coef: m.group(1)!, radicand: m.group(2)!, index: 3)} ',
    );
    result = result.replaceAllMapped(
      RegExp(r'(\d*)√(\d+)'),
      (m) =>
          ' ${_speakSurd(coef: m.group(1)!, radicand: m.group(2)!, index: 2)} ',
    );
    return result;
  }

  /// Vrátí slovní podobu částečně odmocněného tvaru ("6√2" ->
  /// "šest odmocnina ze dvou"), nebo null když [text] není surd.
  /// Používá existující [_s] lokalizační helper, žádný paralelní TTS systém.
  String? _trySpeakSurd(String text) {
    final t = text.replaceAll(' ', '');
    final sqrt = RegExp(r'^(\d*)√(\d+)$').firstMatch(t);
    if (sqrt != null) {
      return _speakSurd(
        coef: sqrt.group(1)!,
        radicand: sqrt.group(2)!,
        index: 2,
      );
    }
    final cbrt = RegExp(r'^(\d*)∛(\d+)$').firstMatch(t);
    if (cbrt != null) {
      return _speakSurd(
        coef: cbrt.group(1)!,
        radicand: cbrt.group(2)!,
        index: 3,
      );
    }
    final nth = RegExp(r'^(\d*)([⁰¹²³⁴⁵⁶⁷⁸⁹]+)√(\d+)$').firstMatch(t);
    if (nth != null) {
      return _speakSurd(
        coef: nth.group(1)!,
        radicand: nth.group(3)!,
        index: _desuperscript(nth.group(2)!),
      );
    }
    return null;
  }

  int _desuperscript(String s) {
    const map = {
      '⁰': '0',
      '¹': '1',
      '²': '2',
      '³': '3',
      '⁴': '4',
      '⁵': '5',
      '⁶': '6',
      '⁷': '7',
      '⁸': '8',
      '⁹': '9',
    };
    return int.tryParse(s.split('').map((c) => map[c] ?? '').join()) ?? 0;
  }

  String _speakSurd({
    required String coef,
    required String radicand,
    required int index,
  }) {
    final c = coef.isEmpty ? 1 : int.tryParse(coef) ?? 0;
    final r = int.tryParse(radicand) ?? 0;
    final coefWord = _czechCardinal(c);
    final radWord = _czechGenitive(r);
    final rootCs = index == 2
        ? 'odmocnina'
        : index == 3
        ? 'třetí odmocnina'
        : index == 4
        ? 'čtvrtá odmocnina'
        : '$index-tá odmocnina';
    final rootEn = index == 2
        ? 'square root'
        : index == 3
        ? 'cube root'
        : index == 4
        ? 'fourth root'
        : '$index-th root';
    final coefEn = c == 1 ? '' : '$c ';
    final coefCs = c == 1 ? '' : '$coefWord ';
    return _s('$coefCs$rootCs ze $radWord', '$coefEn$rootEn of $r');
  }

  // Malá čísla slovně (1-10 + 0), větší čísla číslicemi. Stačí pro
  // reálné surd koeficienty/radikandy; nejde o obecný číslovkový systém.
  String _czechCardinal(int n) {
    const words = {
      0: 'nula',
      1: 'jedna',
      2: 'dvě',
      3: 'tři',
      4: 'čtyři',
      5: 'pět',
      6: 'šest',
      7: 'sedm',
      8: 'osm',
      9: 'devět',
      10: 'deset',
    };
    return words[n] ?? '$n';
  }

  String _czechGenitive(int n) {
    const words = {
      1: 'jedné',
      2: 'dvou',
      3: 'tří',
      4: 'čtyř',
      5: 'pěti',
      6: 'šesti',
      7: 'sedmi',
      8: 'osmi',
      9: 'devíti',
      10: 'deseti',
    };
    return words[n] ?? '$n';
  }

  String _expressionToSpeech(String expr) {
    String result = expr.replaceAllMapped(
      RegExp(
        r'''x²|x³|ⁿ√|\(-\)|°→'|'→°|√|∛|π|ANS|ASIN|ACOS|ATAN|SIN|COS|TAN|ABS|LOG|LN|\d+(?:[.,]\d*)?\(\d+\)|\d+[.,]\d+|\d+|[+\-*/^%!()°'"]|[A-Za-z]''',
        caseSensitive: false,
      ),
      (m) {
        final token = m[0]!;
        String spoken;
        if (RegExp(r'^\d').hasMatch(token)) {
          spoken = _spokenForDisplay(token);
        } else if (token == '\u03C0') {
          spoken = _l10n.piSpoken;
        } else {
          final upper = token.toUpperCase();
          if (upper == 'E' &&
              m.start > 0 &&
              RegExp(r'\d').hasMatch(expr[m.start - 1])) {
            spoken = _getButtonName('EXP');
          } else {
            switch (token) {
              case '°':
                spoken = _l10n.degreesUnit;
                break;
              case "'":
                spoken = _l10n.minutesUnit;
                break;
              case '"':
                spoken = _l10n.secondsUnit;
                break;
              default:
                final name = _getButtonName(token);
                spoken = name == token ? _getButtonName(upper) : name;
            }
          }
        }
        return ' $spoken';
      },
    );
    return result.trim();
  }

  ({int num, int den})? _rationalFromDouble(double x) {
    if (x.isNaN || x.isInfinite || x <= 0) return null;
    double pPrev = 0, p = 1;
    double qPrev = 1, q = 0;
    double xi = x;
    for (int i = 0; i < 100; i++) {
      final a = xi.floorToDouble();
      final pNext = a * p + pPrev;
      final qNext = a * q + qPrev;
      if (qNext > 1e9) return null;
      pPrev = p;
      p = pNext;
      qPrev = q;
      q = qNext;
      if ((x - p / q).abs() < 1e-10) {
        return (num: p.round(), den: q.round());
      }
      final frac = xi - a;
      if (frac < 1e-12) return null;
      xi = 1.0 / frac;
    }
    return null;
  }

  String? _tryFormatRepeating(double value) {
    if (value.isNaN || value.isInfinite || value == 0) return null;
    final neg = value < 0;
    final absVal = value.abs();
    final frac = _rationalFromDouble(absVal);
    if (frac == null) return null;
    final num = frac.num;
    final den = frac.den;

    int d = den;
    int x = 0, y = 0;
    while (d % 2 == 0) {
      d ~/= 2;
      x++;
    }
    while (d % 5 == 0) {
      d ~/= 5;
      y++;
    }
    if (d == 1) return null; // konečné desetinné číslo

    final nonRepCount = math.max(x, y);
    final intPart = num ~/ den;
    int rem = num % den;
    final nonRep = <int>[];
    for (int i = 0; i < nonRepCount; i++) {
      rem *= 10;
      nonRep.add(rem ~/ den);
      rem = rem % den;
    }
    final rep = <int>[];
    final startRem = rem;
    var guard = 0;
    do {
      rem *= 10;
      rep.add(rem ~/ den);
      rem = rem % den;
      guard++;
    } while (rem != startRem && rem != 0 && guard < 1000);
    if (rep.length > 9) return null;

    final sign = neg ? '-' : '';
    final np = nonRep.join();
    final rp = rep.join();
    return '$sign$intPart.${np.isEmpty ? '' : np}($rp)';
  }

  String _formatSpokenNumber(double value) {
    if (_displayFormat == DisplayFormat.standard && _usePeriodicNotation) {
      final repeating = _tryFormatRepeating(value);
      if (repeating != null) return _spokenForDisplay(repeating);
    }
    // Auto-exponenciální hodnoty: centrální speech přes strukturovaná data (ne jen parsování stringu)
    final autoExp = _tryAutoExponential(value);
    if (autoExp != null) {
      final spoken = _speakForAutoExpValue(value);
      if (spoken.isNotEmpty) return spoken;
      return _spokenForDisplay(autoExp);
    }
    final raw = _formatNumber(value);
    // Fallback: pokud format vrátil E-notaci (např. z sci), projde centrálním speech
    if (raw.contains('E')) {
      return _spokenForDisplay(raw);
    }
    // R6: desetinný oddělovač podle jazyka, pouze v číselném kontextu.
    return _localizeDecimalSeparator(raw);
  }

  String _getButtonName(String label) {
    final pair = _buttonNames[label];
    if (pair != null) {
      return _isEnglish() ? pair[1] : pair[0];
    }
    return label;
  }

  String _getCategorySpeech(String category) {
    switch (category) {
      case 'Délka':
        return _s('Délka', 'Length');
      case 'Hmotnost':
        return _s('Hmotnost', 'Mass');
      case 'Plocha':
        return _s('Plocha', 'Area');
      case 'Objem':
        return _s('Objem', 'Volume');
      case 'Tlak':
        return _s('Tlak', 'Pressure');
      case 'Čas':
        return _s('Čas', 'Time');
      case 'Napětí':
        return _s('Napětí', 'Voltage');
      case 'Proud':
        return _s('Proud', 'Current');
      case 'Odpor':
        return _s('Odpor', 'Resistance');
      case 'Výkon':
        return _s('Výkon', 'Power');
      default:
        return category;
    }
  }

  ElectricianCalculation? _electricianCalculationFromButton(String label) {
    switch (label) {
      case 'OHM_V':
        return ElectricianCalculation.voltage;
      case 'OHM_I':
        return ElectricianCalculation.current;
      case 'OHM_R':
        return ElectricianCalculation.resistance;
      default:
        return null;
    }
  }

  String _getElectricianCalculationName(ElectricianCalculation calculation) {
    switch (calculation) {
      case ElectricianCalculation.voltage:
        return _l10n.calcNameVoltage;
      case ElectricianCalculation.current:
        return _l10n.calcNameCurrent;
      case ElectricianCalculation.resistance:
        return _l10n.calcNameResistance;
    }
  }

  String _getElectricianHistoryName(ElectricianCalculation calculation) {
    switch (calculation) {
      case ElectricianCalculation.voltage:
        return 'OHM_V';
      case ElectricianCalculation.current:
        return 'OHM_I';
      case ElectricianCalculation.resistance:
        return 'OHM_R';
    }
  }

  String _getElectricianInputDescription(ElectricianCalculation calculation) {
    switch (calculation) {
      case ElectricianCalculation.voltage:
        return _l10n.calcInputVoltage;
      case ElectricianCalculation.current:
        return _l10n.calcInputCurrent;
      case ElectricianCalculation.resistance:
        return _l10n.calcInputResistance;
    }
  }

  String _getElectricianUnitSpeech(
    ElectricianCalculation calculation,
    double value,
    String prefix,
  ) {
    // Prefix je např. 'mili', 'kilo', ''
    // value je jiż přeškálovaná hodnota
    final absValue = value.abs();
    final isWholeNumber = absValue == absValue.roundToDouble();
    final wholeValue = absValue.toInt();

    if (_isEnglish()) {
      String unit;
      switch (calculation) {
        case ElectricianCalculation.voltage:
          unit = 'volt';
          break;
        case ElectricianCalculation.current:
          unit = 'ampere';
          break;
        case ElectricianCalculation.resistance:
          unit = 'ohm';
          break;
      }
      switch (prefix) {
        case 'mili':
          unit = 'milli$unit';
          break;
        case 'mikro':
          unit = 'micro$unit';
          break;
        case 'nano':
          unit = 'nano$unit';
          break;
        case 'piko':
          unit = 'pico$unit';
          break;
        case 'kilo':
          unit = 'kilo$unit';
          break;
        case 'mega':
          unit = 'mega$unit';
          break;
        case 'giga':
          unit = 'giga$unit';
          break;
      }
      if (isWholeNumber && wholeValue == 1) {
        return unit;
      }
      return '${unit}s';
    }

    String unit = '';
    switch (calculation) {
      case ElectricianCalculation.voltage:
        unit = 'volt';
        break;
      case ElectricianCalculation.current:
        unit = 'ampér';
        break;
      case ElectricianCalculation.resistance:
        unit = 'ohm';
        break;
    }

    // Aplikace prefixu na základní jednotku
    if (prefix == 'mili')
      unit = 'mili${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'mikro')
      unit = 'mikro${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'nano')
      unit = 'nano${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'piko')
      unit = 'piko${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'kilo')
      unit = 'kilo${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'mega')
      unit = 'mega${unit == 'ohm' ? 'ohm' : unit}';
    else if (prefix == 'giga')
      unit = 'giga${unit == 'ohm' ? 'ohm' : unit}';

    // Gramatické tvary
    if (isWholeNumber && wholeValue == 1) {
      // Základní jednotka, např. 1 volt, 1 kiloampér
      return unit;
    }

    if (isWholeNumber && wholeValue >= 2 && wholeValue <= 4) {
      // Plural 2-4, např. 2 volty, 2 kiloampéry
      if (unit.endsWith('volt')) return '${unit}y';
      if (unit.endsWith('ampér')) return '${unit}y';
      if (unit.endsWith('ohm')) return '${unit}y';
      return '${unit}y'; // Default
    }

    // Genitiv plural, např. 5 voltů, 5 kiloampérů
    if (unit.endsWith('volt')) return '${unit}ů';
    if (unit.endsWith('ampér')) return '${unit}ů';
    if (unit.endsWith('ohm')) return '${unit}ů';
    return '${unit}ů';
  }

  void _selectElectricianCalculation(ElectricianCalculation calculation) {
    setState(() {
      _selectedElectricianCalculation = calculation;
    });
    final calculationName = _getElectricianCalculationName(calculation);
    final inputDescription = _getElectricianInputDescription(calculation);
    speak(_l10n.calcIntro(calculationName, inputDescription));
  }

  List<double> _parseElectricianInputValues(String input) {
    final parts = input.split(';');
    if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
      throw _ElectricianInputException(_l10n.elecTwoValuesError);
    }

    try {
      return parts.map((part) => _evaluateExpression(part.trim())).toList();
    } catch (e) {
      throw _ElectricianInputException(_l10n.elecFormatError);
    }
  }

  double _calculateElectricianResult(String input) {
    final values = _parseElectricianInputValues(input);
    final first = values[0];
    final second = values[1];

    switch (_selectedElectricianCalculation) {
      case ElectricianCalculation.voltage:
        return first * second;
      case ElectricianCalculation.current:
        if (second == 0) {
          throw const _ElectricianInputException(
            'Odpor nesmí být nula při výpočtu proudu.',
          );
        }
        return first / second;
      case ElectricianCalculation.resistance:
        if (second == 0) {
          throw const _ElectricianInputException(
            'Proud nesmí být nula při výpočtu odporu.',
          );
        }
        return first / second;
    }
  }

  bool _isSelectedElectricianButton(String label) {
    final calculation = _electricianCalculationFromButton(label);
    return calculation != null &&
        calculation == _selectedElectricianCalculation;
  }

  String? _getElectricianButtonSemanticLabel(String label) {
    final calculation = _electricianCalculationFromButton(label);
    if (calculation == null) {
      return null;
    }

    final baseLabel = _getButtonName(label);
    if (calculation == _selectedElectricianCalculation) {
      return '${baseLabel}, ${_s('vybráno', 'selected')}';
    }
    return baseLabel;
  }

  // --- Čas helpers ---
  int _parseHmsToSeconds(String input) {
    final s = input.trim();
    if (s.isEmpty) throw _TimeInputException(_l10n.timeInvalidFormat);
    if (!s.contains(':')) {
      // Single number = seconds
      final v = double.tryParse(s.replaceAll(',', '.'));
      if (v == null) throw _TimeInputException(_l10n.timeInvalidFormat);
      return v.round();
    }
    final parts = s.split(':');
    if (parts.length == 2 || parts.length == 3) {
      final nums = parts.map((p) => int.tryParse(p.trim())).toList();
      if (nums.any((n) => n == null))
        throw _TimeInputException(_l10n.timeInvalidFormat);
      if (parts.length == 2) {
        final h = nums[0]!;
        final m = nums[1]!;
        if (m < 0 || m >= 60 || h < 0)
          throw _TimeInputException(_l10n.timeInvalidFormat);
        return h * 3600 + m * 60;
      } else {
        final h = nums[0]!;
        final m = nums[1]!;
        final sec = nums[2]!;
        if (m < 0 || m >= 60 || sec < 0 || sec >= 60 || h < 0) {
          throw _TimeInputException(_l10n.timeInvalidFormat);
        }
        return h * 3600 + m * 60 + sec;
      }
    }
    throw _TimeInputException(_l10n.timeInvalidFormat);
  }

  String _formatSecondsToHms(int totalSeconds) {
    final neg = totalSeconds < 0;
    int sec = totalSeconds.abs();
    final h = sec ~/ 3600;
    sec %= 3600;
    final m = sec ~/ 60;
    final s = sec % 60;
    final hms =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return neg ? '-$hms' : hms;
  }

  String _formatSecondsToSpeech(int totalSeconds) {
    final neg = totalSeconds < 0;
    int sec = totalSeconds.abs();
    final h = sec ~/ 3600;
    sec %= 3600;
    final m = sec ~/ 60;
    final s = sec % 60;
    final parts = <String>[];
    if (h > 0) parts.add(_getTimeUnitSpeech('h', h.toDouble()));
    if (m > 0 || h > 0) parts.add(_getTimeUnitSpeech('min', m.toDouble()));
    parts.add(_getTimeUnitSpeech('s', s.toDouble()));
    // Build spoken number + unit
    final buffer = StringBuffer();
    if (neg) buffer.write('${_s('mínus ', 'minus ')}');
    // We need to inject numbers: e.g. "2 hodiny 15 minut 30 sekund"
    // _getTimeUnitSpeech returns declension form, we need to prepend number
    // But for simplicity construct manually
    String speech = '';
    if (h > 0)
      speech +=
          '${_formatSpokenNumber(h.toDouble())} ${_getTimeUnitSpeech('h', h.toDouble(), context: 'base')} ';
    if (m > 0 || h > 0) {
      speech +=
          '${_formatSpokenNumber(m.toDouble())} ${_getTimeUnitSpeech('min', m.toDouble(), context: 'base')} ';
    }
    speech +=
        '${_formatSpokenNumber(s.toDouble())} ${_getTimeUnitSpeech('s', s.toDouble(), context: 'base')}';
    if (neg) speech = '${_s('mínus ', 'minus ')}$speech';
    return speech.trim();
  }

  String _getTimeUnitSpeech(
    String unit,
    double value, {
    String context = 'base',
  }) {
    // Reuse _unitSpeechData for s/min/h
    return _getUnitSpeech(unit, value: value, context: context);
  }

  String _getCurrentTimeHms() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _insertCurrentTime() async {
    final hms = _getCurrentTimeHms();
    setState(() {
      display =
          display.substring(0, _cursorPosition) +
          hms +
          display.substring(_cursorPosition);
      _cursorPosition += hms.length;
      _hasResult = false;
    });
    final spoken = _formatSecondsToSpeech(_parseHmsToSeconds(hms));
    speak(_l10n.timeCurrentIs(spoken));
  }

  String _calculateTimeResult(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) throw _TimeInputException(_l10n.timeInvalidFormat);
    // Check for single time -> normalize
    if (!trimmed.contains('+') &&
        !trimmed.contains('-') &&
        !trimmed.contains(';')) {
      if (trimmed.contains(':')) {
        final sec = _parseHmsToSeconds(trimmed);
        return _formatSecondsToHms(sec);
      } else {
        // numeric seconds -> Hms
        final v = double.tryParse(trimmed.replaceAll(',', '.'));
        if (v != null) {
          return _formatSecondsToHms(v.round());
        }
        throw _TimeInputException(_l10n.timeInvalidFormat);
      }
    }
    // Split by + or - or ; (treat ; as diff)
    if (trimmed.contains(';')) {
      final parts = trimmed.split(';');
      if (parts.length != 2) throw _TimeInputException(_l10n.timeInvalidFormat);
      final a = _parseHmsToSeconds(parts[0].trim());
      final b = _parseHmsToSeconds(parts[1].trim());
      final diff = (a - b).abs();
      return _formatSecondsToHms(diff);
    }
    // Find operator + or - (last occurrence, but simple)
    int plusIdx = trimmed.lastIndexOf('+');
    int minusIdx = trimmed.lastIndexOf('-');
    // Skip leading minus
    if (minusIdx == 0) minusIdx = trimmed.indexOf('-', 1);
    int opIdx = -1;
    String op = '+';
    if (plusIdx > 0 && minusIdx > 0) {
      opIdx = plusIdx > minusIdx ? plusIdx : minusIdx;
      op = plusIdx > minusIdx ? '+' : '-';
    } else if (plusIdx > 0) {
      opIdx = plusIdx;
      op = '+';
    } else if (minusIdx > 0) {
      opIdx = minusIdx;
      op = '-';
    }
    if (opIdx < 0) throw _TimeInputException(_l10n.timeInvalidFormat);
    final left = trimmed.substring(0, opIdx).trim();
    final right = trimmed.substring(opIdx + 1).trim();
    final a = _parseHmsToSeconds(left);
    final b = _parseHmsToSeconds(right);
    final res = op == '+' ? a + b : a - b;
    return _formatSecondsToHms(res);
  }

  // --- Měna helpers ---
  String _getCurrencySpeech(
    String code,
    double value, {
    String context = 'base',
  }) {
    final absVal = value.abs();
    final isWhole = absVal == absVal.roundToDouble();
    final intVal = absVal.round();
    if (_isEnglish()) {
      final en = _currencySpeechDataEn[code];
      if (en == null) return code;
      if (isWhole && intVal == 1) return en['base']!;
      return en['plural']!;
    } else {
      final cs = _currencySpeechData[code];
      if (cs == null) return code;
      final forms = (cs['forms'] as List<String>);
      if (!isWhole) return forms[3];
      if (intVal == 1) return forms[0];
      if (intVal >= 2 && intVal <= 4) return forms[1];
      return forms[2];
    }
  }

  String _formatCurrencyRate(double rate) {
    return _formatNumber(rate).replaceAll('.', ',');
  }

  Future<void> _convertCurrency() async {
    try {
      double value;
      if (display.trim().isNotEmpty) {
        value = _evaluateExpression(display.trim());
      } else if (_hasResult) {
        value = double.parse(_lastResult.replaceAll(',', '.'));
      } else {
        throw Exception('no value');
      }
      final fromRate = _currencyRates[_currencyFrom]!;
      final toRate = _currencyRates[_currencyTo]!;
      if (fromRate == 0 || toRate == 0) throw Exception('zero rate');
      final result = value * (fromRate / toRate);
      if (result.isNaN || result.isInfinite) throw Exception('invalid');
      final resStr = _formatNumber(result);
      final spokenValue = _formatSpokenNumber(value);
      final spokenResult = _formatSpokenNumber(result);
      final fromSpeech = _getCurrencySpeech(_currencyFrom, value);
      final toSpeech = _getCurrencySpeech(_currencyTo, result);
      final rateStr = _formatCurrencyRate(
        toRate / fromRate,
      ); // 1 from = X to? Actually show CZK per 1, simpler show course
      // Show course as 1 from = X to  OR use stored rate display
      setState(() {
        _lastResult = resStr;
        display = '';
        _hasResult = true;
        _lastNumericValue = result;
        // Měnový výsledek je speciální kontext: zlomek nevhodný.
        _lastResultIsPlainNumeric = false;
        _fractionOverride = null;
        // Nový výsledek ruší přesná metadata (klíč + generace).
        _lastExact = null;
        _lastExactKey = '';
        _resultGeneration++;
        _lastExactGeneration = _resultGeneration;
      });
      _addToHistory(
        '${value.toString()} $_currencyFrom → $_currencyTo',
        resStr,
        numericValue: result,
      );
      // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
      unawaited(
        announceEvent(
          _l10n.currencyConverted(
            spokenValue,
            fromSpeech,
            toSpeech,
            spokenResult,
            toSpeech,
            rateStr,
          ),
          category: SpeechCategory.actionConfirm,
          isNumeric: true,
          interruptCurrentSpeech: true,
        ),
      );
    } catch (_) {
      // R9: jedna chybová hláška (dříve speak(force) + announce SnackBaru).
      unawaited(
        announceEvent(
          _l10n.conversionError,
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
      _showAccessibleSnackBar(_l10n.conversionError, announce: false);
    }
  }

  String _formatCurrencyDate(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  Future<void> _updateCurrencyRatesOnline({bool silent = false}) async {
    if (_currencyLoading) return;
    setState(() => _currencyLoading = true);
    if (!silent) speak(_l10n.currencyUpdating);
    final service = CurrencyService();
    final result = await service.fetchCnbRates();
    service.close();
    if (!mounted) return;
    setState(() => _currencyLoading = false);
    if (result != null) {
      // Merge: keep CZK 1.0, update others, keep manual currencies not in CNB
      setState(() {
        for (final e in result.rates.entries) {
          _currencyRates[e.key] = e.value;
        }
        _currencyLastUpdate = DateTime.now();
      });
      await _saveCurrencyRates();
      if (!silent) {
        // R9: oznamuje pouze SnackBar (dříve speak(force) + announce).
        _showAccessibleSnackBar(_l10n.currencyUpdated);
      }
    } else {
      if (!silent) {
        // R9: oznamuje pouze SnackBar (dříve speak(force) + announce).
        _showAccessibleSnackBar(_l10n.currencyOfflineError);
      }
    }
  }

  Future<void> _saveCurrencyRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currencyRates', jsonEncode(_currencyRates));
      await prefs.setString('currencyFrom', _currencyFrom);
      await prefs.setString('currencyTo', _currencyTo);
      if (_currencyLastUpdate != null) {
        await prefs.setString(
          'currencyLastUpdate',
          _currencyLastUpdate!.toIso8601String(),
        );
      }
    } catch (_) {}
  }

  void _showCurrencyManagerDialog() {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Správa kurzů'),
      builder: (ctx) => _CurrencyManagerDialog(parent: this),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handlePrimaryFocusChanged);
    // Počáteční fokus + režim Z1 nezávisí na načtení verze (dříve visely na
    // dokončení PackageInfo v _initAppVersion). Viz [_initPrimaryFocus].
    _initPrimaryFocus();
    _refreshAccessibilityState();
    _initTts();
    _initAppVersion();
    // Jednotný Quick Setup: plánování nezávislé na stats/TTS načítání,
    // aby visící I/O nemohlo zablokovat onboarding. Draft se staví až po
    // dokončení _configLoaded (globály + profily), viz _maybeShowQuickSetup.
    final setupDelay = _sayWelcome
        ? const Duration(milliseconds: 2200)
        : const Duration(milliseconds: 1000);
    // Timer (místo Future.delayed): lze zrušit v dispose, aby testy
    // nekončily s pending timerem. _quickSetupShown navíc brání duplicitě.
    _quickSetupTimer = Timer(setupDelay, () async {
      if (mounted) await _maybeShowQuickSetup();
    });
    _dialogFontScaleNotifier.value = _dialogFontScale;
    _readingOrderFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    // Z6: rebuild při změně klávesnicového fokusu vstupní proxy. SDK při
    // ZÍSKÁNÍ fokusu samo `setState` nevolá
    // (`EditableTextState._handleFocusChanged` volá `setState` jen při
    // ztrátě fokusu), takže by `RenderEditable` nikdy nedostal
    // `hasFocus: true` a do sémantiky by se nedostal skutečný `isFocused`
    // ani akce `setSelection` (oba se publikují POUZE při fokusu, viz
    // `rendering/editable.dart`). Listener pouze zajistí překreslení;
    // hodnotu fokusu stále čte framework z [_displayA11yFocusNode] —
    // žádný fokusový stav se nepředstírá. Stejný vzor jako výše u
    // [_readingOrderFocusNode]; uzel je vlastní a dispozuje se v [dispose].
    _displayA11yFocusNode.addListener(_handleA11yProxyFocusChanged);
  }

  /// Z6: viz poznámka v [initState] — pouze rebuild, aby `RenderEditable`
  /// publikoval skutečné `isFocused`/`setSelection` po získání fokusu.
  void _handleA11yProxyFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Jediné místo počátečního nastavení klávesnicového fokusu a režimu
  /// ovládání výrazu (Z1). Volá se synchronně z [initState], NEZÁVISLE na
  /// načtení verze ([_initAppVersion]): `requestFocus()` na ještě
  /// nepřipojeném uzlu SDK odloží a udělí fokus při prvním buildu
  /// (`FocusNode._doRequestFocus` → `_requestFocusWhenReparented`,
  /// focus_manager.dart), takže fokus je nastaven hned při prvním attachi —
  /// nejčasnější bezpečný okamžik a bez závislosti na platform kanálu.
  /// Opakované volání je zbytečné (requestFocus je idempotentní); protože
  /// jde o jediné volací místo, nemůže vzniknout duplicitní inicializace.
  void _initPrimaryFocus() {
    // Z1: requestFocus PŘED zapnutím režimu, aby jej listener fokusu
    // nemohl předčasně vypnout (při rovnosti s _mainFocusNode nic
    // neshazuje — viz _handlePrimaryFocusChanged).
    _mainFocusNode.requestFocus();
    _expressionControlActive = true;
    _expressionControlOffReason = _ExpressionControlOffReason.none;
  }

  /// Načtení verze aplikace. Pouze verze — počáteční fokus ani Z1 zde NEJSOU
  /// (viz [_initPrimaryFocus], volané z [initState]). Chyba načtení verze
  /// nesmí bránit běžnému používání kalkulačky: zůstane prázdná verze a
  /// guardy v [_checkForUpdates], [_checkForNews] i
  /// [_maybeRunDevAutodiagnostics] ji bezpečně přeskočí.
  Future<void> _initAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // Jediný zápis verze (notifier je zdroj pravdy; getter ji jen čte).
      _appVersionNotifier.value = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Verze se nepodařila načíst — kalkulačka pokračuje bez verze.
    }
    if (mounted) {
      _checkForUpdates();
      _checkForNews();
      _maybeRunDevAutodiagnostics();
    }
  }

  void _maybeRunDevAutodiagnostics() {
    if (_devAutoDiagShown) return;
    if (!_devModeEnabled || !_devAutoDiagnosticEnabled) return;
    if (!mounted) return;
    // Vyžaduje načtenou verzi – pokud ještě není, odloží se
    // (voláno znovu po dokončení _initAppVersion i po načtení nastavení).
    if (_currentAppVersion.isEmpty) {
      return;
    }
    _devAutoDiagShown = true;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _devModeEnabled && _devAutoDiagnosticEnabled) {
        _runDisplayDiagnostics();
      }
    });
  }

  String get _currentNumericVersion {
    return _currentAppVersion.split('+').first;
  }

  Future<void> _checkForNews() async {
    if (!mounted || _updateDialogShown) {
      return;
    }
    // Bez načtené verze nelze porovnávat – odloží se na dokončení loadu.
    if (_currentAppVersion.isEmpty) {
      return;
    }
    if (_lastSeenNewsVersion == null) {
      return;
    }
    final currentNumeric = _currentNumericVersion;
    if (_lastSeenNewsVersion == currentNumeric) {
      return;
    }

    final checker = GitHubReleaseChecker();
    final result = await checker.fetchRecentReleasesWithResult(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      perPage: 30,
      page: 1,
    );
    checker.close();
    if (!mounted) return;

    // Uložit cache při úspěchu, i když currentRelease není nalezena
    if (result.isSuccess && result.releases.isNotEmpty) {
      await _saveNewsCache(result.releases);
    }

    final currentRelease = _findReleaseForVersion(
      result.releases,
      currentNumeric,
    );
    if (currentRelease == null) {
      return;
    }

    await _markNewsSeen(currentNumeric);

    await _showNewsDialog(initialFocusVersion: currentRelease);
  }

  Future<void> _saveNewsCache(List<GitHubReleaseInfo> releases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = releases
          .map(
            (r) => {
              'tag_name': r.tagName,
              'html_url': r.htmlUrl,
              'body': r.body,
            },
          )
          .toList();
      await prefs.setString('news_cache_json', jsonEncode(jsonList));
      await prefs.setString(
        'news_cache_timestamp',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  GitHubReleaseInfo? _findReleaseForVersion(
    List<GitHubReleaseInfo> releases,
    String numericVersion,
  ) {
    for (final release in releases) {
      if (release.normalizedVersion == numericVersion) {
        return release;
      }
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_handlePrimaryFocusChanged);
    _quickSetupTimer?.cancel();
    _devTapTimer?.cancel();
    _voiceCreationSession?.dispose();
    _mainFocusNode.dispose();
    _displayA11yFocusNode.dispose();
    _resultFocusNode.dispose();
    _displayA11yController.dispose();
    _readingOrderFocusNode.dispose();
    _scrollControllerH.dispose();
    _scrollControllerResultH.dispose();
    _scrollControllerV.dispose();
    _dialogFontScaleNotifier.dispose();
    _appVersionNotifier.dispose();
    super.dispose();
  }

  void _startVoiceSetCreation() {
    final session = _voiceCreationSession;
    if (session != null && !session.finished) {
      session.cancelByUser();
      return;
    }
    _voiceCreationSession = _VoiceSetCreationSession(this)..start();
  }

  void _onVoiceSessionEnded() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAccessibilityFeatures() {
    _refreshAccessibilityState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sekundární signál pro R5: změna accessibleNavigation se projeví
    // přes rebuild i tam, kde engine nevyvolá didChangeAccessibilityFeatures.
    bool mq = false;
    try {
      mq = MediaQuery.accessibleNavigationOf(context);
    } catch (_) {
      mq = false;
    }
    if (_lastMqAccessibleNavigation != mq) {
      _lastMqAccessibleNavigation = mq;
      _refreshAccessibilityState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAccessibilityState();
    }
  }

  Future<void> _checkForUpdates() async {
    if (_updateDialogShown || !mounted) {
      return;
    }
    // Bez načtené verze nelze porovnávat (prázdná by se jevila starší
    // než jakákoli release). Auto-cesta běží až po loadu; guard pro jistotu.
    if (_currentAppVersion.isEmpty) {
      return;
    }

    final checker = GitHubReleaseChecker();
    final release = await checker.checkForUpdates(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      currentVersion: _currentAppVersion,
    );

    if (!mounted || release == null || _updateDialogShown) {
      return;
    }

    await _showUpdateDialog(release);
  }

  Future<void> _checkForUpdatesManually() async {
    if (!mounted) return;
    // Ruční kontrola před dokončením loadu: dříve LateInitializationError,
    // s prázdnou verzí falešný update dialog – proto slušné odmítnutí
    // jediným standardním kanálem.
    if (_currentAppVersion.isEmpty) {
      _showAccessibleSnackBar(
        _s(
          'Verze se ještě načítá, zkuste to za chvíli.',
          'Version is still loading, please try again in a moment.',
        ),
      );
      return;
    }
    final checker = GitHubReleaseChecker();
    final release = await checker.checkForUpdates(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      currentVersion: _currentAppVersion,
    );
    checker.close();
    if (!mounted) return;
    if (release != null) {
      await _showUpdateDialog(release);
    } else {
      // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
      _showAccessibleSnackBar(_l10n.appIsCurrent);
    }
  }

  Future<void> _showUpdateDialog(GitHubReleaseInfo release) async {
    setState(() {
      _updateDialogShown = true;
    });

    await showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Dostupná aktualizace'),
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(_l10n.updateAvailableTitle)),
        content: Semantics(
          label: _l10n.newVersionSemantics(
            release.normalizedVersion,
            _currentAppVersion,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.newVersionText(
                  release.normalizedVersion,
                  _currentAppVersion,
                ),
              ),
              if (release.releaseSummary.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _l10n.whatIsNew,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(release.releaseSummary),
              ],
            ],
          ),
        ),
        actions: [
          Semantics(
            label: _l10n.later,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.later),
            ),
          ),
          Semantics(
            label: _l10n.showRelease,
            child: FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final url = release.htmlUrl;
                if (url != null) {
                  final uri = Uri.parse(url);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (!mounted) return;
                    _showAccessibleSnackBar(
                      _s(
                        'Nelze otevřít prohlížeč: $e',
                        'Could not open browser: $e',
                      ),
                    );
                  }
                }
              },
              child: Text(_l10n.showRelease),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewsDialog({GitHubReleaseInfo? initialFocusVersion}) async {
    if (!mounted) return;

    await showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Novinky'),
      builder: (dialogContext) =>
          _NewsDialog(parent: this, initialFocusVersion: initialFocusVersion),
    );
  }

  Future<void> _initTts() async {
    bool ttsReadySuccess = false;
    try {
      // 1. Deterministické načtení: globál → profily v2 → active apply → TTS
      await _loadGlobalSettings();
      try {
        await _loadProfilesV2();
      } catch (e) {
        debugPrint('Profiles preload Error: $e');
      }
      // Konfigurace (globály + profily) je načtena – uvolni startup draft.
      // Schválně PŘED stats/TTS, aby jejich visící I/O neblokovalo onboarding.
      _markConfigLoaded();
      // 2. Data potřebná pro startupové oznámení – zejména statistické sady.
      //    Musí být načtena PŘED sestavením uvítací zprávy, jinak by
      //    _statsModeAnnouncement() vidělo prázdný seznam a sada/pole by
      //    v uvítání chyběly. Historie pro uvítání potřeba není.
      try {
        await _loadStatsData();
      } catch (e) {
        debugPrint('Stats preload Error: $e');
      }
      unawaited(_loadHistory());
      // 3. Inicializace TTS (engine, jazyk, hlas, rychlost, hlasitost).
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final l10n = lookupAppLocalizations(locale);
      _lastTtsLocale = locale.languageCode == 'en' ? 'en-US' : 'cs-CZ';
      // Windows backend nepodporuje setEngine – vynechat.
      if (!Platform.isWindows && _ttsEngine != null) {
        try {
          await tts.setEngine(_ttsEngine!);
        } catch (e) {
          debugPrint('TTS setEngine Error: $e');
        }
      }
      // Nastavení jazyka s kontrolou dostupnosti hlasů na Windows.
      bool languageSetOk = true;
      try {
        await tts.setLanguage(_lastTtsLocale!);
      } catch (e) {
        languageSetOk = false;
        debugPrint('TTS setLanguage Error for $_lastTtsLocale: $e');
        if (Platform.isWindows && _lastTtsLocale == 'cs-CZ') {
          debugPrint('TTS: český hlas cs-CZ není ve Windows dostupný.');
        }
      }
      // Windows readiness kontrola – ověřit dostupné hlasy před prvním speak.
      if (Platform.isWindows) {
        try {
          final voices = await tts.getVoices;
          if (voices != null && voices is List && voices.isNotEmpty) {
            final voiceList = voices.cast<Map<dynamic, dynamic>>();
            final hasDesiredLocale = voiceList.any(
              (v) =>
                  (v['locale']?.toString().toLowerCase() ==
                      _lastTtsLocale!.toLowerCase()) ||
                  (v['name']?.toString().toLowerCase().contains('cs-cz') ??
                      false) ||
                  (v['name']?.toString().toLowerCase().contains('czech') ??
                      false),
            );
            if (!hasDesiredLocale) {
              debugPrint('TTS: český hlas cs-CZ není ve Windows dostupný.');
              // Technický fallback pouze pro diagnostiku – ne automatický přepis
              // českého textu na angličtinu jako běžné chování.
              // Zkusit najít jakýkoli hlas s locale obsahujícím 'cs', jinak první dostupný.
              Map<dynamic, dynamic>? fallback;
              try {
                fallback = voiceList.firstWhere(
                  (v) =>
                      v['locale']?.toString().toLowerCase().contains('cs') ??
                      false,
                );
              } catch (_) {
                fallback = null;
              }
              fallback ??= voiceList.first;
              final fbLocale = fallback['locale']?.toString() ?? 'unknown';
              final fbName = fallback['name']?.toString() ?? 'unknown';
              debugPrint(
                'TTS: cs-CZ není dostupné, použit fallback $fbName ($fbLocale).',
              );
              // Fallback setLanguage pouze pokud původní selhalo a fallback je jiný.
              if (!languageSetOk &&
                  fbLocale.toLowerCase() != _lastTtsLocale!.toLowerCase()) {
                try {
                  await tts.setLanguage(fbLocale);
                } catch (e) {
                  debugPrint('TTS fallback setLanguage Error: $e');
                }
              }
            }
          } else {
            debugPrint('TTS: getVoices vrátil prázdný seznam na Windows.');
            if (_lastTtsLocale == 'cs-CZ') {
              debugPrint('TTS: český hlas cs-CZ není ve Windows dostupný.');
            }
          }
        } catch (e) {
          debugPrint('TTS Windows voice check Error: $e');
          if (_lastTtsLocale == 'cs-CZ') {
            debugPrint('TTS: český hlas cs-CZ není ve Windows dostupný.');
          }
        }
      }
      if (_ttsVoice != null) {
        try {
          await tts.setVoice(_ttsVoice!);
        } catch (e) {
          debugPrint('TTS setVoice Error: $e');
        }
      }
      try {
        await tts.setSpeechRate(_speechRate);
      } catch (e) {
        debugPrint('TTS setSpeechRate Error: $e');
      }
      try {
        await tts.setVolume(_speechVolume);
      } catch (e) {
        debugPrint('TTS setVolume Error: $e');
      }
      try {
        await tts.setQueueMode(0);
      } catch (e) {
        debugPrint('TTS setQueueMode Error: $e');
      }
      ttsReadySuccess = true;
      // 4. Aktuální stav screen readeru – await, aby volba
      //    announce-vs-speak nevycházela ze zastaralé hodnoty.
      //    (Samotná detekce v _isScreenReaderEnabled se nemění.)
      try {
        await _refreshAccessibilityState().timeout(const Duration(seconds: 2));
      } catch (_) {}
      // 5. Až po všem výše – právě jednou – sestavit a oznámit uvítání.
      if (_sayWelcome && !_welcomeAnnounced) {
        String welcome = l10n.welcomeMessage(
          _getModeSpeechNameForL10n(_currentMode, l10n),
        );
        if (_currentMode == CalculatorMode.statistics) {
          // Stejná metoda jako při ručním přepnutí (_changeMode),
          // aby startup a přepnutí hlásily konzistentní informace.
          welcome += _statsModeAnnouncement();
        }
        unawaited(_announceWelcomeOnce(welcome));
      }
      // Auto-aktualizace kurzů ČNB (silent, max 1× za 24h)
      try {
        final needsUpdate =
            _currencyLastUpdate == null ||
            DateTime.now().difference(_currencyLastUpdate!).inHours >= 24;
        if (needsUpdate) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _updateCurrencyRatesOnline(silent: true);
          });
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('TTS Error: $e');
    } finally {
      if (!_ttsReady.isCompleted) {
        _ttsReady.complete(ttsReadySuccess);
      }
      // Pojistka: startup draft nesmí čekat věčně, ani kdyby selhalo
      // samotné načtení konfigurace.
      _markConfigLoaded();
    }
  }

  /// Jediný startup flow rychlého nastavení. Nahrazuje předchozí dva
  /// nezávislé povinné dialogy (_showInitialAccessibilityDialog +
  /// _showInitialModeDialog). Nezobrazí se nikdy dvakrát po sobě a pro
  /// staré validní instalace se neptá vůbec (migrace markeru).
  bool _quickSetupShown = false;
  Timer? _quickSetupTimer;

  Future<void> _maybeShowQuickSetup() async {
    if (_quickSetupShown || !mounted) return;
    _quickSetupShown = true;
    // Draft se smí stavět teprve z načtené konfigurace (globály + profily),
    // jinak by Apply přepsal skutečnou konfiguraci výchozími hodnotami.
    try {
      await _configLoaded.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      return;
    }
    if (!mounted) return;
    bool firstRun;
    try {
      final prefs = await SharedPreferences.getInstance();
      firstRun = await isQuickSetupFirstRun(prefs);
    } catch (_) {
      return;
    }
    if (!firstRun || !mounted) return;
    final draft = QuickSetupDraft.fromRuntime(
      settings: _getActiveAccessibilityProfile().settings,
      themeMode: widget.themeMode,
      isDegreeMode: _isDegreeMode,
      defaultMode: _defaultMode,
      resultDisplayMode: _globalResultDisplayMode,
    );
    await showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: 'Rychlé nastavení'),
      builder: (dialogContext) => QuickSetupDialog(
        initialDraft: draft,
        availableVoices: _loadAvailableVoices(),
        tr: _s,
        isFirstRun: true,
        announce: (msg) => say(msg, dialogContext),
        onCancel: () => _cancelQuickSetup(dialogContext),
        onApply: (next) => _applyQuickSetup(next, dialogContext),
      ),
    );
  }

  /// Ruční otevření rychlého nastavení z menu (nepovinné, zavíratelné).
  void _openQuickSetupManually() {
    final draft = QuickSetupDraft.fromRuntime(
      settings: _getActiveAccessibilityProfile().settings,
      themeMode: widget.themeMode,
      isDegreeMode: _isDegreeMode,
      defaultMode: _defaultMode,
      resultDisplayMode: _globalResultDisplayMode,
    );
    showAppDialog<void>(
      context: context,
      barrierDismissible: true,
      routeSettings: const RouteSettings(name: 'Rychlé nastavení'),
      builder: (dialogContext) => QuickSetupDialog(
        initialDraft: draft,
        availableVoices: _loadAvailableVoices(),
        tr: _s,
        isFirstRun: false,
        announce: (msg) => say(msg, dialogContext),
        onCancel: () => Navigator.of(dialogContext).pop(),
        onApply: (next) => _applyQuickSetup(next, dialogContext),
      ),
    );
  }

  /// Normalizovaný seznam dostupných TTS hlasů. Nikdy nevyhodí.
  Future<List<Map<String, String>>> _loadAvailableVoices() async {
    try {
      final raw = await tts.getVoices;
      if (raw == null) return [];
      final out = <Map<String, String>>[];
      for (final v in raw) {
        final norm = normalizeVoiceMap(
          v is Map ? Map<String, dynamic>.from(v as Map) : v,
        );
        if (norm != null) out.add(norm);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Storno: NESMÍ změnit settings/profiles/globals/theme/contract.
  /// Smí pouze uložit `quickSetupCompleted = true`.
  Future<void> _cancelQuickSetup(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await markQuickSetupSeen(prefs);
    } catch (_) {}
  }

  /// Apply: draft → validate → canonical snapshot → persist → teprve pak
  /// runtime apply → completion marker. Při chybě persistu se runtime
  /// NESMÍ změnit a marker se NESMÍ nastavit.
  Future<void> _applyQuickSetup(
    QuickSetupDraft draft,
    BuildContext dialogContext,
  ) async {
    // Voice resolution proti skutečně dostupným hlasům zařízení.
    QuickSetupDraft effective = draft;
    try {
      final available = await _loadAvailableVoices();
      final requested = draft.settings.ttsVoice;
      if (requested != null) {
        final resolved = resolveVoice(requested, available);
        if (resolved == null) {
          effective = draft.copyWith(
            settings: draft.settings.copyWith(
              clearTtsVoice: true,
              clearTtsVoiceName: true,
            ),
          );
        } else if (resolved['name'] != requested['name'] ||
            resolved['locale'] != requested['locale']) {
          effective = draft.copyWith(
            settings: draft.settings.copyWith(
              ttsVoice: resolved,
              ttsVoiceName: resolved['name'],
            ),
          );
        }
      }
    } catch (_) {}
    // Canonical snapshot + validace.
    late Map<String, dynamic> contract;
    try {
      contract = buildQuickSetupContract(
        draft: effective,
        profiles: _profiles,
        activeProfileId: _activeProfileId,
        statsSummaryOrder: _statsSummaryOrder,
        statsComputedOrder: _statsComputedOrder,
        currencyFrom: _currencyFrom,
        currencyTo: _currencyTo,
        devEnabled: _devModeEnabled,
        devAutoDiagnostic: _devAutoDiagnosticEnabled,
        devDiagnosticDurationMs: _devDiagnosticDurationMs,
        devPinCode: _devPinCode,
        historyExactFormat: _historyExactFormat,
      );
      final vr = validateQuickSetupContract(contract);
      if (!vr.ok) throw StateError('Neplatná konfigurace rychlého nastavení');
    } catch (e) {
      debugPrint('QuickSetup build/validate Error: $e');
      if (mounted) {
        _showAccessibleSnackBar(
          _s(
            'Rychlé nastavení se nepodařilo připravit',
            'Quick setup could not be prepared',
          ),
        );
      }
      return;
    }
    // Persist PŘED jakoukoli změnou runtime.
    try {
      final prefs = await SharedPreferences.getInstance();
      await persistCanonicalContract(prefs, contract);
    } catch (e) {
      debugPrint('QuickSetup persist Error: $e');
      if (mounted) {
        _showAccessibleSnackBar(
          _s(
            'Nastavení se nepodařilo uložit, původní konfigurace zůstává',
            'Settings could not be saved, previous configuration kept',
          ),
        );
      }
      return;
    }
    // Teprve po úspěšné persistenci: runtime apply.
    final parsed = parseContract(contract);
    if (!mounted) return;
    setState(() {
      _profiles = parsed.profiles;
      _activeProfileId = parsed.activeProfileId;
      _globalResultDisplayMode = parsed.resultDisplayMode;
      _isDegreeMode = parsed.isDegreeMode;
      _defaultMode = parsed.defaultMode;
      _currentMode = parsed.defaultMode;
    });
    widget.onThemeModeChanged(parsed.themeMode);
    final activeSettings = _getActiveAccessibilityProfile().settings;
    _applySettingsToRuntime(activeSettings);
    // Hlas s fallbackem: selhání setVoice nesmí shodit apply.
    try {
      if (activeSettings.ttsVoice != null) {
        await tts.setVoice(activeSettings.ttsVoice!);
      } else {
        await tts.clearVoice();
      }
    } catch (_) {
      try {
        await tts.clearVoice();
      } catch (_) {}
    }
    _dialogFontScaleNotifier.value = activeSettings.dialogFontScale;
    if (mounted) setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await markQuickSetupSeen(prefs);
    } catch (_) {}
    Navigator.of(dialogContext).pop();
    say(_s('Nastavení použito', 'Settings applied'), dialogContext);
  }

  /// Startupové uvítání – doručí se právě jednou, až po prvním vykreslení.
  ///
  /// Při aktivní čtečce jde zpráva přes `SemanticsService.announce`
  /// (vlastní TTS by `speak()` stejně potlačilo a vznikla by duplicita).
  /// Bez čtečky jde přes vlastní TTS až po skutečném dokončení
  /// inicializace (Completer + postFrame), 350ms delay již není
  /// mechanismus připravenosti.
  Future<void> _announceWelcomeOnce(String welcome) async {
    if (_welcomeAnnounced || welcome.isEmpty) return;
    // 1. Počkat na připravenost TTS (Completer z _initTts, max 5s, neblokuje UI).
    await _waitForTtsReady;
    if (!mounted || _welcomeAnnounced || welcome.isEmpty) return;
    // 2. Počkat na vhodný okamžik po vykreslení UI.
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    // Pokud již proběhl frame, addPostFrameCallback se zavolá v příštím frame.
    // Pojistit timeoutem aby neuvízl navždy.
    try {
      await completer.future.timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (!mounted || _welcomeAnnounced) return;
    // 3. Zjistit stav screen readeru.
    // _refreshAccessibilityState již proběhl v _initTts, ale pro jistotu
    // re-check pokud ještě není rozhodnuto (neblokuje dlouho).
    // 4. Pokud je aktivní screen reader → Semantics kanál.
    // UNKNOWN se chová jako aktivní (žádné vlastní TTS → žádný double-speech).
    if (_isScreenReaderActive != false) {
      _announce(welcome);
      _welcomeAnnounced = true;
      return;
    }
    // 5. Bez screen readeru → vlastní TTS s lokálním awaitSpeakCompletion.
    // Pouze pro welcome dočasně zapnout čekání na dokončení, ne globálně.
    try {
      try {
        await tts.awaitSpeakCompletion(true);
      } catch (_) {}
      final result = await speak(welcome);
      // 6. Zkontrolovat výsledek tts.speak()
      if (result == 1) {
        _welcomeAnnounced = true;
      } else {
        debugPrint('TTS welcome speak failed, result=$result');
        // Neoznačovat jako přehrané – umožní případný retry (např. po změně hlasu),
        // ale chránit proti duplicitě v rámci tohoto startu.
        // Pokud speak selhal kvůli chybějícímu českému hlasu, log již proběhl v _initTts.
      }
    } finally {
      try {
        await tts.awaitSpeakCompletion(false);
      } catch (_) {}
    }
  }

  String _getModeName(CalculatorMode mode) {
    switch (mode) {
      case CalculatorMode.basic:
        return _l10n.modeBasic;
      case CalculatorMode.scientific:
        return _l10n.modeScientific;
      case CalculatorMode.statistics:
        return _l10n.modeStatistics;
      case CalculatorMode.electrician:
        return _l10n.modeElectrician;
      case CalculatorMode.unitConversion:
        return _l10n.modeUnitConversion;
      case CalculatorMode.time:
        return _l10n.modeTime;
      case CalculatorMode.currency:
        return _l10n.modeCurrency;
    }
  }

  String _getModeSpeechName(CalculatorMode mode) {
    return _getModeSpeechNameForL10n(mode, _l10n);
  }

  /// Sjednocená detekce aktivního screen readeru.
  ///
  /// Android -> nativní `isTalkBackEnabled` (AccessibilityManager).
  /// Windows -> nativní `isScreenReaderEnabled` (SPI_GETSCREENREADER ||
  ///   UiaClientsAreListening), generická pro NVDA / JAWS / Narrator.
  /// Ostatní platformy nebo selhání nativu -> Flutter fallback
  /// `accessibleNavigation` (pouze jako fallback, ne hlavní detekce).
  Future<bool> _isScreenReaderEnabled() async {
    if (Platform.isAndroid) {
      try {
        final result = await _accessibilityChannel.invokeMethod<bool>(
          'isTalkBackEnabled',
        );
        if (result != null) return result;
      } catch (_) {
        // Propadne na fallback níže.
      }
    } else if (Platform.isWindows) {
      try {
        final result = await _accessibilityChannel.invokeMethod<bool>(
          'isScreenReaderEnabled',
        );
        if (result != null) return result;
      } catch (_) {
        // Propadne na fallback níže.
      }
    }
    return WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .accessibleNavigation;
  }

  Future<void> _refreshAccessibilityState() async {
    // R5: sekvenční token – starší výsledek nesmí přepsat novější stav.
    final seq = ++_srRefreshSeq;
    final enabled = await _isScreenReaderEnabled();
    if (!mounted || seq != _srRefreshSeq) return;
    setState(() {
      _accessibleNavigation = enabled;
    });
  }

  /// Stav detekce čtečky (R5): true = aktivní, false = neaktivní,
  /// null = UNKNOWN (detekce ještě nedoběhla, režim auto).
  /// Při UNKNOWN se vlastní TTS nespouští – prevence double-speech.
  bool? get _isScreenReaderActive {
    switch (_screenReaderMode) {
      case ScreenReaderMode.on:
        return true;
      case ScreenReaderMode.off:
        return false;
      case ScreenReaderMode.auto:
        return _accessibleNavigation;
    }
  }

  /// Centrální accessibility mechanismus (R-architektura):
  /// jedna událost → jedno oznámení právě jedním kanálem.
  /// - [isNumeric]: true = číslo/matematický zápis (číselný formatter),
  ///   false = běžná věta (větný formatter, interpunkce se nemění).
  /// - [interruptCurrentSpeech]: zda přerušit právě mluvené vlastní TTS.
  ///   NIKDY neobchází ochranu aktivní čtečky (na rozdíl od starého force).
  Future<void> announceEvent(
    String message, {
    required SpeechCategory category,
    bool isNumeric = false,
    bool interruptCurrentSpeech = false,
  }) async {
    if (message.isEmpty || !mounted) return;
    // R6: číselná zpráva projde číselným formatterem a pak větným
    // (ten doplní jen π → slovo); věta projde pouze větným.
    final formatted = isNumeric
        ? _sentenceToSpeech(_numberToSpeech(message))
        : _sentenceToSpeech(message);
    if (_isScreenReaderActive == true) {
      // Při aktivní čtečce změnu editované hodnoty oznamuje displej
      // (liveRegion) – žádný další explicitní event (R1: žádná duplicita).
      if (category == SpeechCategory.valueChange) return;
      _publishSemanticsAnnouncement(formatted);
      return;
    }
    // UNKNOWN (auto + nedoběhlá detekce): vlastní TTS by mohlo způsobit
    // double-speech souběžně s čtečkou – raději mlčet (R5).
    if (_isScreenReaderActive == null &&
        _screenReaderMode == ScreenReaderMode.auto) {
      return;
    }
    await _speakTts(formatted, interrupt: interruptCurrentSpeech);
  }

  /// Vlastní TTS – jediná cesta k tts.speak mimo testy.
  Future<int?> _speakTts(String formatted, {bool interrupt = false}) async {
    if (!ttsEnabled || !mounted) return null;
    try {
      if (interrupt) await tts.stop();
      final result = await tts.speak(formatted);
      return result;
    } catch (e) {
      debugPrint('TTS Error: $e');
      return 0;
    }
  }

  /// Publikace oznámení Semantics kanálem (při aktivní čtečce).
  /// Android: primárně dedikovaný liveRegion (doporučení Flutteru místo
  /// deprecated announcement eventů). Windows: přednostně
  /// SemanticsService.sendAnnouncement, fallback liveRegion.
  /// Nikdy současně s vlastním TTS stejné události.
  void _publishSemanticsAnnouncement(String formatted) {
    if (formatted.isEmpty || !mounted) return;
    _lastPublishedAnnouncement = formatted;
    _publishedAnnouncementCount++;
    if (!Platform.isWindows) {
      setState(() {
        _lastAnnouncement = formatted;
      });
      return;
    }
    bool delivered = false;
    try {
      final view = View.of(context);
      TextDirection dir = TextDirection.ltr;
      try {
        dir = Directionality.of(context);
      } catch (_) {
        dir = TextDirection.ltr;
      }
      // ignore: deprecated_member_use_from_same_package
      unawaited(SemanticsService.sendAnnouncement(view, formatted, dir));
      delivered = true;
    } catch (_) {
      delivered = false;
    }
    if (!delivered && mounted) {
      setState(() {
        _lastAnnouncement = formatted;
      });
    }
  }

  Future<int?> speak(String text, {bool force = false}) async {
    // R4/R7: force znamená pouze "přeruš aktuální vlastní TTS"
    // (interrupt). NIKDY neobchází ochranu aktivní čtečky.
    // Vstup prochází větným formatterem – čísla musí být předformátována
    // volajícím (R6), aby se větám neměnila interpunkce.
    if (text.isEmpty ||
        !ttsEnabled ||
        !mounted ||
        _isScreenReaderActive == true) {
      return null;
    }
    if (_isScreenReaderActive == null &&
        _screenReaderMode == ScreenReaderMode.auto) {
      return null;
    }
    // QUEUE_FLUSH zajistí, že nová mluva okamžitě přeruší tu aktuální.
    try {
      if (force) await tts.stop();
      final result = await tts.speak(_formatForSpeech(text));
      return result;
    } catch (e) {
      debugPrint('TTS Error: $e');
      return 0;
    }
  }

  void _announce(String message, [BuildContext? ctx]) {
    if (message.isEmpty || !mounted) return;
    // R-architektura: jednotný kanál přes announceEvent.
    // (ctx se ignoruje – směr se čte z vlastního contextu.)
    unawaited(
      announceEvent(message, category: SpeechCategory.actionConfirm),
    );
  }

  void _showAccessibleSnackBar(
    String message, {
    Widget? visualContent,
    Duration duration = const Duration(seconds: 4),
    BuildContext? scaffoldContext,
    String? announceMessage,
    // R9: false = pouze vizuál, oznámení už proběhlo jinde (žádná duplicita).
    bool announce = true,
  }) {
    if (!mounted || message.isEmpty) return;
    final c = scaffoldContext ?? context;
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: visualContent ?? Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
    // Oznámení jde jednotným kanálem (při SR liveRegion/sendAnnouncement,
    // jinak TTS) – nikdy současně s paralelním speak() stejné zprávy.
    if (!announce) return;
    final toAnnounce = announceMessage ?? message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        announceEvent(toAnnounce, category: SpeechCategory.actionConfirm),
      );
    });
  }

  String _formatForSpeech(String text) {
    // R6: TTS vstupem prochází pouze větný formatter. Čísla musí být
    // předformátována volajícím (_numberToSpeech/_formatSpokenNumber/...),
    // aby se větám neměnila interpunkce a exponenty.
    return _sentenceToSpeech(text);
  }

  String _formatDmsSpeech(String dmsStr) {
    if (_isEnglish()) {
      return dmsStr
          .replaceAll('°', ', degrees, ')
          .replaceAll("'", ' minutes and ')
          .replaceAll('"', ' seconds');
    }
    // R6: desetinný oddělovač podle jazyka, pouze v číselném kontextu.
    return _localizeDecimalSeparator(
      dmsStr
          .replaceAll('°', ' stupňů, ')
          .replaceAll("'", ' minut a ')
          .replaceAll('"', ' sekund'),
    );
  }

  /// Z1-dokončení: reaktivace režimu prvním stiskem šipky/Home/End po
  /// návratu primárního fokusu (po Tab-navigaci i po úplném zavření
  /// dialogů). Proběhne pouze, když není otevřený žádný dialog
  /// (`_dialogDepth == 0`) — za otevřeným dialogem se ovládání výrazu
  /// armovat nesmí (požadavek: klávesa nesmí dialog obejít). Návrat fokusu
  /// sám nic nezapíná; zapíná až tento výslovný stisk. Při reaktivaci se
  /// kurzor NEPOSOUVÁ, režim se oznámí právě jednou
  /// ([_announceExpressionControl]); volající vrátí `handled`.
  /// V NVDA Browse Mode šipky do aplikace nedorazí, takže běžná navigace
  /// odečítače zůstává nedotčena. Nemění `_cursorPosition`, fokus ani
  /// traversál; nespouští softwarovou klávesnici.
  /// Vrací true, právě když reaktivace proběhla.
  bool _tryReactivateExpressionControl() {
    if (_expressionControlActive || !_mainFocusNode.hasPrimaryFocus) {
      return false;
    }
    if (_dialogDepth > 0) {
      return false;
    }
    _expressionControlActive = true;
    _expressionControlOffReason = _ExpressionControlOffReason.none;
    _announceExpressionControl();
    return true;
  }

  /// Z1: klávesový handler s konzumací (`Focus.onKeyEvent`). `handled` vrací
  /// VÝHRADNĚ za šipky/Home/End, jimiž aplikace v režimu ovládání výrazu
  /// skutečně pohnula kurzorem. Všechny ostatní cesty vracejí `ignored`
  /// (tedy propagaci shodnou s předchozím `void` handlerem): kořenový uzel
  /// je PŘEDKEM tlačítek, a konzumace např. Enteru by spolkla aktivační
  /// intent fokusovaného potomka (zpracovává jej až Shortcuts nad kořenem —
  /// viz fraction_toggle testy K/J). Šipky/Home/End navíc vyžadují režim
  /// ovládání výrazu (`_expressionControlActive`) a primární fokus na
  /// [_mainFocusNode] — samotné `hasFocus` by pouštělo šipky i při
  /// fokusovaném tlačítku klávesnice (předek ve stromu).
  /// Zpracovává pouze `KeyDownEvent`; `KeyRepeatEvent`/`KeyUpEvent` kurzor
  /// neposouvají (držení klávesy dnes nic neopakovalo — zachováno).
  KeyEventResult _handleKeyboardInput(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final char = event.character;
      final isControl = HardwareKeyboard.instance.isControlPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      // Desetinná čárka -> interní tečka. Normalizuje se TU, ještě před
      // jakýmkoli filtrem (před filtrou pro aktivní odečítač níže i před
      // obecnou filtrací znaků). Na českém rozložení Windows vydá fyzická
      // desetinná klávesa znak ','; ten by jinak odmítl filtr pro aktivní
      // odečítač a znak by se zahodil dřív, než se dostal k
      // _handleButtonPressed. Bez odečítače stejnou normalizaci už dělala
      // spodní větev — chování obou cest se tím sjednocuje, nemění.
      String? effectiveChar = char == ',' ? '.' : char;

      // Numerická desetinná klávesa (numpadDecimal). Windows posílá znak
      // přes WM_CHAR podle aktivního rozložení (','/'.') — ten se normalizuje
      // výše. Android/Google klávesnice však numerické klávesy často posílají
      // BEZ znaku; pak rozhoduje logická klávesa. S Ctrl/Shift se chování
      // záměrně nemění, aby se nezachytila žádná dosud nezpracovaná kombinace
      // (Ctrl+NumpadDesetinná dosud nedělá nic) a aby AltGr fake-Ctrl
      // nevypadl. Protože fallback běží jen při char == null, nikdy se
      // tentýž stisk nezpracuje dvakrát.
      if (char == null &&
          !isControl &&
          !isShift &&
          event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
        effectiveChar = '.';
      }

      // Pohyb kurzoru ve výrazu — musí fungovat i při aktivním screen
      // readeru, proto před SR filtrem níže (šípky/Home/End nenesou znak).
      // Shift/Ctrl modifikátory se prozatím ignorují (žádný výběr textu).
      // Brána režimu (Z1): mimo režim ovládání výrazu nebo bez primárního
      // fokusu patří šipky odečítači/traversálu (ignored), kurzor se nemění.
      if (!isControl &&
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_expressionControlActive && _mainFocusNode.hasPrimaryFocus) {
          _moveCursorBy(-1);
          return KeyEventResult.handled;
        }
        // Z1-dokončení: reaktivace po Tab-návratu (bez pohybu kurzoru).
        if (_tryReactivateExpressionControl()) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      if (!isControl &&
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_expressionControlActive && _mainFocusNode.hasPrimaryFocus) {
          _moveCursorBy(1);
          return KeyEventResult.handled;
        }
        // Z1-dokončení: reaktivace po Tab-návratu (bez pohybu kurzoru).
        if (_tryReactivateExpressionControl()) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      if (!isControl && event.logicalKey == LogicalKeyboardKey.home) {
        if (_expressionControlActive && _mainFocusNode.hasPrimaryFocus) {
          _moveCursorTo(0);
          return KeyEventResult.handled;
        }
        // Z1-dokončení: reaktivace po Tab-návratu (bez pohybu kurzoru).
        if (_tryReactivateExpressionControl()) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      if (!isControl && event.logicalKey == LogicalKeyboardKey.end) {
        if (_expressionControlActive && _mainFocusNode.hasPrimaryFocus) {
          _moveCursorTo(display.length);
          return KeyEventResult.handled;
        }
        // Z1-dokončení: reaktivace po Tab-návratu (bez pohybu kurzoru).
        if (_tryReactivateExpressionControl()) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

      // Když je aktivní screen reader (NVDA, JAWS, TalkBack),
      // jednoznakové klávesy (S, C, T, A, P, atd.) se předávají čtečce.
      // Zpracovávají se pouze Ctrl+ kombinace, čísla, operátory a navigační klávesy.
      if (_isScreenReaderActive == true && effectiveChar != null && !isControl) {
        if (effectiveChar == '±') {
          _handleNegativeButton();
          return KeyEventResult.ignored;
        }
        // effectiveChar už nese interní tečku (čárka byla normalizována
        // na začátku handleru), takže čárka projde stejně jako tečka.
        final String singleChar = effectiveChar.toUpperCase();
        // Povolit číslice, desetinnou tečku a operátory + - * / ^ %
        if (RegExp(r'^[0-9.+\-*/^%]$').hasMatch(singleChar)) {
          _handleButtonPressed(singleChar, silent: true);
          return KeyEventResult.ignored;
        }
        // Všechny ostatní jednoznakové klávesy nechat projít do screen readeru
        return KeyEventResult.ignored;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        calculateResult();
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        backspace();
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        clear();
        return KeyEventResult.ignored;
      } else if (isControl &&
          isShift &&
          event.logicalKey == LogicalKeyboardKey.keyD) {
        // Zachovat původní '→° a zároveň umožnit dev režim přes Ctrl+Shift+Alt+D
        if (HardwareKeyboard.instance.isAltPressed) {
          _handleDevShortcut();
        } else {
          _handleButtonPressed("'→°");
        }
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyD) {
        _handleButtonPressed("°→'");
        return KeyEventResult.ignored;
      } else if (isControl &&
          isShift &&
          event.logicalKey == LogicalKeyboardKey.keyJ) {
        _handleDevShortcut();
        return KeyEventResult.ignored;
      } else if (!isControl && event.logicalKey == LogicalKeyboardKey.keyS) {
        _handleButtonPressed(isShift ? "ASIN" : "SIN");
        return KeyEventResult.ignored;
      } else if (!isControl && event.logicalKey == LogicalKeyboardKey.keyC) {
        _handleButtonPressed(isShift ? "ACOS" : "COS");
        return KeyEventResult.ignored;
      } else if (!isControl && event.logicalKey == LogicalKeyboardKey.keyT) {
        _handleButtonPressed(isShift ? "ATAN" : "TAN");
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.keyQ) {
        _handleButtonPressed("√");
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        _handleButtonPressed("ABS");
        return KeyEventResult.ignored;
      } else if (isControl &&
          isShift &&
          event.logicalKey == LogicalKeyboardKey.keyP) {
        _togglePeriod();
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
        _handleButtonPressed("\u03C0");
      } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _handleButtonPressed("ANS");
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        _insertDegree();
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyM) {
        if (_currentMode == CalculatorMode.statistics) {
          _handleMultipleStatisticsAddition();
        } else {
          _handleButtonPressed('M+');
        }
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        if (_currentMode == CalculatorMode.statistics) {
          _addSingleValueToStats();
        } else {
          _insertMinute();
        }
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit1) {
        _changeMode(CalculatorMode.basic);
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit2) {
        _changeMode(CalculatorMode.scientific);
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit3) {
        _changeMode(CalculatorMode.statistics);
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit4) {
        _changeMode(CalculatorMode.electrician);
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit5) {
        _changeMode(CalculatorMode.unitConversion);
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit6) {
        _changeMode(CalculatorMode.time);
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.digit7) {
        _changeMode(CalculatorMode.currency);
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.comma) {
        _showAccessibilityDialog();
        return KeyEventResult.ignored;
      } else if (isControl && event.logicalKey == LogicalKeyboardKey.tab) {
        if (isShift) {
          _cycleMode(-1);
        } else {
          _cycleMode(1);
        }
        return KeyEventResult.ignored;
      } else if (isControl &&
          (event.logicalKey == LogicalKeyboardKey.pageDown ||
              event.logicalKey == LogicalKeyboardKey.pageUp)) {
        if (_currentMode == CalculatorMode.scientific) {
          _toggleScientificFunctionsPage();
          return KeyEventResult.ignored;
        }
      } else if (char == '±') {
        _handleNegativeButton();
        return KeyEventResult.ignored;
      } else if (effectiveChar != null) {
        // effectiveChar už nese interní tečku (čárka normalizovaná na
        // začátku handleru) a případnou zálohu numpadDecimal, takže tato
        // větev nemusí normalizovat znovu.
        String toAppend = effectiveChar;
        if (RegExp(r'''[0-9.+\-*/^%()eE°'":;a-zA-Z]''').hasMatch(toAppend)) {
          _handleButtonPressed(toAppend.toUpperCase(), silent: true);
          return KeyEventResult.ignored;
        }
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _insertDegree() {
    append('°', silent: true);
    speak(_l10n.degreesUnit);
  }

  void _insertMinute() {
    // Pokud je kurzor na konci a poslední znak je číslo, doplníme '
    RegExp lastDigit = RegExp(r'\d$');
    if (display.isNotEmpty &&
        lastDigit.hasMatch(display.substring(0, _cursorPosition))) {
      append("'", silent: true);
      speak(_l10n.minutesUnit);
      return;
    }
    append("'", silent: true);
    speak(_l10n.minutesUnit);
  }

  void backspace() {
    _deleteAtCursor();
  }

  void clear() {
    setState(() {
      display = '';
      _cursorPosition = 0;
      _lastResult = '0.';
      _isStoreMode = false;
      _isRecallMode = false;
      _hasResult = false;
      _pendingNegOpens.clear();
      _lastResultIsPlainNumeric = false;
      _fractionOverride = null;
      // Vymazání ruší přesná metadata (klíč + generace).
      _lastExact = null;
      _lastExactKey = '';
      _resultGeneration++;
      _lastExactGeneration = _resultGeneration;
    });
    speak(_l10n.cleared);
  }

  void append(String value, {bool silent = false}) {
    _insertAtCursor(value);
    if (!silent) speak(_getButtonName(value));
  }

  /// Společný entry point pro uložení aktuální hodnoty do proměnné.
  /// Znovu používá jedinou business logiku: vyhodnocení [display],
  /// fallback na [_lastResult], kontrolu finite hodnoty, zápis do [_memory],
  /// persistenci přes [_saveStatsData] a hlasové potvrzení.
  /// Vrací true při úspěchu, false při chybě (neplatný výraz / NaN / Infinity).
  /// Jednotné oznámení neúspěšného uložení do paměti
  /// (R9: jedna hláška — announceEvent + vizuální SnackBar bez duplicity).
  void _announceStoreFailure(String message) {
    unawaited(
      announceEvent(
        message,
        category: SpeechCategory.error,
        interruptCurrentSpeech: true,
      ),
    );
    if (mounted) {
      _showAccessibleSnackBar(message, announce: false);
    }
  }

  bool storeCurrentValueToMemory(String name) {
    late double val;
    if (display.isNotEmpty) {
      try {
        final evaluated = _evaluateExpression(display);
        if (!evaluated.isFinite) {
          // Strukturální kontrola uvnitř _evaluateExpression nenašla důkaz
          // dělení nulou ani domény — jde o přetečení / neplatnou operaci.
          _announceStoreFailure(
            _messageForCalcError(
              _classifyResidualNonFinite(evaluated, display),
            ),
          );
          setState(() => _isStoreMode = false);
          return false;
        }
        val = evaluated;
      } on CalcError catch (e) {
        // Původní důvod chyby se zachovává — přesná hláška, ne generická.
        _announceStoreFailure(_messageForCalcError(e));
        setState(() => _isStoreMode = false);
        return false;
      } catch (e) {
        debugPrint('Unexpected store error: $e');
        _announceStoreFailure(_l10n.cannotStoreExpression);
        setState(() => _isStoreMode = false);
        return false;
      }
    } else {
      // Zdroj numerické pravdy je _lastNumericValue, nikdy prezentační
      // text _lastResult (může být 'Error', DMS či jiný speciální formát).
      // Není-li platná hodnota, nic se neukládá — nikdy tiše 0.
      final last = _lastNumericValue;
      if (last == null || !last.isFinite || _lastResult == 'Error') {
        _announceStoreFailure(_l10n.cannotStoreExpression);
        setState(() => _isStoreMode = false);
        return false;
      }
      val = last;
    }
    final String valStrVis = _formatNumberSmart(val).replaceAll('.', ',');
    final String valStrSpoken = _formatSpokenNumber(val);
    // Racionální vazba: exaktní výraz z displeje, jinak platný RationalValue
    // posledního výsledku, jinak nic (vazba se maže — nikdy zastaralá).
    Rational? storedRational;
    if (display.isNotEmpty) {
      final expanded = _expandAnsForRational(display);
      if (expanded != null) {
        final rr = tryEvaluateRational(expanded);
        if (rr is RationalOk) storedRational = rr.value;
      }
    } else {
      storedRational = _validRational;
    }
    setState(() {
      _memory[name] = val;
      _memoryOccupied.add(name);
      _isStoreMode = false;
      if (storedRational != null) {
        _rationalMemory[name] = storedRational;
      } else {
        _rationalMemory.remove(name);
      }
    });
    _saveStatsData();
    // R9: jedno potvrzení (dříve speak + announce SnackBaru).
    unawaited(
      announceEvent(
        _l10n.savedToVariable(name, valStrSpoken),
        category: SpeechCategory.actionConfirm,
      ),
    );
    if (mounted) {
      _showAccessibleSnackBar(
        _l10n.savedToVariable(name, valStrVis),
        visualContent: _PeriodicText(
          _l10n.savedToVariable(name, valStrVis),
          overlineThickness: _overlineThickness,
          overlineHeight: _overlineHeight,
        ),
        announce: false,
      );
    }
    return true;
  }

  /// Společný entry point pro vyvolání proměnné (RCL logika):
  /// vloží číselnou hodnotu do výrazu přes [_insertAtCursor],
  /// hlasově potvrdí, persistenci nemění.
  void recallMemoryVariable(String name) {
    String valStrVis = _formatNumberSmart(
      _memory[name]!,
    ).replaceAll('.', ',');
    String valStrSpoken = _formatSpokenNumber(_memory[name]!);
    // Exaktní vazba (závorkovaný tvar pro správnou prioritu), jinak číselně.
    final rat = _rationalMemory[name];
    if (rat != null && rat.denominator != BigInt.one) {
      append('(${rat.numerator}/${rat.denominator})', silent: true);
    } else {
      append(_formatNumber(_memory[name]!), silent: true);
    }
    // R9: jedno potvrzení (dříve speak + announce SnackBaru).
    unawaited(
      announceEvent(
        _l10n.recalledFromVariable(name, valStrSpoken),
        category: SpeechCategory.actionConfirm,
      ),
    );
    if (mounted) {
      _showAccessibleSnackBar(
        _l10n.recalledFromVariable(name, valStrVis),
        visualContent: _PeriodicText(
          _l10n.recalledFromVariable(name, valStrVis),
          overlineThickness: _overlineThickness,
          overlineHeight: _overlineHeight,
        ),
        announce: false,
      );
    }
    _isRecallMode = false;
  }

  /// Vloží symbol proměnné (např. 'A') do výrazu — nikoli její hodnotu.
  /// Výraz zůstává symbolický ('A*5'), dosazení proběhne až při výpočtu
  /// substitucí v _evaluateExpression. Žádný STO/RCL režim se nemění.
  void insertMemorySymbol(String name) {
    append(name, silent: true);
    speak(_l10n.variableName(name));
  }

  void _handleMemoryVariable(String name) {
    if (_isStoreMode) {
      storeCurrentValueToMemory(name);
    } else if (_isRecallMode) {
      recallMemoryVariable(name);
    } else {
      insertMemorySymbol(name);
    }
  }

  void _insertAtCursor(String text, {int cursorOffset = 0}) {
    final insertLen = text.length;
    final oldPos = _cursorPosition;
    setState(() {
      display =
          display.substring(0, _cursorPosition) +
          text +
          display.substring(_cursorPosition);
      _cursorPosition = (_cursorPosition + text.length + cursorOffset).clamp(
        0,
        display.length,
      );
      // Posuň pending pozice za místem vložení
      for (int i = 0; i < _pendingNegOpens.length; i++) {
        if (_pendingNegOpens[i] >= oldPos) {
          _pendingNegOpens[i] += insertLen;
        }
      }
    });
    // Event kontext (mimo build): proxy lze syncnout okamžitě; zbytek cest
    // kryje post-frame [_scheduleA11yProxySync] z buildu.
    _syncA11yProxy();
  }

  void _deleteAtCursor() {
    if (_cursorPosition > 0) {
      final delPos = _cursorPosition - 1;
      setState(() {
        display =
            display.substring(0, _cursorPosition - 1) +
            display.substring(_cursorPosition);
        _cursorPosition--;
        _syncPendingNegOnDelete(delPos);
      });
      _syncA11yProxy();
      speak(_l10n.deleted);
    }
  }

  /// Pohyb kurzoru o [delta] znaků bez změny [display].
  /// Jediný zdroj pravdy zůstává [_cursorPosition]. Po skutečné změně se
  /// synchronizuje a11y proxy ([_syncA11yProxy]), zachová autoscroll a právě
  /// jednou se oznámí nová pozice jedním kanálem ([_announceCursorPosition]).
  /// Clamp-noop (za hranicí) je tichý — negeneruje žádné hlášení.
  void _moveCursorBy(int delta) {
    if (delta == 0) return;
    final target = (_cursorPosition + delta).clamp(0, display.length);
    if (target == _cursorPosition) return;
    setState(() {
      _cursorPosition = target;
    });
    _syncA11yProxy();
    _scheduleInputAutoscroll();
    _announceCursorPosition();
  }

  /// Přímé nastavení kurzoru na [position] (clamp do 0..display.length).
  /// Bez změny [display]; feedback viz [_moveCursorBy].
  void _moveCursorTo(int position) {
    final target = position.clamp(0, display.length);
    if (target == _cursorPosition) return;
    setState(() {
      _cursorPosition = target;
    });
    _syncA11yProxy();
    _scheduleInputAutoscroll();
    _announceCursorPosition();
  }

  /// Jednosměrná derivace proxy z jediného zdroje pravdy
  /// (`display` + `_cursorPosition`). Společný zápis textu i collapsed
  /// selection jedním `TextEditingValue` (samostatný zápis `text` by resetoval
  /// selection). Při shodě nic nedělá — bezpečné volat opakovaně, nevzniká
  /// smyčka ani druhý zdroj pravdy. Nesmí se volat synchronně uvnitř
  /// `build()` (listener `EditableText` volá `setState`); z buildu se chodí
  /// přes [_scheduleA11yProxySync], z event handlerů přímo.
  void _syncA11yProxy() {
    final pos = _cursorPosition.clamp(0, display.length);
    final value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: pos),
    );
    if (_displayA11yController.value != value) {
      _displayA11yController.value = value;
    }
  }

  /// Naplánuje post-frame sync proxy. Kryje VŠECHNY cesty měnící `display`
  /// (vkládání, mazání, ANS, historie, NEG, DMS, perioda, výpočet, ...) bez
  /// nutnosti sahat do desítek míst: každá mutace volá `setState` → rebuild →
  /// tento hook → jeden post-frame sync (guard `_a11ySyncScheduled`).
  void _scheduleA11yProxySync() {
    if (_a11ySyncScheduled) return;
    _a11ySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _a11ySyncScheduled = false;
      if (!mounted) return;
      _syncA11yProxy();
    });
  }

  /// Zpětný směr proxy → stav: TalkBack/AT změnila selection v proxy.
  /// Jde výhradně přes [_moveCursorTo] (žádný druhý zdroj pravdy).
  /// Rozšířená (non-collapsed) selection se nepodporuje: sjednotí se na
  /// kurzor na `extentOffset` a proxy se dosynchronizuje zpět. Echo
  /// vlastního syncu (shodná collapsed) se ignoruje.
  void _handleA11ySelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final target = selection.extentOffset.clamp(0, display.length);
    if (selection.isCollapsed && target == _cursorPosition) return;
    _moveCursorTo(target);
    // _moveCursorTo při shodě mlčí i nesyncuje — po non-collapsed vstupu
    // musí proxy vždy zpět na collapsed.
    _syncA11yProxy();
  }

  /// Lidská věta o pozici kurzoru (CS/EN přes [_s] + [_getButtonName]).
  /// Hrany: začátek / konec výrazu. Uvnitř: před kterým znakem + absolutní
  /// pozice (1-based, `pos+1 z len+1`), aby bylo jasné kde kurzor je i bez
  /// počítání.
  String _cursorPositionSpeech() {
    final len = display.length;
    final pos = _cursorPosition.clamp(0, len);
    if (len == 0) return _s('Prázdno', 'Empty');
    if (pos == 0) return _s('Začátek výrazu', 'Start of expression');
    if (pos >= len) return _s('Konec výrazu', 'End of expression');
    final ch = display[pos];
    final String name;
    if (_isDigitChar(ch)) {
      name = _s('číslem $ch', 'digit $ch');
    } else {
      name = _getButtonName(ch);
    }
    return _s(
      'Před $name, pozice ${pos + 1} z ${len + 1}',
      'Before $name, position ${pos + 1} of ${len + 1}',
    );
  }

  /// Jediný aplikační kanál pro feedback kurzoru: centrální
  /// [announceEvent] s `actionConfirm` (nikoli potlačovaný `valueChange`,
  /// žádné přímé TTS, žádný extra SnackBar). Volat pouze při skutečné změně.
  void _announceCursorPosition() {
    unawaited(
      announceEvent(
        _cursorPositionSpeech(),
        category: SpeechCategory.actionConfirm,
      ),
    );
  }

  /// Z1-dokončení: jednorázové oznámení reaktivace režimu ovládání výrazu.
  /// Voláno výhradně při přechodu OFF→ON prvním stiskem (viz
  /// [_tryReactivateExpressionControl]) — nikdy opakovaně, jedním kanálem
  /// ([announceEvent], žádný paralelní TTS ani SnackBar).
  void _announceExpressionControl() {
    unawaited(
      announceEvent(
        _s(
          'Režim ovládání výrazu zapnut. Šipky nyní pohybují kurzorem.',
          'Expression control mode on. Arrows now move the cursor.',
        ),
        category: SpeechCategory.actionConfirm,
      ),
    );
  }

  /// Vizuálně neviditelná, sémanticky přítomná proxy vstupního výrazu.
  /// Proxy sama o sobě neurčuje svou velikost: rodič ji vkládá jako
  /// `Positioned.fill` překryv POUZE horního vstupního řádku (viz displej
  /// v `build`), takže `SemanticsNode.rect` odpovídá skutečné ploše horního
  /// výpočetního displeje, nikoli rohu kontejneru. Žádné `Opacity(0)` bez
  /// `alwaysIncludeSemantics`, žádné `Offstage`. `readOnly: true` +
  /// `TextInputType.none` = žádná soft klávesnice.
  /// Proxy je ve stromě VŽDY (i při prázdném výrazu), aby byl displej
  /// dosažitelný lineární navigací TalkBacku hned po startu bez nutnosti
  /// nejprve navštívit tlačítko.
  /// Proxy nese POUZE význam horního výrazu: při editaci `value == display`
  /// + `textSelection == collapsed(_cursorPosition)` přes standardní
  /// mechanismus `RenderEditable`; při prázdném výrazu hodnotu prázdného
  /// stavu (`_l10n.displayEmpty`). Řeč výsledku sem NEPATŘÍ — tu nese
  /// samostatný uzel dolního řádku (viz [_buildResultA11yNode]).
  /// Obalující `Semantics` nese popisek displeje a aktivační `onTap`:
  /// bez `container: true` se slévá s `RenderEditable` do JEDINÉHO uzlu
  /// `textField` (label + value + selection + pohybové akce + tap —
  /// ověřeno `scratch_semantics_merge_test` V1/V4).
  /// Záměrně ŽÁDNÝ `hint` s instrukcí zoomu — ta nesmí zdržovat při každém
  /// průchodu (zoom zůstává gestem, dvojitým klepem a posuvníky v nastavení).
  /// Z6: viditelná indikace klávesnicového fokusu vstupního řádku bílým
  /// obrysem — stejný vzor jako u výsledku (viz [_buildResultA11yNode]):
  /// `Stack` + překryv přes celou plochu NEMĚNÍ layout (velikost určuje
  /// `SizedBox.expand` s těsnými konstrainty, EditableText dostává stejné
  /// jako dřív); obrys se maluje přes okraj plochy. Zdrojem stavu je
  /// VÝHRADNĚ skutečný `_displayA11yFocusNode.hasFocus` přes
  /// `ListenableBuilder` (žádné umělé `Semantics(focused:)`, žádný druhý
  /// zdroj pravdy). `ExcludeSemantics` + `IgnorePointer` zaručují, že
  /// překryv netvoří sémantickou zastávku ani nekonzumuje doteky (celá
  /// proxy je navíc hit-test transparentní přes `_A11yHitTestTransparent`).
  /// Průhledný rámeček je ve stromu trvale — stejná geometrie při zapnutém
  /// i vypnutém fokusu, žádný skok layoutu.
  Widget _buildDisplayA11yProxy() {
    final bool isEmpty = display.isEmpty;
    return Semantics(
      label: _l10n.displayLabel,
      value: isEmpty ? _l10n.displayEmpty : null,
      onTap: () {
        // Z1: explicitní aktivace režimu ovládání výrazu (před fokusem).
        _expressionControlActive = true;
        _expressionControlOffReason = _ExpressionControlOffReason.none;
        _mainFocusNode.requestFocus();
        speak(isEmpty ? _l10n.displayEmpty : _expressionToSpeech(display));
      },
      // Z1: doplňkový signál — odchod přístupného fokusu z proxy vypíná
      // režim. Není jediným mechanismem (TalkBack ano, NVDA/Windows
      // neprokázáno); autoritativní zůstává primární fokus + dialogy.
      // Nemění kurzor, selection ani fokus.
      onDidLoseAccessibilityFocus: () {
        _expressionControlActive = false;
      },
      // Velikost dává výhradně rodič (`Positioned.fill` přes horní řádek):
      // expanduje na celou překryvou plochu, nic sama nezmenšuje na 1×1.
      // Z6: `StackFit.expand` zachová těsné konstrainty pro EditableText
      // (stejné jako dřívější přímé `SizedBox.expand`), překryv obrysu je
      // čistě vizuální sourozenec bez vlivu na layout i sémantiku.
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            EditableText(
              controller: _displayA11yController,
              focusNode: _displayA11yFocusNode,
              style: const TextStyle(fontSize: 1, color: Colors.transparent),
              cursorColor: Colors.transparent,
              backgroundCursorColor: Colors.transparent,
              selectionColor: Colors.transparent,
              readOnly: true,
              showCursor: false,
              showSelectionHandles: false,
              enableInteractiveSelection: true,
              enableIMEPersonalizedLearning: false,
              autocorrect: false,
              autofocus: false,
              minLines: 1,
              maxLines: 1,
              keyboardType: TextInputType.none,
              onSelectionChanged: _handleA11ySelectionChanged,
            ),
            // Z6: obrys klávesnicového fokusu vstupního řádku (viz doc
            // výše). Stav čte přímo z fokusového uzlu proxy.
            ListenableBuilder(
              listenable: _displayA11yFocusNode,
              builder: (context, _) => ExcludeSemantics(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _displayA11yFocusNode.hasFocus
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Samostatná přístupná reprezentace dolního výsledkového řádku.
  /// Jediný statický uzel (nikoli textové pole): `label` + `value` z
  /// [_currentResultSpeech] (desetinná čísla, zlomky, surd tvary i chybové
  /// stavy — stejný kontrakt jako dřívější prázdný stav proxy).
  /// Rodič v `build` tento uzel roztahuje přes skutečnou plochu dolního
  /// řádku, takže TalkBack ho najde dotykovým průzkumem i swipem nezávisle
  /// na horním kurzorovém poli. Výsledek je VŽDY viditelný (minimálně
  /// `0.`), proto je uzel ve stromě trvale — nikdy prázdný.
  /// Z5: uzel je zároveň zastávkou klávesnicového traversálu (Tab/Shift+Tab)
  /// přes [_resultFocusNode]. `Focus(includeSemantics: false)` sem nepřidává
  /// žádný vlastní sémantický uzel — stav fokusu publikuje tento existující
  /// uzel přes `focused: _resultHasFocus` (žádné zastaralé
  /// `Semantics.focusable`). Vlastní `onKeyEvent` záměrně NENÍ: událost
  /// nejprve dostane fokusovaný [_resultFocusNode] (nic nekonzumuje) a pak
  /// propadne kořenovému [_handleKeyboardInput] na [_mainFocusNode] (předek
  /// celého stromu). Důsledky ověřené auditem handleru: číslice/operátory
  /// dál píší do vstupního displeje i při fokusu výsledku; šipky/Home/End
  /// vyžadují `_mainFocusNode.hasPrimaryFocus`, takže při fokusu výsledku
  /// kurzorem výrazu nehýbou; mezerník handler ignoruje; Enter globálně
  /// přepočítá stejně jako při fokusu kteréhokoli tlačítka (výraz ani kurzor
  /// nemění), proto se zde neošetřuje.
  Widget _buildResultA11yNode({required Widget child}) {
    final String speech = _currentResultSpeech();
    return Focus(
      focusNode: _resultFocusNode,
      includeSemantics: false,
      onFocusChange: (hasFocus) {
        if (!mounted) return;
        setState(() => _resultHasFocus = hasFocus);
        // Konvence tlačítek (viz buildButton): při neaktivní čtečce ohlásí
        // fokus TTS; při aktivní čtečce čte NVDA/TalkBack ze sémantiky sám.
        if (hasFocus && _isScreenReaderActive != true) speak(speech);
      },
      child: Semantics(
        container: true,
        label: _l10n.resultLabel,
        value: speech,
        focused: _resultHasFocus,
        onTap: () {
          // Z5: aktivace při klávesnicovém fokusu výsledku nesmí krást fokus
          // zpět na vstup (jinak by Tab-zastávka ztrácela smysl). Dotyk
          // a TalkBack (fokus jinde) dál vracejí řízení klávesnici.
          if (!_resultFocusNode.hasPrimaryFocus) {
            _mainFocusNode.requestFocus();
          }
          speak(speech);
        },
        // Viditelná indikace klávesnicového fokusu tvarem (vznik rámečku),
        // ne pouze barvou. Překryv přes `Stack` + `Positioned.fill` NEMĚNÍ
        // layout (velikost určuje výhradně vizuální potomek) — obyčejný
        // obalový `Container` s rámečkem by přidal 4 px na výšku a rozbil
        // napjaté layoutové/viewportové testy. Rámeček se maluje přes okraj
        // plochy výsledku (pozadí, ne glyfy — ty jsou centrované s rezervou),
        // obsah ani horizontální scroll nezakrývá. `IgnorePointer` propouští
        // dotyky i táhnutí na scroller a `GestureDetector` pod ním;
        // `ExcludeSemantics` garantuje, že překryv netvoří sémantickou
        // zastávku (nese žádné akce, sourozenecký uzel výsledku nedotčen —
        // na rozdíl od proxy se zde `IgnorePointer` smí použít).
        child: Stack(
          children: [
            child,
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _resultHasFocus
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === NEG (±) helpers ===
  bool _isDigitChar(String c) =>
      c.length == 1 && c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  bool _canAutoClosePendingNeg(int openPos) {
    if (openPos < 0 || openPos >= display.length) return false;
    if (display[openPos] != '(') return false;
    // Ověř, že '(' patří k NEG: musí být "(-" (tj. následující znak '-')
    if (openPos + 1 >= display.length || display[openPos + 1] != '-') {
      return false;
    }
    final inner = display.substring(openPos + 2, _cursorPosition);
    if (inner.isEmpty) return false;
    // Musí obsahovat alespoň jednu číslici, nesmí končit '.' nebo '-' nebo '('
    if (!RegExp(r'\d').hasMatch(inner)) return false;
    final last = inner[inner.length - 1];
    if (last == '.' ||
        last == '-' ||
        last == '(' ||
        last == 'E' ||
        last == 'e') {
      return false;
    }
    // Pokud je těsně před kurzorem již ')', neuzavírat duplicitně
    if (_cursorPosition < display.length && display[_cursorPosition] == ')') {
      return false;
    }
    // Pokud poslední otevřená NEG již má uzavření těsně před kurzorem, ne
    return true;
  }

  void _autoClosePendingNegIfNeeded({bool force = false}) {
    if (_pendingNegOpens.isEmpty) return;
    final pos = _pendingNegOpens.last;
    // Pokud kurzor není za otevřením, neuzavírat
    if (_cursorPosition <= pos + 2) return;
    if (force || _canAutoClosePendingNeg(pos)) {
      // Zkontroluj, zda již není uzavřeno ručně – spočti závorky mezi pos a cursor
      int openCnt = 0;
      for (int i = pos; i < _cursorPosition; i++) {
        if (display[i] == '(') openCnt++;
        if (display[i] == ')') openCnt--;
      }
      if (openCnt <= 0) {
        // Již vyvážené – jen vyprázdni stack
        _pendingNegOpens.removeLast();
        return;
      }
      setState(() {
        display =
            display.substring(0, _cursorPosition) +
            ')' +
            display.substring(_cursorPosition);
        _cursorPosition++;
        _pendingNegOpens.removeLast();
        // Posuň pozice zbývajících pending, které jsou za kurzorem
        for (int i = 0; i < _pendingNegOpens.length; i++) {
          if (_pendingNegOpens[i] >= _cursorPosition) {
            _pendingNegOpens[i]++;
          }
        }
      });
    }
  }

  void _closeAllPendingNegBeforeEval() {
    // Uzavři všechny NEG které lze bezpečně uzavřít (obsahují číslo)
    while (_pendingNegOpens.isNotEmpty) {
      final pos = _pendingNegOpens.last;
      if (_cursorPosition <= pos + 2) break;
      if (_canAutoClosePendingNeg(pos)) {
        _autoClosePendingNegIfNeeded(force: true);
      } else {
        break;
      }
    }
    // Vyčisti neplatné (prázdné) pending
    _pendingNegOpens.removeWhere(
      (p) => p < 0 || p >= display.length || display[p] != '(',
    );
  }

  void _handleNegativeButton() {
    // Guard: zabránit duplicitě uvnitř stejné NEG závorky
    if (_pendingNegOpens.isNotEmpty) {
      final last = _pendingNegOpens.last;
      if (_cursorPosition > last && _cursorPosition <= last + 2) {
        speak(_s('Záporné číslo již otevřeno', 'Negative number already open'));
        return;
      }
      // Pokud je kurzor uvnitř pending a před kurzorem je již "(-", neotevírat znovu
      if (_cursorPosition > last + 1) {
        final inner = display.substring(last + 2, _cursorPosition);
        if (inner.isEmpty) {
          speak(
            _s(
              'Dokončete zadávání záporného čísla',
              'Finish entering negative number',
            ),
          );
          return;
        }
      }
    }
    // Guard: prázdné "(-)" – nedovolit další NEG pokud těsně před kurzorem je "(-"
    if (_cursorPosition >= 2 &&
        display.substring(_cursorPosition - 2, _cursorPosition) == '(-') {
      speak(
        _s(
          'Dokončete zadávání záporného čísla',
          'Finish entering negative number',
        ),
      );
      return;
    }
    // Guard: za číslicí / ')' bez operátoru nevkládat "(-" (vyžaduje operátor)
    // – povolíme pouze pokud před kurzorem není číslice/')' nebo je operátor
    // Pro jednoduchost povolíme vždy, ale pokud je předchozí char digit/')', vložíme implicitní '*'?
    // Spec chce bezpečné – povolíme jen na začátku, po operátoru nebo '('
    if (_cursorPosition > 0) {
      final prev = display[_cursorPosition - 1];
      if (_isDigitChar(prev) || prev == ')' || prev == '.') {
        // Vyžaduje operátor – auto-uzavři případné pending před operátorem a pak dovol?
        // Zde zablokujeme a poradíme
        // Ale pro "5^(-2)" je před "(-" znak '(' – to je OK
        // Takže blokuj pouze digit/')'/'.'
        speak(_s('Nejprve vložte operátor', 'Insert operator first'));
        return;
      }
    }
    final insertPos = _cursorPosition;
    _insertAtCursor('(-');
    _pendingNegOpens.add(insertPos);
    speak(
      _s(
        'Záporné číslo, otevřena závorka',
        'Negative number, parenthesis opened',
      ),
    );
  }

  void _syncPendingNegOnDelete(int deletedPos) {
    // Po smazání posuň / odstraň pending pozice
    for (int i = _pendingNegOpens.length - 1; i >= 0; i--) {
      final p = _pendingNegOpens[i];
      if (p == deletedPos) {
        // Smazán '(' patřící k NEG – odstraň i '-' pokud existuje
        _pendingNegOpens.removeAt(i);
      } else if (p > deletedPos) {
        _pendingNegOpens[i] = p - 1;
      }
    }
    // Odstraň pending které již neukazuje na "(-"
    _pendingNegOpens.removeWhere((p) {
      if (p < 0 || p + 1 >= display.length) return true;
      return !(display[p] == '(' && display[p + 1] == '-');
    });
  }

  String? _findShortestPeriod(String digits) {
    for (int len = 1; len <= digits.length ~/ 2; len++) {
      final candidate = digits.substring(digits.length - len);
      if (digits.length % len != 0) continue;
      final builder = StringBuffer();
      for (int i = 0; i < digits.length ~/ len; i++) {
        builder.write(candidate);
      }
      if (builder.toString() == digits) return candidate;
    }
    return null;
  }

  void _applyPeriodText(
    String text,
    int matchStart,
    String newText,
    bool useResult,
  ) {
    setState(() {
      if (useResult) {
        display = newText;
        _cursorPosition = newText.length;
        _hasResult = false;
      } else {
        display =
            display.substring(0, matchStart) +
            newText +
            display.substring(_cursorPosition);
        _cursorPosition = matchStart + newText.length;
      }
    });
  }

  void _togglePeriod() {
    final bool useResult = display.isEmpty && _hasResult;
    final String text = useResult
        ? _lastResult
        : display.substring(0, _cursorPosition);
    if (text.isEmpty) {
      speak(_s('Nejprve zadejte číslo.', 'Enter a number first.'));
      return;
    }
    final match = RegExp(r'(\d+)(?:\.(\d*))?(?:\((\d+)\))?$').firstMatch(text);
    if (match == null) {
      speak(
        _s(
          'Nelze najít číslo pro označení periody.',
          'Cannot find a number to mark as repeating.',
        ),
      );
      return;
    }
    final intPart = match.group(1)!;
    final fracPart = match.group(2) ?? '';
    final existingPeriod = match.group(3);

    if (existingPeriod != null) {
      // Cyklování periody: každý stisk rozšíří periodu o jednu číslici vlevo, po dosažení celé desetinné části se smaže
      if (fracPart.isEmpty) {
        // Případ "3.(3)" – celá desetinná část je perioda -> odstranění
        final newText = intPart;
        _applyPeriodText(text, match.start, newText, useResult);
        speak(
          _s(
            'Perioda odstraněna, číslo je ${_spokenForDisplay(newText)}',
            'Period removed, the number is ${_spokenForDisplay(newText)}',
          ),
        );
        return;
      }
      // Ověření limitu 9 číslic periody
      if (existingPeriod.length >= 9) {
        final newText = '$intPart${fracPart.isEmpty ? '' : '.$fracPart'}';
        _applyPeriodText(text, match.start, newText, useResult);
        speak(
          _s(
            'Perioda odstraněna, číslo je ${_spokenForDisplay(newText)}',
            'Period removed, the number is ${_spokenForDisplay(newText)}',
          ),
        );
        return;
      }
      final newNonRepeating = fracPart.substring(0, fracPart.length - 1);
      final newPeriod =
          fracPart.substring(fracPart.length - 1) + existingPeriod;
      final newText =
          '$intPart.${newNonRepeating.isEmpty ? '' : newNonRepeating}($newPeriod)';
      _applyPeriodText(text, match.start, newText, useResult);
      speak(_spokenForDisplay(newText));
      return;
    }

    if (fracPart.isEmpty) {
      speak(
        _s('Nejprve zadejte desetinnou část.', 'Enter the decimal part first.'),
      );
      return;
    }

    final period = _findShortestPeriod(fracPart);
    final String nonRepeating;
    final String repeating;
    if (period != null) {
      nonRepeating = fracPart.substring(0, fracPart.length - period.length);
      repeating = period;
    } else {
      nonRepeating = fracPart.substring(0, fracPart.length - 1);
      repeating = fracPart.substring(fracPart.length - 1);
    }
    final newText =
        '$intPart.${nonRepeating.isEmpty ? '' : nonRepeating}($repeating)';
    _applyPeriodText(text, match.start, newText, useResult);
    speak(_spokenForDisplay(newText));
  }

  Future<void> _showPeriodEditDialog() async {
    final bool useResult = display.isEmpty && _hasResult;
    final String text = useResult
        ? _lastResult
        : display.substring(0, _cursorPosition);
    if (text.isEmpty) {
      speak(_s('Nejprve zadejte číslo.', 'Enter a number first.'));
      return;
    }
    final match = RegExp(r'(\d+)(?:\.(\d*))?(?:\((\d+)\))?$').firstMatch(text);
    if (match == null) {
      speak(
        _s(
          'Nelze najít číslo pro úpravu periody.',
          'Cannot find a number to edit period.',
        ),
      );
      return;
    }
    final intPart = match.group(1)!;
    final fracPart = match.group(2) ?? '';
    final existingPeriod = match.group(3) ?? '';
    // Rozložit na neperiodickou a periodickou část
    final String nonRepeating = existingPeriod.isEmpty ? fracPart : fracPart;
    final String period = existingPeriod;
    final nonCtrl = TextEditingController(text: nonRepeating);
    final periodCtrl = TextEditingController(text: period);

    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Upravit periodu', 'Edit period')),
      builder: (ctx) => AlertDialog(
        scrollable: false,
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(_s('Upravit periodu', 'Edit period')),
        ),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              Semantics(
                label: _s('Celá část', 'Integer part'),
                child: TextFormField(
                  initialValue: intPart,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: _s('Celá část', 'Integer part'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: _s('Neperiodická část', 'Non-repeating part'),
                child: TextField(
                  controller: nonCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: _s('Neperiodická část', 'Non-repeating part'),
                    hintText: _s('např. 23', 'e.g. 23'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: _s('Perioda (1-9 číslic)', 'Period (1-9 digits)'),
                child: TextField(
                  controller: periodCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: InputDecoration(
                    labelText: _s(
                      'Perioda (1-9 číslic)',
                      'Period (1-9 digits)',
                    ),
                    hintText: _s('např. 45', 'e.g. 45'),
                    helperText: _s(
                      'Povolené znaky: pouze číslice, max. 9',
                      'Allowed: digits only, max. 9',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                container: true,
                label: _s('Náhled', 'Preview'),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: periodCtrl,
                  builder: (_, __, ___) =>
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: nonCtrl,
                        builder: (_, __, ___) {
                          final n = nonCtrl.text.trim();
                          final p = periodCtrl.text.trim();
                          final preview = p.isEmpty
                              ? '$intPart.${n.isEmpty ? fracPart : n}'
                              : '$intPart.${n}($p)';
                          final spokenPreview = p.isEmpty
                              ? preview
                              : _spokenForDisplay(preview);
                          return Semantics(
                            liveRegion: true,
                            label: _s(
                              'Náhled $spokenPreview',
                              'Preview $spokenPreview',
                            ),
                            child: Text(
                              _s('Náhled: $preview', 'Preview: $preview'),
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final n = nonCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
              final p = periodCtrl.text.trim().replaceAll(
                RegExp(r'[^0-9]'),
                '',
              );
              if (p.isEmpty) {
                speak(
                  _s('Perioda nesmí být prázdná.', 'Period must not be empty.'),
                );
                return;
              }
              if (p.length > 9) {
                speak(
                  _s(
                    'Perioda může mít maximálně 9 číslic.',
                    'Period can have at most 9 digits.',
                  ),
                );
                return;
              }
              final newText = p.isEmpty
                  ? '$intPart${n.isEmpty ? '' : '.$n'}'
                  : '$intPart.$n($p)';
              // Validace že neperiodická+perioda nejsou prázdné obě
              _applyPeriodText(text, match.start, newText, useResult);
              Navigator.pop(ctx);
              speak(_spokenForDisplay(newText));
            },
            child: Text(_l10n.confirmAction),
          ),
        ],
      ),
    );
  }

  void calculateResult() {
    try {
      // Auto-uzavři NEG před vyhodnocením
      if (_pendingNegOpens.isNotEmpty) {
        _closeAllPendingNegBeforeEval();
        // Pokud stále zbývá neuzavřené (prázdné), vyčisti
        if (_pendingNegOpens.isNotEmpty) {
          // Pokud je poslední "(-" prázdné, odstraň je (prevence "(-)" chyby)
          final pos = _pendingNegOpens.last;
          if (pos + 2 >= _cursorPosition ||
              !RegExp(
                r'\d',
              ).hasMatch(display.substring(pos + 2, _cursorPosition))) {
            setState(() {
              // odstraň prázdné "(-" – dvě znaky
              if (pos + 1 < display.length &&
                  display.substring(pos, pos + 2) == '(-') {
                display =
                    display.substring(0, pos) + display.substring(pos + 2);
                if (_cursorPosition > pos + 1) _cursorPosition -= 2;
                if (_cursorPosition > pos) _cursorPosition = pos;
              }
              _pendingNegOpens.removeLast();
            });
          }
        }
      }
      if (display.isEmpty) return;
      String currentExpression =
          display; // Uložíme výraz před vymazáním displeje

      String resStr = '0';
      String spoken = '';
      // Exaktní metadata pro historii: vyplní pouze větev běžného
      // výpočtu (RationalValue nebo trySurdFromExpression); ostatní větve
      // nechají null = autoritativní "žádný exaktní tvar".
      SurdValue? historyExact;
      Rational? historyRational;
      // Stavová způsobilost pro zlomkový náhled: true pouze pro běžný
      // numerický výsledek (basic/scientific, standard, bez DMS). Nikdy
      // se neodvozuje parsováním textu výsledku.
      bool plainResult = false;

      if (_currentMode == CalculatorMode.statistics) {
        if (_statsMemory.isEmpty) {
          speak(_statsEmptyMessage());
          return;
        }
        List<double> data = List<double>.from(
          _getFieldValues(_selectedFieldIndex),
        );

        double sum = data.reduce((a, b) => a + b);
        double mean = sum / data.length;
        double variance =
            data.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
            data.length;
        double sd = math.sqrt(variance);

        resStr = _formatNumberSmart(mean);
        spoken = _s(
          'Průměr z paměti je ${_formatSpokenNumber(mean)}, směrodatná odchylka je ${_formatSpokenNumber(sd)}',
          'Mean from memory is ${_formatSpokenNumber(mean)}, standard deviation is ${_formatSpokenNumber(sd)}',
        );
        // R10: synchronizace stavu – ANS po statistickém výpočtu je průměr.
        // (Matematika se nemění, pouze se ukládá již vypočtená hodnota.)
        _lastNumericValue = mean;
      } else if (_currentMode == CalculatorMode.electrician) {
        final result = _calculateElectricianResult(display);
        if (!result.isFinite) {
          throw _ElectricianInputException(_l10n.elecInvalidResult);
        }

        final calculation = _selectedElectricianCalculation;

        final scaledData = _getScaledValueAndPrefix(result);
        final scaledValue = scaledData['value'] as double;
        final prefix = scaledData['prefix'] as String;

        // Formátování pro zobrazení s předponou
        String formattedValue = _formatNumberSmart(scaledValue);
        String unit = '';
        switch (calculation) {
          case ElectricianCalculation.voltage:
            unit = 'V';
            break;
          case ElectricianCalculation.current:
            unit = 'A';
            break;
          case ElectricianCalculation.resistance:
            unit = '\u03A9';
            break; // Omega symbol
        }
        resStr = '$formattedValue $prefix$unit';

        final spokenResult = _formatSpokenNumber(scaledValue);
        final calculationName = _getElectricianCalculationName(calculation);
        final unitSpeech = _getElectricianUnitSpeech(
          calculation,
          scaledValue,
          prefix,
        );
        spoken = _l10n.elecResult(calculationName, spokenResult, unitSpeech);
        currentExpression =
            '${_getElectricianHistoryName(calculation)}($display)';
        _lastNumericValue = result;
      } else if (_currentMode == CalculatorMode.time) {
        try {
          final timeRes = _calculateTimeResult(display);
          resStr = timeRes;
          // Determine speech variant
          final trimmed = display.trim();
          if (trimmed.contains(';')) {
            spoken = _l10n.timeDiffResult(
              _formatSecondsToSpeech(_parseHmsToSeconds(timeRes)),
            );
          } else {
            spoken = _l10n.timeResult(
              _formatSecondsToSpeech(_parseHmsToSeconds(timeRes)),
            );
          }
          _lastNumericValue = _parseHmsToSeconds(timeRes).toDouble();
        } on _TimeInputException catch (e) {
          throw _TimeInputException(e.message);
        }
      } else if (_currentMode == CalculatorMode.unitConversion) {
        // Stejná výpočetní logika jako tlačítko PŘEVÉST (žádná duplicita).
        _convertUnits();
        return;
      } else if (_currentMode == CalculatorMode.currency) {
        _convertCurrency();
        return;
      } else {
        bool isDms = RegExp(r'''\d+(?:\.\d+)?[°'"]''').hasMatch(display);
        bool isTrig =
            display.toUpperCase().contains('SIN') ||
            display.toUpperCase().contains('COS') ||
            display.toUpperCase().contains('TAN');
        bool isInverse =
            display.toUpperCase().contains('ASIN') ||
            display.toUpperCase().contains('ACOS') ||
            display.toUpperCase().contains('ATAN');

        if (_hasResult && display.toUpperCase().contains('ANS')) {
          isInverse = true;
        }

        // Přesná racionální větev (V1): pouze basic/scientific ve standardním
        // formátu, jinak beze změny numerická cesta. Úspěch dává strukturovaný
        // Rational (nikdy aproximaci double); nepodporovaný výraz padá do
        // _evaluateExpression; chyba vyhazuje mapovaný CalcError.
        Rational? exactRational;
        if ((_currentMode == CalculatorMode.basic ||
                _currentMode == CalculatorMode.scientific) &&
            _displayFormat == DisplayFormat.standard) {
          final rationalInput = _expandAnsForRational(display);
          if (rationalInput != null) {
            final rationalEval = tryEvaluateRational(rationalInput);
            if (rationalEval is RationalOk) {
              exactRational = rationalEval.value;
            } else if (rationalEval is RationalFailure) {
              throw _mapRationalFailure(rationalEval.kind);
            }
          }
        }

        double result =
            exactRational?.toDouble() ?? _evaluateExpression(display);
        // Strukturální kontrola už proběhla uvnitř _evaluateExpression:
        // každé prokázané dělení nulou vyhodilo CalcError(divisionByZero).
        // Zbytkový non-finite výsledek bez takového důkazu proto nikdy
        // není dělení nulou — je to přetečení, resp. neplatná operace.
        if (!result.isFinite) {
          throw _classifyResidualNonFinite(result, display);
        }
        _lastNumericValue = result;

        bool userWantsDms = (_inverseFormatPreference == 0 && _isDegreeMode);
        // DMS formát použijeme pouze pokud:
        // 1. Uživatel to má v nastavení (userWantsDms)
        // 2. A ZÁROVEŇ: buď jde o inverzní funkci (výsledek je úhel), nebo šlo o čistý DMS bez SIN/COS/TAN
        if (userWantsDms && (isInverse || (isDms && !isTrig))) {
          resStr = _formatAsDMS(result);
        } else {
          resStr =
              (_displayFormat == DisplayFormat.standard && _usePeriodicNotation)
              ? (_tryFormatRepeating(result) ?? _formatNumber(result))
              : _formatNumber(result);
        }
        plainResult =
            (_currentMode == CalculatorMode.basic ||
                _currentMode == CalculatorMode.scientific) &&
            _displayFormat == DisplayFormat.standard &&
            !resStr.contains('°') &&
            result.isFinite;

      // Exaktní metadata výsledku: RationalValue pro racionální výpočet,
        // jinak částečně odmocněný surd pro jednoduchou odmocninu celého
        // čísla (např. "√72" -> 6√2). _lastResult zůstává VŽDY numerický
        // string; přesnost žije strukturovaně v _lastExact s platností
        // klíč + generace. Ostatní větve nechávají null = autoritativní
        // "žádný exaktní tvar". Vzájemně se vylučují.
        SurdValue? spokenSurd;
        if (exactRational != null) {
          historyRational = exactRational;
        } else {
          // Částečné odmocňování: bezpečně detekuj jednoduchou odmocninu
          // celého čísla (např. "√72" -> 6√2, "∛54" -> 3∛2, "4ⁿ√48" -> 2⁴√3).
          // Numerický resStr, _lastNumericValue i historie zůstávají zdrojem
          // pravdy; surd je pouze exaktní prezentační metadata. Záporné/
          // desetinné vstupy, perfektní mocniny a prvočísla vrací null ->
          // dnešní chování. Zápis metadat probíhá až ve společném commitu
          // níže (jednotná invalidace pro všechny větve).
          final surd = trySurdFromExpression(display);
          if (surd != null) {
            historyExact = surd;
            spokenSurd = surd;
          }
        }

        if (exactRational != null &&
            exactRational.denominator != BigInt.one) {
          // Přesný zlomek se oznamuje přímo (stejný precedens jako surd);
          // věta o dostupnosti se pak nepřipojuje (žádná duplicita).
          final spokenFraction = exactRational
              .toDisplayString()
              .replaceAll('/', _s(' lomeno ', ' over '));
          spoken = _l10n.resultIs(spokenFraction);
        } else if (spokenSurd != null) {
          spoken = _l10n.resultIs(_spokenForDisplay(formatSurd(spokenSurd)));
        } else if (resStr.contains('°')) {
          spoken = _l10n.resultIs(_formatDmsSpeech(resStr));
        } else {
          spoken = _l10n.resultIs(_spokenForDisplay(resStr));
        }

        if (_announceExpression &&
            (_currentMode == CalculatorMode.basic ||
                _currentMode == CalculatorMode.scientific)) {
          spoken = _l10n.expressionResultIs(
            _expressionToSpeech(currentExpression),
            spoken,
          );
        }
      }

      setState(() {
        _lastResult = resStr;
        _hasResult = true;
        display = '';
        _cursorPosition = 0;
        _pendingNegOpens.clear();
        // Nový výpočet začíná bez vynuceného pohledu (override null).
        // Generace se inkrementuje vždy: platnost exaktních metadat hlídá
        // klíč + generace (viz _isLastExactValid a _isShowingFraction).
        // Větve bez vlastních metadat (statistika, elektro, čas) tím
        // zastaralý RationalValue/SurdValue automaticky zneplatní.
        _resultGeneration++;
        _lastExactGeneration = _resultGeneration;
        if (historyRational != null) {
          _lastExact = RationalValue(historyRational);
          _lastExactKey = resStr;
        } else if (historyExact != null) {
          _lastExact = historyExact;
          _lastExactKey = resStr;
        } else {
          _lastExact = null;
          _lastExactKey = '';
        }
        _lastResultIsPlainNumeric = plainResult;
        _fractionOverride = null;
      });

      // Automatické oznámení dostupnosti zlomku: pouze součást existující
      // výsledkové hlášky, žádné druhé speak()/say(). Stav je v tomto bodě
      // již komitnutý (_lastResult, _lastNumericValue,
      // _lastResultIsPlainNumeric, _hasResult), takže _fractionString je
      // finální. Při screen readeru ON vrací helper null a speech zůstává
      // beze změny. Je-li primární hláška již přesný zlomek, věta se
      // nepřipojuje (žádná duplicita).
      final bool exactAlreadySpoken = historyRational != null &&
          historyRational.denominator != BigInt.one;
      final fractionSuffix =
          exactAlreadySpoken ? null : _fractionAvailabilitySuffix();
      if (fractionSuffix != null && fractionSuffix.isNotEmpty) {
        spoken = '$spoken $fractionSuffix';
      }

      // R2/R4: jediná výsledková hláška jednotným kanálem.
      // Při aktivní čtečce oznamuje změna displeje (liveRegion) –
      // žádné paralelní vlastní TTS přes čtečku.
      unawaited(
        announceEvent(
          spoken,
          category: SpeechCategory.actionConfirm,
          interruptCurrentSpeech: true,
        ),
      );
      _addToHistory(
        currentExpression,
        resStr,
        exact: historyExact,
        rational: historyRational,
        numericValue: _lastNumericValue,
      );
    } catch (e) {
      // Známý CalcError -> přesná hláška dle kind + reason.
      // TAN doménová výjimka si drží vlastní přesnou větu (beze změny).
      // ArgumentError z enginu (např. faktoriál) -> obecná doménová hláška
      // dle typu výjimky, nikdy dle jejího anglického textu.
      // Neočekávaná interní výjimka -> bezpečná obecná cesta, nikdy se
      // automaticky nepřeklasifikovává na syntax; detail jen do debug logu.
      String msg = _l10n.expressionNotUnderstood;
      if (e is _ElectricianInputException) {
        msg = e.message;
      } else if (e is _TimeInputException) {
        msg = e.message;
      } else if (e is CalcError) {
        msg = _messageForCalcError(e);
      } else if (e is _MathDomainException) {
        msg = e.message;
      } else if (e is ArgumentError) {
        msg = _l10n.valueOutOfRange;
      } else {
        debugPrint('Unexpected calculation error: $e');
      }

      setState(() {
        _lastResult = 'Error';
        _hasResult = true;
        _lastResultIsPlainNumeric = false;
        _fractionOverride = null;
        // Chyba ruší přesná metadata: generace se inkrementuje, takže ani
        // textově shodný starší výsledek nedostane zastaralý RationalValue.
        _lastExact = null;
        _lastExactKey = '';
        _resultGeneration++;
        _lastExactGeneration = _resultGeneration;
        // Nech pending pro opravu, ale pokud byl prázdný, vyčisti
      });
      // R4: chyba jednou, jejím kanálem (při SR liveRegion, jinak TTS).
      unawaited(
        announceEvent(
          msg,
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
    }
  }

  /// Mapuje známý [CalcError] na přesnou lokalizovanou hlášku.
  /// Neznámý důvod padá na obecnou hlášku své kategorie, nikdy na dělení
  /// nulou. Anglický text výjimky knihovny se zde nikdy nepoužívá.
  String _messageForCalcError(CalcError e) {
    switch (e.reason) {
      case CalcErrorReason.zeroDenominator:
      case CalcErrorReason.zeroToNegativePower:
        return _l10n.cannotDivideByZero;
      case CalcErrorReason.sqrtOfNegative:
        return _l10n.negativeSqrtArgument;
      case CalcErrorReason.logNonPositiveArg:
        return _l10n.logArgumentMustBePositive;
      case CalcErrorReason.logBadBase:
        return _l10n.logBaseInvalid;
      case CalcErrorReason.asinOutOfRange:
        return _l10n.asinArgumentOutOfRange;
      case CalcErrorReason.acosOutOfRange:
        return _l10n.acosArgumentOutOfRange;
      case CalcErrorReason.overflowInfinite:
        return _l10n.calculationOverflow;
      case CalcErrorReason.syntaxParens:
        return _l10n.unbalancedParentheses;
      case CalcErrorReason.syntaxGeneral:
        return _l10n.expressionSyntaxError;
      case CalcErrorReason.tanUndefined:
      case CalcErrorReason.unknown:
        switch (e.kind) {
          case CalcErrorKind.divisionByZero:
            return _l10n.cannotDivideByZero;
          case CalcErrorKind.syntax:
            return _l10n.expressionSyntaxError;
          case CalcErrorKind.overflow:
            return _l10n.calculationOverflow;
          case CalcErrorKind.domain:
          case CalcErrorKind.invalidOperation:
            return _l10n.valueOutOfRange;
        }
    }
  }

  /// Vyhodnotí podstrom stejným enginem i kontextem jako hlavní výpočet.
  /// Vrací null, pokud podstrom nelze vyhodnotit — volající pak pokračuje
  /// bez strukturálního důkazu a nikdy z null neodvozuje chybu.
  /// Žádný setState, žádná mutace stavu.
  double? _tryEvalSubtree(
    math_expr.Expression sub,
    math_expr.ContextModel cm,
  ) {
    try {
      final v = sub.evaluate(math_expr.EvaluationType.REAL, cm);
      if (v is num) return v.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Odobalí argument funkce: BoundVariable -> vázaný výraz, jinak beze změny.
  math_expr.Expression _unbindFuncArg(math_expr.Expression e) {
    if (e is math_expr.BoundVariable) {
      final v = e.value;
      if (v is math_expr.Expression) return v;
    }
    return e;
  }

  /// Strukturální kontrola AST: najde relevantní operátor/funkci, vyhodnotí
  /// pouze potřebný podstrom stejným RealEvaluatorem a stejným ContextModelem
  /// a vrátí [CalcError], pokud je důvod chyby spolehlivě známý.
  /// Jinak vrací null a volající pokračuje normálním výpočtem.
  /// Netvoří druhý kalkulační algoritmus, nic nemutuje (pure read-only).
  /// Pořadí: nejdřív rekurze do dětí (nejvnitřnější chyba má prioritu),
  /// pak kontrola vlastního uzlu. Doména před dělením nulou před overflow.
  CalcError? _findCalcError(
    math_expr.Expression exp,
    math_expr.ContextModel cm,
  ) {
    // Děti nejdřív (post-order).
    if (exp is math_expr.BinaryOperator) {
      final leftErr = _findCalcError(exp.first, cm);
      if (leftErr != null) return leftErr;
      final rightErr = _findCalcError(exp.second, cm);
      if (rightErr != null) return rightErr;
      if (exp is math_expr.Divide) {
        final divisor = _tryEvalSubtree(exp.second, cm);
        if (divisor != null && divisor == 0) {
          return const CalcError(
            CalcErrorKind.divisionByZero,
            CalcErrorReason.zeroDenominator,
          );
        }
      } else if (exp is math_expr.Power) {
        final base = _tryEvalSubtree(exp.first, cm);
        final exponent = _tryEvalSubtree(exp.second, cm);
        if (base != null && exponent != null) {
          if (base == 0 && exponent < 0) {
            return const CalcError(
              CalcErrorKind.divisionByZero,
              CalcErrorReason.zeroToNegativePower,
            );
          }
          // base == 0 && exponent == 0: runtime sonda prokázala 1.0
          // (Dart math.pow) — validní výsledek, žádná chyba.
        }
      }
      return null;
    }
    if (exp is math_expr.Ln) {
      final childErr = _findCalcErrorInFuncArgs(exp, cm);
      if (childErr != null) return childErr;
      // Ln ukládá bázi (e) na getParam(0), argument na getParam(1).
      final arg = _tryEvalSubtree(
        _unbindFuncArg(exp.getParam(1)),
        cm,
      );
      if (arg != null && arg <= 0) {
        return const CalcError(
          CalcErrorKind.domain,
          CalcErrorReason.logNonPositiveArg,
        );
      }
      return null;
    }
    if (exp is math_expr.Log) {
      final childErr = _findCalcErrorInFuncArgs(exp, cm);
      if (childErr != null) return childErr;
      final number = _tryEvalSubtree(
        _unbindFuncArg(exp.getParam(1)),
        cm,
      );
      if (number != null && number <= 0) {
        return const CalcError(
          CalcErrorKind.domain,
          CalcErrorReason.logNonPositiveArg,
        );
      }
      final base = _tryEvalSubtree(
        _unbindFuncArg(exp.getParam(0)),
        cm,
      );
      if (base != null && (base <= 0 || base == 1)) {
        return const CalcError(
          CalcErrorKind.domain,
          CalcErrorReason.logBadBase,
        );
      }
      return null;
    }
    if (exp is math_expr.Sqrt) {
      final childErr = _findCalcErrorInFuncArgs(exp, cm);
      if (childErr != null) return childErr;
      final arg = _tryEvalSubtree(
        _unbindFuncArg(exp.getParam(1)),
        cm,
      );
      if (arg != null && arg < 0) {
        return const CalcError(
          CalcErrorKind.domain,
          CalcErrorReason.sqrtOfNegative,
        );
      }
      return null;
    }
    if (exp is math_expr.Root) {
      // Lichá odmocnina ze záporného čísla je validní (engine rewrite),
      // sudá se chová jako sqrt — tu engine modeluje přes Power, takže
      // zde pouze rekurze do dětí bez vlastního verdiktu.
      return _findCalcErrorInFuncArgs(exp, cm);
    }
    if (exp is math_expr.Asin) {
      final childErr = _findCalcErrorInFuncArgs(exp, cm);
      if (childErr != null) return childErr;
      final arg = _tryEvalSubtree(
        _unbindFuncArg(exp.getParam(0)),
        cm,
      );
      if (arg != null && arg.abs() > 1 + 1e-12) {
        return const CalcError(
          CalcErrorKind.domain,
          CalcErrorReason.asinOutOfRange,
        );
      }
      return null;
    }
    if (exp is math_expr.Acos) {
      final childErr = _findCalcErrorInFuncArgs(exp, cm);
      if (childErr != null) return childErr;
      final arg = _tryEvalSubtree(
        _unbindFuncArg(exp.getParam(0)),
        cm,
      );
      if (arg != null && arg.abs() > 1 + 1e-12) {
        return const CalcError(
          CalcErrorKind.domain,
          CalcErrorReason.acosOutOfRange,
        );
      }
      return null;
    }
    if (exp is math_expr.DefaultFunction) {
      return _findCalcErrorInFuncArgs(exp, cm);
    }
    if (exp is math_expr.UnaryOperator) {
      return _findCalcError(exp.exp, cm);
    }
    return null;
  }

  /// Rekurze do vázaných argumentů DefaultFunction (BoundVariable -> výraz).
  CalcError? _findCalcErrorInFuncArgs(
    math_expr.DefaultFunction func,
    math_expr.ContextModel cm,
  ) {
    for (final param in func.args) {
      final sub = _unbindFuncArg(param);
      if (identical(sub, param) && param is! math_expr.BoundVariable) {
        // Prostá proměnná bez vazby: po substituci by neměla nastat.
        // Bez důkazu — přeskočit, nehlásit.
        continue;
      }
      final err = _findCalcError(sub, cm);
      if (err != null) return err;
    }
    return null;
  }

  /// Klasifikuje zbytkový non-finite výsledek, pro který strukturální
  /// kontrola nenašla důkaz dělení nulou ani domény.
  /// Nekonečno -> overflow; NaN -> invalidOperation. Nikdy divisionByZero.
  CalcError _classifyResidualNonFinite(double value, String debugDetail) {
    if (value.isNaN) {
      return CalcError(
        CalcErrorKind.invalidOperation,
        CalcErrorReason.unknown,
        debugDetail,
      );
    }
    return CalcError(
      CalcErrorKind.overflow,
      CalcErrorReason.overflowInfinite,
      debugDetail,
    );
  }

  /// Strukturální expanze `_CBRT_(...)`: od markeru skenuje s čítačem
  /// hloubky k párové závorce, takže zvládne vnořené závorky (na rozdíl
  /// od plochého regexu `[^()]+`), které zaručeně vznikají substitucí
  /// `ANS` (vždy zabaleno do vlastních závorek).
  ///
  /// Matematika: `math_expressions` počítá `^(1/3)` přes
  /// `math.pow(zápor, 1/3)` = NaN. Vnitřní markery se proto nejprve
  /// rekurzivně expandují zevnitř ven (např. ∛(∛(729))) a argument se pak
  /// rekurzivně vyčíslí (deterministické, bez vedlejších efektů — stejný postup jako
  /// expanze tangens ve stupních) a podle prokázaného znaménka se emituje
  /// původní argument v kladné (`((A)^(1/3))`), nulové (`(0.0)`), nebo
  /// záporné (`(-((-(A))^(1/3)))`) formě. Chyby uvnitř argumentu (např.
  /// dělení nulou) se propagují z rekurze beze změny; nefinite sonda
  /// (Infinity/NaN) zachovává původní text kvůli vnější klasifikaci.
  String _expandCbrtMarkers(String processed) {
    const marker = '_CBRT_';
    final out = StringBuffer();
    int i = 0;
    while (true) {
      final idx = processed.indexOf(marker, i);
      if (idx < 0) {
        out.write(processed.substring(i));
        break;
      }
      out.write(processed.substring(i, idx));
      final j = idx + marker.length;
      if (j >= processed.length || processed[j] != '(') {
        // Holý marker bez závorky (neúplný vstup, např. samotné `∛`).
        // Historické chování `(`; druhá kontrola závorek to odmítne
        // jako syntaxParens.
        out.write('(');
        i = j;
        continue;
      }
      int depth = 0;
      int k = j;
      for (; k < processed.length; k++) {
        if (processed[k] == '(') {
          depth++;
        } else if (processed[k] == ')') {
          depth--;
          if (depth == 0) break;
        }
      }
      if (depth != 0) {
        // Neuzavřená závorka — text se nechá nedotčený, druhá kontrola
        // závorek to odmítne jako syntaxParens.
        out.write(processed.substring(idx));
        break;
      }
      final arg = processed.substring(j + 1, k);
      if (arg.isEmpty) {
        // Prázdný argument ∛() — ponechá se markeru, pozdější kontrola
        // zbytkových markerů to odmítne jako syntaxGeneral (stejně jako SIN()).
        out.write(processed.substring(idx));
        break;
      }
      // Vnořené ∛ zevnitř ven (např. ∛(∛(729))): nejprve se expandují
      // vnitřní markery, sonda i emise pak pracují s textem bez _CBRT_.
      final expandedArg = _expandCbrtMarkers(arg);
      final v = _evaluateExpression(expandedArg);
      if (v == 0) {
        out.write('(0.0)');
      } else if (v.isNaN || v > 0) {
        out.write('(($expandedArg)^(1/3))');
      } else {
        out.write('(-((-( $expandedArg))^(1/3)))');
      }
      i = k + 1;
    }
    return out.toString();
  }

  double _evaluateExpression(String expr) {
    debugPrint("Evaluating expression: '$expr'");
    // ANS se rozvíjí z platného RationalValue strukturovaně ((n/d)),
    // jinak dosavadní numericky. Stejnou expanzi používá exaktní pokus,
    // takže řetězení zůstává přesné.
    String processed =
        expr.replaceAll('ANS', _ansExpansion()).replaceAll(' ', '');

    // 1. PŘÍPRAVA SYMBOLŮ
    processed = processed.replaceAll('x²', '^2').replaceAll('x³', '^3');
    processed = processed.replaceAll('\u03C0', '(3.14159265358979323846)');
    processed = processed.replaceAll('(-)', '-');
    processed = processed.replaceAll(',', '.');
    processed = processed.replaceAll('°→\'', '').replaceAll('\'→°', '');

    // 1.2. PERIODICKÁ ČÍSLA: 3.(3) -> (3 + 3/9), 1.2(34) -> (1 + 2/10 + 34/990)
    processed = processed.replaceAllMapped(RegExp(r'(\d+)\.(\d*)\((\d+)\)'), (
      m,
    ) {
      final intPart = int.parse(m.group(1)!);
      final nonRep = m.group(2) ?? '';
      final period = m.group(3)!;
      final n = nonRep.length;
      final p = period.length;
      final intN = nonRep.isEmpty ? 0 : int.parse(nonRep);
      final intP = int.parse(period);
      final tenN = math.pow(10, n).toInt();
      final tenNP = math.pow(10, n + p).toInt();
      final denominator = tenNP - tenN;
      final numerator = intN * denominator + intP * tenN;
      final totalDenom = denominator * tenN;
      return '($intPart + $numerator/$totalDenom)';
    });

    // 1.5. N-TÁ ODMOCNINA: xⁿ√y -> (y)^(1/x) (POZOR: toto musí být před náhradou √)
    processed = processed.replaceAllMapped(
      RegExp(
        r'(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))ⁿ√(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))',
      ),
      (m) {
        return '(${m[2]})^(1/(${m[1]}))';
      },
    );

    // 2. FUNKCE -> MARKERY (První krok, aby názvy funkcí byly chráněny)
    final Map<String, String> markers = {
      'ASIN': '_ASIN_',
      'ACOS': '_ACOS_',
      'ATAN': '_ATAN_',
      'SIN': '_SIN_',
      'COS': '_COS_',
      'TAN': '_TAN_',
      'ABS': '_ABS_',
      'LOG': '_LOG_',
      'LN': '_LN_',
      '√': '_SQRT_',
      '∛': '_CBRT_',
    };
    markers.forEach((name, marker) {
      String pattern = (name == '√' || name == '∛') ? name : '\\b$name';
      processed = processed.replaceAll(
        RegExp(pattern, caseSensitive: false),
        marker,
      );
    });

    // 2b. OCHRANA E-NOTACE (validní tvary: mantisa E exponent)
    // Mantisa: číslo (10, 2.5) nebo vyvážená závorka ((10), (2.5), (1+2)).
    // Exponent: [+-]?\d+ nebo \([+-]?\d+\) — E5, E+5, E-5, E(5), E(+5), E(-5).
    //  Příklady platné: 10E5, 10E-5, 2.5E-3, 20E(-6), 2.5E(-3), (10)E5, (10)E(-5)
    //  Neplatné (zůstane proměnná E): E, E+2, 2*E, A+E
    // Normalizace: oba zápisy exponentu → atomické (mantisa*10^(exp)),
    //  např. 0.5/20E(-6) -> 0.5/(20*10^(-6)) = 25000.
    final expPlaceholders = <String, String>{};
    int expIdx = 0;
    final expSuffix = RegExp(r'E(?:([+-]?\d+)|\(([+-]?\d+)\))');
    int searchFrom = 0;
    while (searchFrom < processed.length) {
      final sub = processed.substring(searchFrom);
      final m = expSuffix.firstMatch(sub);
      if (m == null) break;
      final int eStart = searchFrom + m.start; // pozice 'E'
      final int eEnd = searchFrom + m.end; // za exponentem
      final String exp = m.group(1) ?? m.group(2)!;
      // Najdi mantisu těsně před 'E'.
      int tokenStart = -1;
      String? mantisaText;
      if (eStart > 0) {
        final String prev = processed[eStart - 1];
        if (RegExp(r'[0-9.]').hasMatch(prev)) {
          int s = eStart - 1;
          while (s > 0 && RegExp(r'[0-9.]').hasMatch(processed[s - 1])) {
            s--;
          }
          final candidate = processed.substring(s, eStart);
          if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(candidate)) {
            tokenStart = s;
            mantisaText = candidate;
          }
        } else if (prev == ')') {
          // Zpětně najdi párovací '(' (izolovaný helper místo matchování samotného ')').
          int depth = 0;
          int openPos = -1;
          for (int i = eStart - 1; i >= 0; i--) {
            if (processed[i] == ')') {
              depth++;
            } else if (processed[i] == '(') {
              depth--;
              if (depth == 0) {
                openPos = i;
                break;
              }
            }
          }
          if (openPos >= 0) {
            tokenStart = openPos;
            mantisaText = processed.substring(openPos, eStart);
          }
        }
      }
      if (tokenStart < 0 || mantisaText == null) {
        // Není E-notace (např. samotné E, A+E) — pokračuj za tímto 'E'.
        searchFrom = eStart + 1;
        continue;
      }
      final key = '__EXP_${expIdx}__';
      // Atomický obal: celý E-token je jeden operand.
      expPlaceholders[key] = '($mantisaText*10^($exp))';
      expIdx++;
      processed =
          processed.substring(0, tokenStart) + key + processed.substring(eEnd);
      searchFrom = tokenStart + key.length;
    }

    // 3. EXPANZE E-NOTACE z placeholderů — musí předcházet implicitnímu
    // násobení, aby se nepracovalo nad dočasnými názvy __EXP_n__:
    // podtržítko by bránilo vložení '*' (lookahead (?![^_]*_)), např.
    // u 2(10E5) by chybělo vnější násobení. Rozbalený text je čistě
    // číselný, takže jej krok 5 (dosazování) nemůže poškodit.
    expPlaceholders.forEach((k, v) {
      processed = processed.replaceAll(k, v);
    });

    // 4. ROBUSTNÍ IMPLICITNÍ NÁSOBENÍ — musí proběhnout PŘED dosazením
    // paměťových proměnných: \b v kroku 5 vyžaduje oboustrannou hranici,
    // takže sousedící proměnné (4AC, 2A, AC) by se samy o sobě nedosadily.
    // Po vložení '*' mezi sousedící tokeny mají proměnné oboustrannou
    // hranici a krok 5 je spolehlivě nahradí hodnotami. Markery funkcí
    // chrání lookahead (?![^_]*_).
    processed = processed.replaceAllMapped(
      RegExp(r'(\d|[A-Z])(?=[A-Z\(])(?![^_]*_)'),
      (m) => '${m[1]}*',
    );
    processed = processed.replaceAllMapped(
      RegExp(r'(\))(?=[\d[A-Z])(?![^_]*_)'),
      (m) => '${m[1]}*',
    );
    processed = processed.replaceAll(')(', ')*(');

    // 5. NAHRAZENÍ PROMĚNNÝCH (E-notation už je rozbalena na čísla;
    // žádné E z chráněné notace v textu není)
    _memory.forEach((key, value) {
      processed = processed.replaceAll(
        RegExp('\\b$key\\b'),
        '(${value.toString()})',
      );
    });

    // DMS ZPRACOVÁNÍ
    processed = processed.replaceAllMapped(
      RegExp(
        r'''(?<![\d.])(-?\d+(?:\.\d+)?)°(?:(\d+(?:\.\d+)?)\')?(?:(\d+(?:\.\d+)?)\")?''',
      ),
      (m) {
        double d = double.parse(m[1]!);
        double mn = m[2] != null ? double.parse(m[2]!) : 0.0;
        double sc = m[3] != null ? double.parse(m[3]!) : 0.0;
        double sign = d < 0 ? -1.0 : 1.0;
        return '(${sign * (d.abs() + mn / 60.0 + sc / 3600.0)})';
      },
    );

    // FAKTORIÁL (n > 20 přetéká double -> strukturální overflow,
    // nikoli syntax ani dělení nulou).
    processed = processed.replaceAllMapped(RegExp(r'(\d+)!'), (m) {
      int n = int.parse(m[1]!);
      final f = _factorial(n);
      if (!f.isFinite) {
        throw const CalcError(
          CalcErrorKind.overflow,
          CalcErrorReason.overflowInfinite,
        );
      }
      return f.toString();
    });

    if (processed.isEmpty) return 0.0;

    // (E-notace již expandována z placeholderů – druhý průchod odstraněn)

    // N-TÁ ODMOCNINA: xⁿ√y -> root(x, y)
    processed = processed.replaceAllMapped(
      RegExp(
        r'(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))ⁿ√(\d+(?:\.\d+)?|[A-Z]|\([^)]+\))',
      ),
      (m) {
        return 'root(${m[1]},${m[2]})';
      },
    );

    // 6. KONTROLA ZÁVOREK (bez automatické opravy).
    // Nevyvážené závorky jsou syntaktická chyba — kalkulačka nesmí hádat
    // význam výrazu za uživatele (viz audit: '1+2)' se nesmí tiše změnit).
    int openCount = '('.allMatches(processed).length;
    int closeCount = ')'.allMatches(processed).length;
    if (openCount != closeCount) {
      throw const CalcError(
        CalcErrorKind.syntax,
        CalcErrorReason.syntaxParens,
      );
    }

    // =========================================================================
    // 7. EXPANZE MARKERŮ A DEG/RAD KONVERZE
    // =========================================================================
    const String PI_VAL = '3.14159265358979323846';

    // KROK A: Ostatní standardní funkce musíme z markerů expandovat jako PRVNÍ!
    // Tím zmizí matoucí vnitřní závorky typu _SQRT_(5) a nahradí se za čisté sqrt(5).
    processed = processed.replaceAll('_ABS_', 'abs');
    processed = processed.replaceAll('_SQRT_', 'sqrt');
    processed = processed.replaceAll('_LN_', 'ln');

    // Vyčištění speciálních funkcí.
    // Třetí odmocnina: strukturální expanze markeru (zvládne vnořené
    // závorky, např. ∛(ANS) po substituci) se znaménkově správným
    // výpočtem pro záporné základy (viz _expandCbrtMarkers).
    processed = _expandCbrtMarkers(processed);
    processed = processed.replaceAll('_LOG_(', 'log(10,');

    // KROK B: Nyní zpracujeme goniometrické funkce podle zvoleného režimu úhlů
    if (_isDegreeMode) {
      // Pro sin, cos, tan: argument ve stupních * (PI/180)
      processed = processed.replaceAllMapped(
        RegExp(r'_SIN_\((.+)\)'),
        (m) => 'sin(${m[1]}*($PI_VAL/180))',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'_COS_\((.+)\)'),
        (m) => 'cos(${m[1]}*($PI_VAL/180))',
      );
      processed = processed.replaceAllMapped(RegExp(r'_TAN_\((.+)\)'), (m) {
        final arg = m[1]!;
        // Tangens není definovaný pro 90° + k*180°. Díky chybě plovoucí
        // řádové čárky by jinak vrátil obrovské číslo místo chyby.
        final argDegrees = _evaluateExpression(arg);
        final normalized = ((argDegrees % 180) + 180) % 180;
        if ((normalized - 90).abs() < 1e-9) {
          throw _MathDomainException(
            _s(
              'Tangens není definovaný pro ${_formatNumber(argDegrees)} stupňů.',
              'Tangent is not defined for ${_formatNumber(argDegrees)} degrees.',
            ),
          );
        }
        return 'tan($arg*($PI_VAL/180))';
      });

      // Pro asin, acos, atan: ZMĚNA na arcsin, arccos, arctan pro knihovnu math_expressions!
      // Přidány otevírací závorky na začátek pro správnou vyváženost
      processed = processed.replaceAllMapped(
        RegExp(r'_ASIN_\((.+)\)'),
        (m) => '(arcsin(${m[1]})*(180/$PI_VAL))',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'_ACOS_\((.+)\)'),
        (m) => '(arccos(${m[1]})*(180/$PI_VAL))',
      );
      processed = processed.replaceAllMapped(
        RegExp(r'_ATAN_\((.+)\)'),
        (m) => '(arctan(${m[1]})*(180/$PI_VAL))',
      );
    } else {
      // RAD mód: knihovna vyžaduje arcsin, arccos, arctan i v radiánech
      processed = processed.replaceAll('_SIN_', 'sin');
      processed = processed.replaceAll('_COS_', 'cos');
      processed = processed.replaceAll('_TAN_', 'tan');
      processed = processed.replaceAll('_ASIN_', 'arcsin');
      processed = processed.replaceAll('_ACOS_', 'arccos');
      processed = processed.replaceAll('_ATAN_', 'arctan');
    }

    // Odstranění případných zdvojených závorek po dosazení ANS, pokud by vznikly
    processed = processed.replaceAll('arcsin((', 'arcsin(');
    processed = processed.replaceAll('arccos((', 'arccos(');
    processed = processed.replaceAll('arctan((', 'arctan(');

    // KONTROLA ZÁVOREK po DEG/RAD expanzi (bez automatické opravy —
    // viz bod 6 výše). Expanze přidává pouze vyvážené závorky.
    openCount = '('.allMatches(processed).length;
    closeCount = ')'.allMatches(processed).length;

    if (openCount != closeCount) {
      throw const CalcError(
        CalcErrorKind.syntax,
        CalcErrorReason.syntaxParens,
      );
    }

    // PROCENTA: % jako postfixový operátor "/100"
    processed = processed.replaceAllMapped(RegExp(r'((?:\d+(?:\.\d+)?)|\))%'), (
      m,
    ) {
      final n = m[1]!;
      return n == ')' ? '$n/100' : '($n/100)';
    });

    debugPrint("Parsing expression: $processed");

    // 8. FINÁLNÍ VYHODNOCENÍ
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(processed)) {
      processed = '$processed+0';
    }

    try {
      final p = math_expr.ShuntingYardParser();
    // Zbytkový marker funkce (např. prázdné SIN()) = neúplná syntaxe.
    // Kontrolují se pouze naše vlastní sentinely (_SIN_, _LOG_, ...),
    // nikdy text výjimky knihovny. E-notační placeholdery jsou v tomto
    // bodě již expandovány (krok 3b), takže tu nemají co dělat.
    if (RegExp(r'_[A-Z]+_').hasMatch(processed)) {
      throw const CalcError(
        CalcErrorKind.syntax,
        CalcErrorReason.syntaxGeneral,
      );
    }

    debugPrint("Parsing expression: $processed");
      math_expr.Expression exp;
      try {
        exp = p.parse(processed);
      } catch (e) {
        // Nepodařený parse = potvrzená syntaktická chyba vstupu.
        debugPrint("Parse error: $e for expression: $processed");
        throw CalcError(
          CalcErrorKind.syntax,
          CalcErrorReason.syntaxGeneral,
          e.toString(),
        );
      }
      math_expr.ContextModel cm = math_expr.ContextModel();
      // Strukturální kontrola před vyhodnocením: vyhodnocený jmenovatel
      // (dělení nulou) a vyhodnocený argument (definiční obor).
      final structural = _findCalcError(exp, cm);
      if (structural != null) throw structural;

      return exp.evaluate(math_expr.EvaluationType.REAL, cm);
    } on CalcError {
      rethrow;
    } catch (e) {
      debugPrint("Evaluation error: $e for expression: $processed");
      rethrow;
    }
  }

  /// Automatická exponenciální prezentace (pouze DisplayFormat.standard).
  /// Podmínky: celé číslo, |value| >= 1e9 (alespoň 10 cifer), po první nenulové číslici jen nuly.
  /// Příklad: 1000000000 -> 1E+09, 10000000000 -> 1E+10. Nevztahuje se na 1230000000 apod.
  /// Bezpečnost double: toStringAsFixed(0) není důkaz přesnosti – provádí se round-trip check
  /// double.parse(absStr) == value; pokud nelze jednoznačně určit, vrací null.
  String? _tryAutoExponential(double value) {
    if (value.isNaN || value.isInfinite) return null;
    if (_displayFormat != DisplayFormat.standard) return null;
    if (value % 1 != 0) return null;
    final absVal = value.abs();
    if (absVal < 1e9) return null;
    // Kandidát jako celé číslo bez vědecké notace
    final absStr = absVal.toStringAsFixed(0);
    if (absStr.contains('.') || absStr.contains('e') || absStr.contains('E')) {
      return null;
    }
    if (absStr.length < 10) return null;
    // Round-trip přesnost: pokud parse nevrátí původní double, je reprezentace nejednoznačná
    final parsed = double.tryParse(absStr);
    if (parsed == null || parsed != absVal) return null;
    if (!RegExp(r'^[1-9]0+$').hasMatch(absStr)) return null;
    final exponent = absStr.length - 1;
    final mantissaDigit = absStr[0];
    final sign = value < 0 ? '-' : '';
    final expStr = exponent.toString().padLeft(2, '0');
    return '$sign${mantissaDigit}E+$expStr';
  }

  /// Rozklad na mantisu + exponent pro centrální speech (strukturovaná data, ne parsování stringu).
  ({String mantissa, int exponent, bool negative})? _decomposeAutoExp(
    double value,
  ) {
    final expStr = _tryAutoExponential(value);
    if (expStr == null) return null;
    // expStr je tvar "[-]dE+NN"
    final m = RegExp(r'^(-?)(\d)E\+(\d+)$').firstMatch(expStr);
    if (m == null) return null;
    final neg = m.group(1) == '-';
    final mant = m.group(2)!;
    final exp = int.parse(m.group(3)!);
    return (mantissa: mant, exponent: exp, negative: neg);
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
        int engExp =
            ((math.log(value.abs()) / math.ln10).floor() / 3).floor() * 3;
        return "${(value / math.pow(10, engExp)).toStringAsFixed(_precision)}E${engExp >= 0 ? '+' : ''}${engExp.toString().padLeft(2, '0')}";
      default:
        final auto = _tryAutoExponential(value);
        if (auto != null) return auto;
        return value.toString().contains('.')
            ? value
                  .toStringAsFixed(10)
                  .replaceAll(RegExp(r'0+$'), '')
                  .replaceAll(RegExp(r'\.$'), '')
            : value.toInt().toString();
    }
  }

  String _formatNumberSmart(double value) {
    if (_displayFormat == DisplayFormat.standard && _usePeriodicNotation) {
      final rep = _tryFormatRepeating(value);
      if (rep != null) return rep;
      final auto = _tryAutoExponential(value);
      if (auto != null) return auto;
    } else if (_displayFormat == DisplayFormat.standard) {
      final auto = _tryAutoExponential(value);
      if (auto != null) return auto;
    }
    return _formatNumber(value);
  }

  // Tenká obálka nad sdílenou čistou vrstvou (fraction.dart) pro dialog
  // „Info o čísle". Pro uživatele je dostupný pouze netriviální zlomek
  // (jmenovatel != 1); triviální n/1 hlásí jako nedostupné.
  String _decimalToFraction(double val) {
    final f = decimalToNonTrivialFraction(val);
    if (f == null) return _s('nedostupné', 'N/A');
    return formatFraction(f);
  }

  // Zlomkový řetězec aktuálního výsledku, nebo null když není způsobilý.
  // Priorita: platný netriviální RationalValue (strukturovaná přesnost),
  // jinak dosavadní aproximace z _lastNumericValue. Nikdy parsováním textu
  // _lastResult a nikdy zpětnou aproximací double jako zdrojem přesnosti:
  // aproximace slouží pouze výsledkům bez exaktních metadat.
  // Triviální n/1 (včetně 0/1) vrací null.
  String? get _fractionString {
    if (!_hasResult || _lastNumericValue == null) return null;
    if (!_lastNumericValue!.isFinite) return null;
    if (!_lastResultIsPlainNumeric) return null;
    if (_lastResult.toLowerCase() == 'error') return null;
    final r = _validRationalNonTrivial;
    if (r != null) return r.toDisplayString();
    final v = _lastNumericValue!;
    final f = decimalToNonTrivialFraction(v);
    if (f == null) return null;
    return formatFraction(f);
  }

  // Shoda uloženého override s aktuálním výsledkem (klíč + generace).
  // Samotné true/false bez platného klíče nikdy nic nevynucuje.
  bool get _isFractionOverrideKeyValid =>
      _fractionOverride != null &&
      _fractionViewKey == _lastResult &&
      _fractionViewGeneration == _resultGeneration;

  // Skutečně zobrazovaná reprezentace (jediný zdroj pro displej, tlačítko
  // i hlas). override null = základ režimu (segment vždy desetinně,
  // text/auto ukazují platný netriviální RationalValue jako n/d);
  // explicitní override platí jen s platným klíčem, zastaralý se chová
  // jako null. Aproximace se v základu nikdy sama neukazuje.
  bool _isShowingFraction() {
    if (!_isFractionEligible) return false;
    final o = _fractionOverride;
    if (o == null || !_isFractionOverrideKeyValid) {
      if (_globalResultDisplayMode == ResultDisplayMode.segment) {
        return false;
      }
      return _validRationalNonTrivial != null;
    }
    return o;
  }

  // Vynucené desetinné při platném RationalValue: obchází racionální větev
  // _activeResultString(), aby vypnutí v text/auto skutečně ukázalo
  // numerický _lastResult. Používáno rendererem i hlasem, vždy s kontrolou
  // platnosti klíče — nikdy samotné `_fractionOverride == false`.
  bool get _isForceDecimalActive =>
      _fractionOverride == false &&
      _isFractionOverrideKeyValid &&
      _validRationalNonTrivial != null;

  bool get _isFractionEligible => _fractionString != null;

  // Cíl příštího stisku přepínače (jediný autoritativní zdroj pro popisek,
  // přístupný stav i hlasové oznámení; žádná část UI cíl neodhaduje
  // samostatně). Simuluje skutečné následné vykreslení: stisk uloží
  // override = !_isShowingFraction(), takže cíl fraction znamená budoucí
  // override true a cíle numeric/surd budoucí override false se základem
  // bez zlomkového překryvu (surd pouze pro surd-základ v text/auto).
  _FractionTargetKind? _fractionTargetKindAfterNextPress() {
    if (!_isFractionEligible) return null;
    if (!_isShowingFraction()) return _FractionTargetKind.fraction;
    if ((_globalResultDisplayMode == ResultDisplayMode.text ||
            _globalResultDisplayMode == ResultDisplayMode.auto) &&
        _isSurdValid) {
      return _FractionTargetKind.surd;
    }
    return _FractionTargetKind.numeric;
  }

  // Přesný operand ANS: platný RationalValue (strukturovaně, nikdy
  // z double), jinak dosavadní numerická hodnota. Stejnou expanzi používají
  // exaktní i numerická vyhodnocovací cesta, takže řetězení (např.
  // 5/6 + 1/6) zůstává přesné.
  String _ansExpansion() {
    final r = _validRational;
    if (r != null) {
      if (r.denominator == BigInt.one) return '(${r.numerator})';
      return '(${r.numerator}/${r.denominator})';
    }
    return '(${_lastNumericValue?.toString() ?? '0'})';
  }

  // Expanze ANS pro exaktní pokus: null = nelze exaktně (neplatný Rational
  // při výskytu ANS) → volat stávající numerickou cestu beze změny.
  String? _expandAnsForRational(String expr) {
    if (!expr.contains('ANS')) return expr;
    final r = _validRational;
    if (r == null) return null;
    if (r.denominator == BigInt.one) {
      return expr.replaceAll('ANS', '(${r.numerator})');
    }
    return expr.replaceAll('ANS', '(${r.numerator}/${r.denominator})');
  }

  // Mapování vrstevnaté chyby do stávajícího CalcError (jediné místo).
  // Překročení limitu je chyba implementace (invalidOperation), nikdy
  // matematický výsleden ani důvod k tichému fallbacku do double.
  CalcError _mapRationalFailure(RationalFailureKind kind) {
    switch (kind) {
      case RationalFailureKind.divisionByZero:
        return const CalcError(
          CalcErrorKind.divisionByZero,
          CalcErrorReason.zeroDenominator,
        );
      case RationalFailureKind.unbalancedParens:
        return const CalcError(
          CalcErrorKind.syntax,
          CalcErrorReason.syntaxParens,
        );
      case RationalFailureKind.syntax:
        return const CalcError(
          CalcErrorKind.syntax,
          CalcErrorReason.syntaxGeneral,
        );
      case RationalFailureKind.limitExceeded:
        return const CalcError(
          CalcErrorKind.invalidOperation,
          CalcErrorReason.unknown,
          'rational-limit',
        );
    }
  }

  // Automatická věta o dostupnosti zlomku pro výsledkovou speech.
  // Pure helper: pouze čte stav a rozhoduje, jakou doplňující větu (pokud
  // vůbec nějakou) přidat ke stávající speech string. Nemění state,
  // nepřepočítává matematiku (konkrétní zlomek bere z _fractionString jako
  // zdroje pravdy), nevolá TTS, nemění focus ani UI. Surd výsledky se
  // nevylučují: řídí se stejnou logikou jako fraction toggle.
  // Vrací null = nic nepřidávat (screen reader ON nebo nerelevantní kontext).
  String? _fractionAvailabilitySuffix() {
    // UNKNOWN (=ne false) → bez doplňkové věty, výsledek oznamuje displej.
    if (_isScreenReaderActive != false) return null;
    if (_currentMode != CalculatorMode.basic &&
        _currentMode != CalculatorMode.scientific) {
      return null;
    }
    if (!_hasResult || !_lastResultIsPlainNumeric) return null;
    // Již zobrazený zlomek se znovu neavizuje (žádná duplicita).
    if (_isShowingFraction()) return null;
    final fracStr = _fractionString;
    if (fracStr != null) {
      final spokenFraction = fracStr.replaceAll('/', _s(' lomeno ', ' over '));
      return _l10n.fractionAvailableAnnouncement(spokenFraction);
    }
    // Triviální zlomek (n/1) ani jiná nedostupnost se k výsledkové speech
    // automaticky nepřidává: výsledek zůstává pouze běžnou hláškou.
    return null;
  }

  // Mluvená podoba zlomku "3 lomeno 4" / "3 over 4".
  String _spokenFraction(Fraction f) {
    if (_isEnglish()) return '${f.numerator} over ${f.denominator}';
    return '${f.numerator} lomeno ${f.denominator}';
  }

  // Řeč aktuálního výsledku pro Semantics.value a onTap: zlomek při
  // skutečně zobrazeném zlomkovém pohledu (racionální metadata přednostně,
  // jinak aproximace), jinak reprezentace podle skutečně zvoleného
  // ResultDisplayMode (segment -> numerika, text/auto -> exaktní tvar
  // pokud validní). Zrcadlí renderer — displej a hlas se nerozcházejí.
  String _currentResultSpeech() {
    if (_isShowingFraction()) {
      final r = _validRationalNonTrivial;
      if (r != null) {
        if (_isEnglish()) {
          return '${r.numerator} over ${r.denominator}';
        }
        return '${r.numerator} lomeno ${r.denominator}';
      }
      final v = _lastNumericValue;
      final f = v == null ? null : decimalToNonTrivialFraction(v);
      if (f != null) return _spokenFraction(f);
      final s = _fractionString;
      if (s != null) return s.replaceAll('/', _s(' lomeno ', ' over '));
    }
    if (_isForceDecimalActive) {
      if (_lastResult == 'Error') return _s('Chyba', 'Error');
      return _spokenForDisplay(
        _lastResult.isEmpty ? '0.' : _lastResult,
      );
    }
    final active = _activeResultString();
    // R7: chybový stav číst lokalizovaně ("Chyba"/"Error"),
    // ne anglickým interním 'Error' v českém jazyce.
    if (active == 'Error') return _s('Chyba', 'Error');
    return _spokenForDisplay(active);
  }

  // Prezentační přepínač DEC <-> a/b. Nemění _lastResult, _lastNumericValue,
  // ANS, historii ani exact metadata. Vždy dosažitelný (i při
  // nezpůsobilosti): jedna aktivace = právě jedno oznámení stávající
  // infrastrukturou (say), nikdy paralelní TTS ani debounce. Oznámení
  // vždy odpovídá cíli stisku z _fractionTargetKindAfterNextPress.
  void toggleFractionResultView() {
    final target = _fractionTargetKindAfterNextPress();
    if (target == null) {
      say(_l10n.fractionUnavailable);
      return;
    }
    final showingAfter = target == _FractionTargetKind.fraction;
    setState(() {
      _fractionOverride = showingAfter;
      _fractionViewKey = _lastResult;
      _fractionViewGeneration = _resultGeneration;
    });
    if (showingAfter) {
      final r = _validRationalNonTrivial;
      if (r != null) {
        say(_l10n.fractionAnnounced(r.numerator, r.denominator));
      } else {
        final v = _lastNumericValue;
        final f = v == null ? null : decimalToNonTrivialFraction(v);
        if (f != null) {
          say(_l10n.fractionAnnounced(f.numerator, f.denominator));
        } else {
          final fracStr = _fractionString;
          say(
            _s(
              'Zlomek $fracStr.',
              'Fraction $fracStr.',
            ).replaceAll('/', _s(' lomeno ', ' over ')),
          );
        }
      }
    } else {
      // Návrat ze zlomkového pohledu: oznámit reprezentaci, která je po
      // stisku skutečně aktivní (cíl z target-funkce, ne odhad).
      // Neměnit _lastResult, _lastNumericValue, _lastExact ani generace.
      if (target == _FractionTargetKind.surd &&
          _lastExact is SurdValue) {
        say(
          _l10n.resultIs(
            _spokenForDisplay(formatSurd(_lastExact as SurdValue)),
          ),
        );
      } else {
        say(
          _l10n.resultIs(
            _spokenForDisplay(
              _lastResult.isEmpty ? '0.' : _lastResult,
            ),
          ),
        );
      }
    }
  }

  List<int> _primeFactors(int n) {
    List<int> factors = [];
    int m = n;
    while (m % 2 == 0) {
      factors.add(2);
      m ~/= 2;
    }
    for (int i = 3; i * i <= m; i += 2) {
      while (m % i == 0) {
        factors.add(i);
        m ~/= i;
      }
    }
    if (m > 1) {
      factors.add(m);
    }
    return factors;
  }

  List<int> _getDivisors(int n) {
    List<int> divs = [];
    for (int i = 1; i * i <= n; i++) {
      if (n % i == 0) {
        divs.add(i);
        if (i != n ~/ i) {
          divs.add(n ~/ i);
        }
      }
    }
    divs.sort();
    return divs;
  }

  String _formatAsDMS(double value) {
    double absVal = value.abs();
    double totalSeconds = absVal * 3600;
    // Normalizace zaokrouhlovacích artefaktů plovoucí řádové čárky,
    // aby např. ASIN(0,5) bylo 30°0'0", nikoli 29°59'60".
    double roundedTotal = totalSeconds.roundToDouble();
    int wholeSeconds;
    double fracSeconds;
    if ((totalSeconds - roundedTotal).abs() < 1e-6) {
      wholeSeconds = roundedTotal.toInt();
      fracSeconds = 0.0;
    } else {
      wholeSeconds = totalSeconds.floor();
      fracSeconds = totalSeconds - wholeSeconds;
    }
    int s = wholeSeconds % 60;
    int totalMinutes = wholeSeconds ~/ 60;
    int m = totalMinutes % 60;
    int d = totalMinutes ~/ 60;

    String sStr;
    if (fracSeconds > 0) {
      sStr = (s + fracSeconds)
          .toStringAsFixed(6)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    } else {
      sStr = s.toString();
    }

    return "${value < 0 ? '-' : ''}$d°$m'$sStr\"";
  }

  void _convertUnits() {
    try {
      // Zdroj hodnoty jako u měny: displej, jinak poslední výsledek pouze
      // při platném _hasResult. Prázdný displej bez výsledku = chyba, nikdy
      // tichá nula (clear() nechává _lastResult '0.' s _hasResult false).
      // Desetinná čárka v _lastResult se převádí na tečku (defenzivně,
      // _formatNumber běžně vydává tečku).
      double value;
      if (display.trim().isNotEmpty) {
        value = _evaluateExpression(display.trim());
      } else if (_hasResult && _lastResult.toLowerCase() != 'error') {
        final parsed = double.tryParse(
          _lastResult.replaceAll(',', '.'),
        );
        if (parsed == null) throw Exception('no value');
        value = parsed;
      } else {
        throw Exception('no value');
      }
      final factors = _unitCategories[_selectedUnitCategory];
      if (factors == null) throw Exception('invalid category');
      final double? fromFactor = factors[_unitFrom];
      final double? toFactor = factors[_unitTo];
      if (fromFactor == null || toFactor == null) {
        throw Exception('invalid unit');
      }
      // Oba faktory musí být konečné a nenulové (jako nulové kurzy u měny).
      // Aktuální konstanty to splňují, kontrola je obrana proti nekonzistenci.
      if (!fromFactor.isFinite ||
          !toFactor.isFinite ||
          fromFactor == 0 ||
          toFactor == 0) {
        throw Exception('invalid factor');
      }
      double result = value * (fromFactor / toFactor);
      // Platná vstupní nula dává platnou nulu; neplatný je jen NaN/nekonečno.
      if (result.isNaN || result.isInfinite) throw Exception('invalid result');
      String resStr = _formatNumber(result);
      setState(() {
        _lastResult = resStr;
        display = '';
        _hasResult = true;
        // Převod jednotek je speciální prezentační kontext: zlomek nevhodný.
        _lastResultIsPlainNumeric = false;
        _fractionOverride = null;
        // R10: synchronizace stavu – ANS a historie jako u měny.
        // (Matematika se nemění, pouze se ukládá již vypočtená hodnota.)
        _lastNumericValue = result;
        // Nový výsledek ruší přesná metadata (klíč + generace).
        _lastExact = null;
        _lastExactKey = '';
        _resultGeneration++;
        _lastExactGeneration = _resultGeneration;
      });
      _addToHistory(
        '${value.toString()} $_unitFrom → $_unitTo',
        resStr,
        numericValue: result,
      );
      // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
      unawaited(
        announceEvent(
          _l10n.unitConverted(
            _getUnitSpeech(_unitFrom, context: 'z'),
            _getUnitSpeech(_unitTo, context: 'na'),
            resStr,
            _getUnitSpeech(_unitTo, value: result),
          ),
          category: SpeechCategory.actionConfirm,
          isNumeric: true,
          interruptCurrentSpeech: true,
        ),
      );
    } catch (e) {
      // Sjednoceno s měnou: oznámení + vizuální SnackBar bez duplicity.
      unawaited(
        announceEvent(
          _l10n.conversionError,
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
      _showAccessibleSnackBar(_l10n.conversionError, announce: false);
    }
  }

  /// Sdílená změna kategorie jednotek: nastaví platné výchozí jednotky
  /// (první dvě v kategorii) a ohlásí změnu. Používá panel na hlavní
  /// obrazovce i dialog Pokročilých funkcí – jediná implementace.
  void _selectUnitCategory(String category) {
    final units = _unitCategories[category];
    if (units == null || units.length < 2) return;
    setState(() {
      _selectedUnitCategory = category;
      _unitFrom = units.keys.first;
      _unitTo = units.keys.elementAt(1);
    });
    speak(
      _s(
        'Kategorie ${_getCategorySpeech(category)}',
        'Category ${_getCategorySpeech(category)}',
      ),
    );
  }

  /// Lokalizovaný název měny pro zobrazení. Neznámé kódy (vlastní měny
  /// ze Správy kurzů) vrací holý kód – nikdy visící pomlčku.
  String _localizedCurrencyName(String code) {
    final l10n = _l10n;
    switch (code) {
      case 'CZK':
        return l10n.currencyNameCZK;
      case 'EUR':
        return l10n.currencyNameEUR;
      case 'USD':
        return l10n.currencyNameUSD;
      case 'GBP':
        return l10n.currencyNameGBP;
      case 'PLN':
        return l10n.currencyNamePLN;
      case 'HUF':
        return l10n.currencyNameHUF;
      case 'CHF':
        return l10n.currencyNameCHF;
      case 'JPY':
        return l10n.currencyNameJPY;
      default:
        return code;
    }
  }

  /// Popisek „KÓD — název" pro výběrové seznamy a hlášky. Interní kód
  /// (value dropdownů, výpočty, kurzy, perzistence) zůstává vždy holý kód.
  String _currencyDisplayName(String code) {
    final name = _localizedCurrencyName(code);
    return name == code ? code : '$code — $name';
  }

  /// Panel převodu jednotek přímo na hlavní obrazovce (mimo 7×4 rastr,
  /// v běžné fokusové cestě). Stejná logika jako Pokročilé funkce.
  Widget _buildUnitConversionPanel() {
    final s = _responsiveScale(context);
    final l10n = _l10n;
    // Izolace od systémového škálování textu (stejný vzor jako klávesnice
    // a přepínač zlomku): zavřené pole a tlačítko drží kompaktní velikost,
    // aby se panel vešel i na malé displeje. Rozbalený seznam (overlay)
    // systémové škálování respektuje – výběr zůstává čitelný.
    final sysFactor = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.6);
    final fieldFontSize = (15.0 * s * sysFactor).clamp(13.0, 16.0);
    final fieldStyle = TextStyle(fontSize: fieldFontSize);
    const fieldPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 2);
    final units = _unitCategories[_selectedUnitCategory]!.keys.toList();
    List<DropdownMenuItem<String>> unitItems() => units
        .map(
          (u) => DropdownMenuItem(
            value: u,
            child: Text(
              _getUnitSpeech(u),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
    Widget fromField = Semantics(
      label: _s('Převod z jednotky', 'Convert from unit'),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('unit_from_dropdown'),
        initialValue: _unitFrom,
        isExpanded: true,
        isDense: true,
        style: fieldStyle,
        decoration: InputDecoration(
          labelText: l10n.fromLabel,
          contentPadding: fieldPadding,
        ),
        items: unitItems(),
        onChanged: (val) {
          if (val == null) return;
          setState(() => _unitFrom = val);
          speak(
            _s(
              'Z jednotky ${_getUnitSpeech(val)}',
              'From unit ${_getUnitSpeech(val)}',
            ),
          );
        },
      ),
    );
    Widget toField = Semantics(
      label: _s('Převod na jednotku', 'Convert to unit'),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('unit_to_dropdown'),
        initialValue: _unitTo,
        isExpanded: true,
        isDense: true,
        style: fieldStyle,
        decoration: InputDecoration(
          labelText: l10n.toLabel,
          contentPadding: fieldPadding,
        ),
        items: unitItems(),
        onChanged: (val) {
          if (val == null) return;
          setState(() => _unitTo = val);
          speak(
            _s(
              'Na jednotku ${_getUnitSpeech(val)}',
              'To unit ${_getUnitSpeech(val)}',
            ),
          );
        },
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * s),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.noScaling),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('unit_category_dropdown'),
              initialValue: _selectedUnitCategory,
              isExpanded: true,
              isDense: true,
              style: fieldStyle,
              decoration: InputDecoration(
                labelText: l10n.categoryLabel,
                contentPadding: fieldPadding,
              ),
              items: _unitCategories.keys
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(
                        _getCategorySpeech(cat),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                _selectUnitCategory(val);
              },
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth < 360) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [fromField, const SizedBox(height: 4), toField],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fromField),
                    const ExcludeSemantics(child: Icon(Icons.arrow_forward)),
                    Expanded(child: toField),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('unit_convert_button'),
                onPressed: _convertUnits,
                icon: const Icon(Icons.sync),
                label: Text(l10n.convertButton, style: fieldStyle),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Panel převodu měn přímo na hlavní obrazovce (mimo 7×4 rastr,
  /// v běžné fokusové cestě). Správa kurzů zůstává v Pokročilých funkcích.
  Widget _buildCurrencyPanel() {
    final s = _responsiveScale(context);
    final l10n = _l10n;
    // Izolace od systémového škálování textu (viz panel jednotek):
    // zavřená pole a tlačítko drží kompaktní velikost, rozbalený seznam
    // systémové škálování respektuje.
    final sysFactor = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.6);
    final fieldFontSize = (15.0 * s * sysFactor).clamp(13.0, 16.0);
    final fieldStyle = TextStyle(fontSize: fieldFontSize);
    const fieldPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 2);
    List<DropdownMenuItem<String>> currencyItems() => _currencyRates.keys
        .map(
          (c) => DropdownMenuItem(
            value: c,
            child: Text(
              _currencyDisplayName(c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
    Widget fromField = DropdownButtonFormField<String>(
      key: const ValueKey('currency_from_dropdown'),
      initialValue: _currencyFrom,
      isExpanded: true,
      isDense: true,
      style: fieldStyle,
      decoration: InputDecoration(
        labelText: l10n.currencyFromLabel,
        contentPadding: fieldPadding,
      ),
      items: currencyItems(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _currencyFrom = v);
        _saveCurrencyRates();
        speak(_s('Z měny ${_currencyDisplayName(v)}', 'From ${_currencyDisplayName(v)}'));
      },
    );
    Widget toField = DropdownButtonFormField<String>(
      key: const ValueKey('currency_to_dropdown'),
      initialValue: _currencyTo,
      isExpanded: true,
      isDense: true,
      style: fieldStyle,
      decoration: InputDecoration(
        labelText: l10n.currencyToLabel,
        contentPadding: fieldPadding,
      ),
      items: currencyItems(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _currencyTo = v);
        _saveCurrencyRates();
        speak(_s('Na měnu ${_currencyDisplayName(v)}', 'To ${_currencyDisplayName(v)}'));
      },
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * s),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.noScaling),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth < 360) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [fromField, const SizedBox(height: 4), toField],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fromField),
                    const ExcludeSemantics(child: Icon(Icons.arrow_forward)),
                    Expanded(child: toField),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('currency_convert_button'),
                onPressed: () => _convertCurrency(),
                icon: const Icon(Icons.sync),
                label: Text(l10n.convertButton, style: fieldStyle),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getUnitSpeech(
    String unitCode, {
    double? value,
    String context = 'base',
  }) {
    if (_isEnglish()) {
      final en = _unitSpeechDataEn[unitCode];
      if (en == null) {
        return unitCode;
      }
      if (value != null) {
        return value.abs() == 1 ? en['base']! : en['plural']!;
      }
      return context == 'base' ? en['base']! : en['plural']!;
    }
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
    const map = {
      'á': 'A',
      'č': 'C',
      'ď': 'D',
      'é': 'E',
      'ě': 'E',
      'í': 'I',
      'ň': 'N',
      'ó': 'O',
      'ř': 'R',
      'š': 'S',
      'ť': 'T',
      'ú': 'U',
      'ů': 'U',
      'ý': 'Y',
      'ž': 'Z',
    };
    String result = text;
    map.forEach(
      (key, value) => result = result
          .replaceAll(key, value)
          .replaceAll(key.toUpperCase(), value),
    );
    return result;
  }

  Widget _buildMainResultDisplay({double fitScale = 1.0}) {
    // Zlomkový náhled má přednost před globálním ResultDisplayMode, ale NEMĚNÍ
    // ho: vždy matematický text se zlomkem, návrat obnoví skutečnou větev.
    // Vynucené desetinné (override false při platném RationalValue) základ
    // obchází a padá na numerický _lastResult (viz _isForceDecimalActive).
    final fracStr = _fractionString;
    if (_isShowingFraction() && fracStr != null) {
      return _buildMathTextDisplay(fracStr, fitScale: fitScale);
    }
    if (_isForceDecimalActive) {
      final String numericRes = _lastResult.isEmpty ? '0.' : _lastResult;
      if (numericRes.contains('°')) {
        return _buildDmsDisplay(numericRes, fitScale: fitScale);
      }
      return _buildNumericResultDisplay(numericRes, fitScale: fitScale);
    }
    String res = _lastResult.isEmpty ? '0.' : _lastResult;
    // Nový režim vzhledu výsledku (default segment = původní chování).
    // Error zůstává vždy na segmentovém rendereru (CHYBA/Err mapování).
    // Aktivní reprezentaci určuje _activeResultString(); fraction view výše.
    if (res.toLowerCase() != 'error') {
      final mode = _resultDisplayMode;
      if (mode == ResultDisplayMode.text) {
        return _buildMathTextDisplay(_activeResultString(), fitScale: fitScale);
      }
      if (mode == ResultDisplayMode.auto) {
        final CalcValue value = _isSurdValid
            ? _lastExact!
            : (_validRationalNonTrivial != null
                ? _lastExact!
                : const NumericValue(0));
        if (chooseDisplayRenderer(value, res) == CalcDisplayKind.mathText) {
          return _buildMathTextDisplay(
            _activeResultString(),
            fitScale: fitScale,
          );
        }
      }
    }
    if (res.contains('°')) {
      return _buildDmsDisplay(res, fitScale: fitScale);
    }
    return _buildNumericResultDisplay(res, fitScale: fitScale);
  }

  // Čistě numerické vykreslení _lastResult (DMS / vědecké / segmentové),
  // bez text/auto exaktních větví. Používáno pro vynucené desetinné
  // (override false při platném RationalValue); matematika ani metadata
  // se nemění, pouze se obchází základ s n/d.
  Widget _buildNumericResultDisplay(String res, {double fitScale = 1.0}) {
    // Auto-exponenciální prezentace ve standard režimu (obsahuje 'E') používá stejný vědecký displej
    final isAutoExp =
        res.contains('E') && RegExp(r'^-?\dE[+-]\d+$').hasMatch(res);
    if (((_displayFormat != DisplayFormat.standard) &&
            res.toLowerCase() != 'error') ||
        isAutoExp) {
      return _buildScientificTripleDisplay(res, fitScale: fitScale);
    }
    return _buildStandardDisplay(res, fitScale: fitScale);
  }

  Widget _buildStandardDisplay(String res, {double fitScale = 1.0}) {
    final scale = _responsiveScale(context);
    return CustomSegmentDisplay(
      value: _normalizeForSegmentDisplay(_toBarNotation(res)),
      size: 16 * _resultZoom * scale * fitScale,
      characterCount: 16,
      isSixteenSegment: _useSixteenSegment,
      overlineThickness: _overlineThickness,
      overlineHeight: _overlineHeight,
    );
  }

  // Samostatný matematický textový renderer pro výsledky typu "6√2".
  // Není pseudo-segmentový font: používá přibalený DejaVu Sans (konzistentní
  // glyfy √ ∛ ⁿ ² ³ π na Windows i Androidu). Segmentový renderer tím není
  // dotčen a zůstává plně obnovitelný přes ResultDisplayMode.segment.
  // Bez vlastního Semantics (ExcludeSemantics): čtečka čte dál jedinou
  // vnější Semantics value, nevzniká duplicitní čtení.
  Widget _buildMathTextDisplay(String text, {double fitScale = 1.0}) {
    final scale = _responsiveScale(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ExcludeSemantics(
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.end,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontFamily: 'MathText',
            fontFamilyFallback: const ['sans-serif'],
            fontSize: 30 * _resultZoom * scale * fitScale,
            fontWeight: FontWeight.w600,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildScientificTripleDisplay(String text, {double fitScale = 1.0}) {
    List<String> parts = text.contains('E') ? text.split('E') : [text, '00'];
    String mantissa = parts[0];
    String exponent = parts[1].replaceAll('+', '');
    String formattedExp = exponent.startsWith('-')
        ? '-${exponent.substring(1).padLeft(2, '0')}'
        : exponent.padLeft(3, '0');
    final scale = _responsiveScale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildStandardDisplay(mantissa, fitScale: fitScale),
        SizedBox(width: 8 * scale * fitScale),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Dekorativní exponent-marker: pro čtečku vyloučen, aby se
            // nesléval do hodnoty samostatného uzlu výsledku
            // ([_buildResultA11yNode]) ani netvořil zastávku navíc.
            // Informaci o exponentu nese řeč výsledku sama.
            ExcludeSemantics(
              child: Text(
                'x10',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10 * scale * fitScale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            CustomSegmentDisplay(
              value: formattedExp,
              size: 8 * _resultZoom * scale * fitScale,
              characterCount: 3,
              isSixteenSegment: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDmsDisplay(String text, {double fitScale = 1.0}) {
    // DMS už zobrazujeme na jednom řádku přímo pomocí CustomSegmentDisplay
    return _buildStandardDisplay(text, fitScale: fitScale);
  }

  // Přímé ovládání kurzoru: 4 tlačítka (Začátek, Doleva, Doprava, Konec).
  // Hlavní řádek nad zlomkovým přepínačem.
  Widget _buildCursorNavigationRow() {
    final s = _responsiveScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4 * s),
      child: Row(
        children: [
          Expanded(
            child: buildButton(
              _s('Zač.', 'Start'),
              icon: Icons.first_page,
              semanticLabel: _s('Na začátek', 'To start'),
              onPressed: () => _moveCursorTo(0),
              expanded: false,
            ),
          ),
          Expanded(
            child: buildButton(
              _s('Zpět', 'Back'),
              icon: Icons.chevron_left,
              semanticLabel: _s('O jeden znak doleva', 'One character left'),
              onPressed: () => _moveCursorBy(-1),
              expanded: false,
            ),
          ),
          Expanded(
            child: buildButton(
              _s('Vpřed', 'Forward'),
              icon: Icons.chevron_right,
              semanticLabel: _s('O jeden znak doprava', 'One character right'),
              onPressed: () => _moveCursorBy(1),
              expanded: false,
            ),
          ),
          Expanded(
            child: buildButton(
              _s('Konec', 'End'),
              icon: Icons.last_page,
              semanticLabel: _s('Na konec', 'To end'),
              onPressed: () => _moveCursorTo(display.length),
              expanded: false,
            ),
          ),
        ],
      ),
    );
  }

  // Samostatný řádek ovládání zobrazení výsledku DEC <-> a/b v hlavním
  // vertikálním layoutu (displej -> tento řádek -> přepínač režimů ->
  // vědecká stránka -> klávesnice). Není součástí displeje, jeho Stacku
  // ani keypad_grid. Kompaktní výška (pouze padding tohoto řádku), aby
  // se nic nerozbilo na malých displejích / vysokém zoomu.
  Widget _buildFractionViewToggleRow() {
    final s = _responsiveScale(context);
    // Nulový vnější svislý padding: výšku řádku určuje pouze kompaktní
    // tlačítko (viz _buildFractionToggle). I tak zůstává řádek stabilní
    // a nerozbije malé displeje ani vysoký zoom. Vedle přepínače stojí
    // tlačítko vložení zlomku (dialog Čitatel/Jmenovatel) — stále mimo
    // displej, Stack i 7×4 rastr klávesnice.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Přepínač se smí zúžit (Text má ellipsis), vkládací tlačítko
          // drží plný popisek pro odečítače.
          Flexible(child: _buildFractionToggle(s)),
          SizedBox(width: 8 * s),
          _buildFractionInsertButton(s),
        ],
      ),
    );
  }

  // Tlačítko vložení zlomku: otevírá přístupný dialog Čitatel/Jmenovatel,
  // potvrzení vloží hotový tvar "(n/d)" výhradně přes _insertAtCursor()
  // na zapamatované pozici kurzoru. Zrušení nic nemění. Po aktivaci fokus
  // zůstává na tlačítku, dialog řeší centrální správa fokusu.
  Widget _buildFractionInsertButton(double s) {
    final sysFactor = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.6);
    final insertFontSize = (13.0 * s * sysFactor).clamp(12.0, 16.0);
    final String label = _s('Vložit zlomek', 'Insert fraction');
    return Semantics(
      label: label,
      button: true,
      enabled: true,
      child: ExcludeSemantics(
        child: TextButton(
          key: const ValueKey('fraction_insert'),
          onPressed: _showFractionInputDialog,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            foregroundColor: Colors.redAccent,
          ),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: insertFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Přístupný dialog Čitatel/Jmenovatel. Sbírá pouze n/d (max. 12 číslic,
  // čitatel smí mít úvodní '-', jmenovatel kladný a nenulový, 1 se odmítá),
  // validuje s lokalizovanými chybami a po potvrzení vloží "(n/d)" přes
  // _insertAtCursor. Evaluátor přijatý vstup na limitu neodmítne (dialogové
  // limity ≤ limitům Rational). Jediné hlasové potvrzení stávajícím kanálem.
  Future<void> _showFractionInputDialog() {
    final int insertPos = _cursorPosition;
    final bool startFresh = _hasResult;
    final numCtrl = TextEditingController();
    final denCtrl = TextEditingController();
    // Chyby validace žijí mimo builder, aby je rebuild dialogu nezahodil.
    String? numError;
    String? denError;
    return showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(
        name: _s('Vložit zlomek', 'Insert fraction'),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          InputDecoration decoration(String label, String? error) =>
              InputDecoration(
                labelText: label,
                errorText: error,
                helperText: _s(
                  'Povolené znaky: číslice, čitatel smí mít mínus, max. 12',
                  'Allowed: digits, numerator may start with minus, max. 12',
                ),
              );
          return AlertDialog(
            scrollable: false,
            insetPadding: _dialogInsetPadding(),
            title: Semantics(
              header: true,
              child: Text(_s('Vložit zlomek', 'Insert fraction')),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: _s('Čitatel', 'Numerator'),
                    child: TextField(
                      controller: numCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[-\d]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                      decoration: decoration(
                        _s('Čitatel', 'Numerator'),
                        numError,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: _s('Jmenovatel', 'Denominator'),
                    child: TextField(
                      controller: denCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: decoration(
                        _s(
                          'Jmenovatel (nesmí být nula)',
                          'Denominator (must not be zero)',
                        ),
                        denError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_l10n.cancel.toUpperCase()),
              ),
              TextButton(
                onPressed: () {
                  final nText = numCtrl.text.trim();
                  final dText = denCtrl.text.trim();
                  String? nErr;
                  String? dErr;
                  if (!RegExp(r'^-?\d{1,12}$').hasMatch(nText)) {
                    nErr = _s(
                      'Čitatel musí být celé číslo, nejvýše 12 číslic.',
                      'Numerator must be an integer with up to 12 digits.',
                    );
                  }
                  if (!RegExp(r'^\d{1,12}$').hasMatch(dText)) {
                    dErr = _s(
                      'Jmenovatel musí být kladné celé číslo, nejvýše 12 číslic.',
                      'Denominator must be a positive integer with up to 12 digits.',
                    );
                  } else if (int.parse(dText) == 0) {
                    dErr = _s(
                      'Jmenovatel nesmí být nula.',
                      'Denominator must not be zero.',
                    );
                  } else if (int.parse(dText) == 1) {
                    dErr = _s(
                      'Jmenovatel 1 netvoří zlomek, zadejte číslo přímo.',
                      'Denominator 1 is not a fraction, enter the number directly.',
                    );
                  }
                  if (nErr != null || dErr != null) {
                    // Dialog zůstává otevřený, chyby se ukážou v polích
                    // (errorText čte čtečka při fokusu pole).
                    setStateDialog(() {
                      numError = nErr;
                      denError = dErr;
                    });
                    return;
                  }
                  Navigator.pop(ctx);
                  final n = BigInt.parse(nText);
                  final d = BigInt.parse(dText);
                  setState(() {
                    if (startFresh) {
                      display = '';
                      _cursorPosition = 0;
                      _hasResult = false;
                      _pendingNegOpens.clear();
                      _fractionOverride = null;
                    } else {
                      _cursorPosition =
                          insertPos.clamp(0, display.length);
                    }
                  });
                  _insertAtCursor('($n/$d)');
                  speak(
                    _s(
                      'Vloženo $n lomeno $d',
                      'Inserted $n over $d',
                    ),
                  );
                },
                child: Text(_l10n.confirmAction.toUpperCase()),
              ),
            ],
          );
        },
      ),
    );
  }

  // Prezentační přepínač DEC <-> a/b jako běžné tlačítko hlavního layoutu
  // (nikoli overlay displeje ani součást 7×4 rastru klávesnice). Stabilní
  // místo, plný význam v Semantics labelu (stav i akce bez použití barvy)
  // + toggled příznak. Vizuální stav je textový ("Zlomek: {fraction} ·
  // zapnuto/vypnuto/nedostupné"), tedy rozlišitelný i bez barvy. Přepínač je
  // vždy dosažitelný (nikdy disabled): nezpůsobilý stisk nic nepřepne
  // a jednou oznámí důvod. Focus order se nemění. Po aktivaci se fokus
  // nepřesouvá (žádný _mainFocusNode.requestFocus), zůstává na tlačítku.
  Widget _buildFractionToggle(double s) {
    // Přepínač je VŽDY přístupně dosažitelný (nikdy disabled): při
    // nezpůsobilosti stisk nic nepřepne a právě jednou oznámí důvod
    // stávající infrastrukturou (say). Popisek i stav se odvozují od
    // skutečně zobrazené reprezentace a cíle příštího stisku
    // (_fractionTargetKindAfterNextPress); žádná větev cíl neodhaduje.
    final bool eligible = _isFractionEligible;
    final bool showing = _isShowingFraction();
    final _FractionTargetKind? target =
        _fractionTargetKindAfterNextPress();

    String semanticLabel;
    String visualText;
    if (!eligible) {
      visualText = _l10n.fractionVisualUnavailable;
      semanticLabel = '$visualText. ${_l10n.fractionUnavailable}';
    } else if (showing) {
      final String fracStr = _fractionString!;
      visualText = _l10n.fractionVisualOn(fracStr);
      // Zpět vede stisk na základ bez překryvu (cíl z target-funkce).
      final bool backExact = target == _FractionTargetKind.surd;
      final String base = backExact
          ? _l10n.fractionBaseExact
          : _l10n.fractionBaseNumeric;
      final String back = backExact
          ? _l10n.fractionSwitchToBaseExact
          : _l10n.fractionSwitchToBaseNumeric;
      semanticLabel = '$visualText. $base. $back';
    } else {
      final String fracStr = _fractionString!;
      visualText = _l10n.fractionVisualOff(fracStr);
      final String base = _fractionBaseIsExact
          ? _l10n.fractionBaseExact
          : _l10n.fractionBaseNumeric;
      semanticLabel = '$visualText. $base. ${_l10n.fractionSwitchToFraction}';
    }
    // Stabilní kompaktní výška i při vysokém systémovém zoomu: stejný
    // izolační vzor jako přepínač režimů (noScaling + ruční sysFactor
    // s horním stropem, aby se scaler nezapočítal dvakrát). Tlačítko má
    // vždy výšku danou minimumSize a neroztáhne layout na malém displeji.
    final sysFactor = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.6);
    final toggleFontSize = (13.0 * s * sysFactor).clamp(12.0, 16.0);
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: true,
      toggled: showing,
      onTap: toggleFractionResultView,
      child: ExcludeSemantics(
        child: TextButton(
          key: const ValueKey('fraction_toggle'),
          onPressed: toggleFractionResultView,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            foregroundColor: Colors.redAccent,
          ),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Text(
              visualText,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: toggleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Globální textový vstup do paměti: velké čitelné tlačítko „Paměť"
  // v hlavní pracovní ploše (nikoli v AppBaru, nikoli v 4×7 rastru
  // klávesnice). Sdílí fixní řádek s přepínačem režimů, takže nepřidává
  // ŽÁDNÝ nový vertikální řádek a neubírá místo displeji ani klávesnici
  // (geometrie 4×7 rastru a všech režimů zůstává beze změny).
  // Volá existující [_showQuickMemoryDialog], jehož hlavní obsah je přímo
  // mřížka A..M (Paměť → A bez mezikroku).
  // A11y: vlastní Semantics label (mimo kontejner „Přepínač režimů"),
  // focus order displej → fraction → Paměť → režimy → klávesnice.
  // buildButton řeší dark mode, velké písmo (sysFactor clamp + noScaling
  // + FittedBox) i TalkBack/NVDA bez duplicitních oznámení.
  // Stojí PŘED scrollovatelnými chipy jako fixní prvek – chipe zůstává
  // horizontálně scrollovatelný i na úzkých displejích.
  Widget _buildMemoryAndModeRow() {
    final scale = _responsiveScale(context);
    return Row(
      children: [
        Container(
          margin: EdgeInsets.only(
            left: 4 * scale,
            top: 4 * scale,
            bottom: 4 * scale,
          ),
          child: SizedBox(
            key: const ValueKey('memory_entry_button'),
            height: 48 * scale,
            width: 132 * scale,
            child: buildButton(
              _l10n.sectionMemory,
              semanticLabel: _s(
                'Paměť, otevře paměťové proměnné A až M',
                'Memory, opens memory variables A to M',
              ),
              color: Colors.teal,
              onPressed: _showQuickMemoryDialog,
              expanded: false,
            ),
          ),
        ),
        Expanded(child: _buildModeSelector()),
      ],
    );
  }

  void _changeMode(CalculatorMode mode) {
    setState(() {
      _currentMode = mode;
      display = '';
      _cursorPosition = 0;
      _scientificFunctionsPage = false;
      _scientificPageAnnouncement = null;
      // Rozpracované STO/RCL nesmí přežít změnu režimu: cílová proměnná
      // by se jinak vybrala v jiném kontextu, než kde byl záměr potvrzen.
      // Zrušení je tiché – změna režimu má vlastní hlasové potvrzení
      // a clear() flagy resetuje stejně.
      _isStoreMode = false;
      _isRecallMode = false;
    });
    _modeUsageCounts[mode.index]++;
    _totalModeSwitches++;
    _saveModeUsage();
    _maybeSuggestFavoriteMode();
    String speech = _l10n.switchedToMode(_getModeSpeechName(mode));
    speech += _statsModeAnnouncement();
    // R7: jedna navigační hláška jednotným kanálem. Při aktivní čtečce
    // se dříve neoznámilo nic (speak mlčel a liveRegion se nezměnil).
    unawaited(
      announceEvent(
        speech,
        category: SpeechCategory.navigation,
        interruptCurrentSpeech: true,
      ),
    );
  }

  String _statsModeAnnouncement() {
    if (_currentMode != CalculatorMode.statistics) return '';
    if (!_hasStatsSet) {
      return '. ' +
          _s(
            'Zatím nemáte vytvořenou žádnou statistickou sadu. Vytvořte ji stisknutím tlačítka SETS.',
            'You have no statistical sets created yet. Create one by pressing the SETS button.',
          );
    } else if (_statsMemory.isEmpty) {
      final setName = _statsSets[_currentStatsSetIndex].name;
      return '. ' +
          _s(
            'Aktivní sada "$setName" je prázdná. Přidejte data pomocí tlačítka M plus.',
            'The active set "$setName" is empty. Add data using the M+ button.',
          );
    } else {
      final set = _statsSets[_currentStatsSetIndex];
      final count = _statsMemory.length;
      final countForm = _getStatsCountForm(count);
      final fieldsLabel = set.fieldNames
          .asMap()
          .entries
          .map((e) {
            final unitCode = e.key < set.fieldUnits.length
                ? set.fieldUnits[e.key]
                : null;
            return unitCode != null
                ? '${e.value}, ${_getUnitSpeech(unitCode)}'
                : e.value;
          })
          .join(', ');
      return '. ' +
          _s(
            'Aktivní sada "${set.name}" obsahuje $count $countForm. Pole: $fieldsLabel.',
            'The active set "${set.name}" contains $count $countForm. Fields: $fieldsLabel.',
          );
    }
  }

  void _cycleMode(int direction) {
    final values = CalculatorMode.values;
    final currentIndex = values.indexOf(_currentMode);
    final newIndex = (currentIndex + direction) % values.length;
    _changeMode(values[newIndex]);
  }

  void _maybeSuggestFavoriteMode() {
    if (!mounted || _totalModeSwitches < 20) {
      return;
    }

    int topIndex = 0;
    for (var i = 1; i < _modeUsageCounts.length; i++) {
      if (_modeUsageCounts[i] > _modeUsageCounts[topIndex]) {
        topIndex = i;
      }
    }

    final topCount = _modeUsageCounts[topIndex];
    if (topIndex == _defaultMode.index || topCount <= 0) {
      return;
    }

    final sortedCounts = List<int>.from(_modeUsageCounts)
      ..sort((a, b) => b.compareTo(a));
    final secondCount = sortedCounts.length > 1 ? sortedCounts[1] : 0;

    final clearlyAhead =
        topCount >= (_totalModeSwitches * 0.4) && topCount >= secondCount * 2;

    if (!clearlyAhead || _lastSuggestedMode == topIndex) {
      return;
    }

    _showFavoriteModeSuggestionDialog(CalculatorMode.values[topIndex]);
  }

  void _showFavoriteModeSuggestionDialog(CalculatorMode mode) {
    final modeName = _getModeName(mode);
    _saveSuggestedMode(mode.index);
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Nejpoužívanější režim'),
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(_s('Nejpoužívanější režim', 'Most used mode')),
        ),
        content: Text(
          _s(
            'Nejvíce používáte režim $modeName.\nChcete ho nastavit jako výchozí režim po spuštění?',
            'You most often use the $modeName.\nDo you want to set it as the default mode on startup?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _saveSuggestedMode(mode.index);
            },
            child: Text(_s('Ne', 'No')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _setDefaultMode(mode);
              speak(
                _s(
                  'Výchozí režim nastaven na $modeName',
                  'Default mode set to $modeName',
                ),
              );
            },
            child: Text(_s('Ano, nastavit', 'Yes, set it')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadGlobalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDegreeMode = prefs.getBool('isDegreeMode') ?? true;
      final savedDefaultMode = prefs.getInt('defaultMode');
      if (savedDefaultMode != null &&
          savedDefaultMode >= 0 &&
          savedDefaultMode < CalculatorMode.values.length) {
        _defaultMode = CalculatorMode.values[savedDefaultMode];
        _currentMode = _defaultMode;
      }
      final savedUsageJson = prefs.getString('modeUsageCounts');
      if (savedUsageJson != null) {
        try {
          final counts = (jsonDecode(savedUsageJson) as List<dynamic>)
              .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
              .toList();
          while (counts.length < CalculatorMode.values.length) {
            counts.add(0);
          }
          _modeUsageCounts = List<int>.from(
            counts.sublist(0, CalculatorMode.values.length),
          );
        } catch (e) {
          _modeUsageCounts = List<int>.filled(CalculatorMode.values.length, 0);
        }
      }
      _totalModeSwitches = _modeUsageCounts.fold(0, (a, b) => a + b);
      _lastSeenNewsVersion = prefs.getString('lastSeenNewsVersion');
      final savedSuggestedMode = prefs.getInt('lastSuggestedMode');
      if (savedSuggestedMode != null &&
          savedSuggestedMode >= 0 &&
          savedSuggestedMode < CalculatorMode.values.length) {
        _lastSuggestedMode = savedSuggestedMode;
      }
      _devModeEnabled = prefs.getBool('devModeEnabled') ?? false;
      _devAutoDiagnosticEnabled =
          prefs.getBool('devAutoDiagnosticEnabled') ?? false;
      _devDiagnosticDurationMs =
          (prefs.getInt('devDiagnosticDurationMs') ?? 700).clamp(200, 3000);
      _devPinCode = prefs.getString('devPinCode');
      // Pořadí statistického souhrnu
      final orderList = prefs.getStringList('statsSummaryOrder');
      if (orderList != null && orderList.isNotEmpty) {
        final parsed = <StatsSummarySection>[];
        for (final s in orderList) {
          for (final v in StatsSummarySection.values) {
            if (v.name == s) {
              parsed.add(v);
              break;
            }
          }
        }
        if (parsed.length == StatsSummarySection.values.length &&
            parsed.toSet().length == parsed.length) {
          _statsSummaryOrder = parsed;
        }
      }
      // Pořadí položek uvnitř Vypočtené statistiky
      final computedOrderList = prefs.getStringList('statsComputedOrder');
      if (computedOrderList != null && computedOrderList.isNotEmpty) {
        final parsed = <StatsComputedItem>[];
        for (final s in computedOrderList) {
          for (final v in StatsComputedItem.values) {
            if (v.name == s) {
              parsed.add(v);
              break;
            }
          }
        }
        if (parsed.length == StatsComputedItem.values.length &&
            parsed.toSet().length == parsed.length) {
          _statsComputedOrder = parsed;
        }
      }
      // Měna
      final currencyJson = prefs.getString('currencyRates');
      if (currencyJson != null) {
        try {
          final Map<String, dynamic> decoded =
              jsonDecode(currencyJson) as Map<String, dynamic>;
          final map = <String, double>{};
          decoded.forEach((k, v) => map[k] = (v as num).toDouble());
          if (map.containsKey('CZK')) _currencyRates = map;
        } catch (_) {}
      }
      _globalResultDisplayMode = _resultDisplayModeFromString(
        prefs.getString('resultDisplayMode'),
      );
      _historyExactFormat = _historyExactFormatFromString(
        prefs.getString('historyExactFormat'),
      );
      _currencyFrom = prefs.getString('currencyFrom') ?? 'CZK';
      _currencyTo = prefs.getString('currencyTo') ?? 'EUR';
      if (!_currencyRates.containsKey(_currencyFrom)) _currencyFrom = 'CZK';
      if (!_currencyRates.containsKey(_currencyTo)) _currencyTo = 'EUR';
      final currencyDateStr = prefs.getString('currencyLastUpdate');
      if (currencyDateStr != null)
        _currencyLastUpdate = DateTime.tryParse(currencyDateStr);
    });
    _dialogFontScaleNotifier.value = _dialogFontScale;
    try {
      await tts.setSpeechRate(_speechRate);
    } catch (e) {
      debugPrint('TTS setSpeechRate Error: $e');
    }
    try {
      await tts.setVolume(_speechVolume);
    } catch (e) {
      debugPrint('TTS setVolume Error: $e');
    }
    if (!Platform.isWindows && _ttsEngine != null) {
      try {
        await tts.setEngine(_ttsEngine!);
      } catch (e) {
        debugPrint('TTS setEngine Error: $e');
      }
    }
    if (_ttsVoice != null) {
      try {
        await tts.setVoice(_ttsVoice!);
      } catch (e) {
        debugPrint('TTS setVoice Error: $e');
      }
    }
    try {
      await tts.setQueueMode(0);
    } catch (e) {
      debugPrint('TTS setQueueMode Error: $e');
    }
    if (mounted) _maybeRunDevAutodiagnostics();
  }

  Future<void> _saveGlobalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDegreeMode', _isDegreeMode);
    await prefs.setString(
      'resultDisplayMode',
      _resultDisplayModeToString(_globalResultDisplayMode),
    );
    await prefs.setString(
      'historyExactFormat',
      _historyExactFormatToString(_historyExactFormat),
    );
    await prefs.setInt('defaultMode', _defaultMode.index);
    await prefs.setBool('devModeEnabled', _devModeEnabled);
    await prefs.setBool('devAutoDiagnosticEnabled', _devAutoDiagnosticEnabled);
    await prefs.setInt('devDiagnosticDurationMs', _devDiagnosticDurationMs);
    if (_devPinCode != null) {
      await prefs.setString('devPinCode', _devPinCode!);
    } else {
      await prefs.remove('devPinCode');
    }
    await prefs.setString('currencyRates', jsonEncode(_currencyRates));
    await prefs.setString('currencyFrom', _currencyFrom);
    await prefs.setString('currencyTo', _currencyTo);
    if (_currencyLastUpdate != null) {
      await prefs.setString(
        'currencyLastUpdate',
        _currencyLastUpdate!.toIso8601String(),
      );
    }
    await prefs.setStringList(
      'statsSummaryOrder',
      _statsSummaryOrder.map((e) => e.name).toList(),
    );
    await prefs.setStringList(
      'statsComputedOrder',
      _statsComputedOrder.map((e) => e.name).toList(),
    );
  }

  // Drží alias pro staré volání – nyní ukládá jen globál (per-profile už řeší _saveProfilesV2).
  // Rychlé toggly mimo Apply: vědomě neblokují UI, Apply/commit cesty
  // vždy awaitují _saveGlobalSettings()/persistCanonicalContract přímo.
  void _saveSettings() {
    unawaited(_saveGlobalSettings());
  }

  /// Lokalizovaný zobrazovaný název profilu (built-in via l10n, custom via name)
  String _displayProfileName(AccessibilityProfile p) {
    if (p.isBuiltIn) {
      switch (p.id) {
        case 'standard':
          return _l10n.profileStandard;
        case 'blind':
          return _l10n.profileBlind;
        case 'lowvision':
          return _l10n.profileLowVision;
      }
    }
    return p.name;
  }

  /// Lokalizovaný název profilu přístupnosti (legacy).
  String _accessibilityProfileName(AccessibilityType profile) {
    switch (profile) {
      case AccessibilityType.blind:
        return _l10n.profileBlind;
      case AccessibilityType.visuallyImpaired:
        return _l10n.profileLowVision;
      case AccessibilityType.none:
        return _l10n.profileLowVision;
    }
  }

  /// Jediný zdroj výchozích profilů přístupnosti.
  /// Vyžaduje dostupné `_l10n` (tj. kontext s lokalizací).
  List<AccessibilityProfile> _defaultAccessibilityProfiles() {
    return [
      AccessibilityProfile(
        id: 'standard',
        name: _l10n.profileStandard,
        isBuiltIn: true,
        settings: AccessibilitySettings.defaultsStandard(),
      ),
      AccessibilityProfile(
        id: 'blind',
        name: _l10n.profileBlind,
        isBuiltIn: true,
        settings: AccessibilitySettings.defaultsBlind(),
      ),
      AccessibilityProfile(
        id: 'lowvision',
        name: _l10n.profileLowVision,
        isBuiltIn: true,
        settings: AccessibilitySettings.defaultsLowVision(),
      ),
    ];
  }

  /// Syntetický nouzový profil pro situace, kdy ještě není dostupné ani
  /// `_l10n` (např. úplně první build). Nikdy nevyhodí výjimku.
  AccessibilityProfile _fallbackStandardProfile() {
    String name;
    try {
      name = _l10n.profileStandard;
    } catch (_) {
      name = _isEnglish() ? 'Standard' : 'Standardní';
    }
    return AccessibilityProfile(
      id: 'standard',
      name: name,
      isBuiltIn: true,
      settings: AccessibilitySettings.defaultsStandard(),
    );
  }

  /// Bezpečný seznam profilů pro vykreslení dialogu.
  /// Když `_profiles` ještě nejsou načtené nebo jsou prázdné,
  /// vrátí výchozí profily — nikdy prázdný seznam.
  List<AccessibilityProfile> get _effectiveProfiles {
    if (_profiles.isNotEmpty) return _profiles;
    try {
      final defaults = _defaultAccessibilityProfiles();
      if (defaults.isNotEmpty) return defaults;
    } catch (_) {}
    return [_fallbackStandardProfile()];
  }

  Future<void> _saveProfilesV2() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'accessibility_profiles_v2',
      jsonEncode(_profiles.map((p) => p.toJson()).toList()),
    );
    await prefs.setString('activeProfileId', _activeProfileId);
  }

  Future<void> _saveActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeProfileId', _activeProfileId);
  }

  Future<void> _loadProfilesV2() async {
    List<AccessibilityProfile>? loaded;
    String? loadedActiveId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('accessibility_profiles_v2');
      loadedActiveId = prefs.getString('activeProfileId');
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final parsed = <AccessibilityProfile>[];
          for (final item in decoded) {
            try {
              final map = item is Map<String, dynamic>
                  ? item
                  : item is Map
                  ? Map<String, dynamic>.from(item)
                  : null;
              if (map == null) continue;
              final profile = AccessibilityProfile.fromJson(map);
              if (profile.id.isEmpty) continue;
              // ensure built-in flag for known ids
              final isBuiltIn =
                  profile.id == 'standard' ||
                  profile.id == 'blind' ||
                  profile.id == 'lowvision';
              parsed.add(
                AccessibilityProfile(
                  id: profile.id,
                  name: profile.name,
                  isBuiltIn: isBuiltIn ? true : profile.isBuiltIn,
                  settings: profile.settings,
                ),
              );
            } catch (_) {
              continue;
            }
          }
          if (parsed.isNotEmpty) loaded = parsed;
        }
      }
    } catch (_) {
      loaded = null;
    }
    if (loaded != null && loaded.isNotEmpty) {
      _profiles = loaded;
      if (loadedActiveId != null && loaded.any((p) => p.id == loadedActiveId)) {
        _activeProfileId = loadedActiveId;
      } else if (!_profiles.any((p) => p.id == _activeProfileId)) {
        _activeProfileId = _profiles.first.id;
      }
    } else {
      try {
        _profiles = _defaultAccessibilityProfiles();
      } catch (_) {
        _profiles = [_fallbackStandardProfile()];
      }
      _activeProfileId = _profiles.first.id;
      try {
        await _saveProfilesV2();
      } catch (_) {}
    }
    // cleanup starých klíčů (neglobálních)
    try {
      final prefs = await SharedPreferences.getInstance();
      const oldKeys = [
        'accessibilityType',
        'keyboardFontScale',
        'fontSizeMultiplier',
        'dotMatrixZoom',
        'resultZoom',
        'thousandGroupGap',
        'overlineThickness',
        'overlineHeight',
        'alignInputLeft',
        'dialogFontScale',
        'ttsEnabled',
        'usePeriodicNotation',
        'useSixteenSegment',
        'announceExpression',
        'readStatsMemoryValues',
        'autoReadStatsSummary',
        'showStatsNavigationHint',
        'screenReaderModeState',
        'screenReaderMode',
        'dialogSize',
        'speechRate',
        'speechVolume',
        'ttsEngine',
        'ttsVoice',
        'inverseFormatPreference',
        'accessibility_profiles',
      ];
      for (final k in oldKeys) {
        if (prefs.containsKey(k) && k != 'activeProfileId') {
          // activeProfileId zůstává jako nová perzistence, ostatní mažeme jen pokud je v2 již uložen
        }
      }
      // Po úspěšném vytvoření v2 smaž staré a11y per-profile klíče (ponech activeProfileId)
      if (loaded == null) {
        for (final k in oldKeys) {
          if (k == 'activeProfileId') continue;
          await prefs.remove(k);
        }
      }
    } catch (_) {}
    _profilesLoaded = true;
    // Jednorázová bezpečná migrace ResultDisplayMode z profilů do globálu:
    // pouze pokud globál ještě neexistuje; staré hodnoty v profilech
    // globální stav nikdy nepřepisují. Opakovatelná, bez ztráty dat.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('resultDisplayMode')) {
        var seeded = ResultDisplayMode.segment;
        for (final p in _profiles) {
          if (p.id == _activeProfileId &&
              p.settings.resultDisplayMode != ResultDisplayMode.segment) {
            seeded = p.settings.resultDisplayMode;
            break;
          }
        }
        // Pokud aktivní profil nemá non-segment, hledej napříč profily.
        if (seeded == ResultDisplayMode.segment) {
          for (final p in _profiles) {
            if (p.settings.resultDisplayMode != ResultDisplayMode.segment) {
              seeded = p.settings.resultDisplayMode;
              break;
            }
          }
        }
        _globalResultDisplayMode = seeded;
        await prefs.setString(
          'resultDisplayMode',
          _resultDisplayModeToString(seeded),
        );
      }
    } catch (_) {}
    _applyActiveProfileToState();
    if (mounted) setState(() {});
    // aplikovat TTS
    try {
      final s = activeAccessibilitySettings;
      await tts.setSpeechRate(s.speechRate);
      await tts.setVolume(s.speechVolume);
      if (!Platform.isWindows && s.ttsEngine != null) {
        await tts.setEngine(s.ttsEngine!);
      }
      if (s.ttsVoice != null) {
        await tts.setVoice(s.ttsVoice!);
      } else {
        tts.clearVoice();
      }
      await tts.setQueueMode(0);
    } catch (e) {
      debugPrint('TTS apply after load Error: $e');
    }
  }

  Future<void> applyAccessibilityProfile(
    AccessibilityProfile profile, {
    String? announcement,
  }) async {
    if (!_profiles.any((p) => p.id == profile.id)) {
      debugPrint('applyAccessibilityProfile: id not found: ${profile.id}');
      _showAccessibleSnackBar(
        _s(
          'Aktivace selhala – profil neexistuje.',
          'Activation failed – profile does not exist.',
        ),
      );
      return;
    }
    setState(() {
      _activeProfileId = profile.id;
    });
    _applyActiveProfileToState();
    final s = activeAccessibilitySettings;
    try {
      await tts.setSpeechRate(s.speechRate);
    } catch (e) {
      debugPrint('TTS setSpeechRate Error: $e');
    }
    try {
      await tts.setVolume(s.speechVolume);
    } catch (e) {
      debugPrint('TTS setVolume Error: $e');
    }
    if (!Platform.isWindows && s.ttsEngine != null) {
      try {
        await tts.setEngine(s.ttsEngine!);
      } catch (e) {
        debugPrint('TTS setEngine Error: $e');
      }
    }
    if (s.ttsVoice != null) {
      try {
        await tts.setVoice(s.ttsVoice!);
      } catch (e) {
        debugPrint('TTS setVoice Error: $e');
      }
    } else {
      tts.clearVoice();
    }
    if (s.accessibilityType == AccessibilityType.visuallyImpaired) {
      widget.onThemeModeChanged(ThemeMode.dark);
    }
    await _saveActiveProfileId();
    if (announcement != null && announcement.isNotEmpty && mounted) {
      // R9: oznamuje pouze SnackBar jednotným kanálem
      // (dříve speak(force) + announce = duplicita při SR).
      _showAccessibleSnackBar(announcement);
    }
    if (mounted) setState(() {});
  }

  void _showProfilePreviewDialog(AccessibilityProfile profile) {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Náhled nastavení'),
      builder: (ctx) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(_l10n.previewSettings)),
        content: Text(
          'Profil: ${profile.name}\n\n' +
              _s('Použít profil?', 'Apply profile?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              applyAccessibilityProfile(
                profile,
                announcement: _l10n.profileChangedTo(profile.name),
              );
            },
            child: Text(_l10n.confirmAction),
          ),
        ],
      ),
    );
  }

  void _showSaveProfileDialog() {
    // legacy – drženo pro zpětnou kompatibilitu, nyní se ukládá automaticky per-profile
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Uložit profil'),
      builder: (ctx) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(_l10n.saveSettingsToProfile),
        ),
        content: Text(
          _s(
            'Nastavení se nyní ukládá automaticky pro každý profil zvlášť.',
            'Settings are now saved automatically per profile.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.close),
          ),
        ],
      ),
    );
  }

  void _showCreateProfileDialog() {
    final nameCtrl = TextEditingController();
    String baseId = _activeProfileId;
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Vytvořit profil'),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sCtx, setLocal) {
            return AlertDialog(
              scrollable: false,
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(_s('Nový profil', 'New profile')),
              ),
              content: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: _s('Název nového profilu', 'New profile name'),
                    child: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: _s('Název', 'Name'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: _s('Základní profil pro kopii', 'Base profile'),
                    child: DropdownButtonFormField<String>(
                      value: baseId,
                      decoration: InputDecoration(
                        labelText: _s('Vycházet z', 'Base on'),
                      ),
                      items: _effectiveProfiles
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(_displayProfileName(p)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => baseId = v);
                      },
                    ),
                  ),
                ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      speak(_s('Zadejte název profilu', 'Enter profile name'));
                      return;
                    }
                    if (_profiles.any(
                      (p) => p.name.toLowerCase() == name.toLowerCase(),
                    )) {
                      speak(
                        _s(
                          'Profil s tímto názvem již existuje',
                          'Profile with this name already exists',
                        ),
                      );
                      return;
                    }
                    final base = _profiles.firstWhere(
                      (p) => p.id == baseId,
                      orElse: () => _getActiveAccessibilityProfile(),
                    );
                    final newProfile = AccessibilityProfile(
                      id: 'custom_${DateTime.now().microsecondsSinceEpoch}_${name.hashCode.abs()}',
                      name: name,
                      isBuiltIn: false,
                      settings: base.settings.copyWith(),
                    );
                    setState(() {
                      _profiles.add(newProfile);
                      _activeProfileId = newProfile.id;
                    });
                    _applyActiveProfileToState();
                    _saveProfilesV2();
                    Navigator.pop(ctx);
                    // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
                    _showAccessibleSnackBar(
                      _s('Profil $name vytvořen', 'Profile $name created'),
                    );
                  },
                  child: Text(_s('Vytvořit', 'Create')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Legacy wrappers – deprecated, delegují na per-ID varianty
  @Deprecated('Use _showRenameProfileDialogForId instead')
  void _showRenameProfileDialog() {
    _showRenameProfileDialogForId(_activeProfileId);
  }

  @Deprecated('Use _confirmResetProfileForId instead')
  void _confirmResetActiveProfile(BuildContext dialogContext) {
    _confirmResetProfileForId(dialogContext, _activeProfileId);
  }

  @Deprecated('Use resetProfile instead')
  void _resetActiveProfile() {
    final active = _getActiveAccessibilityProfile();
    resetProfile(active.id);
    final name = _displayProfileName(active);
    // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
    _showAccessibleSnackBar(_s('Profil $name obnoven', 'Profile $name reset'));
  }

  @Deprecated('Use _confirmDeleteProfileForId instead')
  void _confirmDeleteActiveProfile(BuildContext dialogContext) {
    _confirmDeleteProfileForId(
      dialogContext,
      _activeProfileId,
      parentDialogContext: dialogContext,
    );
  }

  // Nové: operace nad libovolným id (výběr ≠ aktivace)
  void _confirmResetProfileForId(BuildContext dialogContext, String id) {
    final profile = _profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => _getActiveAccessibilityProfile(),
    );
    final displayName = _displayProfileName(profile);
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Reset profilu'),
      builder: (ctx) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(_s('Obnovit výchozí', 'Reset')),
        ),
        content: Text(
          _s(
            'Opravdu obnovit profil $displayName na výchozí hodnoty?',
            'Reset profile $displayName to defaults?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              resetProfile(id);
              if (mounted) setState(() {});
            },
            child: Text(_s('Obnovit', 'Reset')),
          ),
        ],
      ),
    );
  }

  void _showRenameProfileDialogForId(String id) {
    final profile = _profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => _getActiveAccessibilityProfile(),
    );
    if (profile.isBuiltIn) return;
    final ctrl = TextEditingController(text: profile.name);
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Přejmenovat profil'),
      builder: (ctx) => AlertDialog(
        scrollable: false,
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(_s('Přejmenovat profil', 'Rename profile')),
        ),
        content: SingleChildScrollView(
          child: Semantics(
          label: _s('Nový název profilu', 'New profile name'),
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _s('Název', 'Name'),
              border: const OutlineInputBorder(),
            ),
          ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              renameProfile(id, newName);
              Navigator.pop(ctx);
              speak(
                _s(
                  'Profil přejmenován na $newName',
                  'Profile renamed to $newName',
                ),
              );
            },
            child: Text(_l10n.confirmAction),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProfileForId(
    BuildContext dialogContext,
    String id, {
    required BuildContext parentDialogContext,
  }) {
    final profile = _profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => _getActiveAccessibilityProfile(),
    );
    if (profile.isBuiltIn) return;
    final name = _displayProfileName(profile);
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Smazat profil'),
      builder: (ctx) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(_s('Smazat profil', 'Delete profile')),
        ),
        content: Text(
          _s('Opravdu smazat profil $name?', 'Really delete profile $name?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(parentDialogContext);
              _deleteProfile(id);
            },
            child: Text(_s('Smazat', 'Delete')),
          ),
        ],
      ),
    );
  }

  void _deleteProfile(String id) {
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    if (_profiles[idx].isBuiltIn) return;
    final wasActive = _activeProfileId == id;
    setState(() {
      _profiles.removeAt(idx);
      if (wasActive) {
        _activeProfileId = 'standard';
        _applyActiveProfileToState();
      }
    });
    _saveProfilesV2();
    // aplikovat TTS pro nový aktivní
    final s = activeAccessibilitySettings;
    tts.setSpeechRate(s.speechRate);
    tts.setVolume(s.speechVolume);
    if (s.ttsVoice != null) {
      tts.setVoice(s.ttsVoice!);
    } else {
      tts.clearVoice();
    }
    speak(_s('Profil smazán', 'Profile deleted'));
  }

  void _setDefaultMode(CalculatorMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultMode', mode.index);
    setState(() => _defaultMode = mode);
  }

  Future<void> _saveModeUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('modeUsageCounts', jsonEncode(_modeUsageCounts));
  }

  Future<void> _markNewsSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSeenNewsVersion', version);
    _lastSeenNewsVersion = version;
  }

  Future<void> _saveSuggestedMode(int modeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSuggestedMode', modeIndex);
    _lastSuggestedMode = modeIndex;
  }

  void _saveInversePreference(int val) async {
    updateActiveAccessibilitySettings(
      (s) => s.copyWith(inverseFormatPreference: val),
    );
  }

  Widget _wrapWithDialogFontScale(BuildContext ctx, Widget dialog) {
    // Okamžitý náhled: sleduje _dialogFontScaleNotifier, aby se otevřený dialog překreslil živě
    return ValueListenableBuilder<double>(
      valueListenable: _dialogFontScaleNotifier,
      builder: (context, scaleValue, _) {
        final sys = MediaQuery.textScalerOf(ctx);
        final sysFactor = sys.scale(1.0);
        final combined = (sysFactor * scaleValue).clamp(0.5, 3.5);
        final scaled = MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(combined)),
          child: dialog,
        );
        if (_dialogSize == DialogSize.fullscreen) {
          // Záměrně BEZ Dialog.fullscreen: vnořený Dialog v Dialogu by
          // zdvojil surface i viewInsets handling a TalkBack by ohlásil
          // dva dialogy. Jediným vlastníkem keyboard insetu zůstává
          // vnitřní AlertDialog; fullscreen význam (vyplnit obrazovku)
          // zajišťuje tight layout bez dalšího Dialogu.
          return SizedBox.expand(child: scaled);
        }
        return scaled;
      },
    );
  }

  Future<T?> showAppDialog<T>({
    required BuildContext context,
    bool barrierDismissible = true,
    RouteSettings? routeSettings,
    required WidgetBuilder builder,
  }) {
    // Z1: otevření dialogu vypíná režim ovládání výrazu (jediný škrticí
    // bod všech dialogů). Návrat fokusu po zavření jej zpětně nezapíná —
    // vyžaduje se výslovná aktivace displeje nebo reaktivace šipkou až po
    // úplném zavření (viz [_tryReactivateExpressionControl]). Důvod `dialog`
    // se zde zapisuje dřív, než route přesune fokus do dialogu, aby jej
    // listener nemohl přepsat traversálovým. Čítač kryje i vnořené dialogy.
    _expressionControlActive = false;
    _expressionControlOffReason = _ExpressionControlOffReason.dialog;
    _dialogDepth++;
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      requestFocus: true,
      // useSafeArea ponecháno na defaultu (true): o odsazení od klávesnice
      // se stará výhradně frameworkový Dialog/AlertDialog
      // (viewInsets + insetPadding). Aplikační kód viewInsets nikdy
      // znovu neodečítá, aby nedošlo k dvojímu zmenšení dialogu
      // a jeho „vystřelení" k hornímu okraji.
      routeSettings: routeSettings,
      builder: (dialogContext) =>
          _wrapWithDialogFontScale(dialogContext, builder(dialogContext)),
    ).whenComplete(() {
      // Dialog (i vnořený) je pryč: reaktivace je opět dovolena, jakmile se
      // primární fokus skutečně vrátí do kalkulačky. Samotné zavření režim
      // nezapíná. Prostý čítač bez setState — žádný rebuild, žádný cyklus.
      if (_dialogDepth > 0) _dialogDepth--;
    });
  }

  void _toggleTts() {
    final newVal = !ttsEnabled;
    updateActiveAccessibilitySettings((s) => s.copyWith(ttsEnabled: newVal));
    speak(newVal ? _l10n.voiceOn : _l10n.voiceOff);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('history') ?? [];
    final parsed = parseHistoryStrings(raw);
    if (mounted) {
      setState(() => _history = parsed);
    } else {
      _history = parsed;
    }
  }

  /// Společné načtení paměťových proměnných z prefs (synchronní, prefs
  /// přednačtené volajícím). Musí běžet uvnitř setState volajícího.
  /// Sdílí [_loadStatsData] (startup) i testovací hook pro reload —
  /// testuje se tedy stejný produkční kód, nikoli duplicitní logika.
  void _applyMemoryPrefs(SharedPreferences prefs) {
    _memory.updateAll((key, value) => 0);
    _memoryOccupied.clear();
    final memJson = prefs.getString('memoryVariables');
    if (memJson != null) {
      try {
        final decoded = jsonDecode(memJson) as Map<String, dynamic>;
        decoded.forEach(
          (key, value) => _memory[key] = (value as num).toDouble(),
        );
      } catch (_) {}
    }
    // Evidence obsazenosti (nový klíč 'memoryOccupied', zpětně kompatibilní).
    // Pravidla: berou se pouze známé názvy proměnných; každá známá proměnná
    // s nenulovou číselnou hodnotou se považuje za obsazenou vždy (pojistka
    // proti nekonzistenci dvou klíčů); u nulových hodnot respektujeme uložený
    // údaj. Chybí-li klíč úplně (stará data), obsazené = nenulové hodnoty;
    // historicky uložená nula je pak nerozlišitelná od prázdné (neopravitelné,
    // viz release notes) — číselné hodnoty zůstávají zachovány.
    try {
      final occList = prefs.getStringList('memoryOccupied');
      if (occList != null) {
        for (final k in occList) {
          if (_memoryOrder.contains(k)) _memoryOccupied.add(k);
        }
      } else {
        // Migrace starých dat bez údaje o obsazenosti.
        for (final k in _memoryOrder) {
          if ((_memory[k] ?? 0) != 0) _memoryOccupied.add(k);
        }
      }
      // Pojistka: nenulová hodnota = obsazená, i kdyby údaj chyběl/neseděl.
      for (final k in _memoryOrder) {
        if ((_memory[k] ?? 0) != 0) _memoryOccupied.add(k);
      }
    } catch (_) {}
  }

  Future<void> _loadStatsData() async {
    final res = await StatsStorage.load();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _statsSets.clear();
      _statsSets.addAll(res.sets);
      _statsFolders.clear();
      _statsFolders.addAll(res.folders);
      _currentStatsSetIndex = res.currentIndex;
      // Bezpečné ošetření indexu
      if (_statsSets.isNotEmpty && _currentStatsSetIndex >= _statsSets.length) {
        _currentStatsSetIndex = 0;
      }
      _applyMemoryPrefs(prefs);
    });
  }

  /// Samostatný zápis paměťových proměnných (klíč 'memoryVariables').
  /// Formát dat se nemění. Oddělení od ukládání statistických sad znamená,
  /// že pomalé či visící file I/O statistiky nikdy neblokuje persistenci
  /// paměti – _saveStatsData() ji volá vždy jako první.
  /// Společně se zapisuje i evidence obsazenosti (klíč 'memoryOccupied',
  /// StringList známých jmen). Chyba jednoho zápisu neruší druhý.
  Future<void> _saveMemoryVariables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('memoryVariables', jsonEncode(_memory));
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final occ = _memoryOccupied
          .where((k) => _memoryOrder.contains(k))
          .toList()
        ..sort();
      await prefs.setStringList('memoryOccupied', occ);
    } catch (_) {}
  }

  void _saveStatsData() async {
    await _saveMemoryVariables();
    // Udržet updatedAt/lastUsedAt aktuální
    await StatsStorage.save(
      sets: _statsSets,
      folders: _statsFolders,
      currentIndex: _currentStatsSetIndex,
    );
  }

  void _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'history',
        _history.map((e) => e.toStorageString()).toList(),
      );
    } catch (_) {
      // Non-finite výsledek (Infinity/NaN, např. 5/0) nelze serializovat
      // do JSON – paměťová historie zůstává beze změny, přeskočí se pouze
      // persist. Matematika, formát ani obsah historie se nemění.
      debugPrint('_saveHistory skipped: non-encodable entry');
    }
  }

  void _addToHistory(
    String exp,
    String res, {
    SurdValue? exact,
    Rational? rational,
    double? numericValue,
  }) {
    setState(() {
      _history.insert(
        0,
        CalculationHistoryEntry.fromSurd(
          exp,
          res,
          surd: exact,
          rational: rational,
          numericValue: numericValue,
        ),
      );
      if (_history.length > 20) _history.removeLast();
    });
    _saveHistory();
  }

  /// Vizuální výsledek záznamu podle globálního ResultDisplayMode
  /// (jediná autorita pro aktivní vykreslování historie).
  /// Nové záznamy používají autoritativní e.exact / e.rational;
  /// trySurdFromExpression() pouze jako fallback pro starou historii
  /// (isLegacyExactUnknown). Racionální tvar se nikdy neodvozuje z double.
  /// _historyExactFormat je legacy persistovaný údaj a aktivní renderer
  /// ho nečte.
  String _historyDisplayResult(CalculationHistoryEntry e) {
    switch (_globalResultDisplayMode) {
      case ResultDisplayMode.segment:
        return e.numericResult;
      case ResultDisplayMode.text:
      case ResultDisplayMode.auto:
        final ex = e.exact;
        if (ex != null) return formatSurd(ex);
        final ra = e.rational;
        // Jmenovatel 1 se zobrazuje jako celé číslo, nikdy jako n/1
        // (Rational.toDisplayString to garantuje).
        if (ra != null) return ra.toDisplayString();
        if (e.isLegacyExactUnknown) {
          final fb = trySurdFromExpression(e.expression);
          if (fb != null) return formatSurd(fb);
        }
        return e.numericResult;
    }
  }

  Future<void> _exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {};
      for (final key in prefs.getKeys()) {
        data[key] = prefs.get(key);
      }
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/kalkulacka_zaloha.json');
      await file.writeAsString(jsonStr);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: _l10n.backupData),
      );

      // R4: jednotný kanál (dříve force-bypass přes SR).
      unawaited(
        announceEvent(
          _l10n.backupSuccess,
          category: SpeechCategory.actionConfirm,
          interruptCurrentSpeech: true,
        ),
      );
    } catch (e) {
      debugPrint('Chyba při vytváření zálohy: $e');
      unawaited(
        announceEvent(
          _l10n.backupError,
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      String content;
      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        final bytes = await file.readAsBytes();
        content = utf8.decode(bytes);
      }

      final data = jsonDecode(content) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      for (final entry in data.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is List) {
          await prefs.setStringList(
            entry.key,
            value.map((e) => e.toString()).toList(),
          );
        }
      }

      _loadGlobalSettings();
      _loadProfilesV2();
      _loadHistory();
      _loadStatsData();
      setState(() {});
      // R4: jednotný kanál (dříve force-bypass přes SR).
      unawaited(
        announceEvent(
          _l10n.restoreSuccess,
          category: SpeechCategory.actionConfirm,
          interruptCurrentSpeech: true,
        ),
      );
    } catch (e) {
      debugPrint('Chyba při obnově dat: $e');
      unawaited(
        announceEvent(
          _l10n.restoreError,
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
    }
  }

  // --- Kontrakt v1: import/export (konfigurator) ---
  Future<void> _exportContract() async {
    try {
      final contract = buildContractJson(
        profiles: _profiles.isNotEmpty ? _profiles : _effectiveProfiles,
        activeProfileId: _activeProfileId,
        themeMode: widget.themeMode,
        isDegreeMode: _isDegreeMode,
        resultDisplayMode: _globalResultDisplayMode,
        historyExactFormat: _historyExactFormat,
        defaultMode: _defaultMode,
        statsSummaryOrder: _statsSummaryOrder,
        statsComputedOrder: _statsComputedOrder,
        currencyFrom: _currencyFrom,
        currencyTo: _currencyTo,
        devEnabled: _devModeEnabled,
        devAutoDiagnostic: _devAutoDiagnosticEnabled,
        devDiagnosticDurationMs: _devDiagnosticDurationMs,
        devPinCode: _devPinCode,
      );
      await _exportContractFile(contract);
      final msg = _s('Konfigurace exportována', 'Configuration exported');
      // R9: oznamuje pouze SnackBar (dříve speak(force) + announce + snackbar).
      if (mounted) {
        _showAccessibleSnackBar(msg);
      }
    } catch (e) {
      debugPrint('Export kontraktu chyba: $e');
      final msg = _s(
        'Chyba při exportu konfigurace',
        'Error exporting configuration',
      );
      // R9: oznamuje pouze SnackBar (dříve speak(force) + snackbar).
      if (mounted) _showAccessibleSnackBar(msg);
    }
  }

  Future<void> _importContract() async {
    try {
      final raw = await _pickAndReadContractFile();
      if (raw == null) return;
      final vr = validateContract(raw);
      if (!vr.ok) {
        final msgs = vr.errors
            .map((e) => '${e.path.isEmpty ? "root" : e.path}: ${e.message}')
            .join('\n');
        if (mounted) {
          await showAppDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(
                  _s('Neplatná konfigurace', 'Invalid configuration'),
                ),
              ),
              content: SingleChildScrollView(child: Text(msgs)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.close),
                ),
              ],
            ),
          );
        }
        // R4: jednotný kanál (dříve force-bypass přes SR).
        unawaited(
          announceEvent(
            _s(
              'Import selhal – neplatná konfigurace',
              'Import failed – invalid configuration',
            ),
            category: SpeechCategory.error,
            interruptCurrentSpeech: true,
          ),
        );
        return;
      }
      if (vr.warnings.isNotEmpty && mounted) {
        final warns = vr.warnings
            .map((w) => '${w.path}: ${w.message}')
            .join('\n');
        final proceed = await showAppDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            insetPadding: _dialogInsetPadding(),
            title: Semantics(
              header: true,
              child: Text(_s('Varování při importu', 'Import warning')),
            ),
            content: SingleChildScrollView(
              child: Text(
                _s(
                  'Konfigurace obsahuje neznámá pole (budoucí verze), budou ignorována:\n\n$warns\n\nPokračovat?',
                  'Configuration contains unknown keys (future version), they will be ignored:\n\n$warns\n\nContinue?',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_s('Importovat', 'Import')),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
      final parsed = parseContract(raw);
      await _applyContract(parsed, raw);
      final resolved =
          parsed.profiles
              .where((p) => p.id == parsed.activeProfileId)
              .isNotEmpty
          ? parsed.profiles.firstWhere((p) => p.id == parsed.activeProfileId)
          : parsed.profiles.first;
      final name = resolved.name;
      final msg = _s(
        'Konfigurace importována, aktivní profil $name',
        'Configuration imported, active profile $name',
      );
      // R9: oznamuje pouze SnackBar (dříve speak(force) + 2× announce).
      if (mounted) {
        _showAccessibleSnackBar(msg, announceMessage: msg);
      }
    } catch (e) {
      debugPrint('Import kontraktu chyba: $e');
      final msg = _s(
        'Chyba při importu konfigurace',
        'Error importing configuration',
      );
      // R9: oznamuje pouze SnackBar (dříve speak(force) + snackbar).
      if (mounted) _showAccessibleSnackBar(msg);
    }
  }

  /// Aplikace importovaného kontraktu přes testovatelnou ConfigStore vrstvu.
  /// Neznámý hlas nikdy nezpůsobí failure celého importu (fallback).
  /// Při chybě persistu se runtime NESMÍ změnit (volající zobrazí chybu).
  Future<void> _applyContract(
    ParsedContract parsed,
    Map<String, dynamic> raw,
  ) async {
    // Voice tolerance: vyřeš hlas aktivního profilu proti dostupným hlasům.
    var profiles = parsed.profiles;
    try {
      final available = await _loadAvailableVoices();
      final idx = profiles.indexWhere((p) => p.id == parsed.activeProfileId);
      if (idx != -1) {
        final requested = profiles[idx].settings.ttsVoice;
        if (requested != null) {
          final resolved = resolveVoice(requested, available);
          if (resolved == null) {
            profiles = profiles
                .map(
                  (p) => p.id == parsed.activeProfileId
                      ? AccessibilityProfile(
                          id: p.id,
                          name: p.name,
                          isBuiltIn: p.isBuiltIn,
                          settings: p.settings.copyWith(
                            clearTtsVoice: true,
                            clearTtsVoiceName: true,
                          ),
                        )
                      : p,
                )
                .toList();
          } else if (resolved['name'] != requested['name'] ||
              resolved['locale'] != requested['locale']) {
            profiles = profiles
                .map(
                  (p) => p.id == parsed.activeProfileId
                      ? AccessibilityProfile(
                          id: p.id,
                          name: p.name,
                          isBuiltIn: p.isBuiltIn,
                          settings: p.settings.copyWith(
                            ttsVoice: resolved,
                            ttsVoiceName: resolved['name'],
                          ),
                        )
                      : p,
                )
                .toList();
          }
        }
      }
    } catch (_) {}
    // Canonical snapshot z (případně hlasově upraveného) kontraktu.
    final contract = buildContractJson(
      profiles: profiles,
      activeProfileId: parsed.activeProfileId,
      themeMode: parsed.themeMode,
      isDegreeMode: parsed.isDegreeMode,
      defaultMode: parsed.defaultMode,
      statsSummaryOrder: parsed.statsSummaryOrder,
      statsComputedOrder: parsed.statsComputedOrder,
      currencyFrom: parsed.currencyFrom,
      currencyTo: parsed.currencyTo,
      devEnabled: parsed.devEnabled,
      devAutoDiagnostic: parsed.devAutoDiagnostic,
      devDiagnosticDurationMs: parsed.devDiagnosticDurationMs,
      devPinCode: parsed.devPinCode,
      resultDisplayMode: parsed.resultDisplayMode,
      historyExactFormat: parsed.historyExactFormat,
    );
    // Persist PŘED jakoukoli změnou runtime (safe commit workflow).
    final prefs = await SharedPreferences.getInstance();
    await persistCanonicalContract(prefs, contract);
    // Teprve po úspěšné persistenci: runtime apply.
    final applied = parseContract(contract);
    setState(() {
      _profiles = applied.profiles;
      _activeProfileId = applied.activeProfileId;
      _globalResultDisplayMode = applied.resultDisplayMode;
      _historyExactFormat = applied.historyExactFormat;
      _statsSummaryOrder = List<StatsSummarySection>.from(
        applied.statsSummaryOrder,
      );
      _statsComputedOrder = List<StatsComputedItem>.from(
        applied.statsComputedOrder,
      );
      _isDegreeMode = applied.isDegreeMode;
      _defaultMode = applied.defaultMode;
      _currencyFrom = applied.currencyFrom;
      _currencyTo = applied.currencyTo;
      _devModeEnabled = applied.devEnabled;
      _devAutoDiagnosticEnabled = applied.devAutoDiagnostic;
      _devDiagnosticDurationMs = applied.devDiagnosticDurationMs;
      _devPinCode = applied.devPinCode;
    });
    widget.onThemeModeChanged(applied.themeMode);
    _applySettingsToRuntime(_getActiveAccessibilityProfile().settings);
    _dialogFontScaleNotifier.value =
        activeAccessibilitySettings.dialogFontScale;
    if (mounted) setState(() {});
  }

  void _showAccessibilityDialog() {
    showAppDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Nastavení přístupnosti'),
      builder: (context) => _AccessibilityDialog(parent: this),
    );
  }

  void _showStatsSummaryReadingOrderDialog() {
    showAppDialog(
      context: context,
      routeSettings: const RouteSettings(
        name: 'Pořadí čtení statistického souhrnu',
      ),
      builder: (context) => _StatsSummaryReadingOrderDialog(parent: this),
    );
  }

  // ===== Vývojářský režim =====
  void _handleDevTap() {
    if (_devPinLockUntil != null &&
        DateTime.now().isBefore(_devPinLockUntil!)) {
      // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
      if (mounted) {
        _showAccessibleSnackBar(
          _s(
            'Příliš mnoho pokusů, zkuste za chvíli.',
            'Too many attempts, try later.',
          ),
        );
      }
      return;
    }
    _devTapCount++;
    _devTapTimer?.cancel();
    _devTapTimer = Timer(const Duration(seconds: 2), () => _devTapCount = 0);
    if (_devTapCount >= 7) {
      _devTapCount = 0;
      _devTapTimer?.cancel();
      _onDevActivationRequested();
    }
  }

  void _onDevActivationRequested() {
    if (_devModeEnabled) {
      _showDevModeDialog();
      return;
    }
    if (_devPinCode == null) {
      _showDevPinCreateDialog();
    } else {
      _showDevPinVerifyDialog(
        onSuccess: () {
          setState(() => _devModeEnabled = true);
          _saveSettings();
          // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
          if (mounted) {
            _showAccessibleSnackBar(
              _s('Vývojářský režim aktivován', 'Developer mode activated'),
            );
          }
          _showDevModeDialog();
        },
      );
    }
  }

  void _showDevPinCreateDialog() {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Nastavit PIN'),
      barrierDismissible: false,
      builder: (ctx) => _DevPinDialog(
        parent: this,
        mode: _DevPinMode.create,
        onVerified: () {
          // již nastaveno v dialogu
        },
      ),
    );
  }

  void _showDevPinVerifyDialog({VoidCallback? onSuccess}) {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Zadejte PIN'),
      barrierDismissible: false,
      builder: (ctx) => _DevPinDialog(
        parent: this,
        mode: _DevPinMode.verify,
        onVerified: onSuccess,
      ),
    );
  }

  void _showDevPinChangeDialog() {
    if (_devPinCode == null) {
      _showDevPinCreateDialog();
      return;
    }
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Změnit PIN'),
      barrierDismissible: false,
      builder: (ctx) => _DevPinDialog(parent: this, mode: _DevPinMode.change),
    );
  }

  void _confirmDeactivateDevMode() {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Deaktivovat vývojářský režim'),
      builder: (ctx) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(
            _s('Deaktivovat vývojářský režim', 'Deactivate developer mode'),
          ),
        ),
        content: Text(
          _s(
            'Opravdu chcete deaktivovat vývojářský režim? Bude vyžadován PIN pro opětovnou aktivaci.',
            'Really deactivate developer mode? PIN will be required to reactivate.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // vyžadovat PIN pokud existuje
              if (_devPinCode != null) {
                _showDevPinVerifyDialog(
                  onSuccess: () {
                    setState(() => _devModeEnabled = false);
                    _saveSettings();
                    // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
                    if (mounted) {
                      _showAccessibleSnackBar(
                        _s(
                          'Vývojářský režim deaktivován',
                          'Developer mode deactivated',
                        ),
                      );
                    }
                  },
                );
              } else {
                setState(() => _devModeEnabled = false);
                _saveSettings();
                speak(
                  _s(
                    'Vývojářský režim deaktivován',
                    'Developer mode deactivated',
                  ),
                );
              }
            },
            child: Text(_s('Deaktivovat', 'Deactivate')),
          ),
        ],
      ),
    );
  }

  void _showDevModeDialog() {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Vývojářský režim'),
      builder: (ctx) => _DevModeDialog(parent: this),
    );
  }

  void _runDisplayDiagnostics() {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Autodiagnostika displejů'),
      barrierDismissible: false,
      builder: (ctx) => _DisplayDiagnosticsDialog(parent: this),
    );
  }

  void _showVoiceTestDialog() {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Test hlasu'),
      builder: (ctx) => _VoiceTestDialog(parent: this),
    );
  }

  void _showPrefsDumpDialog() {
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Uložená data'),
      builder: (ctx) => _PrefsDumpDialog(parent: this),
    );
  }

  void _handleDevShortcut() {
    _onDevActivationRequested();
  }

  void _openTtsSystemSettings() async {
    try {
      if (Platform.isAndroid) {
        const channel = MethodChannel(
          'com.example.mluvici_kalkulacka/tts_settings',
        );
        await channel.invokeMethod('openTtsSettings');
      } else if (Platform.isWindows) {
        await launchUrl(Uri.parse('ms-settings:speech'));
      }
    } catch (e) {
      debugPrint('openTtsSettings Error: $e');
      if (!mounted) return;
      showAppDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Chyba'),
        builder: (context) => AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(header: true, child: Text(_s('Chyba', 'Error'))),
          content: Text(
            _s(
              'Nelze otevřít systémové nastavení TTS.',
              'Could not open system TTS settings.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showTtsEngineDialog() async {
    if (Platform.isWindows) {
      if (!mounted) return;
      showAppDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Info'),
        builder: (context) => AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(header: true, child: Text(_s('Info', 'Info'))),
          content: Text(
            _s(
              'Výběr TTS enginu není na Windows podporován.',
              'TTS engine selection is not supported on Windows.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_s('Zavřít', 'Close')),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final engines = await tts.getEngines;
      if (!mounted) return;

      showAppDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Vybrat TTS engine'),
        builder: (context) => AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(
            header: true,
            child: Text(_s('Vybrat TTS engine', 'Select TTS engine')),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: engines.length,
              itemBuilder: (context, index) {
                final engine = engines[index].toString();
                final isSelected = _ttsEngine == engine;
                return Semantics(
                  container: true,
                  label:
                      '${_s("Engine", "Engine")}: $engine${isSelected ? _s(", vybráno", ", selected") : ""}',
                  selected: isSelected,
                  child: ListTile(
                    title: Text(engine),
                    selected: isSelected,
                    onTap: () {
                      if (_editingDraft != null && _editingProfileId != null) {
                        final prev = _editingDraft!.settings;
                        updateEditingSettings(
                          (s) => s.copyWith(ttsEngine: engine),
                        );
                        if (_editingProfileId == _activeProfileId &&
                            !Platform.isWindows) {
                          tts.setEngine(engine).catchError((e) {
                            debugPrint('TTS setEngine Error: $e');
                          });
                        }
                        // R9: jedna hláška jednotným kanálem.
                        unawaited(
                          announceEvent(
                            _s(
                              'Engine $engine vybrán',
                              'Engine $engine selected',
                            ),
                            category: SpeechCategory.settings,
                            interruptCurrentSpeech: true,
                          ),
                        );
                      } else {
                        updateActiveAccessibilitySettings(
                          (s) => s.copyWith(ttsEngine: engine),
                        );
                        if (!Platform.isWindows) {
                          tts.setEngine(engine);
                        }
                        // R9: jedna hláška jednotným kanálem.
                        unawaited(
                          announceEvent(
                            _s(
                              'Engine $engine vybrán',
                              'Engine $engine selected',
                            ),
                            category: SpeechCategory.settings,
                            interruptCurrentSpeech: true,
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('TTS Engine Error: $e');
      if (!mounted) return;
      showAppDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Chyba'),
        builder: (context) => AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(header: true, child: Text(_s('Chyba', 'Error'))),
          content: Text(
            _s(
              'Výběr TTS enginu není na tomto zařízení nebo verzi aplikace podporován.',
              'TTS engine selection is not supported on this device or app version.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_s('Zavřít', 'Close')),
            ),
          ],
        ),
      );
    }
  }

  void _showTtsVoiceDialog() async {
    try {
      final voices = await tts.getVoices;
      if (!mounted) return;

      if (voices == null || voices is! List || voices.isEmpty) {
        if (!mounted) return;
        showAppDialog(
          context: context,
          routeSettings: const RouteSettings(name: 'Info'),
          builder: (context) => AlertDialog(
            insetPadding: _dialogInsetPadding(),
            title: Semantics(header: true, child: Text(_s('Info', 'Info'))),
            content: Text(
              _s(
                'Nejsou k dispozici žádné hlasy pro aktuální jazyk.',
                'No voices are available for the current language.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_s('OK', 'OK')),
              ),
            ],
          ),
        );
        return;
      }

      final currentLang = _isEnglish() ? 'en-US' : 'cs-CZ';
      final filteredVoices = voices
          .cast<Map<dynamic, dynamic>>()
          .where((v) => v['locale'] == currentLang)
          .toList();

      if (filteredVoices.isEmpty) {
        if (!mounted) return;
        showAppDialog(
          context: context,
          routeSettings: const RouteSettings(name: 'Info'),
          builder: (context) => AlertDialog(
            insetPadding: _dialogInsetPadding(),
            title: Semantics(header: true, child: Text(_s('Info', 'Info'))),
            content: Text(
              _s(
                'Nejsou k dispozici žádné hlasy pro aktuální jazyk.',
                'No voices are available for the current language.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_s('OK', 'OK')),
              ),
            ],
          ),
        );
        return;
      }

      showAppDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Vybrat hlas'),
        builder: (context) => AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(
            header: true,
            child: Text(_s('Vybrat hlas', 'Select voice')),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredVoices.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _ttsVoice == null;
                  return Semantics(
                    container: true,
                    label:
                        '${_s("Výchozí hlas", "Default voice")}${isSelected ? _s(", vybráno", ", selected") : ""}',
                    selected: isSelected,
                    child: ListTile(
                      title: Text(_s('Výchozí', 'Default')),
                      selected: isSelected,
                      onTap: () {
                        if (_editingDraft != null &&
                            _editingProfileId != null) {
                          updateEditingSettings(
                            (s) => s.copyWith(
                              clearTtsVoice: true,
                              clearTtsVoiceName: true,
                            ),
                          );
                          if (_editingProfileId == _activeProfileId) {
                            tts.clearVoice();
                          }
                          // R9: jedna hláška jednotným kanálem.
                          unawaited(
                            announceEvent(
                              _s(
                                'Hlas nastaven na výchozí',
                                'Voice set to default',
                              ),
                              category: SpeechCategory.settings,
                              interruptCurrentSpeech: true,
                            ),
                          );
                        } else {
                          updateActiveAccessibilitySettings(
                            (s) => s.copyWith(
                              clearTtsVoice: true,
                              clearTtsVoiceName: true,
                            ),
                          );
                          tts.clearVoice();
                          // R9: jedna hláška jednotným kanálem.
                          unawaited(
                            announceEvent(
                              _s(
                                'Hlas nastaven na výchozí',
                                'Voice set to default',
                              ),
                              category: SpeechCategory.settings,
                              interruptCurrentSpeech: true,
                            ),
                          );
                        }
                        Navigator.pop(context);
                      },
                    ),
                  );
                }
                final voice = filteredVoices[index - 1];
                final name = voice['name']?.toString() ?? '';
                String label = name;
                final quality = voice['quality']?.toString();
                final gender = voice['gender']?.toString();
                if (quality != null && quality.isNotEmpty) {
                  label += ' ($quality';
                  if (gender != null && gender.isNotEmpty) {
                    label += ', $gender';
                  }
                  label += ')';
                } else if (gender != null && gender.isNotEmpty) {
                  label += ' ($gender)';
                }
                final isSelected =
                    _ttsVoice?['name'] == name &&
                    _ttsVoice?['locale'] == voice['locale'];
                return Semantics(
                  container: true,
                  label:
                      '${_s("Hlas", "Voice")}: $label${isSelected ? _s(", vybráno", ", selected") : ""}',
                  selected: isSelected,
                  child: ListTile(
                    title: Text(label),
                    selected: isSelected,
                    onTap: () {
                      final voiceMap = <String, String>{
                        'name': name,
                        'locale': voice['locale']?.toString() ?? '',
                      };
                      if (_editingDraft != null && _editingProfileId != null) {
                        updateEditingSettings(
                          (s) => s.copyWith(
                            ttsVoice: voiceMap,
                            ttsVoiceName: name,
                          ),
                        );
                        if (_editingProfileId == _activeProfileId) {
                          tts.setVoice(voiceMap).catchError((e) {
                            debugPrint('TTS setVoice Error: $e');
                          });
                        }
                        // R9: jedna hláška jednotným kanálem.
                        unawaited(
                          announceEvent(
                            _s('Hlas $name vybrán', 'Voice $name selected'),
                            category: SpeechCategory.settings,
                            interruptCurrentSpeech: true,
                          ),
                        );
                      } else {
                        updateActiveAccessibilitySettings(
                          (s) => s.copyWith(
                            ttsVoice: voiceMap,
                            ttsVoiceName: name,
                          ),
                        );
                        tts.setVoice(voiceMap);
                        // R9: jedna hláška jednotným kanálem.
                        unawaited(
                          announceEvent(
                            _s('Hlas $name vybrán', 'Voice $name selected'),
                            category: SpeechCategory.settings,
                            interruptCurrentSpeech: true,
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('TTS Voice Error: $e');
      if (!mounted) return;
      showAppDialog(
        context: context,
        routeSettings: const RouteSettings(name: 'Chyba'),
        builder: (context) => AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(header: true, child: Text(_s('Chyba', 'Error'))),
          content: Text(
            _s(
              'Výběr hlasu není na tomto zařízení nebo verzi aplikace podporován.',
              'Voice selection is not supported on this device or app version.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_s('OK', 'OK')),
            ),
          ],
        ),
      );
    }
  }

  void _showTutorialDialog() {
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      (label: l10n.tutorialTabIntro, text: l10n.tutorialIntro),
      (label: l10n.tutorialTabBasic, text: l10n.tutorialBasic),
      (label: l10n.tutorialTabScientific, text: l10n.tutorialScientific),
      (label: l10n.tutorialTabStatistics, text: l10n.tutorialStatistics),
      (
        label: l10n.tutorialTabStatsManagement,
        text: l10n.tutorialStatsManagement,
      ),
      (label: l10n.tutorialTabElectrician, text: l10n.tutorialElectrician),
      (label: l10n.tutorialTabUnit, text: l10n.tutorialUnit),
      (label: l10n.tutorialTabTime, text: l10n.tutorialTime),
      (label: l10n.tutorialTabCurrency, text: l10n.tutorialCurrency),
    ];
    showAppDialog(
      context: context,
      routeSettings: RouteSettings(name: l10n.helpTitle),
      builder: (context) =>
          _TutorialDialog(tabs: tabs, parent: this, l10n: l10n),
    );
  }

  void _showStatisticsHelpDialog() {
    final l10n = _l10n;

    Widget _section(String title, List<String> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(t),
            ),
          ),
        ],
      );
    }

    final ttsText = l10n.statsHelpText;

    showAppDialog(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsHelpTitle),
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(l10n.statsHelpTitle)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _section(l10n.statsHelpKeyboardSection, [
                l10n.statsHelpKeyboardSets,
                l10n.statsHelpKeyboardMPlus,
                l10n.statsHelpKeyboardMc,
                l10n.statsHelpKeyboardMr,
                l10n.statsHelpKeyboardStats,
                l10n.statsHelpKeyboardSemicolon,
              ]),
              const Divider(),
              _section(l10n.statsHelpAdvancedSection, [
                l10n.statsHelpAdvancedMean,
                l10n.statsHelpAdvancedSd,
                l10n.statsHelpAdvancedVar,
                l10n.statsHelpAdvancedSum,
                l10n.statsHelpAdvancedMed,
                l10n.statsHelpAdvancedMode,
                l10n.statsHelpAdvancedMin,
                l10n.statsHelpAdvancedMax,
                l10n.statsHelpAdvancedCv,
                l10n.statsHelpAdvancedWmean,
              ]),
              const Divider(),
              _section(l10n.statsHelpFieldsSection, [l10n.statsHelpFieldsDesc]),
              const Divider(),
              _section(l10n.statsHelpWeightedMeanSection, [
                l10n.statsHelpWeightedMeanDesc,
              ]),
              const Divider(),
              _section(l10n.statsHelpTipsSection, [
                '• ${l10n.statsHelpTip1}',
                '• ${l10n.statsHelpTip2}',
                '• ${l10n.statsHelpTip3}',
                '• ${l10n.statsHelpTip4}',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _showPrecisionDialog(DisplayFormat format) {
    showAppDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Nastavení přesnosti'),
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(_l10n.precisionTitle)),
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
                    // Čistě formátový přepis stejné matematické hodnoty:
                    // generace se nemění, platná metadata se pouze překlíčují.
                    _lastExactKey = _lastResult;
                  }
                });
                speak(_l10n.decimalPlacesSet(i));
                Navigator.pop(context);
              },
              child: Text('$i'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(_l10n.cancel.toUpperCase()),
          ),
        ],
      ),
    );
  }

  Widget _buildDotMatrixDisplay({double fitScale = 1.0}) {
    String txt = display.isEmpty
        ? (_hasResult ? "" : "_")
        : "${display.substring(0, _cursorPosition)}_${display.substring(_cursorPosition)}";
    final scale = _responsiveScale(context);
    // Vzdušnější rozestupy číslic: základní mezera 0.8 → 1.15 LED jednotky
    // a navíc škálování se systémovým písmem, aby slabozrací uživatelé měli
    // čitelnější rozestupy i bez ručního zoomu. Velikost samotných číslic
    // (ledSize) se nemění – delší výrazy jen více využijí horizontální scroll,
    // který už vstupní řádek má (_scrollControllerH + autoscroll ke kurzoru).
    // Výška plátna roste s mezerou (plátno = ledSize*8 + ledSpacing*7),
    // proto musí auto-fit výpočet níže používat stejné konstanty.
    final inputSysFactor = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.5);
    final gap = _thousandGroupGapBase() * _dotMatrixZoom * scale * fitScale;
    return CustomDotMatrixDisplay(
      text: _toBarNotation(txt),
      ledSize: 3.0 * _dotMatrixZoom * scale * fitScale,
      ledSpacing: 1.15 * _dotMatrixZoom * scale * fitScale * inputSysFactor,
      overlineThickness: _overlineThickness,
      overlineHeight: _overlineHeight,
      thousandGroupGap: gap,
      enableThousandGrouping: true,
    );
  }

  Widget buildButton(
    String label, {
    Color? color,
    String? semanticLabel,
    FutureOr<void> Function()? onPressed,
    FutureOr<void> Function()? onLongPressed,
    bool expanded = true,
    double fitScale = 1.0,
    IconData? icon,
  }) {
    String descriptiveName = semanticLabel ?? _getButtonName(label);
    if (label == 'M+' && _currentMode == CalculatorMode.statistics) {
      descriptiveName += _isEnglish()
          ? ', tap to review and save, long press to set repetition'
          : ', krátký stisk pro kontrolu a uložení, dlouhý stisk pro zadání opakování';
      if (Platform.isWindows) {
        descriptiveName += _isEnglish()
            ? '. Press M to add, Ctrl+M for repetition'
            : '. Stiskněte M pro přidání, Ctrl+M pro opakování';
      }
    }
    if (label == 'PCT') {
      descriptiveName += _isEnglish()
          ? '. Enter value and whole separated by a semicolon, e.g. 30;200.'
          : '. Zadejte hodnotu a celek oddělené středníkem, např. 30;200.';
    }
    if (label == '…') {
      descriptiveName += _isEnglish()
          ? ', tap to toggle period, long press to edit period manually'
          : ', krátký stisk pro přepnutí periody, dlouhý stisk pro ruční úpravu periody';
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scale = _responsiveScale(context);
    final double fit = fitScale.clamp(0.2, 1.0);
    final double gs = scale * fit;
    final sysFactor = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.6);
    final baseFontForScale = (20.0 * _keyboardFontScale * sysFactor * gs).clamp(
      14.0,
      72.0,
    );

    Widget buttonBody = Container(
      margin: EdgeInsets.all(3 * gs),
      constraints: fit < 1.0
          ? const BoxConstraints()
          : BoxConstraints(minHeight: 48.0 * scale, minWidth: 48.0 * scale),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.grey[800] : Colors.grey[300]),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black54, width: 0.5),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 4 * gs, vertical: 6 * gs),
      child: LayoutBuilder(
        builder: (innerContext, innerConstraints) {
          final double keyboardFontSize = baseFontForScale;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null)
                      Icon(
                        icon,
                        color: color != null
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black),
                        size: keyboardFontSize,
                      ),
                    if (icon != null && label.isNotEmpty)
                      SizedBox(width: 4 * gs),
                    if (label.isNotEmpty)
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: keyboardFontSize,
                          fontWeight: FontWeight.bold,
                          color: color != null
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    Future<void> defaultTap() async {
      // R1: žádné předběžné speak(descriptiveName) – hlasové potvrzení
      // generuje samotná akce (_handleButtonPressed/append/clear/...).
      // Předběžné speak by zdvojovalo oznámení stejné informace.
      await _handleButtonPressed(label);
    }

    Widget buttonWidget = Semantics(
      label: descriptiveName,
      button: true,
      enabled: true,
      onTap: () async {
        if (onPressed != null) {
          await onPressed();
        } else {
          await defaultTap();
        }
      },
      child: InkWell(
        excludeFromSemantics:
            true, // Zamezí TalkBacku vidět InkWell jako samostatný prvek
        onFocusChange: (hasFocus) {
          // Mluvíme pouze pokud není aktivní TalkBack, aby nedocházelo k dvojitému čtení
          if (hasFocus && _isScreenReaderActive != true)
            speak(descriptiveName);
        },
        onTap: () async {
          if (onPressed != null) {
            await onPressed();
          } else {
            await defaultTap();
          }
        },
        onLongPress: onLongPressed == null
            ? null
            : () async {
                await onLongPressed();
              },
        child: buttonBody,
      ),
    );

    if (expanded) {
      return Expanded(child: buttonWidget);
    } else {
      return buttonWidget;
    }
  }

  List<StatisticsRecord> _parseDisplayToRecords(String text) {
    final parts = text
        .split(';')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => double.parse(s.trim().replaceAll(',', '.')))
        .toList();
    final fieldCount = _currentFieldCount;
    if (fieldCount == 1) {
      return parts.map((v) => StatisticsRecord(values: [v])).toList();
    }
    final records = <StatisticsRecord>[];
    for (int i = 0; i + fieldCount <= parts.length; i += fieldCount) {
      records.add(StatisticsRecord(values: parts.sublist(i, i + fieldCount)));
    }
    if (records.isEmpty || records.length * fieldCount != parts.length) {
      throw FormatException(
        _s(
          'Počet hodnot musí být násobkem počtu polí ($fieldCount).',
          'Number of values must be a multiple of field count ($fieldCount).',
        ),
      );
    }
    return records;
  }

  Future<void> _addSingleValueToStats() async {
    if (!_hasStatsSet) {
      // R9: oznamuje pouze SnackBar (dříve speak + snackbar = duplicita).
      if (mounted) {
        _showAccessibleSnackBar(
          _s(
            'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
            'No statistics set created. Enter a name for a new set first.',
          ),
        );
        List<StatisticsRecord>? recordsToSave;
        if (display.isNotEmpty) {
          try {
            recordsToSave = _parseDisplayToRecords(display);
          } catch (_) {
            // Hodnoty ze displeje nepůjí zopakovat – po uložení bude
            // ohlášen pouze vznik sady.
          }
        }
        _showCreateStatsSetDialog(context, recordsToSave: recordsToSave);
      }
      return;
    }
    if (display.isEmpty) {
      // R9: oznamuje pouze SnackBar (dříve speak + snackbar = duplicita).
      if (mounted) {
        _showAccessibleSnackBar(
          _s(
            'Displej je prázdný. Zadejte číslo k uložení.',
            'Display is empty. Enter a number to store.',
          ),
        );
      }
      return;
    }
    try {
      final recordsToAdd = _parseDisplayToRecords(display);

      if (recordsToAdd.isEmpty) {
        // R9: oznamuje pouze SnackBar (dříve speak + snackbar = duplicita).
        if (mounted) {
          _showAccessibleSnackBar(
            _s('Žádná platná čísla k uložení.', 'No valid numbers to store.'),
          );
        }
        return;
      }

      // Krátký stisk: vždy kontrolní dialog bez pole pro počet opakování.
      // Jediné oznámení obstará samotný dialog (souhrn) – žádné předběžné
      // hlášení o připravených hodnotách (R9: žádná duplicita).
      _showStatsSaveReviewDialog(recordsToAdd);
    } catch (e) {
      final msg = e is FormatException
          ? e.message
          : _s(
              'Chyba při ukládání do statistické paměti. Zkontrolujte formát dat.',
              'Error storing to statistics memory. Check the data format.',
            );
      // R9: oznamuje pouze SnackBar (dříve speak + snackbar = duplicita).
      if (mounted) {
        _showAccessibleSnackBar(msg);
      }
    }
  }

  Future<void> _handleButtonPressed(String label, {bool silent = false}) async {
    HapticFeedback.selectionClick();
    bool alreadyHandled = false;
    if (label == '…') {
      _togglePeriod();
      return;
    }
    if (_hasResult) {
      setState(() {
        if (['+', '-', '*', '/', '^', '%', 'EXP', 'x²', 'x³'].contains(label)) {
          display = 'ANS';
          _cursorPosition = 3;
          _hasResult = false;
        } else if ([
          'SIN',
          'COS',
          'TAN',
          'ASIN',
          'ACOS',
          'ATAN',
          '√',
          '∛',
          'ABS',
          'LOG',
          'LN',
        ].contains(label)) {
          display = '$label(ANS)';
          _cursorPosition = display.length;
          _hasResult = false;
          if (!silent) {
            final name = _getButtonName(label);
            if (['ASIN', 'ACOS', 'ATAN'].contains(label)) {
              speak(_l10n.inverseResult(name));
            } else {
              speak(_l10n.resultOf(name));
            }
          }
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
        _pendingNegOpens.clear();
        // Pokračování v práci s výsledkem (ANS) používá numerickou hodnotu;
        // zlomkový pohled se konzistentně vypíná.
        _fractionOverride = null;
      });
      if (alreadyHandled) {
        // R1: tichý přepis ⁿ√ by byl bez SR němý – jediné potvrzení.
        // (SIN-větev výše už vlastní hlášku má, tu nedvojovat.)
        // Při aktivní čtečce oznamuje změna displeje (liveRegion).
        if (label == 'ⁿ√' && !silent) {
          unawaited(
            announceEvent(
              _getButtonName(label),
              category: SpeechCategory.valueChange,
            ),
          );
        }
        return;
      }
    }

    if (label == 'C') {
      clear();
    } else if (label == 'DEL') {
      backspace();
    } else if (label == '=') {
      calculateResult();
    } else if (label == 'M+') {
      if (_currentMode == CalculatorMode.statistics) {
        // Logika pro krátký a dlouhý stisk je obsloužena v `buildButton`
        // Pokud je vyvoláno zde (např. klávesnice), defaultně provedeme krátký stisk
        _addSingleValueToStats();
      } else {
        speak(
          _s(
            'Tlačítko M plus je dostupné pouze ve statistickém režimu.',
            'The M+ button is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'MC') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
          if (mounted) {
            _showAccessibleSnackBar(
              _s('Není vytvořena žádná sada.', 'No set created.'),
            );
          }
          return;
        }
        setState(() {
          _statsMemory.clear();
        });
        _saveStatsData();
        final setName = _statsSets[_currentStatsSetIndex].name;
        // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
        if (mounted) {
          _showAccessibleSnackBar(
            _s(
              'Paměť sady $setName byla smazána.',
              'Memory of set $setName was cleared.',
            ),
          );
        }
      } else {
        speak(
          _s(
            'Tlačítko M C je dostupné pouze ve statistickém režimu.',
            'The MC button is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'MR') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
          if (mounted) {
            _showAccessibleSnackBar(
              _s('Není vytvořena žádná sada.', 'No set created.'),
            );
          }
          return;
        }
        if (_statsMemory.isEmpty) {
          // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
          if (mounted) {
            _showAccessibleSnackBar(_statsEmptyMessage());
          }
        } else {
          _showStatisticsMemoryDialog();
        }
      } else {
        speak(
          _s(
            'Tlačítko M R je dostupné pouze ve statistickém režimu.',
            'The MR button is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'STATS') {
      if (_currentMode == CalculatorMode.statistics) {
        if (!_hasStatsSet) {
          // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
          if (mounted) {
            _showAccessibleSnackBar(
              _s('Není vytvořena žádná sada.', 'No set created.'),
            );
          }
          return;
        }
        if (_statsMemory.isEmpty) {
          // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
          if (mounted) {
            _showAccessibleSnackBar(_statsEmptyMessage());
          }
        } else {
          _showStatisticsSummaryDialog();
        }
      } else {
        speak(
          _s(
            'Statistický souhrn je dostupný pouze ve statistickém režimu.',
            'Statistics summary is available only in statistics mode.',
          ),
        );
      }
    } else if (label == 'SETS') {
      if (_currentMode == CalculatorMode.statistics) {
        _showStatsSetsDialog();
      } else {
        speak(
          _s(
            'Správa sad je dostupná pouze ve statistickém režimu.',
            'Manage sets is available only in statistics mode.',
          ),
        );
      }
    } else if (_electricianCalculationFromButton(label) != null) {
      if (_currentMode == CalculatorMode.electrician) {
        _selectElectricianCalculation(
          _electricianCalculationFromButton(label)!,
        );
      } else {
        append(label, silent: silent);
      }
    } else if ([
      'MEAN',
      'SD',
      'VAR',
      'MED',
      'MODE',
      'CV',
      'SUM',
      'WMEAN',
      'MIN',
      'MAX',
    ].contains(label)) {
      if (_currentMode == CalculatorMode.statistics) {
        try {
          if (_statsMemory.isEmpty) {
            speak(_statsEmptyMessage());
            return;
          }

          final fieldNames = _statsSets[_currentStatsSetIndex].fieldNames;

          if (label == 'WMEAN') {
            if (_currentFieldCount < 2) {
              speak(
                _s(
                  'Vážený průměr vyžaduje alespoň 2 pole (hodnoty a váhy).',
                  'Weighted mean requires at least 2 fields (values and weights).',
                ),
              );
              return;
            }
            final values = _getFieldValues(0);
            final weights = _getFieldValues(1);
            double sumW = 0;
            double sumVW = 0;
            for (int i = 0; i < values.length; i++) {
              sumVW += values[i] * weights[i];
              sumW += weights[i];
            }
            if (sumW == 0) {
              speak(
                _s(
                  'Součet vah je nulový, nelze vypočítat vážený průměr.',
                  'Sum of weights is zero, cannot calculate weighted mean.',
                ),
              );
              return;
            }
            final wmean = sumVW / sumW;
            final resStr = _formatNumberSmart(wmean);
            final spoken = _s(
              'Vážený průměr z paměti je ${_formatSpokenNumber(wmean)} '
                  '(pole ${fieldNames[0]} váženo polem ${fieldNames[1]})',
              'Weighted mean from memory is ${_formatSpokenNumber(wmean)} '
                  '(field ${fieldNames[0]} weighted by field ${fieldNames[1]})',
            );
            setState(() {
              _lastResult = resStr;
              _hasResult = true;
              display = resStr;
              _cursorPosition = display.length;
              _lastNumericValue = wmean;
              // R10: statistický kontext – zlomek nevhodný (stale flag fix).
              _lastResultIsPlainNumeric = false;
              _fractionOverride = null;
              // Nový výsledek ruší přesná metadata (klíč + generace).
              _lastExact = null;
              _lastExactKey = '';
              _resultGeneration++;
              _lastExactGeneration = _resultGeneration;
            });
            // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
            unawaited(
              announceEvent(
                spoken,
                category: SpeechCategory.actionConfirm,
                isNumeric: true,
                interruptCurrentSpeech: true,
              ),
            );
            _addToHistory('STATS($label)', resStr, numericValue: wmean);
            return;
          }

          final snapshot = _computeStatisticsSnapshot()!;

          String resStr = '0';
          String spoken = '';
          double? numericResult;
          final fieldUnit =
              _statsSets.isNotEmpty &&
                  _selectedFieldIndex <
                      _statsSets[_currentStatsSetIndex].fieldUnits.length
              ? _statsSets[_currentStatsSetIndex]
                    .fieldUnits[_selectedFieldIndex]
              : null;
          final fieldUnitSpoken = fieldUnit != null
              ? _s(
                  ' v ${_getUnitSpeech(fieldUnit, context: 'z')}',
                  ' in ${_getUnitSpeech(fieldUnit)}',
                )
              : '';
          final fieldLabelSpoken = _currentFieldCount > 1
              ? _s(
                  ' pro pole ${fieldNames[_selectedFieldIndex]}$fieldUnitSpoken',
                  ' for field ${fieldNames[_selectedFieldIndex]}$fieldUnitSpoken',
                )
              : fieldUnitSpoken;

          if (label == 'MEAN') {
            resStr = _formatNumberSmart(snapshot.mean);
            numericResult = snapshot.mean;
            spoken = _s(
              'Průměr${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.mean)}',
              'Mean${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.mean)}',
            );
          } else if (label == 'SUM') {
            resStr = _formatNumberSmart(snapshot.sum);
            numericResult = snapshot.sum;
            spoken = _s(
              'Součet hodnot${fieldLabelSpoken} je ${_formatSpokenNumber(snapshot.sum)}',
              'Sum of values${fieldLabelSpoken} is ${_formatSpokenNumber(snapshot.sum)}',
            );
          } else if (label == 'VAR') {
            resStr = _formatNumberSmart(snapshot.variance);
            numericResult = snapshot.variance;
            spoken = _s(
              'Rozptyl${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.variance)}',
              'Variance${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.variance)}',
            );
          } else if (label == 'SD') {
            resStr = _formatNumberSmart(snapshot.sd);
            numericResult = snapshot.sd;
            spoken = _s(
              'Směrodatná odchylka${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.sd)}',
              'Standard deviation${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.sd)}',
            );
          } else if (label == 'MED') {
            resStr = _formatNumberSmart(snapshot.median);
            numericResult = snapshot.median;
            spoken = _s(
              'Medián${fieldLabelSpoken} z paměti je ${_formatSpokenNumber(snapshot.median)}',
              'Median${fieldLabelSpoken} from memory is ${_formatSpokenNumber(snapshot.median)}',
            );
          } else if (label == 'MODE') {
            if (!snapshot.modeExists) {
              final firstValue = _getFieldValues(_selectedFieldIndex).first;
              resStr = _formatNumberSmart(firstValue);
              numericResult = firstValue;
              spoken = _s(
                'Modus${fieldLabelSpoken} neexistuje, všechny hodnoty se vyskytují pouze jednou.',
                'No mode${fieldLabelSpoken} exists, all values occur only once.',
              );
            } else {
              resStr = snapshot.modes
                  .map((m) => _formatNumberSmart(m))
                  .join(';');
              numericResult = snapshot.modes.first;
              final modesSpoken = snapshot.modes
                  .map((m) => _formatSpokenNumber(m))
                  .join(_s(' a ', ' and '));
              if (snapshot.modes.length == 1) {
                spoken = _s(
                  'Modus${fieldLabelSpoken} z paměti je $modesSpoken, vyskytuje se ${snapshot.modeOccurrenceCount} krát',
                  'Mode${fieldLabelSpoken} from memory is $modesSpoken, occurs ${snapshot.modeOccurrenceCount} times',
                );
              } else {
                spoken = _s(
                  'Modusy${fieldLabelSpoken} z paměti jsou $modesSpoken, vyskytují se ${snapshot.modeOccurrenceCount} krát',
                  'Modes${fieldLabelSpoken} from memory are $modesSpoken, occur ${snapshot.modeOccurrenceCount} times',
                );
              }
            }
          } else if (label == 'CV') {
            if (snapshot.cv == null) {
              spoken = _s(
                'Nelze vypočítat variační koeficient${fieldLabelSpoken}, průměr je nula.',
                'Cannot calculate coefficient of variation${fieldLabelSpoken}, mean is zero.',
              );
              resStr = 'Err';
            } else {
              resStr = _formatNumberSmart(snapshot.cv!);
              numericResult = snapshot.cv!;
              spoken = _s(
                'Variační koeficient${fieldLabelSpoken} je ${_formatSpokenNumber(snapshot.cv!)} procent',
                'Coefficient of variation${fieldLabelSpoken} is ${_formatSpokenNumber(snapshot.cv!)} percent',
              );
            }
          } else if (label == 'MIN') {
            resStr = _formatNumberSmart(snapshot.min);
            numericResult = snapshot.min;
            spoken = _s(
              'Minimální hodnota${fieldLabelSpoken} je ${_formatSpokenNumber(snapshot.min)}',
              'Minimum${fieldLabelSpoken} is ${_formatSpokenNumber(snapshot.min)}',
            );
          } else if (label == 'MAX') {
            resStr = _formatNumberSmart(snapshot.max);
            numericResult = snapshot.max;
            spoken = _s(
              'Maximální hodnota${fieldLabelSpoken} je ${_formatSpokenNumber(snapshot.max)}',
              'Maximum${fieldLabelSpoken} is ${_formatSpokenNumber(snapshot.max)}',
            );
          }

          setState(() {
            _lastResult = resStr;
            _hasResult = true;
            display = resStr;
            _cursorPosition = display.length;
            _lastNumericValue = numericResult;
            // R10: statistický kontext – zlomek nevhodný (stale flag fix).
            _lastResultIsPlainNumeric = false;
            _fractionOverride = null;
            // Nový výsledek ruší přesná metadata (klíč + generace).
            _lastExact = null;
            _lastExactKey = '';
            _resultGeneration++;
            _lastExactGeneration = _resultGeneration;
          });
          // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
          unawaited(
            announceEvent(
              spoken,
              category: SpeechCategory.actionConfirm,
              isNumeric: true,
              interruptCurrentSpeech: true,
            ),
          );
          _addToHistory('STATS($label)', resStr, numericValue: numericResult);
        } catch (e) {
          unawaited(
            announceEvent(
              _s(
                'Chyba statistického výpočtu.',
                'Statistics calculation error.',
              ),
              category: SpeechCategory.error,
              interruptCurrentSpeech: true,
            ),
          );
        }
      } else {
        append(label, silent: silent);
      }
    } else if (label == 'STO') {
      _isStoreMode = true;
      // R9: oznamuje pouze SnackBar (dříve speak + announce = duplicita).
      if (mounted) {
        _showAccessibleSnackBar(_l10n.selectMemory);
      }
    } else if (label == 'RCL') {
      _isRecallMode = true;
      // R9: oznamuje pouze SnackBar (dříve speak + announce = duplicita).
      if (mounted) {
        _showAccessibleSnackBar(_l10n.selectMemoryRecall);
      }
    } else if (label == 'CLR') {
      final cleared = _occupiedMemoryVariableNames();
      setState(() {
        _memory.updateAll((key, value) => 0);
        // Racionální vazby se mažou společně s číselnou pamětí (jinak by
        // zastaralý záznam v _rationalMemory obnovil smazanou hodnotu přes RCL).
        _rationalMemory.clear();
        _memoryOccupied.clear();
      });
      _saveStatsData();
      final clearedMsg = _memoryClearedMessage(cleared);
      // R9: oznamuje pouze SnackBar (dříve speak + announce = duplicita).
      if (mounted) {
        _showAccessibleSnackBar(clearedMsg);
      }
    } else if (_memory.containsKey(label)) {
      _handleMemoryVariable(label);
    } else if (label == 'EXP') {
      // R1: jediné oznámení správným jménem (append by řekl jen písmeno "E").
      append('E', silent: true);
      if (!silent) speak(_getButtonName('EXP'));
    } else if ([
      'SIN',
      'COS',
      'TAN',
      'ASIN',
      'ACOS',
      'ATAN',
      '√',
      '∛',
      'ABS',
      'LOG',
      'LN',
    ].contains(label)) {
      _insertAtCursor('$label(', cursorOffset: 0);
      if (!silent) speak(_getButtonName(label));
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
          String spoken = _l10n.degreesUnit;
          if (symbol == '°') {
            nextSymbol = "'";
            spoken = _l10n.minutesUnit;
          } else if (symbol == "'") {
            nextSymbol = '"';
            spoken = _l10n.secondsUnit;
          }

          setState(() {
            display =
                display.substring(0, _cursorPosition - 1) +
                nextSymbol +
                display.substring(_cursorPosition);
          });
          speak(spoken);
        } else {
          // Jsme za číslem (např. "36°25" nebo jen "36"), určíme co vložit
          String toInsert = '°';
          String spoken = _l10n.degreesUnit;

          if (symbol == '°') {
            toInsert = "'";
            spoken = _l10n.minutesUnit;
          } else if (symbol == "'") {
            toInsert = '"';
            spoken = _l10n.secondsUnit;
          }

          append(toInsert, silent: true);
          speak(spoken);
        }
      } else {
        // Nenalezeno žádné číslo před kurzorem, vložíme výchozí stupně
        append('°', silent: true);
        speak(_l10n.degreesUnit);
      }
    } else if (['°→\'', '\'→°', '°→RAD', 'RAD→°'].contains(label)) {
      try {
        double val = display.isNotEmpty
            ? _evaluateExpression(display)
            : (_lastNumericValue ?? 0.0);
        if (label == '°→\'') {
          // Převod na DMS
          String dmsStr = _formatAsDMS(val);
          setState(() {
            _lastResult = dmsStr;
            _hasResult = true;
            display = '';
            _cursorPosition = 0;
            _lastNumericValue = val;
            // R10: DMS kontext – zlomek nevhodný (stale flag fix).
            _lastResultIsPlainNumeric = false;
            _fractionOverride = null;
            // Nový výsledek ruší přesná metadata (klíč + generace).
            _lastExact = null;
            _lastExactKey = '';
            _resultGeneration++;
            _lastExactGeneration = _resultGeneration;
          });
          // Formátování pro TTS: "12°34'5\"" -> "12 stupňů, 34 minut a 5 sekund"
          String spokenDms = _formatDmsSpeech(dmsStr);
          // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
          unawaited(
            announceEvent(
              _l10n.resultIs(spokenDms),
              category: SpeechCategory.actionConfirm,
              isNumeric: true,
              interruptCurrentSpeech: true,
            ),
          );
        } else if (label == '\'→°') {
          // Převod na desetinné stupně
          String decimalStr = val
              .toStringAsFixed(4)
              .replaceAll(RegExp(r'\.0+$'), '')
              .replaceAll(RegExp(r'0+$'), '');
          setState(() {
            _lastResult = decimalStr;
            _hasResult = true;
            display = '';
            _cursorPosition = 0;
            _lastNumericValue = val;
            // R10: DMS kontext – zlomek nevhodný (stale flag fix).
            _lastResultIsPlainNumeric = false;
            _fractionOverride = null;
            // Nový výsledek ruší přesná metadata (klíč + generace).
            _lastExact = null;
            _lastExactKey = '';
            _resultGeneration++;
            _lastExactGeneration = _resultGeneration;
          });
          // R4/R6: jedna hláška jednotným kanálem, oddělovač podle jazyka.
          unawaited(
            announceEvent(
              _l10n.resultIs(
                '${_localizeDecimalSeparator(decimalStr)} ${_l10n.degreesUnit}',
              ),
              category: SpeechCategory.actionConfirm,
              isNumeric: true,
              interruptCurrentSpeech: true,
            ),
          );
        } else {
          final converted = label == '°→RAD'
              ? val * math.pi / 180.0
              : val * 180.0 / math.pi;
          final result = _formatNumberSmart(converted);
          final fromUnit = label == '°→RAD'
              ? _s('stupňů', 'degrees')
              : _s('radiánů', 'radians');
          final toUnit = label == '°→RAD'
              ? _s('radiánů', 'radians')
              : _s('stupňů', 'degrees');
          setState(() {
            _lastResult = result;
            _hasResult = true;
            display = '';
            _cursorPosition = 0;
            _lastNumericValue = converted;
            // R10: kontext převodu – zlomek nevhodný (stale flag fix).
            _lastResultIsPlainNumeric = false;
            _fractionOverride = null;
            // Nový výsledek ruší přesná metadata (klíč + generace).
            _lastExact = null;
            _lastExactKey = '';
            _resultGeneration++;
            _lastExactGeneration = _resultGeneration;
          });
          // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
          unawaited(
            announceEvent(
              _l10n.resultIs(
                '${_formatSpokenNumber(val)} $fromUnit = ${_formatSpokenNumber(converted)} $toUnit',
              ),
              category: SpeechCategory.actionConfirm,
              isNumeric: true,
              interruptCurrentSpeech: true,
            ),
          );
        }
      } catch (e) {
        unawaited(
          announceEvent(
            _l10n.conversionError,
            category: SpeechCategory.error,
            interruptCurrentSpeech: true,
          ),
        );
      }
    } else if (label == '\u03C0') {
      append(label, silent: silent);
    } else if (label == 'PCT') {
      _calculatePercentOf();
    } else if (label == 'NOW' || label == 'TEĎ') {
      if (_currentMode == CalculatorMode.time) {
        _insertCurrentTime();
      } else {
        append(label, silent: silent);
      }
    } else if (label == 'DIFF' || label == 'ROZDÍL') {
      if (_currentMode == CalculatorMode.time) {
        // R1: jediné oznámení (dříve append mluvil ";" a hned další speak).
        append(';', silent: true);
        if (!silent) speak(_s('středník, rozdíl', 'semicolon, difference'));
      } else {
        append(label, silent: silent);
      }
    } else if (label == 'TO_SEC' || label == 'NA SEKUNDY') {
      if (_currentMode == CalculatorMode.time) {
        try {
          if (display.trim().isEmpty && _hasResult) {
            display = _lastResult;
          }
          final sec = _parseHmsToSeconds(display.trim());
          final secStr = sec.toString();
          // R10: zdroj před vymazáním (dříve historie s prázdným výrazem).
          final src = display.trim().isEmpty && _hasResult
              ? _lastResult
              : display.trim();
          setState(() {
            _lastResult = secStr;
            display = '';
            _hasResult = true;
            _lastNumericValue = sec.toDouble();
            // Nový výsledek ruší přesná metadata (klíč + generace).
            _lastExact = null;
            _lastExactKey = '';
            _resultGeneration++;
            _lastExactGeneration = _resultGeneration;
          });
          // R4/R6: jedna hláška jednotným kanálem, oddělovač podle jazyka.
          unawaited(
            announceEvent(
              _l10n.timeToSecResult(
                _localizeDecimalSeparator(src.isEmpty ? secStr : src),
                secStr,
              ),
              category: SpeechCategory.actionConfirm,
              isNumeric: true,
              interruptCurrentSpeech: true,
            ),
          );
          _addToHistory(
            src.isEmpty ? secStr : src,
            secStr,
            numericValue: sec.toDouble(),
          );
        } catch (e) {
          unawaited(
            announceEvent(
              _l10n.timeInvalidFormat,
              category: SpeechCategory.error,
              interruptCurrentSpeech: true,
            ),
          );
        }
      } else {
        append(label, silent: silent);
      }
    } else if (label == 'TO_HMS' || label == 'NA ČAS') {
      if (_currentMode == CalculatorMode.time) {
        try {
          String src = display.trim();
          if (src.isEmpty && _hasResult) src = _lastResult;
          double v;
          if (src.contains(':')) {
            v = _parseHmsToSeconds(src).toDouble();
          } else {
            v = double.parse(src.replaceAll(',', '.'));
          }
          final hms = _formatSecondsToHms(v.round());
          setState(() {
            _lastResult = hms;
            display = '';
            _hasResult = true;
            _lastNumericValue = v;
            // Nový výsledek ruší přesná metadata (klíč + generace).
            _lastExact = null;
            _lastExactKey = '';
            _resultGeneration++;
            _lastExactGeneration = _resultGeneration;
          });
          // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
          unawaited(
            announceEvent(
              _l10n.timeToHmsResult(v.round().toString(), hms),
              category: SpeechCategory.actionConfirm,
              isNumeric: true,
              interruptCurrentSpeech: true,
            ),
          );
          _addToHistory(src, hms, numericValue: v);
        } catch (e) {
          unawaited(
            announceEvent(
              _l10n.timeInvalidFormat,
              category: SpeechCategory.error,
              interruptCurrentSpeech: true,
            ),
          );
        }
      } else {
        append(label, silent: silent);
      }
    } else if (label == ':') {
      _autoClosePendingNegIfNeeded();
      append(':', silent: silent);
    } else if (label == '±') {
      _handleNegativeButton();
    } else if (label == ')') {
      // Blokovat prázdné "(-)" – musí obsahovat číslo
      if (_pendingNegOpens.isNotEmpty) {
        final p = _pendingNegOpens.last;
        if (_cursorPosition > p + 2) {
          if (!_canAutoClosePendingNeg(p)) {
            // uvnitř je prázdné nebo neplatné – nedovolit další ')'
            // Pokud je to prázdné "(-", zablokuj
            final inner = display.substring(p + 2, _cursorPosition);
            if (!RegExp(r'\d').hasMatch(inner)) {
              speak(_s('Nejprve zadejte číslo', 'Enter number first'));
              return;
            }
          }
        } else {
          // Kurzour těsně za "(-" bez čísla
          speak(_s('Nejprve zadejte číslo', 'Enter number first'));
          return;
        }
      }
      // Pokud je pending NEG a lze bezpečně uzavřít, konzumuj ho místo duplicity
      if (_pendingNegOpens.isNotEmpty &&
          _canAutoClosePendingNeg(_pendingNegOpens.last)) {
        _autoClosePendingNegIfNeeded(force: true);
        if (!silent) speak(_getButtonName(')'));
      } else {
        // Zabránit duplicitnímu "))" těsně za kurzorem
        if (_cursorPosition < display.length &&
            display[_cursorPosition] == ')') {
          setState(() => _cursorPosition++);
          if (!silent) speak(_getButtonName(')'));
        } else {
          append(')', silent: silent);
        }
      }
    } else {
      // Guard: pokud je otevřen NEG bez čísla, povolit jen číslice, '.' a případně další NEG již blokován
      if (_pendingNegOpens.isNotEmpty) {
        final p = _pendingNegOpens.last;
        final insideEmpty =
            _cursorPosition <= p + 2 ||
            !RegExp(r'\d').hasMatch(display.substring(p + 2, _cursorPosition));
        if (insideEmpty) {
          // povolit jen číslice a '.' uvnitř prázdného NEG
          if (!RegExp(r'^[0-9.]$').hasMatch(label)) {
            speak(_s('Nejprve zadejte číslo', 'Enter number first'));
            return;
          }
        }
      }
      // Před operátory a funkcemi auto-uzavři NEG pokud je číslo dokončeno
      const operators = [
        '+',
        '-',
        '*',
        '/',
        '^',
        '%',
        '(',
        ';',
        '!',
        'x²',
        'x³',
        'EXP',
      ];
      if (operators.contains(label)) {
        _autoClosePendingNegIfNeeded();
      }
      // Také před vkládáním funkcí/proměnných auto-uzavři
      if (RegExp(r'^[A-Z]$').hasMatch(label) ||
          [
            'SIN',
            'COS',
            'TAN',
            'ASIN',
            'ACOS',
            'ATAN',
            '√',
            '∛',
            'ABS',
            'LOG',
            'LN',
            'ⁿ√',
            'π',
            'ANS',
          ].contains(label)) {
        _autoClosePendingNegIfNeeded();
      }
      append(label, silent: silent);
    }
  }

  void _calculatePercentOf() {
    if (display.isEmpty) {
      // R4: jedna chybová hláška jednotným kanálem (dříve force-bypass).
      unawaited(
        announceEvent(
          _s(
            'Displej je prázdný. Zadejte hodnotu a celek oddělené středníkem, např. 30;200.',
            'Display is empty. Enter value and whole separated by a semicolon, e.g. 30;200.',
          ),
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
      return;
    }
    final originalDisplay = display;
    final parts = display
        .split(';')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length != 2) {
      unawaited(
        announceEvent(
          _s(
            'Zadejte dvě hodnoty oddělené středníkem: hodnota;celek.',
            'Enter two values separated by a semicolon: value;whole.',
          ),
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
      return;
    }
    try {
      final value = _evaluateExpression(parts[0]);
      final whole = _evaluateExpression(parts[1]);
      if (whole == 0) {
        unawaited(
          announceEvent(
            _s('Celek nesmí být nula.', 'The whole must not be zero.'),
            category: SpeechCategory.error,
            interruptCurrentSpeech: true,
          ),
        );
        return;
      }
      final percent = value / whole * 100;
      final resStr = _formatNumberSmart(percent);
      final spoken = _s(
        '${_formatSpokenNumber(value)} je ${_formatSpokenNumber(percent)} procent z ${_formatSpokenNumber(whole)}',
        '${_formatSpokenNumber(value)} is ${_formatSpokenNumber(percent)} percent of ${_formatSpokenNumber(whole)}',
      );
      setState(() {
        _lastResult = resStr;
        _hasResult = true;
        display = resStr;
        _cursorPosition = display.length;
        _lastNumericValue = percent;
        // R10: kontext procent – zlomek nevhodný (stale flag fix).
        _lastResultIsPlainNumeric = false;
        _fractionOverride = null;
        // Nový výsledek ruší přesná metadata (klíč + generace).
        _lastExact = null;
        _lastExactKey = '';
        _resultGeneration++;
        _lastExactGeneration = _resultGeneration;
      });
      // R4: jedna hláška jednotným kanálem (dříve force-bypass přes SR).
      unawaited(
        announceEvent(
          spoken,
          category: SpeechCategory.actionConfirm,
          isNumeric: true,
          interruptCurrentSpeech: true,
        ),
      );
      _addToHistory('PCT($originalDisplay)', resStr, numericValue: percent);
    } catch (e) {
      unawaited(
        announceEvent(
          _s(
            'Chyba výpočtu procent. Zkontrolujte zadané hodnoty.',
            'Percentage calculation error. Check the entered values.',
          ),
          category: SpeechCategory.error,
          interruptCurrentSpeech: true,
        ),
      );
    }
  }

  Widget _buildMainKeyboard() {
    List<String> btns = [];
    switch (_currentMode) {
      case CalculatorMode.basic:
        btns = [
          'C',
          '(',
          ')',
          '/',
          '7',
          '8',
          '9',
          '*',
          '4',
          '5',
          '6',
          '-',
          '1',
          '2',
          '3',
          '+',
          'DEL',
          '0',
          '.',
          '±',
          '…',
          '%',
          '=',
        ];
        break;
      case CalculatorMode.scientific:
        if (_scientificFunctionsPage) {
          btns = [
            'SIN',
            'COS',
            'TAN',
            'ASIN',
            'ACOS',
            'ATAN',
            '√',
            '∛',
            'ⁿ√',
            '!',
            'LOG',
            'LN',
            'x²',
            'x³',
            '^',
            '\u03C0',
            'DMS',
            '°→\'',
            '\'→°',
            '°→RAD',
            'RAD→°',
            'ABS',
            '±',
            'ANS',
            'C',
            'DEL',
            '=',
          ];
        } else {
          btns = [
            'C',
            '(',
            ')',
            '/',
            '7',
            '8',
            '9',
            '*',
            '4',
            '5',
            '6',
            '-',
            '1',
            '2',
            '3',
            '+',
            '0',
            '.',
            '±',
            '…',
            'EXP',
            '%',
            'DEL',
            '=',
          ];
        }
        break;
      case CalculatorMode.statistics:
        btns = [
          'SETS',
          'MC',
          'MR',
          'M+',
          'STATS',
          'C',
          'DEL',
          '/',
          '7',
          '8',
          '9',
          '*',
          '4',
          '5',
          '6',
          '-',
          '1',
          '2',
          '3',
          '+',
          '0',
          '.',
          '±',
          ';',
          '=',
        ];
        break;
      case CalculatorMode.electrician:
        btns = [
          'OHM_V',
          'OHM_I',
          'OHM_R',
          'C',
          ';',
          '7',
          '8',
          '9',
          '/',
          '4',
          '5',
          '6',
          '*',
          '1',
          '2',
          '3',
          '-',
          '0',
          '.',
          '±',
          'DEL',
          '+',
          'ANS',
          '=',
        ];
        break;
      case CalculatorMode.unitConversion:
        btns = [
          'C',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '0',
          '.',
          '±',
          'DEL',
          '=',
        ];
        break;
      case CalculatorMode.time:
        btns = [
          'C',
          ':',
          'DEL',
          '/',
          '7',
          '8',
          '9',
          '*',
          '4',
          '5',
          '6',
          '-',
          '1',
          '2',
          '3',
          '+',
          '±',
          '0',
          ';',
          'NOW',
          '=',
        ];
        break;
      case CalculatorMode.currency:
        btns = [
          'C',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '0',
          '.',
          '±',
          'DEL',
          '=',
        ];
        break;
    }

    // Konzistentní velikost tlačítek napříč režimy:
    // - 4 sloupce, 7 referenčních řádků, jednotná výška řádku pro všechny režimy
    // - řádky rovnoměrně využijí skutečně dostupnou výšku: pokud se standardní
    //   výška nevejde, všechny řádky se proporcionálně zmenší stejně (fitScale)
    // - NIKDY vertikální SingleChildScrollView v hlavní klávesnici
    // - zachovává _keyboardFontScale, TextScaler, _responsiveScale, Semantics a focus order
    Widget buttonFor(String b, double fitScale) {
      Color? color;
      if (['/', '*', '-', '+'].contains(b)) {
        color = Colors.blue;
      } else if (b == 'C') {
        color = Colors.orange;
      } else if (b == 'DEL') {
        color = Colors.redAccent;
      } else if (b == '=') {
        color = Colors.green;
      } else if (['M+', 'MC', 'MR', 'STATS', 'SETS'].contains(b)) {
        color = Colors.deepPurple;
      } else if (_electricianCalculationFromButton(b) != null) {
        color = _isSelectedElectricianButton(b) ? Colors.green : Colors.teal;
      } else if (b == ';') {
        color = Colors.deepPurple;
      }
      return buildButton(
        b,
        color: color,
        semanticLabel: _getElectricianButtonSemanticLabel(b),
        expanded: false,
        fitScale: fitScale,
        onPressed: () async {
          if (b == 'M+' && _currentMode == CalculatorMode.statistics) {
            await _addSingleValueToStats();
          } else {
            await _handleButtonPressed(b);
          }
        },
        onLongPressed: (b == 'M+' && _currentMode == CalculatorMode.statistics)
            ? () async => await _handleMultipleStatisticsAddition()
            : (b == '…')
            ? () async => await _showPeriodEditDialog()
            : null,
      );
    }

    // Stabilní 7×4 rastr – 4 sloupce, 7 referenčních řádků, max 28 buněk.
    // Mapování: index = row*4 + col. rowH je jednotná pro všechny režimy
    // (závisí pouze na _responsiveScale a společném fitScale, ne na
    // btns.length). Žádný Wrap, žádný vertikální scroll.
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final scale = _responsiveScale(ctx);
        final double standardRowH = (54.0 * scale)
            .clamp(48.0 * scale, 80.0 * scale)
            .toDouble();
        const double spacing = 2.0;
        const double pad = 4.0;
        // Fit: pokud je místa dost, standardní výška (strop, tlačítka nejsou
        // nekonečně vysoká); pokud je místa málo, všechny řádky se zmenší
        // stejně: rowH = (dostupné - mezery - padding) / 7. Podlaha 0.3
        // chrání před degenerací do neviditelna.
        double fitScale = 1.0;
        double rowH = standardRowH;
        if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
          final double fitted =
              (constraints.maxHeight -
                  pad -
                  (_kKeypadReferenceRows - 1) * spacing) /
              _kKeypadReferenceRows;
          if (fitted < standardRowH) {
            rowH = fitted.clamp(standardRowH * 0.3, standardRowH);
            fitScale = (rowH / standardRowH).clamp(0.3, 1.0);
          }
        }

        final List<Widget> cells = List<Widget>.generate(
          _kKeypadCellCount,
          (i) => i < btns.length
              ? SizedBox(height: rowH, child: buttonFor(btns[i], fitScale))
              : SizedBox(
                  height: rowH,
                  child: const ExcludeFocus(
                    child: ExcludeSemantics(child: SizedBox.shrink()),
                  ),
                ),
        );

        final List<Widget> rows = <Widget>[];
        for (int r = 0; r < _kKeypadReferenceRows; r++) {
          rows.add(
            Row(
              key: ValueKey('keypad_row_$r'),
              children: [
                for (int c = 0; c < _kKeypadColumns; c++) ...[
                  if (c > 0) const SizedBox(width: spacing),
                  Expanded(child: cells[r * _kKeypadColumns + c]),
                ],
              ],
            ),
          );
          if (r < _kKeypadReferenceRows - 1) {
            rows.add(const SizedBox(height: spacing));
          }
        }

        Widget grid = Column(
          key: const ValueKey('keypad_grid'),
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
        // Nikdy vertikální scroll: řádky se proporcionálně zmenší (fitScale).
        return Padding(padding: const EdgeInsets.all(2), child: grid);
      },
    );
  }

  Widget _buildScientificPageToggle() {
    final isFunctions = _scientificFunctionsPage;
    final label = isFunctions ? 'ČÍSLA' : 'FUNKCE';
    final semanticLabel = isFunctions
        ? _s('Přepnout na číselnou klávesnici', 'Switch to numeric keyboard')
        : _s('Přepnout na klávesnici funkcí', 'Switch to functions keyboard');
    final scale = _responsiveScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2 * scale, vertical: 2 * scale),
      child: SizedBox(
        height: 48 * scale,
        width: double.infinity,
        child: buildButton(
          label,
          semanticLabel: semanticLabel,
          color: Colors.deepPurple,
          onPressed: _toggleScientificFunctionsPage,
          expanded: false,
        ),
      ),
    );
  }

  void _toggleScientificFunctionsPage() {
    // R7: stejný text pro TTS i liveRegion (dříve "Funkce" vs "Stránka funkcí").
    // Při aktivní čtečce oznamuje skrytý liveRegion, jinak vlastní TTS.
    final msg = !_scientificFunctionsPage
        ? _s('Stránka funkcí', 'Functions page')
        : _s('Číselná stránka', 'Numbers page');
    setState(() {
      _scientificFunctionsPage = !_scientificFunctionsPage;
      _scientificPageAnnouncement = msg;
    });
    speak(msg);
  }

  Widget _buildModeSelector() {
    final scale = _responsiveScale(context);
    final sysFactor = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.6);
    // Chip label – geometrie 48*scale vs text: původně bez explicitního
    // škálování (font fixní 14, škálován jen systémově). Nově explicitně
    // škálujeme s geometrií, ale izolujeme systémový scaler aby nebyl
    // započten dvakrát (noScaling + ruční sysFactor).
    final chipFontSize = (14.0 * scale * sysFactor).clamp(12.0, 22.0);
    return Semantics(
      label: _s('Přepínač režimů', 'Mode selector'),
      container: true,
      child: Container(
        height: 48 * scale,
        margin: EdgeInsets.symmetric(vertical: 4 * scale),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: Row(
            children: CalculatorMode.values.map((mode) {
              String label = _getModeName(mode);
              final isSelected = _currentMode == mode;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                child: Semantics(
                  label:
                      '$label${isSelected ? _s(', vybráno', ', selected') : ''}',
                  selected: isSelected,
                  child: ChoiceChip(
                    label: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
                      child: Text(
                        label,
                        style: TextStyle(fontSize: chipFontSize),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (s) {
                      if (s) {
                        _changeMode(mode);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showAdvancedFunctionsDialog() {
    showAppDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Pokročilé funkce'),
      builder: (context) => _AdvancedFunctionsDialog(parent: this),
    );
  }

  void _showQuickMemoryDialog() {
    showAppDialog(
      context: context,
      // Z2: lokalizovaný název routy (dříve natvrdo česky).
      routeSettings: RouteSettings(
        name: _s('Rychlá paměť', 'Quick memory'),
      ),
      builder: (context) => _QuickMemoryDialog(parent: this),
    ).then((_) => _returnFocusToKeyboard());
  }

  void _insertFromHistory(String value) {
    _insertAtCursor(value.replaceAll(',', '.'));
    speak(
      _s(
        'Vloženo ${_expressionToSpeech(value)}',
        'Inserted ${_expressionToSpeech(value)}',
      ),
    );
    Navigator.pop(context);
  }

  void _removeStatsRecord(
    List<int> indices,
    StateSetter setStateDialog,
    BuildContext dialogContext,
  ) {
    setState(() {
      final sorted = List<int>.from(indices)..sort((a, b) => b.compareTo(a));
      for (final idx in sorted) {
        _statsSets[_currentStatsSetIndex].records.removeAt(idx);
      }
      if (_selectedFieldIndex >= _currentFieldCount) {
        _selectedFieldIndex = 0;
      }
    });
    _saveStatsData();
    setStateDialog(() {});
    final removedMsg = indices.length > 1
        ? _s(
            'Odebráno ${indices.length} ${_getStatsCountForm(indices.length)}',
            'Removed ${indices.length} ${_getStatsCountForm(indices.length)}',
          )
        : _s(
            'Odebrán záznam ${indices.first + 1}',
            'Removed record ${indices.first + 1}',
          );
    // R9: oznamuje pouze SnackBar (dříve speak + snackbar = duplicita).
    if (mounted) {
      _showAccessibleSnackBar(removedMsg, scaffoldContext: dialogContext);
    }
    if (_statsMemory.isEmpty) {
      // R9: oznamuje pouze SnackBar (dříve speak + snackbar = duplicita).
      if (mounted) {
        _showAccessibleSnackBar(
          _statsEmptyMessage(),
          scaffoldContext: dialogContext,
        );
      }
      Navigator.pop(dialogContext);
    }
  }

  void _showEditStatsRecordDialog(
    List<int> recordIndices,
    BuildContext dialogContext,
    StateSetter setStateDialog,
  ) {
    final recordIndex = recordIndices.first;
    final record = _statsMemory[recordIndex];
    final currentSet = _statsSets[_currentStatsSetIndex];
    final fieldNames = currentSet.fieldNames;
    final fieldUnits = currentSet.fieldUnits;
    final controllers = record.values
        .map(
          (v) => TextEditingController(
            text: _formatNumber(v).replaceAll(',', '.'),
          ),
        )
        .toList();

    showAppDialog<void>(
      context: dialogContext,
      routeSettings: RouteSettings(
        name: _s(
          'Upravit záznam ${recordIndex + 1}',
          'Edit record ${recordIndex + 1}',
        ),
      ),
      builder: (ctx) {
        return AlertDialog(
          scrollable: false,
          insetPadding: _dialogInsetPadding(),
          title: Semantics(
            header: true,
            child: Text(
              _s(
                'Upravit záznam ${recordIndex + 1}',
                'Edit record ${recordIndex + 1}',
              ),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(fieldNames.length, (i) {
              final unitCode = i < fieldUnits.length ? fieldUnits[i] : null;
              final label = unitCode != null
                  ? '${fieldNames[i]} (${_getUnitSpeech(unitCode)})'
                  : fieldNames[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  label: '$label (${_s("Pole ${i + 1}", "Field ${i + 1}")})',
                  child: TextField(
                    controller: controllers[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: label,
                      isDense: true,
                    ),
                  ),
                ),
              );
            }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final newValues = <double>[];
                bool valid = true;
                for (int i = 0; i < controllers.length; i++) {
                  final text = controllers[i].text.trim().replaceAll(',', '.');
                  final val = double.tryParse(text);
                  if (val != null) {
                    newValues.add(val);
                  } else {
                    valid = false;
                    break;
                  }
                }
                if (valid) {
                  setState(() {
                    for (final idx in recordIndices) {
                      _statsSets[_currentStatsSetIndex].records[idx] =
                          StatisticsRecord(values: newValues);
                    }
                  });
                  _saveStatsData();
                  setStateDialog(() {});
                  Navigator.pop(ctx);
                  final editedMsg = recordIndices.length > 1
                      ? _s(
                          'Záznam ${recordIndex + 1} upraven. Změněno ${recordIndices.length} ${_getStatsCountForm(recordIndices.length)}.',
                          'Record ${recordIndex + 1} edited. Changed ${recordIndices.length} ${_getStatsCountForm(recordIndices.length)}.',
                        )
                      : _s(
                          'Záznam ${recordIndex + 1} upraven',
                          'Record ${recordIndex + 1} edited',
                        );
                  // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
                  if (mounted) {
                    _showAccessibleSnackBar(editedMsg);
                  }
                } else {
                  speak(_s('Neplatná hodnota', 'Invalid value'));
                }
              },
              child: Text(_l10n.confirmAction),
            ),
          ],
        );
      },
    );
  }

  void _showStatisticsMemoryDialog() {
    final l10n = _l10n;

    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _l10n.statsMemoryTitle),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final currentSet = _statsSets[_currentStatsSetIndex];
            final currentSetName = currentSet.name;
            final fieldNames = currentSet.fieldNames;
            final fieldUnits = currentSet.fieldUnits;
            final totalCount = _statsMemory.length;
            final totalCountForm = _getStatsCountForm(totalCount);
            final records = List<StatisticsRecord>.from(_statsMemory);
            final freqFieldIndex = _selectedFieldIndex < fieldNames.length
                ? _selectedFieldIndex
                : 0;
            final groups = _groupStatsRecords(records);
            if (groups.length > 1) {
              groups.sort(
                (a, b) => records[a.first].values[freqFieldIndex].compareTo(
                  records[b.first].values[freqFieldIndex],
                ),
              );
            }
            final freqSnapshot = records.isNotEmpty
                ? _computeStatisticsSnapshot(freqFieldIndex)
                : null;
            final showFrequencies =
                freqSnapshot != null &&
                (freqSnapshot.frequencies.length > 1 ||
                    freqSnapshot.frequencies.entries.first.value > 1);

            String spokenSummary;
            if (records.isEmpty) {
              spokenSummary = _s(
                'Statistická paměť sady $currentSetName je prázdná.',
                'Statistics memory for set $currentSetName is empty.',
              );
            } else {
              final fieldsSummary = fieldNames
                  .asMap()
                  .entries
                  .map((fe) {
                    final unitCode = fe.key < fieldUnits.length
                        ? fieldUnits[fe.key]
                        : null;
                    final vals = groups
                        .map((g) {
                          final r = records[g.first];
                          final v = _formatSpokenNumber(r.values[fe.key]);
                          final u = unitCode != null
                              ? ' ${_getUnitSpeech(unitCode, value: r.values[fe.key])}'
                              : '';
                          return '$v$u';
                        })
                        .join(_s('; ', '; '));
                    return '${fe.value}: $vals';
                  })
                  .join('. ');
              spokenSummary = _s(
                'Statistická paměť, sada $currentSetName. Obsahuje $totalCount $totalCountForm. '
                    'Pole: $fieldsSummary.',
                'Statistics memory, set $currentSetName. Contains $totalCount $totalCountForm. '
                    'Fields: $fieldsSummary.',
              );
              if (showFrequencies) {
                final freqUnit = freqFieldIndex < fieldUnits.length
                    ? fieldUnits[freqFieldIndex]
                    : null;
                final frequencySpoken = freqSnapshot.frequencies.entries
                    .map((e) {
                      final valStr = _formatSpokenNumber(e.key);
                      final unitStr = freqUnit != null
                          ? ' ${_getUnitSpeech(freqUnit, value: e.key)}'
                          : '';
                      return _s(
                        '$valStr$unitStr se vyskytuje ${e.value} krát',
                        '$valStr$unitStr occurs ${e.value} times',
                      );
                    })
                    .join(_s('; ', '; '));
                spokenSummary += _s(
                  ' Počet výskytů pole ${fieldNames[freqFieldIndex]}: $frequencySpoken.',
                  ' Occurrences for field ${fieldNames[freqFieldIndex]}: $frequencySpoken.',
                );
              }
            }

            return AlertDialog(
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(l10n.statsMemoryTitle),
              ),
              content: Semantics(
                container: true,
                label: spokenSummary,
                liveRegion: true,
                child: Focus(
                  autofocus: true,
                  onFocusChange: (hasFocus) {
                    if (hasFocus && _isScreenReaderActive != true)
                      speak(spokenSummary);
                  },
                  child: SizedBox(
                    width: double.maxFinite,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.65,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              label: l10n.statsCurrentSetLabel(currentSetName),
                              child: ExcludeSemantics(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    l10n.statsCurrentSetLabel(currentSetName),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 8),
                            ExcludeSemantics(
                              child: Text(
                                _s(
                                  'Záznamů: $totalCount, Polí: ${fieldNames.length}',
                                  'Records: $totalCount, Fields: ${fieldNames.length}',
                                ),
                              ),
                            ),
                            if (records.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                header: true,
                                label: _s(
                                  'Sloupce: číslo, ${fieldNames.join(', ')}, počet',
                                  'Columns: number, ${fieldNames.join(', ')}, count',
                                ),
                                child: ExcludeSemantics(
                                  child: DefaultTextStyle.merge(
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    child: _buildMemoryHeaderRow(
                                      fieldNames,
                                      fieldUnits,
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(height: 16),
                              ...groups.asMap().entries.map((gEntry) {
                                final groupIndex = gEntry.key;
                                final group = gEntry.value;
                                final record = records[group.first];
                                final count = group.length;
                                final spokenValues = record.values
                                    .asMap()
                                    .entries
                                    .map((ve) {
                                      final unitCode =
                                          ve.key < fieldUnits.length
                                          ? fieldUnits[ve.key]
                                          : null;
                                      final unitStr = unitCode != null
                                          ? ' ${_getUnitSpeech(unitCode, value: ve.value)}'
                                          : '';
                                      return '${fieldNames[ve.key]}: ${_formatSpokenNumber(ve.value)}$unitStr';
                                    })
                                    .join(', ');

                                final rowLabel = _s(
                                  'Záznam ${groupIndex + 1}: $spokenValues. Počet výskytů: $count',
                                  'Record ${groupIndex + 1}: $spokenValues. Occurrences: $count',
                                );
                                return Semantics(
                                  container: true,
                                  label: rowLabel,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        ExcludeSemantics(
                                          child: SizedBox(
                                            width: 28,
                                            child: Text(
                                              '${groupIndex + 1}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        ...record.values.asMap().entries.map((
                                          ve,
                                        ) {
                                          final unitCode =
                                              ve.key < fieldUnits.length
                                              ? fieldUnits[ve.key]
                                              : null;
                                          final unitStr = unitCode != null
                                              ? ' ${_getUnitSpeech(unitCode, value: ve.value)}'
                                              : '';
                                          return Expanded(
                                            child: ExcludeSemantics(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: _PeriodicText(
                                                  '${_formatNumberSmart(ve.value)}$unitStr',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                  overlineThickness:
                                                      _overlineThickness,
                                                  overlineHeight:
                                                      _overlineHeight,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                        Expanded(
                                          child: ExcludeSemantics(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '$count×',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Semantics(
                                          label: rowLabel,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                  color: Colors.blue,
                                                ),
                                                tooltip: _s(
                                                  'Upravit záznam ${groupIndex + 1}',
                                                  'Edit record ${groupIndex + 1}',
                                                ),
                                                onPressed: () =>
                                                    _showEditStatsRecordDialog(
                                                      group,
                                                      dialogContext,
                                                      setStateDialog,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: const Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                                tooltip: _s(
                                                  'Smazat záznam ${groupIndex + 1}',
                                                  'Delete record ${groupIndex + 1}',
                                                ),
                                                onPressed: () =>
                                                    _removeStatsRecord(
                                                      group,
                                                      setStateDialog,
                                                      dialogContext,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showStatsSetsDialog();
                  },
                  child: Text(l10n.statsSetsManage),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMemoryHeaderRow(
    List<String> fieldNames, [
    List<String?>? fieldUnits,
  ]) {
    return Row(
      children: [
        const SizedBox(
          width: 28,
          child: Text('#', style: TextStyle(fontSize: 12)),
        ),
        ...fieldNames.asMap().entries.map((e) {
          final name = e.value;
          final unitCode = fieldUnits != null && e.key < fieldUnits.length
              ? fieldUnits[e.key]
              : null;
          final label = unitCode != null
              ? '$name (${_getUnitSpeech(unitCode)})'
              : name;
          return Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          );
        }),
        Expanded(
          child: Text(
            _s('Počet', 'Count'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            _s('Akce', 'Actions'),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Map<StatsSummarySection, String> _buildStatsSummaryPartsMap(int fieldIndex) {
    final snapshot = _computeStatisticsSnapshot(fieldIndex);
    if (snapshot == null) return {};
    final currentSetName = _statsSets[_currentStatsSetIndex].name;
    final fieldNames = _statsSets[_currentStatsSetIndex].fieldNames;
    final selectedFieldName = fieldNames[fieldIndex];
    final fieldUnit =
        fieldIndex < _statsSets[_currentStatsSetIndex].fieldUnits.length
        ? _statsSets[_currentStatsSetIndex].fieldUnits[fieldIndex]
        : null;
    final rawValues = _getFieldValues(fieldIndex);
    final sortedValues = List<double>.from(rawValues)..sort();
    final allValuesSpoken = sortedValues
        .map((v) {
          final numStr = _formatSpokenNumber(v);
          final unitStr = fieldUnit != null
              ? ' ${_getUnitSpeech(fieldUnit, value: v)}'
              : '';
          return '$numStr$unitStr';
        })
        .join(_isEnglish() ? ', ' : '; ');
    final dataCount = rawValues.length;
    final modeSpoken = snapshot.modeExists
        ? snapshot.modes
              .map((m) => _formatSpokenNumber(m))
              .join(_s(' a ', ' and '))
        : _l10n.statsModeNone;
    final cvSpoken = snapshot.cv == null
        ? _s('nelze vypočítat', 'cannot calculate')
        : '${_formatSpokenNumber(snapshot.cv!)} ${_s('procent', 'percent')}';
    final wmeanSpoken = snapshot.wmean == null
        ? null
        : _formatSpokenNumber(snapshot.wmean!);

    final header = _s(
      'Statistický souhrn pro sadu $currentSetName, pole $selectedFieldName. Počet hodnot: $dataCount. ',
      'Statistics summary for set $currentSetName, field $selectedFieldName. Count: $dataCount. ',
    );

    final values = _readStatsMemoryValues
        ? _s(
            'Všechny hodnoty: $allValuesSpoken. ',
            'All values: $allValuesSpoken. ',
          )
        : '';

    // Computed – poskládáno dle _statsComputedOrder (synchronizováno s vizuálem)
    final fieldNamesForWmean = _statsSets[_currentStatsSetIndex].fieldNames;
    String computedFor(StatsComputedItem it) {
      switch (it) {
        case StatsComputedItem.mean:
          return _s(
            'Průměr: ${_formatSpokenNumber(snapshot.mean)}. ',
            'Mean: ${_formatSpokenNumber(snapshot.mean)}. ',
          );
        case StatsComputedItem.sum:
          return _s(
            'Součet: ${_formatSpokenNumber(snapshot.sum)}. ',
            'Sum: ${_formatSpokenNumber(snapshot.sum)}. ',
          );
        case StatsComputedItem.variance:
          return _s(
            'Rozptyl: ${_formatSpokenNumber(snapshot.variance)}. ',
            'Variance: ${_formatSpokenNumber(snapshot.variance)}. ',
          );
        case StatsComputedItem.sd:
          return _s(
            'Směrodatná odchylka: ${_formatSpokenNumber(snapshot.sd)}. ',
            'Standard deviation: ${_formatSpokenNumber(snapshot.sd)}. ',
          );
        case StatsComputedItem.median:
          return _s(
            'Medián: ${_formatSpokenNumber(snapshot.median)}. ',
            'Median: ${_formatSpokenNumber(snapshot.median)}. ',
          );
        case StatsComputedItem.min:
          return _s(
            'Minimum: ${_formatSpokenNumber(snapshot.min)}. ',
            'Minimum: ${_formatSpokenNumber(snapshot.min)}. ',
          );
        case StatsComputedItem.max:
          return _s(
            'Maximum: ${_formatSpokenNumber(snapshot.max)}. ',
            'Maximum: ${_formatSpokenNumber(snapshot.max)}. ',
          );
        case StatsComputedItem.mode:
          return _s('Modus: $modeSpoken. ', 'Mode: $modeSpoken. ');
        case StatsComputedItem.cv:
          return _s(
            'Variační koeficient: $cvSpoken.',
            'Coefficient of variation: $cvSpoken.',
          );
        case StatsComputedItem.wmean:
          if (snapshot.wmean == null) return '';
          return _s(
            ' Vážený průměr: $wmeanSpoken (pole ${fieldNamesForWmean[0]} váženo polem ${fieldNamesForWmean[1]}).',
            ' Weighted mean: $wmeanSpoken (field ${fieldNamesForWmean[0]} weighted by field ${fieldNamesForWmean[1]}).',
          );
      }
    }

    final computedBuf = StringBuffer();
    for (final it in _statsComputedOrder) {
      computedBuf.write(computedFor(it));
    }
    final computed =
        computedBuf.toString().trim() + (computedBuf.isEmpty ? '' : '');

    return {
      StatsSummarySection.header: header,
      StatsSummarySection.dataValues: values,
      StatsSummarySection.computed: computed,
    };
  }

  List<String> _buildStatsSummarySpeechParts(int fieldIndex) {
    final map = _buildStatsSummaryPartsMap(fieldIndex);
    if (map.isEmpty) return [];
    final parts = <String>[];
    parts.add(map[StatsSummarySection.header]!);
    final values = map[StatsSummarySection.dataValues]!;
    if (values.isNotEmpty) parts.add(values);
    parts.add(map[StatsSummarySection.computed]!);
    return parts;
  }

  String _getOrderedSpokenSummary(int fieldIndex) {
    final map = _buildStatsSummaryPartsMap(fieldIndex);
    if (map.isEmpty) return '';
    final buffer = StringBuffer();
    for (final section in _statsSummaryOrder) {
      final part = map[section] ?? '';
      if (part.isEmpty) continue;
      buffer.write(part);
      if (!part.endsWith(' ')) buffer.write(' ');
    }
    return buffer.toString().trim();
  }

  String _getStatsSummarySectionLabel(StatsSummarySection s) {
    switch (s) {
      case StatsSummarySection.header:
        return _s('Hlavička souhrnu', 'Summary header');
      case StatsSummarySection.dataValues:
        return _s('Hodnoty v paměti', 'Memory values');
      case StatsSummarySection.computed:
        return _s('Vypočtené statistiky', 'Computed statistics');
    }
  }

  String _getStatsSummarySectionDescription(StatsSummarySection s) {
    switch (s) {
      case StatsSummarySection.header:
        return _s(
          'Název sady, pole a počet hodnot',
          'Set name, field and count',
        );
      case StatsSummarySection.dataValues:
        return _s('Seznam všech hodnot', 'List of all values');
      case StatsSummarySection.computed:
        return _s(
          'Průměr, součet, rozptyl, odchylka, medián, min, max, modus, CV',
          'Mean, sum, variance, SD, median, min, max, mode, CV',
        );
    }
  }

  void _moveStatsSummarySection(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      final item = _statsSummaryOrder.removeAt(oldIndex);
      int insertAt = newIndex;
      if (newIndex > oldIndex) insertAt = newIndex - 1;
      _statsSummaryOrder.insert(insertAt, item);
    });
    _saveSettings();
    final orderSpoken = _statsSummaryOrder
        .map((e) => _getStatsSummarySectionLabel(e))
        .join(', ');
    final msg = _s(
      'Pořadí změněno: $orderSpoken',
      'Order changed: $orderSpoken',
    );
    // R9: jedna hláška jednotným kanálem (dříve speak + announce).
    unawaited(
      announceEvent(msg, category: SpeechCategory.settings),
    );
  }

  void _moveStatsSummarySectionByOffset(int index, int offset) {
    final newIndex = index + offset;
    if (newIndex < 0 || newIndex >= _statsSummaryOrder.length) return;
    setState(() {
      final item = _statsSummaryOrder.removeAt(index);
      _statsSummaryOrder.insert(newIndex, item);
    });
    _saveSettings();
    final label = _getStatsSummarySectionLabel(_statsSummaryOrder[newIndex]);
    final dir = offset < 0 ? _s('výše', 'up') : _s('níže', 'down');
    final len = _statsSummaryOrder.length;
    // R9: přesun i nová pozice v jedné hlášce (dříve 2 eventy).
    unawaited(
      announceEvent(
        _s(
          '$label přesunuto $dir, pozice ${newIndex + 1} z $len',
          '$label moved $dir, position ${newIndex + 1} of $len',
        ),
        category: SpeechCategory.settings,
      ),
    );
  }

  void _resetStatsSummaryOrder() {
    setState(() {
      _statsSummaryOrder = [
        StatsSummarySection.header,
        StatsSummarySection.dataValues,
        StatsSummarySection.computed,
      ];
    });
    _saveSettings();
    final msg = _s('Pořadí obnoveno na výchozí', 'Order reset to default');
    // R9: jedna hláška jednotným kanálem (dříve speak + announce).
    unawaited(
      announceEvent(msg, category: SpeechCategory.settings),
    );
  }

  String _getStatsComputedItemLabel(StatsComputedItem it) {
    switch (it) {
      case StatsComputedItem.mean:
        return _s('Průměr', 'Mean');
      case StatsComputedItem.sum:
        return _s('Součet', 'Sum');
      case StatsComputedItem.variance:
        return _s('Rozptyl', 'Variance');
      case StatsComputedItem.sd:
        return _s('Směrodatná odchylka', 'Standard deviation');
      case StatsComputedItem.median:
        return _s('Medián', 'Median');
      case StatsComputedItem.min:
        return _s('Minimum', 'Minimum');
      case StatsComputedItem.max:
        return _s('Maximum', 'Maximum');
      case StatsComputedItem.mode:
        return _s('Modus', 'Mode');
      case StatsComputedItem.cv:
        return _s('Variační koeficient', 'Coefficient of variation');
      case StatsComputedItem.wmean:
        return _s('Vážený průměr', 'Weighted mean');
    }
  }

  String _getStatsComputedItemDescription(StatsComputedItem it) {
    switch (it) {
      case StatsComputedItem.mean:
        return _s('Aritmetický průměr', 'Arithmetic mean');
      case StatsComputedItem.sum:
        return _s('Součet hodnot', 'Sum of values');
      case StatsComputedItem.variance:
        return _s('Rozptyl', 'Variance');
      case StatsComputedItem.sd:
        return _s('Směrodatná odchylka', 'Standard deviation');
      case StatsComputedItem.median:
        return _s('Prostřední hodnota', 'Middle value');
      case StatsComputedItem.min:
        return _s('Nejmenší hodnota', 'Smallest value');
      case StatsComputedItem.max:
        return _s('Největší hodnota', 'Largest value');
      case StatsComputedItem.mode:
        return _s('Nejčastější hodnota', 'Most frequent value');
      case StatsComputedItem.cv:
        return _s('Variační koeficient v procentech', 'CV in percent');
      case StatsComputedItem.wmean:
        return _s('Vážený průměr (2 pole)', 'Weighted mean (2 fields)');
    }
  }

  void _moveStatsComputedItemByOffset(int index, int offset) {
    final newIndex = index + offset;
    if (newIndex < 0 || newIndex >= _statsComputedOrder.length) return;
    setState(() {
      final item = _statsComputedOrder.removeAt(index);
      _statsComputedOrder.insert(newIndex, item);
    });
    _saveSettings();
    final label = _getStatsComputedItemLabel(_statsComputedOrder[newIndex]);
    final dir = offset < 0 ? _s('výše', 'up') : _s('níže', 'down');
    final len = _statsComputedOrder.length;
    // R9: přesun i nová pozice v jedné hlášce (dříve 2 eventy).
    unawaited(
      announceEvent(
        _s(
          '$label přesunuto $dir, pozice ${newIndex + 1} z $len',
          '$label moved $dir, position ${newIndex + 1} of $len',
        ),
        category: SpeechCategory.settings,
      ),
    );
  }

  void _resetStatsComputedOrder() {
    setState(() {
      _statsComputedOrder = [
        StatsComputedItem.mean,
        StatsComputedItem.sum,
        StatsComputedItem.variance,
        StatsComputedItem.sd,
        StatsComputedItem.median,
        StatsComputedItem.min,
        StatsComputedItem.max,
        StatsComputedItem.mode,
        StatsComputedItem.cv,
        StatsComputedItem.wmean,
      ];
    });
    _saveSettings();
    final msg = _s(
      'Pořadí položek obnoveno na výchozí',
      'Items order reset to default',
    );
    // R9: jedna hláška jednotným kanálem (dříve speak + announce).
    unawaited(
      announceEvent(msg, category: SpeechCategory.settings),
    );
  }

  String _presetLabel(StatsOrderPreset p) {
    switch (p) {
      case StatsOrderPreset.def:
        return _s('Výchozí', 'Default');
      case StatsOrderPreset.valuesFirst:
        return _s('Hodnoty první', 'Values first');
      case StatsOrderPreset.statsFirst:
        return _s('Statistiky první', 'Stats first');
      case StatsOrderPreset.headerLast:
        return _s('Hlavička poslední', 'Header last');
      case StatsOrderPreset.custom:
        return _s('Vlastní', 'Custom');
    }
  }

  bool _isPresetMatch(StatsOrderPreset p) {
    switch (p) {
      case StatsOrderPreset.def:
        return _statsSummaryOrder.length == 3 &&
            _statsSummaryOrder[0] == StatsSummarySection.header &&
            _statsSummaryOrder[1] == StatsSummarySection.dataValues &&
            _statsSummaryOrder[2] == StatsSummarySection.computed;
      case StatsOrderPreset.valuesFirst:
        return _statsSummaryOrder.length == 3 &&
            _statsSummaryOrder[0] == StatsSummarySection.dataValues &&
            _statsSummaryOrder[1] == StatsSummarySection.header &&
            _statsSummaryOrder[2] == StatsSummarySection.computed;
      case StatsOrderPreset.statsFirst:
        return _statsSummaryOrder.length == 3 &&
            _statsSummaryOrder[0] == StatsSummarySection.computed &&
            _statsSummaryOrder[1] == StatsSummarySection.header &&
            _statsSummaryOrder[2] == StatsSummarySection.dataValues;
      case StatsOrderPreset.headerLast:
        return _statsSummaryOrder.length == 3 &&
            _statsSummaryOrder[0] == StatsSummarySection.dataValues &&
            _statsSummaryOrder[1] == StatsSummarySection.computed &&
            _statsSummaryOrder[2] == StatsSummarySection.header;
      case StatsOrderPreset.custom:
        return !_isPresetMatch(StatsOrderPreset.def) &&
            !_isPresetMatch(StatsOrderPreset.valuesFirst) &&
            !_isPresetMatch(StatsOrderPreset.statsFirst) &&
            !_isPresetMatch(StatsOrderPreset.headerLast);
    }
  }

  StatsOrderPreset get _currentPreset {
    for (final p in [
      StatsOrderPreset.def,
      StatsOrderPreset.valuesFirst,
      StatsOrderPreset.statsFirst,
      StatsOrderPreset.headerLast,
    ]) {
      if (_isPresetMatch(p)) return p;
    }
    return StatsOrderPreset.custom;
  }

  void applyStatsOrderPreset(StatsOrderPreset p, {bool announce = true}) {
    if (p == StatsOrderPreset.custom) {
      // R9: jedna hláška (dříve speak + announce různým textem).
      if (announce) {
        unawaited(
          announceEvent(
            _s('Vlastní pořadí aktivováno', 'Custom order activated'),
            category: SpeechCategory.settings,
          ),
        );
      }
      return;
    }
    setState(() {
      switch (p) {
        case StatsOrderPreset.def:
          _statsSummaryOrder = [
            StatsSummarySection.header,
            StatsSummarySection.dataValues,
            StatsSummarySection.computed,
          ];
          break;
        case StatsOrderPreset.valuesFirst:
          _statsSummaryOrder = [
            StatsSummarySection.dataValues,
            StatsSummarySection.header,
            StatsSummarySection.computed,
          ];
          break;
        case StatsOrderPreset.statsFirst:
          _statsSummaryOrder = [
            StatsSummarySection.computed,
            StatsSummarySection.header,
            StatsSummarySection.dataValues,
          ];
          break;
        case StatsOrderPreset.headerLast:
          _statsSummaryOrder = [
            StatsSummarySection.dataValues,
            StatsSummarySection.computed,
            StatsSummarySection.header,
          ];
          break;
        case StatsOrderPreset.custom:
          break;
      }
    });
    _saveSettings();
    final name = _presetLabel(p);
    // R9: jedna hláška jednotným kanálem (dříve speak + announce).
    if (announce) {
      unawaited(
        announceEvent(
          _s('Preset $name aktivován', 'Preset $name activated'),
          category: SpeechCategory.settings,
        ),
      );
    }
  }

  void _showStatisticsSummaryDialog() {
    _statsSummaryInitialized = false;
    if (_statsSets.isEmpty || _statsMemory.isEmpty) {
      // R9: oznamuje pouze SnackBar (jednotný kanál), dříve 3 eventy.
      final msg = _statsEmptyMessage();
      _showAccessibleSnackBar(msg);
      return;
    }
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _l10n.statsSummaryTitle),
      builder: (dialogContext) => _StatsSummaryDialog(parent: this),
    );
  }

  void _showStatsSetsDialog() {
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _l10n.statsSetsTitle),
      builder: (dialogContext) => _StatsSetsDialog(parent: this),
    );
  }

  void _showRenameStatsSetDialog(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final l10n = _l10n;
    final controller = TextEditingController(text: _statsSets[index].name);

    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsSetsRename),
      builder: (ctx) {
        return AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(header: true, child: Text(l10n.statsSetsRename)),
          // Odsazení od klávesnice řeší DialogRoute/AlertDialog.
          // Vnitřní padding s viewInsets.bottom by se přičetl podruhé
          // a vytlačil dialog nad horní hranu obrazovky.
          content: SingleChildScrollView(
            child: Semantics(
              label: l10n.statsSetNameLabel,
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.statsSetNameLabel),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    _statsSets[index].name = newName;
                  });
                  _saveStatsData();
                  onUpdated();
                  Navigator.pop(ctx);
                  speak(l10n.statsSetRenamedAnnouncement(newName));
                }
              },
              child: Text(l10n.confirmAction),
            ),
          ],
        );
      },
    );
  }

  void _showEditStatsSetDialog(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final l10n = _l10n;
    final set = _statsSets[index];

    // Draft kopie – mutuje se pouze lokálně, originál až po Potvrdit (kombinace A+B)
    final draftFieldNames = List<String>.from(set.fieldNames);
    final draftFieldUnits = List<String>.from(
      set.fieldUnits.map((e) => e ?? '--'),
    );
    final draftRecords = set.records
        .map((r) => StatisticsRecord(values: List<double>.from(r.values)))
        .toList();
    final fieldNameControllers = <TextEditingController>[
      for (var i = 0; i < draftFieldNames.length; i++)
        TextEditingController(text: draftFieldNames[i]),
    ];
    final fieldUnitValues = List<String>.from(draftFieldUnits);
    bool dirty = false;

    String fieldsSummary(List<String> names, List<String> units) {
      return names
          .asMap()
          .entries
          .map((e) {
            final u = e.value;
            final unitCode = e.key < units.length ? units[e.key] : '--';
            return unitCode != '--' ? '$u ($unitCode)' : u;
          })
          .join(', ');
    }

    void disposeControllers() {
      for (final c in fieldNameControllers) {
        c.dispose();
      }
    }

    void handleCancel(BuildContext dialogContext) {
      disposeControllers();
      Navigator.pop(dialogContext);
      final msg = _s(
        'Úpravy sady "${set.name}" zahozeny. Sada nebyla změněna.',
        'Edits of set "${set.name}" discarded. Set was not changed.',
      );
      // R9: oznamuje pouze SnackBar (dříve speak(force) + snackbar).
      if (mounted) {
        _showAccessibleSnackBar(msg);
      }
    }

    void handleSave(BuildContext dialogContext, StateSetter setDialogState) {
      // Validace: zapracuj texty z controllerů
      for (var i = 0; i < fieldNameControllers.length; i++) {
        final trimmed = fieldNameControllers[i].text.trim();
        if (trimmed.isNotEmpty) {
          draftFieldNames[i] = trimmed;
        }
      }
      // Prázdný název pole není povolen
      if (draftFieldNames.any((n) => n.trim().isEmpty)) {
        final err = _s(
          'Název pole nesmí být prázdný.',
          'Field name must not be empty.',
        );
        // R9: oznamuje pouze SnackBar (dříve speak(force) + snackbar).
        if (mounted) {
          _showAccessibleSnackBar(err);
        }
        return;
      }
      // Pokud nic nezměněno, jen zavřít s hláškou
      final namesChanged =
          draftFieldNames.length != set.fieldNames.length ||
          !List.generate(
            draftFieldNames.length,
            (i) => draftFieldNames[i] == set.fieldNames[i],
          ).every((e) => e) ||
          !List.generate(fieldUnitValues.length, (i) {
            final orig = i < set.fieldUnits.length
                ? (set.fieldUnits[i] ?? '--')
                : '--';
            return fieldUnitValues[i] == orig;
          }).every((e) => e) ||
          draftRecords.length != set.records.length;
      // Detect i hodnoty jednotek/názvů + délka
      if (!dirty && !namesChanged) {
        disposeControllers();
        Navigator.pop(dialogContext);
      final msg = _s('Žádné změny k uložení.', 'No changes to save.');
      // R4: jednotný kanál (dříve force-bypass přes SR).
      unawaited(
        announceEvent(msg, category: SpeechCategory.actionConfirm),
      );
      return;
      }

      setState(() {
        set.fieldNames
          ..clear()
          ..addAll(draftFieldNames);
        set.fieldUnits
          ..clear()
          ..addAll(fieldUnitValues.map((v) => v == '--' ? null : v));
        set.records
          ..clear()
          ..addAll(
            draftRecords.map(
              (r) => StatisticsRecord(values: List<double>.from(r.values)),
            ),
          );
        if (_selectedFieldIndex >= set.fieldNames.length) {
          _selectedFieldIndex = 0;
        }
      });
      _saveStatsData();
      _statsSummaryInitialized = false;
      onUpdated();
      setDialogState(() {});
      disposeControllers();
      Navigator.pop(dialogContext);
      final summary = fieldsSummary(draftFieldNames, fieldUnitValues);
      final msg = _s(
        'Sada "${set.name}" upravena. Pole: $summary. Změny uloženy.',
        'Set "${set.name}" edited. Fields: $summary. Changes saved.',
      );
      // R9: oznamuje pouze SnackBar (dříve speak(force) + snackbar).
      if (mounted) {
        _showAccessibleSnackBar(msg);
      }
    }

    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      routeSettings: RouteSettings(name: _s('Upravit pole', 'Edit fields')),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                handleCancel(dialogContext);
              },
              child: AlertDialog(
                scrollable: false,
                insetPadding: _dialogInsetPadding(),
                title: Semantics(
                  header: true,
                  child: Text(
                    _s('Pole sady', 'Fields of set') + ' "${set.name}"',
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      ...List.generate(fieldNameControllers.length, (i) {
                        final isLast = fieldNameControllers.length == 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildResponsiveFieldRow(
                            fieldWidget: Semantics(
                              label:
                                  _s('Název pole', 'Field name') + ' ${i + 1}',
                              child: TextField(
                                controller: fieldNameControllers[i],
                                decoration: InputDecoration(
                                  labelText: _s('Pole', 'Field') + ' ${i + 1}',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (_) {
                                  dirty = true;
                                  setDialogState(() {});
                                },
                              ),
                            ),
                            unitWidget: Semantics(
                              label:
                                  _s('Jednotka pole', 'Unit for field') +
                                  ' ${i + 1}',
                              child: DropdownButtonFormField<String>(
                                value: fieldUnitValues[i],
                                isDense: true,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                ),
                                items: _statsFieldUnitOptions.map((u) {
                                  return DropdownMenuItem(
                                    value: u,
                                    child: Text(
                                      _getUnitOptionLabel(u),
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    fieldUnitValues[i] = val;
                                    dirty = true;
                                    setDialogState(() {});
                                    final unitMsg = val == '--'
                                        ? _s(
                                            'Jednotka odstraněna.',
                                            'Unit removed.',
                                          )
                                        : _s(
                                            'Jednotka nastavena na $val. Změna se projeví po uložení.',
                                            'Unit set to $val. Change will apply after saving.',
                                          );
                                    speak(unitMsg);
                                  }
                                },
                              ),
                            ),
                            deleteButton: IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                                size: 20,
                              ),
                              tooltip:
                                  _s('Smazat pole', 'Delete field') +
                                  ' ${i + 1}',
                              onPressed: isLast
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        fieldNameControllers
                                            .removeAt(i)
                                            .dispose();
                                        fieldUnitValues.removeAt(i);
                                        draftFieldNames.removeAt(i);
                                        for (final r in draftRecords) {
                                          if (i < r.values.length)
                                            r.values.removeAt(i);
                                        }
                                        dirty = true;
                                      });
                                      speak(
                                        _s(
                                          'Pole ${i + 1} označeno ke smazání. Změna se projeví po uložení.',
                                          'Field ${i + 1} marked for deletion. Change will apply after saving.',
                                        ),
                                      );
                                    },
                            ),
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(_s('Přidat pole', 'Add field')),
                        onPressed: () {
                          final newIndex = draftFieldNames.length;
                          setDialogState(() {
                            final newName = _s(
                              'Pole ${newIndex + 1}',
                              'Field ${newIndex + 1}',
                            );
                            draftFieldNames.add(newName);
                            fieldUnitValues.add('--');
                            fieldNameControllers.add(
                              TextEditingController(text: newName),
                            );
                            for (final r in draftRecords) {
                              r.values.add(0.0);
                            }
                            dirty = true;
                          });
                          speak(
                            _s(
                              'Pole přidáno do návrhu. Stávajícím záznamům bude doplněna hodnota 0 po uložení.',
                              'Field added to draft. Existing records will be filled with 0 after saving.',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => handleCancel(dialogContext),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => handleSave(dialogContext, setDialogState),
                    child: Text(l10n.confirmAction),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResponsiveFieldRow({
    required Widget fieldWidget,
    required Widget unitWidget,
    Widget? deleteButton,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: fieldWidget),
        const SizedBox(width: 4),
        Expanded(flex: 2, child: unitWidget),
        if (deleteButton != null) deleteButton,
      ],
    );
  }

  List<String> get _statsFieldUnitOptions {
    final units = <String>['--'];
    for (final category in _unitCategories.keys) {
      units.addAll(_unitCategories[category]!.keys);
    }
    return units;
  }

  String _getUnitOptionLabel(String unitCode) {
    if (unitCode == '--') return _s('-- bez jednotky --', '-- no unit --');
    return '$unitCode (${_getUnitSpeech(unitCode)})';
  }

  void _showCreateStatsSetDialog(
    BuildContext context, {
    List<StatisticsRecord>? recordsToRepeat,
    List<StatisticsRecord>? recordsToSave,
  }) {
    final l10n = _l10n;
    final defaultName = l10n.statsSetDefaultName(_statsSets.length + 1);
    final controller = TextEditingController(text: defaultName);
    final fieldControllers = <TextEditingController>[
      TextEditingController(text: 'Hodnota'),
    ];
    final fieldUnitValues = <String>['--'];

    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsSetsCreate),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: false,
              insetPadding: _dialogInsetPadding(),
              title: Semantics(header: true, child: Text(l10n.statsSetsCreate)),
              content: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Semantics(
                        label: l10n.statsSetNameLabel,
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.statsSetNameLabel,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _s('Názvy a jednotky polí:', 'Field names and units:'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(fieldControllers.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildResponsiveFieldRow(
                            fieldWidget: Semantics(
                              label: '${_s("Pole", "Field")} ${i + 1}',
                              child: TextField(
                                controller: fieldControllers[i],
                                decoration: InputDecoration(
                                  labelText: '${_s("Pole", "Field")} ${i + 1}',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            unitWidget: Semantics(
                              label: _s(
                                'Jednotka pole ${i + 1}',
                                'Unit for field ${i + 1}',
                              ),
                              child: DropdownButtonFormField<String>(
                                value: fieldUnitValues[i],
                                isDense: true,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                ),
                                items: _statsFieldUnitOptions.map((u) {
                                  return DropdownMenuItem(
                                    value: u,
                                    child: Text(
                                      _getUnitOptionLabel(u),
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      fieldUnitValues[i] = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            deleteButton: fieldControllers.length > 1
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    tooltip: _s(
                                      'Odebrat pole ${i + 1}',
                                      'Remove field ${i + 1}',
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        fieldControllers[i].dispose();
                                        fieldUnitValues.removeAt(i);
                                        fieldControllers.removeAt(i);
                                      });
                                    },
                                  )
                                : null,
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(_s('Přidat pole', 'Add field')),
                        onPressed: () {
                          setDialogState(() {
                            fieldControllers.add(
                              TextEditingController(
                                text: _s(
                                  'Pole ${fieldControllers.length + 1}',
                                  'Field ${fieldControllers.length + 1}',
                                ),
                              ),
                            );
                            fieldUnitValues.add('--');
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _returnFocusToKeyboard();
                  },
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      final fieldNames = fieldControllers
                          .map((c) => c.text.trim())
                          .where((n) => n.isNotEmpty)
                          .toList();
                      if (fieldNames.isEmpty) fieldNames.add('Hodnota');
                      final fieldUnits = List<String?>.generate(
                        fieldNames.length,
                        (i) {
                          final unit = i < fieldUnitValues.length
                              ? fieldUnitValues[i]
                              : '--';
                          return unit == '--' ? null : unit;
                        },
                      );
                      setState(() {
                        _statsSets.add(
                          StatisticsSet(
                            name: newName,
                            fieldNames: fieldNames,
                            fieldUnits: fieldUnits,
                            records: [],
                          ),
                        );
                        _currentStatsSetIndex = _statsSets.length - 1;
                        _selectedFieldIndex = 0;
                      });
                      _saveStatsData();
                      Navigator.pop(ctx);

                      final repeatRecords = recordsToRepeat;
                      if (repeatRecords != null && repeatRecords.isNotEmpty) {
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (!mounted) return;
                          speak(
                            _s(
                              'Sada $newName byla vytvořena.',
                              'Set $newName has been created.',
                            ),
                          );
                          if (repeatRecords.length >= 2) {
                            _showStatsSaveReviewDialog(
                              repeatRecords,
                              onConfirm: () => _showRepeatDialog(repeatRecords),
                            );
                          } else {
                            _showRepeatDialog(repeatRecords);
                          }
                        });
                      } else {
                        final saveRecords = recordsToSave;
                        if (saveRecords != null && saveRecords.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (!mounted) return;
                            // Krátký stisk: kontrola proběhne vždy, i pro
                            // jediný záznam (dříve se 1 záznam uložil bez
                            // kontroly). Uložení až po Uložit (×1).
                            _showStatsSaveReviewDialog(saveRecords);
                          });
                        } else {
                          speak(l10n.statsSetCreatedAnnouncement(newName));
                          _returnFocusToKeyboard();
                        }
                      }
                    } else {
                      if (mounted) Navigator.pop(ctx);
                      _returnFocusToKeyboard();
                    }
                  },
                  child: Text(l10n.confirmAction),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteStatsSet(int index) {
    final l10n = _l10n;

    final deletedName = _statsSets[index].name;
    _statsSets.removeAt(index);
    _saveStatsData();

    if (_statsSets.isEmpty) {
      _currentStatsSetIndex = 0;
      speak(
        _s(
          'Sada $deletedName byla smazána. Nejsou vytvořeny žádné sady.',
          'Set $deletedName was deleted. No sets created.',
        ),
      );
      return;
    }

    if (_currentStatsSetIndex >= _statsSets.length) {
      _currentStatsSetIndex = _statsSets.length - 1;
    } else if (_currentStatsSetIndex == index) {
      if (_currentStatsSetIndex >= _statsSets.length) {
        _currentStatsSetIndex = _statsSets.length - 1;
      }
    } else if (_currentStatsSetIndex > index) {
      _currentStatsSetIndex--;
    }

    final activeSetName = _statsSets[_currentStatsSetIndex].name;
    speak(l10n.statsSetDeletedAnnouncement(deletedName, activeSetName));
  }

  void _duplicateStatsSet(int index, VoidCallback onUpdated) {
    final orig = _statsSets[index];
    final copyName = _s('${orig.name} – kopie', '${orig.name} – copy');
    final newSet = StatisticsSet(
      name: copyName,
      fieldNames: List<String>.from(orig.fieldNames),
      fieldUnits: List<String?>.from(orig.fieldUnits),
      records: orig.records
          .map((r) => StatisticsRecord(values: List<double>.from(r.values)))
          .toList(),
      folderId: orig.folderId,
      colorIndex: orig.colorIndex,
      iconName: orig.iconName,
    );
    setState(() => _statsSets.add(newSet));
    _saveStatsData();
    onUpdated();
    // R9: oznamuje pouze SnackBar (dříve speak + snackbar stejné informace).
    if (mounted)
      _showAccessibleSnackBar(
        _s('Sada $copyName zkopírována', 'Set $copyName copied'),
      );
  }

  void _toggleStatsSetPinned(int index, VoidCallback onUpdated) {
    setState(() => _statsSets[index].pinned = !_statsSets[index].pinned);
    _saveStatsData();
    onUpdated();
    final pinned = _statsSets[index].pinned;
    // R4: jednotný kanál (dříve force-bypass přes SR).
    unawaited(
      announceEvent(
        pinned
            ? _s('Sada připnuta', 'Set pinned')
            : _s('Sada odepnuta', 'Set unpinned'),
        category: SpeechCategory.settings,
        interruptCurrentSpeech: true,
      ),
    );
  }

  void _toggleStatsSetArchived(int index, VoidCallback onUpdated) {
    setState(() => _statsSets[index].archived = !_statsSets[index].archived);
    _saveStatsData();
    onUpdated();
    final archived = _statsSets[index].archived;
    // R4: jednotný kanál (dříve force-bypass přes SR).
    unawaited(
      announceEvent(
        archived
            ? _s('Sada archivována', 'Set archived')
            : _s('Sada obnovena', 'Set restored'),
        category: SpeechCategory.settings,
        interruptCurrentSpeech: true,
      ),
    );
  }

  void _showMoveStatsSetDialog(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final set = _statsSets[index];
    String? selectedFolderId = set.folderId;
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Přesunout sadu', 'Move set')),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(
                  _s('Přesunout sadu', 'Move set') + ' "${set.name}"',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String?>(
                      title: Text(_s('Bez složky', 'No folder')),
                      value: null,
                      groupValue: selectedFolderId,
                      onChanged: (v) => setDlg(() => selectedFolderId = v),
                    ),
                    ..._statsFolders.map(
                      (f) => RadioListTile<String?>(
                        title: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _statsColorFor(f.colorIndex),
                              radius: 10,
                              child: Icon(
                                _statsIconFor(f.iconName),
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f.name)),
                          ],
                        ),
                        value: f.id,
                        groupValue: selectedFolderId,
                        onChanged: (v) => setDlg(() => selectedFolderId = v),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final oldFolder = _statsFolderName(set.folderId);
                    final newFolder = _statsFolderName(selectedFolderId);
                    setState(() => set.folderId = selectedFolderId);
                    _saveStatsData();
                    onUpdated();
                    setDlg(() {});
                    Navigator.pop(ctx);
                    // R4: jednotný kanál (dříve force-bypass přes SR).
                    unawaited(
                      announceEvent(
                        _s(
                          'Sada ${set.name} přesunuta z $oldFolder do $newFolder',
                          'Set ${set.name} moved from $oldFolder to $newFolder',
                        ),
                        category: SpeechCategory.settings,
                        interruptCurrentSpeech: true,
                      ),
                    );
                  },
                  child: Text(_s('Přesunout', 'Move')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCopyStatsSetToFolderDialog(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final set = _statsSets[index];
    String? selectedFolderId = set.folderId;
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Kopírovat sadu', 'Copy set')),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(
                  _s('Kopírovat sadu', 'Copy set') + ' "${set.name}"',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _s(
                        'Vyberte cílovou složku pro kopii:',
                        'Select target folder for copy:',
                      ),
                    ),
                    RadioListTile<String?>(
                      title: Text(_s('Bez složky', 'No folder')),
                      value: null,
                      groupValue: selectedFolderId,
                      onChanged: (v) => setDlg(() => selectedFolderId = v),
                    ),
                    ..._statsFolders.map(
                      (f) => RadioListTile<String?>(
                        title: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _statsColorFor(f.colorIndex),
                              radius: 10,
                              child: Icon(
                                _statsIconFor(f.iconName),
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f.name)),
                          ],
                        ),
                        value: f.id,
                        groupValue: selectedFolderId,
                        onChanged: (v) => setDlg(() => selectedFolderId = v),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final copyName = _s(
                      '${set.name} – kopie',
                      '${set.name} – copy',
                    );
                    final newSet = StatisticsSet(
                      name: copyName,
                      fieldNames: List<String>.from(set.fieldNames),
                      fieldUnits: List<String?>.from(set.fieldUnits),
                      records: set.records
                          .map(
                            (r) => StatisticsRecord(
                              values: List<double>.from(r.values),
                            ),
                          )
                          .toList(),
                      folderId: selectedFolderId,
                      colorIndex: set.colorIndex,
                      iconName: set.iconName,
                    );
                    setState(() => _statsSets.add(newSet));
                    _saveStatsData();
                    onUpdated();
                    Navigator.pop(ctx);
                    // R4: jednotný kanál (dříve force-bypass přes SR).
                    unawaited(
                      announceEvent(
                        _s(
                          'Kopie $copyName vytvořena ve složce ${_statsFolderName(selectedFolderId)}',
                          'Copy $copyName created in folder ${_statsFolderName(selectedFolderId)}',
                        ),
                        category: SpeechCategory.settings,
                        interruptCurrentSpeech: true,
                      ),
                    );
                  },
                  child: Text(_s('Kopírovat', 'Copy')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatsColorIconPicker(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final set = _statsSets[index];
    int draftColor = set.colorIndex;
    String draftIcon = set.iconName;
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Barva a ikona', 'Color and icon')),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(
                  _s('Barva a ikona', 'Color and icon') + ' "${set.name}"',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _s('Barva:', 'Color:'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_statsPalette.length, (i) {
                        final selected = draftColor == i;
                        return Semantics(
                          label: _s(
                            'Barva ${i + 1}${selected ? ', vybrána' : ''}',
                            'Color ${i + 1}${selected ? ', selected' : ''}',
                          ),
                          button: true,
                          child: InkWell(
                            onTap: () => setDlg(() => draftColor = i),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _statsPalette[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _s('Ikona:', 'Icon:'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statsIconNames.map((name) {
                        final selected = draftIcon == name;
                        return Semantics(
                          label: _s(
                            'Ikona $name${selected ? ', vybrána' : ''}',
                            'Icon $name${selected ? ', selected' : ''}',
                          ),
                          button: true,
                          child: InkWell(
                            onTap: () => setDlg(() => draftIcon = name),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: selected
                                    ? _statsColorFor(draftColor)
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? Colors.black : Colors.grey,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              child: Icon(
                                _statsIconFor(name),
                                color: selected ? Colors.white : Colors.black54,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: CircleAvatar(
                        backgroundColor: _statsColorFor(draftColor),
                        radius: 24,
                        child: Icon(
                          _statsIconFor(draftIcon),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      set.colorIndex = draftColor;
                      set.iconName = draftIcon;
                    });
                    _saveStatsData();
                    onUpdated();
                    Navigator.pop(ctx);
                    // R4: jednotný kanál (dříve force-bypass přes SR).
                    unawaited(
                      announceEvent(
                        _s(
                          'Barva a ikona sady ${set.name} změněny',
                          'Color and icon of set ${set.name} changed',
                        ),
                        category: SpeechCategory.settings,
                        interruptCurrentSpeech: true,
                      ),
                    );
                  },
                  child: Text(_l10n.confirmAction),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateStatsFolderDialog(
    BuildContext context,
    VoidCallback onUpdated,
  ) {
    final controller = TextEditingController();
    int draftColor = 0;
    String draftIcon = 'folder';
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Nová složka', 'New folder')),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              scrollable: false,
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(_s('Nová složka', 'New folder')),
              ),
              content: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: _s('Název složky', 'Folder name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: List.generate(
                      _statsPalette.length,
                      (i) => ChoiceChip(
                        label: Text('${i + 1}'),
                        selected: draftColor == i,
                        onSelected: (_) => setDlg(() => draftColor = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _statsIconNames
                        .map(
                          (n) => ChoiceChip(
                            label: Icon(_statsIconFor(n), size: 16),
                            selected: draftIcon == n,
                            onSelected: (_) => setDlg(() => draftIcon = n),
                          ),
                        )
                        .toList(),
                  ),
                ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isEmpty) {
                      // R4: jednotný kanál (dříve force-bypass přes SR).
                      unawaited(
                        announceEvent(
                          _s(
                            'Název nesmí být prázdný',
                            'Name must not be empty',
                          ),
                          category: SpeechCategory.error,
                          interruptCurrentSpeech: true,
                        ),
                      );
                      return;
                    }
                    if (_statsFolders.any(
                      (f) => f.name.toLowerCase() == name.toLowerCase(),
                    )) {
                      unawaited(
                        announceEvent(
                          _s(
                            'Složka s tímto názvem již existuje',
                            'Folder with this name already exists',
                          ),
                          category: SpeechCategory.error,
                          interruptCurrentSpeech: true,
                        ),
                      );
                      return;
                    }
                    final folder = StatisticsFolder(
                      id: _generateStatsId(),
                      name: name,
                      colorIndex: draftColor,
                      iconName: draftIcon,
                      sortOrder: _statsFolders.length,
                    );
                    setState(() => _statsFolders.add(folder));
                    _saveStatsData();
                    onUpdated();
                    Navigator.pop(ctx);
                    // R4: jednotný kanál (dříve force-bypass přes SR).
                    unawaited(
                      announceEvent(
                        _s('Složka $name vytvořena', 'Folder $name created'),
                        category: SpeechCategory.settings,
                        interruptCurrentSpeech: true,
                      ),
                    );
                  },
                  child: Text(_l10n.confirmAction),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRenameStatsFolderDialog(
    BuildContext context,
    StatisticsFolder folder,
    VoidCallback onUpdated,
  ) {
    final controller = TextEditingController(text: folder.name);
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(
        name: _s('Přejmenovat složku', 'Rename folder'),
      ),
      builder: (ctx) {
        return AlertDialog(
          scrollable: false,
          insetPadding: _dialogInsetPadding(),
          title: Semantics(
            header: true,
            child: Text(_s('Přejmenovat složku', 'Rename folder')),
          ),
          content: SingleChildScrollView(
            child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _s('Název složky', 'Folder name'),
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                setState(() => folder.name = newName);
                _saveStatsData();
                onUpdated();
                Navigator.pop(ctx);
                // R4: jednotný kanál (dříve force-bypass přes SR).
                unawaited(
                  announceEvent(
                    _s(
                      'Složka přejmenována na $newName',
                      'Folder renamed to $newName',
                    ),
                    category: SpeechCategory.settings,
                    interruptCurrentSpeech: true,
                  ),
                );
              },
              child: Text(_l10n.confirmAction),
            ),
          ],
        );
      },
    );
  }

  void _showManageFoldersDialog(BuildContext context, VoidCallback onUpdated) {
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Správa složek', 'Manage folders')),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Text(_s('Správa složek', 'Manage folders')),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_statsFolders.isEmpty)
                        Text(
                          _s('Žádné složky', 'No folders'),
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ..._statsFolders.map(
                        (f) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statsColorFor(f.colorIndex),
                            child: Icon(
                              _statsIconFor(f.iconName),
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: Text(f.name),
                          subtitle: Text(
                            _s(
                              '${_statsSets.where((s) => s.folderId == f.id).length} sad',
                              '${_statsSets.where((s) => s.folderId == f.id).length} sets',
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'rename')
                                _showRenameStatsFolderDialog(ctx, f, () {
                                  onUpdated();
                                  setDlg(() {});
                                });
                              if (v == 'color') {
                                int dc = f.colorIndex;
                                String di = f.iconName;
                                showAppDialog<void>(
                                  context: ctx,
                                  builder: (c2) => StatefulBuilder(
                                    builder: (c2, s2) => AlertDialog(
                                      title: Semantics(
                                        header: true,
                                        child: Text(
                                          _s('Barva a ikona', 'Color and icon'),
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            children: List.generate(
                                              _statsPalette.length,
                                              (i) => ChoiceChip(
                                                label: Text('${i + 1}'),
                                                selected: dc == i,
                                                onSelected: (_) =>
                                                    s2(() => dc = i),
                                              ),
                                            ),
                                          ),
                                          Wrap(
                                            spacing: 6,
                                            children: _statsIconNames
                                                .map(
                                                  (n) => ChoiceChip(
                                                    label: Icon(
                                                      _statsIconFor(n),
                                                      size: 16,
                                                    ),
                                                    selected: di == n,
                                                    onSelected: (_) =>
                                                        s2(() => di = n),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c2),
                                          child: Text(_l10n.cancel),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            setState(
                                              () => {
                                                f.colorIndex = dc,
                                                f.iconName = di,
                                              },
                                            );
                                            _saveStatsData();
                                            onUpdated();
                                            setDlg(() {});
                                            Navigator.pop(c2);
                                          },
                                          child: Text(_l10n.confirmAction),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              if (v == 'delete') {
                                showAppDialog<void>(
                                  context: ctx,
                                  builder: (c2) => AlertDialog(
                                    title: Semantics(
                                      header: true,
                                      child: Text(
                                        _s('Smazat složku?', 'Delete folder?'),
                                      ),
                                    ),
                                    content: Text(
                                      _s(
                                        'Složka ${f.name} bude smazána, sady zůstanou v Bez složky.',
                                        'Folder ${f.name} will be deleted, sets will remain in No folder.',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c2),
                                        child: Text(_l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          setState(() {
                                            _statsFolders.remove(f);
                                            for (final s in _statsSets) {
                                              if (s.folderId == f.id)
                                                s.folderId = null;
                                            }
                                          });
                                          _saveStatsData();
                                          onUpdated();
                                          setDlg(() {});
                                          Navigator.pop(c2);
                                          // R4: jednotný kanál (dříve force-bypass přes SR).
                                          unawaited(
                                            announceEvent(
                                              _s(
                                                'Složka ${f.name} smazána',
                                                'Folder ${f.name} deleted',
                                              ),
                                              category: SpeechCategory.settings,
                                              interruptCurrentSpeech: true,
                                            ),
                                          );
                                        },
                                        child: Text(_s('Smazat', 'Delete')),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(_s('Přejmenovat', 'Rename')),
                              ),
                              PopupMenuItem(
                                value: 'color',
                                child: Text(_s('Barva/ikona', 'Color/icon')),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(_s('Smazat', 'Delete')),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      FilledButton.icon(
                        onPressed: () => _showCreateStatsFolderDialog(ctx, () {
                          onUpdated();
                          setDlg(() {});
                        }),
                        icon: const Icon(Icons.create_new_folder),
                        label: Text(_s('Nová složka', 'New folder')),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @visibleForTesting
  void showEditStatsSetDialogForTest(BuildContext context, int index) {
    _showEditStatsSetDialog(context, index, () {});
  }

  @visibleForTesting
  void addStatsSetForTest(StatisticsSet set) {
    setState(() {
      _statsSets.add(set);
      _currentStatsSetIndex = _statsSets.length - 1;
    });
  }

  @visibleForTesting
  void showStatsSummaryDialogForTest() {
    _showStatisticsSummaryDialog();
  }

  @visibleForTesting
  void showRenameStatsSetDialogForTest(int index) {
    _showRenameStatsSetDialog(context, index, () {});
  }

  @visibleForTesting
  void showStatsSetsDialogForTest() {
    _showStatsSetsDialog();
  }

  @visibleForTesting
  void showAccessibilityDialogForTest() {
    _showAccessibilityDialog();
  }

  @visibleForTesting
  void showAdvancedDialogForTest() {
    _showAdvancedFunctionsDialog();
  }

  @visibleForTesting
  void showTutorialDialogForTest() {
    _showTutorialDialog();
  }

  @visibleForTesting
  void showInitialAccessibilityDialogForTest() {
    // Starý uvítací dialog nahrazen jednotným Quick Setup.
    _openQuickSetupManually();
  }

  @visibleForTesting
  Future<void> showQuickSetupDialogForTest({bool isFirstRun = false}) async {
    final draft = QuickSetupDraft.fromRuntime(
      settings: _getActiveAccessibilityProfile().settings,
      themeMode: widget.themeMode,
      isDegreeMode: _isDegreeMode,
      defaultMode: _defaultMode,
      resultDisplayMode: _globalResultDisplayMode,
    );
    return showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Rychlé nastavení'),
      builder: (dialogContext) => QuickSetupDialog(
        initialDraft: draft,
        availableVoices: Future.value(const <Map<String, String>>[]),
        tr: _s,
        isFirstRun: isFirstRun,
        announce: (msg) => say(msg, dialogContext),
        onCancel: () => Navigator.of(dialogContext).pop(),
        onApply: (next) => _applyQuickSetup(next, dialogContext),
      ),
    );
  }

  @visibleForTesting
  AccessibilityType get displayAccessibilityTypeForTest =>
      _accessibilityType == AccessibilityType.none
      ? AccessibilityType.visuallyImpaired
      : _accessibilityType;

  @visibleForTesting
  double get keyboardFontScaleForTest => _keyboardFontScale;

  @visibleForTesting
  double get dialogFontScaleForTest => _dialogFontScale;

  @visibleForTesting
  double get dotMatrixZoomForTest => _dotMatrixZoom;

  @visibleForTesting
  double get resultZoomForTest => _resultZoom;

  @visibleForTesting
  double get overlineThicknessForTest => _overlineThickness;

  @visibleForTesting
  double get overlineHeightForTest => _overlineHeight;

  @visibleForTesting
  List<AccessibilityProfile> get profilesForTest => _profiles;

  @visibleForTesting
  bool get profilesLoadedForTest => _profilesLoaded;

  @visibleForTesting
  void setKeyboardFontScaleForTest(double value) {
    updateActiveAccessibilitySettings(
      (s) => s.copyWith(fontSizeMultiplier: value),
    );
  }

  @visibleForTesting
  void switchProfileForTest(String id) {
    final p = _profiles.firstWhere(
      (e) => e.id == id,
      orElse: () => _getActiveAccessibilityProfile(),
    );
    applyAccessibilityProfile(p);
  }

  @visibleForTesting
  void updateActiveSettingsForTest(dynamic Function(dynamic) upd) {
    updateActiveAccessibilitySettings((s) => upd(s) as AccessibilitySettings);
  }

  @visibleForTesting
  void createProfileForTest(String name, String baseId) {
    final base = _profiles.firstWhere(
      (p) => p.id == baseId,
      orElse: () => _getActiveAccessibilityProfile(),
    );
    final newProfile = AccessibilityProfile(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}_${name.hashCode.abs()}',
      name: name,
      isBuiltIn: false,
      settings: base.settings.copyWith(),
    );
    setState(() {
      _profiles.add(newProfile);
      _activeProfileId = newProfile.id;
    });
    _applyActiveProfileToState();
    _saveProfilesV2();
  }

  @visibleForTesting
  void resetActiveProfileForTest() => _resetActiveProfile();

  @visibleForTesting
  void deleteProfileForTest(String id) => _deleteProfile(id);

  @visibleForTesting
  String get activeProfileIdForTest => _activeProfileId;

  @visibleForTesting
  AccessibilitySettings get activeSettingsForTest =>
      activeAccessibilitySettings;

  @visibleForTesting
  AccessibilityProfile? get editingDraftForTest => _editingDraft;

  @visibleForTesting
  String? get editingProfileIdForTest => _editingProfileId;

  @visibleForTesting
  ValueNotifier<double> get dialogFontScaleNotifierForTest =>
      _dialogFontScaleNotifier;

  @visibleForTesting
  ThemeMode get themeModeForTest => widget.themeMode;

  @visibleForTesting
  bool startEditingForTest(String id) => startEditingProfile(id);

  @visibleForTesting
  void updateEditingForTest(
    AccessibilitySettings Function(AccessibilitySettings) upd,
  ) => updateEditingSettings(upd);

  @visibleForTesting
  Future<bool> saveEditingForTest() => saveEditingProfile();

  @visibleForTesting
  void discardEditingForTest() => discardEditingProfile();

  @visibleForTesting
  Future<void> resetProfileForTest(String id) => resetProfile(id);

  @visibleForTesting
  ThousandGroupGap get thousandGroupGapForTest => _thousandGroupGap;

  @visibleForTesting
  bool get announceExpressionForTest => _announceExpression;

  @visibleForTesting
  double get speechRateForTest => _speechRate;

  @visibleForTesting
  void showDeleteStatsSetConfirmationForTest(int index) {
    _showDeleteStatsSetConfirmation(context, index, () {});
  }

  @visibleForTesting
  void showClearHistoryConfirmationForTest() {
    _showClearHistoryConfirmation();
  }

  @visibleForTesting
  String get displayForTest => display;

  @visibleForTesting
  set displayForTest(String v) {
    setState(() {
      display = v;
      _cursorPosition = v.length;
    });
  }

  @visibleForTesting
  void setDisplayForTest(String v, int cursorPos) {
    setState(() {
      display = v;
      _cursorPosition = cursorPos.clamp(0, v.length);
    });
  }

  @visibleForTesting
  int get cursorForTest => _cursorPosition;

  @visibleForTesting
  void setCursorForTest(int pos) {
    setState(() {
      _cursorPosition = pos.clamp(0, display.length);
    });
  }

  /// Aktuální derivovaná hodnota a11y proxy (text + collapsed selection).
  @visibleForTesting
  TextEditingValue get a11yProxyValueForTest => _displayA11yController.value;

  @visibleForTesting
  FocusNode get a11yProxyFocusNodeForTest => _displayA11yFocusNode;

  /// Z1: stav režimu ovládání výrazu.
  @visibleForTesting
  bool get expressionControlActiveForTest => _expressionControlActive;

  /// Z1: přímé nastavení režimu (pro test deaktivovaného stavu).
  @visibleForTesting
  void setExpressionControlActiveForTest(bool value) {
    _expressionControlActive = value;
  }

  /// Z1-dokončení: důvod vypnutí režimu pro testy (`none/traversal/dialog`).
  @visibleForTesting
  String get expressionControlOffReasonForTest =>
      _expressionControlOffReason.name;

  /// Z1-reaktivace-po-dialogu: hloubka otevřených dialogů pro testy.
  @visibleForTesting
  int get dialogDepthForTest => _dialogDepth;

  /// Z1: přímé volání klávesového handleru včetně návratové hodnoty
  /// (`handled`/`ignored`) pro testy konzumace.
  @visibleForTesting
  KeyEventResult handleKeyEventForTest(KeyEvent event) =>
      _handleKeyboardInput(_mainFocusNode, event);

  /// Z1: kořenový fokusový uzel klávesnice.
  @visibleForTesting
  FocusNode get mainFocusNodeForTest => _mainFocusNode;

  /// Z5: fokusový uzel výsledkového řádku (Tab/Shift+Tab).
  @visibleForTesting
  FocusNode get resultFocusNodeForTest => _resultFocusNode;

  /// Z5: zda má výsledkový řádek právě klávesnicový fokus.
  @visibleForTesting
  bool get resultHasFocusForTest => _resultHasFocus;

  /// Lidská věta o pozici kurzoru (viz [_cursorPositionSpeech]).
  @visibleForTesting
  String cursorSpeechForTest() => _cursorPositionSpeech();

  /// Vstup AT selection do stavového stroje (viz [_handleA11ySelectionChanged]).
  @visibleForTesting
  void handleA11ySelectionForTest(TextSelection selection) =>
      _handleA11ySelectionChanged(selection, null);

  @visibleForTesting
  void backspaceForTest() => backspace();

  @visibleForTesting
  void calculateForTest() => calculateResult();

  @visibleForTesting
  String get lastResultForTest => _lastResult;

  @visibleForTesting
  void setLastResultForTest(String v) {
    _lastResult = v;
  }

  @visibleForTesting
  void setHasResultForTest(bool v) {
    _hasResult = v;
  }

  @visibleForTesting
  String get displayedResultForTest => _displayedResultString;

  @visibleForTesting
  String activeResultForTest() => _activeResultString();

  @visibleForTesting
  CalcValue? get lastExactForTest =>
      (_lastExact is SurdValue && _lastExactKey == _lastResult)
      ? _lastExact
      : null;

  @visibleForTesting
  void toggleFractionForTest() => toggleFractionResultView();

  @visibleForTesting
  bool get fractionViewForTest => _isShowingFraction();

  @visibleForTesting
  bool get fractionEligibleForTest => _isFractionEligible;

  @visibleForTesting
  String? get fractionStringForTest => _fractionString;

  @visibleForTesting
  String get fractionViewKeyForTest => _fractionViewKey;

  @visibleForTesting
  Rational? get lastRationalForTest => _validRational;

  @visibleForTesting
  String? fractionTargetKindForTest() =>
      _fractionTargetKindAfterNextPress()?.name;

  @visibleForTesting
  bool get showingFractionForTest => _isShowingFraction();

  @visibleForTesting
  String currentResultSpeechForTest() => _currentResultSpeech();

  @visibleForTesting
  double? get lastNumericForTest => _lastNumericValue;

  @visibleForTesting
  void clearForTest() => clear();

  @visibleForTesting
  void setResultDisplayModeForTest(ResultDisplayMode m) {
    setGlobalResultDisplayMode(m);
  }

  @visibleForTesting
  ResultDisplayMode get resultDisplayModeForTest => _globalResultDisplayMode;

  @visibleForTesting
  HistoryExactFormat get historyExactFormatForTest => _historyExactFormat;

  @visibleForTesting
  void setHistoryExactFormatForTest(HistoryExactFormat f) {
    setState(() => _historyExactFormat = f);
  }

  @visibleForTesting
  List<CalculationHistoryEntry> get historyForTest =>
      List.unmodifiable(_history);

  @visibleForTesting
  void addHistoryEntryForTest(CalculationHistoryEntry e) {
    setState(() => _history.insert(0, e));
  }

  @visibleForTesting
  void showHistoryDialogForTest() => _showHistoryDialog();

  @visibleForTesting
  Future<void> openEditorDialogForTest() {
    return showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'editor-test'),
      builder: (ctx) => _AccessibilityProfileEditorDialog(parent: this),
    );
  }

  @visibleForTesting
  Future<void> handleButtonPressedForTest(String label) =>
      _handleButtonPressed(label);

  @visibleForTesting
  double evaluateExpressionForTest(String expr) => _evaluateExpression(expr);

  /// Klasifikace zbytkového non-finite výsledku pro testy.
  @visibleForTesting
  CalcError classifyResidualForTest(double value) =>
      _classifyResidualNonFinite(value, 'test');

  /// Read-only hodnota pro Info o čísle (display -> _lastNumericValue).
  /// Vrací null, není-li dostupná žádná hodnota nebo je výraz chybný.
  @visibleForTesting
  double? resolveNumberInfoForTest() => _resolveNumberInfoValue().value;

  @visibleForTesting
  String formatNumberForTest(double v) => _formatNumber(v);

  @visibleForTesting
  String formatNumberSmartForTest(double v) => _formatNumberSmart(v);

  @visibleForTesting
  String? tryAutoExponentialForTest(double v) => _tryAutoExponential(v);

  @visibleForTesting
  String spokenForDisplayForTest(String t) => _spokenForDisplay(t);

  @visibleForTesting
  String formatForSpeechForTest(String t) => _formatForSpeech(t);

  @visibleForTesting
  String numberToSpeechForTest(String t) => _numberToSpeech(t);

  @visibleForTesting
  String sentenceToSpeechForTest(String t) => _sentenceToSpeech(t);

  @visibleForTesting
  Future<void> announceEventForTest(
    String message, {
    required SpeechCategory category,
    bool isNumeric = false,
    bool interruptCurrentSpeech = false,
  }) => announceEvent(
    message,
    category: category,
    isNumeric: isNumeric,
    interruptCurrentSpeech: interruptCurrentSpeech,
  );

  /// Poslední publikované oznámení Semantics kanálem (bez ohledu na kanál).
  @visibleForTesting
  String get lastAnnouncementForTest => _lastPublishedAnnouncement;

  /// Počet publikování Semantics kanálem (Z3-krok 0, pouze pro testy).
  @visibleForTesting
  int get publishedAnnouncementCountForTest => _publishedAnnouncementCount;

  @visibleForTesting
  bool? get isScreenReaderActiveForTest => _isScreenReaderActive;

  @visibleForTesting
  String formatSpokenNumberForTest(double v) => _formatSpokenNumber(v);

  @visibleForTesting
  void setMemoryForTest(String key, double value) {
    // Odpovídá reálnému uložení (STO): zápis hodnoty + příznak obsazenosti
    // (i pro explicitní 0). Pro přípravu prázdné paměti použít
    // clearMemoryStateForTest(), ne nuly přes tento helper.
    setState(() {
      _memory[key] = value;
      _memoryOccupied.add(key);
    });
  }

  /// Explicitní reset paměti pro testy: vynuluje hodnoty a vyčistí obsazenost
  /// i racionální vazby. Jediná správná cesta, jak připravit prázdnou paměť.
  @visibleForTesting
  void clearMemoryStateForTest() {
    setState(() {
      _memory.updateAll((key, value) => 0);
      _memoryOccupied.clear();
      _rationalMemory.clear();
    });
  }

  /// Znovu načte paměť z prefs stejným produkčním kódem jako startup
  /// ([_applyMemoryPrefs]). Slouží testům persistence bez spoléhání na
  /// načasování úvodního preloadu.
  @visibleForTesting
  Future<void> reloadMemoryForTest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _applyMemoryPrefs(prefs));
  }

  @visibleForTesting
  Map<String, double> get memoryForTest => Map.unmodifiable(_memory);

  /// Obsazené proměnné pro testy (včetně explicitně uložené 0).
  @visibleForTesting
  Set<String> get occupiedMemoryForTest => Set.unmodifiable(_memoryOccupied);

  /// Racionální vazby pro testy (runtime-only, klíčováno jménem proměnné).
  @visibleForTesting
  Map<String, Rational> get rationalMemoryForTest =>
      Map.unmodifiable(_rationalMemory);

  @visibleForTesting
  bool get isStoreModeForTest => _isStoreMode;

  @visibleForTesting
  bool get isRecallModeForTest => _isRecallMode;

  @visibleForTesting
  void showQuickMemoryDialogForTest() => _showQuickMemoryDialog();

  @visibleForTesting
  void showClearMemoryConfirmationForTest({BuildContext? dialogContext}) =>
      _showClearMemoryConfirmation(dialogContext: dialogContext);

  @visibleForTesting
  void setDisplayFormatForTest(DisplayFormat f) {
    setState(() => _displayFormat = f);
  }

  @visibleForTesting
  void setPrecisionForTest(int p) {
    setState(() => _precision = p);
  }

  @visibleForTesting
  Future<void> addSingleValueToStatsForTest() => _addSingleValueToStats();

  @visibleForTesting
  Future<void> handleMultipleStatisticsAdditionForTest() =>
      _handleMultipleStatisticsAddition();

  @visibleForTesting
  String getStatsCountFormForTest(int count) => _getStatsCountForm(count);

  @visibleForTesting
  List<StatisticsRecord> get statsMemoryForTest =>
      List.unmodifiable(_statsMemory);

  @visibleForTesting
  double? memoryValueForTest(String name) => _memory[name];

  @visibleForTesting
  int get statsSetsCountForTest => _statsSets.length;

  @visibleForTesting
  String get currentStatsSetNameForTest =>
      _statsSets.isEmpty ? '' : _statsSets[_currentStatsSetIndex].name;

  @visibleForTesting
  BuildContext get contextForTest => context;

  @visibleForTesting
  void switchModeForTest(CalculatorMode mode) => _changeMode(mode);

  @visibleForTesting
  void toggleScientificPageForTest() => _toggleScientificFunctionsPage();

  @visibleForTesting
  bool get scientificFunctionsPageForTest => _scientificFunctionsPage;

  @visibleForTesting
  CalculatorMode get currentModeForTest => _currentMode;

  void _showDeleteStatsSetConfirmation(
    BuildContext context,
    int index,
    VoidCallback onUpdated,
  ) {
    final name = _statsSets[index].name;
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Smazat sadu?', 'Delete set?')),
      builder: (ctx) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(_s('Smazat sadu?', 'Delete set?')),
        ),
        content: Text(
          _s(
            'Opravdu smazat sadu "$name"? Tato akce je nevratná.',
            'Really delete set "$name"? This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteStatsSet(index);
              onUpdated();
            },
            child: Text(_s('Smazat', 'Delete')),
          ),
        ],
      ),
    );
  }

  // --- Helpers pro diakritiku: vstup bez háčků, čtení s háčky ---
  static const Map<String, String> _diacriticsRestoreMap = {
    'hodnota': 'Hodnota',
    'vaha': 'Váha',
    'vyska': 'Výška',
    'sirka': 'Šířka',
    'delka': 'Délka',
    'hmotnost': 'Hmotnost',
    'cas': 'Čas',
    'teplota': 'Teplota',
    'tlak': 'Tlak',
    'objem': 'Objem',
    'obsah': 'Obsah',
    'cena': 'Cena',
    'mnozstvi': 'Množství',
    'pocet': 'Počet',
    'prumer': 'Průměr',
    'soucet': 'Součet',
    'rychlost': 'Rychlost',
    'sila': 'Síla',
    'vykon': 'Výkon',
    'odpor': 'Odpor',
    'proud': 'Proud',
    'napeti': 'Napětí',
    'skola': 'Škola',
    'mereni': 'Měření',
    'skolni': 'Školní',
    'test': 'Test',
  };

  String _stripDiacritics(String input) {
    const map = {
      'á': 'a',
      'č': 'c',
      'ď': 'd',
      'é': 'e',
      'ě': 'e',
      'í': 'i',
      'ň': 'n',
      'ó': 'o',
      'ř': 'r',
      'š': 's',
      'ť': 't',
      'ú': 'u',
      'ů': 'u',
      'ý': 'y',
      'ž': 'z',
      'Á': 'A',
      'Č': 'C',
      'Ď': 'D',
      'É': 'E',
      'Ě': 'E',
      'Í': 'I',
      'Ň': 'N',
      'Ó': 'O',
      'Ř': 'R',
      'Š': 'S',
      'Ť': 'T',
      'Ú': 'U',
      'Ů': 'U',
      'Ý': 'Y',
      'Ž': 'Z',
    };
    var out = input;
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  String _normalizeAnswer(String input) {
    return _stripDiacritics(
      input.toLowerCase().replaceAll(RegExp(r'[.,!?;:\"]'), ''),
    ).trim();
  }

  String _restoreDiacritics(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    final key = _stripDiacritics(trimmed.toLowerCase());
    final restored = _diacriticsRestoreMap[key];
    if (restored != null) {
      // Zachovej kapitalizaci prvního písmene podle originálu.
      if (trimmed[0] == trimmed[0].toUpperCase()) return restored;
      return restored[0].toLowerCase() + restored.substring(1);
    }
    return trimmed;
  }

  int? _parseNumberAnswer(String input) {
    final norm = _normalizeAnswer(input);
    if (norm.isEmpty) return null;
    const words = {
      'jedna': 1,
      'jedno': 1,
      'dva': 2,
      'tri': 3,
      'ctyri': 4,
      'pet': 5,
      'sest': 6,
      'sedm': 7,
      'osm': 8,
      'devet': 9,
      'deset': 10,
    };
    if (words.containsKey(norm)) return words[norm]!;
    return int.tryParse(norm);
  }

  /// Šířkové chování dialogů podle uživatelské volby DialogSize.
  /// Záměrně BEZ jakéhokoliv odečtu `viewInsets.bottom`: jediným vlastníkem
  /// keyboard insetu je frameworkový Dialog. Výškový limit je odvozen
  /// z plné výšky obrazovky a slouží pouze jako bounded height pro vnitřní
  /// scroll (ListView/SingleChildScrollView), nikoliv jako simulace klávesnice.
  Widget _applyDialogSize(Widget child) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    switch (_dialogSize) {
      case DialogSize.compact:
        return SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.65),
            child: child,
          ),
        );
      case DialogSize.wide:
        return SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.85),
            child: child,
          ),
        );
      case DialogSize.fullscreen:
        return SizedBox.expand(child: child);
    }
  }

  /// Stabilní vizuální odsazení dialogu. Klávesnici řeší výhradně
  /// frameworkový Dialog (viewInsets + insetPadding), proto zde není
  /// žádná keyboard-specific větev.
  EdgeInsets _dialogInsetPadding() {
    const vertical = 24.0;
    switch (_dialogSize) {
      case DialogSize.compact:
        return EdgeInsets.symmetric(horizontal: 40, vertical: vertical);
      case DialogSize.wide:
        return EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.04,
          vertical: vertical,
        );
      case DialogSize.fullscreen:
        return EdgeInsets.zero;
    }
  }

  /// Read-only rozlišení hodnoty pro dialog Info o čísle.
  /// Priorita: 1. neprázdný display -> stejná cesta _evaluateExpression
  /// jako hlavní kalkulace (žádná duplicitní logika); 2. prázdný display ->
  /// _lastNumericValue; 3. nic dostupného -> value null (volající ukáže
  /// infoNoResult). Při chybě výrazu vrací příslušný CalcError pro přesnou
  /// hlášku. Nikdy nevolá setState ani nemění kalkulační stav.
  ({double? value, CalcError? error}) _resolveNumberInfoValue() {
    if (display.trim().isNotEmpty) {
      try {
        final evaluated = _evaluateExpression(display);
        if (!evaluated.isFinite) {
          return (
            value: null,
            error: _classifyResidualNonFinite(evaluated, display),
          );
        }
        return (value: evaluated, error: null);
      } on CalcError catch (e) {
        return (value: null, error: e);
      } catch (e) {
        debugPrint('Unexpected number-info error: $e');
        return (
          value: null,
          error: const CalcError(
            CalcErrorKind.invalidOperation,
            CalcErrorReason.unknown,
          ),
        );
      }
    }
    final last = _lastNumericValue;
    if (last != null && last.isFinite) {
      return (value: last, error: null);
    }
    return (value: null, error: null);
  }

  void _showNumberInfoDialog() {
    final l10n = _l10n;
    final resolved = _resolveNumberInfoValue();
    final value = resolved.value;
    if (value == null) {
      final err = resolved.error;
      final msg = err == null ? l10n.infoNoResult : _messageForCalcError(err);
      // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
      if (mounted) {
        _showAccessibleSnackBar(msg);
      }
      return;
    }

    bool isInteger = value == value.roundToDouble() && value.isFinite;
    bool isPosInt = isInteger && value > 0;
    int intVal = value.round();

    String fraction = _decimalToFraction(value);
    String fractionSpoken = fraction
        .replaceAll('/', _s(' lomeno ', ' over '))
        .replaceAll('.', ',');

    String dmsStr = _formatAsDMS(value);
    String dmsSpoken = dmsStr
        .replaceAll('°', _s(' stupňů ', ' degrees '))
        .replaceAll('\'', _s(' minut ', ' minutes '))
        .replaceAll('"', _s(' sekund', ' seconds'))
        .replaceAll('.', ',');

    String percent = '${_formatNumber(value * 100)} %';
    String percentSpoken =
        '${_formatSpokenNumber(value * 100)} '
        '${_s('procent', 'percent')}';

    String factorsStr = '';
    String factorsSpoken = '';
    if (isPosInt && intVal >= 2) {
      List<int> factors = _primeFactors(intVal);
      factorsStr = factors.join(' × ');
      factorsSpoken = factors.join(_s(' krát ', ' times '));
    }

    String divisorsStr = '';
    String divisorsSpoken = '';
    if (isPosInt) {
      List<int> divs = _getDivisors(intVal);
      divisorsStr = divs.join(', ');
      divisorsSpoken = divs.join(', ');
    }

    String formattedValue = _formatNumber(value);
    String spokenValue = _formatSpokenNumber(value);

    final spokenText = _s(
      'Info o čísle. Hodnota: $spokenValue. '
          'Zlomek: $fractionSpoken. '
          'DMS: $dmsSpoken. '
          'Procenta: $percentSpoken. '
          '${factorsSpoken.isNotEmpty ? 'Rozklad na prvočísla: $factorsSpoken. ' : ''}'
          '${divisorsSpoken.isNotEmpty ? 'Dělitele: $divisorsSpoken.' : ''}',
      'Number info. Value: $spokenValue. '
          'Fraction: $fractionSpoken. '
          'DMS: $dmsSpoken. '
          'Percentage: $percentSpoken. '
          '${factorsSpoken.isNotEmpty ? 'Prime factors: $factorsSpoken. ' : ''}'
          '${divisorsSpoken.isNotEmpty ? 'Divisors: $divisorsSpoken.' : ''}',
    );

    String notIntMsg = l10n.infoNotInteger;
    String naMsg = l10n.infoNotApplicable;

    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.numberInfo),
      builder: (dialogContext) {
        DialogSize currentSize = _dialogSize;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool isInfoFullscreen = currentSize == DialogSize.fullscreen;
            return AlertDialog(
              insetPadding: _dialogInsetPadding(),
              title: Semantics(
                header: true,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.numberInfo)),
                    Semantics(
                      label: isInfoFullscreen
                          ? _s('Zmenšit dialog', 'Minimize dialog')
                          : _s('Zvětšit dialog', 'Maximize dialog'),
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          isInfoFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                        ),
                        tooltip: isInfoFullscreen
                            ? _s('Zmenšit', 'Minimize')
                            : _s('Zvětšit', 'Maximize'),
                        onPressed: () {
                          setDialogState(() {
                            currentSize = isInfoFullscreen
                                ? DialogSize.wide
                                : DialogSize.fullscreen;
                          });
                          speak(
                            isInfoFullscreen
                                ? _s('Dialog zmenšen', 'Dialog minimized')
                                : _s('Dialog zvětšen', 'Dialog maximized'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              content: _applyDialogSize(
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoCard(
                        label: l10n.infoValue,
                        value: formattedValue,
                        spoken: '${l10n.infoValue}: $spokenValue',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoCard(
                        label: l10n.infoFraction,
                        value: fraction,
                        spoken: '${l10n.infoFraction}: $fractionSpoken',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoCard(
                        label: l10n.infoDms,
                        value: dmsStr,
                        spoken: '${l10n.infoDms}: $dmsSpoken',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoCard(
                        label: l10n.infoPercentage,
                        value: percent,
                        spoken: '${l10n.infoPercentage}: $percentSpoken',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoCard(
                        label: l10n.infoPrimeFactors,
                        value: factorsStr.isNotEmpty ? factorsStr : naMsg,
                        spoken: factorsSpoken.isNotEmpty
                            ? '${l10n.infoPrimeFactors}: $factorsSpoken'
                            : '${l10n.infoPrimeFactors}: $notIntMsg',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoCard(
                        label: l10n.infoDivisors,
                        value: divisorsStr.isNotEmpty ? divisorsStr : naMsg,
                        spoken: divisorsSpoken.isNotEmpty
                            ? '${l10n.infoDivisors}: $divisorsSpoken'
                            : '${l10n.infoDivisors}: $notIntMsg',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Semantics(
                  label: _s(
                    'Přečíst všechny informace hlasem',
                    'Read all information aloud',
                  ),
                  button: true,
                  child: TextButton(
                    onPressed: () => speak(spokenText),
                    child: Text(l10n.infoRead),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required String spoken,
  }) {
    return Semantics(
      container: true,
      label: spoken,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: ExcludeSemantics(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDialog() {
    final bool historyEmpty = _history.isEmpty;
    showAppDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Historie výpočtů'),
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(_l10n.historyTitle)),
        content: _applyDialogSize(
          historyEmpty
              ? Semantics(container: true, child: Text(_l10n.emptyHistory))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      final expression = entry.expression;
                      // Vizuální výsledek podle globální volby; vkládání
                      // používá strukturovanou pravdu: racionální metadata
                      // jako (n/d) v závorkách (priorita), jinak numeriku
                      // (nikdy "6√2" ani aproximaci).
                      final displayResult = _historyDisplayResult(entry);
                      final entryRational = entry.rational;
                      final insertResult =
                          (entryRational != null &&
                                  entryRational.denominator != BigInt.one &&
                                  entry.numericResult.isNotEmpty)
                              ? '(${entryRational.numerator}/${entryRational.denominator})'
                              : (entry.numericResult.isNotEmpty
                                  ? entry.numericResult
                                  : expression);

                      // Hlas řádku: racionální tvar jako "n lomeno d",
                      // jinak dosavadní řeč zobrazeného tvaru.
                      final String spokenResult;
                      if (entryRational != null &&
                          entryRational.denominator != BigInt.one) {
                        spokenResult = _s(
                          '${entryRational.numerator} lomeno ${entryRational.denominator}',
                          '${entryRational.numerator} over ${entryRational.denominator}',
                        );
                      } else {
                        spokenResult =
                            _spokenForDisplay(displayResult);
                      }
                      String semanticDescription = _s(
                        "Výpočet: ${_spokenForDisplay(expression)}, výsledek: $spokenResult. Poklepáním vložíte výsledek, přidržením vložíte celý výpočet.",
                        "Calculation: ${_spokenForDisplay(expression)}, result: $spokenResult. Tap to insert the result, hold to insert the whole calculation.",
                      );

                      return Semantics(
                        label: semanticDescription,
                        container: true,
                        child: MergeSemantics(
                          child: ListTile(
                            title: _PeriodicText(
                              expression,
                              style: const TextStyle(fontSize: 14),
                              overlineThickness: _overlineThickness,
                              overlineHeight: _overlineHeight,
                            ),
                            subtitle: displayResult.isNotEmpty
                                ? _PeriodicText(
                                    displayResult,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.blue,
                                    ),
                                    overlineThickness: _overlineThickness,
                                    overlineHeight: _overlineHeight,
                                  )
                                : null,
                            onTap: () => _insertFromHistory(insertResult),
                            onLongPress: () => _insertFromHistory(expression),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: historyEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    _showClearHistoryConfirmation();
                  },
            child: Text(_l10n.clearHistory),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(_l10n.close),
          ),
        ],
      ),
    );
    if (historyEmpty) speak(_l10n.emptyHistory);
  }

  void _showClearHistoryConfirmation() {
    String question = _l10n.deleteConfirmation;
    showAppDialog(
      context: context,
      routeSettings: const RouteSettings(name: 'Potvrzení'),
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(_l10n.confirmationTitle)),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _history.clear();
                _saveHistory();
              });
              // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
              if (mounted) {
                _showAccessibleSnackBar(_l10n.historyCleared);
              }
              Navigator.pop(context);
            },
            child: Semantics(
              label: _l10n.yesConfirmHistory,
              child: Text(_l10n.yesDelete),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Semantics(
              label: _l10n.noCancelHistory,
              child: Text(_l10n.noStay),
            ),
          ),
        ],
      ),
    );
    speak(question);
  }

  /// Názvy obsazených paměťových proměnných v kanonickém pořadí
  /// A,B,C,D,E,F,X,Y,M (včetně explicitně uložené nuly).
  /// Zjišťuje se PŘED vynulováním. Jediný zdroj pro obě cesty mazání;
  /// čistě numerický výběr (value != 0) už žádný volající nepotřebuje.
  List<String> _occupiedMemoryVariableNames() {
    return [for (final k in _memoryOrder) if (_memoryOccupied.contains(k)) k];
  }

  /// Lokalizovaný seznam „A, C a M" / „A, C and M".
  String _formatVariableNameList(List<String> names) {
    if (names.length == 1) return names.first;
    final joinWord = _s(' a ', ' and ');
    if (names.length == 2) return '${names[0]}$joinWord${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')}$joinWord${names.last}';
  }

  /// Potvrzení po smazání: které proměnné byly smazány.
  /// - prázdný seznam → paměť už byla prázdná (netvrdí smazání),
  /// - všech 9 obsazených → krátký souhrn bez vyjmenování,
  /// - 1 proměnná → singulár, jinak plurál s lokalizovaným seznamem.
  String _memoryClearedMessage(List<String> clearedNames) {
    if (clearedNames.isEmpty) return _l10n.memoryAlreadyEmpty;
    if (clearedNames.length >= _memoryOrder.length) {
      return _l10n.memoryClearedAll;
    }
    if (clearedNames.length == 1) {
      return _l10n.memoryClearedSingle(clearedNames.first);
    }
    return _l10n.memoryClearedPartial(
      _formatVariableNameList(clearedNames),
    );
  }

  void _showClearMemoryConfirmation({BuildContext? dialogContext}) {
    final occupied = _occupiedMemoryVariableNames();
    if (occupied.isEmpty) {
      final msg = _l10n.memoryAlreadyEmpty;
      // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
      if (mounted) {
        _showAccessibleSnackBar(msg);
      }
      return;
    }
    final preview = _memoryOrder
        .where((k) => _memoryOccupied.contains(k))
        .map(
          (k) =>
              '$k=${_formatNumberSmart(_memory[k] ?? 0).replaceAll('.', ',')}',
        )
        .join(', ');
    final question = _s(
      'Opravdu chcete smazat všechny proměnné paměti? Aktuálně: $preview.',
      'Really clear all memory variables? Currently: $preview.',
    );
    showAppDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'Potvrdit smazání paměti'),
      builder: (ctx) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(_l10n.confirmationTitle)),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () {
              // Seznam smazaných proměnných zjistit PŘED vynulováním.
              final cleared = _occupiedMemoryVariableNames();
              setState(() {
                _memory.updateAll((key, value) => 0);
                // Racionální vazby se mažou společně s pamětí.
                _rationalMemory.clear();
                _memoryOccupied.clear();
              });
              _saveStatsData();
              final clearedMsg = _memoryClearedMessage(cleared);
              // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
              if (mounted) {
                _showAccessibleSnackBar(clearedMsg);
              }
              Navigator.pop(ctx);
              // Zavřít i rodičovský dialog Pokročilé funkce pokud byl předán
              if (dialogContext != null) {
                // ponechat otevřený – uživatel uvidí prázdnou paměť
              }
            },
            child: Semantics(
              label: _s('Ano, smazat paměť', 'Yes, clear memory'),
              child: Text(_l10n.yesDelete),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Semantics(
              label: _s('Ne, ponechat paměť', 'No, keep memory'),
              child: Text(_l10n.noStay),
            ),
          ),
        ],
      ),
    );
    speak(question);
  }

  void _addValuesToStats(List<StatisticsRecord> records, int count) {
    setState(() {
      for (int i = 0; i < count; i++) {
        _statsMemory.addAll(records.map((r) => r.copyWith()));
      }
      _lastAddedBatch = records
          .map((r) => StatisticsRecord(values: List.from(r.values)))
          .toList();
      display = '';
      _cursorPosition = 0;
    });
    _saveStatsData();

    final setName = _statsSets[_currentStatsSetIndex].name;
    final int totalAdded = records.length * count;
    final int fieldCount = _currentFieldCount;
    String spoken;

    if (totalAdded > 3 || fieldCount > 1) {
      spoken = _s(
        'Přidáno $totalAdded záznamů do sady $setName. V paměti je celkem ${_statsMemory.length} ${_getStatsCountForm(_statsMemory.length)}.',
        'Added $totalAdded records to set $setName. Memory now contains ${_statsMemory.length} ${_getStatsCountForm(_statsMemory.length)}.',
      );
    } else {
      String valuesStr = records
          .map(
            (r) => r.values
                .map((v) => _formatNumber(v).replaceAll('.', ','))
                .join(';'),
          )
          .join(' ');
      String countForm = _getStatsCountForm(_statsMemory.length);

      String countPartCs = count == 1 ? '' : ', $count krát';
      String countPartEn = count == 1 ? '' : ', $count times';

      spoken = _s(
        'Přidáno $valuesStr$countPartCs do sady $setName. V paměti je celkem ${_statsMemory.length} $countForm.',
        'Added $valuesStr$countPartEn to set $setName. Memory now contains ${_statsMemory.length} $countForm.',
      );
    }
    // Z3: jediné oznámení jednotným kanálem (SnackBar s announce).
    if (mounted) {
      _showAccessibleSnackBar(spoken);
    }
  }

  void _showStatsSaveReviewDialog(
    List<StatisticsRecord> records, {
    VoidCallback? onConfirm,
  }) {
    final l10n = _l10n;
    final setName = _statsSets[_currentStatsSetIndex].name;
    final editableRecords = records
        .map((r) => StatisticsRecord(values: List.from(r.values)))
        .toList();
    final summary = l10n.statsReviewSummary(editableRecords.length, setName);

    void closeDialog(BuildContext dialogContext, {VoidCallback? after}) {
      Navigator.pop(dialogContext);
      if (after != null) {
        // Následný dialog převezme fokus. Odložení zajišťuje, že se
        // otevře až po tom, co _FocusRestoreObserver vrátil fokus zpět
        // (po 150 ms), jinak by ho následnému dialogu vytrhl.
        final callback = after;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) callback();
        });
      } else {
        _returnFocusToKeyboard();
      }
    }

    showAppDialog(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsReviewTitle),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          insetPadding: _dialogInsetPadding(),
          title: Semantics(header: true, child: Text(l10n.statsReviewTitle)),
          content: Semantics(
            container: true,
            liveRegion: true,
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.70,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          summary,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...editableRecords.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final rowTextVis = entry.value.values
                              .map((v) => _formatNumberSmart(v))
                              .join('; ');
                          final rowText = entry.value.values
                              .map((v) => _formatNumber(v))
                              .join('; ');
                          final rowLabel = _s(
                            'Hodnota $idx: $rowText',
                            'Value $idx: $rowText',
                          );
                          return Focus(
                            autofocus: idx == 1,
                            onFocusChange: (hasFocus) {
                              if (hasFocus && _isScreenReaderActive != true) {
                                speak(rowLabel);
                              }
                            },
                            child: Semantics(
                              container: true,
                              label: rowLabel,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ExcludeSemantics(
                                        child: _PeriodicText(
                                          '$idx. $rowTextVis',
                                          overlineThickness: _overlineThickness,
                                          overlineHeight: _overlineHeight,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      tooltip: _s(
                                        'Upravit hodnotu $idx',
                                        'Edit value $idx',
                                      ),
                                      onPressed: () =>
                                          _showEditReviewRecordDialog(
                                            entry.key,
                                            editableRecords,
                                            dialogContext,
                                            setStateDialog,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => closeDialog(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => closeDialog(
                dialogContext,
                after: () => onConfirm == null
                    ? _addValuesToStats(editableRecords, 1)
                    : onConfirm(),
              ),
              child: Text(l10n.statsSaveAction),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isScreenReaderActive != true) speak(summary);
    });
  }

  void _showEditReviewRecordDialog(
    int index,
    List<StatisticsRecord> editableRecords,
    BuildContext dialogContext,
    StateSetter setStateDialog,
  ) {
    final record = editableRecords[index];
    final currentSet = _statsSets[_currentStatsSetIndex];
    final fieldNames = currentSet.fieldNames;
    final fieldUnits = currentSet.fieldUnits;
    final controllers = record.values
        .map(
          (v) => TextEditingController(
            text: _formatNumber(v).replaceAll(',', '.'),
          ),
        )
        .toList();

    showAppDialog<void>(
      context: dialogContext,
      routeSettings: RouteSettings(
        name: _s('Upravit hodnotu ${index + 1}', 'Edit value ${index + 1}'),
      ),
      builder: (ctx) => AlertDialog(
        scrollable: false,
        insetPadding: _dialogInsetPadding(),
        title: Semantics(
          header: true,
          child: Text(
            _s('Upravit hodnotu ${index + 1}', 'Edit value ${index + 1}'),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(fieldNames.length, (i) {
            final unitCode = i < fieldUnits.length ? fieldUnits[i] : null;
            final label = unitCode != null
                ? '${fieldNames[i]} (${_getUnitSpeech(unitCode)})'
                : fieldNames[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                label: '$label (${_s("Pole ${i + 1}", "Field ${i + 1}")})',
                child: TextField(
                  controller: controllers[i],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                  ),
                ),
              ),
            );
          }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final newValues = <double>[];
              bool valid = true;
              for (int i = 0; i < controllers.length; i++) {
                final text = controllers[i].text.trim().replaceAll(',', '.');
                final val = double.tryParse(text);
                if (val != null) {
                  newValues.add(val);
                } else {
                  valid = false;
                  break;
                }
              }
              if (valid) {
                setStateDialog(() {
                  editableRecords[index] = StatisticsRecord(values: newValues);
                });
                Navigator.pop(ctx);
                speak(
                  _s(
                    'Hodnota ${index + 1} upravena',
                    'Value ${index + 1} edited',
                  ),
                );
              } else {
                speak(_s('Neplatná hodnota', 'Invalid value'));
              }
            },
            child: Text(_l10n.confirmAction),
          ),
        ],
      ),
    );
  }

  void _showRepeatDialog(
    List<StatisticsRecord> records, {
    bool suppressInitialAnnounce = false,
  }) {
    final l10n = _l10n;
    final setName = _statsSets[_currentStatsSetIndex].name;
    final editableRecords = records
        .map((r) => StatisticsRecord(values: List.from(r.values)))
        .toList();
    final summary = l10n.statsReviewSummary(editableRecords.length, setName);
    final TextEditingController controller = TextEditingController(text: '1');
    final FocusNode countFocusNode = FocusNode(debugLabel: 'statsRepeatCount');
    String? countError;

    final dialogFuture = showAppDialog(
      context: context,
      routeSettings: RouteSettings(name: l10n.statsRepeatTitle),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            scrollable: false,
            insetPadding: _dialogInsetPadding(),
            title: Semantics(header: true, child: Text(l10n.statsRepeatTitle)),
            content: SizedBox(
              width: double.maxFinite,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                        Text(
                          summary,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...editableRecords.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final rowTextVis = entry.value.values
                              .map((v) => _formatNumberSmart(v))
                              .join('; ');
                          final rowText = entry.value.values
                              .map((v) => _formatNumber(v))
                              .join('; ');
                          final rowLabel = _s(
                            'Hodnota $idx: $rowText',
                            'Value $idx: $rowText',
                          );
                          return Semantics(
                            container: true,
                            label: rowLabel,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ExcludeSemantics(
                                      child: _PeriodicText(
                                        '$idx. $rowTextVis',
                                        overlineThickness: _overlineThickness,
                                        overlineHeight: _overlineHeight,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                    tooltip: _s(
                                      'Upravit hodnotu $idx',
                                      'Edit value $idx',
                                    ),
                                    onPressed: () =>
                                        _showEditReviewRecordDialog(
                                          entry.key,
                                          editableRecords,
                                          dialogContext,
                                          setStateDialog,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          focusNode: countFocusNode,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.statsRepeatLabel,
                            errorText: countError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _returnFocusToKeyboard();
                },
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  final int? count = int.tryParse(controller.text.trim());
                  if (count == null ||
                      count < 1 ||
                      count > kMaxStatsRepeatCount) {
                    // Neplatný počet: nic se neuloží, displej se nevymaže
                    // a dialog zůstává otevřený pro opravu. Viditelná chyba
                    // v poli + jedno oznámení (speak je při aktivní čtečce
                    // tichý; přesun fokusu na pole chybu přečte i se čtečkou).
                    final msg = l10n.statsRepeatInvalidRange(
                      kMaxStatsRepeatCount,
                    );
                    setStateDialog(() {
                      countError = msg;
                    });
                    countFocusNode.requestFocus();
                    unawaited(speak(msg));
                    return;
                  }
                  _addValuesToStats(editableRecords, count);
                  Navigator.pop(dialogContext);
                  _returnFocusToKeyboard();
                },
                child: Text(l10n.confirmAction),
              ),
            ],
          );
        },
      ),
    );
    dialogFuture.then((_) => countFocusNode.dispose());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _isScreenReaderActive != true &&
          !suppressInitialAnnounce) {
        speak('$summary ${l10n.statsRepeatHint}');
      }
    });
  }

  Future<void> _handleMultipleStatisticsAddition() async {
    if (!_hasStatsSet) {
      // R9: jednotný kanál jako krátký stisk (dříve přímé speak).
      if (mounted) {
        _showAccessibleSnackBar(
          _s(
            'Není vytvořena žádná statistická sada. Nejprve zadejte název pro novou sadu.',
            'No statistics set created. Enter a name for a new set first.',
          ),
        );
      }

      List<StatisticsRecord>? recordsToRepeat;
      if (display.isNotEmpty) {
        try {
          recordsToRepeat = _parseDisplayToRecords(display);
        } catch (_) {}
      }

      _showCreateStatsSetDialog(context, recordsToRepeat: recordsToRepeat);
      return;
    }
    if (display.isEmpty) {
      // R9: jednotný kanál jako krátký stisk (dříve přímé speak).
      if (mounted) {
        _showAccessibleSnackBar(
          _s(
            'Displej je prázdný. Zadejte číslo k uložení.',
            'Display is empty. Enter a number to store.',
          ),
        );
      }
      return;
    }
    try {
      final recordsToAdd = _parseDisplayToRecords(display);

      if (recordsToAdd.isEmpty) {
        // R9: jednotný kanál jako krátký stisk (dříve přímé speak).
        if (mounted) {
          _showAccessibleSnackBar(
            _s('Žádná platná čísla k uložení.', 'No valid numbers to store.'),
          );
        }
        return;
      }

      _showRepeatDialog(recordsToAdd);
    } catch (e) {
      final msg = e is FormatException
          ? e.message
          : _s(
              'Chyba při ukládání do statistické paměti. Zkontrolujte formát dat.',
              'Error storing to statistics memory. Check the data format.',
            );
      // R9: jednotný kanál jako krátký stisk (dříve přímé speak).
      if (mounted) {
        _showAccessibleSnackBar(msg);
      }
    }
  }

  void _showMoreOptionsDialog() {
    final l10n = _l10n;
    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: l10n.moreOptions),
      builder: (dialogContext) => AlertDialog(
        insetPadding: _dialogInsetPadding(),
        title: Semantics(header: true, child: Text(l10n.moreOptions)),
        content: _applyDialogSize(
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMoreOptionTile(
                  icon: Icons.help_outline,
                  label: l10n.helpTooltip,
                  autofocus: true,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showTutorialDialog();
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.info_outline,
                  label: l10n.numberInfo,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showNumberInfoDialog();
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.campaign,
                  label: l10n.news,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showNewsDialog();
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.update,
                  label: l10n.checkForUpdates,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _checkForUpdatesManually();
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.reorder,
                  label: _s(
                    'Pořadí čtení statistického souhrnu',
                    'Statistics summary reading order',
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _showStatsSummaryReadingOrderDialog();
                    });
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.tune,
                  label: _s(
                    'Rychlé nastavení kalkulačky',
                    'Quick calculator setup',
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) _openQuickSetupManually();
                    });
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.file_download,
                  label: _s(
                    'Importovat konfiguraci (kontrakt)',
                    'Import configuration (contract)',
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) _importContract();
                    });
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.file_upload,
                  label: _s(
                    'Exportovat konfiguraci (kontrakt)',
                    'Export configuration (contract)',
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) _exportContract();
                    });
                  },
                ),
                if (_devModeEnabled)
                  _buildMoreOptionTile(
                    icon: Icons.bug_report,
                    label: _s('Vývojářský režim', 'Developer mode'),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _showDevModeDialog();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionTile({
    required IconData icon,
    required String label,
    bool autofocus = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        autofocus: autofocus,
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  /// Jednotná AppBar akce. Na velmi úzkých displejích (< 360 px) by se
  /// 7 akcí v plné 48px šířce nevešlo (7 × 48 = 336 > 320) a AppBar by
  /// přetekl. Kompaktní constraints (40 px) udrží všechny akce viditelné;
  /// na běžných šířkách se nemění nic. Tooltip (zdroj Semantics labelu
  /// pro TalkBack/NVDA) zůstává vždy zachován.
  Widget _appBarAction({
    required Widget icon,
    required String? tooltip,
    required VoidCallback? onPressed,
  }) {
    final narrow = MediaQuery.of(context).size.width < 360;
    return IconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      padding: narrow ? const EdgeInsets.all(4) : null,
      constraints: narrow
          ? const BoxConstraints(minWidth: 40, minHeight: 40)
          : null,
      // Bez shrinkWrap by výchozí MaterialTapTargetSize.padded vnutil 48px
      // touch target i při menších constraints (tato beta nemá přímý
      // parametr tapTargetSize, proto přes style).
      style: narrow
          ? IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateTtsLanguage();
    final l10n = _l10n;
    // Post-frame derivace a11y proxy (guardovaná, viz [_scheduleA11yProxySync]).
    _scheduleA11yProxySync();

    // Z1: `Focus` místo `KeyboardListener` — stejný uzel i pozice ve stromě,
    // navíc konzumace kláves (`handled`/`ignored`) pro odečítač a traversál.
    // `includeSemantics: false`: výchozí `true` by obalilo celý Scaffold
    // bezjmenným `Semantics(focusable/focused)` uzlem (viz `_FocusState.build`
    // ve flutter/widgets), který Windows mapa na UIA prvek klávesnicového
    // fokusu a NVDA jej ohlašoval jako „seskupení". Klávesový handler ani
    // focus tree tímto nejsou dotčeny — mizí pouze sémantický uzel obálky
    // (stejný vzor jako `_buildResultA11yNode`); potomci si svoji
    // sémantiku (tlačítka, displej, výsledek) nesou dál.
    return Focus(
      focusNode: _mainFocusNode,
      onKeyEvent: _handleKeyboardInput,
      includeSemantics: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            _appBarAction(
              icon: Icon(
                _voiceCreationSession?.listening == true
                    ? Icons.mic
                    : Icons.mic_none,
                color: _voiceCreationSession?.listening == true
                    ? Colors.redAccent
                    : null,
              ),
              tooltip: _s(
                'Hlasové vytvoření statistické sady',
                'Voice statistics set creation',
              ),
              onPressed: _startVoiceSetCreation,
            ),
            _appBarAction(
              icon: const Icon(Icons.history),
              tooltip: l10n.history,
              onPressed: _showHistoryDialog,
            ),
            _appBarAction(
              icon: const Icon(Icons.list),
              tooltip: l10n.advancedFunctions,
              onPressed: _showAdvancedFunctionsDialog,
            ),
            _appBarAction(
              icon: Icon(ttsEnabled ? Icons.volume_up : Icons.volume_off),
              tooltip: ttsEnabled ? l10n.muteVoice : l10n.unmuteVoice,
              onPressed: _toggleTts,
            ),
            _appBarAction(
              icon: const Icon(Icons.settings),
              tooltip: l10n.accessibility,
              onPressed: _showAccessibilityDialog,
            ),
            if (_devModeEnabled)
              _appBarAction(
                icon: const Icon(Icons.bug_report, color: Colors.orange),
                tooltip: _s('Vývojářský režim', 'Developer mode'),
                onPressed: _showDevModeDialog,
              ),
            _appBarAction(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.moreOptions,
              onPressed: _showMoreOptionsDialog,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Výpočet dostupného prostoru
                final double totalHeight = constraints.maxHeight;

                // Rozdělení zbývajícího prostoru mezi displej a klávesnici
                // Na malých displejích dáme klávesnici víc prostoru.
                // Display 1.2 (místo 1.5): kompenzace samostatného řádku
                // DEC<->a/b pod displejem, aby klávesnice ve všech režimech
                // zůstala na stropu standardRowH a řádky byly stejně vysoké.
                // Displej má auto-fit (zmenší obsah), klávesnice strop ne.
                final double displayFlex = (totalHeight < 600) ? 1.0 : 1.2;
                double keyboardFlex = 3.0;
                if (_currentMode == CalculatorMode.unitConversion ||
                    _currentMode == CalculatorMode.currency) {
                  // Panely převodů (~200 px) jsou součástí sloupce pouze
                  // v těchto dvou režimech: klávesnice ustoupí, aby displej
                  // (primární výstup) měl dost místa a sloupec nepřetekl
                  // ani na malých displejích. Rastr 7×4, mechanismus
                  // fitScale ani ostatní režimy se nemění.
                  keyboardFlex = 2.0;
                }
                final double s = _responsiveScale(context);
                if (_alignInputLeft) _scheduleInputAutoscroll();

                return Column(
                  children: [
                    // Displej
                    Expanded(
                      flex: (displayFlex * 100).toInt(),
                      child: GestureDetector(
                        onScaleUpdate: (ScaleUpdateDetails details) {
                          if (details.scale != 1.0) {
                            final newDot = (_dotMatrixZoom * details.scale)
                                .clamp(0.5, 5.0);
                            final newRes = (_resultZoom * details.scale).clamp(
                              0.5,
                              5.0,
                            );
                            updateActiveAccessibilitySettings(
                              (s) => s.copyWith(
                                dotMatrixZoom: newDot,
                                resultZoom: newRes,
                              ),
                            );
                          }
                        },
                        onDoubleTap: () {
                          updateActiveAccessibilitySettings(
                            (s) =>
                                s.copyWith(dotMatrixZoom: 1.0, resultZoom: 1.0),
                          );
                        },
                        onTap: () {
                          // Z1: dotyk na displej je explicitní aktivace
                          // režimu ovládání výrazu (viz proxy onTap).
                          _expressionControlActive = true;
                          _expressionControlOffReason =
                              _ExpressionControlOffReason.none;
                          _mainFocusNode.requestFocus();
                        },
                        child: Container(
                          // E3: svisly margin i svisly padding 4*s (dříve
                          // 8*s). Na nízkém okně (800x600, totalHeight 544)
                          // kůžový prostor rámu sežel 83 % slotu displeje
                          // (68,2 z 81,9 log) -> availableH 13,7 i při
                          // podlaze fitScale 0,35 nestacilo na obsah 29,3
                          // a vědecký displej byl svisle oříznutý (nouzový
                          // scroll). Úspora 2*4*s + 2*4*s = 18,4 log jde
                          // 1:1 do availableH; slot displeje ani prostor
                          // klávesnice se NEMĚNÍ (kůžový prostor je uvnitř
                          // Expanded slotu). Vodorovně beze změny.
                          margin: EdgeInsets.only(
                            left: 8 * s,
                            right: 8 * s,
                            top: 4 * s,
                            bottom: 4 * s,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * s,
                            vertical: 4 * s,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            border: Border.all(
                              color: Colors.black,
                              width: 3 * s.clamp(1.0, 1.3),
                            ),
                          ),
                          // Stabilní kořen displeje: vizuální sloupec se DVĚMA
                          // samostatnými přístupnými oblastmi — horní proxy
                          // výrazu + dolní uzel výsledku (viz níže). Vnější
                          // `Stack` zde layout nemění (displej má velikost
                          // z Expanded); vnitřní `Stack` kolem horního
                          // řádku se dimenzuje POUZE vizuálním vstupem
                          // (`Positioned.fill` do velikosti nepřispívá),
                          // takže rect proxy = rect horního řádku.
                          child: Semantics(
                            liveRegion: true,
                            // Vnější obálka je trvale pass-through: NENÍ
                            // popisek ani akce — jinak by TalkBack hlásil
                            // displej dvakrát (nejdřív obálku, pak pole).
                            // Zoom-hint (displayHint) zde záměrně NENÍ ani
                            // v jednom stavu: zoom zůstává gestem, dvojitým
                            // klepem a posuvníky v nastavení přístupnosti.
                            label: null,
                            // Hodnotu ani aktivaci vnější obálka nenese:
                            // horní výraz patří proxy [_buildDisplayA11yProxy]
                            // (RenderEditable: value + textSelection +
                            // pohybové akce), výsledek patří dolnímu uzlu
                            // [_buildResultA11yNode]. Vnější value zde NESMÍ
                            // konkurovat (jinak duplicitní čtení).
                            value: null,
                            onTap: null,
                                // Když je čtečka aktivní, vnitřní CustomPaint je pro ni neviditelný
                                // a vše se přečte z tohoto Semantics widgetu. Textový matematický
                                // renderer je navíc v ExcludeSemantics, takže displej zůstává
                                // jeden logický prvek bez duplicitního čtení.
                                // Displej je samostatny prvek hlavniho layoutu.
                                // Ovladani zlomku (DEC <-> a/b) je presunuto do
                                // _buildFractionViewToggleRow() pod displejem:
                                // bez Stack/Positioned overlaye, s normalnim
                                // focus order pro TalkBack/NVDA/klavesnici.
                                // Popisek zustava jednoradkovy jako driv.
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.topLeft,
                                      // Dekorativní duplikát pro čtečky: režim je
                                      // v sémantickém stromě zastoupen přepínačem
                                      // režimů ( unfolded chips s `selected`).
                                      // Bez vyloučení by se text slil do labelu
                                      // displeje ("Displej\nVĚDECKÁ") a tvořil
                                      // zastávku navíc před kurzorovým polem.
                                      child: ExcludeSemantics(
                                        child: Text(
                                          _getModeName(_currentMode).toUpperCase(),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12 * s,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4 * s),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, displayConstraints) {
                                          // Auto-fit: oba řádky (vstup + výsledek) viditelné bez svislého švihnutí
                                          // Konstanty musí odpovídat _buildDotMatrixDisplay
                                          // (rozestup 1.15 × systémový faktor) a rezervě
                                          // pro periodickou čáru v CustomSegmentDisplay.
                                          final fitSysFactor =
                                              MediaQuery.textScalerOf(
                                                context,
                                              ).scale(1.0).clamp(1.0, 1.5);
                                          final dotLedSize =
                                              3.0 * _dotMatrixZoom * s;
                                          final dotSpacing =
                                              1.15 *
                                              _dotMatrixZoom *
                                              s *
                                              fitSysFactor;
                                          final dotH =
                                              dotLedSize * 8 + dotSpacing * 7;
                                          final segSize = 16 * _resultZoom * s;
                                          var segH = segSize * 1.8;
                                          if (_toBarNotation(
                                            _lastResult.isEmpty
                                                ? '0.'
                                                : _lastResult,
                                          ).contains('\u0305')) {
                                            final segThick = segSize * 0.15;
                                            segH +=
                                                segThick * 2.0 +
                                                6.0 +
                                                segThick *
                                                    0.75 *
                                                    _overlineThickness /
                                                    2 +
                                                2.0;
                                          }
                                          final gapH = 12 * s;
                                          final neededH = dotH + segH + gapH;
                                          final availableH =
                                              displayConstraints.maxHeight;
                                          double fitScale = 1.0;
                                          if (availableH > 0 &&
                                              neededH > availableH) {
                                            fitScale = (availableH / neededH).clamp(
                                              0.35,
                                              1.0,
                                            );
                                          }
                                          final needsFallbackScroll =
                                              fitScale <= 0.36;

                                          Widget content = Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment: _alignInputLeft
                                                ? CrossAxisAlignment.start
                                                : CrossAxisAlignment.center,
                                            children: [
                                              // Horní výpočetní řádek: vizuál
                                              // + překryvná a11y proxy PŘESNĚ
                                              // přes jeho plochu. `Stack` se
                                              // dimenzuje vizuálním vstupem
                                              // (`Positioned.fill` velikost
                                              // neurčuje), takže rect proxy =
                                              // rect horního řádku. Proxy je
                                              // záměrně MIMO horizontální
                                              // scroll view: nulový viewport
                                              // (prázdný výraz po výpočtu)
                                              // ani odscrollování ji nemohou
                                              // ořezat ze Semantics stromu.
                                              // [_A11yHitTestTransparent]
                                              // propouští dotyky na vnější
                                              // `GestureDetector` (pinch-zoom,
                                              // double-tap, tap) — proxy nikdy
                                              // nekonzumuje gesta vidících
                                              // uživatelů, TalkBack akce (tap,
                                              // pohyb kurzoru) jdou přes
                                              // Semantics a zůstávají funkční.
                                              Stack(
                                                children: [
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: dotH * fitScale,
                                                    child: Align(
                                                      alignment:
                                                          _alignInputLeft
                                                              ? Alignment
                                                                  .centerLeft
                                                              : Alignment
                                                                  .center,
                                                      child:
                                                          SingleChildScrollView(
                                                            controller:
                                                                _scrollControllerH,
                                                            scrollDirection:
                                                                Axis.horizontal,
                                                            // Čistě vizuální
                                                            // renderer vstupu
                                                            // (pro čtečku
                                                            // vyloučen);
                                                            // přístupnou
                                                            // reprezentací je
                                                            // překryvná proxy
                                                            // (viz níže).
                                                            child:
                                                                ExcludeSemantics(
                                                                  child:
                                                                      _buildDotMatrixDisplay(
                                                                        fitScale:
                                                                            fitScale,
                                                                      ),
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                  Positioned.fill(
                                                    child:
                                                        _A11yHitTestTransparent(
                                                      child:
                                                          _buildDisplayA11yProxy(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12 * s * fitScale),
                                              // Dolní výsledkový řádek: vlastní
                                              // samostatná přístupná oblast
                                              // přes skutečnou plochu výsledku
                                              // (viz [_buildResultA11yNode]).
                                              // Renderery uvnitř jsou
                                              // ExcludeSemantics/CustomPaint,
                                              // takže nevzniká duplicitní
                                              // čtení výsledku. Vnitřní
                                              // horizontální scroller je čistě
                                              // vizuální: ExcludeSemantics z něj
                                              // odstraní i scroll-uzel s akcemi,
                                              // který by jinak tvořil němou
                                              // zastávku mezi výsledkem a dalším
                                              // prvkem (Z4). Vizuální posouvání,
                                              // controller ani onTap tím nejsou
                                              // dotčeny; plnou hodnotu nese
                                              // value vnějšího uzlu.
                                              _buildResultA11yNode(
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  height: segH * fitScale,
                                                  child: Align(
                                                    alignment: Alignment.center,
                                                    child: ExcludeSemantics(
                                                      child:
                                                          SingleChildScrollView(
                                                            controller:
                                                                _scrollControllerResultH,
                                                            scrollDirection: Axis
                                                                .horizontal,
                                                            child:
                                                                _buildMainResultDisplay(
                                                                  fitScale:
                                                                      fitScale,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );

                                          if (needsFallbackScroll) {
                                            // Extrémní zoom - ponechat nouzový vertikální scroll se scrollbar
                                            return Scrollbar(
                                              controller: _scrollControllerV,
                                              thumbVisibility: true,
                                              child: SingleChildScrollView(
                                                controller: _scrollControllerV,
                                                scrollDirection: Axis.vertical,
                                                child: content,
                                              ),
                                            );
                                          }
                                          // Běžný stav: zcela bez svislého posunu - obsah je zmenšen aby se vešel
                                          return Center(child: content);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ),
                ),
                    // Ovládání kurzoru.
                    _buildCursorNavigationRow(),
                    // Ovládání zobrazení výsledku DEC <-> a/b: samostatný
                    // prvek hlavního layoutu mimo displej i mimo keypad.
                    _buildFractionViewToggleRow(),
                    // Globální textový vstup „Paměť" sdílí řádek s přepínačem
                    // režimů: fixní tlačítko před scrollovatelnými chipy.
                    // Mimo 4×7 rastr klávesnice (focus order klávesnice se
                    // nemění), bez nového vertikálního řádku.
                    _buildMemoryAndModeRow(),
                    // Panely převodů přímo na hlavní obrazovce (mimo 7×4
                    // rastr klávesnice, v běžné fokusové cestě před ní).
                    if (_currentMode == CalculatorMode.unitConversion)
                      _buildUnitConversionPanel(),
                    if (_currentMode == CalculatorMode.currency)
                      _buildCurrencyPanel(),
                    if (_currentMode == CalculatorMode.scientific) ...[
                      _buildScientificPageToggle(),
                      Semantics(
                        liveRegion: true,
                        label: _scientificPageAnnouncement ?? '',
                        excludeSemantics: true,
                        child: const SizedBox(width: 1, height: 1),
                      ),
                    ],
                    // R-architektura: dedikovaný oznamovací liveRegion.
                    // Primární kanál při aktivní čtečce na Androidu
                    // (doporučení Flutteru místo announcement eventů),
                    // fallback na Windows. Změna labelu = jedno oznámení.
                    // Mimo keypad rastr i focus order, bez vizuálního dopadu.
                    Semantics(
                      liveRegion: true,
                      label: _lastAnnouncement,
                      excludeSemantics: true,
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    // Klávesnice
                    Expanded(
                      flex: (keyboardFlex * 100).toInt(),
                      child: _buildMainKeyboard(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Hit-test průhledný obal a11y proxy horního displeje (GATED BUILD SPIKE).
/// Pro dotyková gesta se chová, jako by v hit-testu vůbec nebyl (pinch-zoom,
/// double-tap i tap jdou na vnější `GestureDetector` displeje — stejné
/// chování jako dřívější proxy 1×1, která nikdy žádné gesto nekonzumovala),
/// ale sémantiku dítěte plně zachovává včetně `SemanticsAction.tap`
/// a kurzorových akcí pro TalkBack.
/// `IgnorePointer`/`AbsorbPointer` záměrně NEPOUŽITY: v aktuálním SDK
/// odstraňují pointer-related akce ze sémantického podstromu
/// (`isBlockingUserActions`), takže by TalkBack přišel o aktivaci proxy.
class _A11yHitTestTransparent extends SingleChildRenderObjectWidget {
  const _A11yHitTestTransparent({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderA11yHitTestTransparent();
}

class _RenderA11yHitTestTransparent extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;
}

enum _ManualBlockType { heading, paragraph, bullet }

class _ManualBlock {
  final _ManualBlockType type;
  final String text;
  const _ManualBlock(this.type, this.text);
}

List<_ManualBlock> _parseManualText(String raw) {
  final blocks = <_ManualBlock>[];
  String normalized = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return blocks;
  final sections = normalized.split(RegExp(r'\n\s*\n'));
  for (final section in sections) {
    final sec = section.trim();
    if (sec.isEmpty) continue;
    final lines = sec.split('\n');
    final hasBullet = lines.any(
      (l) => l.trimLeft().startsWith('- ') || l.trimLeft().startsWith('• '),
    );
    if (hasBullet) {
      final firstBulletIdx = lines.indexWhere(
        (l) => l.trimLeft().startsWith('- ') || l.trimLeft().startsWith('• '),
      );
      final headingPart = lines.sublist(0, firstBulletIdx).join('\n').trim();
      if (headingPart.isNotEmpty) {
        if (headingPart.endsWith(':')) {
          blocks.add(_ManualBlock(_ManualBlockType.heading, headingPart));
        } else if (headingPart.length < 120 && headingPart.contains(':')) {
          if (headingPart.trim().endsWith(':')) {
            blocks.add(_ManualBlock(_ManualBlockType.heading, headingPart));
          } else {
            blocks.add(_ManualBlock(_ManualBlockType.paragraph, headingPart));
          }
        } else {
          blocks.add(_ManualBlock(_ManualBlockType.paragraph, headingPart));
        }
      }
      for (int i = firstBulletIdx; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;
        if (line.startsWith('- ')) {
          line = line.substring(2).trimLeft();
        } else if (line.startsWith('• ')) {
          line = line.substring(2).trimLeft();
        } else if (line.startsWith('-')) {
          line = line.substring(1).trimLeft();
        } else if (line.startsWith('•')) {
          line = line.substring(1).trimLeft();
        }
        if (line.isEmpty) continue;
        // lines that do not start with bullet but appear after bullets are continuation of previous bullet or separate paragraph
        final isBulletLine =
            lines[i].trimLeft().startsWith('- ') ||
            lines[i].trimLeft().startsWith('• ');
        if (!isBulletLine) {
          blocks.add(_ManualBlock(_ManualBlockType.paragraph, line));
        } else {
          blocks.add(_ManualBlock(_ManualBlockType.bullet, line));
        }
      }
    } else {
      // No bullets in this section
      if (lines.length > 1 && lines.first.trim().endsWith(':')) {
        final heading = lines.first.trim();
        blocks.add(_ManualBlock(_ManualBlockType.heading, heading));
        final rest = lines.sublist(1).join('\n').trim();
        if (rest.isNotEmpty) {
          // rest may contain multiple paragraphs separated by single \n, keep as one block
          blocks.add(_ManualBlock(_ManualBlockType.paragraph, rest));
        }
      } else {
        // Check if single short heading
        if (sec.endsWith(':') && sec.length < 120 && !sec.contains('\n')) {
          blocks.add(_ManualBlock(_ManualBlockType.heading, sec));
        } else {
          blocks.add(_ManualBlock(_ManualBlockType.paragraph, sec));
        }
      }
    }
  }
  // Fallback: never return empty
  if (blocks.isEmpty) {
    blocks.add(_ManualBlock(_ManualBlockType.paragraph, normalized));
  }
  return blocks;
}

class _TutorialTabContent extends StatefulWidget {
  final String text;
  final bool isActive;
  final ScrollController? scrollController;
  const _TutorialTabContent({
    required this.text,
    required this.isActive,
    this.scrollController,
  });
  @override
  State<_TutorialTabContent> createState() => _TutorialTabContentState();
}

class _TutorialTabContentState extends State<_TutorialTabContent> {
  late List<_ManualBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = _parseManualText(widget.text);
  }

  @override
  void didUpdateWidget(covariant _TutorialTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _blocks = _parseManualText(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const ExcludeFocus(
        excluding: true,
        child: ExcludeSemantics(child: SizedBox.shrink()),
      );
    }
    if (_blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: 8),
      child: ExcludeFocus(
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final block in _blocks)
                Builder(
                  builder: (context) {
                    final isHeading = block.type == _ManualBlockType.heading;
                    final isBullet = block.type == _ManualBlockType.bullet;
                    Widget content;
                    if (isBullet) {
                      content = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(right: 8, top: 1),
                              child: ExcludeSemantics(child: Text('•')),
                            ),
                            Expanded(child: Text(block.text)),
                          ],
                        ),
                      );
                    } else if (isHeading) {
                      content = Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          block.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      );
                    } else {
                      content = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(block.text),
                      );
                    }
                    if (isHeading) {
                      return Semantics(header: true, child: content);
                    }
                    return content;
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialDialog extends StatefulWidget {
  final List<({String label, String text})> tabs;
  final _CalculatorScreenState parent;
  final AppLocalizations l10n;
  const _TutorialDialog({
    required this.tabs,
    required this.parent,
    required this.l10n,
  });
  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  int? _focusedTabIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Po otevření dialogu zajisti, že fokus bude na první záložce (jediný Tab stop na záložku → InkWell).
    // Bez vlastních FocusNode s autofocus TabBar nezíská fokus automaticky.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final primary = FocusManager.instance.primaryFocus;
      final insideDialog =
          primary != null &&
          primary.context != null &&
          primary.context!.findAncestorWidgetOfExactType<AlertDialog>() != null;
      if (!insideDialog) {
        // nextFocus přejde na první traversovatelný prvek v ReadingOrder – první záložka.
        FocusScope.of(context).nextFocus();
        // Fallback: pokud stále není uvnitř, zkus fokusovat TabBar přímo přes FocusScope
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          final p2 = FocusManager.instance.primaryFocus;
          final inside2 =
              p2 != null &&
              p2.context != null &&
              p2.context!.findAncestorWidgetOfExactType<AlertDialog>() != null;
          if (!inside2) {
            FocusScope.of(context).nextFocus();
          }
        });
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
      final label = widget.tabs[_tabController.index].label;
      // R-architektura: jedna navigační hláška jednotným kanálem
      // (přímé deprecated SemanticsService.announce odstraněno).
      unawaited(
        widget.parent.announceEvent(
          widget.parent._s(
            'Karta ${_tabController.index + 1} z ${widget.tabs.length}: $label',
            'Tab ${_tabController.index + 1} of ${widget.tabs.length}: $label',
          ),
          category: SpeechCategory.navigation,
        ),
      );
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isTabBarFocused() {
    if (_focusedTabIndex != null) return true;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary.context == null) return false;
    try {
      return primary.context!.findAncestorWidgetOfExactType<TabBar>() != null;
    } catch (_) {
      return false;
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final delta = isShift ? -1 : 1;
      final next = (_tabController.index + delta) % widget.tabs.length;
      final normalized = next < 0 ? widget.tabs.length - 1 : next;
      _tabController.animateTo(normalized);
      return KeyEventResult.handled;
    }
    final isTabFocused = _isTabBarFocused();
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (!isTabFocused) return KeyEventResult.ignored;
      final delta = event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1;
      final next = _tabController.index + delta;
      if (next < 0 || next >= widget.tabs.length) {
        return KeyEventResult.ignored;
      }
      _tabController.animateTo(next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      if (!isTabFocused) return KeyEventResult.ignored;
      _tabController.animateTo(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      if (!isTabFocused) return KeyEventResult.ignored;
      _tabController.animateTo(widget.tabs.length - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      if (!isTabFocused) return KeyEventResult.ignored;
      if (_tabController.index < widget.tabs.length - 1) {
        _tabController.animateTo(_tabController.index + 1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (!isTabFocused) return KeyEventResult.ignored;
      if (_tabController.index > 0) {
        _tabController.animateTo(_tabController.index - 1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: AlertDialog(
        insetPadding: widget.parent._dialogInsetPadding(),
        title: Semantics(header: true, child: Text(widget.l10n.helpTitle)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: double.maxFinite,
          ),
          child: SizedBox(
            width: double.maxFinite,
            height: 460,
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              includeSemantics: false,
              onKeyEvent: _handleKey,
              child: Column(
                children: [
                  Semantics(
                    container: true,
                    label: widget.parent._s('Záložky návodu', 'Tutorial tabs'),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      onFocusChange: (focused, index) {
                        if (focused) {
                          _focusedTabIndex = index;
                        } else if (_focusedTabIndex == index) {
                          _focusedTabIndex = null;
                        }
                      },
                      tabs: [
                        for (int i = 0; i < widget.tabs.length; i++)
                          Builder(
                            builder: (context) {
                              final isSelected = _tabController.index == i;
                              return Semantics(
                                selected: isSelected,
                                inMutuallyExclusiveGroup: true,
                                label: widget.tabs[i].label,
                                excludeSemantics: true,
                                child: Tab(text: widget.tabs[i].label),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      label: widget.parent._s(
                        'Obsah karty ${widget.tabs[_tabController.index].label}',
                        'Content of ${widget.tabs[_tabController.index].label} tab',
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          for (int idx = 0; idx < widget.tabs.length; idx++)
                            _TutorialTabContent(
                              text: widget.tabs[idx].text,
                              isActive: idx == _tabController.index,
                              scrollController: idx == _tabController.index
                                  ? _scrollController
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _tabController.index > 0
                            ? () => _tabController.animateTo(
                                _tabController.index - 1,
                              )
                            : null,
                        child: Semantics(
                          button: true,
                          enabled: _tabController.index > 0,
                          label: widget.parent._s(
                            'Předchozí karta',
                            'Previous tab',
                          ),
                          child: ExcludeSemantics(
                            child: Text(
                              widget.parent._s('Předchozí', 'Previous'),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ExcludeSemantics(
                        child: Text(
                          '${_tabController.index + 1} / ${widget.tabs.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _tabController.index < widget.tabs.length - 1
                            ? () => _tabController.animateTo(
                                _tabController.index + 1,
                              )
                            : null,
                        child: Semantics(
                          button: true,
                          enabled:
                              _tabController.index < widget.tabs.length - 1,
                          label: widget.parent._s('Další karta', 'Next tab'),
                          child: ExcludeSemantics(
                            child: Text(widget.parent._s('Další', 'Next')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.l10n.understand),
          ),
        ],
      ),
    );
  }
}
