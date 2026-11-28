from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-cm'
BASE=ROOT/'distribution/jcdrbox-identity/output/JCDRbox_JB26.1.0_Identity_TEST.zip'
SHA='b69e9eb31c6d43a2a6c8d7dc91b1d772681545f01ade5e36e25e67f2e1662841'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.2.0_Character_Management_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc'
    control='HaploBox/ControlBar.lua'
    s=original[toc].decode('utf-8')
    s=replace(s,'## Version: JB26.1.0','## Version: JB26.2.0')
    s=replace(s,'TeamManagement.lua','TeamManagement.lua\nCharacterManagement.lua\nManagementUI.lua')
    c=original[control].decode('utf-8')
    c=replace(c,'if HB.OpenTeamManagement then HB.OpenTeamManagement() end','if HB.OpenManagement then HB.OpenManagement() end')
    c=replace(c,'mkButton(33,"TEAM MANAGER"','mkButton(33,"MANAGEMENT"')
    c=replace(c,'{"Active Team",{33}}','{"Management",{33}}')
    mods={toc:s.encode(),control:c.encode()}
    additions={'HaploBox/'+n:(SRC/n).read_bytes() for n in ('CharacterManagement.lua','ManagementUI.lua')}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
        for n,b in additions.items():out.writestr(n,b)
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)|set(additions)
    for n,b in {**original,**mods,**additions}.items():assert out.read(n)==b,n
    for n in [control,*additions]:
        p=Path(temp)/Path(n).name;p.write_bytes(out.read(n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_cm.lua'),str(Path(temp)/'CharacterManagement.lua')],check=True)
report={'version':'JB26.2.0','base':'JB26.1.0','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'added_files':list(additions),'status':'ingame acceptance open; local catalog only; legacy trust and TM unchanged'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
