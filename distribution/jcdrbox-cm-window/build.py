from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-cm-window'
BASE=ROOT/'distribution/jcdrbox-cm-scroll/output/JCDRbox_JB26.3.6_CM_Scroll_TEST.zip'
SHA='47e33a00ac4d3ff215a1c8e67836bf4f4d1c36dc337f29c46bba25cbb5d504e3'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.7_CM_Window_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.6','## Version: JB26.3.7')
    c=original[ui].decode()
    c=replace(c,'local teamPanel,teamRefresh','local teamPanel,teamRefresh\nlocal layout,windowPrefs\nlocal visibleRows=8')
    c=replace(c,'    frame:SetSize(690,444);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")','''    HB.db=HB.db or {}
    if type(HB.db.managementWindow)~="table" then HB.db.managementWindow={} end
    windowPrefs=HB.db.managementWindow
    local function bounded(v,lo,hi,default)
        return type(v)=="number" and v==v and math.max(lo,math.min(hi,v)) or default
    end
    frame:SetSize(bounded(windowPrefs.width,690,1200,690),bounded(windowPrefs.height,444,1000,444))
    local points={TOPLEFT=true,TOP=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,BOTTOMLEFT=true,BOTTOM=true,BOTTOMRIGHT=true}
    if points[windowPrefs.point] and points[windowPrefs.relativePoint] and type(windowPrefs.x)=="number" and type(windowPrefs.y)=="number" then
        frame:SetPoint(windowPrefs.point,UIParent,windowPrefs.relativePoint,windowPrefs.x,windowPrefs.y)
    else frame:SetPoint("CENTER") end
    frame:SetFrameStrata("DIALOG")''')
    c=replace(c,'    button(frame,"X",650,-3,30,function() frame:Hide() end)','''    frame.close=button(frame,"X",650,-3,30,function() frame:Hide() end)
    local function saveWindow()
        windowPrefs.width=frame:GetWidth();windowPrefs.height=frame:GetHeight()
        local p,_,rp,x,y=frame:GetPoint()
        if p and rp and x and y then windowPrefs.point=p;windowPrefs.relativePoint=rp;windowPrefs.x=x;windowPrefs.y=y end
    end
    local function applyLock()
        local locked=windowPrefs.locked==true
        frame:SetMovable(not locked);frame:SetResizable(not locked)
        frame.lock:SetText(locked and "Unlock" or "Lock")
        frame.grip:SetShown(not locked)
    end
    frame.lock=button(frame,"Lock",574,-3,70,function()
        windowPrefs.locked=not windowPrefs.locked;applyLock();saveWindow()
    end)
    if frame.SetResizeBounds then frame:SetResizeBounds(690,444,1200,1000)
    else frame:SetMinResize(690,444);frame:SetMaxResize(1200,1000) end
    frame.drag=CreateFrame("Frame",nil,frame)
    frame.drag:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);frame.drag:SetSize(550,31)
    frame.drag:EnableMouse(true);frame.drag:RegisterForDrag("LeftButton")
    frame.drag:SetScript("OnDragStart",function() if not windowPrefs.locked then frame:StartMoving() end end)
    frame.drag:SetScript("OnDragStop",function() frame:StopMovingOrSizing();saveWindow() end)
    frame.grip=CreateFrame("Button",nil,frame)
    frame.grip:SetSize(16,16);frame.grip:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-3,3)
    frame.grip:SetNormalTexture("Interface\\\\ChatFrame\\\\UI-ChatIM-SizeGrabber-Up")
    frame.grip:SetHighlightTexture("Interface\\\\ChatFrame\\\\UI-ChatIM-SizeGrabber-Highlight")
    frame.grip:SetPushedTexture("Interface\\\\ChatFrame\\\\UI-ChatIM-SizeGrabber-Down")
    frame.grip:SetScript("OnMouseDown",function(_,key) if key=="LeftButton" and not windowPrefs.locked then frame:StartSizing("BOTTOMRIGHT") end end)
    frame.grip:SetScript("OnMouseUp",function() frame:StopMovingOrSizing();saveWindow() end)
    applyLock()''')
    c=replace(c,'    for i=1,8 do\n        local r=CreateFrame("Frame",nil,body);','    local function makeRow(i)\n        local r=CreateFrame("Frame",nil,body);')
    c=replace(c,'        body.rows[i]=r\n    end\n    body.scroll=','        body.rows[i]=r;return r\n    end\n    body.scroll=')
    c=replace(c,'    body.scroll:GetThumbTexture():SetSize(16,24)','''    body.scroll:GetThumbTexture():SetSize(16,24)
    body.up=button(body,"^",650,-90,16,function() body.scroll:SetValue(offset-1) end)
    body.down=button(body,"v",650,-278,16,function() body.scroll:SetValue(offset+1) end)
    body.up:SetHeight(16);body.down:SetHeight(16)
    body.up:SetNormalTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollUpButton-Up")
    body.up:SetPushedTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollUpButton-Down")
    body.up:SetDisabledTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollUpButton-Disabled")
    body.down:SetNormalTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollDownButton-Up")
    body.down:SetPushedTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollDownButton-Down")
    body.down:SetDisabledTexture("Interface\\\\Buttons\\\\UI-ScrollBar-ScrollDownButton-Disabled")
    body.up:SetText("");body.down:SetText("")''')
    c=replace(c,'''    for _,r in ipairs(body.rows) do
        r:EnableMouseWheel(true);r:SetScript("OnMouseWheel",wheel)
    end
    body.count=text(body,"",0,-309,250,muted)''','''    body.count=text(body,"",0,-309,250,muted)
    local function place(o,parent,x,y)
        o:ClearAllPoints();o:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    end
    layout=function()
        local w,h=frame:GetWidth(),frame:GetHeight()
        local extra=w-690
        visibleRows=math.max(8,math.floor((h-444)/26)+8)
        body:SetSize(w-24,h-118)
        place(frame.close,frame,w-40,-3);place(frame.lock,frame,w-116,-3)
        frame.drag:SetWidth(w-140)
        for i,k in ipairs({"characters","teams"}) do
            local bw=(w-30)/2
            frame.tabs[k]:SetWidth(bw);place(frame.tabs[k],frame,12+(i-1)*(bw+3),-36)
        end
        for i,k in ipairs({"account","class","realm"}) do
            local bw=(w-48)/3
            body.filterButtons[k]:SetWidth(bw);place(body.filterButtons[k],body,(i-1)*(bw+6),-30)
        end
        body.headers.name:SetWidth(177+extra)
        place(body.headers.class,body,285+extra,-62);place(body.headers.race,body,373+extra,-62);place(body.headers.level,body,457+extra,-62)
        for i=1,visibleRows do
            local r=body.rows[i]
            if not r then r=makeRow(i);r:EnableMouseWheel(true);r:SetScript("OnMouseWheel",wheel) end
            r:SetWidth(646+extra);r.name:SetWidth(174+extra)
            place(r.class,r,289+extra,-6);place(r.race,r,377+extra,-6);place(r.level,r,461+extra,-6)
            place(r.assign,r,507+extra,-1);place(r.remove,r,590+extra,-1)
        end
        for i=visibleRows+1,#body.rows do body.rows[i].item=nil;body.rows[i]:Hide() end
        place(body.up,body,650+extra,-90)
        place(body.scroll,body,650+extra,-108);body.scroll:SetHeight(visibleRows*26-36)
        place(body.down,body,650+extra,-90-visibleRows*26+16)
        place(body.count,body,0,-101-visibleRows*26)
        place(frame.status,frame,12,-h+50);frame.status:SetWidth(w-30)
        place(frame.syncLine,frame,12,-h+22);frame.syncLine:SetWidth(w-30)
    end''')
    c=replace(c,'    frame:SetScript("OnShow",function() refresh() end)','''    frame:SetScript("OnSizeChanged",function() layout();refresh() end)
    layout()
    frame:SetScript("OnShow",function() layout();refresh() end)''')
    c=replace(c,'local maxOffset=math.max(0,#items-#body.rows)','local maxOffset=math.max(0,#items-visibleRows)')
    c=replace(c,'    for i,r in ipairs(body.rows) do\n        local item=items[offset+i];','    for i,r in ipairs(body.rows) do\n        local item=i<=visibleRows and items[offset+i] or nil;')
    c=replace(c,'    body.scroll:SetShown(maxOffset>0)','''    body.scroll:SetShown(maxOffset>0);body.up:SetShown(maxOffset>0);body.down:SetShown(maxOffset>0)
    local trackHeight=visibleRows*26-36
    body.scroll:GetThumbTexture():SetSize(16,math.max(12,math.min(trackHeight,trackHeight*visibleRows/math.max(visibleRows,#items))))
    body.up:SetEnabled(offset>0);body.down:SetEnabled(offset<maxOffset)''')
    c=replace(c,'offset+#body.rows','offset+visibleRows')
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
report={'version':'JB26.3.7','base':'JB26.3.6','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Proportional scrollbar, arrows, resizable lockable window; register unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
