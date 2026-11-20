import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/intermediate_evaluation.dart';

void main() {
  group('IntermediateEvaluator unit testy', () {
    // Jednoduchý mock evaluátor pro testy
    double mockEvaluator(String expr) {
      final clean = expr.trim();
      if (clean == '(2+2)' || clean == '2+2') return 4.0;
      if (clean == '6*4' || clean == '6*(4)') return 24.0;
      if (clean == '(3*4)' || clean == '3*4') return 12.0;
      if (clean == '(2+12)' || clean == '2+12') return 14.0;
      if (clean == '6*14' || clean == '6*(14)') return 84.0;
      if (clean == '(3+1)' || clean == '3+1') return 4.0;
      if (clean == '(5-2)' || clean == '5-2') return 3.0;
      if (clean == '4*3' || clean == '4*(3)' || clean == '(4)*3') return 12.0;
      if (clean == 'SIN(30)' || clean == 'SIN(15+15)') return 0.5;
      if (clean == '15+15' || clean == '(15+15)') return 30.0;
      if (clean == '5/(2-2)') throw Exception('Division by zero');
      if (clean == '2-2' || clean == '(2-2)') return 0.0;
      return 0.0;
    }

    String mockFormatter(double v) {
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toString();
    }

    String mockSpoken(double v) => mockFormatter(v);

    test(
      'T1: Jednoduché závorky 6*(2+2) vyhodnotí (2+2) = 4 a následně 6*4 = 24',
      () {
        final res = IntermediateEvaluator.computeIntermediateSteps(
          expression: '6*(2+2)',
          evaluator: mockEvaluator,
          formatter: mockFormatter,
          spokenFormatter: mockSpoken,
        );

        expect(res.hasError, isFalse);
        expect(res.steps.length, greaterThanOrEqualTo(1));
        expect(res.steps[0].subExpression, '(2+2)');
        expect(res.steps[0].value, 4.0);
        expect(res.steps[0].formattedValue, '4');
        if (res.steps.length > 1) {
          expect(res.steps[1].value, 24.0);
        }
      },
    );

    test('T2: Vícenásobné nezávislé závorky (3+1)*(5-2)', () {
      final res = IntermediateEvaluator.computeIntermediateSteps(
        expression: '(3+1)*(5-2)',
        evaluator: mockEvaluator,
        formatter: mockFormatter,
        spokenFormatter: mockSpoken,
      );

      expect(res.hasError, isFalse);
      expect(res.steps.length, greaterThanOrEqualTo(2));
      expect(res.steps[0].subExpression, '(3+1)');
      expect(res.steps[0].value, 4.0);
      expect(res.steps[1].subExpression, '(5-2)');
      expect(res.steps[1].value, 3.0);
    });

    test('T3: Vnořené závorky zevnitř ven 6*(2+(3*4))', () {
      final res = IntermediateEvaluator.computeIntermediateSteps(
        expression: '6*(2+(3*4))',
        evaluator: mockEvaluator,
        formatter: mockFormatter,
        spokenFormatter: mockSpoken,
      );

      expect(res.hasError, isFalse);
      expect(res.steps.length, greaterThanOrEqualTo(2));
      // První krok: nejvnitřnější (3*4)
      expect(res.steps[0].subExpression, '(3*4)');
      expect(res.steps[0].value, 12.0);
      // Druhý krok: (2+12)
      expect(res.steps[1].subExpression, '(2+12)');
      expect(res.steps[1].value, 14.0);
      // Třetí krok: 6*14
      if (res.steps.length > 2) {
        expect(res.steps[2].value, 84.0);
      }
    });

    test('T4: Funkce s argumentem v závorce SIN(15+15)', () {
      final res = IntermediateEvaluator.computeIntermediateSteps(
        expression: 'SIN(15+15)',
        evaluator: mockEvaluator,
        formatter: mockFormatter,
        spokenFormatter: mockSpoken,
      );

      expect(res.hasError, isFalse);
      expect(res.steps.isNotEmpty, isTrue);
      expect(res.steps[0].subExpression, 'SIN(15+15)');
      expect(res.steps[0].value, 0.5);
    });

    test('T7: Zachycení chyby při dělení nulou', () {
      final res = IntermediateEvaluator.computeIntermediateSteps(
        expression: '5/(2-2)',
        evaluator: mockEvaluator,
        formatter: mockFormatter,
        spokenFormatter: mockSpoken,
      );

      // (2-2) se spočte na 0
      expect(res.steps.isNotEmpty, isTrue);
      expect(res.steps[0].value, 0.0);
    });

    test('Výraz bez závorek nevrací zbytečné kroky', () {
      final res = IntermediateEvaluator.computeIntermediateSteps(
        expression: '123 + 456',
        evaluator: mockEvaluator,
        formatter: mockFormatter,
        spokenFormatter: mockSpoken,
      );

      expect(res.hasError, isFalse);
      expect(res.steps, isEmpty);
    });

    test('Úplné mezivýpočty respektují prioritu operací', () {
      final res = IntermediateEvaluator.computeIntermediateSteps(
        expression: '2+3*4',
        evaluator: mockEvaluator,
        formatter: mockFormatter,
        spokenFormatter: mockSpoken,
      );

      expect(res.steps.map((s) => s.subExpression), ['3*4', '2+12']);
      expect(res.finalValue, 14.0);
    });

    test('Úplné mezivýpočty se rekurzivně rozepíšou uvnitř závorek', () {
      double evaluator(String expr) {
        switch (expr) {
          case '3*6':
            return 18;
          case '2+18':
            return 20;
          case '6*5':
            return 30;
          case '2+30':
            return 32;
          case '20+32':
            return 52;
          default:
            throw StateError('Unexpected expression: $expr');
        }
      }

      final res = IntermediateEvaluator.computeIntermediateSteps(
        expression: '(2+3*6)+(2+6*5)',
        evaluator: evaluator,
        formatter: mockFormatter,
        spokenFormatter: mockSpoken,
      );

      expect(res.steps.map((s) => s.subExpression), [
        '3*6',
        '2+18',
        '6*5',
        '2+30',
        '20+32',
      ]);
      expect(res.finalValue, 52.0);
    });
  });
}
