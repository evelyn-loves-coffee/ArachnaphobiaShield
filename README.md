# Arachnaphobia Shield — WoW Forever Addon

Addon for **World of Warcraft Forever** (classic 1.x-line client, v1.60.1)
that covers spider models with a nameplate-attached UI element. UI-layer
only: no model swaps, no game-file modification. Covers are always
click-through and always fully opaque.

**Status: v1.1.0.** This README documents current behavior only; the
change history lives in Git.

## How it works

- Every cover is a child of the spider's **nameplate**, so native plate
  movement and scale carry the cover between polling ticks. No targeting,
  mouseover or input is needed; tracking is on by default.
- Cover size is a **percentage of the nameplate width** (`/as scale`,
  whole number `40`–`130`, `100` = default).
- **Near-field boost (automatic):** the client holds nameplate apparent
  size in a narrow band (~73–90 UI px) while the model keeps growing as
  you close in, so a plate-proportional cover would under-cover close
  spiders. Every 10 Hz tick multiplies the tracked size by a smooth ramp
  of the plate's apparent width: no boost at/under 75 UI px, full ×3.0 at/
  above 85 UI px. There is no setting to change it; `/as debug on` shows
  the per-plate values on the `AS| near:` line.
- When the client removes a dead unit's nameplate, the cover goes with
  it. When the addon observes an accessible spider death, a centered,
  click-through **LOOK AWAY** warning appears for 1.75 seconds. It warns
  that the corpse may be visible; it does not cover the body.

## Install

Extract the fixed ZIP and replace the `ArachnaphobiaShield/` folder in
your client's `Interface/AddOns/` directory. The `.toc` must sit at
`Interface/AddOns/ArachnaphobiaShield/ArachnaphobiaShield.toc`, without an
extra nested folder. Log in or `/reload`; `/as version` reports the
version and `/as selftest` reports the live tracking state.

Enable **enemy nameplates** in the game options. The addon starts enabled
on a fresh install; `/as enable` also enables tracking and retries paused
coverage. `/as disable` stops tracking and hides every cover (stays
disabled after reload).

## Slash commands

| Command | Effect |
| :-- | :-- |
| `/as` | usage (identical to `/as help`) |
| `/as version` | print the addon version and the client's build / interface / Lua versions |
| `/as selftest` | diagnostics: enabled, tracked, covers shown, limited / paused |
| `/as config` | open the cover picker with preview, presets and custom-image path |
| `/as cover <choice>` | select `fox`, `red`, `blue`, `sage`, `charcoal`, or `custom <local .tga path>` |
| `/as enable` | enable tracking and retry paused coverage; enabled by default |
| `/as disable` | stop tracking and hide every cover; stays disabled after reload |
| `/as toggle` | switch between enabled tracking and disabled covers |
| `/as scale [N]` | cover size as a **percentage** of the nameplate width, whole number `40`–`130`, `100` = default |
| `/as drop [N]` | how far below the nameplate it sits (`0`–`4`, default `0.3`) |
| `/as name <name>` | "cover this one too": add an **exact** creature name (spaces allowed) |
| `/as names` | list the names you added |
| `/as forget <name>` | remove one you added |
| `/as reset` | restore every saved setting to its factory default and reapply |
| `/as debug [on\|off]` | verbose decisions for bug reports (off by default) |
| `/as help` | usage |

`/as on` and `/as off` remain compatibility aliases for enable/disable.

## How a spider is recognised

1. **Creature family** `Spider` (id 3) — the primary signal; the addon
   does its best to detect from the in-game family identifier, which
   covers every creature the game itself files as a spider.
2. **Name fragments** (`spider`, `tarantula`, `webspinner`, `widow`,
   `skitterer`, `webwood`, …, case-insensitive) — for units whose family
   read is unavailable.
3. **Extra names** — an exact-name list you build with
   `/as name <exact name>` (per character).

Detection is **best-effort**: some spider-like creatures may not be
identified — a creature filed outside the Spider family whose name gives
nothing away (for example, a "Crypt Horror") is invisible to layers 1
and 2. When you spot one, `/as name <exact name>` adds it permanently.

**Everything stays local.** `/as name` entries are stored only in the
addon's SavedVariables on your machine; they are never uploaded,
transmitted or reported anywhere. The author will do their best to add
instances of enemy units as the game is explored, so coverage can be
rebuilt from scratch out of first-hand observation over time. Player
units are excluded.

## Custom cover images

The picker has no file browser by design: the addon never enumerates the
game's filesystem. Put a `.tga` in the addon's `Custom\` folder and point
the addon at it with the picker or `/as cover custom
Interface\AddOns\ArachnaphobiaShield\Custom\<file>.tga` (path relative to
the game root, backslashes; a bare file name is rejected — the picker
prefills the required prefix). A navy backing is drawn behind custom
images, so transparency in your art shows navy, not the world.

Full setup, the PNG/JPEG conversion helper and the symptom-by-symptom
troubleshooting table: [docs/COVER-IMAGES.md](docs/COVER-IMAGES.md).

## Troubleshooting

| Symptom | Fix |
| :-- | :-- |
| No covers at all | Enemy nameplates disabled in game options? Check `/as selftest` for `limited=true`; run `/as enable` (also retries after `paused=true`). |
| `/as selftest` reports `limited=true` | One or more client reads were unavailable; covers may be incomplete. Re-run `/as selftest` after `/reload`; report if it persists. |
| Close spider shows legs | `/as scale 120` and/or `/as drop 0.5`; the automatic near boost already caps at ×3.0. |
| Cover off the model | Nameplate stacking/clamping moved the plate itself — a client behavior no UI-layer addon can correct (see below). |
| Custom image not loading | See the table in [docs/COVER-IMAGES.md](docs/COVER-IMAGES.md). |

## Known limitations

- This client exposes **no world-to-screen projection** or enemy position
  API, so the cover can only follow the nameplate. Stacking or screen-edge
  clamping by the game can move the plate away from the model.
- The client **fades nameplates with distance** (and covers are nameplate
  children), so covers fade too; this cannot be disabled from an addon.
  The camouflage presets exist to make a spider's outline hard to trace
  through that fade. There is no opacity control.
- Very close models can extend beyond a cover even at the ×3.0 ceiling.
- Deaths not observed through accessible unit data can be missed by the
  look-away warning.

## Credits and data

Arachnaphobia Shield is an independent **spiritual successor to the
accessibility approach** of [NoSpider - Arachnophobia Mode](https://www.curseforge.com/wow/addons/nospider-arachnophobia-mode)
by **GrasHopper42**. No NoSpider code, artwork, bundled libraries,
zone tables, spawn coordinates or creature lists have been copied or
bundled; its native parent-and-anchor overlay approach informed this
implementation.

No creature database is bundled: detection relies on in-client signals
(creature family, name matching) and the owner's own extra-name list.
No zone tables or spawn datasets are bundled or required for the
nameplate overlay.

## Developer documentation

Maintainer handoff — design constraints, client API facts, tracking
model, test procedure and data-source rules: [docs/HANDOFF.md](docs/HANDOFF.md).

## License

MIT (code and original generated background presets). See [LICENSE](LICENSE).
The supplied fox artwork is included with the user's permission to publish
it with this addon; the code license does not grant a separate license to
reuse that artwork elsewhere.
