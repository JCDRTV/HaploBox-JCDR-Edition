-- JCDR Edition / TB19.1n DEVELOPMENT: Macro Menu, active keybinding UI and
-- class spell cards. Blizzard actions always need explicit hardware input.
-- Existing personal macros and bindings are never overwritten silently.
local HB=HaploBox
local panel,notice,content,footer,tabButtons,rows,spellCards,selectedSpell
local page="box"
local waiting,conflict=nil,nil
local BOX={
    {id="follow",name="HB Smart Follow",title="Smart Follow",kind="follow"},
    {id="assist",name="HB Assist",title="Assist",kind="boxassist"},
    {id="trade",name="HB Trade",title="Trade with Leader",kind="trade"},
}
-- Curated, conservative Druid presets. The game client must still validate
-- that a spell is actually known before the macro is created.
local SMART={DRUID={
    {id="wrath",name="HB Wrath",title="Wrath",spell="Wrath",kind="assist"},
    {id="moonfire",name="HB Moonfire",title="Moonfire",spell="Moonfire",kind="assist"},
    {id="starfire",name="HB Starfire",title="Starfire",spell="Starfire",kind="assist"},
    {id="roots",name="HB Entangle",title="Entangling Roots",spell="Entangling Roots",kind="assist"},
    {id="hibernate",name="HB Hibernate",title="Hibernate",spell="Hibernate",kind="assist"},
    {id="rejuvenation",name="HB Rejuvenation",title="Rejuvenation",spell="Rejuvenation",kind="heal"},
    {id="regrowth",name="HB Regrowth",title="Regrowth",spell="Regrowth",kind="heal"},
    {id="healingtouch",name="HB Healing Touch",title="Healing Touch",spell="Healing Touch",kind="heal"},
    {id="mark",name="HB Mark",title="Mark of the Wild",spell="Mark of the Wild",kind="buff"},
    {id="thorns",name="HB Thorns",title="Thorns",spell="Thorns",kind="buff"},
    {id="removecurse",name="HB Remove Curse",title="Remove Curse",spell="Remove Curse",kind="buff"},
    {id="abolish",name="HB Abolish Poison",title="Abolish Poison",spell="Abolish Poison",kind="buff"},
}}
local function me() return UnitClass and select(2,UnitClass("player")) end
local function locked() return InCombatLockdown and InCombatLockdown() end
local function say(message)
    if notice then notice:SetText(message) end
    if HB.print then HB.print(message) end
end
local function keyFor(name)
    if not GetBindingKey then return nil,nil end
    local ok,a,b=pcall(GetBindingKey,"MACRO "..name)
    if ok then return a,b end
end
local function macroIndex(name)
    if not GetMacroIndexByName then return nil end
    local ok,idx=pcall(GetMacroIndexByName,name)
    if ok and type(idx)=="number" and idx>0 then return idx end
end
local function myRegistry()
    local key=HB.Norm and HB.UnitIdent and HB.Norm(HB.UnitIdent("player"))
    return key and HB.db and HB.db.boxMacros and HB.db.boxMacros[key]
end
local function owned(entry)
    local idx=macroIndex(entry.name)
    if not idx then return false,nil end
    if entry.id=="follow" then
        local key=HB.Norm and HB.UnitIdent and HB.Norm(HB.UnitIdent("player"))
        return (key and HB.db and HB.db.smartFollowOwners and HB.db.smartFollowOwners[key]) and true or false,idx
    end
    local reg=myRegistry()
    local item=reg and reg[entry.name]
    if not item or not GetMacroBody then return false,idx end
    local ok,body=pcall(GetMacroBody,idx)
    local valid=ok and (body==item.offBody or body==item.onBody or
        body==item.leaderBody or body==item.legacyBody)
    return not not valid,idx
end
local function allEntries()
    return page=="box" and BOX or (SMART[me()] or {})
end
local function preset(id)
    for _,entry in ipairs(BOX) do if entry.id==id then return entry end end
    for _,entry in ipairs(SMART[me()] or {}) do if entry.id==id then return entry end end
end
function HB.MacroLibraryEntries(section)
    if section=="spells" then return SMART[me()] or {} end
    return BOX
end
local function spellKnown(entry)
    if not entry.spell then return true end
    if IsSpellKnown and GetSpellInfo then
        -- On clients with no reliable spell rank IDs do not claim unavailable.
        local ok,id=pcall(GetSpellInfo,entry.spell)
        return not not (ok and id)
    end
    return true
end
function HB.EnsureMacroPreset(id)
    local entry=preset(id)
    if not entry then say("Preset not available in this menu.") return false end
    if locked() then say("Create macros after combat.") return false end
    if entry.kind=="follow" then
        if not HB.PrepareSmartFollow or not HB.PrepareSmartFollow() then
            say("Could not prepare Smart Follow.") return false end
        say("Smart Follow ready. Bind a key in this menu.")
        return true
    end
    local exists,idx=owned(entry)
    if idx then
        if not exists then say(entry.name.." exists but is not an unchanged HB macro. Not overwritten.") return false end
        say(entry.name.." already exists.")
        return true
    end
    if not spellKnown(entry) then say("Spell not available on this character: "..entry.title) return false end
    local ok
    if entry.spell then ok=HB.AddBoxSpell and HB.AddBoxSpell(entry.spell,entry.kind,entry.name)
    else ok=HB.AddBoxAction and HB.AddBoxAction(entry.id) end
    if not ok then say("Could not create "..entry.name) return false end
    say(entry.name.." created.")
    return true
end
function HB.PickupMacroPreset(id)
    if locked() then say("Pick up macros after combat.") return false end
    local entry=preset(id)
    if not entry then return false end
    local own,idx=owned(entry)
    if not own or not idx then say("Create the HB macro first; personal macros are untouched.") return false end
    if not PickupMacro then say("Blizzard PickupMacro API unavailable.") return false end
    local ok=pcall(PickupMacro,idx)
    if not ok then say("Could not pick up macro.") return false end
    say("Macro on cursor. Place it on a Blizzard action bar.")
    return true
end

local function bindKey(entry,slot,key,confirm)
    if locked() then say("Change bindings after combat.") return false end
    if not SetBindingMacro or not SaveBindings or not GetCurrentBindingSet or not GetBindingAction then
        say("Blizzard binding API unavailable.") return false end
    if not HB.EnsureMacroPreset(entry.id) then return false end
    local first,second=keyFor(entry.name)
    local old=(slot==1 and first or second)
    if key=="" then
        if not old then return true end
        if not SetBinding or not SetBinding(old) then say("Unable to clear binding.") return false end
        SaveBindings(GetCurrentBindingSet());return true
    end
    local action=GetBindingAction(key)
    if action and action~="" and action~="MACRO "..entry.name and not confirm then
        conflict={id=entry.id,slot=slot,key=key}
        say(key.." is assigned to "..tostring(action)..". Click the same key box again to CONFIRM replacement.")
        return false
    end
    -- Preserve a secondary binding if the primary changes (and vice versa).
    local success=SetBindingMacro(key,entry.name)
    if not success then say("Cannot bind "..key) return false end
    if old and old~=key and SetBinding then SetBinding(old) end
    SaveBindings(GetCurrentBindingSet())
    conflict=nil
    say(entry.title.." bound to "..key.." on this client.")
    return true
end
local function namedButton(parent,text,x,y,w,h,handler)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w,h);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b:SetText(text)
    b:SetScript("OnClick",handler)
    return b
end
local function label(parent,text,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetWidth(width or 300);f:SetJustifyH("LEFT")
    f:SetText(text or "")
    return f
end
local function roundIcon(parent,x,y,size)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(size,size);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b.tex=b:CreateTexture(nil,"ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    return b
end
local function setIcon(tex,entry)
    if not entry or not entry.spell then return end
    local texture
    if GetSpellInfo then
        local ok,_,_,art=pcall(GetSpellInfo,entry.spell)
        if ok then texture=art end
    end
    if texture then tex:SetTexture(texture) end
end
local function resetPlacement()
    if not panel then return end
    panel:ClearAllPoints()
    local bar=HB.GetHaploBarFrame and HB.GetHaploBarFrame()
    if bar then panel:SetPoint("TOP",bar,"BOTTOM",0,-7)
    else panel:SetPoint("TOP",UIParent,"TOP",0,-48) end
end
local function setPage(which)
    page=which;waiting=nil;conflict=nil
    if HB.RefreshMacroMenu then HB.RefreshMacroMenu() end
end
local function makeKeyButton(parent,entry,slot,x,y)
    local b=namedButton(parent,"Not Bound",x,y,93,23,function(self)
        if conflict and conflict.id==entry.id and conflict.slot==slot then
            bindKey(entry,slot,conflict.key,true)
            conflict=nil
            if HB.RefreshMacroMenu then HB.RefreshMacroMenu() end
            return
        end
        conflict=nil
        if not panel then return end
        waiting={entry=entry,slot=slot}
        say("Press a key for "..entry.title.." (ESC cancels; BACKSPACE removes binding).")
        panel:EnableKeyboard(true)
        if panel.SetPropagateKeyboardInput then panel:SetPropagateKeyboardInput(false) end
        if panel.SetKeyboardFocus then panel:SetKeyboardFocus() end -- optional API
        self:SetText("Press key...")
    end)
    b.entry,b.slot=entry,slot
    return b
end
local function refreshKeyWidgets(row,entry)
    local first,second=keyFor(entry.name)
    row.key1:SetText(first or "Not Bound")
    row.key2:SetText(second or "Not Bound")
end
local function makePanel()
    if panel then return end
    panel=CreateFrame("Frame","HaploBoxMacroLibrary",UIParent)
    panel:SetSize(700,530);panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true);panel:SetMovable(true);panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    panel:SetScript("OnHide",function(self)
        self:EnableKeyboard(false)
        waiting=nil;conflict=nil
    end)
    panel:SetScript("OnKeyDown",function(self,key)
        local w=waiting
        if not w then return end
        waiting=nil;self:EnableKeyboard(false)
        if key=="ESCAPE" then say("Keybinding cancelled.")
        else
            local value=key
            if key=="BACKSPACE" or key=="DELETE" then value=""
            elseif key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then
                say("Modifier alone is not a keybinding. Try a combination.")
                HB.RefreshMacroMenu();return
            else
                if IsControlKeyDown and IsControlKeyDown() then value="CTRL-"..value end
                if IsAltKeyDown and IsAltKeyDown() then value="ALT-"..value end
                if IsShiftKeyDown and IsShiftKeyDown() then value="SHIFT-"..value end
            end
            bindKey(w.entry,w.slot,value,false)
        end
        HB.RefreshMacroMenu()
    end)
    panel:EnableKeyboard(false)
    local bg=panel:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints();bg:SetColorTexture(0.07,0.09,0.13,0.98)
    local heading=label(panel,"HaploBox - JCDR Edition | Macro Menu",16,-16,520)
    heading:SetTextColor(1,0.83,0.32)
    namedButton(panel,"X",654,-7,30,22,function() panel:Hide() end)
    tabButtons={}
    tabButtons.box=namedButton(panel,"Multibox",16,-48,130,25,function()setPage("box")end)
    tabButtons.spells=namedButton(panel,"Smart Spells",155,-48,140,25,function()setPage("spells")end)
    content=CreateFrame("Frame",nil,panel)
    content:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-83)
    content:SetSize(674,376)
    rows={}
    label(content,"FUNCTION",10,-3,200)
    label(content,"PRIMARY KEY",300,-3,100)
    label(content,"SECONDARY KEY",402,-3,130)
    for i,entry in ipairs(BOX) do
        local y=-24-(i-1)*55
        local row=CreateFrame("Frame",nil,content)
        row:SetSize(674,50);row:SetPoint("TOPLEFT",content,"TOPLEFT",0,y)
        local fill=row:CreateTexture(nil,"BACKGROUND")
        fill:SetAllPoints();fill:SetColorTexture(0.12,0.16,0.21,0.93)
        row.title=label(row,entry.title,10,-18,240)
        row.key1=makeKeyButton(row,entry,1,290,-12)
        row.key2=makeKeyButton(row,entry,2,395,-12)
        row.create=namedButton(row,"Create",505,-12,71,23,function()
            HB.EnsureMacroPreset(entry.id);HB.RefreshMacroMenu()
        end)
        row.pick=namedButton(row,"Pick Up",582,-12,78,23,function()
            HB.PickupMacroPreset(entry.id)
        end)
        rows[i]=row
    end
    local roleY=-24-3*55
    label(content,"Set Role",10,roleY-10,120)
    local roles={"Tank","Healer","DPS"}
    rows.roleButtons={}
    for i,role in ipairs(roles) do
        local b=namedButton(content,role,195+(i-1)*110,roleY-5,102,24,function()
            if HB.SetMyRoleFromMenu then HB.SetMyRoleFromMenu(role:lower()) end
            HB.RefreshMacroMenu()
        end)
        rows.roleButtons[i]=b
    end
    rows.roleCurrent=label(content,"Current: Unknown",10,roleY-34,260)
    rows.roleCurrent:SetTextColor(0.73,0.82,0.91)
    -- Separate, explicit opt-in configuration sync. No key broadcasts.
    rows.sync=namedButton(content,"Sync Team",10,-258,125,25,function()
        if HB.RequestMacroSync then HB.RequestMacroSync() end
    end)
    rows.syncOpt=namedButton(content,"Allow Sync: OFF",145,-258,142,25,function()
        HB.db.allowMacroSync=not HB.db.allowMacroSync
        HB.RefreshMacroMenu()
    end)
    rows.reset=namedButton(content,"Clean HB Macros",300,-258,150,25,function()
        if HB.ResetOwnedMacros then HB.ResetOwnedMacros(false) end
    end)
    -- Spell grid: never creates a macro on selection. A deliberate Create
    -- button below the grid uses one Blizzard macro slot per chosen preset.
    spellCards={}
    for i=1,12 do
        local c=roundIcon(content,10+((i-1)%6)*110,-16-math.floor((i-1)/6)*130,54)
        c.name=label(content,"",10+((i-1)%6)*110,-75-math.floor((i-1)/6)*130,100)
        c.name:SetWordWrap(true)
        c:SetScript("OnClick",function()
            selectedSpell=c.entry
            HB.RefreshMacroMenu()
        end)
        spellCards[i]=c
    end
    rows.spellSelection=label(content,"Select a spell icon above.",10,-294,355)
    rows.spellCreate=namedButton(content,"Create",380,-290,85,25,function()
        if selectedSpell then HB.EnsureMacroPreset(selectedSpell.id) end
        HB.RefreshMacroMenu()
    end)
    rows.spellPick=namedButton(content,"Pick Up",472,-290,85,25,function()
        if selectedSpell then HB.PickupMacroPreset(selectedSpell.id) end
    end)
    notice=label(panel,"",16,-464,665)
    notice:SetWordWrap(true);notice:SetTextColor(0.95,0.79,0.48)
    footer=label(panel,"Local actions require a key press. No auto-casting or input broadcast.",16,-507,668)
    footer:SetTextColor(0.63,0.70,0.77)
    panel:Hide()
end
function HB.RefreshMacroMenu()
    if not panel then return end
    tabButtons.box:SetEnabled(page~="box")
    tabButtons.spells:SetEnabled(page~="spells")
    local showBox=page=="box"
    for i,row in ipairs(rows) do
        row:SetShown(showBox)
        if showBox then
            local entry=BOX[i]
            refreshKeyWidgets(row,entry)
            local yes=owned(entry)
            row.create:SetText(yes and "Ready" or "Create")
            row.create:SetEnabled(not yes)
            row.pick:SetEnabled(yes)
        end
    end
    for _,b in ipairs(rows.roleButtons) do b:SetShown(showBox) end
    rows.roleCurrent:SetShown(showBox)
    rows.sync:SetShown(showBox);rows.syncOpt:SetShown(showBox);rows.reset:SetShown(showBox)
    if showBox then
        rows.roleCurrent:SetText("Current role: "..tostring(HB.MyRole and HB.MyRole() or "Unknown"))
        rows.syncOpt:SetText("Allow Sync: "..(HB.db and HB.db.allowMacroSync and "ON" or "OFF"))
    end
    local entries=SMART[me()] or {}
    for i,c in ipairs(spellCards) do
        c:SetShown(not showBox and not not entries[i])
        c.name:SetShown(not showBox and not not entries[i])
        local entry=entries[i]
        if entry then
            c.entry=entry
            c.name:SetText(entry.title)
            setIcon(c.tex,entry)
            c.tex:SetVertexColor(selectedSpell==entry and 1 or 0.78,selectedSpell==entry and 1 or 0.78,selectedSpell==entry and 1 or 0.78)
        end
    end
    rows.spellSelection:SetShown(not showBox)
    rows.spellCreate:SetShown(not showBox)
    rows.spellPick:SetShown(not showBox)
    if not showBox then
        local entry=selectedSpell
        local yes=entry and owned(entry)
        rows.spellSelection:SetText(entry and (entry.title.."  |  "..(yes and "Ready" or "Not created")) or "Select a spell icon above.")
        rows.spellCreate:SetEnabled(entry and not yes)
        rows.spellPick:SetEnabled(not not yes)
    end
end
function HB.OpenMacroMenu()
    makePanel()
    if panel:IsShown() then panel:Hide();panel:EnableKeyboard(false);waiting=nil;return end
    resetPlacement()
    panel:Show();HB.RefreshMacroMenu()
end

-- Leader-initiated configuration transfer, never action execution. Follower
-- explicitly opts in before any managed macro or key is created. No overwrite
-- of occupied bindings; collisions remain local and are reported to leader.
local function trustedLeader(sender)
    if not HB.db or not HB.GroupLeader or not HB.Norm then return false end
    if not (IsInGroup and IsInGroup()) then return false end
    if IsInRaid and IsInRaid() then return false end
    local leader=HB.GroupLeader()
    return leader and HB.Norm(sender)==HB.Norm(leader) and
        (not HB.IsGroupMember or HB.IsGroupMember(sender))
end
function HB.RequestMacroSync()
    if not HB.IAmLeader or not HB.IAmLeader() or not (IsInGroup and IsInGroup()) then
        say("Only the party leader can sync macros.") return false
    end
    if not HB.SendTeamMessage then return false end
    HB.macroSyncStatus={sent=0,confirmed={}}
    local n=0
    local box=BOX
    local spells=SMART[me()] or {}
    for _,collection in ipairs({box,spells}) do
        for _,entry in ipairs(collection) do
            local yes=owned(entry)
            if yes then
                HB.SendTeamMessage("K|P|"..entry.id)
                local first,second=keyFor(entry.name)
                if first or second then
                    HB.SendTeamMessage("K|B|"..entry.id..":"..(first or "-")..":"..(second or "-"))
                end
                n=n+1
            end
        end
    end
    HB.macroSyncStatus={sent=n,confirmed={}}
    say("Requested "..n.." managed presets on opted-in followers; wait for ACKs.")
    return true
end
function HB.OnMacroSyncMessage(sender,code,arg)
    if code=="A" then
        if HB.IAmLeader and HB.IAmLeader() and HB.IsGroupMember and HB.IsGroupMember(sender) then
            HB.macroSyncStatus=HB.macroSyncStatus or {sent=0,confirmed={}}
            HB.macroSyncStatus.confirmed[HB.Norm(sender)..":"..tostring(arg)]=true
            say("Macro sync response from "..tostring(sender)..": "..tostring(arg))
            if arg and (arg:find(":error",1,true) or arg:find(":consent-needed",1,true)) then
                HB.boxSyncError=true
                say("Macro sync issue from "..tostring(sender)..": "..tostring(arg))
            end
        end
        return
    end
    if code~="P" and code~="B" then return end
    if not trustedLeader(sender) then return end
    if not HB.db.allowMacroSync then
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..tostring(arg)..":consent-needed") end
        return
    end
    if locked() then
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..tostring(arg)..":combat") end
        return
    end
    local id,two,three
    if code=="P" then id=arg else
        id,two,three=tostring(arg or ""):match("^([%w]+):([%w%-]+):([%w%-]+)$")
    end
    local entry=preset(id)
    if not entry then return end -- never accept remote arbitrary macros
    if code=="P" then
        local ok=HB.EnsureMacroPreset(id)
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..id..(ok and ":ok" or ":error")) end
    else
        local ok=true
        for slot,key in ipairs({two,three}) do
            if key and key~="-" then
                local used=GetBindingAction and GetBindingAction(key)
                if used and used~="" and used~="MACRO "..entry.name then
                    ok=false -- avoid replacing follower's own bindings
                elseif not bindKey(entry,slot,key,false) then ok=false end
            end
        end
        if HB.SendTeamMessage then HB.SendTeamMessage("K|A|"..id..(ok and ":bindings-ok" or ":error")) end
    end
end
-- Explicitly accessible from the console in case a follower needs to opt in
-- while its normal UI is suppressed by Mini Heal.
function HB.SetMacroSyncAllowed(on)
    if not HB.db then return end
    HB.db.allowMacroSync=not not on
    if HB.RefreshMacroMenu then HB.RefreshMacroMenu() end
end
