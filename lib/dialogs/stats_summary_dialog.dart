part of '../main.dart';

class _StatsSummaryDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _StatsSummaryDialog({required this.parent});
  @override
  State<_StatsSummaryDialog> createState() => _StatsSummaryDialogState();
}

class _StatsSummaryDialogState extends State<_StatsSummaryDialog> {
  _CalculatorScreenState get p => widget.parent;
  bool _didAnnounce = false;

  @override
  Widget build(BuildContext context) {
    final l10n = p._l10n;
    final fieldNames = p._statsSets.isNotEmpty
        ? p._statsSets[p._currentStatsSetIndex].fieldNames
        : <String>['Hodnota'];

    // Snapshot pro aktuální pole – pokud null, zavřeme dialog a oznámíme
    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final snapshot = p._computeStatisticsSnapshot(p._selectedFieldIndex);
        if (snapshot == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(dialogContext);
            final msg = p._statsEmptyMessage();
            p.speak(msg);
            p._announce(msg, dialogContext);
          });
          return const SizedBox.shrink();
        }

        final currentSetName = p._statsSets[p._currentStatsSetIndex].name;
        final selectedFieldName = fieldNames[p._selectedFieldIndex];
        final fieldUnit = p._statsSets.isNotEmpty &&
                p._selectedFieldIndex < p._statsSets[p._currentStatsSetIndex].fieldUnits.length
            ? p._statsSets[p._currentStatsSetIndex].fieldUnits[p._selectedFieldIndex]
            : null;
        final rawValues = p._getFieldValues(p._selectedFieldIndex);
        final sortedValues = List<double>.from(rawValues)..sort();
        final allValues = sortedValues
            .map((v) {
              final numStr = p._formatNumberSmart(v);
              final unitStr = fieldUnit != null ? ' ${p._getUnitSpeech(fieldUnit, value: v)}' : '';
              return '$numStr$unitStr';
            })
            .join(p._isEnglish() ? ', ' : '; ');
        final allValuesSpoken = sortedValues
            .map((v) {
              final numStr = p._formatSpokenNumber(v);
              final unitStr = fieldUnit != null ? ' ${p._getUnitSpeech(fieldUnit, value: v)}' : '';
              return '$numStr$unitStr';
            })
            .join(p._isEnglish() ? ', ' : '; ');
        final dataCount = rawValues.length;

        final modeText = snapshot.modeExists
            ? snapshot.modes.map((m) => p._formatNumberSmart(m)).join('; ')
            : l10n.statsModeNone;
        final cvText = snapshot.cv == null ? 'Err' : '${p._formatNumberSmart(snapshot.cv!)} %';
        final wmeanText = snapshot.wmean == null ? null : p._formatNumberSmart(snapshot.wmean!);

        MapEntry<String, String>? entryForItem(StatsComputedItem it) {
          switch (it) {
            case StatsComputedItem.mean:
              return MapEntry(l10n.statsMean, p._formatNumberSmart(snapshot.mean));
            case StatsComputedItem.sum:
              return MapEntry(l10n.statsSum, p._formatNumberSmart(snapshot.sum));
            case StatsComputedItem.variance:
              return MapEntry(l10n.statsVariance, p._formatNumberSmart(snapshot.variance));
            case StatsComputedItem.sd:
              return MapEntry(l10n.statsStdDev, p._formatNumberSmart(snapshot.sd));
            case StatsComputedItem.median:
              return MapEntry(l10n.statsMedian, p._formatNumberSmart(snapshot.median));
            case StatsComputedItem.min:
              return MapEntry(l10n.statsMin, p._formatNumberSmart(snapshot.min));
            case StatsComputedItem.max:
              return MapEntry(l10n.statsMax, p._formatNumberSmart(snapshot.max));
            case StatsComputedItem.mode:
              return MapEntry(l10n.statsMode, modeText);
            case StatsComputedItem.cv:
              return MapEntry(l10n.statsCv, cvText);
            case StatsComputedItem.wmean:
              if (snapshot.wmean == null) return null;
              return MapEntry(l10n.statsWeightedMean, wmeanText!);
          }
        }

        final statRows = <MapEntry<String, String>>[
          MapEntry(l10n.statsN, dataCount.toString()),
          for (final it in p._statsComputedOrder)
            if (entryForItem(it) != null) entryForItem(it)!,
        ];

        final spokenSummary = p._getOrderedSpokenSummary(p._selectedFieldIndex);

        if (!_didAnnounce) {
          _didAnnounce = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final tabHint = p._s(
              ' Jednotlivé statistiky můžete procházet klávesou Tab.',
              ' Use Tab to move through individual statistics.',
            );
            if (!p._autoReadStatsSummary) {
              final short = p._s(
                'Statistický souhrn otevřen. Jednotlivé statistiky můžete procházet klávesou Tab.',
                'Statistics summary opened. Use Tab to move through individual statistics.',
              );
              if (p._isScreenReaderActive) {
                p._announce(short, dialogContext);
              } else {
                p.speak(short);
              }
              return;
            }
            // Obojí: celý souhrn v nastaveném pořadí + Tab hint, pro obě větve
            final fullWithHint = spokenSummary.isNotEmpty ? '$spokenSummary$tabHint' : tabHint.trimLeft();
            final announceText = p._s(
              'Statistický souhrn otevřen. $fullWithHint',
              'Statistics summary opened. $fullWithHint',
            );
            if (p._isScreenReaderActive) {
              p._announce(announceText, dialogContext);
            } else {
              p.speak(announceText, force: true);
            }
          });
        }

        void cycleField() {
          final nextIndex = (p._selectedFieldIndex + 1) % fieldNames.length;
          final nextSummary = p._getOrderedSpokenSummary(nextIndex);
          p.setState(() => p._selectedFieldIndex = nextIndex);
          setDialogState(() {});
          final msg = p._s('Vybráno pole ${fieldNames[nextIndex]}. ', 'Selected field ${fieldNames[nextIndex]}. ') + nextSummary;
          if (p._isScreenReaderActive) {
            p._announce(msg, dialogContext);
          }
          p.speak(msg, force: true);
        }

        void toggleReadValues(bool? v) {
          final newVal = v ?? true;
          p.setState(() {
            p._readStatsMemoryValues = newVal;
            p._saveSettings();
          });
          setDialogState(() {});
          final statusMsg = newVal
              ? p._s('Čtení hodnot zapnuto', 'Reading values enabled')
              : p._s('Čtení hodnot vypnuto', 'Reading values disabled');
          final ordered = p._getOrderedSpokenSummary(p._selectedFieldIndex);
          final full = ordered.isNotEmpty ? '$statusMsg. $ordered' : statusMsg;
          if (p._isScreenReaderActive) {
            p._announce(full, dialogContext);
          }
          p.speak(full, force: true);
          p._showAccessibleSnackBar(statusMsg, announceMessage: full, scaffoldContext: dialogContext);
        }

        void toggleAutoRead(bool? v) {
          final newVal = v ?? true;
          p.setState(() {
            p._autoReadStatsSummary = newVal;
            p._saveSettings();
          });
          setDialogState(() {});
          final statusMsg = newVal
              ? p._s('Automatické čtení souhrnu zapnuto', 'Auto-read summary enabled')
              : p._s('Automatické čtení souhrnu vypnuto', 'Auto-read summary disabled');
          final hint = newVal
              ? p._s('Po otevření se rovnou přečte celý souhrn v nastaveném pořadí plus nápověda pro Tab.',
                  'On open the full summary in the configured order plus Tab hint will be read.')
              : p._s('Po otevření se řekne jen hlavička s nápovědou pro Tab.',
                  'On open only the header with Tab hint will be announced.');
          final full = '$statusMsg. $hint';
          if (p._isScreenReaderActive) {
            p._announce(full, dialogContext);
          }
          p.speak(full, force: true);
          p._showAccessibleSnackBar(statusMsg, announceMessage: full, scaffoldContext: dialogContext);
        }

        return AlertDialog(
          insetPadding: p._dialogInsetPadding(),
          title: Semantics(
            header: true,
            child: Text(l10n.statsSummaryTitle),
          ),
          content: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(dialogContext).size.height * 0.72),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tlačítko pořadí – první fokusovatelné, s jasným hintem
                      Semantics(
                        button: true,
                        label: p._s('Změnit pořadí čtení souhrnu', 'Change summary reading order'),
                        hint: p._s('Otevře dialog pro nastavení pořadí čtení', 'Opens reading order settings'),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              // Odložit otevření až po doběhnutí _FocusRestoreObserver (150 ms),
                              // jinak observer vytrhne fokus novému dialogu – viz _showStatsSaveReviewDialog.
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (p.mounted) p._showStatsSummaryReadingOrderDialog();
                              });
                            },
                            icon: const Icon(Icons.reorder, size: 18),
                            label: Text(p._s('Pořadí čtení', 'Reading order')),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Název sady – header pro VoiceOver rotor / NVDA H
                      Semantics(
                        header: true,
                        label: l10n.statsCurrentSetLabel(currentSetName),
                        child: Text(
                          l10n.statsCurrentSetLabel(currentSetName),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (fieldNames.length > 1) ...[
                        const SizedBox(height: 8),
                        // Přepínač pole – button s liveRegion
                        Semantics(
                          button: true,
                          liveRegion: true,
                          label: p._s(
                            'Pole: ${fieldNames[p._selectedFieldIndex]}${fieldUnit != null ? ', ${p._getUnitSpeech(fieldUnit)}' : ''}',
                            'Field: ${fieldNames[p._selectedFieldIndex]}${fieldUnit != null ? ', ${p._getUnitSpeech(fieldUnit)}' : ''}',
                          ),
                          hint: p._s('Poklepáním přepnete pole', 'Double tap to switch field'),
                          onTap: cycleField,
                          child: InkWell(
                            onTap: cycleField,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  Text(p._s('Pole: ', 'Field: ')),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      fieldNames[p._selectedFieldIndex],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (fieldUnit != null) ...[
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '(${p._getUnitSpeech(fieldUnit)})',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  const Icon(Icons.swap_horiz, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      // Checkbox – s jasným hintem o efektu
                      Semantics(
                        checked: p._readStatsMemoryValues,
                        label: p._s('Číst hodnoty v paměti', 'Read values in memory'),
                        hint: p._s(
                          'Vypnutím se skryje sekce Všechny hodnoty v paměti',
                          'Off hides the All values in memory section',
                        ),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p._s('Číst hodnoty v paměti', 'Read values in memory')),
                          subtitle: Text(
                            p._s(
                              'Ovlivňuje i hlasové čtení souhrnu',
                              'Also affects speech reading of summary',
                            ),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          value: p._readStatsMemoryValues,
                          onChanged: toggleReadValues,
                        ),
                      ),
                      Semantics(
                        checked: p._autoReadStatsSummary,
                        label: p._s('Automaticky číst souhrn při otevření', 'Auto-read summary on open'),
                        hint: p._s(
                          'Když je zapnuto, po otevření se rovnou přečte celý souhrn v nastaveném pořadí plus nápověda pro Tab',
                          'When on, opening the dialog reads the full summary in the configured order plus Tab hint',
                        ),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p._s('Automaticky číst souhrn při otevření', 'Auto-read summary on open')),
                          subtitle: Text(
                            p._s(
                              'Vypnutím se řekne jen hlavička s nápovědou pro Tab',
                              'When off only the header with Tab hint is announced',
                            ),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          value: p._autoReadStatsSummary,
                          onChanged: toggleAutoRead,
                        ),
                      ),
                      if (p._readStatsMemoryValues) ...[
                        const Divider(height: 12),
                        Semantics(
                          header: true,
                          label: l10n.statsAllValuesSection,
                          liveRegion: true,
                          child: Text(
                            l10n.statsAllValuesSection,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Hodnoty – jedna sémantická položka s mluvenou formou
                        Semantics(
                          label: p._s(
                            'Všechny hodnoty pole $selectedFieldName: $allValuesSpoken',
                            'All values of field $selectedFieldName: $allValuesSpoken',
                          ),
                          child: _PeriodicText(
                            allValues,
                            overlineThickness: p._overlineThickness,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        label: l10n.statsComputedSection,
                        child: Text(
                          l10n.statsComputedSection,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        label: p._s('Tabulka vypočtených statistik, ${statRows.length} řádků', 'Table of computed statistics, ${statRows.length} rows'),
                        container: true,
                        explicitChildNodes: true,
                        child: Column(
                          children: statRows.asMap().entries.map((entry) {
                            final row = entry.value;
                            final spokenValue = p._spokenForDisplay(row.value);
                            // Každý řádek samostatná položka pro swipe
                            return Semantics(
                              container: true,
                              label: '${row.key}: $spokenValue',
                              hint: p._s('Řádek ${entry.key + 1} z ${statRows.length}', 'Row ${entry.key + 1} of ${statRows.length}'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: MergeSemantics(
                                  child: Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(row.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                                      Expanded(
                                        flex: 2,
                                        child: _PeriodicText(
                                          row.value,
                                          textAlign: TextAlign.right,
                                          overlineThickness: p._overlineThickness,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Scroll hint pro čtečky
                      Semantics(
                        label: p._s(
                          'Konec souhrnu. Použijte akce níže pro správu sad.',
                          'End of summary. Use actions below to manage sets.',
                        ),
                        child: const SizedBox.shrink(),
                      ),
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
                p._showStatsSetsDialog();
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
  }
}
