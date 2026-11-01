part of 'main.dart';

/// Stavový wrapper pro udržení položky v paměti (keep-alive), pokud některý
/// z jejích potomků drží klávesnicový fokus. Nezasahuje do sémantiky ani do Tab pořadí.
class _KeepAliveSetTile extends StatefulWidget {
  final Widget child;
  const _KeepAliveSetTile({required Key key, required this.child}) : super(key: key);

  @override
  State<_KeepAliveSetTile> createState() => _KeepAliveSetTileState();
}

class _KeepAliveSetTileState extends State<_KeepAliveSetTile>
    with AutomaticKeepAliveClientMixin {
  bool _hasFocus = false;

  @override
  bool get wantKeepAlive => _hasFocus;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (hasFocus) {
        if (_hasFocus != hasFocus) {
          setState(() {
            _hasFocus = hasFocus;
          });
          updateKeepAlive();
        }
      },
      child: widget.child,
    );
  }
}
