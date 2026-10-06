import Foundation

// `TuxedoRun --selftest` drives the pomodoro state machine with a fake clock and exits 0 or 1.

func runSelfTest() -> Never {
    var failures = 0
    func check(_ ok: Bool, _ what: String) {
        if !ok { failures += 1; print("FAIL: \(what)") } else { print("ok:   \(what)") }
    }

    var t = Date(timeIntervalSince1970: 1_000_000)
    func make(_ cfg: PomodoroConfig = PomodoroConfig()) -> Pomodoro {
        let p = Pomodoro(config: cfg)
        p.now = { t }
        p.today = { String(Int(t.timeIntervalSince1970 / 86400)) }
        return p
    }
    func advance(_ p: Pomodoro, _ s: TimeInterval) { t = t.addingTimeInterval(s); p.tick() }

    // A work session runs 25 minutes, then a short break waits for Start.
    var p = make()
    var ends: [(Phase, Phase, Bool)] = []
    p.onPhaseEnd = { ends.append(($0, $1, $2)) }
    check(p.phase == .idle && p.remaining() == 0, "starts idle")
    p.start()
    check(p.phase == .work && p.running && p.remaining() == 1500, "start begins 25:00 of work")
    advance(p, 1499)
    check(p.phase == .work && ends.isEmpty, "one second early is still work")
    advance(p, 1)
    check(p.phase == .shortBreak && p.isReady && ends.count == 1 && !ends[0].2, "work ends into a waiting short break")
    check(p.completedToday == 1, "a finished session counts")
    check(p.remaining() == 300, "waiting break shows 5:00")
    advance(p, 3600)
    check(p.phase == .shortBreak && p.isReady && ends.count == 1, "a waiting phase does not run on its own")

    // Pause freezes the countdown, resume continues it.
    p.start()
    advance(p, 100)
    p.pause()
    check(p.isPaused && p.remaining() == 200, "pause keeps 3:20")
    advance(p, 1000)
    check(p.remaining() == 200 && ends.count == 1, "paused time does not pass")
    p.start()
    check(p.running && p.remaining() == 200, "resume continues")
    advance(p, 200)
    check(p.phase == .work && p.isReady && ends.count == 2, "break ends into a waiting work session")

    // Four finished sessions in a row earn a long break.
    p = make()
    p.start()
    var last = Phase.idle
    for i in 1...4 {
        advance(p, 1500)
        last = p.phase
        if i < 4 {
            p.start(); advance(p, 300) // the short break
            p.start()                  // the next work session
        }
    }
    check(last == .longBreak && p.remaining() == 900 && p.completedToday == 4, "the 4th session leads to a 15:00 long break")
    p.start(); advance(p, 900); p.start(); advance(p, 1500)
    check(p.phase == .shortBreak, "the cycle restarts after a long break")

    // Skip moves on without counting, and never notifies.
    p = make()
    ends = []
    p.onPhaseEnd = { ends.append(($0, $1, $2)) }
    p.start()
    advance(p, 60)
    p.skip()
    check(p.phase == .shortBreak && p.isReady && p.completedToday == 0 && ends.isEmpty, "skipping work does not count or notify")
    p.skip()
    check(p.phase == .work && p.isReady, "skipping a break returns to a waiting work session")

    // Reset goes back to idle but keeps today's count.
    p = make()
    p.start(); advance(p, 1500)
    p.reset()
    check(p.phase == .idle && !p.running && p.remaining() == 0 && p.completedToday == 1, "reset returns to idle and keeps today's count")

    // Auto-start breaks.
    var cfg = PomodoroConfig(); cfg.autoStartBreaks = true
    p = make(cfg)
    ends = []
    p.onPhaseEnd = { ends.append(($0, $1, $2)) }
    p.start(); advance(p, 1500)
    check(p.phase == .shortBreak && p.running && ends.first?.2 == true, "auto-start runs the break")
    advance(p, 300)
    check(p.phase == .work && p.isReady, "work never auto-starts")

    // A long sleep ends the phase once, not many times.
    p = make()
    ends = []
    p.onPhaseEnd = { ends.append(($0, $1, $2)) }
    p.start()
    advance(p, 10 * 3600)
    check(ends.count == 1 && p.phase == .shortBreak, "waking after 10 hours ends one phase")

    // A new day starts the count again.
    p = make()
    p.start(); advance(p, 1500)
    check(p.completedToday == 1, "count is 1 today")
    advance(p, 86400)
    check(p.completedToday == 0, "count resets on a new day")

    // Snapshot and restore, including a phase that ended while the app was closed.
    p = make()
    p.start(); advance(p, 600)
    let snap = p.snapshot()
    let data = try! JSONEncoder().encode(snap)
    let back = try! JSONDecoder().decode(PomodoroSnapshot.self, from: data)
    var q = make()
    q.restore(back)
    check(q.phase == .work && q.running && q.remaining() == 900, "a running timer survives a relaunch")
    t = t.addingTimeInterval(2000)
    q = make()
    q.restore(back)
    check(q.phase == .shortBreak && q.isReady, "a phase that ended while closed is finished on launch")

    // Changing durations updates a waiting phase.
    p = make()
    p.start(); advance(p, 1500)
    var c2 = p.config; c2.shortBreak = 600; p.config = c2
    check(p.remaining() == 600, "a new duration applies to the waiting break")

    check(Pomodoro.format(1500) == "25:00" && Pomodoro.format(59.2) == "1:00" && Pomodoro.format(0) == "0:00", "time formatting")

    print(failures == 0 ? "all passed" : "\(failures) failed")
    exit(failures == 0 ? 0 : 1)
}
