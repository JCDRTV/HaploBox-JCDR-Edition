from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-party-loot'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.19' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-legacy-accept/output/JCDRbox_JB26.3.19_Legacy_Accept_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.20_Party_Loot_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/TeamPlannerUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.19','## Version: JB26.3.20')
    # Use the exact inspected immutable package, not historical source files.
    party='HaploBox/Party.lua';game='HaploBox/Gameplay.lua';sync='HaploBox/RegisterSync.lua'
    control='HaploBox/ControlBar.lua'
    for n in (party,game,sync,control):
        assert original[n]==(SRC/'inspection'/n).read_bytes(),n
    p=original[party].decode()
    start=p.index('local function visibleTeamOrder()')
    end=p.index('\n-- Shared roster resolver',start)
    p=p[:start]+"local function visibleTeamOrder()\n    -- Display live units only. Position belongs to GUID, never a nickname or party token.\n    local present={}\n    local function add(u)\n        if UnitExists and UnitExists(u) then\n            local name=HB.UnitIdent(u)\n            local ok,guid=pcall(UnitGUID,u)\n            if not ok or (issecretvalue and issecretvalue(guid)) or type(guid)~=\"string\" then guid=nil end\n            if type(name)==\"string\" and not (issecretvalue and issecretvalue(name)) then\n                present[#present+1]={name=name,guid=guid,index=#present+1}\n            end\n        end\n    end\n    add(\"player\")\n    if IsInGroup() then\n        if IsInRaid() then\n            -- Preserve the existing raid presentation, excluding duplicate player.\n            for i=1,(GetNumGroupMembers() or 0) do\n                local u=\"raid\"..i\n                if not (UnitIsUnit and UnitIsUnit(u,\"player\")) then add(u) end\n            end\n        else\n            for i=1,4 do add(\"party\"..i) end\n        end\n    end\n    local rank={}\n    local team=HB.TeamPlanner and HB.TeamPlanner.Active()\n    if team and not IsInRaid() then\n        for i=1,5 do\n            local s=team.slots[i]\n            if s and s.guid then rank[s.guid]=i end\n        end\n    end\n    table.sort(present,function(a,b)\n        local ar,br=rank[a.guid] or 6,rank[b.guid] or 6\n        if ar~=br then return ar<br end\n        -- Stable across clients, including guests; no actual leader promotion.\n        if a.name~=b.name then return a.name<b.name end\n        if a.guid and b.guid and a.guid~=b.guid then return a.guid<b.guid end\n        return a.index<b.index\n    end)\n    local names={}\n    for _,r in ipairs(present) do names[#names+1]=r.name end\n    return names\nend"+'\n'+p[end:]
    p=replace(p,'\tif not key then return nil end\n\tif HB.Norm(HB.UnitIdent("player"))', '\tif not key then return nil end\n'+"    -- Prefer exact live names for row binding. Legacy aliases are only a fallback\n    -- for callers outside the visible roster (e.g. historic follow messages).\n    local function exact(u)\n        return UnitExists(u) and HB.Norm(HB.UnitIdent(u))==key\n    end\n    if exact(\"player\") then return \"player\" end\n    if IsInGroup() then\n        if IsInRaid() then\n            for i=1,GetNumGroupMembers() do local u=\"raid\"..i;if exact(u) then return u end end\n        else\n            for i=1,4 do local u=\"party\"..i;if exact(u) then return u end end\n        end\n    end\n"+'\tif HB.Norm(HB.UnitIdent("player"))')
    g=original[game].decode()
    start=g.index('local lastLootGoal, lastLootAttempt')
    end=g.index('\nlocal ev = CreateFrame("Frame")',start)
    g=g[:start]+"local lastLootGoal,lastLootAttempt,lastLootRoster=nil,0,nil\nlocal function lootValue(fn,...)\n    if type(fn)~=\"function\" then return nil end\n    local ok,v=pcall(fn,...)\n    if not ok or (issecretvalue and issecretvalue(v)) then return nil end\n    return v\nend\nlocal function lootMethod()\n    local api=C_PartyInfo and C_PartyInfo.GetLootMethod or GetLootMethod\n    local name=lootValue(api)\n    if type(name)==\"string\" then return name:lower() end\n    if name~=nil and Enum and Enum.LootMethod then\n        if name==Enum.LootMethod.Freeforall then return \"freeforall\" end\n        if name==Enum.LootMethod.Group then return \"group\" end\n    end\n    return nil\nend\nHB.LootMethodName=lootMethod\nlocal function resetLootAttempt()\n    lastLootGoal,lastLootAttempt,lastLootRoster=nil,0,nil\nend\nfunction HB.CheckAutoLoot()\n    if not HB.db or not HB.db.autoFFA or lootValue(IsInGroup)~=true or lootValue(IsInRaid)~=false then\n        resetLootAttempt();return\n    end\n    -- Actual Blizzard leader only; do not rely on cached leader or POS1.\n    local leader=lootValue(UnitIsGroupLeader,\"player\")\n    if leader==nil then leader=lootValue(UnitIsPartyLeader,\"player\") end\n    if leader~=true and leader~=1 then resetLootAttempt();return end\n    if lootValue(InCombatLockdown)~=false then return end\n    local CM=HB.CharacterManagement\n    if not CM then return end\n    local n=lootValue(GetNumGroupMembers)\n    if type(n)~=\"number\" or n<2 or n>5 then return end\n    local accounts={}\n    for _,a in ipairs(CM.Accounts()) do accounts[a.id]=true end\n    local seen,used,ids={}, {}, {}\n    local outsider=false\n    for _,u in ipairs({\"player\",\"party1\",\"party2\",\"party3\",\"party4\"}) do\n        if lootValue(UnitExists,u)==true then\n            local g=lootValue(UnitGUID,u)\n            if type(g)~=\"string\" or g==\"\" or seen[g] then return end\n            seen[g]=true;ids[#ids+1]=g\n            local r=CM.GetCharacter(g)\n            if not r or not accounts[r.account] or used[r.account] then outsider=true\n            else used[r.account]=true end\n        end\n    end\n    if #ids~=n then return end\n    table.sort(ids)\n    local roster=table.concat(ids,\";\")\n    local goal=outsider and \"group\" or \"freeforall\"\n    local current=lootMethod()\n    if current==goal then resetLootAttempt();return end\n    local now=lootValue(GetTime) or 0\n    if lastLootGoal==goal and lastLootRoster==roster and now-lastLootAttempt<3 then return end\n    lastLootGoal,lastLootAttempt,lastLootRoster=goal,now,roster\n    local set=C_PartyInfo and C_PartyInfo.SetLootMethod or SetLootMethod\n    if type(set)~=\"function\" then return end\n    local ok,result=pcall(set,goal)\n    if not ok or result==false then\n        local value=Enum and Enum.LootMethod and (goal==\"group\" and Enum.LootMethod.Group or Enum.LootMethod.Freeforall)\n        if value~=nil then ok,result=pcall(set,value) end\n    end\n    if not ok or result==false then notice(\"Could not set loot to \"..goal) end\n    if HB.RefreshControls then HB.RefreshControls() end\nend\n-- Called only after a committed local or received register change.\nfunction HB.OnRegisterPartyChanged()\n    if HB.LayoutPartyFrame then HB.LayoutPartyFrame() end\n    HB.CheckAutoLoot()\nend\n"+g[end:]
    g=replace(g,'    elseif event == "PARTY_LOOT_METHOD_CHANGED" then','    elseif event == "PLAYER_REGEN_ENABLED" or event == "PARTY_LEADER_CHANGED" then\n        HB.CheckAutoLoot()\n    elseif event == "PARTY_LOOT_METHOD_CHANGED" then')
    g=replace(g,'"PLAYER_ENTERING_WORLD", "PARTY_LOOT_METHOD_CHANGED"})','"PLAYER_ENTERING_WORLD", "PARTY_LOOT_METHOD_CHANGED", "PLAYER_REGEN_ENABLED", "PARTY_LEADER_CHANGED"})')
    r=original[sync].decode()
    r=replace(r,'    if S.OnChange then S.OnChange(changed) end','    if S.OnChange then S.OnChange(changed) end\n    if changed and HB.OnRegisterPartyChanged then HB.OnRegisterPartyChanged() end')
    r=replace(r,'        d.rev=math.max(1,d.rev+1);d.dirty=true;schedule()\n        if HB.RegisterPeerSync','        d.rev=math.max(1,d.rev+1);d.dirty=true;schedule()\n        if HB.OnRegisterPartyChanged then HB.OnRegisterPartyChanged() end\n        if HB.RegisterPeerSync')
    c=original[control].decode()
    c=replace(c,'        HB.db.autoFFA=true\n        if HB.CheckAutoLoot then HB.CheckAutoLoot() end','        HB.db.autoFFA=not HB.db.autoFFA\n        if HB.CheckAutoLoot then HB.CheckAutoLoot() end')
    c=replace(c,'        if HB.db.autoFFA and HB.CheckAutoLoot then HB.CheckAutoLoot() end','        if HB.CheckAutoLoot then HB.CheckAutoLoot() end')
    mods={toc:s.encode(),party:p.encode(),game:g.encode(),sync:r.encode(),control:c.encode()}
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
    subprocess.run(['lua5.1',str(SRC/'test_party_loot.lua'),str(Path(temp)/'Party.lua'),str(Path(temp)/'Gameplay.lua'),str(Path(temp)/'RegisterSync.lua'),str(Path(temp)/'ControlBar.lua')],check=True)
report={'version':'JB26.3.20','base':'JB26.3.19','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'GUID-based live party POS display and CM-only automatic loot; no new polling; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
