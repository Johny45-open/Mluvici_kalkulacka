part of '../main.dart';

class _StatsSummaryReadingOrderDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _StatsSummaryReadingOrderDialog({required this.parent});
  @override
  State<_StatsSummaryReadingOrderDialog> createState() => _StatsSummaryReadingOrderDialogState();
}

class _StatsSummaryReadingOrderDialogState extends State<_StatsSummaryReadingOrderDialog> {
  int _sectionSelectedIdx = 0;
  int _itemSelectedIdx = 0;
  String _sectionTypeAhead = '';
  String _itemTypeAhead = '';
  Timer? _sectionTypeAheadTimer;
  Timer? _itemTypeAheadTimer;

  // Pro roving tabindex preset skupiny – index aktuálně fokusovaného presetu
  late int _presetSelectedIdx;

  @override
  void dispose() {
    _sectionTypeAheadTimer?.cancel();
    _itemTypeAheadTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final presets = StatsOrderPreset.values.where((pr) => pr != StatsOrderPreset.custom).toList();
    final cur = widget.parent._currentPreset;
    _presetSelectedIdx = presets.indexOf(cur);
    if (_presetSelectedIdx < 0) _presetSelectedIdx = 0;
  }

  void _moveSection(int index, int offset) {
    final len = widget.parent._statsSummaryOrder.length;
    final newIndex = index + offset;
    if (newIndex < 0 || newIndex >= len) return;
    setState(() {
      widget.parent._moveStatsSummarySectionByOffset(index, offset);
      _sectionSelectedIdx = newIndex;
    });
    widget.parent._announce(widget.parent._s('Pozice ${newIndex + 1} z $len', 'Position ${newIndex + 1} of $len'));
  }

  void _moveItem(int index, int offset) {
    final len = widget.parent._statsComputedOrder.length;
    final newIndex = index + offset;
    if (newIndex < 0 || newIndex >= len) return;
    setState(() {
      widget.parent._moveStatsComputedItemByOffset(index, offset);
      _itemSelectedIdx = newIndex;
    });
    widget.parent._announce(widget.parent._s('Pozice ${newIndex + 1} z $len', 'Position ${newIndex + 1} of $len'));
  }

  KeyEventResult _handlePresetKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final presets = StatsOrderPreset.values.where((pr) => pr != StatsOrderPreset.custom).toList();
    if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _presetSelectedIdx = (_presetSelectedIdx + 1) % presets.length;
        widget.parent.applyStatsOrderPreset(presets[_presetSelectedIdx]);
      });
      final label = widget.parent._presetLabel(presets[_presetSelectedIdx]);
      widget.parent._announce('$label, ${_presetSelectedIdx + 1} z ${presets.length}');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _presetSelectedIdx = (_presetSelectedIdx - 1 + presets.length) % presets.length;
        widget.parent.applyStatsOrderPreset(presets[_presetSelectedIdx]);
      });
      final label = widget.parent._presetLabel(presets[_presetSelectedIdx]);
      widget.parent._announce('$label, ${_presetSelectedIdx + 1} z ${presets.length}');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      setState(() {
        _presetSelectedIdx = 0;
        widget.parent.applyStatsOrderPreset(presets[0]);
      });
      widget.parent._announce('${widget.parent._presetLabel(presets[0])}, 1 z ${presets.length}');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      setState(() {
        _presetSelectedIdx = presets.length - 1;
        widget.parent.applyStatsOrderPreset(presets.last);
      });
      widget.parent._announce('${widget.parent._presetLabel(presets.last)}, ${presets.length} z ${presets.length}');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event, bool isSection) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final len = isSection ? widget.parent._statsSummaryOrder.length : widget.parent._statsComputedOrder.length;
    int idx = isSection ? _sectionSelectedIdx : _itemSelectedIdx;
    if (isAlt && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) (isSection ? _moveSection(idx, -1) : _moveItem(idx, -1));
      return KeyEventResult.handled;
    }
    if (isAlt && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (idx < len - 1) (isSection ? _moveSection(idx, 1) : _moveItem(idx, 1));
      return KeyEventResult.handled;
    }
    if (!isAlt && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) {
        setState(() => isSection ? _sectionSelectedIdx-- : _itemSelectedIdx--);
        isSection ? _announceSection() : _announceItem();
      }
      return KeyEventResult.handled;
    }
    if (!isAlt && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (idx < len - 1) {
        setState(() => isSection ? _sectionSelectedIdx++ : _itemSelectedIdx++);
        isSection ? _announceSection() : _announceItem();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      setState(() => isSection ? _sectionSelectedIdx = 0 : _itemSelectedIdx = 0);
      isSection ? _announceSection() : _announceItem();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      setState(() => isSection ? _sectionSelectedIdx = len - 1 : _itemSelectedIdx = len - 1);
      isSection ? _announceSection() : _announceItem();
      return KeyEventResult.handled;
    }
    // type-ahead: psaní písmena skočí na položku začínající písmenem (APG listbox)
    final char = event.character;
    if (char != null && char.length == 1 && RegExp(r'^[a-zA-Z0-9\u00C0-\u024F]$').hasMatch(char)) {
      final isItem = !isSection;
      String buffer;
      Timer? timer;
      if (isSection) {
        _sectionTypeAheadTimer?.cancel();
        _sectionTypeAhead += char.toLowerCase();
        buffer = _sectionTypeAhead;
        _sectionTypeAheadTimer = Timer(const Duration(milliseconds: 800), () => _sectionTypeAhead = '');
      } else {
        _itemTypeAheadTimer?.cancel();
        _itemTypeAhead += char.toLowerCase();
        buffer = _itemTypeAhead;
        _itemTypeAheadTimer = Timer(const Duration(milliseconds: 800), () => _itemTypeAhead = '');
      }
      final labels = isSection
          ? widget.parent._statsSummaryOrder.map((s) => widget.parent._getStatsSummarySectionLabel(s).toLowerCase()).toList()
          : widget.parent._statsComputedOrder.map((it) => widget.parent._getStatsComputedItemLabel(it).toLowerCase()).toList();
      int start = idx + 1;
      int found = -1;
      for (int i = 0; i < len; i++) {
        final cur = (start + i) % len;
        if (labels[cur].startsWith(buffer)) {
          found = cur;
          break;
        }
      }
      if (found == -1) {
        for (int i = 0; i < len; i++) {
          if (labels[i].startsWith(buffer)) {
            found = i;
            break;
          }
        }
      }
      if (found != -1) {
        setState(() => isSection ? _sectionSelectedIdx = found : _itemSelectedIdx = found);
        isSection ? _announceSection() : _announceItem();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _announceSection() {
    final s = widget.parent._statsSummaryOrder[_sectionSelectedIdx];
    final label = widget.parent._getStatsSummarySectionLabel(s);
    widget.parent._announce('$label, ${_sectionSelectedIdx + 1} z ${widget.parent._statsSummaryOrder.length}');
  }

  void _announceItem() {
    final it = widget.parent._statsComputedOrder[_itemSelectedIdx];
    final label = widget.parent._getStatsComputedItemLabel(it);
    widget.parent._announce('$label, ${_itemSelectedIdx + 1} z ${widget.parent._statsComputedOrder.length}');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parent;
    final presets = StatsOrderPreset.values.where((pr) => pr != StatsOrderPreset.custom).toList();
    // Synchronizovat preset index pokud se změnil přes klik mimo šipky
    final curPreset = p._currentPreset;
    final curIdx = presets.indexOf(curPreset);
    if (curIdx != -1 && curIdx != _presetSelectedIdx) {
      // nevolat setState v build, jen upravit pro příští šipku – necháme index nesynchronizovaný, ale vizuál dle selected
    }

    return AlertDialog(
      insetPadding: p._dialogInsetPadding(),
      title: Semantics(header: true, child: Text(p._s('Pořadí čtení statistického souhrnu', 'Statistics summary reading order'))),
      content: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(p._s('Nastavení pořadí čtení', 'Reading order settings'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                Text(
                  p._s(
                    'Pořadí se čte odshora dolů. Tab na skupinu, šipky uvnitř mění výběr, Alt+šipka přesune položku, Home/End na kraj. Stejný vzor jako u ostatních dialogů.',
                    'Order is read top to bottom. Tab to group, arrows change selection, Alt+Arrow moves, Home/End to edge. Same pattern as other dialogs.',
                  ),
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  label: p._s('Rychlé presety pořadí', 'Quick order presets'),
                  child: Text(p._s('Rychlé presety:', 'Quick presets:'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 6),
                // 1 Tab na celou skupinu presetů – roving tabindex, dle ostatních dialogů
                Semantics(
                  label: p._s('Presety pořadí souhrnu, 1 Tab na skupinu, šipky mění výběr', 'Summary presets, 1 Tab for group, arrows change'),
                  container: true,
                  explicitChildNodes: true,
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: _handlePresetKey,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: presets.asMap().entries.map((e) {
                          final idx = e.key;
                          final preset = e.value;
                          final selected = preset == curPreset;
                          return ExcludeFocusTraversal(
                            child: Semantics(
                              selected: selected,
                              button: true,
                              label: '${p._presetLabel(preset)}${selected ? p._s(', vybráno', ', selected') : ''}',
                              hint: p._s('Jedním klepnutím nastaví vše bez šipek', 'One tap sets all without arrows'),
                              child: ChoiceChip(
                                label: Text(p._presetLabel(preset)),
                                selected: selected,
                                onSelected: (s) {
                                  if (s) {
                                    setState(() {
                                      p.applyStatsOrderPreset(preset);
                                      _presetSelectedIdx = idx;
                                    });
                                  }
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p._s('Tab na skupinu, šipky ←→ mění preset (jako u ostatních dialogů).',
                      'Tab to group, arrows change preset (like other dialogs).'),
                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(p._s('Vlastní = ruční pořadí níže.', 'Custom = manual order below.'),
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  label: p._s('Seznam pořadí částí souhrnu', 'Parts order list'),
                  child: Text(p._s('Pořadí částí souhrnu (3 položky):', 'Parts order (3 items):'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 4),
                Text(p._s('Tab na seznam, šipky mění výběr, Alt+šipka přesune (jako u ostatních).',
                    'Tab to list, arrows select, Alt+Arrow moves (like others).'),
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                const SizedBox(height: 6),
                // 1 Tab na seznam 3 – roving
                Semantics(
                  label: p._s('Seznam částí, 1 Tab na seznam, šipky mění výběr, akce čtečky Posunout',
                      'Parts list, 1 Tab for list, arrows select, Move actions'),
                  container: true,
                  explicitChildNodes: true,
                  child: Focus(
                    onKeyEvent: (n, e) => _handleKey(n, e, true),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: List.generate(p._statsSummaryOrder.length, (i) {
                          final section = p._statsSummaryOrder[i];
                          final label = p._getStatsSummarySectionLabel(section);
                          final desc = p._getStatsSummarySectionDescription(section);
                          final isFirst = i == 0;
                          final isLast = i == p._statsSummaryOrder.length - 1;
                          final isSelected = i == _sectionSelectedIdx;
                          final total = p._statsSummaryOrder.length;
                          return Semantics(
                            selected: isSelected,
                            label: '$label, ${i + 1} z $total, $desc${isSelected ? p._s(', vybráno', ', selected') : ''}',
                            hint: p._s('Poklepáním vyberete, Alt+šipka nebo akce Posunout změní pořadí',
                                'Double tap to select, Alt+Arrow or Move actions change order'),
                            customSemanticsActions: {
                              if (!isFirst) CustomSemanticsAction(label: p._s('Posunout výše', 'Move up')): () => _moveSection(i, -1),
                              if (!isLast) CustomSemanticsAction(label: p._s('Posunout níže', 'Move down')): () => _moveSection(i, 1),
                              if (!isFirst) CustomSemanticsAction(label: p._s('Posunout na začátek', 'Move to top')): () {
                                setState(() {
                                  final item = p._statsSummaryOrder.removeAt(i);
                                  p._statsSummaryOrder.insert(0, item);
                                  _sectionSelectedIdx = 0;
                                });
                                p._saveSettings();
                                p._announce(p._s('$label přesunuto na začátek', '$label moved to top'));
                              },
                              if (!isLast) CustomSemanticsAction(label: p._s('Posunout na konec', 'Move to end')): () {
                                setState(() {
                                  final item = p._statsSummaryOrder.removeAt(i);
                                  p._statsSummaryOrder.add(item);
                                  _sectionSelectedIdx = p._statsSummaryOrder.length - 1;
                                });
                                p._saveSettings();
                                p._announce(p._s('$label přesunuto na konec', '$label moved to end'));
                              },
                            },
                            onTap: () {
                              setState(() => _sectionSelectedIdx = i);
                              _announceSection();
                            },
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _sectionSelectedIdx = i);
                                _announceSection();
                              },
                              child: Card(
                                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                                margin: const EdgeInsets.only(bottom: 6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(isSelected ? Icons.radio_button_checked : Icons.drag_handle,
                                          size: 18,
                                          semanticLabel: isSelected ? p._s('Vybráno', 'Selected') : p._s('Přetáhněte', 'Drag handle')),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: MergeSemantics(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(label,
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null)),
                                              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              Text('${i + 1} z $total', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Tlačítka nejsou samostatné Tab – ExcludeFocusTraversal, jako u ostatních dialogů
                                      ExcludeFocusTraversal(
                                        child: Semantics(
                                          button: true,
                                          label: p._s('Posunout $label výše', 'Move $label up'),
                                          enabled: !isFirst,
                                          child: OutlinedButton(
                                            onPressed: isFirst ? null : () => _moveSection(i, -1),
                                            child: Text(p._s('Výše', 'Up')),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      ExcludeFocusTraversal(
                                        child: Semantics(
                                          button: true,
                                          label: p._s('Posunout $label níže', 'Move $label down'),
                                          enabled: !isLast,
                                          child: OutlinedButton(
                                            onPressed: isLast ? null : () => _moveSection(i, 1),
                                            child: Text(p._s('Níže', 'Down')),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Semantics(
                      button: true,
                      label: p._s('Obnovit výchozí pořadí', 'Reset to default order'),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => p._resetStatsSummaryOrder());
                          _sectionSelectedIdx = 0;
                        },
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: Text(p._s('Výchozí', 'Default')),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: p._s('Přečíst náhled souhrnu v aktuálním pořadí', 'Read preview in current order'),
                      child: FilledButton.icon(
                        onPressed: () {
                          if (p._statsSets.isEmpty || p._statsMemory.isEmpty) {
                            final msg = p._s('Žádná data k náhledu', 'No data for preview');
                            p.speak(msg, force: true);
                            p._announce(msg);
                            return;
                          }
                          final preview = p._getOrderedSpokenSummary(p._selectedFieldIndex);
                          p.speak(preview, force: true);
                          p._announce(preview);
                        },
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: Text(p._s('Přehrát náhled', 'Play preview')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  label: p._s('Pořadí položek uvnitř Vypočtené statistiky', 'Order inside Computed statistics'),
                  child: Text(p._s('Pořadí položek uvnitř Vypočtené (10 položek):', 'Order inside Computed (10 items):'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 4),
                Text(p._s('Stejné pořadí pro čtení i tabulku. Tab na seznam, šipky mění výběr.',
                    'Same order for reading and table. Tab to list, arrows select.'),
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                const SizedBox(height: 6),
                Semantics(
                  label: p._s('Seznam položek Vypočtené, 1 Tab na seznam', 'Computed items list, 1 Tab for list'),
                  container: true,
                  explicitChildNodes: true,
                  child: Focus(
                    onKeyEvent: (n, e) => _handleKey(n, e, false),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: List.generate(p._statsComputedOrder.length, (i) {
                          final item = p._statsComputedOrder[i];
                          final label = p._getStatsComputedItemLabel(item);
                          final desc = p._getStatsComputedItemDescription(item);
                          final isFirst = i == 0;
                          final isLast = i == p._statsComputedOrder.length - 1;
                          final isSelected = i == _itemSelectedIdx;
                          final total = p._statsComputedOrder.length;
                          return Semantics(
                            selected: isSelected,
                            label: '$label, ${i + 1} z $total, $desc${isSelected ? p._s(', vybráno', ', selected') : ''}',
                            hint: p._s('Poklepáním vyberete, Alt+šipka nebo akce změní pořadí',
                                'Double tap to select, Alt+Arrow or actions change order'),
                            customSemanticsActions: {
                              if (!isFirst) CustomSemanticsAction(label: p._s('Posunout výše', 'Move up')): () => _moveItem(i, -1),
                              if (!isLast) CustomSemanticsAction(label: p._s('Posunout níže', 'Move down')): () => _moveItem(i, 1),
                            },
                            onTap: () {
                              setState(() => _itemSelectedIdx = i);
                              _announceItem();
                            },
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _itemSelectedIdx = i);
                                _announceItem();
                              },
                              child: Card(
                                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                                margin: const EdgeInsets.only(bottom: 6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(isSelected ? Icons.radio_button_checked : Icons.drag_handle, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: MergeSemantics(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(label,
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null)),
                                              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              Text('${i + 1} z $total', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      ExcludeFocusTraversal(
                                        child: Semantics(
                                          button: true,
                                          label: p._s('Posunout $label výše', 'Move $label up'),
                                          enabled: !isFirst,
                                          child: OutlinedButton(
                                            onPressed: isFirst ? null : () => _moveItem(i, -1),
                                            child: Text(p._s('Výše', 'Up')),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      ExcludeFocusTraversal(
                                        child: Semantics(
                                          button: true,
                                          label: p._s('Posunout $label níže', 'Move $label down'),
                                          enabled: !isLast,
                                          child: OutlinedButton(
                                            onPressed: isLast ? null : () => _moveItem(i, 1),
                                            child: Text(p._s('Níže', 'Down')),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Semantics(
                      button: true,
                      label: p._s('Obnovit výchozí pořadí položek', 'Reset items to default'),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => p._resetStatsComputedOrder());
                          _itemSelectedIdx = 0;
                        },
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: Text(p._s('Výchozí položky', 'Default items')),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: p._s('Přečíst náhled s novým pořadím položek', 'Read preview with new item order'),
                      child: FilledButton.icon(
                        onPressed: () {
                          if (p._statsSets.isEmpty || p._statsMemory.isEmpty) {
                            final msg = p._s('Žádná data k náhledu', 'No data for preview');
                            p.speak(msg, force: true);
                            p._announce(msg);
                            return;
                          }
                          final preview = p._getOrderedSpokenSummary(p._selectedFieldIndex);
                          p.speak(preview, force: true);
                          p._announce(preview);
                        },
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: Text(p._s('Náhled položek', 'Items preview')),
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(p._l10n.done)),
      ],
    );
  }
}
