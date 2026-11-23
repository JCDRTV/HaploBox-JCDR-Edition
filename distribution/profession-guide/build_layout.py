#!/usr/bin/env python3
"""HF26.20.49 TEST – visual polish to match existing Dungeon Advisor.

Source: the complete SHA-verified HF26.20.48 TEST archive.
Patch ONLY ProfessionGuide/UI.lua plus mandatory TOC version metadata.
No changes to party sync, professions, Dungeon Advisor/Run, Pawn, or menus.
"""
import hashlib, json, re
from pathlib import Path
from zipfile import ZipFile

root = Path(__file__).resolve().parents[2]
dist = root / "distribution" / "test"
mp = dist / "manifest.json"
prev, nxt = "HF26.20.48", "HF26.20.49"
name = "HaploBox_HF26.20.49_Profession_Advisor_Layout_TEST.zip"
prefix = "https://raw.githubusercontent.com/JCDRTV/HaploBox-JCDR-Edition/main/"
output = dist / name
ui_path = "HaploBox/ProfessionGuide/UI.lua"
toc_path = "HaploBox/HaploBox.toc"
hash_bytes = lambda b: hashlib.sha256(b).hexdigest()


def once(text, old, new, label):
    if text.count(old) != 1:
        raise RuntimeError(f"{label}: expected 1 anchor, found {text.count(old)}")
    return text.replace(old, new, 1)


def update_ui(raw):
    bom = raw.startswith(b"\xef\xbb\xbf")
    s = raw.decode("utf-8-sig")
    crlf = "\r\n" in s
    s = s.replace("\r\n", "\n")
    s = once(s,
        '    bg={0.065,0.075,0.095,0.98}, panel={0.105,0.125,0.155,1},\n'
        '    tile={0.14,0.16,0.19,1}, hover={0.19,0.235,0.27,1},\n'
        '    green={0.31,0.77,0.50,1}, gold={0.97,0.73,0.33,1},',
        '    bg={0.085,0.100,0.125,0.99}, panel={0.11,0.135,0.170,1},\n'
        '    tile={0.145,0.175,0.215,1}, hover={0.20,0.29,0.36,1},\n'
        '    green={0.15,0.43,0.29,1}, blue={0.14,0.32,0.49,1},\n'
        '    selected={0.15,0.31,0.27,1}, border={0.67,0.49,0.20,1},\n'
        '    gold={1,0.80,0.30,1},',
        "Dungeon color palette"
    )
    s = once(s,
        '    t:SetTextColor(unpack(color or C.white))',
        '    t:SetTextColor(unpack(color or C.white))\n'
        '    if STANDARD_TEXT_FONT then\n'
        '        t:SetFont(STANDARD_TEXT_FONT, size == "large" and 14 or 12, "OUTLINE")\n'
        '    end',
        "readable typography"
    )
    s = once(s,
        '    b.tint=fill(b,C.tile)\n'
        '    local l=text(b,label,nil,C.white,width-10,"CENTER")\n'
        '    l:SetPoint("CENTER",0,0)\n'
        '    b.label=l\n'
        '    b:SetScript("OnEnter",function(self) self.tint:SetVertexColor(unpack(C.hover)) end)\n'
        '    b:SetScript("OnLeave",function(self) self.tint:SetVertexColor(unpack(C.tile)) end)',
        '    b.tint=fill(b,C.tile)\n'
        '    b.normal=C.tile\n'
        '    b.hover=C.hover\n'
        '    function b:SetColors(normal, over)\n'
        '        self.normal=normal or C.tile\n'
        '        self.hover=over or C.hover\n'
        '        self.tint:SetVertexColor(unpack(self.normal))\n'
        '    end\n'
        '    local l=text(b,label,nil,C.white,width-10,"CENTER")\n'
        '    l:SetPoint("CENTER",0,0)\n'
        '    b.label=l\n'
        '    b:SetScript("OnEnter",function(self) self.tint:SetVertexColor(unpack(self.hover)) end)\n'
        '    b:SetScript("OnLeave",function(self) self.tint:SetVertexColor(unpack(self.normal)) end)',
        "button hover and selected style"
    )
    s = once(s,
        '    fill(f,C.bg)\n'
        '    local header=CreateFrame("Frame",nil,f)',
        '    fill(f,C.bg)\n'
        '    -- Same narrow gold frame and title rule used by the Dungeon Advisor.\n'
        '    local function rule(pointA, pointB, horizontal)\n'
        '        local edge=f:CreateTexture(nil,"BORDER")\n'
        '        edge:SetTexture(WHITE)\n'
        '        edge:SetVertexColor(unpack(C.border))\n'
        '        edge:SetPoint(pointA,f,pointA,0,0)\n'
        '        edge:SetPoint(pointB,f,pointB,0,0)\n'
        '        if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end\n'
        '    end\n'
        '    rule("TOPLEFT","TOPRIGHT",true)\n'
        '    rule("BOTTOMLEFT","BOTTOMRIGHT",true)\n'
        '    rule("TOPLEFT","BOTTOMLEFT",false)\n'
        '    rule("TOPRIGHT","BOTTOMRIGHT",false)\n'
        '    local header=CreateFrame("Frame",nil,f)',
        "gold panel border"
    )
    s = once(s,
        '    header:SetHeight(42)\n'
        '    fill(header,C.panel)\n'
        '    local t=text(header,title,"large")\n'
        '    t:SetPoint("LEFT",header,"LEFT",15,0)\n'
        '    drag(f,header)\n'
        '    local close=button(header,"X",28,26,function() f:Hide() end)\n'
        '    close:SetPoint("RIGHT",header,"RIGHT",-10,0)',
        '    header:SetHeight(36)\n'
        '    fill(header,C.panel)\n'
        '    local titleRule=header:CreateTexture(nil,"ARTWORK")\n'
        '    titleRule:SetTexture(WHITE)\n'
        '    titleRule:SetVertexColor(unpack(C.border))\n'
        '    titleRule:SetPoint("BOTTOMLEFT",header,"BOTTOMLEFT",1,0)\n'
        '    titleRule:SetPoint("BOTTOMRIGHT",header,"BOTTOMRIGHT",-1,0)\n'
        '    titleRule:SetHeight(2)\n'
        '    local t=text(header,title,"large",C.gold)\n'
        '    t:SetPoint("LEFT",header,"LEFT",15,0)\n'
        '    drag(f,header)\n'
        '    local close=button(header,"X",28,26,function() f:Hide() end)\n'
        '    close:SetColors(C.blue)\n'
        '    close:SetPoint("RIGHT",header,"RIGHT",-10,0)',
        "Dungeon-like header, gold rule, blue close"
    )
    s = once(s,
        'local m=panel("HaploBoxProfessionAdvisor",876,535,"HAPLOBOX  /  PROFESSION ADVISOR",-60)',
        'local m=panel("HaploBoxProfessionAdvisor",1004,568,"HAPLOBOX  /  PROFESSION ADVISOR",-60)',
        "main window width"
    )
    s = once(s,
        '    PG.mainSub=text(m,"WO W FOREVER  |  PARTY SKILLS  |  1-300",nil,C.gray)\n'
        '    PG.mainSub:SetPoint("TOPLEFT",m,"TOPLEFT",18,-55)',
        '    PG.mainSub=text(m,"WOW FOREVER  |  PARTY SKILLS  |  1-300",nil,C.gray)\n'
        '    PG.mainSub:SetPoint("TOPLEFT",m,"TOPLEFT",18,-55)\n'
        '    local professionLabel=text(m,"PROFESSIONS","large",C.gold)\n'
        '    professionLabel:SetPoint("TOPLEFT",m,"TOPLEFT",18,-81)\n'
        '    local teamLabel=text(m,"PARTY SKILLS","large",C.gold)\n'
        '    teamLabel:SetPoint("TOPLEFT",m,"TOPLEFT",576,-81)',
        "section headings"
    )
    s = once(s,
        '        local x=18+col*164\n'
        '        local y=-90-row*118\n'
        '        local b=button(m,"",154,106,function()',
        '        local x=18+col*176\n'
        '        local y=-111-row*120\n'
        '        local b=button(m,"",164,108,function()',
        "larger cards and spacing"
    )
    s = once(s,
        '        ico:SetSize(36,36)\n'
        '        ico:SetPoint("TOP",b,"TOP",0,-6)\n'
        '        local n=text(b,p.name,nil,C.white,140,"CENTER")',
        '        ico:SetSize(38,38)\n'
        '        ico:SetPoint("TOP",b,"TOP",0,-7)\n'
        '        local n=text(b,p.name,nil,C.white,150,"CENTER")',
        "icon and tile text"
    )
    s = once(s,
        '        local stat=text(b,"—",nil,C.gray,140,"CENTER")',
        '        local stat=text(b,"—",nil,C.gray,150,"CENTER")',
        "profession status width"
    )
    s = once(s,
        '    separator:SetSize(1,409)\n'
        '    separator:SetPoint("TOPLEFT",m,"TOPLEFT",518,-85)\n'
        '    fill(separator,C.tile)\n'
        '    local head=text(m,"LEATHERWORKING","large",C.white,320)\n'
        '    head:SetPoint("TOPLEFT",m,"TOPLEFT",540,-91)',
        '    separator:SetSize(1,436)\n'
        '    separator:SetPoint("TOPLEFT",m,"TOPLEFT",553,-83)\n'
        '    fill(separator,C.border)\n'
        '    local head=text(m,"LEATHERWORKING","large",C.white,385)\n'
        '    head:SetPoint("TOPLEFT",m,"TOPLEFT",576,-114)',
        "right column separator"
    )
    s = once(s,
        '    PG.mainDetail=text(m,"Party-wide profession progress",nil,C.gray,308)',
        '    PG.mainDetail=text(m,"Party-wide profession progress",nil,C.gray,400)',
        "right column subheading width"
    )
    s = once(s,
        '        local cell=button(m,"",310,48,function()',
        '        local cell=button(m,"",397,48,function()',
        "team row width"
    )
    s = once(s,
        '        cell:SetPoint("TOPLEFT",m,"TOPLEFT",538,-163-(i-1)*55)',
        '        cell:SetPoint("TOPLEFT",m,"TOPLEFT",576,-167-(i-1)*55)',
        "team row position"
    )
    s = once(s,
        '    local refresh=button(m,"SCAN / SYNC",130,31,function()',
        '    local refresh=button(m,"SCAN / SYNC",164,31,function()',
        "scan button width"
    )
    s = once(s,
        '    refresh:SetPoint("BOTTOMLEFT",m,"BOTTOMLEFT",539,18)\n'
        '    local launch=button(m,"OPEN GUIDE",164,31,function() PG.OpenRun(PG.db.selected) end)\n'
        '    launch:SetPoint("LEFT",refresh,"RIGHT",12,0)',
        '    refresh:SetColors(C.green)\n'
        '    refresh:SetPoint("BOTTOMLEFT",m,"BOTTOMLEFT",576,18)\n'
        '    local launch=button(m,"OPEN GUIDE",184,31,function() PG.OpenRun(PG.db.selected) end)\n'
        '    launch:SetColors(C.blue)\n'
        '    launch:SetPoint("LEFT",refresh,"RIGHT",12,0)',
        "bright scan/open action colors"
    )
    s = once(s,
        '    local foot=text(m,"Phase 1 TEST - overview + run window. Recipe steps/material NEED are not enabled yet.",nil,C.gray,817)',
        '    local foot=text(m,"PHASE 1 TEST  |  Recipes and party materials are not enabled yet.",nil,C.gray,540)',
        "footer readability"
    )
    s = once(s,
        '    local r=panel("HaploBoxProfessionRun",448,431,"PROFESSION RUN",220)',
        '    local r=panel("HaploBoxProfessionRun",448,431,"HAPLOBOX  /  PROFESSION RUN",220)',
        "run window title"
    )
    s = once(s,
        '    fill(stepPane,C.panel)\n'
        '    PG.stepTitle=text(stepPane,"NEXT LEVELING STEP","large",C.white,381)',
        '    fill(stepPane,C.panel)\n'
        '    local stepRule=stepPane:CreateTexture(nil,"ARTWORK")\n'
        '    stepRule:SetTexture(WHITE)\n'
        '    stepRule:SetVertexColor(unpack(C.border))\n'
        '    stepRule:SetPoint("TOPLEFT",stepPane,"TOPLEFT",0,0)\n'
        '    stepRule:SetPoint("TOPRIGHT",stepPane,"TOPRIGHT",0,0)\n'
        '    stepRule:SetHeight(1)\n'
        '    PG.stepTitle=text(stepPane,"NEXT LEVELING STEP","large",C.gold,381)',
        "run step gold heading"
    )
    s = once(s,
        '    local matTitle=text(r,"PARTY MATERIAL FINDER",nil,C.white,410)',
        '    local matTitle=text(r,"PARTY MATERIAL FINDER","large",C.gold,410)',
        "run material heading"
    )
    s = once(s,
        '    back:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",-15,12)\n'
        '    local scan=button(r,"SYNC PARTY",120,28,function() PG.ScanMySkills();PG.Broadcast(true);PG.RefreshUI() end)\n'
        '    scan:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",16,12)',
        '    back:SetColors(C.blue)\n'
        '    back:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",-15,12)\n'
        '    local scan=button(r,"SYNC PARTY",120,28,function() PG.ScanMySkills();PG.Broadcast(true);PG.RefreshUI() end)\n'
        '    scan:SetColors(C.green)\n'
        '    scan:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",16,12)',
        "run window actions"
    )
    s = once(s,
        '        if pcode==code then card.back:SetVertexColor(0.17,0.28,0.26,1)\n'
        '        else card.back:SetVertexColor(unpack(C.tile)) end',
        '        if pcode==code then card.button:SetColors(C.selected)\n'
        '        else card.button:SetColors(C.tile) end',
        "selected tile hover logic"
    )
    if crlf:
        s=s.replace("\n","\r\n")
    return (b"\xef\xbb\xbf" if bom else b"")+s.encode("utf-8")


def update_toc(raw):
    bom=raw.startswith(b"\xef\xbb\xbf")
    text=raw.decode("utf-8-sig")
    nl="\r\n" if "\r\n" in text else "\n"
    text=text.replace("\r\n","\n")
    matches=list(re.finditer(r"(?m)^(##\s*Version\s*:\s*)([^\n]*)$",text))
    if len(matches)!=1 or prev not in matches[0].group(2):
        raise RuntimeError("Unexpected packaged TOC version")
    text=re.sub(r"(?m)^(##\s*Version\s*:\s*)([^\n]*)$",lambda m:m.group(1)+nxt,text,count=1)
    if nl=="\r\n":text=text.replace("\n","\r\n")
    return (b"\xef\xbb\xbf" if bom else b"")+text.encode("utf-8")


m=json.loads(mp.read_text(encoding="utf-8"))
if m.get("version")==nxt:
    if output.is_file() and hash_bytes(output.read_bytes())==m.get("sha256"):
        print("ALREADY RELEASED: verified",nxt)
        raise SystemExit(0)
    raise RuntimeError("Manifest already claims new version, but package digest invalid")
if m.get("version")!=prev or m.get("channel")!="test" or m.get("addon_folder")!="HaploBox":
    raise RuntimeError("Unexpected base release "+str(m.get("version")))
if not m["zip_url"].startswith(prefix+"distribution/test/"):
    raise RuntimeError("Unexpected source path")
source=root/m["zip_url"][len(prefix):]
if hash_bytes(source.read_bytes())!=m["sha256"]:
    raise RuntimeError("Baseline ZIP checksum mismatch")
with ZipFile(source) as z:
    names=z.namelist()
    assert ui_path in names and toc_path in names
    updated_ui=update_ui(z.read(ui_path))
    updated_toc=update_toc(z.read(toc_path))
    with ZipFile(output,"w") as out:
        for entry in z.infolist():
            payload=updated_ui if entry.filename==ui_path else updated_toc if entry.filename==toc_path else z.read(entry.filename)
            out.writestr(entry,payload)
with ZipFile(source) as orig,ZipFile(output) as new:
    assert orig.namelist()==new.namelist()
    assert new.testzip() is None
    changed=[p for p in orig.namelist() if orig.read(p)!=new.read(p)]
    assert set(changed)=={ui_path,toc_path},changed
    ui=new.read(ui_path).decode("utf-8-sig")
    assert 'function PG.ToggleMain()' in ui and 'function PG.OpenRun(code)' in ui
    assert 'function PG.RefreshUI()' in ui
    assert 'PG.ScanMySkills();PG.Broadcast(true)' in ui
    assert '"PROFESSIONS","large",C.gold' in ui
    assert '"PARTY SKILLS","large",C.gold' in ui
    assert nxt in new.read(toc_path).decode("utf-8-sig")
    print("PASS: visual-only changes to ProfessionGuide/UI.lua and TOC version metadata")
    print("PASS: all other %d addon file entries byte-identical"%(len(new.namelist())-2))
    Path("/tmp/haplobox_profession_ui.lua").write_bytes(new.read(ui_path))

m.update(version=nxt,zip_url=prefix+"distribution/test/"+name,sha256=hash_bytes(output.read_bytes()),
         notes=("HF26.20.49 TEST: Profession Advisor visual layout refresh styled after Dungeon Advisor. "
                "Main panel enlarged, gold frame/header, readable headings, 3x3 profession cards, "
                "wider party skill rows, blue OPEN and green SCAN buttons. Compact run window "
                "receives same trim, gold step headings and aligned controls. "
                "No sync, profession data, Dungeon Advisor, BIS, Pawn, Weapon Sets or Quick Menu "
                "behavior modified. Only ProfessionGuide/UI.lua plus mandatory TOC version changed. "
                "ZIP CRC/SHA256 verified. INGAME VISUAL ACCEPTANCE OPEN."))
mp.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print("READY",nxt,"sha256",m["sha256"])
