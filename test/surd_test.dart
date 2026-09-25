import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/surd.dart';

void main() {
  group('tryPartialRoot – druhá odmocnina', () {
    test('√72 -> 6√2', () {
      expect(
        tryPartialRoot(radicand: 72, index: 2),
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
    });
    test('√50 -> 5√2', () {
      expect(
        tryPartialRoot(radicand: 50, index: 2),
        const SurdValue(coefficient: 5, radicand: 2, index: 2),
      );
    });
    test('√12 -> 2√3', () {
      expect(
        tryPartialRoot(radicand: 12, index: 2),
        const SurdValue(coefficient: 2, radicand: 3, index: 2),
      );
    });
    test('√180 -> 6√5', () {
      expect(
        tryPartialRoot(radicand: 180, index: 2),
        const SurdValue(coefficient: 6, radicand: 5, index: 2),
      );
    });
    test('√64 (perfektní čtverec) -> null, volající dá NumericValue(8)', () {
      expect(tryPartialRoot(radicand: 64, index: 2), isNull);
    });
    test('√7 a √2 (bez čtvercového činitele) -> null', () {
      expect(tryPartialRoot(radicand: 7, index: 2), isNull);
      expect(tryPartialRoot(radicand: 2, index: 2), isNull);
    });
    test('záporný radikand -> null (domain-error cesta beze změny)', () {
      expect(tryPartialRoot(radicand: -72, index: 2), isNull);
    });
    test('radikand 0/1 a index < 2 -> null', () {
      expect(tryPartialRoot(radicand: 0, index: 2), isNull);
      expect(tryPartialRoot(radicand: 1, index: 2), isNull);
      expect(tryPartialRoot(radicand: 72, index: 1), isNull);
    });
  });

  group('tryPartialRoot – vyšší odmocniny', () {
    test('∛54 -> 3∛2', () {
      expect(
        tryPartialRoot(radicand: 54, index: 3),
        const SurdValue(coefficient: 3, radicand: 2, index: 3),
      );
    });
    test('⁴√48 -> 2⁴√3', () {
      expect(
        tryPartialRoot(radicand: 48, index: 4),
        const SurdValue(coefficient: 2, radicand: 3, index: 4),
      );
    });
    test('∛27 (perfektní) -> null', () {
      expect(tryPartialRoot(radicand: 27, index: 3), isNull);
    });
  });

  group('limity', () {
    test('desetinný radikand -> null', () {
      expect(tryPartialRootOfDouble(7.5, 2), isNull);
      expect(tryPartialRootOfDouble(72.0, 2), isNotNull);
    });
    test('velká čísla nad limitem -> null (overflow guard)', () {
      expect(tryPartialRoot(radicand: maxSurdRadicand + 1, index: 2), isNull);
      expect(tryPartialRootOfDouble(1e15, 2), isNull);
    });
    test('nekonečno/NaN -> null', () {
      expect(tryPartialRootOfDouble(double.infinity, 2), isNull);
      expect(tryPartialRootOfDouble(double.nan, 2), isNull);
    });
  });

  group('formatSurd – matematický zápis bez operátoru', () {
    test('6√2, 5√2, 2√3, 6√5', () {
      expect(
        formatSurd(const SurdValue(coefficient: 6, radicand: 2, index: 2)),
        '6√2',
      );
      expect(
        formatSurd(const SurdValue(coefficient: 5, radicand: 2, index: 2)),
        '5√2',
      );
    });
    test('3∛2 a 2⁴√3', () {
      expect(
        formatSurd(const SurdValue(coefficient: 3, radicand: 2, index: 3)),
        '3∛2',
      );
      expect(
        formatSurd(const SurdValue(coefficient: 2, radicand: 3, index: 4)),
        '2⁴√3',
      );
    });
    test('surdToDouble souhlasí s double výpočtem', () {
      expect(
        surdToDouble(const SurdValue(coefficient: 6, radicand: 2, index: 2)),
        closeTo(6 * 1.4142135623730951, 1e-9),
      );
    });
  });

  group('trySurdFromExpression – detekce jednoduché odmocniny', () {
    test('√72 / ∛54 / 4ⁿ√48 (i se závorkou jako z klávesnice)', () {
      for (final e in ['√72', '√(72)', '√(72', '∛54', '∛(54)']) {
        expect(trySurdFromExpression(e), isNotNull, reason: e);
      }
      expect(
        trySurdFromExpression('√72'),
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      expect(
        trySurdFromExpression('√(72)'),
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      expect(
        trySurdFromExpression('∛54'),
        const SurdValue(coefficient: 3, radicand: 2, index: 3),
      );
      expect(
        trySurdFromExpression('4ⁿ√48'),
        const SurdValue(coefficient: 2, radicand: 3, index: 4),
      );
      expect(
        trySurdFromExpression('4ⁿ√(48)'),
        const SurdValue(coefficient: 2, radicand: 3, index: 4),
      );
    });
    test('složené výrazy a desetinná čísla -> null', () {
      expect(trySurdFromExpression('√72+1'), isNull);
      expect(trySurdFromExpression('2*√72'), isNull);
      expect(trySurdFromExpression('√7.5'), isNull);
      expect(trySurdFromExpression('√-72'), isNull);
      expect(trySurdFromExpression('25'), isNull);
      expect(trySurdFromExpression(''), isNull);
    });
  });

  group('chooseDisplayRenderer – jediné centralizované rozhodnutí', () {
    test('SurdValue -> vždy text', () {
      expect(
        chooseDisplayRenderer(
          const SurdValue(coefficient: 6, radicand: 2, index: 2),
          '8,485',
        ),
        CalcDisplayKind.mathText,
      );
    });
    test('běžná čísla -> segment (123.45, -72, 1E+06, DMS, perioda)', () {
      for (final s in ['123.45', '-72', '1E+06', '12°34′', '0.3̅']) {
        expect(
          chooseDisplayRenderer(const NumericValue(1), s),
          CalcDisplayKind.segment,
          reason: s,
        );
      }
    });
    test('matematická struktura ve fallbacku -> text', () {
      for (final s in ['6√2', '5∛2', '2⁴√3', '3π']) {
        expect(
          chooseDisplayRenderer(const NumericValue(1), s),
          CalcDisplayKind.mathText,
          reason: s,
        );
      }
    });
  });
}
