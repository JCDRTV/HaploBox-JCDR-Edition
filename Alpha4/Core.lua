-- HaploBox Alpha 4 Extras: additive, never replaces an existing HaploBox file.
-- Intentionally conservative about protected UI and sender trust.
local HB4 = {}
_G.HaploBoxA4 = HB4
HB4.VERSION = "0.7.0-alpha5-testbuild6-playable"
HB4.PREFIX = "HB4EX"
HB4.events, HB4.readyCallbacks = {}, {}

local defaults = {
    ui = {
        auraEnabled = true, -- native single renderer; no duplicate aura overlay
        auraSize = 20,
        partyWidth = 365,
        wideFrames = false,  -- explicit opt-in; Alpha 3 sizing differs per screen
        squareFollow = true,
        layoutFix = true, -- single stable row and follow-square geometry
        controlsOpen = false,
        hideBlizzardParty = true,
        showKTL = false, showGold = false, showBags = false,
        showClassColors = true,
    },
    inventory = { junk = {}, autoSell = false, autoRepair = false },
    whisperForward = false, -- opt-in because whispers are private
    metrics = { avgKillXP = 0, countKillXP = 0 },
}
local function copyDefaults(dst, src)
    for k,v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then dst[k] = {} copyDefaults(dst[k], v)
            else dst[k] = v end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            copyDefaults(dst[k], v)
        end
    end
end
HB4.Print = function(s)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66cfffHaploBox A4|r " .. tostring(s)) end
end
HB4.Secret = function(v) return issecretvalue and issecretvalue(v) end
HB4.SafeString = function(v)
    if type(v) == "string" and not HB4.Secret(v) and v ~= "" then return v end
end
HB4.Norm = function(n)
    if HaploBox and HaploBox.Norm then return HaploBox.Norm(n) end
    n = HB4.SafeString(n)
    if not n then return nil end
    return (n:match("^%s*(.-)%s*$")):lower():gsub("%-.*$", "")
end
HB4.UnitName = function(u)
    if not (u and UnitExists and UnitExists(u)) then return nil end
    if HaploBox and HaploBox.UnitIdent then
        local ok, n = pcall(HaploBox.UnitIdent, u)
        if ok and HB4.SafeString(n) then return n end
    end
    if GetUnitName then
        local ok, n = pcall(GetUnitName, u, true)
        if ok and HB4.SafeString(n) then return n end
    end
    if UnitName then
        local ok, a, b = pcall(UnitName, u)
        if ok and HB4.SafeString(a) then return b and (a .. "-" .. b) or a end
    end
end
HB4.PartyUnits = function()
    local units = {"player"}
    if IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) then
        for i=1,4 do
            local u = "party" .. i
            if UnitExists(u) then units[#units+1] = u end
        end
    end
    return units
end
HB4.PartyName = function(name)
    local key = HB4.Norm(name)
    if not key then return nil end
    for _,u in ipairs(HB4.PartyUnits()) do
        local n = HB4.UnitName(u)
        if HB4.Norm(n) == key then return n end
    end
end
HB4.Known = function(name)
    local key = HB4.Norm(name)
    if not key then return false end
    local team = HaploBoxTeam
    if team and type(team.order) == "table" and #team.order > 0 then
        for _,n in ipairs(team.order) do
            if HB4.Norm(n) == key then return true end
        end
        -- A stale team roster must not reject explicitly approved Team A
        -- characters still present in the actual party.
    end
    -- Exact canonical Team A identities. On WoW Forever UnitName commonly
    -- includes the surname (e.g. "Nyra Ashgrove"). The old fallback matched
    -- only first names and silently rejected valid team members. Do NOT use
    -- prefix/substring matching here: outsiders must never be trusted.
    local fixed = {
        ["mael ashgrove"] = true, ["lyra ashgrove"] = true,
        ["elya ashgrove"] = true, ["nyra ashgrove"] = true,
        ["ayla ashgrove"] = true,
    }
    return fixed[key] or false
end
HB4.Trusted = function(name)
    return HB4.Known(name) and HB4.PartyName(name) ~= nil
end
HB4.AmLeader = function()
    if not (IsInGroup and IsInGroup()) then return false end
    -- Some Forever builds expose both old and new leader APIs. Check both;
    -- never fall back to a saved leader value.
    if UnitIsGroupLeader then
        local ok, v = pcall(UnitIsGroupLeader, "player")
        if ok and v == true then return true end
    end
    if UnitIsPartyLeader then
        local ok, v = pcall(UnitIsPartyLeader, "player")
        if ok and v == true then return true end
    end
    return false
end
HB4.LeaderName = function()
    for _,u in ipairs(HB4.PartyUnits()) do
        if UnitIsGroupLeader then
            local ok, lead = pcall(UnitIsGroupLeader, u)
            if ok and lead then return HB4.UnitName(u) end
        end
        if UnitIsPartyLeader then
            local ok, lead = pcall(UnitIsPartyLeader, u)
            if ok and lead then return HB4.UnitName(u) end
        end
    end
end
HB4.CanEditUI = function() return not (InCombatLockdown and InCombatLockdown()) end
HB4.After = function(delay, fn)
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end
HB4.OnReady = function(fn) HB4.readyCallbacks[#HB4.readyCallbacks+1] = fn end

local driver = CreateFrame("Frame")
function HB4.On(event, fn)
    HB4.events[event] = HB4.events[event] or {}
    HB4.events[event][#HB4.events[event]+1] = fn
    pcall(driver.RegisterEvent, driver, event)
end
local function dispatch(event, ...)
    local list = HB4.events[event]
    if list then
        for _,fn in ipairs(list) do
            local ok, err = pcall(fn, ...)
            if not ok then HB4.Print("Module error in " .. event .. ": " .. tostring(err)) end
        end
    end
end
driver:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= "HaploBox" then return end
        HaploBoxA4DB = HaploBoxA4DB or {}
        copyDefaults(HaploBoxA4DB, defaults)
        HB4.db = HaploBoxA4DB
        -- P0 safety: never re-enable selling based on stale saved toggles.
        HB4.db.inventory.autoSell = false
        HB4.db.ui.auraEnabled = true -- native single renderer
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(HB4.PREFIX)
        elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(HB4.PREFIX) end
        dispatch("HB4_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if not HB4.db then return end
        for _,fn in ipairs(HB4.readyCallbacks) do
            local ok, err = pcall(fn)
            if not ok then HB4.Print("Startup module: " .. tostring(err)) end
        end
        dispatch(event, ...)
        HB4.Print("Alpha 4 modules geintegreerd. /hb4 options")
    else
        dispatch(event, ...)
    end
end)
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")

-- This addon deliberately leaves the existing /hb slash handler alone.
SLASH_HAPLOBOXALPHA41 = "/hb4"
SlashCmdList.HAPLOBOXALPHA4 = function(line)
    local cmd, arg = (line or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "options" or cmd == "settings" or cmd == "" then
        if HB4.OpenOptions then HB4.OpenOptions() end
    elseif cmd == "share" then
        if HB4.ShareUI then HB4.ShareUI() end
    elseif cmd == "junk" then
        if arg == "mark" or arg == "toggle" then
            if HB4.ToggleHoveredJunk then HB4.ToggleHoveredJunk() end
        elseif arg == "sell" then HB4.db.inventory.autoSell = false
            HB4.Print("Auto Sell LOCKED until unmark synchronization is validated.")
        elseif arg == "status" then if HB4.PrintJunkStatus then HB4.PrintJunkStatus() end
        elseif arg == "repair" then HB4.db.inventory.autoRepair = not HB4.db.inventory.autoRepair
            HB4.Print("Auto Repair: " .. tostring(HB4.db.inventory.autoRepair))
        else HB4.Print("/hb4 junk mark | status | repair; sell LOCKED") end
    elseif cmd == "whispers" then
        HB4.db.whisperForward = (arg:lower() == "on")
        HB4.Print("Whisper forwarding: " .. (HB4.db.whisperForward and "ON" or "OFF"))
    elseif cmd == "diag" then
        if HB4.Diagnose then HB4.Diagnose() end
    elseif cmd == "ping" then
        if HB4.PingTeam then HB4.PingTeam() end
    elseif cmd == "aura" then
        if arg == "on" or arg == "off" then HB4.db.ui.auraEnabled = arg == "on"
            if HaploBox and HaploBox.RefreshPartyFrame then HaploBox.RefreshPartyFrame() end
        else
            local n = tonumber(arg)
            if n then HB4.db.ui.auraSize = math.max(14, math.min(28, math.floor(n)))
                if HaploBox and HaploBox.RefreshPartyFrame then HaploBox.RefreshPartyFrame() end
            end
        end
        HB4.Print("Auras: " .. tostring(HB4.db.ui.auraEnabled) .. ", icon " .. tostring(HB4.db.ui.auraSize))
    elseif cmd == "layout" then
        local mode = (arg or ""):lower()
        if mode == "on" or mode == "off" then
            HB4.db.ui.layoutFix = (mode == "on")
            HB4.Print("Layout fix " .. (HB4.db.ui.layoutFix and "ON" or "OFF") .. "; /reload to fully restore previous layout after OFF")
            if HaploBox and HaploBox.LayoutPartyFrame then HaploBox.LayoutPartyFrame() end
        elseif mode == "diag" then
            if HB4.LayoutDiagnose then HB4.LayoutDiagnose() end
        else
            HB4.Print("/hb4 layout on | off | diag")
        end
    elseif cmd == "width" then
        local n = tonumber(arg)
        if n then HB4.db.ui.partyWidth = math.max(250,math.min(490,math.floor(n)))
            HB4.db.ui.wideFrames = true
            if HaploBox and HaploBox.db then HaploBox.db.teamW = HB4.db.ui.partyWidth end
            if HaploBox and HaploBox.LayoutPartyFrame then HaploBox.LayoutPartyFrame() end
        end
        HB4.Print("Party width: " .. tostring(HB4.db.ui.partyWidth))
    elseif cmd == "blizzparty" then
        if arg == "on" or arg == "off" then
            HB4.db.ui.hideBlizzardParty = arg == "off"
            if HB4.UpdateBlizzardParty then HB4.UpdateBlizzardParty() end
        end
        HB4.Print("Blizzard party frames: " .. (HB4.db.ui.hideBlizzardParty and "hidden" or "visible"))
    elseif cmd == "ktl" or cmd == "gold" or cmd == "bags" then
        local key = cmd == "ktl" and "showKTL" or cmd == "gold" and "showGold" or "showBags"
        HB4.db.ui[key] = arg == "on"
        if HaploBox and HaploBox.LayoutPartyFrame then HaploBox.LayoutPartyFrame() end
        if HB4.UpdateInformationUI then HB4.UpdateInformationUI() end
        HB4.Print(cmd .. ": " .. tostring(HB4.db.ui[key]))
    else
        HB4.Print("/hb4 options | share | aura on/off/20 | layout on/off/diag | width 365 | blizzparty on/off")
        HB4.Print("/hb4 junk mark/status/repair | whispers on/off | ktl/gold/bags on/off | diag | ping")
    end
end
