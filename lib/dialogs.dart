part of 'main.dart';

class _AdvancedFunctionsDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _AdvancedFunctionsDialog({required this.parent});

  @override
  State<_AdvancedFunctionsDialog> createState() =>
      _AdvancedFunctionsDialogState();
}

class _AdvancedFunctionsDialogState extends State<_AdvancedFunctionsDialog> {
  late _CalculatorScreenState parent;

  @override
  void initState() {
    super.initState();
    parent = widget.parent;
  }

  List<Widget> _buildSections(BuildContext ctx) {
    List<Widget> sections = [];
    if (parent._currentMode == CalculatorMode.statistics) {
      sections.add(
        _CollapsibleSection(
          title: parent._l10n.modeStatistics,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => parent._showStatisticsHelpDialog(),
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: Text(parent._l10n.statsHelpButton),
                  ),
                  const SizedBox(height: 8),
                  if (parent._hasStatsSet)
                    Semantics(
                      label: parent._l10n.statsCurrentSetLabel(
                        parent._statsSets[parent._currentStatsSetIndex].name,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        color: Colors.blue.withOpacity(0.1),
                        child: Column(
                          children: [
                            Text(
                              parent._l10n.statsCurrentSetLabel(
                                    parent
                                        ._statsSets[parent
                                            ._currentStatsSetIndex]
                                        .name,
                                  ) +
                                  ' (${parent._statsMemory.length} ${parent._getStatsCountForm(parent._statsMemory.length)})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (parent._currentFieldCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: StatefulBuilder(
                                  builder: (ctx, setLocalState) {
                                    final fieldNames = parent
                                        ._statsSets[parent
                                            ._currentStatsSetIndex]
                                        .fieldNames;
                                    return InkWell(
                                      onTap: () {
                                        final nextIndex =
                                            (parent._selectedFieldIndex + 1) %
                                            parent._currentFieldCount;
                                        parent.setState(
                                          () => parent._selectedFieldIndex =
                                              nextIndex,
                                        );
                                        setLocalState(() {});
                                        parent.speak(
                                          parent._s(
                                            'Vybráno pole ${fieldNames[nextIndex]}',
                                            'Selected field ${fieldNames[nextIndex]}',
                                          ),
                                        );
                                      },
                                      child: Semantics(
                                        liveRegion: true,
                                        label: parent._s(
                                          'Pole: ${fieldNames[parent._selectedFieldIndex]}',
                                          'Field: ${fieldNames[parent._selectedFieldIndex]}',
                                        ),
                                        excludeSemantics: true,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                parent._s('Pole: ', 'Field: '),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                fieldNames[parent
                                                    ._selectedFieldIndex],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.swap_horiz, size: 14),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Focus(
                      autofocus: true,
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          parent.speak(
                            parent._s(
                              'Není vytvořena žádná sada. Vytvořte novou sadu tlačítkem SETS na hlavní klávesnici.',
                              'No set created. Create a new set using the SETS button on the main keyboard.',
                            ),
                          );
                        }
                      },
                      child: Semantics(
                        container: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            parent._s(
                              'Není vytvořena žádná sada. Vytvořte novou sadu tlačítkem SETS na hlavní klávesnici.',
                              'No set created. Create a new set using the SETS button on the main keyboard.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        [
                          'MEAN',
                          'SD',
                          'VAR',
                          'SUM',
                          'MED',
                          'MODE',
                          'CV',
                          'WMEAN',
                          'MIN',
                          'MAX',
                        ].map((b) {
                          return LayoutBuilder(
                            builder: (lbCtx, lbConstraints) {
                              final lbWidth = lbConstraints.maxWidth.isFinite
                                  ? lbConstraints.maxWidth
                                  : MediaQuery.of(lbCtx).size.width * 0.85;
                              final lbScale = parent._responsiveScale(lbCtx);
                              return SizedBox(
                                width: (lbWidth - 12) / 4,
                                height: 50 * lbScale,
                                child: parent.buildButton(
                              b,
                              onPressed: () {
                                parent._handleButtonPressed(b);
                              },
                              expanded: false,
                                ),
                              );
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (parent._lastAddedBatch.isEmpty) {
                        parent.speak(
                          parent._s(
                            'Žádná data v poslední dávce.',
                            'No data in the last batch.',
                          ),
                          force: true,
                        );
                      } else {
                        String valuesStr = parent._lastAddedBatch
                            .map(
                              (r) => r.values
                                  .map(
                                    (v) => parent
                                        ._formatNumber(v)
                                        .replaceAll('.', ','),
                                  )
                                  .join(';'),
                            )
                            .join(' ');
                        parent.speak(
                          parent._s(
                            'Poslední vložená data: $valuesStr',
                            'Last added data: $valuesStr',
                          ),
                          force: true,
                        );
                      }
                    },
child: Text(
                      parent._s(
                        'Přečíst naposledy vložená data',
                        'Read last added data',
                      ),
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    }

    if (parent._currentMode == CalculatorMode.unitConversion) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: parent._selectedUnitCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: parent._s('Kategorie', 'Category'),
                    ),
                    items: parent._unitCategories.keys
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(
                              parent._getCategorySpeech(cat),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      // ignore: invalid_use_of_protected_member
                      parent.setState(() {
                        parent._selectedUnitCategory = val;
                        parent._unitFrom =
                            parent._unitCategories[val]!.keys.first;
                        parent._unitTo = parent._unitCategories[val]!.keys
                            .elementAt(1);
                      });
                      setState(() {});
                      parent.speak(
                        parent._s(
                          'Kategorie ${parent._getCategorySpeech(val)}',
                          'Category ${parent._getCategorySpeech(val)}',
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: parent._s(
                            'Převod z jednotky',
                            'Convert from unit',
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: parent._unitFrom,
                            isExpanded: true,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: parent._s('Z', 'From'),
                            ),
                            items: parent
                                ._unitCategories[parent._selectedUnitCategory]!
                                .keys
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(
                                      parent._getUnitSpeech(u),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              // ignore: invalid_use_of_protected_member
                              parent.setState(() => parent._unitFrom = val);
                              parent.speak(
                                parent._s(
                                  'Z jednotky ${parent._getUnitSpeech(val)}',
                                  'From unit ${parent._getUnitSpeech(val)}',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward),
                      Expanded(
                        child: Semantics(
                          label: parent._s(
                            'Převod na jednotku',
                            'Convert to unit',
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: parent._unitTo,
                            isExpanded: true,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: parent._s('Na', 'To'),
                            ),
                            items: parent
                                ._unitCategories[parent._selectedUnitCategory]!
                                .keys
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(
                                      parent._getUnitSpeech(u),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              // ignore: invalid_use_of_protected_member
                              parent.setState(() => parent._unitTo = val);
                              parent.speak(
                                parent._s(
                                  'Na jednotku ${parent._getUnitSpeech(val)}',
                                  'To unit ${parent._getUnitSpeech(val)}',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: parent._convertUnits,
                      icon: const Icon(Icons.sync),
                      label: Text(parent._s('PŘEVÉST', 'CONVERT')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (parent._currentMode == CalculatorMode.scientific) {
      sections.add(
        _CollapsibleSection(
          title: parent._l10n.sectionTrigonometry,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: ['SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN'].map((
                  b,
                ) {
                  return LayoutBuilder(
                            builder: (lbCtx, lbConstraints) {
                              final lbWidth = lbConstraints.maxWidth.isFinite
                                  ? lbConstraints.maxWidth
                                  : MediaQuery.of(lbCtx).size.width * 0.85;
                              final lbScale = parent._responsiveScale(lbCtx);
                              return SizedBox(
                                width: (lbWidth - 12) / 4,
                                height: 50 * lbScale,
                                child: parent.buildButton(b, expanded: false
                                ),
                              );
                            },
                          );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    sections.add(
      _CollapsibleSection(
        title: parent._l10n.sectionFunctions,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children:
                  [
                    '√',
                    '∛',
                    'ⁿ√',
                    '!',
                    'LOG',
                    'LN',
                    'EXP',
                    'x²',
                    'x³',
                    '^',
                    '\u03C0',
                    'DMS',
                    '°→\'',
                    '\'→°',
                    'ANS',
                    'ABS',
                    'PCT',
                  ].map((b) {
                    return LayoutBuilder(
                            builder: (lbCtx, lbConstraints) {
                              final lbWidth = lbConstraints.maxWidth.isFinite
                                  ? lbConstraints.maxWidth
                                  : MediaQuery.of(lbCtx).size.width * 0.85;
                              final lbScale = parent._responsiveScale(lbCtx);
                              return SizedBox(
                                width: (lbWidth - 12) / 4,
                                height: 50 * lbScale,
                                child: parent.buildButton(b, expanded: false
                                ),
                              );
                            },
                          );
                  }).toList(),
            ),
          ),
        ],
      ),
    );

    sections.add(
      _CollapsibleSection(
        title: parent._s('Paměť', 'Memory'),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: ['STO', 'RCL', 'CLR'].map((b) {
                    return LayoutBuilder(
                            builder: (lbCtx, lbConstraints) {
                              final lbWidth = lbConstraints.maxWidth.isFinite
                                  ? lbConstraints.maxWidth
                                  : MediaQuery.of(lbCtx).size.width * 0.85;
                              final lbScale = parent._responsiveScale(lbCtx);
                              return SizedBox(
                                width: (lbWidth - 8) / 3.2,
                                height: 50 * lbScale,
                                child: parent.buildButton(b, expanded: false
                                ),
                              );
                            },
                          );
                  }).toList(),
                ),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'].map((
                    b,
                  ) {
                    return LayoutBuilder(
                            builder: (lbCtx, lbConstraints) {
                              final lbWidth = lbConstraints.maxWidth.isFinite
                                  ? lbConstraints.maxWidth
                                  : MediaQuery.of(lbCtx).size.width * 0.85;
                              final lbScale = parent._responsiveScale(lbCtx);
                              return SizedBox(
                                width: (lbWidth - 12) / 4,
                                height: 50 * lbScale,
                                child: parent.buildButton(
                        b,
                        semanticLabel: parent._s('Proměnná $b', 'Variable $b'),
                        onPressed: () => parent._handleMemoryVariable(b),
                        expanded: false,
                                ),
                              );
                            },
                          );
                  }).toList(),
                ),
                const Divider(),
                Semantics(
                  label: parent._s(
                    'Vymazat všechny proměnné paměti, zobrazí potvrzovací dialog',
                    'Clear all memory variables, shows confirmation dialog',
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: Text(parent._s('Vymazat všechny proměnné', 'Clear all variables')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: () => parent._showClearMemoryConfirmation(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    sections.add(
      _CollapsibleSection(
        title: parent._s('Periodická čísla', 'Repeating decimals'),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    LayoutBuilder(
                      builder: (lbCtx, lbConstraints) {
                        final lbWidth = lbConstraints.maxWidth.isFinite
                            ? lbConstraints.maxWidth
                            : MediaQuery.of(lbCtx).size.width * 0.85;
                        final lbScale = parent._responsiveScale(lbCtx);
                        final hasPeriod = RegExp(
                          r'\(\d+\)$',
                        ).hasMatch(parent.display.isEmpty && parent._hasResult
                            ? parent._lastResult
                            : parent.display);
                        final toggleLabel = parent._s(
                          'Přepnout periodu, krátký stisk posune periodu o číslici vlevo, při celé desetinné části ji odstraní. Klávesová zkratka Ctrl+Shift+P',
                          'Toggle period, tap moves period one digit left, removes it when whole fraction is repeating. Shortcut Ctrl+Shift+P',
                        );
                        return SizedBox(
                          width: (lbWidth - 4) / 2,
                          height: 50 * lbScale,
                          child: parent.buildButton(
                            '…',
                            semanticLabel: toggleLabel,
                            color: hasPeriod ? Colors.green : null,
                            onPressed: () {
                              Navigator.pop(lbCtx);
                              Future.delayed(
                                const Duration(milliseconds: 170),
                                () => parent._togglePeriod(),
                              );
                            },
                            expanded: false,
                          ),
                        );
                      },
                    ),
                    LayoutBuilder(
                      builder: (lbCtx, lbConstraints) {
                        final lbWidth = lbConstraints.maxWidth.isFinite
                            ? lbConstraints.maxWidth
                            : MediaQuery.of(lbCtx).size.width * 0.85;
                        final lbScale = parent._responsiveScale(lbCtx);
                        return SizedBox(
                          width: (lbWidth - 4) / 2,
                          height: 50 * lbScale,
                          child: parent.buildButton(
                            parent._s('UPRAVIT', 'EDIT'),
                            semanticLabel: parent._s(
                              'Ruční úprava periody, otevře dialog s neperiodickou částí a periodou 1 až 9 číslic',
                              'Edit period manually, opens dialog with non-repeating part and period 1 to 9 digits',
                            ),
                            onPressed: () {
                              Navigator.pop(lbCtx);
                              Future.delayed(
                                const Duration(milliseconds: 170),
                                () => parent._showPeriodEditDialog(),
                              );
                            },
                            expanded: false,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Semantics(
                  container: true,
                  child: Text(
                    parent._s(
                      'Funguje pro číslo před kurzorem nebo poslední výsledek, vyžaduje desetinnou část. Dlouhý stisk … na hlavní klávesnici dělá totéž.',
                      'Works for number before cursor or last result, requires decimal part. Long press … on main keyboard does the same.',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    sections.add(
      _CollapsibleSection(
        title: parent._s('Zobrazení', 'Display'),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                SizedBox(
                  width: 80 * parent._responsiveScale(ctx),
                  height: 50 * parent._responsiveScale(ctx),
                  child: parent.buildButton(
                    'NORM',
                    semanticLabel: parent._s(
                      'Standardní zobrazení',
                      'Standard display',
                    ),
                    onPressed: () {
                      // ignore: invalid_use_of_protected_member
                      parent.setState(
                        () => parent._displayFormat = DisplayFormat.standard,
                      );
                      parent.speak(
                        parent._s(
                          'Nastaveno standardní zobrazení',
                          'Standard display set',
                        ),
                      );
                      if (parent.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              parent._s(
                                'Nastaveno standardní zobrazení',
                                'Standard display set',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    expanded: false,
                  ),
                ),
                SizedBox(
                  width: 80 * parent._responsiveScale(ctx),
                  height: 50 * parent._responsiveScale(ctx),
                  child: parent.buildButton(
                    'FIX',
                    semanticLabel: parent._s(
                      'Zobrazení s pevným počtem desetinných míst',
                      'Fixed decimal places display',
                    ),
                    onPressed: () =>
                        parent._showPrecisionDialog(DisplayFormat.fix),
                    expanded: false,
                  ),
                ),
                SizedBox(
                  width: 80 * parent._responsiveScale(ctx),
                  height: 50 * parent._responsiveScale(ctx),
                  child: parent.buildButton(
                    'SCI',
                    semanticLabel: parent._s(
                      'Vědecký zápis',
                      'Scientific notation',
                    ),
                    onPressed: () =>
                        parent._showPrecisionDialog(DisplayFormat.sci),
                    expanded: false,
                  ),
                ),
                SizedBox(
                  width: 80 * parent._responsiveScale(ctx),
                  height: 50 * parent._responsiveScale(ctx),
                  child: parent.buildButton(
                    'ENG',
                    semanticLabel: parent._s(
                      'Inženýrský zápis',
                      'Engineering notation',
                    ),
                    onPressed: () =>
                        parent._showPrecisionDialog(DisplayFormat.eng),
                    expanded: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      semanticLabel: parent._s('Pokročilé funkce', 'Advanced functions'),
      title: Semantics(
        header: true,
        child: Text(parent._s('Pokročilé funkce', 'Advanced functions')),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(children: _buildSections(context)),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(parent._s('ZAVŘÍT', 'CLOSE')),
        ),
      ],
    );
  }
}

class _NewsDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  final GitHubReleaseInfo? initialFocusVersion;

  const _NewsDialog({required this.parent, this.initialFocusVersion});

  @override
  State<_NewsDialog> createState() => _NewsDialogState();
}

class _NewsDialogState extends State<_NewsDialog> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  // ignore: unused_field
  String? _errorType;
  List<GitHubReleaseInfo> _releases = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _showingCached = false;
  String? _cachedTimestamp;

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _errorType = null;
        _showingCached = false;
        _cachedTimestamp = null;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    final checker = GitHubReleaseChecker();
    final page = loadMore ? _currentPage + 1 : 1;
    final result = await checker.fetchRecentReleasesWithResult(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      perPage: 30,
      page: page,
    );
    checker.close();
    if (!mounted) return;

    if (result.isSuccess) {
      if (!loadMore) {
        await _saveCache(result.releases);
      }
      setState(() {
        if (loadMore) {
          _releases.addAll(result.releases);
          _currentPage = page;
          _loadingMore = false;
        } else {
          _releases = result.releases;
          _currentPage = 1;
          _loading = false;
        }
        _hasMore = result.releases.length == 30;
        if (_releases.isEmpty) {
          _error = widget.parent._s(
            'Žádné novinky nenalezeny.',
            'No release notes found.',
          );
          _errorType = 'empty';
        } else {
          _error = null;
          _errorType = null;
        }
        _showingCached = false;
        _cachedTimestamp = null;
      });

      if (!loadMore) {
        final focused = widget.initialFocusVersion;
        if (focused != null && result.releases.isNotEmpty) {
          final matching = _findVersion(result.releases, focused.normalizedVersion);
          if (matching != null && matching.plainTextBody.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                widget.parent.speak(
                  widget.parent._s(
                    'Novinky v této verzi. ${matching.plainTextBody}',
                    'What is new in this version. ${matching.plainTextBody}',
                  ),
                  force: true,
                );
              }
            });
          }
        }
      }
    } else {
      // Chyba
      if (!loadMore && _releases.isEmpty) {
        final cached = await _loadCached();
        if (cached != null && cached.releases.isNotEmpty) {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _releases = cached.releases;
            _cachedTimestamp = cached.timestamp;
            _error = _errorMessageForType(result.errorType!);
            _errorType = result.errorType;
            _showingCached = true;
            _hasMore = false;
          });
        } else {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _error = _errorMessageForType(result.errorType!);
            _errorType = result.errorType;
          });
        }
      } else if (loadMore) {
        setState(() {
          _loadingMore = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessageForType(result.errorType!))),
          );
        }
      } else {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = _errorMessageForType(result.errorType!);
          _errorType = result.errorType;
        });
      }
    }
  }

  String _errorMessageForType(String type) {
    switch (type) {
      case 'offline':
        return widget.parent._s(
          'Novinky se nepodařilo načíst. Zkontrolujte připojení k internetu.',
          'News could not be loaded. Check your internet connection.',
        );
      case 'timeout':
        return widget.parent._s(
          'Načítání novinek vypršelo. Zkuste to znovu.',
          'Loading news timed out. Please try again.',
        );
      case 'rateLimit':
        return widget.parent._s(
          'Byl překročen limit GitHub API. Zkuste to znovu za hodinu.',
          'GitHub API rate limit exceeded. Please try again in an hour.',
        );
      case 'notFound':
        return widget.parent._s(
          'Repozitář nebo novinky nebyly nalezeny.',
          'Repository or release notes not found.',
        );
      case 'serverError':
        return widget.parent._s(
          'Chyba serveru GitHub. Zkuste to znovu později.',
          'GitHub server error. Please try again later.',
        );
      case 'empty':
        return widget.parent._s(
          'Žádné novinky nenalezeny.',
          'No release notes found.',
        );
      default:
        return widget.parent._s(
          'Novinky se nepodařilo načíst. Zkuste to znovu.',
          'News could not be loaded. Please try again.',
        );
    }
  }

  Future<void> _saveCache(List<GitHubReleaseInfo> releases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = releases
          .map((r) => {
                'tag_name': r.tagName,
                'html_url': r.htmlUrl,
                'body': r.body,
              })
          .toList();
      await prefs.setString('news_cache_json', jsonEncode(jsonList));
      await prefs.setString('news_cache_timestamp', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<({List<GitHubReleaseInfo> releases, String? timestamp})?>
      _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('news_cache_json');
      final timestamp = prefs.getString('news_cache_timestamp');
      if (jsonStr == null) return null;
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      final releases = decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => GitHubReleaseInfo(
                tagName: (m['tag_name'] as String?) ?? '',
                htmlUrl: m['html_url'] as String?,
                body: m['body'] as String?,
              ))
          .toList();
      if (releases.isEmpty) return null;
      return (releases: releases, timestamp: timestamp);
    } catch (_) {
      return null;
    }
  }

  GitHubReleaseInfo? _findVersion(
    List<GitHubReleaseInfo> releases,
    String normalizedVersion,
  ) {
    for (final release in releases) {
      if (release.normalizedVersion == normalizedVersion) {
        return release;
      }
    }
    return null;
  }

  void _readRelease(GitHubReleaseInfo release) {
    final text = release.plainTextBody;
    if (text.isEmpty) {
      widget.parent.speak(
        widget.parent._s(
          'Tato verze nemá zveřejněné novinky.',
          'This version has no published release notes.',
        ),
        force: true,
      );
      return;
    }
    widget.parent.speak(
      widget.parent._s(
        'Verze ${release.normalizedVersion}. $text',
        'Version ${release.normalizedVersion}. $text',
      ),
      force: true,
    );
  }

  void _readAll() {
    if (_releases.isEmpty) {
      widget.parent.speak(
        widget.parent._s('Nemám co přečíst.', 'There is nothing to read.'),
        force: true,
      );
      return;
    }
    final buffer = StringBuffer();
    for (final release in _releases) {
      buffer.write(
        '${widget.parent._s('Verze', 'Version')} ${release.normalizedVersion}. ',
      );
      buffer.write(release.plainTextBody);
      buffer.write('. ');
    }
    widget.parent.speak(buffer.toString(), force: true);
  }

  Widget _buildReleaseTile(GitHubReleaseInfo release) {
    final body = release.plainTextBody;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Verze ${release.normalizedVersion}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        if (body.isEmpty)
          Text(widget.parent._s('Bez popisu novinek.', 'No release notes.'))
        else
          Text(body),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: widget.parent._s(
              'Přečíst novinky verze ${release.normalizedVersion}',
              'Read release notes of version ${release.normalizedVersion}',
            ),
            child: ElevatedButton.icon(
              onPressed: () => _readRelease(release),
              icon: const Icon(Icons.volume_up),
              label: Text(widget.parent._s('Přečíst novinky', 'Read news')),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  String _formatCachedTimestamp(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$d.$m.$y $hh:$mm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: widget.parent._dialogInsetPadding(),
      semanticLabel: widget.parent._s('Novinky', 'What is new'),
        title: Semantics(
          header: true,
          child: Text(widget.parent._s('Novinky', 'What is new')),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : (_error != null && _releases.isEmpty)
            ? SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  header: true,
                  label: _error,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      Semantics(
                        label: widget.parent._s('Zkusit znovu načíst novinky', 'Try loading news again'),
                        child: FilledButton.icon(
                          onPressed: () => _loadReleases(),
                          icon: const Icon(Icons.refresh),
                          label: Text(widget.parent._s('Zkusit znovu', 'Retry')),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Semantics(
                    explicitChildNodes: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_showingCached && _error != null) ...[
                          Semantics(
                            liveRegion: true,
                            header: true,
                            label: _error,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                  if (_cachedTimestamp != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.parent._s(
                                        'Zobrazeny poslední uložené novinky z ${_formatCachedTimestamp(_cachedTimestamp)}.',
                                        'Showing last saved news from ${_formatCachedTimestamp(_cachedTimestamp)}.',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Semantics(
                                    label: widget.parent._s('Zkusit znovu načíst novinky', 'Try loading news again'),
                                    child: FilledButton.icon(
                                      onPressed: () => _loadReleases(),
                                      icon: const Icon(Icons.refresh),
                                      label: Text(widget.parent._s('Zkusit znovu', 'Retry')),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            label: widget.parent._s(
                              'Přečíst všechny novinky',
                              'Read all release notes',
                            ),
                            child: FilledButton.icon(
                              autofocus: true,
                              onPressed: _readAll,
                              icon: const Icon(Icons.volume_up),
                              label: Text(
                                widget.parent._s('Přečíst vše', 'Read all'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.initialFocusVersion != null) ...[
                          Semantics(
                            header: true,
                            child: Text(
                              widget.parent._s(
                                'Co je nového v této verzi',
                                'What is new in this version',
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildReleaseTile(widget.initialFocusVersion!),
                          const SizedBox(height: 8),
                          Semantics(
                            header: true,
                            child: Text(
                              widget.parent._s('Starší verze', 'Older versions'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          Semantics(
                            header: true,
                            child: Text(
                              widget.parent._s('Seznam novinek', 'Release list'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        ..._releases
                            .where(
                              (release) =>
                                  widget.initialFocusVersion == null ||
                                  release.normalizedVersion !=
                                      widget.initialFocusVersion!.normalizedVersion,
                            )
                            .map(_buildReleaseTile),
                        if (_hasMore && !_showingCached) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: _loadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(),
                                  )
                                : Semantics(
                                    label: widget.parent._s(
                                      'Načíst starší verze novinek',
                                      'Load older release notes',
                                    ),
                                    child: FilledButton.tonalIcon(
                                      onPressed: () => _loadReleases(loadMore: true),
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(widget.parent._s('Načíst starší verze', 'Load older versions')),
                                    ),
                                  ),
                          ),
                        ],
                        if (!_hasMore && _releases.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              widget.parent._s('Žádné další verze.', 'No more versions.'),
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.parent._s('Zavřít', 'Close')),
          ),
        ],
    );
  }
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
      insetPadding: widget.parent._dialogInsetPadding(),
      semanticLabel: widget.parent._l10n.accessibilitySettings,
      title: Semantics(
        header: true,
        child: Text(widget.parent._l10n.accessibilitySettings),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: widget.parent._s(
                'Přepnutí typu displeje',
                'Switch display type',
              ),
              child: ElevatedButton(
                autofocus: true,
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () => widget.parent._useSixteenSegment =
                          !widget.parent._useSixteenSegment,
                    );
                    widget.parent._saveSettings();
                  });
                  widget.parent.speak(
                    widget.parent._useSixteenSegment
                        ? widget.parent._l10n.segment16On
                        : widget.parent._l10n.segment7On,
                  );
                },
                child: Text(
                  widget.parent._l10n.displayType(
                    widget.parent._useSixteenSegment
                        ? widget.parent._s('16-segmentový', '16-segment')
                        : widget.parent._s('7-segmentový', '7-segment'),
                  ),
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Přepnutí periodického zápisu výsledků',
                'Switch repeating decimal notation for results',
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () => widget.parent._usePeriodicNotation =
                          !widget.parent._usePeriodicNotation,
                    );
                  });
                  widget.parent._saveSettings();
                  widget.parent.speak(
                    widget.parent._usePeriodicNotation
                        ? widget.parent._s(
                            'Periodický zápis výsledků zapnut',
                            'Repeating decimal notation for results on',
                          )
                        : widget.parent._s(
                            'Periodický zápis výsledků vypnut',
                            'Repeating decimal notation for results off',
                          ),
                  );
                },
                child: Text(
                  widget.parent._s(
                    'Periodický zápis výsledků',
                    'Repeating decimal notation for results',
                  ) +
                      ': ' +
                      (widget.parent._usePeriodicNotation
                          ? widget.parent._s('Zapnuto', 'On')
                          : widget.parent._s('Vypnuto', 'Off')),
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Přepnutí hlasového výstupu',
                'Switch voice output',
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () =>
                          widget.parent.ttsEnabled = !widget.parent.ttsEnabled,
                    );
                    widget.parent._saveSettings();
                  });
                  widget.parent.speak(
                    widget.parent.ttsEnabled
                        ? widget.parent._l10n.voiceOn
                        : widget.parent._l10n.voiceOff,
                  );
                },
                child: Text(
                  widget.parent._l10n.voiceOutput(
                    widget.parent.ttsEnabled
                        ? widget.parent._s('Zapnuto', 'On')
                        : widget.parent._s('Vypnuto', 'Off'),
                  ),
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Přepnutí oznamování příkladu před výpočtem',
                'Switch announcing expression before calculation',
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () => widget.parent._announceExpression =
                          !widget.parent._announceExpression,
                    );
                    widget.parent._saveSettings();
                  });
                  widget.parent.speak(
                    widget.parent._l10n.announceExpressionState(
                      widget.parent._announceExpression
                          ? widget.parent._s('Zapnuto', 'On')
                          : widget.parent._s('Vypnuto', 'Off'),
                    ),
                  );
                },
                child: Text(
                  widget.parent._l10n.announceExpressionState(
                    widget.parent._announceExpression
                        ? widget.parent._s('Zapnuto', 'On')
                        : widget.parent._s('Vypnuto', 'Off'),
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
                  label: widget.parent._s(
                    'Režim čtečky obrazovky',
                    'Screen reader mode',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s(
                        'Režim čtečky obrazovky',
                        'Screen reader mode',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ScreenReaderMode>(
                  segments: [
                    ButtonSegment(
                      value: ScreenReaderMode.auto,
                      label: Semantics(
                        label: widget.parent._s(
                          'Automaticky podle čtečky',
                          'Automatic according to screen reader',
                        ),
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Auto', 'Auto')),
                        ),
                      ),
                      tooltip: widget.parent._s(
                        'Automaticky podle čtečky',
                        'Automatic according to screen reader',
                      ),
                    ),
                    ButtonSegment(
                      value: ScreenReaderMode.on,
                      label: Semantics(
                        label: widget.parent._s(
                          'Režim čtečky obrazovky zapnut',
                          'Screen reader mode on',
                        ),
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Zapnuto', 'On')),
                        ),
                      ),
                      tooltip: widget.parent._s(
                        'Režim čtečky obrazovky zapnut',
                        'Screen reader mode on',
                      ),
                    ),
                    ButtonSegment(
                      value: ScreenReaderMode.off,
                      label: Semantics(
                        label: widget.parent._s(
                          'Režim čtečky obrazovky vypnut',
                          'Screen reader mode off',
                        ),
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Vypnuto', 'Off')),
                        ),
                      ),
                      tooltip: widget.parent._s(
                        'Režim čtečky obrazovky vypnut',
                        'Screen reader mode off',
                      ),
                    ),
                  ],
                  selected: {widget.parent._screenReaderMode},
                  onSelectionChanged: (Set<ScreenReaderMode> selected) {
                    final mode = selected.first;
                    setState(() {
                      widget.parent.setState(() {
                        widget.parent._screenReaderMode = mode;
                      });
                      widget.parent._saveSettings();
                    });
                    widget.parent.speak(
                      mode == ScreenReaderMode.auto
                          ? widget.parent._s(
                              'Režim čtečky: automaticky',
                              'Screen reader mode: automatic',
                            )
                          : mode == ScreenReaderMode.on
                          ? widget.parent._s(
                              'Režim čtečky obrazovky zapnut',
                              'Screen reader mode on',
                            )
                          : widget.parent._s(
                              'Režim čtečky obrazovky vypnut',
                              'Screen reader mode off',
                            ),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Nastavení hlasového engine',
                'Voice engine settings',
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.parent._showTtsEngineDialog();
                },
                child: Text(
                  '${widget.parent._s('Engine', 'Engine')}: ${widget.parent._ttsEngine ?? widget.parent._s('Výchozí', 'Default')}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Otevřít systémové nastavení TTS',
                'Open system TTS settings',
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.parent._openTtsSystemSettings();
                },
                child: Text(widget.parent._s('Nastavení TTS', 'TTS settings')),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s('Nastavení hlasu', 'Voice settings'),
              child: ElevatedButton(
                onPressed: () {
                  widget.parent._showTtsVoiceDialog();
                },
                child: Text(
                  '${widget.parent._s('Hlas', 'Voice')}: ${widget.parent._ttsVoiceName ?? widget.parent._s('Výchozí', 'Default')}',
                ),
              ),
            ),
            const Divider(),
            Semantics(
              label: widget.parent._s(
                'Přepnutí formátu úhlů',
                'Switch angle format',
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Pokud je null nebo 1, nastavíme na 0 (DMS). Pokud je 0, nastavíme na 1 (Desetinné).
                  final current = widget.parent._inverseFormatPreference ?? 1;
                  final newFormat = (current == 0) ? 1 : 0;

                  widget.parent._saveInversePreference(newFormat);

                  widget.parent.speak(
                    newFormat == 0
                        ? widget.parent._l10n.formatDms
                        : widget.parent._l10n.formatDecimalDegrees,
                  );
                  // Vynucené překreslení dialogu
                  setState(() {});
                },
                child: Text(
                  widget.parent._s(
                    'Úhly: ${(widget.parent._inverseFormatPreference == 0) ? 'DMS' : 'Desetinné'}',
                    'Angles: ${(widget.parent._inverseFormatPreference == 0) ? 'DMS' : 'Decimal'}',
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
                  label: widget.parent._s(
                    'Výběr motivu aplikace',
                    'App theme selection',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s('Motiv aplikace', 'App theme'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Semantics(
                        label: widget.parent._l10n.themeSystemLabel,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Systém', 'System')),
                        ),
                      ),
                      icon: Icon(Icons.brightness_auto),
                      tooltip: widget.parent._l10n.themeSystemLabel,
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Semantics(
                        label: widget.parent._l10n.themeLightLabel,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Světlý', 'Light')),
                        ),
                      ),
                      icon: Icon(Icons.light_mode),
                      tooltip: widget.parent._l10n.themeLightLabel,
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Semantics(
                        label: widget.parent._l10n.themeDarkLabel,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._s('Tmavý', 'Dark')),
                        ),
                      ),
                      icon: Icon(Icons.dark_mode),
                      tooltip: widget.parent._l10n.themeDarkLabel,
                    ),
                  ],
                  selected: {widget.parent.widget.themeMode},
                  onSelectionChanged: (Set<ThemeMode> selection) {
                    ThemeMode mode = selection.first;
                    widget.parent.widget.onThemeModeChanged(mode);
                    String modeName;
                    if (mode == ThemeMode.light) {
                      modeName = widget.parent._l10n.themeLight;
                    } else if (mode == ThemeMode.dark) {
                      modeName = widget.parent._l10n.themeDark;
                    } else {
                      modeName = widget.parent._l10n.themeSystem;
                    }
                    widget.parent.speak(widget.parent._l10n.themeSet(modeName));
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Výchozí režim po spuštění
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._s(
                    'Výchozí režim po spuštění',
                    'Default mode on startup',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s(
                        'Výchozí režim po spuštění',
                        'Default mode on startup',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<CalculatorMode>(
                    showSelectedIcon: false,
                    segments: CalculatorMode.values.map((mode) {
                      final modeName = widget.parent._getModeName(mode);
                      return ButtonSegment(
                        value: mode,
                        label: Semantics(
                          label: modeName,
                          child: ExcludeSemantics(child: Text(modeName)),
                        ),
                        tooltip: modeName,
                      );
                    }).toList(),
                    selected: {widget.parent._defaultMode},
                    onSelectionChanged: (Set<CalculatorMode> selected) {
                      final mode = selected.first;
                      widget.parent._setDefaultMode(mode);
                      widget.parent.speak(
                        widget.parent._s(
                          'Výchozí režim nastaven na ${widget.parent._getModeSpeechName(mode)}',
                          'Default mode set to ${widget.parent._getModeSpeechName(mode)}',
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Velikost dialogů
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.dialogSizeSetting,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.dialogSizeSetting),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<DialogSize>(
                  segments: [
                    ButtonSegment(
                      value: DialogSize.compact,
                      label: Semantics(
                        label: widget.parent._l10n.dialogSizeCompact,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._l10n.dialogSizeCompact),
                        ),
                      ),
                      icon: const Icon(Icons.phone_android),
                      tooltip: widget.parent._l10n.dialogSizeCompact,
                    ),
                    ButtonSegment(
                      value: DialogSize.wide,
                      label: Semantics(
                        label: widget.parent._l10n.dialogSizeWide,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._l10n.dialogSizeWide),
                        ),
                      ),
                      icon: const Icon(Icons.phone_iphone),
                      tooltip: widget.parent._l10n.dialogSizeWide,
                    ),
                    ButtonSegment(
                      value: DialogSize.fullscreen,
                      label: Semantics(
                        label: widget.parent._l10n.dialogSizeFullscreen,
                        child: ExcludeSemantics(
                          child: Text(widget.parent._l10n.dialogSizeFullscreen),
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen),
                      tooltip: widget.parent._l10n.dialogSizeFullscreen,
                    ),
                  ],
                  selected: {widget.parent._dialogSize},
                  onSelectionChanged: (Set<DialogSize> selected) {
                    final size = selected.first;
                    setState(() {
                      widget.parent.setState(() {
                        widget.parent._dialogSize = size;
                      });
                      widget.parent._saveSettings();
                    });
                    String sizeName = widget.parent._l10n.dialogSizeCompact;
                    if (size == DialogSize.wide) {
                      sizeName = widget.parent._l10n.dialogSizeWide;
                    } else if (size == DialogSize.fullscreen) {
                      sizeName = widget.parent._l10n.dialogSizeFullscreen;
                    }
                    widget.parent.speak(
                      '${widget.parent._l10n.dialogSizeSetting}: $sizeName',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.zoomUpperControls,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.zoomUpper),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._s(
                        'Zmenšit zoom horního řádku',
                        'Decrease upper line zoom',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustDotMatrixZoom(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.parent._s(
                          'Hodnota zoomu: ${(widget.parent._dotMatrixZoom * 100).toInt()} %',
                          'Zoom value: ${(widget.parent._dotMatrixZoom * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._dotMatrixZoom * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: widget.parent._s(
                        'Zvětšit zoom horního řádku',
                        'Increase upper line zoom',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustDotMatrixZoom(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
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
                  label: widget.parent._l10n.zoomLowerControls,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.zoomLower),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._s(
                        'Zmenšit zoom dolního řádku',
                        'Decrease lower line zoom',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustResultZoom(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.parent._s(
                          'Hodnota zoomu: ${(widget.parent._resultZoom * 100).toInt()} %',
                          'Zoom value: ${(widget.parent._resultZoom * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._resultZoom * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: widget.parent._s(
                        'Zvětšit zoom dolního řádku',
                        'Increase lower line zoom',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustResultZoom(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
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
                  label: widget.parent._s(
                    'Tloušťka periodické čárky',
                    'Repeating bar thickness',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s(
                        'Tloušťka periodické čárky',
                        'Repeating bar thickness',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  label: widget.parent._s(
                    'Náhled periodické čárky s aktuální tloušťkou',
                    'Preview of repeating bar with current thickness',
                  ),
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: Column(
                        children: [
                          CustomDotMatrixDisplay(
                            text: '0.3\u0305',
                            ledSize: 2.5,
                            ledSpacing: 0.6,
                            overlineThickness: widget.parent._overlineThickness,
                          ),
                          const SizedBox(height: 6),
                          CustomSegmentDisplay(
                            value: '0.3\u0305',
                            size: 12,
                            characterCount: 4,
                            isSixteenSegment: widget.parent._useSixteenSegment,
                            overlineThickness: widget.parent._overlineThickness,
                          ),
                          const SizedBox(height: 4),
                          _PeriodicText(
                            '0,(3)',
                            overlineThickness: widget.parent._overlineThickness,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._s(
                        'Zmenšit tloušťku periodické čárky',
                        'Decrease repeating bar thickness',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustOverlineThickness(-0.2),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.parent._s(
                          'Tloušťka periodické čárky: ${(widget.parent._overlineThickness * 100).toInt()} %',
                          'Repeating bar thickness: ${(widget.parent._overlineThickness * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._overlineThickness * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: widget.parent._s(
                        'Zvětšit tloušťku periodické čárky',
                        'Increase repeating bar thickness',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustOverlineThickness(0.2),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: widget.parent._s(
                'Přepnout zarovnání vstupního řádku vlevo',
                'Toggle left alignment of input line',
              ),
              child: ElevatedButton.icon(
                icon: Icon(
                  widget.parent._alignInputLeft
                      ? Icons.format_align_left
                      : Icons.format_align_center,
                ),
                onPressed: () {
                  setState(() {
                    widget.parent.setState(
                      () => widget.parent._alignInputLeft =
                          !widget.parent._alignInputLeft,
                    );
                    widget.parent._saveSettings();
                  });
                  widget.parent.speak(
                    widget.parent._s(
                      widget.parent._alignInputLeft
                          ? 'Vstupní řádek zarovnán vlevo'
                          : 'Vstupní řádek zarovnán na střed',
                      widget.parent._alignInputLeft
                          ? 'Input line aligned left'
                          : 'Input line centered',
                    ),
                  );
                },
                label: Text(
                  widget.parent._s(
                    widget.parent._alignInputLeft
                        ? 'Vstupní řádek: vlevo'
                        : 'Vstupní řádek: na střed',
                    widget.parent._alignInputLeft
                        ? 'Input line: left'
                        : 'Input line: centered',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._s(
                    'Ovládání velikosti písma dialogů',
                    'Dialog font size controls',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s(
                        'Velikost písma dialogů',
                        'Dialog font size',
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._s(
                        'Zmenšit písmo dialogů',
                        'Decrease dialog font size',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustDialogFontScale(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.parent._s(
                          'Hodnota velikosti písma dialogů: ${(widget.parent._dialogFontScale * 100).toInt()} %',
                          'Dialog font size value: ${(widget.parent._dialogFontScale * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._dialogFontScale * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: widget.parent._s(
                        'Zvětšit písmo dialogů',
                        'Increase dialog font size',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustDialogFontScale(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
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
                  label: widget.parent._s(
                    'Ovládání velikosti písma tlačítek',
                    'Keyboard button font size controls',
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._s(
                        'Velikost písma tlačítek',
                        'Keyboard button font size',
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._s(
                        'Zmenšit písmo tlačítek',
                        'Decrease keyboard button font size',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustKeyboardFontScale(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.parent._s(
                          'Hodnota velikosti písma tlačítek: ${(widget.parent._keyboardFontScale * 100).toInt()} %',
                          'Keyboard button font size value: ${(widget.parent._keyboardFontScale * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._keyboardFontScale * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: widget.parent._s(
                        'Zvětšit písmo tlačítek',
                        'Increase keyboard button font size',
                      ),
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustKeyboardFontScale(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Semantics(
                  container: true,
                  child: Text(
                    widget.parent._s(
                      'Na malém displeji se při velkém písmu klávesnice posouvá.',
                      'On a small display the keyboard scrolls with large font.',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                // Náhled velikosti tlačítek – stejná velikost jako ve Statistickém režimu
                Semantics(
                  label: widget.parent._s(
                    'Náhled tlačítek s aktuální velikostí písma',
                    'Preview of buttons with current font size',
                  ),
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 44 * widget.parent._responsiveScale(context),
                            child: widget.parent.buildButton(
                              '7',
                              expanded: false,
                              onPressed: () {},
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            height: 44 * widget.parent._responsiveScale(context),
                            child: widget.parent.buildButton(
                              '8',
                              expanded: false,
                              onPressed: () {},
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            height: 44 * widget.parent._responsiveScale(context),
                            child: widget.parent.buildButton(
                              '9',
                              expanded: false,
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.speechRateControls,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.speechRate),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._l10n.decreaseSpeechRate,
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechRate(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.parent._l10n.speechRateValue(
                          (widget.parent._speechRate * 100).toInt(),
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._speechRate * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: widget.parent._l10n.increaseSpeechRate,
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechRate(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
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
                  label: widget.parent._s(
                    'Ovládání hlasitosti',
                    'Volume controls',
                  ),
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.volume),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._l10n.decreaseVolume,
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechVolume(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.parent._s(
                          'Aktuální hlasitost: ${(widget.parent._speechVolume * 100).toInt()} %',
                          'Current volume: ${(widget.parent._speechVolume * 100).toInt()} %',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${(widget.parent._speechVolume * 100).toInt()}%',
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: widget.parent._l10n.increaseVolume,
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechVolume(0.1),
                        child: ExcludeSemantics(child: const Text('+')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Column(
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.dataManagementSection,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.dataManagementTitle),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: widget.parent._l10n.backupData,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.backup),
                        onPressed: () {
                          widget.parent._exportBackup();
                          Navigator.pop(context);
                        },
                        label: Text(widget.parent._l10n.backupData),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Semantics(
                      label: widget.parent._l10n.restoreData,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restore),
                        onPressed: () async {
                          final confirmed =
                              await widget.parent.showAppDialog<bool>(
                            context: context,
                            routeSettings: const RouteSettings(
                              name: 'Potvrzení',
                            ),
                            builder: (ctx) => AlertDialog(
      insetPadding: widget.parent._dialogInsetPadding(),
                              semanticLabel:
                                  widget.parent._l10n.confirmationTitle,
                              title: Text(
                                widget.parent._l10n.confirmationTitle,
                              ),
                              content: Text(widget.parent._l10n.restoreConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(widget.parent._l10n.noShort),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(widget.parent._l10n.yesShort),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            widget.parent._importBackup();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        label: Text(widget.parent._l10n.restoreData),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(widget.parent._l10n.done),
        ),
      ],
    );
  }

  void _adjustDotMatrixZoom(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._dotMatrixZoom = (widget.parent._dotMatrixZoom + delta)
            .clamp(0.5, 5.0);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      widget.parent._l10n.zoomUpperPct(
        (widget.parent._dotMatrixZoom * 100).toInt(),
      ),
    );
  }

  void _adjustResultZoom(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._resultZoom = (widget.parent._resultZoom + delta).clamp(
          0.5,
          5.0,
        );
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      widget.parent._l10n.zoomLowerPct(
        (widget.parent._resultZoom * 100).toInt(),
      ),
    );
  }

  void _adjustSpeechRate(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._speechRate = (widget.parent._speechRate + delta).clamp(
          0.1,
          1.0,
        );
        widget.parent.tts.setSpeechRate(widget.parent._speechRate);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      widget.parent._l10n.speechRatePct(
        (widget.parent._speechRate * 100).toInt(),
      ),
    );
  }

  void _adjustSpeechVolume(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._speechVolume = (widget.parent._speechVolume + delta)
            .clamp(0.0, 1.0);
        widget.parent.tts.setVolume(widget.parent._speechVolume);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      widget.parent._l10n.volumePct(
        (widget.parent._speechVolume * 100).toInt(),
      ),
    );
  }

  void _adjustDialogFontScale(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._dialogFontScale = (widget.parent._dialogFontScale + delta)
            .clamp(0.5, 5.0);
        widget.parent._dialogFontScaleNotifier.value =
            widget.parent._dialogFontScale;
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      widget.parent._s(
        'Velikost písma dialogů ${(widget.parent._dialogFontScale * 100).toInt()} procent',
        'Dialog font size ${(widget.parent._dialogFontScale * 100).toInt()} percent',
      ),
    );
  }

  void _adjustKeyboardFontScale(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._keyboardFontScale =
            (widget.parent._keyboardFontScale + delta).clamp(0.7, 2.5);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      widget.parent._s(
        'Velikost písma tlačítek ${(widget.parent._keyboardFontScale * 100).toInt()} procent',
        'Keyboard button font size ${(widget.parent._keyboardFontScale * 100).toInt()} percent',
      ),
    );
  }

  void _adjustOverlineThickness(double delta) {
    setState(() {
      widget.parent.setState(() {
        widget.parent._overlineThickness = (widget.parent._overlineThickness + delta)
            .clamp(0.8, 4.0);
      });
      widget.parent._saveSettings();
    });
    widget.parent.speak(
      widget.parent._s(
        'Tloušťka periodické čárky ${(widget.parent._overlineThickness * 100).toInt()} procent',
        'Repeating bar thickness ${(widget.parent._overlineThickness * 100).toInt()} percent',
      ),
    );
  }
}
