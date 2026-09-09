// ignore_for_file: public_member_api_docs

/// Pure helpers for visual thousands grouping.
/// No Flutter dependency – testable in unit tests.

bool _isDigit(String c) {
  if (c.length != 1) return false;
  final code = c.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

bool _isDecimalSep(String c) => c == '.' || c == ',';

/// Returns the set of indices in [display] after which a visual gap
/// should be rendered. Only the integer part of each numeric literal
/// is grouped, 3 digits from the right. Decimal part, period "(…)",
/// exponent, variables etc. are ignored.
///
/// Example: "8888" -> {0}, "888888" -> {2}, "1234567.89" -> {0,3}
Set<int> computeThousandGapIndicesForDisplay(
  String display, {
  String decimalSeparators = '.,',
}) {
  final gaps = <int>{};
  bool isDec(String ch) => decimalSeparators.contains(ch);
  int i = 0;
  final n = display.length;
  while (i < n) {
    final ch = display[i];
    // start of a number: digit or '-' followed by digit
    bool isStart = _isDigit(ch) ||
        (ch == '-' && i + 1 < n && _isDigit(display[i + 1]));
    if (!isStart) {
      i++;
      continue;
    }
    int start = i;
    if (display[start] == '-') {
      start++;
      // start points to first digit; but for gap we need digit indices
    }
    // collect integer part digits
    final intDigitIndices = <int>[];
    int j = start;
    while (j < n && _isDigit(display[j])) {
      intDigitIndices.add(j);
      j++;
    }
    final L = intDigitIndices.length;
    if (L > 3) {
      for (int p = 0; p < L - 1; p++) {
        if ((L - p - 1) % 3 == 0) {
          gaps.add(intDigitIndices[p]);
        }
      }
    }
    // skip decimal + fractional part
    if (j < n && isDec(display[j])) {
      j++; // skip sep
      while (j < n && _isDigit(display[j])) {
        j++;
      }
    }
    // skip periodic "(digits)" – not grouped
    if (j < n && display[j] == '(') {
      int k = j + 1;
      while (k < n && _isDigit(display[k])) k++;
      if (k < n && display[k] == ')') {
        j = k + 1;
      }
    }
    // also handle exponent part like "E-10" – skip
    if (j < n && (display[j] == 'E' || display[j] == 'e')) {
      int k = j + 1;
      if (k < n && (display[k] == '+' || display[k] == '-')) k++;
      while (k < n && _isDigit(display[k])) k++;
      j = k;
    }
    // avoid infinite loop
    if (j <= i) {
      i++;
    } else {
      i = j;
    }
  }
  return gaps;
}

/// Visual helper that inserts a single space at gap positions for
/// testing / expectation strings. Does NOT modify the underlying
/// display value.
String formatDisplayWithSpaces(
  String display, {
  String decimalSeparators = '.,',
}) {
  final gaps = computeThousandGapIndicesForDisplay(
    display,
    decimalSeparators: decimalSeparators,
  );
  if (gaps.isEmpty) return display;
  final buf = StringBuffer();
  for (int i = 0; i < display.length; i++) {
    buf.write(display[i]);
    if (gaps.contains(i)) buf.write(' ');
  }
  return buf.toString();
}

/// Computes gap indices for the widget's `items` list (which already
/// contains the cursor "_" as an item and has collapsed overline
/// combining marks). `"_"` is treated as transparent – it does not
/// split a number and does not count as a digit.
///
/// Items are `({String char, bool overline})` as built in
/// `CustomDotMatrixDisplay`. This function replicates the same parsing
/// as above but on the item level.
Set<int> computeThousandGapIndicesForItems(
  List<({String char, bool overline})> items,
) {
  final gaps = <int>{};
  final n = items.length;

  bool isDigitChar(String c) => _isDigit(c);
  bool isDecChar(String c) => _isDecimalSep(c);

  int i = 0;
  while (i < n) {
    final ch = items[i].char;
    if (ch == '_') {
      i++;
      continue;
    }
    // look ahead to see if '-' is followed by a digit (skipping '_' )
    bool isStart = isDigitChar(ch);
    if (ch == '-') {
      int k = i + 1;
      while (k < n && items[k].char == '_') k++;
      if (k < n && isDigitChar(items[k].char)) isStart = true;
      else isStart = false;
    }
    if (!isStart) {
      i++;
      continue;
    }

    // collect integer part digit item indices
    final intDigitIndices = <int>[];
    int j = i;
    bool hasMinus = false;
    if (items[j].char == '-') {
      hasMinus = true;
      j++;
      while (j < n && items[j].char == '_') j++;
    }
    // collect consecutive digits (with '_' transparent) as integer part
    while (j < n) {
      final cj = items[j].char;
      if (cj == '_') {
        j++;
        continue;
      }
      if (isDigitChar(cj)) {
        intDigitIndices.add(j);
        j++;
      } else if (isDecChar(cj)) {
        break;
      } else {
        break;
      }
    }
    final L = intDigitIndices.length;
    if (L > 3) {
      for (int p = 0; p < L - 1; p++) {
        if ((L - p - 1) % 3 == 0) {
          gaps.add(intDigitIndices[p]);
        }
      }
    }
    // skip decimal part (including '_' and overline digits as part of fraction)
    if (j < n && isDecChar(items[j].char)) {
      j++;
      while (j < n) {
        final cj = items[j].char;
        if (cj == '_') {
          j++;
          continue;
        }
        if (isDigitChar(cj)) {
          j++;
        } else {
          break;
        }
      }
      // periodic overline part is just digits with overline==true,
      // already consumed as fractional digits – nothing extra.
    }
    // skip exponent if present (E)
    if (j < n && (items[j].char == 'E' || items[j].char == 'e')) {
      int k = j + 1;
      while (k < n && items[k].char == '_') k++;
      if (k < n && (items[k].char == '+' || items[k].char == '-')) k++;
      while (k < n) {
        if (items[k].char == '_') { k++; continue; }
        if (isDigitChar(items[k].char)) k++; else break;
      }
      j = k;
    }
    // Also skip '(' periodic form if it somehow appears in items
    // (should not for bar notation, but handle for raw display with '(' )
    if (j < n && items[j].char == '(') {
      int k = j + 1;
      while (k < n) {
        final cj = items[k].char;
        if (cj == '_') { k++; continue; }
        if (isDigitChar(cj)) k++; else break;
      }
      if (k < n && items[k].char == ')') k++;
      j = k;
    }

    if (j <= i) {
      i++;
    } else {
      i = j;
    }
    // avoid unused warning
    if (hasMinus) {}
  }
  return gaps;
}

/// Estimates visual width helpers for autoscroll (used only for
/// progressive autoscroll correction). Not required for correctness
/// but can improve proportional scroll when grouping gaps are present.
double estimateTotalVisualWidth({
  required int textLength,
  required int gapCount,
  required double charWidth,
  required double baseGap,
  required double extraGap,
}) {
  if (textLength <= 0) return 0;
  return textLength * charWidth +
      (textLength - 1) * baseGap +
      gapCount * extraGap;
}

double estimateWidthBeforeCursor({
  required int cursorPosition,
  required Set<int> gaps,
  required double charWidth,
  required double baseGap,
  required double extraGap,
}) {
  if (cursorPosition <= 0) return 0;
  int gapsBefore = 0;
  for (final g in gaps) {
    if (g < cursorPosition) gapsBefore++;
    // gap after index g is before cursor if g < cursorPosition
    // For cursor inside number with '_' transparent, caller should pass
    // logical gaps; this estimate is approximate using logical positions.
  }
  // chars before cursor = cursorPosition
  // base gaps before cursor = cursorPosition (if not at 0, includes gaps between chars)
  // but last char before cursor does not need trailing base? Approximation:
  // width = chars*charWidth + (chars)*baseGap? Simplify: use chars * (charWidth+baseGap)
  return cursorPosition * charWidth +
      (cursorPosition > 0 ? (cursorPosition - 1) * baseGap : 0) +
      gapsBefore * extraGap;
}
