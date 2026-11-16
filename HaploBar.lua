-- Alpha5 TB19.1: permanent full-width text HaploBar, square native minimap,
-- and a toolbar for Blizzard/addon minimap controls.  This module does not
-- modify secure party/heal frames, combat auras or the native minimap handlers.
local HB = HaploBox
local bar, mapPlate, mapOutline, dock, blizzardBridge
local status, placedButtons = {}, {}
local mapApplied, mapPending, mapConflictWarned = false, false, false
local BAR_HEIGHT, MAP_INSET = 38, 1
local MAP_FALLBACK = 205 -- equal to five existing 41px Buff Overview rows
local MEDIA = "Interface\\AddOns\\HaploBox\\Media\\"
local buttonsWidth = 0
local dielHooked=false
local dockWatchElapsed=0
local overlay, zoneCaption, coordCaption
local lastOverlayUpdate=0
local clockStyled=false
local duplicateScanElapsed=0
local suppressedButtons={}
local movedCount, skippedCount = 0,0
-- Native tooltip and click handlers stay on each original Blizzard widget;
-- only unprotected visible controls may move to our independent toolbar.
local organizeButtons -- forward reference for Blizzard Edit Mode hook
local hideMatchingExternalCoordinate, styleClock
local function safeNumber(v)
    return type(v)=="number" and not (issecretvalue and issecretvalue(v)) and v==v
end
local function safeWidth(frame, fallback)
    local w = frame and frame.GetWidth and frame:GetWidth()
    return safeNumber(w) and w>0 and w or fallback
end
local function screenSize()
    local w,h=UIParent:GetWidth(), UIParent:GetHeight()
    return (safeNumber(w) and w or 0),(safeNumber(h) and h or 0)
end
local function addBorder(frame,alpha)
    for edge=1,4 do
        local t=frame:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(0.65,0.49,0.23,alpha or 1)
        if edge==1 then t:SetPoint("TOPLEFT");t:SetPoint("TOPRIGHT");t:SetHeight(2)
        elseif edge==2 then t:SetPoint("BOTTOMLEFT");t:SetPoint("BOTTOMRIGHT");t:SetHeight(2)
        elseif edge==3 then t:SetPoint("TOPLEFT");t:SetPoint("BOTTOMLEFT");t:SetWidth(2)
        else t:SetPoint("TOPRIGHT");t:SetPoint("BOTTOMRIGHT");t:SetWidth(2) end
    end
end
local function font(text,size)
    if STANDARD_TEXT_FONT then text:SetFont(STANDARD_TEXT_FONT,size,"OUTLINE") end
end
local function measure(f, fallback)
    local ok,w=pcall(function() return f.GetUnboundedStringWidth and
        f:GetUnboundedStringWidth() or f:GetStringWidth() end)
    if ok and safeNumber(w) and w>0 then return math.ceil(w) end
    return fallback
end
local function makeStatus(key)
    local b=CreateFrame("Frame",nil,bar)
    b:SetHeight(26)
    b:EnableMouse(false)
    local bg=b:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.16,0.18,0.23,0.94)
    local f=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    font(f,10)
    f:SetPoint("LEFT",b,"LEFT",6,0)
    f:SetPoint("RIGHT",b,"RIGHT",-4,0)
    f:SetJustifyH("LEFT")
    f:SetWordWrap(false)
    status[key]={frame=b,text=f}
end
local ORDER={"box","follow","loot","repair","quest"}
function HB.GetHaploBarFrame() return bar end
local function buildBar()
    if bar then return end
    bar=CreateFrame("Frame","HaploBoxHaploBar",UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(1)
    bar:EnableMouse(false)
    bar:SetPoint("TOPLEFT",UIParent,"TOPLEFT",0,0)
    bar:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",0,0)
    bar:SetHeight(BAR_HEIGHT) -- FIXED: height must never change for TB19.1
    local fill=bar:CreateTexture(nil,"BACKGROUND")
    fill:SetAllPoints();fill:SetColorTexture(0.065,0.075,0.105,0.97)
    local rule=bar:CreateTexture(nil,"BORDER")
    rule:SetPoint("BOTTOMLEFT");rule:SetPoint("BOTTOMRIGHT")
    rule:SetHeight(2);rule:SetColorTexture(0.65,0.49,0.23,1)
    bar.name=bar:CreateFontString(nil,"OVERLAY","GameFontNormal")
    bar.name:SetPoint("LEFT",bar,"LEFT",41,0)
    bar.name:SetText("HAPLOBOX")
    font(bar.name,11)
    bar.name:SetTextColor(0.97,0.78,0.41)
    -- The only Quick Menu launcher is at the upper-left of HaploBar.
    local menuButton=CreateFrame("Button","HaploBoxQuickMenuButton",bar)
    menuButton:SetFrameStrata("HIGH")
    menuButton:SetSize(29,29)
    menuButton:SetPoint("TOPLEFT",bar,"TOPLEFT",5,-4)
    local gearIcon=menuButton:CreateTexture(nil,"ARTWORK")
    gearIcon:SetAllPoints()
    gearIcon:SetTexture("Interface\\AddOns\\HaploBox\\Media\\ui-settings.tga")
    menuButton:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
    menuButton:SetScript("OnClick",function()
        if HB.ToggleQuickSettings then HB.ToggleQuickSettings() end
    end)
    menuButton:SetScript("OnEnter",function(self)
        if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText("Quick Menu");GameTooltip:Show() end
    end)
    menuButton:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
    for _,key in ipairs(ORDER) do makeStatus(key) end
    dock=CreateFrame("Frame","HaploBoxMinimapToolbar",bar)
    dock:SetFrameStrata("HIGH")
    dock:SetFrameLevel(4)
    dock:EnableMouse(false)
    dock:SetPoint("TOPRIGHT",bar,"TOPRIGHT",-5,-3)
    dock:SetHeight(31)
    dock:SetWidth(1)
    -- WoW can fade the original MinimapCluster after mouse-leave. Children of
    -- our OWN dock do not inherit that fade. A bounded visibility check below
    -- corrects any native hover alpha changes without hiding POI markers.
    dock:SetScript("OnUpdate",function(_,elapsed)
        if not mapApplied or (InCombatLockdown and InCombatLockdown()) then return end
        dockWatchElapsed=dockWatchElapsed+(elapsed or 0)
        lastOverlayUpdate=lastOverlayUpdate+(elapsed or 0)
        if lastOverlayUpdate>=0.3 then
            lastOverlayUpdate=0
            if zoneCaption then
                local zone=(GetMinimapZoneText and GetMinimapZoneText()) or
                    (GetSubZoneText and GetSubZoneText()) or ""
                zoneCaption:SetText(zone)
            end
            if coordCaption and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
                local ok,x,y=pcall(function()
                    local id=C_Map.GetBestMapForUnit("player")
                    local pos=id and C_Map.GetPlayerMapPosition(id,"player")
                    if pos then
                        if pos.GetXY then return pos:GetXY() end
                        return pos.x,pos.y
                    end
                end)
                if ok and safeNumber(x) and safeNumber(y) then
                    coordCaption:SetFormattedText("%.1f, %.1f",x*100,y*100)
                else coordCaption:SetText("") end
            end
        end
        duplicateScanElapsed=duplicateScanElapsed+(elapsed or 0)
        if duplicateScanElapsed>=2 then
            duplicateScanElapsed=0
            hideMatchingExternalCoordinate()
        end
        if dockWatchElapsed<0.5 then return end
        dockWatchElapsed=0
        if _G.TimeManagerClockButton then styleClock(_G.TimeManagerClockButton) end
        for control in pairs(suppressedButtons) do
            if control and control.IsShown and control:IsShown() then
                if control.Hide then pcall(control.Hide,control) end
            end
            if control and control.SetAlpha then pcall(control.SetAlpha,control,0) end
        end
        for control in pairs(placedButtons) do
            if control and control.GetParent and control:GetParent()==dock then
                local shown=control.IsShown and control:IsShown()
                local cluster=_G.MinimapCluster
                local zone=cluster and (cluster.ZoneTextButton or
                    (cluster.BorderTop and cluster.BorderTop.ZoneTextButton)) or
                    _G.MinimapZoneTextButton
                local permanent=(control==zone or control==_G.MinimapZoneTextButton or
                    control==_G.TimeManagerClockButton or control==_G.GameTimeFrame or
                    (cluster and control==cluster.DielFrame))
                if permanent and control.Show and not shown then
                    pcall(control.Show,control)
                    shown=true
                end
                if shown and control.GetEffectiveAlpha and control.SetAlpha then
                    local ok,alpha=pcall(control.GetEffectiveAlpha,control)
                    if ok and safeNumber(alpha) and alpha<0.90 then
                        pcall(control.SetAlpha,control,1)
                    end
                end
            end
        end
    end)
    addBorder(bar,0.7)
end
local function setStatus(key,label,mode)
    local s=status[key]
    if not s then return end
    s.text:SetText(label)
    if mode=="on" then s.text:SetTextColor(0.39,0.96,0.55)
    elseif mode=="warn" then s.text:SetTextColor(0.96,0.79,0.39)
    else s.text:SetTextColor(0.67,0.71,0.76) end
end
local function layoutStatus()
    if not bar then return end
    local sw=screenSize()
    if sw<1 then return end
    local labelX=math.max(123,measure(bar.name,76)+62)
    local usable=math.max(0,sw-labelX-buttonsWidth-14)
    -- Font and HORIZONTAL allocation change, but never bar height or labels.
    -- First attempt one row; for small client windows use TWO complete rows.
    local sizes={}
    local needed=0
    local preferred=10
    for _,size in ipairs({10,9,8}) do
        local total=0
        for _,key in ipairs(ORDER) do
            font(status[key].text,size)
            sizes[key]=measure(status[key].text,110)+13
            total=total+sizes[key]+5
        end
        preferred=size;needed=total-5
        if needed<=usable then break end
    end
    if needed<=usable then
        bar.name:Show()
        local x=labelX
        for _,key in ipairs(ORDER) do
            local s=status[key]
            s.frame:SetSize(sizes[key],25)
            s.frame:ClearAllPoints()
            s.frame:SetPoint("LEFT",bar,"LEFT",x,0)
            s.frame:Show()
            x=x+sizes[key]+5
        end
        return
    end
    -- Two lines, both still INSIDE the fixed 38-height bar, no ellipses.
    -- The complete follow label is never truncated to "FOLLOW: DIRE...".
    local first={"box","follow","loot"}
    local second={"repair","quest"}
    font(status.box.text,9);font(status.follow.text,9);font(status.loot.text,9)
    font(status.repair.text,9);font(status.quest.text,9)
    local rows={first,second}
    local x0=labelX
    if (sizes.box+sizes.follow+sizes.loot+15)>usable or
        (sizes.repair+sizes.quest+10)>usable then
        -- Remove only decorative title space for very narrow client windows.
        bar.name:SetShown(sw>=640)
        if sw<640 then x0=7 end
    else bar.name:Show() end
    for i,row in ipairs(rows) do
        local x=x0
        for _,key in ipairs(row) do
            local s=status[key]
            local width=measure(s.text,90)+12
            s.frame:SetSize(width,16)
            s.frame:ClearAllPoints()
            s.frame:SetPoint("LEFT",bar,"LEFT",x,i==1 and 8 or -9)
            s.frame:Show()
            x=x+width+5
        end
    end
end
function HB.RefreshHaploBar()
    if not (HB.db and bar) then return end
    local mode=HB.db.followMode
    setStatus("box",HB.boxSyncError and "BOX: ERROR" or
        (HB.db.boxMode and "BOX: ON" or "BOX: OFF"),
        HB.boxSyncError and "warn" or (HB.db.boxMode and "on" or "off"))
    -- Mode selected by user is not a claim every follower is actively following.
    setStatus("follow",mode=="direct" and "FOLLOW: DIRECT" or
        mode=="dungeon" and "FOLLOW: DUNGEON" or "FOLLOW: ?","warn")
    local loot=HB.LootMethodName and HB.LootMethodName()
    setStatus("loot",loot=="freeforall" and "LOOT: FFA" or
        loot=="group" and "LOOT: GROUP" or "LOOT: ?",
        loot=="freeforall" and "on" or loot=="group" and "warn" or "off")
    local a4=HaploBoxA4
    local repair=a4 and a4.db and a4.db.inventory and a4.db.inventory.autoRepair
    setStatus("repair",repair and "REPAIR: ON" or "REPAIR: OFF",repair and "on" or "off")
    local quest=HB.db.questEnabled
    setStatus("quest",quest and "QUEST: ON" or "QUEST: OFF",quest and "on" or "off")
    layoutStatus()
end
local function loaded(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok,result=pcall(C_AddOns.IsAddOnLoaded,addon)
        if ok then return result==true end
    end
    if IsAddOnLoaded then
        local ok,result=pcall(IsAddOnLoaded,addon)
        if ok then return result==true end
    end
    return false
end
local competing={"SexyMap","BasicMinimap","Chinchilla","EKMinimap","SquareMinimap",
    "MinimapTweaks","bdMinimap","PocketPlot"}
local function mapOwner()
    for _,addon in ipairs(competing) do if loaded(addon) then return addon end end
end
local function buffHeight()
    local f=_G.HaploBoxBuffOverview
    local h=f and f.GetHeight and f:GetHeight()
    return safeNumber(h) and h>=100 and h<=400 and h or MAP_FALLBACK
end
local function createPlate()
    if mapPlate then return end
    mapPlate=CreateFrame("Frame","HaploBoxMinimapPlate",UIParent)
    mapPlate:SetFrameStrata("BACKGROUND")
    mapPlate:SetFrameLevel(1)
    mapPlate:EnableMouse(false)
    local bg=mapPlate:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints();bg:SetColorTexture(0.065,0.075,0.105,1)
    mapOutline=CreateFrame("Frame","HaploBoxMinimapOutline",UIParent)
    mapOutline:SetFrameStrata("HIGH")
    mapOutline:SetFrameLevel(5)
    mapOutline:SetAllPoints(mapPlate)
    mapOutline:EnableMouse(false)
    addBorder(mapOutline,1)
    overlay=CreateFrame("Frame","HaploBoxMinimapTextOverlay",mapPlate)
    overlay:SetAllPoints(mapPlate)
    overlay:EnableMouse(false)
    overlay:SetFrameStrata("HIGH")
    overlay:SetFrameLevel(8)
    local function caption(yanchor)
        local bg=overlay:CreateTexture(nil,"ARTWORK")
        bg:SetColorTexture(0,0,0,0) -- TB19.1i: no black label panels
        bg:SetSize(150,20)
        bg:SetPoint(yanchor,overlay,yanchor,0,yanchor=="TOP" and -7 or 7)
        local fs=overlay:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        font(fs,11)
        fs:SetTextColor(1,0.93,0.70,1)
        fs:SetShadowColor(0,0,0,1)
        fs:SetShadowOffset(1,-1)
        fs:SetSize(146,18)
        fs:SetPoint("CENTER",bg,"CENTER")
        return fs
    end
    zoneCaption=caption("TOP")
    coordCaption=caption("BOTTOM")
end
local function layoutPlate()
    if not mapPlate then return end
    -- 5x41px buff overview = 205px exterior.  Remove TB19's 4px inset,
    -- enlarging the MAP itself by 6px while matching both exterior edges.
    local h=buffHeight()
    mapPlate:SetSize(h,h)
    mapPlate:ClearAllPoints()
    -- TB19.1k: flush right, with a 4 UIpt gap from the 38pt HaploBar.
    -- This prevents two gold top/bottom rules from visually merging.
    mapPlate:SetPoint("TOPRIGHT",bar,"BOTTOMRIGHT",0,-4)
    if Minimap then
        Minimap:ClearAllPoints()
        Minimap:SetSize(h-2*MAP_INSET,h-2*MAP_INSET)
        Minimap:SetPoint("CENTER",mapPlate,"CENTER",0,0)
    end
    -- TB19.1a: the map is ONLY the default placement for a new/RESET overview.
    -- Never replace the user's saved drag position when locked, on /reload,
    -- on ADDON_LOADED, or when layoutPlate is re-run for scale changes.
    local buff=_G.HaploBoxBuffOverview
    local saved=HB.db and HB.db.buffOverviewPos
    if buff and HB.db and HB.db.buffOverviewEnabled~=false and
        type(saved)~="table" and not HB.db.buffOverviewUnlocked then
        buff:ClearAllPoints()
        -- 10px measured between the 27px square number tile and map edge;
        -- the tile starts ~8px BELOW the fixed-height HaploBar. Row five's
        -- TIMER is allowed to end naturally, never snapped to the map bottom.
        buff:SetPoint("TOPRIGHT",mapPlate,"TOPLEFT",-7,-5)
        -- Intentionally DO NOT save this automatic default as a manual choice.
    end
end
function HB.PositionDefaultBuffOverview()
    if InCombatLockdown and InCombatLockdown() then return false end
    if not (mapPlate and mapApplied and HB.db and
        type(HB.db.buffOverviewPos)~="table") then return false end
    local f=_G.HaploBoxBuffOverview
    if not f then return false end
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT",mapPlate,"TOPLEFT",-7,-5)
    return true
end
-- Never clone Blizzard functionality: where safe, relocate the actual clickable
-- Button frame. No replacements for tracking/calendar/mail/zoom or addon clicks.
local originalButtons={}
local function candidate(obj)
    if not obj or not obj.IsObjectType then return false end
    -- The old button-only filter silently rejected Blizzard's GameTimeFrame
    -- and some Classic tracking widgets: these are Frames, not Buttons.
    -- Permit Frames ONLY for the explicitly identified native controls.
    local cluster=_G.MinimapCluster
    local zone=cluster and (cluster.ZoneTextButton or
        (cluster.BorderTop and cluster.BorderTop.ZoneTextButton)) or
        _G.MinimapZoneTextButton
    local indicator=cluster and cluster.IndicatorFrame
    local nativeFrame=obj==_G.GameTimeFrame or obj==_G.MiniMapTrackingFrame or
        obj==_G.MiniMapMailFrame or obj==_G.MinimapZoneTextButton or
        (cluster and (obj==cluster.DielFrame or obj==zone)) or
        (indicator and (obj==indicator.MailFrame or obj==indicator.CraftingOrderFrame))
    local isButton=obj:IsObjectType("Button")
    if not isButton and not (nativeFrame and obj:IsObjectType("Frame")) then return false end
    -- Forbidden/secure Blizzard frames are NEVER detached or reparented.
    if obj.IsForbidden and obj:IsForbidden() then return false end
    local protected=obj.IsProtected and obj:IsProtected()
    if protected then return false end
    if obj==Minimap then return false end
    local name=obj.GetName and obj:GetName() or ""
    if name and (name:find("Scroll",1,true) or name:find("MapCanvas",1,true)) then return false end
    return true
end
local function collectButtons()
    local list,seen={},{}
    local function add(f)
        if candidate(f) and not seen[f] then seen[f]=true;list[#list+1]=f end
    end
    local cluster=_G.MinimapCluster
    local zone=cluster and (cluster.ZoneTextButton or
        (cluster.BorderTop and cluster.BorderTop.ZoneTextButton)) or
        _G.MinimapZoneTextButton
    local candidates={
        _G.MiniMapWorldMapButton,_G.GameTimeFrame,
        _G.MinimapZoomIn,_G.MinimapZoomOut,
        _G.MiniMapTracking,_G.MiniMapTrackingButton,_G.MiniMapTrackingFrame,
        _G.MiniMapMailFrame,_G.QueueStatusMinimapButton,
        _G.MiniMapBattlefieldFrame,_G.GarrisonLandingPageMinimapButton,
        _G.AddonCompartmentFrame,_G.ExpansionLandingPageMinimapButton,
        zone,_G.TimeManagerClockButton,
        _G.MiniMapInstanceDifficulty,_G.MiniMapLFGFrame,
        cluster and cluster.Tracking and cluster.Tracking.Button,
        cluster and cluster.Tracking and cluster.Tracking.TrackingButton,
        cluster and cluster.CalendarButton,
        cluster and cluster.InstanceDifficulty,
        cluster and cluster.DielFrame,
        cluster and cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame,
        cluster and cluster.IndicatorFrame and cluster.IndicatorFrame.CraftingOrderFrame,
        Minimap and Minimap.ZoomIn, Minimap and Minimap.ZoomOut,
    }
    for _,f in pairs(candidates) do add(f) end
    -- LibDBIcon and conventional minimap buttons created by other addons.
    -- Only known BUTTONS from map/container children, no native map overlays.
    local parents={Minimap,cluster,cluster and cluster.MinimapContainer}
    local function walk(parent,depth)
        if depth>3 or not (parent and parent.GetChildren) then return end
        for _,child in ipairs({parent:GetChildren()}) do
            local n=child and child.GetName and child:GetName() or ""
            if type(n)=="string" and
                (n:find("LibDBIcon",1,true) or n:find("MinimapButton",1,true) or
                 n:find("MiniMapButton",1,true) or n:find("MiniMapTracking",1,true)) then
                add(child)
            end
            -- Scan named addon/Blizzard button wrappers, NOT POI/map-marker
            -- hierarchies. Filter above still requires clickable Button types.
            if depth<3 and child and child.GetChildren and
                (n=="" or n:find("Minimap",1,true) or
                 n:find("MiniMap",1,true) or n:find("LibDBIcon",1,true)) then
                walk(child,depth+1)
            end
        end
    end
    for _,parent in pairs(parents) do walk(parent,1) end
    -- Already-docked addon buttons are no longer children of MinimapCluster;
    -- keep them in the candidate set across zone changes and /reload events.
    for button in pairs(placedButtons) do add(button) end
    -- Keep toolbar order stable across reloads and late addon registration.
    -- Blizzard status/location controls first, then third-party buttons.
    local priority={
        MiniMapWorldMapButton=10,MinimapZoneTextButton=20,
        TimeManagerClockButton=30,GameTimeFrame=31,
        MiniMapTrackingFrame=40,MiniMapTracking=41,MiniMapTrackingButton=42,
        MinimapZoomIn=50,MinimapZoomOut=51,
        MiniMapMailFrame=60,QueueStatusMinimapButton=61,
        AddonCompartmentFrame=70,
    }
    local function orderKey(f)
        local name=f.GetName and f:GetName() or ""
        local cluster=_G.MinimapCluster
        local zone=cluster and (cluster.ZoneTextButton or
            (cluster.BorderTop and cluster.BorderTop.ZoneTextButton))
        local ind=cluster and cluster.IndicatorFrame
        if zone and f==zone then return 20,name end
        if cluster and f==cluster.DielFrame then return 32,name end
        if ind and f==ind.MailFrame then return 60,name end
        local pr=priority[name]
        if pr then return pr,name end
        if name:find("LibDBIcon",1,true) then return 100,name end
        return 80,name
    end
    table.sort(list,function(a,b)
        local pa,na=orderKey(a)
        local pb,nb=orderKey(b)
        return pa<pb or pa==pb and na<nb
    end)
    return list
end
local function displayButtonWidth(button)
    local cluster=_G.MinimapCluster
    local zone=cluster and (cluster.ZoneTextButton or
        (cluster.BorderTop and cluster.BorderTop.ZoneTextButton)) or
        _G.MinimapZoneTextButton
    if button==zone or button==_G.MinimapZoneTextButton then
        -- The longest zone names need more room than 'Westfall'. The native
        -- title should never bleed outside its own protected toolbar slot.
        local nativeText=_G.MinimapZoneText
        local width=nativeText and nativeText.GetUnboundedStringWidth and
            nativeText:GetUnboundedStringWidth()
        if safeNumber(width) then return math.max(116,math.min(190,math.ceil(width)+20)) end
        return 124
    end
    if button==_G.TimeManagerClockButton then return 63 end
    -- Calendar and day/night icons are ordinary 30px controls, not labels.
    return 30
end
local function isZoneButton(button)
    local cluster=_G.MinimapCluster
    local zone=cluster and (cluster.ZoneTextButton or
        (cluster.BorderTop and cluster.BorderTop.ZoneTextButton))
    return button==zone or button==_G.MinimapZoneTextButton
end
local function isSuppressed(button)
    local n=button.GetName and button:GetName() or ""
    local cluster=_G.MinimapCluster
    if (cluster and button==cluster.DielFrame) or
        isZoneButton(button) or button==_G.MiniMapWorldMapButton or
        button==_G.MinimapZoomIn or button==_G.MinimapZoomOut or
        button==_G.AddonCompartmentFrame or
        (Minimap and (button==Minimap.ZoomIn or button==Minimap.ZoomOut)) then return true end
    -- Only addon-launcher mini-buttons; never hide native map POIs.
    return n:find("LibDBIcon",1,true)~=nil
end
-- Keep the approved native clock control, but make its actual clock
-- FontStrings legible. Never restyle tracking/calendar or their callbacks.
styleClock=function(button)
    if not button then return end
    local seen={}
    local function visit(frame,depth)
        if not frame or depth>2 or seen[frame] then return end
        seen[frame]=true
        if frame.GetRegions then
            for i=1,select("#",frame:GetRegions()) do
                local region=select(i,frame:GetRegions())
                if region and region.IsObjectType and region:IsObjectType("FontString") then
                    local ok,value=pcall(region.GetText,region)
                    if ok and type(value)=="string" and value:match("%d+:%d%d") then
                        if STANDARD_TEXT_FONT and region.SetFont then
                            pcall(region.SetFont,region,STANDARD_TEXT_FONT,18,"OUTLINE")
                        end
                        if region.SetShadowOffset then region:SetShadowOffset(1,-1) end
                        if region.SetJustifyH then region:SetJustifyH("CENTER") end
                    end
                end
            end
        end
        if frame.GetChildren then
            for i=1,select("#",frame:GetChildren()) do
                visit(select(i,frame:GetChildren()),depth+1)
            end
        end
    end
    visit(button,0)
end
-- The existing coordinates below the map are owned by an unidentified addon.
-- Only suppress a *matching plain-coordinate FontString* immediately below
-- this specific square minimap. Do not hide whole frames, POIs or other text.
hideMatchingExternalCoordinate=function()
    if not (coordCaption and mapPlate and mapPlate.GetBottom and EnumerateFrames) then return end
    local own=coordCaption:GetText()
    if type(own)~="string" then return end
    local ax,ay=own:match("^%s*(%d+%.%d+)%s*,%s*(%d+%.%d+)%s*$")
    ax,ay=tonumber(ax),tonumber(ay)
    if not (ax and ay) then return end
    local mleft,mright,mbottom=mapPlate:GetLeft(),mapPlate:GetRight(),mapPlate:GetBottom()
    if not (safeNumber(mleft) and safeNumber(mright) and safeNumber(mbottom)) then return end
    local frame,count=EnumerateFrames(),0
    while frame and count<15000 do
        count=count+1
        if frame~=overlay and frame~=mapPlate and frame.GetRegions then
            local ok,regions=pcall(function()return {frame:GetRegions()} end)
            if ok and regions then
                for _,r in ipairs(regions) do
                    if r and r.IsObjectType and r:IsObjectType("FontString") and
                        r~=coordCaption and r.GetText and r.GetCenter then
                        local ok2,t,x,y=pcall(function()
                            local cx,cy=r:GetCenter()
                            return r:GetText(),cx,cy
                        end)
                        if ok2 and type(t)=="string" and safeNumber(x) and safeNumber(y) and
                            x>=mleft-15 and x<=mright+15 and
                            y>=mbottom-72 and y<mbottom then
                            local bx,by=t:match("^%s*(%d+%.%d+)%s*,%s*(%d+%.%d+)%s*$")
                            bx,by=tonumber(bx),tonumber(by)
                            -- The other addon may refresh coordinates at a different time.
                            -- Only hide nearly identical coordinates near the map bottom.
                            if bx and by and math.abs(ax-bx)<=0.3 and math.abs(ay-by)<=0.3 then
                                if r.SetAlpha and not (r.IsForbidden and r:IsForbidden()) then
                                    pcall(r.SetAlpha,r,0)
                                end
                            end
                        end
                    end
                end
            end
        end
        frame=EnumerateFrames(frame)
    end
end

local function suppress(button)
    if not candidate(button) then return end
    if not suppressedButtons[button] then
        suppressedButtons[button]={shown=button.IsShown and button:IsShown(),
            alpha=button.GetAlpha and button:GetAlpha() or 1}
    end
    -- Keep actual widget and click implementation intact for minimap-off rollback.
    if button.Hide then pcall(button.Hide,button) end
    if button.SetAlpha then pcall(button.SetAlpha,button,0) end
end
-- Nonprotected native widgets are docked under our own always-visible parent.
-- SetPoint alone was not enough: Blizzard's faded MinimapCluster remained the
-- PARENT, making relocated controls disappear after mouse leave.
organizeButtons=function()
    if not dock or not mapApplied or (InCombatLockdown and InCombatLockdown()) then return end
    local all=collectButtons()
    local sw=screenSize()
    -- Status labels retain priority. On a narrow viewport leave overflow
    -- native controls in their Blizzard parent rather than clip/cannibalize.
    local allowed=math.max(0,sw-420)
    -- Right edge: [clock][calendar], with calendar at the extreme right.
    local cluster=_G.MinimapCluster
    local calendar=(candidate(_G.GameTimeFrame) and _G.GameTimeFrame) or
        (cluster and candidate(cluster.CalendarButton) and cluster.CalendarButton)
    local clock=candidate(_G.TimeManagerClockButton) and _G.TimeManagerClockButton
    -- Stable non-overlapping anchors. Calendar stays far right with the clock
    -- beside it. Tracking is anchored to the TOP-LEFT of the *minimap*, not
    -- given a hard-coded right-edge clock-relative slot.  Its native dropdown
    -- therefore opens down along the minimap. Mail is immediately LEFT of
    -- Tracking and never shifts it when the mailbox state changes.
    -- Keep Blizzard's native show/hide behavior for unread mail.
    local trackingCandidates={_G.MiniMapTrackingFrame or false,_G.MiniMapTracking or false,
        _G.MiniMapTrackingButton or false,
        (cluster and cluster.Tracking and cluster.Tracking.Button) or false,
        (cluster and cluster.Tracking and cluster.Tracking.TrackingButton) or false}
    local tracking
    for _,item in ipairs(trackingCandidates) do
        if candidate(item) and item.IsShown and item:IsShown() then tracking=item;break end
    end
    if not tracking then
        for _,item in ipairs(trackingCandidates) do
            if candidate(item) then tracking=item;break end
        end
    end
    local indicator=cluster and cluster.IndicatorFrame
    local mail=(candidate(_G.MiniMapMailFrame) and _G.MiniMapMailFrame) or
        (indicator and candidate(indicator.MailFrame) and indicator.MailFrame)
    -- Reserve all map-adjacent controls independent of whether mail exists.
    -- Any extra safe native buttons are placed to the LEFT of the mail slot.
    local reserved=math.ceil(safeWidth(mapPlate,MAP_FALLBACK))+83
    local offset, moved, skipped=reserved,0,0
    for _,button in ipairs(all) do
        if isSuppressed(button) or (cluster and button==cluster.CalendarButton and
            calendar~=button) then
            suppress(button)
            skipped=skipped+1
        else
        local w=displayButtonWidth(button)
        local targetOffset=button==calendar and 0 or
            (button==clock and 32) or offset
        local fixed=(button==calendar or button==clock or button==tracking or button==mail)
        if button==mail then w=34 end -- larger envelope, still native Blizzard widget
        if (fixed or offset+w+5<=allowed) then
            local prior=originalButtons[button]
            if not prior then
                local originalParent=button.GetParent and button:GetParent()
                local oldPoint={}
                if button.GetPoint then
                    local ok,a,b,c,d,e=pcall(button.GetPoint,button,1)
                    if ok and a then oldPoint={a,b,c,d,e} end
                end
                prior={parent=originalParent,point=oldPoint}
            end
            local success=pcall(function()
                if button.GetParent and button:GetParent()~=dock then
                    -- Reparent only unprotected/explicitly-whitelisted native
                    -- controls and normal addon Buttons (filtered above).
                    button:SetParent(dock)
                end
                button:ClearAllPoints()
                if button==tracking and mapPlate then
                    -- map top sits 4pt below bar; +BAR_HEIGHT places control
                    -- 4pt below bar top, centered vertically in HaploBar.
                    button:SetPoint("TOPLEFT",mapPlate,"TOPLEFT",0,BAR_HEIGHT)
                elseif button==mail and mapPlate then
                    -- Same stable map-left anchor whether tracking is shown
                    -- or not; the envelope is exactly 4pt LEFT of it.
                    button:SetPoint("TOPRIGHT",mapPlate,"TOPLEFT",-4,BAR_HEIGHT)
                else
                    button:SetPoint("RIGHT",dock,"RIGHT",-4-targetOffset,0)
                end
                local cluster=_G.MinimapCluster
                if cluster and button==cluster.DielFrame and button.SetScale then
                    button:SetScale(1)
                end
                if button.SetSize then button:SetSize(w,30) end
                if button.SetAlpha then button:SetAlpha(1) end
                -- Prevent oversized decorative Blizzard child art from
                -- crossing into adjacent slots on clients supporting this.
                local zone=cluster and (cluster.ZoneTextButton or
                    (cluster.BorderTop and cluster.BorderTop.ZoneTextButton))
                if (button==zone or button==_G.MinimapZoneTextButton) and
                    button.SetClipsChildren then pcall(button.SetClipsChildren,button,true) end
            end)
            local onBar=false
            if success and button.GetPoint then
                local ok,_,relative=pcall(button.GetPoint,button,1)
                onBar=ok and (relative==dock or
                    ((button==tracking or button==mail) and relative==mapPlate))
            end
            if onBar then
                originalButtons[button]=prior
                placedButtons[button]=true
                if button==clock then styleClock(button) end
                if not fixed then offset=offset+w+5 end
                moved=moved+1
            else
                -- A rejected move must not strand a Blizzard control in our
                -- container. Restore original parent/one original anchor.
                if prior.parent and button.SetParent then pcall(button.SetParent,button,prior.parent) end
                if prior.point and prior.point[1] and button.ClearAllPoints and button.SetPoint then
                    pcall(function()button:ClearAllPoints();button:SetPoint((unpack or table.unpack)(prior.point))end)
                end
                placedButtons[button]=nil
                skipped=skipped+1
            end
        else
            skipped=skipped+1
        end
        end
    end
    movedCount,skippedCount=moved,skipped
    buttonsWidth=offset>0 and offset+12 or 0
    dock:SetWidth(math.max(1,buttonsWidth))
    HB.RefreshHaploBar()
end

-- Blizzard_Camelot/Diel.lua can put the night/day indicator back over the
-- map during SetEditModeScale. A secure post-hook schedules ONLY our known
-- nonprotected controls to be re-anchored after Blizzard has finished.
local function installDielHook()
    if dielHooked or type(hooksecurefunc)~="function" then return end
    local cluster=_G.MinimapCluster
    if not (cluster and type(cluster.SetEditModeScale)=="function") then return end
    hooksecurefunc(cluster,"SetEditModeScale",function()
        if not (mapApplied and HB.db and HB.db.haploMinimapEnabled~=false) then return end
        if InCombatLockdown and InCombatLockdown() then
            mapPending=true
            return
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0,function()
                if mapApplied and organizeButtons then organizeButtons() end
            end)
        elseif organizeButtons then
            organizeButtons()
        end
    end)
    dielHooked=true
end

local function updateBridge()
    -- Decorative, mouse-transparent bridge ONLY when the actual Blizzard raid
    -- manager sidebar exists and has a measurable gap. No native anchor changes.
    if not bar or (InCombatLockdown and InCombatLockdown()) then return end
    local native=_G.CompactRaidFrameManager or _G.CompactRaidFrameManagerToggleButton
    if not (native and native.IsShown and native:IsShown()) then
        if blizzardBridge then blizzardBridge:Hide() end
        return
    end
    local nativeTop=native:GetTop()
    local barBottom=bar:GetBottom()
    local nativeLeft=native:GetLeft()
    if not (safeNumber(nativeTop) and safeNumber(barBottom) and safeNumber(nativeLeft)) then return end
    local gap=barBottom-nativeTop
    if gap<4 or gap>180 or nativeLeft>40 or nativeLeft< -25 then
        if blizzardBridge then blizzardBridge:Hide() end
        return
    end
    if not blizzardBridge then
        blizzardBridge=CreateFrame("Frame","HaploBoxBlizzardSidebarBridge",UIParent)
        blizzardBridge:SetFrameStrata("BACKGROUND")
        blizzardBridge:SetFrameLevel(1)
        blizzardBridge:EnableMouse(false)
        local shade=blizzardBridge:CreateTexture(nil,"BACKGROUND")
        shade:SetAllPoints();shade:SetColorTexture(0.075,0.085,0.115,0.75)
        local edge=blizzardBridge:CreateTexture(nil,"OVERLAY")
        edge:SetPoint("TOPRIGHT");edge:SetPoint("BOTTOMRIGHT")
        edge:SetWidth(1);edge:SetColorTexture(0.62,0.49,0.27,0.85)
    end
    blizzardBridge:ClearAllPoints()
    blizzardBridge:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",math.max(0,nativeLeft),barBottom)
    blizzardBridge:SetSize(20,gap)
    blizzardBridge:Show()
end
function HB.ApplyHaploMinimap()
    if not HB.db or not Minimap or not bar then return end
    if InCombatLockdown and InCombatLockdown() then mapPending=true return end
    updateBridge()
    if HB.db.haploMinimapEnabled==false then return end
    local w,h=screenSize()
    if HB.db.miniHealMode or w<920 or h<520 then return end
    local conflict=mapOwner()
    if conflict then
        if not mapConflictWarned and HB.print then
            HB.print("HaploBar: minimap skin skipped: "..conflict.." manages the map. Disable one skin to test.")
            mapConflictWarned=true
        end
        return
    end
    if not Minimap.SetMaskTexture then return end
    local ok=pcall(Minimap.SetMaskTexture,Minimap,MEDIA.."minimap-square-mask.tga")
    if not ok then
        if HB.print then HB.print("HaploBar: minimap square mask failed; original map kept.") end
        return
    end
    createPlate()
    layoutPlate()
    for _,v in ipairs({"MinimapBorder","MinimapBorderTop",
        "MinimapCompassTexture","MinimapCompassTextureUnderlay"}) do
        local art=_G[v]
        if art and art.IsObjectType and art:IsObjectType("Texture") then art:SetAlpha(0) end
    end
    if not mapApplied then
        _G.GetMinimapShape=function() return "SQUARE" end
    end
    mapApplied=true
    installDielHook()
    organizeButtons()
    HB.RefreshHaploBar()
end
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE",
    "PARTY_LOOT_METHOD_CHANGED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED",
    "PLAYER_REGEN_ENABLED","ADDON_LOADED", "ZONE_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then buildBar() end
    if HB.RefreshHaploBar then HB.RefreshHaploBar() end
    if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" or
        event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" or
        event=="ADDON_LOADED" or event=="ZONE_CHANGED_NEW_AREA" or
        event=="ZONE_CHANGED" or event=="ZONE_CHANGED_INDOORS" or
        (event=="PLAYER_REGEN_ENABLED" and mapPending) then
        mapPending=false
        if C_Timer and C_Timer.After then
            C_Timer.After(1,function()if HB.ApplyHaploMinimap then HB.ApplyHaploMinimap() end end)
            if event=="PLAYER_ENTERING_WORLD" then
                C_Timer.After(4,function()if HB.ApplyHaploMinimap then HB.ApplyHaploMinimap() end end)
            end
        else HB.ApplyHaploMinimap() end
    elseif event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_REGEN_ENABLED" then
        updateBridge()
    end
end)
SLASH_HAPLOBAR1="/haplobar"
SlashCmdList.HAPLOBAR=function(msg)
    if not HB.db then return end
    local cmd=(msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd=="minimap off" then
        HB.db.haploMinimapEnabled=false
        HB.print("HaploBox minimap OFF after /reload (restores Blizzard map/button anchors).")
    elseif cmd=="minimap on" then
        HB.db.haploMinimapEnabled=true
        HB.print("HaploBox minimap ON after /reload.")
    elseif cmd=="buttons" then
        HB.print("TB19.1c minimap toolbar: docked="..tostring(movedCount)..
            " skipped="..tostring(skippedCount)..
            " (native protected/overflow controls remain on map)")
    else
        HB.print("TB19.1c: /haplobar minimap on|off (then /reload), or /haplobar buttons")
    end
end
