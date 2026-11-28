local chars={}
for i=1,5 do chars["g"..i]={guid="g"..i,account="a"..i,name="Char Name"..i,realm="Forever"} end
local team={id="team",name="Team",slots={}}
for i=1,5 do team.slots[i]={account="a"..i,guid="g"..i,role="dps"} end
local allowed=true
local me="g1"
local roster={"g1"}
local now=100
local sent={}
local reject
UnitGUID=function() return me end
GetTime=function() return now end
IsInGroup=function() return #roster>1 end
C_PartyInfo={InviteUnit=function(name) sent[#sent+1]=name;if name==reject then return false end end}
local function rows()
    local list={}
    for _,g in ipairs(roster) do list[#list+1]=chars[g] or {guid=g} end
    return {rows=list}
end
HaploBox={db={plannedTeams={schema=1,active="team",teams={team=team}}},CharacterManagement={
    CanEdit=function()return allowed end,
    Snapshot=rows,
    GetCharacters=function()local a={} for _,r in pairs(chars) do a[#a+1]=r end;return a end,
    GetCharacter=function(g)return chars[g] end,
    RemoveCharacter=function()end,SetAccount=function()end,Import=function()end}}
assert(loadfile(arg[1]))()
local T=HaploBox.TeamPlanner
local ok,msg=T.InviteActive()
assert(ok and #sent==4 and sent[1]=="Char Name2" and sent[4]=="Char Name5")
assert(msg:find("4 invite request",1,true))
T.InviteActive();assert(#sent==4)
roster={"g1","g2","g3"}
now=121
T.InviteActive();assert(#sent==6 and sent[5]=="Char Name4" and sent[6]=="Char Name5")
roster={"g1","g2","g3","g4","g5"}
assert(T.InviteActive());assert(#sent==6)
roster={"g1","guest"}
assert(not T.InviteActive());assert(#sent==6)
roster={"g1"}
allowed=false
assert(not T.InviteActive());assert(#sent==6)
allowed=true
me="guest";roster={"guest"}
assert(not T.InviteActive());assert(#sent==6)
me="g2";roster={"g2"}
local plan=T.InvitePlan();assert(#plan==4 and plan[1].guid=="g1")
chars.g3.name="Char"
assert(not T.InviteActive());assert(#sent==6)
chars.g3.name="Char Name3"
chars.extra={guid="extra",account="extra",name="Char Name3"}
assert(not T.InviteActive());assert(#sent==6)
chars.extra=nil
reject="Char Name3";now=200
assert(not T.InviteActive());assert(#sent==10)
HaploBox.db.plannedTeams.active=nil
assert(not T.InviteActive());assert(#sent==10)
print("Invite tests passed: solo or actual leader, any active member, all missing only in POS order, full name, GUID guards, cooldown, outsider/invalid/ambiguous refusal, API rejection.")
