from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-accept-diagnostics'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.14' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-auto-accept/output/JCDRbox_JB26.3.14_Auto_Accept_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.15_Accept_Diagnostics_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.14','## Version: JB26.3.15')
    cm='HaploBox/CharacterManagement.lua';core='HaploBox/Core.lua'
    c=original[cm].decode()
    marker='-- JB26.3.14: trust only explicit registered own characters.'
    assert c.count(marker)==1
    prefix,diag=c.split(marker)
    diag=replace(diag,"if not HB.db or HB.db.autoAcceptInvite==false then return nil end","if not HB.db or HB.db.autoAcceptInvite==false then return nil,\"Auto Accept disabled or DB unavailable\" end")
    diag=replace(diag,"if grouped~=false or raid~=false or combat~=false then return nil end","if grouped~=false or raid~=false or combat~=false then return nil,\"Group/raid/combat state: \"..tostring(grouped)..\"/\"..tostring(raid)..\"/\"..tostring(combat) end")
    diag=replace(diag,"if type(guid)~=\"string\" or guid==\"\" then return nil end","if type(guid)~=\"string\" or guid==\"\" then return nil,\"Own GUID unavailable\" end")
    diag=replace(diag,"if not own then return nil end","if not own then return nil,\"Own GUID not registered in CM\" end")
    diag=replace(diag,"if not ownName or actual~=ownName or not currentRealm or realmKey(own.realm)~=currentRealm then return nil end","if not ownName or actual~=ownName then return nil,\"Own full name mismatch: CM=\"..tostring(ownName)..\", live=\"..tostring(actual) end\n    if not currentRealm or realmKey(own.realm)~=currentRealm then return nil,\"Own realm mismatch: CM=\"..tostring(realmKey(own.realm))..\", live=\"..tostring(currentRealm) end")
    diag=replace(diag,"if not name or name==ownName then return nil end","if not name or name==ownName then return nil,\"Inviter full name invalid or self: \"..(type(inviter)==\"string\" and not (issecretvalue and issecretvalue(inviter)) and inviter:gsub(\"[%c|]\",\"?\"):sub(1,100) or \"(unavailable)\") end")
    diag=replace(diag,"if match then return nil end","if match then return nil,\"Ambiguous registered inviter name\" end")
    diag=replace(diag,"if not match or match.guid==guid or match.account==own.account or realmKey(match.realm)~=currentRealm then return nil end","if not match then return nil,\"Inviter not found by full name: \"..name end\n    if match.guid==guid or match.account==own.account then return nil,\"Inviter is same character/account\" end\n    if realmKey(match.realm)~=currentRealm then return nil,\"Inviter realm mismatch: CM=\"..tostring(realmKey(match.realm))..\", live=\"..tostring(currentRealm) end")
    diag=replace(diag,"if not accounts[own.account] or not accounts[match.account] then return nil end","if not accounts[own.account] or not accounts[match.account] then return nil,\"Account missing from CM\" end")
    diag=replace(diag,"if issecretvalue and issecretvalue(inviterGuid) then return nil end","if issecretvalue and issecretvalue(inviterGuid) then return nil,\"Inviter GUID secret\" end")
    diag=replace(diag,"if inviterGuid~=nil and inviterGuid~=\"\" and inviterGuid~=match.guid then return nil end","if inviterGuid~=nil and inviterGuid~=\"\" and inviterGuid~=match.guid then return nil,\"Inviter GUID mismatch (event type \"..type(inviterGuid)..\")\" end")
    diag=replace(diag,"local r=CM.TrustedInvite(inviter,inviterGuid)\n    if not r then return false end","local r,reason=CM.TrustedInvite(inviter,inviterGuid)\n    if not r then return false,reason end")
    diag=replace(diag,"if type(fn)~=\"function\" then return false end","if type(fn)~=\"function\" then return false,\"AcceptGroup API unavailable\" end")
    diag=replace(diag,"if not ok or (issecretvalue and issecretvalue(result)) or result==false then return false end","if not ok or (issecretvalue and issecretvalue(result)) or result==false then return false,\"AcceptGroup API rejected or protected\" end")
    diag=replace(diag,"    return true\nend\n","    return true,\"AcceptGroup requested; verify party joined\"\nend\n")
    c=prefix+marker+diag
    v=original[core].decode()
    import re
    pattern=r'function handlers\.PARTY_INVITE_REQUEST\([^)]*\).*?\nend'
    found=re.findall(pattern,v,re.S)
    assert len(found)==1 and 'CM.AcceptTrustedInvite' in found[0]
    handler='''function handlers.PARTY_INVITE_REQUEST(inviter, tank, healer, damage, isNativeRealm, allowMultipleRoles, inviterGuid)
    local function diagnostic(message)
        if HB.print then HB.print("Auto Accept: "..message) end
    end
    if issecretvalue and issecretvalue(isNativeRealm) then diagnostic("Native realm flag secret");return end
    if isNativeRealm==false then diagnostic("Native realm flag false");return end
    local CM=HB.CharacterManagement
    if not CM or not CM.AcceptTrustedInvite then diagnostic("CM unavailable");return end
    local ok,reason=CM.AcceptTrustedInvite(inviter,inviterGuid)
    diagnostic(reason or "No diagnostic returned")
    if ok and HB.PlaySound then HB.PlaySound("inviteAccept") end
end'''
    v=replace(v,found[0],handler)
    mods={toc:s.encode(),cm:c.encode(),core:v.encode()}
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
    subprocess.run(['lua5.1',str(SRC/'test_accept.lua'),str(Path(temp)/'CharacterManagement.lua'),str(Path(temp)/'Core.lua')],check=True)
report={'version':'JB26.3.15','base':'JB26.3.14','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Event-only diagnostic, trust guards unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
