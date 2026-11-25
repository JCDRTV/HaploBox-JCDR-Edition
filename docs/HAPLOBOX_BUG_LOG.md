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

## 2026-11-25 — P2 OPEN — BOX macro initialization after login/roster sync

- User confirmed macro behavior recovered after BOX OFF → ON. Do not assume the earlier Ayla-specific target issue has the same cause.
- Inspected the packaged HF26.20.52 BoxMode.lua: PLAYER_LOGIN resets local BOX OFF and restores safe macros, then schedules trusted-team reconciliation. Roster events can trigger a further reconcile and a follower mode request. Matching cached validatedMode can cause a leader command to receive an ACK without rereading macro bodies. autoTeamDone prevents a repeat automatic enable in an unchanged trusted party session (protects deliberate manual OFF).
- Hypotheses, not ingame proof: startup ordering or a stale validated profile could produce incorrect macro bodies/mode; do not remove intentional manual OFF semantics or touch cast/follow/bindings.
- Next controlled repro: out of combat, with all five trusted characters grouped and BOX ON, reload one follower; inspect actual BOX state and a failing macro before any OFF/ON toggle. Use /hb box status, /hb box inspect, and the exact macro in /macro. Compare against leader/follower profile. Only make a targeted fix after evidence; preserve working Pawn warning and F1 camera preset.
- HF26.20.52 Pawn Advisor warning: user responded “top perfect” to the interface placement/release; no separate screenshot or installed-version readback. Main updater remains .49; .52 test branch, offline build PASS; Drive backup and Windows updater test still open.
