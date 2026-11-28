local nodes={}
local function noop() end
local M={}
function M:SetSize(w,h) self.width=w;self.height=h end
function M:SetPoint(...) self.points[#self.points+1]={...} end
function M:ClearAllPoints() self.points={} end
function M:SetJustifyH(v) self.justify=v end
function M:SetText(v) self.label=v end
function M:GetText() return self.label end
function M:SetScript(k,v) self.scripts[k]=v end
function M:SetEnabled(v) self.enabled=v end
function M:Hide() self.shown=false end
function M:Show() self.shown=true;if self.scripts.OnShow then self.scripts.OnShow(self) end end
function M:GetFontString() return self.font end
local function node(kind,name,parent)
    local o=setmetatable({kind=kind,parent=parent,points={},scripts={},shown=true},{__index=function(_,k)return M[k] or noop end})
    nodes[#nodes+1]=o
    return o
end
function M:CreateTexture() return node("Texture",nil,self) end
CreateFrame=node
local chars={g1={name="Ilona",guid="g1",account="a",class="PRIEST",level=25},g2={name="Ronan",guid="g2",account="b",class="ROGUE",level=25}}
local active={id="duo",name="Duo",slots={{account="a",guid="g1",role="healer"},{account="b",guid="g2",role="dps"}}}
HaploBox={CharacterManagement={CanEdit=function()return true end,Accounts=function()return {{id="a",label="Account 1"},{id="b",label="Account 2"}} end,GetCharacter=function(g)return chars[g] end,GetCharacters=function()return {chars.g1,chars.g2} end},TeamPlanner={Active=function()return active end,Get=function()return active end,InParty=function()return false end,List=function()return {active} end}}
local function button(p,s,x,y,w,fn)
    local b=node("Button",nil,p);b:SetText(s);b:SetSize(w,23);b:SetPoint("TOPLEFT",p,"TOPLEFT",x,y);b:SetScript("OnClick",fn)
    b.font=node("Font",nil,b);b.font:SetPoint("CENTER",b,"CENTER",0,0);b.font:SetJustifyH("CENTER")
    return b
end
local function text(p,s,x,y,w,c)
    local f=node("Font",nil,p);f:SetText(s);f:SetPoint("TOPLEFT",p,"TOPLEFT",x,y);f:SetJustifyH("LEFT");return f
end
local options,callback
assert(loadfile(arg[1]))()
local panel,render=HaploBox.TeamPlannerUI.Create(node("Root"),{button=button,text=text,dropdown=function(_,o,cb)options=o;callback=cb end,notice=noop,hidePopup=noop})
panel:Show()
local count,role,account=0
local function check()
    count=0
    for _,b in ipairs(nodes) do
        if b.kind=="Button" and b.parent==panel then
            local x=b.points[1][4]
            if x==44 or x==214 or x==458 then
                local f=b.font
                assert(f.justify=="LEFT" and #f.points==2)
                assert(f.points[1][1]=="LEFT" and f.points[1][2]==b and f.points[1][4]==4)
                assert(f.points[2][1]=="RIGHT" and f.points[2][2]==b and f.points[2][4]==-4)
                count=count+1
                if b.label=="Healer" then role=b end
                if b.label=="Account 1" then account=b end
            else assert(b.font.justify=="CENTER") end
        end
    end
    assert(count==15)
end
check()
assert(role and account and role.enabled and account.enabled)
role.scripts.OnClick(role);assert(#options==3);callback("tank")
assert(role.label=="Tank")
check()
render();check()
print("TM UI tests passed: all 15 Account/Character/Role labels left aligned, 4px inset, unrelated buttons centered, role interaction and refresh preserved.")
