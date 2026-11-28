local class,level="MAGE",10
local known={Fireball=true,Frostbolt=true,["Arcane Intellect"]=true}
UnitClass=function()return class,class end
UnitLevel=function()return level end
UnitFactionGroup=function()return "Alliance" end
GetSpellInfo=function(n)return n,nil,123,nil,nil,nil,1 end
IsSpellKnown=function()return false end
-- spellbook data, no actual macro creation
GetNumSpellTabs=function()return 2 end
GetSpellTabInfo=function(tab)if tab==1 then return "General",nil,0,0 end;return "Arcane",nil,0,3 end
GetSpellBookItemName=function(i)return ({"Fireball","Frostbolt","Arcane Intellect"})[i],"Rank 1" end
GetSpellBookItemInfo=function(i)return "SPELL",i end
IsPassiveSpell=function()return false end
HaploBox={}
assert(loadfile(arg[1]))()
local HB=HaploBox
local function find(n)
    for _,e in ipairs(HB.MacroLibraryEntries("spells")) do if e.spell==n then return e end end
end
assert(#HB.MacroLibraryEntries("spells")>=45)
local function state(n)return HB.MacroSpellStatus(assert(find(n),n))end
assert(state("Fireball")=="Learned")
assert(state("Conjure Food"):find("Check trainer",1,true))
assert(state("Frostfire Bolt")=="Level 40 required")
level=60
assert(state("Arcane Power")=="Talent")
assert(state("Portal: Orgrimmar")=="Horde only")
assert(not HB.EnsureMacroPreset(find("Arcane Power").id))
for _,cl in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","WARLOCK","DRUID"}) do
    class=cl
    local entries=HB.MacroLibraryEntries("spells")
    local ids,names={},{}
    assert(#entries>=30,cl)
    for _,e in ipairs(entries) do
        assert(not ids[e.id] and not names[e.name],e.title)
        ids[e.id]=true;names[e.name]=true
        assert(not e.level or e.level>=1 and e.level<=60)
    end
end
assert(find("Wrath").name=="HB Wrath")
assert(find("Healing Touch").kind=="heal")
assert(find("Mark of the Wild").kind=="buff")
assert(find("Omen of Clarity").passive)
print("Macro catalog tests passed: nine classes, distinct IDs/names, level range, current class, learned/trainable/locked/talent/faction, preserved Druid macros, passive no cast.")
