import 'package:math_expressions/math_expressions.dart' as math_expr;

void main() {
  String processed = "36.416666666666664";
  
  try {
    final p = math_expr.ShuntingYardParser();
    final val = p.parse(processed).evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());
    print("Výsledek: $val");
  } catch (e) {
    print("Chyba při parsování: $e");
  }
}
