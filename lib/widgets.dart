part of 'main.dart';

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final List<Widget> children;
  const _CollapsibleSection({required this.title, required this.children});
  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.title,
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: _isExpanded,
            label: '${_isExpanded ? 'Sbalit' : 'Rozbalit'} ${widget.title}',
            child: ListTile(
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          if (_isExpanded) ...widget.children,
        ],
      ),
    );
  }
}

class _PeriodicText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const _PeriodicText(this.text, {this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final text = this.text.replaceAll('.', ',');
    final re = RegExp(r'(\d+)([.,])(\d*)\((\d+)\)');
    final spans = <TextSpan>[];
    var lastEnd = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      final intPart = m.group(1)!;
      final sep = m.group(2)!;
      final nonRepeating = m.group(3) ?? '';
      final period = m.group(4)!;
      spans.add(TextSpan(text: '$intPart$sep$nonRepeating'));
      spans.add(
        TextSpan(
          text: period,
          style: const TextStyle(decoration: TextDecoration.overline),
        ),
      );
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
    );
  }
}

class CustomSegmentDisplay extends StatelessWidget {
  final String value;
  final double size;
  final int characterCount;
  final double characterSpacing;
  final bool isSixteenSegment;
  final Color enabledColor;
  final Color disabledColor;

  const CustomSegmentDisplay({
    super.key,
    required this.value,
    this.size = 24,
    this.characterCount = 16,
    this.characterSpacing = 8,
    this.isSixteenSegment = false,
    this.enabledColor = Colors.redAccent,
    this.disabledColor = const Color(0x30FF5252),
  });

  @override
  Widget build(BuildContext context) {
    // Rozklad na znaky a informaci o tečce
    List<_SegmentCharData> chars = [];
    int valIdx = 0;
    while (chars.length < characterCount && valIdx < value.length) {
      String char = value[valIdx];
      bool hasDot = false;
      bool overline = false;
      if (valIdx + 1 < value.length && value[valIdx + 1] == '.') {
        hasDot = true;
        valIdx++;
      }
      if (valIdx + 1 < value.length && value[valIdx + 1] == '\u0305') {
        overline = true;
        valIdx++;
      }
      chars.add(_SegmentCharData(char, hasDot, overline));
      valIdx++;
    }

    // Doplnění mezerami
    while (chars.length < characterCount) {
      chars.add(_SegmentCharData(' ', false, false));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(characterCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == characterCount - 1 ? 0 : characterSpacing,
          ),
          child: SizedBox(
            width: size * 1.5,
            height: size * 1.8,
            child: CustomPaint(
              painter: isSixteenSegment
                  ? _CustomSixteenSegmentPainter(
                      chars[index].char,
                      chars[index].hasDot,
                      chars[index].overline,
                      enabledColor,
                      disabledColor,
                    )
                  : _CustomSevenSegmentPainter(
                      chars[index].char,
                      chars[index].hasDot,
                      chars[index].overline,
                      enabledColor,
                      disabledColor,
                    ),
            ),
          ),
        );
      }),
    );
  }
}

class _SegmentCharData {
  final String char;
  final bool hasDot;
  final bool overline;
  _SegmentCharData(this.char, this.hasDot, this.overline);
}

class _CustomSevenSegmentPainter extends CustomPainter {
  final String char;
  final bool showDot;
  final bool overline;
  final Color enabledColor;
  final Color disabledColor;

  _CustomSevenSegmentPainter(
    this.char,
    this.showDot,
    this.overline,
    this.enabledColor,
    this.disabledColor,
  );

  static const Map<String, List<bool>> _map = {
    '0': [true, true, true, true, true, true, false],
    '1': [false, true, true, false, false, false, false],
    '2': [true, true, false, true, true, false, true],
    '3': [true, true, true, true, false, false, true],
    '4': [false, true, true, false, false, true, true],
    '5': [true, false, true, true, false, true, true],
    '6': [true, false, true, true, true, true, true],
    '7': [true, true, true, false, false, false, false],
    '8': [true, true, true, true, true, true, true],
    '9': [true, true, true, true, false, true, true],
    '-': [false, false, false, false, false, false, true],
    '(': [false, false, false, false, true, true, false],
    ')': [false, true, true, false, false, false, false],
    'E': [true, false, false, true, true, true, true],
    'R': [false, false, false, false, true, false, true],
    'H': [false, true, true, false, true, true, true],
    'A': [true, true, true, false, true, true, true],
    'C': [true, false, false, true, true, true, false],
    'B': [false, false, true, true, true, true, true],
    'Y': [false, true, true, true, false, true, true],
    '°': [true, true, false, false, false, true, true],
    "'": [false, false, false, false, false, true, false],
    'ⁿ': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ], // Symbolicky prázdné nebo specifické
    '∛': [
      true,
      false,
      false,
      true,
      true,
      true,
      true,
    ], // Symbolicky jako root s horním segmentem
    '√': [false, false, false, true, true, true, false],
    '.': [false, false, false, false, false, false, false],
    '_': [false, false, false, true, false, false, false],
    ';': [
      false,
      false,
      true,
      true,
      false,
      false,
      false,
    ], // Jako spodní tečka a čárka
    ' ': [false, false, false, false, false, false, false],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _map[char.toUpperCase()] ?? List.filled(7, false);
    final w = size.width / 1.5; // Číslice zabírá 2/3 šířky
    final h = size.height;
    final thickness = w * 0.15;

    void draw(int index, Offset p1, Offset p2) {
      final paint = Paint()
        ..color = segments[index] ? enabledColor : disabledColor
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
    }

    draw(0, Offset(thickness, 0), Offset(w - thickness, 0)); // a
    draw(1, Offset(w, thickness), Offset(w, h / 2 - thickness / 2)); // b
    draw(2, Offset(w, h / 2 + thickness / 2), Offset(w, h - thickness)); // c
    draw(3, Offset(thickness, h), Offset(w - thickness, h)); // d
    draw(4, Offset(0, h / 2 + thickness / 2), Offset(0, h - thickness)); // e
    draw(5, Offset(0, thickness), Offset(0, h / 2 - thickness / 2)); // f
    draw(6, Offset(thickness, h / 2), Offset(w - thickness, h / 2)); // g

    // Čárka nad periodou (overline) – zvednuta nad segment a a ztenčena, aby 4 nevypadala jako 9
    if (overline) {
      final barPaint = Paint()
        ..color = enabledColor
        ..strokeWidth = thickness * 0.75
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, 0),
        Offset(size.width, 0),
        barPaint,
      );
    }

    // Decimální tečka (DP) - odsazená od číslice
    final dotPaint = Paint()..color = showDot ? enabledColor : disabledColor;
    canvas.drawCircle(
      Offset(w + thickness * 1.5, h),
      thickness * 0.8,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CustomSixteenSegmentPainter extends CustomPainter {
  final String char;
  final bool showDot;
  final bool overline;
  final Color enabledColor;
  final Color disabledColor;

  _CustomSixteenSegmentPainter(
    this.char,
    this.showDot,
    this.overline,
    this.enabledColor,
    this.disabledColor,
  );

  // A1, A2, B, C, D2, D1, E, F, G2, G1, H, I, J, K, L, M
  static const Map<String, List<bool>> _map = {
    '0': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    '1': [
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '2': [
      true,
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '3': [
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '4': [
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '5': [
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '6': [
      true,
      true,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '7': [
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '8': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '9': [
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'A': [
      true,
      true,
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'B': [
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'C': [
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'D': [
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'E': [
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'F': [
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'H': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'I': [
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'J': [
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'K': [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    'L': [
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'M': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      false,
      true,
      false,
      false,
      false,
    ],
    'N': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
      true,
    ],
    'O': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'P': [
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '(': [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    ')': [
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'Q': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
    ],
    'R': [
      true,
      true,
      true,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
    ],
    'S': [
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'T': [
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      true,
      false,
    ],
    'U': [
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'V': [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    'W': [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
    ],
    'X': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
      true,
      false,
      true,
    ],
    'Y': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
      false,
      true,
      false,
    ],
    'Z': [
      true,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
    ],
    '-': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '°': [
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    'ⁿ': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
    ],
    '∛': [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    '√': [
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
    ],
    "'": [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      false,
      false,
    ],
    '"': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
      true,
      false,
      false,
      false,
    ],
    '_': [
      false,
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    ';': [
      false,
      false,
      false,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      false,
    ], // Symbolicky jako spodní čárka a tečka
    ' ': [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _map[char.toUpperCase()] ?? List.filled(16, false);
    final w = size.width / 1.5; // Číslice zabírá 2/3 šířky
    final h = size.height;
    final thickness = w * 0.12;

    void draw(int index, Offset p1, Offset p2) {
      final paint = Paint()
        ..color = segments[index] ? enabledColor : disabledColor
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
    }

    // A1, A2, B, C, D2, D1, E, F, G2, G1, H, I, J, K, L, M
    draw(0, Offset(thickness, 0), Offset(w / 2 - thickness / 4, 0)); // A1
    draw(1, Offset(w / 2 + thickness / 4, 0), Offset(w - thickness, 0)); // A2
    draw(2, Offset(w, thickness), Offset(w, h / 2 - thickness / 2)); // B
    draw(3, Offset(w, h / 2 + thickness / 2), Offset(w, h - thickness)); // C
    draw(4, Offset(w / 2 + thickness / 4, h), Offset(w - thickness, h)); // D2
    draw(5, Offset(thickness, h), Offset(w / 2 - thickness / 4, h)); // D1
    draw(6, Offset(0, h / 2 + thickness / 2), Offset(0, h - thickness)); // E
    draw(7, Offset(0, thickness), Offset(0, h / 2 - thickness / 2)); // F
    draw(
      8,
      Offset(w / 2 + thickness / 4, h / 2),
      Offset(w - thickness, h / 2),
    ); // G2
    draw(
      9,
      Offset(thickness, h / 2),
      Offset(w / 2 - thickness / 4, h / 2),
    ); // G1
    draw(
      10,
      Offset(thickness, thickness),
      Offset(w / 2 - thickness / 2, h / 2 - thickness / 2),
    ); // H
    draw(
      11,
      Offset(w / 2, thickness),
      Offset(w / 2, h / 2 - thickness / 2),
    ); // I
    draw(
      12,
      Offset(w - thickness, thickness),
      Offset(w / 2 + thickness / 2, h / 2 - thickness / 2),
    ); // J
    draw(
      13,
      Offset(thickness, h - thickness),
      Offset(w / 2 - thickness / 2, h / 2 + thickness / 2),
    ); // K
    draw(
      14,
      Offset(w / 2, h - thickness),
      Offset(w / 2, h / 2 + thickness / 2),
    ); // L
    draw(
      15,
      Offset(w - thickness, h - thickness),
      Offset(w / 2 + thickness / 2, h / 2 + thickness / 2),
    ); // M

    // Čárka nad periodou (overline) – zvednuta a ztenčena
    if (overline) {
      final barPaint = Paint()
        ..color = enabledColor
        ..strokeWidth = thickness * 0.75
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, 0),
        Offset(size.width, 0),
        barPaint,
      );
    }

    // Decimální tečka (DP) - odsazená od číslice
    final dotPaint = Paint()..color = showDot ? enabledColor : disabledColor;
    canvas.drawCircle(
      Offset(w + thickness * 1.5, h),
      thickness * 0.8,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomDotMatrixDisplay extends StatelessWidget {
  final String text;
  final double ledSize;
  final double ledSpacing;
  final Color enabledColor;
  final Color disabledColor;

  const CustomDotMatrixDisplay({
    super.key,
    required this.text,
    this.ledSize = 3.0,
    this.ledSpacing = 1.0,
    this.enabledColor = Colors.redAccent,
    this.disabledColor = const Color(0x30FF5252),
  });

  @override
  Widget build(BuildContext context) {
    final items = <({String char, bool overline})>[];
    for (final unit in text.split('')) {
      if (unit == '\u0305') {
        if (items.isNotEmpty) {
          items[items.length - 1] = (
            char: items.last.char,
            overline: true,
          );
        }
      } else {
        items.add((char: unit, overline: false));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        return Container(
          margin: EdgeInsets.only(right: ledSpacing * 2),
          child: CustomPaint(
            size: Size(
              ledSize * 5 + ledSpacing * 4,
              ledSize * 8 + ledSpacing * 7,
            ),
            painter: _CustomDotMatrixPainter(
              item.char,
              item.overline,
              ledSize,
              ledSpacing,
              enabledColor,
              disabledColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomDotMatrixPainter extends CustomPainter {
  final String char;
  final bool overline;
  final double ledSize;
  final double ledSpacing;
  final Color enabledColor;
  final Color disabledColor;

  _CustomDotMatrixPainter(
    this.char,
    this.overline,
    this.ledSize,
    this.ledSpacing,
    this.enabledColor,
    this.disabledColor,
  );

  static const Map<String, List<int>> _font = {
    '0': [0x1F, 0x11, 0x11, 0x11, 0x1F],
    '1': [0x00, 0x12, 0x1F, 0x10, 0x00],
    '2': [0x19, 0x15, 0x15, 0x15, 0x13],
    '3': [0x11, 0x15, 0x15, 0x15, 0x1F],
    '4': [0x07, 0x04, 0x04, 0x04, 0x1F],
    '5': [0x17, 0x15, 0x15, 0x15, 0x19],
    '6': [0x1F, 0x15, 0x15, 0x15, 0x19],
    '7': [0x01, 0x01, 0x01, 0x01, 0x1F],
    '8': [0x1F, 0x15, 0x15, 0x15, 0x1F],
    '9': [0x17, 0x15, 0x15, 0x15, 0x1F],
    'A': [0x1E, 0x05, 0x05, 0x05, 0x1E],
    'B': [0x1F, 0x15, 0x15, 0x15, 0x0A],
    'C': [0x0E, 0x11, 0x11, 0x11, 0x11],
    'D': [0x1F, 0x11, 0x11, 0x11, 0x0E],
    'E': [0x1F, 0x15, 0x15, 0x15, 0x11],
    'F': [0x1F, 0x05, 0x05, 0x05, 0x01],
    'G': [0x0E, 0x11, 0x15, 0x15, 0x1D],
    'H': [0x1F, 0x04, 0x04, 0x04, 0x1F],
    'I': [0x11, 0x11, 0x1F, 0x11, 0x11],
    'J': [0x10, 0x10, 0x10, 0x11, 0x0F],
    'K': [0x1F, 0x04, 0x0A, 0x11, 0x00],
    'L': [0x1F, 0x10, 0x10, 0x10, 0x10],
    'M': [0x1F, 0x02, 0x04, 0x02, 0x1F],
    'N': [0x1F, 0x02, 0x04, 0x08, 0x1F],
    'O': [0x0E, 0x11, 0x11, 0x11, 0x0E],
    'P': [0x1F, 0x05, 0x05, 0x05, 0x02],
    'Q': [0x0E, 0x11, 0x19, 0x11, 0x2E],
    'R': [0x1F, 0x05, 0x05, 0x0D, 0x12],
    'S': [0x12, 0x15, 0x15, 0x15, 0x09],
    'T': [0x01, 0x01, 0x1F, 0x01, 0x01],
    'U': [0x0F, 0x10, 0x10, 0x10, 0x0F],
    'V': [0x07, 0x08, 0x10, 0x08, 0x07],
    'W': [0x1F, 0x08, 0x04, 0x08, 0x1F],
    'X': [0x11, 0x0A, 0x04, 0x0A, 0x11],
    'Y': [0x03, 0x04, 0x18, 0x04, 0x03],
    'Z': [0x11, 0x19, 0x15, 0x13, 0x11],
    '-': [0x04, 0x04, 0x04, 0x04, 0x04],
    '°': [0x00, 0x03, 0x03, 0x00, 0x00],
    "'": [0x00, 0x01, 0x02, 0x00, 0x00],
    '"': [0x01, 0x02, 0x00, 0x01, 0x02],
    '_': [0x10, 0x10, 0x10, 0x10, 0x10],
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00],
    '.': [0x00, 0x00, 0x10, 0x00, 0x00],
    '\u03C0': [0x12, 0x1F, 0x12, 0x1F, 0x12],
    '\u03A0': [0x12, 0x1F, 0x12, 0x1F, 0x12],
    '(': [0x00, 0x0E, 0x11, 0x00, 0x00],
    ')': [0x00, 0x00, 0x11, 0x0E, 0x00],
    '+': [0x04, 0x04, 0x1F, 0x04, 0x04],
    '*': [0x00, 0x0A, 0x04, 0x0A, 0x00],
    '/': [0x10, 0x08, 0x04, 0x02, 0x01],
    '%': [0x19, 0x05, 0x02, 0x14, 0x13],
    '^': [0x02, 0x01, 0x02, 0x00, 0x00],
    '\u00B2': [0x01, 0x05, 0x05, 0x05, 0x03],
    '\u00B3': [0x01, 0x05, 0x05, 0x05, 0x07],
    '√': [0x02, 0x04, 0x08, 0x10, 0x1E],
    '∛': [0x22, 0x24, 0x28, 0x30, 0x2E],
    'ⁿ': [0x00, 0x03, 0x01, 0x03, 0x00],
    ',': [0x00, 0x00, 0x18, 0x00, 0x00],
    '!': [0x00, 0x16, 0x16, 0x00, 0x00],
    ';': [0x00, 0x00, 0x14, 0x00, 0x00],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final data =
        _font[char] ??
        _font[char.toUpperCase()] ??
        [0x1F, 0x1F, 0x1F, 0x1F, 0x1F];
    final paint = Paint()..style = PaintingStyle.fill;

    for (int col = 0; col < 5; col++) {
      for (int row = 0; row < 7; row++) {
        bool enabled = (data[col] >> row) & 1 == 1;
        paint.color = enabled ? enabledColor : disabledColor;
        canvas.drawCircle(
          Offset(
            col * (ledSize + ledSpacing) + ledSize / 2,
            (row + 1) * (ledSize + ledSpacing) + ledSize / 2,
          ),
          ledSize / 2,
          paint,
        );
      }
    }

    // Čárka nad periodou (overline)
    if (overline) {
      paint.color = enabledColor;
      for (int col = 0; col < 5; col++) {
        canvas.drawCircle(
          Offset(
            col * (ledSize + ledSpacing) + ledSize / 2,
            ledSize / 2,
          ),
          ledSize / 2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
