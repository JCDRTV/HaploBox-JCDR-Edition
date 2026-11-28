local function read(p)local f=assert(io.open(p));local s=f:read("*a");f:close();return s end
local party,game,sync,control=read(arg[1]),read(arg[2]),read(arg[3]),read(arg[4])
local grouped,raid,combat,leader=true,false,false,true
local units={player={g="g2",n="Beta Two"},party1={g="g1",n="Alpha One"},party2={g="g3",n="Gamma Three"}}
local chars={g1={account="a"},g2={account="b"},g3={account="c"}}
local team={slots={{guid="g3"},{guid="g1"},{guid="g2"}}}
local now=100;local method="group";local calls={};local layouts=0
IsInGroup=function()return grouped end
IsInRaid=function()return raid end
InCombatLockdown=function()return combat end
UnitIsGroupLeader=function()return leader end
UnitExists=function(u)return units[u]~=nil end
UnitGUID=function(u)return units[u] and units[u].g end
GetNumGroupMembers=function()local n=0 for _ in pairs(units) do n=n+1 end return n end
GetTime=function()return now end
C_PartyInfo={GetLootMethod=function()return method end,SetLootMethod=function(v)calls[#calls+1]=v;method=v end}
HaploBox={db={autoFFA=true},UnitIdent=function(u)return units[u] and units[u].n end,Norm=function(n)return n and n:lower() end,TeamPlanner={Active=function()return team end},CharacterManagement={Accounts=function()return {{id="a"},{id="b"},{id="c"}} end,GetCharacter=function(g)return chars[g] end},LayoutPartyFrame=function()layouts=layouts+1 end}
local HB=HaploBox
local a=assert(party:match("(local function unitForName%b().-\nend)"))
local b=assert(party:match("(local function visibleTeamOrder%b().-\nend)"))
local order,resolve=assert(loadstring("local HB=...;"..a.."\n"..b.."\nreturn visibleTeamOrder,unitForName"))(HB)
local function names()return table.concat(order(),";")end
assert(names()=="Gamma Three;Alpha One;Beta Two")
assert(resolve("Alpha One")=="party1")
units.player,units.party2=units.party2,units.player
assert(names()=="Gamma Three;Alpha One;Beta Two")
team.slots[1],team.slots[3]=team.slots[3],team.slots[1]
assert(names()=="Beta Two;Alpha One;Gamma Three")
units.party3={g="guest",n="A Guest"}
assert(names()=="Beta Two;Alpha One;Gamma Three;A Guest")
units.party3=nil
local l=assert(game:match("(local lastLootGoal,lastLootAttempt,lastLootRoster.-)\nlocal ev = CreateFrame"))
assert(loadstring("local HB=...;local function notice()end;"..l))(HB)
HB.CheckAutoLoot();assert(method=="freeforall" and #calls==1)
HB.CheckAutoLoot();assert(#calls==1)
units.party3={g="guest",n="Alpha One"} -- even identical name does not grant GUID trust
HB.CheckAutoLoot();assert(method=="group" and #calls==2)
units.party3=nil;HB.CheckAutoLoot();assert(method=="freeforall" and #calls==3)
HB.db.autoFFA=false;units.party3={g="guest",n="Guest Other"};HB.CheckAutoLoot();assert(#calls==3)
HB.db.autoFFA=true;combat=true;HB.CheckAutoLoot();assert(#calls==3)
combat=false;leader=false;HB.CheckAutoLoot();assert(#calls==3)
leader=true;HB.CheckAutoLoot();assert(method=="group" and #calls==4)
units.party3=nil;HB.OnRegisterPartyChanged();assert(layouts==1 and method=="freeforall" and #calls==5)
chars.g1=nil;HB.CheckAutoLoot();assert(method=="group" and #calls==6)
chars.g1={account="a"};HB.CheckAutoLoot();assert(method=="freeforall" and #calls==7)
assert(sync:find("if changed and HB.OnRegisterPartyChanged then HB.OnRegisterPartyChanged() end",1,true))
assert(sync:find("if HB.OnRegisterPartyChanged then HB.OnRegisterPartyChanged() end",1,true))
assert(game:find('event == "PLAYER_REGEN_ENABLED" or event == "PARTY_LEADER_CHANGED"',1,true))
assert(control:find("HB.db.autoFFA=not HB.db.autoFFA",1,true))
print("Party and loot tests passed: GUID POS order across clients, reorder, guests appended, exact row binding, CM trust, FFA/group transition, manual off, combat, real leader, register refresh.")
