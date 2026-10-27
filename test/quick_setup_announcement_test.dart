import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';

/// Harness drží log oznámení a poslední draft z `onApply`.
class Harness {
  final List<String> announceLog = [];
  QuickSetupDraft? appliedDraft;
}

/// Regresní testy hlasových oznámení změn v QuickSetupDialog.
///
/// Každá změna nastavení musí oznámit NÁZEV položky i NOVOU HODNOTU
/// („Typ přístupnosti: Slabozraký"), právě jednou, ve CS i EN.
/// Ověřuje se přesný text předaný do `announce`, ne jen vizuální stav.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Harness> pumpDialog(WidgetTester tester, {required bool czech}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final h = Harness();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => QuickSetupDialog(
                initialDraft: QuickSetupDraft.defaults(),
                availableVoices: Future.value(const <Map<String, String>>[]),
                onApply: (d) => h.appliedDraft = d,
                onCancel: () {},
                announce: h.announceLog.add,
                tr: czech ? (cs, _) => cs : (_, en) => en,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return h;
  }

  /// Klepne na segment v rámci daného SegmentedButton (popisky
  /// 'Standard'/'Auto' se v dialogu opakují u více prvků).
  Future<void> tapSegment(
    WidgetTester tester,
    Finder segmentedButton,
    String label,
  ) async {
    final segment = find.descendant(
      of: segmentedButton,
      matching: find.text(label),
    );
    expect(segment, findsOneWidget, reason: 'segment "$label" nenalezen');
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  Finder byA11yType() => find.byType(SegmentedButton<AccessibilityType>);
  Finder byReaderMode() => find.byType(SegmentedButton<ScreenReaderMode>);
  Finder byDialogSize() => find.byType(SegmentedButton<DialogSize>);
  Finder byInverseFormat() => find.byType(SegmentedButton<int?>);
  Finder byResultDisplay() => find.byType(SegmentedButton<ResultDisplayMode>);

  group('Oznámení – čeština', () {
    testWidgets('Typ přístupnosti oznamuje konkrétní hodnotu', (tester) async {
      final h = await pumpDialog(tester, czech: true);
      // Výchozí: Standardní (nelze znovu vybrat -> začínáme jinou volbou).
      await tapSegment(tester, byA11yType(), 'Nevidomý');
      expect(h.announceLog, ['Typ přístupnosti: Nevidomý']);
      await tapSegment(tester, byA11yType(), 'Slabozraký');
      expect(h.announceLog, [
        'Typ přístupnosti: Nevidomý',
        'Typ přístupnosti: Slabozraký',
      ]);
      await tapSegment(tester, byA11yType(), 'Standardní');
      expect(h.announceLog, [
        'Typ přístupnosti: Nevidomý',
        'Typ přístupnosti: Slabozraký',
        'Typ přístupnosti: Standardní',
      ]);
    });

    testWidgets('Režim čtečky oznamuje Automaticky/Zapnuto/Vypnuto', (
      tester,
    ) async {
      final h = await pumpDialog(tester, czech: true);
      // Výchozí: Auto.
      await tapSegment(tester, byReaderMode(), 'Zapnuto');
      expect(h.announceLog, ['Režim čtečky: Zapnuto']);
      await tapSegment(tester, byReaderMode(), 'Vypnuto');
      expect(h.announceLog, ['Režim čtečky: Zapnuto', 'Režim čtečky: Vypnuto']);
      // UI popisek zůstává 'Auto', oznámení používá přirozené 'Automaticky'.
      await tapSegment(tester, byReaderMode(), 'Auto');
      expect(h.announceLog, [
        'Režim čtečky: Zapnuto',
        'Režim čtečky: Vypnuto',
        'Režim čtečky: Automaticky',
      ]);
    });

    testWidgets('Velikost dialogů oznamuje Kompaktní/Široký/Celý', (
      tester,
    ) async {
      final h = await pumpDialog(tester, czech: true);
      // Výchozí: Kompaktní.
      await tapSegment(tester, byDialogSize(), 'Široký');
      expect(h.announceLog, ['Velikost dialogů: Široký']);
      await tapSegment(tester, byDialogSize(), 'Celý');
      expect(h.announceLog, [
        'Velikost dialogů: Široký',
        'Velikost dialogů: Celý',
      ]);
      await tapSegment(tester, byDialogSize(), 'Kompaktní');
      expect(h.announceLog, [
        'Velikost dialogů: Široký',
        'Velikost dialogů: Celý',
        'Velikost dialogů: Kompaktní',
      ]);
    });

    testWidgets('Formát inverzních funkcí oznamuje Automaticky/DMS/Desetinný', (
      tester,
    ) async {
      final h = await pumpDialog(tester, czech: true);
      // Výchozí: null (Auto).
      await tapSegment(tester, byInverseFormat(), 'DMS');
      expect(h.announceLog, ['Formát inverzních funkcí: DMS']);
      await tapSegment(tester, byInverseFormat(), 'Desetinný');
      expect(h.announceLog, [
        'Formát inverzních funkcí: DMS',
        'Formát inverzních funkcí: Desetinný',
      ]);
      // Návrat na Auto == null -> přirozené 'Automaticky'.
      await tapSegment(tester, byInverseFormat(), 'Auto');
      expect(h.announceLog, [
        'Formát inverzních funkcí: DMS',
        'Formát inverzních funkcí: Desetinný',
        'Formát inverzních funkcí: Automaticky',
      ]);
    });

    testWidgets('Zobrazení výsledku oznamuje Segment/Text/Automaticky', (
      tester,
    ) async {
      final h = await pumpDialog(tester, czech: true);
      // Výchozí: Segment.
      await tapSegment(tester, byResultDisplay(), 'Text');
      expect(h.announceLog, ['Zobrazení výsledku: Text']);
      await tapSegment(tester, byResultDisplay(), 'Auto');
      expect(h.announceLog, [
        'Zobrazení výsledku: Text',
        'Zobrazení výsledku: Automaticky',
      ]);
      await tapSegment(tester, byResultDisplay(), 'Segment');
      expect(h.announceLog, [
        'Zobrazení výsledku: Text',
        'Zobrazení výsledku: Automaticky',
        'Zobrazení výsledku: Segment',
      ]);
    });
  });

  group('Oznámení – angličtina', () {
    testWidgets('Accessibility type oznamuje hodnotu', (tester) async {
      final h = await pumpDialog(tester, czech: false);
      await tapSegment(tester, byA11yType(), 'Blind');
      expect(h.announceLog, ['Accessibility type: Blind']);
      await tapSegment(tester, byA11yType(), 'Low vision');
      expect(h.announceLog, [
        'Accessibility type: Blind',
        'Accessibility type: Low vision',
      ]);
      await tapSegment(tester, byA11yType(), 'Standard');
      expect(h.announceLog, [
        'Accessibility type: Blind',
        'Accessibility type: Low vision',
        'Accessibility type: Standard',
      ]);
    });

    testWidgets('Screen reader mode oznamuje Auto/On/Off', (tester) async {
      final h = await pumpDialog(tester, czech: false);
      await tapSegment(tester, byReaderMode(), 'On');
      expect(h.announceLog, ['Screen reader mode: On']);
      await tapSegment(tester, byReaderMode(), 'Off');
      expect(h.announceLog, [
        'Screen reader mode: On',
        'Screen reader mode: Off',
      ]);
      await tapSegment(tester, byReaderMode(), 'Auto');
      expect(h.announceLog, [
        'Screen reader mode: On',
        'Screen reader mode: Off',
        'Screen reader mode: Auto',
      ]);
    });

    testWidgets('Dialog size oznamuje Compact/Wide/Full', (tester) async {
      final h = await pumpDialog(tester, czech: false);
      await tapSegment(tester, byDialogSize(), 'Wide');
      expect(h.announceLog, ['Dialog size: Wide']);
      await tapSegment(tester, byDialogSize(), 'Full');
      expect(h.announceLog, ['Dialog size: Wide', 'Dialog size: Full']);
      await tapSegment(tester, byDialogSize(), 'Compact');
      expect(h.announceLog, [
        'Dialog size: Wide',
        'Dialog size: Full',
        'Dialog size: Compact',
      ]);
    });

    testWidgets('Inverse format oznamuje Auto/DMS/Decimal', (tester) async {
      final h = await pumpDialog(tester, czech: false);
      await tapSegment(tester, byInverseFormat(), 'DMS');
      expect(h.announceLog, ['Inverse format: DMS']);
      await tapSegment(tester, byInverseFormat(), 'Decimal');
      expect(h.announceLog, ['Inverse format: DMS', 'Inverse format: Decimal']);
      await tapSegment(tester, byInverseFormat(), 'Auto');
      expect(h.announceLog, [
        'Inverse format: DMS',
        'Inverse format: Decimal',
        'Inverse format: Auto',
      ]);
    });

    testWidgets('Result display oznamuje Segment/Text/Auto', (tester) async {
      final h = await pumpDialog(tester, czech: false);
      await tapSegment(tester, byResultDisplay(), 'Text');
      expect(h.announceLog, ['Result display: Text']);
      await tapSegment(tester, byResultDisplay(), 'Auto');
      expect(h.announceLog, ['Result display: Text', 'Result display: Auto']);
      await tapSegment(tester, byResultDisplay(), 'Segment');
      expect(h.announceLog, [
        'Result display: Text',
        'Result display: Auto',
        'Result display: Segment',
      ]);
    });
  });

  group('Změna nastavení zůstává beze změny', () {
    testWidgets('Apply předá změněné hodnoty v draftu', (tester) async {
      final h = await pumpDialog(tester, czech: true);
      await tapSegment(tester, byA11yType(), 'Slabozraký');
      await tapSegment(tester, byDialogSize(), 'Celý');
      await tapSegment(tester, byInverseFormat(), 'DMS');
      await tapSegment(tester, byResultDisplay(), 'Text');
      await tester.tap(find.text('Použít nastavení'));
      await tester.pumpAndSettle();
      final d = h.appliedDraft;
      expect(d, isNotNull);
      expect(d!.settings.accessibilityType, AccessibilityType.visuallyImpaired);
      expect(d.settings.dialogSize, DialogSize.fullscreen);
      expect(d.settings.inverseFormatPreference, 0);
      expect(d.resultDisplayMode, ResultDisplayMode.text);
    });

    testWidgets('Návrat formátu inverzních funkcí na Auto == null', (
      tester,
    ) async {
      final h = await pumpDialog(tester, czech: true);
      await tapSegment(tester, byInverseFormat(), 'DMS');
      await tapSegment(tester, byInverseFormat(), 'Auto');
      await tester.tap(find.text('Použít nastavení'));
      await tester.pumpAndSettle();
      expect(h.appliedDraft!.settings.inverseFormatPreference, isNull);
    });
  });
}
