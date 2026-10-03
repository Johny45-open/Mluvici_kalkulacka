import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/fraction.dart';

void main() {
  group('decimalToFraction', () {
    test('0 -> 0/1 (oprava nuly)', () {
      expect(decimalToFraction(0), const Fraction(0, 1));
      expect(decimalToFraction(-0.0), const Fraction(0, 1));
    });

    test('zakladni zlomky', () {
      expect(decimalToFraction(0.5), const Fraction(1, 2));
      expect(decimalToFraction(0.25), const Fraction(1, 4));
      expect(decimalToFraction(0.75), const Fraction(3, 4));
      expect(decimalToFraction(1.25), const Fraction(5, 4));
      expect(decimalToFraction(1.5), const Fraction(3, 2));
      expect(decimalToFraction(2.75), const Fraction(11, 4));
      expect(decimalToFraction(-0.75), const Fraction(-3, 4));
    });

    test('cela cisla -> n/1', () {
      expect(decimalToFraction(2), const Fraction(2, 1));
      expect(decimalToFraction(5), const Fraction(5, 1));
      expect(decimalToFraction(-3), const Fraction(-3, 1));
    });

    test('blizka 1/3 -> rozumna reprezentace 1/3', () {
      expect(decimalToFraction(1 / 3), const Fraction(1, 3));
      expect(decimalToFraction(0.3333333333), const Fraction(1, 3));
      expect(decimalToFraction(2 / 3), const Fraction(2, 3));
    });

    test('male zlomky a zaporna cisla', () {
      expect(decimalToFraction(0.2), const Fraction(1, 5));
      expect(decimalToFraction(-1.5), const Fraction(-3, 2));
      expect(decimalToFraction(0.125), const Fraction(1, 8));
    });

    test('NaN/Infinity -> null (nedostupne)', () {
      expect(decimalToFraction(double.nan), isNull);
      expect(decimalToFraction(double.infinity), isNull);
      expect(decimalToFraction(double.negativeInfinity), isNull);
    });

    test('jmenovatel drzi limit 10000', () {
      final f = decimalToFraction(0.123456789)!;
      expect(f.denominator, lessThanOrEqualTo(10000));
      expect(f.numerator / f.denominator, closeTo(0.123456789, 1e-8));
    });
  });

  group('decimalToNonTrivialFraction', () {
    test('cela cisla a nula -> null (neni dostupny zlomek)', () {
      expect(decimalToNonTrivialFraction(0), isNull);
      expect(decimalToNonTrivialFraction(-0.0), isNull);
      expect(decimalToNonTrivialFraction(2), isNull);
      expect(decimalToNonTrivialFraction(5), isNull);
      expect(decimalToNonTrivialFraction(-3), isNull);
    });

    test('skutecne zlomky zustavaji dostupne', () {
      expect(decimalToNonTrivialFraction(0.5), const Fraction(1, 2));
      expect(decimalToNonTrivialFraction(1.5), const Fraction(3, 2));
      expect(decimalToNonTrivialFraction(2.75), const Fraction(11, 4));
      expect(decimalToNonTrivialFraction(1 / 3), const Fraction(1, 3));
    });

    test('NaN/Infinity -> null', () {
      expect(decimalToNonTrivialFraction(double.nan), isNull);
      expect(decimalToNonTrivialFraction(double.infinity), isNull);
      expect(decimalToNonTrivialFraction(double.negativeInfinity), isNull);
    });
  });

  group('formatFraction', () {
    test('textovy zapis n/d', () {
      expect(formatFraction(const Fraction(3, 4)), '3/4');
      expect(formatFraction(const Fraction(11, 4)), '11/4');
      expect(formatFraction(const Fraction(-3, 4)), '-3/4');
      expect(formatFraction(const Fraction(5, 1)), '5/1');
      expect(formatFraction(const Fraction(0, 1)), '0/1');
    });
  });
}
