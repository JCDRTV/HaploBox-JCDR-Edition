from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-auto-accept'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.13' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-team-invite/output/JCDRbox_JB26.3.13_Team_Invite_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.14_Auto_Accept_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.13','## Version: JB26.3.14')
    cm='HaploBox/CharacterManagement.lua';core='HaploBox/Core.lua'
    c=original[cm].decode()
    c+="\n-- JB26.3.14: trust only explicit registered own characters. No legacy fallback.\nlocal function acceptValue(fn,...)\n    if type(fn)~=\"function\" then return nil end\n    local ok,v=pcall(fn,...)\n    if not ok or (issecretvalue and issecretvalue(v)) then return nil end\n    return v\nend\nlocal function fullName(s)\n    if issecretvalue and issecretvalue(s) then return nil end\n    if type(s)~=\"string\" or s:find(\"[%c|]\") or not s:match(\"^%S+ %S+$\") then return nil end\n    return s:lower()\nend\nlocal function realmKey(s)\n    if issecretvalue and issecretvalue(s) then return nil end\n    if type(s)~=\"string\" or s==\"\" or s:find(\"[%c|]\") then return nil end\n    return s:lower():gsub(\"%s\",\"\")\nend\nfunction CM.TrustedInvite(inviter,inviterGuid)\n    if not HB.db or HB.db.autoAcceptInvite==false then return nil end\n    -- Fail closed if group/combat state cannot be read.\n    local grouped=acceptValue(IsInGroup)\n    local raid=acceptValue(IsInRaid)\n    local combat=acceptValue(InCombatLockdown)\n    if grouped~=false or raid~=false or combat~=false then return nil end\n    local guid=acceptValue(UnitGUID,\"player\")\n    if type(guid)~=\"string\" or guid==\"\" then return nil end\n    local own=CM.GetCharacter(guid)\n    if not own then return nil end\n    local ownName=fullName(own.name)\n    local actual=fullName(acceptValue(HB.UnitIdent,\"player\"))\n    local currentRealm=realmKey(acceptValue(GetNormalizedRealmName) or acceptValue(GetRealmName))\n    if not ownName or actual~=ownName or not currentRealm or realmKey(own.realm)~=currentRealm then return nil end\n    local name=fullName(inviter)\n    if not name or name==ownName then return nil end\n    local match\n    for _,r in ipairs(CM.GetCharacters()) do\n        if fullName(r.name)==name then\n            -- Even across realms, never silently resolve an ambiguous name.\n            if match then return nil end\n            match=r\n        end\n    end\n    if not match or match.guid==guid or match.account==own.account or realmKey(match.realm)~=currentRealm then return nil end\n    local accounts={}\n    for _,a in ipairs(CM.Accounts()) do accounts[a.id]=true end\n    if not accounts[own.account] or not accounts[match.account] then return nil end\n    if issecretvalue and issecretvalue(inviterGuid) then return nil end\n    if inviterGuid~=nil and inviterGuid~=\"\" and inviterGuid~=match.guid then return nil end\n    return match\nend\nfunction CM.AcceptTrustedInvite(inviter,inviterGuid)\n    local r=CM.TrustedInvite(inviter,inviterGuid)\n    if not r then return false end\n    local fn=AcceptGroup\n    if type(fn)~=\"function\" then return false end\n    local ok,result=pcall(fn)\n    if not ok or (issecretvalue and issecretvalue(result)) or result==false then return false end\n    return true\nend\n"
    v=original[core].decode()
    import re
    # Match the entire old handler, not a second event listener.
    pattern=r'function handlers\.PARTY_INVITE_REQUEST\([^)]*\).*?\nend'
    found=re.findall(pattern,v,re.S)
    assert len(found)==1 and 'JB26.3.13: acceptance is manual' in found[0] and 'AcceptGroup()' in found[0],found
    handler='''function handlers.PARTY_INVITE_REQUEST(inviter, tank, healer, damage, isNativeRealm, allowMultipleRoles, inviterGuid)
    -- Accept only explicit CM identities. Cross-realm and uncertain requests stay manual.
    if issecretvalue and issecretvalue(isNativeRealm) then return end
    if isNativeRealm==false then return end
    local CM=HB.CharacterManagement
    if not CM or not CM.AcceptTrustedInvite or not CM.AcceptTrustedInvite(inviter,inviterGuid) then return end
    if HB.PlaySound then HB.PlaySound("inviteAccept") end
    -- Let the native invite UI follow the actual party state; do not hide a
    -- newer invitation or dismiss a rejected request with a delayed timer.
end'''
    v=replace(v,found[0],handler)
    mods={toc:s.encode(),cm:c.encode(),core:v.encode()}
    # Ensure only the native Core handler invokes auto acceptance in this package.
    print("Replaced legacy PARTY_INVITE_REQUEST with CM trust checks")
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
report={'version':'JB26.3.14','base':'JB26.3.13','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'CM-only auto accept; unique full name, same realm, different registered account, own GUID, optional inviter GUID, solo and outside combat; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
