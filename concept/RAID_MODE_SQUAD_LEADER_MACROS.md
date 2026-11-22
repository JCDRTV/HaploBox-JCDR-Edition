# CONCEPT — Raid Mode: squad-leader targeting for HaploBox macros

**Status:** CONCEPT ONLY — not implemented; no HF version or TEST release.
**Requested:** 22 November 2026.
**Current baseline:** HaploBox JCDR Edition HF26.20.22 TEST; existing Party / BOX ON behavior remains unchanged.

## Goal

When Raid Mode is intentionally enabled, follower targeting macros should assist **the raid squad leader assigned to that follower's raid subgroup**, **not** `party1` and not automatically the overall raid leader.

## Proposed behavior

- Configure a designated **Squad Leader** for each relevant raid subgroup (5-player squad) from the actual raid roster.
- Each follower's Smart Spell attack/targeting macros resolve its own squad's **assigned leader**.
- Party Mode retains the existing `/assist party1` behavior.
- Raid Mode uses the chosen squad leader's stable character identity and a macro-valid target reference; never depend on a hard-coded `party1` or a `raidN` slot that may change when the raid roster changes.
- Switching Party ↔ Raid Mode must be explicit and show which mode and leader currently control the macro profile.
- If the chosen squad leader is absent, changed, duplicated/ambiguous or unresolved, **warn and require a valid selection** instead of silently falling back to `party1` or the global raid leader.
- Preserve user-edited macros. Do not rewrite macro bodies during combat. Any secure-action/roster limitation must be validated against the WoW Forever client before implementation.
- A squad leader is a **HaploBox-designated follower target**, which may be different from Blizzard's global raid leader/assistant.
- No automatic casts, gear changes, or background updater checks.

## Proposed UX

Raid Mode concept UI:
1. Toggle Party Mode / Raid Mode.
2. Show raid subgroups and let the user assign a Squad Leader for each.
3. Preview macro target: `Raid Squad N → <selected character>`.
4. Mark each squad READY or NEED LEADER; only allow profile synchronization when references are valid.
5. Clearly indicate which followers will change and what macro target is being applied.

## Acceptance criteria (future ingame tests)

1. Assign two different squad leaders to two different raid subgroups; followers assist their **own** chosen squad leader, not `party1` or the global raid leader.
2. Reorder the raid roster; associations still target the intended named character or explicitly become unresolved and warn (never silently swap targets).
3. Change a squad leader; macros adopt the new target only through an authorized and combat-safe update.
4. Leave raid / disable Raid Mode: Party Mode retains the established `/assist party1` behavior.
5. Confirm that personal macros, protected Mini UI/Smart Follow/Party Pawn, and bindings are preserved.
6. Verify behavior in and out of combat; no prohibited protected macro modification in combat.

## Non-goals for the concept stage

- No changes to current macro generator or HF26.20.22 source.
- No new TEST ZIP, manifest/version change, or updater publication.
- No automatic discovery of squad leaders from raid leadership roles.
