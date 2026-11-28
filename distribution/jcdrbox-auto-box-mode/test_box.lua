local function read(p)local f=assert(io.open(p));local s=f:read("*a");f:close();return s end
local source,game=read(arg[1]),read(arg[2])
local group,raid,combat,instance=false,false,false,false
local units={player={g="g1",lead=true}}
local chars={g1={account="a"},g2={account="b"},g3={account="c"}}
LE_PARTY_CATEGORY_INSTANCE=2
IsInGroup=function(c)if c then return instance end return group end
IsInRaid=function()return raid end
InCombatLockdown=function()return combat end
UnitExists=function(u)return units[u]~=nil end
UnitGUID=function(u)return units[u] and units[u].g end
UnitIsGroupLeader=function(u)return units[u] and units[u].lead==true end
GetNumGroupMembers=function()local n=0 for _ in pairs(units) do n=n+1 end return n end
local HB={db={boxMode=false},CharacterManagement={Accounts=function()return {{id="a"},{id="b"},{id="c"}} end,GetCharacter=function(g)return chars[g] end}}
local changes={};local failure=false
local prefix=assert(source:match("(%-%- JB26%.3%.22: only the explicit CM register.-)\nlocal function buildSpell"))
local profile=assert(source:match("(local function desiredProfile%(enabled%).-)\n%-%- Read%-only Spellbook"))
local runtime=assert(source:match('(local lastSyncReason="not started".-)\nlocal function setCombat'))
local setup=[[
local HB,changes,failed=...
local function safe(v)return true end
local function notify()end
local function refresh()end
local pendingMode,validatedMode,validatedProfile
local function updateMacros(v)changes[#changes+1]=v;if failed() then return false,"modified macro" end;return true end
HB.PrepareSmartFollow=function()return true end
]]
local f=assert(loadstring(setup..prefix.."\n"..profile.."\n"..runtime.."\nreturn desiredProfile,registeredParty"))
local desired,registered=f(HB,changes,function()return failure end)
HB.AutoBoxReconcile();assert(HB.db.boxMode==false and desired(false)=="off")
group=true;units.party1={g="g2"};assert(registered())
HB.AutoBoxReconcile();assert(HB.db.boxMode and desired(true)=="leader")
local count=#changes;HB.AutoBoxReconcile();assert(#changes==count)
units.player.lead=false;units.party1.lead=true;HB.AutoBoxReconcile();assert(desired(true)=="on" and #changes==count+1)
HB.SetBoxMode(false);assert(not HB.db.boxMode);HB.AutoBoxReconcile();assert(not HB.db.boxMode)
HB.SetBoxMode(true);assert(HB.db.boxMode)
units.party2={g="guest"};HB.AutoBoxReconcile();assert(not HB.db.boxMode and desired(true)=="off")
HB.OnBoxMessage("guest","1");assert(not HB.db.boxMode)
units.party2=nil;HB.AutoBoxReconcile();assert(HB.db.boxMode)
combat=true;units.party2={g="guest"};HB.AutoBoxReconcile();assert(HB.db.boxMode)
units.party2=nil;combat=false;HB.AutoBoxReconcile(true);assert(HB.db.boxMode)
units.party2={g="guest"};HB.AutoBoxReconcile();assert(not HB.db.boxMode)
units.party2=nil;HB.AutoBoxReconcile();assert(HB.db.boxMode)
raid=true;HB.AutoBoxReconcile();assert(not HB.db.boxMode);raid=false
instance=true;HB.AutoBoxReconcile();assert(not HB.db.boxMode);instance=false
HB.AutoBoxReconcile();assert(HB.db.boxMode)
chars.g2.account="a";HB.AutoBoxReconcile();assert(not HB.db.boxMode)
chars.g2.account="b";HB.AutoBoxReconcile();assert(HB.db.boxMode)
failure=true;group=false;units.party1=nil;HB.AutoBoxReconcile();assert(HB.boxSyncError and HB.db.boxMode)
count=#changes;HB.AutoBoxReconcile();assert(#changes==count)
failure=false;HB.RefreshBoxSync();assert(not HB.db.boxMode and not HB.boxSyncError)
assert(game:find("if HB.AutoBoxReconcile then HB.AutoBoxReconcile() end",1,true))
assert(not runtime:find("send(",1,true))
print("Auto BOX tests passed: CM GUID/account trust, solo/guest/raid/instance OFF, all-owned ON, actual leader profile, local override, no remote activation, combat re-evaluation, dedupe and macro rejection.")
