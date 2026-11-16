-- Local Lua 5.1 mock test: lua tests/jcdr_macromenu_smoke.lua
-- No WoW runtime here. BOX-mode logic has separate BoxMode.lua smoke tests.
local macros,ids,bindings={}, {}, {F1="TARGETPARTYMEMBER1",F3="ASSISTTARGET",F5="FOCUSTARGET",F6="CLEARFOCUS",NUMPAD1="OPENALLBAGS"}
local count,picked,combat,casts=0,nil,false,0
function InCombatLockdown() return combat end
function UnitClass() return "Druid","DRUID" end
function GetMacroIndexByName(name) return ids[name] or 0 end
function GetMacroBody(idx)
    for name,id in pairs(ids) do if idx==id then return macros[name] end end
end
function CreateMacro(name,icon,body,perCharacter)
    assert(perCharacter==true and not ids[name],"character-only; never overwrite")
    count=count+1;ids[name]=count;macros[name]=body
    return count
end
function GetBindingAction(key) return bindings[key] end
function SetBindingMacro(key,name) bindings[key]="MACRO "..name;return true end
function GetCurrentBindingSet() return 2 end
function SaveBindings(n) assert(n==2);return true end
function PickupMacro(idx) picked=idx end
HaploBox={
    db={smartFollowOwners={},boxMacros={},boxMode=false},
    print=function()end,
    UnitIdent=function()return "Lyra"end,
    Norm=function(s)return s:lower()end,
}
local HB=HaploBox
HB.PrepareSmartFollow=function()
    if not ids["HB Smart Follow"] then
        CreateMacro("HB Smart Follow","INV_MISC_QUESTIONMARK","#showtooltip\n/stopmacro",true)
    end
    HB.db.smartFollowOwners["lyra"]=true
    return true
end
HB.InstallSmartFollowBinding=function(confirm)
    if not confirm then return false end
    bindings.F1="MACRO HB Smart Follow"
    return true
end
HB.AddBoxSpell=function(spell,kind)
    assert(not combat)
    local name="HB "..spell
    if ids[name] then return false end
    local off=kind=="heal" and ("#showtooltip "..spell.."\n/cast [mod:shift,@player][@mouseover,help,nodead][] "..spell) or ("#showtooltip "..spell.."\n/cast "..spell)
    local on=kind=="assist" and
        ("#showtooltip "..spell.."\n/assist party1\n/cast "..spell) or
        (kind=="heal" and ("#showtooltip "..spell.."\n/cast [mod:shift,@player][@mouseover,help,nodead][@party1,help,nodead] "..spell) or
        ("#showtooltip "..spell.."\n/cast [@party1] "..spell))
    local id=CreateMacro(name,"INV_MISC_QUESTIONMARK",off,true)
    HB.db.boxMacros.lyra=HB.db.boxMacros.lyra or {}
    HB.db.boxMacros.lyra[name]={offBody=off,onBody=on,applied="off"}
    return id>0
end
dofile("MacroLibrary.lua")
assert(#HB.MacroLibraryEntries("box")==1,"only F1 Smart Follow in multibox")
assert(#HB.MacroLibraryEntries("spells")==3,"three Druid smart spells")
for _,name in ipairs({"assist","focus","clear","trade"}) do
    assert(not HB.EnsureMacroPreset(name),"no old focus or trade presets")
end
assert(not HB.PickupMacroPreset("wrath"),"must make spell before drag")
assert(HB.EnsureMacroPreset("wrath"))
assert(macros["HB Wrath"]=="#showtooltip Wrath\n/cast Wrath")
assert(HB.db.boxMacros.lyra["HB Wrath"].onBody:find("/assist party1",1,true))
assert(HB.EnsureMacroPreset("moonfire"))
assert(HB.EnsureMacroPreset("rejuvenation"))
assert(HB.db.boxMacros.lyra["HB Rejuvenation"].onBody:find("[mod:shift,@player][@mouseover,help,nodead][@party1,help,nodead]",1,true))
assert(HB.db.boxMacros.lyra["HB Rejuvenation"].offBody:find("[mod:shift,@player][@mouseover,help,nodead][]",1,true))
assert(HB.PickupMacroPreset("wrath"))
assert(picked==ids["HB Wrath"])
assert(HB.EnsureMacroPreset("follow"))
assert(not HB.BindMacroPreset("follow",false),"F1 binding conflict warning")
assert(bindings.F1=="TARGETPARTYMEMBER1","no binding replacement without confirmation")
assert(HB.BindMacroPreset("follow",true))
assert(bindings.F1=="MACRO HB Smart Follow")
assert(bindings.F3=="ASSISTTARGET" and bindings.F5=="FOCUSTARGET" and bindings.F6=="CLEARFOCUS")
assert(bindings.NUMPAD1=="OPENALLBAGS","trade binding unchanged")
macros["HB Wrath"]="/say my custom macro"
assert(not HB.EnsureMacroPreset("wrath"),"no overwrite of edited macro")
assert(not HB.PickupMacroPreset("wrath"),"no pickup of changed macro")
combat=true
assert(not HB.EnsureMacroPreset("wrath"),"no macro creation in combat")
assert(not HB.BindMacroPreset("follow",true),"no key edits in combat")
combat=false
assert(HB.EnsureMacroPreset("rejuvenation"),"idempotent owned spell")
assert(casts==0,"never auto-cast")
print("PASS: Smart Follow + BOX-aware spell library mock assertions")
