from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-auto-box-mode'
# Unpublished candidate chain: validate against previous successful immutable report.
manifest=json.loads((ROOT/'distribution/jcdrbox-auto-roles/output/build-report.json').read_text())
assert manifest['version']=='JB26.3.21' and manifest['base']=='JB26.3.20'
BASE=ROOT/'distribution/jcdrbox-auto-roles/output/JCDRbox_JB26.3.21_Auto_Roles_TEST.zip'
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.22_Auto_Box_Mode_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.21','## Version: JB26.3.22')
    box='HaploBox/BoxMode.lua';game='HaploBox/Gameplay.lua';control='HaploBox/ControlBar.lua'
    b=original[box].decode()
    def section(s,a,z,new):
        assert s.count(a)==1 and s.count(z)==1,(a,z)
        start=s.index(a);end=s.index(z,start)
        return s[:start]+new+'\n'+s[end:]
    b=section(b,'local function leaderToken()','local function buildSpell(',"-- JB26.3.22: only the explicit CM register can authorize BOX targeting.\nlocal function boxValue(fn,...)\n    if type(fn)~=\"function\" then return nil end\n    local ok,v=pcall(fn,...)\n    if not ok or not safe(v) then return nil end\n    return v\nend\nlocal function actualLeaderUnit()\n    local leader\n    for _,u in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n        if boxValue(UnitExists,u)==true then\n            local v=boxValue(UnitIsGroupLeader,u)\n            if v==nil then v=boxValue(UnitIsPartyLeader,u) end\n            if v==true or v==1 then\n                if leader then return nil end\n                leader=u\n            end\n        end\n    end\n    return leader\nend\nlocal function registeredParty()\n    if boxValue(IsInGroup)~=true then return nil,\"solo\" end\n    if boxValue(IsInRaid)~=false then return nil,\"raid\" end\n    -- Do not enable BOX in an instance-category group (e.g. battleground).\n    if LE_PARTY_CATEGORY_INSTANCE and boxValue(IsInGroup,LE_PARTY_CATEGORY_INSTANCE)==true then return nil,\"instance group\" end\n    local n=boxValue(GetNumGroupMembers)\n    if type(n)~=\"number\" or n<2 or n>5 then return nil,\"pending roster\" end\n    local CM=HB.CharacterManagement\n    if not CM or not CM.GetCharacter or not CM.Accounts then return nil,\"CM unavailable\" end\n    local accounts={}\n    for _,a in ipairs(CM.Accounts()) do accounts[a.id]=true end\n    local ids,seen,used={}, {}, {}\n    for _,u in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n        if boxValue(UnitExists,u)==true then\n            local g=boxValue(UnitGUID,u)\n            if type(g)~=\"string\" or g==\"\" or seen[g] then return nil,\"pending roster\" end\n            local r=CM.GetCharacter(g)\n            if not r or not accounts[r.account] or used[r.account] then return nil,\"untrusted member\" end\n            seen[g]=true;used[r.account]=true;ids[#ids+1]=g\n        end\n    end\n    if #ids~=n then return nil,\"pending roster\" end\n    local leader=actualLeaderUnit()\n    if not leader then return nil,\"pending leader\" end\n    table.sort(ids)\n    return table.concat(ids,\";\"),\"ready\",leader\nend\nlocal function leaderToken()\n    local u=actualLeaderUnit()\n    return type(u)==\"string\" and u:match(\"^party[1-4]$\") and u or \"party1\"\nend")
    b=section(b,'local function desiredProfile(enabled)','local function profileKey(enabled)',"local function desiredProfile(enabled)\n    if not enabled then return \"off\" end\n    local signature,_,u=registeredParty()\n    if not signature then return \"off\" end\n    if u==\"player\" then return \"leader\" end\n    if type(u)==\"string\" and u:match(\"^party[1-4]$\") then return \"on\" end\n    return \"off\"\nend")
    b=section(b,'local function ack(code)','local function setCombat(name,value)',"local lastSyncReason=\"not started\"\nlocal manualOffRoster,lastAttempt\nlocal function readySignature()\n    return registeredParty()\nend\nlocal function localApply(enabled)\n    if enabled and not readySignature() then return false end\n    if boxValue(InCombatLockdown)~=false then\n        pendingMode=enabled\n        return false\n    end\n    local ok,err=updateMacros(enabled)\n    if not ok then\n        validatedMode=nil;validatedProfile=nil\n        lastSyncReason=tostring(err);HB.boxSyncError=true\n        notify(\"BOX switch cancelled: \"..tostring(err));refresh()\n        return false\n    end\n    HB.db.boxMode=enabled\n    validatedMode=enabled\n    validatedProfile=profileKey(enabled)\n    lastSyncReason=enabled and \"local ON verified\" or \"local OFF verified\"\n    HB.boxSyncError=false;pendingMode=nil\n    if not HB.PrepareSmartFollow() then\n        lastSyncReason=\"Smart Follow macro not verified\"\n        HB.boxSyncError=true;refresh();return false\n    end\n    refresh()\n    return true\nend\nfunction HB.AutoBoxReconcile(force)\n    if not HB.db then return false end\n    local signature,state=readySignature()\n    if manualOffRoster and manualOffRoster~=signature then manualOffRoster=nil end\n    local wanted=signature~=nil and manualOffRoster~=signature\n    local profile=profileKey(wanted)\n    if boxValue(InCombatLockdown)~=false then\n        if validatedMode~=wanted or validatedProfile~=profile then\n            pendingMode=wanted\n            lastSyncReason=\"pending combat exit: \"..(wanted and \"ON\" or \"OFF\")\n        end\n        return false\n    end\n    pendingMode=nil\n    local key=tostring(signature)..\"|\"..tostring(state)..\"|\"..profile\n    if not force and validatedMode==wanted and validatedProfile==profile and HB.db.boxMode==wanted and not HB.boxSyncError then\n        lastAttempt=nil;return true\n    end\n    if not force and lastAttempt==key then return false end\n    lastAttempt=key\n    local ok=localApply(wanted)\n    if ok then\n        lastAttempt=nil\n        lastSyncReason=(wanted and \"CM party: ON\" or \"BOX OFF: \"..(manualOffRoster and \"manual override\" or state))\n    end\n    return ok\nend\nfunction HB.SetBoxMode(enabled)\n    if not HB.db then return false end\n    local signature=readySignature()\n    if enabled and not signature then notify(\"BOX ON requires a party of registered own characters.\");return false end\n    if not enabled then manualOffRoster=signature else manualOffRoster=nil end\n    lastAttempt=nil\n    return HB.AutoBoxReconcile(true)\nend\nfunction HB.LocalBoxOff()\n    return HB.SetBoxMode(false)\nend\nlocal function scheduleAutoBox(delay)\n    if C_Timer and C_Timer.After then\n        C_Timer.After(delay or 0.8,function() HB.AutoBoxReconcile() end)\n    end\nend\nfunction HB.RefreshBoxSync()\n    lastAttempt=nil\n    return HB.AutoBoxReconcile(true)\nend\nfunction HB.OnBoxMessage(sender,code,arg)\n    -- Legacy Z requests/ACKs are not authoritative. Every client applies its\n    -- own CM-verified live roster; remote messages cannot switch local macros.\nend\n")
    b=replace(b,'        autoTeamKey, autoTeamDone=nil, false\n        requestKey=nil;requestSerial=requestSerial+1','        manualOffRoster,lastAttempt=nil,nil')
    start=b.index('    elseif event=="PLAYER_REGEN_ENABLED" then',b.index('e:SetScript("OnEvent",HB.Diag.WrapEvent("BoxMode event"'))
    end=b.index('\n-- Diagnostic does not change settings or macros.',start)
    b=b[:start]+"    elseif event==\"PLAYER_REGEN_ENABLED\" then\n        -- Recompute from live roster, never replay a stale queued ON.\n        HB.AutoBoxReconcile(true)\n        if pendingFollow then HB.PrepareSmartFollow() end\n        pulseCombat(true)\n    elseif event==\"PLAYER_REGEN_DISABLED\" then\n        pulseCombat(true)\n    elseif event==\"PLAYER_ENTERING_WORLD\" or event==\"GROUP_ROSTER_UPDATE\" or event==\"PARTY_LEADER_CHANGED\" or event==\"UNIT_CONNECTION\" then\n        HB.AutoBoxReconcile()\n        pulseCombat(true)\n        scheduleAutoBox(0.8)\n    else\n        HB.PrepareSmartFollow()\n    end\nend))"+'\n'+b[end:]
    # At login do not pretend OFF if owned macro restore failed.
    b=replace(b,'        HB.db.boxMode=false\n        pendingMode=nil\n        validatedMode=nil','        pendingMode=nil\n        validatedMode=nil')
    b=replace(b,'            validatedMode=false\n            validatedProfile=profileKey(false)','            HB.db.boxMode=false\n            validatedMode=false\n            validatedProfile=profileKey(false)')
    b=replace(b,'    local team=HB.TeamManagement and HB.TeamManagement.GetActiveTeam()\n','')
    start=b.index('    if not team then return end',b.index('function HB.BoxSyncStatus()'))
    end=b.index('\nend',start)
    b=b[:start]+'    notify("Trust source: Character Management; mode verified locally. Manual OFF lasts for the same roster.")'+b[end:]
    g=original[game].decode()
    g=replace(g,'function HB.OnRegisterPartyChanged()\n','function HB.OnRegisterPartyChanged()\n    if HB.AutoBoxReconcile then HB.AutoBoxReconcile() end\n')
    c=original[control].decode()
    c=replace(c,'    stateButton(19,HB.db.boxMode and "ON" or "OFF",HB.db.boxMode and GREEN or RED)','    stateButton(19,HB.boxSyncError and "CHECK" or HB.db.boxMode and "ON" or "OFF",HB.boxSyncError and GOLD or HB.db.boxMode and GREEN or RED)')
    mods={toc:s.encode(),box:b.encode(),game:g.encode(),control:c.encode()}
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
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-party-loot/test_party_loot.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua'),str(Path(temp)/'RegisterSync.lua'),str(Path(temp)/'ControlBar.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-auto-roles/test_roles.lua'),str(Path(temp)/'TeamPlanner.lua'),str(Path(temp)/'Core.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_box.lua'),str(Path(temp)/'BoxMode.lua'),str(Path(temp)/'Gameplay.lua')],check=True)
report={'version':'JB26.3.22','base':'JB26.3.21','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'CM-only automatic local BOX mode; normal OFF in solo/guest/raid, combat defer, local manual override, legacy remote switching retired; candidate only'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
