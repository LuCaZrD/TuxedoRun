# TuxedoRun

A tiny macOS menu bar app: a pixel tuxedo cat whose animation follows your CPU load, in the spirit of RunCat.

| CPU | Cat |
| --- | --- |
| under 33% | sleeping, with a Z drifting up |
| 33-70% | waving its ears, faster as CPU climbs |
| over 70% | running, with speed lines |

The cat is the 16x12 `tuxedo` theme from [pixel-pet](https://github.com/Namenomeaning/pixel-pet) (`tuxedo.theme.json`).

## Build and run

Needs the Xcode command line tools (Swift) and macOS 13 or later.

```bash
./build.sh
open TuxedoRun.app
```

Copy `TuxedoRun.app` to `/Applications` to use **Launch at Login** from its menu.

`TuxedoRun.app/Contents/MacOS/TuxedoRun --dump frames.png` writes every frame to one PNG, to check the art without a menu bar.
