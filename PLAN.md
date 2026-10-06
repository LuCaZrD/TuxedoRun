# Pomodoro for TuxedoRun: plan

Status: draft, nothing implemented yet.

## Goal

Add a pomodoro timer to the menu bar cat. The cat keeps reacting to CPU, and the timer adds a countdown and a break mode. One click to start, no windows.

## Behavior

**Cycle (defaults, all adjustable):** 25 min work, 5 min short break, 15 min long break after every 4th work session. After a work session ends, the next phase starts only when the user clicks Start (no surprise auto-restart). Option to auto-start breaks, off by default.

**Menu bar:**
- Idle (timer off): cat only, exactly as today.
- Work running: cat keeps the CPU stages, plus the remaining time next to it, e.g. `24:31`.
- Break running: the cat stops following CPU and plays a relaxed break animation (eyes closed with a slow smile, a small steam or heart rising), plus the remaining time in a break color.
- Paused: countdown frozen and dimmed, cat shows the stage it was in.
- Phase ends: the cat does a short cheer (hops with sparkles, 3 seconds), a notification appears, and an optional sound plays.

**Menu additions** (above Launch at Login):
- `Start Focus` / `Pause` / `Resume` (one item, label changes)
- `Skip to Next Phase`, `Reset`
- `Today: N sessions` (read only)
- `Durations` submenu with presets: 25/5/15, 50/10/30, 15/3/10
- `Notifications` and `Sound` toggles, `Auto-start breaks` toggle

## Design

- **State machine** `Pomodoro`: phase (`idle`, `work`, `shortBreak`, `longBreak`), `running` or `paused`, `endDate`, `remaining`, `completedToday`, `cycleCount`. Time is tracked as an end `Date`, not by counting ticks, so sleep, lid close, and timer drift cannot skew it. On wake, if `endDate` passed, finish the phase once.
- **UI tick:** a 1 s timer updates `button.title`. Use a monospaced-digit font so the width does not jump. It reuses the existing animation loop; no new timers fighting each other.
- **Cat selection:** `Stage` gains an override. `current = pomodoro.isBreak ? .resting : Stage(cpu:)`. New frames: `breakFrames` (4) and `cheerFrames` (4), built in `render` via new `Pose` fields.
- **Notifications:** `UNUserNotificationCenter`, authorization requested on first Start, not at launch. Sound is `NSSound(named: "Glass")`, no bundled audio.
- **Persistence:** `UserDefaults`: durations, toggles, `completedToday` with its date (reset on a new day), and a running timer's `endDate` and phase so a relaunch resumes it.
- **Code layout:** split `main.swift` into `Cat.swift` (sprite, frames), `CPU.swift`, `Pomodoro.swift` (pure logic, no AppKit), and `main.swift` (app and menu). `build.sh` compiles `*.swift`.
- **Menu bar width:** the title appears only while a timer runs, so idle width is unchanged.

## Steps

1. Split the file with no behavior change. Build, run `--dump`, compare frames to the current ones.
2. Write `Pomodoro.swift` (state machine, injectable clock) and a `--selftest` flag that runs it through full cycles, pause/resume, skip, long break, and wake-after-sleep without a UI.
3. Add `Pose` fields and the break and cheer frames. Extend `--dump` to include them, and check them visually.
4. Wire the menu, the countdown title, and the cat override.
5. Add notifications, sound, persistence, and the Durations submenu.
6. Manual pass with a 10-second duration preset hidden behind `--fast` to watch a whole cycle quickly.
7. Update the README, rebuild, reinstall to `/Applications`, commit, and push.

## Risks

- **Notifications on an ad-hoc signed app:** should work from `/Applications`, but macOS may need a one-time approval in System Settings. Fall back to sound plus the cheer animation when denied.
- **Menu bar space:** a countdown plus the 36 pt cat is wide on crowded bars. Mitigation: a menu toggle to hide the countdown and show it only in the menu.
- **Dark and light menu bars:** the break and cheer effects reuse the existing light rim so they read on both.

## Decisions to confirm

1. Break behavior: cat sleeps on break (reusing sleeping frames) or gets the distinct relaxed animation described above? Default: distinct.
2. Auto-start the next phase after a phase ends? Default: no.
3. Show the countdown in the menu bar by default? Default: yes.
4. Sound on by default? Default: on.

## Out of scope

Task lists, statistics history, global hotkeys, and syncing across devices.
