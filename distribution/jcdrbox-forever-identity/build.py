from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-forever-identity'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.16' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-accept-realm/output/JCDRbox_JB26.3.16_Accept_Realm_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.17_Forever_Identity_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.16','## Version: JB26.3.17')
    cm='HaploBox/CharacterManagement.lua';core='HaploBox/Core.lua'
    c=original[cm].decode()
    c=replace(c,"    if not currentRealm or realmKey(own.realm)~=currentRealm then return nil,\"Own realm mismatch: CM=\"..tostring(realmKey(own.realm))..\", live=\"..tostring(currentRealm) end",'''    -- Forever's second UnitName/UnitFullName value is a surname.
    -- Legacy CM rows can contain that surname in the realm field.
    -- Never infer a live realm from it or rewrite the shared register here.
    local function storedRealm(r)
        local n=fullName(r.name)
        local last=n and n:match(" (%S+)$")
        local k=realmKey(r.realm)
        if k==last then return nil end
        return k
    end
    local ownRealm=storedRealm(own)
    if currentRealm and ownRealm and ownRealm~=currentRealm then
        return nil,"Own verified realm mismatch"
    end''')
    c=replace(c,"    if realmKey(match.realm)~=currentRealm then return nil,\"Inviter realm mismatch: CM=\"..tostring(realmKey(match.realm))..\", live=\"..tostring(currentRealm) end",'''    local targetRealm=storedRealm(match)
    if targetRealm and (currentRealm or ownRealm) and targetRealm~=(currentRealm or ownRealm) then
        return nil,"Inviter verified realm mismatch"
    end
    -- Without a usable realm, require the event GUID. No ambiguous name-only
    -- fallback for an invite with no independently verified realm.
    if not (currentRealm and ownRealm and targetRealm) and (inviterGuid==nil or (not (issecretvalue and issecretvalue(inviterGuid)) and inviterGuid=="")) then
        return nil,"Inviter GUID required: live realm unavailable or legacy surname"
    end''')
    mods={toc:s.encode(),cm:c.encode()}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)
    for n,b in {**original,**mods}.items():assert out.read(n)==b,n
    for n,b in mods.items():
        if n.endswith('.lua'):
            p=Path(temp)/Path(n).name;p.write_bytes(b);subprocess.run(['luac5.1','-p',str(p)],check=True)
    names=('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterSync.lua','PeerAuth.lua','RegisterPeerSync.lua','ManagementUI.lua','TeamPlannerUI.lua')
    for n in names:
        p=Path(temp)/n;p.write_bytes(out.read('HaploBox/'+n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/names[0])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-tm/test_tm.lua'),str(Path(temp)/names[1])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_sync.lua'),*[str(Path(temp)/n) for n in names[:4]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_peer.lua'),*[str(Path(temp)/n) for n in names[:6]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-scroll-spacing/test_ui.lua'),str(Path(temp)/'ManagementUI.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-team-invite/test_tm_ui.lua'),str(Path(temp)/'TeamPlannerUI.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-team-invite/test_invite.lua'),str(Path(temp)/'TeamPlanner.lua')],check=True)
    (Path(temp)/'Core.lua').write_bytes(out.read('HaploBox/Core.lua'))
    subprocess.run(['lua5.1',str(SRC/'test_accept.lua'),str(Path(temp)/'CharacterManagement.lua'),str(Path(temp)/'Core.lua')],check=True)
report={'version':'JB26.3.17','base':'JB26.3.16','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Recognize legacy surname in realm field, require event GUID when real realm unavailable; no saved register mutation; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
