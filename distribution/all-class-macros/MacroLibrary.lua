-- JCDR Edition / TB19.1q SPELLBOOK UI: linked windows, direct pickup and
-- class spell cards. Blizzard actions always need explicit hardware input.
-- Existing personal macros and bindings are never overwritten silently.
local HB=HaploBox
local panel,bindingWindow,bindingNotice,notice,content,boxContent,spellContent,footer,tabButtons,rows,spellCards,bookHeading
local page="box"
local spellPage=1
local PER_PAGE=12  -- Two columns x six rows; preserves the existing icon size
local spellBook={};local scannedBook=false
local waiting,conflict=nil,nil
local BOX={
    {id="follow",name="HB Smart Follow",title="Smart Follow",kind="follow"},
    {id="assist",name="HB Assist",title="Assist",kind="boxassist"},
    {id="trade",name="HB Trade",title="Trade with Leader",kind="trade"},
    {id="role",name="HB Set Role",title="Set Role",kind="role"},
    {id="quickmenu",title="Quick Menu",kind="native",binding="HAPLOBOX_QUICK_TOGGLE"},
    {id="mainmini",title="Main / Mini UI",kind="native",binding="HAPLOBOX_HEAL_TOGGLE"},
}
-- Level 1-30 WoW Forever Druid active spell/ability presets. Class-quest,
-- trainer and talent actions can only be created if known by the character.
-- Passive skills are never listed or offered as a macro. More levels later.
-- kind: assist follows leader target only on follower BOX ON; heal uses
-- shift self > friendly mouseover > party1 on follower / self on leader.
-- cast never changes target; buff chooses friendly target/self; revive requires dead target.
local SMART={DRUID={
    {id="wrath",name="HB Wrath",title="Wrath",spell="Wrath",kind="assist",level=1,icon="Spell_Nature_AbolishMagic"},
    {id="moonfire",name="HB Moonfire",title="Moonfire",spell="Moonfire",kind="assist",level=4,icon="Spell_Nature_StarFall"},
    {id="starfire",name="HB Starfire",title="Starfire",spell="Starfire",kind="assist",level=20,icon="Spell_Arcane_StarFire"},
    {id="roots",name="HB Entangle",title="Entangling Roots",spell="Entangling Roots",kind="assist",level=8,icon="Spell_Nature_StrangleVines"},
    {id="hibernate",name="HB Hibernate",title="Hibernate",spell="Hibernate",kind="assist",level=18,icon="Spell_Nature_Sleep"},
    {id="faeriefire",name="HB Faerie Fire",title="Faerie Fire",spell="Faerie Fire",kind="assist",level=18,icon="Spell_Nature_FaerieFire"},
    {id="healingtouch",name="HB Healing Touch",title="Healing Touch",spell="Healing Touch",kind="heal",level=1,icon="Spell_Nature_HealingTouch"},
    {id="rejuvenation",name="HB Rejuvenation",title="Rejuvenation",spell="Rejuvenation",kind="heal",level=4,icon="Spell_Nature_Rejuvenation"},
    {id="regrowth",name="HB Regrowth",title="Regrowth",spell="Regrowth",kind="heal",level=12,icon="Spell_Nature_ResistNature"},
    {id="mark",name="HB Mark",title="Mark of the Wild",spell="Mark of the Wild",kind="buff",level=1,icon="Spell_Nature_Regeneration"},
    {id="thorns",name="HB Thorns",title="Thorns",spell="Thorns",kind="buff",level=6,icon="Spell_Nature_Thorns"},
    {id="curepoison",name="HB Cure Poison",title="Cure Poison",spell="Cure Poison",kind="buff",level=14,icon="Spell_Nature_NullifyPoison"},
    {id="revive",name="HB Revive",title="Revive",spell="Revive",kind="revive",level=12,icon="Spell_Nature_Resurrection"},
    {id="rebirth",name="HB Rebirth",title="Rebirth",spell="Rebirth",kind="revive",level=20,icon="Spell_Nature_Reincarnation"},
    {id="naturesgrasp",name="HB Nature Grasp",title="Nature's Grasp",spell="Nature's Grasp",kind="cast",level=10,icon="Spell_Nature_NaturesWrath"},
    {id="moonglade",name="HB Moonglade",title="Teleport: Moonglade",spell="Teleport: Moonglade",kind="cast",level=10,icon="Spell_Arcane_TeleportMoonglade"},
    {id="bear",name="HB Bear Form",title="Bear Form",spell="Bear Form",kind="cast",level=10,icon="Ability_Racial_BearForm"},
    {id="maul",name="HB Maul",title="Maul",spell="Maul",kind="assist",level=10,icon="Ability_Druid_Maul"},
    {id="growl",name="HB Growl",title="Growl",spell="Growl",kind="cast",level=10,icon="Ability_Physical_Taunt"},
    {id="demoroar",name="HB Demo Roar",title="Demoralizing Roar",spell="Demoralizing Roar",kind="cast",level=10,icon="Ability_Druid_DemoralizingRoar"},
    {id="enrage",name="HB Enrage",title="Enrage",spell="Enrage",kind="cast",level=12,icon="Ability_Druid_Enrage"},
    {id="bash",name="HB Bash",title="Bash",spell="Bash",kind="assist",level=14,icon="Ability_Druid_Bash"},
    {id="aquatic",name="HB Aquatic Form",title="Aquatic Form",spell="Aquatic Form",kind="cast",level=16,icon="Ability_Druid_AquaticForm"},
    {id="swipe",name="HB Swipe",title="Swipe",spell="Swipe",kind="cast",level=16,icon="INV_Misc_MonsterClaw_03"},
    {id="cat",name="HB Cat Form",title="Cat Form",spell="Cat Form",kind="cast",level=20,icon="Ability_Druid_CatForm"},
    {id="claw",name="HB Claw",title="Claw",spell="Claw",kind="assist",level=20,icon="Ability_Druid_Rake"},
    {id="rip",name="HB Rip",title="Rip",spell="Rip",kind="assist",level=20,icon="Ability_GhoulFrenzy"},
    {id="shred",name="HB Shred",title="Shred",spell="Shred",kind="assist",level=20,icon="Spell_Shadow_VampiricAura"},
    {id="prowl",name="HB Prowl",title="Prowl",spell="Prowl",kind="cast",level=20,icon="Ability_Ambush"},
    {id="omen",name="HB Omen",title="Omen of Clarity",spell="Omen of Clarity",kind="cast",level=20,icon="Spell_Nature_CrystalBall",passive=true},
    {id="feralcharge",name="HB Feral Charge",title="Feral Charge",spell="Feral Charge",kind="assist",level=20,icon="Ability_Hunter_Pet_Bear",optional=true},
    -- Forever 21-30: first-rank active spells only. Existing rank updates use
    -- the same macros, so never duplicate a spell just for a later rank.
    {id="sootheanimal",name="HB Soothe Animal",title="Soothe Animal",spell="Soothe Animal",kind="assist",level=22,icon="Ability_Hunter_BeastSoothe"},
    {id="rake",name="HB Rake",title="Rake",spell="Rake",kind="assist",level=24,icon="Ability_Druid_Disembowel"},
    {id="ferociousbite",name="HB Fero Bite",title="Ferocious Bite",spell="Ferocious Bite",kind="assist",level=24,icon="Ability_Druid_FerociousBite"},
    {id="removecurse",name="HB Remove Curse",title="Remove Curse",spell="Remove Curse",kind="buff",level=24,icon="Spell_Holy_RemoveCurse"},
    {id="tigersfury",name="HB Tiger Fury",title="Tiger's Fury",spell="Tiger's Fury",kind="cast",level=24,icon="Ability_Mount_JungleTiger"},
    {id="insectswarm",name="HB Insect Swarm",title="Insect Swarm",spell="Insect Swarm",kind="assist",level=25,icon="Spell_Nature_InsectSwarm",optional=true},
    {id="lacerate",name="HB Lacerate",title="Lacerate",spell="Lacerate",kind="assist",level=25,icon="Ability_Druid_Lacerate",optional=true},
    {id="abolishpoison",name="HB AbolishPois",title="Abolish Poison",spell="Abolish Poison",kind="buff",level=26,icon="Spell_Nature_NullifyPoison_02"},
    {id="dash",name="HB Dash",title="Dash",spell="Dash",kind="cast",level=26,icon="Ability_Druid_Dash"},
    {id="challengingroar",name="HB Chall Roar",title="Challenging Roar",spell="Challenging Roar",kind="cast",level=28,icon="Ability_Druid_ChallangingRoar"},
    {id="cower",name="HB Cower",title="Cower",spell="Cower",kind="cast",level=28,icon="Ability_Druid_Cower"},
    {id="travelform",name="HB Travel Form",title="Travel Form",spell="Travel Form",kind="cast",level=30,icon="Ability_Druid_TravelForm"},
    {id="tranquility",name="HB Tranquility",title="Tranquility",spell="Tranquility",kind="cast",level=30,icon="Spell_Nature_Tranquility"},
    {id="naturesswiftness",name="HB Nature Swift",title="Nature's Swiftness",spell="Nature's Swiftness",kind="cast",level=30,icon="Spell_Nature_RavenForm",optional=true},
}}
local function me() return UnitClass and select(2,UnitClass("player")) end
-- HF26.20.54: learned active class spells, with stable IDs and safe defaults.
-- Existing Druid presets above remain authoritative, including macro names.
local scanSpellbook
local RULES={}
local function rules(class,kind,names)
    RULES[class]=RULES[class] or {}
    for name in names:gmatch("[^|]+") do RULES[class][name:lower()]=kind end
end
rules("WARRIOR","assist","Heroic Strike|Charge|Rend|Hamstring|Overpower|Sunder Armor|Revenge|Shield Bash|Taunt|Mocking Blow|Execute|Mortal Strike|Bloodthirst|Slam|Pummel|Intercept|Disarm|Shield Slam|Concussion Blow")
rules("WARRIOR","cast","Battle Stance|Defensive Stance|Berserker Stance|Battle Shout|Demoralizing Shout|Challenging Shout|Thunder Clap|Cleave|Whirlwind|Shield Block|Shield Wall|Retaliation|Recklessness|Bloodrage|Berserker Rage|Sweeping Strikes|Last Stand|Death Wish")
rules("PALADIN","heal","Holy Light|Flash of Light|Lay on Hands")
rules("PALADIN","dual","Holy Shock")
rules("PALADIN","buff","Blessing of Might|Blessing of Wisdom|Blessing of Protection|Blessing of Freedom|Blessing of Salvation|Blessing of Sanctuary|Blessing of Light|Blessing of Kings|Blessing of Sacrifice|Greater Blessing of Might|Greater Blessing of Wisdom|Greater Blessing of Kings|Greater Blessing of Salvation|Greater Blessing of Sanctuary|Greater Blessing of Light|Purify|Cleanse")
rules("PALADIN","revive","Redemption|Resurrection")
rules("PALADIN","assist","Judgement|Judgment|Exorcism|Hammer of Justice|Hammer of Wrath|Turn Undead|Repentance|Crusader Strike|Judgement of Light|Judgement of Wisdom|Judgement of Justice")
rules("PALADIN","cast","Devotion Aura|Retribution Aura|Concentration Aura|Shadow Resistance Aura|Frost Resistance Aura|Fire Resistance Aura|Sanctity Aura|Seal of Righteousness|Seal of the Crusader|Seal of Command|Seal of Justice|Seal of Light|Seal of Wisdom|Divine Shield|Divine Protection|Divine Favor|Holy Shield|Consecration|Righteous Fury|Holy Wrath|Summon Warhorse|Summon Charger")
rules("HUNTER","assist","Auto Shot|Arcane Shot|Serpent Sting|Concussive Shot|Multi-Shot|Aimed Shot|Scatter Shot|Wyvern Sting|Scorpid Sting|Viper Sting|Distracting Shot|Hunter's Mark|Wing Clip|Raptor Strike|Mongoose Bite|Counterattack|Tranquilizing Shot|Kill Command|Kill Shot|Steady Shot|Explosive Shot|Black Arrow|Intimidation|Flare")
rules("HUNTER","cast","Aspect of the Hawk|Aspect of the Monkey|Aspect of the Cheetah|Aspect of the Pack|Aspect of the Beast|Aspect of the Wild|Mend Pet|Revive Pet|Call Pet|Dismiss Pet|Feed Pet|Tame Beast|Eyes of the Beast|Beast Lore|Scare Beast|Feign Death|Disengage|Freezing Trap|Frost Trap|Immolation Trap|Explosive Trap|Rapid Fire|Bestial Wrath|Trueshot Aura|Volley|Eagle Eye")
rules("ROGUE","assist","Sinister Strike|Eviscerate|Gouge|Backstab|Ambush|Garrote|Rupture|Cheap Shot|Kidney Shot|Kick|Hemorrhage|Ghostly Strike|Riposte|Blind|Expose Armor|Sap|Pick Pocket|Shiv|Mutilate|Envenom")
rules("ROGUE","cast","Stealth|Vanish|Sprint|Evasion|Feint|Slice and Dice|Preparation|Cold Blood|Blade Flurry|Adrenaline Rush|Premeditation|Distract|Pick Lock|Detect Traps|Disarm Trap")
rules("PRIEST","heal","Lesser Heal|Heal|Greater Heal|Flash Heal|Renew|Power Word: Shield|Desperate Prayer|Penance")
rules("PRIEST","dual","Dispel Magic")
rules("PRIEST","buff","Power Word: Fortitude|Prayer of Fortitude|Divine Spirit|Prayer of Spirit|Shadow Protection|Prayer of Shadow Protection|Cure Disease|Abolish Disease|Fear Ward|Power Infusion")
rules("PRIEST","revive","Resurrection")
rules("PRIEST","assist","Smite|Holy Fire|Shadow Word: Pain|Mind Blast|Mind Flay|Mana Burn|Shackle Undead|Mind Control|Silence|Devouring Plague|Vampiric Touch|Shadow Word: Death")
rules("PRIEST","cast","Inner Fire|Fade|Psychic Scream|Prayer of Healing|Holy Nova|Shadowform|Vampiric Embrace|Inner Focus|Lightwell|Levitate|Mind Vision|Spirit of Redemption")
rules("SHAMAN","heal","Healing Wave|Lesser Healing Wave|Chain Heal|Riptide")
rules("SHAMAN","buff","Water Walking|Water Breathing|Cure Poison|Cure Disease|Cleanse Spirit|Earth Shield")
rules("SHAMAN","revive","Ancestral Spirit")
rules("SHAMAN","assist","Lightning Bolt|Chain Lightning|Earth Shock|Flame Shock|Frost Shock|Purge|Stormstrike|Lightning Lasso|Lava Burst|Lava Lash|Hex")
rules("SHAMAN","cast","Ghost Wolf|Lightning Shield|Water Shield|Rockbiter Weapon|Flametongue Weapon|Frostbrand Weapon|Windfury Weapon|Astral Recall|Far Sight|Reincarnation|Elemental Mastery|Nature's Swiftness|Call of the Elements|Call of the Ancestors|Call of the Spirits")
rules("MAGE","assist","Fireball|Frostbolt|Arcane Missiles|Fire Blast|Scorch|Pyroblast|Polymorph|Counterspell|Cone of Cold|Arcane Blast|Ice Lance|Living Bomb|Frostfire Bolt")
rules("MAGE","buff","Arcane Intellect|Arcane Brilliance|Dampen Magic|Amplify Magic|Remove Lesser Curse|Remove Curse|Slow Fall")
rules("MAGE","cast","Frost Nova|Arcane Explosion|Flamestrike|Blizzard|Blast Wave|Ice Block|Ice Barrier|Mana Shield|Fire Ward|Frost Ward|Mage Armor|Ice Armor|Frost Armor|Molten Armor|Blink|Evocation|Presence of Mind|Arcane Power|Combustion|Cold Snap|Summon Water Elemental")
rules("WARLOCK","assist","Shadow Bolt|Corruption|Immolate|Curse of Agony|Curse of Weakness|Curse of Recklessness|Curse of Tongues|Curse of Elements|Curse of Shadow|Curse of Doom|Fear|Banish|Drain Life|Drain Soul|Drain Mana|Searing Pain|Shadowburn|Conflagrate|Death Coil|Siphon Life|Unstable Affliction|Incinerate|Haunt")
rules("WARLOCK","buff","Unending Breath|Detect Lesser Invisibility|Detect Invisibility|Detect Greater Invisibility")
rules("WARLOCK","cast","Life Tap|Dark Pact|Demon Armor|Demon Skin|Fel Armor|Health Funnel|Sacrifice|Demonic Sacrifice|Soul Link|Summon Imp|Summon Voidwalker|Summon Succubus|Summon Felhunter|Summon Felguard|Summon Dreadsteed|Summon Felsteed|Enslave Demon|Ritual of Summoning|Ritual of Doom|Hellfire|Rain of Fire|Howl of Terror|Shadow Ward|Create Healthstone|Create Soulstone|Create Firestone|Create Spellstone|Soulstone Resurrection")
rules("DRUID","assist","Faerie Fire (Feral)|Feral Faerie Fire|Pounce|Ravage|Mangle|Mangle (Bear)|Mangle (Cat)|Cyclone|Hurricane|Moonfire|Wrath|Starfire")
rules("DRUID","heal","Swiftmend|Nourish|Lifebloom|Wild Growth")
rules("DRUID","buff","Gift of the Wild|Innervate|Remove Curse|Remove Corruption")
rules("DRUID","revive","Revive|Rebirth")
rules("DRUID","cast","Dire Bear Form|Moonkin Form|Tree of Life|Barkskin|Frenzied Regeneration|Frenzied Regeneration (Bear)|Nature's Swiftness|Tiger's Fury")
local function kindFor(class,key)
    local rule=RULES[class] and RULES[class][key]
    if rule then return rule end
    -- Stances, auras, seals, totems, traps, teleports and unknown/custom
    -- spells remain ordinary local casts. Never infer targeting from a name.
    return "cast"
end
local function spellHash(s)
    local h=0
    for i=1,#s do h=(h*131+s:byte(i))%4294967296 end
    return h
end
local function autoEntry(class,data,key,reserved)
    if not data.name or data.name:find("[%c|;%[%]]") then return nil end
    local h=spellHash(class..":"..key)
    local clean=data.name:gsub("[^%w ]",""):gsub("%s+"," "):match("^%s*(.-)%s*$")
    local name="HB "..clean
    if #clean==0 or clean~=data.name or #name>16 or reserved[name] then
        local prefix=clean:sub(1,7):gsub("%s+$","")
        if prefix=="" then prefix="Spell" end
        name="HB "..prefix.." "..string.format("%05X",h%1048576)
    end
    if reserved[name] then return nil end
    return {id="auto"..class..string.format("%08X",h),name=name,title=data.name,
        spell=data.name,kind=kindFor(class,key),auto=true}
end
-- Stable legacy presets plus live spellbook entries. No macro or binding
-- is created by a scan, and the general/profession tab is not imported.
local function activeSpells()
    if not scannedBook and scanSpellbook then scanSpellbook() end
    local class=me()
    local out,seen,reserved,ids={},{},{},{}
    for _,entry in ipairs(BOX) do if entry.name then reserved[entry.name]=true end end
    for _,entry in ipairs(SMART[class] or {}) do
        local key=entry.spell:lower()
        seen[key]=true;reserved[entry.name]=true;ids[entry.id]=true
        local learned=spellBook[key]
        if not entry.passive and not (learned and learned.passive) then
            out[#out+1]=entry
        end
    end
    local keys={}
    for key in pairs(spellBook) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local data=spellBook[key]
        local explicit=RULES[class] and RULES[class][key]
        if class and RULES[class] and not seen[key] and data.passive==false and
           (data.tab>1 or explicit) then
            local entry=autoEntry(class,data,key,reserved)
            if entry and not ids[entry.id] then
                out[#out+1]=entry;reserved[entry.name]=true;ids[entry.id]=true
            end
        end
    end
    return out
end
local function locked() return InCombatLockdown and InCombatLockdown() end
local function say(message)
    if notice then notice:SetText(message) end
    if bindingNotice then bindingNotice:SetText(message) end
    if HB.print then HB.print(message) end
end
local function bindingAction(entry)
    return entry.binding or ("MACRO "..entry.name)
end
local function keyFor(entry)
    if not GetBindingKey then return nil,nil end
    local ok,a,b=pcall(GetBindingKey,bindingAction(entry))
    if ok then return a,b end
end
local function macroIndex(name)
    if not GetMacroIndexByName then return nil end
    local ok,idx=pcall(GetMacroIndexByName,name)
    if ok and type(idx)=="number" and idx>0 then return idx end
end
local function myRegistry()
    local key=HB.Norm and HB.UnitIdent and HB.Norm(HB.UnitIdent("player"))
    return key and HB.db and HB.db.boxMacros and HB.db.boxMacros[key]
end
local function owned(entry)
    -- A native key action is owned by HaploBox's Bindings.xml, not a macro.
    if entry.kind=="native" then return true,nil end
    local idx=macroIndex(entry.name)
    if not idx then return false,nil end
    if entry.id=="follow" then
        local key=HB.Norm and HB.UnitIdent and HB.Norm(HB.UnitIdent("player"))
        return (key and HB.db and HB.db.smartFollowOwners and HB.db.smartFollowOwners[key]) and true or false,idx
    end
    local reg=myRegistry()
    local item=reg and reg[entry.name]
    if not item or not GetMacroBody then return false,idx end
    local ok,body=pcall(GetMacroBody,idx)
    local match=HB.SameMacroBody or function(a,b) return a==b end
    local valid=ok and (match(body,item.offBody) or match(body,item.onBody) or
        match(body,item.leaderBody) or match(body,item.legacyBody))
    return not not valid,idx
end
local function allEntries()
    return page=="box" and BOX or activeSpells()
end
local function preset(id)
    for _,entry in ipairs(BOX) do if entry.id==id then return entry end end
    for _,entry in ipairs(activeSpells()) do if entry.id==id then return entry end end
end
function HB.MacroLibraryEntries(section)
    if section=="spells" then return activeSpells() end
    return BOX
end
-- Read the actual spellbook rather than depending on GetSpellInfo(name),
-- which is inconsistent on several 1.x/Forever clients. Do not claim a
-- quest spell has been learned just because the character is level 20.
scanSpellbook=function()
    spellBook={};scannedBook=false
    if not GetNumSpellTabs or not GetSpellTabInfo then return end
    local ok,tabs=pcall(GetNumSpellTabs)
    if not ok or type(tabs)~="number" then return end
    local bookType=BOOKTYPE_SPELL or "spell"
    local total=0
    for tab=1,tabs do
        local tabok,_,__,offset,count=pcall(GetSpellTabInfo,tab)
        if tabok and type(offset)=="number" and type(count)=="number" then
            for slot=offset+1,offset+count do
                local name,rank
                if GetSpellBookItemName then
                    local worked,n,r=pcall(GetSpellBookItemName,slot,bookType)
                    if worked then name,rank=n,r end
                end
                if not name and GetSpellName then
                    local worked,n,r=pcall(GetSpellName,slot,bookType)
                    if worked then name,rank=n,r end
                end
                local texture
                if GetSpellBookItemTexture then
                    local worked,art=pcall(GetSpellBookItemTexture,slot,bookType)
                    if worked then texture=art end
                end
                local itemType
                if GetSpellBookItemInfo then
                    local worked,t=pcall(GetSpellBookItemInfo,slot,bookType)
                    if worked then itemType=t end
                end
                if type(name)=="string" and name~="" and
                   itemType~="FUTURESPELL" and itemType~="FLYOUT" then
                    local key=name:lower()
                    local passive
                    if IsPassiveSpell then
                        local worked,flag=pcall(IsPassiveSpell,slot,bookType)
                        if worked and type(flag)=="boolean" then passive=flag
                        elseif worked and (flag==0 or flag==1) then passive=flag==1 end
                    end
                    if passive==nil and C_SpellBook and C_SpellBook.IsSpellBookItemPassive and
                       Enum and Enum.SpellBookSpellBank then
                        local worked,flag=pcall(C_SpellBook.IsSpellBookItemPassive,slot,Enum.SpellBookSpellBank.Player)
                        if worked and type(flag)=="boolean" then passive=flag end
                    end
                    local prev=spellBook[key]
                    local rn=tonumber(type(rank)=="string" and rank:match("%d+") or "") or 0
                    local pn=prev and prev.rankNumber or -1
                    if not prev or rn>=pn then
                        spellBook[key]={name=name,texture=texture,slot=slot,rank=rank,
                            rankNumber=rn,tab=tab,passive=passive}
                    end
                    total=total+1
                end
            end
        end
    end
    scannedBook=total>0
end
local function spellKnown(entry)
    if not entry.spell then return true end
    if entry.passive then return false end
    if not scannedBook then scanSpellbook() end
    local data=spellBook[entry.spell:lower()]
    return data~=nil and data.passive~=true
end
function HB.EnsureMacroPreset(id)
    local entry=preset(id)
    if not entry then say("Preset not available in this menu.") return false end
    if locked() then say("Create macros after combat.") return false end
    -- Native UI actions are declared in Bindings.xml. They never occupy
    -- Blizzard macro slots or touch the managed spell registry.
    if entry.kind=="native" then return true end
    if entry.kind=="follow" then
        if not HB.PrepareSmartFollow or not HB.PrepareSmartFollow() then
            say("Could not prepare Smart Follow.") return false end
        say("Smart Follow ready. Bind a key in this menu.")
        return true
    end
    local exists,idx=owned(entry)
    if idx then
        if entry.spell then
            -- An explicit click can reconcile a standard old /cast-only macro
            -- to follower BOX ON, including when ownership data was lost.
            -- Never adopt or modify arbitrary macros with the same name.
            local good,reason=HB.EnsureKnownBoxSpell and
                HB.EnsureKnownBoxSpell(entry.name,entry.spell,entry.kind)
            if not good then say(reason or (entry.name.." cannot be safely synchronized.")) return false end
            say(entry.name.." ready for current BOX profile.")
            return true
        end
        if not exists then say(entry.name.." exists but is not an unchanged HB macro. Not overwritten.") return false end
        say(entry.name.." already exists.")
        return true
    end
    if entry.passive then say(entry.title.." is passive and needs no macro.") return false end
    if not spellKnown(entry) then say("Not learned yet (trainer, quest or talent): "..entry.title) return false end
    local ok
    if entry.spell then ok=HB.AddBoxSpell and HB.AddBoxSpell(entry.spell,entry.kind,entry.name)
    else ok=HB.AddBoxAction and HB.AddBoxAction(entry.id) end
    if not ok then say("Could not create "..entry.name) return false end
    say(entry.name.." created.")
    return true
end
function HB.PickupMacroPreset(id)
    if locked() then say("Pick up macros after combat.") return false end
    local entry=preset(id)
    if not entry then return false end
    local own,idx=owned(entry)
    if not idx then say("Create the HB macro first; personal macros are untouched.") return false end
    if entry.spell then
        -- Keep the selected action bar macro synchronized to the active mode.
        -- Failed verification must NOT put an unsafe /cast-only macro on cursor.
        if not HB.EnsureMacroPreset(id) then return false end
    elseif not own then
        say("Existing macro is not a verified HB macro. Not picked up.") return false
    end
    if not PickupMacro then say("Blizzard PickupMacro API unavailable.") return false end
    local ok,result=pcall(PickupMacro,idx)
    if not ok or result==false then say("Could not pick up macro.") return false end
    say("Macro on cursor. Place it on a Blizzard action bar.")
    return true
end

local function bindKey(entry,slot,key,confirm)
    if locked() then say("Change bindings after combat.") return false end
    if not SetBinding or not SaveBindings or not GetCurrentBindingSet or not GetBindingAction or
        (entry.kind~="native" and not SetBindingMacro) then
        say("Blizzard binding API unavailable.") return false end
    if not HB.EnsureMacroPreset(entry.id) then return false end
    local first,second=keyFor(entry)
    local old=(slot==1 and first or second)
    if key=="" then
        if not old then return true end
        if not SetBinding or not SetBinding(old) then say("Unable to clear binding.") return false end
        SaveBindings(GetCurrentBindingSet());return true
    end
    local action=GetBindingAction(key)
    if action and action~="" and action~=bindingAction(entry) and not confirm then
        conflict={id=entry.id,slot=slot,key=key}
        say(key.." is assigned to "..tostring(action)..". Click the same key box again to CONFIRM replacement.")
        return false
    end
    -- Preserve a secondary binding if the primary changes (and vice versa).
    local success
    if entry.kind=="native" then success=SetBinding(key,entry.binding)
    else success=SetBindingMacro(key,entry.name) end
    if not success then say("Cannot bind "..key) return false end
    if old and old~=key and SetBinding then SetBinding(old) end
    SaveBindings(GetCurrentBindingSet())
    conflict=nil
    say(entry.title.." bound to "..key.." on this client.")
    return true
end
local function namedButton(parent,text,x,y,w,h,handler)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w,h);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b:SetText(text)
    b:SetScript("OnClick",handler)
    if HB.MenuStyle then HB.MenuStyle.Button(b,"blue") end
    return b
end
local function label(parent,text,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetWidth(width or 300);f:SetJustifyH("LEFT")
    f:SetText(text or "")
    return f
end
local function roundIcon(parent,x,y,size)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(size,size);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b.tex=b:CreateTexture(nil,"ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    return b
end
local function setIcon(tex,entry)
    if not entry or not entry.spell then return end
    local data=spellBook[entry.spell:lower()]
    local texture=data and data.texture
    if not texture and GetSpellTexture then
        local ok,art=pcall(GetSpellTexture,entry.spell)
        if ok then texture=art end
    end
    if not texture and GetSpellInfo then
        local ok,_,__,art=pcall(GetSpellInfo,entry.spell)
        if ok then texture=art end
    end
    -- Concrete fallback icons prevent a wall of red question marks even if
    -- this client cannot resolve spell textures by name before learning them.
    if not texture and entry.icon then texture="Interface\\Icons\\"..entry.icon end
    tex:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
end
-- TB19.1q: popup windows share one placement calculation in ControlBar.lua.
-- If Quick Menu is open the Macro Menu attaches immediately to its right.
local function resetPlacement()
    if not panel then return end
    if HB.PositionMacroMenu then HB.PositionMacroMenu(true)
    else
        panel:ClearAllPoints()
        local quick=_G.HaploBoxControlsFlyout
        local party=_G.HaploBoxControlsPanel
        local target=quick and quick:IsShown() and quick or party
        if target then panel:SetPoint("TOPLEFT",target,"TOPRIGHT",7,0)
        else panel:SetPoint("TOPLEFT",UIParent,"TOPLEFT",15,-45) end
    end
end
local function setPage(which)
    page=which;waiting=nil;conflict=nil
    if which=="spells" then scanSpellbook() end
    if HB.RefreshMacroMenu then HB.RefreshMacroMenu() end
end
local function makeKeyButton(parent,entry,slot,x,y)
    local b=namedButton(parent,"Not Bound",x,y,93,23,function(self)
        if conflict and conflict.id==entry.id and conflict.slot==slot then
            bindKey(entry,slot,conflict.key,true)
            conflict=nil
            if HB.RefreshMacroMenu then HB.RefreshMacroMenu() end
            return
        end
        conflict=nil
        if not bindingWindow then return end
        waiting={entry=entry,slot=slot}
        say("Press a key for "..entry.title.." (ESC cancels; BACKSPACE removes binding).")
        bindingWindow:EnableKeyboard(true)
        if bindingWindow.SetPropagateKeyboardInput then bindingWindow:SetPropagateKeyboardInput(false) end
        if bindingWindow.SetKeyboardFocus then bindingWindow:SetKeyboardFocus() end -- optional API
        self:SetText("Press key...")
    end)
    b.entry,b.slot=entry,slot
    return b
end
local function refreshKeyWidgets(row,entry)
    local first,second=keyFor(entry)
    row.key1:SetText(first or "Not Bound")
    if row.key2 then row.key2:SetText(second or "Not Bound") end
end
local function makePanel()
    if panel then return end
    panel=CreateFrame("Frame","HaploBoxMacroLibrary",UIParent)
    panel.hbMenuName="MacroMenu"
    panel:SetSize(680,525);panel:SetFrameStrata("DIALOG")
    if HB.MenuStyle then HB.MenuStyle.Window(panel,32) end
    panel:SetClampedToScreen(true);panel:SetMovable(true);panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",function(self)
        if HB.db and HB.db.submenuLocks and HB.db.submenuLocks.MacroMenu==false and
           not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
    end)
    panel:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        if not (HB.db and HB.db.submenuLocks and HB.db.submenuLocks.MacroMenu==false) then return end
        local w,h=UIParent:GetWidth(),UIParent:GetHeight()
        local l,t=self:GetLeft(),self:GetTop()
        if l and t and w and h and w>0 and h>0 then
            local scale=self:GetEffectiveScale()/(UIParent:GetEffectiveScale() or 1)
            HB.db.submenuPositions=HB.db.submenuPositions or {}
            HB.db.submenuPositions.MacroMenu={
                math.max(0,math.min(0.97,l*scale/w)),
                math.max(0,math.min(0.97,1-t*scale/h)),
            }
        end
    end)
    panel:SetScript("OnHide",function(self)
        self:EnableKeyboard(false)
        waiting=nil;conflict=nil
    end)
    local function captureKey(self,key)
        local w=waiting
        if not w then return end
        waiting=nil;self:EnableKeyboard(false)
        if key=="ESCAPE" then say("Keybinding cancelled.")
        else
            local value=key
            if key=="BACKSPACE" or key=="DELETE" then value=""
            elseif key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then
                say("Modifier alone is not a keybinding. Try a combination.")
                HB.RefreshMacroMenu();return
            else
                if IsControlKeyDown and IsControlKeyDown() then value="CTRL-"..value end
                if IsAltKeyDown and IsAltKeyDown() then value="ALT-"..value end
                if IsShiftKeyDown and IsShiftKeyDown() then value="SHIFT-"..value end
            end
            bindKey(w.entry,w.slot,value,false)
        end
        HB.RefreshMacroMenu()
    end
    panel:SetScript("OnKeyDown",captureKey)
    panel:EnableKeyboard(false)
    local bg=panel:CreateTexture(nil,"BACKGROUND")
    -- TB19.1r: the spellbook is a LAYOUT, not a parchment skin.
    bg:SetAllPoints();bg:SetColorTexture(0.095,0.11,0.14,0.99)
    local goldTrim=panel:CreateTexture(nil,"OVERLAY")
    goldTrim:SetPoint("TOPLEFT",panel,"TOPLEFT",5,-31)
    goldTrim:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-5,-31)
    goldTrim:SetHeight(2);goldTrim:SetColorTexture(0.72,0.54,0.24,0.94)
    local heading=label(panel,"HaploBox - JCDR Edition | Macro Menu",16,-16,520)
    heading:SetTextColor(1,0.83,0.32)
    panel.heading=heading
    local close=namedButton(panel,"X",634,-7,30,22,function() panel:Hide() end)
    panel.closeButton=close
    local lock=namedButton(panel,"L",598,-7,30,22,function(self)
        if InCombatLockdown and InCombatLockdown() then say("Change menu lock after combat.") return end
        HB.db.submenuLocks=HB.db.submenuLocks or {}
        local wasLocked=HB.db.submenuLocks.MacroMenu~=false
        if not wasLocked then
            local dragstop=panel:GetScript("OnDragStop")
            if dragstop then dragstop(panel) end
        end
        HB.db.submenuLocks.MacroMenu=not wasLocked
        if HB.MenuStyle then HB.MenuStyle.LockButton(self,not wasLocked)
        else self:SetText(wasLocked and "U" or "L") end
    end)
    panel:HookScript("OnShow",function()
        local isLocked=not (HB.db.submenuLocks and HB.db.submenuLocks.MacroMenu==false)
        if HB.MenuStyle then HB.MenuStyle.LockButton(lock,isLocked)
        else lock:SetText(isLocked and "L" or "U") end
    end)
    -- HF13: separate binding window, backed by the *existing* keybind engine.
    -- No keybind data is copied/rewritten merely by opening this window.
    bindingWindow=CreateFrame("Frame","HaploBoxKeybindingsWindow",UIParent)
    bindingWindow.hbMenuName="HaploBoxKeybindings"
    bindingWindow:SetSize(680,382);bindingWindow:SetFrameStrata("DIALOG")
    bindingWindow:SetClampedToScreen(true);bindingWindow:SetMovable(true)
    bindingWindow:EnableMouse(true);bindingWindow:RegisterForDrag("LeftButton")
    if HB.MenuStyle then HB.MenuStyle.Window(bindingWindow,32) end
    local bindingHeading=label(bindingWindow,"HaploBox - JCDR Edition | Keybindings",16,-16,520)
    bindingHeading:SetTextColor(1,0.83,0.32)
    namedButton(bindingWindow,"X",634,-7,30,22,function() bindingWindow:Hide() end)
    -- Saved locations inherited from the original shared popup once.
    HB.db.submenuPositions=HB.db.submenuPositions or {}
    local old=HB.db.submenuPositions.MacroKeybindings
    if type(old)=="table" and not HB.db.submenuPositions.MacroMenu then
        HB.db.submenuPositions.MacroMenu={old[1],old[2]}
    end
    if type(old)=="table" and not HB.db.submenuPositions.HaploBoxKeybindings then
        HB.db.submenuPositions.HaploBoxKeybindings={old[1],old[2]}
    end
    local function saveBindingPosition(self)
        local w,h=UIParent:GetWidth(),UIParent:GetHeight()
        local l,t=self:GetLeft(),self:GetTop()
        if l and t and w and h and w>0 and h>0 then
            local scale=self:GetEffectiveScale()/(UIParent:GetEffectiveScale() or 1)
            HB.db.submenuPositions.HaploBoxKeybindings={
                math.max(0,math.min(0.97,l*scale/w)),
                math.max(0,math.min(0.97,1-t*scale/h))}
        end
    end
    local bindingLock=namedButton(bindingWindow,"L",598,-7,30,22,function(self)
        if InCombatLockdown and InCombatLockdown() then say("Change menu lock after combat.");return end
        HB.db.submenuLocks=HB.db.submenuLocks or {}
        local wasLocked=HB.db.submenuLocks.HaploBoxKeybindings~=false
        if not wasLocked then saveBindingPosition(bindingWindow) end
        HB.db.submenuLocks.HaploBoxKeybindings=not wasLocked
        if HB.MenuStyle then HB.MenuStyle.LockButton(self,not wasLocked)
        else self:SetText(wasLocked and "U" or "L") end
    end)
    bindingWindow:HookScript("OnShow",function()
        local isLocked=not (HB.db.submenuLocks and HB.db.submenuLocks.HaploBoxKeybindings==false)
        if HB.MenuStyle then HB.MenuStyle.LockButton(bindingLock,isLocked)
        else bindingLock:SetText(isLocked and "L" or "U") end
    end)
    bindingWindow:SetScript("OnDragStart",function(self)
        if HB.db.submenuLocks and HB.db.submenuLocks.HaploBoxKeybindings==false and
           not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
    end)
    bindingWindow:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        if HB.db.submenuLocks and HB.db.submenuLocks.HaploBoxKeybindings==false then
            saveBindingPosition(self)
        end
    end)
    bindingWindow:SetScript("OnHide",function(self)
        self:EnableKeyboard(false);waiting=nil;conflict=nil
    end)
    bindingWindow:SetScript("OnKeyDown",captureKey)
    bindingWindow:EnableKeyboard(false)
    tabButtons={}
    tabButtons.box=namedButton(panel,"Multibox",16,-48,130,25,function()setPage("box")end)
    tabButtons.spells=namedButton(panel,"Smart Spells",155,-48,140,25,function()setPage("spells")end)
    for _,tab in pairs(tabButtons) do
        tab.activeLine=tab:CreateTexture(nil,"OVERLAY")
        tab.activeLine:SetPoint("BOTTOMLEFT",tab,"BOTTOMLEFT",4,1)
        tab.activeLine:SetPoint("BOTTOMRIGHT",tab,"BOTTOMRIGHT",-4,1)
        tab.activeLine:SetHeight(3)
        tab.activeLine:SetColorTexture(1,0.71,0.19,1)
    end
    content=CreateFrame("Frame",nil,panel)
    content:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-83)
    content:SetSize(654,375)
    boxContent=CreateFrame("Frame",nil,content)
    boxContent:SetAllPoints(content)
    spellContent=CreateFrame("Frame",nil,content)
    spellContent:SetAllPoints(content)
    spellContent:Hide()
    rows={}
    label(boxContent,"FUNCTION",10,-3,200)
    label(boxContent,"KEYBINDING",337,-3,130)
    for i,entry in ipairs(BOX) do
        local y=-24-(i-1)*38
        local row=CreateFrame("Frame",nil,boxContent)
        row:SetSize(654,36);row:SetPoint("TOPLEFT",boxContent,"TOPLEFT",0,y)
        local fill=row:CreateTexture(nil,"BACKGROUND")
        fill:SetAllPoints();fill:SetColorTexture(0.12,0.16,0.21,0.93)
        row.title=label(row,entry.title,10,-12,240)
        row.key1=makeKeyButton(row,entry,1,333,-6)
        -- Secondary legacy Blizzard binding is preserved; only one key box is displayed.
        row.key2=false
        row.create=namedButton(row,"Create",440,-6,71,23,function()
            HB.EnsureMacroPreset(entry.id);HB.RefreshMacroMenu()
        end)
        row.pick=namedButton(row,"Pick Up",520,-6,78,23,function()
            HB.PickupMacroPreset(entry.id)
        end)
        row.create:Hide();row.pick:Hide()
        local tips={
            follow="Follows the correct party member when you press the key. Direct: Follow the Group Leader. Dungeon: Healer follows the Group Leader; DPS follows the Healer.",
            assist="Targets the same enemy as the Group Leader.",
            trade="Opens a trade window with the Group Leader.",
            role="Assigns your Blizzard party role using the current team setup. Other users must assign their roles manually for now. Custom team configurations are planned for a future update.",
            quickmenu="Opens or closes the HaploBox Quick Menu.",
            mainmini="Switches between the Main UI and Mini UI. If you switch during combat, the UI changes automatically after combat ends.",
        }
        row:EnableMouse(true)
        row:SetScript("OnEnter",function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(entry.title,1,0.82,0.42)
                GameTooltip:AddLine(tips[entry.id] or "",0.88,0.88,0.88,true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row.key1:SetScript("OnEnter",row:GetScript("OnEnter"))
        row.key1:SetScript("OnLeave",row:GetScript("OnLeave"))
        rows[i]=row
    end
    -- Dedicated keybinding rows are parented to the separate Keybindings
    -- window. Macro Menu still owns only its Spellbook/Smart Spells page.
    boxContent:SetParent(bindingWindow)
    boxContent:ClearAllPoints()
    boxContent:SetPoint("TOPLEFT",bindingWindow,"TOPLEFT",12,-67)
    boxContent:SetSize(654,295)
    bindingNotice=label(bindingWindow,"",16,-355,646)
    bindingNotice:SetWordWrap(true);bindingNotice:SetTextColor(0.95,0.79,0.48)
    bindingWindow:Hide()
    -- Separate, explicit opt-in configuration sync. No key broadcasts.
    rows.sync=namedButton(spellContent,"Sync Team",335,-352,98,22,function()
        if HB.RequestMacroSync then HB.RequestMacroSync() end
    end)
    rows.syncOpt=namedButton(spellContent,"Allow Sync: OFF",437,-352,118,22,function()
        HB.db.allowMacroSync=not HB.db.allowMacroSync
        HB.RefreshMacroMenu()
    end)
    rows.reset=namedButton(spellContent,"Clean HB Macros",558,-352,95,22,function()
        if HB.ResetOwnedMacros then HB.ResetOwnedMacros(false) end
    end)
    -- Blizzard Spellbook presentation: two columns of icon / name / rank.
    -- Single hardware click creates (if needed) and picks up a managed macro.
    -- No selection state, Ready text or separate Create/Pick Up buttons.
    spellCards={}
    local ICON=51
    local rowHeight=56
    for i=1,PER_PAGE do
        local col=math.floor((i-1)/6)
        local row=(i-1)%6
        local tile=CreateFrame("Button",nil,spellContent)
        tile:RegisterForClicks("LeftButtonUp")
        tile:SetSize(314,rowHeight-2)
        tile:SetPoint("TOPLEFT",spellContent,"TOPLEFT",10+col*324,-7-row*rowHeight)
        tile.tex=tile:CreateTexture(nil,"ARTWORK")
        tile.tex:SetSize(ICON,ICON)
        tile.tex:SetPoint("LEFT",tile,"LEFT",2,0)
        tile.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        tile.name=tile:CreateFontString(nil,"OVERLAY","GameFontNormal")
        tile.name:SetPoint("TOPLEFT",tile,"TOPLEFT",63,-7)
        tile.name:SetWidth(242)
        tile.name:SetJustifyH("LEFT")
        tile.name:SetWordWrap(false)
        tile.level=tile:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        tile.level:SetPoint("TOPLEFT",tile,"TOPLEFT",63,-27)
        tile.level:SetWidth(242)
        tile.level:SetJustifyH("LEFT")
        tile:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
        tile:SetScript("OnClick",function(self)
            local entry=self.entry
            if not entry then return end
            if entry.passive then say(entry.title.." is passive; no macro required.") return end
            if not spellKnown(entry) then say("Not learned yet: "..entry.title) return end
            -- Always verify the current BOX profile on a deliberate click,
            -- even when a stale off-body still appears 'owned'.
            if not HB.EnsureMacroPreset(entry.id) then return end
            HB.PickupMacroPreset(entry.id)
        end)
        tile:SetScript("OnEnter",function(self)
            local entry=self.entry
            if not entry or not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(entry.title,1,0.85,0.37)
            GameTooltip:AddLine((entry.level and ("Level "..tostring(entry.level)) or "Learned spell").." | "..entry.kind,0.75,0.72,0.64)
            if entry.passive then
                GameTooltip:AddLine("Passive ability: no macro needed",0.95,0.61,0.41)
            elseif not spellKnown(entry) then
                GameTooltip:AddLine("Not learned yet",1,0.48,0.38)
            else
                local exists,idx=owned(entry)
                if idx and not exists then
                    GameTooltip:AddLine("Click to verify/sync standard HB macro",1,0.73,0.35)
                    GameTooltip:AddLine("Custom macro text is NEVER overwritten",1,0.54,0.40)
                else
                    GameTooltip:AddLine(exists and "Click to sync and pick up HB macro" or "Click to create and pick up HB macro",0.46,0.9,0.52)
                end
                local profile=HB.IAmLeader and HB.IAmLeader() and "Leader" or
                    (HB.db and HB.db.boxMode and "Follower BOX ON" or "BOX OFF")
                GameTooltip:AddLine("Macro profile: "..profile,0.94,0.79,0.40)
                local macro=HB.PreviewBoxSpell and HB.PreviewBoxSpell(entry.spell,entry.kind)
                if macro then
                    for line in (macro.."\n"):gmatch("(.-)\n") do
                        if line~="" then GameTooltip:AddLine(line,0.88,0.84,0.71) end
                    end
                end
            end
            GameTooltip:Show()
        end)
        tile:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        spellCards[i]=tile
    end
    rows.spellPrev=namedButton(spellContent,"<",11,-352,34,22,function()
        spellPage=math.max(1,spellPage-1);HB.RefreshMacroMenu()
    end)
    rows.spellPage=label(spellContent,"",57,-356,205)
    rows.spellNext=namedButton(spellContent,">",245,-352,34,22,function()
        spellPage=math.min(math.ceil(#(SMART[me()] or {})/PER_PAGE),spellPage+1)
        HB.RefreshMacroMenu()
    end)
    notice=label(panel,"",16,-470,651)
    notice:SetWordWrap(true);notice:SetTextColor(0.95,0.79,0.48)
    footer=label(panel,"Local actions require a key press. No auto-casting or input broadcast.",16,-508,651)
    footer:SetTextColor(0.63,0.70,0.77)
    panel:Hide()
end
function HB.RefreshMacroMenu()
    if not panel then return end
    -- Active tab has a gold underline; do NOT show the selected tab as
    -- disabled/grey (which made Multibox appear selected on the spell page).
    tabButtons.box:Hide()
    tabButtons.spells:Hide()
    tabButtons.box.activeLine:SetShown(page=="box")
    tabButtons.spells.activeLine:SetShown(page=="spells")
    if panel.heading then
        panel.heading:SetText("HaploBox - JCDR Edition | Macro Menu")
    end
    local showBox=page=="box"
    -- Hide *entire* tab containers. No headings, buttons or selection from
    -- the other tab may remain visible, regardless of button child state.
    boxContent:SetShown(showBox)
    spellContent:SetShown(not showBox)
    if showBox then
        for i,row in ipairs(rows) do
            local entry=BOX[i]
            refreshKeyWidgets(row,entry)
            -- One bind field per row; macro creation remains available via explicit binding.
        end
        return
    end
    rows.syncOpt:SetText("Allow Sync: "..(HB.db and HB.db.allowMacroSync and "ON" or "OFF"))
    local entries=activeSpells()
    local totalPages=math.max(1,math.ceil(#entries/PER_PAGE))
    spellPage=math.min(math.max(1,spellPage),totalPages)
    for i,c in ipairs(spellCards) do
        local entry=entries[(spellPage-1)*PER_PAGE+i]
        c.entry=entry
        c:SetShown(entry~=nil)
        if entry then
            c.name:SetText(entry.title)
            local known=spellKnown(entry)
            local bookEntry=spellBook[entry.spell:lower()]
            local bookRank=bookEntry and bookEntry.rank
            c.level:SetText(entry.passive and "Passive" or
                (not known and "Not learned" or
                (type(bookRank)=="string" and bookRank~="" and bookRank or (entry.level and ("Level "..tostring(entry.level)) or "Learned"))))
            setIcon(c.tex,entry)
            local learned=spellKnown(entry)
            local v=learned and 1 or 0.42
            c.tex:SetVertexColor(v,v,v)
            if c.name.SetTextColor then
                c.name:SetTextColor(learned and 0.97 or 0.72, learned and 0.84 or 0.66, learned and 0.51 or 0.55)
            end
        end
    end
    rows.spellPage:SetText("Page "..spellPage.." / "..totalPages.."   (Lv 1-60, active)")
    rows.spellPrev:SetEnabled(spellPage>1)
    rows.spellNext:SetEnabled(spellPage<totalPages)
end
local function openMacroPage(wantedPage)
    makePanel()
    local target=wantedPage=="box" and bindingWindow or panel
    if target:IsShown() then
        target:Hide();target:EnableKeyboard(false);waiting=nil;return
    end
    if HB.PrepareQuickSubmenu then HB.PrepareQuickSubmenu(target) end
    setPage(wantedPage)
    if wantedPage=="spells" then scanSpellbook() end
    target:Show()
    HB.RefreshMacroMenu()
    if HB.PositionQuickSettings then HB.PositionQuickSettings(true) end
    if HB.PositionDockedSubmenu then HB.PositionDockedSubmenu(target,true)
    elseif target==panel then resetPlacement()
    else target:SetPoint("CENTER",UIParent,"CENTER") end
end
function HB.OpenMacroMenu() openMacroPage("spells") end
function HB.OpenKeybindingsMenu() openMacroPage("box") end
function HB.RequestMacroSync()
    if not HB.IAmLeader or not HB.IAmLeader() or not (IsInGroup and IsInGroup()) then
        say("Only the party leader can sync macros.") return false
    end
    if not HB.SendTeamMessage then return false end
    HB.macroSyncStatus={sent=0,confirmed={}}
    local n=0
    local box=BOX
    local spells=activeSpells()
    for _,collection in ipairs({box,spells}) do
        for _,entry in ipairs(collection) do
            local yes=owned(entry)
            if yes then
                HB.SendTeamMessage("K|P|"..entry.id)
                local first,second=keyFor(entry)
                if first or second then
                    HB.SendTeamMessage("K|B|"..entry.id..":"..(first or "-")..":"..(second or "-"))
                end
                n=n+1
            end
        end
    end
    HB.macroSyncStatus={sent=n,confirmed={}}
    say("Requested "..n.." managed presets on opted-in followers; wait for ACKs.")
    return true
end
function HB.OnMacroSyncMessage(sender,code,arg)
    if code=="A" then
        if HB.IAmLeader and HB.IAmLeader() and HB.IsGroupMember and HB.IsGroupMember(sender) then
            HB.macroSyncStatus=HB.macroSyncStatus or {sent=0,confirmed={}}
            HB.macroSyncStatus.confirmed[HB.Norm(sender)..":"..tostring(arg)]=true
            say("Macro sync response from "..tostring(sender)..": "..tostring(arg))
            if arg and (arg:find(":error",1,true) or arg:find(":consent-needed",1,true)) then
                HB.boxSyncError=true
                say("Macro sync issue from "..tostring(sender)..": "..tostring(arg))
            end
        end
        return
    end
    if code~="P" and code~="B" then return end
    if not trustedLeader(sender) then return end
    if not HB.db.allowMacroSync then
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..tostring(arg)..":consent-needed") end
        return
    end
    if locked() then
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..tostring(arg)..":combat") end
        return
    end
    local id,two,three
    if code=="P" then id=arg else
        id,two,three=tostring(arg or ""):match("^([%w]+):([%w%-]+):([%w%-]+)$")
    end
    local entry=preset(id)
    if not entry then return end -- never accept remote arbitrary macros
    if code=="P" then
        local ok=HB.EnsureMacroPreset(id)
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..id..(ok and ":ok" or ":error")) end
    else
        local ok=true
        for slot,key in ipairs({two,three}) do
            if key and key~="-" then
                local used=GetBindingAction and GetBindingAction(key)
                if used and used~="" and used~=bindingAction(entry) then
                    ok=false -- avoid replacing follower's own bindings
                elseif not bindKey(entry,slot,key,false) then ok=false end
            end
        end
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..id..(ok and ":bindings-ok" or ":error")) end
    end
end
-- Explicitly accessible from the console in case a follower needs to opt in
-- while its normal UI is suppressed by Mini Heal.
function HB.SetMacroSyncAllowed(on)
    if not HB.db then return end
    HB.db.allowMacroSync=not not on
    if HB.RefreshMacroMenu then HB.RefreshMacroMenu() end
end

-- Refresh read-only spell cards when the client learns a spell or rank.
if CreateFrame then
    local watcher=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","SPELLS_CHANGED","LEARNED_SPELL_IN_TAB"}) do
        pcall(watcher.RegisterEvent,watcher,event)
    end
    watcher:SetScript("OnEvent",function()
        scanSpellbook()
        if panel and panel:IsShown() then HB.RefreshMacroMenu() end
    end)
end
