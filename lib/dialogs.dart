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
                    Padding(
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
                                  onPressed: () async {
                                    await parent._handleButtonPressed(b);
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
                    onPressed: () async {
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

    if (parent._currentMode == CalculatorMode.time) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    parent._l10n.timeHelp,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      LayoutBuilder(
                        builder: (lbCtx, lbC) {
                          final w = lbC.maxWidth.isFinite
                              ? lbC.maxWidth
                              : MediaQuery.of(lbCtx).size.width * 0.85;
                          final s = parent._responsiveScale(lbCtx);
                          return SizedBox(
                            width: (w - 4) / 2,
                            height: 50 * s,
                            child: parent.buildButton(
                              'NOW',
                              semanticLabel: parent._l10n.timeNowHint,
                              onPressed: () async =>
                                  parent._insertCurrentTime(),
                              expanded: false,
                            ),
                          );
                        },
                      ),
                      LayoutBuilder(
                        builder: (lbCtx, lbC) {
                          final w = lbC.maxWidth.isFinite
                              ? lbC.maxWidth
                              : MediaQuery.of(lbCtx).size.width * 0.85;
                          final s = parent._responsiveScale(lbCtx);
                          return SizedBox(
                            width: (w - 4) / 2,
                            height: 50 * s,
                            child: parent.buildButton(
                              'DIFF',
                              semanticLabel: parent._l10n.timeDiffHint,
                              onPressed: () async =>
                                  await parent._handleButtonPressed('DIFF'),
                              expanded: false,
                            ),
                          );
                        },
                      ),
                      LayoutBuilder(
                        builder: (lbCtx, lbC) {
                          final w = lbC.maxWidth.isFinite
                              ? lbC.maxWidth
                              : MediaQuery.of(lbCtx).size.width * 0.85;
                          final s = parent._responsiveScale(lbCtx);
                          return SizedBox(
                            width: (w - 4) / 2,
                            height: 50 * s,
                            child: parent.buildButton(
                              'TO_SEC',
                              semanticLabel: parent._l10n.timeToSec,
                              onPressed: () async =>
                                  await parent._handleButtonPressed('TO_SEC'),
                              expanded: false,
                            ),
                          );
                        },
                      ),
                      LayoutBuilder(
                        builder: (lbCtx, lbC) {
                          final w = lbC.maxWidth.isFinite
                              ? lbC.maxWidth
                              : MediaQuery.of(lbCtx).size.width * 0.85;
                          final s = parent._responsiveScale(lbCtx);
                          return SizedBox(
                            width: (w - 4) / 2,
                            height: 50 * s,
                            child: parent.buildButton(
                              'TO_HMS',
                              semanticLabel: parent._l10n.timeToHms,
                              onPressed: () async =>
                                  await parent._handleButtonPressed('TO_HMS'),
                              expanded: false,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (parent._currentMode == CalculatorMode.currency) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: parent._l10n.currencyFromLabel,
                          child: DropdownButtonFormField<String>(
                            initialValue: parent._currencyFrom,
                            isExpanded: true,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: parent._l10n.currencyFromLabel,
                            ),
                            items: parent._currencyRates.keys
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              parent.setState(() => parent._currencyFrom = v);
                              parent._saveCurrencyRates();
                              parent.speak(parent._s('Z měny $v', 'From $v'));
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward),
                      Expanded(
                        child: Semantics(
                          label: parent._l10n.currencyToLabel,
                          child: DropdownButtonFormField<String>(
                            initialValue: parent._currencyTo,
                            isExpanded: true,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: parent._l10n.currencyToLabel,
                            ),
                            items: parent._currencyRates.keys
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              parent.setState(() => parent._currencyTo = v);
                              parent._saveCurrencyRates();
                              parent.speak(parent._s('Na měnu $v', 'To $v'));
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      parent._currencyLastUpdate == null
                          ? parent._s(
                              'Kurzy dosud neaktualizovány',
                              'Rates not yet updated',
                            )
                          : parent._l10n.currencyLastUpdate(
                              parent._formatCurrencyDate(
                                parent._currencyLastUpdate,
                              ),
                            ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: parent._convertCurrency,
                      icon: const Icon(Icons.sync),
                      label: Text(parent._s('PŘEVÉST', 'CONVERT')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: parent._l10n.currencyUpdateButton,
                          child: FilledButton.icon(
                            onPressed: parent._currencyLoading
                                ? null
                                : () async {
                                    await parent._updateCurrencyRatesOnline(
                                      silent: false,
                                    );
                                    setState(() {});
                                  },
                            icon: parent._currencyLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh, size: 18),
                            label: Text(parent._l10n.currencyUpdateButton),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          label: parent._l10n.currencyManageTitle,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                parent._showCurrencyManagerDialog(),
                            icon: const Icon(Icons.settings, size: 18),
                            label: Text(
                              parent._l10n.currencyManageButton,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (parent._currencyLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          parent._l10n.currencyUpdating,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
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
                        child: parent.buildButton(b, expanded: false),
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
                    '°→RAD',
                    'RAD→°',
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
                          child: parent.buildButton(b, expanded: false),
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
                          child: parent.buildButton(b, expanded: false),
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
                            semanticLabel: parent._s(
                              'Proměnná $b',
                              'Variable $b',
                            ),
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
                      label: Text(
                        parent._s(
                          'Vymazat všechny proměnné',
                          'Clear all variables',
                        ),
                      ),
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
                        final hasPeriod = RegExp(r'\(\d+\)$').hasMatch(
                          parent.display.isEmpty && parent._hasResult
                              ? parent._lastResult
                              : parent.display,
                        );
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
                Text(
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
                        parent._showAccessibleSnackBar(
                          parent._s(
                            'Nastaveno standardní zobrazení',
                            'Standard display set',
                          ),
                          scaffoldContext: ctx,
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

class _CurrencyManagerDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _CurrencyManagerDialog({required this.parent});
  @override
  State<_CurrencyManagerDialog> createState() => _CurrencyManagerDialogState();
}

class _CurrencyManagerDialogState extends State<_CurrencyManagerDialog> {
  late _CalculatorScreenState parent;
  late Map<String, double> _rates;
  @override
  void initState() {
    super.initState();
    parent = widget.parent;
    _rates = Map<String, double>.from(parent._currencyRates);
  }

  @override
  Widget build(BuildContext context) {
    final sortedKeys = _rates.keys.toList()..sort();
    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      title: Semantics(
        header: true,
        child: Text(parent._l10n.currencyManageTitle),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sortedKeys.isEmpty) Text(parent._l10n.currencyNoRates),
              ...sortedKeys.map((code) {
                final isCzk = code == 'CZK';
                final controller = TextEditingController(
                  text: _rates[code]!.toStringAsFixed(4).replaceAll('.', ','),
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          code,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: parent._l10n.currencyRateLabel(code),
                          child: TextField(
                            controller: controller,
                            enabled: !isCzk,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: isCzk
                                  ? parent._l10n.currencyCzkLocked
                                  : parent._l10n.currencyRateLabel(code),
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (v) {
                              if (isCzk) return;
                              final parsed = double.tryParse(
                                v.replaceAll(',', '.').trim(),
                              );
                              if (parsed == null || parsed <= 0) {
                                parent.speak(parent._l10n.currencyInvalidRate);
                                parent._showAccessibleSnackBar(
                                  parent._l10n.currencyInvalidRate,
                                  scaffoldContext: context,
                                );
                                return;
                              }
                              setState(() => _rates[code] = parsed);
                              parent.speak(
                                parent._s(
                                  'Kurz $code nastaven na ${v.replaceAll('.', ',')}',
                                  'Rate $code set to $v',
                                ),
                              );
                            },
                            onChanged: (v) {
                              final parsed = double.tryParse(
                                v.replaceAll(',', '.').trim(),
                              );
                              if (parsed != null && parsed > 0 && !isCzk) {
                                _rates[code] = parsed;
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!isCzk)
                        IconButton(
                          tooltip: parent._s(
                            'Smazat měnu $code',
                            'Delete $code',
                          ),
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            setState(() => _rates.remove(code));
                            parent.speak(
                              parent._s(
                                'Měna $code smazána',
                                'Currency $code deleted',
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Semantics(
                  label: parent._s('Přidat novou měnu', 'Add new currency'),
                child: FilledButton.icon(
                  onPressed: () async {
                    final code = await parent.showAppDialog<String>(
                      context: context,
                      builder: (dCtx) {
                        final ctrl = TextEditingController();
                        // Bez vnějšího Padding(viewInsets): odsazení řeší
                        // DialogRoute. Vnitřní SingleChildScrollView drží
                        // TextField viditelný nad klávesnicí.
                        return AlertDialog(
                          insetPadding: parent._dialogInsetPadding(),
                          title: Semantics(
                            header: true,
                            child: Text(parent._l10n.currencyAddTitle),
                          ),
                          content: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(dCtx).viewInsets.bottom,
                            ),
                            child: TextField(
                              controller: ctrl,
                              autofocus: true,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: parent._l10n.currencyCodeLabel,
                                border: const OutlineInputBorder(),
                              ),
                              maxLength: 3,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: Text(parent._l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(
                                dCtx,
                                ctrl.text.trim().toUpperCase(),
                              ),
                              child: Text(parent._l10n.currencyAddButton),
                            ),
                          ],
                        );
                      },
                    );
                    if (code != null && code.isNotEmpty) {
                      if (code.length != 3 ||
                          !RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
                        if (mounted)
                          parent._showAccessibleSnackBar(
                            parent._s(
                              'Neplatný kód měny',
                              'Invalid currency code',
                            ),
                            scaffoldContext: context,
                          );
                        return;
                      }
                      if (_rates.containsKey(code)) {
                        if (mounted)
                          parent._showAccessibleSnackBar(
                            parent._s(
                              'Měna již existuje',
                              'Currency already exists',
                            ),
                            scaffoldContext: context,
                          );
                        return;
                      }
                      setState(() => _rates[code] = 1.0);
                      parent.speak(
                        parent._s('Měna $code přidána', 'Currency $code added'),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(parent._l10n.currencyAddTitle),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(parent._l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            // Validate
            for (final e in _rates.entries) {
              if (e.value <= 0) {
                parent._showAccessibleSnackBar(
                  '${parent._l10n.currencyInvalidRate}: ${e.key}',
                  scaffoldContext: context,
                );
                return;
              }
            }
            parent.setState(
              () => parent._currencyRates = Map<String, double>.from(_rates),
            );
            if (!parent._currencyRates.containsKey(parent._currencyFrom))
              parent._currencyFrom = 'CZK';
            if (!parent._currencyRates.containsKey(parent._currencyTo))
              parent._currencyTo = 'CZK';
            parent._saveCurrencyRates();
            parent.speak(parent._s('Kurzy uloženy', 'Rates saved'));
            Navigator.pop(context);
            parent.setState(() {});
          },
          child: Text(parent._l10n.confirmAction),
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
          final matching = _findVersion(
            result.releases,
            focused.normalizedVersion,
          );
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
          widget.parent._showAccessibleSnackBar(
            _errorMessageForType(result.errorType!),
            scaffoldContext: context,
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
          .map(
            (m) => GitHubReleaseInfo(
              tagName: (m['tag_name'] as String?) ?? '',
              htmlUrl: m['html_url'] as String?,
              body: m['body'] as String?,
            ),
          )
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
                        label: widget.parent._s(
                          'Zkusit znovu načíst novinky',
                          'Try loading news again',
                        ),
                        child: FilledButton.icon(
                          onPressed: () => _loadReleases(),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            widget.parent._s('Zkusit znovu', 'Retry'),
                          ),
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Semantics(
                                    label: widget.parent._s(
                                      'Zkusit znovu načíst novinky',
                                      'Try loading news again',
                                    ),
                                    child: FilledButton.icon(
                                      onPressed: () => _loadReleases(),
                                      icon: const Icon(Icons.refresh),
                                      label: Text(
                                        widget.parent._s(
                                          'Zkusit znovu',
                                          'Retry',
                                        ),
                                      ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildReleaseTile(widget.initialFocusVersion!),
                          const SizedBox(height: 8),
                          Semantics(
                            header: true,
                            child: Text(
                              widget.parent._s(
                                'Starší verze',
                                'Older versions',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          Semantics(
                            header: true,
                            child: Text(
                              widget.parent._s(
                                'Seznam novinek',
                                'Release list',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        ..._releases
                            .where(
                              (release) =>
                                  widget.initialFocusVersion == null ||
                                  release.normalizedVersion !=
                                      widget
                                          .initialFocusVersion!
                                          .normalizedVersion,
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
                                      onPressed: () =>
                                          _loadReleases(loadMore: true),
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(
                                        widget.parent._s(
                                          'Načíst starší verze',
                                          'Load older versions',
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                        if (!_hasMore && _releases.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              widget.parent._s(
                                'Žádné další verze.',
                                'No more versions.',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
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
  String? _selectedProfileId;
  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.parent._activeProfileId;
  }
  void _openEditor() {
    if (_selectedProfileId == null) {
      widget.parent.speak(widget.parent._s('Nejprve vyberte profil','Select a profile first'));
      return;
    }
    if (!widget.parent._profilesLoaded) {
      widget.parent.speak(widget.parent._s('Profily se ještě načítají, zkuste to znovu.','Profiles are still loading, please try again.'));
      return;
    }
    final ok = widget.parent.startEditingProfile(_selectedProfileId!);
    if (!ok) return;
    final editingId = _selectedProfileId!;
    final profileForName = widget.parent._profiles.firstWhere((p)=>p.id==editingId, orElse: ()=> widget.parent._getActiveAccessibilityProfile());
    final routeName = 'Upravit profil ${widget.parent._displayProfileName(profileForName)}';
    widget.parent.showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: routeName),
      builder: (ctx) => _AccessibilityProfileEditorDialog(parent: widget.parent),
    ).then((_) {
      if (mounted) setState((){});
    });
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: widget.parent._dialogInsetPadding(),
      title: Semantics(
        header: true,
        child: Text(widget.parent._l10n.accessibilitySettings),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: widget.parent._l10n.accessibilityProfileSection,
                  child: ExcludeSemantics(
                    child: Text(widget.parent._l10n.accessibilityProfileSection),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  header: true,
                  label: widget.parent._l10n.activeProfile(
                    widget.parent._displayProfileName(
                      widget.parent._getActiveAccessibilityProfile(),
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.parent._l10n.activeProfile(
                        widget.parent._displayProfileName(
                          widget.parent._getActiveAccessibilityProfile(),
                        ),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Profily – výběr k editaci (nikoli aktivace)
                if (!widget.parent._profilesLoaded)
                  Semantics(
                    liveRegion: true,
                    label: widget.parent._s('Profily se načítají', 'Profiles loading'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text(widget.parent._s('Načítám profily…', 'Loading profiles…')),
                        ],
                      ),
                    ),
                  )
                else
                Semantics(
                  label: widget.parent._s('Seznam profilů, vyberte profil k úpravě','Profile list, select profile to edit'),
                  child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.parent._effectiveProfiles.map((profile) {
                    final isActive = profile.id == widget.parent._getActiveAccessibilityProfile().id;
                    final isSelected = profile.id == _selectedProfileId;
                    final displayName = widget.parent._displayProfileName(profile);
                    final label = displayName + (isActive ? ', aktivní' : '') + (isSelected ? ', vybrán k úpravě' : '') + (profile.isBuiltIn ? ', vestavěný' : '');
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: label,
                      child: ElevatedButton(
                        style: isSelected
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                              )
                            : isActive
                                ? ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  )
                                : null,
                        onPressed: !widget.parent._profilesLoaded ? null : () {
                          setState(() => _selectedProfileId = profile.id);
                          widget.parent.speak(label);
                        },
                        child: Text(displayName),
                      ),
                    );
                  }).toList(),
                )),
                const SizedBox(height: 8),
                // Management – operace nad vybraným profilem (výběr ≠ aktivace)
                Builder(builder: (ctx) {
                  final selId = _selectedProfileId;
                  final selProfile = selId == null ? null : widget.parent._profiles.firstWhere((p)=>p.id==selId, orElse: ()=> widget.parent._getActiveAccessibilityProfile());
                  final selIsBuiltIn = selProfile?.isBuiltIn ?? true;
                  final selName = selProfile == null ? '' : widget.parent._displayProfileName(selProfile);
                  final profilesReady = widget.parent._profilesLoaded;
                  return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Semantics(
                      button: true,
                      enabled: selId != null && profilesReady,
                      label: selId == null ? widget.parent._s('Upravit profil – nejprve vyberte profil','Edit profile – select a profile first') : widget.parent._s('Upravit profil $selName','Edit profile $selName'),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(widget.parent._s('Upravit','Edit')),
                        onPressed: (selId == null || !profilesReady) ? null : _openEditor,
                      ),
                    ),
                    Semantics(
                      button: true,
                      enabled: selId != null && profilesReady,
                      label: selId == null ? widget.parent._s('Aktivovat profil – nejprve vyberte profil','Activate profile – select a profile first') : widget.parent._s('Aktivovat profil $selName','Activate profile $selName'),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text(widget.parent._s('Aktivovat','Activate')),
                        onPressed: (selId == null || !profilesReady) ? null : () {
                          final p = widget.parent._profiles.firstWhere((e)=>e.id==selId, orElse: ()=> widget.parent._getActiveAccessibilityProfile());
                          // Guard: ensure p.id == selId (exists in _profiles)
                          if (p.id != selId) {
                            widget.parent.speak(widget.parent._s('Profil neexistuje','Profile does not exist'));
                            return;
                          }
                          widget.parent.applyAccessibilityProfile(p, announcement: widget.parent._l10n.profileChangedTo(selName));
                          setState((){});
                        },
                      ),
                    ),
                    Semantics(
                      button: true,
                      enabled: profilesReady,
                      label: widget.parent._s('Vytvořit nový profil', 'Create new profile'),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(widget.parent._s('Nový profil', 'New profile')),
                        onPressed: !profilesReady ? null : () {
                          Navigator.pop(context);
                          widget.parent._showCreateProfileDialog();
                        },
                      ),
                    ),
                    Semantics(
                      button: true,
                      enabled: selId != null && profilesReady,
                      label: selId == null ? widget.parent._s('Obnovit výchozí nastavení profilu','Reset profile to defaults') : widget.parent._s('Obnovit profil $selName','Reset profile $selName'),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(widget.parent._s('Obnovit výchozí', 'Reset')),
                        onPressed: (selId == null || !profilesReady) ? null : () {
                          widget.parent._confirmResetProfileForId(context, selId);
                        },
                      ),
                    ),
                    Semantics(
                      button: true,
                      enabled: selId != null && !selIsBuiltIn && profilesReady,
                      label: selIsBuiltIn ? widget.parent._s('Přejmenovat profil $selName – nelze, vestavěný profil','Rename profile $selName – cannot, built-in profile') : widget.parent._s('Přejmenovat profil $selName','Rename profile $selName'),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(widget.parent._s('Přejmenovat', 'Rename')),
                        onPressed: (selId == null || selIsBuiltIn || !profilesReady) ? null : () {
                          Navigator.pop(context);
                          widget.parent._showRenameProfileDialogForId(selId);
                        },
                      ),
                    ),
                    Semantics(
                      button: true,
                      enabled: selId != null && !selIsBuiltIn && profilesReady,
                      label: selIsBuiltIn ? widget.parent._s('Smazat profil $selName – nelze, vestavěný profil','Delete profile $selName – cannot, built-in profile') : widget.parent._s('Smazat profil $selName','Delete profile $selName'),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete, size: 18),
                        label: Text(widget.parent._s('Smazat', 'Delete')),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: (selId == null || selIsBuiltIn || !profilesReady) ? null : () {
                          widget.parent._confirmDeleteProfileForId(context, selId, parentDialogContext: context);
                        },
                      ),
                    ),
                  ],
                );}),
              ],
            ),
                        const Divider(),
            Semantics(
              label: widget.parent._s('Nastavení profilu upravíte stiskem Upravit u vybraného profilu','Edit profile settings via Edit button for selected profile'),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical:8),
                child: Text(
                  widget.parent._s('Nastavení profilu upravíte stiskem Upravit u vybraného profilu.','Edit profile settings via Edit button for selected profile.'),
                  style: TextStyle(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
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

}
