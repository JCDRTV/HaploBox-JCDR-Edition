-- JB26.3.2: local bridge, no party or addon messages.
local HB=HaploBox
local CM,T,C=HB.CharacterManagement,HB.TeamPlanner,HB.RegisterCodec
local S={}
HB.RegisterSync=S
local ready=false
local base="V|1"
local status="Central register not initialized."
local function say(msg,changed)
    status=msg
    if S.OnChange then S.OnChange(changed) end
end
function S.Status()return status end
function S.ActionLabel()return "Register status" end
local function export()
    if not ready then return end
    local data,why=C.Capture()
    if not data then say("Register export blocked: "..tostring(why));return end
    JCDRRegisterBase=base
    JCDRRegisterCurrent=data
    say(data==base and "Central register loaded." or "Local changes: /reload or logout to save for BoxManager.")
end
function S.Action()export() end
local function signature(b,c)
    return C.Hash(b.."~"..c).."-"..#b.."-"..#c
end
local function valid(data)
    if type(data)~="string" then return nil end
    return C.Decode(data)
end
local function acknowledged(b,c)
    if type(HaploBoxRegisterReceipts)~="string" then return false end
    return (","..HaploBoxRegisterReceipts..","):find(","..signature(b,c)..",",1,true)~=nil
end
local function login()
    local current=C.Capture()
    if not current then say("Local register invalid; not replaced.");return end
    local priorBase,priorCurrent=JCDRRegisterBase,JCDRRegisterCurrent
    local incoming=HaploBoxRegisterInbox
    local parsed=valid(incoming)
    local priorValid=valid(priorBase) and valid(priorCurrent)
    -- First-time migration: do not discard existing independent data.
    local pending=priorValid and priorBase~=priorCurrent and not acknowledged(priorBase,priorCurrent) and incoming~=priorCurrent
    if not priorValid and current~="V|1" and current~=incoming then pending=true end
    -- CM login refresh can change metadata after the previous logout; preserve it.
    if parsed and not pending then
        HB.db.ownedCharacterCatalog=parsed.cm
        HB.db.plannedTeams=parsed.tm
        base=incoming
        CM.RefreshLogin()
    else
        base=priorValid and priorBase or "V|1"
    end
    ready=true
    export()
    if pending and parsed then say("Local migration or unsent changes: save, let BoxManager collect, then reload.") end
end
for _,pair in ipairs({{CM,"AddAccount"},{CM,"RemoveAccount"},{CM,"Import"},{CM,"SetAccount"},{CM,"RemoveCharacter"},{T,"Save"},{T,"Select"},{T,"Delete"}}) do
    local obj,k=pair[1],pair[2]
    local old=obj[k]
    obj[k]=function(...)
        local ok,result=old(...)
        if ok then export() end
        return ok,result
    end
end
local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then login() else export() end
end)
