# HaploBox distribution — TEST (JCDR Edition)

**De Windows-update is op aanvraag:** er is geen polling, automatische achtergrondtaak of Windows Taakplanner. De knop **HaploBox UPDATE** haalt wel in één klik de nieuwste complete TEST-release op.

## Eerste installatie

1. Download [HaploBox Manual Updater](test/HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip) en pak de ZIP uit.
2. Start één keer INSTALL.cmd. De installer herkent D:\World of Warcraft\_forever_\Interface\AddOns.
3. Een bureaubladsnelkoppeling **HaploBox UPDATE** wordt gemaakt.
4. Klik de snelkoppeling om de nieuwe TEST-release op te halen.
5. **Sluit WoW volledig af en start alle vijf clients opnieuw** na een update die een nieuwe module toevoegt.


## Belangrijke updater-reparatie (HF26.20.48)

De oorspronkelijke TEST-updater (D_FOREVER) accepteert uitsluitend twee onderdelen in het versienummer. Onze drieledige HF26.20.48 wordt daardoor geweigerd. De pakketversies 20.45–47 hadden bovendien geen overeenkomende `## Version` in `HaploBox.toc`, terwijl het Windows-programma dat verplicht controleert. HF26.20.48 herstelt het TOC-veld; de complete overige addonbestanden zijn ongewijzigd gebleven.

**Eenmalig nodig als je nog de oorspronkelijke updater gebruikt:** download [VERSION HOTFIX Updater](test/HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip), pak uit en start `INSTALL.cmd`. De installer vernieuwt je bestaande updater-snelkoppeling en blijft dezelfde AddOns-map gebruiken. Doe daarna met WoW gesloten **HaploBox UPDATE** om de herstelde HF26.20.48 op te halen. De lokale log staat op `%LOCALAPPDATA%\HaploBoxUpdater\updater.log`; `STATUS.cmd` toont de laatste regels.

## Huidige TEST-versie

- **HF26.20.49 – Profession Advisor Layout TEST** (nog niet ingame goedgekeurd)
- [Volledige TEST-release](test/HaploBox_HF26.20.49_Profession_Advisor_Layout_TEST.zip)
- [TEST manifest](test/manifest.json)
- [Installatie-updater](test/HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip)
- Backups/logs: %LOCALAPPDATA%\HaploBoxUpdater

De updater leest het TEST-manifest alleen bij een klik, controleert de SHA-256, maakt een backup en installeert de volledige HaploBox-map. De gebruikersinstellingen in WTF/SavedVariables blijven behouden.

### Wat is toegevoegd in HF26.20.45–49?

Deze build is opgebouwd uit de **volledige HF26.20.44 release**, niet de oudere bronbestanden in de repository-root. Onder HaploBox/ProfessionGuide zijn uitsluitend Data.lua, Core.lua en UI.lua toegevoegd. In HaploBox.toc is de module geladen en HaploBoxProfessionDB als SavedVariables opgenomen. De hotfixes HF26.20.46–47 veranderen ten opzichte van HF26.20.45 uitsluitend HaploBox/ControlBar.lua om de Quick Menu-knop toe te voegen en **Profession Guide bovenaan MENUS** te zetten; alle overige verpakte addonbestanden blijven inhoudelijk gelijk.

**Ingame opening:** Quick Menu > MENUS > **Profession Guide** (eerste rij) > **OPEN**. Ook via /hb professions of /hbprof. Profession Advisor (hoofdscherm), compacte Profession Run, negen professions, skillscanner en party-sync zijn inbegrepen.

HF26.20.49 is een uitsluitend visuele update van de Profession Advisor: goudomlijnde titelbalk zoals Dungeon Advisor, duidelijkere sectiekoppen, ruimere profession-kaarten, bredere party-rijen en groen/blauw gekleurde acties. Het compacte Profession Run-venster heeft nu dezelfde herkenbare stijl. Party-sync, Dungeon Advisor en alle andere modules zijn niet aangepast.

**Nog niet inbegrepen:** leveling-recepten 1–300, materialen/party-bags/banks en Need-tags BS/LW/ENG/TAIL/ALCH/ENCH. Deze functionaliteit blijft bewust uit tot de volgende geteste fases.

## Belangrijk

- TEST en STABLE zijn gescheiden; er is geen automatische promotie.
- Er is nog **geen** ingame-goedkeuring voor HF26.20.49.
- De repository-root bevat oudere broncode; gebruik de volledige release-ZIP in distribution/test.
- Bron, standalone test-archief en gecontroleerde package-builder staan in [distribution/profession-guide](profession-guide/).

## Projectoverdracht en ontwikkellog

- [Actueel projectgeheugen / handoff](../docs/HAPLOBOX_PROJECT_HANDOFF.md)
- [Chronologisch development log](../docs/HAPLOBOX_DEV_LOG.md)
