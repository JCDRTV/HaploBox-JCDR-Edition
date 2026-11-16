-- JCDR Edition / TB19.1m MVP: Smart Follow and BOX-aware Druid spell presets.
-- This panel NEVER casts, follows or trades, nor modifies somebody else's macro.
-- F3/F5/F6/NUM1 are legacy bindings, NOT modified here.
-- BOX ON spell macros assist/heal party1 directly; Blizzard Focus remains untouched.
-- Blizzard actions still require the user's real keypress/click, and writes stay OOC.
local HB=HaploBox
local panel, rows, tabs, notice, page, pending = nil, {}, {}, nil, "box", nil

local BOX={
    {id="follow", name="HB Smart Follow", title="F1 - Smart Follow", key="F1"},
}
-- Small proof-of-concept collection. More classes/spells only after real tests.
-- BOX ON: assist Mael for DPS, heal Mael for party1. BOX OFF: ordinary /cast.
local SMART={
    DRUID={
        {id="wrath", name="HB Wrath", title="Wrath - DPS (assist Mael)", spell="Wrath", kind="assist"},
        {id="moonfire", name="HB Moonfire", title="Moonfire - DPS (assist Mael)", spell="Moonfire", kind="assist"},
        {id="rejuvenation", name="HB Rejuvenation", title="Rejuvenation - heal Mael", spell="Rejuvenation", kind="party1"},
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
    if section=="spells" then return SMART[myClass()] or {} end
    return BOX
end
local function preset(id)
    for _,row in ipairs(BOX) do if row.id==id then return row end end
    for _,row in ipairs(SMART[myClass()] or {}) do
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
    local key=HB.UnitIdent and HB.UnitIdent("player")
    key=key and HB.Norm and HB.Norm(key)
    local list=key and HB.db and HB.db.boxMacros and HB.db.boxMacros[key]
    local managed=list and list[entry.name]
    if not managed then return false,index end
    local expected=managed.applied=="on" and managed.onBody or managed.offBody
    if managed.applied=="legacy" then expected=managed.legacyBody end
    local ok,body=pcall(GetMacroBody,index)
    return ok and body==expected,index
end
function HB.EnsureMacroPreset(id)
    local entry=preset(id)
    if not entry then say("Macro not available in this test menu.") return false end
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
        if not own then
            say(entry.name.." exists but is not an unchanged HaploBox-managed macro. Not overwritten.")
            return false
        end
        say(entry.name.." already exists; no changes made.")
        return true
    end
    if not HB.AddBoxSpell then say("BOX spell support not loaded.") return false end
    local result=HB.AddBoxSpell(entry.spell,entry.kind)
    local nowOwned=ownedMatch(entry)
    if not result or not nowOwned then
        say("Could not create "..entry.name.."; inspect Blizzard macro slots.")
        return false
    end
    say(entry.name.." created. BOX ON/OFF switches its body outside combat.")
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
    if inCombat() then say("Drag macros after combat.") return false end
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
    tabs.spells:SetEnabled(page~="spells")
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
    if page=="spells" then
        local token=myClass() or "UNKNOWN"
        notice:SetText(#entries==0 and ("Nog geen slimme spells voor "..token..".") or
            "Slimme spells: BOX ON = assist/heal Mael; BOX OFF = gewoon casten. Maak + Pak op.")
    else
        notice:SetText("F1 volgt volgens Direct/Dungeon en is actief bij BOX ON. Toets vervangen alleen na akkoord.")
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
    tabs.spells=button(panel,"Slimme spells",144,26,146,-48,function()page="spells";refresh()end)
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
    foot:SetText("Testversie: alleen lokale macro's. Geen Share-to-Party of automatische casts.")
    foot:SetTextColor(0.64,0.70,0.78)
    panel:Hide()
end
function HB.OpenMacroMenu()
    createPanel()
    if panel:IsShown() then panel:Hide() else panel:Show();refresh() end
end
