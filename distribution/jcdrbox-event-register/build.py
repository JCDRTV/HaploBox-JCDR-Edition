from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-event-register'
BASE=ROOT/'distribution/jcdrbox-no-accept/output/JCDRbox_JB26.3.4_Automatic_Register_TEST.zip'
SHA='04b14039285a037037804a18598fa7c8e268eb702203ed9cc3e3e3e45fad1d33'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.5_Event_Register_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# Verify the exact immutable Git object used by the published release.
blob=subprocess.check_output(['git','hash-object',str(BASE)],cwd=ROOT,text=True).strip()
assert blob=='eb2af6f925cd8fb0bba5b9246e9e10253a179078',blob
actual=hashlib.sha256(BASE.read_bytes()).digest()
assert actual==bytes.fromhex(SHA),(actual.hex(),SHA)
print('Verified original Git blob and SHA-256:',blob,actual.hex())
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.4','## Version: JB26.3.5')
    mods={toc:s.encode(),**{'HaploBox/'+n:(SRC/n).read_bytes() for n in ('RegisterSync.lua','RegisterPeerSync.lua')}}
    for n in ('RegisterSync.lua','RegisterPeerSync.lua'):
        assert b'NewTicker' not in mods['HaploBox/'+n]
    assert b'syncButton' not in original[ui]
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
    subprocess.run(['lua5.1',str(SRC/'test_peer.lua'),*[str(Path(temp)/n) for n in names[:6]]],check=True)
report={'version':'JB26.3.5','base':'JB26.3.4','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'CM/TM recurring tickers removed; event-driven only; BM26.2.0 and other systems unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
