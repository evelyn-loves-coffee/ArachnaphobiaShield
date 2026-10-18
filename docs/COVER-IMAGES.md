# Choose your cover image

Run `/as config` to open the cover picker. Click a preset to preview it
and update every cover immediately. The choice is saved in addon settings
and survives reloads; the fox is the default. The window appears only when
requested. Covers are permanently click-through; changing an image while
the addon is disabled keeps it disabled.

## Included choices

![Included cover choices](art/cover_choices.png)

| Choice | Appearance | Command |
| --- | --- | --- |
| Fox | Supplied illustration on a navy-toned camouflage squircle card, original colors, fitted in proportion | `/as cover fox` |
| Muted red | Red camouflage squircle | `/as cover red` |
| Muted blue | Blue camouflage squircle | `/as cover blue` |
| Sage green | Green camouflage squircle | `/as cover sage` |
| Plain charcoal | Dark grey camouflage squircle | `/as cover charcoal` |

Every preset is a 32-bit RGBA **camouflage squircle** with **transparent
rounded corners**: the world shows through the corners only. The
camouflage is deliberate — this client fades nameplates with distance,
and a busy pattern makes a spider's outline much harder to trace through
the fade than a flat fill. All covers are **fully opaque**; there is no
opacity control because the client's distance fade applies regardless.

`/as cover` lists choices and the selected image. Offline layout preview
(client fonts/rendering may differ):

![Cover picker layout](art/config_preview.png)

## Use your own image

Prepare a local square TGA texture in the addon's custom folder, for
example:

```text
<game folder>/Interface/AddOns/ArachnophobiaShield/Custom/flower.tga
```

Then open the picker, keep the prefilled
`Interface\AddOns\ArachnophobiaShield\Custom\` prefix, add the file name
and click **Use image** (a bare file name without the prefix is
rejected), or enter:

```text
/as cover custom Interface\AddOns\ArachnophobiaShield\Custom\flower.tga
```

A custom image must live under
`Interface\AddOns\ArachnophobiaShield\Custom\` (no `..`, no Windows
drives, no web addresses). The empty `Custom\` folder ships in the
release zip; its contents are git-ignored and never packaged, so personal
images stay outside addon updates. When updating, extract the zip over
the existing folder (or re-copy your images) so your images survive.
Choose a bundled preset at any time to switch back. A navy backing is
drawn behind custom images, so transparent parts show navy, not the world.

The picker does not browse Windows files, download images or upload
anything. To use a PNG or JPEG illustration, convert it first with the
included local helper:

```powershell
uv run --with pillow python tools/import_cover.py "C:\Pictures\flower.png" --output "C:\Games\WoW\Interface\AddOns\ArachnophobiaShield\Custom\flower.tga"
```

Replace those example paths with your own. The helper reads the source
without modifying it, fits the entire illustration into a 512 x 512
square without stretching/cropping, and writes an uncompressed 24-bit RGB
TGA. If you use another converter, a 512 x 512 uncompressed RGB TGA is
the format used and checked for the included fox.

**Dimensions rule:** the TGA's width and height must each be a power of
2 (256, 512, 1024, …; non-square is fine, e.g. 512 x 256), per the
client's texture documentation (["TGA files",
warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/TGA_files)). A
800 x 600 or 1000 x 1000 file cannot be decoded and the picker falls
back to the fox. The import helper always satisfies the rule (it pads
to 512 x 512), so any PNG/JPEG works as-is.

Fully exit and reopen the game after adding a new texture, then check
the picker's preview (new-file reload behavior is not verified on this
client). A reported texture failure falls back to the fox.

## Troubleshooting

| Symptom | Cause / fix |
| :-- | :-- |
| Picker status: *“Image failed to load; showing the fox.”* | The client could not load the file. Check spelling, backslashes and that the file really is a TGA the client can decode. Test a known-good file first (e.g. `Interface\AddOns\ArachnophobiaShield\cover.tga`). | Dimensions are not powers of 2 (e.g. 800 x 600, 1000 x 1000) | Re-export at 512 x 512 — the import helper does this automatically. |
| Picker rejects the path with an error | The path must be under `Interface\AddOns\ArachnophobiaShield\Custom\`, end with `.tga`, contain no `..`, no double backslashes, no control characters, and be ≤ 240 characters. |
| Preview looks right but the in-game cover shows the fox | The texture loaded in the picker but not at cover size/time. Retry after `/reload`; try a smaller 24-bit TGA. |
| Transparent parts show navy, not the world | Intentional — the navy backing is the minimum coverage floor for custom art. |
| Image looks cropped / stretched | It is not cropped; non-square images are letterboxed inside the square cover box. Use a square source. |

## Maintenance (addon developers)

The preset list in `Appearance.lua` drives the buttons and selection
handler. To ship another approved illustration: prepare its TGA, add a
preset entry, add the filename to `tools/package_addon.py`, regenerate
the package. `tools/make_backgrounds.py` regenerates the four camo
squircles, the 8×8 picker UI textures and `cover-backdrop.tga`;
`tools/make_art.py` regenerates the addon icon;
`tools/make_cover_alpha.py` re-cuts the fox import onto the camo card;
`tools/render_config_preview.py` and `tools/make_choices_preview.py`
re-render the images above. Supplied artwork needs permission before
publication; no NoSpider artwork is used.
