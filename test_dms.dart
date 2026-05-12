
import 'package:math_expressions/math_expressions.dart' as math_expr;

void main() {
  String expr = "SIN(12°30')";
  print("Testování výrazu: $expr");
  
  // Simulace logiky z _evaluateExpression
  const String PI_VAL = '3.14159265358979323846';
  String processed = expr.replaceAll(' ', '');
  
  // 2. DMS převod (simulace upravené verze)
  processed = processed.replaceAllMapped(RegExp(r'''(?:^|[\(\+\-\*\/\^])(-?\d+(?:\.\d+)?)°(?:(\d+(?:\.\d+)?)\')?(?:(\d+(?:\.\d+)?)\")?'''), (m) {
    double d = double.parse(m[1]!);
    double mn = m[2] != null ? double.parse(m[2]!) : 0.0;
    double sc = m[3] != null ? double.parse(m[3]!) : 0.0;
    double sign = d < 0 ? -1.0 : 1.0;
    String replacement = '${sign * (d.abs() + mn / 60.0 + sc / 3600.0)}';
    if (m[0]!.startsWith('(') || m[0]!.startsWith('+') || m[0]!.startsWith('-') || m[0]!.startsWith('*') || m[0]!.startsWith('/') || m[0]!.startsWith('^')) {
      return '${m[0]![0]}$replacement';
    }
    return replacement;
  });

  print("Po převodu DMS: $processed");

  // 4. Tokenizace (zjednodušená)
  processed = processed.replaceAll('SIN(', '#SIN#(');

  // 5. Expanze (předpoklad: DEG režim)
  processed = processed.replaceAllMapped(RegExp(r'#SIN#\((.*?)\)'), (m) => 'sin((${m[1]}*$PI_VAL/180))');

  print("Výraz pro math_expressions: $processed");

  final p = math_expr.ShuntingYardParser();
  final val = p.parse(processed).evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());

  print("Výsledek: $val");
  }
