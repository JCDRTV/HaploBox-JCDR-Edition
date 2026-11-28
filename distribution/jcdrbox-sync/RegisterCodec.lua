-- JB26.3.1: validated CM/TM snapshot format. No Lua evaluation or remote commands.
local HB=HaploBox
local C={}
HB.RegisterCodec=C
C.MAX=60000
local function hex(s)
    return (s:gsub(".",function(c)return string.format("%02x",c:byte())end))
end
local function unhex(s,max)
    if type(s)~="string" or #s==0 or #s%2~=0 or #s>max*2 or s:find("[^0-9a-f]") then return nil end
    local v=s:gsub("..",function(c)return string.char(tonumber(c,16))end)
    if v:find("[%c]") then return nil end
    return v
end
local function validGuid(s)
    return type(s)=="string" and #s<=80 and s:match("^[%w%-]+$")~=nil
end
local function keys(t)
    local r={}
    for k in pairs(t or {}) do r[#r+1]=k end
    table.sort(r);return r
end
function C.Hash(s)
    local a,b=1,0
    for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
    return string.format("%08x",b*65536+a)
end
function C.Encode(cm,tm)
    local rows={"V|1"}
    for _,id in ipairs(keys(cm.accounts)) do
        rows[#rows+1]="A|"..hex(id).."|"..hex(cm.accounts[id])
    end
    for _,id in ipairs(keys(cm.characters)) do
        local r=cm.characters[id]
        rows[#rows+1]=table.concat({"C",id,hex(r.account),hex(r.name),hex(r.realm),hex(r.class),hex(r.race),tostring(r.level)},"|")
    end
    for _,id in ipairs(keys(tm.teams)) do
        local t=tm.teams[id]
        rows[#rows+1]="T|"..hex(id).."|"..hex(t.name)
        for i=1,5 do
            local s=t.slots[i]
            if s then rows[#rows+1]=table.concat({"S",hex(id),tostring(i),hex(s.account),s.guid,s.role},"|") end
        end
    end
    if tm.active then rows[#rows+1]="X|"..hex(tm.active) end
    local data=table.concat(rows,"~")
    if #data>C.MAX then return nil,"Register exceeds sync limit." end
    return data
end
function C.Decode(data)
    if type(data)~="string" or #data>C.MAX or data:sub(1,3)~="V|1" then return nil,"Invalid register header." end
    local cm={schema=1,accounts={},characters={}}
    local tm={schema=1,teams={}}
    local nA,nC,nT=0,0,0
    local first=true
    for line in (data.."~"):gmatch("(.-)~") do
        local f={}
        for value in (line.."|"):gmatch("(.-)|") do f[#f+1]=value end
        local kind=f[1]
        if first then
            if line~="V|1" then return nil,"Invalid register version." end
            first=false
        elseif kind=="A" and #f==3 then
            local id,name=unhex(f[2],40),unhex(f[3],40)
            if not id or not name or id~=name:lower() or name:find("|",1,true) or name:match("^%s") or name:match("%s$") or cm.accounts[id] then return nil,"Invalid account." end
            nA=nA+1;if nA>100 then return nil,"Too many accounts." end
            cm.accounts[id]=name
        elseif kind=="C" and #f==8 then
            local guid,account,name,realm,class,race,level=f[2],unhex(f[3],40),unhex(f[4],120),unhex(f[5],100),unhex(f[6],40),unhex(f[7],40),tonumber(f[8])
            if not validGuid(guid) or not account or not cm.accounts[account] or not name or not realm or not class or not race or not level or level%1~=0 or level<1 or level>255 or cm.characters[guid] then return nil,"Invalid character." end
            nC=nC+1;if nC>500 then return nil,"Too many characters." end
            cm.characters[guid]={guid=guid,account=account,name=name,realm=realm,class=class,race=race,level=level}
        elseif kind=="T" and #f==3 then
            local id,name=unhex(f[2],40),unhex(f[3],40)
            if not id or not name or id~=name:lower() or name:find("|",1,true) or name:match("^%s") or name:match("%s$") or tm.teams[id] then return nil,"Invalid team." end
            nT=nT+1;if nT>200 then return nil,"Too many teams." end
            tm.teams[id]={id=id,name=name,slots={}}
        elseif kind=="S" and #f==6 then
            local id,pos,account,guid,role=unhex(f[2],40),tonumber(f[3]),unhex(f[4],40),f[5],f[6]
            local t=id and tm.teams[id]
            local r=cm.characters[guid]
            if not t or not pos or pos%1~=0 or pos<1 or pos>5 or t.slots[pos] or not account or not r or r.account~=account or (role~="tank" and role~="healer" and role~="dps") then return nil,"Invalid team position." end
            t.slots[pos]={account=account,guid=guid,role=role}
        elseif kind=="X" and #f==2 then
            local id=unhex(f[2],40)
            if tm.active or not id or not tm.teams[id] then return nil,"Invalid active team." end
            tm.active=id
        else return nil,"Invalid register record." end
    end
    for _,t in pairs(tm.teams) do
        local accounts,guids,gap,n={},{},false,0
        for i=1,5 do
            local s=t.slots[i]
            if not s then gap=true
            else
                if gap or accounts[s.account] or guids[s.guid] then return nil,"Invalid team order or duplicate account." end
                accounts[s.account]=true;guids[s.guid]=true;n=n+1
            end
        end
        if n<2 then return nil,"Incomplete team." end
    end
    return {cm=cm,tm=tm}
end
function C.Capture()
    if not HB.db then return nil,"Register not initialized." end
    local cm=HB.db.ownedCharacterCatalog or {schema=1,accounts={},characters={}}
    local tm=HB.db.plannedTeams or {schema=1,teams={}}
    local ok,data,e=pcall(C.Encode,cm,tm)
    if not ok or not data then return nil,e or "Invalid local register." end
    local decoded,why=C.Decode(data)
    if not decoded then return nil,why end
    return data,decoded
end

function C.EncodeLogin(r)
    if type(r)~="table" or type(r.name)~="string" or type(r.realm)~="string" or type(r.class)~="string" or type(r.race)~="string" then return nil end
    return table.concat({hex(r.name),hex(r.realm),hex(r.class),hex(r.race),tostring(r.level)},"|")
end
function C.DecodeLogin(data)
    local f={}
    for v in (data.."|"):gmatch("(.-)|") do f[#f+1]=v end
    if #f~=5 then return nil end
    local name,realm,class,race,level=unhex(f[1],120),unhex(f[2],100),unhex(f[3],40),unhex(f[4],40),tonumber(f[5])
    if not name or not realm or not class or not race or not level or level%1~=0 or level<1 or level>255 then return nil end
    return {name=name,realm=realm,class=class,race=race,level=level}
end
