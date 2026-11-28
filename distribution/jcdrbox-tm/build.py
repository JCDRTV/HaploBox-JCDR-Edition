from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-tm'
BASE=ROOT/'distribution/jcdrbox-cm/output/JCDRbox_JB26.2.0_Character_Management_TEST.zip'
SHA='b71582202a905e1447c1b652c4f622c353c5811aad4f41307aa027553169dd83'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.0_Team_Management_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua'
    s=original[toc].decode()
    s=replace(s,'## Version: JB26.2.0','## Version: JB26.3.0')
    s=replace(s,'CharacterManagement.lua\nManagementUI.lua','CharacterManagement.lua\nTeamPlanner.lua\nTeamPlannerUI.lua\nManagementUI.lua')
    c=original[ui].decode()
    c=replace(c,'local frame,body,popup,refresh','local frame,body,popup,refresh\nlocal teamPanel,teamRefresh')
    c=replace(c,'    frame:SetScript("OnShow",function() refresh() end)','    teamPanel,teamRefresh=HB.TeamPlannerUI.Create(frame,{button=button,text=text,dropdown=dropdown,notice=notice,hidePopup=hidePopup})\n    frame:SetScript("OnShow",function() refresh() end)')
    c=replace(c,'    local editable=CM.CanEdit()','    for k,b in pairs(frame.tabs) do b.line:SetShown(k==tab) end\n    body:SetShown(tab=="characters")\n    teamPanel:SetShown(tab=="teams")\n    if tab=="teams" then teamRefresh();return end\n    local editable=CM.CanEdit()')
    mods={toc:s.encode(),ui:c.encode()}
    additions={'HaploBox/'+n:(SRC/n).read_bytes() for n in ('TeamPlanner.lua','TeamPlannerUI.lua')}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
        for n,b in additions.items():out.writestr(n,b)
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)|set(additions)
    for n,b in {**original,**mods,**additions}.items():assert out.read(n)==b,n
    for n in [ui,'HaploBox/CharacterManagement.lua',*additions]:
        p=Path(temp)/Path(n).name;p.write_bytes(out.read(n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/'CharacterManagement.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_tm.lua'),str(Path(temp)/'TeamPlanner.lua')],check=True)
report={'version':'JB26.3.0','base':'JB26.2.0','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'added_files':list(additions),'status':'ingame acceptance open; local saved teams; live party, invites, macro engine unchanged'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
