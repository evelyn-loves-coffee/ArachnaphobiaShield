# Handoff (maintainer)

**Current: v1.1.0** — creature-ID database removed (it was a
NoSpider-derived compilation, and the level cap blocked the in-game
family audit that would have verified it): detection is now creature
family `Spider` (3) → built-in name fragments → owner extra-names
(`/as name`, local-only, never uploaded); coverage is best-effort and
user entries rebuild the database from first-hand observation. v1.0.0:
`/as scale` band widened to 40–130 (100 = default, stored 0.4–1.3);
`/as selftest` trimmed to live state (the constant `mode` and
`fallbackSize` fields are gone; `limited` / `paused` remain). Bare `/as` mirrors `/as help`; `/as version` and
`/as selftest` split the old diagnostics; default cover is charcoal;
default `drop` is 0.3. Automatic nameplate-attached covers, image
picker, custom TGA support, look-away corpse warning. Offline Lua 5.1
suite green; packaged build re-validates the same suite against the
extracted zip.

Development and live testing happen on the owner's own machine: this
checkout's `dist/` package is live-swapped into
`~/Apps/wow/AddOns/ArachnaphobiaShield` (the game's
`_classic_beta_/Interface/AddOns` is the same directory, bind-mounted
through the Proton prefix). The owner exits/reloads the client to apply
changes. A full game exit is still the documented safe path for folder
replacement; live swaps are acceptable to the owner with `/reload`.

## Current behavior

- Every cover is a child of an accessible spider nameplate; permanently
  mouse-disabled; hidden until attached. No movement API, screen
  placement, layout save/restore or interactive mode exists.
- 24-slot pool; reverse ownership map prevents a recycled slot from being
  adopted by another unit; rejected cleanup quarantines a slot; repeated
  failures pause tracking (`/as enable` retries).
- Recognition: creature family `Spider` (3) → built-in name fragments
  → owner extra-names (`/as name`). Best-effort by design: detection
  relies on the in-game family identifier, and some spider-like
  creatures (e.g. Crypt Horror, filed outside Spider) go unidentified.
  No creature-ID database is bundled (the 124-ID list was removed
  post-1.0: it was a NoSpider-derived compilation, and the level cap
  prevented the in-game audit that would have verified it entry-by-
  entry). `/as name` entries are local-only (SavedVariables; never
  uploaded or transmitted) and seed the rebuild of coverage from
  first-hand observation — the author adds instances of enemy units as
  the game is explored. Player units excluded.
- Covers are always fully opaque (the client's distance fade makes any
  opacity control fiction — see constraints below).
- Picker: `/as config` opens an explicit window (the only input-taking
  surface). Presets + strict `ArachnaphobiaShield\Custom\` custom path,
  prefilled prefix, caret parked at the end of the prefix. No native
  Slider frame is ever created (a Slider froze the cursor in v0.3.2–0.4).
- Look-away warning: centered, click-through, 1.75 s, observes accessible
  spider deaths through a bounded recent-observation window.

## Client constraints (in-client verified, WoW Forever 1.60.1)

Design-defining facts, verified in-client (full probe records were in
`docs/API-VERIFICATION.md` / `FOREVER-API-REVIEW.md` / `NATIVE-OVERLAYS.md`,
removed with the doc consolidation; this summary is the live reference):

- **No position/projection route:** `GetUnitPosition`, `GetUnitWorldPosition`,
  `WorldFramePoint3D`, `C_Map.PositionToScreen`, `GetCameraPosition`,
  `GetViewingInfo` are all absent. The only position API is player-scoped
  `UnitPosition`. Consequence: covers follow nameplates, never the world.
- **Nameplate token queries that work:** `UnitExists`, `UnitIsVisible`,
  `UnitIsDead`, `UnitCreatureFamily`, `UnitName`, plus frame
  `GetWidth`/`GetEffectiveScale` on the plate itself.
- **Apparent-width band:** the client clamps far nameplates at ~73 UI px
  apparent width and grows them to ~90 on approach (debug capture
  2026-10-17). All size logic must live inside that band.
- **Numeric `SetTexture(r,g,b,a)` is a silent no-op** on this client
  (Spoken — the only proven-working UI addon — renders every texture from
  a string path). All solids ship as 8×8 TGA files loaded by path.
- **`CHAT_COMMAND` event does not exist** — slash dispatch is a direct
  `SlashCmdList` lookup.
- **Client-side distance fade** applies to nameplates and their children
  regardless of vertex alpha; the camouflage pattern is the mitigation.
- Nameplates are pooled and can be reassigned to another unit — never
  retain a plate reference past detach.

## Tracking model

`Core.lua` `plateSize()`: `size = plateWidth × (trackScale × nearBoost)`,
clamped to `MIN_TRACK`–`MAX_TRACK` in local px. `trackScale` is the
`/as scale` multiplier (0.4–1.3, default 1.0). `drop` offsets the cover
`drop` cover-heights below the plate (default 0.3 since v0.4.9; the
2026-10-16 in-game calibration established the range, 0.5 fully inside).
The near-field boost is a smoothstep of apparent width:
knees 75/85 UI px, ceiling `nearBoost = 3.0` (raised from 2.6 in v0.4.4;
plate width saturates at ~91 UI so the flat ceiling is the only lever for
extreme-close legs). Knees must stay inside the 73–90 band — earlier
knees (30, then 60) sat below the clamp and boosted far plates. Do not
change the sizing model without live measurements.

Defaults: `trackScale=1.0`, `drop=0.3`, `nearBoost=3.0`,
`coverSize=96` fallback, `trackRelease=0.5` s.

## Corpse handling

Covers cannot survive plate removal (pooled plates, no position API). The
v0.2.8 look-away popup is the whole corpse story: observe a readable
spider death → centered click-through warning for 1.75 s. NoSpider does
the same class of notification (mouseover-based), not corpse masking. Do
not force native plate visibility, guess screen coordinates, or add
mouseover detection (owner rule).

## Data sources

No creature database, zone/sub-zone tables or spawn datasets are
bundled; detection is creature family + name fragments + owner
extra-names, none of which require external data. If general area
metadata ever becomes necessary, **LibTourist Classic Era (MIT)** remains
the selected source; Questie data and Wowhead-derived bulk spawn tables
remain excluded (license). NoSpider is design inspiration only — no code
or data copied. Full review rules were in `docs/DATA-SOURCES.md` (removed
with the consolidation; kept in Git).

## Known issues

- Nameplate stacking/clamping can move a cover off the model; no
  UI-layer fix exists on this client.
- Unobserved deaths miss the look-away warning.
- Very close models can extend past the cover at the ×3.0 ceiling.
- In-game camera-drag cursor freeze (when it recurs) is consistent with a
  client/Proton input-layer bug, not the addon: the addon creates no
  mouse-capture control, and the freeze follows camera drags anywhere on
  screen. Owner rule: remove offending surfaces, never patch around input.

## In-game test sequence

1. Log in away from spiders: no leftover covers; mouse and camera work.
   Check again after `/reload` and relog.
2. Approach several spiders with the pointer elsewhere. Covers follow
   movement, camera rotation and zoom. Ground clicks, targeting and
   camera control pass through; clicking a cover moves nothing.
3. `/as disable`, reload, relog: no covers. `/as enable`: only live
   nameplate covers resume.
4. `/as config`: visible dark panel, visible button faces, preview on a
   checker with checker visible in the rounded corners of every choice,
   no opacity section. Change presets/custom art: preview and live covers
   update immediately; world shows through cover corners. Close it:
   input returns to the game; choice persists after reload.
5. Observed spider death: centered click-through warning, gone in ~1.75 s.
6. `/as scale 120` / `/as drop 1.25` / an extra name, then `/as reset`:
   defaults return (charcoal, scale 100) and persist after reload.

## Files and offline verification

- `Core.lua` — controls, settings schema, guarded scanning, TrackTick.
- `Cover.lua` — native-only pool, permanent click-through.
- `Appearance.lua` / `Config.lua` — data-driven presets, explicit picker.
- `Access.lua` / `Units.lua` — readable public queries, spider recognition.
- `DeathWarning.lua` — bounded recent observations, brief centered notice.
- `tools/test_core.lua` — client stubs prohibit movement/screen reads,
  record mouse-enable history, and trap Slider creation.
- `tools/make_backgrounds.py` — the four camo presets, 8×8 picker UI
  textures, `cover-backdrop.tga`. `tools/make_cover_alpha.py` — fox cut +
  camo card (pure function of the opaque import; restore with
  `git show HEAD:ArachnaphobiaShield/cover.tga`). `tools/import_cover.py`
  — local PNG/JPEG → 24-bit TGA. `tools/make_art.py` — addon icon.
- `tools/package_addon.py` — writes `dist/ArachnaphobiaShield-<v>-fixed.zip`
  (git-ignored), validates TGA invariants, re-runs the offline suite
  against the extracted files.

```bash
cd ArachnaphobiaShield
export UV_CACHE_DIR="$PWD/.test-cache" UV_LINK_MODE=copy
lua5.1 tools/test_core.lua
uv run --with lupa python tools/package_addon.py
```

Packaging ships only explicitly listed assets plus `README.md`,
`LICENSE`, `docs/HANDOFF.md`, `docs/COVER-IMAGES.md` and `docs/art/*`.
The packaged README is asserted to carry the NoSpider credit.

## History

Version history (v0.3.x incident record — cursor freeze, slider removal,
picker backgrounds, camo presets, opacity retirement — and the v0.4.x
near-ramp/UX line), the probe rounds, the zone-data review and the old
session archives lived in `docs/PLAN.md`, `docs/API-VERIFICATION.md`,
`docs/FOREVER-API-REVIEW.md`, `docs/NATIVE-OVERLAYS.md`,
`docs/CORPSE-HANDLING.md`, `docs/DATA-SOURCES.md`,
`docs/NEAR-RAMP.md`, `docs/TRACKING-FIX.md`, `docs/TRACKING-ONLY.md` and
`docs/HANDOFF-HISTORY.md`. Those files were removed in the 2026-10-18
doc consolidation; everything above is the distilled live reference and
the full text remains in Git history.
