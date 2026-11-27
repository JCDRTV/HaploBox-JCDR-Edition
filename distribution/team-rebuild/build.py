"""Build phase 1 from the exact .55 package, preserving legacy payloads."""
import hashlib
from copy import copy
import json
import re
from pathlib import Path, PurePosixPath
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "distribution/team-rebuild"
BASE = ROOT / "distribution/test/HaploBox_HF26.20.55_Spellbook_Hotfix_TEST.zip"
BASE_SHA = "77a616b84598080938ae73a75d6faadf900b81af007ee89a3c9a60167eae92ef"
VERSION = "HF26.20.60"
FILENAME = "HaploBox_HF26.20.60_Team_Management_Rebuild_TEST.zip"
OUT = ROOT / "distribution/team-rebuild/output"
BRANCH = "dev/hf26.20.60-team-management-rebuild"
MODULES = ("Planning.lua", "PlanningUI.lua")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_paths(names):
    assert len(names) == len(set(names)), "duplicate archive paths"
    for name in names:
        path = PurePosixPath(name)
        assert not path.is_absolute() and ".." not in path.parts and "\\" not in name
        assert path.parts[0] == "HaploBox", name

def main():
    assert digest(BASE) == BASE_SHA, "unexpected base archive SHA256"
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / FILENAME
    with ZipFile(BASE) as old:
        assert old.testzip() is None
        names = old.namelist()
        validate_paths(names)
        toc_name = "HaploBox/HaploBox.toc"
        toc = old.read(toc_name).decode("utf-8-sig")
        toc, version_count = re.subn(r"(?m)^##\s*Version:\s*[^\r\n]+", "## Version: " + VERSION, toc)
        assert version_count == 1
        toc, saved_count = re.subn(r"(?m)^(##\s*SavedVariables:[^\r\n]+)", r"\1, HaploBoxPlanningDB", toc)
        assert saved_count == 1
        assert all("HaploBox/" + f not in names for f in MODULES)
        toc = toc.rstrip() + "\n\n" + "\n".join(MODULES) + "\n"
        with ZipFile(target, "w", compression=ZIP_DEFLATED) as new:
            for info in old.infolist():
                data = toc.encode("utf-8") if info.filename == toc_name else old.read(info.filename)
                new.writestr(copy(info), data)
            for filename in MODULES:
                info = ZipInfo("HaploBox/" + filename, date_time=(2026, 11, 27, 0, 0, 0))
                info.compress_type = ZIP_DEFLATED
                new.writestr(info, (SRC / filename).read_bytes())
        with ZipFile(target) as new:
            assert new.testzip() is None
            validate_paths(new.namelist())
            assert set(new.namelist()) == set(names) | {"HaploBox/" + f for f in MODULES}
            for name in names:
                if name != toc_name:
                    assert new.read(name) == old.read(name), name
            assert new.read(toc_name).decode("utf-8") == toc
            for filename in MODULES:
                assert new.read("HaploBox/" + filename) == (SRC / filename).read_bytes()
    manifest = {
        "schema": 1, "channel": "test", "version": VERSION,
        "addon_folder": "HaploBox",
        "zip_url": f"https://raw.githubusercontent.com/JCDRTV/HaploBox-JCDR-Edition/{BRANCH}/distribution/team-rebuild/output/{FILENAME}",
        "sha256": digest(target),
        "notes": "HF26.20.60 Phase 1: independent CM and TM; local planning only. In-game acceptance OPEN."
    }
    (OUT / "manifest-candidate.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("PASS: base SHA256, ZIP CRC, TOC, added modules, byte-identical legacy payloads")
    print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    main()
