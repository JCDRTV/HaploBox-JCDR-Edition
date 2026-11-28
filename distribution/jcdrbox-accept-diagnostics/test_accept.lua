local group,raid,combat=false,false,false
local myGuid="g1"
local myName="Own Player"
local currentRealm="Forever"
local calls,sounds=0,0
local messages={}
local secret={}
issecretvalue=function(v)return v==secret end
IsInGroup=function()return group end
IsInRaid=function()return raid end
InCombatLockdown=function()return combat end
UnitGUID=function()return myGuid end
GetNormalizedRealmName=function()return currentRealm end
GetRealmName=GetNormalizedRealmName
AcceptGroup=function()calls=calls+1 end
CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end} end
local function rec(g,a,n,realm)return {guid=g,account=a,name=n,realm=realm or "Forever"} end
local chars={g1=rec("g1","a","Own Player"),g2=rec("g2","b","Trusted Friend"),g3=rec("g3","c","Other Friend")}
HaploBox={print=function(m)messages[#messages+1]=m end,db={autoAcceptInvite=true,ownedCharacterCatalog={schema=1,accounts={a="A",b="B",c="C"},characters=chars}},UnitIdent=function()return myName end,PlaySound=function()sounds=sounds+1 end}
assert(loadfile(arg[1]))()
local CM=HaploBox.CharacterManagement
local f=assert(io.open(arg[2],"r"));local source=f:read("*a");f:close()
local body=assert(source:match("(function handlers%.PARTY_INVITE_REQUEST%b()%s.-\nend)"))
local handlers={}
assert(loadstring("local handlers,HB=...;"..body))(handlers,HaploBox)
local function event(name,guid,native)
    handlers.PARTY_INVITE_REQUEST(name,false,false,true,native,true,guid)
end
event("Trusted Friend","g2",true);assert(calls==1 and sounds==1 and messages[#messages]:find("AcceptGroup requested",1,true))
event("Other Friend",nil,true);assert(calls==2 and sounds==2)
event("trusted friend",nil,nil);assert(calls==3 and sounds==3)
local function denied(name,guid,native)
    local before=#messages;event(name,guid,native);assert(calls==3 and sounds==3 and #messages==before+1 and not messages[#messages]:find("No diagnostic",1,true))
end
denied("Unknown Player");denied("Trusted");denied("Trusted Friend-Realm");denied("Own Player");denied(secret);denied("Trusted Friend","wrong");denied("Trusted Friend",secret);denied("Trusted Friend",nil,false)
group=true;denied("Trusted Friend");group=false
raid=true;denied("Trusted Friend");raid=false
combat=true;denied("Trusted Friend");combat=false
group=nil;denied("Trusted Friend");group=false
chars.g4=rec("g4","c","Trusted Friend","OtherRealm");denied("Trusted Friend");chars.g4=nil
chars.g2.realm="OtherRealm";denied("Trusted Friend");chars.g2.realm="Forever"
chars.g2.account="a";denied("Trusted Friend");chars.g2.account="b"
myGuid="unregistered";denied("Trusted Friend");myGuid="g1"
myName="Wrong Player";denied("Trusted Friend");myName="Own Player"
currentRealm="OtherRealm";denied("Trusted Friend");currentRealm="Forever"
HaploBox.db.autoAcceptInvite=false;denied("Trusted Friend");HaploBox.db.autoAcceptInvite=true
AcceptGroup=function()return false end;denied("Trusted Friend")
AcceptGroup=function()error("protected")end;denied("Trusted Friend")
print("Auto Accept tests passed: actual Core handler, registered identity, full name, optional GUID, realm and account checks, guest/ambiguous/group/combat/disabled/API failure left manual.")
