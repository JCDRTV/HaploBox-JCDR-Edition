local args=arg
local bit=require("bit")
local t,events,clients,messages=0,{},{},{}
local drop
local players={
 {guid="P-1",name="Warrior",class="WARRIOR",race="Human",level=20,account="one"},
 {guid="P-2",name="Rogue",class="ROGUE",race="NightElf",level=15,account="two"},
 {guid="P-3",name="Guest",class="MAGE",race="Gnome",level=12,account="guest"},
 {guid="P-4",name="Priest",class="PRIEST",race="Dwarf",level=15,account="three"}}
local key=string.rep("ab",32)
local function cp(x)
 if type(x)~="table" then return x end
 local r={};for k,v in pairs(x) do r[k]=cp(v) end;return r
end
local seed={schema=1,accounts={one="One",two="Two",three="Three"},characters={}}
for i=1,2 do local p=players[i];seed.characters[p.guid]={guid=p.guid,name=p.name,realm="Forever",class=p.class,race=p.race,level=p.level,account=p.account} end
local function later(delay,fn)events[#events+1]={at=t+delay,fn=fn} end
local function advance(seconds)
 local untilTime=t+seconds
 local nextTick=t+5
 local n=0
 while true do
  table.sort(events,function(a,b)return a.at<b.at end)
  local e=events[1]
  if nextTick<=untilTime and (not e or nextTick<=e.at) then
   t=nextTick;nextTick=nextTick+5
   for _,c in pairs(clients) do for _,fn in ipairs(c.tickers) do fn() end end
  elseif e and e.at<=untilTime then t=e.at;table.remove(events,1);e.fn()
  else t=untilTime;break end
  n=n+1;assert(n<50000,"event limit")
 end
end
local function client(i,shared)
 local env=setmetatable({bit=bit},{__index=_G})
 local c={i=i,env=env,frames={},tickers={}}
 clients[i]=c
 local p=players[i]
 local db={ownedCharacterCatalog=cp(seed),plannedTeams={schema=1,teams={}},registerSync={schema=1,rev=10,dirty=false,bridgeKey=shared and key or string.rep("ff",32)}}
 c.db=db
 env.HaploBox={db=db,Norm=function(n)return n:lower() end,UnitIdent=function(u)return u=="player" and p.name end}
 env.UnitGUID=function(u)return u=="player" and p.guid or nil end
 env.UnitFullName=function(u)if u=="player" then return p.name,"Forever" end end
 env.GetUnitName=function(u)return u=="player" and p.name or nil end
 env.UnitClass=function(u)if u=="player" then return p.class,p.class end end
 env.UnitRace=function(u)if u=="player" then return p.race,p.race end end
 env.UnitLevel=function(u)return u=="player" and p.level or nil end
 env.UnitExists=function(u)return u=="player" end
 env.IsInGroup=function()return false end
 env.IsInRaid=function()return false end
 env.GetNumGroupMembers=function()return 0 end
 env.UnitIsGroupLeader=function()return false end
 env.InCombatLockdown=function()return false end
 env.GetTime=function()return t end
 env.GetServerTime=function()return 100000+math.floor(t) end
 env.C_Timer={After=later,NewTicker=function()error("Unexpected periodic peer ticker") end}
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
   assert(not msg:find(key,1,true),"secret transmitted")
   messages[#messages+1]={from=i,target=target,msg=msg,prefix=prefix}
   if drop and drop(i,target,msg) then return true end
   for j,pp in ipairs(players) do if pp.name==target and clients[j] then
    later(.01,function()clients[j]:emit("CHAT_MSG_ADDON",prefix,msg,channel,p.name)end)
    return true
   end end
   return false
  end}
 for _,path in ipairs(args) do local fn=assert(loadfile(path));setfenv(fn,env);fn() end
 local H=env.HaploBox
 c.CM,c.T,c.S,c.C,c.A=H.CharacterManagement,H.TeamPlanner,H.RegisterSync,H.RegisterCodec,H.RegisterPeerAuth
 assert(c.A.HMAC("key","The quick brown fox jumps over the lazy dog")=="f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")
 c:emit("PLAYER_LOGIN");c:emit("PLAYER_ENTERING_WORLD");return c
end
local a,b,g,p=client(1,true),client(2,true),client(3,false),client(4,true)
advance(50)
assert(#p.CM.Accounts()==3 and not p.CM.GetCharacter("P-4"))
assert(a.CM.AddAccount("Extra"))
assert(a.T.Save("Team B",{{account="one",guid="P-1",role="tank"},{account="two",guid="P-2",role="dps"}}))
advance(50)
assert(#b.CM.Accounts()==4 and b.T.Active().name=="Team B")
assert(#p.CM.Accounts()==4 and p.T.Active().name=="Team B")
assert(#g.CM.Accounts()==3 and not g.T.Active())
-- Previously unregistered character on an already initialized account registers once.
local ss=assert(p.CM.Snapshot(true))
assert(p.CM.Import(ss,{["P-4"]="three"}))
advance(50)
assert(a.CM.GetCharacter("P-4") and b.CM.GetCharacter("P-4"))
-- Missing packet recovery without a button.
local lost=false
drop=function(i,target,msg)
 if not lost and i==2 and target=="Warrior" and msg:match("^%x+|D|") then lost=true;return true end
end
assert(b.CM.AddAccount("Retry"));advance(15)
assert(lost)
drop=nil;advance(180)
local idle=#messages;advance(600);assert(#messages==idle,"Idle peer traffic")
a:emit("PLAYER_LOGIN");advance(100)
assert(a.db.ownedCharacterCatalog.accounts.retry=="Retry")
assert(p.db.ownedCharacterCatalog.accounts.retry=="Retry")
-- A guest with the wrong key may not receive register payloads or overwrite.
local wrong=g.A.Sign(g.db.registerSync.bridgeKey,"guest|Q|P-3|999|deadbeef|10")
a:emit("CHAT_MSG_ADDON","JCDRPEER1",wrong.."|Q|P-3|999|deadbeef|10","WHISPER","Guest")
advance(10)
for _,m in ipairs(messages) do assert(m.target~="Guest","guest received register traffic") end
assert(not a.CM.GetCharacter("P-3"))
-- Independent edits are not silently overwritten.
assert(a.CM.AddAccount("Fork A"));assert(b.CM.AddAccount("Fork B"))
advance(50)
assert(a.db.ownedCharacterCatalog.accounts["fork a"] and not a.db.ownedCharacterCatalog.accounts["fork b"])
assert(b.db.ownedCharacterCatalog.accounts["fork b"] and not b.db.ownedCharacterCatalog.accounts["fork a"])
print("Central peer tests passed: HMAC vector, solo cross-account sync, unregistered initialized client, one-time registration, retry, guest rejection, conflicting edits protected.")

advance(600);local idle=#messages;advance(600);assert(#messages==idle,"Idle peer traffic after changes")
