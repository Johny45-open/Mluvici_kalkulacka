# Implementační plán: Spolehlivé oznámení stisknutých tlačítek numerické klávesnice při aktivní čtečce obrazovky

## 1. Potvrzená příčina problému
- **Chybějící routování přes jednotný oznamovací kanál (`announceEvent`):** Metoda `append()` v `lib/calculator_screen.dart` volá pro hlasovou zpětnou vazbu přímo `speak(_getButtonName(value))`.
- **Ochrana v `speak()`:** Metoda `speak()` obsahuje explicitní guard `if (_isScreenReaderActive == true) return null;`, což znamená, že při aktivní čtečce je vlastní TTS výstup zcela umlčen (záměrně, aby nedocházelo ke kolizi s TalkBackem/NVDA).
- **Důsledek:** Při zapnuté čtečce se stisk tlačítka (např. číslice `7`) sice vizuálně a logicky provede (vloží se do výrazu), ale **žádné oznámení se nepředá čtečce**, protože `speak()` se ukončí a `announceEvent` není zavolán.

## 2. Všechny dotčené metody a jejich odpovědnost
1. **`append(String value, {bool silent = false})`**:
   - Odpovědnost: Vkládá hodnotu do výrazu na pozici kurzoru a zajišťuje hlasové potvrzení stisknutého tlačítka.
   - Úprava: Místo přímého volání `speak(_getButtonName(value))` musí využít jednotný oznamovací kanál (`announceEvent`), který správně rozliší stav čtečky (při vypnuté čtečce zavolá TTS, při zapnuté publikuje Semantics oznámení).
2. **`speak(String text, {bool force = false})`**:
   - Odpovědnost: Správa vlastního TTS enginu (pouze při vypnuté čtečce). Zůstává beze změny.
3. **`announceEvent(String message, {required SpeechCategory category, ...})`**:
   - Odpovědnost: Jednotný oznamovací bod (R-architektura). Při SR ON publikuje přes `_publishSemanticsAnnouncement` (pokud nejde o `valueChange`), při SR OFF spouští TTS.

## 3. Konkrétní návrh opravy
V metodě `append()` v souboru `lib/calculator_screen.dart`:

```dart
  void append(String value, {bool silent = false}) {
    _insertAtCursor(value);
    if (!silent) {
      unawaited(
        announceEvent(
          _getButtonName(value),
          category: SpeechCategory.actionConfirm,
        ),
      );
    }
  }
```

*Proč to řeší problém:*
Použití `announceEvent` s kategorií `SpeechCategory.actionConfirm` zajistí, že:
- Pokud je čtečka vypnutá (`SR OFF`), `announceEvent` deleguje požadavek na vlastní TTS (`_speakTts`), čímž je zachováno původní chování.
- Pokud je čtečka zapnutá (`SR ON`), `announceEvent` ignoruje `valueChange`, ale `actionConfirm` propustí a zavolá `_publishSemanticsAnnouncement()`, což odešle srozumitelný popisek tlačítka (např. "7" nebo "plus") skrze Semantics živou oblast / `SemanticsService`.

## 4. Přesný seznam souborů, které se mají změnit
1. `lib/calculator_screen.dart` (aktualizace metody `append`).
2. `test/speech_contract_test.dart` a případně `test/single_announcement_test.dart` (rozšíření testů o ověření Semantics oznámení stisknutých tlačítek při zapnuté čtečce).

## 5. Návrh testů
Do testovací suite přidat tyto testovací scenáře:
1. **TalkBack ON – stisk číslice 7:** Právě jedno Semantics oznámení s textem odpovídajícím tlačítku `7`, nulový ttsLog (žádné paralelní TTS).
2. **TalkBack ON – posloupnost `7`, `+`, `3`:** Každá akce vygeneruje právě jedno Semantics oznámení (`7`, `plus`, `3`).
3. **TalkBack OFF – stisk 7:** Právě jedno TTS volání v `ttsLog`, žádné Semantics publikování.
4. **Auto + detekce `true`:** Chování shodné s `SR ON`.
5. **Auto + `UNKNOWN` (nedoběhlá detekce):** Bezpečný režim bez duplicitního hlasu.
6. **Tlačítka DEL a C:** Správná a právě jedna hláška odpovídající akci.
7. **Fyzická klávesnice:** Respektování parametru `silent` a zábran duplicitním oznámením.
8. **Displej vs. tlačítko (Kontrola duplicity):** Ověření, že změna hodnoty v `EditableText` spolu s vnějším `liveRegion` nevytváří druhou automatickou hlášku kolidující s potvrzením stisku tlačítka.

## 6. Rizika duplicity a vedlejších regresí
- **Riziko duplicity (Tlačítko + Displej):** Pokud by displej (liveRegion) automaticky oznamoval každou změnu textu (např. vložení `7`) a současně tlačítko explicitně ohlásilo `7`, uživatel by slyšel "Sedm" dvakrát.
  - *Ochrana:* Využití `SpeechCategory.actionConfirm` pro stisk tlačítka a spoléhání na to, že změny obsahu displeje jsou buď kategorizovány jako `valueChange` (které jsou při SR ON ignorovány), nebo je zajištěno, že uživatel obdrží akční potvrzení stisku klávesy jako primární feedback a displej slouží pro orientaci při navigaci kurzorem.
- **Neznámý stav (UNKNOWN):** V režimu `auto` před dokončením asynchronní detekce čtečky nesmí dojít k spuštění TTS ani chybnému publikování (ošetřeno existujícími guardy).

## 7. Doporučené pořadí implementace
1. **Implementace změny v `lib/calculator_screen.dart`:** Změnit `speak(_getButtonName(value))` na `announceEvent(_getButtonName(value), category: SpeechCategory.actionConfirm)` uvnitř `append()`.
2. **Psaní regresních testů:** Přidat testy do `test/speech_contract_test.dart` pro ověření `announceEvent` kanálu při `SR ON` a `SR OFF`.
3. **Spuštění automatických testů:** Provést `flutter test` a ověřit, že veškerá existující i nová kontraktní ověření procházejí.
4. **Manuální validace:** Otestovat na reálném Android zařízení s aktivním TalkBackem (ověřit, že stisk číslice vysloví TalkBack právě jednou a srozumitelně).
