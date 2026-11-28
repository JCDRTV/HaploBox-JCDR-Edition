local function read(p)local f=assert(io.open(p));local s=f:read("*a");f:close();return s end
local source,core,party,game=read(arg[1]),read(arg[2]),read(arg[3]),read(arg[4])
local grouped,raid,combat=true,false,false
local units={player={g="g2",n="Beta Two"},party1={g="g1",n="Alpha One"},party2={g="g3",n="Gamma Three"}}
local chars={g1={account="a"},g2={account="b"},g3={account="c"}}
local team={id="test",slots={{guid="g1",account="a",role="tank"},{guid="g2",account="b",role="healer"},{guid="g3",account="c",role="dps"}}}
local native="NONE";local calls={};local reject=false
IsInGroup=function()return grouped end
IsInRaid=function()return raid end
InCombatLockdown=function()return combat end
UnitExists=function(u)return units[u]~=nil end
UnitGUID=function(u)return units[u] and units[u].g end
GetNumGroupMembers=function()local n=0 for _ in pairs(units) do n=n+1 end return n end
UnitGroupRolesAssigned=function()return native end
UnitSetRole=function(u,r)assert(u=="player");calls[#calls+1]=r;if reject then return false end;native=r end
local HB={UnitIdent=function(u)return units[u] and units[u].n end,TeamPlanner={Active=function()return team end}}
local T=HB.TeamPlanner;local CM={GetCharacter=function(g)return chars[g] end}
local s=assert(source:match("(%-%- JB26%.3%.21: the active saved team.*)"))
assert(loadstring("local HB,T,CM=...;"..s))(HB,T,CM)
assert(T.RoleForUnit("player")=="healer" and T.RoleForName("Alpha One")=="tank")
assert(T.RoleForName("Gamma") == nil and T.LiveHealer()=="Beta Two")
assert(T.ApplyOwnPlannedRole() and native=="HEALER" and #calls==1)
T.ApplyOwnPlannedRole();assert(#calls==1)
team.slots[2].role="dps";assert(T.ApplyOwnPlannedRole() and native=="DAMAGER" and #calls==2)
combat=true;team.slots[2].role="tank";assert(not T.ApplyOwnPlannedRole() and #calls==2)
combat=false;assert(T.ApplyOwnPlannedRole() and native=="TANK" and #calls==3)
units.party3={g="guest",n="Guest Other"};assert(T.RoleForName("Guest Other")==nil)
T.ApplyOwnPlannedRole();assert(#calls==3)
reject=true;team.slots[2].role="healer";assert(not T.ApplyOwnPlannedRole() and #calls==4)
T.ApplyOwnPlannedRole();assert(#calls==4)
grouped=false;assert(not T.ApplyOwnPlannedRole() and #calls==4)
grouped=true;reject=false;assert(T.ApplyOwnPlannedRole() and #calls==5)
raid=true;team.slots[2].role="dps";assert(not T.ApplyOwnPlannedRole() and #calls==5)
raid=false;units.player={g="guest2",n="Guest Two"};assert(not T.ApplyOwnPlannedRole() and #calls==5)
units.player={g="g2",n="Beta Two"};chars.g2.account="wrong";assert(not T.ApplyOwnPlannedRole() and #calls==5)
assert(core:find("return T.RoleForUnit(\"player\")",1,true))
assert(core:find("return T.RoleForName(name)",1,true))
assert(core:find("return T.LiveHealer()",1,true))
assert(party:find('plannedLabel.."*"',1,true))
assert(game:find("HB.TeamPlanner.ApplyOwnPlannedRole()",1,true))
print("Auto role tests passed: CM GUID/account role, full live name, actual self only, TANK/HEALER/DAMAGER, role updates, combat defer, no guest changes, raid/solo guard, API rejection dedupe, TM fallback.")
