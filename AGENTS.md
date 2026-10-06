# Guide for AI agents

TuxedoRun is a macOS menu bar app: a pixel pet whose animation follows CPU load, with a built-in pomodoro timer. It is plain Swift with no dependencies and no Xcode project. Read this file before changing anything.

## Commands

```bash
./build.sh                                           # build TuxedoRun.app next to the script
TuxedoRun.app/Contents/MacOS/TuxedoRun --selftest    # check the pomodoro logic; exits 0 or 1
TuxedoRun.app/Contents/MacOS/TuxedoRun --dump out.png    # render every frame to one PNG sheet
TuxedoRun.app/Contents/MacOS/TuxedoRun --export docs     # regenerate the README GIFs
TuxedoRun.app/Contents/MacOS/TuxedoRun --icon dir        # write the app icon (an .iconset) from the avatar; build.sh does this for you
TuxedoRun.app/Contents/MacOS/TuxedoRun --fast            # run the app with 10 s focus / 4 s breaks, nothing saved
```

There is no test framework. `--selftest` is the test suite, and `--dump` is how you check art without a menu bar.

## Files

| File | What it holds |
| --- | --- |
| `Avatar.swift` | **The pet's look**: sprite, palette, eye positions, ear rows. The only file to edit for a new avatar. |
| `Cat.swift` | Draws every frame (hop, ear flop, run lean, Z's, hearts, sparkles) from the avatar. |
| `CPU.swift` | CPU meter. |
| `Pomodoro.swift` | Timer state machine. Foundation only: do not import AppKit here. |
| `Selftest.swift` | `--selftest`. Add a check here for every timer behavior you change. |
| `main.swift` | The app: menu, notifications, animation loop, and the `--dump` / `--export` modes. |
| `build.sh` | Builds and ad-hoc signs the app. |
| `tuxedo.theme.json` | The original cat as a pixel-pet theme. Reference only; the app does not read it. |

## Rules

- Build with `./build.sh`, not a bare `swiftc`. It builds in a temp folder because codesign rejects the file attributes that Desktop sync adds.
- Do not commit `TuxedoRun.app` (it is gitignored).
- The timer works from an end `Date`, never by counting ticks. Keep it that way, so sleep and relaunch cannot skew it.
- `Pomodoro.swift` takes its clock as `now` and the day as `today`, so tests can fake time. Do not call `Date()` inside its logic.
- Settings are saved in `UserDefaults` under `config`, `prefs`, and `state`. A change to those structs must still decode what an older version saved (give new fields defaults).
- The app must stay a menu-bar-only app (`LSUIElement`): no windows, no Dock icon.
- After a change to frames, run `--dump` and look at the PNG. After a change to the README's animations, run `--export docs`.
- After any change, run `--selftest`, and do not report success unless it passes.

## Create a new avatar

Users can swap the cat for any pet they like. All the work is in `Avatar.swift`.

1. **Draw the sprite.** `sprite` is rows of characters, one per pixel, `.` for clear. Aim for **16 wide, 12 tall** (bigger is shrunk to fit the menu bar, and loses sharpness). Every row must be the same width. Make the shape compact with a flat bottom. Features such as ears should be at least 2 pixels thick so a hop doesn't erase them.
2. **Set the palette.** `palette` maps each sprite character to a color. A character with no color draws clear. Use a dark outline color.
3. **Place the eyes.** `eyes` is the top-left pixel `(x, y)` of each 2x2 eye. Put them on a flat patch of one body color, with no outline inside. Choose `eyeColor` so it reads on that patch. Leave `eyes` empty for a pet with no eyes (then it will not look asleep, only the Z's show).
4. **Closed eyes.** `closedEyeBody` is the body color under the eye and `closedEyeLine` is the line color drawn when the pet sleeps, blinks, or rests. Use the pet's fur and outline colors.
5. **Ears.** `earRows` is how many top rows flop while the pet waves and lay back while it runs. Use `0` for a pet with no ears, such as a slime.
6. **Rim.** `rimColor` is the light outline drawn around the pet so a dark pet still shows on a dark menu bar. Keep it light, or lower its alpha for a light-colored pet.
7. **Check it.** Run `./build.sh`, then `--dump sheet.png` and open the PNG. Look at all frames: sleeping (Z's), waving, running (speed lines), resting (heart), and cheering (sparkles). Fix anything that looks broken or cropped.
8. **Install.** Quit the running copy (`pkill -x TuxedoRun`), copy `TuxedoRun.app` to `/Applications`, and open it.
9. **Icon:** `./build.sh` redraws the app icon from the new sprite. Check `--icon /tmp/icon` and open `icon_512x512@2x.png` if you changed the sprite size, to make sure the pet fits the tile.
10. **Optional:** run `--export docs` to regenerate the README GIFs, copy a fresh `docs/icon.png`, and update the avatar mentions in `README.md`.

Constraints worth knowing:

- Effects live in side margins of 3 pixels each (`Cat.swift`: `leftMargin`, `rightMargin`). Keep the pet's visible body inside the sprite grid and let the effects use the margins.
- Hops use 1 pixel of headroom above the sprite, so leave the top row of the sprite for the highest part of the pet.
- The pet is front-facing in every frame. A side-view pet works, but "lean forward while running" will look like a small shift, not a turn.
- To draw a pet from a reference image, reduce it to about 16x12 with a handful of flat colors first, then write the rows. Rough shapes with high contrast beat fine detail at this size.

### A prompt users can give their agent

> Replace the avatar in TuxedoRun with a pixel \<describe your pet\>. Read `AGENTS.md`, edit only `Avatar.swift`, then build, run `--dump` to render all the frames, look at the PNG and fix any problems, and install the app to `/Applications`.
