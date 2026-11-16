-- JCDR Edition / TB19.1m MVP: local multibox macro controls and a tiny class library.
-- This panel NEVER casts, follows, trades or modifies somebody else's macro.
-- Blizzard actions still require the user's real keypress/click, and writes stay OOC.
local HB=HaploBox
local panel, rows, tabs, notice, page, pending = nil, {}, {}, nil, "box", nil

local BOX={
    {id="follow", name="HB Smart Follow", title="F1  Smart Follow", key="F1", detail="Direct/Dungeon via BOX mode"},
    {id="assist", name="HB Assist Focus", title="F3  Assist Focus", key="F3", body="#showtooltip\n/assist focus"},
    {id="focus", name="HB Focus Leader", title="F5  Focus leader", key="F5", body="#showtooltip\n/focus party1"},
    {id="clear", name="HB Clear Focus", title="F6  Clear Focus", key="F6", body="#showtooltip\n/clearfocus"},
    {id="trade", name="HB Trade Leader", title="NUM1  Trade with Mael", key="NUMPAD1", body="#showtooltip\n/run InitiateTrade(\"party1\")"},
}
local CLASS={
    DRUID={
        {id="motw", name="HB Mark Wild", title="Mark of the Wild - mouseover", body="#showtooltip Mark of the Wild\n/cast [@mouseover,help,nodead][@player] Mark of the Wild"},
        {id="thorns", name="HB Thorns", title="Thorns - mouseover", body="#showtooltip Thorns\n/cast [@mouseover,help,nodead][@player] Thorns"},
        {id="rejuv", name="HB Rejuv", title="Rejuvenation - mouseover", body="#showtooltip Rejuvenation\n/cast [@mouseover,help,nodead][help,nodead][@player] Rejuvenation"},
    },
}
local function say(message)
    if notice then notice:SetText(message) end
    if HB.print then HB.print(message) end
end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function myClass()
    if not UnitClass then return nil end
    local _,code=UnitClass("player")
    return code
end
function HB.MacroLibraryEntries(section)
    if section=="class" then return CLASS[myClass()] or {} end
    return BOX
end
local function preset(id)
    for _,row in ipairs(BOX) do if row.id==id then return row end end
    for _,row in ipairs(CLASS[myClass()] or {}) do
        if row.id==id then return row end
    end
    return nil
end
local function macroIndex(name)
    if not GetMacroIndexByName then return nil end
    local ok,index=pcall(GetMacroIndexByName,name)
    if ok and type(index)=="number" and index>0 then return index end
    return nil
end
local function ownedMatch(entry)
    local index=macroIndex(entry.name)
    if not index or not GetMacroBody then return false,index end
    if entry.id=="follow" then
        -- BoxMode.lua owns and updates this macro's body on mode/role changes.
        local key=HB.UnitIdent and HB.UnitIdent("player")
        key=key and HB.Norm and HB.Norm(key)
        return not not (key and HB.db and HB.db.smartFollowOwners
            and HB.db.smartFollowOwners[key]),index
    end
    local ok,body=pcall(GetMacroBody,index)
    return ok and body==entry.body,index
end
function HB.EnsureMacroPreset(id)
    local entry=preset(id)
    if not entry then say("Macro not available for this class.") return false end
    if inCombat() then say("Create macros after combat.") return false end
    if entry.id=="follow" then
        if not HB.PrepareSmartFollow or not HB.PrepareSmartFollow() then
            say("Smart Follow could not be prepared.") return false
        end
        say("Smart Follow prepared. Set F1 separately with the Toets button.")
        return true
    end
    local own,index=ownedMatch(entry)
    if index then
        if not own then say("Macro "..entry.name.." already exists with different text; not overwritten.") return false end
        say(entry.name.." already exists; no changes made.")
        return true
    end
    if not CreateMacro then say("Blizzard CreateMacro API unavailable.") return false end
    if #entry.name>16 or #entry.body>255 then say("Macro too long.") return false end
    local ok,created=pcall(CreateMacro,entry.name,"INV_MISC_QUESTIONMARK",entry.body,true)
    local valid=ownedMatch(entry)
    if not ok or not created or not valid then
        say("Could not create macro; check character macro limits.") return false
    end
    say(entry.name.." created as a Blizzard character macro.")
    return true
end
function HB.BindMacroPreset(id,confirm)
    local entry=preset(id)
    if not entry or not entry.key then return false end
    if inCombat() then say("Change keys after combat.") return false end
    if not HB.EnsureMacroPreset(id) then return false end
    if not (GetBindingAction and SaveBindings and GetCurrentBindingSet) then
        say("Blizzard keybinding API unavailable.") return false
    end
    local old=GetBindingAction(entry.key)
    local desired="MACRO "..entry.name
    if old and old~="" and old~=desired and not confirm then
        pending=id
        say(entry.key.." is already bound to "..tostring(old)..". Click Toets again to confirm replacement.")
        return false
    end
    local ok,result
    if entry.id=="follow" then
        if not HB.InstallSmartFollowBinding then return false end
        ok,result=pcall(HB.InstallSmartFollowBinding,true)
    else
        if not SetBindingMacro then say("Blizzard SetBindingMacro API unavailable.") return false end
        ok,result=pcall(SetBindingMacro,entry.key,entry.name)
        if ok and result then
            local savedOK,savedResult=pcall(SaveBindings,GetCurrentBindingSet())
            if not savedOK or savedResult==false then ok=false end
        end
    end
    if not ok or not result then say("Could not bind "..entry.key..".") return false end
    pending=nil
    say(entry.key.." set locally for "..entry.name..".")
    return true
end
function HB.PickupMacroPreset(id)
    local entry=preset(id)
    if not entry then return false end
    local own,index=ownedMatch(entry)
    if not own or not index then say("Click Maak first; an existing different macro is never picked up.") return false end
    if not PickupMacro then say("PickupMacro unavailable; use Blizzard Macros instead.") return false end
    local ok=pcall(PickupMacro,index)
    if not ok then say("Could not pick up macro; try the Blizzard Macros window.") return false end
    say("Macro on cursor: place it on your Blizzard action bar.")
    return true
end
local function makeText(parent,size)
    local fs=parent:CreateFontString(nil,"OVERLAY",size or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    return fs
end
local function button(parent,text,w,h,x,y,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w,h)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b:SetText(text)
    b:SetScript("OnClick",fn)
    return b
end
local function refresh()
    if not panel then return end
    pending=nil
    local entries=HB.MacroLibraryEntries(page)
    tabs.box:SetEnabled(page~="box")
    tabs.class:SetEnabled(page~="class")
    for i,r in ipairs(rows) do
        local e=entries[i]
        if e then
            r.preset=e
            r.frame:Show()
            r.label:SetText(e.title)
            local own,index=ownedMatch(e)
            r.create:SetText(index and own and "Klaar" or "Maak")
            r.create:SetEnabled(not (index and own))
            r.bind:SetShown(not not e.key)
            r.bind:SetText("Toets")
            r.pick:SetEnabled(own and not not index)
        else
            r.preset=nil
            r.frame:Hide()
        end
    end
    if page=="class" then
        local token=myClass() or "UNKNOWN"
        notice:SetText(#entries==0 and ("Nog geen testmacro's voor "..token..".") or
            "Class library ("..token.."): maak een Blizzard-macro, pak hem op en plaats hem op je skillbalk.")
    else
        notice:SetText("Multibox: Maak -> Toets (2x bij conflict). F1 werkt met BOX ON; niets volgt automatisch.")
    end
end
local function createPanel()
    if panel then return end
    panel=CreateFrame("Frame","HaploBoxMacroLibrary",UIParent)
    panel:SetSize(560,438)
    panel:SetPoint("CENTER",UIParent,"CENTER",0,0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true);panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    local bg=panel:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.07,0.09,0.13,0.98)
    local heading=makeText(panel,"GameFontNormalLarge")
    heading:SetPoint("TOPLEFT",panel,"TOPLEFT",16,-12)
    heading:SetText("HaploBox - JCDR Edition | Macro Menu (TEST)")
    button(panel,"X",30,22,514,-8,function()panel:Hide()end)
    tabs.box=button(panel,"Multibox",124,26,16,-48,function()page="box";refresh()end)
    tabs.class=button(panel,"Class macros",124,26,146,-48,function()page="class";refresh()end)
    local l=makeText(panel)
    l:SetPoint("TOPLEFT",panel,"TOPLEFT",18,-89)
    l:SetText("Functie / macro")
    for i=1,5 do
        local row=CreateFrame("Frame",nil,panel)
        row:SetSize(540,47)
        row:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-109-(i-1)*49)
        local shade=row:CreateTexture(nil,"BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(i%2==0 and 0.15 or 0.12,0.16,0.20,0.92)
        local label=makeText(row,"GameFontHighlight")
        label:SetPoint("LEFT",row,"LEFT",9,0)
        label:SetWidth(286)
        local r={frame=row,label=label}
        r.create=button(row,"Maak",63,25,301,-11,function()
            if r.preset then HB.EnsureMacroPreset(r.preset.id);refresh() end
        end)
        r.bind=button(row,"Toets",70,25,370,-11,function()
            if r.preset then
                local id=r.preset.id
                local confirm=pending==id
                HB.BindMacroPreset(id,confirm)
                -- Keep the explicit second-click confirmation on the button.
                if pending==id then r.bind:SetText("Bevestig") else refresh() end
            end
        end)
        r.pick=button(row,"Pak op",84,25,446,-11,function()
            if r.preset then HB.PickupMacroPreset(r.preset.id) end
        end)
        rows[i]=r
    end
    notice=makeText(panel)
    notice:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",16,30)
    notice:SetWidth(530)
    notice:SetWordWrap(true)
    notice:SetTextColor(0.94,0.78,0.47)
    local foot=makeText(panel)
    foot:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",16,11)
    foot:SetText("Alleen deze client. Party-sync en volledige class library volgen later.")
    foot:SetTextColor(0.64,0.70,0.78)
    panel:Hide()
end
function HB.OpenMacroMenu()
    createPanel()
    if panel:IsShown() then panel:Hide() else panel:Show();refresh() end
end
