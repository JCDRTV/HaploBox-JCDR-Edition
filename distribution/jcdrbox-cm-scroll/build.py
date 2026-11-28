from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import copy
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-cm-scroll'
BASE=ROOT/'distribution/jcdrbox-event-register/output/JCDRbox_JB26.3.5_Event_Register_TEST.zip'
SHA='04ce3237b51994e2882b3a8d840dcdfbafc4544254beb2eba0c41398c081efd7'
OUT=SRC/'output';OUT.mkdir(exist_ok=True)
TARGET=OUT/'JCDRbox_JB26.3.6_CM_Scroll_TEST.zip'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(BASE)==SHA,(digest(BASE),SHA)
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
with ZipFile(BASE) as old:
    original={n:old.read(n) for n in old.namelist()}
    assert old.testzip() is None and len(original)==len(old.namelist())
    toc='HaploBox/HaploBox.toc';ui='HaploBox/ManagementUI.lua'
    s=replace(original[toc].decode(),'## Version: JB26.3.5','## Version: JB26.3.6')
    c=original[ui].decode()
    c=replace(c,'local tab,view,page,sortKey,asc="characters","list",1,"account",true','local tab,view,offset,sortKey,asc="characters","list",0,"account",true')
    c=replace(c,'view=v;page=1;','view=v;offset=0;')
    c=replace(c,'filters[key]=v;page=1;refresh()','filters[key]=v;offset=0;refresh()')
    c=replace(c,'            page=1;refresh()','            offset=0;refresh()')
    c=replace(c,'r:SetSize(666,25)','r:SetSize(646,25)')
    c=replace(c,'590,-1,76,function()','590,-1,56,function()')
    c=replace(c,'''    body.prev=button(body,"<",0,-302,35,function() page=page-1;refresh() end)
    body.next=button(body,">",150,-302,35,function() page=page+1;refresh() end)
    body.count=text(body,"",42,-309,100,muted)''','''    body.scroll=CreateFrame("Slider",nil,body)
    body.scroll:SetSize(16,208);body.scroll:SetPoint("TOPLEFT",body,"TOPLEFT",650,-90)
    body.scroll:SetOrientation("VERTICAL");body.scroll:SetMinMaxValues(0,0)
    body.scroll:SetValueStep(1);body.scroll:SetObeyStepOnDrag(true)
    local track=body.scroll:CreateTexture(nil,"BACKGROUND")
    track:SetAllPoints();track:SetColorTexture(.063,.137,.196,.95)
    body.scroll:SetThumbTexture("Interface\\\\Buttons\\\\UI-ScrollBar-Knob")
    body.scroll:GetThumbTexture():SetSize(16,24)
    body.scroll:SetScript("OnValueChanged",function(_,v)
        if body.updatingScroll then return end
        local n=math.floor(v+.5)
        if n~=offset then offset=n;removeGuid=nil;refresh() end
    end)
    local function wheel(_,delta)
        if body.scroll:IsShown() then
            local _,max=body.scroll:GetMinMaxValues()
            body.scroll:SetValue(math.max(0,math.min(max,offset-delta)))
        end
    end
    body:EnableMouseWheel(true);body:SetScript("OnMouseWheel",wheel)
    body.scroll:EnableMouseWheel(true);body.scroll:SetScript("OnMouseWheel",wheel)
    for _,r in ipairs(body.rows) do
        r:EnableMouseWheel(true);r:SetScript("OnMouseWheel",wheel)
    end
    body.count=text(body,"",0,-309,250,muted)''')
    c=replace(c,'    local pages=math.max(1,math.ceil(#items/8));page=math.min(pages,math.max(1,page))','    local maxOffset=math.max(0,#items-#body.rows);offset=math.max(0,math.min(maxOffset,offset))')
    c=replace(c,'items[(page-1)*8+i]','items[offset+i]')
    c=replace(c,'''    body.prev:SetShown(tab=="characters");body.next:SetShown(tab=="characters");body.count:SetShown(tab=="characters")
    body.prev:SetEnabled(page>1);body.next:SetEnabled(page<pages);body.count:SetText(page.." / "..pages)''','''    body.updatingScroll=true
    body.scroll:SetMinMaxValues(0,maxOffset);body.scroll:SetValue(offset)
    body.scroll:SetShown(maxOffset>0)
    body.updatingScroll=false
    body.count:SetShown(tab=="characters")
    body.count:SetText(#items==0 and "0 characters" or (offset+1).."–"..math.min(#items,offset+#body.rows).." / "..#items)''')
    c=replace(c,'snapshot=nil;view="list";removeGuid=nil','snapshot=nil;view="list";offset=0;removeGuid=nil')
    assert 'body.prev' not in c and 'body.next' not in c and 'page=' not in c
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
report={'version':'JB26.3.6','base':'JB26.3.5','base_sha256':SHA,'sha256':digest(TARGET),'unchanged_files':len(original)-len(mods),'modified_files':list(mods),'status':'Vertical CM list scrolling; register and other systems unchanged; ingame acceptance open'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
