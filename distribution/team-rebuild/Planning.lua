-- HF26.20.60 phase 1: independent, pure data model. No party or macro APIs.
local P={}
HaploBoxPlanning=P
local roles={TANK=true,HEALER=true,DPS=true}
local function trim(s)
    if type(s)~="string" then return "" end
    return (s:gsub("^%s+",""):gsub("%s+$",""))
end
local function field(s,max)
    s=trim(s)
    if s=="" or #s>max or s:find("[%c|]") then return nil end
    return s
end
local function copy(t)
    if type(t)~="table" then return t end
    local out={}
    for k,v in pairs(t) do out[k]=copy(v) end
    return out
end
local function key(name,realm)
    return name:lower():gsub("%s+"," ").."|"..realm:lower():gsub("[%s']","")
end
local function sortRecords(map)
    local list={}
    for _,v in pairs(map) do list[#list+1]=copy(v) end
    table.sort(list,function(a,b)
        local an,bn=a.name:lower(),b.name:lower()
        if an==bn then return a.id<b.id end
        return an<bn
    end)
    return list
end
function P.New(db)
    if type(db)~="table" then return nil,"Invalid planning database." end
    if db.schema~=nil and db.schema~=1 then return nil,"Unsupported planning database schema." end
    db.schema=1
    db.characters=db.characters or {}
    db.teams=db.teams or {}
    db.nextCharacter=db.nextCharacter or 0
    db.nextTeam=db.nextTeam or 0
    local M={}
    function M.GetCharacters() return sortRecords(db.characters) end
    function M.GetCharacter(id) return copy(db.characters[id]) end
    function M.SaveCharacter(input,id)
        if type(input)~="table" then return nil,"Missing character." end
        local name,realm=field(input.name,100),field(input.realm,100)
        local account,race,class=field(input.account,80),field(input.race,60),field(input.class,60)
        local level=tonumber(input.level)
        local guid=field(input.guid,100)
        if not (name and realm and account and race and class and level and level>=1 and level<=255 and level%1==0) then
            return nil,"Enter name, realm, account alias, race, class and a valid level."
        end
        local identity=key(name,realm)
        local existing=id and db.characters[id]
        if id and not existing then return nil,"Character not found." end
        local match
        for cid,c in pairs(db.characters) do
            if c.key==identity or (guid and c.guid==guid) then
                if match and match~=cid then return nil,"Conflicting character identities." end
                match=cid
            end
        end
        if id and match and id~=match then return nil,"Character is already registered." end
        if not id and match then
            if not guid then return nil,"Already registered. Select the existing character to edit." end
            id=match;existing=db.characters[id]
        end
        if existing and existing.guid and guid and existing.guid~=guid then return nil,"GUID conflict." end
        if existing and existing.key~=identity and not (guid and existing.guid==guid) then
            return nil,"Identity cannot change without a matching live GUID."
        end
        -- An account change must not make any saved team invalid.
        if id then
            for _,team in pairs(db.teams) do
                local contains=false
                for pos=1,5 do if team.slots[pos] and team.slots[pos].characterId==id then contains=true end end
                if contains then
                    for pos=1,5 do
                        local slot=team.slots[pos]
                        local other=slot and db.characters[slot.characterId]
                        if other and other.id~=id and other.account:lower()==account:lower() then
                            return nil,"Account change conflicts with a saved team."
                        end
                    end
                end
            end
        end
        if not id then
            repeat db.nextCharacter=db.nextCharacter+1;id="c"..db.nextCharacter until not db.characters[id]
        end
        local c={id=id,key=identity,name=name,realm=realm,account=account,race=race,class=class,level=level,guid=guid or (existing and existing.guid)}
        db.characters[id]=c
        return copy(c)
    end
    function M.RemoveCharacter(id)
        if not db.characters[id] then return nil,"Character not found." end
        for _,team in pairs(db.teams) do
            for pos=1,5 do
                if team.slots[pos] and team.slots[pos].characterId==id then return nil,"Remove character from saved teams first." end
            end
        end
        db.characters[id]=nil
        return true
    end
    function M.GetTeams() return sortRecords(db.teams) end
    function M.GetTeam(id) return copy(db.teams[id]) end
    function M.ValidateSlots(slots)
        if type(slots)~="table" then return nil,"Missing positions." end
        local count,used,accounts=0,{},{}
        local normalized={}
        for pos,s in pairs(slots) do
            if type(pos)~="number" or pos%1~=0 or pos<1 or pos>5 or type(s)~="table" then
                return nil,"Invalid position."
            end
            local c=db.characters[s.characterId]
            if not c or not roles[s.role] then return nil,"Choose a registered character and role." end
            if used[c.id] then return nil,"A character cannot occupy two positions." end
            local account=c.account:lower()
            if accounts[account] then return nil,"Use only one character per WoW account." end
            used[c.id]=true;accounts[account]=true;count=count+1
            normalized[pos]={characterId=c.id,role=s.role}
        end
        if count<2 or count>5 then return nil,"Teams need 2 to 5 characters." end
        return normalized
    end
    function M.SaveTeam(name,slots,id)
        name=field(name,80)
        if not name then return nil,"Enter a team name." end
        if id and not db.teams[id] then return nil,"Team not found." end
        for tid,t in pairs(db.teams) do
            if tid~=id and t.name:lower()==name:lower() then return nil,"Team name exists. Load it to edit." end
        end
        local checked,err=M.ValidateSlots(slots)
        if not checked then return nil,err end
        if not id then
            repeat db.nextTeam=db.nextTeam+1;id="t"..db.nextTeam until not db.teams[id]
        end
        local t={id=id,name=name,slots=checked}
        db.teams[id]=t
        return copy(t)
    end
    function M.SetActiveTeam(id)
        local team=db.teams[id]
        if not team then return nil,"Save or load a team first." end
        local ok,err=M.ValidateSlots(team.slots)
        if not ok then return nil,err end
        db.activeTeamId=id
        return copy(team)
    end
    function M.GetActiveTeam()
        return M.GetTeam(db.activeTeamId)
    end
    function M.ClearActiveTeam()
        db.activeTeamId=nil
        return true
    end
    function M.GetOrderedMembers(id)
        local t=db.teams[id or db.activeTeamId]
        local out={}
        if t then
            for pos=1,5 do
                local s=t.slots[pos]
                if s and db.characters[s.characterId] then
                    out[#out+1]={pos=pos,role=s.role,character=copy(db.characters[s.characterId])}
                end
            end
        end
        return out
    end
    return M
end
