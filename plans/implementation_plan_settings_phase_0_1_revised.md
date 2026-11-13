# Revidovaný implementační plán: Centralizace TTS – Fáze 0 a Fáze 1

Tento dokument představuje revidovaný implementační plán pro centralizaci TTS logiky na základě zpřesnění bodů týkajících se mazání profilů, fallbacku `setVoice`, error-handlingu a testovacího pokrytí.

---

## Fáze 0: Příprava a stabilizace (Beze změny)
- **Cíl:** Stabilizace stávajícího chování, oprava chyb v importu/exportu nastavení a zajištění testovatelnosti.
- **Doplnění testu:** Přidat samostatný test importu konfigurace a následného restartu pro `announceFractionAvailability` (ověření perzistence a správného načtení při startu).
- **Stav:** Připraveno k implementaci bez změn.

---

## Fáze 1: Centralizace TTS volání – Revidovaný návrh

### 1. Mazání profilu a TTS engine (Bod 1)
- **Zjištění:** Standardní profil má `ttsEngine == null`. Metoda `applyTtsConfig()` (respektive centralizovaná logika) nevolá `setEngine`, pokud je `ttsEngine == null`.
- **Rozhodnutí:** Neexistuje nativní/podporovaný způsob resetu enginu na výchozí hodnotu pomocí `setEngine(null)`. Proto se toto chování ponechává v dosavadním stavu (pokud je `ttsEngine == null`, `setEngine` se nevyvolá).
- **Úprava testu T1-6:** Test T1-6 bude upraven tak, aby ověřoval korektní smazání profilu a aplikaci výchozích/standardních parametrů (hlasitost, rychlost, hlas) bez očekávání volání `setEngine(null)`.

### 2. Fallback při selhání setVoice (Bod 2)
- **Zjištění:** Původní návrh počítal s plošným rozšířením fallbacku `setVoice()` → `clearVoice()` na všechny aplikační body. V této refaktoringové fázi to však představuje zbytečnou změnu chování.
- **Rozhodnutí:** Zachovat stávající chování jednotlivých aplikačních bodů. Fallback `setVoice()` → `clearVoice()` zůstává tam, kde byl (např. Quick Setup), zatímco ostatní místa zachovávají své dosavadní ošetření chyb. Plošné rozšíření fallbacku se odkládá do samostatné budoucí změny.

### 3. Zachování error-handling chování (Bod 3)
- **Zjištění:** Blok D (a další aplikační místa) používají specifické vzorce pro zachycení výjimek (`try/catch` vs. `.catchError`).
- **Rozhodnutí:** Centralizační wrapper/helper zachová současné chování při chybách pro každou cestu (příp. bude parametrizován), aby nedošło k tiché změně chování při selhání TTS.

### 4. Dodatečná kontrola testů (Bod 4)
- **T1-1:** Ověření zachování rychlosti, hlasitosti, enginu a hlasu při přepínání profilů.
- **T1-6:** Úprava dle bodu 1 (mazání profilu bez vynuceného `setEngine(null)`).
- **T1-7:** Odstranění dvojího nastavení hlasu v Quick Setupu.
- **T1-8:** Ověření chování při výjimkách (zachování původního error-handlingu).
- **T1-9:** Ověření pořadí konfigurace při startu aplikace.
- **Fáze 0 – Nový test:** Test importu konfigurace a restartu pro `announceFractionAvailability`.

---

## Shrnutí připravenosti k implementaci

### Bezpečně připraveno k implementaci:
1. **Fáze 0** (včetně nového testu pro `announceFractionAvailability`).
2. **Centralizace TTS logiky (Fáze 1)** s výše uvedenými úpravami:
   - Zachování stávajícího error-handling chování pro jednotlivé cesty.
   - Ponechání specifických fallbacků per aplikační bod (bez plošného zavádění nového chování v této fázi).
   - Úprava testu T1-6 tak, aby odpovídal realitě mazání profilu s `ttsEngine == null`.

### Vyžaduje další rozhodnutí (odloženo mimo Fázi 1):
1. Plošné rozšíření fallbacku `setVoice` na všechna místa v aplikaci.
2. Eventuální implementace globálního resetu TTS enginu na výchozí hodnotu (pokud to platforma a TTS plugin budou v budoucnu podporovat).

---
*Plán uložen v souboru `plans/implementation_plan_settings_phase_0_1_revised.md`.*
