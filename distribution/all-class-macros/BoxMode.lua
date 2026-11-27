-- JCDR Edition TB19.1l: central BOX ON/OFF, explicit managed spell macros,
-- secure F1 preparation and per-client combat telemetry.
-- Never casts or follows from addon code. Protected edits happen ONLY out of combat.
local HB = HaploBox
local FOLLOW_MACRO = "HB Smart Follow"
-- HF2 diagnostic: state changes are sent immediately; send a periodic safety
-- heartbeat only every 30s, not every 3s, to isolate reported 3s game hitches.
-- Keep the last confirmed remote combat state long enough between heartbeats.
local HEARTBEAT = 30
local STALE = 75
local pendingMode, pendingFollow = nil, false
-- The last locally verified macro profile. A repeated identical leader sync
-- needs an ACK, not another complete EditMacro/GetMacroBody/RefreshControls pass.
local validatedMode = nil
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
-- WoW/its macro editor can persist a generated macro with CRLF line endings,
-- harmless trailing spaces or a final newline.  Textual identity of an owned
-- generated macro must therefore use semantic-line normalization, not raw bytes.
-- Never ignore any command, condition, argument or extra executable line.
local function normalizedBody(body)
    if type(body)~="string" then return nil end
    return body:gsub("\r\n", "\n"):gsub("\r", "\n")
        :gsub("[ \t]+\n", "\n"):gsub("[ \t\n]+$", "")
end
local function sameBody(a,b)
    return type(a)=="string" and type(b)=="string" and normalizedBody(a)==normalizedBody(b)
end
HB.SameMacroBody=sameBody

local function changeMacro(name,body)
    if locked() or not EditMacro or not macroIndex(name) then return false end
    local ok=pcall(EditMacro,name,nil,nil,body)
    return ok and sameBody(macroBody(name),body)
end
-- The leader has a deliberately distinct profile. In particular @party1 on the
-- leader is a follower, NOT the leader. Never let his heals fall back to it.
local function buildSpell(spell,kind,profile)
    local head="#showtooltip "..spell.."\n"
    if kind=="assist" then
        if profile=="on" then return head.."/assist party1\n/cast "..spell end
        return head.."/cast "..spell
    elseif kind=="party1" then
        return profile=="on" and (head.."/cast [@party1] "..spell) or (head.."/cast "..spell)
    elseif kind=="heal" then
        if profile=="on" then
            return head.."/cast [mod:shift,@player][@mouseover,help,nodead][@party1,help,nodead] "..spell
        elseif profile=="leader" then
            return head.."/cast [mod:shift,@player][@mouseover,help,nodead][@target,help,nodead][@player] "..spell
        end
        return head.."/cast [mod:shift,@player][@mouseover,help,nodead][] "..spell
    elseif kind=="buff" then
        return head.."/cast [mod:shift,@player][@mouseover,help,nodead][@target,help,nodead][@player] "..spell
    elseif kind=="dual" then
        -- Dual-purpose spells (e.g. Dispel Magic, Holy Shock) preserve
        -- the player's deliberate friendly or hostile target.
        return head.."/cast [mod:shift,@player][@mouseover,help,nodead][@mouseover,harm,nodead][@target,help,nodead][@target,harm,nodead] "..spell
    elseif kind=="cast" then
        return head.."/cast "..spell
    elseif kind=="revive" then
        return head.."/cast [@mouseover,help,dead][@target,help,dead] "..spell
    elseif kind=="role" then
        -- Preserved Team A preset supplied by the user; manual keypress only.
        return '/run local n=UnitName("player");local r=n=="Mael" and "TANK" or n=="Lyra" and "HEALER" or "DAMAGER";if not InCombatLockdown() then UnitSetRole("player",r) end'
    elseif kind=="boxassist" then
        return profile=="on" and ("#showtooltip\n/assist party1") or "#showtooltip\n/stopmacro"
    elseif kind=="trade" then
        -- The /trade command requires a deliberate physical button press.
        -- No automatic trade acceptance, inventory, or money operations.
        return profile=="on" and ("#showtooltip\n/target party1\n/trade\n/targetlasttarget") or "#showtooltip\n/stopmacro"
    end
    return head.."/cast "..spell
end
local function desiredProfile(enabled)
    return (HB.IAmLeader and HB.IAmLeader()) and "leader" or (enabled and "on" or "off")
end
-- Read-only Spellbook tooltip preview. This uses the SAME generator and live
-- leader/follower profile as the real managed macro, never a static example.
function HB.PreviewBoxSpell(spell,kind)
    if type(spell)~="string" or spell=="" then return nil end
    return buildSpell(spell,kind or "cast",desiredProfile(HB.db and HB.db.boxMode))
end
local function knownBody(entry,body)
    -- A legitimate macro can be in a previous profile after /reload. Accept
    -- ALL exactly generated variants, but never silently overwrite user edits.
    if type(entry)~="table" then return false end
    if sameBody(body,entry.offBody) or sameBody(body,entry.onBody) or
        sameBody(body,entry.leaderBody) or sameBody(body,entry.legacyBody) then
        return true
    end
    -- Old TB19.1m records may carry a stale applied/body marker. For strictly
    -- generated, already-owned spell macros, recognize the actual historical
    -- deterministic templates as well. Never do this for imported macros.
    if entry.legacyBody or type(entry.spell)~="string" or entry.spell=="" or
       (entry.kind~="assist" and entry.kind~="party1" and
        entry.kind~="heal" and entry.kind~="buff" and
        entry.kind~="cast" and entry.kind~="revive" and entry.kind~="dual") then return false end
    return sameBody(body,buildSpell(entry.spell,entry.kind,"off")) or
        sameBody(body,buildSpell(entry.spell,entry.kind,"on")) or
        sameBody(body,buildSpell(entry.spell,entry.kind,"leader"))
end
local function updateMacros(enabled)
    local list=registry()
    if not list then return false,"No character macro registry" end
    if locked() then return false,"in combat" end
    local edits,stale={},{ }
    local profile=desiredProfile(enabled)
    for name,entry in pairs(list) do
        if not entry.leaderBody then
            local spell=entry.spell or name:match("^HB (.+)$")
            local kind=entry.kind or (spell=="Rejuvenation" or spell=="Regrowth" or spell=="Healing Touch") and "heal" or "assist"
            -- Only infer spells for canonical generated records, never imports.
            if not entry.legacyBody and type(spell)=="string" then
                entry.spell,entry.kind=spell,kind
                entry.leaderBody=buildSpell(spell,kind,"leader")
            end
        end
        local current=macroBody(name)
        if not current then
            -- A deleted macro cannot be restored by registry state alone. It
            -- is safe to forget an ownership record for an absent macro.
            stale[#stale+1]=name
        elseif not knownBody(entry,current) then
            HB.lastBoxMismatch={name=name,body=current,
                onBody=entry.onBody,offBody=entry.offBody,leaderBody=entry.leaderBody}
            return false,"Macro changed outside HaploBox: "..name.." (not overwritten)"
        else
            local nextBody=(profile=="leader" and (entry.leaderBody or entry.offBody)) or
                (profile=="on" and entry.onBody) or entry.offBody
            if type(nextBody)~="string" or #nextBody>255 then return false,"Invalid managed macro: "..name end
            edits[#edits+1]={name=name,before=current,after=nextBody,entry=entry}
        end
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
    for _,name in ipairs(stale) do list[name]=nil end
    for _,edit in ipairs(edits) do edit.entry.applied=profile end
    HB.lastBoxMismatch=nil
    return true
end
HB.UpdateBoxMacros=updateMacros

-- HF26.20.16: Explicit, safe recovery for existing canonical Smart Spell
-- macros after a missing/stale SavedVariables ownership registry.  This is
-- only called from a real Macro Menu click, never an automatic roster sync.
-- An unowned macro is adopted ONLY if its current full command body matches
-- one of the exact generated variants for that spell/kind. Custom and imported
-- macros remain untouched. Do not repair the unrelated macros in the registry.
function HB.EnsureKnownBoxSpell(name,spell,kind)
    if locked() then return false,"Try again after combat." end
    if type(name)~="string" or type(spell)~="string" or
       type(kind)~="string" or #name>16 or not name:match("^HB [%w ]+$") or
       spell=="" or spell:find("[\r\n|;]") or
       (kind~="assist" and kind~="party1" and kind~="heal" and
        kind~="buff" and kind~="cast" and kind~="revive" and kind~="dual") then
        return false,"Invalid spell preset."
    end
    local list=registry()
    local current=macroBody(name)
    if not list or not current then return false,"Macro not found: "..name end
    local off=buildSpell(spell,kind,"off")
    local on=buildSpell(spell,kind,"on")
    local leader=buildSpell(spell,kind,"leader")
    local record=list[name]
    -- Never commandeer a user-imported macro, even if the text happens to
    -- resemble a generated spell preset. Imported bodies belong to users.
    if record and record.legacyBody then
        return false,"Imported macro is protected: "..name
    end
    local canonical=sameBody(current,off) or sameBody(current,on) or sameBody(current,leader)
    if not canonical then
        return false,"Existing "..name.." is not a standard HB spell macro; not overwritten. Check /macro."
    end
    -- If a record exists, it must refer to the same known preset. The macro
    -- itself is checked above so we can recover a missing old registry safely.
    if record and ((record.spell and record.spell~=spell) or
                   (record.kind and record.kind~=kind)) then
        return false,"Macro registry mismatch: "..name.."; not overwritten."
    end
    local profile=desiredProfile(HB.db and HB.db.boxMode)
    local desired=(profile=="on" and on) or (profile=="leader" and leader) or off
    if not sameBody(current,desired) and not changeMacro(name,desired) then
        return false,"Unable to sync "..name.." to "..profile.." profile."
    end
    list[name]={spell=spell,kind=kind,offBody=off,onBody=on,
        leaderBody=leader,applied=profile}
    return true
end
-- Read-only diagnostic for any mismatch that remains after safe normalization.
-- Useful when Blizzard or another addon silently re-formats the body.
function HB.BoxMacroInspect()
    local list=registry()
    if not list then notify("BOX inspect: no registry") return end
    local total,unknown=0,0
    for name,entry in pairs(list) do
        total=total+1
        local current=macroBody(name)
        local state=not current and "MISSING" or knownBody(entry,current) and "KNOWN" or "UNKNOWN"
        if state=="UNKNOWN" then unknown=unknown+1 end
        notify("BOX inspect "..name..": "..state.."; "..tostring(current and #current or 0).." bytes; off="..
            tostring(entry.offBody and #entry.offBody or 0)..", on="..
            tostring(entry.onBody and #entry.onBody or 0)..", leader="..
            tostring(entry.leaderBody and #entry.leaderBody or 0))
        if state=="UNKNOWN" then
            -- Line breaks shown literally for easy screenshot, without touching content.
            local preview=tostring(current):gsub("\r","<CR>"):gsub("\n"," | ")
            notify("BOX inspect current "..name..": "..preview:sub(1,240))
        end
    end
    notify("BOX inspect complete: "..total.." registered, "..unknown.." unknown; no changes made.")
end

-- Generate safe, visible Blizzard macros to drag onto the ordinary action bars.
function HB.AddBoxSpell(spell,kind,requestedName)
    if locked() then notify("Create spell macros after combat.") return false end
    spell=tostring(spell or ""):match("^%s*(.-)%s*$")
    kind=kind or "assist"
    if spell=="" or spell:find("[\r\n|;]") or (kind~="assist" and kind~="party1" and kind~="heal" and kind~="buff" and kind~="cast" and kind~="revive" and kind~="dual") then
        notify("Usage: /hb box spell <spell name> [assist|party1|heal|buff]") return false
    end
    local name=requestedName or ("HB "..spell)
    if type(name)~="string" or not name:match("^HB [%w ]+$") then return false end
    if #name>16 then notify("Macro name too long (16 characters): "..name) return false end
    local list=registry()
    if not list then return false end
    if list[name] and not macroIndex(name) then list[name]=nil end
    if list[name] or macroIndex(name) then
        notify("Macro already exists; nothing overwritten: "..name) return false
    end
    local offBody=buildSpell(spell,kind,"off")
    local onBody=buildSpell(spell,kind,"on")
    local leaderBody=buildSpell(spell,kind,"leader")
    if #offBody>255 or #onBody>255 or #leaderBody>255 or not CreateMacro then return false end
    local profile=desiredProfile(HB.db and HB.db.boxMode)
    local initial=(profile=="on" and onBody) or (profile=="leader" and leaderBody) or offBody
    local ok,idx=pcall(CreateMacro,name,"INV_MISC_QUESTIONMARK",initial,true)
    if not ok or type(idx)~="number" or idx<1 or not sameBody(macroBody(name),initial) then
        notify("Could not create character macro; check macro limits.") return false
    end
    list[name]={spell=spell,kind=kind,offBody=offBody,onBody=onBody,leaderBody=leaderBody,applied=profile}
    notify("Created "..name.." ("..profile.."). Drag it from Blizzard Macros to the action bar.")
    return true
end


-- Dedicated multibox actions, kept distinct from the class spell library.
function HB.AddBoxAction(id)
    if locked() then notify("Create action macros after combat.") return false end
    if id~="assist" and id~="trade" and id~="role" then return false end
    local name=id=="assist" and "HB Assist" or id=="role" and "HB Set Role" or "HB Trade"
    local list=registry()
    if not list then return false end
    if list[name] and not macroIndex(name) then list[name]=nil end
    if list[name] or macroIndex(name) then
        notify("Macro already exists; nothing overwritten: "..name) return false
    end
    local kind=id=="assist" and "boxassist" or id=="role" and "role" or "trade"
    local offBody=buildSpell("",kind,"off")
    local onBody=buildSpell("",kind,"on")
    if not CreateMacro then return false end
    local ok,idx=pcall(CreateMacro,name,"INV_MISC_QUESTIONMARK",offBody,true)
    if not ok or type(idx)~="number" or idx<1 or not sameBody(macroBody(name),offBody) then return false end
    list[name]={kind=kind,spell="",onBody=onBody,offBody=offBody,leaderBody=offBody,applied="off"}
    local done,err=updateMacros(HB.db.boxMode)
    if not done then notify(err or "Action macro update failed") end
    notify("Created "..name)
    return true
end

-- Explicit opt-in reset: only known, unchanged HB macros are removed. Any
-- personally edited or unknown macro survives. Keybindings are not touched.
function HB.ResetOwnedMacros(confirm)
    if not confirm then notify("Use /hb macros reset confirm to remove only unchanged HaploBox macros.") return false end
    if locked() then notify("Reset macros after combat.") return false end
    local list=registry()
    if not list or not DeleteMacro then return false end
    local removed,skipped=0,0
    for name,entry in pairs(list) do
        local current=macroBody(name)
        if not current then list[name]=nil
        elseif knownBody(entry,current) then
            local ok=pcall(DeleteMacro,name)
            if ok and not macroIndex(name) then list[name]=nil removed=removed+1 else skipped=skipped+1 end
        else skipped=skipped+1 end
    end
    -- Smart Follow is also HB-owned, but never delete a different macro that
    -- happens to share its name. Its live body must be a known generated form.
    local key=norm(myName())
    local follow=macroBody(FOLLOW_MACRO)
    local normalized=normalizedBody(follow)
    local knownFollow=normalized=="#showtooltip\n/stopmacro" or
        (type(normalized)=="string" and (
            normalized:match("^#showtooltip\n/follow party[1-4]$") or
            normalized:match("^#showtooltip\n/follow party[1-4]\n/run HaploBox%.SmartFollowCamera%(%)$")
        ))
    if follow and knownFollow and key and HB.db.smartFollowOwners and HB.db.smartFollowOwners[key] then
        local ok=pcall(DeleteMacro,FOLLOW_MACRO)
        if ok and not macroIndex(FOLLOW_MACRO) then
            HB.db.smartFollowOwners[key]=nil
            removed=removed+1
        else skipped=skipped+1 end
    elseif follow then skipped=skipped+1 end
    notify("HB reset: "..removed.." unchanged macros removed, "..skipped.." modified/blocked kept. Bindings kept.")
    if HB.RefreshMacroMenu then HB.RefreshMacroMenu() end
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

-- Camera is invoked by the same real F1 hardware macro after Blizzard /follow.
-- This extra /run only sets an explicitly calibrated LOCAL follower view;
-- it never casts, follows, changes target selection, or touches Mael's camera.
local function followMacroFor(unit)
    return "#showtooltip\n/follow "..unit.."\n/run HaploBox.SmartFollowCamera()"
end
-- Build F1's secure /follow macro from Blizzard's own role assignments.
-- This ONLY prepares a Blizzard macro, never makes the character start following.
local function followBody()
    local inert="#showtooltip\n/stopmacro"
    if not HB.db or not HB.db.boxMode or not (IsInGroup and IsInGroup()) or
       (IsInRaid and IsInRaid()) then return inert end
    if HB.IAmLeader and HB.IAmLeader() then return inert end
    if not UnitExists or not UnitExists("party1") then return inert end
    if HB.db.followMode=="direct" then return followMacroFor("party1") end
    if HB.db.followMode~="dungeon" or not UnitGroupRolesAssigned then return inert end
    local me=UnitGroupRolesAssigned("player")
    if not safe(me) then return inert end
    if me=="HEALER" then return followMacroFor("party1") end
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
    return followMacroFor(healer)
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
    elseif not sameBody(current,body) then
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
    local ok,err=updateMacros(enabled)
    if not ok then
        validatedMode=nil
        HB.boxSyncError=true
        ack("E")
        notify("BOX switch cancelled: "..tostring(err))
        return false
    end
    HB.db.boxMode=enabled
    validatedMode=enabled
    HB.boxSyncError=false
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
    HB.boxSyncError=false
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
        if #missing>0 then
            HB.boxSyncError=true
            notify("BOX sync NOT confirmed for: "..table.concat(missing,", "))
            refresh()
        end
    end) end
    notify("BOX "..(enabled and "ON" or "OFF").." sent to your team.")
    return true
end
function HB.LocalBoxOff()
    local ok=localApply(false,false)
    if ok then notify("BOX OFF on this client (not broadcast).") end
    return ok
end
-- TB19.1t-HF1: A fresh login/reload or a newly formed trusted five-toon party
-- should become ready without requiring a manual BOX SYNC. Keep manual BOX OFF
-- for the rest of an unchanged party session. Only the explicit trusted team
-- may use automatic BOX targeting; strangers, raids, and solo play never do.
local autoTeamKey, autoTeamDone = nil, false
local function trustedTeamSignature()
    if not (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) then
        return nil, "outside"
    end
    local names, seen = {}, {}
    for i=0,4 do
        local unit=i==0 and "player" or "party"..i
        if not (UnitExists and UnitExists(unit)) then return nil, "incomplete" end
        local name=HB.UnitIdent and HB.UnitIdent(unit)
        if not name then return nil, "pending" end
        if not trusted(name) then return nil, "outside" end
        local key=teamKey(name)
        if not key or seen[key] then return nil, "outside" end
        names[#names+1]=key
        seen[key]=true
    end
    local leader=HB.GroupLeader and HB.GroupLeader()
    if not leader then return nil, "pending" end
    if not trusted(leader) or not seen[teamKey(leader)] then return nil, "outside" end
    table.sort(names)
    return table.concat(names, ",").."|"..teamKey(leader), "ready"
end
function HB.AutoBoxReconcile()
    if not HB.db then return false end
    local signature, state=trustedTeamSignature()
    if state~="ready" then
        if state=="outside" or state=="incomplete" then
            autoTeamKey, autoTeamDone=nil, false
            if HB.db.boxMode and not locked() then localApply(false,false) end
        end
        return false
    end
    if signature~=autoTeamKey then
        autoTeamKey, autoTeamDone=signature, false
    end
    if autoTeamDone then
        if HB.PrepareSmartFollow then HB.PrepareSmartFollow() end
        return true
    end
    if locked() then return false end  -- PLAYER_REGEN_ENABLED retries
    local ok
    if HB.IAmLeader and HB.IAmLeader() then
        ok=HB.SetBoxMode(true)
    else
        ok=localApply(true,true)
    end
    if ok then autoTeamDone=true end
    return not not ok
end
local function scheduleAutoBox(delay)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.8,function()
            if HB.AutoBoxReconcile then HB.AutoBoxReconcile() end
        end)
    end
end
local function confirmedBoxAcks()
    if not (HB.IAmLeader and HB.IAmLeader()) then return false end
    local signature,state=trustedTeamSignature()
    if state~="ready" then return false end
    local wanted=HB.db and HB.db.boxMode and "1" or "0"
    for i=1,4 do
        local name=HB.UnitIdent and HB.UnitIdent("party"..i)
        if not name or HB.boxAcks[teamKey(name)]~=wanted then return false end
    end
    return true
end
-- Manual recovery lives in the technical Options panel, never Quick Menu.
function HB.RefreshBoxSync()
    if not HB.boxSyncError then return false end
    local signature,state=trustedTeamSignature()
    if state~="ready" then
        notify("REFRESH SYNC requires all five trusted team members in one party.")
        return false
    end
    if locked() then notify("REFRESH SYNC after combat.") return false end
    if HB.IAmLeader and HB.IAmLeader() then
        return HB.SetBoxMode(true)
    end
    -- Recheck *only* the local owned macros, then request the leader's mode.
    -- Never clear a genuine mismatch by only hiding the ERROR label.
    local ok=localApply(true,true)
    if ok then send("Z|?") end
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
            if arg=="E" then
                HB.boxSyncError=true
                notify("BOX sync failed on "..sender)
                refresh()
            elseif (arg=="0" or arg=="1") and confirmedBoxAcks() then
                -- A late but complete round of acknowledgements resolves a
                -- timeout without requiring the player to flip BOX OFF/ON.
                HB.boxSyncError=false
                refresh()
            end
        end
        return
    end
    if (code=="1" or code=="0") and isTeamLeader(sender) then
        local wanted=(code=="1")
        if validatedMode==wanted and HB.db and HB.db.boxMode==wanted and pendingMode==nil then
            -- Idempotent response, even while in combat: no protected edits,
            -- no expensive macro/UI pass, but the leader still gets an ACK.
            ack(code)
        else
            localApply(wanted,true)
        end
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
e:SetScript("OnEvent",HB.Diag.WrapEvent("BoxMode event",function(_,event)
    if not HB.db then return end
    if event=="PLAYER_LOGIN" then
        -- On login, always restore safe normal spell targeting. An explicit
        -- leader command or verified team sync can re-enable BOX mode.
        HB.db.boxMode=false
        pendingMode=nil
        validatedMode=nil
        local ok,err=updateMacros(false)
        if not ok then
            HB.boxSyncError=true
            notify("BOX OFF macro restore requires attention: "..tostring(err))
        else
            HB.boxSyncError=false
            validatedMode=false
        end
        HB.PrepareSmartFollow()
        if C_Timer and C_Timer.NewTicker then
            local lastCombatPaint=-100
            C_Timer.NewTicker(0.5,HB.Diag.Wrap("BoxMode 0.5s",function()
                pulseCombat(false)
                -- Combat transitions already repaint immediately in setCombat.
                -- Repaint aging/offline indicators only every five seconds.
                local now=GetTime()
                if now-lastCombatPaint>=5 then
                    lastCombatPaint=now
                    if HB.OnCombatStateChanged then HB.OnCombatStateChanged() end
                end
            end))
        end
        refresh()
        autoTeamKey, autoTeamDone=nil, false
        scheduleAutoBox(2.0)
    elseif event=="PLAYER_REGEN_ENABLED" then
        if pendingMode~=nil then localApply(pendingMode,true) end
        if pendingFollow then HB.PrepareSmartFollow() end
        if HB.AutoBoxReconcile then HB.AutoBoxReconcile() end
        pulseCombat(true)
    elseif event=="PLAYER_REGEN_DISABLED" then
        pulseCombat(true)
    elseif event=="PLAYER_ENTERING_WORLD" or event=="GROUP_ROSTER_UPDATE" then
        -- Reconcile safe saved macro variants with the current team role even
        -- if BOX is OFF; the group leader may be determined after PLAYER_LOGIN.
        if not locked() then
            local ok,err=updateMacros(HB.db.boxMode)
            if not ok then
                validatedMode=nil
                HB.boxSyncError=true
                notify("BOX macro restore needs repair: "..tostring(err))
            else
                validatedMode=HB.db.boxMode
            end
            if ok and not HB.db.boxMode and not HB.boxSyncError then
                -- A clean local OFF macro is not proof that the leader has
                -- received the other clients' ACKs. Keep a real error visible.
                refresh()
            end
        end
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
        scheduleAutoBox(0.8)
    else
        HB.PrepareSmartFollow()
    end
end))
