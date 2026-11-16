local H = HaploBoxA4
local panel, refresh
local function addText(parent,text,x,y,width,font)
    local l=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    l:SetWidth(width or 460)
    l:SetJustifyH("LEFT")
    l:SetText(text)
    return l
end
local function addButton(parent,label,x,y,w,click)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w or 180,24)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b:SetText(label)
    b:SetScript("OnClick",click)
    return b
end
local checks={}
local function addCheck(parent,label,key,x,y,area)
    local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    local l=b.Text or b.text
    if not l then
        l=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        l:SetPoint("LEFT",b,"RIGHT",3,0)
    end
    l:SetText(label)
    b:SetScript("OnClick",function(self)
        local target=area=="inventory" and H.db.inventory or area=="root" and H.db or H.db.ui
        target[key]=self:GetChecked() and true or false
        if key=="wideFrames" and target[key] then
            if HaploBox and HaploBox.db then HaploBox.db.teamW=H.db.ui.partyWidth end
        end
        if HaploBox and HaploBox.LayoutPartyFrame then HaploBox.LayoutPartyFrame() end
        if H.UpdateBlizzardParty then H.UpdateBlizzardParty() end
        if HaploBox and HaploBox.RefreshPartyFrame then HaploBox.RefreshPartyFrame() end
        if H.UpdateInformationUI then H.UpdateInformationUI() end
    end)
    checks[#checks+1]={b=b,area=area,key=key}
    return b
end
local function bindDelete()
    if not GetBindingAction or not SetBinding then H.Print("This client has no key-binding API.") return end
    local current=GetBindingAction("DELETE")
    if current and current~="" and current~="HAPLOBOXA4_JUNKMARK" then
        H.Print("Delete is already bound to "..tostring(current).."; not overriding. Set it yourself in Key Bindings.")
        return
    end
    if InCombatLockdown and InCombatLockdown() then H.Print("Bind after combat.") return end
    local ok=pcall(SetBinding,"DELETE","HAPLOBOXA4_JUNKMARK")
    if ok and SaveBindings and GetCurrentBindingSet then
        pcall(SaveBindings,GetCurrentBindingSet())
    end
    H.Print(ok and "Delete bound to junk toggle (when available)." or "Key binding failed; use Key Bindings menu.")
end
local function createOptions()
    panel=CreateFrame("Frame","HaploBoxA4Options",UIParent,"BasicFrameTemplateWithInset")
    panel:SetSize(540,550)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    panel:Hide()
    if panel.TitleText then panel.TitleText:SetText("HaploBox - Alpha 4 (integrated)") end
    addText(panel,"UI display settings (local until you press SHARE).",17,-38,490)
    addCheck(panel,"Native buff display (single renderer)","auraEnabled",14,-60,"ui")
    addCheck(panel,"Square follow indicators","squareFollow",14,-92,"ui")
    addCheck(panel,"Hide Blizzard PartyFrames","hideBlizzardParty",14,-124,"ui")
    addCheck(panel,"Enable wider PartyFrames (local width)","wideFrames",14,-156,"ui")
    addCheck(panel,"Kills to Level column","showKTL",14,-188,"ui")
    addCheck(panel,"Gold + Team Gold","showGold",14,-220,"ui")
    addCheck(panel,"Free bag slots","showBags",14,-252,"ui")
    addText(panel,"AURA SIZE (14-28)",282,-70,190)
    local auraSize=addButton(panel,"20 px",290,-88,170,function()
        local s=H.db.ui.auraSize+2
        if s>28 then s=14 end
        H.db.ui.auraSize=s
        if HaploBox and HaploBox.RefreshPartyFrame then HaploBox.RefreshPartyFrame() end
        refresh()
    end)
    addText(panel,"FRAME WIDTH (250-490)",282,-143,190)
    local frameSize=addButton(panel,"365 px",290,-161,170,function()
        local s=H.db.ui.partyWidth+25
        if s>490 then s=250 end
        H.db.ui.partyWidth=s
        H.db.ui.wideFrames=true
        if HaploBox and HaploBox.db then HaploBox.db.teamW=s end
        if HaploBox and HaploBox.LayoutPartyFrame then HaploBox.LayoutPartyFrame() end
        refresh()
    end)
    addText(panel,"INVENTORY AUTOMATION – each client controls its own toggles",18,-294,500,"GameFontNormal")
    addText(panel,"AUTO SELL: LOCKED (unmark synchronization unsafe)",18,-313,480,"GameFontNormal")
    addCheck(panel,"AUTO REPAIR using own funds","autoRepair",14,-344,"inventory")
    addCheck(panel,"Forward incoming whispers to trusted leader (private)","whisperForward",14,-375,"root")
    addButton(panel,"Bind DELETE (only if free)",18,-410,238,bindDelete)
    addButton(panel,"SHARE UI TO PARTY",277,-410,232,function()
        H.ShareUI()
    end)
    addText(panel,"SHARE sends frame size, scale, position, options; private settings remain local.",17,-445,500)
    addText(panel,"One integrated aura renderer; original Alpha 3 code is the base.",17,-466,500)
    addButton(panel,"Close",355,-490,140,function() panel:Hide() end)
    refresh=function()
        if not H.db then return end
        for _,entry in ipairs(checks) do
            local t=entry.area=="inventory" and H.db.inventory or entry.area=="root" and H.db or H.db.ui
            entry.b:SetChecked(t[entry.key])
        end
        auraSize:SetText(tostring(H.db.ui.auraSize).." px (+2)")
        frameSize:SetText(tostring(H.db.ui.partyWidth).." px (+25)")
    end
    panel:SetScript("OnShow",refresh)
end
function H.OpenOptions()
    if not H.db then return end
    if not panel then createOptions() end
    panel:Show()
    panel:Raise()
end
H.OnReady(function()
    -- In-game original /hb options remains unchanged; A4 has its own /hb4 options.
end)
