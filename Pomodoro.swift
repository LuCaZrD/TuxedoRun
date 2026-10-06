import Foundation

// The pomodoro state machine. Foundation only, so `--selftest` can run it without a UI.
// Time is kept as an end date, not by counting ticks, so sleep and drift cannot skew it.

enum Phase: String, Codable {
    case idle, work, shortBreak, longBreak

    var isBreak: Bool { self == .shortBreak || self == .longBreak }
    var label: String {
        switch self {
        case .idle: return "Timer off"
        case .work: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}

struct PomodoroConfig: Codable, Equatable {
    var work: TimeInterval = 25 * 60
    var shortBreak: TimeInterval = 5 * 60
    var longBreak: TimeInterval = 15 * 60
    var sessionsBeforeLong = 4
    var autoStartBreaks = false

    /// Minutes of work, short break, long break.
    static let presets: [(work: Int, short: Int, long: Int)] = [(25, 5, 15), (50, 10, 30), (15, 3, 10)]
}

struct PomodoroSnapshot: Codable {
    var phase: Phase
    var running: Bool
    var started: Bool
    var endDate: Date?
    var pausedRemaining: TimeInterval
    var cycleCount: Int
    var completedToday: Int
    var day: String
}

final class Pomodoro {
    var config: PomodoroConfig {
        didSet { if isReady { pausedRemaining = duration(of: phase) } } // a waiting phase takes the new length
    }
    var now: () -> Date = { Date() }
    var today: () -> String = {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    /// Called when a phase ends on its own (not when it is skipped).
    var onPhaseEnd: ((_ ended: Phase, _ next: Phase, _ nextRunning: Bool) -> Void)?

    private(set) var phase = Phase.idle
    private(set) var running = false
    private(set) var started = false          // has begun counting down, so not running means paused
    private(set) var cycleCount = 0           // work sessions finished since the last long break
    private(set) var completedToday = 0
    private var endDate: Date?
    private var pausedRemaining: TimeInterval = 0
    private var day = ""

    init(config: PomodoroConfig = PomodoroConfig()) { self.config = config }

    /// The next phase is set up and waiting for Start.
    var isReady: Bool { phase != .idle && !running && !started }
    var isPaused: Bool { phase != .idle && !running && started }

    func duration(of p: Phase) -> TimeInterval {
        switch p {
        case .idle: return 0
        case .work: return config.work
        case .shortBreak: return config.shortBreak
        case .longBreak: return config.longBreak
        }
    }

    func remaining() -> TimeInterval {
        if running, let endDate { return max(0, endDate.timeIntervalSince(now())) }
        return phase == .idle ? 0 : pausedRemaining
    }

    // MARK: Actions

    /// Starts a focus session from idle, begins a waiting phase, or resumes a paused one.
    func start() {
        rollDay()
        switch phase {
        case .idle:
            phase = .work
            begin(config.work)
        default:
            if !running { begin(pausedRemaining) }
        }
    }

    func pause() {
        guard running else { return }
        pausedRemaining = remaining()
        running = false
        endDate = nil
    }

    func reset() {
        phase = .idle
        running = false
        started = false
        endDate = nil
        pausedRemaining = 0
        cycleCount = 0
    }

    func skip() {
        guard phase != .idle else { return }
        advance(natural: false)
    }

    /// Call about once a second. Ends the phase when its time is up, once, even after a long sleep.
    func tick() {
        rollDay()
        guard running, let endDate, now() >= endDate else { return }
        advance(natural: true)
    }

    // MARK: Persistence

    func snapshot() -> PomodoroSnapshot {
        PomodoroSnapshot(phase: phase, running: running, started: started, endDate: endDate,
                         pausedRemaining: pausedRemaining, cycleCount: cycleCount,
                         completedToday: completedToday, day: day)
    }

    func restore(_ s: PomodoroSnapshot) {
        phase = s.phase
        running = s.running && s.endDate != nil
        started = s.started || running
        endDate = running ? s.endDate : nil
        pausedRemaining = s.pausedRemaining
        cycleCount = s.cycleCount
        completedToday = s.completedToday
        day = s.day
        rollDay()
        tick()
    }

    // MARK: Internals

    private func begin(_ length: TimeInterval) {
        endDate = now().addingTimeInterval(length)
        running = true
        started = true
    }

    private func rollDay() {
        let t = today()
        if day != t { day = t; completedToday = 0 }
    }

    private func advance(natural: Bool) {
        let ended = phase
        var next = Phase.work
        if ended == .work {
            if natural { completedToday += 1; cycleCount += 1 }
            if natural && cycleCount >= config.sessionsBeforeLong {
                cycleCount = 0
                next = .longBreak
            } else {
                next = .shortBreak
            }
        }
        phase = next
        running = false
        started = false
        endDate = nil
        pausedRemaining = duration(of: next)
        let autoStart = natural && next.isBreak && config.autoStartBreaks
        if autoStart { begin(pausedRemaining) }
        if natural { onPhaseEnd?(ended, next, autoStart) }
    }

    /// `m:ss`, rounded up so the display reaches 0:00 only when the phase ends.
    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
