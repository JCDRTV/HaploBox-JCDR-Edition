-- JB26.3.3: opt-in by local BoxManager key, authenticated peer reconciliation
-- outside parties. Never writes disk or sends the key. Party sync remains intact.
local HB=HaploBox
local CM,C,S,A=HB.CharacterManagement,HB.RegisterCodec,HB.RegisterSync,HB.RegisterPeerAuth
local P={PREFIX="JCDRPEER1"}
HB.RegisterPeerSync=P
local peers,queues,acks={}, {},{}
local pending,discovery,working,ready,combatDeferred
local serial=0
local lastAd,lastConflict
local cached
local function api(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b=pcall(fn,...)
    if ok and (not issecretvalue or not issecretvalue(a)) and (not issecretvalue or not issecretvalue(b)) then return a,b end
end
local function state()
    local d=HB.db and HB.db.registerSync
    if type(d)~="table" or d.schema~=1 or type(d.rev)~="number" or d.rev<0 or d.rev%1~=0 or d.rev>1000000000 then return end
    if type(d.bridgeKey)~="string" or #d.bridgeKey~=64 or d.bridgeKey:find("[^0-9a-f]") or not A.Sign then return end
    return d
end
local function now()return api(GetTime) or 0 end
local function me()return api(UnitGUID,"player") end
local function norm(s)
    if type(s)~="string" or s=="" or #s>180 or s:find("[%c|]") then return end
    return HB.Norm and HB.Norm(s) or s:lower()
end
local function myName()return norm(api(HB.UnitIdent,"player") or api(GetUnitName,"player",true)) end
local function guid(s)return type(s)=="string" and #s<=80 and s:match("^[%w%-]+$")~=nil end
local function say(msg,changed)
    if S.PeerChanged then S.PeerChanged(msg,changed) end
end
local function snap()
    local d=state()
    if not d then return end
    local cm,tm=HB.db.ownedCharacterCatalog,HB.db.plannedTeams
    if cached and cached.rev==d.rev and cached.cm==cm and cached.tm==tm then return cached end
    local data=C.Capture()
    if not data then return end
    cached={rev=d.rev,hash=C.Hash(data),data=data,cm=cm,tm=tm}
    return cached
end
local function send(target,body)
    local d=state();local n=myName();local g=me()
    if not d or not n or not guid(g) or not norm(target) then return false end
    local kind,tail=body:match("^([^|]+)|(.+)$")
    if not kind then return false end
    local payload=kind.."|"..g.."|"..tail
    local sig=A.Sign(d.bridgeKey,n.."|"..payload)
    local msg=sig and sig.."|"..payload
    if not msg or #msg>255 then return false end
    local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(fn)~="function" then return false end
    local ok,res=pcall(fn,P.PREFIX,msg,"WHISPER",target)
    if not ok or res==false then return false end
    local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    if type(res)=="number" and success~=nil and res~=success then return false end
    return true
end
local function announce(target,kind)
    local s=snap()
    if not s then return false end
    return send(target,table.concat({kind or "H",s.rev,s.hash,#s.data},"|"))
end
local function sameParty(g)
    for i=1,4 do if api(UnitGUID,"party"..i)==g then return true end end
    return false
end
local function valid(rev,hash,len)
    rev,len=tonumber(rev),tonumber(len)
    if not rev or rev<0 or rev%1~=0 or rev>1000000000 or type(hash)~="string" or #hash~=8 or hash:find("[^0-9a-f]") or not len or len%1~=0 or len<3 or len>C.MAX then return end
    return rev,len
end
local function nonce()
    serial=serial+1
    local d=state()
    return d and A.Sign(d.bridgeKey,table.concat({me() or "",now(),api(GetServerTime) or 0,serial,math.random()},"|")):sub(1,16)
end
local function chunk(g)return math.min(170,255-(25+2+#g+1+16+1+4+1)) end
local function hexNonce(n)return type(n)=="string" and #n==16 and n:match("^[0-9a-f]+$") end
local function canReceive()
    return not api(InCombatLockdown)
end
local function conflict(g,rev,hash)
    local k=g..":"..rev..":"..hash
    if lastConflict~=k then
        lastConflict=k
        say("Different register edits detected. Close clients; BoxManager will reconcile or ask for a source.")
    end
end
local function request(p,s,rev,hash,len)
    if pending and (pending.guid~=p.guid or pending.rev>=rev) then return end
    local n=nonce();if not n then return end
    local t={guid=p.guid,name=p.name,nonce=n,rev=rev,hash=hash,len=len,baseRev=s.rev,baseHash=s.hash,expires=now()+math.max(60,math.ceil(len/120)*2+60)}
    pending=t
    if not send(p.name,table.concat({"R",n,rev,hash},"|")) then pending=nil;return end
    C_Timer.After(t.expires-now(),function()
        if pending==t then pending=nil;say("Peer transfer interrupted; next login or register change will retry.") end
    end)
end
local function offer(p,rev,hash,len)
    local s,d=snap(),state()
    if not s or not d then return end
    if hash==s.hash then
        if rev>=s.rev then d.rev=rev;d.dirty=false end
        return
    end
    if rev<s.rev then return end
    -- Unlike party leader sync, independent accounts have no authority over
    -- a locally modified or same-revision divergent register.
    if rev==s.rev or d.dirty==true then conflict(p.guid,rev,hash);return end
    if not canReceive() then combatDeferred=true;return end
    request(p,s,rev,hash,len)
end
local function pump()
    local x=queues[1]
    if not x then working=false;return end
    local s=snap()
    if not s or s.rev~=x.rev or s.hash~=x.hash or now()>x.expires then table.remove(queues,1);C_Timer.After(.35,pump);return end
    local msg
    if x.index==0 then
        msg=table.concat({"B",x.nonce,x.rev,x.hash,#x.data,x.count,x.chunk},"|")
    else
        local start=(x.index-1)*x.chunk+1
        msg=table.concat({"D",x.nonce,x.index,x.data:sub(start,start+x.chunk-1)},"|")
    end
    if send(x.name,msg) then
        x.index=x.index+1;x.retries=0
        if x.index>x.count then
            acks[x.guid]={nonce=x.nonce,rev=x.rev,hash=x.hash,expires=now()+90}
            table.remove(queues,1)
        end
    else
        x.retries=(x.retries or 0)+1
        if x.retries>5 then table.remove(queues,1) end
    end
    C_Timer.After(x.retries and x.retries>0 and 1.5 or .4,pump)
end
local function queue(p,n,rev,hash)
    local s=snap()
    if not s or rev~=s.rev or hash~=s.hash then announce(p.name);return end
    for i=#queues,1,-1 do
        if queues[i].guid==p.guid then
            if queues[i].nonce==n then return end
            table.remove(queues,i)
        end
    end
    if #queues>=5 then return end
    local size=chunk(me())
    local count=math.ceil(#s.data/size)
    queues[#queues+1]={guid=p.guid,name=p.name,nonce=n,rev=rev,hash=hash,data=s.data,index=0,count=count,chunk=size,expires=now()+math.max(60,count*2+60)}
    if not working then working=true;pump() end
end
local function commit()
    local t=pending
    if not t then return end
    pending=nil
    local s,d=snap(),state()
    if not s or not d or not canReceive() or s.rev~=t.baseRev or s.hash~=t.baseHash or d.dirty==true or t.rev<=s.rev then return end
    local data=table.concat(t.parts)
    local decoded=C.Decode(data)
    if #data~=t.len or C.Hash(data)~=t.hash or not decoded then say("Invalid peer register rejected.");return end
    if s.data~="V|1" then d.backup={rev=s.rev,data=s.data,source=t.guid} end
    HB.db.ownedCharacterCatalog=decoded.cm
    HB.db.plannedTeams=decoded.tm
    d.rev=t.rev;d.lastSource=t.guid;d.dirty=false
    send(t.name,table.concat({"K",t.nonce,t.rev,t.hash},"|"))
    say("Central register synced automatically.",true)
end
local function receive(prefix,msg,channel,sender)
    if not ready or prefix~=P.PREFIX or channel~="WHISPER" or (issecretvalue and (issecretvalue(msg) or issecretvalue(sender))) or type(msg)~="string" or #msg>255 then return end
    local d=state();local n=norm(sender)
    if not d or not n or n==myName() then return end
    local sig,payload=msg:match("^([0-9a-f]+)|(.+)$")
    if not sig or #sig~=24 or A.Sign(d.bridgeKey,n.."|"..payload)~=sig then return end
    local kind,g,body=payload:match("^([^|]+)|([^|]+)|(.+)$")
    if not kind or not guid(g) or g==me() then return end
    local record=CM.GetCharacter(g)
    if record and norm(record.name)~=n then return end
    local p=peers[g]
    if not p then
        local count=0;for _ in pairs(peers) do count=count+1 end
        if count>=50 then return end
        p={guid=g};peers[g]=p
    end
    p.name=sender;p.seen=now()
    if kind=="Q" or kind=="H" then
        local rev,hash,len=body:match("^(%d+)|([0-9a-f]+)|(%d+)$")
        rev,len=valid(rev,hash,len)
        if not rev then return end
        if kind=="Q" then announce(sender) end
        offer(p,rev,hash,len)
        return
    end
    if kind=="R" then
        local nonceValue,rev,hash=body:match("^([0-9a-f]+)|(%d+)|([0-9a-f]+)$")
        if hexNonce(nonceValue) then queue(p,nonceValue,tonumber(rev),hash) end
        return
    end
    if kind=="K" then
        local nonceValue,rev,hash=body:match("^([0-9a-f]+)|(%d+)|([0-9a-f]+)$")
        local ack,s=acks[g],snap()
        if ack and s and ack.expires>=now() and ack.nonce==nonceValue and ack.rev==tonumber(rev) and ack.hash==hash and s.rev==ack.rev and s.hash==hash then
            d.dirty=false;acks[g]=nil
        end
        return
    end
    local t=pending
    if not t or t.guid~=g or t.name~=sender or now()>t.expires then return end
    if kind=="B" then
        local nonceValue,rev,hash,len,count,size=body:match("^([0-9a-f]+)|(%d+)|([0-9a-f]+)|(%d+)|(%d+)|(%d+)$")
        count,size=tonumber(count),tonumber(size)
        if nonceValue==t.nonce and tonumber(rev)==t.rev and hash==t.hash and tonumber(len)==t.len and size==chunk(g) and count==math.ceil(t.len/size) then
            t.count=count;t.chunk=size;t.parts={};t.received=0
        end
        return
    end
    if kind=="D" and t.parts then
        local nonceValue,index,data=body:match("^([0-9a-f]+)|(%d+)|(.*)$")
        index=tonumber(index)
        if nonceValue~=t.nonce or not index or index<1 or index>t.count then return end
        local length=index==t.count and t.len-(t.count-1)*t.chunk or t.chunk
        if #data~=length then return end
        if not t.parts[index] then t.parts[index]=data;t.received=t.received+1 end
        if t.received==t.count then commit() end
    end
end
local function targets()
    local _,realm=api(UnitFullName,"player")
    if type(realm)~="string" or realm=="" then realm=api(GetNormalizedRealmName) or api(GetRealmName) end
    local ownGuid=me();local ownName=myName()
    local ownRecord=CM.GetCharacter(ownGuid)
    local names,dup={},{}
    for _,r in ipairs(CM.GetCharacters()) do
        local n=norm(r.name)
        if n and n~=ownName and r.guid~=ownGuid and (not realm or r.realm==realm) and (not ownRecord or r.account~=ownRecord.account) then
            if names[n] then dup[n]=true else names[n]=r end
        end
    end
    local list={}
    for n,r in pairs(names) do if not dup[n] then list[#list+1]=r end end
    table.sort(list,function(a,b)
        local ap,bp=peers[a.guid],peers[b.guid]
        if (ap~=nil)~=(bp~=nil) then return ap~=nil end
        return a.guid<b.guid
    end)
    return list
end
local function discover()
    if discovery or not ready or not state() then return end
    local list=targets()
    local i=0
    discovery=true
    local function step()
        i=i+1
        local r=list[i]
        if not r or not state() then discovery=false;return end
        -- Existing party sync takes priority for known party members.
        if not sameParty(r.guid) or not CM.GetCharacter(me()) then announce(r.name,"Q") end
        C_Timer.After(.65,step)
    end
    step()
end
local function heartbeat()
    local s=snap()
    if not s then return end
    local k=s.rev..":"..s.hash
    local changed=k~=lastAd
    lastAd=k
    for g,p in pairs(peers) do
        if acks[g] and now()>acks[g].expires then acks[g]=nil end
        if now()-p.seen>180 then peers[g]=nil
        elseif not sameParty(g) and (changed or now()-(p.asked or 0)>=25) then
            if announce(p.name,"Q") then p.asked=now() end
        end
    end
end
local notifyPending=false
function P.NotifyLocal()
    if not ready or notifyPending or not state() then return end
    notifyPending=true
    C_Timer.After(1,function()
        notifyPending=false
        heartbeat()
        discover()
    end)
end
local f=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","CHAT_MSG_ADDON"}) do f:RegisterEvent(e) end
f:SetScript("OnEvent",function(_,event,...)
    if event=="CHAT_MSG_ADDON" then receive(...);return end
    if event=="PLAYER_LOGIN" then
        if not state() or not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then return end
        api(C_ChatInfo.RegisterAddonMessagePrefix,P.PREFIX)
        ready=true
        C_Timer.After(2,discover)
    elseif ready and event=="PLAYER_REGEN_ENABLED" and combatDeferred then
        combatDeferred=false;heartbeat();discover()
    end
end)
