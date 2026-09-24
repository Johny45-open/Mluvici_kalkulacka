# Plán: Stabilní 7×4 rastr hlavní klávesnice

## Kontext
- `AI_rules.txt` – žádný zbytečný `Semantics`, respekt `FocusNode/FocusScope`
- HEAD `lib/calculator_screen.dart:7315-7604` používá `Wrap` + `btnH=(54*scale).clamp(48*scale,80*scale)` – fixní výška, ale bez 7řádkového referenčního rastru a s rizikem reflow
- Maximální reálný počet tlačítek HEAD: `basic 23, scientific-num 24, scientific-func 27, statistics 25, electrician 23, unit 15, time 21, currency 15` → `ceil(27/4)=7` → referenční rastr `7×4=28` je **pouze geometrická kapacita**, ne požadavek na 28 skutečných tlačítek. Žádné falešné tlačítko se nepřidá. `git diff HEAD` prázdný, `git status` clean.

## Cíl
Počet tlačítek nesmí určovat výšku řádku ani způsobovat reflow. Uživatel má stabilní prostorovou orientaci při přepnutí režimu, resize a změně textScale.

## Minimální diff
```dart
static const int _kKeypadColumns = 4;
static const int _kKeypadReferenceRows = 7;
static const int _kKeypadCellCount = _kKeypadColumns * _kKeypadReferenceRows; // 28
// + refactor Widget _buildMainKeyboard()
```
`_responsiveScale()` zachovat, `buildButton()` neměnit pokud není nutné.

## Refactor _buildMainKeyboard()
- Zachovat `switch(_currentMode)` pro `btns` beze změny pořadí.
- `LayoutBuilder`:
```dart
final scale = _responsiveScale(ctx);
final double rowH = (54.0 * scale).clamp(48.0 * scale, 80.0 * scale).toDouble();
const spacing = 2.0;
final needH = _kKeypadReferenceRows * rowH + (_kKeypadReferenceRows - 1) * spacing + 4;
final needVScroll = constraints.maxHeight.isFinite && needH > constraints.maxHeight;
List<Widget> cells = List.generate(_kKeypadCellCount, (i) => i < btns.length
  ? SizedBox(height: rowH, child: buttonFor(btns[i]))
  : SizedBox(height: rowH, child: const ExcludeFocus(child: ExcludeSemantics(child: SizedBox.shrink()))));
List<Widget> rows = [];
for (int r = 0; r < _kKeypadReferenceRows; r++) {
  rows.add(Row(key: ValueKey('keypad_row_$r'), children: [
    for (int c = 0; c < 4; c++) ...[
      if (c > 0) const SizedBox(width: spacing),
      Expanded(child: cells[r * 4 + c]),
    ]
  ]));
  if (r < 6) rows.add(const SizedBox(height: spacing));
}
Widget grid = Column(key: const ValueKey('keypad_grid'), children: rows);
// FocusTraversalGroup přidat pouze pokud audit prokáže nezbytnost; jinak zachovat současný mechanismus
grid = Padding(padding: const EdgeInsets.all(2), child: grid);
return needVScroll ? SingleChildScrollView(child: grid) : grid; // struktura: SingleChildScrollView -> Padding -> keypad_grid
```
- 4 sloupce via `Expanded`, šířka buněk řízena `Expanded`, `btnW` uvnitř není potřeba.
- Poslední neúplný řádek: tlačítko zůstává vlevo (`col0`), zbytek placeholdery.
- Žádný `Wrap` pro hlavní keypad. `Scrollbar(thumbVisibility:true)` pouze pokud nekonfliktní – není povinný.
- Prázdné buňky: `ExcludeFocus + ExcludeSemantics + SizedBox.shrink()` – nefokusovatelné, mimo accessibility tree.

## Testy (test/keypad_spatial_stability_test.dart)
- T1: vždy 7 referenčních řádků × 4 buňky (keypad_grid → 7× Row), reálných tlačítek méně.
- T2: stejná `rowH` na stejném `Size`/`scale` – `Basic == Statistics == Unit == Time == Currency == Electrician == Scientific-num == Scientific-func` via `find.byKey(ValueKey('keypad_row_0'))`.
- T3: snapshot `expectedBtns` per režim + `row=index~/4, col=index%4`, index se po refactoru nemění.
- T4: na šířkách 360,412,600,1280 žádný `Wrap` descendant/ancestor keypad_grid, stále 4 sloupce, stejné index→row/col.
- T5: vysoký textScale (1.8-2.0) – žádný Wrap, bez výjimky, všechna tlačítka přítomna. Scroll test odděleně:
```dart
expect(find.ancestor(of: find.byKey(const ValueKey('keypad_grid')), matching: find.byType(SingleChildScrollView)), findsOneWidget); // needH>maxH
expect(find.ancestor(of: find.byKey(const ValueKey('keypad_grid')), matching: find.byType(SingleChildScrollView)), findsNothing); // vejde se
```
- T6: unitConversion 15 tlačítek → 13 placeholderů – počet `Semantics(button:true)` scoped na keypad_grid =15, placeholdery 13× ExcludeSemantics/ExcludeFocus, ověřeno přes `SemanticsTester` a absence v accessibility tree, nejsou focusovatelné.

## Validace
```
dart format .
flutter analyze
flutter test
```
NVDA/TalkBack reálné čtení pouze manuálně – widget test ověřuje pouze `ExcludeSemantics`/`ExcludeFocus`.

## Manuální ověření
Basic, Statistics, Time, UnitConversion, Currency, Electrician, Scientific-num, Scientific-func – prostorové pořadí, velikost, Tab fokus, TalkBack/NVDA.
