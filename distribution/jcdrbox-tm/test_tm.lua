local grouped,leader,combat=false,true,false
local chars={a={guid="a",name="A",account="one",class="MAGE"},b={guid="b",name="B",account="two",class="PRIEST"},c={guid="c",name="C",account="one",class="ROGUE"},d={guid="d",name="D",account="three",class="PALADIN"}}
HaploBox={db={},CharacterManagement={
    CanEdit=function()return not combat and (not grouped or leader) end,
    GetCharacter=function(id)return chars[id] end,
    RemoveCharacter=function(id)chars[id]=nil;return true end,
    SetAccount=function(id,account)chars[id].account=account;return true end,
    Import=function()return true end
}}
function IsInGroup()return grouped end
dofile(arg[1])
local T,CM=HaploBox.TeamPlanner,HaploBox.CharacterManagement
local function slot(account,guid,role)return {account=account,guid=guid,role=role} end
local a,b,c,d=slot("one","a","dps"),slot("two","b","dps"),slot("one","c","tank"),slot("three","d","healer")
assert(not T.Save("A",{a}))
assert(not T.Save("A",{a,c}))
assert(not T.Save("A",{a,[3]=b}))
assert(not T.Save("A",{a,slot("three","b","heal")}))
assert(T.Save("Team B",{a,b}))
assert(T.Active().name=="Team B")
assert(not T.Save("team b",{a,b}))
assert(T.Save("Team C",{c,d}))
assert(T.Active().id=="team c")
assert(T.Select("team b"))
assert(T.Active().slots[1].guid=="a")
local x=T.Active();x.slots[1].guid="c";assert(T.Active().slots[1].guid=="a")
assert(not CM.RemoveCharacter("a"));assert(not CM.SetAccount("a","three"));assert(not CM.Import({}, {a="three"}))
grouped=true
assert(not T.Select("team c"));assert(not T.Save("Team D",{a,b}));assert(not T.Delete("team b"))
assert(not T.Save("Team B",{c,b},"team b"))
assert(T.Save("Team B",{slot("two","b","healer"),a},"team b"))
assert(T.Active().slots[1].guid=="b")
leader=false;assert(not T.Save("Team B",{a,b},"team b"));assert(not T.Select("team b"))
leader=true;combat=true;assert(not T.Save("Team B",{a,b},"team b"))
combat=false;grouped=false
assert(T.Delete("team b"));assert(not T.Active());assert(CM.RemoveCharacter("a"))
assert(T.Select("team c"));assert(#T.List()==1)
-- Reload preserves the catalog and active team.
dofile(arg[1]);assert(HaploBox.TeamPlanner.Active().name=="Team C")
print("TM tests passed: 2-5 consecutive slots, duplicate accounts, role checks, active persistence, party restrictions, CM reference protection.")
