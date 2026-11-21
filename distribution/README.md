# HaploBox distribution — TEST (JCDR Edition)

**Alle updates zijn nu handmatig.** Er is geen polling, achtergrondtaak of Windows Taakplanner meer.

## Eerste installatie

1. Download [HaploBox Manual Updater](test/HaploBox_Manual_Updater_D_FOREVER_TEST.zip) en pak de ZIP uit.
2. Start eenmalig `INSTALL.cmd`. De installer herkent `D:\World of Warcraft\_forever_\Interface\AddOns`.
3. De installer maakt een desktop-snelkoppeling **HaploBox UPDATE**. Installeren betekent nog **niet** dat een build wordt gedownload.
4. Klik **HaploBox UPDATE** (of `UPDATE.cmd`) wanneer je de actuele build wilt ophalen.
5. Doe daarna `/reload` in alle vijf clients (bij sommige addon-structuurwijzigingen eerst volledig herstarten).

## Hoe een nieuwe testbuild wordt geleverd

De ontwikkelaar publiceert een gecontroleerde volledige addon-ZIP en past [manifest.json](test/manifest.json) aan. De updater leest dit manifest **uitsluitend na een klik**. Alleen bij een nieuwe versie downloadt hij het bestand, controleert SHA-256, maakt een lokale backup buiten `Interface\AddOns`, en installeert in de ene gedeelde `HaploBox` map. `WTF/SavedVariables` blijven intact.

* Huidige TEST-build: **HF26.17 Dungeon Advisor V1**, nog niet ingame goedgekeurd.
* [Huidige volledige addon-ZIP](test/HaploBox_HF26.17_DungeonAdvisor_V1.zip)
* [Manual Updater ZIP](test/HaploBox_Manual_Updater_D_FOREVER_TEST.zip)
* [TEST manifest](test/manifest.json)
* Backups en logs: `%LOCALAPPDATA%\HaploBoxUpdater`

Bij installatie van deze handmatige versie wordt een eventueel eerder gemaakte taak **HaploBox Auto Updater TEST** verwijderd. TEST en STABLE zijn gescheiden; er is geen automatische promotie naar STABLE.

De repository-root bevat een oudere broncodestand. De volledige huidige addon is beschikbaar via de bovenstaande ZIP, niet als vervanging van die rootbestanden.
