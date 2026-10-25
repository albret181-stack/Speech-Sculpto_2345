import AppKit
import Foundation

// App icon inspired by the selected fourth concept: monochrome voice waveform.
let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
let fm = FileManager.default
let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/SpeechSculptor.iconset", isDirectory: true)
try fm.createDirectory(at: output, withIntermediateDirectories: true)

func render(size: Int, url: URL) throws {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocus()
    defer { image.unlockFocus() }

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.scaleBy(x: dimension / 1024, y: dimension / 1024)

    // A clean squircle, without the generated image's outer photographic backdrop.
    let background = NSBezierPath(roundedRect: NSRect(x: 34, y: 34, width: 956, height: 956),
                                  xRadius: 228, yRadius: 228)
    NSColor(calibratedWhite: 0.946, alpha: 1).setFill()
    background.fill()

    NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 177, y: 177, width: 670, height: 670)).fill()

    // A waveform carved out of the circle, matching the fourth icon's central motif.
    let wave = NSBezierPath()
    wave.lineWidth = 61
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    wave.move(to: NSPoint(x: 212, y: 511))
    wave.line(to: NSPoint(x: 338, y: 511))
    wave.line(to: NSPoint(x: 396, y: 592))
    wave.line(to: NSPoint(x: 476, y: 390))
    wave.line(to: NSPoint(x: 556, y: 665))
    wave.line(to: NSPoint(x: 624, y: 461))
    wave.line(to: NSPoint(x: 692, y: 543))
    wave.line(to: NSPoint(x: 811, y: 543))
    NSColor(calibratedWhite: 0.946, alpha: 1).setStroke()
    wave.stroke()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: nil)
    }
    try data.write(to: url)
}

for size in sizes where size <= 512 {
    try render(size: size, url: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size: size * 2, url: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
print("Generated macOS iconset at \(output.path)")
