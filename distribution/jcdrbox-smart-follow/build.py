from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-smart-follow'
# Unpublished candidate chain: validate against previous successful immutable report.
manifest=json.loads((ROOT/'distribution/jcdrbox-smart-assist/output/build-report.json').read_text())
assert manifest['version']=='JB26.3.24' and manifest['base']=='JB26.3.23'
BASE=ROOT/'distribution/jcdrbox-smart-assist/output/JCDRbox_JB26.3.24_Smart_Assist_TEST.zip'
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.25_Smart_Follow_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.24','## Version: JB26.3.25')
    box='HaploBox/BoxMode.lua';core='HaploBox/Core.lua';game='HaploBox/Gameplay.lua'
    b=original[box].decode()
    start=b.index('-- Build F1\\x27s secure /follow macro from Blizzard\\x27s own role assignments.'.replace('\\x27',"'"))
    end=b.index('function HB.PrepareSmartFollow()',start)
    b=b[:start]+"-- JB26.3.25: TM roles are authoritative, independent of Blizzard role assignment.\n-- Only resolve the existing F1 macro and expected chain; never initiate following.\nfunction HB.ResolveSmartFollowUnit(u,mode)\n    local signature,_,leader=registeredParty()\n    if not signature or not u or boxValue(UnitExists,u)~=true or u==leader then return nil end\n    if mode~=\"dungeon\" then return leader end\n    local T=HB.TeamPlanner\n    if not T or not T.RoleForUnit or not T.Active or not T.Active() then return leader end\n    if T.RoleForUnit(u)==\"healer\" then return leader end\n    local healer,count=nil,0\n    for _,unit in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n        if boxValue(UnitExists,unit)==true and T.RoleForUnit(unit)==\"healer\" then\n            healer=unit;count=count+1\n        end\n    end\n    -- Preserve the existing direct fallback for missing or ambiguous healer.\n    if count~=1 or healer==u then return leader end\n    return healer\nend\nfunction HB.ExpectedTMFollowTarget(name)\n    if type(name)~=\"string\" or not safe(name) then return nil end\n    local key=norm(name)\n    if not key then return nil end\n    local found\n    for _,u in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n        if boxValue(UnitExists,u)==true and norm(boxValue(HB.UnitIdent,u))==key then\n            if found then return nil end\n            found=u\n        end\n    end\n    local target=HB.ResolveSmartFollowUnit(found,HB.db and HB.db.followMode)\n    if target then return boxValue(HB.UnitIdent,target) end\nend\nlocal function followBody()\n    local inert=\"#showtooltip\\n/stopmacro\"\n    if not HB.db or not HB.db.boxMode then return inert end\n    local target=HB.ResolveSmartFollowUnit(\"player\",HB.db.followMode)\n    if not target or not target:match(\"^party[1-4]$\") then return inert end\n    return followMacroFor(target)\nend"+'\n'+b[end:]
    # Roster/leader events also update the dedicated macro if BOX profile stayed the same.
    b=replace(b,'        HB.AutoBoxReconcile()\n        pulseCombat(true)\n        scheduleAutoBox(0.8)','        HB.AutoBoxReconcile()\n        HB.PrepareSmartFollow()\n        pulseCombat(true)\n        scheduleAutoBox(0.8)')
    b=replace(b,'C_Timer.After(delay or 0.8,function() HB.AutoBoxReconcile() end)','C_Timer.After(delay or 0.8,function()\n            HB.AutoBoxReconcile()\n            HB.PrepareSmartFollow()\n        end)')
    # Never overwrite a personally edited follow macro, even when old ownership exists.
    b=replace(b,'        if not changeMacro(FOLLOW_MACRO,body) then return false end','''        local normalized=normalizedBody(current)
        if normalized~="#showtooltip\\n/stopmacro" and
           not (normalized and (normalized:match("^#showtooltip\\n/follow party[1-4]$") or
               normalized:match("^#showtooltip\\n/follow party[1-4]\\n/run HaploBox%.SmartFollowCamera%(%)$"))) then
            notify("Smart Follow macro was modified; not overwritten.")
            return false
        end
        if not changeMacro(FOLLOW_MACRO,body) then return false end''')
    v=original[core].decode()
    start=v.index('function HB.ExpectedFollowTarget(name)')
    end=v.index('\nfunction HB.RoleOf(name)',start)
    v=v[:start]+'''function HB.ExpectedFollowTarget(name)
    if HB.ExpectedTMFollowTarget then return HB.ExpectedTMFollowTarget(name) end
end
'''+v[end:]
    # Existing D mode message path stays intact. Only trust the actual owned leader.
    # No new messages, timers or role assignments.
    g=original[game].decode()
    g=replace(g,'    if HB.AutoBoxReconcile then HB.AutoBoxReconcile() end\n    if HB.TeamPlanner and HB.TeamPlanner.ApplyOwnPlannedRole then HB.TeamPlanner.ApplyOwnPlannedRole() end','    if HB.AutoBoxReconcile then HB.AutoBoxReconcile() end\n    if HB.TeamPlanner and HB.TeamPlanner.ApplyOwnPlannedRole then HB.TeamPlanner.ApplyOwnPlannedRole() end\n    if HB.PrepareSmartFollow then HB.PrepareSmartFollow() end\n    if HB.OnFollowStateChanged then HB.OnFollowStateChanged() end')
    # Prove spell generator (including the fixed party1 assist) is byte-identical.
    for a,z in [('local function buildSpell(', 'local function desiredProfile('),('local function updateMacros(', 'HB.UpdateBoxMacros=updateMacros'),('function HB.InstallSmartFollowBinding(', 'local lastSyncReason=')]:
        old_source=original[box].decode()
        assert old_source[old_source.index(a):old_source.index(z,old_source.index(a))]==b[b.index(a):b.index(z,b.index(a))],a
    mods={toc:s.encode(),box:b.encode(),core:v.encode(),game:g.encode()}
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
    (Path(temp)/'Party.lua').write_bytes(out.read('HaploBox/Party.lua'))
    (Path(temp)/'Gameplay.lua').write_bytes(out.read('HaploBox/Gameplay.lua'))
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-party-loot/test_party_loot.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua'),str(Path(temp)/'RegisterSync.lua'),str(Path(temp)/'ControlBar.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-auto-roles/test_roles.lua'),str(Path(temp)/'TeamPlanner.lua'),str(Path(temp)/'Core.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
    (Path(temp)/'BoxMode.lua').write_bytes(out.read('HaploBox/BoxMode.lua'))
    (Path(temp)/'Gameplay.lua').write_bytes(out.read('HaploBox/Gameplay.lua'))
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-auto-box-mode/test_box.lua'),str(Path(temp)/'BoxMode.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
    (Path(temp)/'MacroLibrary.lua').write_bytes(out.read('HaploBox/MacroLibrary.lua'))
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-macro-management/test_macro.lua'),str(Path(temp)/'MacroLibrary.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-smart-assist/test_assist.lua'),str(Path(temp)/'BoxMode.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_follow.lua'),str(Path(temp)/'BoxMode.lua'),str(Path(temp)/'Core.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
report={'version':'JB26.3.25','base':'JB26.3.24','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Smart Follow uses live TM GUID healer roles, direct fallback, same expected chain, refresh on existing register and party events; spell templates and F1 binding unchanged; candidate only'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
