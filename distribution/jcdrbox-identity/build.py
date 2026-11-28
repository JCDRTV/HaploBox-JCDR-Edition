"""JB26.1.0: UI-only restyle of verified .59, preserving all internal identifiers."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
from copy import copy
import hashlib, json, re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'distribution/jcdrbox-identity'
BASE=ROOT/'distribution/test/HaploBox_HF26.20.59_Macro_Profile_Hotfix_TEST.zip'
SHA='f3039d96c468395525dcba8a0ae14f819b21552db3e63509a67d0ac35403d71e'
NAME='JCDRbox_JB26.1.0_Identity_TEST.zip'
OUT=SRC/'output'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
# Explicitly scoped UI presentation changes; no generic replacement of class,
# role, warning, gold currency, HP or spell colours.
ACCENT='0.396,0.851,1'
EDGE='0.157,0.376,0.502'
TEXT='0.863,0.910,0.945'
BASE_BG='0.024,0.051,0.082'
PANEL='0.063,0.137,0.196'
def literal(s,old,new,required=True):
    n=s.count(old)
    if required: assert n, 'Missing anchor: '+old
    return s.replace(old,new),n
def rgb(s,old,new,required=True):
    pattern=r'(?<![\d.])'+r'\s*,\s*'.join(re.escape(x) for x in old.split(','))+r'(?![\d.])'
    s,n=re.subn(pattern,new,s)
    if required: assert n,'Missing RGB anchor: '+old
    return s,n
# These pairs were confirmed in the actual archived source. Target only
# UI lines (not global literal substitutions) via the named receiver.
CHANGES={
 'ControlBar.lua':[
 ('background:SetColorTexture(0.08,0.09,0.12,0.94)','background:SetColorTexture('+BASE_BG+',0.94)'),
 ('trim:SetColorTexture(0.62,0.49,0.27,0.95)','trim:SetColorTexture('+EDGE+',0.95)'),
 ('bg:SetColorTexture(0.18,0.21,0.26,1)','bg:SetColorTexture('+PANEL+',1)'),
 ('goldTop:SetColorTexture(0.65,0.49,0.23,1)','goldTop:SetColorTexture('+ACCENT+',0.75)'),
 ('edge:SetColorTexture(0.72,0.54,0.20,0.95)','edge:SetColorTexture('+EDGE+',0.95)'),
 ('flyout.back:SetColorTexture(0.095,0.11,0.14,0.99)','flyout.back:SetColorTexture('+BASE_BG+',0.99)'),
 ('trim:SetColorTexture(0.72,0.54,0.24,0.94)','trim:SetColorTexture('+ACCENT+',0.8)'),
 ('headline:SetTextColor(1,0.82,0.44)','headline:SetTextColor('+ACCENT+')'),
 ('sectionLabel:SetTextColor(0.88,0.78,0.52)','sectionLabel:SetTextColor('+TEXT+')'),
 ('rule:SetColorTexture(0.45,0.43,0.34,0.92)','rule:SetColorTexture('+EDGE+',0.92)'),
 ('bg:SetColorTexture(0.13,0.16,0.20,','bg:SetColorTexture('+PANEL+','),
 ('rowLabel:SetTextColor(0.93,0.92,0.88)','rowLabel:SetTextColor('+TEXT+')'),
 ('headline=font(flyout,"Quick Menu")','headline=font(flyout,"JCDRbox | Quick Menu")\n        local credit=font(flyout,"Based on HaploBox")\n        credit:SetTextColor(0.51,0.58,0.65)\n        if STANDARD_TEXT_FONT then credit:SetFont(STANDARD_TEXT_FONT,9,"OUTLINE") end\n        credit:SetPoint("LEFT",headline,"RIGHT",7,0)'),
 ('"HaploBox Options"','"JCDRbox Options"'),
 ('"HaploBox Keybindings"','"JCDRbox Keybindings"'),
 ('local OFF={0.20,0.23,0.28,0.98}','local OFF={0.10,0.18,0.24,0.98}'),
 ('local BLUE={0.14,0.30,0.48,0.97}','local BLUE={0.10,0.32,0.46,0.97}')],
 'ConfigUI.lua':[
 ('heading:SetTextColor(1,0.82,0.40)','heading:SetTextColor('+ACCENT+')'),
 (':SetTextColor(1,0.81,0.39)',':SetTextColor('+ACCENT+')')],
 'MacroLibrary.lua':[
 ('bg:SetColorTexture(0.095,0.11,0.14,0.99)','bg:SetColorTexture('+BASE_BG+',0.99)'),
 ('goldTrim:SetColorTexture(0.72,0.54,0.24,0.94)','goldTrim:SetColorTexture('+EDGE+',0.94)'),
 ('heading:SetTextColor(1,0.83,0.32)','heading:SetTextColor('+ACCENT+')'),
 ('bindingHeading:SetTextColor(1,0.83,0.32)','bindingHeading:SetTextColor('+ACCENT+')'),
 ('tab.activeLine:SetColorTexture(1,0.71,0.19,1)','tab.activeLine:SetColorTexture('+ACCENT+',1)'),
 ('fill:SetColorTexture(0.12,0.16,0.21,0.93)','fill:SetColorTexture('+PANEL+',0.93)'),
 ('"HaploBox - JCDR Edition | Macro Menu"','"JCDRbox | Macro Menu"')],
 'Party.lua':[
 ('t:SetText("HaploBox team - drag to move")','t:SetText("JCDRbox team - drag to move")'),
 ('line:SetColorTexture(0.72,0.54,0.20,0.95)','line:SetColorTexture('+EDGE+',0.95)')],
 'Options.lua':[
 ('title:SetTextColor(1,0.83,0.42)','title:SetTextColor('+ACCENT+')')],
 'TeamManagement.lua':[
 ('font(frame,"TEAM MANAGEMENT",14,-9,500):SetTextColor(1,0.82,0.44)','font(frame,"TEAM MANAGEMENT",14,-9,500):SetTextColor('+ACCENT+')')],
 'LootAdvisor.lua':[
 ('view:SetBackdropColor(.06,.09,.14,.97)','view:SetBackdropColor('+BASE_BG+',.97)'),
 ('side:SetBackdropColor(.07,.11,.17,.97)','side:SetBackdropColor('+PANEL+',.97)')],
 'LootPlanner.lua':[
 ('trim:SetColorTexture(0.72,0.54,0.24,0.94)','trim:SetColorTexture('+EDGE+',0.94)'),
 ('header:SetTextColor(1,.82,.40)','header:SetTextColor('+ACCENT+')')],
 'WeaponSets.lua':[
 ('bg:SetColorTexture(.095,.11,.14,.98)','bg:SetColorTexture('+BASE_BG+',.98)'),
 ('title:SetTextColor(1,.80,.32)','title:SetTextColor('+ACCENT+')')],
 'Alpha4/Options.lua':[
 ('"HaploBox - Alpha 4 (integrated)"','"JCDRbox | Integrated Options"')],
}
# Presentation palettes only. These names are deliberately limited to UI chrome.
PALETTE={
 'bg':BASE_BG,'background':BASE_BG,'panel':PANEL,'surface':PANEL,
 'gold':ACCENT,'accent':ACCENT,'border':EDGE,'trim':EDGE,
 'hover':'0.102,0.278,0.376','normal':PANEL,'text':TEXT,
 'header':PANEL,'edge':EDGE,'neutral':'0.10,0.18,0.24','tile':PANEL,'white':TEXT,
}
def palette(s,filename):
    # Only inspect the leading style declarations, never gameplay functions.
    lines=s.splitlines(keepends=True)
    changes=0
    for i,line in enumerate(lines[:100]):
        if not re.search(r'\b(?:local|[A-Za-z_]+\s*=)',line): continue
        def replace(m):
            nonlocal changes
            key=m.group(1).lower()
            if key not in PALETTE:return m.group(0)
            changes+=1
            return m.group(1)+m.group(2)+'{'+PALETTE[key]+(m.group(4) or '')+'}'
        lines[i]=re.sub(r'\b([A-Za-z_]+)(\s*=\s*)\{(\s*[.\d]+\s*,\s*[.\d]+\s*,\s*[.\d]+)(\s*,\s*[.\d]+)?\s*\}',replace,line)
    return ''.join(lines),changes
def main():
    assert digest(BASE)==SHA
    OUT.mkdir(parents=True,exist_ok=True)
    target=OUT/NAME
    modified={}
    originals={}
    with ZipFile(BASE) as old:
        assert old.testzip() is None
        names=old.namelist()
        assert len(names)==len(set(names))
        for name in names:
            assert name.startswith('HaploBox/') and '..' not in name.split('/') and '\\' not in name
            originals[name]=old.read(name)
        tocname='HaploBox/HaploBox.toc'
        toc=originals[tocname].decode('utf-8-sig')
        assert '## Version: HF26.20.59' in toc and '## Title: HaploBox' in toc
        toc=toc.replace('## Title: HaploBox','## Title: JCDRbox').replace('## Version: HF26.20.59','## Version: JB26.1.0')
        toc=toc.replace('## Author: Haplo','## Author: JCDR TV (based on HaploBox by Haplo)')
        modified[tocname]=toc.encode('utf-8')
        counts={}
        for filename,pairs in CHANGES.items():
            n='HaploBox/'+filename
            s=originals[n].decode('utf-8')
            count=0
            for a,b in pairs:
                s,k=literal(s,a,b);count+=k
            if filename=='ConfigUI.lua':
                s,k=palette(s,filename);count+=k
            if filename=='ControlBar.lua':
                s,k=literal(s,'local GOLD={0.43,0.34,0.15,0.98}','local GOLD={0.102,0.278,0.376,0.98}');count+=k
            modified[n]=s.encode('utf-8');counts[filename]=count
        for filename in ['MenuStyle.lua','ProfessionGuide/UI.lua']:
            n='HaploBox/'+filename
            s=originals[n].decode('utf-8')
            print(filename+' original palette:\n'+'\n'.join(s.splitlines()[:40]))
            s,k=palette(s,filename)
            if filename=='MenuStyle.lua':
                s,j=literal(s,'text:SetTextColor(0.98,0.96,0.92)','text:SetTextColor('+TEXT+')');k+=j
            if k:modified[n]=s.encode('utf-8');counts[filename]=k
        with ZipFile(target,'w',compression=ZIP_DEFLATED) as new:
            for info in old.infolist():
                new.writestr(copy(info),modified.get(info.filename,originals[info.filename]))
    with ZipFile(target) as z, tempfile.TemporaryDirectory() as temp:
        assert z.testzip() is None and z.namelist()==names
        for n in names:
            assert z.read(n)==modified.get(n,originals[n])
            if n.endswith('.lua') and n in modified:
                p=Path(temp)/Path(n).name
                p.write_bytes(z.read(n))
                subprocess.run(['luac5.1','-p',str(p)],check=True)
        for n in ['Core.lua','BoxMode.lua','CharacterRegistry.lua','Bindings.xml','Alpha4/Sync.lua']:
            key='HaploBox/'+n
            if key in originals: assert z.read(key)==originals[key],key
    report={'version':'JB26.1.0','base':'HF26.20.59','base_sha256':SHA,'sha256':digest(target),'modified_files':counts,'unchanged_files':len(names)-len(modified),'status':'candidate; ingame acceptance open','internal_folder':'HaploBox'}
    (OUT/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
