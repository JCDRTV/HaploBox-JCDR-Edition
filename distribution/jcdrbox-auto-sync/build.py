from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-sync'
BASE=SRC/'output/JCDRbox_JB26.3.1_Register_Sync_TEST.zip'
SHA='6bd639d387fc5ee8913f2929a375a68ae724d078b0748cb6ced24ef1933fb05a'
OUT=ROOT/'distribution/jcdrbox-auto-sync/output';OUT.mkdir(parents=True,exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.2_Auto_Sync_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';sync='HaploBox/RegisterSync.lua'
    s=original[toc].decode()
    assert s.count('## Version: JB26.3.1')==1
    mods={toc:s.replace('## Version: JB26.3.1','## Version: JB26.3.2').encode(),sync:(SRC/'RegisterSync.lua').read_bytes()}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)
    for n,b in {**original,**mods}.items():assert out.read(n)==b,n
    for name in ('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterSync.lua','ManagementUI.lua','TeamPlannerUI.lua'):
        p=Path(temp)/name;p.write_bytes(out.read('HaploBox/'+name));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/'CharacterManagement.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-tm/test_tm.lua'),str(Path(temp)/'TeamPlanner.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_sync.lua'),*[str(Path(temp)/n) for n in ('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterSync.lua')]],check=True)
report={'version':'JB26.3.2','base':'JB26.3.1','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Ingame acceptance open; 10-second periodic reconciliation, automatic retry, combat exit; no macro changes'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
