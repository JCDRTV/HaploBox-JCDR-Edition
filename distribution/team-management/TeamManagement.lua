-- HF26.20.56 TEST - local explicit trust, live party and role management.
local HB=HaploBox
local T={}
HB.TeamManagement=T
local roles={tank="TANK",healer="HEALER",dps="DAMAGER"}
local reverse={TANK="tank",HEALER="healer",DAMAGER="dps"}
local legacyA={mael="mael ashgrove",lyra="lyra ashgrove",elya="elya ashgrove",nyra="nyra ashgrove",ayla="ayla ashgrove"}
local db,frame,refreshUI,pendingRole
local approvalKey,view,page=nil,"active",1
local function notice(s) if HB.print then HB.print(s) else print(s) end end
local function val(v) if not (issecretvalue and issecretvalue(v)) then return v end end
local function api(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b=pcall(fn,...)
    if ok then return val(a),val(b) end
end
local function norm(n) return HB.Norm and HB.Norm(n) end
local function clean(n)
    return type(n)=="string" and not n:find("[%c|;=]") and n~="" and n or nil
end
local function yes(v) return v==true or v==1 end
local function locked() return InCombatLockdown and InCombatLockdown() end
local function init()
    if not HB.db then return false end
    if type(HB.db.teamManagement)~="table" then HB.db.teamManagement={} end
    db=HB.db.teamManagement
    for _,k in ipairs({"trusted","revoked","saved","roles"}) do
        if type(db[k])~="table" then db[k]={} end
    end
    db.schema=1
    return true
end
local function legacyTrusted(name)
    local key=norm(name)
    if not key then return false end
    for item in tostring(HB.db and HB.db.trustedMembers or ""):gmatch("[^,]+") do
        local n=norm(item)
        if n==key or (legacyA[n] and legacyA[n]==key) then return true end
    end
    return false
end
local function trusted(m)
    if not m or not m.guid or not init() then return false end
    if m.unit=="player" then return true end
    if db.revoked[m.guid] then return false end
    local entry=db.trusted[m.guid]
    return type(entry)=="table" or legacyTrusted(m.name)
end
local function party()
    local members,ids,seen,leader={}, {},{},nil
    if IsInRaid and IsInRaid() then return members,nil,nil,"raid" end
    local group=IsInGroup and IsInGroup()
    local expected=group and api(GetNumGroupMembers) or 1
    for i=0,4 do
        local u=i==0 and "player" or "party"..i
        if i==0 or (group and UnitExists and UnitExists(u)) then
            local guid=clean(api(UnitGUID,u))
            local name=clean(api(HB.UnitIdent,u))
            if not guid or not name or seen[guid] then return members,nil,nil,"pending" end
            seen[guid]=true
            local m={unit=u,guid=guid,name=name,online=i==0 or yes(api(UnitIsConnected,u))}
            m.native=reverse[api(UnitGroupRolesAssigned,u)]
            local isLead=api(UnitIsGroupLeader,u)
            if isLead==nil then isLead=api(UnitIsPartyLeader,u) end
            if yes(isLead) or (i==0 and not group) then
                if leader then return members,nil,nil,"pending" end
                leader=m
            end
            members[#members+1]=m;ids[#ids+1]=guid
        end
    end
    if type(expected)=="number" and expected~=#members then return members,nil,nil,"pending" end
    table.sort(ids)
    if not leader then return members,nil,nil,"pending" end
    return members,table.concat(ids,";"),leader,group and "party" or "solo"
end
function T.GetActiveTeam()
    local members,key,leader,state=party()
    for _,m in ipairs(members) do m.trusted=trusted(m) end
    return {members=members,key=key,leader=leader,state=state}
end
function T.GetLeaderUnit()
    local _,_,leader=party()
    return leader and leader.unit
end
-- Stable DISPLAY order only. Unit tokens are still resolved by live identity.
-- Preserve the existing Team A order after the leader; other teams sort by name.
local teamARank={["mael ashgrove"]=1,["lyra ashgrove"]=2,["elya ashgrove"]=3,["nyra ashgrove"]=4,["ayla ashgrove"]=5,
    mael=1,lyra=2,elya=3,nyra=4,ayla=5}
local function sortDisplay(members,leader)
    local allA=#members>0
    for _,m in ipairs(members) do if not teamARank[norm(m.name)] then allA=false end end
    table.sort(members,function(a,b)
        if a.guid==b.guid then return false end
        if leader and a.guid==leader.guid then return true end
        if leader and b.guid==leader.guid then return false end
        local an,bn=norm(a.name) or a.name,norm(b.name) or b.name
        if allA and teamARank[an]~=teamARank[bn] then return teamARank[an]<teamARank[bn] end
        if an==bn then return a.guid<b.guid end
        return an<bn
    end)
    return members
end
function T.GetDisplayMembers()
    local members,key,leader,state=party()
    if state~="party" or not key or not leader then return nil end
    return sortDisplay(members,leader)
end
local oldTeamOrder=HB.TeamOrder
HB.TeamOrder=function()
    local members=T.GetDisplayMembers()
    if members then
        local out={}
        for _,m in ipairs(members) do out[#out+1]=m.name end
        return out
    end
    return oldTeamOrder and oldTeamOrder() or {}
end
local oldAmLeader,oldGroupLeader=HB.IAmLeader,HB.GroupLeader
HB.IAmLeader=function()
    if IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) then
        return T.GetLeaderUnit()=="player"
    end
    return oldAmLeader and oldAmLeader() or false
end
HB.GroupLeader=function()
    if IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) then
        local _,_,leader=party()
        return leader and leader.name
    end
    return oldGroupLeader and oldGroupLeader()
end
function T.GetReadySignature()
    local members,key,leader,state=party()
    if state~="party" or not key or #members<2 or #members>5 then
        return nil,state=="pending" and "pending" or "outside"
    end
    for _,m in ipairs(members) do
        if not trusted(m) then return nil,"outside" end
        if not m.online then return nil,"incomplete" end
    end
    return key.."|"..leader.guid,"ready"
end
local function memberByName(name)
    local key=norm(name)
    if not key then return nil end
    local found
    for _,m in ipairs((T.GetActiveTeam()).members) do
        -- Sender names and displayed names can differ on Forever.
        -- Match only actual API aliases from the current roster, never a
        -- guessed first-name prefix. Ambiguous aliases are rejected.
        local short=api(GetUnitName,m.unit,false)
        local first,realm=api(UnitName,m.unit)
        local full,fullRealm=api(UnitFullName,m.unit)
        local aliases={m.name,short or "",first or "",full or ""}
        if first and realm and realm~="" then aliases[#aliases+1]=first.."-"..realm end
        if full and fullRealm and fullRealm~="" then aliases[#aliases+1]=full.."-"..fullRealm end
        local match=false
        for _,alias in ipairs(aliases) do if alias~="" and norm(alias)==key then match=true;break end end
        if match then
            if found and found.guid~=m.guid then return nil end
            found=m
        end
    end
    return found
end
function T.ResolvePartyMember(name)
    return memberByName(name)
end
function T.IsLeaderName(name)
    local m=memberByName(name)
    return m~=nil and trusted(m) and T.GetLeaderUnit()==m.unit
end
function T.IsTrustedName(name)
    if not init() then return false end
    local m=memberByName(name)
    if m then return trusted(m) end
    local n=norm(name)
    if not n then return false end
    for guid,entry in pairs(db.trusted) do
        if type(entry)=="table" and norm(entry.name)==n then return not db.revoked[guid] end
    end
    for _,entry in pairs(db.revoked) do if type(entry)=="string" and norm(entry)==n then return false end end
    return legacyTrusted(name)
end
function T.IsTrustedPartyMember(name)
    local m=memberByName(name)
    return m~=nil and trusted(m)
end
-- C_PartyInfo takes a unit token; the legacy global takes a character name.
-- Only a deliberate local click can promote. Verify via the roster event.
local oldPromote=HB.PromoteName
HB.PromoteName=function(name)
    local m=memberByName(name)
    if not m or m.unit=="player" or not HB.IAmLeader() or locked() then return false end
    local fn=C_PartyInfo and C_PartyInfo.PromoteToLeader
    if type(fn)=="function" then
        local ok,result=pcall(fn,m.unit)
        if ok and result~=false then
            notice("Requested party leader: "..m.name)
            return true
        end
    end
    if type(PromoteToLeader)=="function" then
        local ok,result=pcall(PromoteToLeader,m.name)
        if ok and result~=false then notice("Requested party leader: "..m.name);return true end
    end
    notice("WoW rejected the leader switch. Use the native party menu.")
    return false
end
local function reconcile()
    if HB.AutoBoxReconcile then HB.AutoBoxReconcile() end
    if refreshUI then refreshUI() end
end
function T.ApproveParty(expectedKey)
    if locked() or not init() then return false,"Wait until after combat." end
    local members,key,leader,state=party()
    if not expectedKey or expectedKey~=key or state~="party" or #members<2 then
        return false,"Party changed or is incomplete."
    end
    for _,m in ipairs(members) do
        db.trusted[m.guid]={name=m.name}
        db.revoked[m.guid]=nil
    end
    notice("Party approved locally. Approve on each of your own clients once.")
    reconcile()
    return true
end
function T.Revoke(guid)
    if not init() or locked() then return false end
    if guid==api(UnitGUID,"player") then return false end
    local rec=db.trusted[guid]
    local name=rec and rec.name
    if not name then
        for _,m in ipairs((T.GetActiveTeam()).members) do if m.guid==guid then name=m.name end end
    end
    db.revoked[guid]=name or true;db.trusted[guid]=nil
    reconcile()
    return true
end
local function currentRole(m)
    if not init() then return m.native end
    return db.roles[m.guid] or (HB.RoleOf and HB.RoleOf(m.name)) or m.native
end
local function updateNative(m,role,key)
    if m.unit~="player" then return true end
    if locked() then pendingRole={guid=m.guid,role=role,key=key};return false end
    if not UnitSetRole then notice("WoW role API unavailable; HaploBox role saved.");return false end
    local ok,result=pcall(UnitSetRole,"player",roles[role])
    if not ok or result==false then
        notice("HaploBox role saved; WoW rejected role update.")
        return false
    end
    return true
end
local function applyRole(m,role,key)
    if not roles[role] or not init() then return false end
    db.roles[m.guid]=role
    if HB.SetRoleLocal then HB.SetRoleLocal(m.name,role) end
    updateNative(m,role,key)
    if HB.RefreshTeam and not locked() then HB.RefreshTeam() end
    if HB.PrepareSmartFollow and not locked() then HB.PrepareSmartFollow() end
    if refreshUI then refreshUI() end
    return true
end
function T.ApplyOwnRole()
    local members,key=party()
    local m=members[1]
    if not m or not roles[currentRole(m)] then notice("Select your role in Team Management first.");return false end
    if locked() then notice("Set your role after combat.");return false end
    return applyRole(m,currentRole(m),key)
end
function T.SetRole(guid,role)
    if not init() or locked() or not roles[role] then return false end
    local members,key,leader,state=party()
    local target
    for _,m in ipairs(members) do if m.guid==guid then target=m end end
    if not target then return false end
    local ready=T.GetReadySignature()
    if target.unit~="player" and (not leader or leader.unit~="player" or not ready) then
        notice("Only the leader of an approved party can assign other roles.");return false
    end
    if not applyRole(target,role,key) then return false end
    if state=="party" and ready and HB.SendTeamMessage then
        HB.SendTeamMessage("TM|R|"..guid..":"..role)
    end
    return true
end
local function saveTeam(name,remote)
    if not init() or locked() then return false end
    local members,key,leader,state=party()
    if not T.GetReadySignature() or not leader then notice("Approve the entire active party first.");return false end
    if not remote and leader.unit~="player" then notice("Only the party leader saves/syncs a team.");return false end
    name=clean(name)
    if not name or #name>48 then notice("Enter a team name (1-48 characters).");return false end
    local list={}
    for _,m in ipairs(members) do
        list[#list+1]={guid=m.guid,name=m.name,role=currentRole(m)}
    end
    db.saved[key]={name=name,members=list}
    db.activeKey=key
    if not remote and HB.SendTeamMessage then HB.SendTeamMessage("TM|S|"..name) end
    if refreshUI then refreshUI() end
    return true
end
function T.SaveTeam(name) return saveTeam(name,false) end
function T.Receive(sender,code,arg)
    if not T.GetReadySignature() or not T.IsTrustedPartyMember(sender) or type(arg)~="string" or #arg>120 then return end
    local members,key,leader=party()
    local source=memberByName(sender)
    if not source or not leader then return end
    if code=="R" then
        local guid,role=arg:match("^([%w%-]+):(%a+)$")
        if not roles[role] then return end
        for _,m in ipairs(members) do
            if m.guid==guid and (source.guid==leader.guid or source.guid==guid) then applyRole(m,role,key);return end
        end
    elseif code=="S" and source.guid==leader.guid then saveTeam(arg,true) end
end
-- Explicit approved identities are the shared trust provider. A saved roster
-- or previously encountered character alone is never authorization.
HB.IsKnownTeam=function(name) return T.IsTrustedName(name) end
if HaploBoxA4 then
    HaploBoxA4.Known=function(name) return T.IsTrustedName(name) end
    HaploBoxA4.Trusted=function(name) return T.IsTrustedPartyMember(name) end
end
local function font(parent,text,x,y,w)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(w);f:SetJustifyH("LEFT")
    f:SetText(text);return f
end
local function button(parent,text,x,y,w,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w,24);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetText(text)
    if HB.MenuStyle then HB.MenuStyle.Button(b,"blue") end
    b:SetScript("OnClick",fn);return b
end
local rows,status,teamName,approve,save,prev,nextBtn,pagination
local function chooseView(which)
    view=which;page=1;approvalKey=nil;refreshUI()
end
local function makeFrame()
    if frame then return end
    frame=CreateFrame("Frame","HaploBoxTeamManagement",UIParent)
    frame:SetSize(650,410);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true);frame:EnableMouse(true)
    if HB.MenuStyle then HB.MenuStyle.Window(frame,30) end
    font(frame,"TEAM MANAGEMENT",14,-9,500):SetTextColor(1,0.82,0.44)
    button(frame,"X",610,-3,30,function() frame:Hide() end)
    button(frame,"Active Team",12,-38,145,function() chooseView("active") end)
    button(frame,"My Characters",165,-38,145,function() chooseView("characters") end)
    button(frame,"Saved Teams",318,-38,145,function() chooseView("saved") end)
    button(frame,"Trusted",471,-38,165,function() chooseView("trusted") end)
    status=font(frame,"",14,-71,622)
    rows={}
    for i=1,5 do
        local row=CreateFrame("Frame",nil,frame);row:SetSize(622,42)
        row:SetPoint("TOPLEFT",frame,"TOPLEFT",14,-96-(i-1)*43)
        row.title=font(row,"",0,-2,350)
        row.detail=font(row,"",0,-18,350);row.detail:SetTextColor(.65,.75,.86)
        row.roleButtons={}
        for j,role in ipairs({"tank","healer","dps"}) do
            row.roleButtons[role]=button(row,role=="tank" and "Tank" or role=="healer" and "Heal" or "DPS",355+(j-1)*61,-6,57,function()
                if row.item then T.SetRole(row.item.guid,role) end
            end)
        end
        row.action=button(row,"Revoke",543,-6,76,function()
            if view=="trusted" and row.item then T.Revoke(row.item.guid)
            elseif view=="saved" and row.item then
                local _,key=party()
                if key==row.item.key then local name=row.item.name;chooseView("active");teamName:SetText(name or "")
                else notice("Form this saved party first; active team follows the actual WoW party.") end
            end
        end)
        rows[i]=row
    end
    prev=button(frame,"<",14,-316,35,function() page=math.max(1,page-1);refreshUI() end)
    pagination=font(frame,"",58,-322,100)
    nextBtn=button(frame,">",166,-316,35,function() page=page+1;refreshUI() end)
    approve=button(frame,"Approve party",14,-352,176,function()
        local _,key=party()
        if not key then return end
        if approvalKey==key then
            approvalKey=nil
            local ok,err=T.ApproveParty(key)
            if not ok then notice(err or "Approval failed.") end
        else
            approvalKey=key;notice("Only approve your OWN characters. Click Confirm approval again on this client.")
        end
        refreshUI()
    end)
    teamName=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
    teamName:SetSize(210,24);teamName:SetPoint("TOPLEFT",frame,"TOPLEFT",211,-352)
    teamName:SetAutoFocus(false);teamName:SetMaxLetters(48)
    teamName:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    save=button(frame,"Save / Sync",435,-352,200,function() T.SaveTeam(teamName:GetText());teamName:ClearFocus() end)
    font(frame,"Approve only your own characters. Native role updates depend on the client.",14,-384,622)
    frame:SetScript("OnShow",function() refreshUI() end)
    frame:Hide()
end
refreshUI=function()
    if not frame or not frame:IsShown() or not init() then return end
    local members,key,leader,state=party()
    local signature,why=T.GetReadySignature()
    if approvalKey~=key then approvalKey=nil end
    local approved=0
    for _,m in ipairs(members) do if trusted(m) then approved=approved+1 end end
    status:SetText((db.saved[key or ""] and db.saved[key].name or "Active party").."  |  "..approved.."/"..#members.." trusted  |  "..(signature and "READY" or (why or state)))
    if HB.CharacterRegistry then HB.CharacterRegistry.Refresh() end
    local items={}
    if view=="active" then items=sortDisplay(members,leader)
    elseif view=="characters" or view=="trusted" then
        local records=HB.CharacterRegistry and HB.CharacterRegistry.GetCharacters() or {}
        local seen={}
        for _,m in ipairs(records) do
            local own=m.guid==api(UnitGUID,"player") or (not db.revoked[m.guid] and (db.trusted[m.guid] or legacyTrusted(m.name)))
            if own then items[#items+1]={guid=m.guid,name=m.name,record=m};seen[m.guid]=true end
        end
        for guid,m in pairs(db.trusted) do
            if not seen[guid] and not db.revoked[guid] then items[#items+1]={guid=guid,name=m.name} end
        end
        table.sort(items,function(a,b) return (a.name or "")<(b.name or "") end)
    else
        for k,m in pairs(db.saved) do items[#items+1]={key=k,name=m.name,members=m.members} end
        table.sort(items,function(a,b) return a.name<b.name end)
    end
    local pages=math.max(1,math.ceil(#items/5))
    page=math.max(1,math.min(page,pages))
    pagination:SetText(page.." / "..pages);prev:SetEnabled(page>1);nextBtn:SetEnabled(page<pages)
    for i,row in ipairs(rows) do
        local item=items[(page-1)*5+i]
        row.item=item;row:SetShown(item~=nil)
        if item then
            local rec=item.record or (HB.CharacterRegistry and HB.CharacterRegistry.GetCharacter(item.guid)) or {}
            local role=item.unit and currentRole(item) or db.roles[item.guid] or rec.role
            row.title:SetText((item.name or "?")..(item.unit and leader and item.guid==leader.guid and "  [Leader]" or ""))
            row.detail:SetText(view=="saved" and (#(item.members or {}).." characters") or
                ((rec.class or "?").."  Lv "..(rec.level or "?").."  "..(rec.spec or "").."  "..(role or "No role")..
                (item.unit and (trusted(item) and "  [Trusted]" or "  [Approve]") or "")))
            for r,b in pairs(row.roleButtons) do
                b:SetShown(view=="active")
                b:SetEnabled(not locked() and (item.unit=="player" or (signature and leader and leader.unit=="player")) and true or false)
                if HB.MenuStyle then HB.MenuStyle.Button(b,role==r and "green" or "blue") end
            end
            row.action:SetShown(view=="trusted" or view=="saved")
            row.action:SetText(view=="saved" and "Select" or "Revoke")
            row.action:SetEnabled(not locked() and (view=="saved" or item.guid~=api(UnitGUID,"player")))
        end
    end
    approve:SetShown(view=="active");approve:SetEnabled(state=="party" and key~=nil and not locked())
    approve:SetText(approvalKey and "Confirm approval" or "Approve party")
    teamName:SetShown(view=="active");save:SetShown(view=="active")
    save:SetEnabled(signature~=nil and leader and leader.unit=="player" and not locked() or false)
    if view=="active" and db.saved[key or ""] and not teamName:HasFocus() and teamName:GetText()=="" then teamName:SetText(db.saved[key].name) end
end
function HB.OpenTeamManagement()
    makeFrame()
    if HB.OpenQuickSubmenu then HB.OpenQuickSubmenu(frame)
    elseif frame:IsShown() then frame:Hide() else frame:Show() end
end
local previous=SlashCmdList.HAPLOBOX
SlashCmdList.HAPLOBOX=function(input)
    if (input or ""):match("^%s*teammanage%s*$") then HB.OpenTeamManagement();return end
    if (input or ""):match("^%s*macrorepair%s*$") then
        if HB.RepairExistingMacroPresets then HB.RepairExistingMacroPresets() end
        return
    end
    if (input or ""):match("^%s*boxstatus%s*$") then
        if HB.BoxSyncStatus then HB.BoxSyncStatus() end
        return
    end
    previous(input)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","PARTY_LEADER_CHANGED","PLAYER_ROLES_ASSIGNED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UNIT_CONNECTION"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event)
    if not init() then return end
    if event=="PLAYER_REGEN_ENABLED" and pendingRole then
        local saved=pendingRole;pendingRole=nil
        local members,key=party()
        if members[1] and members[1].guid==saved.guid and key==saved.key then updateNative(members[1],saved.role,key) end
    end
    if event=="PARTY_LEADER_CHANGED" or event=="GROUP_ROSTER_UPDATE" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.8,function()
                if HB.LayoutPartyFrame then HB.LayoutPartyFrame() end
                if refreshUI then refreshUI() end
            end)
        end
    end
    if refreshUI then refreshUI() end
end)
