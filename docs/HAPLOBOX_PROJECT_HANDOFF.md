# HaploBox JCDR Edition — Projectoverdracht

**Bijgewerkt:** 25 november 2026  
**Project:** World of Warcraft Forever / Classic, multiboxing met HaploBox JCDR Edition  
**Repository:** https://github.com/JCDRTV/HaploBox-JCDR-Edition  
**Actuele gepubliceerde TEST:** **HF26.20.49 — Profession Advisor Layout TEST**  
**Release manifest:** [distribution/test/manifest.json](../distribution/test/manifest.json)  
**Installatie/handmatige updater:** [distribution/README.md](../distribution/README.md)  
**Gedetailleerd changelog:** [HAPLOBOX_DEV_LOG.md](HAPLOBOX_DEV_LOG.md)

> **Belangrijk:** De huidige TEST is HF26.20.49; HF26.20.44 was de laatst besproken Dungeon/Need-dobbelsteenhotfix in de vorige chat. De huidige repository-root bevat verouderde addonbron. Nieuwe hotfixes moeten worden opgebouwd vanaf de **volledige, verifieerbare TEST-ZIP** in `distribution/test`, niet vanaf alleen de rootbestanden.

## 2026-11-25 — Recovery checkpoint (user-confirmed ingame)

- SYN-02: .49 and .50 isolation failed initially; .44 also failed. PING and batched Pawn transport worked. `/hbbiscoverage Lyra` reported 47 NOSCALE out of 48 checked weapon/ring items; one OWNED. User found missing Pawn specialization/scales and confirmed scores worked after configuration.
- HF26.20.50 isolation branch is diagnostic only, not the next release baseline. Keep .49 ZIP and main TEST manifest unchanged.
- Smart Follow F1 camera recall worked after `/hb followcam save confirm` on Lyra. Other characters' camera presets not individually confirmed.
- Macro behavior recovered after manual BOX OFF → ON; root cause of stale macros not established. No code fix claimed.
- User reports current gameplay working well; .49 is the chosen development baseline, but the installed version at final recovery was not independently read back. Profession UI and Need-dice acceptance remain separately open.
- Next: P1 clear per-character NOSCALE warning without changing Pawn scoring, transport, macro generation or timers; P2 investigate macro initialization separately.

## Team A, rollen en platform

- **Mael** — Druid, leader, **Tank**.
- **Lyra** — Druid, **Healer**.
- **Elya, Nyra, Ayla** — Druids, **DPS**; bij exacte DPS-gelijkstand deze volgorde.
- WoW Forever-mechanics zijn leidend. **Pawn Forever** gebruikt gecontroleerde passende Forever-statgewichten (inclusief relevante weapon DPS); deze niet zonder aantoonbare noodzaak aanpassen.
- **Baganator** is de bag-addon; AtlasLoot levert de bekeken dungeonloot.

## Onveranderlijke ontwikkelafspraken

- **Alleen handmatige HaploBox UPDATE** op initiatief van de gebruiker. Geen automatische installatie, achtergrondpolling of automatische promotie van TEST naar STABLE.
- Bij nieuwe modules of TOC-wijzigingen: WoW afsluiten en alle vijf clients opnieuw starten. Bewaar SavedVariables.
- **Offline PASS is niet hetzelfde als ingame PASS.** Statussen expliciet gescheiden registreren.
- Minimale, gerichte wijzigingen. Behoud ALT-hover/Party Pawn, Quick Menu, Mini UI, Smart Follow, macros, Baganator-markeringen, Weapon Sets, Dungeon Planner/Run en bestaande scanners.
- Bescherm de snelle **HF26.20.29 Pawn Batch Scan** (16 item-ID's per batch, circa 0,9 s verzoekinterval en 0,42 s antwoordinterval), inclusief netwerkprotocol.
- Controleer alle Lua-syntax, mocks, ZIP-integriteit, veranderde/onveranderde bestanden, TEST-manifest, actuele GitHub HEAD en Google Drive-back-up vóór publicatie.
- **HaploBox en Alpega Slot Booker volledig gescheiden houden.**
- Technische detailinformatie via chatcommands; UI voor gameplay. Onzekerheid niet verbergen of tot 0% omzetten.

## Dungeon BiS / HaploLoot — overeengekomen werking

- Scan huidige-level dungeonloot via AtlasLoot en vergelijk items per Druid met Pawn Forever.
- Maak een party-wide BiS-farmwishlist. Unique/Unique-Equipped OWNED-guard werkt op exact item-ID, per Druid; andere unieke groepen/koppelingen blijven een aandachtspunt.
- Eén uniek item-ID telt **één keer** in de dungeonprioriteit, ook als meerdere Druids het nodig hebben. De rollen hebben gewichten: **Tank 3, Healer 2, DPS 1**; gedeeld item krijgt alleen het hoogste relevante gewicht. Rolcounters voor T/H/D mogen overlappen; de Score is de som van unieke itembijdragen.
- **Need-dobbelsteen (HF26.20.44):** precies één winnaar per betrouwbaar beoordeeld item, **Tank Mael > Healer Lyra > hoogste bevestigde Pawn-increase bij DPS**. Exacte DPS-tie: **Elya > Nyra > Ayla**. Geen speculatieve dobbelsteen voor UNKNOWN/UNVERIFIED/SPECIAL of een onbewezen EMPTY-situatie. Ingame acceptatie van deze hotfix nog expliciet controleren.
- Wapens: 2H vergelijken met volledige 1H + Off-Hand-combinaties; onvolledige sets mogen niet stilzwijgend alle kandidaten blokkeren. Voor Lyra waren Main-Hand/Off-Hand-coverage en onopgeloste itemdata nog een aandachtspunt. Polearm-ondersteuning vanaf level 20 is in eerdere test meegenomen.
- **Statusweergave:** bevestigde positieve percentages groen, `EMPTY` en `SPECIAL` geel, `UNVERIFIED` rood. Geen `CHECK?`, geen `NEW`, geen vraagtekens achter scores. Een onvolledige globale dungeoncontrole mag een afzonderlijk betrouwbaar beoordeeld item niet automatisch rood maken.
- Voorbeeld bijzondere data: **Nightskulker Ring item 273820** heeft alleen speciale Equip-effects; AtlasLoot toont item, Pawn-itemparser geeft `NO_ITEM`. Als `SPECIAL`/handmatige beoordeling behandelen, niet als 0%-upgrade.
- Aanbevolen zichtbare interface: Dungeon Advisor/Run met AtlasLoot-achtige compacte items en **echte WoW-quality colors**, originele tooltips, inklapbare bosses, één RUN-knop per dungeon, duidelijke maar subtiele dynamische scrollbars en compacte kolomiconen.
- Gewenste headericonen na .44: **Need-dobbelsteen boven UNI**, bestaande **Pawn-upgradepijl boven Score**, plus native Tank/Healer/DPS-iconen.
- Chatdiagnostiek behouden: `/hbbiscoverage Lyra`, `/hblootnet diag`, `/hblootnet inspect 273820`, waar beschikbaar `/hbrunaudit`.

## Profession Guide — actuele projectstatus (.45–.49)

- Phase 1 bevat **Profession Advisor**-hoofdscherm, compacte **Profession Run**, negen professions, skillscanner en party-sync.
- Opening: Quick Menu → **MENUS → Profession Guide → OPEN** (eerste rij); fallback `/hbprof` of `/hb professions`.
- **HF26.20.49** is een **uitsluitend visuele** update: goudomlijnde header, leesbare cards/sectiekoppen, bredere party-rijen, meer consistente knoppen en compacte run-layout.
- **Nog niet geïmplementeerd:** volledige leveling-receptgids 1–300, materiaalbehoefteberekening, party-wide bags/banks inventaris, en Need-tags **BS/LW/ENG/TAIL/ALCH/ENCH**. Niet presenteren als reeds werkend.

## Windows-updater — belangrijke HF26.20.48 reparatie

- De oude `D_FOREVER` updater accepteerde niet de drieledige HF26.20.xx-versienummers en releases .45–.47 hadden een niet-overeenkomende TOC-versie.
- Gebruik indien nodig éénmalig `distribution/test/HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip` met `INSTALL.cmd` om de bestaande snelkoppeling **HaploBox UPDATE** te repareren; daarna handmatig bijwerken.
- Updaterlogs: `%LOCALAPPDATA%\HaploBoxUpdater\updater.log`, bekijken via `STATUS.cmd`.
- Verifieer altijd of TEST-manifest, ZIP-versie, `HaploBox.toc` en installatiestatus overeenkomen.

## Acceptatie en eerstvolgende controles

1. **HF26.20.49 ingame visual acceptance OPEN:** Profession Advisor en Profession Run bekijken, openen vanuit Quick Menu; regressiecontrole met Dungeon Advisor/Run.
2. **HF26.20.44 Need-dobbelsteen ingame OPEN:** gedeeld item krijgt exact één juiste winnaar volgens Tank > Healer > DPS highest Pawn, DPS-tie Elya > Nyra > Ayla; Party Pawn-tooltip toont dezelfde labels/scores als Planner.
3. Dungeon BiS-coverage blijft deels **PROVISIONAL/UNVERIFIED** waar dungeon-/itemgegevens niet compleet zijn. Eerdere Wailing Caverns/Stockade-diagnostiek toonde grotendeels complete netwerkantwoorden, maar itemcache/NEEDPAIR/NOSTATS kunnen nog spelen.
4. Toekomstig: volledige BiS-coverage per slot, tweede ring/combinatie, automatische BiS-markeringen op Baganator en Character, optionele vaste **Command Center Layout** (vijf Druids links, Advisor midden, Run rechts).
5. Profession Guide toekomstige fasen: recipe steps, materialen, party-bags/banks en relevante Need-tags.

**Statusnoot:** Dit bestand legt de projectafspraken vast. Het vervangt geen ingame goedkeuring en schrijft geen automatisch ChatGPT-geheugen.
