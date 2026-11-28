from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-macro-management'
# Unpublished candidate chain: validate against previous successful immutable report.
manifest=json.loads((ROOT/'distribution/jcdrbox-auto-box-mode/output/build-report.json').read_text())
assert manifest['version']=='JB26.3.22' and manifest['base']=='JB26.3.21'
BASE=ROOT/'distribution/jcdrbox-auto-box-mode/output/JCDRbox_JB26.3.22_Auto_Box_Mode_TEST.zip'
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.23_Macro_Management_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.22','## Version: JB26.3.23')
    macro='HaploBox/MacroLibrary.lua'
    c=original[macro].decode()
    def section(s,a,z,new):
        assert s.count(a)==1 and s.count(z)==1,(a,z)
        start=s.index(a);end=s.index(z,start)
        return s[:start]+new+'\n'+s[end:]
    c=replace(c,'local function me() return UnitClass and select(2,UnitClass("player")) end',(SRC/'catalog.lua').read_text()+'\nlocal function me() return UnitClass and select(2,UnitClass("player")) end')
    c=section(c,'local function activeSpells()','local function locked()',"local function catalogFor(class)\n    local out={}\n    for _,g in ipairs(FOREVER[class] or {}) do\n        for line in g[2]:gmatch(\"[^|]+\") do\n            local name,code=line:match(\"^(.-)=(.+)$\")\n            local level=tonumber(code:match(\"%d+\"))\n            local mode=code:sub(1,1)\n            local special=mode==\"t\" and \"Talent\" or mode==\"q\" and \"Quest / requirement\" or mode==\"p\" and \"Passive\" or not level and \"Check source\" or nil\n            out[name:lower()]={name=name,level=level,category=g[1],special=special,passive=mode==\"p\"}\n        end\n    end\n    return out\nend\nlocal selectedCategory=\"All Spells\"\nlocal function activeSpells()\n    if not scanAttempted and scanSpellbook then scanSpellbook() end\n    local class=me()\n    local facts=catalogFor(class)\n    local out,seen,reserved,ids={},{},{},{}\n    for _,e in ipairs(BOX) do if e.name then reserved[e.name]=true end end\n    for _,e in ipairs(SMART[class] or {}) do\n        local key=e.spell:lower()\n        local learned=spellBook[key]\n        local fact=facts[key]\n        -- Preserve existing IDs and macro names for matching legacy entries.\n        if fact or learned then\n            local entry={}\n            for k,v in pairs(e) do entry[k]=v end\n            if fact then\n                entry.level=fact.level;entry.category=fact.category;entry.special=fact.special;entry.passive=fact.passive or (learned and learned.passive==true)\n            else entry.category=\"Other\";entry.special=\"Check source\";entry.level=nil end\n            seen[key]=true;reserved[entry.name]=true;ids[entry.id]=true\n            out[#out+1]=entry\n        end\n    end\n    local keys={}\n    for k in pairs(facts) do if not seen[k] then keys[#keys+1]=k end end\n    table.sort(keys)\n    for _,k in ipairs(keys) do\n        local fact=facts[k]\n        local e=autoEntry(class,fact,k,reserved)\n        if e and not ids[e.id] then\n            e.level=fact.level;e.category=fact.category;e.special=fact.special\n            e.passive=fact.passive or (spellBook[k] and spellBook[k].passive==true)\n            -- Race/faction dependent portals must not be presented as trainable to the wrong side.\n            local faction=UnitFactionGroup and UnitFactionGroup(\"player\")\n            local city=e.spell:match(\"^Teleport: (.+)$\") or e.spell:match(\"^Portal: (.+)$\")\n            local side=city and ({Ironforge=\"Alliance\",Stormwind=\"Alliance\",Darnassus=\"Alliance\",Orgrimmar=\"Horde\",Undercity=\"Horde\",[\"Thunder Bluff\"]=\"Horde\"})[city]\n            if side and side~=faction then e.special=side..\" only\" end\n            out[#out+1]=e;seen[k]=true;reserved[e.name]=true;ids[e.id]=true\n        end\n    end\n    keys={}\n    for k in pairs(spellBook) do keys[#keys+1]=k end\n    table.sort(keys)\n    for _,k in ipairs(keys) do\n        local d=spellBook[k]\n        local explicit=RULES[class] and RULES[class][k]\n        if class and RULES[class] and not seen[k] and (d.tab>1 or explicit) then\n            local e=autoEntry(class,d,k,reserved)\n            if e and not ids[e.id] then\n                e.category=d.category or \"Other\";e.passive=d.passive==true\n                e.special=\"Client spellbook\";out[#out+1]=e;reserved[e.name]=true;ids[e.id]=true\n            end\n        end\n    end\n    table.sort(out,function(a,b)\n        local al,bl=a.level or 99,b.level or 99\n        if al~=bl then return al<bl end\n        return a.title<b.title\n    end)\n    return out\nend\nlocal function filteredSpells()\n    local out={}\n    for _,e in ipairs(activeSpells()) do\n        if selectedCategory==\"All Spells\" or selectedCategory==e.category then out[#out+1]=e end\n    end\n    return out\nend\n")
    c=section(c,'local function spellKnown(entry)','function HB.MacroSpellbookStatus()',"local function learnedState(entry)\n    if not entry.spell then return true end\n    if not scanAttempted then scanSpellbook() end\n    local data=spellBook[entry.spell:lower()]\n    if data then return true end\n    local known=knownByName(entry.spell)\n    return known\nend\nlocal function spellKnown(entry)\n    return not entry.passive and learnedState(entry)==true\nend\nlocal function spellStatus(entry)\n    local learned=learnedState(entry)\n    if learned==true then return \"Learned\"..(entry.passive and \" / Passive\" or \"\"),.30,.90,.42 end\n    local lv=UnitLevel and UnitLevel(\"player\")\n    if type(lv)==\"number\" and entry.level and lv<entry.level then\n        return \"Level \"..entry.level..\" required\",.95,.32,.32\n    end\n    if entry.special or entry.passive then return entry.special or \"Passive\",.74,.56,.94 end\n    if learned==false or scannedBook then\n        if type(lv)==\"number\" and entry.level and lv>=entry.level then\n            return \"Level \"..entry.level..\" / Check trainer\",1,.63,.24\n        end\n    end\n    return \"Not verified\",.65,.69,.76\nend\nHB.MacroSpellStatus=spellStatus\n")
    # Keep explicit targeting rules; add only clearly classified Forever spells.
    c=replace(c,'local function baseSpellKey(spell)', '''rules("WARRIOR","assist","Victory Rush|Spearing Strike")
rules("PALADIN","assist","Holy Strike|Hammer of the Righteous|Judgement of Righteousness|Judgement of Fury|Judgement of the Crusader")
rules("WARLOCK","assist","Bane of Agony|Bane of Doom|Bane of Havoc|Curse of Exhaustion|Soul Fire|Subjugate Demon|Wrack")
rules("HUNTER","assist","Sniper Shot|Strider Kick")
rules("PRIEST","heal","Divine Grace|Prayer of Mending")
rules("PRIEST","assist","Chastise|Dark Sacrifice|Shadow Word: Death")
rules("DRUID","assist","Primal Bite")
local function baseSpellKey(spell)''')
    # Preserve the old tooltip/drag flow, but require verified learned skills even
    # when a macro already exists; never create a macro for a passive or future skill.
    c=replace(c,'    local exists,idx=owned(entry)\n    if idx then','    if entry.spell and (entry.passive or not spellKnown(entry)) then say("Spell not confirmed learned or passive: "..entry.title);return false end\n    local exists,idx=owned(entry)\n    if idx then')
    # Also retain passive spellbook records for display; do not mark as castable.
    c=replace(c,'        if not entry.passive then candidates[entry.spell:lower()]=entry.spell end','        candidates[entry.spell:lower()]=entry.spell')
    c=replace(c,'                if passive~=true then\n                    rememberSpell(sn,nil,icon,nil,2,passive,id);verified=verified+1\n                end','                rememberSpell(sn,nil,icon,nil,2,passive,id);verified=verified+1')
    # Source class categories, all-spells default, existing 12-card page geometry.
    c=replace(c,'    spellContent:Hide()\n    rows={}','''    spellContent:Hide()
    local categoryButtons={}
    panel.categoryButtons=categoryButtons
    for i=1,6 do
        local b=namedButton(panel,"",12+(i-1)*108,-48,105,25,function(self)
            selectedCategory=self.category or "All Spells";spellPage=1;HB.RefreshMacroMenu()
        end)
        categoryButtons[i]=b
    end
    rows={}''')
    c=replace(c,'        tile:SetScript("OnClick",function(self)','        local function pick(self)')
    c=replace(c,'            HB.PickupMacroPreset(entry.id)\n        end)\n        tile:SetScript("OnEnter"','            HB.PickupMacroPreset(entry.id)\n        end\n        tile:SetScript("OnClick",pick)\n        tile:RegisterForDrag("LeftButton")\n        tile:SetScript("OnDragStart",pick)\n        tile:SetScript("OnEnter"')
    c=replace(c,'            GameTooltip:AddLine((entry.level and ("Level "..tostring(entry.level)) or "Learned spell").." | "..entry.kind,0.75,0.72,0.64)','            local status,r,g,b=spellStatus(entry)\n            GameTooltip:AddLine(status,r,g,b)\n            GameTooltip:AddLine((entry.category or "Other").." | "..entry.kind,0.75,0.72,0.64)')
    c=replace(c,'        spellPage=math.min(math.ceil(#(SMART[me()] or {})/PER_PAGE),spellPage+1)','        spellPage=math.min(math.max(1,math.ceil(#filteredSpells()/PER_PAGE)),spellPage+1)')
    c=replace(c,'    local entries=activeSpells()\n    local totalPages','''    local categories={"All Spells"}
    for _,g in ipairs(FOREVER[me()] or {}) do categories[#categories+1]=g[1] end
    categories[#categories+1]="Other"
    local present=false
    for i,b in ipairs(panel.categoryButtons) do
        b.category=categories[i];b:SetShown(categories[i]~=nil)
        if categories[i] then
            b:SetText(categories[i]);b:SetEnabled(categories[i]~=selectedCategory)
            if categories[i]==selectedCategory then present=true end
        end
    end
    if not present then selectedCategory="All Spells" end
    local entries=filteredSpells()
    local totalPages''')
    start=c.index('            local known=spellKnown(entry)',c.index('function HB.RefreshMacroMenu()'))
    end=c.index('\n        end\n    end\n    rows.spellPage:SetText',start)
    c=c[:start]+'''            local status,r,g,b=spellStatus(entry)
            c.level:SetText(status)
            c.level:SetTextColor(r,g,b)
            setIcon(c.tex,entry)
            c.tex:SetVertexColor(1,1,1)
            c.name:SetTextColor(r,g,b)
'''+c[end:]
    c=replace(c,'(Lv 1-60, active)','(Lv 1-60)')
    c=replace(c,'    page=which;waiting=nil;conflict=nil','    page=which;waiting=nil;conflict=nil\n    if which=="spells" then selectedCategory="All Spells";spellPage=1 end')
    import re
    c,n=re.subn(r'panel\.heading:SetText\("[^"\n]*Macro Menu"\)', 'panel.heading:SetText("JCDRbox | "..tostring(me() or "").." | Macro Menu")', c)
    assert n==1,("macro heading",n)
    c=replace(c,'{"PLAYER_ENTERING_WORLD","SPELLS_CHANGED","LEARNED_SPELL_IN_TAB"}','{"PLAYER_ENTERING_WORLD","SPELLS_CHANGED","LEARNED_SPELL_IN_TAB","PLAYER_LEVEL_UP"}')
    # Do not scan on each level event when the menu is closed; normal spell events remain.
    # Known catalog entries use live name lookup and actual icons where the client exposes them.
    mods={toc:s.encode(),macro:c.encode()}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)
    for n,b in {**original,**mods}.items():assert out.read(n)==b,n
    for n,b in mods.items():
        if n.endswith('.lua'):
            p=Path(temp)/Path(n).name;p.write_bytes(b);subprocess.run(['luac5.1','-p',str(p)],check=True)
    names=('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterSync.lua','PeerAuth.lua','RegisterPeerSync.lua','ManagementUI.lua','TeamPlannerUI.lua')
    for n in names:
        p=Path(temp)/n;p.write_bytes(out.read('HaploBox/'+n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/names[0])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-tm/test_tm.lua'),str(Path(temp)/names[1])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_sync.lua'),*[str(Path(temp)/n) for n in names[:4]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_peer.lua'),*[str(Path(temp)/n) for n in names[:6]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-scroll-spacing/test_ui.lua'),str(Path(temp)/'ManagementUI.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-team-invite/test_tm_ui.lua'),str(Path(temp)/'TeamPlannerUI.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-team-invite/test_invite.lua'),str(Path(temp)/'TeamPlanner.lua')],check=True)
    (Path(temp)/'Core.lua').write_bytes(out.read('HaploBox/Core.lua'))
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-legacy-accept/test_accept.lua'),str(Path(temp)/'CharacterManagement.lua'),str(Path(temp)/'Core.lua')],check=True)
    (Path(temp)/'ControlBar.lua').write_bytes(out.read('HaploBox/ControlBar.lua'))
    (Path(temp)/'Party.lua').write_bytes(out.read('HaploBox/Party.lua'))
    (Path(temp)/'Gameplay.lua').write_bytes(out.read('HaploBox/Gameplay.lua'))
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-party-loot/test_party_loot.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua'),str(Path(temp)/'RegisterSync.lua'),str(Path(temp)/'ControlBar.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-auto-roles/test_roles.lua'),str(Path(temp)/'TeamPlanner.lua'),str(Path(temp)/'Core.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
    (Path(temp)/'BoxMode.lua').write_bytes(out.read('HaploBox/BoxMode.lua'))
    (Path(temp)/'Gameplay.lua').write_bytes(out.read('HaploBox/Gameplay.lua'))
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-auto-box-mode/test_box.lua'),str(Path(temp)/'BoxMode.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_macro.lua'),str(Path(temp)/'MacroLibrary.lua')],check=True)
report={'version':'JB26.3.23','base':'JB26.3.22','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Nine-class Forever catalogue, learned/level/special status, category filters, verified click/drag, existing BoxMode macro templates unchanged; candidate only'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
