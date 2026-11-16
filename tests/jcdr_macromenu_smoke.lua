-- Run with Lua 5.1: lua tests/jcdr_macromenu_smoke.lua
-- Mocked WoW APIs; this is NOT a five-client in-game test.
local macros,ids,bindings={}, {}, {F1="TARGETPARTYMEMBER1",F3="ASSISTTARGET"}
local count,picked,combat=0,nil,false
local notices={}
function InCombatLockdown() return combat end
function UnitClass() return "Druid","DRUID" end
function GetMacroIndexByName(name) return ids[name] or 0 end
function GetMacroBody(idx)
    for name,id in pairs(ids) do if idx==id then return macros[name] end end
end
function CreateMacro(name,icon,body,perCharacter)
    assert(perCharacter==true and not ids[name],"character-only / no overwrite")
    count=count+1;ids[name]=count;macros[name]=body
    return count
end
function GetBindingAction(key) return bindings[key] end
function SetBindingMacro(key,name)
    bindings[key]="MACRO "..name
    return true
end
function GetCurrentBindingSet() return 2 end
function SaveBindings(n) assert(n==2);return true end
function PickupMacro(idx) picked=idx end
HaploBox={
    db={smartFollowOwners={}},
    print=function(message) notices[#notices+1]=message end,
    UnitIdent=function() return "Lyra" end,
    Norm=function(v) return v:lower() end,
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
dofile("MacroLibrary.lua")
assert(#HB.MacroLibraryEntries("box")==5)
assert(#HB.MacroLibraryEntries("class")==3)
assert(not HB.PickupMacroPreset("trade"),"must create before drag")
assert(HB.EnsureMacroPreset("assist"))
assert(macros["HB Assist Focus"]=="#showtooltip\n/assist focus")
assert(HB.EnsureMacroPreset("trade"))
assert(macros["HB Trade Leader"]:find('InitiateTrade("party1")',1,true))
assert(not HB.BindMacroPreset("assist",false),"F3 conflict should require confirmation")
assert(bindings.F3=="ASSISTTARGET","no silent overwrite")
assert(HB.BindMacroPreset("assist",true))
assert(bindings.F3=="MACRO HB Assist Focus")
assert(HB.EnsureMacroPreset("motw"))
assert(HB.EnsureMacroPreset("thorns"))
assert(macros["HB Thorns"]:find("[@mouseover,help,nodead]",1,true))
assert(HB.PickupMacroPreset("thorns"))
assert(picked==ids["HB Thorns"])
assert(HB.EnsureMacroPreset("follow"))
assert(not HB.BindMacroPreset("follow",false),"F1 conflict requires confirmation")
assert(bindings.F1=="TARGETPARTYMEMBER1")
assert(HB.BindMacroPreset("follow",true))
assert(bindings.F1=="MACRO HB Smart Follow")
macros["HB Assist Focus"]="/say user changed this"
assert(not HB.EnsureMacroPreset("assist"),"must not overwrite user-customized macro")
assert(not HB.PickupMacroPreset("assist"))
combat=true
assert(not HB.EnsureMacroPreset("rejuv"),"no macro creation in combat")
assert(not HB.BindMacroPreset("trade",true),"no binding in combat")
combat=false
assert(HB.EnsureMacroPreset("rejuv"))
print("PASS: 24 macro library smoke assertions (local, mocked APIs)")
