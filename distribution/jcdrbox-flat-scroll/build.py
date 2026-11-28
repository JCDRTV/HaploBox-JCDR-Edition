from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-flat-scroll'
manifest=json.loads((ROOT/'base-manifest/distribution/test/manifest.json').read_text())
assert manifest['version']=='JB26.3.7' and manifest['channel']=='test'
BASE=ROOT/'distribution/jcdrbox-cm-window/output/JCDRbox_JB26.3.7_CM_Window_TEST.zip'
assert manifest['zip_url'].endswith('/'+BASE.relative_to(ROOT).as_posix())
SHA=manifest['sha256']
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.8_Flat_Scroll_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.7','## Version: JB26.3.8')
    c=original[ui].decode()
    c=replace(c,'track:SetColorTexture(.063,.137,.196,.95)','track:SetColorTexture(.125,.173,.220,1)')
    c=replace(c,'''    body.scroll:SetThumbTexture("Interface\\\\Buttons\\\\UI-ScrollBar-Knob")
    body.scroll:GetThumbTexture():SetSize(16,24)''','''    body.scroll:SetThumbTexture("Interface\\\\Buttons\\\\WHITE8X8")
    local thumb=body.scroll:GetThumbTexture()
    thumb:SetColorTexture(.443,.533,.608,1)
    thumb:SetSize(16,24)
    body.scroll:SetScript("OnEnter",function() thumb:SetColorTexture(.58,.68,.76,1) end)
    body.scroll:SetScript("OnLeave",function() thumb:SetColorTexture(.443,.533,.608,1) end)''')
    c=replace(c,'''    body.up=button(body,"^",650,-90,16,function() body.scroll:SetValue(offset-1) end)
    body.down=button(body,"v",650,-278,16,function() body.scroll:SetValue(offset+1) end)
    body.up:SetHeight(16);body.down:SetHeight(16)
    body.up:SetNormalTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollUpButton-Up")
    body.up:SetPushedTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollUpButton-Down")
    body.up:SetDisabledTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollUpButton-Disabled")
    body.down:SetNormalTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollDownButton-Up")
    body.down:SetPushedTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollDownButton-Down")
    body.down:SetDisabledTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollDownButton-Disabled")
    body.up:SetText("");body.down:SetText("")''','''    local function scrollArrow(direction,fn)
        local b=CreateFrame("Button",nil,body)
        b:SetSize(16,16)
        local bg=b:CreateTexture(nil,"BACKGROUND")
        bg:SetAllPoints()
        local marks={}
        for i=-2,2 do
            local mark=b:CreateTexture(nil,"ARTWORK")
            mark:SetSize(2,2)
            mark:SetPoint("CENTER",b,"CENTER",i*2,direction*(2-math.abs(i))*2-direction*2)
            marks[#marks+1]=mark
        end
        local enabled,hover=true,false
        local function paint()
            if hover and enabled then bg:SetColorTexture(.19,.25,.31,1)
            else bg:SetColorTexture(.125,.173,.220,1) end
            for _,mark in ipairs(marks) do
                if not enabled then mark:SetColorTexture(.32,.38,.43,1)
                elseif hover then mark:SetColorTexture(.85,.91,.95,1)
                else mark:SetColorTexture(.65,.72,.78,1) end
            end
        end
        b.SetScrollEnabled=function(self,v) enabled=v;self:SetEnabled(v);paint() end
        b:SetScript("OnEnter",function() hover=true;paint() end)
        b:SetScript("OnLeave",function() hover=false;paint() end)
        b:SetScript("OnClick",fn)
        paint()
        return b
    end
    body.up=scrollArrow(1,function() body.scroll:SetValue(offset-1) end)
    body.down=scrollArrow(-1,function() body.scroll:SetValue(offset+1) end)''')
    c=replace(c,'body.up:SetEnabled(offset>0);body.down:SetEnabled(offset<maxOffset)','body.up:SetScrollEnabled(offset>0);body.down:SetScrollEnabled(offset<maxOffset)')
    mods={toc:s.encode(),ui:c.encode()}
    with ZipFile(TARGET,'w',compression=ZIP_DEFLATED) as out:
        for info in old.infolist():out.writestr(copy(info),mods.get(info.filename,original[info.filename]))
with ZipFile(TARGET) as out,tempfile.TemporaryDirectory() as temp:
    assert out.testzip() is None and set(out.namelist())==set(original)
    for n,b in {**original,**mods}.items():assert out.read(n)==b,n
    names=('CharacterManagement.lua','TeamPlanner.lua','RegisterCodec.lua','RegisterSync.lua','PeerAuth.lua','RegisterPeerSync.lua','ManagementUI.lua','TeamPlannerUI.lua')
    for n in names:
        p=Path(temp)/n;p.write_bytes(out.read('HaploBox/'+n));subprocess.run(['luac5.1','-p',str(p)],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-cm/test_cm.lua'),str(Path(temp)/names[0])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-tm/test_tm.lua'),str(Path(temp)/names[1])],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_sync.lua'),*[str(Path(temp)/n) for n in names[:4]]],check=True)
    subprocess.run(['lua5.1',str(ROOT/'distribution/jcdrbox-event-register/test_peer.lua'),*[str(Path(temp)/n) for n in names[:6]]],check=True)
    subprocess.run(['lua5.1',str(SRC/'test_ui.lua'),str(Path(temp)/'ManagementUI.lua')],check=True)
report={'version':'JB26.3.8','base':'JB26.3.7','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Flat scrollbar visuals only; register and window behavior unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
