from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-tm-align'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.9' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-scroll-spacing/output/JCDRbox_JB26.3.9_Scroll_Spacing_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.10_TM_Alignment_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.9','## Version: JB26.3.10')
    c=original[ui].decode()
    c=replace(c,'    local function setColor(b,c)', '''    local function alignLeft(b)
        local f=b:GetFontString()
        if not f then return end
        f:ClearAllPoints()
        f:SetPoint("LEFT",b,"LEFT",4,0)
        f:SetPoint("RIGHT",b,"RIGHT",-4,0)
        f:SetJustifyH("LEFT")
    end
    local function setColor(b,c)''')
    c=replace(c,'text(panel,"Character",216,-52,240,muted)','text(panel,"Character",218,-52,240,muted)')
    c=replace(c,'        rows[i]=r','        alignLeft(r.account);alignLeft(r.character);alignLeft(r.role)\n        rows[i]=r')
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
report={'version':'JB26.3.10','base':'JB26.3.9','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'TM Account, Character and Role labels left aligned; CM and team logic unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
