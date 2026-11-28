local args=arg
local now,events,messages,clients=0,{}, {},{}
local leader="P-1"
local grouped=true
local drop,combat=nil,{}
local players={
 {guid="P-1",name="Warrior",class="WARRIOR",race="Human",level=20},
 {guid="P-2",name="Rogue",class="ROGUE",race="NightElf",level=15},
 {guid="P-3",name="Guest",class="MAGE",race="Gnome",level=12}}
local function later(delay,fn)events[#events+1]={at=now+delay,fn=fn} end
local function run(limit)
 local n=0
 while #events>0 do
  table.sort(events,function(a,b)return a.at<b.at end)
  local e=table.remove(events,1);now=e.at;e.fn();n=n+1
  assert(n<(limit or 10000),"event loop")
 end
end
local function tickAll()
 for _,c in pairs(clients) do if c.tick then c.tick() end end
 run()
end
local function client(i,db)
 local env=setmetatable({},{__index=_G})
 local c={i=i,env=env,frames={},db=db or {}}
 clients[i]=c
 local function unit(u)
  if u=="player" then return players[i] end
  if not grouped then return nil end
  local index=tonumber(u:match("^party(%d)$"));if not index then return end
  local n=0
  for j,p in ipairs(players) do if j~=i then n=n+1;if n==index then return p end end end
 end
 env.HaploBox={db=c.db,Norm=function(n)return n:lower() end,UnitIdent=function(u)local p=unit(u);return p and p.name end}
 env.UnitGUID=function(u)local p=unit(u);return p and p.guid end
 env.UnitFullName=function(u)local p=unit(u);if p then return p.name,"Forever" end end
 env.GetUnitName=function(u)local p=unit(u);return p and p.name end
 env.UnitClass=function(u)local p=unit(u);if p then return p.class,p.class end end
 env.UnitRace=function(u)local p=unit(u);if p then return p.race,p.race end end
 env.UnitLevel=function(u)local p=unit(u);return p and p.level end
 env.UnitExists=function(u)return unit(u)~=nil end
 env.IsInGroup=function()return grouped end
 env.IsInRaid=function()return false end
 env.GetNumGroupMembers=function()return grouped and 3 or 0 end
 env.UnitIsGroupLeader=function(u)local p=unit(u);return p and p.guid==leader end
 env.InCombatLockdown=function()return combat[i] or false end
 env.GetTime=function()return now end
 env.C_Timer={After=later,NewTicker=function(interval,fn)assert(interval==10);c.tick=fn;return {} end}
 env.CreateFrame=function()
  local f={events={}}
  function f:RegisterEvent(e)self.events[e]=true end
  function f:UnregisterEvent(e)self.events[e]=nil end
  function f:SetScript(_,fn)self.fn=fn end
  c.frames[#c.frames+1]=f;return f
 end
 function c:emit(e,...)
  for _,f in ipairs(self.frames) do if f.events[e] and f.fn then f.fn(f,e,...) end end
 end
 env.C_ChatInfo={
  RegisterAddonMessagePrefix=function()return true end,
  SendAddonMessage=function(prefix,msg,channel,target)
   assert(#msg<=255 and channel=="WHISPER")
   messages[#messages+1]={from=i,target=target,msg=msg}
   if drop and drop(i,target,msg) then return true end
   for j,p in ipairs(players) do if p.name==target then
    later(.01,function()clients[j]:emit("CHAT_MSG_ADDON",prefix,msg,channel,players[i].name)end)
    return true
   end end
   return false
  end}
 for _,path in ipairs(args) do local fn=assert(loadfile(path));setfenv(fn,env);fn() end
 c.CM=env.HaploBox.CharacterManagement;c.T=env.HaploBox.TeamPlanner;c.S=env.HaploBox.RegisterSync;c.C=env.HaploBox.RegisterCodec
 c:emit("PLAYER_LOGIN");return c
end
local a,b,g=client(1),client(2),client(3)
run()
assert(a.CM.AddAccount("Account 1"));assert(a.CM.AddAccount("Account 2"))
local ss=assert(a.CM.Snapshot(false));assert(a.CM.Import(ss,{["P-1"]="account 1",["P-2"]="account 2"}))
run()
assert(#b.CM.Accounts()==0 and #g.CM.Accounts()==0)
assert(b.S.ActionLabel()=="Automatic register")
-- Untrusted first contact does not offer a manual override.
b.S.Action();run();assert(#b.CM.Accounts()==0)
-- Explicitly seeded own-character trust, as provided by the manager/legacy register.
b.env.HaploBox.TeamManagement={IsTrustedPartyMember=function(n)return n=="Warrior" end}
tickAll()
assert(#b.CM.Accounts()==2 and #b.CM.GetCharacters()==2)
assert(#g.CM.Accounts()==0 and not b.CM.GetCharacter("P-3"))
for _,m in ipairs(messages) do assert(m.target~="Guest","guest received registry traffic") end
assert(a.CM.AddAccount("Extra"));run();assert(#b.CM.Accounts()==3)
-- Save outside the party, then automatically replicate when regrouping.
grouped=false
a:emit("GROUP_ROSTER_UPDATE");b:emit("GROUP_ROSTER_UPDATE");g:emit("GROUP_ROSTER_UPDATE");run()
assert(a.T.Save("Team B",{{account="account 1",guid="P-1",role="tank"},{account="account 2",guid="P-2",role="dps"}}))
run();assert(not b.T.Active())
grouped=true
a:emit("GROUP_ROSTER_UPDATE");b:emit("GROUP_ROSTER_UPDATE");g:emit("GROUP_ROSTER_UPDATE");run()
assert(b.T.Active().name=="Team B")
leader="P-2"
a:emit("PARTY_LEADER_CHANGED");b:emit("PARTY_LEADER_CHANGED");g:emit("PARTY_LEADER_CHANGED");run()
assert(b.CM.AddAccount("Fourth"));run();assert(#a.CM.Accounts()==4)
assert(b.T.Save("Team B",{{account="account 2",guid="P-2",role="tank"},{account="account 1",guid="P-1",role="dps"}},"team b"))
run();assert(a.T.Active().slots[1].guid=="P-2")
-- Reload follower at a new level: no level-up polling; leader receives login data.
players[1].level=21
local db=a.db
a=client(1,db);run()
assert(b.CM.GetCharacter("P-1").level==21)
assert(a.CM.GetCharacter("P-1").level==21)
-- Invalid snapshots never modify active tables.
local payload=assert(b.C.Capture())
assert(b.C.Decode(payload));assert(not b.C.Decode(payload.."~X|00"))
assert(not b.C.Decode("V|1~A|61|62"))
assert(not b.C.Decode("V|1~C|P-9|61|61|61|61|61|1"))
local count=#a.CM.Accounts()
a:emit("CHAT_MSG_ADDON","JCDRREG1","H|999|deadbeef|10","PARTY","Guest");run()
assert(#a.CM.Accounts()==count)
-- Stale advertisements cannot replace a current register.
a:emit("CHAT_MSG_ADDON","JCDRREG1","H|1|deadbeef|10","WHISPER","Rogue");run()
assert(a.S.ActionLabel()=="Automatic register" and #a.CM.Accounts()==count)
print("Register sync tests passed: automatic trusted bootstrap, private own-GUID transfer, guest isolation, saved teams, leader handover, login refresh, stale and invalid snapshot rejection.")

-- First advertisement lost: no manual Sync Register required.
local lost=false
drop=function(i,target,msg)
 if not lost and i==2 and target=="Warrior" and msg:sub(1,2)=="H|" then lost=true;return true end
end
assert(b.CM.AddAccount("Heartbeat"));run()
assert(lost and #a.CM.Accounts()==count)
drop=nil;tickAll()
assert(#a.CM.Accounts()==count+1)
assert(a.S.ActionLabel()=="Automatic register")
-- Transfer chunk lost: timeout followed by periodic recovery.
lost=false
drop=function(i,target,msg)
 if not lost and i==2 and target=="Warrior" and msg:sub(1,2)=="D|" then lost=true;return true end
end
assert(b.CM.AddAccount("Retry"));run()
assert(lost and #a.CM.Accounts()==count+1)
drop=nil;tickAll()
assert(#a.CM.Accounts()==count+2)
-- Follower in combat accepts automatically on leaving combat.
combat[1]=true
assert(b.CM.AddAccount("Combat"));run()
assert(#a.CM.Accounts()==count+2)
combat[1]=false;a:emit("PLAYER_REGEN_ENABLED");run()
assert(#a.CM.Accounts()==count+3)
-- Missing leader/roster event on both clients; heartbeat detects current leader.
leader="P-1"
assert(a.CM.AddAccount("New leader"));run()
assert(#b.CM.Accounts()==count+4)
-- Independent leader edit at equal revision remains protected; clean follower
-- follows the trusted leader even when the version number matches.
local current=b.db.registerSync.rev
a.db.ownedCharacterCatalog.accounts["equal"]="Equal"
a.db.registerSync.rev=current
a.db.registerSync.dirty=true
tickAll()
assert(b.db.ownedCharacterCatalog.accounts.equal=="Equal")
assert(b.S.ActionLabel()=="Automatic register")
for _,m in ipairs(messages) do assert(m.target~="Guest","guest received registry traffic") end
print("Auto-sync recovery tests passed: lost announcement, missing data chunk, combat exit, leader change without event, trusted equal revision, guest isolation.")
