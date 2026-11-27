-- HF26.20.53 TEST / TEAM-01: read-only character and active-team registry.
-- No protected actions, no changes to team roles, no duplicate UI or polling.
local HB, H = HaploBox, HaploBoxA4
local R = {}
HB.CharacterRegistry = R
local active, activeKey, leaderGUID = {}, nil, nil
local liveSpecs, pending, forceSend, lastSent = {}, false, false, nil
local db
local function secret(v) return issecretvalue and issecretvalue(v) end
local function safe(v)
    if secret(v) then return nil end
    return v
end
local function str(v)
    v = safe(v)
    if type(v) == "string" and v ~= "" then return v end
end
local function num(v)
    v = safe(v)
    if type(v) == "number" and v == v and v >= 0 and v < 1000000000 then return v end
end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok,a,b,c,d,e = pcall(fn,...)
    if ok then return safe(a),safe(b),safe(c),safe(d),safe(e) end
end
local function now() return call(GetServerTime) or call(time) or 0 end
local function copy(t)
    local o = {}
    for k,v in pairs(t or {}) do o[k] = v end
    return o
end
local function units()
    local t = {"player"}
    if IsInGroup() and not IsInRaid() then
        for i=1,4 do
            local u = "party"..i
            if UnitExists(u) then t[#t+1] = u end
        end
    end
    return t
end
local function identity(u)
    local guid = str(call(UnitGUID,u))
    local name, realm = call(UnitFullName,u)
    name = str(name)
    if not name then name,realm = call(UnitName,u) end
    name = str(name)
    realm = str(realm) or str(call(GetNormalizedRealmName)) or str(call(GetRealmName))
    if not guid or not name or not realm then return end
    return guid,name,realm
end
local function canonical(name)
    name = str(name)
    if not name then return end
    return name:lower():gsub("%s+",""):gsub("'","")
end
local function ownSpec()
    local idx = num(call(GetSpecialization))
    if idx and idx > 0 then
        local id,name = call(GetSpecializationInfo,idx)
        if num(id) and str(name) then return name,"specialization" end
    end
    -- Classic: only a unique dominant talent tree, never guess from role.
    local count = num(call(GetNumTalentTabs))
    if not count or count < 1 or count > 10 then return nil,"unknown" end
    local best,highest,tied = nil,0,false
    for i=1,count do
        local a,b,c,d,e = call(GetTalentTabInfo,i)
        local name,points
        if type(a) == "string" then name,points = str(a),num(c)
        elseif type(a) == "number" then name,points = str(b),num(e) end
        if not name or not points then return nil,"unknown" end
        if points > highest then best,highest,tied = name,points,false
        elseif points == highest and points > 0 then tied = true end
    end
    if best and not tied then return best,"talent_tree" end
    return nil,"unknown"
end
local function role(name)
    local r = call(HB.RoleOf,name)
    if r == "tank" or r == "healer" or r == "dps" then return r end
end
local function init()
    if db then return true end
    if not HB.db then return false end
    if type(HB.db.characterRegistry) ~= "table" then HB.db.characterRegistry = {} end
    db = HB.db.characterRegistry
    if type(db.characters) ~= "table" then db.characters = {} end
    db.schema = 1
    return true
end
local function refresh()
    if not init() then return end
    local nextActive,keys,nextLeader = {},{},nil
    for _,u in ipairs(units()) do
        local guid,name,realm = identity(u)
        if guid then
            local old = db.characters[guid]
            if type(old) ~= "table" then old = {} end
            local rec = copy(old)
            local _,class = call(UnitClass,u)
            local _,race = call(UnitRace,u)
            local level = num(call(UnitLevel,u))
            local online = u == "player" or call(UnitIsConnected,u) == true
            rec.guid,rec.name,rec.realm = guid,name,realm
            rec.class = str(class) or rec.class
            rec.race = str(race) or rec.race
            if level and level > 0 then rec.level = level end
            rec.role = role(name.."-"..realm) or role(name) or rec.role
            if online then rec.lastSeen = now() end
            local spec,source
            if u == "player" then
                spec,source = ownSpec()
            elseif online and liveSpecs[guid] then
                spec,source = liveSpecs[guid].name,liveSpecs[guid].source
            end
            if source then
                rec.spec,rec.specSource,rec.specUpdated = spec,source,now()
            end
            db.characters[guid] = rec
            if not online then liveSpecs[guid] = nil end
            local live = copy(rec)
            live.unit,live.online = u,online
            live.role = role(name.."-"..realm) or role(name)
            live.specStatus = source and (spec and "current" or "unknown") or (rec.spec and "last_known" or "unknown")
            if call(UnitIsGroupLeader,u) == true or (u == "player" and not IsInGroup()) then nextLeader = guid end
            nextActive[guid] = live
            keys[#keys+1] = guid
        end
    end
    for guid in pairs(liveSpecs) do if not nextActive[guid] then liveSpecs[guid] = nil end end
    table.sort(keys)
    active,activeKey,leaderGUID = nextActive,table.concat(keys,";"),nextLeader
end
local function announce(force)
    if not H or not H.SendTeam or not H.db or not IsInGroup() or IsInRaid() then return end
    local name,source = ownSpec()
    if name and (#name > 80 or name:find("[|,\r\n%c]")) then name,source = nil,"unknown" end
    local payload = source..","..(name or "")
    if not force and lastSent == payload then return end
    if H.SendTeam("CR1",payload) > 0 then lastSent = payload end
end
local function queue(sendForce)
    forceSend = forceSend or sendForce
    if pending then return end
    pending = true
    C_Timer.After(0.5,function()
        local forced = forceSend
        pending,forceSend = false,false
        refresh()
        announce(forced)
    end)
end
local function receive(prefix,msg,channel,sender)
    if not H or prefix ~= H.PREFIX or channel ~= "WHISPER" or not H.Trusted then return end
    if not str(msg) or #msg > 120 or not str(sender) or not H.Trusted(sender) then return end
    local source,name = msg:match("^1|CR1|([%a_]+),(.*)$")
    if not source or (source ~= "unknown" and source ~= "specialization" and source ~= "talent_tree") then return end
    if #name > 80 or name:find("[|,\r\n%c]") or (source == "unknown" and name ~= "") or (source ~= "unknown" and name == "") then return end
    local found
    for _,u in ipairs(units()) do
        if u ~= "player" and call(UnitIsConnected,u) == true then
            local guid,n,realm = identity(u)
            if guid and canonical(n.."-"..realm) == canonical(sender) then
                if found then return end
                found = guid
            end
        end
    end
    -- Some clients report only the short name: accept only an unambiguous
    -- same-realm roster identity, and still require existing H.Trusted.
    if not found and not sender:find("-",1,true) then
        local myRealm = str(call(GetNormalizedRealmName)) or str(call(GetRealmName))
        for _,u in ipairs(units()) do
            local guid,n,realm = identity(u)
            if guid and canonical(n) == canonical(sender) then
                if found or u == "player" or canonical(realm) ~= canonical(myRealm) or call(UnitIsConnected,u) ~= true then return end
                found = guid
            end
        end
    end
    if found then
        liveSpecs[found] = {name=name ~= "" and name or nil,source=source}
        queue(false)
    end
end
function R.GetCharacter(guid)
    if not init() or type(guid) ~= "string" or secret(guid) then return nil end
    local rec = active[guid] or db.characters[guid]
    if not rec then return nil end
    local result = copy(rec)
    if not active[guid] then result.online=nil; result.specStatus=rec.spec and "last_known" or "unknown" end
    return result
end
function R.GetActiveTeam()
    local members = {}
    for guid in pairs(active) do members[#members+1] = R.GetCharacter(guid) end
    table.sort(members,function(a,b) return a.guid < b.guid end)
    return {key=activeKey,leaderGUID=leaderGUID,members=members}
end
function R.GetCharacters()
    local result = {}
    if init() then for guid in pairs(db.characters) do result[#result+1] = R.GetCharacter(guid) end end
    table.sort(result,function(a,b) return a.guid < b.guid end)
    return result
end
function R.Refresh() refresh() end
function R.Diagnose()
    refresh()
    local team=R.GetActiveTeam()
    print("HaploBox Registry: "..#team.members.." active / "..#R.GetCharacters().." recorded")
    for _,m in ipairs(team.members) do
        print(m.name.."-"..m.realm.." | "..(m.class or "?").." | lvl "..(m.level or "?").." | "..(m.role or "?").." | "..(m.spec or "?").." ("..m.specStatus..")"..(m.guid==team.leaderGUID and " | LEADER" or "")..(m.online and "" or " | OFFLINE"))
    end
end
local previous = SlashCmdList.HAPLOBOX
SlashCmdList.HAPLOBOX = function(input)
    if (input or ""):match("^%s*registry%s*$") then R.Diagnose() else return previous(input) end
end
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent",function(_,event,...)
    if event=="CHAT_MSG_ADDON" then receive(...)
    elseif event=="UNIT_NAME_UPDATE" or event=="UNIT_LEVEL" or event=="UNIT_CONNECTION" then queue(false)
    else queue(event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" or event=="GROUP_ROSTER_UPDATE") end
end)
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","PARTY_LEADER_CHANGED","PLAYER_LEVEL_UP","UNIT_LEVEL","UNIT_NAME_UPDATE","UNIT_CONNECTION","PLAYER_TALENT_UPDATE","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_SPECIALIZATION_CHANGED","ROLE_CHANGED_INFORM","PLAYER_ROLES_ASSIGNED","CHAT_MSG_ADDON"}) do
    pcall(frame.RegisterEvent,frame,event)
end
-- Existing role/team refresh path (including received role messages).
if hooksecurefunc and type(HB.RefreshTeam) == "function" then
    hooksecurefunc(HB,"RefreshTeam",function() queue(false) end)
end
