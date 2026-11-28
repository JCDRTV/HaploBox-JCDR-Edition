local args=arg
local env=setmetatable({},{__index=_G})
local frames={}
env.HaploBox={db={},UnitIdent=function()return "Warrior" end}
env.UnitGUID=function()return "Player-1" end
env.UnitFullName=function()return "Warrior","Forever" end
env.UnitClass=function()return "Warrior","WARRIOR" end
env.UnitRace=function()return "Human","Human" end
env.UnitLevel=function()return 1 end
env.IsInGroup=function()return false end
env.IsInRaid=function()return false end
env.InCombatLockdown=function()return false end
env.CreateFrame=function()
    local f={events={}}
    function f:RegisterEvent(e)self.events[e]=true end
    function f:UnregisterEvent(e)self.events[e]=nil end
    function f:SetScript(_,fn)self.fn=fn end
    frames[#frames+1]=f;return f
end
local function login()
    frames={}
    for _,p in ipairs(args) do local fn=assert(loadfile(p));setfenv(fn,env);fn() end
    for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then f.fn(f,"PLAYER_LOGIN") end end
end
login()
local CM=env.HaploBox.CharacterManagement
assert(CM.AddAccount("One"))
local s=assert(CM.Snapshot(true));assert(CM.Import(s,{["Player-1"]="one"}))
local current=env.JCDRRegisterCurrent
assert(env.JCDRRegisterBase=="V|1" and current:find("Player%-1"))
-- An unsent local change is not erased by an outdated inbox.
env.HaploBoxRegisterInbox="V|1"
login();assert(env.HaploBox.CharacterManagement.GetCharacter("Player-1"))
-- The manager receives this export and acknowledges it.
local C=env.HaploBox.RegisterCodec
env.HaploBoxRegisterReceipts=C.Hash("V|1~"..current).."-3-"..#current
env.HaploBoxRegisterInbox=current
login();assert(env.JCDRRegisterBase==current)
-- A fresh account gets the central register with no group.
env.HaploBox.db={};env.JCDRRegisterBase=nil;env.JCDRRegisterCurrent=nil
env.UnitGUID=function()return "Player-2" end
env.HaploBox.UnitIdent=function()return "Rogue" end
login();CM=env.HaploBox.CharacterManagement
assert(#CM.Accounts()==1 and CM.GetCharacter("Player-1"))
assert(CM.AddAccount("Two"))
s=assert(CM.Snapshot(true));assert(CM.Import(s,{["Player-2"]="two"}))
assert(env.JCDRRegisterBase==current and env.JCDRRegisterCurrent:find("Player%-2"))
print("Central addon bridge tests passed: solo registration, protected pending data, acknowledged migration and fresh-account import.")
