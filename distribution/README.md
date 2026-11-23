# HaploBox distribution — TEST (JCDR Edition)

**De Windows-update is op aanvraag:** er is geen polling, automatische achtergrondtaak of Windows Taakplanner. De knop **HaploBox UPDATE** haalt wel in één klik de nieuwste complete TEST-release op.

## Eerste installatie

1. Download [HaploBox Manual Updater](test/HaploBox_Manual_Updater_D_FOREVER_TEST.zip) en pak de ZIP uit.
2. Start één keer INSTALL.cmd. De installer herkent D:\World of Warcraft\_forever_\Interface\AddOns.
3. Een bureaubladsnelkoppeling **HaploBox UPDATE** wordt gemaakt.
4. Klik de snelkoppeling om de nieuwe TEST-release op te halen.
5. **Sluit WoW volledig af en start alle vijf clients opnieuw** na een update die een nieuwe module toevoegt.

## Huidige TEST-versie

- **HF26.20.45 – Profession Guide Phase 1 TEST** (nog niet ingame goedgekeurd)
- [Volledige TEST-release](test/HaploBox_HF26.20.45_Profession_Guide_Fase1_TEST.zip)
- [TEST manifest](test/manifest.json)
- [Installatie-updater](test/HaploBox_Manual_Updater_D_FOREVER_TEST.zip)
- Backups/logs: %LOCALAPPDATA%\HaploBoxUpdater

De updater leest het TEST-manifest alleen bij een klik, controleert de SHA-256, maakt een backup en installeert de volledige HaploBox-map. De gebruikersinstellingen in WTF/SavedVariables blijven behouden.

### Wat is toegevoegd in HF26.20.45?

Deze build is opgebouwd uit de **volledige HF26.20.44 release**, niet de oudere bronbestanden in de repository-root. Onder HaploBox/ProfessionGuide zijn uitsluitend Data.lua, Core.lua en UI.lua toegevoegd. In HaploBox.toc is de module geladen en HaploBoxProfessionDB als SavedVariables opgenomen. Alle andere bestaande addonbestanden blijven inhoudelijk gelijk.

**Ingame opening:** /hb professions of /hbprof. Profession Advisor (hoofdscherm), compacte Profession Run, negen professions, skillscanner en party-sync zijn inbegrepen.

**Nog niet inbegrepen:** leveling-recepten 1–300, materialen/party-bags/banks, Need-tags BS/LW/ENG/TAIL/ALCH/ENCH en een Quick Menu-knop. Deze functionaliteit blijft bewust uit tot de volgende geteste fases.

## Belangrijk

- TEST en STABLE zijn gescheiden; er is geen automatische promotie.
- Er is nog **geen** ingame-goedkeuring voor HF26.20.45.
- De repository-root bevat oudere broncode; gebruik de volledige release-ZIP in distribution/test.
- Bron, standalone test-archief en gecontroleerde package-builder staan in [distribution/profession-guide](profession-guide/).
