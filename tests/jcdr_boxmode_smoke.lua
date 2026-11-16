-- Mocked offline BOX / macro / follow / combat smoke tests, no WoW client.
local logs,wire,binds={}, {}, {F1="TARGETPARTYMEMBER1"}
local macros={};local macroIds={};local nextMacro=1;local t=100;local combat=false;local combatLock=false
local leader="Mael";local player="Elya"
function GetTime()return t end
function InCombatLockdown()return combatLock end
function UnitAffectingCombat(u)return combat end
function IsInGroup()return true end
function IsInRaid()return false end
function UnitExists(unit)return unit=="party1" or unit=="party2" or unit=="player" end
function UnitGroupRolesAssigned(unit)
 if unit=="party2"then return "HEALER"end
 if unit=="player"then return "DAMAGER"end
 return "TANK"
end
function CreateFrame()local f={};function f:RegisterEvent(_)end;function f:SetScript(_,fn)self.fn=fn end;_G.eventFrame=f;return f end
C_Timer={NewTicker=function(_,fn) _G.ticker=fn;return {} end}
function GetMacroIndexByName(name)return macroIds[name] or 0 end
function GetMacroBody(id)
 for n,b in pairs(macros) do if macroIds[n]==id then return b end end
end
function CreateMacro(name,icon,body,perChar)
 if macros[name]then error("exists")end
 macros[name]=body;macroIds[name]=nextMacro;nextMacro=nextMacro+1;return macroIds[name]
end
function EditMacro(name,_,_,body)
 assert(macros[name]);macros[name]=body;return macroIds[name]
end
function GetBindingAction(k)return binds[k] end
function SetBindingMacro(key,name) binds[key]="MACRO "..name;return true end
function GetCurrentBindingSet()return 2 end
function SaveBindings(k)assert(k==2)return true end
HaploBox={db={trustedMembers="Mael,Lyra,Elya,Nyra,Ayla",boxMode=false,followMode="direct"},combatState={},boxAcks={}}
local HB=HaploBox
HB.print=function(s)logs[#logs+1]=s end
HB.SendTeamMessage=function(s)wire[#wire+1]=s end
HB.Norm=function(s)return s and string.lower(s) end
HB.UnitIdent=function(unit) if unit=="player"then return player elseif unit=="party1"then return leader elseif unit=="party2"then return "Lyra"end end
HB.IAmLeader=function()return player==leader end
HB.GroupLeader=function()return leader end
HB.IsGroupMember=function(n)return true end
HB.RefreshControls=function()end
HB.RefreshHaploBar=function()end
HB.OnCombatStateChanged=function()end
-- Load production source and trigger login.
dofile("BoxMode.lua")
eventFrame.fn(nil,"PLAYER_LOGIN")
assert(not HB.db.boxMode and macros["HB Smart Follow"]=="#showtooltip\n/stopmacro","login safe")
assert(HB.AddBoxSpell("Wrath","assist"))
assert(HB.AddBoxSpell("Rejuvenation","party1"))
assert(macros["HB Wrath"]=="#showtooltip Wrath\n/cast Wrath")
assert(not HB.AddBoxSpell("Wrath","assist"),"cannot overwrite user macro")
macros["Moonfire"]="#showtooltip Moonfire\n/assist focus\n/cast Moonfire"; macroIds["Moonfire"]=nextMacro;nextMacro=nextMacro+1
assert(HB.ImportBoxMacro("Moonfire"))
assert(macros["Moonfire"]:find("/assist focus",1,true),"import non-destructive")
assert(not HB.InstallSmartFollowBinding(false),"F1 conflict guard")
assert(binds.F1=="TARGETPARTYMEMBER1")
assert(HB.InstallSmartFollowBinding(true))
assert(binds.F1=="MACRO HB Smart Follow")
-- Follower receives authoritative ON command from trusted leader.
HB.OnBoxMessage("Mael","1")
assert(HB.db.boxMode)
assert(macros["HB Wrath"]=="#showtooltip Wrath\n/assist party1\n/cast Wrath")
assert(macros["HB Rejuvenation"]=="#showtooltip Rejuvenation\n/cast [@party1] Rejuvenation")
assert(macros["Moonfire"]=="#showtooltip Moonfire\n/assist party1\n/cast Moonfire")
assert(macros["HB Smart Follow"]=="#showtooltip\n/follow party1")
-- Dungeon uses Blizzard healer role.
HB.db.followMode="dungeon"
assert(HB.PrepareSmartFollow())
assert(macros["HB Smart Follow"]=="#showtooltip\n/follow party2")
-- Roster combat telemetry: the target is actually in combat.
HB.OnCombatMessage("Lyra","1")
assert(HB.CombatState("Lyra")==true)
combat=true;assert(HB.CombatState("Elya")==true)
-- Mode changes in combat are deferred; macros cannot be modified.
combatLock=true
HB.OnBoxMessage("Mael","0")
assert(HB.db.boxMode==true and macros["HB Wrath"]:find("/assist party1",1,true))
combatLock=false
-- Apply queued OFF after combat event.
eventFrame.fn(nil,"PLAYER_REGEN_ENABLED")
assert(not HB.db.boxMode and macros["HB Wrath"]=="#showtooltip Wrath\n/cast Wrath")
assert(macros["Moonfire"]=="#showtooltip Moonfire\n/cast Moonfire")
assert(macros["HB Smart Follow"]=="#showtooltip\n/stopmacro")
-- Only HB-owned macros are modified, and external edits are detected.
macros["HB Wrath"]="#showtooltip Wrath\n/cast CustomSpell"
HB.OnBoxMessage("Mael","1")
assert(not HB.db.boxMode,"refuse to overwrite modified macro")
assert(macros["HB Wrath"]:find("CustomSpell",1,true))
-- Leader itself stays on ordinary target in BOX ON.
macros["HB Wrath"]="#showtooltip Wrath\n/cast Wrath"
leader="Elya"
assert(HB.SetBoxMode(true))
assert(HB.db.boxMode==true)
assert(macros["HB Wrath"]=="#showtooltip Wrath\n/cast Wrath")
print("PASS: 23 assertions, macro variants, import guard, F1 binding, dungeon roles, remote combat, combat queue, leader safety")
