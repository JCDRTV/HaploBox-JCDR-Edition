# HaploBox JCDR Edition — Development Log

## 2026-11-16 — Chat-overdracht / TB19.1m Macro Menu MVP

**Status:** ontwikkelwerk; nog NIET ingame getest. Dit log legt de laatste goedgekeurde afspraken vast na de overgang naar een nieuwe chat. Eerdere release-notities en technische documenten blijven intact.

### GitHub en builds
- Repository: `JCDRTV/HaploBox-JCDR-Edition`.
- `main`: ongemoeid laten; geen productie-uitrol.
- `jcdr-development`: TB19.1l Total Overhaul-basis, met centrale BOX ON/OFF, Smart Follow en combat-indicators.
- `jcdr-total-overhaul-macros-mvp`: TB19.1m experimentele macro-menu-uitbreiding bovenop TB19.1l.
- Geen GitHub Release, productiebouw, ZIP of WowUp-installatie op basis van TB19.1m.
- Behoud de betrouwbare TB19.1k ZIP als rollback.

### Overhaul: richting en doel
- HaploBox is bedoeld als centrale interface voor de standaard multibox-bediening én een slimme macro-library, niet alleen als status-/teamframe.
- Eerste kleine, testbare fase: **F1 Smart Follow** en **slimme Druid-spellmacro's**.
- Bedien het menu via Quick Menu → **MACRO MENU** of `/hb macros`.
- Macros worden lokaal in eigen Blizzard-macroslots gemaakt, bewust opgepakt en handmatig op de gewone actionbar gezet; geen automatische casts.
- Veiligheidsgrenzen: bestaande afwijkende Blizzard-macros nooit ongemerkt overschrijven; wijzigingen/bindings alleen buiten combat; conflicterende F1-toets expliciet laten bevestigen.
- De centrale Share-to-Party UI / keybinding-overdracht is **nog niet** gerealiseerd.
- Legacy F3 Assist, F5/F6 Focus en NUM1 Trade worden in deze MVP **niet** vervangen of uitgebreid. Blizzard Focus en bestaande bindings blijven voorlopig staan.

### BOX mode en unit-targeting
- **`party1` is een dynamische WoW-unit-ID, niet de hardcoded naam Mael.** Wie op dat moment op party1 staat, wordt gebruikt.
- **BOX ON — DPS:** `/assist party1`, daarna `/cast <spell>`.
- **BOX OFF — DPS:** gewone `/cast <spell>`, zonder gedwongen assist.
- **BOX ON — heal (goedgekeurde vaste prioriteit):**
  1. Shift ingedrukt → heal op **self** (`@player`).
  2. Friendly live mouseover → heal op **de unit onder de muis**.
  3. Anders → heal op **party1**, ongeacht het geselecteerde target.
- **BOX OFF — heal:** Shift en friendly mouseover blijven werken; daarna normale Blizzard-target-cast.
- Dit wordt de standaard voor alle geschikte healing-spells die later aan HB worden toegevoegd.
- **Beschikbaar als MVP-preset:** Rejuvenation, naast Wrath en Moonfire.
- **Nog toe te voegen na test:** Healing Touch en Regrowth, dezelfde heal-prioriteit.

### Smart Follow
- F1 is een expliciet door speler geactiveerde Blizzard-macro, **geen automatisch volgen**.
- **Direct:** followers volgen party1 (in huidige opstelling Mael).
- **Dungeon:** healer volgt party1; DPS volgen de enige als Blizzard-HEALER aangewezen partijgenoot.
- Bij nul of meerdere healer-rollen blijft de followmacro bewust inactief.
- Smart Follow hangt aan BOX ON; bij BOX OFF geen HB-followactie.

### Wat wel en niet bewezen is
- De TB19.1m GitHub-testbranch bevat code voor het Macro Menu en eerste presets.
- De uiteindelijke in-game werking, frame-regressie, keybinding-API en combatgedrag zijn **nog niet bevestigd**.
- Ontwerpafspraak is niet hetzelfde als gevalideerde functionaliteit.

### Eerstvolgende werkvolgorde
1. TB19.1k rollback veilig houden; TB19.1m alleen op een testinstallatie.
2. `/reload`: controleren op Lua-errors en regressies in Party, HoTs, Buffs, Focus/combat, HaploBar en Quick Menu.
3. `/hb macros`: menu tonen, F1 aanmaken, conflictmelding en bewuste bevestiging testen.
4. Direct/Dungeon Smart Follow testen met verschillende partyposities, healerrollen en BOX ON/OFF.
5. Wrath, Moonfire en Rejuvenation aanmaken, via **Pak op** op de actionbar zetten en de gegenereerde Blizzard-macrotekst inspecteren.
6. Heal-prioriteit testen: geen mouseover → party1; Shift → self; vriendelijke mouseover → die unit; controleren dat BOX OFF teruggaat naar normale cast.
7. Testen: combat, partywissel, andere leider/healer, solo, BG, reload/relog en 5-client sync.
8. Alleen na succesvolle tests: overige heals (Healing Touch, Regrowth), vervolgens uitbreiden van macro-library/centrale bediening.

### Naslag
- `docs/BOXMODE_DEV_LEESMIJ.txt` — TB19.1l basis en testopzet.
- `docs/MACROMENU_MVP_LEESMIJ.txt` — TB19.1m menu en beperkte testscope.
- `BoxMode.lua` en `MacroLibrary.lua` — huidige implementatie op de testbranch.

**Projectstand bij overdracht:** ontwerp goedgekeurd, code voor MVP aanwezig, praktische test nog open. Geen veranderingen aan `main` of aan bestaande historische notities.
