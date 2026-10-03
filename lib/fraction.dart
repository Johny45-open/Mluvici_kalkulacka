// Čistá matematická vrstva pro převod desetinného čísla na zlomek.
// Záměrně bez importu Flutteru: unit-testovatelná izolovaně.
// Zlomek je POUZE prezentační vrstva nad numerickým výsledkem — nikdy
// zdroj pravdy pro výpočty, historii ani ANS.
library;

// Racionální reprezentace desetinného čísla.
class Fraction {
  final int numerator;
  final int denominator;

  const Fraction(this.numerator, this.denominator);

  @override
  bool operator ==(Object other) =>
      other is Fraction &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => formatFraction(this);
}

// Maximální jmenovatel racionální aproximace. Vědomě konzervativní:
// výsledek je aproximace, ne tvrzení o přesném zlomku každého reálného čísla.
const int maxFractionDenominator = 10000;

// Tolerance shody aproximace s původní hodnotou.
const double _fractionEpsilon = 1e-10;

// Převede [value] na zlomek continued-fraction aproximací.
// - 0 -> 0/1 (oprava: dříve se vracelo "nedostupné"),
// - celá čísla -> n/1,
// - záporná čísla si nesou znaménko v čitateli,
// - ne-konečné hodnoty (NaN/Infinity) -> null (volající řeší nedostupnost).
Fraction? decimalToFraction(double value) {
  if (value.isNaN || value.isInfinite) return null;
  if (value == 0) return const Fraction(0, 1);
  final bool negative = value < 0;
  double absVal = value.abs();
  final double intPart = absVal.floorToDouble();
  final double frac = absVal - intPart;
  if (frac < _fractionEpsilon) {
    final int n = intPart.toInt();
    return Fraction(negative ? -n : n, 1);
  }
  // Standardní inicializace konvergentů: h[-2]=0, h[-1]=1, k[-2]=1, k[-1]=0.
  // (Původní helper v calculator_screen je měl prohozené a vracel
  // převrácené hodnoty, např. 0.5 -> 2/1 — ověřeno testem.)
  double hPrev = 0, hCurr = 1;
  double kPrev = 1, kCurr = 0;
  double remaining = frac;
  const int maxIter = 10000;
  int iter = 0;
  while (iter < maxIter && kCurr <= maxFractionDenominator) {
    final double a = remaining.floorToDouble();
    final double hNext = a * hCurr + hPrev;
    final double kNext = a * kCurr + kPrev;
    if (kNext > maxFractionDenominator) break;
    hPrev = hCurr;
    hCurr = hNext;
    kPrev = kCurr;
    kCurr = kNext;
    final double approx = (intPart * kCurr + hCurr) / kCurr;
    if ((absVal - approx).abs() < _fractionEpsilon) break;
    final double diff = remaining - a;
    if (diff < _fractionEpsilon) break;
    remaining = 1.0 / diff;
    iter++;
  }
  int num = (intPart * kCurr + hCurr).round();
  final int den = kCurr.round();
  if (negative) num = -num;
  return Fraction(num, den);
}

// Textový zápis "n/d", např. 3/4, 11/4, -3/4, 5/1, 0/1.
String formatFraction(Fraction fraction) =>
    '${fraction.numerator}/${fraction.denominator}';

/// Vrátí pouze uživatelsky smysluplný, netriviální zlomek.
/// Matematický převodník [decimalToFraction] zůstává beze změny.
/// - null z [decimalToFraction] (NaN/Infinity) -> null,
/// - zlomek se jmenovatelem 1 (n/1, včetně 0/1) -> null (není dostupný zlomek),
/// - jinak vrátí [Fraction].
Fraction? decimalToNonTrivialFraction(double value) {
  final f = decimalToFraction(value);
  if (f == null) return null;
  if (f.denominator == 1) return null;
  return f;
}
