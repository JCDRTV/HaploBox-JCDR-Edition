#!/usr/bin/env python3
"""Safely bundle the Phase 1 Profession Guide into the existing HaploBox TEST ZIP.

The updater installs only the HaploBox directory, so a separate AddOns folder in
another ZIP would NOT get installed. This script adds just three Lua files under
HaploBox/ProfessionGuide and registers them at the end of HaploBox.toc.

The current full packaged TEST ZIP, NOT the stale repository-root sources, is
always the baseline. All unrelated packaged file contents are preserved.
"""
from __future__ import annotations
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlparse
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[2]
TEST = ROOT / 'distribution' / 'test'
PARENT = ROOT / 'distribution' / 'profession-guide'
MANIFEST = TEST / 'manifest.json'
COMPANION = PARENT / 'HaploBox_Profession_Guide_Fase1_TEST.zip'
BASE_VERSION = 'HF26.20.44'
NEW_VERSION = 'HF26.20.45'
NEW_NAME = 'HaploBox_HF26.20.45_Profession_Guide_Fase1_TEST.zip'
NEW_PACKAGE = TEST / NEW_NAME
TOC_PATH = 'HaploBox/HaploBox.toc'
MODULES = ('Data.lua', 'Core.lua', 'UI.lua')
REPO_RAW_PREFIX = 'https://raw.githubusercontent.com/JCDRTV/HaploBox-JCDR-Edition/main/'


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def update_toc(content: bytes) -> bytes:
    txt = content.decode('utf-8-sig')
    newline = '\r\n' if '\r\n' in txt else '\n'
    # Phase 1 is an internal module of the existing HaploBox addon. Saved
    # variables must be declared on the parent .toc, not a nested .toc.
    found = re.search(r'(?mi)^(##\s*SavedVariables\s*:\s*)([^\r\n]*)', txt)
    if not found:
        raise ValueError('HaploBox.toc missing SavedVariables declaration')
    variables = [s.strip() for s in found.group(2).split(',') if s.strip()]
    if 'HaploBoxProfessionDB' not in variables:
        variables.append('HaploBoxProfessionDB')
    txt = txt[:found.start()] + found.group(1) + ', '.join(variables) + txt[found.end():]
    for name in MODULES:
        entry = 'ProfessionGuide/' + name
        if entry not in txt.replace('\\', '/'):
            txt = txt.rstrip('\r\n') + newline + entry + newline
    return txt.encode('utf-8')


def main() -> None:
    current = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if current.get('version') == NEW_VERSION:
        if NEW_PACKAGE.exists() and sha256(NEW_PACKAGE.read_bytes()) == current.get('sha256'):
            print(f'Already built: {NEW_VERSION}, verified SHA-256')
            return
        raise RuntimeError('Version already claims 20.45 but package digest is wrong or missing')
    if current.get('version') != BASE_VERSION or current.get('addon_folder') != 'HaploBox' or current.get('channel') != 'test':
        raise RuntimeError('Refusing to replace newer or unexpected TEST manifest: ' + str(current.get('version')))
    url = current.get('zip_url', '')
    if not url.startswith(REPO_RAW_PREFIX):
        raise RuntimeError('Unexpected base archive URL')
    path = url[len(REPO_RAW_PREFIX):]
    if not path.startswith('distribution/test/') or '..' in Path(path).parts:
        raise RuntimeError('Unexpected base archive path')
    src = ROOT / path
    original = src.read_bytes()
    if sha256(original) != current.get('sha256'):
        raise RuntimeError('Existing TEST ZIP digest does not match manifest; refusing to package')
    if not COMPANION.is_file():
        raise RuntimeError('Missing Phase 1 companion archive')

    with ZipFile(src) as old, ZipFile(COMPANION) as helper:
        old_items = set(old.namelist())
        if TOC_PATH not in old_items:
            raise RuntimeError('Packaged HaploBox.toc not found at expected path')
        helper_prefix = 'HaploBoxProfessionGuide/'
        new_files = {}
        for name in MODULES:
            origin = helper_prefix + name
            target = 'HaploBox/ProfessionGuide/' + name
            if origin not in helper.namelist() or target in old_items:
                raise RuntimeError('Missing Phase 1 source or existing module collision: ' + name)
            new_files[target] = helper.read(origin)
        with ZipFile(NEW_PACKAGE, 'w') as out:
            for info in old.infolist():
                data = old.read(info.filename)
                if info.filename == TOC_PATH:
                    data = update_toc(data)
                out.writestr(info, data)
            for filename, content in new_files.items():
                out.writestr(filename, content, compress_type=ZIP_DEFLATED, compresslevel=9)

    # Structural/content regression checks: only the TOC may differ among old
    # entries; the three added files must match the input ZIP exactly.
    with ZipFile(src) as old, ZipFile(NEW_PACKAGE) as built, ZipFile(COMPANION) as helper:
        assert built.testzip() is None, 'Built ZIP failed CRC verification'
        assert len(built.namelist()) == len(old.namelist()) + len(MODULES)
        for name in old.namelist():
            if name != TOC_PATH:
                assert sha256(old.read(name)) == sha256(built.read(name)), f'Changed existing file: {name}'
        toc = built.read(TOC_PATH).decode('utf-8-sig').replace('\\', '/')
        assert 'HaploBoxProfessionDB' in toc
        for name in MODULES:
            dest = 'HaploBox/ProfessionGuide/' + name
            assert built.read(dest) == helper.read('HaploBoxProfessionGuide/' + name)
            assert 'ProfessionGuide/' + name in toc
        print('PASS: untouched old files byte-identical, three new modules, SavedVariables, toc load order and ZIP CRC')
    new_hash = sha256(NEW_PACKAGE.read_bytes())
    updated = dict(current)
    updated.update({
        'version': NEW_VERSION,
        'zip_url': REPO_RAW_PREFIX + 'distribution/test/' + NEW_NAME,
        'sha256': new_hash,
        'notes': (
            'HF26.20.45 Profession Guide Phase 1 TEST built strictly from the verified HF26.20.44 '
            'packaged TEST ZIP. Adds integrated Profession Advisor main window, compact Profession Run, '
            'nine profession tiles, individual skill scan and party skill sync. '
            'Existing HaploBox, Dungeon Advisor, Dungeon Run, Party Pawn, Weapon Sets, Baganator '
            'integration and macros preserved byte-identically; only parent TOC metadata/load list '
            'changes and three ProfessionGuide Lua files added. '
            'Verified leveling recipes, material counts, party bags/banks and BS/LW/ENG/TAIL/ALCH '
            'NEED indicators are intentionally not active in Phase 1. Offline archive checks PASS. '
            'Manual HaploBox UPDATE (existing one-click updater) only. INGAME ACCEPTANCE OPEN.'
        ),
    })
    MANIFEST.write_text(json.dumps(updated, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('Ready: ' + NEW_NAME + ' (' + str(NEW_PACKAGE.stat().st_size) + ' bytes)')
    print('SHA-256: ' + new_hash)


if __name__ == '__main__':
    main()
