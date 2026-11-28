from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-legacy-accept'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.17' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-forever-identity/output/JCDRbox_JB26.3.17_Forever_Identity_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.19_Legacy_Accept_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.17','## Version: JB26.3.19')
    cm='HaploBox/CharacterManagement.lua';core='HaploBox/Core.lua'
    c=original[cm].decode()
    start=c.index('function CM.TrustedInvite(')
    stop=c.index('function CM.AcceptTrustedInvite(',start)
    c=c[:start]+"function CM.TrustedInvite(inviter)\n    if not HB.db or HB.db.autoAcceptInvite==false then return nil,\"Auto Accept disabled\" end\n    if acceptValue(IsInGroup)~=false or acceptValue(IsInRaid)~=false or acceptValue(InCombatLockdown)~=false then\n        return nil,\"Not solo or outside combat\"\n    end\n    local guid=acceptValue(UnitGUID,\"player\")\n    if type(guid)~=\"string\" or guid==\"\" then return nil,\"Own GUID unavailable\" end\n    local own=CM.GetCharacter(guid)\n    if not own then return nil,\"Own character not registered\" end\n    local ownName=fullName(own.name)\n    if not ownName or fullName(acceptValue(HB.UnitIdent,\"player\"))~=ownName then return nil,\"Own name mismatch\" end\n    local name=fullName(inviter)\n    if not name or name==ownName then return nil,\"Invalid inviter full name\" end\n    local match\n    for _,r in ipairs(CM.GetCharacters()) do\n        if fullName(r.name)==name then\n            if match then return nil,\"Ambiguous registered name\" end\n            match=r\n        end\n    end\n    if not match or match.guid==guid or match.account==own.account then return nil,\"Inviter not a registered other account\" end\n    local accounts={}\n    for _,a in ipairs(CM.Accounts()) do accounts[a.id]=true end\n    if not accounts[own.account] or not accounts[match.account] then return nil,\"Unregistered account\" end\n    return match\nend\n"+c[stop:]
    v=original[core].decode()
    import re
    found=re.findall(r'function handlers\.PARTY_INVITE_REQUEST\([^)]*\).*?\nend',v,re.S)
    assert len(found)==1 and 'CM.AcceptTrustedInvite' in found[0]
    handler='''function handlers.PARTY_INVITE_REQUEST(inviter)
    local CM=HB.CharacterManagement
    if not CM or not CM.AcceptTrustedInvite then return end
    local ok,reason=CM.AcceptTrustedInvite(inviter)
    if not ok then
        if HB.print then HB.print("Auto Accept: "..(reason or "manual invitation")) end
        return
    end
    if HB.PlaySound then HB.PlaySound("inviteAccept") end
    -- Original working popup cleanup, only after the client joined.
    C_Timer.After(0.1,function()
        if IsInGroup() then
            StaticPopup_Hide("PARTY_INVITE")
            StaticPopup_Hide("PARTY_INVITE_XREALM")
        end
    end)
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
    (Path(temp)/'Core.lua').write_bytes(out.read('HaploBox/Core.lua'))
    subprocess.run(['lua5.1',str(SRC/'test_accept.lua'),str(Path(temp)/'CharacterManagement.lua'),str(Path(temp)/'Core.lua')],check=True)
report={'version':'JB26.3.19','base':'JB26.3.17','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Original name-only invite event with unique registered full name and distinct CM account; no realm or event GUID dependency; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
