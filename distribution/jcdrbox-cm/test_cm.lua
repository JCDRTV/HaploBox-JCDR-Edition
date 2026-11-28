local units={
 player={guid="P-1",name="Mael Ashgrove",class="DRUID",race="NightElf",level=27},
 party1={guid="P-2",name="Lyra Ashgrove",class="DRUID",race="NightElf",level=26},
 party2={guid="P-3",name="Guest",class="MAGE",race="Human",level=20}
}
local grouped,leader,combat=true,true,false
HaploBox={db={},UnitIdent=function(u)return units[u] and units[u].name end}
function UnitGUID(u)return units[u] and units[u].guid end
function UnitFullName(u)return units[u].name,"Forever" end
function UnitClass(u)return units[u].class,units[u].class end
function UnitRace(u)return units[u].race,units[u].race end
function UnitLevel(u)return units[u].level end
function UnitExists(u)return units[u]~=nil end
function IsInGroup()return grouped end
function IsInRaid()return false end
function GetNumGroupMembers()return grouped and 3 or 0 end
function UnitIsGroupLeader()return leader end
function InCombatLockdown()return combat end
function CreateFrame()return {RegisterEvent=function()end,UnregisterEvent=function()end,SetScript=function()end} end
dofile(arg[1])
local C=HaploBox.CharacterManagement
assert(#C.GetCharacters()==0)
assert(C.AddAccount("WoW1"));assert(C.AddAccount("WoW2"));assert(not C.AddAccount("wow1"))
local s=assert(C.Snapshot(false));assert(#s.rows==3)
assert(not C.Import(s,{["P-1"]="wow1",["P-2"]="wow1"}));assert(#C.GetCharacters()==0)
assert(not C.Import(s,{["P-1"]="wow1",["P-2"]="missing"}));assert(#C.GetCharacters()==0)
assert(C.Import(s,{["P-1"]="wow1",["P-2"]="wow2"}));assert(#C.GetCharacters()==2)
assert(not C.GetCharacter("P-3"));assert(not C.GetCharacter("P-1").role)
units.player.level=28
assert(C.Import(s,{["P-1"]="wow1"}));assert(C.GetCharacter("P-1").level==27)
assert(C.RefreshLogin());assert(C.GetCharacter("P-1").level==28)
assert(C.GetCharacter("P-2").level==26)
assert(not C.RemoveAccount("wow1"))
leader=false
assert(not C.AddAccount("WoW3"));assert(not C.RemoveCharacter("P-1"));assert(not C.Snapshot(false));assert(not C.SetAccount("P-1","wow2"))
leader=true;combat=true;assert(not C.Import(s,{["P-1"]="wow1"}));combat=false
units.party2.guid="P-4";assert(not C.Import(s,{["P-1"]="wow1"}))
grouped=false
local solo=assert(C.Snapshot(true));assert(#solo.rows==1)
assert(C.SetAccount("P-1","wow2"));assert(C.GetCharacter("P-1").account=="wow2")
assert(C.RemoveAccount("wow1"));assert(C.RemoveCharacter("P-2"));assert(#C.GetCharacters()==1)
assert(C.Import(solo,{["P-1"]="wow2"}));assert(#C.GetCharacters()==1)
print("CM tests passed: explicit ownership, account uniqueness, atomic import, stale roster, leader/combat guards, login refresh, solo registration.")
