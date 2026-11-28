-- JB26.3.1: event-driven peer sync of the separate owned CM/TM catalogs.
-- Only registered own GUIDs receive snapshots, via private addon whispers.
-- A previously unknown source requires an explicit local confirmation.
local HB=HaploBox
local CM,T,C=HB.CharacterManagement,HB.TeamPlanner,HB.RegisterCodec
local S={PREFIX="JCDRREG1"}
HB.RegisterSync=S
local ready=false
local pending,offer,scheduled=nil,nil,false
local outgoing,working={},false
local status="Register sync not started."
local loginRecord
local schedule
local function say(msg,changed)
    status=msg
    if S.OnChange then S.OnChange(changed) end
end
function S.Status()return status end
local function safe(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function api(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b=pcall(fn,...)
    if ok then return safe(a),safe(b) end
end
local function isYes(v)return v==true or v==1 end
local function now()return api(GetTime) or 0 end
local function localGuid()return api(UnitGUID,"player") end
local function state()
    if not HB.db then return nil end
    if type(HB.db.registerSync)~="table" then HB.db.registerSync={schema=1,rev=0} end
    local d=HB.db.registerSync
    if d.schema~=1 then return nil end
    if type(d.rev)~="number" or d.rev<0 or d.rev%1~=0 or d.rev>1000000000 then return nil end
    return d
end
local function snapshot()
    local d=state()
    if not d then return nil end
    local data,parsed=C.Capture()
    if not data then return nil end
    local hash=C.Hash(data)
    if d.rev==0 and data~="V|1" then d.rev=1 end
    return {rev=d.rev,hash=hash,data=data,parsed=parsed}
end
local function nameKey(n)
    if type(n)~="string" or n=="" or #n>180 then return nil end
    return HB.Norm and HB.Norm(n) or n:lower()
end
local function party()
    if not isYes(api(IsInGroup)) or isYes(api(IsInRaid)) then return nil end
    local members,ids,leader={}, {},nil
    for i=0,4 do
        local u=i==0 and "player" or "party"..i
        if i==0 or isYes(api(UnitExists,u)) then
            local guid=api(UnitGUID,u)
            local target=api(GetUnitName,u,true) or api(HB.UnitIdent,u)
            if type(guid)~="string" or type(target)~="string" or members[guid] then return nil end
            local name,realm=api(UnitFullName,u)
            local m={guid=guid,target=target,unit=u,aliases={target}}
            local short=api(GetUnitName,u,false)
            if type(short)=="string" then m.aliases[#m.aliases+1]=short end
            if type(name)=="string" then
                m.aliases[#m.aliases+1]=name
                if type(realm)=="string" and realm~="" then m.aliases[#m.aliases+1]=name.."-"..realm end
            end
            members[guid]=m;ids[#ids+1]=guid
            local lead=api(UnitIsGroupLeader,u)
            if lead==nil then lead=api(UnitIsPartyLeader,u) end
            if isYes(lead) then if leader then return nil end;leader=guid end
        end
    end
    local count=api(GetNumGroupMembers)
    if not leader or #ids<2 or (type(count)=="number" and count~=#ids) then return nil end
    table.sort(ids)
    return {members=members,leader=leader,key=table.concat(ids,";").."@"..leader}
end
local function resolve(p,sender)
    local k=nameKey(sender)
    if not k then return nil end
    local found
    for guid,m in pairs(p.members) do
        for _,n in ipairs(m.aliases) do
            if nameKey(n)==k then
                if found and found.guid~=guid then return nil end
                found=m;break
            end
        end
    end
    if found and found.guid~=localGuid() then return found end
end
local function related(p,guid)
    return p and p.members[guid] and (p.leader==guid or p.leader==localGuid())
end
local function own(guid)return CM.GetCharacter(guid)~=nil end
local function trusted(m,p)
    if own(m.guid) then return true end
    -- Explicit legacy trust can bootstrap a previously empty follower only.
    -- No trust is inferred solely from another player's offered catalog.
    local localData=snapshot()
    local legacy=HB.TeamManagement
    return localData and localData.data=="V|1" and p.leader==m.guid and legacy and
        type(legacy.IsTrustedPartyMember)=="function" and legacy.IsTrustedPartyMember(m.target)==true
end
local function send(guid,msg,key,requireOwn)
    local p=party()
    if not p or p.key~=key or not related(p,guid) or (requireOwn and not own(guid)) or #msg>255 then return false end
    local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(fn)~="function" then return false end
    return pcall(fn,S.PREFIX,msg,"WHISPER",p.members[guid].target)
end
local function pump()
    local item=table.remove(outgoing,1)
    if not item then working=false;return end
    local p=party()
    if p and p.key==item.key and related(p,item.guid) and own(item.guid) and own(localGuid()) then
        local msg
        if item.index==0 then
            msg=table.concat({"B",item.rev,item.hash,#item.data,item.count},"|")
        else
            local start=(item.index-1)*190+1
            msg=table.concat({"D",item.rev,item.hash,item.index,item.data:sub(start,start+189)},"|")
        end
        if send(item.guid,msg,item.key,true) and item.index<item.count then
            item.index=item.index+1;table.insert(outgoing,1,item)
        end
    end
    C_Timer.After(.22,pump)
end
local function queueSnapshot(guid,p,s)
    for i=#outgoing,1,-1 do if outgoing[i].guid==guid then table.remove(outgoing,i) end end
    if #outgoing>=5 then return end
    outgoing[#outgoing+1]={guid=guid,key=p.key,rev=s.rev,hash=s.hash,data=s.data,index=0,count=math.ceil(#s.data/190)}
    if not working then working=true;pump() end
end
local function validOffer(rev,hash,len)
    rev,len=tonumber(rev),tonumber(len)
    if not rev or rev<1 or rev%1~=0 or rev>1000000000 or type(hash)~="string" or #hash~=8 or hash:find("[^0-9a-f]") or not len or len%1~=0 or len<3 or len>C.MAX then return nil end
    return rev,len
end
local function applyLogin(guid,meta)
    local cat=HB.db and HB.db.ownedCharacterCatalog
    local rec=cat and cat.characters and cat.characters[guid]
    if not rec or not meta then return false end
    local changed=false
    for _,k in ipairs({"name","realm","class","race","level"}) do
        if rec[k]~=meta[k] then rec[k]=meta[k];changed=true end
    end
    if changed then local d=state();d.rev=math.max(1,d.rev+1);d.dirty=true end
    return changed
end
local function localMeta()
    local guid=localGuid()
    local name=api(HB.UnitIdent,"player")
    local _,realm=api(UnitFullName,"player")
    realm=type(realm)=="string" and realm~="" and realm or api(GetNormalizedRealmName) or api(GetRealmName)
    local _,class=api(UnitClass,"player")
    local _,race=api(UnitRace,"player")
    local level=api(UnitLevel,"player")
    if type(guid)~="string" or type(name)~="string" or type(realm)~="string" or type(class)~="string" or type(race)~="string" or type(level)~="number" or level%1~=0 or level<1 or level>255 then return nil end
    return {guid=guid,name=name,realm=realm,class=class,race=race,level=level}
end
-- Keep a follower login-only metadata change separate from the shared revision.
-- The actual leader commits it after receiving an authenticated login report.
local originalLogin=CM.RefreshLogin
CM.RefreshLogin=function()
    local rec=CM.GetCharacter(localGuid())
    local ok=originalLogin()
    if ok and rec then
        local fresh=CM.GetCharacter(localGuid())
        loginRecord=fresh
        HB.db.ownedCharacterCatalog.characters[rec.guid]=rec
    end
    return ok
end
local originalGet=CM.GetCharacter
CM.GetCharacter=function(guid)
    local rec=originalGet(guid)
    if rec and loginRecord and guid==localGuid() and guid==loginRecord.guid then
        for _,k in ipairs({"name","realm","class","race","level"}) do rec[k]=loginRecord[k] end
    end
    return rec
end
local originalList=CM.GetCharacters
CM.GetCharacters=function()
    local rows=originalList()
    if loginRecord then for _,rec in ipairs(rows) do
        if rec.guid==localGuid() and rec.guid==loginRecord.guid then
            for _,k in ipairs({"name","realm","class","race","level"}) do rec[k]=loginRecord[k] end
        end
    end end
    return rows
end
local function advertise()
    if not ready then return end
    local p=party()
    if not p or not own(localGuid()) then return end
    if loginRecord and loginRecord.guid==localGuid() then
        if p.leader==localGuid() then applyLogin(localGuid(),loginRecord)
        elseif own(p.leader) then
            local m=C.EncodeLogin(loginRecord)
            if m and #m<=253 then send(p.leader,"L|"..m,p.key,true) end
        end
    end
    local s=snapshot()
    if not s or s.rev==0 then return end
    local msg=table.concat({"H",s.rev,s.hash,#s.data},"|")
    for guid in pairs(p.members) do
        if guid~=localGuid() and related(p,guid) and own(guid) then send(guid,msg,p.key,true) end
    end
end
schedule=function()
    if not ready or scheduled then return end
    scheduled=true
    C_Timer.After(.8,function() scheduled=false;advertise() end)
end
local function request(o,manual)
    local p,s=party(),snapshot()
    if not p or p.key~=o.key or not related(p,o.guid) or not s or o.rev<s.rev then return false end
    if o.rev==s.rev and o.hash==s.hash then offer=nil;return true end
    if not manual and (not trusted(p.members[o.guid],p) or (o.rev==s.rev and s.data~="V|1") or (p.leader==localGuid() and state().dirty)) then return false end
    if pending then return false end
    local lifetime=math.max(45,math.ceil(o.len/190)*.30+20)
    local token={guid=o.guid,key=o.key,rev=o.rev,hash=o.hash,len=o.len,localRev=s.rev,localHash=s.hash,manual=manual,expires=now()+lifetime}
    pending=token;offer=nil
    if not send(o.guid,table.concat({"R",o.rev,o.hash},"|"),o.key,false) then
        pending=nil;say("Register request could not be sent.");return false
    end
    say("Receiving register from "..p.members[o.guid].target.."...")
    C_Timer.After(lifetime,function()
        if pending==token then pending=nil;say("Register sync timed out. Use Sync Register to retry.") end
    end)
    return true
end
function S.Action()
    if not ready then return end
    if isYes(api(InCombatLockdown)) then say("Sync after combat.");return end
    if pending then say("Register transfer in progress.");return end
    if offer then
        local o=offer
        -- A stale offer is never accepted, even by an explicit click.
        if request(o,true) then return end
        offer=nil
    end
    if not party() then say("Form a party with your own clients to sync.");return end
    advertise();say("Sync requested. Only registered own party members receive data.")
    -- Ask existing known peers to advertise; empty clients send no catalog.
    local p=party()
    if p then for guid in pairs(p.members) do
        if guid~=localGuid() and related(p,guid) and (own(guid) or guid==p.leader) then send(guid,"Q",p.key,own(guid)) end
    end end
end
function S.ActionLabel()
    if offer then return "Accept Register" end
    return "Sync Register"
end
local function commit()
    local r=pending
    if not r then return end
    local p,s=party(),snapshot()
    if not p or p.key~=r.key or not related(p,r.guid) or not s or s.rev~=r.localRev or s.hash~=r.localHash or r.rev<s.rev then
        pending=nil;say("Register changed during transfer; nothing overwritten.");schedule();return
    end
    local data=table.concat(r.parts)
    local decoded,why=C.Decode(data)
    if #data~=r.len or C.Hash(data)~=r.hash or not decoded or not decoded.cm.characters[localGuid()] or not decoded.cm.characters[r.guid] then
        pending=nil;say("Register rejected: "..(why or "invalid checksum or ownership."));return
    end
    if not r.manual and not trusted(p.members[r.guid],p) then pending=nil;say("Source no longer trusted.");return end
    local d=state()
    -- Backup retained separately from the active catalogs; no settings,
    -- macros or legacy trust fields are touched.
    if s.data~="V|1" and s.hash~=r.hash then
        d.backup={rev=s.rev,data=s.data,source=r.guid}
    end
    HB.db.ownedCharacterCatalog=decoded.cm
    HB.db.plannedTeams=decoded.tm
    d.rev=r.rev;d.lastSource=r.guid;d.dirty=false
    if p.leader==localGuid() and r.rev==s.rev and r.hash~=s.hash then d.rev=d.rev+1 end
    pending=nil;offer=nil
    say("Register synced: "..#CM.Accounts().." accounts / "..#CM.GetCharacters().." characters / "..#T.List().." teams.",true)
    send(r.guid,"K|"..r.rev.."|"..r.hash,p.key,true)
    schedule()
end
local function receive(prefix,msg,channel,sender)
    if not ready or prefix~=S.PREFIX or channel~="WHISPER" or type(safe(msg))~="string" or type(safe(sender))~="string" or #msg>255 then return end
    local p=party()
    if not p then return end
    local m=resolve(p,sender)
    if not m or not related(p,m.guid) then return end
    if msg=="Q" then if own(m.guid) and own(localGuid()) then schedule() end;return end
    if msg:sub(1,2)=="L|" then
        if p.leader==localGuid() and own(m.guid) and own(localGuid()) and not isYes(api(InCombatLockdown)) then
            local meta=C.DecodeLogin(msg:sub(3))
            if meta and applyLogin(m.guid,meta) then schedule();say("Character login information updated.",true) end
        end
        return
    end
    local kr,kh=msg:match("^K|(%d+)|([0-9a-f]+)$")
    if kr then
        local s=snapshot()
        if own(m.guid) and s and s.rev==tonumber(kr) and s.hash==kh then state().dirty=false end
        return
    end
    local rev,hash,len=msg:match("^H|(%d+)|([0-9a-f]+)|(%d+)$")
    if rev then
        rev,len=validOffer(rev,hash,len)
        if not rev then return end
        local s=snapshot()
        if not s or rev<s.rev or (rev==s.rev and hash==s.hash) then return end
        if pending then return end
        local o={guid=m.guid,key=p.key,rev=rev,hash=hash,len=len}
        if trusted(m,p) and (rev>s.rev or s.data=="V|1") and not (p.leader==localGuid() and state().dirty) then
            if isYes(api(InCombatLockdown)) then offer=o;say("Register available; accept after combat.") else request(o,false) end
        else
            -- Do not overwrite independent catalogs at the same revision.
            offer=o;say("Register offered by "..m.target..". Accept only if this is your own client.")
        end
        return
    end
    rev,hash=msg:match("^R|(%d+)|([0-9a-f]+)$")
    if rev then
        local s=snapshot()
        if own(m.guid) and own(localGuid()) and s and tonumber(rev)==s.rev and hash==s.hash then queueSnapshot(m.guid,p,s) end
        return
    end
    local r=pending
    if not r or r.guid~=m.guid or r.key~=p.key or now()>r.expires then return end
    local count
    rev,hash,len,count=msg:match("^B|(%d+)|([0-9a-f]+)|(%d+)|(%d+)$")
    if rev then
        if tonumber(rev)==r.rev and hash==r.hash and tonumber(len)==r.len and tonumber(count)==math.ceil(r.len/190) then
            r.count=tonumber(count);r.parts={};r.received=0
        end
        return
    end
    local index,data
    rev,hash,index,data=msg:match("^D|(%d+)|([0-9a-f]+)|(%d+)|(.*)$")
    index=tonumber(index)
    if rev and tonumber(rev)==r.rev and hash==r.hash and r.parts and index and index>=1 and index<=r.count then
        local expected=index==r.count and r.len-(r.count-1)*190 or 190
        if #data~=expected then return end
        if not r.parts[index] then r.parts[index]=data;r.received=r.received+1 end
        if r.received==r.count then commit() end
    end
end
local function bump()
    local d=state()
    if d then d.rev=math.max(1,d.rev+1);d.dirty=true;schedule() end
end
for _,pair in ipairs({{CM,"AddAccount"},{CM,"RemoveAccount"},{CM,"Import"},{CM,"SetAccount"},{CM,"RemoveCharacter"},{T,"Save"},{T,"Select"},{T,"Delete"}}) do
    local obj,k=pair[1],pair[2]
    local old=obj[k]
    obj[k]=function(...)
        local before=ready and snapshot()
        local ok,result=old(...)
        if ok and ready then
            local after=snapshot()
            if after and (not before or before.hash~=after.hash) then bump() end
        end
        return ok,result
    end
end
local f=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","PARTY_LEADER_CHANGED","PLAYER_REGEN_ENABLED","CHAT_MSG_ADDON"}) do f:RegisterEvent(e) end
f:SetScript("OnEvent",function(_,event,...)
    if event=="CHAT_MSG_ADDON" then receive(...);return end
    if event=="PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then api(C_ChatInfo.RegisterAddonMessagePrefix,S.PREFIX) end
        loginRecord=localMeta() or loginRecord
        ready=true;snapshot()
    end
    local p=party()
    if pending and (not p or pending.key~=p.key) then pending=nil;say("Party changed; previous transfer canceled.") end
    if offer and (not p or offer.key~=p.key) then offer=nil;say("Party changed; previous offer canceled.") end
    schedule()
end)
