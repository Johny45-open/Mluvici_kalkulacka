# Implementační plán: Vylepšení prvního spuštění Mluvící kalkulačky

Tento plán popisuje kroky k implementaci vylepšení prvního spuštění (onboarding) Mluvící kalkulačky ve Flutteru, při plném dodržení pravidel přístupnosti (`AI_rules.txt`) a požadavků zadání.

## 1. Cíle úprav
1. **Odlišení prvního spuštění od běžného nastavení v `QuickSetupDialog`**:
   - Při `isFirstRun == true` zobrazit úvodní text (CZ/EN), předvolby (Standardní, Nevidomý, Slabozraký) a pokročilé volby umístit do sbalené rozbalitelné sekce (`ExpansionTile`).
   - Při `isFirstRun == false` zachovat kompletní formulář jako doposud.
   - Odstranit `autofocus: true` z tlačítka „Použít nastavení“, aby fokus po otevření dialogu nepadal rovnou na akci uložení.
2. **Zpřesnění akcí tlačítek (`Storno` vs `Přeskočit nastavení`)**:
   - Při `isFirstRun == true` změnit text tlačítka na „Přeskočit nastavení“ / „Skip setup“.
   - Při přeskočení uložit `markQuickSetupSeen(prefs)`, nezapisovat rozpracovaný draft do konfigurace, nevynucovat další dialogy.
   - Při chybě validace či uložení neoznačovat první spuštění za dokončené a informovat uživatele.
3. **Spolehlivější detekce prvního spuštění v `config_store.dart`**:
   - V `hasPersistedUserConfiguration()` a `isQuickSetupFirstRun()` ověřovat platnost struktury uložených profilů a existenci aktivního profilu namísto pouhé přítomnosti klíčů.
4. **Ošetření chyb spouštění v `calculator_screen.dart`**:
   - Posunout nastavení `_quickSetupShown = true` až na moment úspěšného zobrazení dialogu, což umožní bezpečné opakování pokusu při dočasné chybě.
5. **Rozšíření testů**:
   - Přidat testy pokrývající 10 specifikovaných scénářů (nová instalace, migrace, poškozená data, storno/přeskočení, fokus a sémantika, chybové stavy).

---

## 2. Plánované kroky implementace

### Krok 1: Úprava `config_store.dart` (Detekce a migrace)
- Zpřesnit `hasPersistedUserConfiguration()` tak, aby dekódoval a ověřil formát `accessibility_profiles_v2` a platnost aktivního profilu.
- Zajistit robustní ošetření chyb (pokud je JSON poškozený, nepovažovat za platnou konfiguraci).

### Krok 2: Úprava `QuickSetupDialog` (`lib/dialogs/quick_setup_dialog.dart`)
- Přidat úvodní text (v češtině i angličtině) viditelný pouze při `isFirstRun == true`.
- Pokročilá nastavení (hlasy, rychlost, hlasitost, písmo, zoom, displeje, úhly, výsledky, výchozí režim, téma) zabalit do přístupného `ExpansionTile` („Pokročilá nastavení“ / „Advanced settings“), který je ve výchozím stavu sbalený.
- Odstranit `autofocus: true` z tlačítka „Použít nastavení“.
- Podle `isFirstRun` dynamicky volit popisek tlačítka storno („Přeskočit nastavení“ / „Skip setup“ vs „Storno“ / „Cancel“).

### Krok 3: Úprava `calculator_screen.dart` (Správa životního cyklu onboardingu)
- Upravit `_maybeShowQuickSetup()` tak, aby `_quickSetupShown` nastavoval až při úspěšném zobrazení dialogu.
- Zajistit, že případné dočasné selhání načtení SharedPreferences nezablokuje pokus natrvalo v aktuálním běhu.

### Krok 4: Rozšíření testů (`test/quick_setup_test.dart`)
- Přidat unit/widget testy pro:
  1. Poškozenou nebo neúplnou konfiguraci (nedetekuje se jako validní).
  2. První spuštění s úvodním textem, sbalenou rozbalitelnou sekcí a tlačítkem Přeskočit.
  3. Fokus a chybějící autofocus na tlačítku uložení.
  4. Chybové stavy uložení.

### Krok 5: Ověření a validace
- Spustit `dart format`, `flutter analyze` a `flutter test`.
