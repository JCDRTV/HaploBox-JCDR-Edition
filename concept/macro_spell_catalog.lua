-- PREPARATION ONLY - HaploBox JCDR Edition spell database draft (2026-11-16).
-- This file is NOT referenced by HaploBox.toc and is NOT loaded by the addon.
-- In-game behavior and spell availability have not been validated.
-- spellId is intentionally absent until confirmed against the WoW Forever client.
--
-- Profile contract:
-- dps_assist           BOX ON: /assist party1 then cast; BOX OFF: normal cast
-- heal_party1          BOX ON: Shift self > friendly mouseover > party1
--                      BOX OFF: Shift self > friendly mouseover > normal target
-- buff_friendly_self   BOTH modes: Shift self > friendly mouseover >
--                      friendly current target > self
-- self_cast            BOTH modes: ordinary self-cast, no party1
-- group_buff_candidate Same targeting idea as buff_friendly_self; verify
--                      per-spell group/class mechanics before implementing
-- aoe_buff_candidate   Ordinary cast; test per-spell behavior before implementing

return {
    schemaVersion = 1,
    statuses = {"existing_TB19_1m", "proposal", "needs_client_verification"},
    profiles = {
        dps_assist = {
            modeAware = true,
            boxOn = "#showtooltip {spell}\n/assist party1\n/cast {spell}",
            boxOff = "#showtooltip {spell}\n/cast {spell}",
        },
        heal_party1 = {
            modeAware = true,
            boxOn = "#showtooltip {spell}\n/cast [mod:shift,@player][@mouseover,help,nodead][@party1,help,nodead] {spell}",
            boxOff = "#showtooltip {spell}\n/cast [mod:shift,@player][@mouseover,help,nodead][] {spell}",
        },
        buff_friendly_self = {
            modeAware = false,
            boxOn = "#showtooltip {spell}\n/cast [mod:shift,@player][@mouseover,help,nodead][@target,help,nodead][@player] {spell}",
            boxOff = "#showtooltip {spell}\n/cast [mod:shift,@player][@mouseover,help,nodead][@target,help,nodead][@player] {spell}",
        },
        self_cast = {
            modeAware = false,
            boxOn = "#showtooltip {spell}\n/cast {spell}",
            boxOff = "#showtooltip {spell}\n/cast {spell}",
        },
        -- Do not generate these candidate profiles without client tests.
    },
    spells = {
        DRUID = {
            {id="wrath", spell="Wrath", macroName="HB Wrath", profile="dps_assist", status="existing_TB19_1m"},
            {id="moonfire", spell="Moonfire", macroName="HB Moonfire", profile="dps_assist", status="existing_TB19_1m"},
            {id="rejuvenation", spell="Rejuvenation", macroName="HB Rejuvenation", profile="heal_party1", status="existing_TB19_1m"},
            {id="healing_touch", spell="Healing Touch", macroName="HB Healing Touch", profile="heal_party1", status="proposal"},
            {id="regrowth", spell="Regrowth", macroName="HB Regrowth", profile="heal_party1", status="proposal"},
            {id="mark_of_the_wild", spell="Mark of the Wild", macroName="HB MotW", profile="buff_friendly_self", status="proposal"},
            {id="thorns", spell="Thorns", macroName="HB Thorns", profile="buff_friendly_self", status="proposal"},
            {id="gift_of_the_wild", spell="Gift of the Wild", macroName="HB Gift Wild", profile="group_buff_candidate", status="needs_client_verification"},
        },
        PRIEST = {
            {id="renew", spell="Renew", macroName="HB Renew", profile="heal_party1", status="proposal"},
            {id="power_word_fortitude", spell="Power Word: Fortitude", macroName="HB Fortitude", profile="buff_friendly_self", status="proposal"},
            {id="prayer_of_fortitude", spell="Prayer of Fortitude", macroName="HB Prayer Fort", profile="group_buff_candidate", status="needs_client_verification"},
        },
        MAGE = {
            {id="arcane_intellect", spell="Arcane Intellect", macroName="HB Arcane Int", profile="buff_friendly_self", status="proposal"},
            {id="arcane_brilliance", spell="Arcane Brilliance", macroName="HB Arc Brill", profile="group_buff_candidate", status="needs_client_verification"},
            {id="mage_armor", spell="Mage Armor", macroName="HB Mage Armor", profile="self_cast", status="proposal"},
        },
        PALADIN = {
            {id="flash_of_light", spell="Flash of Light", macroName="HB Flash Light", profile="heal_party1", status="proposal"},
            {id="blessing_of_might", spell="Blessing of Might", macroName="HB Bless Might", profile="buff_friendly_self", status="proposal"},
            {id="greater_blessing_of_might", spell="Greater Blessing of Might", macroName="HB Gr Bless M", profile="group_buff_candidate", status="needs_client_verification"},
        },
        SHAMAN = {
            {id="healing_wave", spell="Healing Wave", macroName="HB Healing Wave", profile="heal_party1", status="proposal"},
            {id="lightning_shield", spell="Lightning Shield", macroName="HB Light Shield", profile="self_cast", status="proposal"},
        },
        WARLOCK = {
            {id="demon_armor", spell="Demon Armor", macroName="HB Demon Armor", profile="self_cast", status="proposal"},
        },
        HUNTER = {
            {id="aspect_of_the_hawk", spell="Aspect of the Hawk", macroName="HB Hawk", profile="self_cast", status="proposal"},
        },
        WARRIOR = {
            {id="battle_shout", spell="Battle Shout", macroName="HB Battle Shout", profile="aoe_buff_candidate", status="needs_client_verification"},
        },
        ROGUE = {}, -- Add useful candidate macros only after class-specific review.
    },
}
