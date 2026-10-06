import Cocoa
import ServiceManagement
import UserNotifications
import UniformTypeIdentifiers

struct Prefs: Codable {
    var notifications = true
    var sound = true
    var showCountdown = true
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let meter = CPUMeter()
    let defaults = UserDefaults.standard
    /// `--fast` shrinks every phase to seconds, to watch a whole cycle, and saves nothing.
    let fast = CommandLine.arguments.contains("--fast")

    let pomo: Pomodoro
    var prefs = Prefs()
    var cpu = 0.0 // smoothed, so the cat does not flap between stages
    var stage = Stage.sleeping
    var frame = 0
    var ticks = 0
    var cheerUntil = Date.distantPast

    let cpuLine = NSMenuItem(title: "CPU: --", action: nil, keyEquivalent: "")
    let phaseLine = NSMenuItem(title: "Timer off", action: nil, keyEquivalent: "")
    let startItem = NSMenuItem(title: "Start Focus", action: #selector(startPause), keyEquivalent: "")
    let skipItem = NSMenuItem(title: "Skip to Next Phase", action: #selector(skip), keyEquivalent: "")
    let resetItem = NSMenuItem(title: "Reset", action: #selector(reset), keyEquivalent: "")
    let todayItem = NSMenuItem(title: "Today: 0 sessions", action: nil, keyEquivalent: "")
    let durations = NSMenu()
    let notifyItem = NSMenuItem(title: "Notifications", action: #selector(toggleNotifications), keyEquivalent: "")
    let soundItem = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
    let autoItem = NSMenuItem(title: "Auto-start Breaks", action: #selector(toggleAutoStart), keyEquivalent: "")
    let countdownItem = NSMenuItem(title: "Show Countdown in Menu Bar", action: #selector(toggleCountdown), keyEquivalent: "")
    let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")

    override init() {
        var config = PomodoroConfig()
        if CommandLine.arguments.contains("--fast") {
            config.work = 10; config.shortBreak = 4; config.longBreak = 6
        } else if let data = UserDefaults.standard.data(forKey: "config"),
                  let saved = try? JSONDecoder().decode(PomodoroConfig.self, from: data) {
            config = saved
        }
        pomo = Pomodoro(config: config)
        super.init()
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        if !fast {
            if let d = defaults.data(forKey: "prefs"), let p = try? JSONDecoder().decode(Prefs.self, from: d) { prefs = p }
            if let d = defaults.data(forKey: "state"), let s = try? JSONDecoder().decode(PomodoroSnapshot.self, from: d) { pomo.restore(s) }
        }
        pomo.onPhaseEnd = { [weak self] ended, next, nextRunning in self?.phaseEnded(ended, next, nextRunning) }
        UNUserNotificationCenter.current().delegate = self

        item.button?.image = sleepFrames[0]
        item.button?.toolTip = "TuxedoRun: sleeps under 33% CPU, waves its ears to 70%, runs above. Click for the pomodoro timer."
        buildMenu()
        refresh()

        // A phase can end while the Mac sleeps; check the moment it wakes.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.pomo.tick(); self?.refresh()
        }
        _ = meter.usage()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.sample() }
        step()
    }

    // MARK: Menu

    func buildMenu() {
        let menu = NSMenu()
        cpuLine.isEnabled = false
        phaseLine.isEnabled = false
        todayItem.isEnabled = false
        menu.addItem(cpuLine)
        menu.addItem(.separator())
        menu.addItem(phaseLine)
        for i in [startItem, skipItem, resetItem] { i.target = self; menu.addItem(i) }
        menu.addItem(todayItem)
        menu.addItem(.separator())

        let durationsItem = NSMenuItem(title: "Durations", action: nil, keyEquivalent: "")
        for (n, p) in PomodoroConfig.presets.enumerated() {
            let i = NSMenuItem(title: "\(p.work) min work · \(p.short) / \(p.long) min breaks", action: #selector(pickPreset(_:)), keyEquivalent: "")
            i.tag = n
            i.target = self
            durations.addItem(i)
        }
        durationsItem.submenu = durations
        menu.addItem(durationsItem)
        for i in [notifyItem, soundItem, autoItem, countdownItem] { i.target = self; menu.addItem(i) }
        menu.addItem(.separator())

        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit TuxedoRun", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    /// Brings the menu and the countdown up to date with the timer.
    func refresh() {
        // Countdown next to the cat.
        if let b = item.button {
            if prefs.showCountdown && pomo.phase != .idle {
                let color: NSColor = (pomo.isPaused || pomo.isReady) ? .secondaryLabelColor : (pomo.phase.isBreak ? .systemGreen : .labelColor)
                b.attributedTitle = NSAttributedString(string: " " + Pomodoro.format(pomo.remaining()), attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: color,
                ])
                b.imagePosition = .imageLeft
            } else {
                b.attributedTitle = NSAttributedString(string: "")
                b.imagePosition = .imageOnly
            }
        }

        let state = pomo.running ? "" : (pomo.isPaused ? " (paused)" : (pomo.isReady ? " (ready)" : ""))
        phaseLine.title = pomo.phase == .idle ? "Timer off" : "\(pomo.phase.label) · \(Pomodoro.format(pomo.remaining()))\(state)"
        if pomo.running { startItem.title = "Pause" }
        else if pomo.isPaused { startItem.title = "Resume" }
        else if pomo.phase.isBreak { startItem.title = pomo.phase == .longBreak ? "Start Long Break" : "Start Break" }
        else { startItem.title = "Start Focus" }
        skipItem.isEnabled = pomo.phase != .idle
        resetItem.isEnabled = pomo.phase != .idle
        todayItem.title = "Today: \(pomo.completedToday) session\(pomo.completedToday == 1 ? "" : "s")"

        let c = pomo.config
        for i in durations.items {
            let p = PomodoroConfig.presets[i.tag]
            i.state = (c.work == TimeInterval(p.work * 60) && c.shortBreak == TimeInterval(p.short * 60) && c.longBreak == TimeInterval(p.long * 60)) ? .on : .off
        }
        notifyItem.state = prefs.notifications ? .on : .off
        soundItem.state = prefs.sound ? .on : .off
        autoItem.state = c.autoStartBreaks ? .on : .off
        countdownItem.state = prefs.showCountdown ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func save() {
        guard !fast else { return }
        let enc = JSONEncoder()
        defaults.set(try? enc.encode(pomo.config), forKey: "config")
        defaults.set(try? enc.encode(prefs), forKey: "prefs")
        defaults.set(try? enc.encode(pomo.snapshot()), forKey: "state")
    }

    // MARK: Actions

    @objc func startPause() {
        if pomo.running { pomo.pause() }
        else {
            if pomo.phase == .idle && prefs.notifications { requestNotificationAccess() }
            pomo.start()
        }
        save(); refresh()
    }
    @objc func skip() { pomo.skip(); save(); refresh() }
    @objc func reset() { pomo.reset(); save(); refresh() }

    @objc func pickPreset(_ sender: NSMenuItem) {
        let p = PomodoroConfig.presets[sender.tag]
        var c = pomo.config
        c.work = TimeInterval(p.work * 60); c.shortBreak = TimeInterval(p.short * 60); c.longBreak = TimeInterval(p.long * 60)
        pomo.config = c
        save(); refresh()
    }
    @objc func toggleNotifications() {
        prefs.notifications.toggle()
        if prefs.notifications { requestNotificationAccess() }
        save(); refresh()
    }
    @objc func toggleSound() { prefs.sound.toggle(); save(); refresh() }
    @objc func toggleCountdown() { prefs.showCountdown.toggle(); save(); refresh() }
    @objc func toggleAutoStart() {
        var c = pomo.config
        c.autoStartBreaks.toggle()
        pomo.config = c
        save(); refresh()
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let a = NSAlert(); a.messageText = "Could not change Launch at Login"
            a.informativeText = "\(error.localizedDescription)\n\nMove TuxedoRun.app to /Applications and try again."
            a.runModal()
        }
        refresh()
    }

    // MARK: Phase end

    func phaseEnded(_ ended: Phase, _ next: Phase, _ nextRunning: Bool) {
        cheerUntil = Date().addingTimeInterval(3)
        if prefs.sound { NSSound(named: "Glass")?.play() }
        if prefs.notifications {
            let title: String, body: String
            if ended == .work {
                title = "Focus session done"
                body = nextRunning ? "\(next.label) started." : "Time for a \(next == .longBreak ? "long" : "short") break."
            } else {
                title = "\(ended.label) over"
                body = "Ready for the next focus session?"
            }
            notify(title, body)
        }
        save(); refresh()
    }

    func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func notify(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    /// Show the banner even though this app is "in front".
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .list])
    }

    // MARK: Animation

    func sample() {
        cpu = cpu * 0.4 + meter.usage() * 0.6
        stage = Stage(cpu: cpu)
        cpuLine.title = String(format: "CPU: %.0f%% · %@", cpu, stage.rawValue)
        pomo.tick()
        refresh()
    }

    /// One animation tick. Cheer after a phase ends, rest during a break, otherwise follow the CPU.
    func step() {
        ticks += 1
        frame += 1
        let interval: Double
        if Date() < cheerUntil {
            item.button?.image = cheerFrames[frame % cheerFrames.count]
            interval = 0.12
        } else if pomo.phase.isBreak && (pomo.running || pomo.isPaused) {
            item.button?.image = pomo.running ? breakFrames[frame % breakFrames.count] : breakFrames[0]
            interval = 0.6
        } else {
            switch stage {
            case .sleeping:
                item.button?.image = sleepFrames[frame % sleepFrames.count]
                interval = 0.6
            case .waving:
                item.button?.image = ticks % 37 == 0 ? waveBlink : waveFrames[frame % waveFrames.count]
                interval = 0.22 - 0.14 * min(max((cpu - 33) / 37, 0), 1)
            case .running:
                item.button?.image = runFrames[frame % runFrames.count]
                interval = 0.08 - 0.05 * min(max((cpu - 70) / 30, 0), 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in self?.step() }
    }
}

// `TuxedoRun --selftest` checks the pomodoro logic and exits.
if CommandLine.arguments.contains("--selftest") { runSelfTest() }

// `TuxedoRun --dump out.png` writes every frame to one PNG sheet and exits, to check the art without a menu bar.
if let i = CommandLine.arguments.firstIndex(of: "--dump"), i + 1 < CommandLine.arguments.count {
    let all = sleepFrames + waveFrames + [waveBlink] + runFrames + breakFrames + cheerFrames
    let scale: CGFloat = 8, cols = 6
    let cell = NSSize(width: CGFloat(gridW) * px * scale + 8, height: CGFloat(gridH) * px * scale + 8)
    let rows = (all.count + cols - 1) / cols
    let sheet = NSImage(size: NSSize(width: cell.width * CGFloat(cols), height: cell.height * CGFloat(rows)))
    sheet.lockFocus()
    hex(0x3a6ea5).setFill(); NSRect(origin: .zero, size: sheet.size).fill() // the menu bar's blue
    NSGraphicsContext.current?.imageInterpolation = .none
    for (n, img) in all.enumerated() {
        let x = CGFloat(n % cols) * cell.width + 4, y = sheet.size.height - CGFloat(n / cols + 1) * cell.height + 4
        img.draw(in: NSRect(x: x, y: y, width: img.size.width * scale, height: img.size.height * scale))
    }
    sheet.unlockFocus()
    let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}

// `TuxedoRun --export dir` writes an animated GIF per stage, and one that tours them all, for the README.
if let i = CommandLine.arguments.firstIndex(of: "--export"), i + 1 < CommandLine.arguments.count {
    let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let scale: CGFloat = 8, pad: Int = 24
    func gif(_ name: String, _ frames: [(NSImage, Double)]) {
        let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name) as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for (img, delay) in frames {
            let w = Int(img.size.width * scale) + pad * 2, h = Int(img.size.height * scale) + pad * 2
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            let ctx = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .none
            hex(0x2b2f3a).setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
            img.draw(in: NSRect(x: CGFloat(pad), y: CGFloat(pad), width: img.size.width * scale, height: img.size.height * scale))
            NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(dest, rep.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        CGImageDestinationFinalize(dest)
    }
    let sleep = sleepFrames.map { ($0, 0.6) }
    let wave = waveFrames.map { ($0, 0.14) }
    let run = runFrames.map { ($0, 0.07) }
    let rest = breakFrames.map { ($0, 0.6) }
    let cheer = cheerFrames.map { ($0, 0.12) }
    gif("sleeping.gif", sleep + sleep)
    gif("waving.gif", wave + wave)
    gif("running.gif", Array(repeating: run, count: 6).flatMap { $0 })
    gif("break.gif", rest + rest)
    gif("cheer.gif", cheer + cheer)
    gif("hero.gif", sleep + sleep + wave + wave + Array(repeating: run, count: 5).flatMap { $0 } + cheer + rest + rest)
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
