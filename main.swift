import Cocoa
import ServiceManagement

// MARK: - Sprite (the pixel-pet tuxedo cat, 16x12)

let sprite = [
    ".aa..........aa.",
    "akia........aika",
    "akkkaaaaaaaakkka",
    "akkkkkkwwkkkkkka",
    "akkkkkkwwkkkkkka",
    "akkkkkwwwwkkkkka",
    "asskwwwppwwwkssa",
    "akkkwwwmmwwwkkka",
    "asskwwwwwwwwkssa",
    "akkkkwwwwwwkkkka",
    "akkkkkwwwwkkkkka",
    ".aaaaaaaaaaaaaa.",
].map { Array($0) }

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
            blue: CGFloat(v & 255) / 255, alpha: a)
}

let palette: [Character: NSColor] = [
    "a": hex(0x12121a), "k": hex(0x3a3a4c), "i": hex(0xc27a8f), "w": hex(0xf6f6f6),
    "s": hex(0xb9bcc8), "p": hex(0xf58fa8), "m": hex(0xc27a8f),
]
let eyeColor = hex(0xc9e060)
let rimColor = hex(0xe6e8f2, 0.9) // light rim so the dark cat reads on a dark menu bar
let eyes = [(3, 4), (11, 4)]

// MARK: - Frames

let spriteW = 16, spriteH = 12
let leftMargin = 3, rightMargin = 3 // room for speed streaks and sleeping z's
let gridW = leftMargin + 1 + spriteW + 1 + rightMargin
let gridH = spriteH + 2 // 1px rim around, 1px of hop headroom
let px: CGFloat = 1.5

struct Pose {
    var hop = 0
    var ear = 0        // horizontal shift of the ear rows
    var lean = 0       // horizontal shift of the whole cat
    var blink = false  // eyes closed
    var streak = -1    // speed lines phase, -1 for none
    var z = -1         // rising z phase, -1 for none
}

let zShape = ["zzz", "..z", ".z.", "z..", "zzz"]
let zRows = [8, 6, 4, 2]
let zAlpha: [CGFloat] = [1, 0.9, 0.7, 0.4]

func render(_ pose: Pose) -> NSImage {
    var grid = [[NSColor?]](repeating: [NSColor?](repeating: nil, count: gridW), count: gridH)
    let ox = leftMargin + 1 + pose.lean
    let top = gridH - spriteH - pose.hop
    for (y, row) in sprite.enumerated() {
        for (x, ch) in row.enumerated() {
            guard let c = palette[ch] else { continue }
            let gx = x + ox + (y < 2 ? pose.ear : 0), gy = top + y
            if gx >= 0, gx < gridW, gy >= 0, gy < gridH { grid[gy][gx] = c }
        }
    }
    for (ex, ey) in eyes {
        for dy in 0..<2 { for dx in 0..<2 {
            let gy = top + ey + dy, gx = ex + ox + dx
            if pose.blink { grid[gy][gx] = dy == 1 ? palette["a"] : palette["k"] }
            else { grid[gy][gx] = eyeColor }
        } }
    }
    var rim = [[Bool]](repeating: [Bool](repeating: false, count: gridW), count: gridH)
    for y in 0..<gridH { for x in 0..<gridW where grid[y][x] == nil {
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = x + dx, ny = y + dy
            if nx >= 0, nx < gridW, ny >= 0, ny < gridH, grid[ny][nx] != nil { rim[y][x] = true }
        }
    } }
    // Effects sit outside the cat: streaks on the left, z's on the right.
    var fx = [(Int, Int, CGFloat)]()
    if pose.streak >= 0 {
        let lines = [(5, 1 + pose.streak % 2), (7, pose.streak % 3 == 0 ? 0 : 1), (9, 1 + (pose.streak + 1) % 2)]
        for (y, x0) in lines { for x in x0..<(leftMargin) { fx.append((x, y, 0.85)) } }
    }
    if pose.z >= 0 {
        let x0 = gridW - rightMargin, y0 = zRows[pose.z]
        for (dy, row) in zShape.enumerated() { for (dx, ch) in row.enumerated() where ch == "z" {
            fx.append((x0 + dx, y0 + dy, zAlpha[pose.z]))
        } }
    }
    let size = NSSize(width: CGFloat(gridW) * px, height: CGFloat(gridH) * px)
    return NSImage(size: size, flipped: true) { _ in
        NSGraphicsContext.current?.shouldAntialias = false
        for y in 0..<gridH { for x in 0..<gridW {
            let r = NSRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: px, height: px)
            if let c = grid[y][x] { c.setFill(); r.fill() }
            else if rim[y][x] { rimColor.setFill(); r.fill() }
        } }
        for (x, y, a) in fx where x >= 0 && x < gridW && y >= 0 && y < gridH {
            hex(0xe6e8f2, a).setFill()
            NSRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: px, height: px).fill()
        }
        return true
    }
}

enum Stage: String {
    case sleeping = "Sleeping", waving = "Waving ears", running = "Running"
    init(cpu: Double) { self = cpu < 33 ? .sleeping : (cpu <= 70 ? .waving : .running) }
}

// Sleeping: eyes shut, z's drift up.
let sleepFrames = (0..<4).map { render(Pose(blink: true, z: $0)) }
// Waving ears: the hop and ear flop from before.
let waveHops = [0, 1, 1, 0, 0, 1, 1, 0]
let waveEars = [0, 0, -1, -1, 0, 0, 1, 1]
let waveFrames = (0..<waveHops.count).map { render(Pose(hop: waveHops[$0], ear: waveEars[$0])) }
let waveBlink = render(Pose(blink: true))
// Running: leaning forward, ears pinned back, speed lines streaking behind.
let runHops = [0, 1, 1, 0]
let runEars = [1, 2, 2, 1]
let runFrames = (0..<4).map { render(Pose(hop: runHops[$0], ear: runEars[$0], lean: 1, streak: $0)) }

// MARK: - CPU

final class CPUMeter {
    private var last: [UInt32] = []
    func usage() -> Double {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return 0 }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)) }
        var now: [UInt32] = []
        for i in 0..<Int(count) {
            for s in 0..<Int(CPU_STATE_MAX) { now.append(UInt32(bitPattern: info[i * Int(CPU_STATE_MAX) + s])) }
        }
        defer { last = now }
        guard last.count == now.count else { return 0 }
        var busy = 0.0, total = 0.0
        for i in 0..<Int(count) {
            let base = i * Int(CPU_STATE_MAX)
            let user = Double(now[base + Int(CPU_STATE_USER)] &- last[base + Int(CPU_STATE_USER)])
            let sys = Double(now[base + Int(CPU_STATE_SYSTEM)] &- last[base + Int(CPU_STATE_SYSTEM)])
            let nice = Double(now[base + Int(CPU_STATE_NICE)] &- last[base + Int(CPU_STATE_NICE)])
            let idle = Double(now[base + Int(CPU_STATE_IDLE)] &- last[base + Int(CPU_STATE_IDLE)])
            busy += user + sys + nice
            total += user + sys + nice + idle
        }
        return total > 0 ? busy / total * 100 : 0
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let meter = CPUMeter()
    let cpuLine = NSMenuItem(title: "CPU: --", action: nil, keyEquivalent: "")
    let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
    var cpu = 0.0 // smoothed, so the cat does not flap between stages
    var stage = Stage.sleeping
    var frame = 0
    var ticks = 0

    func applicationDidFinishLaunching(_ n: Notification) {
        item.button?.image = sleepFrames[0]
        item.button?.toolTip = "TuxedoRun: sleeps under 33% CPU, waves its ears to 70%, runs above"

        let menu = NSMenu()
        cpuLine.isEnabled = false
        menu.addItem(cpuLine)
        menu.addItem(.separator())
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit TuxedoRun", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        _ = meter.usage()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.sample() }
        step()
    }

    func sample() {
        cpu = cpu * 0.4 + meter.usage() * 0.6
        stage = Stage(cpu: cpu)
        cpuLine.title = String(format: "CPU: %.0f%% · %@", cpu, stage.rawValue)
    }

    /// One animation tick; the next comes sooner the busier the CPU is within the stage.
    func step() {
        ticks += 1
        frame += 1
        let interval: Double
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
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in self?.step() }
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
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

// `TuxedoRun --dump out.png` writes every frame to one PNG strip and exits, to check the art without a menu bar.
if let i = CommandLine.arguments.firstIndex(of: "--dump"), i + 1 < CommandLine.arguments.count {
    let all = sleepFrames + waveFrames + [waveBlink] + runFrames
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

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
