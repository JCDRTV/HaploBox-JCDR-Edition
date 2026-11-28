-- JB26.3.0: account-first saved team planning. No live party or macro mutation.
local HB=HaploBox
local CM=HB.CharacterManagement
local T={}
HB.TeamPlanner=T
local roles={tank=true,healer=true,dps=true}
local function db()
    if not HB.db then return end
    local d=HB.db.plannedTeams
    if type(d)~="table" then d={schema=1,teams={}};HB.db.plannedTeams=d end
    if d.schema==1 and type(d.teams)=="table" then return d end
end
local function copy(t)
    if not t then return nil end
    local r={name=t.name,id=t.id,slots={}}
    for i=1,5 do
        local s=t.slots[i]
        if s then r.slots[i]={account=s.account,guid=s.guid,role=s.role} end
    end
    return r
end
local function group() return IsInGroup and IsInGroup() end
local function editable()
    if not CM.CanEdit() then return nil,"Only the leader can edit outside combat." end
    local d=db()
    if not d then return nil,"Team register unavailable." end
    return d
end
local function nameId(n)
    if type(n)~="string" then return end
    n=n:match("^%s*(.-)%s*$")
    if n=="" or #n>40 or n:find("[%c|]") then return end
    return n:lower(),n
end
function T.List()
    local d=db();local r={}
    if d then for _,t in pairs(d.teams) do r[#r+1]=copy(t) end end
    table.sort(r,function(a,b)return a.id<b.id end)
    return r
end
function T.Active()
    local d=db()
    return d and d.active and copy(d.teams[d.active])
end
function T.Get(id)
    local d=db();return d and copy(d.teams[id])
end
function T.Validate(slots)
    if type(slots)~="table" then return false,"Missing positions." end
    local accounts,guids={},{}
    local n,gap=0,false
    for i=1,5 do
        local s=slots[i]
        if not s or not s.account then
            if s and (s.guid or s.role) then return false,"Position "..i.." is incomplete." end
            gap=true
        else
            if gap then return false,"Use consecutive positions starting at 1." end
            local r=s.guid and CM.GetCharacter(s.guid)
            if not r or r.account~=s.account or not roles[s.role] then return false,"Complete account, character and role at POS "..i.."." end
            if accounts[s.account] or guids[s.guid] then return false,"Each account and character may appear only once." end
            accounts[s.account]=true;guids[s.guid]=true;n=n+1
        end
    end
    for k in pairs(slots) do if type(k)~="number" or k%1~=0 or k<1 or k>5 then return false,"Invalid position." end end
    if n<2 then return false,"A team needs 2 to 5 characters." end
    return true,n
end
local function sameMembers(a,b)
    local m={}
    for _,s in pairs(a.slots) do m[s.guid]=s.account end
    local count=0
    for _,s in pairs(b.slots) do if m[s.guid]~=s.account then return false end;m[s.guid]=nil;count=count+1 end
    return count>0 and next(m)==nil
end
function T.Save(name,slots,editingId)
    local d,e=editable();if not d then return false,e end
    local id,label=nameId(name)
    if not id then return false,"Enter a team name (1-40 characters)." end
    local ok,err=T.Validate(slots);if not ok then return false,err end
    if d.teams[id] and editingId~=id then return false,"Team name already exists; choose it to edit." end
    if editingId and (editingId~=id or not d.teams[id]) then return false,"Use New to create a differently named team." end
    local record=copy({id=id,name=label,slots=slots})
    if group() then
        local old=d.active and d.teams[d.active]
        if not old or id~=d.active or not sameMembers(old,record) then
            return false,"Leave the party before creating, switching or changing members."
        end
    end
    d.teams[id]=record;d.active=id
    return true,copy(record)
end
function T.Select(id)
    local d,e=editable();if not d then return false,e end
    if not d.teams[id] then return false,"Unknown team." end
    if group() and id~=d.active then return false,"Leave the party before switching teams." end
    local ok,err=T.Validate(d.teams[id].slots);if not ok then return false,err end
    d.active=id
    return true,copy(d.teams[id])
end
function T.Delete(id)
    local d,e=editable();if not d then return false,e end
    if group() then return false,"Leave the party before deleting a team." end
    if not d.teams[id] then return false,"Unknown team." end
    d.teams[id]=nil
    if d.active==id then d.active=nil end
    return true
end
function T.InParty()return not not group() end
-- Prevent CM edits from silently invalidating saved team membership.
local oldRemove,oldAccount=CM.RemoveCharacter,CM.SetAccount
local function used(guid)
    for _,t in ipairs(T.List()) do
        for _,s in pairs(t.slots) do if s.guid==guid then return t.name end end
    end
end
CM.RemoveCharacter=function(guid)
    local n=used(guid)
    if n then return false,"Character belongs to "..n..". Edit or delete that team first." end
    return oldRemove(guid)
end
CM.SetAccount=function(guid,id)
    local r=CM.GetCharacter(guid);local n=used(guid)
    if n and r and r.account~=id then return false,"Character belongs to "..n..". Edit that team first." end
    return oldAccount(guid,id)
end
local oldImport=CM.Import
CM.Import=function(snapshot,selection)
    for guid,id in pairs(selection or {}) do
        local r=CM.GetCharacter(guid)
        if id and r and r.account~=id and used(guid) then return false,"Remove the character from saved teams before changing account." end
    end
    return oldImport(snapshot,selection)
end

-- One explicit click; no timers, roster mutation, legacy-name fallback or auto-accept.
local invitePending={}
local function inviteSafe(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function inviteName(name)
    if type(name)~="string" or name=="" or name:find("[%c|]") then return nil end
    -- Forever's two-name identities must not be reduced to the first name.
    if not name:match("^%S+%s+%S+") then return nil end
    return name
end
function T.InvitePlan()
    local ok,allowed=pcall(CM.CanEdit)
    if not ok or not allowed then return nil,"Only the actual party leader can invite outside combat." end
    local team=T.Active()
    if not team then return nil,"Select and save a team in Management first." end
    local valid,err=T.Validate(team.slots)
    if not valid then return nil,err end
    local rosterOK,roster,why=pcall(CM.Snapshot,false)
    if not rosterOK or not roster or type(roster.rows)~="table" then return nil,why or "Party roster unavailable; try again." end
    local guidOK,me=pcall(UnitGUID,"player")
    me=guidOK and inviteSafe(me) or nil
    if type(me)~="string" or me=="" then return nil,"Your character identity is unavailable." end
    local planned,present={},{}
    for _,s in pairs(team.slots) do planned[s.guid]=s end
    if not planned[me] then return nil,"Your character is not in the active team." end
    for _,r in ipairs(roster.rows) do
        if not planned[r.guid] then return nil,"Party contains a character outside the active team. No invitations sent." end
        present[r.guid]=true
        invitePending[r.guid]=nil
    end
    if not present[me] then return nil,"Party roster unavailable; try again." end
    local knownNames={}
    for _,r in ipairs(CM.GetCharacters()) do
        local n=inviteName(r.name)
        if n then
            local k=n:lower()
            knownNames[k]=(knownNames[k] or 0)+1
        end
    end
    local targets={}
    for i=1,5 do
        local s=team.slots[i]
        if s and not present[s.guid] then
            local r=CM.GetCharacter(s.guid)
            local name=r and inviteName(r.name)
            if not name or knownNames[name:lower()]~=1 then return nil,"Missing or ambiguous full character name at POS "..i.."." end
            targets[#targets+1]={guid=s.guid,name=name}
        end
    end
    return targets,team.name
end
function T.InviteActive()
    local targets,message=T.InvitePlan()
    if not targets then return false,message end
    if #targets==0 then return true,"All members of "..message.." are already in the party." end
    local fn=C_PartyInfo and C_PartyInfo.InviteUnit
    if type(fn)~="function" then fn=InviteUnit end
    if type(fn)~="function" then return false,"WoW invite API unavailable." end
    local now=GetTime and GetTime()
    local sent,skipped,failed=0,0,{}
    for _,r in ipairs(targets) do
        if type(now)=="number" and invitePending[r.guid] and now-invitePending[r.guid]<20 then
            skipped=skipped+1
        else
            local ok,result=pcall(fn,r.name)
            if ok and inviteSafe(result)~=false then
                sent=sent+1
                if type(now)=="number" then invitePending[r.guid]=now end
            else
                failed[#failed+1]=r.name
            end
        end
    end
    local summary=message..": "..sent.." invite request(s) sent."
    if skipped>0 then summary=summary.." "..skipped.." recently requested; wait 20 seconds before retrying." end
    if #failed>0 then summary=summary.." API rejected: "..table.concat(failed,", ").."." end
    return #failed==0,summary
end
