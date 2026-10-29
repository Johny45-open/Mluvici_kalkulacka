// Čistá výpočetní vrstva pro přesnou racionální aritmetiku.
// Záměrně bez importu Flutteru i bez závislosti na aplikačním CalcError:
// unit-testovatelná izolovaně. Normalizace: jmenovatel > 0, znaménko
// v čitateli, krácení největším společným dělitelem po každé operaci.
library;

/// Přesné racionální číslo. Nulový jmenovatel konstruktor odmítne.
class Rational {
  final BigInt numerator;
  final BigInt denominator;

  Rational._(this.numerator, this.denominator);

  /// Normalizovaný tvar: `denominator > 0`, `gcd(|n|, d) == 1`, `0 == 0/1`.
  factory Rational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw const RationalZeroDenominator();
    }
    if (numerator == BigInt.zero) {
      return Rational._(BigInt.zero, BigInt.one);
    }
    var n = numerator;
    var d = denominator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.abs().gcd(d);
    if (g != BigInt.one) {
      n = n ~/ g;
      d = d ~/ g;
    }
    return Rational._(n, d);
  }

  bool get isZero => numerator == BigInt.zero;
  bool get isInteger => denominator == BigInt.one;

  Rational operator +(Rational other) => Rational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  Rational operator -(Rational other) => Rational(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );

  Rational operator *(Rational other) =>
      Rational(numerator * other.numerator, denominator * other.denominator);

  /// Dělení nulovým racionálem vyhodí [RationalZeroDenominator]
  /// (evaluátor mapuje na dělení nulou, nikdy na Infinity).
  Rational operator /(Rational other) {
    if (other.isZero) throw const RationalZeroDenominator();
    return Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  Rational operator -() => Rational(-numerator, denominator);

  /// Kompatibilní double hodnota pro formátovače, ANS-fallback a statistiky.
  /// Nikdy zdroj přesnosti pro další exaktní výpočet.
  double toDouble() => numerator.toDouble() / denominator.toDouble();

  /// Zobrazitelný tvar: celé číslo pro `d == 1`, jinak `n/d`.
  /// Nikdy nevrací `n/1`.
  String toDisplayString() {
    if (denominator == BigInt.one) return numerator.toString();
    return '${numerator.toString()}/${denominator.toString()}';
  }

  /// Serializace pro historii: desetinné řetězce `BigInt` (JSON-safe).
  String toStorageString() =>
      '${numerator.toString()}/${denominator.toString()}';

  static Rational? tryParseStorage(String? num, String? den) {
    if (num == null || den == null) return null;
    final n = BigInt.tryParse(num);
    final d = BigInt.tryParse(den);
    if (n == null || d == null || d == BigInt.zero) return null;
    return Rational(n, d);
  }

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => toDisplayString();
}

/// Vnitřní signál nulového jmenovatele/dělitele. Nikdy neopouští evaluátor.
class RationalZeroDenominator implements Exception {
  const RationalZeroDenominator();
}

/// Překročení implementačního limitu. Není matematická chyba ani výsledek.
class RationalLimitExceeded implements Exception {
  const RationalLimitExceeded();
}

/// Důvod neúspěchu exaktního vyhodnocení. Záměrně bez vazby na CalcError;
// mapování do CalcError patří integrační vrstvě kalkulačky.
enum RationalFailureKind {
  /// Dělitel normalizovaný na nulu (včetně `1/(2-2)`).
  divisionByZero,

  /// V gramatice, ale neplatné: prázdné závorky, chybějící operand,
  /// visící operátor.
  syntax,

  /// Nevyvážené závorky.
  unbalancedParens,

  /// Překročení limitu implementace (délka, tokeny, číslice).
  /// Nesmí se vydávat za výsledek ani tiše padat do `double`.
  limitExceeded,
}

/// Trojstavový výsledek exaktního evaluátoru:
/// - [RationalOk]: přesná hodnota existuje, volatelná smí ji použít.
/// - [RationalUnsupported]: mimo gramatiku → předat stávajícímu enginu
///   beze změny chování (žádná chyba, žádná hláška).
/// - [RationalFailure]: v gramatice, ale chyba → mapovat na CalcError,
///   nikdy nezaměnit za nepodporovaný výraz.
sealed class RationalEvalResult {
  const RationalEvalResult();
}

class RationalOk extends RationalEvalResult {
  final Rational value;
  const RationalOk(this.value);
}

class RationalUnsupported extends RationalEvalResult {
  const RationalUnsupported();
}

class RationalFailure extends RationalEvalResult {
  final RationalFailureKind kind;
  const RationalFailure(this.kind);
}

// Limity implementace (konstanty, zamrznout testy). Dialogová pole (12 číslic)
// se do literálového limitu vždy vejdou, takže dialogem přijatý vstup
// evaluátor na limitu neodmítne.
const int maxRationalExprLength = 200;
const int maxRationalTokens = 64;
const int maxRationalLiteralDigits = 12;
const int maxRationalValueDigits = 30;

// Povolená V1 gramatika: celočíselné literály, unární +/-, závorky,
// binární + - * /. Vše ostatní (desetinná čísla, E-notace, π, odmocniny,
// goniometrie, logaritmy, faktoriál, mocniny, procenta, DMS, čas, měny)
// je nepodporované a patří stávajícímu enginu.
RationalEvalResult tryEvaluateRational(
  String expression, {
  Map<String, Rational> symbols = const {},
}) {
  final t = expression.replaceAll(' ', '');
  if (t.isEmpty) return const RationalFailure(RationalFailureKind.syntax);
  if (t.length > maxRationalExprLength) {
    return const RationalFailure(RationalFailureKind.limitExceeded);
  }
  try {
    final tokens = _tokenize(t, symbols);
    if (tokens.length > maxRationalTokens) {
      return const RationalFailure(RationalFailureKind.limitExceeded);
    }
    final value = _evaluateTokens(tokens);
    final digits = _digits(value.numerator);
    final digitsD = _digits(value.denominator);
    if (digits > maxRationalValueDigits || digitsD > maxRationalValueDigits) {
      return const RationalFailure(RationalFailureKind.limitExceeded);
    }
    return RationalOk(value);
  } on _Unsupported {
    return const RationalUnsupported();
  } on RationalZeroDenominator {
    return const RationalFailure(RationalFailureKind.divisionByZero);
  } on RationalLimitExceeded {
    return const RationalFailure(RationalFailureKind.limitExceeded);
  } on _UnbalancedParens {
    return const RationalFailure(RationalFailureKind.unbalancedParens);
  } on _Syntax {
    return const RationalFailure(RationalFailureKind.syntax);
  }
}

class _Unsupported implements Exception {}

class _Syntax implements Exception {}

class _UnbalancedParens implements Exception {}

// Tokeny s předem vloženým explicitním násobením tam, kde stávající engine
// doplňuje `*` (číslo/`)"("`, `)`+číslice/`(`). Sousedství bez operátoru,
// které engine nepodporuje, je nepodporované (žádná tichá změna významu).
List<Object> _tokenize(String t, Map<String, Rational> symbols) {
  final out = <Object>[];
  var i = 0;
  var expectOperand = true;

  void pushImplicitMult(Object next) {
    if (out.isNotEmpty && (out.last is Rational || out.last == ')')) {
      if (next is Rational || next == '(' || next is String) {
        out.add('*');
      }
    }
  }

  while (i < t.length) {
    final c = t[i];
    if (c == ' ' || c == '\t') {
      i++;
      continue;
    }
    if (c == '(') {
      if (!expectOperand) {
        // "2(" / ")(": implicitní násobení jako stávající engine.
        out.add('*');
      }
      out.add('(');
      expectOperand = true;
      i++;
      continue;
    }
    if (c == ')') {
      if (expectOperand) throw _Syntax();
      out.add(')');
      expectOperand = false;
      i++;
      continue;
    }
    if (c == '+' || c == '-') {
      if (expectOperand) {
        // Unární znaménko: pouze jednoduché. Řetězce ("--", "+-", …)
        // patří stávajícímu enginu (dnešní chování beze změny).
        final next = i + 1 < t.length ? t[i + 1] : '';
        if (next == '+' || next == '-') throw _Unsupported();
        out.add(c == '-' ? 'u-' : 'u+');
        i++;
        continue;
      }
      out.add(c);
      expectOperand = true;
      i++;
      continue;
    }
    if (c == '*' || c == '/') {
      if (expectOperand) throw _Syntax();
      out.add(c);
      expectOperand = true;
      i++;
      continue;
    }
    if (_isDigit(c)) {
      var j = i;
      while (j < t.length && _isDigit(t[j])) {
        j++;
      }
      final digits = t.substring(i, j);
      if (digits.length > maxRationalLiteralDigits) {
        throw RationalLimitExceeded();
      }
      final value = Rational(BigInt.parse(digits), BigInt.one);
      pushImplicitMult(value);
      out.add(value);
      expectOperand = false;
      i = j;
      continue;
    }
    final code = c.codeUnitAt(0);
    final isLetter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    if (isLetter || c == '_') {
      var j = i;
      while (j < t.length) {
        final cc = t[j].codeUnitAt(0);
        final ok =
            (cc >= 65 && cc <= 90) ||
            (cc >= 97 && cc <= 122) ||
            (cc >= 48 && cc <= 57) ||
            t[j] == '_';
        if (!ok) break;
        j++;
      }
      final word = t.substring(i, j);
      final bound = symbols[word];
      if (bound == null) throw _Unsupported();
      pushImplicitMult(bound);
      out.add(bound);
      expectOperand = false;
      i = j;
      continue;
    }
    // Vše ostatní (., %, ^, !, π, √, °, E-notace, …) patří enginu.
    throw _Unsupported();
  }
  if (expectOperand && out.isNotEmpty) throw _Syntax();
  if (out.isEmpty) throw _Syntax();
  return out;
}

bool _isDigit(String c) {
  final code = c.codeUnitAt(0);
  return code >= 48 && code <= 57;
}

int _precedence(Object op) {
  if (op == 'u-' || op == 'u+') return 3;
  if (op == '*' || op == '/') return 2;
  return 1;
}

Rational _evaluateTokens(List<Object> tokens) {
  final values = <Rational>[];
  final ops = <Object>[];

  void applyOp() {
    if (ops.isEmpty) throw _Syntax();
    final op = ops.removeLast();
    if (op == 'u-' || op == 'u+') {
      if (values.isEmpty) throw _Syntax();
      final v = values.removeLast();
      values.add(op == 'u-' ? -v : v);
      return;
    }
    if (values.length < 2) throw _Syntax();
    final b = values.removeLast();
    final a = values.removeLast();
    switch (op) {
      case '+':
        values.add(a + b);
      case '-':
        values.add(a - b);
      case '*':
        values.add(a * b);
      case '/':
        values.add(a / b);
      default:
        throw _Syntax();
    }
    final r = values.last;
    if (_digits(r.numerator) > maxRationalValueDigits ||
        _digits(r.denominator) > maxRationalValueDigits) {
      throw RationalLimitExceeded();
    }
  }

  for (final tok in tokens) {
    if (tok is Rational) {
      values.add(tok);
    } else if (tok == '(') {
      ops.add(tok);
    } else if (tok == ')') {
      var found = false;
      while (ops.isNotEmpty) {
        if (ops.last == '(') {
          found = true;
          break;
        }
        applyOp();
      }
      if (!found) throw _UnbalancedParens();
      ops.removeLast();
    } else {
      // Binární i unární operátory: unární jsou pravě-asociativní,
      // binární levě-asociativní (dělení zleva: 1/2/3/4 = 1/24).
      while (ops.isNotEmpty &&
          ops.last != '(' &&
          (_precedence(ops.last) > _precedence(tok) ||
              (_precedence(ops.last) == _precedence(tok) &&
                  !(tok == 'u-' || tok == 'u+')))) {
        applyOp();
      }
      ops.add(tok);
    }
  }
  while (ops.isNotEmpty) {
    if (ops.last == '(') throw _UnbalancedParens();
    applyOp();
  }
  if (values.length != 1) throw _Syntax();
  return values.single;
}

int _digits(BigInt v) => v.abs().toString().length;
