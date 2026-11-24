# HaploBox JCDR Edition — Buglog

Dit document houdt open problemen bij die in-game nog onderzocht moeten worden. Een hypothese is geen bevestigde oorzaak; ingame PASS wordt uitsluitend na bevestiging van de gebruiker vermeld.

## 2026-11-24 — OPEN — Account 5 (Ayla): target ontbreekt bij Moonfire en Star-spell

**Context**
- WoW Forever; Team A: vijf Druids. Mael is party leader, account 5 is Ayla.
- De setup gebruikt **mouseover multiboxing**, niet een systeem dat één toets aan meerdere clients broadcast.
- In de ingestelde partylogica verwijst `party1` op de volgers naar de leader (Mael).
- De macro's worden identiek beheerd/gegeneerd via HaploBox **Macro Config**.

**Wat is vastgesteld door ingame gebruik**
- **Wrath werkt** op Ayla, inclusief het selecteren van het doel.
- **Healing werkt** op Ayla.
- **Moonfire en een andere Star-spell** (waarschijnlijk Starfire, exacte spellnaam nog controleren) krijgen op Ayla **geen target**.
- Mouseover/window focus werken volgens de gebruiker.
- Het probleem is specifiek voor account 5; de andere accounts functioneren met dezelfde macroconfiguratie wel.

**Hypothese — NIET bevestigd**
Een verschil bij de uitvoering van de concrete spellmacro's, bijvoorbeeld in de volgorde of voorwaarden van `/assist party1`, `/target`, `/cleartarget` of `/cast`. Het functioneren van Wrath toont aan dat assist in één macro werkt, maar verklaart de andere twee nog niet. Niet speculatief aan Box Mode of `party1` sleutelen.

**Volgende ingame test**
1. Target op Mael een vijand.
2. Voer op Ayla rechtstreeks uit:
   ```lua
   /assist party1
   /run print("Target:", UnitName("target") or "GEEN")
   ```
3. Vergelijk de **volledig gegenereerde macrotekst** van Wrath, Moonfire en de exacte Star-spell op Ayla; vergelijk indien nodig met account 4.
4. Bepaal of target al ontbreekt na assist, of pas tijdens de volgende regels verloren gaat. Controleer daarna pas binding of spelvoorwaarden.
5. Alleen een kleine gerichte fix na bewijs; test in-game op alle vijf Druids en houd werkende macro's intact.

**Status:** OPEN / INGAME TEST NODIG. Laatste run afgesloten voor deze diagnose. Geen codewijziging, geen TEST-release en geen ingame PASS voor dit issue.
