-- Alpha 5 TB14: integrated Quick Menu layout, gear click-layer fix and JCDRbox icon art.
-- Alpha 5 TB6: persistent, fixed-height Controls anchor.
-- Expanding the menu NEVER changes the secure partyframe anchor position.
-- The popup is a sibling in screen layout, not part of the anchor's height.
local HB=HaploBox
local panel,header,flyout
local nativeParent,buttons=nil,{}
local gear,headline,quickBadges,menuSectionLabels,quickHeader,quickLockButton,quickRows
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
local controlsReady=false -- HF16: a partial menu build must never refresh
local activeSubmenu=nil
local GREEN={0.15,0.42,0.26,0.98}
local OFF={0.20,0.23,0.28,0.98}
local RED={0.56,0.17,0.17,0.98}
local GOLD={0.43,0.34,0.15,0.98}
local BLUE={0.14,0.30,0.48,0.97}
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
            -- HF12 PFR-07: default header flush to screen top. Respect a
            -- Blizzard party/raid snapper when it is visible without touching it.
            local x=44 -- safe fallback reserved for the narrow Blizzard tab
            local snap=_G.CompactRaidFrameManagerToggleButton
            if snap and snap.IsShown and snap:IsShown() and snap.GetRight then
                local ok,right=pcall(snap.GetRight,snap)
                local us=UIParent:GetEffectiveScale() or 1
                local fs=snap.GetEffectiveScale and snap:GetEffectiveScale() or us
                if ok and type(right)=="number" and safe(right) and
                    type(us)=="number" and us>0 and type(fs)=="number" then
                    x=math.max(x,math.min(100,right*fs/us-(UIParent:GetLeft() or 0)+8))
                end
            end
            panel:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,0)
        end
    end
end
-- TB19.1q: all popups form a chain beside the Party Frame.
-- Measure real client geometry every time a menu opens. Do not persist dragged
-- locations; the next opening returns to the docked default. The native
-- Blizzard minimap is the right boundary, and Party Frames bound the bottom.
local function rect(frame)
    if not frame or not frame.GetLeft or (frame.IsShown and not frame:IsShown()) then return nil end
    local l,r,t,b=frame:GetLeft(),frame:GetRight(),frame:GetTop(),frame:GetBottom()
    if not (l and r and t and b and safe(l) and safe(r) and safe(t) and safe(b)) then return nil end
    local fs=frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local us=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local factor=fs/(us>0 and us or 1)
    return {l=l*factor,r=r*factor,t=t*factor,b=b*factor}
end
local function popupBounds()
    local control=HB.GetControlAnchor and HB.GetControlAnchor()
    local party=_G.HaploBoxPartyFrame
    local mini=_G.MinimapCluster or _G.Minimap
    local ctrl,pr,mp=rect(control),rect(party),rect(mini)
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    local left=math.max((ctrl and ctrl.r) or 0,(pr and pr.r) or 0,7)+7
    -- HF24: Mael moved his minimap to the lower-left.  It must NOT be
    -- treated as a permanent right boundary (that reduced the whole menu
    -- to ~35-40% size).  Only reserve space for a map genuinely on the
    -- RIGHT of the menu, near its top.
    local right=sw-10
    if mp and mp.l>left+405 and mp.t>(sh*0.68) then
        right=math.min(right,mp.l-9)
    end
    local top=(ctrl and ctrl.t) or (sh-12)
    local bottom=(pr and pr.b) or (sh*0.27)
    return {left=left,right=right,top=top,bottom=bottom,ctrl=control,party=party}
end
function HB.GetPopupBounds() return popupBounds() end
local function fitHeight(frame,bounds)
    local available=math.max(60,bounds.top-bounds.bottom-4)
    return math.min(1,available/math.max(frame:GetHeight(),1))
end
local function saveQuickPos()
    if not (flyout and HB.db) then return end
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    local r=rect(flyout)
    if r and sw and sh and sw>0 and sh>0 then
        HB.db.quickMenuPos={clamp(r.l/sw,0,0.97),clamp((sh-r.t)/sh,0,0.97)}
    end
end
local function saveSubmenuPos(frame)
    if not (frame and HB.db and frame.hbMenuName) then return end
    local r=rect(frame)
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    if r and sw and sh and sw>0 and sh>0 then
        HB.db.submenuPositions=HB.db.submenuPositions or {}
        HB.db.submenuPositions[frame.hbMenuName]={clamp(r.l/sw,0,0.97),clamp((sh-r.t)/sh,0,0.97)}
    end
end
function HB.SetQuickMenuLocked(locked)
    if not HB.db then return end
    if InCombatLockdown and InCombatLockdown() then HB.print("Change menu lock after combat.") return end
    HB.db.quickMenuLocked=not not locked
    if locked then saveQuickPos() end
    if quickLockButton then
        if HB.MenuStyle then HB.MenuStyle.LockButton(quickLockButton,locked)
        else quickLockButton:SetText(locked and "L" or "U") end
    end
end
function HB.PositionQuickSettings(force)
    if not (flyout and HB.db) then return end
    if flyout:IsShown() and not force then return end
    local bounds=popupBounds()
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    if not (sw and sh and safe(sw) and safe(sh) and sw>0 and sh>0) then return end
    local w,h=flyout:GetWidth(),flyout:GetHeight()
    if not (w and h and w>0 and h>0) then return end
    -- HF24: fit to the actual game viewport, NOT the minimap or the party
    -- frame's bottom edge.  The compressed native-size rows fit even a
    -- 960x360 multibox viewport without unreadable micro-scaling.
    local scale=math.min(1,(sw-16)/w,(sh-12)/h)
    flyout:SetScale(clamp(scale,0.72,1))
    local actualW,actualH=w*flyout:GetScale(),h*flyout:GetScale()
    local function overlapsParty(x,top)
        local pr=rect(bounds.party)
        return pr and x<(pr.r+4) and x+actualW>(pr.l-4)
            and (sh-top)>(pr.b-4) and (sh-top-actualH)<(pr.t+4)
    end
    local function onScreen(x,top)
        return x>=4 and top>=4 and x+actualW<=sw-4 and top+actualH<=sh-4
    end
    flyout:ClearAllPoints()
    local saved=HB.db.quickMenuPos
    if type(saved)=="table" and type(saved[1])=="number" and type(saved[2])=="number" and
        safe(saved[1]) and safe(saved[2]) then
        local x,top=saved[1]*sw,saved[2]*sh
        if onScreen(x,top) and not overlapsParty(x,top) then
            -- Ignore positions that would cover interactive party HP bars.
            flyout:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,-top)
            return
        end
        -- HF24: ignore stale, overlapping saved positions; do not erase the
        -- rest of the character's saved layout.
    end
    local x,top
    if HB.db.miniHealMode then
        -- The Mini UI's gathering map lives on the LEFT. Place its menu on
        -- the right, accessible via the existing Quick Menu keybind or /hb controls.
        x=sw-actualW-8
        top=8
    else
        x=math.max(8,bounds.left)
        if x+actualW>sw-8 then x=sw-actualW-8 end
        top=math.max(8,sh-bounds.top)
    end
    x=clamp(x,8,math.max(8,sw-actualW-8))
    top=clamp(top,8,math.max(8,sh-actualH-8))
    flyout:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,-top)
end
function HB.PositionDockedSubmenu(frame,force)
    if not frame or (frame:IsShown() and not force) then return end
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    local fw,fh=frame:GetWidth(),frame:GetHeight()
    if not (sw and sh and fw and fh and sw>0 and sh>0 and fw>0 and fh>0) then return end
    local scale=clamp(math.min(1,(sw-16)/fw,(sh-16)/fh),0.72,1)
    frame:SetScale(scale)
    local aw,ah=fw*scale,fh*scale
    local positions=HB.db and HB.db.submenuPositions
    local saved=positions and positions[frame.hbMenuName or ""]
    local x,top
    if type(saved)=="table" and type(saved[1])=="number" and type(saved[2])=="number" and
        safe(saved[1]) and safe(saved[2]) then
        local sx,sy=saved[1]*sw,saved[2]*sh
        if sx>=4 and sy>=4 and sx+aw<=sw-4 and sy+ah<=sh-4 then x,top=sx,sy end
    end
    if not x then
        local q=rect(flyout)
        if q and q.r+7+aw<=sw-8 then
            x,top=q.r+7,sh-q.t
        elseif q and q.l-aw-7>=8 then
            x,top=q.l-aw-7,sh-q.t
        else
            -- In narrow multibox windows the submenu can temporarily cover
            -- the Quick Menu, instead of becoming microscopic.
            x,top=sw-aw-8,8
        end
    end
    x=clamp(x,8,math.max(8,sw-aw-8))
    top=clamp(top,8,math.max(8,sh-ah-8))
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,-top)
end
function HB.PositionMacroMenu(force)
    HB.PositionDockedSubmenu(_G.HaploBoxMacroLibrary,force)
end
function HB.PrepareQuickSubmenu(frame)
    if not frame then return end
    if activeSubmenu and activeSubmenu~=frame and activeSubmenu:IsShown() then activeSubmenu:Hide() end
    activeSubmenu=frame
end
function HB.HideQuickSubmenus()
    if activeSubmenu then activeSubmenu:Hide() end
    activeSubmenu=nil
end
function HB.OpenQuickSubmenu(frame)
    if not frame then return end
    if frame:IsShown() then frame:Hide();activeSubmenu=nil;return end
    HB.PrepareQuickSubmenu(frame)
    if not (flyout and flyout:IsShown()) then
        HB.db.controlsOpen=true
        flyout:Show()
    end
    frame:Show()
    HB.PositionQuickSettings(true)
    HB.PositionDockedSubmenu(frame,true)
    if HB.RefreshControls then HB.RefreshControls() end
end
function HB.ToggleQuickSettings()
    if not HB.db then return end
    HB.db.controlsOpen=not HB.db.controlsOpen
    if HB.db.controlsOpen then
        HB.HideQuickSubmenus()  -- fresh opening starts without a submenu
        HB.PositionQuickSettings(true)
    else HB.HideQuickSubmenus() end
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
    -- Decorative HaploBox gold top rule. No frame/drag/currency
    -- geometry is changed; this texture cannot capture mouse clicks.
    local goldTop=header:CreateTexture(nil,"OVERLAY")
    goldTop:SetPoint("TOPLEFT",header,"TOPLEFT",0,0)
    goldTop:SetPoint("TOPRIGHT",header,"TOPRIGHT",0,0)
    goldTop:SetHeight(2)
    goldTop:SetColorTexture(0.65,0.49,0.23,1)
    for _,side in ipairs({"LEFT","RIGHT"}) do
        local edge=panel:CreateTexture(nil,"OVERLAY")
        edge:SetColorTexture(0.72,0.54,0.20,0.95)
        if side=="LEFT" then edge:SetPoint("TOPLEFT",panel,"TOPLEFT");edge:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT")
        else edge:SetPoint("TOPRIGHT",panel,"TOPRIGHT");edge:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT") end
        edge:SetWidth(2)
    end
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
    -- Quick Menu is launched from the Party Frame header; technical Options remain accessible separately.
    gear:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Quick Menu",1,0.82,0.43)
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
        badge:Hide() -- Keep existing compact Party Frame header behavior
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
    flyout:SetMovable(true)
    flyout:EnableMouse(true)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetFrameLevel(panel:GetFrameLevel()+2)
    if HB.MenuStyle then HB.MenuStyle.Window(flyout,26) end
    flyout.back=flyout:CreateTexture(nil,"BACKGROUND")
    -- TB19.1r: original neutral HaploBox background, not Blizzard parchment.
    flyout.back:SetAllPoints();flyout.back:SetColorTexture(0.095,0.11,0.14,0.99)
    local trim=flyout:CreateTexture(nil,"OVERLAY")
    trim:SetPoint("TOPLEFT",flyout,"TOPLEFT",4,-26)
    trim:SetPoint("TOPRIGHT",flyout,"TOPRIGHT",-4,-26)
    trim:SetHeight(2);trim:SetColorTexture(0.72,0.54,0.24,0.94)
    quickHeader=CreateFrame("Frame",nil,flyout)
    quickHeader:SetPoint("TOPLEFT",flyout,"TOPLEFT",0,0)
    quickHeader:SetPoint("TOPRIGHT",flyout,"TOPRIGHT",0,0)
    quickHeader:SetHeight(26)
    quickHeader:EnableMouse(true)
    quickHeader:RegisterForDrag("LeftButton")
    quickHeader:SetScript("OnDragStart",function()
        if HB.db and not HB.db.quickMenuLocked and not (InCombatLockdown and InCombatLockdown()) then flyout:StartMoving() end
    end)
    quickHeader:SetScript("OnDragStop",function()
        flyout:StopMovingOrSizing()
        if HB.db and not HB.db.quickMenuLocked then saveQuickPos() end
    end)
    quickLockButton=CreateFrame("Button",nil,quickHeader,"UIPanelButtonTemplate")
    quickLockButton:SetSize(24,20)
    quickLockButton:SetPoint("RIGHT",quickHeader,"RIGHT",-34,0)
    if HB.MenuStyle then HB.MenuStyle.LockButton(quickLockButton,HB.db.quickMenuLocked)
    else quickLockButton:SetText(HB.db.quickMenuLocked and "L" or "U") end
    quickLockButton:SetScript("OnClick",function() HB.SetQuickMenuLocked(not HB.db.quickMenuLocked) end)
    quickLockButton:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(HB.db.quickMenuLocked and "Locked. Click to unlock and drag." or "Unlocked. Click to lock and save position.")
        GameTooltip:Show()
    end)
    quickLockButton:SetScript("OnLeave",function()GameTooltip:Hide()end)
    -- Settings is a TITLE BAR action, not an eleventh menu entry.
    local optionsGear=CreateFrame("Button",nil,quickHeader,"UIPanelButtonTemplate")
    optionsGear:SetSize(24,20)
    optionsGear:SetPoint("RIGHT",quickHeader,"RIGHT",-64,0)
    if HB.MenuStyle then HB.MenuStyle.Button(optionsGear,"blue") end
    local optIcon=optionsGear:CreateTexture(nil,"ARTWORK")
    optIcon:SetTexture(media.."ui-settings.tga")
    optIcon:SetSize(17,17);optIcon:SetPoint("CENTER")
    optionsGear:SetScript("OnClick",function()
        if HB.OpenOptions then HB.OpenOptions() end
    end)
    if HB.MenuStyle then HB.MenuStyle.Tooltip(optionsGear,"HaploBox Options","Opens the separate Options window. Also available with /hb options.") end
    local close=CreateFrame("Button",nil,quickHeader,"UIPanelButtonTemplate")
    close:SetSize(24,20);close:SetPoint("TOPRIGHT",quickHeader,"TOPRIGHT",-6,-3)
    close:SetText("X")
    if HB.MenuStyle then HB.MenuStyle.Button(close,"blue") end
    close:SetScript("OnClick",function()
        HB.db.controlsOpen=false
        flyout:Hide()
        HB.HideQuickSubmenus()
        if HB.RefreshControls then HB.RefreshControls() end
    end)
    flyout:Hide()
    mkButton(19,"BOX OFF",function()
        if HB.SetBoxMode then HB.SetBoxMode(not HB.db.boxMode) end
    end)
    buttons[19].statusLight=buttons[19]:CreateTexture(nil,"OVERLAY")
    buttons[19].statusLight:SetTexture(media.."status-dot.tga")
    buttons[19].statusLight:SetSize(15,15)
    buttons[19].statusLight:SetPoint("LEFT",buttons[19],"LEFT",8,0)
    mkButton(21,"MACRO MENU",function()
        if HB.OpenMacroMenu then HB.OpenMacroMenu() end
    end)
    mkButton(22,"FOLLOW ALERTS",function()
        HB.db.followAlerts=not HB.db.followAlerts
        HB.RefreshControls()
    end)
    mkButton(23,"KEYBINDINGS",function()
        if HB.OpenKeybindingsMenu then HB.OpenKeybindingsMenu() end
    end)
    mkButton(24,"UI LAYOUT",function()
        if HB.OpenUILayout then HB.OpenUILayout() end
    end)
    mkButton(26,"PLAY MODES CONFIG",function()
        if HB.OpenCategoryConfig then HB.OpenCategoryConfig("play") end
    end)
    mkButton(27,"TEAM MANAGEMENT CONFIG",function()
        if HB.OpenCategoryConfig then HB.OpenCategoryConfig("team") end
    end)
    mkButton(33,"TEAM MANAGER",function()
        if HB.OpenTeamManagement then HB.OpenTeamManagement() end
    end)
    mkButton(28,"MENUS CONFIG",function()
        if HB.OpenCategoryConfig then HB.OpenCategoryConfig("menus") end
    end)
    -- HF24: Lyra-only Blizzard gathering minimap inside her own Mini UI.
    mkButton(31,"WEAPON SETS",function()
        if HB.OpenWeaponSetKeybindings then HB.OpenWeaponSetKeybindings() end
    end)
    -- Profession Advisor integrates with the existing Quick Menu. No secure frames changed.
    mkButton(32,"PROFESSION GUIDE",function()
        local PG = HaploBoxProfessionGuide
        if PG and PG.ToggleMain then PG.ToggleMain() end
    end)
    mkButton(30,"HAPLO LOOT",function()
        if HB.ToggleLootPlanner then HB.ToggleLootPlanner() end
    end)
    mkButton(29,"GATHER MAP",function()
        if HB.SetGatheringMapEnabled then
            local on=HB.db and HB.db.gatheringMapEnabled~=false
            if HB.SetGatheringMapEnabled(not on) and HB.RefreshControls then HB.RefreshControls() end
        end
    end)
    mkButton(1,"DIRECT",function() HB.SetFollowMode("direct") end)
    mkButton(2,"DUNGEON",function() HB.SetFollowMode("dungeon") end)
    mkButton(3,"HEALER",function() HB.AssignMyHealer() end)
    mkButton(4,"QUEST OFF",function() HB.ToggleQuest() end)
    mkButton(5,"LOOT AUTO",function()
        HB.db.autoFFA=not HB.db.autoFFA
        if HB.db.autoFFA and HB.CheckAutoLoot then HB.CheckAutoLoot() end
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
    -- Keep legacy handlers defined for old add-on callers, but hide both
    -- role buttons; access is now via native game bindings in Multibox.
    buttons[3]:Hide();buttons[13]:Hide()
    mkButton(14,"LOOT AUTO",function()
        HB.db.autoFFA=true
        if HB.CheckAutoLoot then HB.CheckAutoLoot() end
        HB.RefreshControls()
    end)
    -- Buff Overview retains its existing independent enable and lock controls.
    -- The old floating Debuff Overview has been retired in HF12.
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
    -- 17/18 were the retired floating Debuff Overview toggle/drag controls.
    -- Do not recreate them or expose stale functions through the Quick Menu.
    controlsReady=true -- only after all 28-era section CONFIG buttons exist
    applyPosition()
    HB.UpdateControlSize(parent)
    HB.RefreshControls()
end
function HB.UpdateControlSize(parent)
    if not (panel and HB.db and controlsReady) then return end
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
    -- HF24: ten rows in three compact sections, plus their CONFIG buttons. Config remains a
    -- tiny header action, not an extra list row. Every functional row has
    -- its caption on the left and its action on the right.
    local sections={
        {"PLAY MODES",{{"Box Mode",{19}},{"Follow Mode",{1,2}}},26},
        {"TEAM MANAGEMENT",{{"Active Team",{33}},{"Party",{7,8}},
            {"Loot Mode",{5}},{"Quest Sharing",{4}},{"Auto Repair",{10}}},27},
        {"MENUS",{{"Profession Guide",{32}},{"Macro Menu",{21}},
            {"HaploBox Keybindings",{23}},{"UI Layout",{24}},
            {"Lyra Gathering Map",{29}},{"Haplo Loot",{30}},{"Weapon Sets",{31}}},28},
    }
    if not headline then
        headline=font(flyout,"Quick Menu")
        headline:SetTextColor(1,0.82,0.44)
        headline:SetPoint("TOPLEFT",flyout,"TOPLEFT",10,-8)
    end
    if not menuSectionLabels then
        menuSectionLabels={}
        for index=1,#sections do
            local sectionLabel=font(flyout,"")
            sectionLabel:SetTextColor(0.88,0.78,0.52)
            local rule=flyout:CreateTexture(nil,"BORDER")
            rule:SetColorTexture(0.45,0.43,0.34,0.92)
            menuSectionLabels[index]={label=sectionLabel,rule=rule}
        end
    end
    if not quickRows then
        quickRows={}
        for i=1,13 do
            local bg=flyout:CreateTexture(nil,"BACKGROUND")
            bg:SetColorTexture(0.13,0.16,0.20,(i%2==0) and 0.92 or 0.75)
            local rowLabel=font(flyout,"")
            rowLabel:SetTextColor(0.93,0.92,0.88)
            if STANDARD_TEXT_FONT then rowLabel:SetFont(STANDARD_TEXT_FONT,11,"OUTLINE") end
            quickRows[i]={bg=bg,label=rowLabel}
        end
    end
    local approved={}
    for _,section in ipairs(sections) do
        approved[section[3]]=true
        for _,row in ipairs(section[2]) do
            for _,idx in ipairs(row[2]) do approved[idx]=true end
        end
    end
    for idx,b in pairs(buttons) do
        b:SetShown(approved[idx]==true)
        if b.glyph then b.glyph:Hide() end
        if b.glyph2 then b.glyph2:Hide() end
    end
    -- HF24: compact native-size rows avoid the former 0.35x menu scaling.
    local y,rowN=30,0
    local actionLeft=menuW-170
    local actionWidth=156
    for secN,section in ipairs(sections) do
        local ui=menuSectionLabels[secN]
        ui.label:SetText(section[1]);ui.label:ClearAllPoints()
        ui.label:SetPoint("TOPLEFT",flyout,"TOPLEFT",12,-y)
        ui.rule:ClearAllPoints()
        ui.rule:SetPoint("TOPLEFT",flyout,"TOPLEFT",12,-y-15)
        ui.rule:SetSize(menuW-24,1)
        local cfg=buttons[section[3]]
        -- Defensive: never index a missing CONFIG control if another addon
        -- or a future layout change interrupted menu construction.
        if not (cfg and cfg.label) then return end
        cfg:SetSize(66,18);cfg:ClearAllPoints()
        cfg:SetPoint("TOPRIGHT",flyout,"TOPRIGHT",-12,-y+4)
        cfg.label:ClearAllPoints();cfg.label:SetPoint("CENTER")
        cfg.label:SetWidth(60);cfg.label:SetJustifyH("CENTER")
        cfg.label:SetText("CONFIG")
        color(cfg,BLUE)
        y=y+19
        for _,def in ipairs(section[2]) do
            rowN=rowN+1
            local row=quickRows[rowN]
            row.bg:ClearAllPoints()
            row.bg:SetPoint("TOPLEFT",flyout,"TOPLEFT",7,-y)
            row.bg:SetSize(menuW-14,21)
            row.label:SetText(def[1]);row.label:ClearAllPoints()
            row.label:SetPoint("LEFT",flyout,"TOPLEFT",16,-y-10)
            row.label:SetWidth(actionLeft-25)
            for n,idx in ipairs(def[2]) do
                local b=buttons[idx]
                local half=(#def[2]==2)
                local width=half and 75 or actionWidth
                local x=actionLeft+(n-1)*80
                b:SetSize(width,19);b:ClearAllPoints()
                b:SetPoint("TOPLEFT",flyout,"TOPLEFT",x,-y-1)
                b.label:ClearAllPoints();b.label:SetPoint("CENTER")
                b.label:SetWidth(width-8);b.label:SetJustifyH("CENTER")
            end
            y=y+23
        end
        y=y+3
    end
    flyout:SetSize(menuW,y+3)
    HB.PositionQuickSettings(false)
end
function HB.RefreshControls()
    if not (panel and HB.db and controlsReady) then return end
    HB.UpdateControlSize(nativeParent)
    local inGroup=IsInGroup and IsInGroup()
    local mode=HB.db.followMode
    buttons[19].label:SetText(HB.db.boxMode and "BOX ON" or "BOX OFF")
    color(buttons[19],OFF)
    local lamp=HB.boxSyncError and {1,0.66,0.09} or
        (HB.db.boxMode and {0.21,0.95,0.40} or {1,0.22,0.20})
    if buttons[19].statusLight then buttons[19].statusLight:SetVertexColor(unpack(lamp)) end
    color(buttons[21],OFF)
    if buttons[30] then color(buttons[30],OFF) end
    if buttons[31] then color(buttons[31],OFF) end
    if buttons[32] then color(buttons[32],OFF) end
    color(buttons[1],mode=="direct" and GREEN or OFF)
    color(buttons[2],mode=="dungeon" and GREEN or OFF)
    color(buttons[3],HB.MyRole and HB.MyRole()=="healer" and GREEN or OFF)
    local q=HB.db.questEnabled
    buttons[4].label:SetText(q and "QUEST ON" or "QUEST OFF")
    color(buttons[4],q and GREEN or OFF)
    local loot=HB.LootMethodName and HB.LootMethodName()
    buttons[5].label:SetText(HB.db.autoFFA and "Loot: Auto" or "Loot: Manual")
    color(buttons[5],HB.db.autoFFA and GREEN or OFF)
    buttons[22].label:SetText(HB.db.followAlerts and "Follow Alerts: ON" or "Follow Alerts: OFF")
    color(buttons[22],HB.db.followAlerts and GREEN or OFF)
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
    -- Spellbook-style title case, while preserving the state-dependent labels
    -- and every existing click handler.
    local pretty={
        [19]=HB.db.boxMode and "Box On" or "Box Off",[21]="Macro Menu",
        [22]=HB.db.followAlerts and "Follow Alerts ON" or "Follow Alerts OFF",
        [23]="HaploBox Keybindings",[24]="UI Layout",
        [26]="Play Modes Config",[27]="Team Management Config",[28]="Menus Config",
        [1]="Direct",[2]="Dungeon",[3]="Healer",[13]="Follower Heal UI",
        [4]=q and "Quest On" or "Quest Off",
        [5]=HB.db.autoFFA and "Loot: Auto" or "Loot: Manual",
        [6]=HB.db.tradeEnabled and "Trade On" or "Trade Off",[7]="Invite Party",
        [8]="Leave Party",[9]="Options",[10]="Auto Repair: "..((HaploBoxA4 and HaploBoxA4.db and HaploBoxA4.db.inventory and HaploBoxA4.db.inventory.autoRepair) and "ON" or "OFF"),[11]="Sell Locked",
        [12]=HB.db.teamLocked and "Frame Unlock" or "Frame Lock",
        [14]=HB.db.autoFFA and "Loot Auto On" or "Loot Auto Off",
        [15]=(HB.db.buffOverviewEnabled~=false and "[x] " or "[ ] ").."Buff Overview",
        [16]=HB.db.buffOverviewUnlocked and "Lock Buff Frame" or "Unlock Buff Frame",
    }
    for i,title in pairs(pretty) do
        if buttons[i] and buttons[i].label then buttons[i].label:SetText(title) end
    end
    -- HF13 rows: name on left, state/operation in the right control.
    local function stateButton(idx,labelText,paint)
        local b=buttons[idx]
        if b and b.label then b.label:SetText(labelText);color(b,paint) end
    end
    stateButton(19,HB.db.boxMode and "ON" or "OFF",HB.db.boxMode and GREEN or RED)
    stateButton(1,"DIRECT",mode=="direct" and GOLD or OFF)
    stateButton(2,"DUNGEON",mode=="dungeon" and GOLD or OFF)
    stateButton(7,"INVITE",BLUE)
    stateButton(8,"LEAVE",BLUE)
    local method=(loot=="freeforall" and "FFA" or loot=="group" and "PL" or "?")
    stateButton(5,(HB.db.autoFFA and "AUTO " or "MANUAL ")..method,GOLD)
    stateButton(4,q and "ON" or "OFF",q and GREEN or RED)
    local repairActive=HaploBoxA4 and HaploBoxA4.db and
        HaploBoxA4.db.inventory and HaploBoxA4.db.inventory.autoRepair
    stateButton(10,repairActive and "ON" or "OFF",repairActive and GREEN or RED)
    for _,idx in ipairs({21,23,24,32}) do stateButton(idx,"OPEN",BLUE) end
    local gather=HB.IsLyraGatheringMapClient and HB.IsLyraGatheringMapClient()
    stateButton(29,gather and (HB.db.gatheringMapEnabled==false and "OFF" or "ON") or "LYRA",
        gather and (HB.db.gatheringMapEnabled==false and RED or GREEN) or OFF)
    for _,idx in ipairs({26,27,28}) do stateButton(idx,"CONFIG",BLUE) end
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
    -- HaploBoxControlsPanel can become protected through WoW's secure UI.
    -- Do not call SetShown (even with an unchanged value) in combat.
    -- Defer panel/flyout visibility and layout until PLAYER_REGEN_ENABLED.
    local inCombat = InCombatLockdown and InCombatLockdown()
    if inCombat then
        deferred = true
    else
        panel:SetShown(not HB.db.miniHealMode)
        HB.PositionQuickSettings(false)
        flyout:SetShown(not not HB.db.controlsOpen)
        if not HB.db.controlsOpen and activeSubmenu then HB.HideQuickSubmenus() end
    end
    gear.icon:SetVertexColor(HB.db.controlsOpen and 0.4 or 0.9,
        HB.db.controlsOpen and 0.95 or 0.9,0.48)
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
