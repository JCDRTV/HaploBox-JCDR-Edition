local f=assert(io.open(arg[1]));local s=f:read("*a");f:close()
local group,raid=true,false
local units={player={g="g1"},party1={g="g2",lead=true},party2={g="g3"}}
local chars={g1={account="a"},g2={account="b"},g3={account="c"}}
IsInGroup=function()return group end
IsInRaid=function()return raid end
UnitExists=function(u)return units[u]~=nil end
UnitGUID=function(u)return units[u] and units[u].g end
UnitIsGroupLeader=function(u)return units[u] and units[u].lead==true end
GetNumGroupMembers=function()local n=0 for _ in pairs(units) do n=n+1 end return n end
local HB={db={boxMode=true},CharacterManagement={Accounts=function()return {{id="a"},{id="b"},{id="c"}} end,GetCharacter=function(g)return chars[g] end}}
local body=assert(s:match("(%-%- JB26%.3%.22: only the explicit CM register.-)\nlocal function updateMacros"))
local code="local HB=...;local function safe(v)return true end;local function sameBody(a,b)return type(a)=='string' and type(b)=='string' and a==b end\n"..body.."\nreturn buildSpell,knownBody,profileKey"
local build,known,key=assert(loadstring(code))(HB)
local function preview(kind,spell)return HB.PreviewBoxSpell(spell or "Fireball",kind) end
local on="#showtooltip Fireball\n/assist party1\n/cast Fireball"
local off="#showtooltip Fireball\n/cast Fireball"
assert(preview("assist")==on)
for i=1,4 do assert(build("Fireball","assist","on","party"..i)==on) end
assert(build("","boxassist","on","party4")=="#showtooltip\n/assist party1")
assert(build("","boxassist","off","party1")=="#showtooltip\n/stopmacro")
assert(known({spell="Fireball",kind="assist"},"#showtooltip Fireball\n/assist party4\n/cast Fireball"))
assert(not known({spell="Fireball",kind="assist"},"#showtooltip Fireball\n/assist party4\n/cast Fireball\n/say custom"))
assert(known({spell="",kind="boxassist"},"#showtooltip\n/assist party4"))
assert(not known({spell="Fireball",kind="assist",legacyBody="custom"},"#showtooltip Fireball\n/assist party4\n/cast Fireball"))
local heal=preview("heal","Heal")
assert(heal=="#showtooltip Heal\n/cast [mod:shift,@player][@mouseover,help,nodead][@party1,help,nodead] Heal")
assert(preview("buff","Arcane Intellect")=="#showtooltip Arcane Intellect\n/cast [mod:shift,@player][@mouseover,help,nodead][@target,help,nodead][@player] Arcane Intellect")
assert(preview("cast","Frost Nova")=="#showtooltip Frost Nova\n/cast Frost Nova")
-- Even a simulated unusual unit order does not change assist text.
units.party1.lead=false;units.party2.lead=true
assert(preview("assist")==on)
assert(preview("heal","Heal"):find("[@party2,help,nodead]",1,true))
units.party2.lead=false;units.player.lead=true
assert(preview("assist")==off)
units.player.lead=false;units.party1.lead=true
HB.db.boxMode=false;assert(preview("assist")==off)
HB.db.boxMode=true;units.party2.g="guest";assert(preview("assist")==off)
group=false;assert(preview("assist")==off)
assert(not s:find("local function assistGuard",1,true))
assert(s:find('on=on:gsub("(/assist )party[1-4]", "%1party1",1)',1,true))
print("Corrected Smart Assist tests passed: fixed party1, exact ordinary cast, leader/follower/off/guest, no additional guard, historical ownership protection, unchanged healing/buffs.")
