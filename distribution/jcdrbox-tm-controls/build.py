from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-tm-controls'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.11' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-tm-preview/output/JCDRbox_JB26.3.11_TM_Screen_Layout_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.12_TM_Controls_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.11','## Version: JB26.3.12')
    c=original[ui].decode()
    c=replace(c,'deleteBtn,legacy,rows','deleteBtn,rows')
    c=replace(c,'''    rows={}
    for i=1,5 do''','''    local function orderArrow(x,y,direction,fn)
        local b=button(panel,"",x,y,42,fn)
        local marks={}
        for i=-2,2 do
            local mark=b:CreateTexture(nil,"OVERLAY")
            mark:SetSize(2,2)
            mark:SetPoint("CENTER",b,"CENTER",i*2,direction*(1-math.abs(i))*2)
            marks[#marks+1]=mark
        end
        b.SetOrderEnabled=function(self,enabled)
            self:SetEnabled(enabled)
            for _,mark in ipairs(marks) do
                if enabled then mark:SetColorTexture(.863,.910,.945,1)
                else mark:SetColorTexture(.32,.38,.43,1) end
            end
        end
        return b
    end
    rows={}
    for i=1,5 do''')
    c=replace(c,'r.up=button(panel,"<",574,y,42,function()','r.up=orderArrow(574,y,1,function()')
    c=replace(c,'r.down=button(panel,">",620,y,42,function()','r.down=orderArrow(620,y,-1,function()')
    c=replace(c,'r.up:SetEnabled(can and i>1','r.up:SetOrderEnabled(can and i>1')
    c=replace(c,'r.down:SetEnabled(can and i<5','r.down:SetOrderEnabled(can and i<5')
    c=replace(c,'''    legacy=button(panel,"Legacy party controls",0,-301,168,function()
        hidePopup();parent:Hide()
        if HB.OpenTeamManagement then HB.OpenTeamManagement() end
    end)
    local previewNote=text(panel,"Preview only - live party and invites unchanged.",180,-308,480,muted)''','''    local previewNote=text(panel,"Preview only - live party and invites unchanged.",0,-308,660,muted)''')
    c=replace(c,'''        place(legacy,panel,0,footer)
        place(previewNote,panel,180,footer-7)''','''        place(previewNote,panel,0,footer-7)''')
    mods={toc:s.encode(),ui:c.encode()}
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
report={'version':'JB26.3.12','base':'JB26.3.11','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'TM legacy shortcut removed, vertical order chevrons, existing swap logic unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
