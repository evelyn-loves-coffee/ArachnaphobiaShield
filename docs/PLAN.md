# Spiders Be Gone — Arachnaphobia Addon

**Plan of record for the addon. Read this before writing code.**

- Repo: `SpidersBeGone-ArachnaphobiaAddon`
- Target client: **World of Warcraft Forever** — official, original, classic-based
  (1.x line) client, version **1.60.1**, with new content. No content or APIs from
  WoW 2.x or later exist on this client.
- Working copy: `~/Apps/SpidersBeGone`
- In-game install path (verified): `.../World of Warcraft/_classic_beta_/Interface/AddOns/`
  (reachable locally via the `~/Apps/wow/AddOns` symlink).

---

## 1. Purpose

For players with arachnaphobia: when a spider is the player's target (or otherwise
a "tracked" unit), a **screen-anchored UI element** is projected onto the spider's
3D position every frame and visually covers the model.

Hard constraints:

1. **UI-layer only.** No model swaps, no asset replacement, no file modification of
   game data, no WMO/model edits. Everything is `CreateFrame` + `SetPoint` +
   `SetTexture` on top of the 3D world.
2. **Dynamic.** The cover is re-projected from world coordinates every frame, so it
   tracks the spider, the camera, and perspective (near = big, far = small).
3. **Classic-generation API only.** The code must run on the 1.x UI API (Lua 5.0,
   old-style unit/aura/event APIs). Nothing introduced in 2.x/3.0+ may be used.

## 2. Target environment & API surface

Facts (verified from the local installation):

- Client install: `World of Warcraft/_classic_beta_/Interface/` (Steam/Proton prefix).
- Addons are classic-style: one folder in `Interface/AddOns/`, one `.toc` whose
  filename equals the folder name and `## Title`, files listed in the `.toc`.
- Addon scripting is **Lua 5.0**: no `//`, no `table.pack`, no `goto`, no bitwise
  ops, no `math.huge`. `^` works, `unpack` exists, `#` works.

APIs this plan relies on (classic-era):

| API | Use | Status |
|---|---|---|
| `GetUnitPosition(unit)` → x, y, z (z = up) or nil | world anchor | classic ✓ (self-test in M1) |
| `WorldFramePoint3D(x, y, z)` → sx, sy, isBehind | world→screen projection | classic ✓ (self-test in M1) |
| `GetUnitFamily(unit)` → e.g. "Spider" | primary spider detection | 1.12-era (self-test in M1) |
| `UnitCreatureType(unit)` | secondary detection | 1.1x-era (self-test in M1) |
| `UnitIsVisible`, `UnitIsDead`, `UnitCanAttack`, `UnitLevel`, `UnitName`, `IsPlayerUnit` | tracking/detection guards | classic ✓ |
| `GetBuildInfo()` → major, minor, patch, build | interface-number check | classic ✓ |
| Events: `PLAYER_ENTERING_WORLD`, `UNIT_TARGET`, `UNIT_PET`, `UNIT_HEALTH`, `PARTY_UPDATE`, `RAID_UPDATE`, `UPDATE_AURAS` | refresh triggers | classic ✓ |
| `SLASH_` vars + `CHAT_COMMAND` event | slash commands | classic ✓ (note: `SlashCmdList` is 3.0+ — do **not** use) |
| `CreateFrame`, `SetPoint`, `SetSize`, `SetTexture`, `SetFrameStrata`, `SetClampRect`, `CheckBox`, `Slider`, `EditBox`, `SetBackdrop`, `PlaySoundFile`, `StaticPopup`? (no) | UI | classic ✓ |
| `SavedVariables` in `.toc` | persistence | classic ✓ |

Known **absences** (do not use): `C_*` namespaces, `C_Timer`, `SlashCmdList`,
`ADDON_LOADED`/`ADDON_DISABLED` events, `UNIT_FACTION`, `partyNtarget` unit
tokens, any unit-enumeration API.

> **M1 gate:** the exact `## Interface:` number for the 1.60.1 client is unknown
> until we run `/run print(GetBuildInfo())` in-game. Until then the `.toc` is
> blocked. A mismatched interface number means the client lists the addon as
> out-of-date and it will not load.

### Unit-token limitation (design-defining)

The 1.x API cannot enumerate arbitrary on-screen creatures. We can only query
units we hold a **unit token** for. Classic tokens usable here:

`player, pet, focus, target, targettarget, partyleader, party1-4, raid1-20,
arena1-4, mouseover`

Therefore the addon covers spiders among: **target, targettarget, focus, pet,
party1-4, raid1-20, mouseover** (each group individually toggleable). This is the
single biggest functional constraint and it is accepted: the arachnophobe pain
points are "I am fighting this spider" and "I am hovering over that spider" —
both covered.

## 3. How it works (architecture)

```
            ┌─────────────── Core.lua (orchestration) ───────────────┐
            │  init, lifecycle, driver frame OnUpdate, debug ring    │
            └──────┬──────────────┬───────────────┬──────────────────┘
                   │              │               │
            ┌──────▼─────┐ ┌──────▼─────┐ ┌───────▼──────┐
            │  Units.lua │ │ Project.lua│ │  Cover.lua   │
            │ tracked    │ │ world→     │ │ frame pool,  │
            │ unit list +│ │ screen     │ │ per-unit     │
            │ spider     │ │ (pure fns) │ │ cover frames │
            │ predicate  │ │            │ │ + label      │
            └────────────┘ └────────────┘ └──────────────┘
            ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
            │  Config.lua  │ │  UI.lua      │ │  Slash.lua   │
            │ settings     │ │ config       │ │ /spider      │
            │ schema, load │ │ window       │ │ parser       │
            │ + migrate    │ │ (vanilla    │ │              │
            │ + validate   │ │ widgets)    │ │              │
            └──────────────┘ └──────────────┘ └──────────────┘
```

### 3.1 Tracking (Units.lua)

- The **tracked set** = union of enabled groups → list of unit tokens (≤ 24).
- **Spider predicate** (single, DRY, used for every unit):

  1. `IsPlayerUnit(unit)` → false (never cover players);
  2. `GetUnitFamily(unit) == "Spider"` **or** family ∈ `settings.families`;
  3. OR `UnitCreatureType(unit)` ∈ `settings.families` (fallback if family API
     is absent on this build);
  4. OR `UnitName(unit)` ∈ `settings.extraNames` (data-driven escape hatch for
     the new content's spiders whose family string we haven't confirmed);
  5. level window `settings.minLevel..settings.maxLevel`;
  6. if `settings.requireHostile` and `UnitCanAttack(unit, "player")` → false.

- Tracked list is rebuilt on events (`UNIT_TARGET`, `UNIT_PET`, `PARTY_UPDATE`,
  `RAID_UPDATE`, `PLAYER_ENTERING_WORLD`), not per frame.

### 3.2 Projection (Project.lua) — pure functions, no frame state

For a unit at world position `(wx, wy, wz)` (from `GetUnitPosition`, foot
anchor):

1. `sx, sy, behind = WorldFramePoint3D(wx, wy, wz)` — foot in screen space
   (UIParent coordinates, origin bottom-left).
2. `sx2, sy2, behind2 = WorldFramePoint3D(wx, wy, wz + h)` — estimated model top,
   where `h` ≈ `max(settings.minModelHeight, UnitLevel(unit) * 0.12)` (classic
   spiders scale with level; tunable).
3. If both in front: apparent height `H = max(1, sy2 - sy)`; frame size
   `S = clamp(H * settings.sizeScale, settings.minSize, settings.maxSize)`;
   anchor = midpoint `(sx+sx2)/2, (sy+sy2)/2` plus `yOffset * H`.
4. If top is behind/nil: fall back to `S = clamp(settings.fallbackK / dist,
   minSize, maxSize)` with `dist` from player↔unit positions.
5. Hide if `behind` (foot), positions nil, `UnitIsVisible` false, or
   (`UnitIsDead` and not `settings.coverCorpses`).

This two-point projection gives correct perspective scaling for free.

### 3.3 Cover rendering (Cover.lua)

- **Frame pool**: N frames (N = max tracked units = 24) pre-created at load —
  zero allocation in the per-frame loop. Each cover = Frame + child Texture
  (solid color + alpha) + optional thin border + optional `GameFontHighlightSmall`
  name label above it.
- Strata: `HIGH` (above MEDIUM default UI, below DIALOG; the 3D world is always
  behind all UI strata, so any stratum covers the model — HIGH chosen so the
  shield sits over action bars etc.). Frame level within stratum by distance
  (nearer = drawn last) so covers don't clip each other badly.
- Per frame, per tracked spider: `SetPoint("CENTER", UIParent, "BOTTOMLEFT",
  cx, cy)` + `SetSize(S, S)` (v1 square; v1.1 candidate: 2:1 wide rect, spiders
  are flat). Skip the `SetPoint`/`SetSize` calls if values changed by < 1px
  (epsilon cache) — avoids useless layout work.
- One **driver frame** owns the single `OnUpdate`; individual covers have no
  timers.

### 3.4 Lifecycle

- All `.lua` files run at client load (character-select time). No `ADDON_LOADED`
  in 1.x: initialize structures at file load, arm the driver on
  `PLAYER_ENTERING_WORLD`, reset all covers on logout events.
- Guarded init (idempotent), `settings.enabled` gate checked per frame (cheap).
- `/reload` safe: everything rebuilds from `SavedVariables` + defaults.

## 4. What the addon must contain (file inventory)

Repo layout (the `SpidersBeGone/` folder is the installable addon):

```
SpidersBeGone-ArachnaphobiaAddon/
├── README.md                  install + usage + config reference
├── LICENSE                    MIT
├── .gitignore
├── docs/
│   └── PLAN.md                this file
└── SpidersBeGone/             ← copy this folder to Interface/AddOns/
    ├── SpidersBeGone.toc      Interface (TBD M1), Title "Spiders Be Gone",
    │                          Notes, Version, Author, IconTexture,
    │                          SavedVariables: SBeGoneSettings
    ├── icon.tga               original 32x32 art (no Blizzard assets)
    ├── Core.lua               init/lifecycle/driver/debug ring buffer
    ├── Units.lua              tracked tokens + spider predicate
    ├── Project.lua            world→screen (pure functions)
    ├── Cover.lua              frame pool + per-frame placement
    ├── Config.lua             defaults, schema validation, load/migrate/save
    ├── UI.lua                 config window (vanilla widgets)
    ├── Slash.lua              /spider parser (SLASH_ + CHAT_COMMAND)
    └── Locales.lua            enUS strings (i18n stub for later)
```

### 4.1 Settings (`SBeGoneSettings`, versioned)

```lua
{
  version = 1,
  enabled = true,
  color = { r=0.55, g=0.12, b=0.12 },  opacity = 0.85,
  sizeScale = 1.0,   minSize = 8,      maxSize = 800,
  yOffset = 0.0,     minModelHeight = 1.0, fallbackK = 600,
  coverCorpses = true,
  showName = false,
  track = { target=true, targettarget=true, focus=true, pet=true,
            party=true, raid=true, mouseover=true },
  families = { ["Spider"]=true },
  extraNames = {},
  requireHostile = false, minLevel = 1, maxLevel = 99,
  minimapButton = true,
  debug = false,
}
```

- Load: `loadstring("return " .. tostring(SBeGoneSettings))`-style deep copy is
  **not** used — plain table traversal with per-key type checks; unknown/missing
  → default; corrupt → full reset + chat message. (No `loadstring` of untrusted
  data at all.)
- All UI inputs clamped to their legal ranges on write (auditability).

### 4.2 Config window (UI.lua)

Draggable ~500x480 `Frame`, `SetBackdrop`, vanilla widgets only:
Enable checkbox; cover color (R/G/B 0-255 edit boxes or 3 sliders) + opacity
slider; size / min / max sliders; offset slider; corpse + name-label checkboxes;
track-group checkboxes; hostile-only checkbox; level range edit boxes;
`Reset defaults` / `Close` buttons. Changes autosave (idempotent `Config.Save`),
take effect next frame.

### 4.3 Slash command

`/spider` (aliases `/spiderbe`, `/sb`) — classic registration:
`SLASH_SPIDER1..3`, handler on `CHAT_COMMAND` reading `CHAT_COMMAND1`.

| cmd | effect |
|---|---|
| `on` / `off` / `toggle` | enable/disable |
| `reset` | reset settings to defaults |
| `debug` | toggle debug ring buffer |
| `hide` / `show` | temporary full hide (panic button) |
| `selftest` | print GetBuildInfo, API probes, unit-position samples |
| `help` | usage |

### 4.4 Minimap button (v1.1, optional)

32x32 button parented to `Minimap`, toggles the config window; reposition on
`MINIMAP_UPDATE_ZOOM` (verify event exists on this build; else OnUpdate poll of
`Minimap` width). Kept out of v1.0 scope.

## 5. Performance budget (details in §8 PAWS)

- Per frame: one `OnUpdate`; ≤ 24 tokens; per visible spider ≤ 2
  `WorldFramePoint3D` calls + ≤ 2 layout calls (usually 0 thanks to epsilon
  cache). No allocations in the loop (pool + preallocated scratch numbers).
- Memory: fixed (24 cover frames + textures + one 200-entry debug ring).
- Worst case (all 24 tokens are visible spiders, camera spinning): still a few
  hundred simple Lua ops/frame — negligible on the classic client.

## 6. Milestones

| # | Deliverable | Exit criteria |
|---|---|---|
| M0 | Repo + this plan | committed, pushed |
| M1 | **In-game API verification** (manual): run `/run print(GetBuildInfo())`, `/run print(WorldFramePoint3D)` etc.; record real interface number + API availability | `docs/API-VERIFICATION.md` written from a real session |
| M2 | TOC + load skeleton: `SpidersBeGone.toc`, `Core.lua`, `Config.lua`, `Slash.lua` (`help`, `toggle`, `selftest`); placeholder icon | addon loads, appears in AddOns list, `/spider help` works, `/spider selftest` prints |
| M3 | Tracker + projection + single cover (target only) | targeting a spider in Elwynn/Duskwood shows a correctly-sized, correctly-placed shield that tracks movement & camera |
| M4 | Full tracked set, frame pool, corpse/name-label options | all groups work; no per-frame allocations; debug ring buffer |
| M5 | Config window + SavedVariables polish (migrate/reset/validation) | settings survive logout/reload; corrupt SV self-heals |
| M6 | README, icon art, polish, `v1.0.0` tag | install-from-clone instructions verified end-to-end on the Proton client |

Post-v1 candidates (roadmap, not planned work): 2:1 wide cover, per-level model-
height table, other creature families, per-character settings, hotkey binding
(`Bindings.xml`), i18n locales, minimap button.

## 7. Testing & verification plan

No automated test runner exists for 1.x addons; verification is:

1. **`/spider selftest`** (in M2): prints `GetBuildInfo()`, nil-checks for
   `WorldFramePoint3D`, `GetUnitFamily`, `UnitCreatureType`, a sample
   `GetUnitPosition("player")`, and the resolved tracked-token list.
2. **Manual matrix** (M3/M4), in-game on the Proton client:
   - target a small spider (Elwynn ~5) and a large one (later zone); cover
     tracks during camera rotation and movement; size scales with distance;
   - death: cover persists on corpse (default) / hides with setting off;
   - out-of-range / behind camera: cover hidden, no error spam;
   - `/spider hide` then `show`; `/spider reset`; logout/relogin persistence;
   - UI scale change (Ctrl+` in 1.x): cover reprojects correctly next frame.
3. **Debug ring buffer** (`/spider debug`): every hide reason and projection
   failure is logged with unit token + reason string (auditability).
4. Install test: copy `SpidersBeGone/` → `~/Apps/wow/AddOns/`, character
   select, confirm enabled with no red errors in `/run print(GetError())`
   pattern (classic: check no Lua errors on login via chat `SCRIPT ERROR`).

## 8. PAWS standard review (per AGENTS.md)

Context: single-player, client-side, visual-only WoW classic addon; "agent" =
this planning/implementation agent. Confidence: High/Medium/Low.

### P — Performance (Big O, bottlenecks, memory/time)

- Per-frame cost **O(T)**, T = tracked tokens (≤ 24, fixed bound). Per visible
  spider: O(1) lookups + ≤ 2 projection calls + ≤ 2 layout calls. No per-frame
  table/string allocation (pool + scalar scratch; epsilon cache skips layout).
- Bottleneck: `WorldFramePoint3D` (view/projection math). Worst realistic case
  ≈ 48 calls/frame — negligible; classic clients run far heavier UIs.
- Memory: fixed pool (24 frames + textures), 200-entry debug ring, tiny SV
  table. Zero growth over session.
- Risks: (a) nil-position or nil-behind misuse → guarded, logged; (b) layout
  thrash from sub-pixel jitter → epsilon cache.
- Confidence: **High**.
- Path to improvement: event-driven dirty flag (skip projection entirely when
  camera + all units are static) if M3 profiling ever shows need — not planned.

### A — Auditability (input validation, least privilege, traceable errors)

- Inputs: SV load validates every key (type + range), resets corrupt data with
  a visible message; config widgets clamp on write; slash parser is a strict
  lookup (unknown → help line, never `loadstring`/`load` of user input).
- Least privilege: pure UI. No protected frames, no macros, no CLEAVE, no file
  I/O, no network, no `Secure` interaction. Nothing the game doesn't already
  render to us.
- Traceability: debug ring buffer (unit token, reason, timestamp via
  `GetTime()`); `/spider selftest` for environment; every failure path produces
  an actionable chat line, never a silent no-op.
- Risks: API availability on the 1.60.1 build unconfirmed until M1 (this is
  the main audit gap in the plan). Mitigation: M1 gate + selftest + name-list
  fallback so detection degrades gracefully.
- Confidence: **High** for design; **Medium** for API availability until M1.
- Path to improvement: numeric error codes in the ring buffer; optional
  "print ring" slash subcommand for reports.

### W — Workability (edge cases, idempotency, thread safety)

- Idempotency: guarded init; `Config.Save`/`Load` safe to call any time; driver
  frame created once (nil-check before create); `/reload` fully rebuilds state.
- Edge cases covered: foot behind camera (hide); top behind camera (fallback
  sizing); distance ≈ 0 (clamp); nil positions (hide, no error); dead unit
  (corpse setting); target/focus cleared (event rebuild); player death (covers
  persist — harmless); zone change (positions go nil → hide); UI rescale
  (reprojection next frame); borderless window (UIParent coords still valid);
  4:3/16:9 (projection is aspect-aware by construction).
- Thread safety: single-threaded Lua; all mutation inside event/OnUpdate
  callbacks; no re-entrancy (no event fired from our own handlers).
- Risks: stale corpse positions (accepted: covering a corpse is the point);
  `GetUnitFamily` returning localized strings on non-enUS locale (mitigation:
  also match via `extraNames`; v1 is enUS anyway).
- Confidence: **High**.
- Path to improvement: panic hotkey via `Bindings.xml`; "idle pause" (stop
  OnUpdate when no tracked spider visible for N seconds).

### S — Scalability (modularity, DRY, separation of concerns)

- Modules have one responsibility each; `Project` is pure (trivially
  re-testable); the spider predicate is a single function shared by every
  tracked group (DRY); detection is data-driven (`families`/`extraNames`) so
  "support a new spider type" is a data edit, not code; cover visuals isolated
  in `Cover` (swap solid→art texture later without touching projection).
- Anti-goal honored: no speculative frameworks — 9 small files, no Libs, no
  embedded third-party code (zero dependency surface).
- Risks: slight over-modularization for a single-user addon; kept in check by
  the file inventory in §4 (each file has a clear, non-overlapping role).
- Confidence: **High**.
- Path to improvement: if multi-family support lands, promote the predicate to
  a rule list; per-character SV if needed.

### Adherence to original intent

Intent: "cover up spider models in-game, by using a dynamic UI element … no
model swaps." Plan is 100% UI-layer: no game-file or model modification of any
kind; covers are recomputed from live world coordinates every frame (dynamic);
spiders are detected by game APIs + user data. **Fully adherent.** The only
intent-adjacent compromise is the unit-token limitation (§2): spiders you never
target/focus/mouseover are not covered — an API boundary of the 1.x client,
documented, accepted, and mitigated where it hurts most (your target +
mouseover).

## 9. Risks & mitigations (consolidated)

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Wrong `## Interface:` number → addon won't load | Medium | Blocker | M1 gate: `GetBuildInfo()` first; list all confirmed numbers in TOC |
| 2 | `WorldFramePoint3D` absent on this build | Low | Blocker | M1 probe; if absent, stop and re-scope (addon is infeasible without a world→screen API) |
| 3 | `GetUnitFamily` absent/localized | Medium | Medium | `UnitCreatureType` + `extraNames` fallbacks; data-driven |
| 4 | Cover undersized for large/flat spiders | Medium | Medium | sizeScale/minSize/maxSize/yOffset tuning; v1.1 wide rect + height table |
| 5 | Can't cover non-token spiders (API boundary) | Certain | Medium | Documented limitation; target+mouseover cover the real pain points |
| 6 | Proton/Wine path quirks | Low | Low | Standard folder copy into `Interface/AddOns/` (symlinked); test at M2 |
| 7 | "New content" spiders with unknown family strings | Medium | Low | `extraNames` list; selftest prints family of current target for discovery |

## 10. Open questions

1. Repo visibility — created **private**; say the word to make it public
   (`gh repo edit --visibility=public`).
2. Cover appearance v1: solid color (default deep red, 85% opacity) — acceptable,
   or do you want original art from day one?
3. Icon: I'll generate an original 32x32 TGA (spider silhouette with a slash);
   provide one if you'd rather supply your own.
4. Panic hotkey (F-key to hide all covers) — v1.1 candidate; needed for v1.0?

## 11. Conventions

- Lua 5.0 only. No global pollution: all state under one `local SBeGone = {}`
  namespace table (plus the SV table); files attach to it.
- No per-frame string concatenation outside debug mode.
- Comments: `--` only, short; each file starts with a one-line purpose comment.
- Git: `main` branch, conventional-ish lowercase commit messages, tag `v1.0.0`
  at M6. Addon folder name == TOC file name == `SpidersBeGone`.
