-- HaploBox party frame: one row per team member with health, power and follow status.
-- Rows are secure unit buttons: left-click targets the member, and [@mouseover]
-- macros work on them. Secure attributes and visibility only change out of combat.
-- Health values may be secret on this client: they go straight into StatusBars and
-- FontStrings, never into Lua arithmetic or comparisons.
local HB = HaploBox

local GAP, ROW_GAP, AURA_W = 3, 3, 180 -- Aura rails are outside the clickable frame and do not enlarge it.
HB.AURA_COLUMN_WIDTH = AURA_W -- shared with the aura renderer
local MEDIA = "Interface\\AddOns\\HaploBox\\Media\\"
local secret = function(v) return issecretvalue and issecretvalue(v) end

-- TB19.1b: fixed currency grid for both the five character headers and the
-- summary above them. All geometry is relative to their existing goldText
-- anchors; the secure party frame itself is never moved or reparented.
HB.CURRENCY_MIN_SPAN=128
function HB.CurrencySpanForCopper(copper)
    if type(copper)~="number" or secret(copper) or copper<0 then return HB.CURRENCY_MIN_SPAN end
    local g=math.floor(copper/10000)
    return math.max(HB.CURRENCY_MIN_SPAN,97+math.max(30,#tostring(g)*8))
end
function HB.CreateCurrencyCells(parent,anchor)
    local cells={}
    local function number(offset,width)
        local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f:SetJustifyH("RIGHT");f:SetJustifyV("MIDDLE")
        f:SetWordWrap(false)
        f:SetSize(width,21)
        f:SetPoint("RIGHT",anchor,"RIGHT",-offset,0)
        f:SetTextColor(1,0.89,0.67,1)
        if STANDARD_TEXT_FONT then f:SetFont(STANDARD_TEXT_FONT,11,"OUTLINE") end
        f:SetShadowOffset(1,-1)
        return f
    end
    local function coin(name,offset)
        local icon=parent:CreateTexture(nil,"OVERLAY")
        icon:SetTexture("Interface\\MoneyFrame\\UI-"..name.."Icon")
        icon:SetSize(11,11)
        icon:SetPoint("RIGHT",anchor,"RIGHT",-offset,0)
        return icon
    end
    cells.cIcon=coin("Copper",0)
    cells.c=number(13,22)
    cells.sIcon=coin("Silver",40)
    cells.s=number(53,22)
    cells.gIcon=coin("Gold",80)
    cells.g=number(93,31)
    for _,cell in pairs(cells) do cell:SetShown(false) end
    return cells
end
function HB.SetCurrencyCells(cells,copper,span)
    if not cells then return end
    local valid=type(copper)=="number" and not secret(copper) and copper>=0
    for _,cell in pairs(cells) do cell:SetShown(valid) end
    if not valid then return end
    local gold=math.floor(copper/10000)
    cells.g:SetWidth(math.max(31,(span or HB.CURRENCY_MIN_SPAN)-97))
    cells.g:SetText(tostring(gold))
    cells.s:SetText(tostring(math.floor(copper%10000/100)))
    cells.c:SetText(tostring(math.floor(copper%100)))
end

local C = {
	rowBg    = { 0.085, 0.08, 0.08, 0.28 }, -- Classic WoW-style subtle background, bars only
	xp       = { 0.67, 0.18, 0.78 },
	rested   = { 0.24, 0.41, 0.76 },
	xpBg     = { 0.09, 0.09, 0.13, 1.00 },
	name     = { 1.00, 0.78, 0.26 },
	health   = { 0.10, 0.72, 0.22 },
	healthBg = { 0.04, 0.11, 0.04, 0.90 },
	power    = { 0.30, 0.55, 0.95 },
	powerBg  = { 0.12, 0.14, 0.20, 0.90 },
	ok       = { 0.17, 0.33, 0.20, 0.95 },
	lead     = { 0.14, 0.38, 0.71, 0.97 }, -- FOCUS blue, gold border only on leader
	paused   = { 0.55, 0.38, 0.08, 0.95 },
	broken   = { 0.55, 0.16, 0.14, 0.95 },
	unknown  = { 0.25, 0.25, 0.28, 0.95 },
}

local container, rows = nil, {}
local unitRow = {}          -- unit token -> row
local pendingLayout = false
local displayPrefix         -- shared first word of all team names, hidden in the rows

-- ---------------------------------------------------------------- team
-- Team names in display order: HaploBoxTeam.order, else leader, tank, healer, dps.
function HB.TeamOrder()
	local team, out, seen = HaploBoxTeam or {}, {}, {}
	local function add(n)
		local k = HB.Norm(n)
		if not k then return end
		for i, previous in ipairs(out) do
			if HB.SameTeamMember and HB.SameTeamMember(previous,n) then
				-- Prefer the actual full name from UnitIdent over a stale short alias.
				if #n > #previous then out[i] = n end
				seen[k] = true
				return
			end
		end
		if not seen[k] then seen[k] = true out[#out + 1] = n end
	end
	if type(team.order) == "table" and #team.order > 0 then
		for _, n in ipairs(team.order) do add(n) end
	else
		add(HB.Leader())
		local rank = { tank = 1, healer = 2, dps = 3 }
		local names = {}
		for n in pairs(team.roles or {}) do names[#names + 1] = n end
		table.sort(names, function(a, b)
			local ra, rb = rank[team.roles[a]] or 4, rank[team.roles[b]] or 4
			if ra ~= rb then return ra < rb end
			return a < b
		end)
		for _, n in ipairs(names) do add(n) end
	end
	-- anyone with a role but missing from the order goes at the end
	add(HB.Leader())
	local extra = {}
	for n in pairs(team.roles or {}) do extra[#extra + 1] = n end
	table.sort(extra)
	for _, n in ipairs(extra) do add(n) end
	-- group members who are not in the team list (a swapped-in toon) still get a row
	if IsInGroup() and not IsInRaid() then
		add(HB.UnitIdent("player"))
		for i = 1, 4 do
			if UnitExists("party" .. i) then add(HB.UnitIdent("party" .. i)) end
		end
	end
	-- Sort only the displayed rows. The shared team roster and roles stay untouched.
	local order = HB.db and HB.db.preferredOrder or ""
	local rank = {}
	local index = 0
	for name in order:gmatch("[^,]+") do
		name = name:match("^%s*(.-)%s*$")
		local key = HB.Norm(name)
		if key and not rank[key] then index = index + 1 rank[key] = index end
	end
	if index > 0 then
		local function priority(name)
			local k = HB.Norm(name)
			if rank[k] then return rank[k] end
			for word in name:gmatch("%S+") do
				local wordKey = HB.Norm(word)
				if rank[wordKey] then return rank[wordKey] end
			end
			return math.huge
		end
		local listed = {}
		for i, n in ipairs(out) do listed[#listed + 1] = { name = n, position = i, priority = priority(n) } end
		table.sort(listed, function(a, b)
			if a.priority ~= b.priority then return a.priority < b.priority end
			return a.position < b.position
		end)
		for i, entry in ipairs(listed) do out[i] = entry.name end
	end
	return out
end

local function unitForName(name)
	local key = HB.Norm(name)
	if not key then return nil end
	if HB.Norm(HB.UnitIdent("player")) == key or (HB.SameTeamMember and HB.SameTeamMember(name, HB.UnitIdent("player"))) then return "player" end
	if not IsInGroup() then return nil end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local u = "raid" .. i
			if HB.Norm(HB.UnitIdent(u)) == key or (HB.SameTeamMember and HB.SameTeamMember(name, HB.UnitIdent(u))) then return u end
		end
	else
		for i = 1, 4 do
			local u = "party" .. i
			if UnitExists(u) and (HB.Norm(HB.UnitIdent(u)) == key or
                (HB.SameTeamMember and HB.SameTeamMember(name, HB.UnitIdent(u)))) then return u end
		end
	end
end

-- TeamOrder describes the saved five-person team; it does not describe who is
-- actually in the current party. Show only live party members, never cached
-- characters that have left to catch up XP. In solo mode show player only.
local function visibleTeamOrder()
    local present = {}
    local function add(u)
        if UnitExists and UnitExists(u) then
            local n = HB.UnitIdent(u)
            if n then present[#present + 1] = n end
        end
    end
    add("player")
    if IsInGroup() then
        if IsInRaid() then
            for i=1,(GetNumGroupMembers() or 0) do add("raid" .. i) end
        else
            for i=1,4 do add("party" .. i) end
        end
    end
    local sorted, taken = {}, {}
    for _, expected in ipairs(HB.TeamOrder()) do
        for j, actual in ipairs(present) do
            if not taken[j] and (HB.Norm(expected) == HB.Norm(actual) or
                (HB.SameTeamMember and HB.SameTeamMember(expected, actual))) then
                sorted[#sorted+1] = actual
                taken[j] = true
                break
            end
        end
    end
    for j, actual in ipairs(present) do
        if not taken[j] then sorted[#sorted+1] = actual end
    end
    return sorted
end

-- Shared roster resolver for the client-local Mini Heal presentation.
HB.VisiblePartyNames = visibleTeamOrder
HB.ResolvePartyUnit = unitForName

local function sharedPrefix(names)
	local first
	for _, n in ipairs(names) do
		local w = n:match("^(%S+)%s+%S")
		if not w then return nil end
		if first and first ~= w then return nil end
		first = w
	end
	return #names > 1 and first or nil
end

local function displayName(name)
	if displayPrefix then
		local rest = name:match("^" .. displayPrefix:gsub("(%W)", "%%%1") .. "%s+(.+)$")
		if rest then return rest end
	end
	return (name:gsub("%-.*$", ""))
end

-- ---------------------------------------------------------------- sizes
local MIN_W, MAX_W, MIN_H, MAX_H = 150, 500, 60, 110
local BASE_HEADER, BAR_GAP = 18, 2
local function rowW() return math.min(MAX_W, math.max(MIN_W, HB.db.teamW or 250)) end
local function rowH() return math.min(MAX_H, math.max(MIN_H, HB.db.teamRowH or 86)) end

-- ---------------------------------------------------------------- class colours
local function classFileFor(r)
	local key = HB.Norm(r.name)
	HB.db.classCache = HB.db.classCache or {}
	if r.unit then
		local ok, _, file = pcall(UnitClass, r.unit)
		if ok and type(file) == "string" and not secret(file) then HB.db.classCache[key] = file return file end
	end
	return HB.db.classCache[key]
end

local function classColor(file)
	if not file then return nil end
	if C_ClassColor and C_ClassColor.GetClassColor then
		local c = C_ClassColor.GetClassColor(file)
		if c then return c.r, c.g, c.b end
	end
	local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[file]
	if c then return c.r, c.g, c.b end
end

local function updateColors(r)
	local cr, cg, cb
	if HB.db.teamClassColors then cr, cg, cb = classColor(classFileFor(r)) end
	if not cr then cr, cg, cb = C.health[1], C.health[2], C.health[3] end
	r.health:SetStatusBarColor(cr, cg, cb)
	r.health.back:SetColorTexture(cr * 0.28, cg * 0.28, cb * 0.28, 0.9)
	if HB.db.teamClassColors then
		r.nameText:SetTextColor(math.min(1, cr * 1.1 + 0.08), math.min(1, cg * 1.1 + 0.08), math.min(1, cb * 1.1 + 0.08))
	else
		r.nameText:SetTextColor(C.name[1], C.name[2], C.name[3])
	end
end

-- ---------------------------------------------------------------- rows
local function solid(parent, layer, c)
	local t = parent:CreateTexture(nil, layer)
	t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	return t
end

local function bar(parent, fg, bg)
	local b = CreateFrame("StatusBar", nil, parent)
    -- Native Blizzard unitframe bar texture, with subtle bronze inset trim.
	b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	b:SetStatusBarColor(fg[1], fg[2], fg[3])
	b:SetMinMaxValues(0, 1)
	b:SetValue(0)
	b.back = solid(b, "BACKGROUND", bg)
	b.back:SetAllPoints()
    local trim = {0.56,0.45,0.27,0.98}
    b.trim={}
    for i=1,4 do
        local e=solid(b,"OVERLAY",trim)
        b.trim[i]=e
        if i==1 then e:SetPoint("TOPLEFT");e:SetPoint("TOPRIGHT");e:SetHeight(2)
        elseif i==2 then e:SetPoint("BOTTOMLEFT");e:SetPoint("BOTTOMRIGHT");e:SetHeight(2)
        elseif i==3 then e:SetPoint("TOPLEFT");e:SetPoint("BOTTOMLEFT");e:SetWidth(2)
        else e:SetPoint("TOPRIGHT");e:SetPoint("BOTTOMRIGHT");e:SetWidth(2) end
    end
	return b
end

local function tileTexture(parent,layer)
    local t=parent:CreateTexture(nil,layer)
    -- Same straight rectangular visual language as HP/Mana bars.
    t:SetColorTexture(1,1,1,1)
    t:SetAllPoints()
    return t
end
local function tileBorder(parent)
    local t=parent:CreateTexture(nil,"OVERLAY")
    -- Exact one/two-pixel edge textures draw the border below. No bevel art.
    t:SetColorTexture(0,0,0,0)
    t:SetAllPoints()
    return t
end

local function startMove()
	if HB.db.teamLocked or InCombatLockdown() or not container then return end
    if HB.BeginControlMove then HB.BeginControlMove() else container:StartMoving() end
end

-- Single source of geometry. Legacy HP/mana/XP heights use BASE row height only;
-- the extra buff strip must not inflate them or make leader rows different.
local function geometry()
    local W, baseH = rowW(), rowH()
    local innerH = math.max(40,baseH - BASE_HEADER - 8)
    -- Rebalance TB4: thinner cast, a readable XP bar; keep HP dominant.
    local hpH = math.max(19,math.floor(innerH * 0.44 + 0.5)) + 3
    local manaH = math.max(12,math.floor(innerH * 0.29 + 0.5))
    local castH = math.max(7,math.min(manaH-4,math.floor(innerH * 0.14 + 0.5)))
    local tickH, xpH = 3, 15
    local square = hpH + manaH + castH + tickH + xpH + 6
    -- Normal buffs move to FOCUS: no reserved buff strip above the HP bar.
    -- The header is just tall enough for level / name / gold / bag information.
    -- Keep the full stacked FOCUS and FOLLOW tiles inside each compact row.
    local headerH = 29
    local actualH = headerH + square + 3
    return W, baseH, headerH, hpH, manaH, xpH, square, actualH, 0, tickH, castH
end

local function sizeRow(r)
    local W, _, headerH, hpH, manaH, xpH, square, H, infoW, tickH, castH = geometry()
    local barW = W - 12
    -- SecureUnitButtonTemplate is click-targetable only across the actual
    -- player bars. Aura/status columns are transparent siblings visually,
    -- never part of the unit-target mouse hitbox.
    r:SetSize(W, H)
    r.bg:SetSize(W, headerH + square + 3) -- world shows through empty status and aura space
    -- Level | Name ... free slots | Gold: all inside one short header.
    -- Neither new resource label changes the width of the player bars.
    -- Layout the header AFTER measuring money; keep the copper icon inside
    -- the right border even when a character has 3 currency denominations.
    -- Level, name, bag and coins all share the same vertical centerline.
    local centerY=-math.floor(headerH/2)
    r.levelText:ClearAllPoints()
    r.levelText:SetPoint("LEFT",r,"TOPLEFT",7,centerY)
    r.nameText:ClearAllPoints()
    r.nameText:SetPoint("LEFT",r.levelText,"RIGHT",5,0)
    r.levelText:SetHeight(21)
    r.nameText:SetHeight(21)
    r.levelText:SetJustifyV("MIDDLE")
    r.nameText:SetJustifyV("MIDDLE")
    if r.goldText then
        r.goldText:ClearAllPoints()
        r.goldText:SetPoint("RIGHT",r,"TOPRIGHT",-12,centerY)
        r.goldText:SetHeight(21)
        r.goldText:SetJustifyV("MIDDLE")
        local coinWidth=HB.currencySpanWidth or HB.CURRENCY_MIN_SPAN
        r.goldText:SetWidth(coinWidth)
        if r.bagText then
            r.bagText:ClearAllPoints()
            r.bagText:SetPoint("RIGHT",r.goldText,"LEFT",-9,0)
            r.bagText:SetSize(31,21) -- a fixed right-aligned three-digit slot
            r.bagText:SetJustifyV("MIDDLE")
            if r.bagIcon then
                r.bagIcon:ClearAllPoints()
                r.bagIcon:SetPoint("RIGHT",r.bagText,"LEFT",-2,0)
            end
            r.bagText:SetShown(W>=220)
            if r.bagIcon then r.bagIcon:SetShown(W>=220 and r.bagIcon:IsShown()) end
        end
        -- Leave space for the leader's crown / healer marker after the name.
        local nameW=r.nameText.GetUnboundedStringWidth and r.nameText:GetUnboundedStringWidth() or r.nameText:GetStringWidth()
        if type(nameW)~="number" or secret(nameW) then nameW=W*0.35 end
        local resources=(W>=220) and (coinWidth+9+31+2+19+9+14+16) or (coinWidth+10+16)
        local maxName=math.max(36,W-7-34-5-resources)
        r.nameText:SetWidth(math.max(35,math.min(math.ceil(nameW)+2,maxName)))
    end

    r.health:ClearAllPoints()
    r.health:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -headerH)
    r.health:SetSize(barW, hpH)
    if r.hpIndexText then r.hpIndexText:SetWidth(math.max(56,barW-76)) end
    r.power:SetSize(barW, manaH)
    r.fiveSR:SetSize(barW, tickH)
    r.castBar:SetSize(barW, castH)
    r.xpTrack:SetSize(barW, xpH)

    -- TB16: same height as the ENTIRE single frame (name through XP),
    -- touching its right edge. No disconnected floating Focus/Follow tiles.
    local tileW=math.max(42,math.floor(square*0.84 + 0.5))
    local focusH=math.floor(H/3)
    r.focusTile:ClearAllPoints()
    r.focusTile:SetPoint("TOPLEFT",r,"TOPRIGHT",-1,0)
    r.focusTile:SetSize(tileW,focusH)
    -- Only the solo correct-focus crosshair needs to match other glyphs.
    -- Other tiles/Follow are already visually approved.
    local focusIconSize=math.min(24,math.floor(focusH*0.64))
    r.focusIcon:SetSize(focusIconSize,focusIconSize)
    r.focusText:SetWidth(tileW-6)
    r.focusMaxW=tileW-6
    r.box:ClearAllPoints()
    r.box:SetPoint("TOPLEFT",r.focusTile,"BOTTOMLEFT",0,0)
    r.box:SetSize(tileW,H-focusH)
    -- Increase status glyphs only, never the clickable Follow tile width.
    local iconSize=math.min(24,math.max(21,math.floor(tileW*0.46+0.5)))
    r.box.icon:SetSize(iconSize,iconSize)
    r.box.targetIcon:SetSize(iconSize,iconSize)
    if r.combinedBorder then
        r.combinedBorder:ClearAllPoints()
        r.combinedBorder:SetPoint("TOPLEFT",r,"TOPLEFT",0,0)
        r.combinedBorder:SetPoint("BOTTOMRIGHT",r.box,"BOTTOMRIGHT",0,0)
    end
    if HB.SizeAuraWidgets then
        HB.SizeAuraWidgets(r, W + GAP + square + GAP, headerH, W, H, 0, square)
    end
end
local function createRow(i)
	local r = CreateFrame("Button", "HaploBoxPartyRow" .. i, container, "SecureUnitButtonTemplate")
	r:RegisterForClicks("AnyUp")
	r:SetAttribute("type1", "target")
    -- HF12 PFR-06: Blizzard's secure right-click menu, not a custom handler.
    -- Works with the native unit token assigned in LayoutPartyFrame (OOC).
    r:SetAttribute("type2", "togglemenu")
	r:RegisterForDrag("LeftButton")
	r:SetScript("OnDragStart", startMove)
	r:SetScript("OnDragStop", function() HB.SavePartyPosition() end)

	r.bg = solid(r, "BACKGROUND", C.rowBg)
	r.bg:SetPoint("TOPLEFT")
    -- The compact name strip hints at Classic WoW's recessed gold-edged bars.
    r.namePlate=solid(r,"BACKGROUND",{0.07,0.065,0.06,0.76})
    r.namePlate:SetPoint("TOPLEFT",r,"TOPLEFT",1,-3)
    r.namePlate:SetHeight(23)
    r.namePlate:SetPoint("RIGHT",r,"RIGHT",-1,0)
    r.nameGold=solid(r,"BORDER",{0.55,0.44,0.24,0.83})
    r.nameGold:SetPoint("TOPLEFT",r,"TOPLEFT",1,0)
    r.nameGold:SetPoint("TOPRIGHT",r,"TOPRIGHT",-1,0)
    r.nameGold:SetHeight(1)

	r.nameText = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.nameText:SetPoint("TOPLEFT", 40, -3) -- anchored precisely after levelText exists
	r.nameText:SetJustifyH("LEFT")
	-- Gold crown immediately after the name marks the *actual* WoW party leader.
	r.leaderCrown = r:CreateTexture(nil, "OVERLAY")
	r.leaderCrown:SetTexture(MEDIA .. "crown")
	r.leaderCrown:SetSize(13, 13)
	r.leaderCrown:SetVertexColor(1, 0.83, 0.22)
	r.leaderCrown:SetPoint("LEFT", r.nameText, "RIGHT", 3, 0)
	r.healerMark = r:CreateTexture(nil, "OVERLAY")
	r.healerMark:SetTexture(MEDIA .. "cross")
	r.healerMark:SetSize(12, 12)
	r.healerMark:SetVertexColor(0.45, 0.95, 0.56)
	r.healerMark:SetPoint("LEFT", r.nameText, "RIGHT", 4, 0)
	r.healerMark:Hide()
    -- HF12 PFR-05: native Blizzard party role. Decorative texture never
    -- captures mouse input from the approved SecureUnitButtonTemplate.
    r.blizzardRoleIcon=r:CreateTexture(nil,"OVERLAY")
    r.blizzardRoleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    r.blizzardRoleIcon:SetSize(14,14)
    r.blizzardRoleIcon:Hide()
    r.blizzardRoleFallback=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    r.blizzardRoleFallback:SetSize(14,14)
    r.blizzardRoleFallback:SetJustifyH("CENTER")
    r.blizzardRoleFallback:SetTextColor(1,0.89,0.60,1)
    if STANDARD_TEXT_FONT then r.blizzardRoleFallback:SetFont(STANDARD_TEXT_FONT,11,"THICKOUTLINE") end
    r.blizzardRoleFallback:Hide()

    -- Independent focus status tile above the approved follow square.
    r.focusTile = CreateFrame("Frame", nil, r)
    r.focusTile:EnableMouse(false)
    r.focusBg = r.focusTile:CreateTexture(nil,"BACKGROUND")
    r.focusBg:SetColorTexture(1,1,1,1)
    r.focusBg:SetAllPoints()
    r.focusBorder = r.focusTile:CreateTexture(nil,"OVERLAY")
    r.focusBorder:SetColorTexture(0,0,0,0)
    r.focusBorder:SetAllPoints()
    r.focusBorder:SetAlpha(0.96)
    r.focusIcon = r.focusTile:CreateTexture(nil, "ARTWORK")
    r.focusIcon:SetSize(15, 15)
    r.focusIcon:SetTexture(MEDIA .. "swords-clear.tga")
    r.focusIcon:SetPoint("CENTER", r.focusTile, "CENTER", 0, 0)
    r.focusText = r.focusTile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.focusText:SetPoint("BOTTOM", r.focusTile, "BOTTOM", 0, 2)
    r.focusText:SetJustifyH("CENTER")
    r.focusText:SetWordWrap(false)
    r.focusText:SetShadowOffset(1, -1)
    r.focusText:SetTextColor(1, 1, 1)
    r.focusText:Hide() -- TB15 Target/Focus: WHITE ICON ONLY, never a label.
    r.focusTile.edges = {}
    local goldFocus = {0.71, 0.56, 0.27, 0.98} -- WoW gold; unified border overrides individual tiles
    for side=1,4 do
        local e = solid(r.focusTile, "OVERLAY", goldFocus)
        r.focusTile.edges[side] = e
        if side == 1 then e:SetPoint("TOPLEFT"); e:SetPoint("TOPRIGHT"); e:SetHeight(2)
        elseif side == 2 then e:SetPoint("BOTTOMLEFT"); e:SetPoint("BOTTOMRIGHT"); e:SetHeight(2)
        elseif side == 3 then e:SetPoint("TOPLEFT"); e:SetPoint("BOTTOMLEFT"); e:SetWidth(2)
        else e:SetPoint("TOPRIGHT"); e:SetPoint("BOTTOMRIGHT"); e:SetWidth(2) end
        e:Show()
    end

	r.health = bar(r, C.health, C.healthBg)
	r.health:SetPoint("TOPLEFT", 6, -18)
    -- HF26.19.1: HP amount replaces the old party-number label.
    -- Display-only FontString; values remain owned by the secure StatusBar.
    r.hpIndexText=r.health:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    r.hpIndexText:SetPoint("LEFT",r.health,"LEFT",5,0)
    r.hpIndexText:SetSize(162,27)
    r.hpIndexText:SetJustifyH("LEFT")
    r.hpIndexText:SetJustifyV("MIDDLE")
    r.hpIndexText:SetTextColor(1,1,0.98,1)
    r.hpIndexText:SetShadowOffset(1,-1)
    if STANDARD_TEXT_FONT then r.hpIndexText:SetFont(STANDARD_TEXT_FONT,11,"OUTLINE") end
    r.hpIndexText:SetText("")
    -- Native heal prediction works even if WoW marks combat HP as secret.
    -- The attached display is mouse-transparent and clipped to the HP bar.
    r.incomingHeal=HB.AttachIncomingHealBar and HB.AttachIncomingHealBar(r.health)
	r.focusIcon:Hide()

	-- Keep the right-hand values anchored to the same pixel column.
    r.levelText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.levelText:SetPoint("TOPLEFT",r,"TOPLEFT",7,-4)
    r.levelText:SetWidth(34)
    r.levelText:SetJustifyH("LEFT")
    r.levelText:SetTextColor(1.00,0.82,0.42,1)
    if STANDARD_TEXT_FONT then r.levelText:SetFont(STANDARD_TEXT_FONT,12,"OUTLINE") end
	r.levelText:SetShadowOffset(1, -1)
    r.nameText:ClearAllPoints()
    r.nameText:SetPoint("LEFT",r.levelText,"RIGHT",4,0)
    r.goldText=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    r.goldText:SetJustifyH("RIGHT")
    r.goldText:SetWordWrap(false)
    r.goldText:SetTextColor(1,0.89,0.67,1)
    if STANDARD_TEXT_FONT then r.goldText:SetFont(STANDARD_TEXT_FONT,11,"OUTLINE") end
    r.goldText:SetShadowOffset(1,-1)
    r.currencyCells=HB.CreateCurrencyCells(r,r.goldText)
    r.bagText=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    r.bagText:SetJustifyH("RIGHT")
    r.bagText:SetTextColor(0.80,0.87,0.92,1)
    if STANDARD_TEXT_FONT then r.bagText:SetFont(STANDARD_TEXT_FONT,11,"OUTLINE") end
    r.bagText:SetShadowOffset(1,-1)
    -- New backpack icon follows the existing bag slot readout, not a new column.
    r.bagIcon=r:CreateTexture(nil,"OVERLAY")
    r.bagIcon:SetTexture(MEDIA.."bag-jcdr.tga")
    r.bagIcon:SetSize(18,18)
    r.bagIcon:SetPoint("RIGHT",r.bagText,"LEFT",0,0)
    r.bagIcon:Hide()
	r.pctText = r.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.pctText:SetPoint("RIGHT", r.health, "RIGHT", -4, 0)
	r.pctText:SetWidth(52)
	r.pctText:SetJustifyH("RIGHT")
	r.pctText:SetShadowOffset(1, -1)

	r.power = bar(r, C.power, C.powerBg)
	r.power:SetPoint("TOPLEFT", r.health, "BOTTOMLEFT", 0, -2)
	r.powerText = r.power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.powerText:SetPoint("RIGHT", r.power, "RIGHT", -4, 0)
	r.powerText:SetWidth(52)
	r.powerText:SetJustifyH("RIGHT")
    r.powerText:SetShadowOffset(1, -1)
    r.powerText:Hide() -- Visual mana bar alone; numerical percentage not needed.

    -- Party-wide 5-second-rule timer. Full muted track is the ready state;
    -- any confirmed local mana expenditure restarts the thin moving fill.
    r.fiveSR = bar(r,{0.35,0.78,0.73},{0.06,0.20,0.19,0.9})
    r.fiveSR:SetPoint("TOPLEFT",r.power,"BOTTOMLEFT",0,-1)
    r.fiveSR:SetMinMaxValues(0,5)
    r.fiveSR:SetValue(5)
    for _,edge in ipairs(r.fiveSR.trim or {}) do edge:Hide() end
    -- Always-visible casting track, activated on observed casts/channels.
    r.castBar = bar(r,{0.99,0.69,0.19},{0.20,0.16,0.09,0.87})
    r.castBar:SetPoint("TOPLEFT",r.fiveSR,"BOTTOMLEFT",0,-1)
    r.castBar:SetValue(0)
    for _,edge in ipairs(r.castBar.trim or {}) do edge:Hide() end

	-- XP track: dark background, blue rested area, purple earned XP on top.
	r.xpTrack = CreateFrame("Frame", nil, r)
	r.xpTrack:SetPoint("TOPLEFT", r.castBar, "BOTTOMLEFT", 0, -2)
	r.xpBg = solid(r.xpTrack, "BACKGROUND", C.xpBg)
	r.xpBg:SetAllPoints()
	r.xpRested = CreateFrame("StatusBar", nil, r.xpTrack)
	r.xpRested:SetAllPoints()
	r.xpRested:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	r.xpRested:SetStatusBarColor(C.rested[1], C.rested[2], C.rested[3])
	r.xpRested:SetMinMaxValues(0, 1)
	r.xpRested:SetValue(0)
	r.xpRested:SetFrameLevel(r.xpTrack:GetFrameLevel() + 1)
	r.xp = CreateFrame("StatusBar", nil, r.xpTrack)
	r.xp:SetAllPoints()
	r.xp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	r.xp:SetStatusBarColor(C.xp[1], C.xp[2], C.xp[3])
	r.xp:SetMinMaxValues(0, 1)
	r.xp:SetValue(0)
	r.xp:SetFrameLevel(r.xpRested:GetFrameLevel() + 1)
	r.xpLeft = r.xp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.xpLeft:SetPoint("LEFT", r.xpTrack, "LEFT", 4, 0)
	r.xpLeft:SetJustifyH("LEFT")
	r.xpLeft:SetShadowOffset(1, -1)
	r.restRight = r.xp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.restRight:SetPoint("RIGHT", r.xpTrack, "RIGHT", -4, 0)
	r.restRight:SetWidth(52)
	r.restRight:SetJustifyH("RIGHT")
	r.restRight:SetShadowOffset(1, -1)
    -- XP remains legible on the thinner track used to free castbar height.
    if STANDARD_TEXT_FONT then
        r.xpLeft:SetFont(STANDARD_TEXT_FONT,10,"OUTLINE")
        r.restRight:SetFont(STANDARD_TEXT_FONT,10,"OUTLINE")
    end

	local box = CreateFrame("Button", nil, r)
	box:RegisterForClicks("LeftButtonUp")
	box:SetScript("OnClick", function()
		if HB.PromoteName then HB.PromoteName(r.name) end
	end)
	box.bg = tileTexture(box,"BACKGROUND")
    box.border = tileBorder(box)
    box.border:SetAlpha(0.96)
	box.icon = box:CreateTexture(nil, "ARTWORK")
	box.icon:SetSize(22, 22)
	box.icon:SetPoint("CENTER", box, "CENTER", 0, 0)
    -- Optional second symbol: action (link/pause) + target (leader/healer).
    -- Re-use the existing follow tile; never enlarge its clickable area.
    box.targetIcon = box:CreateTexture(nil, "ARTWORK")
    box.targetIcon:SetSize(22, 22)
    box.targetIcon:Hide()
	box.edge = {}
    local gold = {0.71,0.56,0.27,0.98} -- same gold as Focus + outer frame
	for i = 1, 4 do
		local edge = solid(box, "OVERLAY", gold)
		box.edge[i] = edge
		if i == 1 then edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(2)
		elseif i == 2 then edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(2)
		elseif i == 3 then edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(2)
		else edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(2) end
		edge:Show()
	end
    -- Icon ONLY: no label inside the clickable follow / leader block.
    r.box = box
    -- One outer gilded perimeter, encompassing the player name, all bars,
    -- the upper Focus third and the lower Follow two-thirds.
    r.combinedBorder=CreateFrame("Frame",nil,r)
    r.combinedBorder:EnableMouse(false)
    r.combinedBorder:SetFrameLevel(box:GetFrameLevel()+5)
    for side=1,4 do
        local edge=solid(r.combinedBorder,"OVERLAY",{0.71,0.56,0.27,0.98})
        if side==1 then edge:SetPoint("TOPLEFT");edge:SetPoint("TOPRIGHT");edge:SetHeight(2)
        elseif side==2 then edge:SetPoint("BOTTOMLEFT");edge:SetPoint("BOTTOMRIGHT");edge:SetHeight(2)
        elseif side==3 then edge:SetPoint("TOPLEFT");edge:SetPoint("BOTTOMLEFT");edge:SetWidth(2)
        else edge:SetPoint("TOPRIGHT");edge:SetPoint("BOTTOMRIGHT");edge:SetWidth(2) end
    end
    r.focusDivider=solid(r.focusTile,"OVERLAY",{0.71,0.56,0.27,0.98})
    r.focusDivider:SetPoint("BOTTOMLEFT");r.focusDivider:SetPoint("BOTTOMRIGHT");r.focusDivider:SetHeight(2)
    -- Configure the real Focus blue inner dimensions BEFORE creating native
    -- AuraButtons, whose elementWidth/Height are fixed at AddAuraGroup time.
    sizeRow(r)
    if HB.CreateAuraWidgets then HB.CreateAuraWidgets(r) end
    -- The new aura rails now exist: anchor them to the already-sized Focus.
    sizeRow(r)
	return r
end

local function setBox(r, c, actionIcon, targetIcon)
    local b = r.box
    b.bg:SetVertexColor(c[1], c[2], c[3], c[4])
    -- Keep the normal single-icon status (including FOLLOW BREAK) untouched.
    -- When a target is given, render action + role in the same square.
    b.icon:ClearAllPoints()
    if targetIcon then
        b.icon:SetPoint("RIGHT", b, "CENTER", -1, 0)
        b.targetIcon:ClearAllPoints()
        b.targetIcon:SetPoint("LEFT", b, "CENTER", 1, 0)
        b.targetIcon:SetTexture(MEDIA .. targetIcon)
        b.targetIcon:Show()
    else
        b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.targetIcon:Hide()
    end
    if actionIcon then
        b.icon:SetTexture(MEDIA .. actionIcon)
        b.icon:Show()
    else
        b.icon:Hide()
        b.targetIcon:Hide()
    end
end

-- Walks the follow chain from a toon: true when it ends at the leader (or at
-- someone outside the team we know nothing about), false when a toon on the way
-- has stopped following. Following the healer while the healer stopped = paused.
local function chainMoving(target)
	local seen = {}
	for _ = 1, 10 do
		local k = HB.Norm(target)
		if not k or seen[k] then return true end
		seen[k] = true
		if HB.IsLeaderName(target) then return true end
		local st = HB.followState[k]
		if st == "X" then return false end
		if st ~= "S" then return true end
		target = HB.followTarget[k]
		if not target then return true end
	end
	return true
end


-- ---------------------------------------------------------------- updates
local function safe(fn, ...)
	local ok, v = pcall(fn, ...)
	if ok and not secret(v) then return v end
end

-- Per-toon money and bag free-space arrive through the already functioning
-- Alpha4 DATA sync; never allocate another partywide information column.
-- Native gold/silver/copper coin art. Number is always actual client data;
-- the snapshot 3g 94s 77c from screenshot is NEVER hard-coded.
local function compactMoney(copper)
    if type(copper)~="number" or copper<0 or secret(copper) then return "" end
    local gold=math.floor(copper/10000)
    local silver=math.floor(copper%10000/100)
    local copperPart=math.floor(copper%100)
    local g="|TInterface\\MoneyFrame\\UI-GoldIcon:11:11:0:0|t"
    local s="|TInterface\\MoneyFrame\\UI-SilverIcon:11:11:0:0|t"
    local c="|TInterface\\MoneyFrame\\UI-CopperIcon:11:11:0:0|t"
    if gold>0 then return gold..g.." "..silver..s.." "..copperPart..c end
    if silver>0 then return silver..s.." "..copperPart..c end
    return copperPart..c
end
function HB.UpdatePartyResourceText()
    local source=_G.HaploBoxA4
    local entries,span,teamMoney={},HB.CURRENCY_MIN_SPAN,0
    for _,r in ipairs(rows) do
        if r:IsShown() and r.goldText and r.bagText then
            local data=source and source.data
            local n=r.name and HB.Norm(r.name)
            local d=n and data and data[n]
            if not d and r.unit and source and source.UnitName then
                local live=source.UnitName(r.unit)
                d=live and data and data[source.Norm(live)]
            end
            entries[#entries+1]={row=r,data=d}
            if d and type(d.gold)=="number" and not secret(d.gold) and d.gold>=0 then
                span=math.max(span,HB.CurrencySpanForCopper(d.gold))
                teamMoney=teamMoney+d.gold
            end
        end
    end
    span=math.max(span,HB.CurrencySpanForCopper(teamMoney))
    HB.currencySpanWidth=span
    for _,entry in ipairs(entries) do
        local r,d=entry.row,entry.data
        -- The goldText string is an INVISIBLE GEOMETRY ANCHOR, not a dynamic
        -- money string. Three fixed denomination cells are positioned on it.
        r.goldText:SetText("")
        r.goldText:SetWidth(span)
        HB.SetCurrencyCells(r.currencyCells,d and d.gold,span)
        r.bagText:SetSize(31,21)
        if d and type(d.bags)=="number" and not secret(d.bags) and d.bags>=0 then
            r.bagText:SetText(tostring(d.bags))
            if d.bags==0 then r.bagText:SetTextColor(1,0.33,0.28)
            elseif d.bags<=3 then r.bagText:SetTextColor(1,0.72,0.26)
            else r.bagText:SetTextColor(0.80,0.87,0.92) end
        else r.bagText:SetText("") end
        if r.bagIcon then
            local known=d and type(d.bags)=="number" and not secret(d.bags) and d.bags>=0
            r.bagIcon:SetShown(not not known)
            local cap=d and d.bagCapacity
            if known and type(cap)=="number" and not secret(cap) and cap>0 then
                local frac=d.bags/cap
                if frac>0.50 then r.bagIcon:SetVertexColor(0.22,0.86,0.39)
                elseif frac>=0.20 then r.bagIcon:SetVertexColor(1,0.76,0.21)
                else r.bagIcon:SetVertexColor(1,0.31,0.29) end
            else r.bagIcon:SetVertexColor(0.70,0.73,0.78) end
        end
        if r.levelText and r.nameText then
            local w=r:GetWidth()
            if type(w)=="number" and not secret(w) and w>0 then
                local nameWidth=r.nameText.GetUnboundedStringWidth and r.nameText:GetUnboundedStringWidth() or r.nameText:GetStringWidth()
                if type(nameWidth)~="number" or secret(nameWidth) then nameWidth=w*0.35 end
                local reserve=(w>=220) and (span+84) or (span+10)
                r.nameText:SetWidth(math.max(35,math.min(math.ceil(nameWidth)+2,w-46-reserve)))
            end
        end
    end
    if HB.RefreshResourceSummary then HB.RefreshResourceSummary() end
end

-- Only format numbers when fully readable (combat HP may be secret on 12.x).
local function readableHP(n)
    if type(n)~="number" or secret(n) then return nil end
    local s=tostring(math.max(0,math.floor(n+0.5)))
    return s:reverse():gsub("(%d%d%d)","%1."):reverse():gsub("^%.","")
end
local function updateHealth(r)
	local u = r.unit
	if not u or not UnitExists(u) then
		r.health:SetMinMaxValues(0, 1) r.health:SetValue(0)
		r.levelText:SetText("")
		r.pctText:SetText("")
        if r.hpIndexText then r.hpIndexText:SetText("") end
        if r.incomingHeal then r.incomingHeal:Hide() end
		return
	end
	local lv = safe(UnitLevel, u)
	r.levelText:SetText(lv and tostring(lv) or "")
	if safe(UnitIsConnected, u) == false then r.pctText:SetText("|cff999999offline|r") r.hpIndexText:SetText("") r.health:SetValue(0) if r.incomingHeal then r.incomingHeal:Hide() end return end
	if safe(UnitIsDeadOrGhost, u) then r.pctText:SetText("|cffff5555dead|r") r.hpIndexText:SetText("") r.health:SetValue(0) if r.incomingHeal then r.incomingHeal:Hide() end return end
	local h, m = UnitHealth(u), UnitHealthMax(u)
	r.health:SetMinMaxValues(0, m)
    r.health:SetValue(h)
    local current,total=readableHP(h),readableHP(m)
    -- Secret values cannot be coerced to text by addon code. Preserve a
    -- neutral placeholder in protected combat instead of risking Lua errors.
    r.hpIndexText:SetText(current and total and (current.." / "..total) or "HP ?")
    if r.incomingHeal and HB.UpdateIncomingHealBar then
        HB.UpdateIncomingHealBar(r.incomingHeal,u,m)
    end
	if not secret(h) and not secret(m) then
		r.pctText:SetText(m > 0 and (math.floor(h / m * 100 + 0.5) .. "%") or "")
	elseif UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
		local ok = pcall(function()
			r.pctText:SetFormattedText("%.0f%%", UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
		end)
		if not ok then r.pctText:SetText("") end
	else
		r.pctText:SetText("")
	end
end

-- The team is made of Druids: always show MANA (power type 0), not
-- whatever primary resource a shapeshift or client happens to expose.
-- Keep power numbers on native StatusBars: combat may make them secret.
local MANA_TYPE = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local function updatePower(r)
    local u = r.unit
    if not u or not UnitExists(u) then
        r.power:SetMinMaxValues(0,1)
        r.power:SetValue(0)
        return
    end
    r.power:SetStatusBarColor(C.power[1],C.power[2],C.power[3])
    -- Do not test/compare mana values here; protected power data is secret in
    -- modern Forever combat. Native bar setters can consume secret numbers.
    local ok = pcall(function()
        local maximum = UnitPowerMax(u,MANA_TYPE)
        local current = UnitPower(u,MANA_TYPE)
        r.power:SetMinMaxValues(0,maximum)
        r.power:SetValue(current)
    end)
    if not ok then
        -- Older clients can lack the explicit power-type argument.
        pcall(function()
            r.power:SetMinMaxValues(0,UnitPowerMax(u))
            r.power:SetValue(UnitPower(u))
        end)
    end
    r.powerText:SetText("") -- numeric mana percentages intentionally hidden
end

local function updateXP(r)
	local k = HB.Norm(r.name)
	local data = HB.xp and k and HB.xp[k]
	if not data or not r.unit then
		r.xp:SetMinMaxValues(0, 1) r.xp:SetValue(0)
		r.xpRested:SetMinMaxValues(0, 1) r.xpRested:SetValue(0)
		r.xpLeft:SetText("--") r.restRight:SetText("")
		return
	end
	local current, maximum = data.current, data.maximum
	local rested = data.rested or 0
	if not maximum or maximum <= 0 then
		r.xpLeft:SetText("--") r.restRight:SetText("")
		return
	end
	r.xp:SetMinMaxValues(0, maximum)
	r.xp:SetValue(math.min(current, maximum))
	r.xpRested:SetMinMaxValues(0, maximum)
	r.xpRested:SetValue(math.min(maximum, current + rested))
	r.xpLeft:SetText(math.floor(current / maximum * 100 + 0.5) .. "%")
	r.restRight:SetText(math.floor(rested / maximum * 100 + 0.5) .. "%")
end

local function updateStatus(r)
	local leader = HB.GroupLeader and HB.GroupLeader()
	local isLeader = leader and HB.Norm(r.name) == HB.Norm(leader)
	r.leaderCrown:SetShown(not not isLeader)
	if r.healerMark then
		r.healerMark:ClearAllPoints()
		if isLeader then r.healerMark:SetPoint("LEFT", r.leaderCrown, "RIGHT", 3, 0)
		else r.healerMark:SetPoint("LEFT", r.nameText, "RIGHT", 4, 0) end
        -- Preserve the old custom healer mark only when the WoW role API
        -- does not supply an assigned Blizzard group role.
        local assigned="NONE"
        if r.unit and UnitGroupRolesAssigned then
            local ok,role=pcall(UnitGroupRolesAssigned,r.unit)
            if ok and type(role)=="string" and not secret(role) then assigned=role end
        end
        local roleVisible=assigned=="TANK" or assigned=="HEALER" or assigned=="DAMAGER"
        r.healerMark:SetShown(not roleVisible and HB.RoleOf(r.name)=="healer")
        if r.blizzardRoleIcon then
            local texCoords=GetTexCoordsForRoleSmallCircle or GetTexCoordsForRole
            local ok,a,b,c,d=false,nil,nil,nil,nil
            if texCoords and roleVisible then ok,a,b,c,d=pcall(texCoords,assigned) end
            local anchor=isLeader and r.leaderCrown or r.nameText
            r.blizzardRoleIcon:ClearAllPoints()
            r.blizzardRoleIcon:SetPoint("LEFT",anchor,"RIGHT",3,0)
            r.blizzardRoleFallback:ClearAllPoints()
            r.blizzardRoleFallback:SetPoint("LEFT",anchor,"RIGHT",3,0)
            if ok and type(a)=="number" and type(b)=="number" and type(c)=="number" and type(d)=="number" then
                r.blizzardRoleIcon:SetTexCoord(a,b,c,d)
                r.blizzardRoleIcon:Show()
                r.blizzardRoleFallback:Hide()
            else
                r.blizzardRoleIcon:Hide()
                r.blizzardRoleFallback:SetText(assigned=="TANK" and "T" or assigned=="HEALER" and "H" or "D")
                r.blizzardRoleFallback:SetShown(roleVisible) -- role from WoW, never inferred
            end
        end
	end
	if r.box.edge then
        for _, edge in ipairs(r.box.edge) do
            edge:Show() -- gilded perimeter AROUND Follow, plus shared outer rim
        end
    end
	if isLeader then setBox(r, C.lead, "crown") return end
	if not r.unit then setBox(r, C.unknown, nil) return end
	local k = HB.Norm(r.name)
	local st, target = HB.followState[k], HB.followTarget[k]
	if st == "X" then setBox(r, C.broken, "link-broken") return end
	if st ~= "S" then setBox(r, C.unknown, nil) return end
	if HB.db.followMode == "dungeon" and target and not chainMoving(target) then
        if HB.RoleOf(target) == "healer" then
            setBox(r, C.paused, "pause", "cross") -- healer stopped: DPS wait
        else
            setBox(r, C.paused, "pause") -- preserve legacy status for other targets
        end
        return
    end
	local expected = HB.ExpectedFollowTarget and HB.ExpectedFollowTarget(r.name)
	if not expected and HB.db.followMode == "dungeon" and HB.Norm(r.name) ~= HB.Norm(HB.Healer()) then
		-- A dungeon chain needs a configured /hb role healer. Don't guess.
		setBox(r, C.unknown, nil)
		return
	end
	if expected and target and HB.Norm(target) ~= HB.Norm(expected) then
		setBox(r, C.broken, "link-broken") -- following the wrong character
		return
	end
	if target and HB.RoleOf(target) == "healer" and HB.Norm(target) ~= HB.Norm(leader) then
		setBox(r, C.ok, "link", "cross") -- following the healer
	else
		setBox(r, C.ok, "link", "crown") -- following the leader
	end
end

local function updateRange(r)
	local u = r.unit
	if not u then r:SetAlpha(0.45) return end
	if u == "player" then r:SetAlpha(1) return end
	local ok, inRange, checked = pcall(UnitInRange, u)
	if not ok then r:SetAlpha(1) return end
	if secret(inRange) then
		if r.SetAlphaFromBoolean then pcall(r.SetAlphaFromBoolean, r, inRange, 1, 0.5) else r:SetAlpha(1) end
	elseif checked == false or secret(checked) then
		r:SetAlpha(1)
	else
		r:SetAlpha(inRange and 1 or 0.5)
	end
end

-- The former Focus tile now shows this character's reported combat status.
-- Preserve all sizing/anchors: HoT rails still attach to the same tile frame.
local function updateCombat(r)
    local state=HB.CombatState and HB.CombatState(r.name)
    local color=state==true and C.broken or state==false and C.ok or C.unknown
    r.focusBg:SetVertexColor(color[1],color[2],color[3],color[4])
    r.focusIcon:SetTexture(MEDIA .. "swords-clear.tga")
    r.focusIcon:SetVertexColor(1,1,1) -- original multicolour icon, not tinted
    local size=r.focusTile:GetHeight()
    r.focusIcon:SetSize(math.min(27,math.floor(size*0.72)),math.min(27,math.floor(size*0.72)))
    r.focusIcon:Show()
    r.focusText:SetText("") -- icon only; never a combat label
    for _,edge in ipairs(r.focusTile.edges) do edge:Show() end
end
local function updateRow(r)
	updateColors(r) updateHealth(r) updatePower(r) updateXP(r) updateStatus(r) updateCombat(r) updateRange(r)
	if HB.UpdateAuraWidgets then HB.UpdateAuraWidgets(r) end
end

function HB.RefreshPartyFrame()
	for _, r in ipairs(rows) do if r:IsShown() then updateRow(r) end end
end

function HB.OnXPChanged()
	for _, r in ipairs(rows) do if r:IsShown() then updateXP(r) end end
end

function HB.OnCombatStateChanged()
    for _,r in ipairs(rows) do if r:IsShown() then updateCombat(r) end end
end
-- Kept for compatibility with old focus messages until migration is complete.
function HB.OnFocusChanged() end

function HB.OnFollowStateChanged()
	for _, r in ipairs(rows) do if r:IsShown() then updateStatus(r) end end
end


-- ---------------------------------------------------------------- slim cast & 5SR tracks
-- Native UnitCastingInfo on party tokens is preferred; follower messages are a
-- fallback on clients that don't expose other units' cast times. These tracks
-- *observe* a cast, not a keypress, and can't demonstrate an instant cast.
local remoteCasts, fiveSRAt = {}, {}
local lastPlayerPower, recentPlayerCast, lastPowerDecreaseAt, lastManaSpendAt = nil,0,0,0
local function safeNumber(v)
    return type(v)=="number" and not secret(v) and v or nil
end
local castFunctions={}
if UnitCastingInfo then castFunctions[#castFunctions+1]=UnitCastingInfo end
if UnitChannelInfo then castFunctions[#castFunctions+1]=UnitChannelInfo end
local function currentCast(u)
    local now=GetTime()
    for _,fn in ipairs(castFunctions) do
        if fn then
            local ok,name,_,_,startMS,endMS=pcall(fn,u)
            if ok and name and not secret(name) then
                local first,last=safeNumber(startMS),safeNumber(endMS)
                if first and last and last>first then
                    local begin,finish=first/1000,last/1000
                    if now>=begin-0.2 and now<=finish+0.2 then
                        return begin,finish
                    end
                end
            end
        end
    end
end
local function updateCast(r)
    if not r.castBar then return end
    local now=GetTime()
    local first,last
    if r.unit then first,last=currentCast(r.unit) end
    if not first then
        local data=r.name and remoteCasts[HB.Norm(r.name)]
        if data and now<data.finish then first,last=data.begin,data.finish end
    end
    if first and last and last>first then
        r.castBar:SetMinMaxValues(0,last-first)
        r.castBar:SetValue(math.max(0,math.min(last-first,now-first)))
    else
        r.castBar:SetMinMaxValues(0,1)
        r.castBar:SetValue(0)
    end
end
local function updateFiveSR(r)
    if not r.fiveSR then return end
    local started=fiveSRAt[r.name and HB.Norm(r.name)]
    if not started then r.fiveSR:SetValue(5);return end
    r.fiveSR:SetValue(math.max(0,math.min(5,GetTime()-started)))
end
function HB.ReceivePulse(sender,code,arg)
    if not sender or not (HB.IsGroupMember and HB.IsGroupMember(sender)) then return end
    local key=HB.Norm(sender)
    if not key then return end
    if code=="C" then
        local ms=tonumber(arg)
        if ms and ms>0 and ms<=30000 then
            local now=GetTime()
            remoteCasts[key]={begin=now,finish=now+ms/1000}
        end
    elseif code=="X" then
        remoteCasts[key]=nil
    elseif code=="M" then
        fiveSRAt[key]=GetTime()
    end
end
local function playerCastMessage()
    if not HB.SendTeamMessage then return end
    local first,last=currentCast("player")
    if first and last then
        local ms=math.floor((last-first)*1000+0.5)
        if ms>0 and ms<=30000 then HB.SendTeamMessage("Y|C|"..ms) end
    end
end
local function recordManaSpend()
    local name=HB.UnitIdent("player")
    local key=name and HB.Norm(name)
    local now=GetTime()
    if now-lastManaSpendAt<0.2 then return end
    lastManaSpendAt=now
    if key then fiveSRAt[key]=now end
    if HB.SendTeamMessage then HB.SendTeamMessage("Y|M") end
end
-- If unprotected, detect the actual mana decrease (including Druid forms).
-- If the combat client marks power as secret, use the spell-cost fallback below.
local function checkPlayerMana()
    local ok,amount=pcall(UnitPower,"player",MANA_TYPE)
    amount=ok and safeNumber(amount) or nil
    if not amount then lastPlayerPower=nil;return end
    if lastPlayerPower and amount<lastPlayerPower then
        lastPowerDecreaseAt=GetTime()
        if GetTime()-recentPlayerCast<1.5 then
            recordManaSpend()
            recentPlayerCast=0
        end
    end
    lastPlayerPower=amount
end

-- The spell-cost API works even when combat power readings are protected.
-- A fallback list handles older Forever client builds that don't expose cost
-- data for a spell ID. We intentionally exclude free/unknown abilities.
local KNOWN_MANA_SPELLS = {
    wrath=true,moonfire=true,starfire=true,rejuvenation=true,regrowth=true,
    ["healing touch"]=true,["mark of the wild"]=true,["gift of the wild"]=true,
    thorns=true,["entangling roots"]=true,["faerie fire"]=true,
    ["nature's grasp"]=true,hibernate=true,["cure poison"]=true,
    ["remove curse"]=true,tranquility=true,hurricane=true,
    ["abolish poison"]=true,["rebirth"]=true,["revive"]=true,
    ["bear form"]=true,["cat form"]=true,["travel form"]=true,
    ["aquatic form"]=true,["dire bear form"]=true,
}
local function successfulManaSpell(spellID)
    if type(spellID)~="number" or secret(spellID) then return false end
    local fn=(C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if fn then
        local ok,costs=pcall(fn,spellID)
        if ok and type(costs)=="table" then
            for _,entry in ipairs(costs) do
                if type(entry)=="table" and
                   ((not secret(entry.type) and entry.type==MANA_TYPE) or
                    (not secret(entry.name) and entry.name=="MANA")) then
                    for _,field in ipairs({"cost","minCost","costPercent","costPerSec"}) do
                        local value=entry[field]
                        if type(value)=="number" and not secret(value) and value>0 then
                            return true
                        end
                    end
                end
            end
            -- An empty cost list confirms a free spell: don't fabricate a 5SR.
            return false
        end
    end
    local nameFn=(C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if nameFn then
        local ok,name=pcall(nameFn,spellID)
        if ok and type(name)=="string" and not secret(name) then
            return KNOWN_MANA_SPELLS[name:lower()] or false
        end
    end
    return false
end

-- ---------------------------------------------------------------- handle, lock and resize
local function shownRows()
	local n = 0
	for _, r in ipairs(rows) do if r:IsShown() then n = n + 1 end end
	return n
end

local function sizeContainer()
    local n = math.max(1, shownRows())
    local W, _, _, _, _, _, square, actualH, infoW = geometry()
    -- Visual aura rails can extend into the game world but MUST NOT enlarge
    -- the container, Controls header or secure partyframes / click target area.
    local followW=math.max(42,math.floor(square*0.84+0.5))
    container:SetSize(W - 1 + followW,n * (actualH + ROW_GAP) - ROW_GAP)
	for i, r in ipairs(rows) do
		if r:IsShown() then
			sizeRow(r)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * (actualH + ROW_GAP))
		end
	end
	if HB.UpdateControlSize then HB.UpdateControlSize(container) end
end

local function updateLockUI()
	local unlocked = not HB.db.teamLocked
    -- One drag handle only: the persistent Controls header.
    container.handle:Hide()
    container.grip:SetShown(unlocked)
end

function HB.SetTeamFrameLocked(locked)
	HB.db.teamLocked = locked and true or false
	if container then updateLockUI() end
	HB.print("team frame " .. (HB.db.teamLocked and "locked (/hb frame unlock to move it)"
		or "unlocked: drag the bar or a row to move it, drag the corner to resize"))
end

local function createChrome()
	local h = CreateFrame("Frame", nil, container)
	h:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 2)
	h:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, 2)
	h:SetHeight(18)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", startMove)
	h:SetScript("OnDragStop", function() HB.SavePartyPosition() end)
	solid(h, "BACKGROUND", { 0.10, 0.11, 0.13, 0.95 }):SetAllPoints()
	local t = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	t:SetPoint("LEFT", 6, 0)
	t:SetText("JCDRbox team - drag to move")
	local lock = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
	lock:SetSize(48, 16)
	lock:SetPoint("RIGHT", -2, 0)
	lock:SetText("Lock")
	lock:SetScript("OnClick", function() HB.SetTeamFrameLocked(true) end)
    -- Distinct outer gold border for the whole team block, not individual
    -- swords/status tiles. Decorative textures cannot intercept clicks.
    for side=1,4 do
        local line=container:CreateTexture(nil,"OVERLAY")
        line:SetColorTexture(0.157,0.376,0.502,0.95)
        if side==1 then line:SetPoint("TOPLEFT",container,"TOPLEFT");line:SetPoint("TOPRIGHT",container,"TOPRIGHT");line:SetHeight(2)
        elseif side==2 then line:SetPoint("BOTTOMLEFT",container,"BOTTOMLEFT");line:SetPoint("BOTTOMRIGHT",container,"BOTTOMRIGHT");line:SetHeight(2)
        elseif side==3 then line:SetPoint("TOPLEFT",container,"TOPLEFT");line:SetPoint("BOTTOMLEFT",container,"BOTTOMLEFT");line:SetWidth(2)
        else line:SetPoint("TOPRIGHT",container,"TOPRIGHT");line:SetPoint("BOTTOMRIGHT",container,"BOTTOMRIGHT");line:SetWidth(2) end
    end
	container.handle = h

	local g = CreateFrame("Button", nil, container)
	g:SetSize(16, 16)
	g:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 2, -2)
	g:SetFrameLevel(container:GetFrameLevel() + 20)
	solid(g, "BACKGROUND", { 0.45, 0.45, 0.50, 0.6 }):SetAllPoints()  -- visible even without the grabber art
	g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	g:SetScript("OnMouseDown", function(self)
		if InCombatLockdown() or HB.db.teamLocked then return end
		local s = container:GetEffectiveScale()
		local cx, cy = GetCursorPosition()
		self.start = { x = cx / s, y = cy / s, w = rowW(), h = rowH(), n = math.max(1, shownRows()), s = s }
		self:SetScript("OnUpdate", function()
			if InCombatLockdown() then return end
			local st = self.start
			local x, y = GetCursorPosition()
			x, y = x / st.s, y / st.s
			HB.db.teamW = math.floor(math.min(MAX_W, math.max(MIN_W, st.w + (x - st.x))) + 0.5)
			HB.db.teamRowH = math.floor(math.min(MAX_H, math.max(MIN_H, st.h + (st.y - y) / st.n)) + 0.5)
			sizeContainer()
		end)
	end)
	g:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
		HB.SavePartyPosition()
	end)
	container.grip = g
	if HB.AttachControlBar then HB.AttachControlBar(container) end
	updateLockUI()
end

-- ---------------------------------------------------------------- layout (out of combat only)
local function wanted()
	local mode = HB.db.teamFrame
    if HB.db.miniHealMode then return false end -- mini view has its own secure unit buttons
	if mode == "hide" then return false end
	if mode ~= "show" and not HB.IAmLeader() then return false end  -- "auto": leader only
	if not IsInGroup() and not HB.db.partyFrameSolo then return false end
	return #visibleTeamOrder() > 0
end

-- The narrow Blizzard raid-manager tab can overlap a flush-left HB team UI.
-- Never touch a protected native frame or attempt protected changes in combat.
-- Restore original visibility/mouse state whenever HB party UI is not active.
local nativeSidebar={}
local function suppressNativeSidebar(active)
    -- HF12 PFR-07: do not suppress the native Blizzard Party snapper.
    -- Restore earlier HaploBox-imposed alpha/mouse values if present.
    if InCombatLockdown and InCombatLockdown() then return end
    for f,state in pairs(nativeSidebar) do
        if f and (not f.IsForbidden or not f:IsForbidden()) and
            (not f.IsProtected or not f:IsProtected()) then
            if f.SetAlpha then pcall(f.SetAlpha,f,state.alpha or 1) end
            if f.EnableMouse then pcall(f.EnableMouse,f,state.mouse) end
        end
        nativeSidebar[f]=nil
    end
end

function HB.LayoutPartyFrame()
	if not container then return end
	if InCombatLockdown() then pendingLayout = true return end
	pendingLayout = false
	container:SetScale(HB.db.partyScale or 1)
    if not wanted() then
        suppressNativeSidebar(false)
        container:Hide()
        -- HF26.19.3: Buff Overview is NOT part of the secure Party Frame.
        -- Build/rebind the non-visible unit rows as aura data carriers even
        -- in solo play and when the party UI is hidden. Mini UI is an
        -- explicit EXCEPTION: its Buff Overview must remain hidden.
        -- Protected unit attributes are only changed OUT OF COMBAT here.
        if HB.db and HB.db.buffOverviewEnabled~=false and not HB.db.miniHealMode then
            local names=visibleTeamOrder()
            wipe(unitRow)
            for i,name in ipairs(names) do
                local r=rows[i] or createRow(i)
                rows[i]=r
                local u=unitForName(name)
                if HB.ResetAuraRow and (r.name~=name or r.unit~=u) then
                    HB.ResetAuraRow(r)
                end
                r.name,r.unit=name,u
                r:SetAttribute("unit",u)
                if HB.BindAuraUnit then HB.BindAuraUnit(r) end
                if u then unitRow[u]=r end
                r:Hide() -- keep secure Party UI hidden; aura rails use UIParent
            end
            for i=#names+1,#rows do
                rows[i]:Hide()
                rows[i].unit=nil
                rows[i]:SetAttribute("unit",nil)
            end
            if HB.LayoutBuffOverview then HB.LayoutBuffOverview(true,rows) end
        elseif HB.LayoutBuffOverview then
            HB.LayoutBuffOverview(false,rows)
        end
        if HB.LayoutDebuffOverview then HB.LayoutDebuffOverview(false,rows) end
        if HB.UpdateMiniHealLayout then HB.UpdateMiniHealLayout() end
        if HB.RefreshControls then HB.RefreshControls() end
        return
    end
	local names = visibleTeamOrder()
	displayPrefix = sharedPrefix(names)
	wipe(unitRow)
	for i, name in ipairs(names) do
		local r = rows[i] or createRow(i)
		rows[i] = r
        local previousName,previousUnit = r.name,r.unit
		r.name = name
		r.unit = unitForName(name)
        if HB.ResetAuraRow and (previousUnit ~= r.unit or previousName ~= name) then
            HB.ResetAuraRow(r)
        end
		r:SetAttribute("unit", r.unit)
        if HB.BindAuraUnit then HB.BindAuraUnit(r) end
		r.nameText:SetText(displayName(name))
		if r.unit then unitRow[r.unit] = r end
		r:Show()
	end
	for i = #names + 1, #rows do rows[i]:Hide() rows[i]:SetAttribute("unit", nil) end
	sizeContainer()
	updateLockUI()
	container:Show()
    suppressNativeSidebar(true)
    if HB.LayoutBuffOverview then HB.LayoutBuffOverview(true,rows) end
    if HB.LayoutDebuffOverview then HB.LayoutDebuffOverview(true,rows) end
    if HB.UpdateMiniHealLayout then HB.UpdateMiniHealLayout() end
	HB.RefreshPartyFrame()
    if HB.UpdatePartyResourceText then HB.UpdatePartyResourceText() end
	if HB.RefreshControls then HB.RefreshControls() end
end

-- Position is stored as the top-left corner, so resizing grows right and down.
function HB.SavePartyPosition()
	if not container then return end
    if HB.EndControlMove then HB.EndControlMove() return end
    container:StopMovingOrSizing()
    local left,top=container:GetLeft(),container:GetTop()
    if not left or not top then return end
    HB.db.partyPos={"TOPLEFT","BOTTOMLEFT",left,top}
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
end

function HB.ApplyPartyPosition()
    if not container then return end
    local control=HB.GetControlAnchor and HB.GetControlAnchor()
    container:ClearAllPoints()
    if control then
        container:SetPoint("TOPLEFT",control,"BOTTOMLEFT",0,0)
        return
    end
    local p=HB.db.partyPos
    if p then container:SetPoint(p[1],UIParent,p[2],p[3],p[4])
    else container:SetPoint("TOPLEFT",UIParent,"TOPLEFT",20,-200) end
end

function HB.ResetPartyPosition()
	if InCombatLockdown() then HB.print("not in combat") return end
    HB.db.partyPos,HB.db.controlsPos,HB.db.controlsFrac,HB.db.teamW,HB.db.teamRowH=nil,nil,nil,nil,nil
    if HB.ApplyControlPosition then HB.ApplyControlPosition() end
    HB.ApplyPartyPosition()
	HB.LayoutPartyFrame()
end

-- ---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
local unitEvents = {
	UNIT_HEALTH = updateHealth, UNIT_MAXHEALTH = updateHealth, UNIT_CONNECTION = updateRow,
	UNIT_POWER_UPDATE = updatePower, UNIT_POWER_FREQUENT = updatePower,
	UNIT_MAXPOWER = updatePower, UNIT_DISPLAYPOWER = updatePower,
	UNIT_FLAGS = updateHealth, UNIT_LEVEL = updateHealth,
}

ev:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
	if event == "PLAYER_LOGIN" then
		container = CreateFrame("Frame", "HaploBoxPartyFrame", UIParent)
		container:SetMovable(true)
		container:SetClampedToScreen(true)
        createChrome()
        HB.ApplyPartyPosition() -- secure rows follow Controls, even while solo
        HB.LayoutPartyFrame()
        pcall(checkPlayerMana) -- initial mana is a baseline, not mana spent
        local auraRefreshAt = 0
        local powerTick=0
        C_Timer.NewTicker(0.05, HB.Diag.Wrap("Party 0.05s", function()
            -- Smooth castbar motion at 20Hz; power polling stays at 5Hz.
            -- Power and 5SR must update even if Forever omits per-party
            -- UNIT_POWER_UPDATE during an instant spell or stance change.
            pcall(checkPlayerMana)
            if not container:IsShown() then return end
            local t=GetTime()
            local refreshPower = t>=powerTick
            if refreshPower then powerTick=t+0.20 end
            for _,r in ipairs(rows) do
                if r:IsShown() then
                    updateCast(r);updateFiveSR(r)
                    if refreshPower then pcall(updatePower,r) end
                end
            end
        end))
		C_Timer.NewTicker(0.5, HB.Diag.Wrap("Party 0.5s", function()
            local timeNow = GetTime and GetTime() or 0
            local refreshAuras = timeNow >= auraRefreshAt
            if refreshAuras then auraRefreshAt = timeNow + 1.0 end
            for _,r in ipairs(rows) do
                local partyVisible=container:IsShown() and r:IsShown()
                local buffVisible=r.buffOverviewVisible and r.unit
                if partyVisible then
                    updateRange(r) updateHealth(r) updateCombat(r)
                end
                -- Continue live buff/timer scans on independently visible
                -- panels even when secure Party Frames are deliberately hidden.
                if partyVisible or buffVisible then
                    if refreshAuras and HB.UpdateAuraWidgets then
                        pcall(HB.UpdateAuraWidgets,r)
                    end
                    if HB.TickAuraTimers then pcall(HB.TickAuraTimers,r) end
                end
            end
			-- Controlbar keeps updating while solo and after hidden-frame changes.
			if HB.RefreshControls then HB.RefreshControls() end
		end))
		return
	end
	if not container then return end
	local fn = unitEvents[event]
	if fn then
		local r = arg1 and unitRow[arg1]
		if r and r:IsShown() then pcall(fn, r) end
        if arg1=="player" and (event=="UNIT_POWER_UPDATE" or event=="UNIT_POWER_FREQUENT" or
                                  event=="UNIT_DISPLAYPOWER" or event=="UNIT_MAXPOWER") then
            pcall(checkPlayerMana)
        end
    elseif event == "UNIT_HEAL_PREDICTION" then
        local r=arg1 and unitRow[arg1]
        if r and r:IsShown() then pcall(updateHealth,r) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1=="player" then
            recentPlayerCast=GetTime()
            pcall(checkPlayerMana)
            if GetTime()-lastPowerDecreaseAt<0.5 then
                recordManaSpend()
                lastPowerDecreaseAt=0
            elseif successfulManaSpell(arg3) then
                -- Event fallback: protected combat mana cannot be compared in
                -- Lua, but the client still reports a paid successful cast.
                recordManaSpend()
            end
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if arg1=="player" then
            recentPlayerCast=GetTime()
            playerCastMessage()
            C_Timer.After(0.06,playerCastMessage) -- some clients populate cast info after START
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or
           event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if arg1=="player" and HB.SendTeamMessage then HB.SendTeamMessage("Y|X") end
    elseif event == "UNIT_AURA" then
        local r = arg1 and unitRow[arg1]
        if r and (r:IsShown() or r.buffOverviewVisible) and HB.UpdateAuraWidgets then
            pcall(HB.UpdateAuraWidgets,r)
            local expected=r.unit
            -- Forever sometimes publishes the next aura cache state later than
            -- the immediate event. Schedule two guarded retries, still bounded
            -- by the existing periodic refresh and never reusing a row token.
            for _,delay in ipairs({0.20,0.70}) do
                C_Timer.After(delay,function()
                    if (r:IsShown() or r.buffOverviewVisible) and r.unit==expected then
                        pcall(HB.UpdateAuraWidgets,r)
                    end
                end)
            end
        end
    elseif event == "ROLE_CHANGED_INFORM" or event == "PLAYER_ROLES_ASSIGNED" then
        if InCombatLockdown and InCombatLockdown() then pendingLayout=true
        else HB.RefreshPartyFrame() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingLayout then HB.LayoutPartyFrame() end
	else  -- GROUP_ROSTER_UPDATE, PLAYER_ENTERING_WORLD, UNIT_NAME_UPDATE
		HB.LayoutPartyFrame()
	end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "UNIT_NAME_UPDATE", "UNIT_AURA", "UNIT_HEAL_PREDICTION", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "ROLE_CHANGED_INFORM", "PLAYER_ROLES_ASSIGNED" }) do
	pcall(ev.RegisterEvent, ev, e)
end
for e in pairs(unitEvents) do pcall(ev.RegisterEvent, ev, e) end
