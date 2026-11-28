-- JB26.2.0: modern Management shell; legacy Team Management stays available.
local HB=HaploBox
local CM=HB.CharacterManagement
local frame,body,popup,refresh
local tab,view,page,sortKey,asc="characters","list",1,"account",true
local filters={account="",class="",realm=""}
local snapshot,choices,selected,removeGuid
local accent={.396,.851,1}
local muted={.51,.58,.65}
local silver={.863,.910,.945}
local function color(t,c) t:SetTextColor(unpack(c)) end
local function notice(s) if frame then frame.status:SetText(s or "") end end
local function text(p,s,x,y,w,c)
    local f=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",p,"TOPLEFT",x,y);f:SetWidth(w);f:SetJustifyH("LEFT")
    if STANDARD_TEXT_FONT then f:SetFont(STANDARD_TEXT_FONT,11,"OUTLINE") end
    f:SetText(s or "");color(f,c or silver);return f
end
local function button(p,s,x,y,w,fn)
    local b=CreateFrame("Button",nil,p,"UIPanelButtonTemplate")
    b:SetSize(w,23);b:SetPoint("TOPLEFT",p,"TOPLEFT",x,y);b:SetText(s)
    if HB.MenuStyle then HB.MenuStyle.Button(b,"blue") end
    b:SetScript("OnClick",fn);return b
end
local function hidePopup()
    if popup then popup:Hide() end
end
local function dropdown(anchor,options,callback)
    hidePopup()
    if not popup then
        popup=CreateFrame("Frame",nil,frame)
        popup:SetFrameStrata("TOOLTIP");popup:EnableMouse(true)
        if HB.MenuStyle then HB.MenuStyle.Window(popup,1) end
        popup.rows={}
        for i=1,8 do
            local row=button(popup,"",3,-3-(i-1)*24,172,function(self)
                if self.option then local v=self.option.value;local cb=popup.callback;hidePopup();cb(v) end
            end)
            popup.rows[i]=row
        end
        popup.prev=button(popup,"<",3,-196,35,function() popup.index=math.max(1,popup.index-8);popup.render() end)
        popup.next=button(popup,">",141,-196,35,function() popup.index=popup.index+8;popup.render() end)
        popup.count=text(popup,"",43,-201,96,muted)
        popup:SetSize(178,224)
        popup.render=function()
            for i,b in ipairs(popup.rows) do
                b.option=popup.options[popup.index+i-1]
                b:SetShown(b.option~=nil)
                if b.option then b:SetText(b.option.label) end
            end
            popup.prev:SetEnabled(popup.index>1)
            popup.next:SetEnabled(popup.index+7<#popup.options)
            popup.count:SetText(math.ceil(popup.index/8).." / "..math.max(1,math.ceil(#popup.options/8)))
        end
    end
    popup.options=options;popup.callback=callback;popup.index=1
    popup:ClearAllPoints()
    popup:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-2)
    popup:SetClampedToScreen(true);popup.render();popup:Show()
end
local function accountOptions(empty)
    local r={}
    if empty then r[#r+1]={label=empty,value=""} end
    for _,a in ipairs(CM.Accounts()) do r[#r+1]={label=a.label,value=a.id} end
    return r
end
local function accountLabel(id)
    for _,a in ipairs(CM.Accounts()) do if a.id==id then return a.label end end
    return "Select account"
end
local function switch(v)
    hidePopup();view=v;page=1;removeGuid=nil;notice("");refresh()
end
local function openImport(solo)
    local s,e=CM.Snapshot(solo)
    if not s then notice(e);return end
    snapshot=s;choices={};selected={}
    for _,r in ipairs(s.rows) do
        local old=CM.GetCharacter(r.guid)
        if old then choices[r.guid]=old.account end
    end
    switch("import")
end
local function classColor(r)
    local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class]
    return c and {c.r,c.g,c.b} or silver
end
local function setTab(t)
    tab=t;switch("list")
end
local function make()
    if frame then return end
    frame=CreateFrame("Frame","HaploBoxManagement",UIParent)
    frame:SetSize(690,420);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true);frame:EnableMouse(true);frame.hbMenuName="Management"
    if HB.MenuStyle then HB.MenuStyle.Window(frame,30) end
    text(frame,"JCDRbox | Management",12,-9,500,accent)
    button(frame,"X",650,-3,30,function() frame:Hide() end)
    frame.tabs={}
    for i,def in ipairs({{"characters","Character Management"},{"teams","Team Management"}}) do
        local key,label=def[1],def[2]
        local b=button(frame,label,12+(i-1)*333,-36,330,function() setTab(key) end)
        b.line=b:CreateTexture(nil,"OVERLAY")
        b.line:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",0,0);b.line:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",0,0)
        b.line:SetHeight(2);b.line:SetColorTexture(unpack(accent))
        frame.tabs[key]=b
    end
    frame.status=text(frame,"",12,-394,660,muted)
    body=CreateFrame("Frame",nil,frame);body:SetSize(666,326);body:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-66)
    body.actions={}
    local function action(key,label,x,w,fn)
        local b=button(body,label,x,0,w,fn);body.actions[key]=b;return b
    end
    action("import","Import Party",0,125,function() openImport(false) end)
    action("register","Register Current",131,138,function() openImport(true) end)
    action("accounts","Manage Accounts",275,145,function() switch("accounts") end)
    action("back","Back",0,85,function() switch("list") end)
    action("selectAll","Select all own",91,130,function()
        for _,r in ipairs(snapshot.rows) do selected[r.guid]=true end;refresh()
    end)
    action("confirm","Confirm Import",227,145,function()
        local picked={}
        for _,r in ipairs(snapshot.rows) do
            if selected[r.guid] then
                if not choices[r.guid] then notice("Choose an account for "..r.name);return end
                picked[r.guid]=choices[r.guid]
            end
        end
        local ok,result=CM.Import(snapshot,picked)
        if ok then switch("list");notice(result.." character(s) registered.")
        else notice(result) end
    end)
    action("legacy","Open existing Team Management",0,255,function()
        hidePopup();frame:Hide()
        if HB.OpenTeamManagement then HB.OpenTeamManagement() end
    end)
    body.alias=CreateFrame("EditBox",nil,body,"InputBoxTemplate")
    body.alias:SetSize(220,24);body.alias:SetPoint("TOPLEFT",body,"TOPLEFT",98,-30)
    body.alias:SetAutoFocus(false);body.alias:SetMaxLetters(40)
    body.alias:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    body.add=button(body,"Add Account",330,-30,125,function()
        local ok,e=CM.AddAccount(body.alias:GetText())
        if ok then body.alias:SetText("");body.alias:ClearFocus();refresh();notice("Account registered.") else notice(e) end
    end)
    body.filterButtons={}
    for i,k in ipairs({"account","class","realm"}) do
        local key=k
        local b=button(body,"", (i-1)*220,-30,214,function(self)
            local opts={{label=key=="class" and "All classes" or "All "..key.."s",value=""}}
            local seen={}
            if key=="account" then opts=accountOptions("All accounts")
            else
                for _,r in ipairs(CM.GetCharacters()) do
                    local v=r[key]
                    if not seen[v] then opts[#opts+1]={label=v,value=v};seen[v]=true end
                end
                table.sort(opts,function(a,b) if a.value=="" then return b.value~="" elseif b.value=="" then return false end;return a.label<b.label end)
            end
            dropdown(self,opts,function(v) filters[key]=v;page=1;refresh() end)
        end)
        body.filterButtons[key]=b
    end
    body.headers={}
    for _,def in ipairs({{"account","Account",0,100},{"name","Character",104,177},{"class","Class",285,84},{"race","Race",373,80},{"level","Lv",457,44}}) do
        local key=def[1]
        local b=button(body,def[2],def[3],-62,def[4],function()
            if sortKey==key then asc=not asc else sortKey=key;asc=true end
            page=1;refresh()
        end)
        body.headers[key]=b
    end
    body.help=text(body,"",0,-62,660,muted)
    body.rows={}
    for i=1,8 do
        local r=CreateFrame("Frame",nil,body);r:SetSize(666,25);r:SetPoint("TOPLEFT",body,"TOPLEFT",0,-90-(i-1)*26)
        local bg=r:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.063,.137,.196,(i%2==0) and .8 or .45)
        r.account=text(r,"",4,-6,96)
        r.name=text(r,"",108,-6,174)
        r.class=text(r,"",289,-6,80)
        r.race=text(r,"",377,-6,76)
        r.level=text(r,"",461,-6,40)
        r.check=button(r,"",0,-1,96,function()
            if r.item then selected[r.item.guid]=not selected[r.item.guid];refresh() end
        end)
        r.assign=button(r,"",507,-1,81,function(self)
            if not r.item then return end
            local guid=r.item.guid
            dropdown(self,accountOptions(),function(id)
                if view=="import" then choices[guid]=id;selected[guid]=true;refresh()
                else local ok,e=CM.SetAccount(guid,id);refresh();notice(ok and "Account updated." or e) end
            end)
        end)
        r.remove=button(r,"Remove",590,-1,76,function()
            if not r.item then return end
            local id=view=="accounts" and r.item.id or r.item.guid
            if removeGuid~=id then removeGuid=id;refresh();notice("Click Confirm to remove.");return end
            local ok,e
            if view=="accounts" then ok,e=CM.RemoveAccount(id) else ok,e=CM.RemoveCharacter(id) end
            if ok and view=="accounts" and filters.account==id then filters.account="" end
            removeGuid=nil;refresh();notice(ok and "Removed." or e)
        end)
        body.rows[i]=r
    end
    body.prev=button(body,"<",0,-302,35,function() page=page-1;refresh() end)
    body.next=button(body,">",150,-302,35,function() page=page+1;refresh() end)
    body.count=text(body,"",42,-309,100,muted)
    frame:SetScript("OnShow",function() refresh() end)
    frame:SetScript("OnHide",function() hidePopup();snapshot=nil;view="list";removeGuid=nil end)
    frame:Hide()
end
refresh=function()
    if not frame or not frame:IsShown() then return end
    hidePopup()
    local editable=CM.CanEdit()
    local isList=tab=="characters" and view=="list"
    local isAccounts=tab=="characters" and view=="accounts"
    local isImport=tab=="characters" and view=="import"
    for k,b in pairs(frame.tabs) do b.line:SetShown(k==tab) end
    local states={import=isList,register=isList,accounts=isList,back=isAccounts or isImport,selectAll=isImport,confirm=isImport,legacy=tab=="teams"}
    for k,b in pairs(body.actions) do
        b:SetShown(states[k] or false)
        b:SetEnabled(k=="back" or k=="legacy" or editable)
    end
    for k,b in pairs(body.filterButtons) do
        b:SetShown(isList)
        local v=filters[k]
        b:SetText(v=="" and (k=="class" and "All classes" or "All "..k.."s") or (k=="account" and accountLabel(v) or v))
    end
    for _,b in pairs(body.headers) do b:SetShown(isList) end
    body.alias:SetShown(isAccounts);body.add:SetShown(isAccounts);body.add:SetEnabled(editable);if editable then body.alias:Enable() else body.alias:Disable() end
    body.help:SetShown(not isList)
    body.help:SetText(isImport and "Check only your own characters. Assign an account to each checked row." or isAccounts and "Register account aliases once. No passwords or login details." or "New Team Management is phase 3. Existing functions remain available.")
    local items={}
    if isList then
        for _,r in ipairs(CM.GetCharacters()) do
            if (filters.account=="" or r.account==filters.account) and (filters.class=="" or r.class==filters.class) and (filters.realm=="" or r.realm==filters.realm) then items[#items+1]=r end
        end
        table.sort(items,function(a,b)
            local k=sortKey=="account" and "accountLabel" or sortKey
            local av,bv=a[k],b[k]
            if type(av)=="string" then av=av:lower();bv=bv:lower() end
            if av==bv then return a.guid<b.guid end
            if asc then return av<bv else return av>bv end
        end)
    elseif isAccounts then items=CM.Accounts()
    elseif isImport and snapshot then items=snapshot.rows end
    local pages=math.max(1,math.ceil(#items/8));page=math.min(pages,math.max(1,page))
    for i,r in ipairs(body.rows) do
        local item=items[(page-1)*8+i];r.item=item;r:SetShown(item~=nil)
        if item then
            r.account:SetShown(not isImport)
            r.check:SetShown(isImport);r.check:SetEnabled(editable)
            r.assign:SetShown(not isAccounts);r.assign:SetEnabled(editable)
            r.remove:SetShown(not isImport);r.remove:SetEnabled(editable)
            if isAccounts then
                r.account:SetText("");r.name:SetText(item.label);color(r.name,silver)
                r.class:SetText("");r.race:SetText("");r.level:SetText("")
            else
                r.account:SetText(item.accountLabel or "")
                r.name:SetText(item.name);color(r.name,classColor(item))
                r.class:SetText(item.class);r.race:SetText(item.race);r.level:SetText(tostring(item.level))
                r.check:SetText(selected and selected[item.guid] and "[x] Own" or "[ ] Own")
                r.assign:SetText(isImport and accountLabel(choices[item.guid]) or "Account")
            end
            r.remove:SetText(removeGuid==(item.guid or item.id) and "Confirm" or "Remove")
        end
    end
    body.prev:SetShown(tab=="characters");body.next:SetShown(tab=="characters");body.count:SetShown(tab=="characters")
    body.prev:SetEnabled(page>1);body.next:SetEnabled(page<pages);body.count:SetText(page.." / "..pages)
    if not editable then notice("Read only: leader can edit outside combat.")
    elseif isList and #items==0 then notice("Register account aliases, then import your own characters.") end
end
function HB.OpenManagement()
    make()
    if HB.OpenQuickSubmenu then HB.OpenQuickSubmenu(frame)
    elseif frame:IsShown() then frame:Hide() else frame:Show() end
end
local events=CreateFrame("Frame")
for _,e in ipairs({"GROUP_ROSTER_UPDATE","PARTY_LEADER_CHANGED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function() if frame and frame:IsShown() then refresh() end end)
