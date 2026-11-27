# HF26.20.53 TEST — TEAM-01

Base: HF26.20.52 TEST archive; base SHA-256 verified against its manifest. Original 165 entries retained, only TOC replaced; registry and notes added (167 entries). New registry module SHA-256: 758bc16302574e6ca3d773eb0a96264b7e7ca2462a8830c2e39ff79f0d281097.

Local Lua 5.4 stub simulation passed: login, membership, leader change, trusted spec, invalid sender/payload, level, offline/return, role, read-only copies, talent fallback, persistence on leaving party, slash routing. No actual WoW runtime test yet. Team membership is current party (including guests); spec messages use existing trusted HB4EX transport. No raid support in this foundation. Other modules are not migrated yet; API is available via HaploBox.CharacterRegistry.

In-game: install on all clients, run `/hb registry`, form party, switch leader, switch role, level up, leave/rejoin and reload. Check no Lua errors, normal UI, and current vs last-known specs.
