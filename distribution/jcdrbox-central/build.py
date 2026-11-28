from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-central'
BASE=ROOT/'distribution/jcdrbox-sync/output/JCDRbox_JB26.3.1_Register_Sync_TEST.zip'
SHA='6bd639d387fc5ee8913f2929a375a68ae724d078b0748cb6ced24ef1933fb05a'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.2_Central_Register_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua';removed='HaploBox/RegisterSync.lua'
    s=original[toc].decode()
    s=replace(s,'## Version: JB26.3.1','## Version: JB26.3.2')
    s,n=re.subn(r'(?m)^(## SavedVariables:[^\r\n]+)$',r'\1, JCDRRegisterBase, JCDRRegisterCurrent',s)
    assert n==1
    s=replace(s,'RegisterSync.lua\nManagementUI.lua','RegisterInbox.lua\nRegisterBridge.lua\nManagementUI.lua')
    c=original[ui].decode()
    c=replace(c,'frame.syncLine=text(frame,"",12,-422,480,muted)','frame.syncLine=text(frame,"",12,-422,660,muted)')
    c=replace(c,'    frame.syncButton=button(frame,"Sync Register",516,-414,150,function() HB.RegisterSync.Action() end)','')
    c=replace(c,'            frame.syncButton:SetText(HB.RegisterSync.ActionLabel())','')
    c=replace(c,'    frame.syncButton:SetText(HB.RegisterSync.ActionLabel())','')
    mods={toc:s.encode(),ui:c.encode()}
    additions={'HaploBox/'+n:(SRC/n).read_bytes() for n in ('RegisterInbox.lua','RegisterBridge.lua')}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():
            if info.filename!=removed:out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
        for n,b in additions.items():out.writestr(n,b)
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==(set(original)-{removed})|set(additions)
    for n,b in {**original,**mods,**additions}.items():
        if n!=removed:assert out.read(n)==b,n
    for n in [ui,'HaploBox/TeamPlannerUI.lua','HaploBox/CharacterManagement.lua','HaploBox/TeamPlanner.lua','HaploBox/RegisterCodec.lua',*additions]:
        p=Path(temp)/Path(n).name;p.write_bytes(out.read(n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/'CharacterManagement.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-tm/test_tm.lua'),str(Path(temp)/'TeamPlanner.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_bridge.lua'),*[str(Path(temp)/n) for n in ('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterBridge.lua')]],check=True)
report={'version':'JB26.3.2','base':'JB26.3.1','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods)-1,'modified_files':list(mods),'removed_files':[removed],'added_files':list(additions),'status':'Requires BM26.1.14 central bridge; no party or consent; logout/reload required for SavedVariables; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
