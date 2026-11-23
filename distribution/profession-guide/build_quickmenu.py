#!/usr/bin/env python3
"""Release HF26.20.46: integrate Profession Advisor into the existing Quick Menu.

Patch only the packaged ControlBar.lua of the SHA-verified HF26.20.45
complete release. Preserve all other addon files byte-for-byte. Refuse newer
manifests, missing anchors, or incomplete profession modules.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
TEST = ROOT / "distribution" / "test"
MANIFEST = TEST / "manifest.json"
BASE_VERSION = "HF26.20.45"
VERSION = "HF26.20.46"
NAME = "HaploBox_HF26.20.46_Profession_Guide_QuickMenu_TEST.zip"
DEST = TEST / NAME
TARGET = "HaploBox/ControlBar.lua"
PREFIX = "https://raw.githubusercontent.com/JCDRTV/HaploBox-JCDR-Edition/main/"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def replace_one(content, old, new, label):
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, found {count}")
    return content.replace(old, new, 1)


def patch(data):
    had_bom = data.startswith(b"\xef\xbb\xbf")
    original = data.decode("utf-8-sig")
    newline = "\r\n" if "\r\n" in original else "\n"
    normalized = original.replace("\r\n", "\n")

    insert = (
        '    -- Profession Advisor integrates with the existing Quick Menu. No secure frames changed.\n'
        '    mkButton(32,"PROFESSION GUIDE",function()\n'
        '        local PG = HaploBoxProfessionGuide\n'
        '        if PG and PG.ToggleMain then PG.ToggleMain() end\n'
        '    end)\n'
    )
    normalized = replace_one(
        normalized,
        '    mkButton(30,"HAPLO LOOT",function()',
        insert + '    mkButton(30,"HAPLO LOOT",function()',
        "profession button",
    )
    normalized = replace_one(
        normalized,
        '{"Haplo Loot",{30}},{"Weapon Sets",{31}}},28},',
        '{"Haplo Loot",{30}},{"Weapon Sets",{31}},{"Profession Guide",{32}}},28},',
        "MENUS section",
    )
    normalized = replace_one(
        normalized,
        "for i=1,12 do\n            local bg=flyout:CreateTexture",
        "for i=1,13 do\n            local bg=flyout:CreateTexture",
        "visible rows",
    )
    normalized = replace_one(
        normalized,
        "    if buttons[31] then color(buttons[31],OFF) end",
        "    if buttons[31] then color(buttons[31],OFF) end\n"
        "    if buttons[32] then color(buttons[32],OFF) end",
        "button reset",
    )
    normalized = replace_one(
        normalized,
        'for _,idx in ipairs({21,23,24}) do stateButton(idx,"OPEN",BLUE) end',
        'for _,idx in ipairs({21,23,24,32}) do stateButton(idx,"OPEN",BLUE) end',
        "OPEN status",
    )
    assert normalized.count('{"Profession Guide",{32}}') == 1
    assert normalized.count('mkButton(32,"PROFESSION GUIDE"') == 1
    assert normalized.count("for i=1,13 do") == 1
    # Do not change the existing menu section's six entries or their identifiers.
    for preserved in ('{"Macro Menu",{21}}', '{"HaploBox Keybindings",{23}}',
                      '{"UI Layout",{24}}', '{"Lyra Gathering Map",{29}}',
                      '{"Haplo Loot",{30}}', '{"Weapon Sets",{31}}'):
        assert preserved in normalized, preserved
    if newline == "\r\n":
        normalized = normalized.replace("\n", "\r\n")
    return (b"\xef\xbb\xbf" if had_bom else b"") + normalized.encode("utf-8")


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("version") == VERSION:
        if DEST.is_file() and digest(DEST.read_bytes()) == manifest.get("sha256"):
            print(f"ALREADY PUBLISHED: {VERSION}")
            return
        raise RuntimeError("Manifest claims HF26.20.46 but package file or checksum mismatch")
    if manifest.get("version") != BASE_VERSION or manifest.get("channel") != "test":
        raise RuntimeError("Unexpected TEST baseline version: " + str(manifest.get("version")))
    if manifest.get("addon_folder") != "HaploBox":
        raise RuntimeError("Unexpected addon folder")
    remote = manifest["zip_url"]
    if not remote.startswith(PREFIX + "distribution/test/"):
        raise RuntimeError("Unexpected source URL")
    source = ROOT / remote[len(PREFIX):]
    original_bytes = source.read_bytes()
    if digest(original_bytes) != manifest.get("sha256"):
        raise RuntimeError("BASELINE HASH MISMATCH")

    with ZipFile(source) as old:
        names = old.namelist()
        if TARGET not in names or len(names) != len(set(names)):
            raise RuntimeError("Missing ControlBar or duplicate archive entries")
        for name in ("Data.lua", "Core.lua", "UI.lua"):
            if "HaploBox/ProfessionGuide/" + name not in names:
                raise RuntimeError("Missing integrated Profession Guide " + name)
        updated = patch(old.read(TARGET))
        with ZipFile(DEST, "w") as new:
            for info in old.infolist():
                new.writestr(info, updated if info.filename == TARGET else old.read(info.filename))

    with ZipFile(source) as old, ZipFile(DEST) as new:
        assert new.testzip() is None, "ZIP CRC failure"
        assert new.namelist() == old.namelist(), "Archive file list changed unexpectedly"
        changed = [name for name in old.namelist() if old.read(name) != new.read(name)]
        assert changed == [TARGET], "Unexpected package changes: " + repr(changed)
        result = new.read(TARGET).decode("utf-8-sig")
        assert '"Profession Guide",{32}' in result
        assert "for i=1,13 do" in result
        assert "PG and PG.ToggleMain then PG.ToggleMain()" in result
        print(f"PASS: {len(new.namelist())-1} packaged entries byte-identical; only ControlBar.lua changed")
        print("PASS: 13 menu rows; menu item 32 calls existing Profession Advisor")
        print("PASS: archive CRC and saved original module load list")

    sha = digest(DEST.read_bytes())
    manifest.update(
        version=VERSION,
        zip_url=PREFIX + "distribution/test/" + NAME,
        sha256=sha,
        notes=(
            "HF26.20.46 TEST hotfix built exclusively from SHA-verified HF26.20.45 complete "
            "Profession Guide TEST release. Adds Profession Guide in Quick Menu > MENUS "
            "with OPEN button (native menu index 32, existing Profession Advisor main screen). "
            "Preserves all previous Quick Menu choices and actions. Updates row count 12 to 13. "
            "All files except HaploBox/ControlBar.lua are byte-identical to HF26.20.45. "
            "Existing Dungeon Advisor/Run, Party Pawn, Baganator, Weapon Sets, Macros, "
            "Profession Guide files, saved variables and party sync are untouched. "
            "Archive CRC / manifest SHA-256 verified offline. "
            "Manual HaploBox UPDATE only. INGAME ACCEPTANCE OPEN."
        ),
    )
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"BUILT {NAME} ({DEST.stat().st_size} bytes)")
    print("SHA-256 " + sha)


if __name__ == "__main__":
    main()
