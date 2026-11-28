local f=assert(io.open(arg[1]));local s=f:read("*a");f:close()
local group,raid=true,false
local units={player={g="g1"},party1={g="g2"},party2={g="g3",lead=true}}
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
local on=preview("assist")
assert(on=="#showtooltip Fireball\n/stopmacro [nogroup:party][@party2target,noharm][@party2target,dead]\n/assist party2\n/cast [@party2target,harm,nodead] Fireball")
assert(preview("boxassist","")=="#showtooltip\n/stopmacro [nogroup:party][@party2target,noharm][@party2target,dead]\n/assist party2" or build("","boxassist","on","party2"):find("/assist party2",1,true))
local old={spell="Fireball",kind="assist"}
assert(known(old,"#showtooltip Fireball\n/assist party4\n/cast Fireball"))
assert(not known(old,"#showtooltip Fireball\n/assist party4\n/cast Fireball\n/say custom"))
assert(known({spell="",kind="boxassist"},"#showtooltip\n/assist party1"))
assert(not known({spell="Fireball",kind="assist",legacyBody="custom"},"#showtooltip Fireball\n/assist party4\n/cast Fireball"))
assert(preview("heal","Heal"):find("[@party2,help,nodead]",1,true))
assert(preview("buff","Arcane Intellect"):find("[@target,help,nodead][@player]",1,true))
assert(preview("cast","Frost Nova")=="#showtooltip Frost Nova\n/cast Frost Nova")
local before=key(true)
units.party2.lead=false;units.party1.lead=true
assert(key(true)~=before and preview("assist"):find("/assist party1",1,true))
before=key(true)
units.party1.g,units.party2.g=units.party2.g,units.party1.g
assert(key(true)~=before)
units.party1.lead=false;units.player.lead=true
assert(preview("assist")=="#showtooltip Fireball\n/cast Fireball")
units.player.lead=false;units.party1.lead=true;HB.db.boxMode=false
assert(preview("assist")=="#showtooltip Fireball\n/cast Fireball")
HB.db.boxMode=true;units.party2.g="guest"
assert(preview("assist")=="#showtooltip Fireball\n/cast Fireball")
group=false
assert(preview("assist")=="#showtooltip Fireball\n/cast Fireball")
assert(#build("Shadow Word: Death","assist","on","party4")<=255)
print("Smart Assist tests passed: actual leader token, hostile target guard, normal leader/off/guest/solo casts, same-slot identity change, exact historical migration, custom protection, unchanged heal/buff/cast.")
