local path=arg[1]
local nodes={}
local noop=function() end
local methods={}
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
 local o=setmetatable({kind=kind,name=name,parent=parent,scripts={},shown=true},{__index=function(_,k)return methods[k] or noop end})
 nodes[#nodes+1]=o
 if name then _G[name]=o end
 return o
end
function methods:CreateFontString() return node("Font",nil,self) end
function methods:CreateTexture() return node("Texture",nil,self) end
function methods:SetThumbTexture() self.thumb=node("Texture",nil,self) end
CreateFrame=node
UIParent=node("Root")
local records={}
for i=1,23 do records[i]={guid=string.format("g%02d",i),name=string.format("Char%02d",i),account="a",accountLabel="Account 1",class="MAGE",race="Human",realm="Forever",level=i} end
local removed
HaploBox={CharacterManagement={
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
for i=22,5,-1 do table.remove(records,i) end
HaploBox.RegisterSync.OnChange(true)
assert(not s:IsShown() and s.value==0 and body.rows[5]:IsShown()==false)
print("CM scroll tests passed: single-row wheel, drag to end, remove correct GUID, clamp after deletion, sorting reset, hide for short list.")
