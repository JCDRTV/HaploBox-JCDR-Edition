from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-scroll-spacing'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.8' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-flat-scroll/output/JCDRbox_JB26.3.8_Flat_Scroll_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.9_Scroll_Spacing_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.8','## Version: JB26.3.9')
    c=original[ui].decode()
    # Keep both action buttons at their existing widths; take 10 px from the flexible name column.
    c=replace(c,'body.headers.name:SetWidth(177+extra)','body.headers.name:SetWidth(167+extra)')
    c=replace(c,'place(body.headers.class,body,285+extra,-62);place(body.headers.race,body,373+extra,-62);place(body.headers.level,body,457+extra,-62)','place(body.headers.class,body,275+extra,-62);place(body.headers.race,body,363+extra,-62);place(body.headers.level,body,447+extra,-62)')
    c=replace(c,'r:SetWidth(646+extra);r.name:SetWidth(174+extra)','r:SetWidth(636+extra);r.name:SetWidth(164+extra)')
    c=replace(c,'place(r.class,r,289+extra,-6);place(r.race,r,377+extra,-6);place(r.level,r,461+extra,-6)','place(r.class,r,279+extra,-6);place(r.race,r,367+extra,-6);place(r.level,r,451+extra,-6)')
    c=replace(c,'place(r.assign,r,507+extra,-1);place(r.remove,r,590+extra,-1)','place(r.assign,r,497+extra,-1);place(r.remove,r,580+extra,-1)')
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
    subprocess.run(['lua5.1',str(SRC/'test_ui.lua'),str(Path(temp)/'ManagementUI.lua')],check=True)
report={'version':'JB26.3.9','base':'JB26.3.8','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'10 px extra gap before scrollbar; action button widths and all behavior unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
