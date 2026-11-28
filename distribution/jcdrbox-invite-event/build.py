from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-invite-event'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.17' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-forever-identity/output/JCDRbox_JB26.3.17_Forever_Identity_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.18_Invite_Event_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.17','## Version: JB26.3.18')
    cm='HaploBox/CharacterManagement.lua';core='HaploBox/Core.lua'
    v=original[core].decode()
    import re
    pattern=r'function handlers\.PARTY_INVITE_REQUEST\([^)]*\).*?\nend'
    found=re.findall(pattern,v,re.S)
    assert len(found)==1 and 'CM.AcceptTrustedInvite' in found[0]
    handler='''function handlers.PARTY_INVITE_REQUEST(inviter, ...)
    local function diagnostic(message)
        if HB.print then HB.print("Auto Accept: "..message) end
    end
    -- WoW API variants differ by an inserted isCrossShard flag.
    -- Only a typed player GUID from the documented payload positions is valid.
    local inviterGuid
    local types={}
    for i=1,select("#",...) do
        local value=select(i,...)
        local secret=issecretvalue and issecretvalue(value)
        types[#types+1]=tostring(i+1)..":"..(secret and "secret" or type(value))
        if i==6 or i==7 then
            if secret then diagnostic("Inviter GUID unavailable (secret event field)");return end
            if type(value)=="string" and value~="" then
                if inviterGuid and inviterGuid~=value then diagnostic("Ambiguous inviter GUID fields");return end
                inviterGuid=value
            end
        end
    end
    local CM=HB.CharacterManagement
    if not CM or not CM.AcceptTrustedInvite then diagnostic("CM unavailable");return end
    local ok,reason=CM.AcceptTrustedInvite(inviter,inviterGuid)
    if not inviterGuid and not ok then
        reason=(reason or "No diagnostic returned").." [event "..table.concat(types,",").."]"
    end
    diagnostic(reason or "No diagnostic returned")
    if ok and HB.PlaySound then HB.PlaySound("inviteAccept") end
end'''
    v=replace(v,found[0],handler)
    mods={toc:s.encode(),core:v.encode()}
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
report={'version':'JB26.3.18','base':'JB26.3.17','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Recognize both documented invite event layouts; retain CM trust guards; diagnostic event argument types; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
