-- Alpha 3 experimental trade autofill: never accepts a trade automatically.
-- Sends profession names to party; routes only when the recipient is trusted
-- and a safe, unambiguous material rule exists. In-game API restrictions apply.
local HB = HaploBox
HB.professions = HB.professions or {}
local itemProfessions = {
    [5]={"Tailoring"}, [6]={"Leatherworking"},
    [7]={"Blacksmithing", "Engineering"},
    [9]={"Alchemy", "Inscription"}, [12]={"Enchanting"},
}
local function safe(v) return v ~= nil and (not HB.secret or not HB.secret(v)) end
local function me() return HB.UnitIdent("player") end
local function localProfessions()
    local found = {}
    if GetProfessions and GetProfessionInfo then
        for _, slot in ipairs({GetProfessions()}) do
            if slot then
                local ok, n = pcall(GetProfessionInfo, slot)
                if ok and type(n) == "string" and safe(n) then found[n:lower()] = true end
            end
        end
    end
    local names = {}
    for n in pairs(found) do names[#names+1] = n end
    table.sort(names)
    return names, found
end
local function sync()
    local n = me()
    if not n then return end
    local names = localProfessions()
    HB.professions[HB.Norm(n)] = {}
    for _, p in ipairs(names) do HB.professions[HB.Norm(n)][p] = true end
    if HB.SendTeamMessage then HB.SendTeamMessage("P|" .. table.concat(names, ",")) end
end
local function onProf(sender, payload)
    if not HB.IsGroupMember or not HB.IsGroupMember(sender) then return end
    if #payload > 120 then return end
    local list = {}
    for entry in payload:gmatch("[^,]+") do
        if entry:match("^[%a ]+$") then list[entry:lower()] = true end
    end
    HB.professions[HB.Norm(sender)] = list
end
local function targetName()
    if TradeFrameRecipientNameText and TradeFrameRecipientNameText.GetText then
        local ok, n = pcall(TradeFrameRecipientNameText.GetText, TradeFrameRecipientNameText)
        if ok and safe(n) and type(n) == "string" then return n end
    end
    return nil
end
local function itemRule(itemID)
    local rules = HB.db and HB.db.tradeRules
    local n = rules and rules[tostring(itemID)]
    return safe(n) and n or nil
end
local function professionRecipient(itemID, recipient)
    -- Explicit item rule overrides profession protection. Without one, only
    -- routing of plain trade goods to a *unique* profession on the recipient.
    local rule = itemRule(itemID)
    if rule then return HB.Norm(rule) == HB.Norm(recipient) end
    if not C_Item or not C_Item.GetItemInfoInstant then return false end
    local ok, _, _, _, _, _, class, subclass = pcall(C_Item.GetItemInfoInstant, itemID)
    if not ok or not safe(class) or not safe(subclass) or class ~= 7 then return false end
    local profs = itemProfessions[subclass]
    if not profs then return false end
    local their = HB.professions[HB.Norm(recipient)] or {}
    local mine = HB.professions[HB.Norm(me())] or {}
    local matches, own = 0, false
    for _, n in ipairs(profs) do
        local k = n:lower()
        if their[k] then matches = matches + 1 end
        if mine[k] then own = true end
    end
    return matches == 1 and not own
end
function HB.FillTradeMaterials()
    if not HB.db or not HB.db.tradeEnabled then return end
    local recipient = targetName()
    if not recipient or not HB.IsKnownTeam or not HB.IsKnownTeam(recipient) then
        HB.print("TRADE: recipient could not be verified as a trusted team character; no auto-fill.")
        return
    end
    if not C_Container or not C_Container.GetContainerItemInfo or not C_Container.PickupContainerItem or
        not ClickTradeButton then
        HB.print("TRADE: no compatible container/trade placement API; manual trade required.") return
    end
    local free = 0
    if GetTradePlayerItemLink then
        for i=1,6 do
            local ok, link = pcall(GetTradePlayerItemLink, i)
            if ok and not link then free = free + 1 end
        end
    else free = 6 end
    if free == 0 then return end
    local attempted = 0
    -- Never use a modifier to bypass normal item locks, stacks or trade protection.
    for bag=0,4 do
        local slots = C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        if safe(slots) and type(slots) == "number" then
            for slot=1,slots do
                if attempted >= math.min(6, free) then break end
                local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if ok and info and safe(info.itemID) and not info.isLocked and not info.isBound
                    and professionRecipient(info.itemID, recipient) then
                    local pickOK = pcall(C_Container.PickupContainerItem, bag, slot)
                    local placeOK = false
                    if pickOK then placeOK = pcall(ClickTradeButton, attempted + 1) end
                    if placeOK then attempted = attempted + 1
                    else
                        if ClearCursor then pcall(ClearCursor) end
                        HB.print("TRADE: WoW blocked automatic placement; fill manually.")
                        return
                    end
                end
            end
        end
    end
    if attempted > 0 then HB.print("TRADE: attempted " .. attempted .. " material stack(s). Verify before accepting.") end
end
function HB.TradeCommand(argument)
    local action, arg = (argument or ""):match("^(%S+)%s*(.-)$")
    if action == "rule" then
        local id, name = arg:match("^(%d+)%s+(.+)$")
        if not id or not name or not HB.IsKnownTeam(name) then
            HB.print("Use /hb trade rule <itemID> <trusted-character>; use /hb trusted to configure team.") return
        end
        HB.db.tradeRules = HB.db.tradeRules or {}
        HB.db.tradeRules[tostring(tonumber(id))] = name
        HB.print("Trade rule: item " .. id .. " -> " .. name)
    elseif action == "rules" then
        local n = 0
        for item, target in pairs(HB.db.tradeRules or {}) do
            n = n + 1; HB.print("Item " .. item .. " -> " .. target)
        end
        if n == 0 then HB.print("No explicit trade rules; profession matching only.") end
    elseif action == "fill" then HB.FillTradeMaterials()
    else HB.print("/hb trade rules | rule <itemID> <trusted-character> | fill") end
end
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, a, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if a ~= "HaploBox" or type(message) ~= "string" or (HB.secret and HB.secret(message)) then return end
        local payload = message:match("^P|(.*)$")
        if payload then onProf(sender, payload) end
    elseif event == "TRADE_SHOW" then
        if HB.db and HB.db.tradeEnabled then
            C_Timer.After(0.2, function() HB.FillTradeMaterials() end)
        end
    elseif event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE" or event == "SKILL_LINES_CHANGED" then
        C_Timer.After(1, sync)
    end
end)
for _, event in ipairs({"PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "SKILL_LINES_CHANGED", "CHAT_MSG_ADDON", "TRADE_SHOW"}) do
    pcall(events.RegisterEvent, events, event)
end
