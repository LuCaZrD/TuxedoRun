import Cocoa

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
    var heart = -1     // rising heart phase (on a break), -1 for none
    var sparkle = -1   // cheer sparkles phase, -1 for none
}

let zShape = ["zzz", "..z", ".z.", "z..", "zzz"]
let zRows = [8, 6, 4, 2]
let zAlpha: [CGFloat] = [1, 0.9, 0.7, 0.4]
let heartShape = ["h.h", "hhh", ".h."]
let sparkShape = [".y.", "yyy", ".y."]

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
    var tinted = [(Int, Int, NSColor)]()
    if pose.heart >= 0 { // a heart drifts up on the right while the cat rests
        let x0 = gridW - rightMargin, y0 = zRows[pose.heart]
        for (dy, row) in heartShape.enumerated() { for (dx, ch) in row.enumerated() where ch == "h" {
            tinted.append((x0 + dx, y0 + dy, hex(0xf58fa8, zAlpha[pose.heart])))
        } }
    }
    if pose.sparkle >= 0 { // sparkles pop on both sides, alternating
        let rows = pose.sparkle % 2 == 0 ? (1, 6) : (6, 1)
        for (x0, y0) in [(0, rows.0), (gridW - 3, rows.1)] {
            for (dy, row) in sparkShape.enumerated() { for (dx, ch) in row.enumerated() where ch == "y" {
                tinted.append((x0 + dx, y0 + dy, hex(0xffe25a)))
            } }
        }
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
        for (x, y, c) in tinted where x >= 0 && x < gridW && y >= 0 && y < gridH {
            c.setFill()
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
// Break: eyes shut and content, a heart drifts up.
let breakFrames = (0..<4).map { render(Pose(blink: true, heart: $0)) }
// Cheer when a phase ends: hops with sparkles on both sides.
let cheerHops = [1, 0, 1, 0, 1, 0]
let cheerFrames = (0..<6).map { render(Pose(hop: cheerHops[$0], sparkle: $0)) }
