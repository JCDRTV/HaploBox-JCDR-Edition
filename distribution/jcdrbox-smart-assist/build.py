from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-smart-assist'
# Unpublished candidate chain: validate against previous successful immutable report.
manifest=json.loads((ROOT/'distribution/jcdrbox-macro-management/output/build-report.json').read_text())
assert manifest['version']=='JB26.3.23' and manifest['base']=='JB26.3.22'
BASE=ROOT/'distribution/jcdrbox-macro-management/output/JCDRbox_JB26.3.23_Macro_Management_TEST.zip'
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.24_Smart_Assist_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.23','## Version: JB26.3.24')
    box='HaploBox/BoxMode.lua'
    b=original[box].decode()
    # User-confirmed Forever invariant: party1 is the leader on each follower.
    # Do not modify the follow resolver, healing, buffs, or other spell bodies.
    b=replace(b,'local function buildSpell(spell,kind,profile,token)', '''-- JB26.3.24: fixed follower assist; keep historical exact bodies for ownership migration.
local function legacyAssistBody(spell,kind,token)
    if kind=="assist" then return "#showtooltip "..spell.."\\n/assist "..token.."\\n/cast "..spell end
    if kind=="boxassist" then return "#showtooltip\\n/assist "..token end
end
local function buildSpell(spell,kind,profile,token)''')
    b=replace(b,'        if profile=="on" then return head.."/assist "..token.."\\n/cast "..spell end','        if profile=="on" then return head.."/assist party1\\n/cast "..spell end')
    b=replace(b,'        return profile=="on" and ("#showtooltip\\n/assist "..token) or "#showtooltip\\n/stopmacro"','        return profile=="on" and "#showtooltip\\n/assist party1" or "#showtooltip\\n/stopmacro"')
    # Preserve the exact known historical templates without accepting custom bodies.
    b=replace(b,'    -- Old TB19.1m records may carry a stale applied/body marker.','''    if not entry.legacyBody and type(entry.spell)=="string" and (entry.kind=="assist" or entry.kind=="boxassist") then
        for i=1,4 do
            if sameBody(body,legacyAssistBody(entry.spell,entry.kind,"party"..i)) then return true end
        end
    end
    -- Old TB19.1m records may carry a stale applied/body marker.''')
    b=replace(b,'        if sameBody(current,buildSpell(spell,kind,"on","party"..i)) then canonical=true end','''        if sameBody(current,buildSpell(spell,kind,"on","party"..i)) or
           (kind=="assist" and sameBody(current,legacyAssistBody(spell,kind,"party"..i))) then canonical=true end''')
    # Existing explicitly imported HB assist profiles also use the fixed slot.
    # No other lines or unowned macros are changed.
    b=replace(b,'on=on:gsub("(/assist )party[1-4]", "%1"..leaderToken(),1)','on=on:gsub("(/assist )party[1-4]", "%1party1",1)')
    mods={toc:s.encode(),box:b.encode()}
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
    subprocess.run(['lua5.1',str(SRC/'test_assist.lua'),str(Path(temp)/'BoxMode.lua')],check=True)
report={'version':'JB26.3.24','base':'JB26.3.23','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Fixed /assist party1 for follower BOX ON; ordinary leader/off cast; no target guard; heal/buff/follow and other templates unchanged; corrected candidate only'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
