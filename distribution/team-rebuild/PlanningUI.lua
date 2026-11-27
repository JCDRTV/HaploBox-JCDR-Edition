-- HF26.20.60 Phase 1. Manual planning UI; no party, trust or macro side effects.
local HB=HaploBox
local P=HaploBoxPlanning
local model,frame,left,right,status,header,activeText
local view="team"
local draft,teamId,dirty={},nil,false
local characterId,capturedGUID,capturedName,capturedRealm
local fields,slots={},{}
local chooser,page="teams",1
local listButtons={}
local teamName,search,listTitle,pageText
local refresh,renderList
local function message(s) status:SetText(s or "") end
local function getModel()
    if model then return model end
    if HaploBoxPlanningDB==nil then HaploBoxPlanningDB={} end
    local err
    model,err=P.New(HaploBoxPlanningDB)
    if not model then print("HaploBox Planning: "..(err or "database unavailable"));return end
    if HB then HB.Planning=model end
    return model
end
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b=pcall(fn,...)
    if not ok then return nil end
    if issecretvalue then
        if issecretvalue(a) then a=nil end
        if issecretvalue(b) then b=nil end
    end
    return a,b
end
local function ownProfile()
    local name,realm=safe(UnitFullName,"player")
    name=name or safe(UnitName,"player")
    if not realm or realm=="" then realm=safe(GetNormalizedRealmName) or safe(GetRealmName) end
    local race,raceToken=safe(UnitRace,"player")
    local class,classToken=safe(UnitClass,"player")
    return {name=name,realm=realm,race=raceToken or race,class=classToken or class,level=safe(UnitLevel,"player"),guid=safe(UnitGUID,"player")}
end
local function text(parent,x,y,w,s)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    f:SetWidth(w);f:SetJustifyH("LEFT");f:SetText(s or "")
    return f
end
local function button(parent,x,y,w,s,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w,25);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    b:SetText(s);b:SetScript("OnClick",fn)
    return b
end
local function edit(parent,x,y,w,max)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetSize(w,25);e:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    e:SetAutoFocus(false);e:SetMaxLetters(max or 100)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    return e
end
local function fillCharacter(c)
    characterId=c and c.id or nil
    capturedGUID,capturedName,capturedRealm=nil,nil,nil
    for k,e in pairs(fields) do e:SetText(c and tostring(c[k] or "") or "") end
end
local function fillOwn()
    local c=ownProfile()
    if not (c.name and c.realm and c.guid) then message("Player identity not available yet.");return end
    local matched
    for _,r in ipairs(model.GetCharacters()) do
        if r.guid==c.guid or (r.name:lower()==c.name:lower() and r.realm:lower():gsub("[%s']","")==c.realm:lower():gsub("[%s']","")) then
            matched=r;break
        end
    end
    fillCharacter(matched)
    for k,e in pairs(fields) do if c[k]~=nil then e:SetText(tostring(c[k])) end end
    capturedGUID,capturedName,capturedRealm=c.guid,c.name,c.realm
    message("Enter your account alias, then Save Character to register.")
end
local function saveCharacter()
    local c={}
    for k,e in pairs(fields) do c[k]=e:GetText() end
    if c.name==capturedName and c.realm==capturedRealm then c.guid=capturedGUID end
    local saved,err=model.SaveCharacter(c,characterId)
    if not saved then message(err);return end
    fillCharacter(saved);refresh();message("Character saved: "..saved.name)
end
local function setChooser(kind)
    chooser=kind;page=1;search:SetText("");renderList()
end
local function loadTeam(id)
    local t=model.GetTeam(id)
    if not t then message("Team not found.");return end
    teamId=t.id;draft=t.slots;teamName:SetText(t.name);dirty=false
    refresh();message("Loaded "..t.name)
end
local function newTeam()
    teamId=nil;draft={};teamName:SetText("");dirty=false
    setChooser("teams");refresh();message("New team: select characters in positions 1-5.")
end
local function saveTeam()
    local t,err=model.SaveTeam(teamName:GetText(),draft,teamId)
    if not t then message(err);return end
    teamId=t.id;draft=t.slots;dirty=false
    refresh();message("Saved "..t.name)
end
local function changePosition(pos,other)
    draft[pos],draft[other]=draft[other],draft[pos]
    dirty=true;refresh()
end
local function chooseRole(pos)
    if not draft[pos] then return end
    local nextRole={DPS="TANK",TANK="HEALER",HEALER="DPS"}
    draft[pos].role=nextRole[draft[pos].role] or "DPS"
    dirty=true;refresh()
end
local function selectCharacter(pos,id)
    local c=model.GetCharacter(id)
    if not c then return end
    for i=1,5 do
        local s=draft[i]
        if i~=pos and s then
            local other=model.GetCharacter(s.characterId)
            if s.characterId==id or (other and other.account:lower()==c.account:lower()) then
                message("Character or account already in team. Use arrows to move positions.");return
            end
        end
    end
    draft[pos]={characterId=id,role=draft[pos] and draft[pos].role or "DPS"}
    dirty=true;refresh();message("Position "..pos..": "..c.name)
end
renderList=function()
    if not frame then return end
    local records
    if chooser=="teams" then records=model.GetTeams();listTitle:SetText("SAVED TEAMS")
    else
        records=model.GetCharacters()
        listTitle:SetText(type(chooser)=="number" and ("SELECT CHARACTER FOR POS "..chooser) or "CHARACTER REGISTER")
    end
    local term=search:GetText():lower()
    local filtered={}
    for _,r in ipairs(records) do
        local label=r.name
        if r.realm then label=label.." - "..r.realm.." | "..r.account.." | "..r.class.." "..r.level end
        if label:lower():find(term,1,true) then filtered[#filtered+1]={id=r.id,label=label} end
    end
    local pages=math.max(1,math.ceil(#filtered/#listButtons))
    page=math.max(1,math.min(page,pages))
    pageText:SetText(page.." / "..pages.."   ("..#filtered..")")
    for i,b in ipairs(listButtons) do
        local record=filtered[(page-1)*#listButtons+i]
        if record then
            b:SetText(record.label);b:Show()
            b:SetScript("OnClick",function()
                if chooser=="teams" then loadTeam(record.id)
                elseif type(chooser)=="number" then selectCharacter(chooser,record.id)
                else fillCharacter(model.GetCharacter(record.id));message("Editing registered character.") end
            end)
        else b:Hide();b:SetScript("OnClick",nil) end
    end
end
refresh=function()
    local active=model.GetActiveTeam()
    activeText:SetText("ACTIVE TEAM: "..(active and active.name or "None").."   |   Local planning only")
    for pos=1,5 do
        local s=draft[pos]
        local c=s and model.GetCharacter(s.characterId)
        slots[pos].name:SetText(c and c.name or "Select character")
        slots[pos].account:SetText(c and (c.account.." | "..c.class.." "..c.level) or "-")
        slots[pos].role:SetText(s and s.role or "-")
        if s then slots[pos].role:Enable();slots[pos].remove:Enable()
        else slots[pos].role:Disable();slots[pos].remove:Disable() end
    end
    header:SetText(view=="team" and ("TEAM MANAGEMENT"..(dirty and "  *" or "")) or "CHARACTER MANAGEMENT")
    renderList()
end
local function switch(v)
    view=v
    if v=="team" then left.team:Show();left.cm:Hide();setChooser("teams")
    else left.team:Hide();left.cm:Show();setChooser("characters") end
    refresh();message("")
end
local function build()
    frame=CreateFrame("Frame","HaploBoxPlanningFrame",UIParent,BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(940,440);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true);frame:SetMovable(true);frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton");frame:SetScript("OnDragStart",frame.StartMoving);frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
    local bg=frame:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(0.035,0.055,0.075,0.98)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="HaploBoxPlanningFrame" end
    text(frame,18,12,510,"HaploBox JCDR Edition | HF26.20.60 | Phase 1")
    button(frame,18,36,175,"Character Management",function() switch("cm") end)
    button(frame,200,36,175,"Team Management",function() switch("team") end)
    button(frame,853,12,70,"Close",function() frame:Hide() end)
    header=text(frame,18,72,520,"TEAM MANAGEMENT")
    activeText=text(frame,18,95,900,"")
    left={}
    for _,k in ipairs({"team","cm"}) do
        local p=CreateFrame("Frame",nil,frame);p:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-120);p:SetSize(530,250);left[k]=p
    end
    local p=left.team
    text(p,0,3,75,"Team name")
    teamName=edit(p,85,0,270,80)
    teamName:SetScript("OnTextChanged",function(_,userInput) if userInput then dirty=true;refresh() end end)
    text(p,0,33,30,"POS");text(p,35,33,164,"CHARACTER");text(p,205,33,135,"ACCOUNT / CLASS")
    text(p,346,33,64,"ROLE")
    for i=1,5 do
        local pos=i
        local y=52+(i-1)*28
        text(p,5,y+5,28,tostring(i))
        local s={}
        s.name=button(p,35,y,165,"Select character",function() setChooser(pos);message("Choose a registered character on the right.") end)
        s.account=text(p,205,y+5,135,"-")
        s.role=button(p,346,y,65,"-",function() chooseRole(pos) end)
        local up=button(p,415,y,30,"Up",function() if pos>1 then changePosition(pos,pos-1) end end)
        local down=button(p,446,y,42,"Down",function() if pos<5 then changePosition(pos,pos+1) end end)
        if pos==1 then up:Disable() end;if pos==5 then down:Disable() end
        s.remove=button(p,490,y,30,"X",function() draft[pos]=nil;dirty=true;refresh() end)
        slots[pos]=s
    end
    button(p,0,202,78,"New",newTeam)
    button(p,82,202,100,"Save team",saveTeam)
    button(p,186,202,100,"Load team",function() setChooser("teams");message("Choose a saved team on the right.") end)
    button(p,290,202,120,"Set active team",function()
        if dirty then message("Save the team before activating.");return end
        local t,err=model.SetActiveTeam(teamId)
        if not t then message(err);return end
        refresh();message("Active team: "..t.name)
    end)
    button(p,414,202,106,"Clear active",function() model.ClearActiveTeam();refresh();message("Active team cleared.") end)
    text(p,0,234,520,"Fixed positions. Empty slots stay empty. Click role to cycle.")
    p=left.cm
    local labels={{"name","Character name"},{"realm","Realm / ruleset"},{"account","Account alias"},{"race","Race"},{"class","Class"},{"level","Level"}}
    for i,item in ipairs(labels) do
        local y=(i-1)*30
        text(p,0,y+6,125,item[2]);fields[item[1]]=edit(p,140,y,330,item[1]=="level" and 3 or 100)
    end
    button(p,0,190,115,"New character",function() fillCharacter(nil);message("Register an owned character manually.") end)
    button(p,120,190,135,"Use current player",fillOwn)
    button(p,260,190,115,"Save character",saveCharacter)
    button(p,380,190,115,"Remove",function()
        local ok,err=model.RemoveCharacter(characterId)
        if not ok then message(err);return end
        fillCharacter(nil);refresh();message("Character removed from planning register.")
    end)
    text(p,0,225,520,"Own characters only. Account aliases are manual; no credentials.")
    right=CreateFrame("Frame",nil,frame);right:SetPoint("TOPLEFT",frame,"TOPLEFT",550,-120);right:SetSize(372,260)
    listTitle=text(right,0,0,372,"SAVED TEAMS")
    text(right,0,26,52,"Search")
    search=edit(right,60,21,305,100)
    for i=1,7 do
        listButtons[i]=button(right,0,49+(i-1)*25,372,"",function() end)
    end
    button(right,0,228,70,"Previous",function() page=page-1;renderList() end)
    button(right,302,228,70,"Next",function() page=page+1;renderList() end)
    pageText=text(right,90,234,210,"")
    search:SetScript("OnTextChanged",function() page=1;renderList() end)
    status=text(frame,18,390,900,"")
    switch("team")
    frame:Hide()
end
local function open(v)
    if InCombatLockdown and InCombatLockdown() then print("HaploBox: open planning after combat.");return end
    if not getModel() then return end
    if not frame then build() end
    switch(v);frame:Show()
end
SLASH_HAPLOBOXPLANCM1="/hbcm"
SLASH_HAPLOBOXPLANTM1="/hbtm"
SlashCmdList.HAPLOBOXPLANCM=function() open("cm") end
SlashCmdList.HAPLOBOXPLANTM=function() open("team") end
if HB then HB.OpenCharacterManagement=function() open("cm") end;HB.OpenTeamManagement=function() open("team") end end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent",function(_,event,level)
    local m=getModel()
    if not m then return end
    local c=ownProfile()
    if event=="PLAYER_LEVEL_UP" and type(level)=="number" then c.level=level end
    if not (c.guid and c.name and c.realm and c.race and c.class and c.level) then return end
    for _,r in ipairs(m.GetCharacters()) do
        if r.guid==c.guid or (r.name:lower()==c.name:lower() and r.realm:lower():gsub("[%s']","")==c.realm:lower():gsub("[%s']","")) then
            c.account=r.account
            m.SaveCharacter(c,r.id)
            if frame and frame:IsShown() then refresh() end
            return
        end
    end
end)
