from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-tm-preview'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.10' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-tm-align/output/JCDRbox_JB26.3.10_TM_Alignment_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.11_TM_Screen_Layout_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.10','## Version: JB26.3.11')
    c=original[ui].decode()
    c=replace(c,'''    preview={}
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
    end''','''    preview={}
    for i=1,5 do
        local p=CreateFrame("Frame",nil,panel)
        local edge=p:CreateTexture(nil,"BACKGROUND");edge:SetAllPoints();p.edge=edge
        local bg=p:CreateTexture(nil,"BORDER")
        bg:SetPoint("TOPLEFT",p,"TOPLEFT",1,-1);bg:SetPoint("BOTTOMRIGHT",p,"BOTTOMRIGHT",-1,1);p.bg=bg
        p.title=text(p,i==1 and "1 - MAIN" or tostring(i),6,-5,100,muted)
        p.label=text(p,"",4,-20,100,silver);p.label:SetJustifyH("CENTER")
        p.role=text(p,"",4,-36,100,muted);p.role:SetJustifyH("CENTER")
        preview[i]=p
    end''')
    c=replace(c,'''    text(panel,"Preview only - live party and invites unchanged.",180,-308,480,muted)
    render=function()''','''    local previewNote=text(panel,"Preview only - live party and invites unchanged.",180,-308,480,muted)
    local function place(o,p,x,y)
        o:ClearAllPoints();o:SetPoint("TOPLEFT",p,"TOPLEFT",x,y)
    end
    local function font(o,size)
        if STANDARD_TEXT_FONT then o:SetFont(STANDARD_TEXT_FONT,size,"") end
    end
    function panel.ResizePreview(w,h)
        local pw=w-24
        panel:SetSize(pw,h-118)
        -- The upper controls retain their original approved positions.
        -- Fit the same 16:9 screen geometry to the available space.
        local gap=6
        local available=math.max(65,h-362)
        local mainW=math.min(pw,math.floor((available-gap+3*gap*9/64)*64/45))
        local smallW=math.floor((mainW-3*gap)/4)
        local mainH=math.floor(mainW*9/16)
        local smallH=math.floor(smallW*9/16)
        local left=math.floor((pw-mainW)/2)
        for i,p in ipairs(preview) do
            local main=i==1
            local sw,sh=main and mainW or smallW,main and mainH or smallH
            local x=main and left or left+(i-2)*(smallW+gap)
            local y=main and -211 or -211-mainH-gap
            p:SetSize(sw,sh);place(p,panel,x,y)
            p.title:SetWidth(math.max(1,sw-12))
            p.label:SetWidth(math.max(1,sw-8));p.role:SetWidth(math.max(1,sw-8))
            local nameSize=main and math.min(24,math.max(12,math.floor(mainH/6))) or math.min(14,math.max(8,math.floor(smallH/4)))
            local roleSize=main and 13 or 10
            local compact=sh<40
            font(p.title,main and 11 or 9);font(p.label,nameSize);font(p.role,roleSize)
            p.title:SetShown(not compact)
            p.role:SetShown(not compact)
            place(p.label,p,4,-math.floor(sh/2)+(compact and math.floor(nameSize/2) or 8))
            place(p.role,p,4,-math.floor(sh/2)-nameSize+4)
        end
        local footer=-211-mainH-gap-smallH-8
        place(legacy,panel,0,footer)
        place(previewNote,panel,180,footer-7)
    end
    panel.ResizePreview(parent:GetWidth(),parent:GetHeight())
    render=function()''')
    c=replace(c,'''            p.bg:SetColorTexture(c and .063 or .035,c and .137 or .058,c and .196 or .079,1)
            p.label:SetText(c and (c.name.."  /  "..(roleLabels[s.role] or "-")) or "-")
            p.label:SetTextColor(unpack(c and classColor(c) or muted))''','''            p.edge:SetColorTexture(c and .25 or .16,c and .35 or .20,c and .43 or .24,1)
            p.bg:SetColorTexture(c and .086 or .055,c and .169 or .079,c and .224 or .106,1)
            p.label:SetText(c and (c.name:match("^%S+") or c.name) or "-")
            p.label:SetTextColor(unpack(c and classColor(c) or muted))
            p.role:SetText(c and (roleLabels[s.role] or "-") or "Empty")''')
    mg='HaploBox/ManagementUI.lua'
    g=original[mg].decode()
    g=replace(g,'local layout,windowPrefs','local layout,windowPrefs\nlocal cmHeight,tmHeight')
    g=replace(g,'''local function setTab(t)
    tab=t;switch("list")
end''','''local function setTab(t)
    if t~=tab then
        local h=frame:GetHeight()
        if t=="teams" then
            cmHeight=h
            local screenH=UIParent:GetHeight()
            local desired=math.max(h,tmHeight or 670)
            if type(screenH)=="number" and screenH>0 then desired=math.min(desired,math.max(h,screenH-40)) end
            tab=t;frame:SetHeight(desired)
        else
            tmHeight=h
            tab=t
            if cmHeight then frame:SetHeight(cmHeight) end
        end
    end
    switch("list")
end''')
    g=replace(g,'windowPrefs.width=frame:GetWidth();windowPrefs.height=frame:GetHeight()','windowPrefs.width=frame:GetWidth();windowPrefs.height=(tab=="teams" and cmHeight) or frame:GetHeight()')
    g=replace(g,'        body:SetSize(w-24,h-118)','        body:SetSize(w-24,h-118)\n        if teamPanel and type(teamPanel.ResizePreview)=="function" then teamPanel.ResizePreview(w,h) end')
    mods={toc:s.encode(),ui:c.encode(),mg:g.encode()}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)
    for n,b in {**original,**mods}.items():assert out.read(n)==b,n
    names=('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterSync.lua','PeerAuth.lua','RegisterPeerSync.lua','ManagementUI.lua','TeamPlannerUI.lua')
    for n in names:
        p=Path(temp)/n;p.write_bytes(out.read('HaploBox/'+n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/names[0])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-tm/test_tm.lua'),str(Path(temp)/names[1])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_sync.lua'),*[str(Path(temp)/n) for n in names[:4]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_peer.lua'),*[str(Path(temp)/n) for n in names[:6]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-scroll-spacing/test_ui.lua'),str(Path(temp)/'ManagementUI.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_tm_ui.lua'),str(Path(temp)/'TeamPlannerUI.lua')],check=True)
report={'version':'JB26.3.11','base':'JB26.3.10','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'TM 16:9 screen preview, first name in class color, role below, adaptive layout and separate session height; register logic unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
