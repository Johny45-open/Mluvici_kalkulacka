part of 'main.dart';

class _StatsSetsDialog extends StatefulWidget {
  final _CalculatorScreenState parent;
  const _StatsSetsDialog({required this.parent});

  @override
  State<_StatsSetsDialog> createState() => _StatsSetsDialogState();
}

class _StatsSetsDialogState extends State<_StatsSetsDialog> {
  String _searchQuery = '';
  String _sortBy = 'lastUsed';
  bool _showArchived = false;
  String? _selectedFolderId;
  int _setsFocusIdx = 0;
  String _typeAhead = '';
  Timer? _typeAheadTimer;

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _typeAheadTimer?.cancel();
    super.dispose();
  }

  KeyEventResult _handleSortArchiveKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    const order = ['lastUsed', 'name', 'count'];
    if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final dir = event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1;
      final idx = order.indexOf(_sortBy);
      final next = order[(idx + dir + order.length) % order.length];
      setState(() => _sortBy = next);
      widget.parent._announce(widget.parent._s('Řazení ', 'Sorting '));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.enter) {
      setState(() => _showArchived = !_showArchived);
      widget.parent._announce(_showArchived ? widget.parent._s('Archiv zapnut', 'Archive on') : widget.parent._s('Archiv vypnut', 'Archive off'));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) { setState(() => _sortBy = order.first); return KeyEventResult.handled; }
    if (event.logicalKey == LogicalKeyboardKey.end) { setState(() => _sortBy = order.last); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleFolderKey(FocusNode node, KeyEvent event, List<dynamic> folders) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ids = <String?>[null, '__none', ...folders.map((f) => f.id as String?)];
    final curIdx = ids.indexOf(_selectedFolderId);
    if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final next = ids[(curIdx + 1) % ids.length];
      setState(() => _selectedFolderId = next);
      final label = next == null ? widget.parent._s('Vše', 'All') : next == '__none' ? widget.parent._s('Bez složky', 'No folder') : folders[ids.indexOf(next) - 2].name;
      widget.parent._announce(label);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final next = ids[(curIdx - 1 + ids.length) % ids.length];
      setState(() => _selectedFolderId = next);
      final label = next == null ? widget.parent._s('Vše', 'All') : next == '__none' ? widget.parent._s('Bez složky', 'No folder') : folders[ids.indexOf(next) - 2].name;
      widget.parent._announce(label);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) { setState(() => _selectedFolderId = null); widget.parent._announce(widget.parent._s('Vše', 'All')); return KeyEventResult.handled; }
    if (event.logicalKey == LogicalKeyboardKey.end) { setState(() => _selectedFolderId = ids.last); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSetsKey(FocusNode node, KeyEvent event, List<StatisticsSet> filtered) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final len = filtered.length;
    if (len == 0) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && char.length == 1 && RegExp(r'^[a-zA-Z0-9À-ɏ]$').hasMatch(char)) {
      _typeAheadTimer?.cancel();
      _typeAhead += char.toLowerCase();
      _typeAheadTimer = Timer(const Duration(milliseconds: 800), () => _typeAhead = '');
      final start = (_setsFocusIdx + 1) % len;
      int found = -1;
      for (int i = 0; i < len; i++) { final idx = (start + i) % len; if (filtered[idx].name.toLowerCase().startsWith(_typeAhead)) { found = idx; break; } }
      if (found == -1) for (int i = 0; i < len; i++) if (filtered[i].name.toLowerCase().startsWith(_typeAhead)) { found = i; break; }
      if (found != -1) { setState(() => _setsFocusIdx = found); widget.parent._announce('\, \ z '); return KeyEventResult.handled; }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) { if (_setsFocusIdx < len - 1) { setState(() => _setsFocusIdx++); widget.parent._announce('\, \ z '); } return KeyEventResult.handled; }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) { if (_setsFocusIdx > 0) { setState(() => _setsFocusIdx--); widget.parent._announce('\, \ z '); } return KeyEventResult.handled; }
    if (event.logicalKey == LogicalKeyboardKey.home) { setState(() => _setsFocusIdx = 0); widget.parent._announce('\, 1 z '); return KeyEventResult.handled; }
    if (event.logicalKey == LogicalKeyboardKey.end) { setState(() => _setsFocusIdx = len - 1); widget.parent._announce('\, \ z '); return KeyEventResult.handled; }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space) {
      final set = filtered[_setsFocusIdx]; final realIndex = widget.parent._statsSets.indexOf(set); final countForm = widget.parent._getStatsCountForm(set.records.length);
      widget.parent.setState(() => widget.parent._currentStatsSetIndex = realIndex); widget.parent._saveStatsData();
      final msg = widget.parent._l10n.statsSetSelectedAnnouncement(set.name, set.records.length, countForm); widget.parent.speak(msg, force: true); widget.parent._announce(msg); Navigator.pop(context); return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showCreateChoice() {
    final parent = widget.parent;
    parent.showAppDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Semantics(header: true, child: Text(parent._s('Vytvořit sadu', 'Create set'))),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              parent._showCreateStatsSetDialog(context, recordsToSave: null);
            },
            child: Semantics(label: parent._s('Rychlé vytvoření – název a pole', 'Quick create – name and fields'), child: Text(parent._s('Rychlé vytvoření', 'Quick create'))),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              parent._showGuidedStatsCreationDialog();
            },
            child: Semantics(label: parent._s('Průvodce – krok za krokem', 'Wizard – step by step'), child: Text(parent._s('Průvodce', 'Wizard'))),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              parent._startVoiceSetCreation();
            },
            child: Semantics(label: parent._s('Hlasové vytvoření', 'Voice create'), child: Text(parent._s('Hlasem', 'By voice'))),
          ),
        ],
      ),
    );
  }

  /// Speciální bezpečný inset pouze pro tento dialog.
  /// Globální [parent._dialogInsetPadding] se nemění, protože ho sdílí
  /// ostatní dialogy. Na úzké obrazovce nechá dialogu podstatně větší
  /// část šířky (místo fixních 40px z compact režimu).
  EdgeInsets _setsInsetPadding(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final vertical = mq.viewInsets.bottom > 0 ? 8.0 : 16.0;
    double horizontal;
    if (w < 360) {
      horizontal = 8.0;
    } else if (w < 500) {
      horizontal = 12.0;
    } else if (w < 700) {
      horizontal = 20.0;
    } else {
      // Velký displej: chování jako ostatní dialogy.
      return widget.parent._dialogInsetPadding();
    }
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  Widget _buildSortControl() {
    final parent = widget.parent;
    return Semantics(
      label: parent._s('Řazení', 'Sorting'),
      child: DropdownButton<String>(
        value: _sortBy,
        items: [
          DropdownMenuItem(value: 'lastUsed', child: Text(parent._s('Poslední použití', 'Last used'))),
          DropdownMenuItem(value: 'name', child: Text(parent._s('Název', 'Name'))),
          DropdownMenuItem(value: 'count', child: Text(parent._s('Počet', 'Count'))),
        ],
        onChanged: (v) => setState(() => _sortBy = v ?? 'lastUsed'),
      ),
    );
  }

  Widget _buildArchiveControl() {
    final parent = widget.parent;
    return Semantics(
      label: parent._s('Zobrazit archivované', 'Show archived'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: _showArchived, onChanged: (v) => setState(() => _showArchived = v ?? false)),
          Flexible(child: Text(parent._s('Archiv', 'Archive'))),
        ],
      ),
    );
  }

  /// Responzivní řádek řazení + archiv: vedle sebe když se vejdou
  /// (široký displej), automaticky pod sebe přes [Wrap] na úzkém.
  /// Žádný horizontální scroll, nic se neschovává.
  Widget _buildSortArchiveSection(bool narrow) {
    return Wrap(
      spacing: narrow ? 8 : 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [_buildSortControl(), _buildArchiveControl()],
    );
  }

  Widget _buildFolderFilters() {
    final parent = widget.parent;
    return SizedBox(
      // 48px: dostatečná výška pro dotykové ovládání, chipy se nezkracují.
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(parent._s('Vše', 'All')),
              selected: _selectedFolderId == null,
              onSelected: (_) => setState(() => _selectedFolderId = null),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(parent._s('Bez složky', 'No folder')),
              selected: _selectedFolderId == '__none',
              onSelected: (_) => setState(() => _selectedFolderId = '__none'),
            ),
          ),
          ...parent._statsFolders.map((f) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: parent._statsColorFor(f.colorIndex), radius: 10, child: Icon(parent._statsIconFor(f.iconName), size: 10, color: Colors.white)),
                  label: Text(f.name),
                  selected: _selectedFolderId == f.id,
                  onSelected: (_) => setState(() => _selectedFolderId = f.id),
                ),
              )),
        ],
      ),
    );
  }

  void _handleSetSelected(StatisticsSet set, int realIndex) {
    final parent = widget.parent;
    final l10n = parent._l10n;
    parent.setState(() => parent._currentStatsSetIndex = realIndex);
    parent._saveStatsData();
    parent.speak(l10n.statsSetSelectedAnnouncement(set.name, set.records.length, parent._getStatsCountForm(set.records.length)), force: true);
    Navigator.pop(context);
  }

  PopupMenuButton<String> _buildSetPopup(StatisticsSet set, int realIndex, bool isCurrent) {
    final parent = widget.parent;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: parent._s('Možnosti sady', 'Set options'),
      onSelected: (v) async {
        switch (v) {
          case 'select':
            _handleSetSelected(set, realIndex);
            break;
          case 'rename':
            parent._showRenameStatsSetDialog(context, realIndex, _refresh);
            break;
          case 'edit':
            parent._showEditStatsSetDialog(context, realIndex, _refresh);
            break;
          case 'color':
            parent._showStatsColorIconPicker(context, realIndex, _refresh);
            break;
          case 'move':
            parent._showMoveStatsSetDialog(context, realIndex, _refresh);
            break;
          case 'copy':
            parent._showCopyStatsSetToFolderDialog(context, realIndex, _refresh);
            break;
          case 'duplicate':
            parent._duplicateStatsSet(realIndex, _refresh);
            break;
          case 'pin':
            parent._toggleStatsSetPinned(realIndex, _refresh);
            break;
          case 'archive':
            parent._toggleStatsSetArchived(realIndex, _refresh);
            break;
          case 'delete':
            parent._showDeleteStatsSetConfirmation(context, realIndex, _refresh);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'select', child: Text(isCurrent ? parent._s('✓ Aktivní', '✓ Active') : parent._s('Vybrat', 'Select'))),
        PopupMenuItem(value: 'rename', child: Text(parent._s('Přejmenovat', 'Rename'))),
        PopupMenuItem(value: 'edit', child: Text(parent._s('Upravit pole', 'Edit fields'))),
        PopupMenuItem(value: 'color', child: Text(parent._s('Barva/ikona', 'Color/icon'))),
        PopupMenuItem(value: 'move', child: Text(parent._s('Přesunout do složky', 'Move to folder'))),
        PopupMenuItem(value: 'copy', child: Text(parent._s('Kopírovat do složky', 'Copy to folder'))),
        PopupMenuItem(value: 'duplicate', child: Text(parent._s('Duplikovat', 'Duplicate'))),
        PopupMenuItem(value: 'pin', child: Text(set.pinned ? parent._s('Odepnout', 'Unpin') : parent._s('Připnout', 'Pin'))),
        PopupMenuItem(value: 'archive', child: Text(set.archived ? parent._s('Obnovit', 'Restore') : parent._s('Archivovat', 'Archive'))),
        PopupMenuItem(value: 'delete', child: Text(parent._s('Smazat', 'Delete'), style: const TextStyle(color: Colors.red))),
      ],
    );
  }

  /// Kompaktní horizontální varianta pro široký displej (původní vzhled).
  Widget _buildSetTileWide(StatisticsSet set, int realIndex, bool isCurrent) {
    final parent = widget.parent;
    return Card(
      color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        selected: isCurrent,
        leading: Semantics(
          label: parent._s('Sada ${set.name}, ${set.records.length} hodnot, složka ${parent._statsFolderName(set.folderId)}', 'Set ${set.name}, ${set.records.length} values, folder ${parent._statsFolderName(set.folderId)}'),
          child: CircleAvatar(
            backgroundColor: parent._statsColorFor(set.colorIndex),
            child: Icon(parent._statsIconFor(set.iconName), color: Colors.white, size: 18),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(set.name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal))),
            if (set.pinned) Semantics(label: parent._s('Připnuto', 'Pinned'), child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin, size: 14))),
            if (set.archived) Semantics(label: parent._s('Archivováno', 'Archived'), child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.archive, size: 14))),
          ],
        ),
        subtitle: Text('${parent._statsFolderName(set.folderId)} • ${set.records.length} ${parent._getStatsCountForm(set.records.length)} • ${set.fieldNames.join(', ')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: parent._s('Upravit pole sady ${set.name}', 'Edit fields of set ${set.name}'),
              button: true,
              child: IconButton(
                icon: const Icon(Icons.view_list, size: 18),
                tooltip: parent._s('Upravit pole', 'Edit fields'),
                onPressed: () => parent._showEditStatsSetDialog(context, realIndex, _refresh),
              ),
            ),
            _buildSetPopup(set, realIndex, isCurrent),
          ],
        ),
        onTap: () => _handleSetSelected(set, realIndex),
      ),
    );
  }

  /// Vertikální varianta pro úzký displej: název+stav nahoře,
  /// info pod ním, akce na samostatném řádku. Žádná duplicita akcí –
  /// úprava je jen dole, menu jen nahoře.
  Widget _buildSetTileNarrow(StatisticsSet set, int realIndex, bool isCurrent) {
    final parent = widget.parent;
    return Card(
      color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => _handleSetSelected(set, realIndex),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    label: parent._s('Sada ${set.name}, ${set.records.length} hodnot, složka ${parent._statsFolderName(set.folderId)}', 'Set ${set.name}, ${set.records.length} values, folder ${parent._statsFolderName(set.folderId)}'),
                    child: CircleAvatar(
                      backgroundColor: parent._statsColorFor(set.colorIndex),
                      child: Icon(parent._statsIconFor(set.iconName), color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(set.name, softWrap: true, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        ),
                        if (set.pinned) Semantics(label: parent._s('Připnuto', 'Pinned'), child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin, size: 14))),
                        if (set.archived) Semantics(label: parent._s('Archivováno', 'Archived'), child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.archive, size: 14))),
                      ],
                    ),
                  ),
                  _buildSetPopup(set, realIndex, isCurrent),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 52, right: 12),
                child: Text(
                  '${parent._statsFolderName(set.folderId)} • ${set.records.length} ${parent._getStatsCountForm(set.records.length)} • ${set.fieldNames.join(', ')}',
                  softWrap: true,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Semantics(
                  label: parent._s('Upravit pole sady ${set.name}', 'Edit fields of set ${set.name}'),
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: () => parent._showEditStatsSetDialog(context, realIndex, _refresh),
                    icon: const Icon(Icons.view_list, size: 18),
                    label: Text(parent._s('Upravit pole', 'Edit fields')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    final l10n = parent._l10n;

    List<StatisticsSet> filtered = parent._statsSets.where((s) {
      if (!_showArchived && s.archived) return false;
      if (_selectedFolderId == '__none' && s.folderId != null) return false;
      if (_selectedFolderId != null && _selectedFolderId != '__none' && s.folderId != _selectedFolderId) return false;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      switch (_sortBy) {
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'count':
          return b.records.length.compareTo(a.records.length);
        case 'lastUsed':
          return b.lastUsedAt.compareTo(a.lastUsedAt);
        default:
          return 0;
      }
    });

    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final keyboardOpen = mq.viewInsets.bottom > 0;
    // Stejná hranice se používá pro řazení/archiv i pro volbu layoutu položky.
    // Vychází z dostupné šířky obrazovky, ne z pevné šířky dialogu.
    final narrowScreen = screenW < 500;
    final contentPadding =
        narrowScreen ? const EdgeInsets.fromLTRB(16, 12, 16, 0) : null;
    final titlePadding =
        narrowScreen ? const EdgeInsets.fromLTRB(16, 16, 16, 0) : null;
    // Viditelná výška po odečtu klávesnice. Obsah musí nechat rezervu na
    // titulek + akce dialogu + vertikální insets, jinak by AlertDialog
    // přetekl vertikálně (na malém displeji se to projeví i bez klávesnice).
    final visibleH = mq.size.height - mq.viewInsets.bottom;
    final insetsV = keyboardOpen ? 16.0 : (screenW < 700 ? 32.0 : 48.0);
    final double contentMaxH =
        (visibleH - insetsV - 185).clamp(180.0, visibleH * 0.72);

    return AlertDialog(
      insetPadding: _setsInsetPadding(context),
      semanticLabel: l10n.statsSetsTitle,
      titlePadding: titlePadding,
      contentPadding: contentPadding,
      title: Semantics(header: true, child: Text(l10n.statsSetsTitle)),
      content: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: contentMaxH,
          ),
          child: LayoutBuilder(
            builder: (ctx, contentConstraints) {
              // Šířka skutečně dostupná uvnitř dialogu (po odečtu paddingu).
              // Položka se přepne do vertikálního režimu i když je okno
              // široké, ale dialog je zúžený volbou DialogSize.compact.
              final contentW = contentConstraints.maxWidth.isFinite
                  ? contentConstraints.maxWidth
                  : screenW;
              final narrowContent = contentW < 420 || narrowScreen;
              final searchField = Semantics(
                label: parent._s('Hledat sadu podle názvu', 'Search set by name'),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: keyboardOpen ? 4 : 0,
                  ),
                  child: TextField(
                    decoration: InputDecoration(labelText: parent._s('Hledat', 'Search'), prefixIcon: const Icon(Icons.search)),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              );
              // Akční lišta – zalamuje se pomocí Wrap, vždy celá viditelná
              // bez horizontálního scrollu.
              final actionsBar = Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Semantics(
                    label: parent._s('Vytvořit novou sadu', 'Create new set'),
                    button: true,
                    child: FilledButton.icon(onPressed: () => parent._showCreateStatsSetDialog(context), icon: const Icon(Icons.add, size: 16), label: Text(l10n.statsSetsCreate)),
                  ),
                  Semantics(
                    label: parent._s('Vytvořit sadu – možnosti', 'Create set – options'),
                    button: true,
                    child: OutlinedButton.icon(onPressed: _showCreateChoice, icon: const Icon(Icons.more_horiz, size: 16), label: Text(parent._s('Více', 'More'))),
                  ),
                  Semantics(
                    label: parent._s('Správa složek', 'Manage folders'),
                    button: true,
                    child: OutlinedButton.icon(onPressed: () => parent._showManageFoldersDialog(context, _refresh), icon: const Icon(Icons.folder_copy, size: 16), label: Text(parent._s('Složky', 'Folders'))),
                  ),
                ],
              );
              Widget buildItem(BuildContext ctx, int index) {
                final set = filtered[index];
                final realIndex = parent._statsSets.indexOf(set);
                final isCurrent = realIndex == parent._currentStatsSetIndex;
                return LayoutBuilder(
                  builder: (itemCtx, itemConstraints) {
                    final itemNarrow = itemConstraints.maxWidth < 420 || narrowContent;
                    if (itemNarrow) {
                      return _buildSetTileNarrow(set, realIndex, isCurrent);
                    }
                    return _buildSetTileWide(set, realIndex, isCurrent);
                  },
                );
              }

              Widget buildSetsList({required bool shrinkWrap}) {
                if (filtered.isEmpty) {
                  return Center(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(parent._s('Žádné sady neodpovídají filtru', 'No sets match filter'), style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: shrinkWrap,
                  physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
                  itemCount: filtered.length,
                  itemBuilder: buildItem,
                );
              }

              // Úzký displej nebo klávesnice: fixní součet hlavičky (filtry +
              // třířádková akční lišta) se nevejde nad seznam. Hledání zůstává
              // fixní nahoře, zbytek (filtry + akce + seznam) se posouvá
              // společně v jednom scrollu – matematicky nemůže přetéct.
              // Pořadí fokusu a Semantics zůstávají v původním pořadí.
              if (keyboardOpen || narrowScreen) {
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSortArchiveSection(narrowScreen),
                            const SizedBox(height: 8),
                            // Složky zůstávají horizontálně posuvné.
                            _buildFolderFilters(),
                            const Divider(height: 12),
                            actionsBar,
                            const SizedBox(height: 8),
                            buildSetsList(shrinkWrap: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              // Široký displej: filtry i akce fixní (jako původně), posouvá se
              // pouze seznam sad.
              return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 8),
              _buildSortArchiveSection(narrowScreen),
              const SizedBox(height: 8),
              // Složky zůstávají horizontálně posuvné (počet není omezen).
              _buildFolderFilters(),
              const Divider(height: 12),
              actionsBar,
              const SizedBox(height: 8),
              Flexible(
                fit: FlexFit.tight,
                child: buildSetsList(shrinkWrap: false),
              ),
            ],
          );
            },
          ),
        ),
      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }
}
