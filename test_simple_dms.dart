import 'package:math_expressions/math_expressions.dart' as math_expr;

void main() {
  String expr = "36°25'";
  
  // 1. ZÁKLADNÍ PŘÍPRAVA
  String processed = expr.replaceAll(',', '.');
  processed = processed.replaceAll('°→\'', '').replaceAll('\'→°', '');
  print("Po přípravě: $processed");

  // 2. DMS A SPECIÁLNÍ ZNAKY
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
  print("Po DMS: $processed");

  // 6. BALANCOVÁNÍ ZÁVOREK (zjednodušeno)
  int openCount = '('.allMatches(processed).length;
  int closeCount = ')'.allMatches(processed).length;
  if (openCount > closeCount) {
    processed += ')' * (openCount - closeCount);
  }
  print("Konečný výraz: $processed");

  try {
    final p = math_expr.ShuntingYardParser();
    final val = p.parse(processed).evaluate(math_expr.EvaluationType.REAL, math_expr.ContextModel());
    print("Výsledek: $val");
  } catch (e) {
    print("Chyba při parsování: $e");
  }
}
