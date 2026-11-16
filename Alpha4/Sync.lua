local H = HaploBoxA4
function H.Diagnose()
    H.Print("Diagnostics: version " .. tostring(H.VERSION))
    H.Print("Self=" .. tostring(H.UnitName("player")) .. "; leader=" .. tostring(H.LeaderName()) .. "; amLeader=" .. tostring(H.AmLeader()) .. "; whispers=" .. tostring(H.db and H.db.whisperForward))
    local count = 0
    for _, unit in ipairs(H.PartyUnits()) do
        local name = H.UnitName(unit)
        local trusted = H.Trusted(name)
        if unit ~= "player" and trusted then count = count + 1 end
        H.Print(unit .. "=" .. tostring(name) .. " trusted=" .. tostring(trusted))
    end
    H.Print("Trusted other clients: " .. count .. " / 4 expected with full Team A")
end
function H.PingTeam()
    H.Print("PING: " .. H.SendTeam("P", "test") .. " clients queued (not confirmation); expect separate Sync ACK replies")
end
local function now() return (GetTime and GetTime()) or 0 end
local function sendRaw(target, payload)
    if type(payload) ~= "string" or #payload > 240 or #payload < 1 then return false end
    if not H.Trusted(target) then return false end
    local name = H.PartyName(target)
    if not name then return false end
    local ok
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        ok = pcall(C_ChatInfo.SendAddonMessage, H.PREFIX, payload, "WHISPER", name)
    elseif SendAddonMessage then
        ok = pcall(SendAddonMessage, H.PREFIX, payload, "WHISPER", name)
    end
    return ok == true
end
function H.SendTo(target, kind, data)
    if not (kind and data) or data:find("[\r\n]") then return false end
    return sendRaw(target, "1|" .. kind .. "|" .. data)
end
function H.SendTeam(kind, data)
    local n = 0
    for _,u in ipairs(H.PartyUnits()) do
        if u ~= "player" then
            local name = H.UnitName(u)
            if name and H.SendTo(name, kind, data) then n=n+1 end
        end
    end
    return n
end
local UI_FIELDS = {
    "auraEnabled", "auraSize", "squareFollow", "hideBlizzardParty",
    "showKTL", "showGold", "showBags", "showClassColors",
    "layoutFix", "wideFrames", "partyWidth", "controlsOpen",
}
local function encodeUI()
    local p = {}
    for _,key in ipairs(UI_FIELDS) do
        local v = H.db.ui[key]
        if key == "controlsOpen" and HaploBox and HaploBox.db then v = HaploBox.db.controlsOpen end
        if type(v) == "boolean" then v = v and "1" or "0" end
        p[#p+1] = key .. "=" .. tostring(v)
    end
    -- Native frame dimensions/position are transferred in a separate LAY packet.
    return table.concat(p, ";")
end
local function finite(v, min, max)
    return type(v)=="number" and not H.Secret(v) and v==v and v>=min and v<=max
end
local function nativeLayout()
    local old=_G.HaploBox
    if not old or not old.db then return nil end
    local db=old.db
    local f=_G.HaploBoxPartyFrame
    local pos=db.partyPos
    local x,y
    if type(pos)=="table" then x,y=tonumber(pos[3]),tonumber(pos[4]) end
    if not finite(x,-5000,5000) or not finite(y,-5000,5000) then
        if f then
            local ok,left,top=pcall(function() return f:GetLeft(),f:GetTop() end)
            if ok and finite(left,-5000,5000) and finite(top,-5000,5000) then x,y=left,top end
        end
    end
    if not x or not y then x,y=20,650 end
    local w=tonumber(db.teamW) or 250
    local h=tonumber(db.teamRowH) or 60
    local scale=tonumber(db.partyScale) or 1
    if not (finite(w,150,500) and finite(h,28,140) and finite(scale,0.5,2)) then return nil end
    return string.format("%.0f,%.0f,%.3f,%.1f,%.1f",w,h,scale,x,y)
end
local function controlLayout()
    local old=_G.HaploBox
    if old and old.GetControlFractions then
        local x,y=old.GetControlFractions()
        if finite(x,0,1) and finite(y,0,1) then
            return string.format("N,%.6f,%.6f",x,y)
        end
    end
    return "D" -- use receiver's default if leader position isn't available
end
function H.ShareUI()
    if not H.db then return end
    if not H.AmLeader() then H.Print("Only actual party leader can SHARE UI.") return end
    local payload=nativeLayout()
    if not payload then H.Print("Cannot read native party frame layout; no changes sent.") return end
    local n=H.SendTeam("UI",encodeUI())
    H.SendTeam("LAY",payload)
    H.SendTeam("CTL",controlLayout()) -- unified normalized Controls/party anchor
    local old=_G.HaploBox
    if old and old.GetBuffOverviewFractions then
        local x,y=old.GetBuffOverviewFractions()
        if finite(x,0,1) and finite(y,0,1) then
            H.SendTeam("AUR",string.format("B,%.6f,%.6f",x,y))
        end
    end
    if H.SendFullConfig then H.SendFullConfig() end
    H.Print("UI/anchors sent to "..tostring(n).." trusted clients; full configuration sent separately with ACK tracking.")
end
local pendingLayout,pendingControls,pendingAuraAnchor
-- Alpha 5 TB1 called H.CanEditUI without defining it, so received CTL/LAY
-- messages could error before applying the shared bar position.
function H.CanEditUI()
    return not (InCombatLockdown and InCombatLockdown())
end
function H.ApplyControlPosition(data)
    local old=_G.HaploBox
    if not (old and old.db) then return false end
    if data~="D" then
        local fx,fy=data:match("^N,([%d%.]+),([%d%.]+)$")
        fx,fy=tonumber(fx),tonumber(fy)
        if finite(fx,0,1) and finite(fy,0,1) then
            if not H.CanEditUI() then pendingControls=data return true end
            return old.SetControlFractions and old.SetControlFractions(fx,fy) or false
        end
        -- Accept old Alpha 5 absolute packets from a mixed-version client.
        local x,y=data:match("^P,([%-%d%.]+),([%-%d%.]+)$")
        x,y=tonumber(x),tonumber(y)
        if not (finite(x,-5000,5000) and finite(y,-5000,5000)) then return false end
        if not H.CanEditUI() then pendingControls=data return true end
        old.db.controlsFrac=nil
        old.db.controlsPos={x,y}
    else
        if not H.CanEditUI() then pendingControls=data return true end
        old.db.controlsFrac=nil
        old.db.controlsPos=nil
    end
    if old.ApplyControlPosition then old.ApplyControlPosition() end
    if old.RefreshControls then old.RefreshControls() end
    return true
end
function H.ApplyAuraAnchor(data)
    local x,y=data:match("^B,([%d%.]+),([%d%.]+)$")
    x,y=tonumber(x),tonumber(y)
    if not (finite(x,0,1) and finite(y,0,1)) then return false end
    if not H.CanEditUI() then pendingAuraAnchor=data return true end
    local old=_G.HaploBox
    if not (old and old.SetBuffOverviewFractions) then return false end
    return old.SetBuffOverviewFractions(x,y)
end
function H.ApplyNativeLayout(data)
    local w,h,scale,x,y=data:match("^([%d%.]+),([%d%.]+),([%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
    w,h,scale,x,y=tonumber(w),tonumber(h),tonumber(scale),tonumber(x),tonumber(y)
    if not (finite(w,150,500) and finite(h,28,140) and finite(scale,0.5,2) and finite(x,-5000,5000) and finite(y,-5000,5000)) then return false end
    if not H.CanEditUI() then pendingLayout=data return true end
    local old=_G.HaploBox
    if not old or not old.db then return false end
    old.db.teamW,old.db.teamRowH,old.db.partyScale=w,h,scale
    -- BUG-22: the LAY packet carries dimensions ONLY. Party anchor is the
    -- single normalized CTL position; never restore the old partyPos from LAY.
    H.db.ui.partyWidth=w
    if old.ApplyPartyPosition then pcall(old.ApplyPartyPosition) end
    if old.LayoutPartyFrame then pcall(old.LayoutPartyFrame) end
    -- Never re-anchor secure party rows directly: Controls owns the position.
    if old.LayoutPartyFrame then H.After(0.2,old.LayoutPartyFrame) end
    if old.RefreshControls then H.After(0.2,old.RefreshControls) end
    return true
end
H.On("PLAYER_REGEN_ENABLED",function()
    if pendingLayout then local d=pendingLayout pendingLayout=nil H.ApplyNativeLayout(d) end
    if pendingControls then local d=pendingControls pendingControls=nil H.ApplyControlPosition(d) end
    if pendingAuraAnchor then local d=pendingAuraAnchor pendingAuraAnchor=nil H.ApplyAuraAnchor(d) end
end)
local function acceptUI(data)
    local u = H.db.ui
    local allowed = {}
    for _,k in ipairs(UI_FIELDS) do allowed[k] = true end
    for token in data:gmatch("[^;]+") do
        local key, value = token:match("^(%a+)=([%w]+)$")
        if key and allowed[key] then
            if key == "auraSize" or key == "partyWidth" then
                local size = tonumber(value)
                if size and key == "auraSize" and size >= 7 and size <= 28 then u.auraSize = math.floor(size) end
                if size and key == "partyWidth" and size >= 150 and size <= 490 then u.partyWidth = math.floor(size) end
            elseif value == "0" or value == "1" then u[key] = value == "1" end
        end
    end
    if HaploBoxDB then HaploBoxDB.controlsOpen = u.controlsOpen end
    if HaploBoxDB and type(u.showClassColors) == "boolean" then
        HaploBoxDB.teamClassColors = u.showClassColors
    end
    if HaploBox and HaploBox.LayoutPartyFrame then HaploBox.LayoutPartyFrame() end
    if HaploBox and HaploBox.RefreshPartyFrame then HaploBox.RefreshPartyFrame() end
    if HaploBox and HaploBox.RefreshControls then HaploBox.RefreshControls() end
    if H.UpdateInformationUI then H.UpdateInformationUI() end
    if H.UpdateBlizzardParty then H.UpdateBlizzardParty() end
    H.Print("Leader display settings received; awaiting full layout packet.")
end


-- TB17: complete, versioned UI/settings snapshot for Share UI to Party.
-- Never serialize character gameplay (HP, bags, gold, spell state, team roles,
-- current mouseover target, character identity or private whispers).
-- Never overwrite the follower's LOCAL Main/Heal view or WoW keybinding.
local CONFIG_FIELDS={
    B={"alertOnFollowStart","autoAcceptInvite","autoAcceptShared", "autoRoleCheck",
       "autoFFA","autoLeaveWithLeader","followMode","focusAlerts","teamFrame",
       "partyFrameSolo","partyScale","teamW","teamRowH","questEnabled",
       "tradeEnabled","teamLocked","teamClassColors","buffOverviewEnabled",
       "buffOverviewUnlocked","debuffOverviewEnabled","debuffOverviewUnlocked",
       "showRelayedErrors","shareErrorAlert","relayErrors","autoShareQuests",
       "preferredOrder","trustedMembers","debug","goldDetailsOpen","bagsDetailsOpen"},
    U={"auraEnabled","auraSize","squareFollow","hideBlizzardParty","showKTL",
       "showGold","showBags","showClassColors","layoutFix","wideFrames","partyWidth"},
    I={"autoRepair"},
    R={"xp","food","camp","mark","thorns","intellect","fortitude","blessing"},
    S={"followOn","followOff","leaderAlert","focusError","shareError",
       "inviteAccept","mountOn","mountOff"},
}
local CONFIG_ALLOWED={}
for section,keys in pairs(CONFIG_FIELDS) do
    CONFIG_ALLOWED[section]={}
    for _,k in ipairs(keys) do CONFIG_ALLOWED[section][k]=true end
end
local function sectionFor(section)
    local old=_G.HaploBox
    if section=="B" then return old and old.db end
    if section=="U" then return H.db and H.db.ui end
    if section=="I" then return H.db and H.db.inventory end
    if section=="R" then return old and old.db and old.db.requiredBuffs end
    if section=="S" then return old and old.db and old.db.sounds end
end
local function encodeValue(v)
    if v==false then return "b0" end
    if v==true then return "b1" end
    if type(v)=="number" and finite(v,-100000,100000) then
        return "n"..string.format("%.6g",v)
    end
    if type(v)=="string" and #v<=180 then
        return "s"..v:gsub("([^%w%-_%.])",function(c) return string.format("%%%02X",c:byte()) end)
    end
end
local function configSnapshot()
    local entries={}
    for _,section in ipairs({"B","U","I","R","S"}) do
        local t=sectionFor(section)
        if type(t)=="table" then
            for _,key in ipairs(CONFIG_FIELDS[section]) do
                local e=encodeValue(t[key])
                if e then entries[#entries+1]=section.."."..key.."="..e end
            end
        end
    end
    -- Separate normalized anchors are portable across four smaller clients.
    local old=_G.HaploBox
    if old and old.GetControlFractions then
        local x,y=old.GetControlFractions()
        if finite(x,0,1) and finite(y,0,1) then
            entries[#entries+1]=string.format("P.C=%.6f,%.6f",x,y)
        end
    end
    if old and old.GetBuffOverviewFractions then
        local x,y=old.GetBuffOverviewFractions()
        if finite(x,0,1) and finite(y,0,1) then
            entries[#entries+1]=string.format("P.B=%.6f,%.6f",x,y)
        end
    end
    if old and old.GetDebuffOverviewFractions then
        local x,y=old.GetDebuffOverviewFractions()
        if finite(x,0,1) and finite(y,0,1) then
            entries[#entries+1]=string.format("P.D=%.6f,%.6f",x,y)
        end
    end
    return "2;"..table.concat(entries,";")
end
local function checkValue(section,key,raw)
    if not CONFIG_ALLOWED[section] or not CONFIG_ALLOWED[section][key] then return nil end
    local prefix,payload=raw:sub(1,1),raw:sub(2)
    local value
    if prefix=="b" and (payload=="0" or payload=="1") then value=payload=="1"
    elseif prefix=="n" then value=tonumber(payload)
        if not finite(value,-100000,100000) then return nil end
    elseif prefix=="s" then
        if #payload>540 or payload:find("%%[^%x]") then return nil end
        value=payload:gsub("%%(%x%x)",function(hex) return string.char(tonumber(hex,16)) end)
        if #value>180 or value:find("[%c]") then return nil end
    else return nil end
    local existing=sectionFor(section)
    if not existing then return nil end
    -- Avoid type confusion or adding fields that the installed client does not support.
    local was=existing[key]
    if was~=nil and type(value)~=type(was) then
        -- Sounds may be disabled using false or use either numeric ID/string path.
        if section~="S" then return nil end
    end
    if section=="B" then
        if key=="partyScale" and not finite(value,0.5,2) then return nil end
        if key=="teamW" and not finite(value,150,500) then return nil end
        if key=="teamRowH" and not finite(value,28,140) then return nil end
        if key=="followMode" and value~="direct" and value~="dungeon" then return nil end
        if key=="teamFrame" and value~="show" and value~="hide" and value~="auto" then return nil end
        if key=="autoShareQuests" and value~="all" and value~="leader" and value~="off" then return nil end
    elseif section=="U" then
        if key=="auraSize" and not finite(value,7,28) then return nil end
        if key=="partyWidth" and not finite(value,150,490) then return nil end
    end
    return value
end
local function parseSnapshot(payload)
    if type(payload)~="string" or #payload>13000 or payload:sub(1,2)~="2;" then return nil end
    local values,anchors={},{}
    for token in payload:sub(3):gmatch("[^;]+") do
        local section,key,v=token:match("^([BUIRS])%.([%w_]+)=(.+)$")
        if section then
            local parsed=checkValue(section,key,v)
            if parsed==nil then return nil end
            values[#values+1]={section,key,parsed}
        else
            local kind,x,y=token:match("^P%.([CBD])=([%d%.]+),([%d%.]+)$")
            x,y=tonumber(x),tonumber(y)
            if not kind or not finite(x,0,1) or not finite(y,0,1) then return nil end
            anchors[kind]={x,y}
        end
    end
    if #values<12 then return nil end
    return values,anchors
end
local pendingComplete=nil
local function applyCompleteSnapshot(payload)
    if not H.CanEditUI() then pendingComplete=payload return "WAIT" end
    local parsed,anchors=parseSnapshot(payload)
    if not parsed then return "BAD" end
    -- Parse and validate EVERYTHING first, then apply as one local config transaction.
    for _,entry in ipairs(parsed) do
        local target=sectionFor(entry[1])
        if target then target[entry[2]]=entry[3] end
    end
    local old=_G.HaploBox
    if old and old.db then
        -- On all clients preserve their own Main/Heal view, actual action
        -- bar bindings and all character/runtime data.
        old.db.controlsOpen=false
        if anchors.C and old.SetControlFractions then
            old.SetControlFractions(anchors.C[1],anchors.C[2])
        end
        if anchors.B and old.SetBuffOverviewFractions then
            old.SetBuffOverviewFractions(anchors.B[1],anchors.B[2])
        end
        if anchors.D and old.SetDebuffOverviewFractions then
            old.SetDebuffOverviewFractions(anchors.D[1],anchors.D[2])
        end
        if old.SetBuffOverviewUnlocked then old.SetBuffOverviewUnlocked(old.db.buffOverviewUnlocked) end
        if old.SetDebuffOverviewUnlocked then old.SetDebuffOverviewUnlocked(old.db.debuffOverviewUnlocked) end
        if old.LayoutPartyFrame then old.LayoutPartyFrame() end
        if old.RefreshPartyFrame then old.RefreshPartyFrame() end
        if old.RefreshControls then old.RefreshControls() end
        if old.ApplyBlizzardAuraVisibility then old.ApplyBlizzardAuraVisibility() end
    end
    if H.UpdateInformationUI then H.UpdateInformationUI() end
    if H.UpdateBlizzardParty then H.UpdateBlizzardParty() end
    return "OK"
end
local sessionCounter=0
local outgoing={}
local incoming={}
local applied={}
local function checksum(text)
    local n=0
    for i=1,#text do n=(n+text:byte(i)*i)%65521 end
    return n
end
local function sendFullTo(target,sid,attempt)
    local key=H.Norm(target)
    local job=key and outgoing[key]
    if not job or job.id~=sid or job.ack then return end
    if attempt>3 then
        H.Print("Share UI to Party: NO ACK from "..tostring(target).." after 3 attempts")
        outgoing[key]=nil
        return
    end
    job.attempt=attempt
    for i,chunk in ipairs(job.chunks) do
        H.After((i-1)*0.12,function()
            if outgoing[key]==job and not job.ack then
                H.SendTo(target,"CFG",sid..","..i..","..#job.chunks..","..job.crc..","..chunk)
            end
        end)
    end
    H.After(#job.chunks*0.12+4.0,function()
        if outgoing[key]==job and not job.ack then sendFullTo(target,sid,attempt+1) end
    end)
end
local function sendFullSnapshot()
    local data=configSnapshot()
    if #data>13000 then H.Print("Share UI to Party: configuration too large") return 0 end
    local chunks={}
    local chunkSize=160  -- <=240 byte maximum even with version/CRC metadata
    for i=1,#data,chunkSize do chunks[#chunks+1]=data:sub(i,i+chunkSize-1) end
    if #chunks>82 then return 0 end
    sessionCounter=(sessionCounter%999999)+1
    local sid=tostring(sessionCounter)
    local n=0
    for _,u in ipairs(H.PartyUnits()) do
        if u~="player" then
            local target=H.UnitName(u)
            if target and H.Trusted(target) then
                local key=H.Norm(target)
                outgoing[key]={id=sid,chunks=chunks,crc=checksum(data),ack=false,attempt=0}
                sendFullTo(target,sid,1)
                n=n+1
            end
        end
    end
    H.Print("Share UI to Party: FULL config v2 queued for "..n.." trusted clients ("..#chunks.." chunks each). Await per-client ACK.")
    return n
end
local function receiveFullPart(sender,data)
    local sid,part,total,crc,chunk=data:match("^(%d+),(%d+),(%d+),(%d+),(.+)$")
    if not sid then return end
    local i,n,sum=tonumber(part),tonumber(total),tonumber(crc)
    if not (i and n and sum and i>=1 and n>=1 and i<=n and n<=82 and #chunk<=160) then return end
    local peer=H.Norm(sender)
    if not peer then return end
    local id=peer..":"..sid
    if applied[id]=="OK" then H.SendTo(sender,"CFGA",sid..",OK") return end
    local now=GetTime and GetTime() or 0
    local bag=incoming[id]
    if not bag or bag.total~=n or bag.crc~=sum or now-bag.time>90 then
        bag={total=n,crc=sum,items={},time=now,count=0}
        incoming[id]=bag
    end
    if not bag.items[i] then bag.items[i]=chunk bag.count=bag.count+1 end
    if bag.count<n then return end
    local payload=table.concat(bag.items,"")
    incoming[id]=nil
    if #payload>13000 or checksum(payload)~=sum then return end
    local status=applyCompleteSnapshot(payload)
    if status=="WAIT" then
        pendingComplete={text=payload,sender=sender,sid=sid}
        H.SendTo(sender,"CFGA",sid..",WAIT")
    elseif status=="OK" then
        applied[id]="OK"
        H.SendTo(sender,"CFGA",sid..",OK")
        H.Print("Share UI to Party: complete settings applied from actual party leader.")
    else
        H.SendTo(sender,"CFGA",sid..",BAD")
    end
end
H.On("PLAYER_REGEN_ENABLED",function()
    if type(pendingComplete)=="table" then
        local v=pendingComplete
        pendingComplete=nil
        local status=applyCompleteSnapshot(v.text)
        H.SendTo(v.sender,"CFGA",v.sid..","..status)
        if status=="OK" then applied[H.Norm(v.sender)..":"..v.sid]="OK" end
    end
end)

H.SendFullConfig=sendFullSnapshot

-- No party/raid broadcasts are used for private whispers or character data.
-- The actual leader is checked against the live roster, not saved leader metadata.
H.On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
    if prefix ~= H.PREFIX or channel ~= "WHISPER" then return end
    if H.Secret(msg) or H.Secret(sender) or type(msg) ~= "string" then return end
    if not H.Trusted(sender) then return end
    if #msg > 240 then return end
    local ver, kind, data = msg:match("^(%d+)|([A-Z]+)|(.+)$")
    if ver ~= "1" or not data then return end
    if kind == "UI" then
        if H.Norm(sender) ~= H.Norm(H.LeaderName()) then return end
        acceptUI(data)
    elseif kind == "LAY" then
        if H.Norm(sender) ~= H.Norm(H.LeaderName()) then return end
        local applied=H.ApplyNativeLayout(data)
        H.SendTo(sender,"K",applied and "LAY-OK" or "LAY-FAILED")
    elseif kind == "CTL" then
        if H.Norm(sender) ~= H.Norm(H.LeaderName()) then return end
        local applied=H.ApplyControlPosition(data)
        H.SendTo(sender,"K",applied and "CTL-OK" or "CTL-FAILED")
    elseif kind == "AUR" then
        if H.Norm(sender) ~= H.Norm(H.LeaderName()) then return end
        local applied=H.ApplyAuraAnchor(data)
        H.SendTo(sender,"K",applied and "AUR-OK" or "AUR-FAILED")
    elseif kind == "CFG" then
        if H.Norm(sender) ~= H.Norm(H.LeaderName()) then return end
        receiveFullPart(sender,data)
    elseif kind == "CFGA" then
        if H.AmLeader() then
            local id,status=data:match("^(%d+),([A-Z]+)$")
            local job=outgoing[H.Norm(sender)]
            if job and id==job.id then
                if status=="OK" then
                    job.ack=true
                    outgoing[H.Norm(sender)]=nil
                    H.Print("FULL UI/settings ACK from "..tostring(sender))
                elseif status=="BAD" then
                    H.Print("Share UI to Party config rejected by "..tostring(sender))
                elseif status=="WAIT" then
                    H.Print("Share UI to Party: "..tostring(sender).." waits for combat to end")
                end
            end
        end
    elseif kind == "K" then
        if H.AmLeader() then H.Print("Layout ACK from "..tostring(sender)..": "..tostring(data)) end
    elseif kind == "DATA" and H.ReceiveData then
        H.ReceiveData(sender, data)
    elseif kind == "J" and H.ReceiveJunk then
        H.ReceiveJunk(sender, data)
    elseif kind == "JL" and H.ReceiveJunkList then
        H.ReceiveJunkList(sender, data)
    elseif kind == "W" and H.ReceiveWhisper then
        if H.AmLeader() and H.db.whisperForward then H.ReceiveWhisper(sender, data) end
    elseif kind == "P" then
        -- Private diagnostic only. Never echo a forwarded whisper message.
        H.SendTo(sender, "A", "ok")
    elseif kind == "A" then
        H.Print("Sync ACK from " .. tostring(sender))
    end
end)
H.On("GROUP_ROSTER_UPDATE", function()
    H.After(4, function()
        if H.SendData then H.SendData(true) end
        if H.SendJunkList then H.SendJunkList() end
    end)
end)
H.OnReady(function()
    H.After(5, function()
        if H.SendData then H.SendData(true) end
        if H.SendJunkList then H.SendJunkList() end
    end)
end)
