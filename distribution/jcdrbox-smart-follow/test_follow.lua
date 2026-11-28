local function read(p)local f=assert(io.open(p));local s=f:read("*a");f:close();return s end
local source,core,game=read(arg[1]),read(arg[2]),read(arg[3])
local group,raid=true,false
local units={player={g="d",n="Dps One"},party1={g="l",n="Leader One",lead=true},party2={g="h",n="Healer One"},party3={g="x",n="Other One"}}
local chars={d={account="a"},l={account="b"},h={account="c"},x={account="e"}}
local roles={d="dps",l="tank",h="healer",x="dps"}
IsInGroup=function()return group end
IsInRaid=function()return raid end
UnitExists=function(u)return units[u]~=nil end
UnitGUID=function(u)return units[u] and units[u].g end
UnitIsGroupLeader=function(u)return units[u] and units[u].lead==true end
GetNumGroupMembers=function()local n=0 for _ in pairs(units) do n=n+1 end return n end
UnitGroupRolesAssigned=function()error("Blizzard roles must not be used by follow")end
local active=true
local HB={db={boxMode=true,followMode="dungeon"},UnitIdent=function(u)return units[u] and units[u].n end,CharacterManagement={Accounts=function()return {{id="a"},{id="b"},{id="c"},{id="e"}} end,GetCharacter=function(g)return chars[g] end},TeamPlanner={Active=function()return active and {} or nil end,RoleForUnit=function(u)return units[u] and roles[units[u].g] end}}
local prefix=assert(source:match("(%-%- JB26%.3%.22: only the explicit CM register.-)\n%-%- JB26%.3%.24:"))
local follow=assert(source:match("(local function followMacroFor%(unit%).-)\nfunction HB.PrepareSmartFollow"))
local setup="local HB=...;local function safe(v)return true end;local function norm(v)return v and v:lower() end\n"
local body=assert(loadstring(setup..prefix.."\n"..follow.."\nreturn followBody"))(HB)
local function expected(token)return "#showtooltip\n/follow "..token.."\n/run HaploBox.SmartFollowCamera()" end
assert(body()==expected("party2"))
assert(HB.ExpectedTMFollowTarget("Dps One")=="Healer One")
assert(HB.ExpectedTMFollowTarget("Healer One")=="Leader One")
assert(HB.ExpectedTMFollowTarget("Leader One")==nil)
HB.db.followMode="direct";assert(body()==expected("party1"))
HB.db.followMode="dungeon";roles.h="dps";roles.x="healer";assert(body()==expected("party3"))
roles.d="healer";roles.x="dps";assert(body()==expected("party1"))
roles.d="dps";assert(body()==expected("party1"))
roles.h="healer";roles.x="healer";assert(body()==expected("party1"))
roles.x="dps";active=false;assert(body()==expected("party1"))
active=true;roles.h="dps";roles.l="healer";assert(body()==expected("party1"))
roles.l="tank";roles.h="healer";units.party1.lead=false;units.party2.lead=true;assert(body()==expected("party2"))
units.party2.lead=false;units.player.lead=true;assert(body()=="#showtooltip\n/stopmacro")
units.player.lead=false;units.party1.lead=true;HB.db.boxMode=false;assert(body()=="#showtooltip\n/stopmacro")
HB.db.boxMode=true;units.party3.g="guest";assert(body()=="#showtooltip\n/stopmacro")
units.party3.g="x";group=false;assert(body()=="#showtooltip\n/stopmacro")
assert(core:find("return HB.ExpectedTMFollowTarget(name)",1,true))
assert(game:find("if HB.PrepareSmartFollow then HB.PrepareSmartFollow() end",1,true))
assert(not follow:find("UnitGroupRolesAssigned",1,true))
assert(source:find("Smart Follow macro was modified; not overwritten.",1,true))
print("Smart Follow tests passed: direct leader, TM healer chain and role swaps, native role independence, missing/multiple healer fallback, leader change, solo/guest/off, expected target consistency, unchanged F1 and spell templates.")
