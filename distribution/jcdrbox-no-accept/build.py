from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-no-accept'
BASE=ROOT/'distribution/jcdrbox-central/output/JCDRbox_JB26.3.3_Central_Register_TEST.zip'
SHA='8877db5b616f20ecdd37a42f22e73cb72b6b2a9542215da319178feda4b99c70'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.4_Automatic_Register_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.3','## Version: JB26.3.4')
    c=original[ui].decode()
    c=replace(c,'frame.syncLine=text(frame,"",12,-422,480,muted)','frame.syncLine=text(frame,"",12,-422,660,muted)')
    c=replace(c,'    frame.syncButton=button(frame,"Sync Register",516,-414,150,function() HB.RegisterSync.Action() end)','')
    c=replace(c,'            frame.syncButton:SetText(HB.RegisterSync.ActionLabel())','')
    c=replace(c,'    frame.syncButton:SetText(HB.RegisterSync.ActionLabel())','')
    mods={toc:s.encode(),ui:c.encode(),**{'HaploBox/'+n:(SRC/n).read_bytes() for n in ('RegisterSync.lua','RegisterPeerSync.lua')}}
    assert b'Accept Register' not in mods['HaploBox/RegisterSync.lua'] and b'syncButton' not in mods[ui]
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
    subprocess.run(['lua5.1',str(SRC/'test_sync.lua'),*[str(Path(temp)/n) for n in names[:4]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-central/test_peer.lua'),*[str(Path(temp)/n) for n in names[:6]]],check=True)
report={'version':'JB26.3.4','base':'JB26.3.3','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Requires BM26.2.0 shared key for automatic solo peer sync; removes manual acceptance; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
