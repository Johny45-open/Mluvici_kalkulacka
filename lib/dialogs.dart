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
  String? _error;
  List<GitHubReleaseInfo> _releases = [];

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final checker = GitHubReleaseChecker();
    final releases = await checker.fetchRecentReleases(
      owner: 'Johny45-open',
      repo: 'Mluvici_kalkulacka',
      perPage: 10,
    );
    checker.close();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _releases = releases;
      if (releases.isEmpty) {
        _error = widget.parent._s(
          'Novinky se nepodařilo načíst. Zkontrolujte připojení k internetu.',
          'News could not be loaded. Check your internet connection.',
        );
      }
    });

    final focused = widget.initialFocusVersion;
    if (focused != null && releases.isNotEmpty) {
      final matching = _findVersion(releases, focused.normalizedVersion);
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
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(label: _error, child: Text(_error!)),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        label: widget.parent._s(
                          'Přečíst všechny novinky',
                          'Read all release notes',
                        ),
                        child: FilledButton.icon(
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
                    ],
                    ..._releases
                        .where(
                          (release) =>
                              widget.initialFocusVersion == null ||
                              release.normalizedVersion !=
                                  widget.initialFocusVersion!.normalizedVersion,
                        )
                        .map(_buildReleaseTile),
                  ],
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
                      container: true,
                      label: widget.parent._s(
                        'Zmenšit zoom horního řádku',
                        'Decrease upper line zoom',
                      ),
                      child: ElevatedButton(
                        onPressed: () => _adjustDotMatrixZoom(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
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
                      container: true,
                      label: widget.parent._s(
                        'Zvětšit zoom horního řádku',
                        'Increase upper line zoom',
                      ),
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
                      container: true,
                      label: widget.parent._s(
                        'Zmenšit zoom dolního řádku',
                        'Decrease lower line zoom',
                      ),
                      child: ElevatedButton(
                        onPressed: () => _adjustResultZoom(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
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
                      container: true,
                      label: widget.parent._s(
                        'Zvětšit zoom dolního řádku',
                        'Increase lower line zoom',
                      ),
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
                  label: widget.parent._l10n.speechRateControls,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.speechRate),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      container: true,
                      label: widget.parent._l10n.decreaseSpeechRate,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechRate(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
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
                      container: true,
                      label: widget.parent._l10n.increaseSpeechRate,
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
                      container: true,
                      label: widget.parent._l10n.decreaseVolume,
                      child: ElevatedButton(
                        onPressed: () => _adjustSpeechVolume(-0.1),
                        child: ExcludeSemantics(child: const Text('-')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        container: true,
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
                      container: true,
                      label: widget.parent._l10n.increaseVolume,
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
                          final confirmed = await showDialog<bool>(
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
}
