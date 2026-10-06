# TuxedoRun

A tiny macOS menu bar app: a pixel tuxedo cat whose animation follows your CPU load, in the spirit of RunCat.

| CPU | Cat |
| --- | --- |
| under 33% | sleeping, with a Z drifting up |
| 33-70% | waving its ears, faster as CPU climbs |
| over 70% | running, with speed lines |

The cat is the 16x12 `tuxedo` theme from [pixel-pet](https://github.com/Namenomeaning/pixel-pet) (`tuxedo.theme.json`).

## Pomodoro

Click the cat to run a focus timer. The countdown sits next to the cat in the menu bar.

- **Cycle:** 25 min focus, 5 min break, 15 min long break after every 4th session. Presets for 50/10/30 and 15/3/10.
- **Break:** the cat stops following CPU, shuts its eyes, and a heart drifts up.
- **Phase end:** the cat cheers, a notification shows, and a sound plays. The next phase waits for you to click Start, except breaks if **Auto-start Breaks** is on.
- **Menu:** Start/Pause/Resume, Skip, Reset, today's session count, durations, and toggles for notifications, sound, auto-start, and the countdown.
- The timer uses an end time, so sleep and relaunch don't throw it off. Settings and a running timer are saved.

`TuxedoRun --selftest` runs the timer logic through full cycles and exits. `--fast` shrinks every phase to seconds, to watch a whole cycle.

## Build and run

Needs the Xcode command line tools (Swift) and macOS 13 or later.

```bash
./build.sh
open TuxedoRun.app
```

Copy `TuxedoRun.app` to `/Applications` to use **Launch at Login** from its menu.

`TuxedoRun.app/Contents/MacOS/TuxedoRun --dump frames.png` writes every frame to one PNG, to check the art without a menu bar.
