-- HaploBox 0.7.0-alpha1: character-local XP/rested reporting across the party.
-- Party member XP and rested XP aren't directly visible to the client; each toon
-- reports its own values over the existing HaploBox addon channel.
local HB = HaploBox
local PREFIX = "HaploBox"
HB.xp = HB.xp or {}

local function normal(v)
    return type(v) == "number" and (not issecretvalue or not issecretvalue(v))
end

local function groupPeer(sender)
    local key = HB.Norm(sender)
    if not key or not IsInGroup() then return false end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and HB.Norm(HB.UnitIdent(unit)) == key then return true end
    end
    return false
end

local function ownXP()
    local current = UnitXP("player")
    local maximum = UnitXPMax("player")
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    if rested == nil then rested = 0 end
    if not normal(current) or not normal(maximum) or not normal(rested) or maximum <= 0 then return nil end
    current = math.max(0, math.min(maximum, math.floor(current)))
    maximum = math.floor(maximum)
    rested = math.max(0, math.floor(rested))
    return current, maximum, rested
end

local lastSent
local function publish(force)
    local current, maximum, rested = ownXP()
    if not current then return end
    local me = HB.Norm(HB.UnitIdent("player"))
    if not me then return end
    local changed = not HB.xp[me] or HB.xp[me].current ~= current or
        HB.xp[me].maximum ~= maximum or HB.xp[me].rested ~= rested
    HB.xp[me] = { current = current, maximum = maximum, rested = rested }
    if changed and HB.OnXPChanged then HB.OnXPChanged() end
    if not IsInGroup() then return end
    local payload = "X|" .. current .. "|" .. maximum .. "|" .. rested
    if not force and lastSent == payload then return end
    lastSent = payload
    local channel = IsInRaid() and "RAID" or "PARTY"
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then channel = "INSTANCE_CHAT" end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, payload, channel)
    end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a, b, c, d)
    if event == "CHAT_MSG_ADDON" then
        if a ~= PREFIX or type(b) ~= "string" then return end
        if issecretvalue and (issecretvalue(b) or issecretvalue(d)) then return end
        local sender = d
        if not groupPeer(sender) then return end
        if b == "X|?" then publish(true) return end
        local value, maxXP, rested = b:match("^X|(%d+)|(%d+)|(%d+)$")
        if not value then return end
        value, maxXP, rested = tonumber(value), tonumber(maxXP), tonumber(rested)
        -- Bound incoming data; never trust arbitrary addon messages as code or state.
        if not maxXP or maxXP <= 0 or maxXP > 100000000 or
            not value or value > maxXP or not rested or rested > 150000000 then return end
        local key = HB.Norm(sender)
        HB.xp[key] = { current = value, maximum = maxXP, rested = rested }
        if HB.OnXPChanged then HB.OnXPChanged() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        -- Query all currently connected peers, then publish local data.
        C_Timer.After(2, function()
            lastSent = nil
            publish(true)
            if IsInGroup() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
                local channel = IsInRaid() and "RAID" or "PARTY"
                if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then channel = "INSTANCE_CHAT" end
                C_ChatInfo.SendAddonMessage(PREFIX, "X|?", channel)
            end
        end)
        return
    end
    publish(false)
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "CHAT_MSG_ADDON" }) do
    pcall(ev.RegisterEvent, ev, event)
end
