local H = HaploBoxA4
H.data = {}
local function clock() return (time and time()) or 0 end
local function safeNumber(v)
    if H.Secret(v) or type(v) ~= "number" then return -1 end
    if v ~= v or v == math.huge or v == -math.huge then return -1 end
    return math.max(-1, math.floor(v))
end
local function ownBagSpace()
    local free,capacity=0,0
    for bag=0,4 do
        local empty,slots
        local getFree=C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
        local getSize=C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
        if getSize then
            local ok,n=pcall(getSize,bag)
            if ok and type(n)=="number" and not H.Secret(n) then slots=n end
        end
        if getFree then
            local ok,n=pcall(getFree,bag)
            if ok and type(n)=="number" and not H.Secret(n) then empty=n end
        end
        if slots==0 and empty==nil then empty=0 end -- no bag equipped
        if not slots or not empty or slots<0 or empty<0 or empty>slots then return -1,-1 end
        capacity=capacity+slots
        free=free+empty
    end
    return free,capacity
end
local prevLevel, prevXP
local function snapshot()
    local lvl = safeNumber(UnitLevel("player"))
    local xp = safeNumber(UnitXP and UnitXP("player"))
    local max = safeNumber(UnitXPMax and UnitXPMax("player"))
    local rested = safeNumber(GetXPExhaustion and GetXPExhaustion() or 0)
    local gold = safeNumber(GetMoney and GetMoney())
    local bags,bagCapacity = ownBagSpace()
    local avg = H.db.metrics.avgKillXP or 0
    local val = {lvl, xp, max, rested, gold, bags, avg, bagCapacity}
    local name = H.UnitName("player")
    if name then
        H.data[H.Norm(name)] = {name=name, level=lvl, xp=xp, max=max,
            rested=rested, gold=gold, bags=bags, bagCapacity=bagCapacity, avg=avg, at=clock()}
    end
    return table.concat(val, ",")
end
local lastSent = -100
function H.SendData(force)
    if not H.db then return end
    local payload=snapshot() -- keep local totals fresh even before party formation
    if not (IsInGroup and IsInGroup()) then
        if H.UpdateInformationUI then H.UpdateInformationUI() end
        return
    end
    local t = (GetTime and GetTime()) or 0
    if not force and t-lastSent < 2 then return end
    lastSent = t
    H.SendTeam("DATA", payload)
    if H.UpdateInformationUI then H.UpdateInformationUI() end
end
function H.ReceiveData(sender, str)
    local v = {}
    for part in str:gmatch("[^,]+") do v[#v+1] = tonumber(part) end
    if #v ~= 7 and #v ~= 8 then return end
    for i=1,#v do if not v[i] or v[i] < -1 or v[i] > 100000000000 then return end end
    H.data[H.Norm(sender)] = {name=sender, level=v[1], xp=v[2], max=v[3],
        rested=v[4], gold=v[5], bags=v[6], bagCapacity=v[8] or -1,
        avg=v[7], at=clock()}
    if H.UpdateInformationUI then H.UpdateInformationUI() end
end
local queued = false
local function updateLater()
    if queued or not H.db then return end
    queued = true
    H.After(0.5, function() queued = false H.SendData(false) end)
end
for _,evt in ipairs({"PLAYER_MONEY", "BAG_UPDATE_DELAYED", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION"}) do
    H.On(evt, updateLater)
end
-- XP gains from combat text are an estimate, not a guaranteed kill counter.
H.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
    if type(msg) ~= "string" or H.Secret(msg) then return end
    -- English/Classic combat XP messages: `... you gain 123 experience ...`.
    local xp = tonumber(msg:match("[Yy]ou gain ([%d,]+) experience") and
        msg:match("[Yy]ou gain ([%d,]+) experience"):gsub(",", ""))
    if not xp or xp < 1 or xp > 100000 then return end
    local m = H.db.metrics
    local n = math.min((m.countKillXP or 0)+1, 30)
    m.avgKillXP = math.floor(((m.avgKillXP or xp)*(n-1) + xp) / n + 0.5)
    m.countKillXP = n
    updateLater()
end)
H.OnReady(function()
    H.db.infoCache = H.db.infoCache or {}
    H.data = H.db.infoCache
    snapshot()
    H.After(2, function() H.SendData(true) end)
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(20, function() H.SendData(true) end) end
end)

local function formatGold(copper)
    if not copper or copper < 0 then return "?" end
    local g = math.floor(copper/10000)
    local s = math.floor((copper%10000)/100)
    return tostring(g) .. "g" .. tostring(s) .. "s" .. tostring(copper%100) .. "c"
end
local function stats(d)
    if not d then return "?" end
    local arr = {}
    if H.db.ui.showKTL then
        if d.max > 0 and d.avg > 0 and d.xp >= 0 then
            arr[#arr+1] = "KTL " .. math.ceil(math.max(0,d.max-d.xp)/d.avg)
        else arr[#arr+1] = "KTL ?" end
    end
    if H.db.ui.showGold then arr[#arr+1] = formatGold(d.gold) end
    if H.db.ui.showBags then
        if d.bags < 0 then arr[#arr+1] = "bags ?"
        elseif d.bags == 0 then arr[#arr+1] = "|cffff55550 free|r"
        elseif d.bags <= 3 then arr[#arr+1] = "|cffffaa003 free or fewer|r"
        else arr[#arr+1] = tostring(d.bags) .. " free" end
    end
    local age = clock() - (d.at or 0)
    if age > 55 then arr[#arr+1] = "~" end
    return table.concat(arr,"  ")
end
local texts = {}
local totalText
function H.UpdateInformationUI()
    if not H.db then return end
    -- Alpha5 TB9 presents gold and free bag slots inside the compact name
    -- strip; legacy side-column / team-summary text must remain hidden.
    local show = false
    for i=1,5 do
        local row = _G["HaploBoxPartyRow" .. i]
        if row then
            if not texts[i] then
                local t = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                t:SetJustifyH("LEFT")
                t:SetPoint("LEFT",row.infoArea or row,"LEFT",3,0)
                t:SetWidth(156)
                texts[i] = t
            end
            local d = row.name and H.data[H.Norm(row.name)]
            if not d and row.unit then
                local live = H.UnitName(row.unit)
                d = live and H.data[H.Norm(live)]
            end
            texts[i]:SetText(show and stats(d) or "")
        end
    end
    local container = _G.HaploBoxPartyFrame
    if container then
        if not totalText then
            totalText = container:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            totalText:SetPoint("TOPLEFT",container,"BOTTOMLEFT",2,-1)
        end
        if false then -- no extra team summary under compact partyframes
            local total, count = 0,0
            -- Sum the five registered characters only, including cached/offline values.
            local team = HaploBoxTeam and HaploBoxTeam.order
            if not team or #team == 0 then team={"Mael","Lyra","Elya","Nyra","Ayla"} end
            local n, stale = 0, false
            for _,name in ipairs(team) do
                if H.Known(name) and n < 5 then
                    n=n+1
                    local d = H.data[H.Norm(name)]
                    if d and d.gold >= 0 then
                        total=total+d.gold
                        count=count+1
                        if clock() - (d.at or 0) > 55 then stale=true end
                    end
                end
            end
            totalText:SetText("TEAM GOLD "..count.."/"..n..": "..formatGold(total)..(stale and "  ~cached" or ""))
        else totalText:SetText("") end
    end
    if HaploBox and HaploBox.UpdatePartyResourceText then HaploBox.UpdatePartyResourceText() end
    if HaploBox and HaploBox.RefreshResourceSummary then HaploBox.RefreshResourceSummary() end
end
H.On("GROUP_ROSTER_UPDATE", function() H.After(2,H.UpdateInformationUI) end)
H.OnReady(function() H.After(3,H.UpdateInformationUI) end)
