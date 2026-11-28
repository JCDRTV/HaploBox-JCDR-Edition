from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-team-invite'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.12' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-tm-controls/output/JCDRbox_JB26.3.12_TM_Controls_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.13_Team_Invite_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.12','## Version: JB26.3.13')
    c=original[ui].decode()
    c=replace(c,'    local previewNote=text(panel,"Preview only - live party and invites unchanged.",0,-308,660,muted)','''    local inviteBtn=button(panel,"Invite team",0,-301,168,function()
        if dirty then notice("Save or discard team changes before inviting.");return end
        local ok,message=T.InviteActive()
        notice(message)
    end)
    local previewNote=text(panel,"Invites use the saved active team.",180,-308,480,muted)''')
    c=replace(c,'        place(previewNote,panel,0,footer-7)','        place(inviteBtn,panel,0,footer)\n        place(previewNote,panel,180,footer-7)')
    c=replace(c,'        discard:SetEnabled(dirty)','        discard:SetEnabled(dirty)\n        inviteBtn:SetEnabled(can and active~=nil and not dirty)')
    tm='HaploBox/TeamPlanner.lua'
    t=original[tm].decode()
    t+="\n-- One explicit click; no timers, roster mutation, legacy-name fallback or auto-accept.\nlocal invitePending={}\nlocal function inviteSafe(v)\n    if issecretvalue and issecretvalue(v) then return nil end\n    return v\nend\nlocal function inviteName(name)\n    if type(name)~=\"string\" or name==\"\" or name:find(\"[%c|]\") then return nil end\n    -- Forever's two-name identities must not be reduced to the first name.\n    if not name:match(\"^%S+%s+%S+\") then return nil end\n    return name\nend\nfunction T.InvitePlan()\n    local ok,allowed=pcall(CM.CanEdit)\n    if not ok or not allowed then return nil,\"Only the actual party leader can invite outside combat.\" end\n    local team=T.Active()\n    if not team then return nil,\"Select and save a team in Management first.\" end\n    local valid,err=T.Validate(team.slots)\n    if not valid then return nil,err end\n    local rosterOK,roster,why=pcall(CM.Snapshot,false)\n    if not rosterOK or not roster or type(roster.rows)~=\"table\" then return nil,why or \"Party roster unavailable; try again.\" end\n    local guidOK,me=pcall(UnitGUID,\"player\")\n    me=guidOK and inviteSafe(me) or nil\n    if type(me)~=\"string\" or me==\"\" then return nil,\"Your character identity is unavailable.\" end\n    local planned,present={},{}\n    for _,s in pairs(team.slots) do planned[s.guid]=s end\n    if not planned[me] then return nil,\"Your character is not in the active team.\" end\n    for _,r in ipairs(roster.rows) do\n        if not planned[r.guid] then return nil,\"Party contains a character outside the active team. No invitations sent.\" end\n        present[r.guid]=true\n        invitePending[r.guid]=nil\n    end\n    if not present[me] then return nil,\"Party roster unavailable; try again.\" end\n    local knownNames={}\n    for _,r in ipairs(CM.GetCharacters()) do\n        local n=inviteName(r.name)\n        if n then\n            local k=n:lower()\n            knownNames[k]=(knownNames[k] or 0)+1\n        end\n    end\n    local targets={}\n    for i=1,5 do\n        local s=team.slots[i]\n        if s and not present[s.guid] then\n            local r=CM.GetCharacter(s.guid)\n            local name=r and inviteName(r.name)\n            if not name or knownNames[name:lower()]~=1 then return nil,\"Missing or ambiguous full character name at POS \"..i..\".\" end\n            targets[#targets+1]={guid=s.guid,name=name}\n        end\n    end\n    return targets,team.name\nend\nfunction T.InviteActive()\n    local targets,message=T.InvitePlan()\n    if not targets then return false,message end\n    if #targets==0 then return true,\"All members of \"..message..\" are already in the party.\" end\n    local fn=C_PartyInfo and C_PartyInfo.InviteUnit\n    if type(fn)~=\"function\" then fn=InviteUnit end\n    if type(fn)~=\"function\" then return false,\"WoW invite API unavailable.\" end\n    local now=GetTime and GetTime()\n    local sent,skipped,failed=0,0,{}\n    for _,r in ipairs(targets) do\n        if type(now)==\"number\" and invitePending[r.guid] and now-invitePending[r.guid]<20 then\n            skipped=skipped+1\n        else\n            local ok,result=pcall(fn,r.name)\n            if ok and inviteSafe(result)~=false then\n                sent=sent+1\n                if type(now)==\"number\" then invitePending[r.guid]=now end\n            else\n                failed[#failed+1]=r.name\n            end\n        end\n    end\n    local summary=message..\": \"..sent..\" invite request(s) sent.\"\n    if skipped>0 then summary=summary..\" \"..skipped..\" recently requested; wait 20 seconds before retrying.\" end\n    if #failed>0 then summary=summary..\" API rejected: \"..table.concat(failed,\", \")..\".\" end\n    return #failed==0,summary\nend\n"
    mods={toc:s.encode(),ui:c.encode(),tm:t.encode()}
    # Replace the legacy entry point itself: Quick Menu, slash and other callers
    # now use only the saved TeamPlanner register, never a legacy roster.
    import re
    definitions=[]
    for n,b in original.items():
        if n.endswith('.lua'):
            content=b.decode('utf-8-sig',errors='strict')
            if re.search(r'function\s+HB\.InviteTeam\s*\(\s*\)',content):
                definitions.append(n)
    assert len(definitions)==1,definitions
    old_invite=definitions[0]
    v=original[old_invite].decode()
    match=re.search(r'function\s+HB\.InviteTeam\s*\(\s*\)',v)
    anchor=match.group(0)
    v=replace(v,anchor,'''function HB.InviteTeam()
    if not HB.TeamPlanner or not HB.TeamPlanner.InviteActive then
        if HB.print then HB.print("Team register unavailable.") end
        return false
    end
    local ok,message=HB.TeamPlanner.InviteActive()
    if HB.print then HB.print(message) end
    return ok,message
end
local function legacyInviteTeam()''')
    mods[old_invite]=v.encode()
    # Do not let the pre-register automatic acceptance path accept invites
    # during this phase. The new trusted acceptance is a separate release.
    core='HaploBox/Core.lua'
    v=mods.get(core,original[core]).decode()
    pattern=r'function handlers\.PARTY_INVITE_REQUEST\([^)]*\)'
    found=re.findall(pattern,v)
    assert len(found)==1,found
    v=replace(v,found[0],found[0]+'\n    -- JB26.3.13: acceptance is manual until CM-based Auto Accept is implemented.\n    if HB.TeamPlanner then return end')
    mods[core]=v.encode()
    print("Routed legacy invite entry point:",old_invite)
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
    subprocess.run(['lua5.1',str(SRC/'test_tm_ui.lua'),str(Path(temp)/'TeamPlannerUI.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_invite.lua'),str(Path(temp)/'TeamPlanner.lua')],check=True)
report={'version':'JB26.3.13','base':'JB26.3.12','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Active team invite from TM and Quick Menu; full names and GUID roster guards; legacy automatic acceptance paused; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
