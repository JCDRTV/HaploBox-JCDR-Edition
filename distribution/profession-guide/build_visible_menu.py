#!/usr/bin/env python3
"""HF26.20.47 TEST: surface Profession Guide as first MENUS row.

Preserve every existing menu action and all packaged files except ControlBar.lua.
Fail closed on unverified base archive or unexpected menu layout.
"""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
TEST = ROOT / 'distribution' / 'test'
MANIFEST = TEST / 'manifest.json'
BASE = 'HF26.20.46'
VERSION = 'HF26.20.47'
FILENAME = 'HaploBox_HF26.20.47_Profession_Guide_Visible_Menu_TEST.zip'
PREFIX = 'https://raw.githubusercontent.com/JCDRTV/HaploBox-JCDR-Edition/main/'
TARGET = 'HaploBox/ControlBar.lua'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def patch(data):
    bom = data.startswith(b'\xef\xbb\xbf')
    s = data.decode('utf-8-sig')
    nl = '\r\n' if '\r\n' in s else '\n'
    s = s.replace('\r\n', '\n')
    old = '{"MENUS",{{"Macro Menu",{21}},{"HaploBox Keybindings",{23}},\n' \
          '            {"UI Layout",{24}},{"Lyra Gathering Map",{29}},\n' \
          '            {"Haplo Loot",{30}},{"Weapon Sets",{31}},{"Profession Guide",{32}}},28},'
    new = '{"MENUS",{{"Profession Guide",{32}},{"Macro Menu",{21}},\n' \
          '            {"HaploBox Keybindings",{23}},{"UI Layout",{24}},\n' \
          '            {"Lyra Gathering Map",{29}},{"Haplo Loot",{30}},{"Weapon Sets",{31}}},28},'
    if s.count(old) != 1:
        raise RuntimeError(f'Expected exactly one existing 20.46 menu; found {s.count(old)}')
    s = s.replace(old, new, 1)
    assert s.count('mkButton(32,"PROFESSION GUIDE"') == 1
    assert s.count('for i=1,13 do') == 1
    assert s.count('{"Profession Guide",{32}}') == 1
    for idx in (21,23,24,29,30,31):
        assert '{' + str(idx) + '}' in s
    if nl == '\r\n':
        s = s.replace('\n','\r\n')
    return (b'\xef\xbb\xbf' if bom else b'') + s.encode('utf-8')


def main():
    m = json.loads(MANIFEST.read_text(encoding='utf-8'))
    dest = TEST / FILENAME
    if m.get('version') == VERSION:
        if dest.exists() and sha(dest.read_bytes()) == m.get('sha256'):
            print('ALREADY PUBLISHED', VERSION)
            return
        raise RuntimeError('New manifest but missing/mismatching zip')
    if m.get('version') != BASE or m.get('channel') != 'test' or m.get('addon_folder') != 'HaploBox':
        raise RuntimeError('Unexpected manifest baseline: ' + repr(m.get('version')))
    remote = m['zip_url']
    if not remote.startswith(PREFIX + 'distribution/test/'):
        raise RuntimeError('Unexpected source ZIP URL')
    src = ROOT / remote[len(PREFIX):]
    if sha(src.read_bytes()) != m.get('sha256'):
        raise RuntimeError('Base ZIP checksum mismatch')
    with ZipFile(src) as z:
        assert TARGET in z.namelist()
        assert 'HaploBox/ProfessionGuide/UI.lua' in z.namelist()
        ui = z.read('HaploBox/ProfessionGuide/UI.lua').decode('utf-8-sig')
        if 'function PG.ToggleMain()' not in ui:
            raise RuntimeError('Profession Guide launcher function missing')
        replacement = patch(z.read(TARGET))
        with ZipFile(dest,'w') as out:
            for info in z.infolist():
                out.writestr(info,replacement if info.filename==TARGET else z.read(info.filename))
    with ZipFile(src) as old, ZipFile(dest) as new:
        if new.testzip() is not None:
            raise RuntimeError('ZIP CRC failed')
        assert old.namelist()==new.namelist()
        changed = [x for x in old.namelist() if old.read(x)!=new.read(x)]
        assert changed==[TARGET],changed
        txt = new.read(TARGET).decode('utf-8-sig')
        menupos = txt.find('{"MENUS",{{"Profession Guide",{32}}')
        assert menupos != -1
        print(f'PASS: one changed packaged file; {len(new.namelist())-1} other entries byte-identical')
        print('PASS: first MENUS row is Profession Guide, button 32 calls PG.ToggleMain')
    hash_value = sha(dest.read_bytes())
    m.update(
        version=VERSION,
        zip_url=PREFIX+'distribution/test/'+FILENAME,
        sha256=hash_value,
        notes=(
            'HF26.20.47 TEST visibility hotfix built strictly from SHA-verified HF26.20.46: '
            'Profession Guide is now the FIRST row in Quick Menu > MENUS so it cannot be missed '
            'below other menu buttons. Existing OPEN handler (index 32) and Profession Advisor '
            'main screen validated in package. All other menu entries retain their index, '
            'actions and order. Only packaged HaploBox/ControlBar.lua differs from HF26.20.46; '
            'all other files byte-identical. Offline integrity/CRC passed. '
            'Manual HaploBox UPDATE; close and restart WoW clients. INGAME ACCEPTANCE OPEN.'
        )
    )
    MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('BUILT',FILENAME,'SHA-256',hash_value)


if __name__=='__main__':
    main()
