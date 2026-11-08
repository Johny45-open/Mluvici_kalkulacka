# Implementační plán opravy: Pokračování v zadávání výrazu po chybovém stavu

Tento dokument představuje podrobný implementační plán pro opravu chyby, kdy uživatel nemůže pokračovat v zadávání výrazu po stisknutí tlačítka `=` v případě, že předchozí výpočet skončil chybou.

---

### A. Potvrzená příčina
1. Při vyhodnocení chybného výrazu (např. neúplného výrazu `12+` nebo dělení nulou) v metodě `calculateResult()` zachytí blok `catch (e)` výjimku a provede:
   ```dart
   setState(() {
     _lastResult = 'Error';
     _hasResult = true;
     ...
   });
   ```
   Původní `display` přitom zůstává beze změny (obsahuje např. `12+`).
2. V metodě `_handleButtonPressed()` se pro jakýkoliv stisk tlačítka za stavu, kdy `_hasResult == true`, prověřuje podmínka:
   ```dart
   if (_hasResult) {
   ```
3. Tato podmínka nerozlišuje, zda se jedná o platný výsledek úspěšného výpočtu, nebo o chybový stav (`'Error'`).
4. V důsledku toho stisk číslice nebo operátoru po chybě spustí větev pro práci s výsledkem, která buď vymaže displej (`display = ''`), nebo jej nahradí za `ANS`, čímž uživatel ztratí rozpracovaný výraz na displeji a nemůže v něm pokračovat.

---

### B. Přesné soubory a funkce, kterých se oprava týká
- **Soubor:** `lib/calculator_screen.dart`
- **Funkce / Metoda:** `_handleButtonPressed(String label, {bool silent = false})` (začátek zpracování `if (_hasResult)`, cca řádek 10389)

---

### C. Doporučená minimální změna
Úprava podmínky v metodě `_handleButtonPressed()` tak, aby se logika pro práci s předchozím výsledkem (ANS / reset displeje) uplatnila pouze v případě, že jde o platný výsledek (nikoliv chybový stav `'Error'`):

**Původní stav:**
```dart
    if (_hasResult) {
      setState(() {
        if (['+', '-', '*', '/', '^', '%', 'EXP', 'x²', 'x³'].contains(label)) {
          ...
```

**Navrhovaná změna:**
```dart
    if (_hasResult && _lastResult != 'Error') {
      setState(() {
        if (['+', '-', '*', '/', '^', '%', 'EXP', 'x²', 'x³'].contains(label)) {
          ...
```

---

### D. Zdůvodnění, proč je změna bezpečná
- **Minimální rozsah zásahu:** Mění se pouze jedna podmínka guardu, která přesně cílí na oddělení chybového stavu od stavu úspěšného výsledku.
- **Zachování sémantiky úspěšných výsledků:** Pro všechny platné výsledky (kde `_lastResult != 'Error'`) zůstává chování zcela nedotčené (podpora operátorů s ANS, přímé psaní číslic atd.).
- **Zachování uživatelského vstupu:** Pokud nastane chyba, `display` na displeji zůstane zachován (např. `12+`), a uživatel může plynule pokračovat v zadávání (např. dopsáním `5` vznikne `12+5`).
- **Soulad s architekturou:** Respektuje jednotný stav displeje, správu kurzoru i přístupnostní vrstvu (NVDA / TalkBack).

---

### E. Konkrétní návrh regresních testů
Přidání nového testovacího scénáře do souboru `test/calc_error_classification_test.dart` (nebo jako samostatný test v testovací suite):

```dart
    testWidgets('pokracovani v zadavani po chybe (12+ -> Error -> 5 -> 17)', (tester) async {
      final state = await pumpApp(tester);
      
      // 1. Zadej výraz 12+
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('+'));
      await tester.pump();

      // 2. Stiskněte =
      await tester.tap(find.text('='));
      await tester.pump();

      // 3. Ověř, že stav je Error a display stále obsahuje 12+
      expect(state.getLastResultForTest(), 'Error');
      expect(state.getDisplayForTest(), '12+');

      // 4. Zadej číslici 5
      await tester.tap(find.text('5'));
      await tester.pump();

      // 5. Ověř, že display nyní obsahuje 12+5
      expect(state.getDisplayForTest(), '12+5');

      // 6. Opětovné stisknutí =
      await tester.tap(find.text('='));
      await tester.pump();

      // 7. Ověř výsledek 17
      expect(state.getLastResultForTest(), '17');
    });
```
*(Poznámka: Test využije existující test-hooky nebo odpovídající metody pro kontrolu stavu displeje a výsledku).*

---

### F. Rizika a možné vedlejší dopady
- **Riziko:** Velmi nízké.
- **Možné dopady:** Žádné negativní dopady na úspěšné výpočty ani na existující funkce nebuly identifikovány.

---

### G. Příkazy pro ověření opravy
Po případném schválení a implementaci lze ověření provést příkazem:
```bash
flutter test test/calc_error_classification_test.dart
```
Nebo spuštěním celé testovací sady:
```bash
flutter test
```

---

### H. Kritéria úspěšného dokončení
1. Všechny existující testy procházejí bez selhání.
2. Nový regresní test úspěšně ověří možnost pokračování v zadávání výrazu po chybě.
3. Chování odečítačů obrazovky (NVDA / TalkBack) zůstává plně funkční a konzistentní.

---

### Závěrečné doporučení
**Ano, doporučuji navrženou změnu implementovat.** Řeší hlášený problém čistým, minimálním a plně bezpečně ověřitelným způsobem.
