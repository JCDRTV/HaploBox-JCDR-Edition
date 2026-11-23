#!/usr/bin/env python3
"""Repair the actual packaged HaploBox.toc version used by the Windows updater."""
import hashlib, json, re
from pathlib import Path
from zipfile import ZipFile

root = Path(__file__).resolve().parents[2]
test = root / "distribution/test"
mp = test / "manifest.json"
m = json.loads(mp.read_text(encoding="utf-8"))
OLD, NEW = "HF26.20.47", "HF26.20.48"
name = "HaploBox_HF26.20.48_Profession_Guide_Updater_Fix_TEST.zip"
prefix = "https://raw.githubusercontent.com/JCDRTV/HaploBox-JCDR-Edition/main/"
out = test / name
sha = lambda b: hashlib.sha256(b).hexdigest()

if m.get("version") == NEW:
    if out.exists() and sha(out.read_bytes()) == m.get("sha256"):
        print("Previously released, SHA256 verified")
        raise SystemExit(0)
    raise RuntimeError("Already points to new version without matching ZIP")
if m.get("version") != OLD or m.get("channel") != "test":
    raise RuntimeError("Unexpected release baseline: " + str(m.get("version")))
if not m["zip_url"].startswith(prefix + "distribution/test/"):
    raise RuntimeError("Unexpected archive source")
source = root / m["zip_url"][len(prefix):]
if sha(source.read_bytes()) != m["sha256"]:
    raise RuntimeError("Baseline checksum mismatch")

with ZipFile(source) as z:
    paths = z.namelist()
    assert "HaploBox/HaploBox.toc" in paths
    assert "HaploBox/ProfessionGuide/UI.lua" in paths
    toc = z.read("HaploBox/HaploBox.toc")
    bom = toc.startswith(b"\xef\xbb\xbf")
    text = toc.decode("utf-8-sig")
    newline = "\r\n" if "\r\n" in text else "\n"
    text = text.replace("\r\n", "\n")
    pattern = r"(?m)^(##\s*Version\s*:\s*)([^\r\n]*)$"
    matching = list(re.finditer(pattern, text))
    assert len(matching) == 1, "Expected one ## Version field"
    print("BASE packaged TOC version:", repr(matching[0].group(2)))
    text = re.sub(pattern,lambda hit:hit.group(1)+NEW,text,count=1)
    assert "HaploBoxProfessionDB" in text
    for file in ("Data.lua","Core.lua","UI.lua"):
        assert "ProfessionGuide/"+file in text.replace("\\", "/")
    if newline == "\r\n": text=text.replace("\n","\r\n")
    replacement=(b"\xef\xbb\xbf" if bom else b"")+text.encode("utf-8")
    with ZipFile(out,"w") as newzip:
        for entry in z.infolist():
            newzip.writestr(entry, replacement if entry.filename=="HaploBox/HaploBox.toc" else z.read(entry.filename))
with ZipFile(source) as orig, ZipFile(out) as fixed:
    assert fixed.testzip() is None, "ZIP CRC failed"
    assert orig.namelist()==fixed.namelist()
    changed=[n for n in orig.namelist() if orig.read(n)!=fixed.read(n)]
    assert changed==["HaploBox/HaploBox.toc"], changed
    assert len([x for x in fixed.namelist() if not x.endswith("/")])>=15
    assert all(x.startswith("HaploBox/") and ".." not in Path(x).parts and len(x)<=240 for x in fixed.namelist())
    assert NEW in fixed.read("HaploBox/HaploBox.toc").decode("utf-8-sig")
    print("PASS: updater ZIP, TOC, CRC, changed-files tests")

# Both old and fixed updater scripts are in repo. The fixed installer supports three-part versions.
with ZipFile(test/"HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip") as updater:
    code=updater.read("HaploBox-Updater.ps1").decode("utf-8-sig")
    line=next(s for s in code.splitlines() if "$version -notmatch" in s)
    assert r"(\.[0-9]{1,3})?" in line
    assert NEW in fixed.read("HaploBox/HaploBox.toc").decode("utf-8-sig")
    print("PASS: corrected Windows updater accepts 3-component version syntax")

m.update(
    version=NEW,
    zip_url=prefix+"distribution/test/"+name,
    sha256=sha(out.read_bytes()),
    notes=("HF26.20.48 TEST corrects mismatched packaged HaploBox.toc version. The "
           "manual Windows updater rejects archive versions not printed in the TOC. "
           "HF26.20.47 had wrong TOC version. With the VERSION_HOTFIX Windows updater "
           "this release is installable. Original two-component-only updater requires "
           "one-time reinstall from HaploBox_Manual_Updater_VERSION_HOTFIX_TEST.zip. "
           "Only packaged HaploBox.toc differs from HF26.20.47; all other files are "
           "byte-identical. Profession Guide is first in Quick Menu > MENUS. "
           "Offline acceptance checks passed. INGAME ACCEPTANCE OPEN.")
)
mp.write_text(json.dumps(m,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print("RELEASE",NEW,"ZIP",out.stat().st_size,"SHA256",m["sha256"])
