import 'package:flutter/foundation.dart';

/// Reprezentace jednoho vyhodnoceného kroku v mezivýpočtech.
@immutable
class IntermediateStep {
  /// Pořadové číslo kroku (1-based).
  final int stepIndex;

  /// Původní podvýraz, např. "2+2" nebo "(2+2)".
  final String subExpression;

  /// Numerická hodnota výsledku podvýrazu.
  final double value;

  /// Zformátovaný text výsledku, např. "4".
  final String formattedValue;

  /// Plný textový zápis, např. "2 + 2 = 4" nebo "(2 + 2) = 4".
  final String stepDescription;

  /// Hlasový přepis pro TalkBack / NVDA / TTS.
  final String spokenText;

  const IntermediateStep({
    required this.stepIndex,
    required this.subExpression,
    required this.value,
    required this.formattedValue,
    required this.stepDescription,
    required this.spokenText,
  });

  @override
  String toString() => '$stepIndex. $stepDescription';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntermediateStep &&
          runtimeType == other.runtimeType &&
          stepIndex == other.stepIndex &&
          subExpression == other.subExpression &&
          value == other.value &&
          formattedValue == other.formattedValue &&
          stepDescription == other.stepDescription &&
          spokenText == other.spokenText;

  @override
  int get hashCode => Object.hash(
    stepIndex,
    subExpression,
    value,
    formattedValue,
    stepDescription,
    spokenText,
  );
}

/// Výsledek dekompozice a vyhodnocení mezivýpočtů.
@immutable
class IntermediateEvaluationResult {
  /// Původní vstupní výraz.
  final String originalExpression;

  /// Seznam vyhodnocených kroků od nejhlubších závorek zevnitř ven.
  final List<IntermediateStep> steps;

  /// Celkový konečný výsledek (pokud byl výraz kompletně spočten).
  final double? finalValue;

  /// Formátovaný konečný výsledek.
  final String? finalFormattedValue;

  /// Případná chyba při vyhodnocování podvýrazu.
  final Object? error;

  /// Textová zpráva chyby, pokud nastala.
  final String? errorMessage;

  const IntermediateEvaluationResult({
    required this.originalExpression,
    required this.steps,
    this.finalValue,
    this.finalFormattedValue,
    this.error,
    this.errorMessage,
  });

  bool get hasSteps => steps.isNotEmpty;
  bool get hasError => error != null;
}

/// Nalezený rozsah závorky pro řazení dle hloubky zevnitř ven.
class _ParenSpan {
  final int openIdx;
  final int closeIdx;
  final int depth;
  final String prefix; // Např. "SIN", "LOG", "√" nebo prázdný řetězec

  _ParenSpan({
    required this.openIdx,
    required this.closeIdx,
    required this.depth,
    this.prefix = '',
  });

  int get length => closeIdx - openIdx + 1 + prefix.length;
  int get fullStart => openIdx - prefix.length;
}

/// Čistá logika pro extrakci podvýrazů a postupné vyhodnocování zevnitř ven.
///
/// Nepoužívá vlastní matematický parser; spoléhá na předanou funkci [evaluator],
/// která je přímo napojena na stávající `_evaluateExpression` kalkulačky.
class IntermediateEvaluator {
  /// Vyhodnotí mezivýpočty pro zadaný výraz.
  ///
  /// [expression] - zkoumaný matematický výraz (např. "6*(2+(3*4))")
  /// [evaluator] - funkce pro výpočet hodnoty výrazu v kontextu kalkulačky
  /// [formatter] - funkce pro formátování čísla do textu (např. _formatNumber)
  /// [spokenFormatter] - funkce pro formátování čísla do hlasu
  /// [sentenceSpoken] - volitelný konvertor matematického zápisu na českou řeč
  static IntermediateEvaluationResult computeIntermediateSteps({
    required String expression,
    required double Function(String expr) evaluator,
    required String Function(double val) formatter,
    required String Function(double val) spokenFormatter,
    String Function(String mathExpr)? sentenceSpoken,
  }) {
    final cleanExpr = expression.trim();
    if (cleanExpr.isEmpty) {
      return IntermediateEvaluationResult(
        originalExpression: expression,
        steps: const [],
      );
    }

    // Periodická čísla používají závorky jako součást zápisu (např. 3.(3)),
    // nikoli jako samostatný výpočetní podvýraz. Textová dekompozice by je
    // rozbila, proto je v tomto případě bezpečně přeskočíme.
    if (RegExp(r'\d+[\.,]\(\d+\)').hasMatch(cleanExpr)) {
      return IntermediateEvaluationResult(
        originalExpression: expression,
        steps: const [],
      );
    }

    final steps = <IntermediateStep>[];
    String currentWorkingExpr = cleanExpr;
    int stepNumber = 1;

    try {
      // Cyklicky vyhodnocujeme nejvnitřnější závorkové podvýrazy
      while (true) {
        final span = _findInnermostParenSpan(currentWorkingExpr);
        if (span == null) {
          break;
        }

        // Vnitřní text uvnitř závorek
        final innerContent = currentWorkingExpr
            .substring(span.openIdx + 1, span.closeIdx)
            .trim();

        // Celý podvýraz včetně případného funkčního prefixu, např. SIN(30+15) nebo (2+2)
        final fullSubExpr = currentWorkingExpr.substring(
          span.fullStart,
          span.closeIdx + 1,
        );

        // Pokud je v závorce jen samotné číslo (např. "(4)" nebo "(-5)"), není to samostatný výpočetní krok
        final isSimpleNumber = RegExp(
          r'^-?\d+(?:[\.,]\d+)?$',
        ).hasMatch(innerContent);
        if (isSimpleNumber && span.prefix.isEmpty) {
          // Nahradíme závorky čistou hodnotou bez závorek pro zjednodušení dalšího zpracování,
          // ale nepřidáváme zbytečný krok "4 = 4".
          currentWorkingExpr =
              currentWorkingExpr.substring(0, span.openIdx) +
              innerContent +
              currentWorkingExpr.substring(span.closeIdx + 1);
          continue;
        }

        // Vyhodnotíme podvýraz
        final val = evaluator(fullSubExpr);
        final formattedVal = formatter(val);
        final spokenVal = spokenFormatter(val);

        // Popis kroku
        final description = '$fullSubExpr = $formattedVal';
        final spoken = sentenceSpoken != null
            ? sentenceSpoken('$fullSubExpr = $spokenVal')
            : '$fullSubExpr rovná se $spokenVal';

        steps.add(
          IntermediateStep(
            stepIndex: stepNumber++,
            subExpression: fullSubExpr,
            value: val,
            formattedValue: formattedVal,
            stepDescription: description,
            spokenText: spoken,
          ),
        );

        // Nahradíme tento podvýraz jeho numerickou hodnotou v pracovním výrazu
        // Použijeme závorku kolem čísla, aby nedošlo k syntaktické kolizi se znaménky (+- nebo ^)
        // Pracovní výraz musí zůstat v kanonickém syntaktickém tvaru. Formát
        // pro UI může používat čárku, mezery nebo periodický zápis.
        final canonicalValue = _canonicalNumber(val);
        final replacement = val < 0 ? '($canonicalValue)' : canonicalValue;
        currentWorkingExpr =
            currentWorkingExpr.substring(0, span.fullStart) +
            replacement +
            currentWorkingExpr.substring(span.closeIdx + 1);
      }

      // Pokud proběhly nějaké mezikroky a zbyl finální výraz, který ještě nebyl jedním celým krokem:
      double? finalVal;
      String? finalFormatted;
      if (steps.isNotEmpty) {
        // Zkusíme vyhodnotit výsledný redukovaný výraz
        try {
          finalVal = evaluator(currentWorkingExpr);
          finalFormatted = formatter(finalVal);

          // Pokud redukovaný výraz nebyl jen prosté číslo a liší se od posledního mezikroku
          final isJustNumber = RegExp(
            r'^\(?\s*-?\d+(?:[\.,]\d+)?\s*\)?$',
          ).hasMatch(currentWorkingExpr.trim());
          if (!isJustNumber &&
              steps.last.stepDescription !=
                  '$currentWorkingExpr = $finalFormatted') {
            final spokenVal = spokenFormatter(finalVal);
            final desc = '$currentWorkingExpr = $finalFormatted';
            final spoken = sentenceSpoken != null
                ? sentenceSpoken('$currentWorkingExpr = $spokenVal')
                : '$currentWorkingExpr rovná se $spokenVal';

            steps.add(
              IntermediateStep(
                stepIndex: stepNumber++,
                subExpression: currentWorkingExpr,
                value: finalVal,
                formattedValue: finalFormatted,
                stepDescription: desc,
                spokenText: spoken,
              ),
            );
          }
        } catch (_) {
          // Pokud finální redukovaný tvar selže, nevadí, kroky již máme
        }
      }

      return IntermediateEvaluationResult(
        originalExpression: expression,
        steps: steps,
        finalValue: finalVal,
        finalFormattedValue: finalFormatted,
      );
    } catch (e) {
      return IntermediateEvaluationResult(
        originalExpression: expression,
        steps: steps,
        error: e,
        errorMessage: e.toString(),
      );
    }
  }

  static String _canonicalNumber(double value) {
    if (value.isFinite && value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Najde nejvnitřnější rozsah závorek s největší hloubkou (zleva doprava).
  static _ParenSpan? _findInnermostParenSpan(String expr) {
    int maxDepth = 0;
    int currentDepth = 0;
    int bestOpen = -1;
    int bestClose = -1;

    // První průchod: najdeme nejvyšší hloubku
    for (int i = 0; i < expr.length; i++) {
      if (expr[i] == '(') {
        currentDepth++;
        if (currentDepth > maxDepth) {
          maxDepth = currentDepth;
        }
      } else if (expr[i] == ')') {
        currentDepth--;
      }
    }

    if (maxDepth == 0) {
      return null; // Žádné závorky ve výrazu nejsou
    }

    // Druhý průchod: najdeme první závorku na této maximální hloubce
    currentDepth = 0;
    for (int i = 0; i < expr.length; i++) {
      if (expr[i] == '(') {
        currentDepth++;
        if (currentDepth == maxDepth && bestOpen == -1) {
          bestOpen = i;
        }
      } else if (expr[i] == ')') {
        if (currentDepth == maxDepth && bestOpen != -1) {
          bestClose = i;
          break;
        }
        currentDepth--;
      }
    }

    if (bestOpen == -1 || bestClose == -1) return null;

    // Zkontrolujeme, zda před otevírací závorkou není název funkce (např. SIN, COS, TAN, LOG, LN, √, ∛)
    String prefix = '';
    int p = bestOpen - 1;
    while (p >= 0 && RegExp(r'[A-Za-z0-9_√∛]').hasMatch(expr[p])) {
      p--;
    }
    if (p < bestOpen - 1) {
      prefix = expr.substring(p + 1, bestOpen);
    }

    return _ParenSpan(
      openIdx: bestOpen,
      closeIdx: bestClose,
      depth: maxDepth,
      prefix: prefix,
    );
  }
}
