local group,raid,combat=false,false,false
local calls,sounds,hides=0,0,0
local myGuid="g1"
local myName="Own Player"
local secret={}
issecretvalue=function(v)return v==secret end
IsInGroup=function()return group end
IsInRaid=function()return raid end
InCombatLockdown=function()return combat end
UnitGUID=function()return myGuid end
AcceptGroup=function()calls=calls+1 end
local pending
C_Timer={After=function(t,fn) assert(t==0.1);pending=fn end}
StaticPopup_Hide=function()hides=hides+1 end
CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end} end
local function rec(g,a,n,r)return {guid=g,account=a,name=n,realm=r} end
local chars={g1=rec("g1","a","Own Player","Player"),g2=rec("g2","b","Trusted Friend","Friend"),g3=rec("g3","c","Other Friend","Friend")}
HaploBox={print=function()end,db={autoAcceptInvite=true,ownedCharacterCatalog={schema=1,accounts={a="A",b="B",c="C"},characters=chars}},UnitIdent=function()return myName end,PlaySound=function()sounds=sounds+1 end}
assert(loadfile(arg[1]))()
local f=assert(io.open(arg[2],"r"));local source=f:read("*a");f:close()
local body=assert(source:match("(function handlers%.PARTY_INVITE_REQUEST%b()%s.-\nend)"))
local handlers={}
assert(loadstring("local handlers,HB=...;"..body))(handlers,HaploBox)
local function event(name)handlers.PARTY_INVITE_REQUEST(name,false,false,true,false,false,true)end
event("Trusted Friend");assert(calls==1 and sounds==1 and pending)
pending();assert(hides==0)
group=true;pending();assert(hides==2);group=false
event("Other Friend");assert(calls==2 and sounds==2)
local function denied(n)event(n);assert(calls==2 and sounds==2)end
denied("Unknown Player");denied("Trusted");denied("Trusted Friend-Realm");denied("Own Player");denied(secret)
group=true;denied("Trusted Friend");group=false
raid=true;denied("Trusted Friend");raid=false
combat=true;denied("Trusted Friend");combat=false
chars.g4=rec("g4","c","Trusted Friend","Friend");denied("Trusted Friend");chars.g4=nil
chars.g2.account="a";denied("Trusted Friend");chars.g2.account="b"
myGuid="unregistered";denied("Trusted Friend");myGuid="g1"
myName="Wrong Player";denied("Trusted Friend");myName="Own Player"
HaploBox.db.autoAcceptInvite=false;denied("Trusted Friend");HaploBox.db.autoAcceptInvite=true
AcceptGroup=function()return false end;denied("Trusted Friend")
AcceptGroup=function()error("protected")end;denied("Trusted Friend")
assert(chars.g1.realm=="Player" and chars.g2.realm=="Friend")
print("Auto Accept tests passed: legacy event, surname records, unique CM full names, account checks, boolean extras ignored, popup cleanup only after join, manual guests and failures.")
