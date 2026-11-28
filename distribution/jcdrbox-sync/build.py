from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-sync'
BASE=ROOT/'distribution/jcdrbox-tm/output/JCDRbox_JB26.3.0_Team_Management_TEST.zip'
SHA='9b44a65f749d8e00ab364b36b3873795a01ed4d7b7b763300e5ec284f316c783'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.1_Register_Sync_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua';tu='HaploBox/TeamPlannerUI.lua'
    s=original[toc].decode()
    s=replace(s,'## Version: JB26.3.0','## Version: JB26.3.1')
    s=replace(s,'TeamPlannerUI.lua\nManagementUI.lua','TeamPlannerUI.lua\nRegisterCodec.lua\nRegisterSync.lua\nManagementUI.lua')
    c=original[ui].decode()
    c=replace(c,'frame:SetSize(690,420)','frame:SetSize(690,444)')
    c=replace(c,'    frame.status=text(frame,"",12,-394,660,muted)','''    frame.status=text(frame,"",12,-394,660,muted)
    frame.syncLine=text(frame,"",12,-422,480,muted)
    frame.syncButton=button(frame,"Sync Register",516,-414,150,function() HB.RegisterSync.Action() end)''')
    c=replace(c,'    frame:SetScript("OnShow",function() refresh() end)','''    HB.RegisterSync.OnChange=function(changed)
        if changed and teamPanel and teamPanel.SyncReload then teamPanel.SyncReload() end
        if frame:IsShown() then
            if changed then refresh() end
            frame.syncLine:SetText(HB.RegisterSync.Status())
            frame.syncButton:SetText(HB.RegisterSync.ActionLabel())
        end
    end
    frame:SetScript("OnShow",function() refresh() end)''')
    c=replace(c,'    if not frame or not frame:IsShown() then return end\n    hidePopup()','''    if not frame or not frame:IsShown() then return end
    frame.syncLine:SetText(HB.RegisterSync.Status())
    frame.syncButton:SetText(HB.RegisterSync.ActionLabel())
    hidePopup()''')
    t=original[tu].decode()
    t=replace(t,'local dirty,deleteConfirm=false,false','local dirty,deleteConfirm,staleDraft=false,false,false')
    t=replace(t,'dirty=false;deleteConfirm=false;render()','dirty=false;deleteConfirm=false;staleDraft=false;render()')
    t=replace(t,'saveBtn:SetEnabled(can and (not party','saveBtn:SetEnabled(not staleDraft and can and (not party')
    t=replace(t,'    panel:SetScript("OnShow",function() if not dirty then load(T.Active()) else render() end end)','''    panel.SyncReload=function()
        if dirty then
            staleDraft=true
            if panel:IsShown() then render();notice("Register changed remotely; discard this draft before saving.") end
        else
            load(T.Active())
        end
    end
    panel:SetScript("OnShow",function() if not dirty then load(T.Active()) else render() end end)''')
    mods={toc:s.encode(),ui:c.encode(),tu:t.encode()}
    additions={'HaploBox/'+n:(SRC/n).read_bytes() for n in ('RegisterCodec.lua','RegisterSync.lua')}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
        for n,b in additions.items():out.writestr(n,b)
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)|set(additions)
    for n,b in {**original,**mods,**additions}.items():assert out.read(n)==b,n
    for n in [ui,tu,'HaploBox/CharacterManagement.lua','HaploBox/TeamPlanner.lua',*additions]:
        p=Path(temp)/Path(n).name;p.write_bytes(out.read(n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/'CharacterManagement.lua')],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-tm/test_tm.lua'),str(Path(temp)/'TeamPlanner.lua')],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_sync.lua'),*[str(Path(temp)/n) for n in ('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterSync.lua')]],check=True)
report={'version':'JB26.3.1','base':'JB26.3.0','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'added_files':list(additions),'status':'ingame acceptance open; online own-party sync only; first unknown source requires consent; no live party or macro engine changes'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
