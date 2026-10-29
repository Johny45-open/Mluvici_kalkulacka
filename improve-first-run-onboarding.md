# Implementační plán: Vylepšení prvního spuštění Mluvící kalkulačky (Aktualizováno podle zpětné vazby)

## 1. Cíl a přehled změn
Cílem je zjednodušit první spuštění (onboarding) Mluvící kalkulačky, zpřehlednit výběr předvoleb přístupnosti, skrýt pokročilá nastavení do sbalitelné sekce při prvním spuštění, zajistit bezpečný počáteční fokus (na první předvolbu namísto tlačítka Uložit), ošetřit chybovou odolnost detekce starších profilů, zabránit souběžnému otevírání duplicitních dialogů s omezeným opakováním a dodržet všechna pravidla z `AI_rules.txt`.

---

## 2. Klíčové soubory k úpravě
1. `lib/config_store.dart` – Zpřesnění `hasPersistedUserConfiguration()` a `isQuickSetupFirstRun()` s kompletní validací JSON struktury profilů a `activeProfileId`. Aktualizace volání a testů.
2. `lib/dialogs/quick_setup_dialog.dart` – Využití existujícího parametru `isFirstRun`:
   - Zobrazení stručného úvodu (CZ/EN) při `isFirstRun == true`.
   - Umístění pokročilých nastavení do sbalitelné sekce (`ExpansionTile` s `initiallyExpanded: false`).
   - Dynamické popisky tlačítek (`Přeskočit nastavení` / `Skip setup` při prvním spuštění vs. `Storno` / `Cancel` při běžném ručním nastavení).
   - Nastavení počátečního fokusu na první předvolbu (např. Standardní preset) pomocí explicitního `FocusNode` / `autofocus`, aby fokus nepadal na tlačítko Uložit.
3. `lib/calculator_screen.dart` – Zavedení `_quickSetupInProgress` pro prevenci duplicitních dialogů, omezené retry (max 1 pokus) při dočasné chybě inicializace, oddělení stavu pokusu od úspěšného zobrazení a zamezení překrývání hlasového oznámení s úvodní hláškou.
4. `test/quick_setup_test.dart` & `test/quick_setup_announcement_test.dart` – Doplnění testů pro všech 10 požadovaných scénářů (nová instalace, migrace validní/poškozené konfigurace, rozbalitelná sekce, počáteční fokus, popisy tlačítek, selhání uložení, storno bez změn, prevence duplicit, zamezení překrývání TTS).

---

## 3. Podrobný návrh změn

### A. Konfigurace a migrace (`lib/config_store.dart`)
- **Robustní `hasPersistedUserConfiguration`**:
  - Kontrola, zda existují klíče `accessibility_profiles_v2`, `activeProfileId` a `modeQuestionAsked == true`.
  - Přečtení `accessibility_profiles_v2` (string) a pokus o `jsonDecode`.
  - Ověření, že výsledek je `List`, obsahuje alespoň jeden prvek s platnou strukturou profilu (`id`, `name`, `settings`).
  - Ověření, že `activeProfileId` odpovídá ID některého z profilů v seznamu.
  - Pokud je JSON neplatný, prázdný nebo `activeProfileId` nesouhlasí, `hasPersistedUserConfiguration` vrátí `false` (onboarding se spustí, aniž by se přepsala data).

### B. QuickSetupDialog (`lib/dialogs/quick_setup_dialog.dart`)
- Využití existujícího parametru `isFirstRun`.
- **UI pro `isFirstRun == true`**:
  - Úvodní text: *„Vítejte v Ml. kalkulačce. Zde si můžete vybrat vhodnou předvolbu přístupnosti. Ostatní nastavení můžete upravit v rozbalitelné sekci nebo kdykoliv později v menu.“* / *„Welcome to Talking Calculator. Choose an accessibility preset. You can adjust settings in the expandable section or anytime later in the menu.“*
  - Výběr předvolby (Standardní, Nevidomý, Slabozraký) na předním místě.
  - Pokročilá nastavení uvnitř `ExpansionTile` (ve výchozím stavu sbalená).
  - Tlačítko Storno/Přeskočit: popisek se dynamicky mění na „Přeskočit nastavení“ (`isFirstRun`) vs. „Storno` (běžné nastavení).
- **Počáteční fokus**:
  - Odstranit `autofocus: true` z `FilledButton` („Použít nastavení“).
  - Přidat `autofocus: true` nebo explicitní `FocusNode` na prvek na začátku dialogu (např. na první segment předvolby nebo úvodní text), aby klávesnice a čtečka začínaly na začátku průvodce.

### C. Řízení spouštění v CalculatorScreen (`lib/calculator_screen.dart`)
- **Prevence duplicit a retry**:
  - Přidat `bool _quickSetupInProgress = false;`.
  - V `_maybeShowQuickSetup()`: zkontrolovat `_quickSetupShown || _quickSetupInProgress || !mounted`.
  - Nastavit `_quickSetupInProgress = true`. Při výjimce (např. selhání SharedPreferences) povolit maximálně 1 opakovaný pokus s krátkou prodlevou (nebo ukončit bez permanentního zablokování, pokud nebylo zobrazeno).
- **Zamezení překrývání TTS**:
  - Počkat na dokončení `_waitForTtsReady` a úvodního uvítání před zobrazením onboardingu, aby nedošlo k duplicitní nebo překrývající se řeči.

---

## 4. Testovací scénáře (10 bodů)
1. Nová instalace zobrazí onboarding právě jednou.
2. Platná starší instalace projde migrací bez onboardingu.
3. Poškozená nebo neúplná uložená konfigurace se nedetekuje jako validní.
4. Změna předvolby v draftu nic nezapisuje, dokud uživatel nepotvrdí použití.
5. První spuštění zobrazuje úvodní text, rozbalitelnou sekci a správně pojmenované akce („Přeskočit nastavení“).
6. Akce přeskočení označí onboarding za viděný, ale nemění konfiguraci.
7. Ruční nastavení zůstává kompletní (bez rozbalovací sekce) a zachovává své chování.
8. Selhání uložení neoznačí nastavení za úspěšně dokončené a informuje uživatele.
9. Dočasné selhání inicializace nevede k trvalému vynechání ani k dvojitému otevření dialogu.
10. Fokus a sémantika úvodního dialogu začínají na předvolbě/začátku a nedochází k překrývání řeči s uvítáním.

---

## 5. Ruční ověření (NVDA / TalkBack)
- **NVDA (Windows)**: Otevřít aplikaci při nové instalaci → fokus by měl padnout na předvolbu/začátek dialogu (nikoliv na tlačítko Uložit) → šipkami projít úvod a předvolby → rozbalit pokročilá nastavení pomocí mezerníku/Enteru → ověřit, že Escape/Alt+F4 nebo tlačítko „Přeskočit nastavení“ správně přeskočí onboarding.
- **TalkBack (Android)**: Spustit aplikaci → ověřit, že fokus přistane na úvodním prvku, čtečka přečte instrukce a předvolby, pokročilá nastavení jsou sbalená a rozbalitelná.
