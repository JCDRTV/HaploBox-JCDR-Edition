local path=arg[1]
local nodes={}
local noop=function() end
local methods={}
function methods:SetSize(w,h) self.width=w;self.height=h;if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(p,_,rp,x,y) self.point={p,rp or p,x or 0,y or 0} end
function methods:GetPoint() local p=self.point or {};return p[1],UIParent,p[2],p[3],p[4] end
function methods:SetMovable(v) self.movable=v end
function methods:SetResizable(v) self.resizable=v end
function methods:SetEnabled(v) self.enabled=v end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetText(v) self.label=v end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:Show() local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetMinMaxValues(a,b) self.min,self.max=a,b;self:SetValue(self.value or a) end
function methods:GetMinMaxValues() return self.min,self.max end
function methods:SetValue(v) v=math.max(self.min or 0,math.min(self.max or v,v));local old=self.value;self.value=v;if old~=v and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function methods:GetThumbTexture() return self.thumb end
local function node(kind,name,parent)
 local o=setmetatable({kind=kind,name=name,parent=parent,scripts={},shown=true},{__index=function(_,k)return methods[k] or (type(k)=="string" and k:match("^[A-Z]") and noop or nil) end})
 nodes[#nodes+1]=o
 if name then _G[name]=o end
 return o
end
function methods:CreateFontString() return node("Font",nil,self) end
function methods:CreateTexture() return node("Texture",nil,self) end
function methods:SetThumbTexture(path) self.thumb=node("Texture",nil,self);self.thumb.path=path end
function methods:SetColorTexture(...) self.color={...} end
CreateFrame=node
UIParent=node("Root")
local records={}
for i=1,23 do records[i]={guid=string.format("g%02d",i),name=string.format("Char%02d",i),account="a",accountLabel="Account 1",class="MAGE",race="Human",realm="Forever",level=i} end
local removed
HaploBox={db={},CharacterManagement={
 CanEdit=function()return true end,Accounts=function()return {{id="a",label="Account 1"}} end,
 GetCharacters=function()return records end,RemoveCharacter=function(g)
 removed=g;for i,r in ipairs(records) do if r.guid==g then table.remove(records,i);return true end end
 end},
 RegisterSync={Status=function()return "" end},
 TeamPlannerUI={Create=function()return node("Team"),noop end}}
assert(loadfile(path))()
HaploBox.OpenManagement()
local frame=HaploBoxManagement
local body
for _,o in ipairs(nodes) do if o.parent==frame and rawget(o,"rows") and rawget(o,"scroll") then body=o end end
assert(body and #body.rows==8)
local s=body.scroll
assert(s:IsShown() and s.max==15)
assert(body.rows[1].item.guid=="g01" and body.rows[8].item.guid=="g08")
assert(s.thumb.path=="Interface\\Buttons\\WHITE8X8")
assert(s.thumb.color[1]==.443)
s.scripts.OnEnter();assert(s.thumb.color[1]==.58)
s.scripts.OnLeave();assert(s.thumb.color[1]==.443)
assert(body.up.enabled==false and body.down.enabled==true)
local thumb=s.thumb.height
assert(thumb>12 and thumb< s.height)
body.down.scripts.OnClick();assert(body.rows[1].item.guid=="g02" and body.up.enabled==true)
body.up.scripts.OnClick();assert(s.value==0)
s:SetValue(1);assert(body.rows[1].item.guid=="g02")
body.rows[1].scripts.OnMouseWheel(body.rows[1],-1)
assert(s.value==2 and body.rows[1].item.guid=="g03")
s:SetValue(15);assert(body.rows[8].item.guid=="g23")
body.rows[8].remove.scripts.OnClick()
body.rows[8].remove.scripts.OnClick()
assert(removed=="g23" and s.max==14 and body.rows[8].item.guid=="g22")
body.headers.name.scripts.OnClick()
assert(s.value==0 and body.rows[1].item.guid=="g01")
body.headers.name.scripts.OnClick()
assert(body.rows[1].item.guid=="g22")
frame:SetSize(850,548)
assert(#body.rows==12 and s.max==10)
assert(s.thumb.height>thumb)
s:SetValue(10);assert(body.rows[12].item.guid=="g01")
frame.grip.scripts.OnMouseUp()
assert(HaploBox.db.managementWindow.width==850 and HaploBox.db.managementWindow.height==548)
frame.lock.scripts.OnClick()
assert(HaploBox.db.managementWindow.locked and not frame.grip:IsShown() and not frame.resizable and not frame.movable)
frame.lock.scripts.OnClick()
assert(not HaploBox.db.managementWindow.locked and frame.grip:IsShown() and frame.resizable)
frame:SetSize(690,444)
assert(s.max==14 and not body.rows[9]:IsShown())
for i=22,5,-1 do table.remove(records,i) end
HaploBox.RegisterSync.OnChange(true)
assert(not s:IsShown() and s.value==0 and body.rows[5]:IsShown()==false)
print("CM window tests passed: proportional thumb, arrows, wheel, sort, correct removal, resize grow/shrink, persisted size, lock/unlock, hide when list fits.")
