-- HaploBox Alpha 3: local-click group actions and authenticated, shared toggles.
-- No auto-follow, auto-focus, auto-promote or remote party-leave action.
local HB = HaploBox
local function notice(s) if HB.print then HB.print(s) end end
local function norm(n) return HB.Norm(n) end
local function safe(v) return v ~= nil and (not HB.secret or not HB.secret(v)) end

function HB.IsGroupMember(name)
    local key = norm(name)
    if not key or not IsInGroup() then return false end
    for _, u in ipairs({"player", "party1", "party2", "party3", "party4"}) do
        if UnitExists(u) then
            local actual = norm(HB.UnitIdent(u))
            if actual == key or (HB.SameTeamMember and HB.SameTeamMember(name, HB.UnitIdent(u))) then
                return true
            end
        end
    end
    return false
end

-- The explicit trusted list is never expanded by joining a random pickup party.
-- Single-word entries intentionally accept a matching Forever 'Name Surname'.
local function trustedList()
    local out = {}
    for entry in tostring(HB.db and HB.db.trustedMembers or ""):gmatch("[^,]+") do
        local clean = entry:match("^%s*(.-)%s*$")
        if clean and clean ~= "" then out[#out + 1] = clean end
    end
    return out
end
function HB.IsKnownTeam(name)
    local n = norm(name)
    if not n then return false end
    for _, entry in ipairs(trustedList()) do
        local e = norm(entry)
        if e == n or (e and not e:find("[ %%-]") and n:match("^([^ %%-]+)") == e) then
            return true
        end
    end
    return false
end
-- Match a trusted one-word nickname to its full Forever character name,
-- but never merge two different full names that happen to share a first word.
function HB.SameTeamMember(a,b)
    local x,y=norm(a),norm(b)
    if not x or not y then return false end
    if x==y then return true end
    local short,full
    if not x:find("[ %%-]") then short,full=x,y
    elseif not y:find("[ %%-]") then short,full=y,x
    else return false end
    return HB.IsKnownTeam(short) and HB.IsKnownTeam(full) and
        full:match("^([^ %%-]+)")==short
end

function HB.PromoteName(name)
    if not IsInGroup() or not HB.IAmLeader() then
        notice("Only the current party leader can promote another member.") return false
    end
    if not HB.IsGroupMember(name) then notice("That character is not in your party.") return false end
    if norm(name) == norm(HB.UnitIdent("player")) then return false end
    if InCombatLockdown and InCombatLockdown() then notice("Leader switch unavailable during combat.") return false end
    local promote = (C_PartyInfo and C_PartyInfo.PromoteToLeader) or PromoteToLeader
    if not promote then notice("This client has no supported promote API.") return false end
    local ok, result = pcall(promote, name)
    if not ok or result == false then notice("WoW rejected leader switch: " .. tostring(result)) return false end
    notice("Requested party leader: " .. name)
    return true
end

function HB.AssignMyHealer()
    if not IsInGroup() then notice("Join the party before assigning healer.") return false end
    local me = HB.UnitIdent("player")
    if not me or not HB.SetRoleLocal then return false end
    HB.SetRoleLocal(me, "healer")
    if HB.SendTeamMessage then HB.SendTeamMessage("H|me") end
    if HB.RefreshTeam then HB.RefreshTeam() end
    notice("Healer: " .. me .. " (sent to group).")
    return true
end

function HB.ApplyQuestEnabled(on, broadcast)
    if not HB.db then return end
    HB.db.questEnabled = not not on
    HB.db.autoShareQuests = on and "leader" or "off"
    HB.db.autoAcceptShared = not not on
    if broadcast and HB.SendTeamMessage then HB.SendTeamMessage("Q|" .. (on and "1" or "0")) end
    if HB.RefreshControls then HB.RefreshControls() end
end
function HB.ToggleQuest()
    if not HB.IAmLeader() or not IsInGroup() then notice("Only the party leader may toggle QUEST.") return end
    HB.ApplyQuestEnabled(not HB.db.questEnabled, true)
end
function HB.ToggleTrade()
    if not HB.IAmLeader() or not IsInGroup() then notice("Only the party leader may toggle TRADE.") return end
    HB.db.tradeEnabled = not HB.db.tradeEnabled
    if HB.SendTeamMessage then HB.SendTeamMessage("V|" .. (HB.db.tradeEnabled and "1" or "0")) end
    if HB.RefreshControls then HB.RefreshControls() end
end

-- The default trusted list stores first names, but Forever's actual /invite
-- targets are full "Name Surname" names. These five names are the user-approved
-- Team A roster; custom trusted names are still supported as entered.
local TEAM_A_FULL={
    mael="Mael Ashgrove",lyra="Lyra Ashgrove",elya="Elya Ashgrove",
    nyra="Nyra Ashgrove",ayla="Ayla Ashgrove",
}
local inviteQueue,inviting={},false
local function inviteName(name)
    if not (name and safe(name)) then return nil end
    local k=norm(name)
    if not k then return nil end
    if k:find("[ %%-]") then return name end -- synced real full name
    return TEAM_A_FULL[k] or name
end
local function inviteMissingList()
    local byKey={}
    local roster=HaploBoxTeam and HaploBoxTeam.order or {}
    -- Include explicitly trusted roster identities first; never invite outsiders
    -- based on an earlier random PUG party.
    for _,name in ipairs(roster) do
        if HB.IsKnownTeam(name) then
            local key=(norm(name) or ""):match("^([^ %%-]+)")
            if key then byKey[key]=inviteName(name) end
        end
    end
    -- The trusted list is authoritative for ungrouped members, including a
    -- character who has not yet been added to the synced team roster.
    for _,name in ipairs(trustedList()) do
        local key=(norm(name) or ""):match("^([^ %%-]+)")
        if key and not byKey[key] then byKey[key]=inviteName(name) end
    end
    local list={}
    for _,name in pairs(byKey) do
        if name and norm(name)~=norm(HB.UnitIdent("player"))
           and not (HB.SameTeamMember and HB.SameTeamMember(name,HB.UnitIdent("player")))
           and not HB.IsGroupMember(name) then
            list[#list+1]=name
        end
    end
    table.sort(list)
    return list
end
local function sendNextInvite()
    if #inviteQueue==0 then
        inviting=false
        notice("Invite Team: requests finished; check actual party joins.")
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        inviting=false;inviteQueue={}
        notice("Invite Team cancelled in combat; retry afterward.")
        return
    end
    if IsInGroup() and not HB.IAmLeader() then
        inviting=false;inviteQueue={}
        notice("Invite Team stopped: you are no longer the party leader.")
        return
    end
    local name=table.remove(inviteQueue,1)
    if not HB.IsGroupMember(name) then
        local invite=InviteUnit or (C_PartyInfo and C_PartyInfo.InviteUnit)
        if not invite then
            notice("Invite Team failed: no compatible invite API.")
            inviteQueue={};inviting=false
            return
        end
        -- The API returns no reliable confirmation of an accepted invite.
        local ok,result=pcall(invite,name)
        if not ok or result==false then
            notice("Invite rejected for "..name..": "..tostring(result))
        else
            notice("Invite sent to "..name.." (join not yet confirmed).")
        end
    end
    if #inviteQueue>0 then
        -- A short gap gives Forever time to register each invitation; do not
        -- send four /invite requests in one frame and trip server throttling.
        if C_Timer and C_Timer.After then C_Timer.After(1.5,sendNextInvite)
        else
            inviting=false
            notice("Click INVITE PARTY again to send the next invite on this client.")
        end
    else
        inviting=false
        notice("Invite Team: all requests sent; check actual group joins.")
    end
end
function HB.InviteTeam()
    if inviting then notice("Invite Team already sending requests.") return end
    if InCombatLockdown and InCombatLockdown() then notice("Invite Team is unavailable during combat.") return end
    if IsInGroup() and not HB.IAmLeader() then
        notice("Only the party leader can send team invites.") return
    end
    local list=inviteMissingList()
    if #list==0 then notice("No missing trusted characters to invite.") return end
    -- Never fill beyond a five-person party; group APIs can report one slot
    -- differently across Classic/Forever versions, so clamp defensively.
    local members=GetNumGroupMembers and GetNumGroupMembers() or (IsInGroup() and 2 or 1)
    if not safe(members) or type(members)~="number" then members=1 end
    local slots=math.max(0,5-math.max(1,members))
    if slots==0 then notice("The party already has five members.") return end
    inviteQueue={}
    for i=1,math.min(#list,slots) do inviteQueue[#inviteQueue+1]=list[i] end
    inviting=true
    notice("Invite Team: requesting "..#inviteQueue.." trusted characters.")
    sendNextInvite() -- first invite is a direct result of the user's click
end
function HB.LeaveTeam()
    if not IsInGroup() then return end
    -- The user's single, explicit click acts on this client only.
    local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
    if not leave then notice("No leave-party API on this client.") return end
    local ok, err = pcall(leave)
    if not ok then notice("Leave party failed: " .. tostring(err)) end
end

local lastLootGoal, lastLootAttempt = nil, 0
local function lootMethod()
    local api = C_PartyInfo and C_PartyInfo.GetLootMethod or GetLootMethod
    if not api then return nil end
    local ok, name = pcall(api)
    if not ok or not safe(name) then return nil end
    if type(name) == "string" then return name:lower() end
    if Enum and Enum.LootMethod then
        if name == Enum.LootMethod.Freeforall then return "freeforall" end
        if name == Enum.LootMethod.Group then return "group" end
    end
    return nil
end
HB.LootMethodName = lootMethod
function HB.CheckAutoLoot()
    if not HB.db or not HB.db.autoFFA or not IsInGroup() or IsInRaid() or not HB.IAmLeader() then return end
    local outsider = false
    for _, token in ipairs({"player", "party1", "party2", "party3", "party4"}) do
        if UnitExists(token) and not HB.IsKnownTeam(HB.UnitIdent(token)) then outsider = true break end
    end
    local goal = outsider and "group" or "freeforall"
    local current = lootMethod()
    if current == goal then return end
    local now = GetTime and GetTime() or 0
    if lastLootGoal == goal and now - lastLootAttempt < 3 then return end
    lastLootGoal, lastLootAttempt = goal, now
    local set = (C_PartyInfo and C_PartyInfo.SetLootMethod) or SetLootMethod
    if not set then return end
    local ok, result = pcall(set, goal)
    if not ok or result == false then notice("Could not set loot to " .. goal .. ": " .. tostring(result)) end
    if HB.RefreshControls then HB.RefreshControls() end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if HB.db then
            -- Convert the old three-state setting into the new two-state shared toggle.
            HB.ApplyQuestEnabled(HB.db.questEnabled, false)
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.4, function() HB.CheckAutoLoot() end)
    elseif event == "PARTY_LOOT_METHOD_CHANGED" then
        if HB.RefreshControls then HB.RefreshControls() end
    end
end)
for _, name in ipairs({"PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PARTY_LOOT_METHOD_CHANGED"}) do
    pcall(ev.RegisterEvent, ev, name)
end
