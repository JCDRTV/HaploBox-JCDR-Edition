# HaploBox Profession Guide – Phase 1 TEST

This directory contains the stand-alone tested prototype HaploBox_Profession_Guide_Fase1_TEST.zip.

## One-click update integration

The existing **HaploBox UPDATE** shortcut downloads only the complete HaploBox addon folder; a second companion ZIP would be ignored. The release build script therefore merges three Phase 1 Lua files into the current SHA-256-verified complete TEST ZIP and updates HaploBox.toc. It publishes HF26.20.45 on the existing distribution/test/manifest.json channel.

Only HaploBox.toc and these newly added files change inside the archive:

- HaploBox/ProfessionGuide/Data.lua
- HaploBox/ProfessionGuide/Core.lua
- HaploBox/ProfessionGuide/UI.lua

All other files from HF26.20.44 remain byte-identical when extracted. The build refuses to overwrite a newer TEST manifest or a ZIP with mismatched hash.

## Usage

Click the existing Windows **HaploBox UPDATE** shortcut (no background polling). Restart all five WoW clients afterward. Open /hb professions or /hbprof.

Phase 1 does not include recipe routes, bags/banks, or profession NEED tooltip tags. Ingame acceptance remains open.
