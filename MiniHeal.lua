-- Alpha5 TB12: per-client Mini Heal layout for four small WoW windows.
-- Real SecureUnitButtonTemplate targets, not simulated HP pictures. This never
-- alters team communication or the main window's existing partyframe module.
local HB=HaploBox
local root, slots, exitButton, settingsButton = nil, {}, nil, nil
function HB.GetMiniHealSettingsAnchor() return settingsButton end
local pending=false
local function secret(v) return issecretvalue and issecretvalue(v) end
local function safeNumber(v) return type(v)=="number" and not secret(v) end
local function makeBorder(parent)
    for side=1,4 do
        local t=parent:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(0.62,0.49,0.27,0.98)
        if side==1 then t:SetPoint("TOPLEFT");t:SetPoint("TOPRIGHT");t:SetHeight(2)
        elseif side==2 then t:SetPoint("BOTTOMLEFT");t:SetPoint("BOTTOMRIGHT");t:SetHeight(2)
        elseif side==3 then t:SetPoint("TOPLEFT");t:SetPoint("BOTTOMLEFT");t:SetWidth(2)
        else t:SetPoint("TOPRIGHT");t:SetPoint("BOTTOMRIGHT");t:SetWidth(2) end
    end
end
local function newSlot(i)
    local f=CreateFrame("Button","HaploBoxMiniHeal"..i,root,"SecureUnitButtonTemplate")
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("type1","target")
    f:SetAttribute("unit",nil)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(root:GetFrameLevel()+2)
    local bg=f:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints();bg:SetColorTexture(0.07,0.085,0.075,0.95)
    f.name=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f.name:SetPoint("TOPLEFT",f,"TOPLEFT",7,-5)
    f.name:SetPoint("TOPRIGHT",f,"TOPRIGHT",-7,-5)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.name:SetTextColor(1,0.82,0.44)
    f.classAccent=f:CreateTexture(nil,"ARTWORK")
    f.classAccent:SetColorTexture(1,0.49,0.04,1)
    f.classAccent:SetPoint("TOPLEFT",f,"TOPLEFT",6,-21)
    f.classAccent:SetPoint("TOPRIGHT",f,"TOPRIGHT",-6,-21)
    f.classAccent:SetHeight(2)
    f.bar=CreateFrame("StatusBar",nil,f)
    f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f.bar:SetStatusBarColor(0.18,0.73,0.25)
    f.bar:SetMinMaxValues(0,1);f.bar:SetValue(0)
    f.bar:SetPoint("TOPLEFT",f,"TOPLEFT",6,-24)
    f.bar:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-6,7)
    f.incomingHeal=HB.AttachIncomingHealBar and HB.AttachIncomingHealBar(f.bar)
    local barBack=f.bar:CreateTexture(nil,"BACKGROUND")
    barBack:SetAllPoints();barBack:SetColorTexture(0.055,0.13,0.07,0.95)
    f.pct=f.bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f.pct:SetPoint("CENTER")
    f.pct:SetShadowOffset(1,-1)
    makeBorder(f)
    f:EnableMouse(false)
    return f
end
local function layoutSizes()
    if not root then return end
    local total=UIParent:GetWidth() or 800
    if not safeNumber(total) or total<1 then total=800 end
    local screenH=UIParent:GetHeight() or 450
    if not safeNumber(screenH) or screenH<1 then screenH=450 end
    local gap=5
    -- TB16.1 HOTFIX: leave accessible space at BOTH screen edges for the
    -- native WoW bags and micro-menu on narrow follower clients.
    -- The heal row stays centered; only tile WIDTH changes, not its height.
    local sideInset=math.max(36,math.min(80,math.floor(total*0.10)))
    local width=math.max(36,math.floor((total-2*sideInset-4*gap)/5))
    -- TB14: follower healing tiles are 3x TALLER, never wider.
    -- Fit only height against the smallest client viewport.
    local oldHeight=math.max(60,math.min(104,math.floor(screenH*0.22)))
    local height=math.min(math.floor(screenH*0.76),oldHeight*3)
    root:SetSize(width*5+gap*4,height)
    root:ClearAllPoints()
    root:SetPoint("BOTTOM",UIParent,"BOTTOM",0,42) -- TB16: keep native Character/micro menu free
    for i=1,5 do
        local f=slots[i]
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT",root,"TOPLEFT",(i-1)*(width+gap),0)
        f:SetSize(width,height)
    end
    exitButton:ClearAllPoints()
    exitButton:SetPoint("BOTTOMRIGHT",root,"TOPRIGHT",0,4)
    settingsButton:ClearAllPoints()
    settingsButton:SetPoint("RIGHT",exitButton,"LEFT",-5,0)
    if HB.PositionQuickSettings then HB.PositionQuickSettings() end
end
local function health(f)
    if not f or not f.active or not f.unit then
        if f then
            f.bar:SetMinMaxValues(0,1);f.bar:SetValue(0);f.pct:SetText("")
            if f.incomingHeal then f.incomingHeal:Hide() end
        end
        return
    end
    local ok,h,m=pcall(function()return UnitHealth(f.unit),UnitHealthMax(f.unit)end)
    if not ok then return end
    if not m then return end
    -- Protected 12.x values are forwarded into native UI setters; never
    -- branch or calculate on a secret numeric health value in Lua.
    pcall(f.bar.SetMinMaxValues,f.bar,0,m)
    pcall(f.bar.SetValue,f.bar,h)
    if f.incomingHeal and HB.UpdateIncomingHealBar then
        HB.UpdateIncomingHealBar(f.incomingHeal,f.unit,m)
    end
    if safeNumber(h) and safeNumber(m) and m>0 then
        f.pct:SetText(math.floor(100*h/m+0.5).."%")
    elseif UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local success=pcall(function()
            f.pct:SetFormattedText("%.0f%%",UnitHealthPercent(f.unit,true,CurveConstants.ScaleTo100))
        end)
        if not success then f.pct:SetText("") end
    else f.pct:SetText("") end
end
function HB.UpdateMiniHealLayout()
    if not root or not HB.db then return end
    if InCombatLockdown and InCombatLockdown() then pending=true return end
    pending=false
    if not HB.db.miniHealMode then root:Hide() return end
    layoutSizes()
    -- The 5 tiles are always present. Unoccupied slots are not mouse targets.
    local people=HB.VisiblePartyNames and HB.VisiblePartyNames() or {}
    for i=1,5 do
        local f=slots[i]
        local name=people[i]
        local unit=name and HB.ResolvePartyUnit and HB.ResolvePartyUnit(name) or nil
        f.unit=unit
        f.active=unit~=nil
        f:SetAttribute("unit",unit)
        f:EnableMouse(not not unit)
        local short=(name and name:gsub("%-.*$","")) or "—"
        f.name:SetText(short)
        -- Only the CLASS COLOR accent changes in TB18; no geometry changes.
        local red,green,blue=1,0.82,0.44
        if unit and UnitClass then
            local ok,_,class=pcall(UnitClass,unit)
            if ok and type(class)=="string" and not secret(class) then
                local color=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
                if C_ClassColor and C_ClassColor.GetClassColor then
                    local success,fromAPI=pcall(C_ClassColor.GetClassColor,class)
                    if success and fromAPI then color=fromAPI end
                end
                if color then red,green,blue=color.r,color.g,color.b end
            end
        end
        if unit then
            f.name:SetTextColor(red,green,blue)
            f.classAccent:SetColorTexture(red,green,blue,1)
        else
            f.name:SetTextColor(0.42,0.45,0.46)
            f.classAccent:SetColorTexture(0.32,0.34,0.36,1)
        end
        health(f)
    end
    root:Show()
end
function HB.ToggleMiniHealMode()
    if not HB.db then return end
    return HB.SetMiniHealMode(not HB.db.miniHealMode)
end
function HB.SetMiniHealMode(enabled)
    if not HB.db then return false end
    if InCombatLockdown and InCombatLockdown() then
        HB.print("Switch between MAIN and MINI HEAL after combat.")
        return false
    end
    HB.db.miniHealMode=not not enabled
    -- Avoid a large menu obscuring the healing row during a local view switch.
    HB.db.controlsOpen=false
    if HB.LayoutPartyFrame then HB.LayoutPartyFrame() end
    HB.UpdateMiniHealLayout()
    if HB.RefreshControls then HB.RefreshControls() end
    if HB.ApplyBlizzardAuraVisibility then HB.ApplyBlizzardAuraVisibility() end
    HB.print("Local display: "..(enabled and "FOLLOWER HEAL UI" or "MAIN").." (only this WoW client)")
    return true
end
local ev=CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then
        root=CreateFrame("Frame","HaploBoxMiniHealRoot",UIParent)
        root:SetFrameStrata("HIGH")
        root:SetFrameLevel(150)
        for i=1,5 do slots[i]=newSlot(i) end
        exitButton=CreateFrame("Button",nil,root,"UIPanelButtonTemplate")
        exitButton:SetSize(68,19)
        exitButton:SetText("MAIN")
        exitButton:SetScript("OnClick",function() HB.SetMiniHealMode(false) end)
        settingsButton=CreateFrame("Button",nil,root)
        settingsButton:RegisterForClicks("LeftButtonUp")
        settingsButton:SetSize(24,19)
        local bg=settingsButton:CreateTexture(nil,"BACKGROUND")
        bg:SetAllPoints();bg:SetColorTexture(0.08,0.09,0.12,0.98)
        local icon=settingsButton:CreateTexture(nil,"ARTWORK")
        icon:SetTexture("Interface\\AddOns\\HaploBox\\Media\\ui-settings.tga")
        icon:SetSize(16,16);icon:SetPoint("CENTER")
        settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
        settingsButton:SetScript("OnClick",function()
            if HB.ToggleQuickSettings then HB.ToggleQuickSettings() end
        end)
        settingsButton:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText("Quick Settings",1,0.82,0.43)
            GameTooltip:Show()
        end)
        settingsButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
        root:Hide()
        HB.UpdateMiniHealLayout()
        C_Timer.NewTicker(0.16,function()
            if root and root:IsShown() then for _,s in ipairs(slots) do health(s) end end
        end)
    elseif root then
        if event=="PLAYER_REGEN_ENABLED" and pending then
            HB.UpdateMiniHealLayout()
        elseif event~="PLAYER_REGEN_ENABLED" then
            HB.UpdateMiniHealLayout()
        end
    end
end)
