# HaploBox JCDR Edition – Macro Spell Database (voorbereiding)

**Datum:** 16 november 2026  
**Basis:** `jcdr-total-overhaul-macros-mvp` / TB19.1m  
**Deze branch:** `jcdr-spell-database-prep`  
**Status:** ontwerp / data, niet actief, niet ingame getest.

## Afgesproken regels

| Profiel | BOX ON | BOX OFF |
| --- | --- | --- |
| DPS | `/assist party1` gevolgd door spell | Normale spell |
| Heal | Shift = jezelf; friendly mouseover; anders `party1` | Shift = jezelf; friendly mouseover; anders normale target-cast |
| Buff | Shift = jezelf; friendly mouseover; anders huidig vriendelijk target; anders jezelf | Precies hetzelfde |
| Self-buff | Gewone self-cast; geen assist en geen `party1` | Precies hetzelfde |
| Group-buff | Apart te controleren per spell; niet zomaar gelijkstellen aan een single-target buff | Idem |

Voor buffs geldt dus **geen automatisch `party1`**, ook niet bij BOX ON. Als er geen geldige mouseover en geen vriendelijk huidig target is, wordt de buff op jezelf gericht. Als Shift is ingedrukt, heeft self altijd voorrang. De gekozen macro blijft verder een gewone Blizzard-macro, geactiveerd met een echte toets of klik.

**Druid-voorbeeld, identiek voor BOX ON/OFF:**
```macro
#showtooltip Mark of the Wild
/cast [mod:shift,@player][@mouseover,help,nodead][@target,help,nodead][@player] Mark of the Wild
```

**N.B.:** `help` betekent vriendelijk, niet noodzakelijk lid van je eigen party. Daardoor kan ook een vriendelijke NPC onder de muis worden gekozen. Eerst in de client testen; pas daarna beslissen of een party-only mouseover-filter wenselijk is. Niet ongevraagd veranderen.

## Catalogusdata

Zie `concept/macro_spell_catalog.lua` – een **passieve** Lua-tabel, niet geladen door de addon. De eerste drie Druid-presets (Wrath, Moonfire en Rejuvenation) zijn bestaande TB19.1m-poc's; andere entries zijn voorstellen of per-spell te verifiëren kandidaten. De catalogus bevat zowel alle negen Classic class-sleutels als enkele voorbeelden buiten Druid. Geen volledige spelldekking claimen.

Per entry:
- `id`: stabiele interne sleutel
- `spell`: echte Engelse spellnaam (later toetsen aan client-locale)
- `macroName`: naam met maximaal 16 karakters, bv. `HB MotW`
- `profile`: herbruikbare template/targeting-logica
- `status`: bestaande MVP, voorstel of verifiëren
- spell-ID pas invullen wanneer tegen de Forever-client/API gecontroleerd

Blizzard karaktermacro-limieten zijn leidend. Macro's worden alleen expliciet op verzoek aangemaakt, uitsluitend buiten combat; bestaande persoonlijke macro's of afwijkende teksten worden nooit stilzwijgend overschreven.

## Integratie in het bestaande Macro Menu (pas na goedkeuring en test)

- Tab **Multibox** blijft Smart Follow tonen.
- Tab **Slimme spells** kan op termijn per class de catalogus tonen, met filter **DPS / Healing / Buffs / Utility**.
- Voor iedere entry: spellnaam, macroprofiel, status; acties **Maak** en **Pak op**. `Toets` alleen bij daadwerkelijk gedefinieerde binding; conflicten vereisen expliciete bevestiging.
- Geen automatische casts, geen UI-wijziging tijdens combat.
- Eerst offline databanktests; daarna test in de echte Forever-client, inclusief BOX ON/OFF en verschillende targeting-situaties.
- F3 = Assist `party1` en F4 = Blizzard *Interact With Target* blijven ongewijzigd. F1 Smart Follow en legacy focus/trade-bindingen blijven ongewijzigd.

## Testgevallen voor buffs

| Situatie | Verwacht |
| --- | --- |
| Shift ingedrukt, friendly mouseover en target bestaan | Buff jezelf |
| Friendly mouseover + huidig ander vriendelijk target | Buff mouseover |
| Geen mouseover, huidig vriendelijk target | Buff huidig target |
| Geen mouseover en geen target | Buff jezelf |
| Huidig vijandig target | Buff jezelf (mits geen friendly mouseover) |
| Friendly NPC onder muis | Wordt geraakt door `help` – expliciet beoordelen, mogelijk ongewenst |
| BOX ON vs OFF | Exact dezelfde buff-macro; geen `party1` |
| Combat / groepswissel / na reload | Geen onbedoelde macro-bewerking; gecontroleerd testen |

## Bouwgrenzen

Dit document is **geen** toestemming om de werkende TB19.1m-code aan te passen. `main`, `jcdr-development` en `jcdr-total-overhaul-macros-mvp` blijven onaangeroerd. De data in deze ontwerpbranch wordt niet gebruikt door `HaploBox.toc`. Eerst TB19.1m ingame testen, pas daarna integratie bespreken. TB19.1k ZIP blijft de betrouwbare rollback.
