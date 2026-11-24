# HaploBox JCDR Edition — Development Log

**Bijgewerkt:** 24 november 2026  
**Actuele TEST op GitHub:** **HF26.20.49** — Profession Advisor Layout TEST  
**Testmanifest:** [distribution/test/manifest.json](../distribution/test/manifest.json)  
**Actuele overdracht:** [HAPLOBOX_PROJECT_HANDOFF.md](HAPLOBOX_PROJECT_HANDOFF.md)

> Alle versies hieronder zijn TEST-releases. Offline tests of publicatie zijn **geen** automatische ingame PASS. Latest TEST is de volledige, geverifieerde ZIP uit `distribution/test` (repository-root is ouder).

## Releases / mijlpalen

| Versie | Gerealiseerd | Acceptatie / kanttekening |
|---|---|---|
| HF26.20.29 | Versnelde batched Pawn-scan; batches van 16, ~0,9 s aanvraag, ~0,42 s antwoorden. | Snelheid ingame positief bevestigd; niet aanpassen zonder bewijs. |
| HF26.20.30–31 | Resizable Dungeon Advisor/Run, compacte Dungeon Run. | Bestaande lay-outfunctionaliteit beschermen. |
| HF26.20.32 | Exact-item-ID Unique-Equipped OWNED guard per Druid. | Geen dubbele unieke farmdoelen ingame gerapporteerd; groepsrestricties tussen verschillende IDs niet volledig afgedekt. |
| HF26.20.33–34 | Baganator/Character Weapon Set labels, native Quick Menu hover-hotkeys voor 2H/1H/OH. | Markeren, verwijderen, reassign, bags sorteren en `/reload` op Mael bevestigd; volledige 2H vs 1H+OH BiS-scoretest bleef open. |
| HF26.20.35 | BiS coverage, missing Main-Hand scenario, complete-set vergelijking, Forever Polearms. | `/hbbiscoverage Lyra` werkte; 2H- en ringupgrade verschenen, 1H/Off-Hand/uncached en 3–7 unresolved dungeoncontroles nog open. |
| HF26.20.36 | Leesbaardere Dungeon Advisor, voorlopige gewogen prioriteitsweergave. | Vervolgprioriteit in .37 vervangen. |
| HF26.20.37 | Unieke item-ID's één keer in dungeon Score; Tank 3 / Healer 2 / DPS 1; rolcounters, scrollbare lijsten en SPECIAL-behandeling. | Mock PASS; ingame layoutverzoeken leidden tot .38. |
| HF26.20.38 | Afzonderlijke Tank/Healer/DPS kolommen met iconen en responsieve uitlijning. | Mock PASS, wijzigingen visueel bijgeschaafd in opvolgers. |
| HF26.20.39 | Compacte UI: per-dungeon RUN, inklapbare bosses, schone labels/percentages, paginaknoppen weg. | Offline PASS; ingame UI verder verfijnd. |
| HF26.20.40 | Proportionele scrollbars met pijltjes, UNI/Score iconheaders, geen '?' achter score. | Offline PASS; iconen en scrollbarstijl kregen vervolgpolish. |
| HF26.20.41 | Eerste UI-polish/nieuwe statuslabels. | **Regressie:** te veel items werden UNVERIFIED door globale onvolledige scan. |
| HF26.20.42 | Herstel per-item Pawn-verificatie; ronde headericonen; kwaliteitsranden. | Offline PASS; ingame screenshot bevestigde groen/geel en lootweergave; volledige goedkeuring niet expliciet vastgelegd. |
| HF26.20.43 | AtlasLoot-achtige items: native quality colors, dubbele slotprefix weg, onderregel itemtype, subtiele scrollbars en headericonen. | Offline PASS; nog verdere dobbelsteen-/tooltipcorrecties nodig. |
| **HF26.20.44** | **Need-dobbelsteen zichtbaar in Advisor/Run**, deterministisch Tank > Healer > DPS hoogste Pawn, bij DPS-tie Elya > Nyra > Ayla; Party Pawn-tooltip gelijk aan Plannerlabels; UNI gebruikt Need-dobbelsteen, Score upgradepijl. | **Geplaatst op GitHub/Drive, offline Lua + 20 mocks PASS; ingame Need-prioriteit/tooltip nog OPEN.** GitHub commit `ec168c20db7976fa6be2430219e9d5432e4c85f0`. |
| HF26.20.45 | Profession Guide fase 1 geïntegreerd in volledige HF26.20.44-package: 9 professions, Advisor/Run, skillscanner, party-sync. | TEST, geen volledige 1–300 recepten. |
| HF26.20.46 | Profession Guide geïntegreerd in Quick Menu. | TEST. |
| HF26.20.47 | Profession Guide eerste rij in Quick Menu → MENUS; `/hbprof` fallback. | TEST. |
| HF26.20.48 | Windows-updater compatibiliteit voor drieledige versienummers en pakket-TOC-versie; VERSION_HOTFIX installer. | Updatercontract/Windows-smoketest gedocumenteerd; handmatige installatie blijft verplicht. |
| **HF26.20.49** | **Profession Advisor visuele refresh:** Dungeon Advisor-stijl goudrand, 3×3 profession cards, brede party-rijen, duidelijke acties en compacte Profession Run. | **Huidige TEST**, offline ZIP-integriteit bevestigd volgens manifest; **INGAME VISUAL ACCEPTANCE OPEN**. |

## Bevindingen uit de ingame tests

- Team A: **Mael (Tank/leader), Lyra (Healer), Elya/Nyra/Ayla (DPS)**.
- Weapon Set-hotkeys in Baganator en markeringen na sorteren/`/reload` werkten op Mael; automatische swaps zijn niet gewenst.
- Lyra: coverage ooit 2H 14 gescand, 1 UP; 1H 18 gescand (16 NOUP + 2 UNCACHED); OH 2 NEEDPAIR; ring 12 gescand (1 UP). Latere scans hadden wisselende completeness. Dit bewijst **niet** dat alle potentiële BiS-items onderzocht zijn.
- The Stockade: volledige verzonden Pawn-requests maar `Nightskulker Ring` item 273820 gaf `NO_ITEM` / NOSTATS voor de vijf Druids; AtlasLoot laat speciale Equip-effects zonder normale Pawn-stats zien. Als SPECIAL markeren, niet als mislukte upgrade of 0%.
- Algemene dungeonstatus PROVISIONAL/UNVERIFIED niet automatisch doordrukken naar afzonderlijke items met betrouwbare Pawn-scores (gefixte .41-regressie).
- Dungeonprio telt unieke items, niet vijf keer hetzelfde lootitem. Need-dobbelsteen prioriteert het item binnen de party, **niet** de waarde van de dungeon Score.

## Open issues / werkvoorraad

- HF26.20.49 Profession Advisor/Run **ingame** layout, Quick Menu en skill/party sync bevestigen.
- HF26.20.44 Need-dobbelsteen **ingame** aanwezig per gedeeld item en juiste prioriteit; Party Pawn-tooltip gelijk aan Planner.
- Dungeon BiS completeness en ontbrekende/gecachete items; 2H vs 1H+OH en ring-/trinketcombinaties, FULL per-slot coverage.
- Latere features: automatische BiS-markeringen, Command Center layoutpreset, volledige Profession leveling-guide 1–300 en party-wide bags/banks Need-indicatie.
- Geen wijziging aan snelle scanner zonder aangetoonde noodzaak. Bij iedere volgende release: volledige TEST-ZIP als basis; offline regressies + Drive-back-up + manifestverificatie + aparte ingame acceptatie.

## Publicatie / updater

- [TEST-manifest](../distribution/test/manifest.json)
- [Handmatige updaterinstructies](../distribution/README.md)
- De oude `D_FOREVER` Windows updater is incompatibel met de HF26.20.xx-versies: gebruik zo nodig `HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip` éénmalig.
- Geen auto-update; gebruiker klikt zelf **HaploBox UPDATE**. Bewaar projecten strikt gescheiden (HaploBox ≠ Alpega).
