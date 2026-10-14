import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/rational.dart';

void main() {
  group('Rational normalization', () {
    test('sign lives in numerator, gcd applied', () {
      expect(Rational(BigInt.from(2), BigInt.from(4)), Rational(BigInt.one, BigInt.from(2)));
      expect(Rational(BigInt.from(-2), BigInt.from(4)), Rational(BigInt.from(-1), BigInt.from(2)));
      expect(Rational(BigInt.from(2), BigInt.from(-4)), Rational(BigInt.from(-1), BigInt.from(2)));
      expect(Rational(BigInt.from(-2), BigInt.from(-4)), Rational(BigInt.one, BigInt.from(2)));
      expect(Rational(BigInt.zero, BigInt.from(5)), Rational(BigInt.zero, BigInt.one));
      expect(Rational(BigInt.from(5), BigInt.one).isInteger, isTrue);
    });

    test('zero denominator throws layer-local error', () {
      expect(
        () => Rational(BigInt.one, BigInt.zero),
        throwsA(isA<RationalZeroDenominator>()),
      );
    });

    test('arithmetic', () {
      Rational r(String expr) {
        final res = tryEvaluateRational(expr);
        expect(res, isA<RationalOk>());
        return (res as RationalOk).value;
      }

      expect(r('1/2+1/3'), Rational(BigInt.from(5), BigInt.from(6)));
      expect(r('3/4*2/5'), Rational(BigInt.from(3), BigInt.from(10)));
      expect(r('(1/2)/(3/4)'), Rational(BigInt.from(2), BigInt.from(3)));
      expect(r('-1/2+3/4'), Rational(BigInt.from(1), BigInt.from(4)));
      expect(r('1/2-1/3'), Rational(BigInt.one, BigInt.from(6)));
      expect(r('1/3*3'), Rational(BigInt.one, BigInt.one));
      expect(r('2/4+1/4'), Rational(BigInt.from(3), BigInt.from(4)));
      expect(r('0/5'), Rational(BigInt.zero, BigInt.one));
      expect(r('1/2/3/4'), Rational(BigInt.one, BigInt.from(24)));
      expect(r('2(1/2)'), Rational(BigInt.one, BigInt.one));
      expect(r('(1/2)(1/3)'), Rational(BigInt.one, BigInt.from(6)));
      expect(r('0-3/4'), Rational(BigInt.from(-3), BigInt.from(4)));
    });

    test('toDisplayString never yields n/1', () {
      expect(Rational(BigInt.from(5), BigInt.one).toDisplayString(), '5');
      expect(Rational(BigInt.zero, BigInt.one).toDisplayString(), '0');
      expect(Rational(BigInt.from(-3), BigInt.from(4)).toDisplayString(), '-3/4');
    });

    test('storage roundtrip', () {
      const original = '123/456';
      final parsed = Rational.tryParseStorage('123', '456');
      expect(parsed, isNotNull);
      // 123/456 reduces by gcd 3 -> 41/152
      expect(parsed.toString(), '41/152');
      expect(original, isNotEmpty);
      expect(Rational.tryParseStorage('1', '0'), isNull);
      expect(Rational.tryParseStorage('a', '2'), isNull);
      expect(Rational.tryParseStorage(null, '2'), isNull);
    });
  });

  group('tryEvaluateRational contract', () {
    RationalFailureKind? failureOf(String expr) {
      final res = tryEvaluateRational(expr);
      if (res is RationalFailure) return res.kind;
      return null;
    }

    test('B: unsupported goes to the double engine, never an error', () {
      for (final expr in [
        'SIN(30)',
        '1/2+0.5',
        '1/2+3,5',
        '10E5',
        '2^3',
        '50%',
        '√2',
        '∛8',
        '4ⁿ√16',
        '1/2+π',
        '30°',
        '5!',
        'LOG(10)',
        'LN(2)',
        'ABS(-1)',
        'A+1',
        'E+2',
        '--1/2',
        '1/2+SIN(30)',
      ]) {
        expect(tryEvaluateRational(expr), isA<RationalUnsupported>(),
            reason: expr);
      }
    });

    test('C: division by zero keeps its kind', () {
      expect(failureOf('1/0'), RationalFailureKind.divisionByZero);
      expect(failureOf('1/(2-2)'), RationalFailureKind.divisionByZero);
      expect(failureOf('(1/2)/0'), RationalFailureKind.divisionByZero);
      expect(failureOf('4/(3-3)'), RationalFailureKind.divisionByZero);
    });

    test('C: syntax vs unbalanced parens stay distinct', () {
      expect(failureOf('1/2+'), RationalFailureKind.syntax);
      expect(failureOf('(1/2'), RationalFailureKind.unbalancedParens);
      expect(failureOf('1/2)'), RationalFailureKind.unbalancedParens);
      expect(failureOf('()'), RationalFailureKind.syntax);
      expect(failureOf(''), RationalFailureKind.syntax);
      expect(failureOf('(1/2))((3/4)'), RationalFailureKind.unbalancedParens);
    });

    test('C: limits are errors, never silent double fallback', () {
      expect(failureOf('1/2+${'1' * 300}'), RationalFailureKind.limitExceeded);
      expect(
        failureOf('${'1234567890123'}/2'),
        RationalFailureKind.limitExceeded,
      );
      // 12-digit literals are accepted (dialog limit fits evaluator limit).
      final ok = tryEvaluateRational('123456789012/1');
      expect(ok, isA<RationalOk>());
    });

    test('symbols: only bound ANS expands, other words are unsupported', () {
      final ans = Rational(BigInt.one, BigInt.from(2));
      final res = tryEvaluateRational('ANS+1/2', symbols: {'ANS': ans});
      expect(res, isA<RationalOk>());
      expect((res as RationalOk).value, Rational(BigInt.one, BigInt.one));
      expect(
        tryEvaluateRational('ANS+1/2'),
        isA<RationalUnsupported>(),
      );
    });
  });
}
