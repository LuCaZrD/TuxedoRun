import Cocoa

// MARK: - The avatar
//
// Everything that makes the menu bar pet look like this tuxedo cat lives in this file.
// To use a different pet, replace the values below and leave the rest of the app alone.
// See AGENTS.md ("Create a new avatar") for the rules and a checklist.

/// Pixel rows. One character is one pixel; `.` is clear. Every row must be the same width.
/// Keep it about 16 wide and 12 tall; a bigger sprite is shrunk to fit the menu bar.
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

/// The color of each sprite character. A character with no color draws clear.
let palette: [Character: NSColor] = [
    "a": hex(0x12121a), "k": hex(0x3a3a4c), "i": hex(0xc27a8f), "w": hex(0xf6f6f6),
    "s": hex(0xb9bcc8), "p": hex(0xf58fa8), "m": hex(0xc27a8f),
]

/// The top-left pixel of each 2x2 eye, as (x, y) in sprite pixels. Leave empty for a pet with no eyes.
/// The sprite should show a flat patch of body color under each eye; the app paints the eyes over it.
let eyes = [(3, 4), (11, 4)]
let eyeColor = hex(0xc9e060)
/// A closed eye (sleeping, blinking, resting) is a 2x1 line: the top row takes the body color,
/// the bottom row the line color.
let closedEyeBody = palette["k"]!
let closedEyeLine = palette["a"]!

/// The top rows of the sprite that count as ears: they flop while the pet waves and lay back while it runs.
/// Use 0 for a pet with no ears.
let earRows = 2

/// The light rim drawn around the pet so a dark pet still reads on a dark menu bar.
let rimColor = hex(0xe6e8f2, 0.9)

