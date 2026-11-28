-- HMAC-SHA256 for the local bridge key. The key is never transmitted.
-- Uses WoW's 32-bit bit operations; fail closed if unavailable.
local HB=HaploBox
local A={}
HB.RegisterPeerAuth=A
local B=bit or bit32
if not B or not B.band or not B.bxor or not B.bnot or not B.rshift or not B.lshift then return end
local band,bxor,bnot,rshift,lshift=B.band,B.bxor,B.bnot,B.rshift,B.lshift
local ror=B.ror or B.rrotate or function(x,n)return band(rshift(x,n)+lshift(x,32-n),0xffffffff)end
local K={
0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
local function pack(n)
    return string.char(band(rshift(n,24),255),band(rshift(n,16),255),band(rshift(n,8),255),band(n,255))
end
local function sha(s)
    local n=#s
    s=s.."\128"..string.rep("\0",(55-n)%64)..pack(math.floor(n/536870912))..pack((n*8)%4294967296)
    local H={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    for pos=1,#s,64 do
        local w={}
        for i=1,16 do
            local a,b,c,d=s:byte(pos+(i-1)*4,pos+(i-1)*4+3)
            w[i]=a*16777216+b*65536+c*256+d
        end
        for i=17,64 do
            local x,y=w[i-15],w[i-2]
            local u=bxor(ror(x,7),ror(x,18),rshift(x,3))
            local v=bxor(ror(y,17),ror(y,19),rshift(y,10))
            w[i]=band(w[i-16]+u+w[i-7]+v,0xffffffff)
        end
        local a,b,c,d,e,f,g,h=unpack(H)
        for i=1,64 do
            local s1=bxor(ror(e,6),ror(e,11),ror(e,25))
            local ch=bxor(band(e,f),band(bnot(e),g))
            local t1=band(h+s1+ch+K[i]+w[i],0xffffffff)
            local s0=bxor(ror(a,2),ror(a,13),ror(a,22))
            local maj=bxor(band(a,b),band(a,c),band(b,c))
            local t2=band(s0+maj,0xffffffff)
            a,b,c,d,e,f,g,h=band(t1+t2,0xffffffff),a,b,c,band(d+t1,0xffffffff),e,f,g
        end
        local v={a,b,c,d,e,f,g,h}
        for i=1,8 do H[i]=band(H[i]+v[i],0xffffffff) end
    end
    local out={}
    for i=1,8 do out[i]=pack(H[i]) end
    return table.concat(out)
end
local function hex(s)return (s:gsub(".",function(c)return string.format("%02x",c:byte())end)) end
function A.HMAC(key,msg)
    if type(key)~="string" or type(msg)~="string" then return nil end
    if #key>64 then key=sha(key) end
    key=key..string.rep("\0",64-#key)
    local ip,op={},{}
    for i=1,64 do local b=key:byte(i);ip[i]=string.char(bxor(b,54));op[i]=string.char(bxor(b,92)) end
    return hex(sha(table.concat(op)..sha(table.concat(ip)..msg)))
end
function A.Sign(key,msg)
    if type(key)~="string" or #key~=64 or key:find("[^0-9a-f]") then return nil end
    local v=A.HMAC(key,msg)
    return v and v:sub(1,24)
end
