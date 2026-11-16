local H = HaploBoxA4
BINDING_HEADER_HAPLOBOXA4 = "HaploBox Alpha 4"
BINDING_NAME_HAPLOBOXA4_JUNKMARK = "Toggle Junk on hovered bag item"
local function timeNow() return (time and time()) or 0 end
local function getID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        local ok,v = pcall(C_Container.GetContainerItemID,bag,slot)
        if ok and type(v)=="number" and not H.Secret(v) then return v end
    end
    if GetContainerItemID then
        local ok,v = pcall(GetContainerItemID,bag,slot)
        if ok and type(v)=="number" and not H.Secret(v) then return v end
    end
end
local function numSlots(bag)
    local f = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    if not f then return 0 end
    local ok,n = pcall(f,bag)
    return ok and type(n)=="number" and not H.Secret(n) and n or 0
end
local function isLocked(bag,slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, v = pcall(C_Container.GetContainerItemInfo,bag,slot)
        return ok and type(v)=="table" and v.isLocked
    end
    if GetContainerItemInfo then
        local ok, _,_, locked = pcall(GetContainerItemInfo,bag,slot)
        return ok and locked
    end
    return false
end
local function cleanEntry(v)
    return type(v)=="table" and (v.v == 0 or v.v == 1) and type(v.t)=="number" and v.t or 0
end
function H.Marked(id)
    local x = H.db and H.db.inventory.junk[tostring(id)]
    return type(x)=="table" and x.v == 1
end
local function put(id, v, ts, origin)
    if not H.db then return false end
    id, v, ts = tonumber(id), tonumber(v), tonumber(ts)
    if not id or id < 1 or id > 999999999 or (v ~= 1 and v ~= 0) then return false end
    if not ts or ts < 1 or ts > timeNow()+86400 then return false end
    local key = tostring(math.floor(id))
    local old = H.db.inventory.junk[key]
    -- Timestamp + deterministic origin tiebreaker; removals persist (tombstones).
    local oldT = cleanEntry(old)
    origin = tostring(origin or ""):lower():sub(1,48)
    local oldOrigin = type(old)=="table" and tostring(old.o or "") or ""
    if old and (ts < oldT or (ts == oldT and origin <= oldOrigin)) then return false end
    H.db.inventory.junk[key] = {v=v,t=ts,o=origin}
    return true
end
local function compact(id, val)
    return tostring(id) .. "," .. tostring(val.v) .. "," .. tostring(val.t) .. "," .. (val.o or "")
end
local function localOrigin()
    return (H.Norm(H.UnitName("player")) or "local"):gsub("[^%w]", ""):sub(1,40)
end
function H.SetJunk(id, marked)
    if not H.db then return end
    local origin = localOrigin()
    local ts = timeNow()
    -- Same-second toggles are versioned at next second for deterministic order.
    local old = H.db.inventory.junk[tostring(id)]
    if old and old.t and ts <= old.t then ts = old.t + 1 end
    if put(id, marked and 1 or 0, ts, origin) then
        local packet=compact(id, H.db.inventory.junk[tostring(id)])
        H.SendTeam("J", packet)
        H.After(1.5,function() if H.db then H.SendTeam("J",packet) end end)
        if H.RefreshCoins then H.RefreshCoins() end
    end
end
function H.ReceiveJunk(sender, raw)
    local id,v,t,origin = raw:match("^(%d+),([01]),(%d+),([%w]*)$")
    if id and put(id,v,t,origin) then
        if H.RefreshCoins then H.RefreshCoins() end
    end
end
function H.ReceiveJunkList(sender, raw)
    local changed = false
    for entry in raw:gmatch("[^;]+") do
        local id,v,t,origin = entry:match("^(%d+),([01]),(%d+),([%w]*)$")
        if id and put(id,v,t,origin) then changed=true end
    end
    if changed and H.RefreshCoins then H.RefreshCoins() end
end
function H.SendJunkList()
    if not H.db then return end
    local list = {}
    for id,v in pairs(H.db.inventory.junk) do
        if cleanEntry(v)>0 then list[#list+1] = compact(id,v) end
    end
    table.sort(list)
    -- Whisper only; chunks remain <240 byte; no unbounded accumulation.
    local chunk = ""
    for _,entry in ipairs(list) do
        if #entry < 200 then
            if #chunk + #entry + 1 > 215 then
                H.SendTeam("JL",chunk)
                chunk = ""
            end
            chunk = chunk == "" and entry or (chunk .. ";" .. entry)
        end
    end
    if chunk ~= "" then H.SendTeam("JL",chunk) end
end
local function getHoveredID()
    local foci = {}
    if GetMouseFoci then
        local ok, v = pcall(GetMouseFoci)
        if ok and type(v)=="table" then foci = v end
    end
    if #foci == 0 and GetMouseFocus then
        local ok,v = pcall(GetMouseFocus)
        if ok and v then foci[1] = v end
    end
    local frame = foci[1]
    for i=1,8 do
        if not frame then break end
        if frame.GetItemID then
            local ok,id = pcall(frame.GetItemID,frame)
            if ok and type(id)=="number" and id>0 and not H.Secret(id) then return id end
        end
        local bag, slot
        if frame.GetBagID then
            local ok,v = pcall(frame.GetBagID,frame)
            if ok then bag=v end
        end
        if frame.GetID then
            local ok,v = pcall(frame.GetID,frame)
            if ok then slot=v end
        end
        if bag and slot then
            local id = getID(bag,slot)
            if id then return id end
        end
        if frame.GetParent then frame = frame:GetParent() else break end
    end
    -- Bag items only: never silently mark an unrelated linked item.

end
function H.PrintJunkStatus()
    local id = getHoveredID()
    if not id then H.Print("Hover a bag item before /hb4 junk status.") return end
    H.Print("Junk status for item "..tostring(id)..": ".. (H.Marked(id) and "MARKED" or "UNMARKED"))
end
function H.ToggleHoveredJunk()
    if InCombatLockdown and InCombatLockdown() then H.Print("Mark junk after combat.") return end
    local id = getHoveredID()
    if not id then H.Print("Hover a bag item first, then press your junk key.") return end
    H.SetJunk(id,not H.Marked(id))
    H.Print("Item ".. id .. ": ".. (H.Marked(id) and "JUNK" or "unmarked"))
end
function HaploBoxA4_ToggleJunk() H.ToggleHoveredJunk() end
local buttons = {}
local function drawCoin(button,id)
    if not button then return end
    local t = buttons[button]
    if not t then
        t = button:CreateTexture(nil,"OVERLAY")
        t:SetSize(13,13)
        t:SetPoint("TOPRIGHT",button,"TOPRIGHT",1,-1)
        t:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        buttons[button] = t
    end
    t:SetShown(id and H.Marked(id) or false)
end
function H.RefreshCoins()
    if not H.db then return end
    for frame=1,13 do
        for slot=1,36 do
            local button = _G["ContainerFrame"..frame.."Item"..slot]
            if button and button.GetParent then
                local parent = button:GetParent()
                local bag
                if parent and parent.GetID then
                    local ok, val=pcall(parent.GetID,parent)
                    if ok then bag=val end
                end
                local s = button:GetID()
                local id = bag and s and getID(bag,s)
                drawCoin(button,id)
            end
        end
    end
end
local selling = false
local function merchantOpen() return MerchantFrame and MerchantFrame:IsShown() end
local function useBagItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        return pcall(C_Container.UseContainerItem,bag,slot)
    elseif UseContainerItem then
        return pcall(UseContainerItem,bag,slot)
    end
    return false
end
local function performSell()
    -- Major hotfix safety lock: JUNK-SYNC-02 not yet proven fixed.
    if H.db and H.db.inventory then H.db.inventory.autoSell = false end
    return
end

local function disabledLegacyPerformSell()
    if selling or not H.db.inventory.autoSell then return end
    if not merchantOpen() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local work = {}
    for bag=0,4 do
        for slot=1,numSlots(bag) do
            local id = getID(bag,slot)
            if id and H.Marked(id) and not isLocked(bag,slot) then
                work[#work+1] = {bag=bag,slot=slot,id=id}
            end
        end
    end
    if #work == 0 then return end
    selling = true
    local i = 0
    local function nextItem()
        if not H.db.inventory.autoSell or not merchantOpen() then selling=false return end
        i=i+1
        local v=work[i]
        if not v then selling=false return end
        -- Revalidate immediately before each sale; never auto-sell unmarked greys.
        if H.Marked(v.id) and getID(v.bag,v.slot) == v.id and not isLocked(v.bag,v.slot) then
            useBagItem(v.bag,v.slot)
        end
        H.After(0.25,nextItem)
    end
    nextItem()
end
local function doRepair()
    if not H.db.inventory.autoRepair then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    if not (GetRepairAllCost and RepairAllItems) then return end
    local ok,cost,can = pcall(GetRepairAllCost)
    if ok and type(cost)=="number" and cost>0 and (can ~= false) and cost <= (GetMoney and GetMoney() or 0) then
        pcall(RepairAllItems,false) -- personal funds only, no guildbank spend
    end
end
H.On("MERCHANT_SHOW",function() H.After(0.2, function() doRepair() performSell() end) end)
H.On("MERCHANT_CLOSED",function() selling=false end)
H.On("BAG_UPDATE_DELAYED",function() H.After(0.15,H.RefreshCoins) end)
H.On("BAG_UPDATE",function() H.After(0.3,H.RefreshCoins) end)
H.OnReady(function()
    H.After(2,H.RefreshCoins)
    -- User-approved default: DELETE only when genuinely unassigned; do not
    -- overwrite existing keybindings. Store one attempt per local character DB.
    H.After(2, function()
        if H.db.deleteBindAttempted then return end
        H.db.deleteBindAttempted = true
        if not (GetBindingAction and SetBinding and SaveBindings and GetCurrentBindingSet) then
            H.Print("Set your junk key at Key Bindings > HaploBox Alpha 4.") return
        end
        local existing = GetBindingAction("DELETE")
        if existing and existing ~= "" and existing ~= "HAPLOBOXA4_JUNKMARK" then
            H.Print("DELETE already bound; no override. Use Key Bindings to choose a junk key.")
            return
        end
        if not (InCombatLockdown and InCombatLockdown()) then
            local ok, bound = pcall(SetBinding,"DELETE","HAPLOBOXA4_JUNKMARK")
            if ok and bound then
                pcall(SaveBindings,GetCurrentBindingSet())
                H.Print("DELETE set as Shared Junk default.")
            else H.Print("Could not bind DELETE automatically; set it in Key Bindings.") end
        end
    end)
end)
