-- JB26.3.0: Team Management tab, using the existing CM menu helpers.
local HB=HaploBox
local CM,T=HB.CharacterManagement,HB.TeamPlanner
local UI={}
HB.TeamPlannerUI=UI
function UI.Create(parent,helpers)
    local button,text,dropdown,notice,hidePopup=helpers.button,helpers.text,helpers.dropdown,helpers.notice,helpers.hidePopup
    local panel=CreateFrame("Frame",nil,parent)
    panel:SetSize(666,326);panel:SetPoint("TOPLEFT",parent,"TOPLEFT",12,-66)
    local silver={.863,.910,.945};local muted={.51,.58,.65};local accent={.396,.851,1}
    local draft,editingId={},nil
    local dirty,deleteConfirm=false,false
    local name,selector,newBtn,saveBtn,deleteBtn,legacy,rows,preview,activeText
    local render
    local function load(t)
        draft=t and t.slots or {};editingId=t and t.id or nil
        name:SetText(t and t.name or "")
        dirty=false;deleteConfirm=false;render()
    end
    local function changed()
        dirty=true;deleteConfirm=false;render()
    end
    local function label(id)
        for _,a in ipairs(CM.Accounts()) do if a.id==id then return a.label end end
        return "Select account"
    end
    local function setColor(b,c)
        local f=b:GetFontString()
        if f then f:SetTextColor(unpack(c)) end
    end
    local function classColor(r)
        local c=r and RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class]
        return c and {c.r,c.g,c.b} or silver
    end
    local function used(id,pos)
        for i,s in pairs(draft) do if i~=pos and s.account==id then return true end end
        return false
    end
    local function accountSelect(self,pos)
        if not CM.CanEdit() or T.InParty() then return end
        local opts={{label="Empty slot",value=""}}
        for _,a in ipairs(CM.Accounts()) do
            if not used(a.id,pos) then opts[#opts+1]={label=a.label,value=a.id} end
        end
        dropdown(self,opts,function(id)
            if not CM.CanEdit() or T.InParty() then return end
            if id=="" then draft[pos]=nil
            elseif not used(id,pos) and (not draft[pos] or draft[pos].account~=id) then draft[pos]={account=id} end
            changed()
        end)
    end
    local function characterSelect(self,pos)
        local s=draft[pos]
        if not CM.CanEdit() or T.InParty() or not s then return end
        local opts={{label="Select character",value=""}}
        for _,r in ipairs(CM.GetCharacters()) do
            if r.account==s.account then opts[#opts+1]={label=r.name.." (Lv "..r.level..")",value=r.guid} end
        end
        table.sort(opts,function(a,b) if a.value=="" then return b.value~="" elseif b.value=="" then return false end;return a.label:lower()<b.label:lower() end)
        dropdown(self,opts,function(id)
            if not CM.CanEdit() or T.InParty() or draft[pos]~=s then return end
            s.guid=id~="" and id or nil
            if not s.guid then s.role=nil end
            changed()
        end)
    end
    local function roleSelect(self,pos)
        local s=draft[pos]
        if not CM.CanEdit() or not s or not s.guid then return end
        dropdown(self,{{label="Tank",value="tank"},{label="Healer",value="healer"},{label="DPS",value="dps"}},function(role)
            if not CM.CanEdit() or draft[pos]~=s then return end
            s.role=role;changed()
        end)
    end
    local roleLabels={tank="Tank",healer="Healer",dps="DPS"}
    selector=button(panel,"Select saved team",0,0,180,function(self)
        if dirty then notice("Save or discard your draft before selecting another team.");return end
        local opts={}
        local active=T.Active()
        for _,t in ipairs(T.List()) do
            if not T.InParty() or (active and active.id==t.id) then
                opts[#opts+1]={label=t.name,value=t.id}
            end
        end
        if #opts==0 then notice("No selectable teams. Leave the party to create or switch teams.");return end
        dropdown(self,opts,function(id)
            local ok,result=T.Select(id)
            if ok then load(result);notice("Active team: "..result.name) else notice(result) end
        end)
    end)
    newBtn=button(panel,"New",186,0,65,function()
        if not CM.CanEdit() or T.InParty() then return end
        if dirty then notice("Save or discard your draft first.");return end
        load(nil);name:SetFocus();notice("Choose accounts, characters and roles.")
    end)
    name=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
    name:SetSize(178,23);name:SetPoint("TOPLEFT",panel,"TOPLEFT",260,0)
    name:SetAutoFocus(false);name:SetMaxLetters(40)
    name:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    name:SetScript("OnTextChanged",function(self,user) if user then changed() end end)
    saveBtn=button(panel,"Save",444,0,66,function()
        local ok,result=T.Save(name:GetText(),draft,editingId)
        if ok then load(result);name:ClearFocus();notice("Saved and active: "..result.name) else notice(result) end
    end)
    deleteBtn=button(panel,"Delete",516,0,70,function()
        if not editingId then return end
        if not deleteConfirm then deleteConfirm=true;render();notice("Click Confirm to delete this saved team.");return end
        local ok,e=T.Delete(editingId)
        if ok then load(T.Active());notice("Team deleted.") else notice(e) end
    end)
    local discard=button(panel,"Discard",592,0,74,function()
        load(T.Active());notice("Unsaved changes discarded.")
    end)
    activeText=text(panel,"",0,-31,660,accent)
    text(panel,"POS",4,-52,40,muted)
    text(panel,"Account",48,-52,160,muted)
    text(panel,"Character",216,-52,240,muted)
    text(panel,"Role",462,-52,100,muted)
    text(panel,"Order",580,-52,80,muted)
    rows={}
    for i=1,5 do
        local pos=i
        local y=-67-(i-1)*25
        local r={}
        r.pos=text(panel,tostring(i),8,y-6,32,accent)
        r.account=button(panel,"",44,y,164,function(self) accountSelect(self,pos) end)
        r.character=button(panel,"",214,y,238,function(self) characterSelect(self,pos) end)
        r.role=button(panel,"",458,y,110,function(self) roleSelect(self,pos) end)
        r.up=button(panel,"<",574,y,42,function()
            if not CM.CanEdit() or pos<=1 or not draft[pos] or not draft[pos-1] then return end
            draft[pos],draft[pos-1]=draft[pos-1],draft[pos];changed()
        end)
        r.down=button(panel,">",620,y,42,function()
            if not CM.CanEdit() or pos>=5 or not draft[pos] or not draft[pos+1] then return end
            draft[pos],draft[pos+1]=draft[pos+1],draft[pos];changed()
        end)
        rows[i]=r
    end
    text(panel,"SCREEN LAYOUT  /  POS 1 = MAIN",0,-195,660,accent)
    preview={}
    for i=1,5 do
        local p=CreateFrame("Frame",nil,panel)
        local x,y,w,h
        if i==1 then x,y,w,h=0,-211,666,46
        else x,y,w,h=(i-2)*167,-261,164,36 end
        p:SetSize(w,h);p:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
        local bg=p:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();p.bg=bg
        p.title=text(p,i==1 and "1 - MAIN" or tostring(i),5,-4,w-10,muted)
        p.label=text(p,"",5,-17,w-10,silver);p.label:SetJustifyH("CENTER")
        preview[i]=p
    end
    legacy=button(panel,"Legacy party controls",0,-301,168,function()
        hidePopup();parent:Hide()
        if HB.OpenTeamManagement then HB.OpenTeamManagement() end
    end)
    text(panel,"Preview only - live party and invites unchanged.",180,-308,480,muted)
    render=function()
        hidePopup()
        local can=CM.CanEdit()
        local party=T.InParty()
        local active=T.Active()
        selector:SetText(editingId and (T.Get(editingId) or {}).name or "Select saved team")
        selector:SetEnabled(can and not dirty and not party)
        newBtn:SetEnabled(can and not party and not dirty)
        if can and not party and not editingId then name:Enable() else name:Disable() end
        saveBtn:SetEnabled(can and (not party or (active and active.id==editingId)) and true or false)
        deleteBtn:SetEnabled(can and not party and editingId~=nil)
        deleteBtn:SetText(deleteConfirm and "Confirm" or "Delete")
        discard:SetEnabled(dirty)
        activeText:SetText("Active: "..(active and active.name or "None")..(dirty and "  |  Unsaved changes" or "")..(not can and "  |  Read only" or party and "  |  Party: roles / order only" or ""))
        for i,r in ipairs(rows) do
            local s=draft[i]
            local c=s and s.guid and CM.GetCharacter(s.guid)
            r.account:SetText(s and label(s.account) or "Select account")
            r.account:SetEnabled(can and not party)
            r.character:SetText(c and c.name or "Select character")
            r.character:SetEnabled(can and not party and s~=nil)
            setColor(r.character,c and classColor(c) or muted)
            r.role:SetText(s and roleLabels[s.role] or "Select role")
            r.role:SetEnabled(can and c~=nil)
            r.up:SetEnabled(can and i>1 and s~=nil and draft[i-1]~=nil)
            r.down:SetEnabled(can and i<5 and s~=nil and draft[i+1]~=nil)
            local p=preview[i]
            p.bg:SetColorTexture(c and .063 or .035,c and .137 or .058,c and .196 or .079,1)
            p.label:SetText(c and (c.name.."  /  "..(roleLabels[s.role] or "-")) or "-")
            p.label:SetTextColor(unpack(c and classColor(c) or muted))
        end
    end
    panel:SetScript("OnShow",function() if not dirty then load(T.Active()) else render() end end)
    panel:Hide()
    return panel,render
end
