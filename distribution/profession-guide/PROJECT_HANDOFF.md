# HaploBox – projectgeheugen / overdracht

**Bijgewerkt:** 24 november 2026  
**Project:** WOW / HaploBox JCDR Edition – WoW Forever  
**Bron van waarheid voor downloads:** [TEST-manifest](../test/manifest.json) en de complete release-ZIP in `distribution/test/` (repository-root is oudere addon-broncode).

## Actuele stand

- **Nieuwste gepubliceerde TEST-release:** **HF26.20.49 – Profession Advisor Layout TEST**.
- **Release-archief:** `distribution/test/HaploBox_HF26.20.49_Profession_Advisor_Layout_TEST.zip`.
- **TEST SHA-256:** `e1951da4782ad77bb6ea78804ec16763ba79c6381cc4716b712dd797ecd5ab30`.
- **GitHub Actions:** visual-refresh build, Lua 5.1-syntaxcontrole en geïsoleerde Windows-updater-installatietest zijn geslaagd ([run 45260809055](https://github.com/JCDRTV/HaploBox-JCDR-Edition/actions/runs/45260809055)).
- **Ingame goedkeuring voor de nieuwe layout:** **OPEN**; niet afgevinkt. De screenshot van de **vorige** layout was aanleiding voor HF26.20.49.
- **Updatepad:** de bestaande **HaploBox UPDATE**-snelkoppeling, **alleen na handmatige klik**. Geen background polling of Taakplanner-update. De `VERSION_HOTFIX`-updater is vereist voor versies `HF26.20.xx`.

## Gebruikerswens / definitieve functionele specificatie

De Profession Guide moet functioneren als een interne WoW-Professions-achtige **stap-voor-stap guide van skill 1–300**, niet als een los overzicht. De hoofdinterface is **Profession Advisor**, qua stijl en werking zoals **Dungeon Advisor**. Vanuit het overzicht opent een **compact Profession Run**-venster, vergelijkbaar met Dungeon Run. Behoud de andere HaploBox-functies en hun bestaande UI.

1. De negen professions in het hoofdscherm: Blacksmithing, Leatherworking, Engineering, Tailoring, Alchemy, Enchanting, Mining, Herbalism, Skinning.
2. Per character werkelijk gemeten profession-skills; een guide volgt de relevante skill-fase met concrete craft/reagent-vereisten, trainerstappen en alternatieven. Recepten moeten bij WoW Forever passen: SoD-only patronen niet zonder live bevestiging opnemen.
3. **Party-wide** voorraadscanner voor bags én banken van Mael, Lyra, Elya, Nyra en Ayla; totalen, benodigde hoeveelheden, tekorten en itemlocaties op één scherm. Bankvoorraad kan alleen uit de laatst bekende scan komen en moet als mogelijk verouderd worden gekenmerkt.
4. Een zichtbare indicator op materiaal-items in bags/bank/tooltip: **BS – LW – ENG – TAIL – ALCH** (later uitbreidbaar naar ENCH). Groen = nog nodig, grijs = niet meer nodig, geel = onbekend; **geen onjuiste NOT NEEDED bij incomplete gegevens**. De behoefte geldt voor alle toekomstige nog open leveling-stappen, niet alleen de volgende craft.
5. Materialen mogen bij gezamenlijke planning **niet dubbel** worden toegekend aan verschillende professions. Integratie met Baganator is gewenst.
6. Gecontroleerde fasen met ingebouwde acceptatietests; de gebruiker wil tijd winnen bij profession leveling.

## Releaselog tot nu toe

| Release | Resultaat | Teststatus |
| --- | --- | --- |
| HF26.20.44 | Bestaande volledige TEST-basis waarop uitbreidingen zijn gebouwd | Ingame-eerdere features afzonderlijk te toetsen |
| HF26.20.45 | Profession Guide Fase 1: 9 tiles, skillscanner, party-dataoverzicht, compact runvenster, slashcommands | Offline checks geslaagd; ingame acceptatie deels open |
| HF26.20.46 | Quick Menu-knop `Profession Guide` toegevoegd aan MENUS | GitHub build geslaagd |
| HF26.20.47 | Quick Menu-knop naar **bovenaan MENUS** verplaatst | GitHub build geslaagd |
| HF26.20.48 | Mismatch `## Version` in verpakte `HaploBox.toc` hersteld; oorspronkelijke Windows-updater accepteerde geen drieledig versienummer | Volledige Windows-updater smoke-test geslaagd met VERSION_HOTFIX |
| **HF26.20.49** | **Visuele Profession Advisor/Run-herziening in Dungeon Advisor-stijl**: goudrand/titelbalk, sectiekoppen, ruimere vakken/partijrijen, groen/blauwe acties | **Lua 5.1 syntax PASS, SHA/ZIP PASS, Windows updater PASS; ingame layout nog OPEN** |

## Bewijs en openstaande punten

- De gebruiker heeft screenshots van **Profession Advisor naast Dungeon Advisor** gedeeld. **De primaire feedback was de opmaak**: Profession Advisor week visueel sterk af van Dungeon Advisor. Er was **geen opdracht om toen de Dungeon Advisor of sync logica aan te passen**. Daarom was HF26.20.49 **uitsluitend UI** (+ verplichte TOC-versiebump).
- Op de screenshot van de oudere Profession Advisor werden bij Mael **Engineering 59/300** en **Mining 112/300** getoond; de vier andere Druids stonden als **NO DATA**. Dit betekent **niet** dat zij geen professions hebben. De echte oorzaak van ontbrekende party-data is **nog niet vastgesteld** en moet afzonderlijk, ná de UI-acceptatie, getest worden.
- De Dungeon Advisor was in het vergelijkingsscherm geopend maar er stond `No farm dungeon selected`, met lege lijsten. **Dit was niet de vraag** en vormt geen aangetoonde defectdiagnose.
- De echte routes/reagent-aantallen 1–300, party-bags/banks, NEED-labels en materiaalreserveringen zijn **niet geïmplementeerd** in HF26.20.49. Ze mogen niet als werkend gepresenteerd worden.
- **Quick Menu-pad:** `Quick Menu > MENUS > Profession Guide (eerste rij) > OPEN`; alternatieve commands `/hbprof`, `/hb professions`.
- Updater probleem vóór HF26.20.48: oude updater had regex die `HF26.20.47` weigerde, terwijl de TOC zelf een oudere versie behield. Met `HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip` en HF26.20.48+ is de updateketen in Windows CI geverifieerd.

## Eerstvolgende stappen (volgorde)

1. **Ingame bevestigen** op Mael dat na handmatige updater-installatie **HF26.20.49** met de verbeterde hoofd- en Run-opmaak zichtbaar is en overeenkomt met het Dungeon Advisor-design. Controleer leesbaarheid en overlap op 5-box viewport.
2. **Vervolgens partij-sync apart testen**: vijf clients online, gelijke release, scan/sync; alleen bij reproduceerbare NO DATA fouten de berichtuitwisseling onderzoeken.
3. Na goedkeuring leveling-guidefasen (één profession eerst, bijvoorbeeld Leatherworking 1–300) toevoegen met geverifieerde recepten en trainercheckpoints.
4. Daarna gezamenlijke bags/banks-voorraadplanning en tenslotte de BS/LW/ENG/TAIL/ALCH NEED-indicator. Geen speculatieve materialen of false-negative labels.

## Regels voor de volgende werksessie

- **Volledige TEST-ZIP** in `distribution/test` is de basis. **NIET** reconstrueren vanuit de oudere rootbestanden.
- Nieuwe releases pas publiceren met geverifieerde manifest-hash, correcte `HaploBox.toc ## Version`, Lua-syntaxcontrole en Windows-updatertest.
- Respecteer bestaande Dungeon Advisor, Dungeon Run, Weapon Sets, Party Pawn/BiS, Baganator en macros; alleen doelgerichte wijzigingen.
- Onderscheid **offline geslaagd** en **ingame bevestigd**.
