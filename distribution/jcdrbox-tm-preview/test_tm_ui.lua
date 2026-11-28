local nodes={}
local function noop() end
local M={}
function M:SetSize(w,h) self.width=w;self.height=h end
function M:GetWidth() return self.width end
function M:GetHeight() return self.height end
function M:SetWidth(w) self.width=w end
function M:SetShown(v) self.shown=v end
function M:SetTextColor(...) self.color={...} end
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
local chars={g1={name="Ilona Moon",guid="g1",account="a",class="PRIEST",level=25},g2={name="Ronan Storm",guid="g2",account="b",class="ROGUE",level=25}}
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
RAID_CLASS_COLORS={PRIEST={r=1,g=1,b=1},ROGUE={r=1,g=.96,b=.41}}
local root=node("Root");root:SetSize(690,670)
local panel,render=HaploBox.TeamPlannerUI.Create(root,{button=button,text=text,dropdown=function(_,o,cb)options=o;callback=cb end,notice=noop,hidePopup=noop})
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

local screens={}
for _,p in ipairs(nodes) do if p.parent==panel and p.kind=="Frame" and rawget(p,"role") then screens[#screens+1]=p end end
assert(#screens==5)
local function geometry()
    local main=screens[1]
    assert(math.abs(main.height-main.width*9/16)<1)
    assert(main.width>screens[2].width*3)
    for i=2,5 do
        local p=screens[i]
        assert(math.abs(p.height-p.width*9/16)<1)
        assert(p.points[1][5]==main.points[1][5]-main.height-6)
        if i>2 then assert(p.points[1][4]==screens[i-1].points[1][4]+p.width+6) end
    end
end
geometry()
assert(screens[1].label.label=="Ilona" and screens[1].role.label=="Tank")
assert(screens[2].label.label=="Ronan" and screens[2].role.label=="DPS")
assert(screens[2].label.color[2]==.96)
assert(screens[3].label.label=="-" and screens[3].role.label=="Empty")
local before=screens[1].height
panel.ResizePreview(900,800);geometry();assert(screens[1].height>before)
panel.ResizePreview(690,670);geometry();assert(screens[1].height==before)
print("TM screen preview tests passed: 16:9 main and four monitors, first names, class colors, separate roles, empty slots, responsive geometry.")
