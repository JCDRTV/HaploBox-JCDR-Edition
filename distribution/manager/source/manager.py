"""HaploBox Manager HM26.1.0 TEST. Python 3.10+; no external packages."""
import hashlib, json, os, re, stat, subprocess, tempfile, uuid
from pathlib import Path
from datetime import datetime, timezone

VERSION = 'HM26.1.0 TEST'
DEFAULT = r'D:\World of Warcraft\_forever_'
RULES = {'Blizzard frame positions': 'layout-local.txt', 'Character keybinds (optional)': 'bindings-cache.wtf'}
HOME = Path(os.getenv('LOCALAPPDATA', str(Path.home()))) / 'HaploBoxManager'

def digest(data): return hashlib.sha256(data).hexdigest()
def snapshot(path): return digest(path.read_bytes()) if path.is_file() else None

def guard(path, root):
    root, path = Path(os.path.abspath(root)), Path(os.path.abspath(path))
    if not path.is_relative_to(root) or path == root: raise ValueError('Path outside selected root')
    for p in (path, *path.parents):
        if p.exists() or p.is_symlink():
            s = p.lstat()
            if p.is_symlink() or getattr(s, 'st_file_attributes', 0) & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 1024):
                raise ValueError('Symlink or junction refused: ' + str(p))
    return path

def characters(root):
    root = Path(root).absolute(); base = guard(root/'WTF'/'Account',root)
    if not base.is_dir(): raise ValueError('Select the Forever folder containing WTF/Account')
    result=[]
    for a in sorted(base.iterdir()):
        if not a.is_dir(): continue
        guard(a,root)
        for r in sorted(a.iterdir()):
            if not r.is_dir() or r.name.lower() in ('savedvariables','backups','cache'): continue
            guard(r,root)
            for c in sorted(r.iterdir()):
                if not c.is_dir() or c.name.lower() in ('savedvariables','backups','cache'): continue
                guard(c,root)
                if not ((c/'SavedVariables').is_dir() or any((c/f).is_file() for f in ('layout-local.txt','AddOns.txt','config-cache.wtf','bindings-cache.wtf','macros-cache.txt'))): continue
                result.append(c.relative_to(root).as_posix())
    return result

def closed():
    if os.name != 'nt': raise RuntimeError('Windows process check unavailable; live writes blocked')
    p=subprocess.run(['tasklist','/FO','CSV','/NH'],capture_output=True,text=True,errors='replace',check=True,creationflags=subprocess.CREATE_NO_WINDOW)
    import csv
    if not p.stdout.strip(): raise RuntimeError('Could not inspect Windows processes')
    for row in csv.reader(p.stdout.splitlines()):
        if row and re.match(r'^(wow|worldofwarcraft).*\.exe$',row[0],re.I): raise RuntimeError('Close ALL WoW clients first: '+row[0])
    if not any(len(r)>=5 for r in csv.reader(p.stdout.splitlines())): raise RuntimeError('Unexpected process list; writes blocked')

def plan(root, source, targets, choices):
    root=Path(root).absolute(); roster=characters(root)
    if source not in roster or not targets or source in targets or any(t not in roster for t in targets): raise ValueError('Choose one source and different valid targets')
    if not choices or any(c not in RULES for c in choices): raise ValueError('Choose supported settings')
    rows=[]
    for c in sorted(set(choices)):
        src=guard(root/source/RULES[c],root)
        if not src.is_file(): raise ValueError('Missing source file: '+str(src))
        if src.stat().st_size > 2*1024*1024: raise ValueError('Unexpected source file size')
        for t in sorted(set(targets)):
            dst=guard(root/t/RULES[c],root)
            if dst.exists() and not dst.is_file(): raise ValueError('Invalid destination')
            before=snapshot(dst); after=snapshot(src)
            if before!=after: rows.append(dict(source=src.relative_to(root).as_posix(),dest=dst.relative_to(root).as_posix(),before=before,after=after))
    return rows

def atomic(path,data):
    with tempfile.NamedTemporaryFile(dir=path.parent,delete=False) as f:
        tmp=Path(f.name); f.write(data); f.flush(); os.fsync(f.fileno())
    try: os.replace(tmp,path)
    finally: tmp.unlink(missing_ok=True)

def log(home,msg):
    home.mkdir(parents=True,exist_ok=True)
    with (home/'manager.log').open('a',encoding='utf-8') as f: f.write(datetime.now(timezone.utc).isoformat()+' '+msg+'\n')

def execute(root, rows, home, check=closed):
    root,home=Path(root).absolute(),Path(home).absolute(); check()
    if not rows: raise ValueError('No changes')
    roster=set(characters(root)); seen=set(); payload=[]
    for r in rows:
        src=guard(root/r['source'],root); dst=guard(root/r['dest'],root)
        if src.name not in RULES.values() or src.name!=dst.name or src.parent.relative_to(root).as_posix() not in roster or dst.parent.relative_to(root).as_posix() not in roster or src==dst or dst in seen: raise ValueError('Invalid plan')
        seen.add(dst); data=src.read_bytes(); old=dst.read_bytes() if dst.is_file() else None
        if digest(data)!=r['after'] or (digest(old) if old is not None else None)!=r['before']: raise ValueError('Files changed since preview; preview again')
        payload.append((dst,data,old))
    if root.is_relative_to(home) or home.is_relative_to(root): raise ValueError('Backup folder must be separate from game folder')
    backup=home/'Backups'/(datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8]); backup.mkdir(parents=True)
    for i,(_,_,old) in enumerate(payload):
        if old is not None:
            atomic(backup/f'{i}.bak',old)
            if snapshot(backup/f'{i}.bak')!=rows[i]['before']: raise RuntimeError('Backup verification failed')
    manifest={'version':VERSION,'root':str(root),'rows':rows}
    atomic(backup/'manifest.json',json.dumps(manifest,indent=2).encode())
    atomic(backup/'state',b'PREPARED'); log(home,'PREPARED '+str(backup)); changed=[]
    try:
        check()
        for i,(dst,data,old) in enumerate(payload):
            check(); guard(dst,root)
            if snapshot(dst)!=rows[i]['before']: raise ValueError('Destination changed during operation')
            atomic(dst,data); changed.append(i)
            if snapshot(dst)!=rows[i]['after']: raise RuntimeError('Copy verification failed')
        atomic(backup/'state',b'APPLIED'); log(home,'APPLIED '+str(backup)); return backup
    except Exception:
        try:
            check()
            for i in reversed(changed):
                dst,_,old=payload[i]; guard(dst,root)
                if snapshot(dst)!=rows[i]['after']: raise RuntimeError('Destination modified; manual recovery required')
                if old is None: dst.unlink()
                else: atomic(dst,old)
            atomic(backup/'state',b'ROLLED_BACK')
        except Exception as exc: log(home,'RECOVERY REQUIRED '+str(backup)+' '+str(exc))
        raise

def restore(root,backup,home,check=closed):
    root,backup,home=Path(root).absolute(),Path(backup).absolute(),Path(home).absolute(); check(); guard(backup,home/'Backups')
    m=json.loads(guard(backup/'manifest.json',backup).read_text()); rows=m['rows']
    if Path(m['root'])!=root or guard(backup/'state',backup).read_text() not in ('APPLIED','PREPARED'): raise ValueError('Backup belongs to different root or is not restorable')
    roster=set(characters(root)); changes=[]; seen=set()
    for i,r in enumerate(rows):
        dst=guard(root/r['dest'],root)
        if dst.name not in RULES.values() or dst.parent.relative_to(root).as_posix() not in roster or dst in seen: raise ValueError('Invalid backup destination')
        seen.add(dst); current=snapshot(dst)
        if current not in (r['before'],r['after']): raise ValueError('File changed after sync; restore refused: '+str(dst))
        old=None if r['before'] is None else guard(backup/f'{i}.bak',backup).read_bytes()
        if old is not None and digest(old)!=r['before']: raise ValueError('Backup checksum mismatch')
        if current!=r['before']: changes.append((dst,old,current))
    for dst,old,current in changes:
        check(); guard(dst,root)
        if snapshot(dst)!=current: raise ValueError('Destination changed during restore; retry after checking files')
        if old is None: dst.unlink()
        else: atomic(dst,old)
        if snapshot(dst)!=(digest(old) if old is not None else None): raise RuntimeError('Restore verification failed')
    atomic(backup/'state',b'RESTORED'); log(home,'RESTORED '+str(backup))

def updater():
    if os.name!='nt': raise RuntimeError('Windows required')
    # Use the installed updater shortcut, not a guessed executable.
    import ctypes
    buf=ctypes.create_unicode_buffer(32768)
    if ctypes.windll.shell32.SHGetFolderPathW(None,0x10,None,0,buf)!=0: raise RuntimeError('Desktop not found')
    shortcut=Path(buf.value)/'HaploBox UPDATE.lnk'
    if not shortcut.is_file(): raise ValueError('Existing HaploBox UPDATE shortcut not found; install original updater first')
    closed(); os.startfile(str(shortcut))

def main():
    import tkinter as tk
    from tkinter import ttk, filedialog, messagebox
    w=tk.Tk(); w.title('HaploBox Manager | '+VERSION); w.geometry('1050x760'); w.minsize(820,580)
    style=ttk.Style(w); style.theme_use('clam'); style.configure('TFrame',background='#20252d'); style.configure('TLabel',background='#20252d',foreground='#e6e6e6'); style.configure('TCheckbutton',background='#20252d',foreground='#e6e6e6'); style.configure('Title.TLabel',font=('Segoe UI',18,'bold'),foreground='#dfbe79'); w.configure(bg='#20252d')
    panel=ttk.Frame(w,padding=16); panel.pack(fill='both',expand=True)
    ttk.Label(panel,text='HAPLOBOX MANAGER',style='Title.TLabel').pack(anchor='w'); ttk.Label(panel,text=VERSION+' | Safe offline settings sync').pack(anchor='w')
    root=tk.StringVar(value=DEFAULT); top=ttk.Frame(panel); top.pack(fill='x',pady=10); ttk.Entry(top,textvariable=root).pack(side='left',fill='x',expand=True)
    def browse():
        p=filedialog.askdirectory();
        if p: root.set(p); run(scan)
    ttk.Button(top,text='BROWSE',command=browse).pack(side='left')
    def run(fn):
        try: fn()
        except Exception as e: messagebox.showerror('HaploBox Manager',str(e),parent=w)
    ttk.Button(top,text='SCAN',command=lambda:run(scan)).pack(side='left')
    source=ttk.Combobox(panel,state='readonly'); ttk.Label(panel,text='SOURCE | account / realm / character').pack(anchor='w'); source.pack(fill='x')
    ttk.Label(panel,text='TARGETS | select one or more (Ctrl / Shift)').pack(anchor='w',pady=(10,0)); targets=tk.Listbox(panel,selectmode='extended',exportselection=False,height=8,bg='#141920',fg='white',selectbackground='#826b38'); targets.pack(fill='x')
    actions=ttk.Frame(panel); actions.pack(fill='x'); ttk.Button(actions,text='SELECT ALL',command=lambda:targets.selection_set(0,'end')).pack(side='left'); ttk.Button(actions,text='CLEAR',command=lambda:targets.selection_clear(0,'end')).pack(side='left')
    choices={k:tk.BooleanVar() for k in RULES}
    for k,v in choices.items(): ttk.Checkbutton(panel,text=k,variable=v).pack(anchor='w')
    ttk.Label(panel,text='Addon SavedVariables, account keybinds, macros and progress are not copied.').pack(anchor='w')
    output=tk.Text(panel,height=12,wrap='none',bg='#141920',fg='#e6e6e6'); output.pack(fill='both',expand=True,pady=8)
    def show(s): output.delete('1.0','end'); output.insert('1.0',s)
    def update_targets(*_):
        targets.delete(0,'end')
        for c in source['values']:
            if c!=source.get(): targets.insert('end',c)
    source.bind('<<ComboboxSelected>>',update_targets)
    def scan():
        roster=characters(root.get()); source['values']=roster; source.set(roster[0] if roster else ''); update_targets(); show(f'{len(roster)} character folders detected. No targets or settings selected.')
        for v in choices.values(): v.set(False)
    def current(): return plan(root.get(),source.get(),[targets.get(i) for i in targets.curselection()],[k for k,v in choices.items() if v.get()])
    previewed=[]
    def preview():
        rows=current(); previewed[:]=[(str(Path(root.get()).absolute()),rows)]; show('PREVIEW - no changes made\n'+ '\n'.join(('CREATE ' if r['before'] is None else 'REPLACE ')+r['dest']+'\n  from '+r['source'] for r in rows) if rows else 'No changes necessary.')
    def apply():
        rows=current()
        if not previewed or previewed[0]!=(str(Path(root.get()).absolute()),rows): raise ValueError('Preview first; selection/files changed')
        if not rows: raise ValueError('No changes')
        closed()
        if messagebox.askyesno('Confirm',f'Copy {len(rows)} files with verified backups? All WoW clients must remain closed. If selected, character keybinds will be replaced in full.',parent=w):
            backup=execute(root.get(),rows,HOME); previewed.clear(); show('SUCCESS\nBackup: '+str(backup))
    def recover():
        p=filedialog.askdirectory(initialdir=str(HOME/'Backups'),title='Choose a Manager backup folder')
        if p and messagebox.askyesno('Restore','Restore selected transaction? Changed files since sync are refused.',parent=w): restore(root.get(),p,HOME); previewed.clear(); show('RESTORED '+p)
    def status():
        p=HOME/'manager.log'; show((p.read_text(encoding='utf-8')[-12000:] if p.exists() else 'No Manager transactions yet.')+'\n\nExisting updater log: '+str(HOME.parent/'HaploBoxUpdater'/'updater.log'))
    bar=ttk.Frame(panel); bar.pack(fill='x')
    for name,fn in [('PREVIEW',preview),('COPY SETTINGS',apply),('RESTORE',recover),('UPDATE',updater),('STATUS',status)]: ttk.Button(bar,text=name,command=lambda f=fn:run(f)).pack(side='left',padx=3)
    if Path(DEFAULT).is_dir(): run(scan)
    w.mainloop()
if __name__=='__main__': main()
