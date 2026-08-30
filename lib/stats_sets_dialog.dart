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
  
  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    final l10n = parent._l10n;
    
    List<StatisticsSet> filtered = parent._statsSets.where((s) {
      if (!_showArchived && s.archived) return false;
      if (_selectedFolderId != null && s.folderId != _selectedFolderId) return false;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      switch (_sortBy) {
        case 'name': return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'count': return b.records.length.compareTo(a.records.length);
        case 'lastUsed': return b.lastUsedAt.compareTo(a.lastUsedAt);
        default: return 0;
      }
    });

    return AlertDialog(
      insetPadding: parent._dialogInsetPadding(),
      semanticLabel: l10n.statsSetsTitle,
      title: Semantics(header: true, child: Text(l10n.statsSetsTitle)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Hledat', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            // TODO: Add Filters (Folders, SortBy) - simplified for now
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, index) {
                  final set = filtered[index];
                  final isCurrent = set == parent._statsSets[parent._currentStatsSetIndex];
                  return ListTile(
                    selected: isCurrent,
                    leading: CircleAvatar(
                      backgroundColor: parent._statsColorFor(set.colorIndex),
                      child: Icon(parent._statsIconFor(set.iconName), color: Colors.white),
                    ),
                    title: Text(set.name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(parent._statsFolderName(set.folderId)),
                    trailing: Icon(set.pinned ? Icons.push_pin : null),
                    onTap: () {
                      parent.setState(() => parent._currentStatsSetIndex = parent._statsSets.indexOf(set));
                      parent.speak(l10n.statsSetSelectedAnnouncement(set.name, set.records.length, parent._getStatsCountForm(set.records.length)));
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }
}
