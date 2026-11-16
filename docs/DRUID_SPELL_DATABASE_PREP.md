# HaploBox: Complete Druid Spell Inventory – voorbereiding

**16 november 2026 · branch `jcdr-spell-database-prep` · WoW Forever build 1.60.1.70938 · NIET ingame getest**

## Resultaat
We hebben **59 unieke actieve of in de actuele clientdata vermelde abilities** verzameld, plus twee verwijderde Classic-spellnamen in een aparte sectie. Eén entry per naam, *niet* per rank; 34 entries bevatten voorlopige referentie-ranklevels, maar **Spell ID en rank-ID blijven leeg totdat ze ingame/tegen de actuele client geverifieerd zijn**. Deze totaaltelling is ons geharmoniseerde overzicht uit meerdere bronnen, niet een garantie van de actuele spellbook-inhoud per character.

Catalogus: `concept/druid_spell_inventory.lua`. Het bestand wordt niet in `HaploBox.toc` geladen en wijzigt dus niets in de TB19.1m Macro Menu-test.

## Afgesproken targeting
| Profiel | Macroregels / status |
|---|---|
| `dps_assist` | BOX ON: `/assist party1` + `/cast`; BOX OFF: normaal casten |
| `heal_party1` | Shift=self; friendly mouseover; BOX ON fallback `party1`, BOX OFF normale target |
| `buff_friendly_self` | Shift=self; friendly mouseover; friendly target; anders self. **Geen party1, zowel BOX ON als OFF** |
| `dispel_friendly_self` | Zelfde vriendelijke prioriteit, apart testen voor Curse/Poison |
| `group_buff_review` | Gift of the Wild: targetgroep/raid-effect beoordelen, nooit automatisch party1 |
| `resurrection_dead` | Revive/Rebirth: dood vriendelijk doel, **nooit** self-fallback |
| `form`, `self_cast`, `self_aoe` | Eigen spell/form/AoE, nooit party1 |
| `hostile_control` | CC/taunt target behouden, niet blind automatisch assisten |
| `ground_aoe` | Hurricane: gronddoel en channel, niet blind assisten |
| `feral_target_review` | Cat/Bear finisher/combo/next-melee, eerste ingame test vóór auto-assist |
| `passive_no_macro` | Omen of Clarity en Feline Grace: nooit een castmacro |

### Buff-voorbeeld
```
#showtooltip Mark of the Wild
/cast [mod:shift,@player][@mouseover,help,nodead][@target,help,nodead][@player] Mark of the Wild
```
Een vriendelijke NPC onder de muis kan aan `help` voldoen; alleen via partyframes buffen is de afgesproken workflow, maar party-only filtering blijft een aparte testbeslissing.

## Wat wijkt af van Classic?
- **Revive** bestaat als Forever out-of-combat resurrection; **Wild Growth**, **Lacerate**, **Primal Bite**, **Shifting Power** staan in de Forever talentgegevens.
- **Omen of Clarity** is baseline/passief; **Feline Grace** ook passief.
- **Faerie Fire (Feral)** is als apart talent verdwenen; `Faerie Fire` kan nu ook in vormen.
- **Tiger's Fury** is verdwenen in Forever volgens clientvergelijking. Geen macro voor oude Tiger's Fury genereren.
- Feral talenten en status volgen talentkeuze; spells die via quests geleerd worden horen alleen beschikbaar te zijn na daadwerkelijke aanlering.
- Sommige rankgegevens verschillen tussen recente communitybronnen, met name Lacerate, Ferocious Bite en Frenzied Regeneration. Die zijn slechts als referentie bedoeld en worden pas na verificatie door de generator gebruikt.

## Sources (fan sites, client-export; geen live spellbookcontrole)
- https://theforeverera.com/en/spells/druid/
- https://wowfdb.com/classes/druid/spells/
- https://wowfdb.com/classes/druid/balance/spells/
- https://wowfdb.com/classes/druid/feral-cat/spells/
- https://wowfdb.com/classes/druid/feral-bear/spells/
- https://wowfdb.com/classes/druid/restoration/spells/

## Structurele offline checks
- 59 entries, alle spellnamen, IDs en macronamen uniek.
- 57 actieve macro-aliases, **maximaal 16 tekens**; 2 passives zonder macro.
- 9 talent-spells, 7 quest-spells, 2 passives gemarkeerd.
- 34 voorlopige rank-levelsets voor latere validatie.
- 2 verwijderde Classic-namen apart, niet in actieve lijst.
- **Geen** spelcommando's/macrobewerking of UI-wijzigingen in deze voorbereidingsbranch.

## Na TB19.1m ingame test
1. Spells en ranks vergelijken met het echte Forever-spellbook (ook speciale talents en nieuwe spells).
2. Spell IDs/rank IDs valideren per actuele build, locale en getrainde ranks.
3. Aanpassingen aan de gespecialiseerde profielen (Feral, CC, ground AoE, resurrection, group buffs).
4. Pas na akkoord database koppelen aan het bestaande Macro Menu met spellbook-learned filtering, zoekfunctie en previews. Main en TB19.1m blijven intussen onaangeroerd.
