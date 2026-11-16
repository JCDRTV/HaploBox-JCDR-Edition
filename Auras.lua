-- HaploBox Alpha 5 Testbuild 4: resilient aura pipeline for buff/HoT/debuff,
-- deterministic priority sorting, compact timers, and missing-required-buff icons.
-- The visual aura region is mouse-transparent; the secure unit row hitbox never
-- extends into this column. All aura inspection is local to the current client.
local HB = HaploBox
local HOT_IDS = {
    [774]=true,[1058]=true,[1430]=true,[2090]=true,[2091]=true,[3627]=true,
    [8910]=true,[9839]=true,[9840]=true,[9841]=true,[25299]=true,
    [26982]=true,[48440]=true,[48441]=true,[8936]=true,[8938]=true,
    [8939]=true,[8940]=true,[8941]=true,[9750]=true,[9856]=true,
    [9857]=true,[9858]=true,[26980]=true,[33763]=true,[48438]=true,[740]=true,
}
local HOT_NAMES = {rejuvenation=true,regrowth=true,lifebloom=true,["wild growth"]=true,tranquility=true}
local HOT_PRIORITY = {rejuvenation=1,regrowth=2,lifebloom=3,["wild growth"]=4,tranquility=5}
local DISPEL = {Magic={0.32,0.65,1.0},Curse={0.72,0.32,0.98},Poison={0.30,0.85,0.28},Disease={0.75,0.55,0.25}}
local DISPEL_PRIORITY = {Magic=1,Curse=2,Poison=3,Disease=4}
-- The Sleeping Bag Well-Rested aura is spell 429959 (Blizzard native texture).
local SLEEPING_BAG_XP_SPELL = 429959
local REQUIRED_ORDER = {"xp","food","camp","mark","thorns","intellect","fortitude","blessing"}
local REQUIRED = {
    xp={label="Sleeping Bag +3% XP",spell=SLEEPING_BAG_XP_SPELL,icon="Interface\\Icons\\INV_Drink_15"},
    food={label="Food",spell=0,icon="Interface\\Icons\\INV_Misc_Food_15"},
    camp={label="Camp",spell=0,icon="Interface\\Icons\\Spell_Fire_Fire"},
    mark={label="Mark of the Wild",spell=1126,icon="Interface\\Icons\\Spell_Nature_Regeneration"},
    thorns={label="Thorns",spell=467,icon="Interface\\Icons\\Spell_Nature_Thorns"},
    intellect={label="Arcane Intellect",spell=1459,icon="Interface\\Icons\\Spell_Holy_MagicalSentry"},
    fortitude={label="Power Word: Fortitude",spell=1243,icon="Interface\\Icons\\Spell_Holy_WordFortitude"},
    blessing={label="Paladin Blessing",spell=19740,icon="Interface\\Icons\\Spell_Holy_FistOfJustice"},
}
local function safe(v) return v ~= nil and (not HB.secret or not HB.secret(v)) end
local function cleanText(v)
    return safe(v) and type(v)=="string" and v:lower() or ""
end
local function family(a)
    local n=cleanText(a and a.name)
    if n=="mark of the wild" or n=="gift of the wild" then return "mark" end
    if n=="thorns" then return "thorns" end
    if n=="arcane intellect" or n=="arcane brilliance" then return "intellect" end
    if n=="power word: fortitude" or n=="prayer of fortitude" then return "fortitude" end
    if n:find("blessing of ",1,true)==1 or n:find("greater blessing of ",1,true)==1 then return "blessing" end
    -- The temporary Eating/Food aura is NOT Well Fed. Never suppress MISSING Food until
    -- a genuine completed Well Fed aura is present.
    if n=="well fed" or n=="well-fed" or n:find("well fed",1,true) then return "food" end
    -- WoW Forever: Campfire Nearby / Welcoming Campfire are only progress.
    -- "Camp Benefits" is the earned one-hour bonus; Sleeping Bag is separate.
    if n == "camp benefits" or n:find("camp benefits",1,true) then return "camp" end
    -- Only the 3-stack Sleeping Bag reward satisfies the REQUIRED XP alert.
    -- Student Fodder and other XP gains remain visible buffs, not substitutions.
    if n == "well-rested" or (safe(a and a.id) and a.id == SLEEPING_BAG_XP_SPELL) then return "xp" end
end
local function aura(unit,index,filter)
    local helpful=filter=="HELPFUL"
    if C_UnitAuras then
        local fn=helpful and C_UnitAuras.GetBuffDataByIndex or C_UnitAuras.GetDebuffDataByIndex
        local data
        if fn then
            local ok,a=pcall(fn,unit,index)
            if ok and type(a)=="table" and safe(a.name) then data=a end
        end
        if not data and C_UnitAuras.GetAuraDataByIndex then
            local ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,filter)
            if ok and type(a)=="table" and safe(a.name) then data=a end
        end
        if data then
            local artwork=data.icon
            if not safe(artwork) and safe(data.spellId) then
                local fn=(C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
                if fn then local ok,v=pcall(fn,data.spellId);if ok and safe(v) then artwork=v end end
            end
            return {icon=artwork or "Interface\\Icons\\INV_Misc_QuestionMark",id=data.spellId,name=data.name,expiration=data.expirationTime,
                duration=data.duration,dispel=data.dispelName,source=data.sourceUnit,count=data.applications}
        end
    end
    local fn=helpful and UnitBuff or UnitDebuff
    if fn then
        local ok,name,texture,count,dtype,duration,expiration,source,_,_,id=pcall(fn,unit,index)
        if ok and safe(name) and safe(texture) then
            return {name=name,icon=texture,count=count,dispel=dtype,duration=duration,
                expiration=expiration,source=source,id=id}
        end
    end
    if UnitAura then
        local ok,name,texture,count,dtype,duration,expiration,source,_,_,id=pcall(UnitAura,unit,index,filter)
        if ok and safe(name) and safe(texture) then
            return {name=name,icon=texture,count=count,dispel=dtype,duration=duration,
                expiration=expiration,source=source,id=id}
        end
    end
end
local function isHot(a)
    return (safe(a.id) and HOT_IDS[a.id]) or
        (safe(a.name) and HOT_NAMES[cleanText(a.name)]) or false
end
local function icon(parent)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetTexCoord(0.08,0.92,0.08,0.92)
    local sides={}
    for i=1,4 do
        local edge=parent:CreateTexture(nil,"OVERLAY")
        edge:SetColorTexture(0,0,0,0)
        sides[i]=edge
    end
    local stack=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    stack:SetPoint("TOPRIGHT",t,"TOPRIGHT",-1,-1)
    stack:SetJustifyH("RIGHT")
    stack:SetWordWrap(false)
    stack:SetShadowOffset(1,-1)
    if STANDARD_TEXT_FONT then stack:SetFont(STANDARD_TEXT_FONT,9,"OUTLINE") end
    stack:SetText("")
    local font=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    font:SetPoint("BOTTOM",t,"BOTTOM",0,1)
    font:SetJustifyH("CENTER")
    font:SetJustifyV("BOTTOM")
    font:SetWordWrap(false)
    font:SetTextColor(1,1,1,1)
    font:SetShadowOffset(1,-1)
    font:SetText("")
    t:Hide()
    return {tex=t,sides=sides,time=font,stack=stack,aura=nil}
end
local function setSize(o,width)
    o.tex:SetSize(width,width)
    -- A smaller font prevents WoW's own text truncation/ellipsis in 20px icons.
    o.time:SetWidth(math.max(10,width-2))
    o.time:SetHeight(math.max(9,math.floor(width*0.48)))
    o.timerFontSize=math.max(7,math.min(9,math.floor(width*0.34)))
    o.stack:SetWidth(math.max(width+8,36)) -- full XP 1/3, 2/3, 3/3 without crop
    o.stack:SetHeight(12)
    if STANDARD_TEXT_FONT and o.time.SetFont then
        o.time:SetFont(STANDARD_TEXT_FONT,o.timerFontSize,"OUTLINE")
    end
    local t=o.tex
    local e=o.sides
    e[1]:ClearAllPoints();e[1]:SetPoint("TOPLEFT",t,"TOPLEFT");e[1]:SetSize(width,1)
    e[2]:ClearAllPoints();e[2]:SetPoint("BOTTOMLEFT",t,"BOTTOMLEFT");e[2]:SetSize(width,1)
    e[3]:ClearAllPoints();e[3]:SetPoint("TOPLEFT",t,"TOPLEFT");e[3]:SetSize(1,width)
    e[4]:ClearAllPoints();e[4]:SetPoint("TOPRIGHT",t,"TOPRIGHT");e[4]:SetSize(1,width)
end
local function sides(o,c)
    for _,e in ipairs(o.sides) do
        if c then e:SetColorTexture(c[1],c[2],c[3],c[4] or 1)
        else e:SetColorTexture(0,0,0,0) end
    end
end
local function setIcon(o,a,warning)
    o.aura=a
    if a and safe(a.icon) then
        o.tex:SetTexture(a.icon)
        o.tex:Show()
        sides(o,warning and {0.95,0.19,0.13,1} or (safe(a.dispel) and DISPEL[a.dispel] or nil))
        local c=a.count
        if safe(c) and type(c)=="number" and c>=(warning and 1 or 2) then
            o.stack:SetText(warning and (tostring(c).."/3") or tostring(c))
        else o.stack:SetText("") end
    else
        o.tex:Hide()
        o.time:SetText("")
        o.stack:SetText("")
        sides(o,nil)
    end
end
local function fitTimer(o, label)
    o.time:SetText(label)
    if o.isNormalBuff then
        -- WoW may render "..." on a narrow FontString. Prefer a shorter,
        -- meaningful timer (never literal ellipses), using the fixed 8px size.
        if STANDARD_TEXT_FONT and o.time.SetFont then
            o.time:SetFont(STANDARD_TEXT_FONT,o.timerFontSize or 8,"OUTLINE")
        end
        if label~="" and o.time.GetUnboundedStringWidth then
            local ok,w=pcall(o.time.GetUnboundedStringWidth,o.time)
            local maxW=o.time:GetWidth()
            if ok and safe(w) and type(w)=="number" and
               safe(maxW) and type(maxW)=="number" and w>maxW then
                -- Very constrained UI scales: keep just two digits rather
                -- than letting FontString substitute an unreadable "...".
                local digits=label:match("^(%d+)")
                if digits then o.time:SetText(digits:sub(1,2)) end
            end
        end
        return
    end
    if not (STANDARD_TEXT_FONT and o.time.SetFont and label ~= "") then return end
    local fontSize = o.timerFontSize or 7
    local limit = math.max(10, o.time:GetWidth())
    o.time:SetFont(STANDARD_TEXT_FONT,fontSize,"OUTLINE")
    -- Text must never become clipped or replaced by WoW ellipsis. A smaller
    -- font is preferred to expanding the text beyond the existing HoT icon.
    if o.time.GetUnboundedStringWidth then
        local width = o.time:GetUnboundedStringWidth()
        while type(width)=="number" and safe(width) and width>limit and fontSize>6 do
            fontSize=fontSize-0.5
            o.time:SetFont(STANDARD_TEXT_FONT,fontSize,"OUTLINE")
            width=o.time:GetUnboundedStringWidth()
        end
    end
end
local function updateTime(o)
    local a=o.aura
    if not a or not o.tex:IsShown() then return end
    local expiration,duration=a.expiration,a.duration
    if not (safe(expiration) and safe(duration) and type(expiration)=="number"
        and type(duration)=="number" and duration>0) then fitTimer(o,"");return end
    local remaining=expiration-GetTime()
    if not safe(remaining) or type(remaining)~="number" or remaining<=0 then
        fitTimer(o,"");return
    end
    if o.isNormalBuff then
        if remaining<=60 then o.time:SetTextColor(1,1,1,1)
        else o.time:SetTextColor(1,0.83,0.49,1) end
    end
    if o.isNormalBuff and remaining>=3600 then
        fitTimer(o,tostring(math.min(99,math.ceil(remaining/3600))).."h")
    elseif remaining>=60 then fitTimer(o,tostring(math.ceil(remaining/60)).."m")
    else fitTimer(o,tostring(math.max(1,math.floor(remaining)))) end
end
local function sourceName(a)
    if not safe(a.source) or type(a.source)~="string" then return "" end
    if UnitName then
        local ok,n=pcall(UnitName,a.source)
        if ok and safe(n) and type(n)=="string" then return n:lower() end
    end
    return cleanText(a.source)
end
local function stableSort(items,kind)
    local keys={}
    for _,a in ipairs(items) do
        local name=cleanText(a.name)
        local f=family(a)
        local priority=99
        if kind=="buff" then
            if f then for i,k in ipairs(REQUIRED_ORDER) do if k==f then priority=i break end end end
        elseif kind=="hot" then priority=HOT_PRIORITY[name] or 99
        else priority=DISPEL_PRIORITY[a.dispel] or 99 end
        keys[a]={priority=priority,name=name,id=safe(a.id) and type(a.id)=="number" and a.id or 0,
            source=sourceName(a)}
    end
    table.sort(items,function(a,b)
        local x,y=keys[a],keys[b]
        if x.priority~=y.priority then return x.priority<y.priority end
        -- Personal extras are sorted by numeric spell ID, not alphabetically.
        if x.priority==99 and kind=="buff" and x.id~=y.id then return x.id<y.id end
        if x.name~=y.name then return x.name<y.name end
        if x.id~=y.id then return x.id<y.id end
        return x.source<y.source
    end)
end
-- 12.1+ Forever client: during combat the Lua-facing aura fields become
-- secret, and in later clients the index APIs refuse access entirely. The
-- engine-owned AuraContainer is the supported way to render live auras then.
-- The container classifies and changes icons itself, WITHOUT exposing secret
-- spell IDs, icons or expiration data to our addon code. On older clients we
-- retain the existing legacy renderer with an expiry-bounded combat fallback.
local BUFF_ROW_H, BUFF_ICON, BUFF_STEP, BUFF_NUM_W = 41,27,30,37
-- Each number tile is ICON-sized and uses the existing timer-provided row gap.
-- Debuff icons remain their original distinct size (24px): no row/timer changes.
local DEBUFF_ROW_H,DEBUFF_ICON,DEBUFF_STEP,DEBUFF_NUM_W=38,24,27,37
-- TB18.3 / P1: ONE horizontal HoT row, exactly the height of the blue
-- INNER FACE of Focus (excluding gold edges). Never wrap into a second row.
-- This resolves the conflicting 2-row size/height requirements: there is
-- now one full-height icon per cell and additional HoTs flow RIGHT.
local HOT_COLUMNS, HOT_BORDER_INSET=16,2
local function hotGeometry(focusH)
    local blueH=math.max(8,(focusH or 0)-2*HOT_BORDER_INSET)
    return blueH,blueH
end
local function nativeAuraButton(button,size,timerBelow)
    button:SetSize(size,size)
    button:EnableMouse(false) -- aura display must NEVER obstruct world clicks
    local artwork=button:CreateTexture(nil,"ARTWORK")
    artwork:SetAllPoints(button)
    artwork:SetTexCoord(0.08,0.92,0.08,0.92)
    button:SetIcon(artwork)
    local timer=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    if timerBelow then
        timer:SetPoint("TOP",button,"BOTTOM",0,-1)
    else
        timer:SetPoint("BOTTOM",button,"BOTTOM",0,1)
    end
    timer:SetSize(size+8,timerBelow and 8 or 10)
    timer:SetJustifyH("CENTER")
    timer:SetJustifyV("TOP")
    timer:SetWordWrap(false)
    timer:SetShadowOffset(1,-1)
    if STANDARD_TEXT_FONT then timer:SetFont(STANDARD_TEXT_FONT,math.max(6,math.min(8,size*0.4)),"OUTLINE") end
    if timerBelow then timer:SetTextColor(1,0.83,0.49,1) end
    if button.SetDurationText then button:SetDurationText(timer) end
    -- Blizzard owns this stack label, including secret aura values in combat.
    local stack=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    stack:SetPoint("TOPRIGHT",button,"TOPRIGHT",-1,-1)
    stack:SetSize(math.max(size+8,36),12) -- no clipped XP stack numerals
    stack:SetJustifyH("RIGHT")
    stack:SetWordWrap(false)
    stack:SetShadowOffset(1,-1)
    if STANDARD_TEXT_FONT then stack:SetFont(STANDARD_TEXT_FONT,size<18 and 7 or 9,"OUTLINE") end
    -- The engine owns protected stack values. Allow single-stack application
    -- labels where the 12.1+ client exposes them (e.g. Camp Benefits).
    if button.SetApplicationCount then pcall(button.SetApplicationCount,button,stack,{minApplications=1}) end
    for side=1,4 do
        local edge=button:CreateTexture(nil,"OVERLAY")
        edge:SetColorTexture(0.52,0.57,0.64,0.9)
        if side==1 then edge:SetPoint("TOPLEFT");edge:SetPoint("TOPRIGHT");edge:SetHeight(1)
        elseif side==2 then edge:SetPoint("BOTTOMLEFT");edge:SetPoint("BOTTOMRIGHT");edge:SetHeight(1)
        elseif side==3 then edge:SetPoint("TOPLEFT");edge:SetPoint("BOTTOMLEFT");edge:SetWidth(1)
        else edge:SetPoint("TOPRIGHT");edge:SetPoint("BOTTOMRIGHT");edge:SetWidth(1) end
    end
end
local function makeNativeAura(parent,kind,filter,count,size,candidates,timerBelow,fromRight,columns)
    local ok,container=pcall(CreateFrame,"AuraContainer",nil,parent,"CustomAuraContainerTemplate")
    if not ok or not container or not container.AddAuraGroup or not container.SetUnit then return nil end
    local success=pcall(function()
        container:EnableMouse(false)
        -- The engine needs positive dimensions *before* the group is added.
        -- A HoT group has enough width for ALL 16 icons in ONE row.
        container:SetSize((columns or count)*(size+3)+3,size)
        local anchor=container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
        local growth=container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
        if anchor then anchor(container,fromRight and "TOPRIGHT" or "TOPLEFT") end
        if growth and AnchorUtil and AnchorUtil.FlowDirection then
            -- Native Blizzard container still owns all combat aura presentation.
            -- Only the visual FLOW direction differs for the upper-right panel.
            local fd=AnchorUtil.FlowDirection
            growth(container,fromRight and (fd.Left or fd.Right) or fd.Right,fd.Down)
        end
        container:AddAuraGroup(kind,filter,{
            maxFrameCount=count,
            candidateFilters=candidates or {},
            layout={elementWidth=size,elementHeight=size,elementSpacing=3,lineSpacing=5},
            initializeFrame=function(button) nativeAuraButton(button,size,timerBelow) end,
        })
        container:Show()
    end)
    if not success then pcall(container.Hide,container);return nil end
    return container
end
-- Classic/legacy clients do not expose the 12.1 intrinsic. They use the
-- original out-of-combat aura algorithm with a combat snapshot fallback.
local function setupNativeAuras(r)
    r.nativeBuff=makeNativeAura(r.buffArea,"normal","HELPFUL",16,BUFF_ICON,{excludeSpellIDs=HOT_IDS},true,true)
    -- FocusTile has already been sized by Party before creation, so the
    -- intrinsic Blizzard aura group gets its CORRECT button dimensions.
    local hotCell=hotGeometry(r.focusTile:GetHeight())
    r.hotNativeCell=hotCell
    r.nativeHots=makeNativeAura(r.auraArea,"hots","HELPFUL",16,hotCell,{includeSpellIDs=HOT_IDS},false,false,HOT_COLUMNS)
    r.nativeDebuffs=makeNativeAura(r.debuffArea,"debuffs","HARMFUL",16,DEBUFF_ICON,{},true,false)
    if r.nativeBuff and r.nativeHots and r.nativeDebuffs then
        r.nativeAurasReady=true
        HB.auraEngine="Blizzard native (live combat)"
        for _,group in ipairs({r.hots,r.debuffs,r.buffIcons}) do
            for _,o in ipairs(group) do o.tex:Hide();o.time:SetText("") end
        end
    else
        -- Partial setup must not create duplicate/overlapping aura rows.
        for _,c in ipairs({r.nativeBuff,r.nativeHots,r.nativeDebuffs}) do
            if c then pcall(c.Hide,c) end
        end
        r.nativeAurasReady=false
        if not HB.auraEngine then HB.auraEngine="legacy (combat snapshot only)" end
    end
end
function HB.BindAuraUnit(r)
    if not r.nativeAurasReady or not r.unit then return end
    local success=true
    for _,c in ipairs({r.nativeBuff,r.nativeHots,r.nativeDebuffs}) do
        if not pcall(c.SetUnit,c,r.unit) then success=false end
    end
    if not success then
        r.nativeAurasReady=false
        HB.auraEngine="legacy (native SetUnit failed)"
        for _,c in ipairs({r.nativeBuff,r.nativeHots,r.nativeDebuffs}) do pcall(c.Hide,c) end
    end
end
-- TB15: visually independent, mouse-transparent five-player Buff/Missing panel.
-- The existing aura engine, timers, missing detection and secure native containers
-- are intentionally unchanged. This only moves their DISPLAY parents and anchors.
local MAX_BUFFS, MAX_MISSING = 16,#REQUIRED_ORDER
local buffOverview
-- TB19.1c: visual HP-bar-style SQUARE numeral tile, sized to the existing
-- icon on that rail. Existing buff/debuff aura scanners, timers and secure UI
-- handling are not changed here. Badge carries the old class-colour tint.
local function styleOverviewNumber(text,iconSize)
    local face=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    text:SetFont(face,iconSize>=27 and 15 or 14,"THICKOUTLINE")
    text:SetSize(iconSize,iconSize)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(1,1,0.98,1)
    text:SetShadowColor(0,0,0,1)
    text:SetShadowOffset(0,0) -- outlined numeral is centered in the square
end
local function makeOverviewNumberTile(parent,iconSize,point,relative,x,y)
    local tile=parent:CreateTexture(nil,"ARTWORK")
    tile:SetColorTexture(1,1,1,0.90)
    tile:SetSize(iconSize,iconSize)
    tile:SetVertexColor(1,0.49,0.04,0.98) -- class-colour updated as before
    tile:SetPoint(point,parent,relative,x,y)
    -- Straight borders and thin highlight, same rectangular geometry as HP.
    for edge=1,4 do
        local t=parent:CreateTexture(nil,"OVERLAY")
        t:SetColorTexture(0.025,0.035,0.045,0.98)
        if edge==1 then t:SetPoint("TOPLEFT",tile,"TOPLEFT",0,0)
            t:SetPoint("TOPRIGHT",tile,"TOPRIGHT",0,0);t:SetHeight(1)
        elseif edge==2 then t:SetPoint("BOTTOMLEFT",tile,"BOTTOMLEFT",0,0)
            t:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",0,0);t:SetHeight(1)
        elseif edge==3 then t:SetPoint("TOPLEFT",tile,"TOPLEFT",0,0)
            t:SetPoint("BOTTOMLEFT",tile,"BOTTOMLEFT",0,0);t:SetWidth(1)
        else t:SetPoint("TOPRIGHT",tile,"TOPRIGHT",0,0)
            t:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",0,0);t:SetWidth(1) end
    end
    local accent=parent:CreateTexture(nil,"OVERLAY")
    accent:SetColorTexture(0.69,0.55,0.28,0.91)
    accent:SetPoint("TOPLEFT",tile,"TOPLEFT",1,-1)
    accent:SetPoint("TOPRIGHT",tile,"TOPRIGHT",-1,-1)
    accent:SetHeight(1)
    return tile
end
local function ensureBuffOverview()
    if buffOverview then return buffOverview end
    local f=CreateFrame("Frame","HaploBoxBuffOverview",UIParent)
    -- Compact draggable anchor: visible even if aura trails extend off-screen.
    -- Aura rails may extend LEFT; the actual movable frame/handle never can.
    f:SetSize(BUFF_NUM_W,BUFF_ROW_H*5)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetClampedToScreen(true)
    local saved=HB.db and HB.db.buffOverviewPos
    local uiW,uiH=UIParent:GetWidth() or 1200,UIParent:GetHeight() or 800
    local px=(type(saved)=="table" and type(saved[1])=="number") and saved[1] or -205
    local py=(type(saved)=="table" and type(saved[2])=="number") and saved[2] or -68
    px=math.max(-math.max(40,uiW-f:GetWidth()-8),math.min(-8,px))
    py=math.max(-math.max(40,uiH-f:GetHeight()-8),math.min(-8,py))
    f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",px,py)
    f.rows={}
    f.labels={}
    f.badges={}
    for i=1,5 do
        local bg=makeOverviewNumberTile(f,BUFF_ICON,"TOPRIGHT","TOPRIGHT",-5,-((i-1)*BUFF_ROW_H+5))
        f.badges[i]=bg
        local n=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        n:ClearAllPoints()
        -- FRIZQT numerals paint high/left within a centered FontString.
        -- Image-checked optical glyph centering in the 27px orange tile.
        n:SetPoint("CENTER",bg,"CENTER",2,-3)
        styleOverviewNumber(n,BUFF_ICON)
        n:SetText(tostring(i))
        f.labels[i]=n
    end
    local line=f:CreateTexture(nil,"OVERLAY")
    line:SetColorTexture(0.72,0.74,0.78,0.75)
    line:SetSize(1,BUFF_ROW_H*5-10)
    f.divider=line
    local grip=CreateFrame("Button",nil,f)
    grip:SetSize(BUFF_ICON,BUFF_ICON)
    grip:SetPoint("TOPRIGHT",f,"TOPRIGHT",-3,-3)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart",function()
        if InCombatLockdown and InCombatLockdown() then return end
        f:StartMoving()
    end)
    grip:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x=(f:GetRight() or 0)-(UIParent:GetRight() or 0)
        local y=(f:GetTop() or 0)-(UIParent:GetTop() or 0)
        x=math.max(-math.max(40,(UIParent:GetWidth() or 1200)-f:GetWidth()-8),math.min(-8,x))
        y=math.max(-math.max(40,(UIParent:GetHeight() or 800)-f:GetHeight()-8),math.min(-8,y))
        if HB.db then HB.db.buffOverviewPos={x,y} end
        f:ClearAllPoints()
        f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",x,y)
    end)
    local shade=grip:CreateTexture(nil,"BACKGROUND")
    shade:SetAllPoints();shade:SetColorTexture(0,0,0,0)
    local label=grip:CreateTexture(nil,"OVERLAY")
    label:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    label:SetSize(17,17)
    label:SetPoint("CENTER")
    label:SetVertexColor(1,0.82,0.40,0) -- invisible drag overlay, numeral remains readable
    f.grip=grip
    grip:SetShown(HB.db and HB.db.buffOverviewUnlocked or false)
    buffOverview=f
    f:Hide()
    return f
end
function HB.SetBuffOverviewUnlocked(value)
    if InCombatLockdown and InCombatLockdown() then return false end
    if HB.db then HB.db.buffOverviewUnlocked=value and true or false end
    if buffOverview then buffOverview.grip:SetShown(value and true or false) end
    return true
end
function HB.ResetBuffOverviewPosition()
    if InCombatLockdown and InCombatLockdown() then return false end
    if HB.db then HB.db.buffOverviewPos=nil end
    if buffOverview then
        buffOverview:StopMovingOrSizing()
        buffOverview:ClearAllPoints()
        buffOverview:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-205,-68)
        -- The map alignment is a default ONLY after an intentional reset.
        if HB.PositionDefaultBuffOverview then HB.PositionDefaultBuffOverview() end
    end
    return true
end
function HB.AttachBuffOverviewRow(r)
    local f=ensureBuffOverview()
    -- Parent only these ordinary display frames, not a SecureUnitButton or aura
    -- scanning state. Native C-side Buff button stays a child of buffArea.
    r.buffArea:SetParent(f)
    r.missingArea:SetParent(f)
    f.rows[#f.rows+1]=r
    r.buffOverviewIndex=#f.rows
    r.buffShownCount=0
    r.buffArea:Hide();r.missingArea:Hide()
end
function HB.AlignBuffOverview()
    if not buffOverview then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local f=buffOverview
    local maxActive=0
    for _,r in ipairs(f.rows) do
        if r.buffOverviewVisible then
            maxActive=math.max(maxActive,math.min(MAX_BUFFS,r.buffShownCount or 0))
        end
    end
    -- TB19.1i: a single aligned divider for all five rows. The missing
    -- rail starts just LEFT of it, leaving a small visible gap on each side.
    local offset=BUFF_NUM_W+maxActive*BUFF_STEP+5
    local dividerOffset=offset
    local right=f.GetRight and f:GetRight()
    local uiLeft=UIParent and UIParent.GetLeft and UIParent:GetLeft()
    if type(right)=="number" and type(uiLeft)=="number" and
        not (issecretvalue and (issecretvalue(right) or issecretvalue(uiLeft))) then
        local fs=(f.GetEffectiveScale and f:GetEffectiveScale()) or 1
        local us=(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if type(fs)=="number" and fs>0 and type(us)=="number" then
            local available=(right*fs-uiLeft*us)/fs-8
            if available>0 then dividerOffset=math.min(offset,math.max(3,available)) end
        end
    end
    f.divider:ClearAllPoints()
    f.divider:SetPoint("TOPRIGHT",f,"TOPRIGHT",-dividerOffset,-4)
    f.divider:Show()
    for _,r in ipairs(f.rows) do
        local i=r.buffOverviewIndex
        local top=(i-1)*BUFF_ROW_H+5
        r.buffArea:ClearAllPoints()
        r.buffArea:SetPoint("TOPRIGHT",f,"TOPRIGHT",-BUFF_NUM_W,-top)
        r.missingArea:ClearAllPoints()
        -- Use ONE stable column boundary; missing icons never collide with
        -- buff icons or jump horizontally when a row changes buff count.
        -- The divider sits 5px beyond the widest active row; the missing
        -- rail starts a further 7px beyond the divider.
        r.missingArea:SetPoint("TOPRIGHT",f,"TOPRIGHT",-(offset+7),-top)
    end
end
function HB.LayoutBuffOverview(active,rows)
    if not buffOverview then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local f=buffOverview
    -- Two independent menu toggles, neither changes any aura scanner.
    active=active and (not HB.db or HB.db.buffOverviewEnabled~=false)
    f:SetShown(active and true or false)
    for i,r in ipairs(f.rows) do
        local visible=active and rows and rows[i] == r and r:IsShown()
        r.buffOverviewVisible=visible and true or false
        r.buffArea:SetShown(r.buffOverviewVisible)
        r.missingArea:SetShown(r.buffOverviewVisible)
        f.labels[i]:SetShown(r.buffOverviewVisible)
        f.badges[i]:SetShown(r.buffOverviewVisible)
        if r.buffOverviewVisible then HB.SetAuraBadgeClassColor(f.badges[i],r) end
    end
    HB.AlignBuffOverview()
end

-- TB16: mirror-image 5-row Debuff Overview, with draggable independent anchor.
local MAX_DEBUFFS=16
local debuffOverview
local function classColorForAuraRow(r)
    local file
    if r and r.unit and UnitClass then
        local ok,_,v=pcall(UnitClass,r.unit)
        if ok and safe(v) and type(v)=="string" then file=v end
    end
    local cc=file and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[file]
    if cc then return cc.r,cc.g,cc.b end
    if file=="DRUID" or not file then return 1.0,0.49,0.04 end
    return 0.72,0.72,0.72
end
function HB.SetAuraBadgeClassColor(badge,r)
    if not badge then return end
    badge:SetVertexColor(classColorForAuraRow(r))
end
local function ensureDebuffOverview()
    if debuffOverview then return debuffOverview end
    local f=CreateFrame("Frame","HaploBoxDebuffOverview",UIParent)
    -- Narrow draggable anchor with icons extending right, making the
    -- drag handle reachable even when the icon rail is wider than the viewport.
    f:SetSize(DEBUFF_NUM_W,DEBUFF_ROW_H*5)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetClampedToScreen(true)
    local pos=HB.db and HB.db.debuffOverviewPos
    local uiW,uiH=UIParent:GetWidth() or 1200,UIParent:GetHeight() or 800
    local px=(type(pos)=="table" and type(pos[1])=="number") and pos[1] or 24
    local py=(type(pos)=="table" and type(pos[2])=="number") and pos[2] or 260
    px=math.max(8,math.min(math.max(8,uiW-f:GetWidth()-8),px))
    py=math.max(8,math.min(math.max(8,uiH-f:GetHeight()-8),py))
    f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",px,py)
    f.rows={};f.labels={};f.badges={}
    for i=1,5 do
        local bg=makeOverviewNumberTile(f,DEBUFF_ICON,"TOPLEFT","TOPLEFT",5,-((i-1)*DEBUFF_ROW_H+5))
        f.badges[i]=bg
        local n=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        n:SetPoint("CENTER",bg,"CENTER",1,-2)
        styleOverviewNumber(n,DEBUFF_ICON)
        n:SetText(tostring(i))
        f.labels[i]=n
    end
    local grip=CreateFrame("Button",nil,f)
    grip:SetSize(DEBUFF_ICON,DEBUFF_ICON)
    grip:SetPoint("TOPLEFT",f,"TOPLEFT",3,-3)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart",function()
        if InCombatLockdown and InCombatLockdown() then return end
        f:StartMoving()
    end)
    grip:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x=(f:GetLeft() or 24)-(UIParent:GetLeft() or 0)
        local y=(f:GetBottom() or 260)-(UIParent:GetBottom() or 0)
        x=math.max(8,math.min(math.max(8,(UIParent:GetWidth() or 1200)-f:GetWidth()-8),x))
        y=math.max(8,math.min(math.max(8,(UIParent:GetHeight() or 800)-f:GetHeight()-8),y))
        if HB.db then HB.db.debuffOverviewPos={x,y} end
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
    end)
    local bg=grip:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints();bg:SetColorTexture(0,0,0,0)
    local txt=grip:CreateTexture(nil,"OVERLAY")
    txt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    txt:SetSize(17,17)
    txt:SetPoint("CENTER")
    txt:SetVertexColor(1,0.82,0.40,0) -- no old drag glyph across numeral
    f.grip=grip
    grip:SetShown(HB.db and HB.db.debuffOverviewUnlocked or false)
    debuffOverview=f
    f:Hide()
    return f
end
function HB.AttachDebuffOverviewRow(r)
    local f=ensureDebuffOverview()
    r.debuffArea:SetParent(f)
    f.rows[#f.rows+1]=r
    r.debuffOverviewIndex=#f.rows
    r.debuffArea:Hide()
end
function HB.AlignDebuffOverview()
    if not debuffOverview or (InCombatLockdown and InCombatLockdown()) then return end
    for _,r in ipairs(debuffOverview.rows) do
        r.debuffArea:ClearAllPoints()
        r.debuffArea:SetPoint("TOPLEFT",debuffOverview,"TOPLEFT",DEBUFF_NUM_W,-((r.debuffOverviewIndex-1)*DEBUFF_ROW_H+5))
    end
end
function HB.LayoutDebuffOverview(active,rows)
    if not debuffOverview or (InCombatLockdown and InCombatLockdown()) then return end
    local f=debuffOverview
    active=active and (HB.db and HB.db.debuffOverviewEnabled)
    f:SetShown(active and true or false)
    for i,r in ipairs(f.rows) do
        local visible=active and rows and rows[i]==r and r:IsShown()
        r.debuffOverviewVisible=not not visible
        r.debuffArea:SetShown(r.debuffOverviewVisible)
        f.labels[i]:SetShown(r.debuffOverviewVisible)
        f.badges[i]:SetShown(r.debuffOverviewVisible)
        if r.debuffOverviewVisible then HB.SetAuraBadgeClassColor(f.badges[i],r) end
    end
    HB.AlignDebuffOverview()
    if HB.ApplyBlizzardAuraVisibility then HB.ApplyBlizzardAuraVisibility() end
end
function HB.SetDebuffOverviewUnlocked(value)
    if InCombatLockdown and InCombatLockdown() then return false end
    if HB.db then HB.db.debuffOverviewUnlocked=not not value end
    if debuffOverview then debuffOverview.grip:SetShown(not not value) end
    return true
end
function HB.ResetDebuffOverviewPosition()
    if InCombatLockdown and InCombatLockdown() then return false end
    if HB.db then HB.db.debuffOverviewPos=nil end
    if debuffOverview then
        debuffOverview:StopMovingOrSizing()
        debuffOverview:ClearAllPoints()
        debuffOverview:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",24,260)
    end
    return true
end
function HB.SetOverviewEnabled(kind,enabled)
    if not HB.db or (InCombatLockdown and InCombatLockdown()) then return false end
    local field=kind=="buff" and "buffOverviewEnabled" or kind=="debuff" and "debuffOverviewEnabled"
    if not field then return false end
    HB.db[field]=not not enabled
    if HB.LayoutPartyFrame then HB.LayoutPartyFrame() end
    if HB.ApplyBlizzardAuraVisibility then HB.ApplyBlizzardAuraVisibility() end
    if HB.RefreshControls then HB.RefreshControls() end
    return true
end
-- Default Blizzard bars are replaced only while their JCDRbox alternative
-- is genuinely displayed. NEVER reparent/alter secure Blizzard frames in combat.
local savedBlizzard={}
local pendingBlizzard=false
local function ancestorOf(a,b)
    local node=b and b.GetParent and b:GetParent()
    while node do
        if node==a then return true end
        node=node.GetParent and node:GetParent()
    end
end
local function disableDefaultAuraMouse(record,frame,depth)
    if depth>5 or not frame then return end
    if record.mouse[frame]==nil and frame.IsMouseEnabled then
        local ok,enabled=pcall(frame.IsMouseEnabled,frame)
        if ok then record.mouse[frame]=not not enabled end
    end
    if frame.EnableMouse then pcall(frame.EnableMouse,frame,false) end
    if frame.GetChildren then
        local ok,children=pcall(function() return {frame:GetChildren()} end)
        if ok and children then
            for _,child in ipairs(children) do disableDefaultAuraMouse(record,child,depth+1) end
        end
    end
end
local function setDefaultAuraVisible(frame,wantHidden)
    if not frame then return end
    if InCombatLockdown and InCombatLockdown() then pendingBlizzard=true return end
    local record=savedBlizzard[frame]
    if wantHidden then
        if not record then
            local alpha=frame.GetAlpha and frame:GetAlpha() or 1
            record={alpha=alpha,mouse={}}
            savedBlizzard[frame]=record
        end
        -- Keep engine-side aura updates alive. Hide pixels AND mouse hitboxes;
        -- changing Blizzard secure frame properties in combat is forbidden.
        pcall(frame.SetAlpha,frame,0)
        disableDefaultAuraMouse(record,frame,0)
    elseif record then
        pcall(frame.SetAlpha,frame,record.alpha or 1)
        for object,enabled in pairs(record.mouse) do
            if object and object.EnableMouse then pcall(object.EnableMouse,object,enabled) end
        end
        savedBlizzard[frame]=nil
    end
end
function HB.ApplyBlizzardAuraVisibility()
    if InCombatLockdown and InCombatLockdown() then pendingBlizzard=true return false end
    pendingBlizzard=false
    local b=_G.BuffFrame
    local d=_G.DebuffFrame
    local buffVisible=buffOverview and buffOverview:IsShown()
    local debuffVisible=debuffOverview and debuffOverview:IsShown()
    -- Some client builds put DebuffFrame UNDER BuffFrame; in that case a
    -- whole-parent fade would hide BOTH, so preserve native buffs instead.
    setDefaultAuraVisible(b,buffVisible and not ancestorOf(b,d))
    setDefaultAuraVisible(d,debuffVisible)
    return true
end
function HB.GetBuffOverviewFractions()
    local f=buffOverview
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if not f or not w or not h or w<=0 or h<=0 then return nil end
    local x,y=f:GetRight(),f:GetTop()
    if not (safe(x) and safe(y)) then return nil end
    return math.max(0,math.min(1,((UIParent:GetRight() or 0)-x)/w)),
           math.max(0,math.min(1,((UIParent:GetTop() or 0)-y)/h))
end
function HB.SetBuffOverviewFractions(x,y)
    if not buffOverview or not HB.db or (InCombatLockdown and InCombatLockdown()) then return false end
    if type(x)~="number" or type(y)~="number" or x<0 or x>1 or y<0 or y>1 then return false end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if not w or not h then return false end
    local px=-math.min(x*w,math.max(8,w-buffOverview:GetWidth()-8))
    local py=-math.min(y*h,math.max(8,h-buffOverview:GetHeight()-8))
    px=math.min(-8,px);py=math.min(-8,py)
    buffOverview:ClearAllPoints()
    buffOverview:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",px,py)
    HB.db.buffOverviewPos={px,py}
    return true
end

-- Normalized Debuff Overview anchor, used by full Share UI to Party.
function HB.GetDebuffOverviewFractions()
    if not debuffOverview then return nil end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if not w or not h or w<=0 or h<=0 then return nil end
    local x,y=debuffOverview:GetLeft(),debuffOverview:GetBottom()
    if not (safe(x) and safe(y) and type(x)=="number" and type(y)=="number") then return nil end
    return math.max(0,math.min(1,(x-(UIParent:GetLeft() or 0))/w)),
           math.max(0,math.min(1,(y-(UIParent:GetBottom() or 0))/h))
end
function HB.SetDebuffOverviewFractions(x,y)
    if not debuffOverview or not HB.db or (InCombatLockdown and InCombatLockdown()) then return false end
    if type(x)~="number" or type(y)~="number" or x<0 or x>1 or y<0 or y>1 then return false end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if not w or not h then return false end
    local px=math.max(8,math.min(x*w,math.max(8,w-debuffOverview:GetWidth()-8)))
    local py=math.max(8,math.min(y*h,math.max(8,h-debuffOverview:GetHeight()-8)))
    debuffOverview:ClearAllPoints()
    debuffOverview:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",px,py)
    HB.db.debuffOverviewPos={px,py}
    return true
end

local blizEvents=CreateFrame("Frame")
blizEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
blizEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
blizEvents:SetScript("OnEvent",function()
    if not (InCombatLockdown and InCombatLockdown()) and (pendingBlizzard or HB.db) then
        HB.ApplyBlizzardAuraVisibility()
    end
end)

function HB.CreateAuraWidgets(r)
    r.hots,r.debuffs,r.buffIcons,r.missingIcons={},{},{},{}
    r.auraArea=CreateFrame("Frame",nil,r)
    r.auraArea:EnableMouse(false)
    r.debuffArea=CreateFrame("Frame",nil,r)
    r.debuffArea:EnableMouse(false)
    -- Full-length, visual-only rails. Hidden slots are never clickable.
    -- 16 visible slots per rail provides room beyond the requested 10-12.
    for i=1,16 do r.hots[i]=icon(r.auraArea) end
    for i=1,16 do r.debuffs[i]=icon(r.debuffArea) end
    r.buffArea=CreateFrame("Frame",nil,r)
    r.buffArea:EnableMouse(false)
    for i=1,16 do r.buffIcons[i]=icon(r.buffArea) end
    r.missingArea=CreateFrame("Frame",nil,r)
    r.missingArea:EnableMouse(false)
    for i=1,#REQUIRED_ORDER do r.missingIcons[i]=icon(r.missingArea) end
    setupNativeAuras(r)
    HB.AttachBuffOverviewRow(r)
    HB.AttachDebuffOverviewRow(r)
end
function HB.SizeAuraWidgets(r,areaX,headerH,W,H,manaH,square)
    if not r.auraArea then return end
    -- TB18.3: ALL HoT icons form ONE horizontal row. One icon fills the
    -- actual blue inner height of Focus, not the external golden border.
    local focusH=r.focusTile:GetHeight()
    local cell,railHeight=hotGeometry(focusH)
    local step=cell+3
    local columns=HOT_COLUMNS
    local railW=columns*step+3
    r.auraArea:EnableMouse(false)
    r.auraArea:ClearAllPoints()
    r.auraArea:SetPoint("TOPLEFT",r.focusTile,"TOPRIGHT",3,-HOT_BORDER_INSET)
    r.auraArea:SetSize(railW,railHeight)
    -- Clip to the blue height, and place every fallback texture in row 1.
    -- The rail is mouse transparent and never overlaps the Follow area.
    if r.auraArea.SetClipsChildren then r.auraArea:SetClipsChildren(true) end
    for i,o in ipairs(r.hots) do
        local col=i-1
        o.tex:ClearAllPoints()
        o.tex:SetPoint("TOPLEFT",r.auraArea,"TOPLEFT",col*step,0)
        setSize(o,cell)
    end
    r.debuffArea:SetSize(16*DEBUFF_STEP,DEBUFF_ROW_H)
    for i,o in ipairs(r.debuffs) do
        o.tex:ClearAllPoints()
        o.tex:SetPoint("TOPLEFT",r.debuffArea,"TOPLEFT",(i-1)*DEBUFF_STEP,0)
        setSize(o,DEBUFF_ICON)
        o.isNormalBuff=true
        o.time:ClearAllPoints()
        o.time:SetPoint("TOP",o.tex,"BOTTOM",0,-1)
        o.timerFontSize=7.5
        if STANDARD_TEXT_FONT then o.time:SetFont(STANDARD_TEXT_FONT,7.5,"OUTLINE") end
    end
    -- TB15: same proven icon widgets, now in an independent top-right panel.
    -- Active buffs and missing alerts run RIGHT -> LEFT in five fixed rows.
    local buffSize=BUFF_ICON
    r.missingSize=buffSize
    r.missingStep=BUFF_STEP
    r.buffStep=BUFF_STEP
    r.maxBuffIcons=#r.buffIcons
    r.buffArea:EnableMouse(false)
    r.buffArea:SetSize(#r.buffIcons*BUFF_STEP,buffSize+10)
    for i,o in ipairs(r.buffIcons) do
        o.isNormalBuff=true
        o.tex:ClearAllPoints()
        o.tex:SetPoint("TOPRIGHT",r.buffArea,"TOPRIGHT",-(i-1)*BUFF_STEP,0)
        setSize(o,buffSize)
        -- Retain Blizzard-style duration UNDER each icon (TB14).
        o.time:ClearAllPoints()
        o.time:SetPoint("TOP",o.tex,"BOTTOM",0,-1)
        o.time:SetWidth(buffSize+8)
        o.time:SetHeight(8)
        o.timerFontSize=7.5
        if STANDARD_TEXT_FONT then o.time:SetFont(STANDARD_TEXT_FONT,7.5,"OUTLINE") end
        o.time:SetJustifyV("TOP")
    end
    r.missingArea:EnableMouse(false)
    r.missingArea:SetSize(#r.missingIcons*BUFF_STEP,buffSize+10)
    for i,o in ipairs(r.missingIcons) do
        o.tex:ClearAllPoints()
        o.tex:SetPoint("TOPRIGHT",r.missingArea,"TOPRIGHT",-(i-1)*BUFF_STEP,0)
        setSize(o,buffSize)
    end
    if r.nativeAurasReady then
        r.nativeBuff:ClearAllPoints()
        r.nativeBuff:SetPoint("TOPRIGHT",r.buffArea,"TOPRIGHT",0,0)
        r.nativeHots:ClearAllPoints()
        r.nativeHots:SetPoint("TOPLEFT",r.auraArea,"TOPLEFT",0,0)
        -- The single-row group was created at the exact native button size.
        -- If party rows are later resized OOC, scale its visual contents
        -- without rebuilding secure combat auras or re-reading aura data.
        local original=r.hotNativeCell or cell
        local scale=(original>0) and (cell/original) or 1
        r.nativeHots:SetScale(scale)
        r.nativeHots:SetSize(railW/scale,railHeight/scale)
        r.nativeDebuffs:ClearAllPoints()
        r.nativeDebuffs:SetPoint("TOPLEFT",r.debuffArea,"TOPLEFT",0,0)
        r.nativeDebuffs:SetSize(16*DEBUFF_STEP,DEBUFF_ROW_H)
    end
    HB.AlignBuffOverview()
    if HB.AlignDebuffOverview then HB.AlignDebuffOverview() end
end
-- Team composition affects which class buffs can be expected. Per-recipient
-- selection of Paladin Blessings remains configurable rather than fabricated.
local REQUIRED_CLASS={mark="DRUID",thorns="DRUID",intellect="MAGE",fortitude="PRIEST",blessing="PALADIN"}
local function buffAvailableInTeam(f)
    local wanted=REQUIRED_CLASS[f]
    if not wanted then return true end
    local function isClass(unit)
        if not UnitExists or not UnitExists(unit) then return false end
        local ok,_,cf=pcall(UnitClass,unit)
        return ok and safe(cf) and cf==wanted
    end
    if isClass("player") then return true end
    if not (IsInGroup and IsInGroup()) then return false end
    for i=1,4 do if isClass("party"..i) then return true end end
    return false
end
local function hideMissing(r)
    for _,o in ipairs(r.missingIcons or {}) do setIcon(o,nil) end
end
function HB.ResetAuraRow(r)
    r.auraGoodAt=nil
    r.lastMissingKey=nil
    r.missingStability=0
    r.lastHelpful,r.lastHots,r.lastHarmful=nil,nil,nil
    r.helpfulSeenAt,r.hotsSeenAt,r.harmfulSeenAt=nil,nil,nil
    for _,group in ipairs({r.hots or {},r.debuffs or {},r.buffIcons or {}}) do
        for _,o in ipairs(group) do setIcon(o,nil) end
    end
    hideMissing(r)
end
local function updateMissing(r,helpful,hots)
    -- An intentionally unbuffed character still needs red Missing Buffs.
    -- Two consecutive matching noncombat snapshots (below) debounce brief
    -- empty UnitAura race conditions. Do NOT equate zero auras with bad data.
    local found={}
    local sleepingBagStacks=0
    for _,a in ipairs(helpful) do
        local f=family(a)
        if f=="xp" then
            -- applications is explicitly not just a yes/no aura presence flag.
            -- Unknown/secret stack values must never incorrectly clear missing.
            local c=a.count
            if safe(c) and type(c)=="number" then
                sleepingBagStacks=math.max(sleepingBagStacks,c)
                if c>=3 then found.xp=true end
            end
        elseif f then found[f]=true end
    end
    local key={}
    for _,f in ipairs(REQUIRED_ORDER) do key[#key+1]=found[f] and "1" or "0" end
    key=table.concat(key)
    if key==r.lastMissingKey then r.missingStability=(r.missingStability or 0)+1
    else r.lastMissingKey=key;r.missingStability=1 end
    if r.missingStability<2 then hideMissing(r);return end
    local settings=HB.db and HB.db.requiredBuffs or {}
    local index=0
    for _,f in ipairs(REQUIRED_ORDER) do
        if settings[f] and buffAvailableInTeam(f) and not found[f] then
            index=index+1
            local config=REQUIRED[f]
            local tex=config.icon
            if config.spell>0 then
                local fn=(C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
                if fn then local ok,v=pcall(fn,config.spell);if ok and safe(v) and v then tex=v end end
            end
            setIcon(r.missingIcons[index],{icon=tex or "Interface\\Icons\\INV_Misc_QuestionMark",
                count=(f=="xp" and sleepingBagStacks>0) and sleepingBagStacks or nil},true)
            r.missingIcons[index].time:SetText("")
        end
    end
    for i=index+1,#r.missingIcons do setIcon(r.missingIcons[i],nil) end
end
function HB.UpdateAuraWidgets(r)
    if not r.hots then return end
    if not (r.unit and UnitExists(r.unit)) then HB.ResetAuraRow(r);return end
    local combat=InCombatLockdown and InCombatLockdown()
    if r.nativeAurasReady and combat then
        -- The C-side aura engine keeps updating; never query forbidden Lua
        -- aura data or replace real combat icons with an empty list.
        return
    end
    local helpful,hots,harmful={},{},{}
    for i=1,80 do
        local a=aura(r.unit,i,"HELPFUL")
        if not a then break end
        if isHot(a) then hots[#hots+1]=a else helpful[#helpful+1]=a end
    end
    for i=1,80 do
        local a=aura(r.unit,i,"HARMFUL")
        if not a then break end
        harmful[#harmful+1]=a
    end
    local now=GetTime and GetTime() or 0
    -- In native mode, scans below serve Missing Buff evaluation OUT OF COMBAT
    -- only; the C-side engine owns all visible active aura widgets.
    -- Some Forever clients return an empty category while UNIT_AURA and the
    -- local party aura cache are catching up. Hold for a brief bounded grace,
    -- on modern clients. On a legacy client, retain only unexpired cached
    -- icons for the duration of protected combat: incomplete but readable.
    local function restore(group, previous, seenAt)
        if #group>0 then return group,true end
        if not previous or not seenAt or (not combat and now-seenAt>5.5) then
            return group,false
        end
        local retained={}
        for _,a in ipairs(previous) do
            local expire=a.expiration
            if not (safe(expire) and type(expire)=="number" and expire>0 and expire<=now) then
                retained[#retained+1]=a
            end
        end
        return retained,false
    end
    local freshHelpful,freshHots,freshHarmful
    helpful,freshHelpful=restore(helpful,r.lastHelpful,r.helpfulSeenAt)
    hots,freshHots=restore(hots,r.lastHots,r.hotsSeenAt)
    harmful,freshHarmful=restore(harmful,r.lastHarmful,r.harmfulSeenAt)
    if freshHelpful then r.lastHelpful=helpful;r.helpfulSeenAt=now end
    if freshHots then r.lastHots=hots;r.hotsSeenAt=now end
    if freshHarmful then r.lastHarmful=harmful;r.harmfulSeenAt=now end
    if #helpful+#hots+#harmful>0 then r.auraGoodAt=now end
    -- Keep native WoW buff order. Missing Buff icons already tell the user what
    -- the party lacks, so extra sorting only makes characters inconsistent.
    stableSort(hots,"hot")
    stableSort(harmful,"debuff")
    stableSort(helpful,"buff")
    local visibleBuffs=math.min(#helpful,r.maxBuffIcons or #r.buffIcons)
    -- The only TB15 runtime layout input: already-readable OOC buff count.
    -- Secure C-side containers still own live combat aura updates unchanged.
    r.buffShownCount=visibleBuffs
    HB.AlignBuffOverview()
    if not r.nativeAurasReady then
        -- On legacy clients, retain known auras in combat until their
        -- *actual known expiry*. Do not blank the row after 5.5s of secrets.
        for i,o in ipairs(r.hots) do setIcon(o,hots[i]);updateTime(o) end
        for i,o in ipairs(r.debuffs) do setIcon(o,harmful[i]);updateTime(o) end
        for i,o in ipairs(r.buffIcons) do
            setIcon(o,i<=visibleBuffs and helpful[i] or nil)
            updateTime(o)
        end
    end
    -- Missing Buff evaluation is only trustworthy with readable aura fields.
    -- Never clear or invent warnings from a secret/restricted combat snapshot.
    if not combat then updateMissing(r,helpful,hots) end
end
function HB.TickAuraTimers(r)
    if not r.hots or r.nativeAurasReady then return end
    for _,group in ipairs({r.hots,r.debuffs,r.buffIcons}) do
        for _,o in ipairs(group) do updateTime(o) end
    end
end
