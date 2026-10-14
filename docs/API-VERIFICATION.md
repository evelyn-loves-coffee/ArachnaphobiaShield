# API verification record — WoW Forever 1.60.1

M1 exit criteria. Compiled 2026-10-13 from in-client probe rounds SBG1–SBG4
(full probe lines in [PLAN.md §12](PLAN.md#12-m1-in-client-verification-scripts))
and the Warcraft Wiki per-client API table
(`warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic`, current as of
2026-10-06, with an explicit **Forever 1.60.1 (70235) Beta** column).

## Environment (confirmed in-client)

| Fact | Value | Source |
|---|---|---|
| Build | `GetBuildInfo()` → `"1.60.1"`, `"70374"`, `"Oct 12 2026"`, `"16001"` (four strings, modern signature) | SBG2 |
| **TOC interface number** | **16001** (4th `GetBuildInfo()` value; matches `Spoken_Books.toc` listing `16001`) | SBG2 |
| Lua | **5.1** (`_VERSION` = "Lua 5.1"; `math.huge` present; `table.unpack`/`table.pack` absent; global `unpack` present) | SBG2 |
| Locale | `enUS` | SBG2 |
| Codebase generation | **Modern** (post-3.0 layout: `Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua` in error stack) with a **reduced** API set | SBG1 error stack |
| Screen | `GetEffectiveScreenInfo()` → 1772.3 × 1181.5 (UI-scaled) | SBG4 |
| Camera (moot, 3D path closed) | `GetCameraZoom()` = 30; `GetCameraFOVDefaults()` = 90, 50, 90 | SBG4 |

## Confirmed PRESENT (in-client, this build)

`UnitName`, `GetUnitName`, `UnitLevel`, `UnitIsVisible`, `UnitIsDead`,
`UnitCanAttack`, `UnitCreatureType`, `UnitCreatureID` (→ 1504 for Young Night
Web Spider), **`UnitCreatureFamily`** (→ `("Spider", 3)` on a wild spider),
`UnitPosition` (player/party/raid only; player in Tirisfal: 2070.9, 1694.3,
z=0, map=0), `C_Timer`, `C_Map` (partial — no `PositionToScreen`),
`SlashCmdList`, `GetBuildInfo`, `GetEffectiveScreenInfo`, `GetCameraZoom`,
`GetCameraFOVDefaults`, `GetUICameraInfo` (call untested — probe had a syntax
error, irrelevant now).

Wiki-table-only (not yet probed in-client; expected per 2026-10-06 table):
`GetCursorPosition`, `UnitClass`, `UnitFactionGroup`, `UnitIsUnit`,
`GetScreenWidth`/`GetScreenHeight`, `PlaySoundFile`, `GetPhysicalScreenSize`.
→ Probe round SBG5 (PLAN.md §12.8) covers these.

## Confirmed ABSENT (in-client, this build)

`WorldFramePoint3D`, `GetUnitPosition`, `GetUnitFamily`, `IsPlayerUnit`,
`GetNumAuras`, `GetUnitAura`, `GetScreenSize`, `C_Map.PositionToScreen`,
`GetUnitWorldPosition`, `GetCameraPosition` (global), `GetViewingInfo`.

## Confirmed DEAD ENDS (tested)

- **`ClosestUnitPosition(1504)` → nil** while standing in Tirisfal Glades
  (a starting zone) with the spider targeted. Wiki: "Only works for mobs in
  the starting zones" — the gate rejects it where the spiders live. Even a
  working result in Elwynn would not serve the spider use case (Elwynn has no
  spiders). → **3D-follow cover is infeasible on this client; UI-anchored
  design is final (PLAN.md §3.0).** `C_Map.ScreenToPosition` also absent.

## Spider data (reference specimen)

- Name: "Young Night Web Spider" — level 2 — Tirisfal Glades
- `UnitCreatureID` = **1504**; `UnitCreatureType` = "Beast" (too broad for
  detection); `UnitCreatureFamily` = **("Spider", 3)** ← primary detection
  signal.

## Design consequences (final)

1. Detection: `select(2, UnitCreatureFamily(unit)) == 3` primary; name
   patterns `{"Spider","Gloomweaver"}` + user `extraNames` fallback.
2. No spider world position → no projection → covers are UI-anchored:
   hover shield (cursor), parkable shields (draggable), blind mode, frame
   cover.
3. Player detection: `UnitClass(unit) ~= nil` (replaces absent
   `IsPlayerUnit`).
4. Lua 5.1: never use `//`, `goto`, `table.pack`, bitwise ops.
5. Slash commands: `SlashCmdList` + `CHAT_COMMAND` (classic `SLASH_` vars not
   relied on). Events themselves remain unconfirmed in-client → `OnUpdate`
   polling is the primary refresh mechanism (PLAN.md §3.4).
