from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-auto-roles'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.20' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-party-loot/output/JCDRbox_JB26.3.20_Party_Loot_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.21_Auto_Roles_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.20','## Version: JB26.3.21')
    tm='HaploBox/TeamPlanner.lua';core='HaploBox/Core.lua'
    party='HaploBox/Party.lua';game='HaploBox/Gameplay.lua'
    t=original[tm].decode()+"\n-- JB26.3.21: the active saved team is the role source. Only assign our own native role.\nlocal nativeRoles={tank=\"TANK\",healer=\"HEALER\",dps=\"DAMAGER\"}\nlocal function roleAPI(fn,...)\n    if type(fn)~=\"function\" then return nil end\n    local ok,v=pcall(fn,...)\n    if not ok or (issecretvalue and issecretvalue(v)) then return nil end\n    return v\nend\nlocal function liveGuid(u)\n    local g=roleAPI(UnitGUID,u)\n    if type(g)==\"string\" and g~=\"\" then return g end\nend\nlocal function roleForGuid(team,g)\n    if not team or not g then return nil end\n    for i=1,5 do\n        local s=team.slots[i]\n        if s and s.guid==g and nativeRoles[s.role] then\n            local r=CM.GetCharacter(g)\n            if r and r.account==s.account then return s.role end\n        end\n    end\nend\nfunction T.RoleForUnit(u)\n    return roleForGuid(T.Active(),liveGuid(u))\nend\nfunction T.RoleForName(name)\n    if type(name)~=\"string\" or (issecretvalue and issecretvalue(name)) then return nil end\n    local team=T.Active()\n    if not team then return nil end\n    local key=name:lower()\n    local found,matched=nil,false\n    for _,u in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n        local n=roleAPI(HB.UnitIdent,u)\n        if roleAPI(UnitExists,u)==true and type(n)==\"string\" and n:lower()==key then\n            if matched then return nil end\n            matched=true;found=roleForGuid(team,liveGuid(u))\n        end\n    end\n    return found\nend\nfunction T.LiveHealer()\n    local team=T.Active()\n    if not team then return nil end\n    for i=1,5 do\n        local s=team.slots[i]\n        if s and s.role==\"healer\" then\n            for _,u in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n                if roleAPI(UnitExists,u)==true and liveGuid(u)==s.guid and roleForGuid(team,s.guid)==\"healer\" then\n                    return roleAPI(HB.UnitIdent,u)\n                end\n            end\n        end\n    end\nend\nlocal lastRoleAttempt\nfunction T.ApplyOwnPlannedRole()\n    if roleAPI(IsInGroup)~=true or roleAPI(IsInRaid)~=false then\n        lastRoleAttempt=nil;return false\n    end\n    local team=T.Active()\n    local g=liveGuid(\"player\")\n    local role=roleForGuid(team,g)\n    if not role then lastRoleAttempt=nil;return false end\n    if roleAPI(InCombatLockdown)~=false then return false end\n    local count=roleAPI(GetNumGroupMembers)\n    if type(count)~=\"number\" or count<2 or count>5 then return false end\n    local ids,seen={},{}\n    for _,u in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n        if roleAPI(UnitExists,u)==true then\n            local guid=liveGuid(u)\n            if not guid or seen[guid] then return false end\n            seen[guid]=true;ids[#ids+1]=guid\n        end\n    end\n    if #ids~=count or not seen[g] then return false end\n    table.sort(ids)\n    local desired=nativeRoles[role]\n    local key=team.id..\"|\"..g..\"|\"..desired..\"|\"..table.concat(ids,\";\")\n    local current=roleAPI(UnitGroupRolesAssigned,\"player\")\n    if current==desired then lastRoleAttempt=nil;return true end\n    if lastRoleAttempt==key then return false end\n    lastRoleAttempt=key -- prevent roster-event loops and repeated failed API calls\n    if type(UnitSetRole)~=\"function\" then\n        if HB.print then HB.print(\"TM role \"..desired..\" saved; WoW role API unavailable.\") end\n        return false\n    end\n    local ok,result=pcall(UnitSetRole,\"player\",desired)\n    if not ok or (issecretvalue and issecretvalue(result)) or result==false then\n        if HB.print then HB.print(\"TM role \"..desired..\" saved; WoW rejected role update.\") end\n        return false\n    end\n    return true -- request sent; actual native icon still read from Blizzard\nend\n"
    v=original[core].decode()
    v=replace(v,'function HB.RoleOf(name)\n','''function HB.RoleOf(name)
    local T=HB.TeamPlanner
    if T and T.Active and T.Active() then return T.RoleForName(name) end
''')
    v=replace(v,'function HB.MyRole() return HB.RoleOf(HB.UnitIdent("player")) end','''function HB.MyRole()
    local T=HB.TeamPlanner
    if T and T.Active and T.Active() then return T.RoleForUnit("player") end
    return HB.RoleOf(HB.UnitIdent("player"))
end''')
    v=replace(v,'function HB.Healer()\n','''function HB.Healer()
    local T=HB.TeamPlanner
    if T and T.Active and T.Active() then return T.LiveHealer() end
''')
    # Core's roster event gives immediate application; existing delayed Gameplay
    # callback covers clients whose roster is not yet complete.
    v=replace(v,'\tif HB.CheckAutoLoot then HB.CheckAutoLoot() end','\tif HB.CheckAutoLoot then HB.CheckAutoLoot() end\n    if HB.TeamPlanner and HB.TeamPlanner.ApplyOwnPlannedRole then HB.TeamPlanner.ApplyOwnPlannedRole() end')
    g=original[game].decode()
    g=replace(g,'function HB.OnRegisterPartyChanged()\n','''function HB.OnRegisterPartyChanged()
    if HB.TeamPlanner and HB.TeamPlanner.ApplyOwnPlannedRole then HB.TeamPlanner.ApplyOwnPlannedRole() end
''')
    g=replace(g,'C_Timer.After(1.4, function() HB.CheckAutoLoot() end)','''C_Timer.After(1.4, function()
            HB.CheckAutoLoot()
            if HB.TeamPlanner and HB.TeamPlanner.ApplyOwnPlannedRole then HB.TeamPlanner.ApplyOwnPlannedRole() end
        end)''')
    g=replace(g,'    elseif event == "PLAYER_REGEN_ENABLED" or event == "PARTY_LEADER_CHANGED" then\n        HB.CheckAutoLoot()','''    elseif event == "PLAYER_REGEN_ENABLED" or event == "PARTY_LEADER_CHANGED" then
        HB.CheckAutoLoot()
        if HB.TeamPlanner and HB.TeamPlanner.ApplyOwnPlannedRole then HB.TeamPlanner.ApplyOwnPlannedRole() end''')
    p=original[party].decode()
    # Existing role icon keeps reporting the Blizzard role when assigned.
    # If the native API has not assigned it yet, show a distinct TM fallback.
    p=replace(p,'        r.healerMark:SetShown(not roleVisible and HB.RoleOf(r.name)=="healer")','''        local planned=HB.TeamPlanner and HB.TeamPlanner.RoleForUnit and HB.TeamPlanner.RoleForUnit(r.unit)
        local plannedLabel=planned=="tank" and "T" or planned=="healer" and "H" or planned=="dps" and "D" or nil
        local fallback=plannedLabel and (not roleVisible or assigned~=(planned=="dps" and "DAMAGER" or planned:upper()))
        r.healerMark:SetShown(not roleVisible and not fallback and HB.RoleOf(r.name)=="healer")''')
    p=replace(p,'            if ok and type(a)=="number" and type(b)=="number" and type(c)=="number" and type(d)=="number" then','''            if fallback then
                r.blizzardRoleIcon:Hide()
                r.blizzardRoleFallback:SetText(plannedLabel.."*")
                r.blizzardRoleFallback:SetShown(true) -- * means TM role; native not confirmed
            elseif ok and type(a)=="number" and type(b)=="number" and type(c)=="number" and type(d)=="number" then''')
    mods={toc:s.encode(),tm:t.encode(),core:v.encode(),party:p.encode(),game:g.encode()}
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
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-legacy-accept/test_accept.lua'),str(Path(temp)/'CharacterManagement.lua'),str(Path(temp)/'Core.lua')],check=True)
    (Path(temp)/'ControlBar.lua').write_bytes(out.read('HaploBox/ControlBar.lua'))
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-party-loot/test_party_loot.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua'),str(Path(temp)/'RegisterSync.lua'),str(Path(temp)/'ControlBar.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_roles.lua'),str(Path(temp)/'TeamPlanner.lua'),str(Path(temp)/'Core.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
report={'version':'JB26.3.21','base':'JB26.3.20','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'TM role source, own native role on roster/register changes, distinct planned fallback; candidate only, ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
