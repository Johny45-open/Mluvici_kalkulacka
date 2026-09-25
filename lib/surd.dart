// Čistá výpočetní vrstva pro částečné odmocňování a volbu rendereru.
// Záměrně bez importu Flutteru: musí být unit-testovatelná izolovaně
// a nesmí záviset na konkrétním vizuálním rendereru (segment vs. text).
import 'dart:math' as math;

// Režim vykreslování výsledkového displeje. Význam je nezávislý na
// existujícím DisplayFormat (standard/fix/sci/eng), který se nemění:
// - segment: vždy současný segmentový displej (původní vzhled),
// - text: vždy matematický textový displej,
// - auto: běžná čísla segmentově, matematické konstrukce textově.
enum ResultDisplayMode { segment, text, auto }

// Výsledek výpočtu oddělený od vizuální reprezentace.
sealed class CalcValue {
  const CalcValue();
}

// Běžný numerický výsledek. Zůstává zdrojem pravdy pro výpočty,
// formátování, statistiky, historii i ANS-řetězení.
class NumericValue extends CalcValue {
  final double value;
  const NumericValue(this.value);
}

// Exaktní částečně odmocněný výsledek, např. √72 = 6√2.
// Pouze prezentační nadstavba nad numerickým výsledkem, nikdy jediný
// zdroj pravdy pro segmentový renderer ani historii.
class SurdValue extends CalcValue {
  // Koeficient před odmocninou (vždy >= 2, jinak nejde o částečný tvar).
  final int coefficient;
  // Zbytek pod odmocninou (index-free: neobsahuje index-tou mocninu > 1).
  final int radicand;
  // Index odmocniny: 2 = √, 3 = ∛, n = ⁿ√.
  final int index;
  const SurdValue({
    required this.coefficient,
    required this.radicand,
    required this.index,
  });

  @override
  bool operator ==(Object other) =>
      other is SurdValue &&
      other.coefficient == coefficient &&
      other.radicand == radicand &&
      other.index == index;

  @override
  int get hashCode => Object.hash(coefficient, radicand, index);

  @override
  String toString() =>
      'SurdValue($coefficient, $radicand, $index) = ${formatSurd(this)}';
}

// Horní mez radikandu pro bezpečný rozklad na prvočinitele.
// Trial-division do sqrt(1e9) ≈ 31623 je otázkou milisekund;
// větší vstupy odmítneme (volající použije běžný numerický výsledek).
const int maxSurdRadicand = 1000000000;

// Rozloží celé kladné n na n = k^index × m, kde m je index-free
// (žádné prvočíslo se v m nevyskytuje s mocnitelem >= index).
// Vrací SurdValue(k, m, index), nebo null když částečný tvar nedává
// smysl: perfektní mocnina (např. √64 -> null, volající dá NumericValue(8)),
// prvočíslo/square-free číslo (√7, √2 -> null), nekladný/necelý vstup,
// index < 2, nebo radikand nad [maxSurdRadicand].
SurdValue? tryPartialRoot({required int radicand, required int index}) {
  if (index < 2) return null;
  if (radicand <= 1) return null;
  if (radicand > maxSurdRadicand) return null;

  // Rozklad na prvočinitele trial-division.
  final factors = <int, int>{};
  var rest = radicand;
  for (var p = 2; p * p <= rest; p += (p == 2 ? 1 : 2)) {
    while (rest % p == 0) {
      factors[p] = (factors[p] ?? 0) + 1;
      rest ~/= p;
    }
  }
  if (rest > 1) factors[rest] = (factors[rest] ?? 0) + 1;

  var coef = 1;
  var inner = 1;
  factors.forEach((prime, exp) {
    final out = exp ~/ index;
    final kept = exp % index;
    for (var i = 0; i < out; i++) {
      coef *= prime;
    }
    for (var i = 0; i < kept; i++) {
      inner *= prime;
    }
  });

  // Perfektní mocnina (nic nezbylo pod odmocninou) -> numerický výsledek.
  if (inner == 1) return null;
  // Nic nelze vytknout (koeficient 1) -> běžný numerický výsledek.
  if (coef == 1) return null;
  return SurdValue(coefficient: coef, radicand: inner, index: index);
}

// Bezpečnostní obálka nad double vstupem: surd pouze pro kladná celá čísla.
SurdValue? tryPartialRootOfDouble(double radicand, int index) {
  if (!radicand.isFinite) return null;
  if (radicand <= 1) return null;
  if (radicand > maxSurdRadicand) return null;
  final n = radicand.round();
  // Odmítni necelé hodnoty (tolerance proti float-šumu z parseru).
  if ((radicand - n).abs() > 1e-9) return null;
  return tryPartialRoot(radicand: n, index: index);
}

const _superscripts = <String>[
  '⁰',
  '¹',
  '²',
  '³',
  '⁴',
  '⁵',
  '⁶',
  '⁷',
  '⁸',
  '⁹',
];

// Převede index odmocniny na superscript řetězec, např. 4 -> "⁴", 12 -> "¹²".
String superscriptIndex(int index) {
  return index
      .toString()
      .split('')
      .map((d) => _superscripts[int.parse(d)])
      .join();
}

// Matematický zápis bez operátoru: "6√2", "3∛2", "2⁴√3".
String formatSurd(SurdValue v) {
  if (v.index == 2) return '${v.coefficient}√${v.radicand}';
  if (v.index == 3) return '${v.coefficient}∛${v.radicand}';
  return '${v.coefficient}${superscriptIndex(v.index)}√${v.radicand}';
}

// Numerická hodnota surdu pro ANS, historii a kontroly (nikoli pro displej).
double surdToDouble(SurdValue v) {
  return v.coefficient * math.pow(v.radicand, 1.0 / v.index).toDouble();
}

// Rozpozná jednoduchou odmocninu celého čísla zadanou jako celý výraz:
// "√72" i "√(72)" (index 2), "∛54" i "∛(54)" (index 3),
// "4ⁿ√48" i "4ⁿ√(48)" (obecný index). Závorka je volitelná, protože
// kalkulačka vkládá "√(" a auto-uzavírání může chybějící ")" doplnit až
// při výpočtu. Vrací SurdValue, nebo null pro složené výrazy,
// desetinná/záporná čísla a případy bez částečného tvaru.
// Nenahrazuje parser, jen bezpečně detekuje tvar vhodný pro exaktní zobrazení.
SurdValue? trySurdFromExpression(String expr) {
  final t = expr.replaceAll(' ', '').replaceAll(',', '.');
  var m = RegExp(r'^√\(?(\d+)\)?$').firstMatch(t);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n == null) return null;
    return tryPartialRoot(radicand: n, index: 2);
  }
  m = RegExp(r'^∛\(?(\d+)\)?$').firstMatch(t);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n == null) return null;
    return tryPartialRoot(radicand: n, index: 3);
  }
  m = RegExp(r'^(\d+)ⁿ√\(?(\d+)\)?$').firstMatch(t);
  if (m != null) {
    final idx = int.tryParse(m.group(1)!);
    final n = int.tryParse(m.group(2)!);
    if (idx == null || n == null) return null;
    return tryPartialRoot(radicand: n, index: idx);
  }
  return null;
}

// Kam se má výsledek vykreslit. Jediné centralizované rozhodnutí
// segment-vs-text v celé aplikaci (požadavek: nerozesívat heuristiky).
enum CalcDisplayKind { segment, mathText }

// Centralizovaný rozhodovací mechanismus:
// - SurdValue -> vždy text (segmenty neumí "6√2"),
// - NumericValue -> segment, ledaže fallback-řetězec obsahuje matematickou
//   strukturu nezobrazitelnou segmenty (√ ∛ ⁿ π ² ³), pak text.
// DMS (°), E-notace, periodická čára (U+0305) a znaménka jsou segment-safe.
CalcDisplayKind chooseDisplayRenderer(CalcValue value, String fallbackResult) {
  if (value is SurdValue) return CalcDisplayKind.mathText;
  if (fallbackResult.contains('√') ||
      fallbackResult.contains('∛') ||
      fallbackResult.contains('ⁿ') ||
      fallbackResult.contains('π') ||
      fallbackResult.contains('²') ||
      fallbackResult.contains('³')) {
    return CalcDisplayKind.mathText;
  }
  return CalcDisplayKind.segment;
}
