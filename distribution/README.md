# HaploBox distribution — TEST (JCDR Edition)

Dit is de **TEST-distributie**, gescheiden van de broncode in de root van de repo.

* Laatste testbuild: **HF26.17 Dungeon Advisor V1**
* Doelinstallatie: `D:\World of Warcraft\_forever_\Interface\AddOns\HaploBox`
* [Updater ZIP](test/HaploBox_Auto_Updater_CONFIGURED_D_FOREVER_TEST.zip)
* [HaploBox HF26.17 ZIP](test/HaploBox_HF26.17_DungeonAdvisor_V1.zip)
* [Machine-readable manifest](test/manifest.json)

De updater wordt **eenmalig** op Windows geïnstalleerd met `INSTALL.cmd`. Daarna controleert Windows Taakplanner om de vijf minuten of het TEST-manifest verandert. Hij controleert SHA-256, maakt een volledige lokale backup, installeert één gedeelde WoW-addonmap en verandert geen SavedVariables.

Deze TEST-release is nog niet ingame goedgekeurd. Er wordt geen STABLE-release gepubliceerd of automatisch gepromoveerd. Na een nieuwe versie in alle WoW-clients `/reload`; bij bepaalde TOC/structuurwijzigingen een volledige WoW-herstart.

De files in de root van deze repo zijn niet automatisch bijgewerkt naar HF26.17. De volledige HF26.17 addon-build staat in de bovenstaande ZIP.
