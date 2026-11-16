-- Alpha 5 TB14: integrated Quick Menu layout, gear click-layer fix and JCDRbox icon art.
-- Alpha 5 TB6: persistent, fixed-height Controls anchor.
-- Expanding the menu NEVER changes the secure partyframe anchor position.
-- The popup is a sibling in screen layout, not part of the anchor's height.
local HB=HaploBox
local panel,header,flyout
local nativeParent,buttons=nil,{}
local gear,headline,quickBadges,menuSectionLabels
local summaryGold, summaryBags, summaryBagIcon, summaryCurrencyCells
-- TB13: custom JCDRbox line-art, matching the approved Focus/Follow glyphs.
local media="Interface\\AddOns\\HaploBox\\Media\\"
local quickArt={
    {media.."link.tga","Follow mode"},
    {media.."ui-loot.tga","Loot mode"},
    {media.."ui-repair.tga","Auto repair"},
    {media.."ui-quest.tga","Quest sharing"},
}
local dragging,deferred=false,false
local GREEN={0.15,0.42,0.26,0.98}
local OFF={0.20,0.23,0.28,0.98}
local RED={0.56,0.17,0.17,0.98}
local GOLD={0.43,0.34,0.15,0.98}
local function safe(v) return not (issecretvalue and issecretvalue(v)) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function color(button,c) button.surface:SetColorTexture(c[1],c[2],c[3],c[4]) end
local function font(parent,text)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f:SetJustifyH("LEFT")
    f:SetText(text or "")
    if STANDARD_TEXT_FONT then f:SetFont(STANDARD_TEXT_FONT,10,"OUTLINE") end
    return f
end
local function mkButton(i,text,fn)
    local b=CreateFrame("Button",nil,flyout)
    b:RegisterForClicks("LeftButtonUp")
    b.surface=b:CreateTexture(nil,"BACKGROUND");b.surface:SetAllPoints()
    b.surface:SetColorTexture(unpack(OFF))
    b.label=font(b,text)
    b.label:SetPoint("CENTER");b.label:SetJustifyH("CENTER")
    if i==1 or i==2 or i==3 or i==4 or i==5 or i==10 or i==12 or i==13 then
        local paths={
            [1]=media.."link.tga", [2]=media.."link.tga", [3]=media.."cross.tga",
            [4]=quickArt[4][1], [5]=quickArt[2][1],
            [10]=quickArt[3][1], [12]=media.."ui-lock.tga",
            [13]=media.."ui-heal.tga",
        }
        b.glyph=b:CreateTexture(nil,"ARTWORK")
        b.glyph:SetTexture(paths[i])
        b.glyph:SetSize(14,14)
        b.glyph:SetPoint("LEFT",b,"LEFT",5,0)
        if i==1 or i==2 then
            b.glyph2=b:CreateTexture(nil,"ARTWORK")
            b.glyph2:SetTexture(media..(i==1 and "crown.tga" or "cross.tga"))
            b.glyph2:SetSize(12,12)
            b.glyph2:SetPoint("LEFT",b,"LEFT",14,0)
        end
    end
    b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
    b:SetScript("OnClick",fn)
    buttons[i]=b
    return b
end
local function screenCoords()
    if not panel then return nil end
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local left,top=panel:GetLeft(),panel:GetTop()
    local parentTop=UIParent:GetTop()
    if not (width and height and left and top and parentTop and
        safe(width) and safe(height) and safe(left) and safe(top) and safe(parentTop) and
        width>0 and height>0) then return nil end
    -- Convert the panel coordinate system into UIParent's coordinate system.
    -- For identical UI scale these factors are one; for mixed global WoW UI
    -- scales they avoid sending addon-scale-specific pixel offsets.
    local ps=panel:GetEffectiveScale() or 1
    local us=UIParent:GetEffectiveScale() or 1
    if not (safe(ps) and safe(us) and us>0) then return nil end
    local factor=ps/us
    local x=left*factor-(UIParent:GetLeft() or 0)
    local y=parentTop-top*factor
    return clamp(x/width,0,0.98),clamp(y/height,0,0.98)
end
function HB.GetControlFractions()
    -- Read live position first: a leader may share immediately after moving.
    local x,y=screenCoords()
    if x and y then return x,y end
    local p=HB.db and HB.db.controlsFrac
    if type(p)=="table" then return p[1],p[2] end
end
local function applyPosition()
    if not (panel and HB.db) then return end
    if InCombatLockdown and InCombatLockdown() then deferred=true return end
    if not HB.db.unifiedControlsV1 then
        local old=HB.db.partyPos
        local scale=tonumber(HB.db.partyScale) or 1
        if type(old)=="table" and type(old[3])=="number" and type(old[4])=="number" and safe(old[3]) and safe(old[4]) then
            HB.db.controlsPos={old[3],old[4]+23*scale}
        end
        HB.db.unifiedControlsV1=true
    end
    panel:ClearAllPoints()
    local fraction=HB.db.controlsFrac
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if type(fraction)=="table" and type(fraction[1])=="number" and type(fraction[2])=="number" and
       safe(fraction[1]) and safe(fraction[2]) and w and h and safe(w) and safe(h) then
        panel:SetPoint("TOPLEFT",UIParent,"TOPLEFT",clamp(fraction[1],0,0.98)*w,-clamp(fraction[2],0,0.98)*h)
    else
        local p=HB.db.controlsPos
        if type(p)=="table" and type(p[1])=="number" and type(p[2])=="number" and safe(p[1]) and safe(p[2]) then
            -- Preserve the user's existing TB5 position on the same client.
            panel:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",p[1],p[2])
        else
            panel:SetPoint("TOPLEFT",UIParent,"TOPLEFT",20,-44)
        end
    end
end
-- TB13: place the independent popup INSIDE the current game client's viewport.
-- In Mini Heal the normal controlbar is hidden, so the small settings button
-- above the five heal blocks becomes the popup anchor instead.
function HB.PositionQuickSettings()
    if not (flyout and HB.db) then return end
    local screenW,screenH=UIParent:GetWidth(),UIParent:GetHeight()
    if not (screenW and screenH and safe(screenW) and safe(screenH) and screenW>0 and screenH>0) then return end
    local anchor=(HB.db.miniHealMode and HB.GetMiniHealSettingsAnchor and HB.GetMiniHealSettingsAnchor()) or panel
    local effective=anchor and anchor:GetEffectiveScale() or 1
    local parentEffective=UIParent:GetEffectiveScale() or 1
    if not (effective and parentEffective and safe(effective) and safe(parentEffective) and parentEffective>0) then return end
    local aScale=effective/parentEffective
    local w,h=flyout:GetWidth(),flyout:GetHeight()
    if not (w and h and safe(w) and safe(h) and w>0 and h>0) then return end
    -- On small windows scale only the popup, never a secure unit button or the
    -- underlying party layout. Clamp also when the original bar is near edges.
    local baseScale=(tonumber(HB.db.partyScale) or 1)
    if not safe(baseScale) then baseScale=1 end
    local fitScale=math.min((screenW-12)/w,(screenH-12)/h)
    local scale=clamp(math.min(baseScale,fitScale),0.45,2)
    flyout:SetScale(scale)
    local menuW,menuH=w*scale,h*scale
    local left=anchor and anchor:GetLeft()
    local right=anchor and anchor:GetRight()
    local top=anchor and anchor:GetTop()
    if not (left and right and top and safe(left) and safe(right) and safe(top)) then
        flyout:ClearAllPoints()
        flyout:SetPoint("CENTER",UIParent,"CENTER",0,0)
        return
    end
    left,right,top=left*aScale,right*aScale,top*aScale
    -- Touch the Controlbar edge so it reads as one integrated extension.
    local x=right
    if x+menuW>screenW-5 then x=left-menuW end
    x=clamp(x,5,math.max(5,screenW-menuW-5))
    local y=clamp(top,menuH+5,math.max(menuH+5,screenH-5))
    flyout:ClearAllPoints()
    flyout:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
end
function HB.ToggleQuickSettings()
    if not HB.db then return end
    HB.db.controlsOpen=not HB.db.controlsOpen
    if HB.RefreshControls then HB.RefreshControls() end
end
function HB.GetControlAnchor() return panel end
function HB.ApplyControlPosition()
    if not panel then return end
    applyPosition()
    if HB.UpdateControlSize then HB.UpdateControlSize(nativeParent) end
end
function HB.SetControlFractions(x,y)
    if not (HB.db and type(x)=="number" and type(y)=="number" and safe(x) and safe(y)) then return false end
    HB.db.controlsFrac={clamp(x,0,0.98),clamp(y,0,0.98)}
    HB.db.controlsPos=nil -- no conflicting absolute frame position remains
    HB.ApplyControlPosition()
    return true
end
function HB.BeginControlMove()
    if not panel or HB.db.teamLocked or (InCombatLockdown and InCombatLockdown()) then return end
    dragging=true
    panel:StartMoving()
end
function HB.EndControlMove()
    if not panel or not dragging then return end
    panel:StopMovingOrSizing()
    dragging=false
    local x,y=screenCoords()
    if x and y then
        HB.db.controlsFrac={x,y}
        HB.db.controlsPos=nil
    end
    HB.ApplyControlPosition()
end
function HB.AttachControlBar(parent)
    if panel then return end
    nativeParent=parent
    panel=CreateFrame("Frame","HaploBoxControlsPanel",UIParent)
    panel:SetFrameStrata("HIGH");panel:SetFrameLevel(140)
    panel:SetClampedToScreen(true);panel:SetMovable(true);panel:EnableMouse(true)
    local background=panel:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints();background:SetColorTexture(0.08,0.09,0.12,0.94)
    local trim=panel:CreateTexture(nil,"BORDER")
    trim:SetPoint("BOTTOMLEFT");trim:SetPoint("BOTTOMRIGHT")
    trim:SetHeight(1);trim:SetColorTexture(0.62,0.49,0.27,0.95)
    header=CreateFrame("Button",nil,panel)
    header:SetPoint("TOPLEFT",panel,"TOPLEFT",0,0)
    header:SetHeight(24)
    local bg=header:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints()
    bg:SetColorTexture(0.18,0.21,0.26,1)
    -- Decorative matching HaploBar gold top rule. No frame/drag/currency
    -- geometry is changed; this texture cannot capture mouse clicks.
    local goldTop=header:CreateTexture(nil,"OVERLAY")
    goldTop:SetPoint("TOPLEFT",header,"TOPLEFT",0,0)
    goldTop:SetPoint("TOPRIGHT",header,"TOPRIGHT",0,0)
    goldTop:SetHeight(2)
    goldTop:SetColorTexture(0.65,0.49,0.23,1)
    -- TB19.1: reuse the EXISTING 24px drag header for party totals.
    -- Ordinary fontstrings/textures never intercept the drag handle's mouse.
    header.label=font(header,"")
    header.label:SetPoint("LEFT",header,"LEFT",6,0)
    summaryGold=font(header,"?")
    summaryGold:SetTextColor(1,0.89,0.67,1)
    summaryGold:SetJustifyH("LEFT") -- shown only when team data is unknown
    summaryGold:SetJustifyV("MIDDLE")
    summaryGold:SetWordWrap(false)
    summaryGold:SetSize(90,21)
    summaryGold:SetShadowOffset(1,-1)
    if STANDARD_TEXT_FONT then summaryGold:SetFont(STANDARD_TEXT_FONT,13,"OUTLINE") end
    summaryCurrencyCells=HB.CreateCurrencyCells(header,summaryGold)
    -- Team totals: larger display than the individual character headers.
    for _,n in ipairs({"g","s","c"}) do
        local f=summaryCurrencyCells[n]
        if f and STANDARD_TEXT_FONT then f:SetFont(STANDARD_TEXT_FONT,13,"OUTLINE") end
    end
    for _,n in ipairs({"gIcon","sIcon","cIcon"}) do
        local tex=summaryCurrencyCells[n]
        if tex then tex:SetSize(12,12) end
    end
    summaryBags=font(header,"?")
    summaryBags:SetTextColor(0.80,0.87,0.92,1)
    summaryBags:SetJustifyH("RIGHT")
    summaryBags:SetJustifyV("MIDDLE")
    summaryBags:SetSize(48,21)
    summaryBags:SetShadowOffset(1,-1)
    if STANDARD_TEXT_FONT then summaryBags:SetFont(STANDARD_TEXT_FONT,13,"OUTLINE") end
    summaryBagIcon=header:CreateTexture(nil,"OVERLAY")
    summaryBagIcon:SetTexture(media.."bag-jcdr.tga")
    summaryBagIcon:SetSize(18,18)
    gear=CreateFrame("Button",nil,panel)
    gear:RegisterForClicks("LeftButtonUp")
    gear:SetSize(26,24)
    gear:SetFrameLevel(panel:GetFrameLevel()+25)
    gear:EnableMouse(true)
    gear:SetPoint("TOPRIGHT",panel,"TOPRIGHT",0,0)
    gear.icon=gear:CreateTexture(nil,"ARTWORK")
    gear.icon:SetTexture(media.."ui-settings.tga")
    gear.icon:SetSize(17,17)
    gear.icon:SetPoint("CENTER")
    gear:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
    gear:SetScript("OnClick",function()
        if HB.ToggleQuickSettings then HB.ToggleQuickSettings() end
    end)
    gear:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Quick Settings",1,0.82,0.43)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave",function() GameTooltip:Hide() end)
    quickBadges={}
    for i,info in ipairs(quickArt) do
        local badge=CreateFrame("Frame",nil,panel)
        badge:EnableMouse(true)
        badge:SetSize(21,18)
        badge.bg=badge:CreateTexture(nil,"BACKGROUND")
        badge.bg:SetAllPoints()
        badge.icon=badge:CreateTexture(nil,"ARTWORK")
        badge.icon:SetTexture(info[1])
        badge.icon:SetPoint("CENTER")
        badge.icon:SetSize(15,15)
        badge.tooltip=info[2]
        badge:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltip,1,0.82,0.43)
            GameTooltip:Show()
        end)
        badge:SetScript("OnLeave",function()GameTooltip:Hide() end)
        badge:Hide() -- TB19 statuses are now legible text in the top HaploBar
        quickBadges[i]=badge
    end
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() HB.BeginControlMove() end)
    header:SetScript("OnDragStop",function() HB.EndControlMove() end)
    -- Title is a drag handle; only the gear toggles the quick menu.
    header:SetScript("OnClick",function() end)
    -- Fixed-height anchor. Opening the controls shows a separate adjacent panel
    -- to the right of ALL party columns, not over healthbars or beneath them.
    flyout=CreateFrame("Frame","HaploBoxControlsFlyout",UIParent)
    flyout:SetClampedToScreen(true)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetFrameLevel(panel:GetFrameLevel()+2)
    flyout.back=flyout:CreateTexture(nil,"BACKGROUND")
    flyout.back:SetAllPoints();flyout.back:SetColorTexture(0.08,0.09,0.12,0.96)
    flyout:Hide()
    mkButton(1,"DIRECT",function() HB.SetFollowMode("direct") end)
    mkButton(2,"DUNGEON",function() HB.SetFollowMode("dungeon") end)
    mkButton(3,"HEALER",function() HB.AssignMyHealer() end)
    mkButton(4,"QUEST OFF",function() HB.ToggleQuest() end)
    mkButton(5,"LOOT",function()
        -- Manual choice applies the observed loot method, not a fictitious
        -- green status. Auto loot is turned off to avoid immediately reverting.
        local method=HB.LootMethodName and HB.LootMethodName()
        if not (IsInGroup and IsInGroup()) or not HB.IAmLeader() then
            HB.print("Only the party leader can change loot in a group.") return
        end
        local nextMode=(method=="freeforall") and "group" or "freeforall"
        local setter=(C_PartyInfo and C_PartyInfo.SetLootMethod) or SetLootMethod
        if not setter then HB.print("Loot method API unavailable.") return end
        local ok,err=pcall(setter,nextMode)
        if ok and err~=false then HB.db.autoFFA=false
        else HB.print("Loot mode change failed: "..tostring(err)) end
        HB.RefreshControls()
    end)
    mkButton(6,"TRADE OFF",function() HB.ToggleTrade() end)
    mkButton(7,"INVITE PARTY",function() HB.InviteTeam() end)
    mkButton(8,"LEAVE PARTY",function() HB.LeaveTeam() end)
    mkButton(9,"OPTIONS",function()
        if HaploBoxA4 and HaploBoxA4.OpenOptions then HaploBoxA4.OpenOptions()
        elseif HB.OpenOptions then HB.OpenOptions() end
    end)
    mkButton(10,"AUTO REPAIR",function()
        local a4=HaploBoxA4
        if not (a4 and a4.db and a4.db.inventory) then return end
        a4.db.inventory.autoRepair=not a4.db.inventory.autoRepair
        a4.Print("Auto Repair: "..(a4.db.inventory.autoRepair and "ON" or "OFF"))
        HB.RefreshControls()
    end)
    mkButton(11,"SELL LOCKED",function() HB.print("Auto Sell remains LOCKED until junk unmark safety is verified in-game.") end)
    mkButton(12,"FRAME LOCK",function()
        if HB.SetTeamFrameLocked then HB.SetTeamFrameLocked(not HB.db.teamLocked) end
        HB.RefreshControls()
    end)
    mkButton(13,"FOLLOWER HEAL UI",function()
        if HB.SetMiniHealMode then HB.SetMiniHealMode(true) end
    end)
    mkButton(14,"LOOT AUTO",function()
        HB.db.autoFFA=true
        if HB.CheckAutoLoot then HB.CheckAutoLoot() end
        HB.RefreshControls()
    end)
    -- TB16 single Buff / Debuff Overview section; each has its own
    -- enable checkbox and independent unlock/lock position handle.
    mkButton(15,"[x] BUFF OVERVIEW",function()
        if HB.SetOverviewEnabled then
            local ok=HB.SetOverviewEnabled("buff",HB.db.buffOverviewEnabled==false)
            if not ok then HB.print("Change Buff Overview after combat.") end
        end
    end)
    mkButton(16,"UNLOCK BUFF",function()
        if HB.SetBuffOverviewUnlocked then
            local ok=HB.SetBuffOverviewUnlocked(not HB.db.buffOverviewUnlocked)
            if not ok then HB.print("Unlock Buff Overview after combat.") end
        end
        HB.RefreshControls()
    end)
    mkButton(17,"[ ] DEBUFF OVERVIEW",function()
        if HB.SetOverviewEnabled then
            local ok=HB.SetOverviewEnabled("debuff",not HB.db.debuffOverviewEnabled)
            if not ok then HB.print("Change Debuff Overview after combat.") end
        end
    end)
    mkButton(18,"UNLOCK DEBUFF",function()
        if HB.SetDebuffOverviewUnlocked then
            local ok=HB.SetDebuffOverviewUnlocked(not HB.db.debuffOverviewUnlocked)
            if not ok then HB.print("Unlock Debuff Overview after combat.") end
        end
        HB.RefreshControls()
    end)
    applyPosition()
    HB.UpdateControlSize(parent)
    HB.RefreshControls()
end
function HB.UpdateControlSize(parent)
    if not (panel and HB.db) then return end
    if InCombatLockdown and InCombatLockdown() then deferred=true return end
    local w=tonumber(HB.db.teamW) or 250
    if not safe(w) then w=250 end
    w=clamp(w,150,500)
    local s=tonumber(HB.db.partyScale) or 1
    if not safe(s) then s=1 end
    s=clamp(s,0.5,2)
    panel:SetScale(s)
    -- TB19.1d: team totals start at the LEFT of the existing party header.
    -- Keep a readable drag area between the summary and the rightmost gear;
    -- only at extremely narrow party widths can the header grow independently.
    -- The five secure party frames and their individual resources do not move.
    local parentW=(parent and parent:GetWidth()) or (w+75)
    if not safe(parentW) or parentW<1 then parentW=w+75 end
    -- 13pt money captions need their OWN wider denomination columns. A min
    -- 320pt header keeps all three values + icons clear of the right-hand
    -- Quick Settings gear, with a draggable gap between. Typical widths
    -- (including the user's screenshot) are unchanged.
    local headerW=math.max(w+55,parentW,320)
    panel:SetSize(headerW,24) -- slightly taller, fixed across menu toggles
    header:SetWidth(headerW)
    header.label:SetWidth(math.max(65,headerW-132))
    if HB.RefreshResourceSummary then HB.RefreshResourceSummary() end
    for i,b in ipairs(quickBadges or {}) do
        b:ClearAllPoints()
        b:SetPoint("RIGHT",panel,"RIGHT",-(24+(5-i)*23),0)
    end
    -- Wider flyout only: Controls anchor, height and party position unchanged.
    local menuW=math.max(390,math.min(440,headerW))
    local bw=math.floor((menuW-14)/2)
    -- Reuse every existing action, but group them by purpose.
    local sections={
        {"Follow Mode",{1,2}},
        {"Roles",{3,13}},
        {"Party Control",{5,7,8,4}},
        {"Other Controls",{6,9,10,11,12,14}},
        {"Buff / Debuff Overview",{15,16,17,18}},
    }
    if not headline then
        headline=font(flyout,"Quick Menu")
        headline:SetTextColor(1,0.82,0.44)
        headline:SetPoint("TOPLEFT",flyout,"TOPLEFT",8,-8)
    end
    if not menuSectionLabels then
        menuSectionLabels={}
        for index=1,#sections do
            local label=font(flyout,"")
            label:SetTextColor(0.71,0.77,0.82)
            local rule=flyout:CreateTexture(nil,"BORDER")
            rule:SetColorTexture(0.39,0.42,0.48,0.9)
            menuSectionLabels[index]={label=label,rule=rule}
        end
    end
    local y=31
    for index,section in ipairs(sections) do
        local ui=menuSectionLabels[index]
        ui.label:SetText(section[1])
        ui.label:ClearAllPoints()
        ui.label:SetPoint("TOPLEFT",flyout,"TOPLEFT",8,-y)
        ui.rule:ClearAllPoints()
        ui.rule:SetPoint("TOPLEFT",flyout,"TOPLEFT",8,-y-14)
        ui.rule:SetSize(menuW-16,1)
        y=y+20
        for j,buttonIndex in ipairs(section[2]) do
            local b=buttons[buttonIndex]
            local col,row=(j-1)%2,math.floor((j-1)/2)
            b:SetSize(bw,23);b:ClearAllPoints()
            b:SetPoint("TOPLEFT",flyout,"TOPLEFT",5+col*(bw+4),-y-row*25)
            b.label:ClearAllPoints()
            if b.glyph then
                b.label:SetPoint("LEFT",b,"LEFT",30,0)
                b.label:SetPoint("RIGHT",b,"RIGHT",-2,0)
                b.label:SetJustifyH("LEFT")
                b.label:SetWidth(bw-33)
            else
                b.label:SetPoint("CENTER")
                b.label:SetJustifyH("CENTER")
                b.label:SetWidth(bw-6)
            end
        end
        y=y+math.ceil(#section[2]/2)*25+8
    end
    flyout:SetSize(menuW,y+5)
    HB.PositionQuickSettings()
end
function HB.RefreshControls()
    if not (panel and HB.db) then return end
    HB.UpdateControlSize(nativeParent)
    local inGroup=IsInGroup and IsInGroup()
    local mode=HB.db.followMode
    color(buttons[1],mode=="direct" and GREEN or OFF)
    color(buttons[2],mode=="dungeon" and GREEN or OFF)
    color(buttons[3],HB.MyRole and HB.MyRole()=="healer" and GREEN or OFF)
    local q=HB.db.questEnabled
    buttons[4].label:SetText(q and "QUEST ON" or "QUEST OFF")
    color(buttons[4],q and GREEN or OFF)
    local loot=HB.LootMethodName and HB.LootMethodName()
    buttons[5].label:SetText("LOOT: "..(loot=="freeforall" and "FFA" or loot=="group" and "GROUP" or "?"))
    color(buttons[5],loot=="freeforall" and GREEN or loot=="group" and GOLD or OFF)
    buttons[6].label:SetText(HB.db.tradeEnabled and "TRADE ON" or "TRADE OFF")
    color(buttons[6],HB.db.tradeEnabled and GREEN or OFF)
    color(buttons[7],OFF);color(buttons[8],RED);color(buttons[9],OFF)
    color(buttons[10],(HaploBoxA4 and HaploBoxA4.db and HaploBoxA4.db.inventory and HaploBoxA4.db.inventory.autoRepair) and GREEN or OFF)
    color(buttons[11],RED)
    buttons[12].label:SetText(HB.db.teamLocked and "FRAME UNLOCK" or "FRAME LOCK")
    color(buttons[12],HB.db.teamLocked and GOLD or OFF)
    buttons[8]:SetEnabled(not not inGroup)
    buttons[14].label:SetText(HB.db.autoFFA and "LOOT AUTO ON" or "LOOT AUTO OFF")
    color(buttons[14],HB.db.autoFFA and GREEN or OFF)
    buttons[15].label:SetText((HB.db.buffOverviewEnabled~=false and "[x] " or "[ ] ").."BUFF OVERVIEW")
    color(buttons[15],HB.db.buffOverviewEnabled~=false and GREEN or OFF)
    buttons[16].label:SetText(HB.db.buffOverviewUnlocked and "LOCK BUFF FRAME" or "UNLOCK BUFF FRAME")
    color(buttons[16],HB.db.buffOverviewUnlocked and GOLD or OFF)
    buttons[17].label:SetText((HB.db.debuffOverviewEnabled and "[x] " or "[ ] ").."DEBUFF OVERVIEW")
    color(buttons[17],HB.db.debuffOverviewEnabled and GREEN or OFF)
    buttons[18].label:SetText(HB.db.debuffOverviewUnlocked and "LOCK DEBUFF FRAME" or "UNLOCK DEBUFF FRAME")
    color(buttons[18],HB.db.debuffOverviewUnlocked and GOLD or OFF)
    -- Only actual, currently observed choices may produce a green quick status.
    local info={
        {(mode=="direct" or mode=="dungeon") and GREEN or OFF,
           "Follow mode selected: "..(mode=="direct" and "Direct / Leader" or mode=="dungeon" and "Dungeon / Healer" or "Unknown")},
        {loot=="freeforall" and GREEN or loot=="group" and GOLD or OFF,
           "Loot method: "..(loot=="freeforall" and "FFA" or loot=="group" and "Group" or "Unknown")},
        {(HaploBoxA4 and HaploBoxA4.db and HaploBoxA4.db.inventory and HaploBoxA4.db.inventory.autoRepair) and GREEN or OFF,
           "Auto Repair: "..((HaploBoxA4 and HaploBoxA4.db and HaploBoxA4.db.inventory and HaploBoxA4.db.inventory.autoRepair) and "ON" or "OFF")},
        {q and GREEN or OFF,"Quest sharing: "..(q and "ON" or "OFF")},
    }
    for i,b in ipairs(quickBadges or {}) do
        b.bg:SetColorTexture(unpack(info[i][1]))
        b.tooltip=info[i][2]
        b.icon:SetVertexColor(1,1,1)
    end
    panel:SetShown(not HB.db.miniHealMode)
    -- Always honor the click, even in combat when layout resizing is deferred.
    -- Flyout is a normal, non-secure settings frame parented to UIParent.
    HB.PositionQuickSettings()
    flyout:SetShown(not not HB.db.controlsOpen)
    gear.icon:SetVertexColor(HB.db.controlsOpen and 0.4 or 0.9,
        HB.db.controlsOpen and 0.95 or 0.9,0.48)
    if HB.RefreshHaploBar then HB.RefreshHaploBar() end
end
function HB.MainBarStatusDiagnostics()
    if not HB.db then return end
    local a4=HaploBoxA4
    local repair=a4 and a4.db and a4.db.inventory and a4.db.inventory.autoRepair
    local actual=HB.LootMethodName and HB.LootMethodName()
    HB.print("Main bar statuses (local) | followMode="..tostring(HB.db.followMode)
        .." | actualLoot="..tostring(actual).." | autoFFA="..tostring(HB.db.autoFFA)
        .." | autoRepair="..tostring(repair).." | quest="..tostring(HB.db.questEnabled)
        .." | party="..tostring(IsInGroup and IsInGroup()))
end
-- Party team totals read the existing five-client data, shown LEFT-to-RIGHT
-- in the header as Bags, Gold, Silver, Copper. Individual character resource geometry is
-- untouched; all data values still require a current sample from each toon.
local function resourceValid(n)
    return type(n)=="number" and safe(n) and n>=0 and n==n
end
local function totalMoney(c)
    if not resourceValid(c) then return "?" end
    local g,s,cc=math.floor(c/10000),math.floor(c%10000/100),math.floor(c%100)
    local gi="|TInterface\\MoneyFrame\\UI-GoldIcon:11:11:0:0|t"
    local si="|TInterface\\MoneyFrame\\UI-SilverIcon:11:11:0:0|t"
    local ci="|TInterface\\MoneyFrame\\UI-CopperIcon:11:11:0:0|t"
    if g>0 then return g..gi.." "..s..si.." "..cc..ci end
    if s>0 then return s..si.." "..cc..ci end
    return cc..ci
end
local function bagColor(free,capacity)
    if not (resourceValid(free) and resourceValid(capacity) and capacity>0) then
        return 0.70,0.73,0.78 -- unknown, not a false green success
    end
    local pct=free/capacity
    if pct>0.5 then return 0.22,0.86,0.39 end
    if pct>=0.2 then return 1,0.76,0.21 end
    return 1,0.31,0.29
end
function HB.ResourceBagColor(free,capacity) return bagColor(free,capacity) end
function HB.RefreshResourceSummary()
    if not (panel and header and HB.db and summaryGold and summaryBags) then return end
    local src=_G.HaploBoxA4
    local dataset=src and src.data
    local now=time and time() or 0
    local money,free,capacity,count=0,0,0,0
    local fresh=true
    local first
    for i=1,5 do
        local r=_G["HaploBoxPartyRow"..i]
        if r and r.IsShown and r:IsShown() then
            if not first then first=r end
            count=count+1
            local n=r.name and src and src.Norm and src.Norm(r.name)
            local d=n and dataset and dataset[n]
            if not (d and resourceValid(d.gold) and resourceValid(d.bags) and
                resourceValid(d.bagCapacity) and d.bagCapacity>0 and
                resourceValid(d.at) and now-d.at<=55 and d.at<=now+5) then
                fresh=false
            else
                money=money+d.gold
                free=free+d.bags
                capacity=capacity+d.bagCapacity
            end
        end
    end
    local complete=count>=1 and fresh
    summaryGold:SetText(complete and "" or "?")
    HB.SetCurrencyCells(summaryCurrencyCells,complete and money or nil,
        HB.currencySpanWidth or HB.CURRENCY_MIN_SPAN)
    if not complete then
        summaryBags:SetText("?")
        summaryBagIcon:SetVertexColor(0.70,0.73,0.78)
    else
        summaryBags:SetText(tostring(free))
        summaryBagIcon:SetVertexColor(bagColor(free,capacity))
    end
    summaryGold:Show();summaryBags:Show();summaryBagIcon:Show()
    -- TB19.1g: money columns are content-sized, not padded with a large
    -- 74-point Gold minimum. 13pt numbers sit directly beside their coin
    -- textures with small consistent gaps, even when Gold has only 2 digits.
    -- Silver/Copper are at most 99; their stable fields fit two wide digits.
    -- Gold keeps automatic expansion for arbitrarily many digits. Only the
    -- NON-SECURE team totals change; Party.lua/individual rows are untouched.
    summaryBags:SetSize(48,21) -- reserved space for 000..999 at 13pt and UI scaling
    summaryBagIcon:ClearAllPoints()
    summaryBagIcon:SetPoint("LEFT",header,"LEFT",8,0)
    summaryBags:ClearAllPoints()
    summaryBags:SetPoint("LEFT",summaryBagIcon,"RIGHT",3,0)
    summaryGold:ClearAllPoints()
    summaryGold:SetPoint("LEFT",summaryBags,"RIGHT",12,0)

    local cash=summaryCurrencyCells
    local goldText=complete and tostring(math.floor(money/10000)) or "0"
    local gDigits=#goldText
    -- Widths are in the same UI points as the text frame's actual rendered
    -- font, not guessed character counts. Temporarily give the label plenty
    -- of width so Blizzard cannot measure a truncated "..." string.
    local function measureText(label,value,fallback)
        if not (label and label.SetText and label.SetWidth) then return fallback end
        local previous=label.GetText and label:GetText() or ""
        -- Avoid measuring clipped fallback text on versions that only have
        -- GetStringWidth(): use a temporary width that scales with digits.
        label:SetWidth(math.max(240,#tostring(value)*20))
        label:SetText(value)
        local method=label.GetUnboundedStringWidth or label.GetStringWidth
        local ok,measured=false,nil
        if method then ok,measured=pcall(method,label) end
        label:SetText(previous)
        if ok and type(measured)=="number" and safe(measured) and
            measured>0 and measured<10000 then return measured end
        return fallback
    end
    -- Sample the widest two-digit patterns at the real 13pt font. Keep 3pt
    -- for OUTLINE/shadow; no artificial 24pt+ field minimum or broad 8pt gaps.
    local twoDigitW=math.max(
        measureText(cash and cash.s,"88",20),
        measureText(cash and cash.s,"99",20),
        measureText(cash and cash.s,"00",20))
    local fractionW=math.max(18,math.ceil(twoDigitW+3))
    -- A value like '17' only occupies the measured width of '17'. This also
    -- ensures 5/7/10+ digit gold always extends the same row without cropping.
    local goldW=math.max(12,math.ceil(measureText(
        cash and cash.g,goldText,math.max(10,gDigits*10))+4))
    local coinW=12
    local iconGap=2       -- number -> its native gold/silver/copper icon
    local denominationGap=3 -- coin icon -> next denomination's number
    if cash then
        -- SetCurrencyCells() was called above: override its small-row widths
        -- and positions here. Every refresh keeps the right order and spacing.
        cash.g:SetWidth(goldW)
        cash.s:SetWidth(fractionW)
        cash.c:SetWidth(fractionW)
        local function fromLeft(widget,relative,space)
            widget:ClearAllPoints()
            widget:SetPoint("LEFT",relative,"RIGHT",space,0)
        end
        cash.g:ClearAllPoints()
        cash.g:SetPoint("LEFT",summaryGold,"LEFT",0,0)
        fromLeft(cash.gIcon,cash.g,iconGap)
        fromLeft(cash.s,cash.gIcon,denominationGap)
        fromLeft(cash.sIcon,cash.s,iconGap)
        fromLeft(cash.c,cash.sIcon,denominationGap)
        fromLeft(cash.cIcon,cash.c,iconGap)
    end
    local cashW=goldW+fractionW*2+coinW*3+iconGap*3+denominationGap*2
    summaryGold:SetWidth(cashW) -- unknown "?" starts immediately after Bags
    -- On exceptionally small/custom panel widths, leave the gear and at
    -- least 24pt of draggable header free; only the header is widened.
    local needW=8+18+3+48+12+cashW+24+26+5
    if panel:GetWidth()<needW then
        if InCombatLockdown and InCombatLockdown() then
            deferred=true -- resize the ordinary header safely after combat
        else
            panel:SetWidth(needW)
            header:SetWidth(needW)
        end
    end

end
function HB.ResetControlPosition()
    if InCombatLockdown and InCombatLockdown() then HB.print("Move controls after combat.") return end
    if not HB.db then return end
    HB.db.controlsPos=nil
    HB.db.controlsFrac=nil
    HB.db.partyPos=nil
    HB.ApplyControlPosition()
    HB.print("Controls and party frames reset together.")
end
local ev=CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent",function()
    if deferred then deferred=false HB.UpdateControlSize(nativeParent) HB.RefreshControls() end
end)
