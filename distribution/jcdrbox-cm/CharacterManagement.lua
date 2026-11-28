-- JB26.2.0: explicit owned-character catalog. Independent of legacy party trust.
local HB=HaploBox
local CM={}
HB.CharacterManagement=CM
local function safe(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function api(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b=pcall(fn,...)
    if ok then return safe(a),safe(b) end
end
local function str(v)
    v=safe(v)
    if type(v)=="string" and v~="" then return v end
end
local function clone(r)
    local out={}
    for k,v in pairs(r or {}) do out[k]=v end
    return out
end
local function store()
    if not HB.db then return nil end
    local d=HB.db.ownedCharacterCatalog
    if type(d)~="table" then d={schema=1,accounts={},characters={}};HB.db.ownedCharacterCatalog=d end
    if d.schema~=1 or type(d.accounts)~="table" or type(d.characters)~="table" then return nil end
    return d
end
function CM.CanEdit()
    if api(InCombatLockdown) or api(IsInRaid) then return false end
    if not api(IsInGroup) then return true end
    local v=api(UnitIsGroupLeader,"player")
    if v==nil then v=api(UnitIsPartyLeader,"player") end
    return v==true or v==1
end
local function writable()
    if not CM.CanEdit() then return nil,"Only the party leader can edit, outside combat." end
    local d=store()
    if not d then return nil,"Catalog unavailable." end
    return d
end
function CM.Accounts()
    local d=store()
    local result={}
    if d then for id,label in pairs(d.accounts) do result[#result+1]={id=id,label=label} end end
    table.sort(result,function(a,b) return a.label:lower()<b.label:lower() end)
    return result
end
function CM.AddAccount(label)
    local d,e=writable();if not d then return false,e end
    label=str(label)
    if label then label=label:match("^%s*(.-)%s*$") end
    if not label or label=="" or #label>40 or label:find("[%c|]") then return false,"Enter an account alias (1-40 characters)." end
    local id=label:lower()
    if d.accounts[id] then return false,"Account already exists." end
    d.accounts[id]=label
    return true
end
function CM.RemoveAccount(id)
    local d,e=writable();if not d then return false,e end
    if not id or not d.accounts[id] then return false,"Unknown account." end
    for _,r in pairs(d.characters) do if r.account==id then return false,"Move or remove its characters first." end end
    d.accounts[id]=nil
    return true
end
local function read(u)
    local guid=str(api(UnitGUID,u))
    local first,realm=api(UnitFullName,u)
    if not str(first) then first,realm=api(UnitName,u) end
    local name=str(api(HB.UnitIdent,u)) or str(first)
    realm=str(realm) or str(api(GetNormalizedRealmName)) or str(api(GetRealmName))
    local _,class=api(UnitClass,u)
    local _,race=api(UnitRace,u)
    local level=api(UnitLevel,u)
    if not guid or not name or not realm or not str(class) or not str(race) or type(level)~="number" or level<1 then return nil end
    return {guid=guid,name=name,realm=realm,class=class,race=race,level=level}
end
function CM.Snapshot(solo)
    if not CM.CanEdit() then return nil,"Only the party leader can register characters." end
    local rows={}
    local seen={}
    local n=solo and 1 or (api(IsInGroup) and api(GetNumGroupMembers) or 1)
    if type(n)~="number" or n<1 or n>5 then return nil,"Party roster unavailable." end
    for i=0,4 do
        local u=i==0 and "player" or "party"..i
        if i==0 or (not solo and api(IsInGroup) and api(UnitExists,u)) then
            local r=read(u)
            if not r or seen[r.guid] then return nil,"Wait for complete party character information." end
            seen[r.guid]=true
            rows[#rows+1]=r
        end
    end
    if #rows~=n then return nil,"Party roster changed; try again." end
    local ids={}
    for _,r in ipairs(rows) do ids[#ids+1]=r.guid end
    table.sort(ids)
    return {key=table.concat(ids,";"),rows=rows,solo=solo==true}
end
function CM.GetCharacters()
    local d=store();local rows={}
    if d then
        for _,r in pairs(d.characters) do
            local c=clone(r);c.accountLabel=d.accounts[r.account] or "?";rows[#rows+1]=c
        end
    end
    table.sort(rows,function(a,b) return a.guid<b.guid end)
    return rows
end
function CM.GetCharacter(guid)
    local d=store()
    local r=d and d.characters[guid]
    return r and clone(r)
end
function CM.Import(snapshot,selection)
    local d,e=writable();if not d then return false,e end
    if type(snapshot)~="table" or type(selection)~="table" then return false,"Missing import selection." end
    local live,err=CM.Snapshot(snapshot.solo)
    if not live or live.key~=snapshot.key then return false,err or "Party changed; open import again." end
    local staged,accounts={},{}
    for _,r in ipairs(live.rows) do
        local id=selection[r.guid]
        if id then
            if type(id)~="string" or not d.accounts[id] then return false,"Select a registered account for every checked character." end
            if accounts[id] then return false,"Two selected party characters use the same account." end
            accounts[id]=true
            local old=d.characters[r.guid]
            -- Do not overwrite last-known identity/level for an existing record
            -- from a party refresh; only the character's own login refreshes it.
            local c=old and clone(old) or clone(r)
            c.account=id
            staged[r.guid]=c
        end
    end
    local n=0
    for guid in pairs(selection) do
        if selection[guid] and not staged[guid] then return false,"Import selection no longer matches the party." end
    end
    for guid,r in pairs(staged) do d.characters[guid]=r;n=n+1 end
    if n==0 then return false,"Select at least one own character." end
    return true,n
end
function CM.SetAccount(guid,id)
    local d,e=writable();if not d then return false,e end
    if not d.characters[guid] or not d.accounts[id] then return false,"Unknown character or account." end
    d.characters[guid].account=id
    return true
end
function CM.RemoveCharacter(guid)
    local d,e=writable();if not d then return false,e end
    if not d.characters[guid] then return false,"Unknown character." end
    d.characters[guid]=nil
    return true
end
function CM.RefreshLogin()
    local d=store()
    local r=read("player")
    if not d or not r or not d.characters[r.guid] then return false end
    r.account=d.characters[r.guid].account
    d.characters[r.guid]=r
    return true
end
local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function(self)
    -- Only once per login, no level or roster refreshes.
    self:UnregisterEvent("PLAYER_LOGIN")
    CM.RefreshLogin()
end)
