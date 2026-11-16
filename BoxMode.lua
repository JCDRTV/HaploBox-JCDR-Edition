-- JCDR Edition TB19.1l: central BOX ON/OFF, explicit managed spell macros,
-- secure F1 preparation and per-client combat telemetry.
-- Never casts or follows from addon code. Protected edits happen ONLY out of combat.
local HB = HaploBox
local FOLLOW_MACRO = "HB Smart Follow"
local HEARTBEAT = 3
local STALE = 10
local pendingMode, pendingFollow = nil, false
local lastSentCombat, lastCombatAt = nil, -100
HB.combatState = HB.combatState or {}
HB.boxAcks = HB.boxAcks or {}

local function locked() return InCombatLockdown and InCombatLockdown() end
local function safe(v) return not (issecretvalue and issecretvalue(v)) end
local function myName() return HB.UnitIdent and HB.UnitIdent("player") end
local function norm(name) return HB.Norm and HB.Norm(name) end
local function notify(msg) if HB.print then HB.print(msg) end end
local function same(a,b)
    if not norm(a) or not norm(b) then return false end
    return norm(a)==norm(b) or
        (HB.SameTeamMember and HB.SameTeamMember(a,b)) or false
end

local function trusted(name)
    local n=norm(name)
    if not n then return false end
    for item in tostring(HB.db and HB.db.trustedMembers or ""):gmatch("[^,]+") do
        local key=norm(item)
        if key and (n==key or n:match("^([^ %%-]+)") == key) then return true end
    end
    return false
end
-- Team characters have unique first names, but Forever displays surnames.
-- Use the trusted short name for local telemetry/acks across both name forms.
local function teamKey(name)
    local n=norm(name)
    if not n then return nil end
    if trusted(name) then return n:match("^([^ %%-]+)") or n end
    return n
end
local function isTeamLeader(name)
    return IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) and
        same(name,HB.GroupLeader and HB.GroupLeader()) and trusted(name)
end
local function send(message)
    if HB.SendTeamMessage then HB.SendTeamMessage(message) end
end
local function refresh()
    if HB.RefreshControls then HB.RefreshControls() end
    if HB.RefreshHaploBar then HB.RefreshHaploBar() end
end

-- Character-specific registry: never scan/change arbitrary user macros.
local function registry()
    if not HB.db then return nil end
    HB.db.boxMacros=HB.db.boxMacros or {}
    local key=norm(myName())
    if not key then return nil end
    HB.db.boxMacros[key]=HB.db.boxMacros[key] or {}
    return HB.db.boxMacros[key]
end
local function macroIndex(name)
    if not GetMacroIndexByName then return nil end
    local ok,idx=pcall(GetMacroIndexByName,name)
    return ok and type(idx)=="number" and safe(idx) and idx>0 and idx or nil
end
local function macroBody(name)
    local id=macroIndex(name)
    if not id or not GetMacroBody then return nil end
    local ok,body=pcall(GetMacroBody,id)
    return ok and type(body)=="string" and safe(body) and body or nil
end
local function changeMacro(name,body)
    if locked() or not EditMacro or not macroIndex(name) then return false end
    local ok=pcall(EditMacro,name,nil,nil,body)
    return ok and macroBody(name)==body
end
local function buildSpell(spell,kind,on)
    local head="#showtooltip "..spell.."\n"
    if on and kind=="assist" then return head.."/assist party1\n/cast "..spell end
    if on and kind=="party1" then return head.."/cast [@party1] "..spell end
    return head.."/cast "..spell
end
local function expected(entry)
    if entry.applied=="legacy" then return entry.legacyBody end
    return entry.applied=="on" and entry.onBody or entry.offBody
end
local function updateMacros(enabled)
    local list=registry()
    if not list then return false,"No character macro registry" end
    if locked() then return false,"in combat" end
    local edits={}
    for name,entry in pairs(list) do
        local current=macroBody(name)
        if not current then return false,"Missing managed macro: "..name end
        if current~=expected(entry) then
            return false,"Macro changed outside HaploBox: "..name.." (not overwritten)"
        end
        local newBody=enabled and entry.onBody or entry.offBody
        if type(newBody)~="string" or #newBody>255 then return false,"Invalid managed macro: "..name end
        edits[#edits+1]={name=name,before=current,after=newBody,entry=entry}
    end
    local committed={}
    for _,edit in ipairs(edits) do
        if edit.before~=edit.after then
            if not changeMacro(edit.name,edit.after) then
                for i=#committed,1,-1 do
                    local previous=committed[i]
                    changeMacro(previous.name,previous.before)
                end
                return false,"Unable to update macro "..edit.name.."; rolled back"
            end
            committed[#committed+1]=edit
        end
    end
    for _,edit in ipairs(edits) do edit.entry.applied=enabled and "on" or "off" end
    return true
end
HB.UpdateBoxMacros=updateMacros

-- Generate safe, visible Blizzard macros to drag onto the ordinary action bars.
function HB.AddBoxSpell(spell,kind)
    if locked() then notify("Create spell macros after combat.") return false end
    spell=tostring(spell or ""):match("^%s*(.-)%s*$")
    kind=kind or "assist"
    if spell=="" or spell:find("[\r\n|;]") or (kind~="assist" and kind~="party1") then
        notify("Usage: /hb box spell <spell name> [assist|party1]") return false
    end
    local name="HB "..spell
    if #name>16 then notify("Macro name too long (16 characters): "..name) return false end
    local list=registry()
    if not list then return false end
    if list[name] or macroIndex(name) then
        notify("Macro already exists; nothing overwritten: "..name) return false
    end
    local offBody=buildSpell(spell,kind,false)
    local onBody=buildSpell(spell,kind,true)
    if #offBody>255 or #onBody>255 or not CreateMacro then return false end
    local ok,idx=pcall(CreateMacro,name,"INV_MISC_QUESTIONMARK",offBody,true)
    if not ok or type(idx)~="number" or idx<1 or macroBody(name)~=offBody then
        notify("Could not create character macro; check macro limits.") return false
    end
    list[name]={offBody=offBody,onBody=onBody,applied="off"}
    if HB.db.boxMode and not (HB.IAmLeader and HB.IAmLeader()) then
        local done,err=updateMacros(true)
        if not done then notify(err or "Macro update failed") end
    end
    notify("Created "..name..". Drag it from Blizzard Macros to the action bar.")
    return true
end

-- Optional, explicit migration of an existing /assist focus spell macro.
-- Preserve every other line; only replace/remove a full standalone assist line.
function HB.ImportBoxMacro(name)
    if locked() then notify("Import macros after combat.") return false end
    name=tostring(name or ""):match("^%s*(.-)%s*$")
    local list=registry()
    local body=macroBody(name)
    if not list or not body or list[name] or name==FOLLOW_MACRO then
        notify("Macro not found or already managed; no changes made.") return false
    end
    local on,off,count={}, {},0
    for line in (body.."\n"):gmatch("(.-)\n") do
        if line:lower():match("^%s*/assist%s+focus%s*$") then
            on[#on+1]="/assist party1"
            count=count+1
        else
            on[#on+1]=line
            off[#off+1]=line
        end
    end
    if count~=1 or body:lower():gsub("/assist%s+focus",""):find("@focus",1,true) then
        notify("Import only supports one plain /assist focus line (no other @focus).") return false
    end
    local onBody=table.concat(on,"\n")
    local offBody=table.concat(off,"\n")
    if #onBody>255 or #offBody>255 then notify("Macro too long.") return false end
    -- The source is deliberately NOT edited until BOX ON/OFF is explicitly changed.
    list[name]={legacyBody=body,onBody=onBody,offBody=offBody,applied="legacy"}
    notify("Imported "..name.." (unchanged until next BOX MODE update).")
    return true
end

-- Build F1's secure /follow macro from Blizzard's own role assignments.
-- This ONLY prepares a Blizzard macro, never makes the character start following.
local function followBody()
    local inert="#showtooltip\n/stopmacro"
    if not HB.db or not HB.db.boxMode or not (IsInGroup and IsInGroup()) or
       (IsInRaid and IsInRaid()) then return inert end
    if HB.IAmLeader and HB.IAmLeader() then return inert end
    if not UnitExists or not UnitExists("party1") then return inert end
    if HB.db.followMode=="direct" then return "#showtooltip\n/follow party1" end
    if HB.db.followMode~="dungeon" or not UnitGroupRolesAssigned then return inert end
    local me=UnitGroupRolesAssigned("player")
    if not safe(me) then return inert end
    if me=="HEALER" then return "#showtooltip\n/follow party1" end
    local healer,healerCount=nil,0
    for i=1,4 do
        local u="party"..i
        if UnitExists(u) then
            local ok,role=pcall(UnitGroupRolesAssigned,u)
            if ok and safe(role) and role=="HEALER" then
                healer=u
                healerCount=healerCount+1
            end
        end
    end
    if healerCount~=1 then return inert end
    return "#showtooltip\n/follow "..healer
end
function HB.PrepareSmartFollow()
    if locked() then pendingFollow=true return false end
    if not HB.db then return false end
    local body=followBody()
    local current=macroBody(FOLLOW_MACRO)
    HB.db.smartFollowOwners=HB.db.smartFollowOwners or {}
    local key=norm(myName())
    if not key then return false end
    if not current then
        if not CreateMacro then return false end
        local ok,id=pcall(CreateMacro,FOLLOW_MACRO,"INV_MISC_QUESTIONMARK",body,true)
        if not ok or not id or not macroBody(FOLLOW_MACRO) then
            notify("Could not create Smart Follow macro (check character macro limit).")
            return false
        end
    elseif current~=body then
        -- Dedicated macro only: never modify the user's original F1 macro.
        if not HB.db.smartFollowOwners[key] then
            notify("Existing 'HB Smart Follow' macro is not ours; not overwritten.")
            return false
        end
        if not changeMacro(FOLLOW_MACRO,body) then return false end
    end
    HB.db.smartFollowOwners[key]=true
    pendingFollow=false
    return true
end
function HB.InstallSmartFollowBinding(confirm)
    if locked() then notify("Bind F1 after combat.") return false end
    if not HB.PrepareSmartFollow() then return false end
    if not (GetBindingAction and SetBindingMacro and SaveBindings and GetCurrentBindingSet) then
        notify("Blizzard F1 keybinding API unavailable.") return false
    end
    local current=GetBindingAction("F1")
    if current and current~="" and current~="MACRO "..FOLLOW_MACRO and not confirm then
        notify("F1 already uses: "..current..". Type /hb followbind confirm to replace that binding.")
        return false
    end
    local ok,result=pcall(SetBindingMacro,"F1",FOLLOW_MACRO)
    if not ok or not result then notify("Cannot bind F1.") return false end
    pcall(SaveBindings,GetCurrentBindingSet())
    notify("F1 bound to HB Smart Follow. Only pressing F1 initiates follow.")
    return true
end

local function ack(code)
    send("Z|A|"..code)
end
local function localApply(enabled,remote)
    if locked() then
        pendingMode=enabled
        ack("P")
        notify("BOX mode switch queued until combat ends.")
        return false
    end
    local ok,err=updateMacros(enabled and not (HB.IAmLeader and HB.IAmLeader()))
    if not ok then
        ack("E")
        notify("BOX switch cancelled: "..tostring(err))
        return false
    end
    HB.db.boxMode=enabled
    pendingMode=nil
    HB.PrepareSmartFollow()
    refresh()
    if remote then ack(enabled and "1" or "0") end
    return true
end
function HB.SetBoxMode(enabled)
    if not HB.db then return false end
    if IsInRaid and IsInRaid() then notify("BOX mode unavailable in raids/BGs. Switch OFF after combat.") return false end
    if not (IsInGroup and IsInGroup()) or not (HB.IAmLeader and HB.IAmLeader()) then
        notify("Only the box party leader can switch BOX mode; for local OFF use /hb box localoff.")
        return false
    end
    if not trusted(myName()) then notify("Leader is not in the trusted team list.") return false end
    if locked() then notify("Switch BOX mode after combat.") return false end
    if not localApply(enabled,false) then return false end
    HB.boxAcks={}
    send("Z|"..(enabled and "1" or "0"))
    -- Detect old/unreachable followers instead of silently claiming a full sync.
    HB.boxSyncSerial=(HB.boxSyncSerial or 0)+1
    local serial=HB.boxSyncSerial
    if C_Timer and C_Timer.After then C_Timer.After(5,function()
        if HB.boxSyncSerial~=serial or not HB.IAmLeader or not HB.IAmLeader() then return end
        local missing={}
        for i=1,4 do
            local u="party"..i
            if UnitExists and UnitExists(u) then
                local name=HB.UnitIdent(u)
                if trusted(name) and HB.boxAcks[teamKey(name)]~=(enabled and "1" or "0") then
                    missing[#missing+1]=tostring(name)
                end
            end
        end
        if #missing>0 then notify("BOX sync NOT confirmed for: "..table.concat(missing,", ")) end
    end) end
    notify("BOX "..(enabled and "ON" or "OFF").." sent to your team.")
    return true
end
function HB.LocalBoxOff()
    local ok=localApply(false,false)
    if ok then notify("BOX OFF on this client (not broadcast).") end
    return ok
end
function HB.OnBoxMessage(sender,code,arg)
    if code=="?" then
        if HB.db and HB.IAmLeader and HB.IAmLeader() and isTeamLeader(myName()) then
            send("Z|"..(HB.db.boxMode and "1" or "0"))
        end
        return
    end
    if code=="A" then
        if HB.IAmLeader and HB.IAmLeader() and trusted(sender) and
           HB.IsGroupMember and HB.IsGroupMember(sender) and
           (arg=="0" or arg=="1" or arg=="P" or arg=="E") then
            HB.boxAcks[teamKey(sender)]=arg
            if arg=="E" then notify("BOX sync failed on "..sender) end
        end
        return
    end
    if (code=="1" or code=="0") and isTeamLeader(sender) then
        localApply(code=="1",true)
    end
end

local function setCombat(name,value)
    local key=teamKey(name)
    if not key then return end
    local old=HB.combatState[key]
    HB.combatState[key]={value=value,at=GetTime()}
    if not old or old.value~=value then
        if HB.OnCombatStateChanged then HB.OnCombatStateChanged() end
    end
end
function HB.OnCombatMessage(sender,code)
    if (code~="1" and code~="0") or not trusted(sender) or not HB.IsGroupMember or
       not HB.IsGroupMember(sender) then return end
    setCombat(sender,code=="1")
end
function HB.CombatState(name)
    if same(name,myName()) then
        local ok,v=pcall(UnitAffectingCombat,"player")
        if ok and safe(v) then return not not v end
    end
    local key=teamKey(name)
    local item=key and HB.combatState[key]
    if item and GetTime()-item.at < STALE then return item.value end
    return nil
end
local function pulseCombat(force)
    if not HB.db or not UnitAffectingCombat then return end
    local ok,v=pcall(UnitAffectingCombat,"player")
    if not ok or not safe(v) then return end
    v=not not v
    setCombat(myName(),v)
    if IsInGroup and IsInGroup() and (force or v~=lastSentCombat or GetTime()-lastCombatAt>HEARTBEAT) then
        lastSentCombat=v
        lastCombatAt=GetTime()
        send("C|"..(v and "1" or "0"))
    end
end
local e=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE",
    "PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","PLAYER_ROLES_ASSIGNED"}) do
    pcall(e.RegisterEvent,e,event)
end
e:SetScript("OnEvent",function(_,event)
    if not HB.db then return end
    if event=="PLAYER_LOGIN" then
        -- On login, always restore safe normal spell targeting. An explicit
        -- leader command or verified team sync can re-enable BOX mode.
        HB.db.boxMode=false
        pendingMode=nil
        local ok,err=updateMacros(false)
        if not ok then notify("BOX OFF macro restore requires attention: "..tostring(err)) end
        HB.PrepareSmartFollow()
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(0.5,function()
                pulseCombat(false)
                if HB.OnCombatStateChanged then HB.OnCombatStateChanged() end
            end)
        end
        refresh()
    elseif event=="PLAYER_REGEN_ENABLED" then
        if pendingMode~=nil then localApply(pendingMode,true) end
        if pendingFollow then HB.PrepareSmartFollow() end
        pulseCombat(true)
    elseif event=="PLAYER_REGEN_DISABLED" then
        pulseCombat(true)
    elseif event=="PLAYER_ENTERING_WORLD" or event=="GROUP_ROSTER_UPDATE" then
        -- Never carry BOX targeting into another party, solo play or a BG/raid.
        if HB.db.boxMode and (not (IsInGroup and IsInGroup()) or
            (IsInRaid and IsInRaid()) or not isTeamLeader(HB.GroupLeader and HB.GroupLeader())) then
            localApply(false,false)
        end
        HB.PrepareSmartFollow()
        pulseCombat(true)
        if IsInGroup and IsInGroup() and not (HB.IAmLeader and HB.IAmLeader()) then
            send("Z|?")
        end
    else
        HB.PrepareSmartFollow()
    end
end)
