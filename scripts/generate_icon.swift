import Foundation
import CoreGraphics
import ImageIO

// Generates the selected fourth waveform icon at all required macOS icon sizes.
let sizes = [16, 32, 128, 256, 512]
let manager = FileManager.default
let destination = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/SpeechSculptor.iconset", isDirectory: true)
try manager.createDirectory(at: destination, withIntermediateDirectories: true)

enum RenderError: Error {
    case contextCreation, imageCreation, destinationCreation, writeFailure
}

func draw(size: Int, fileURL: URL) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw RenderError.contextCreation }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.scaleBy(x: CGFloat(size) / 1024.0, y: CGFloat(size) / 1024.0)

    let backing = CGPath(
        roundedRect: CGRect(x: 34, y: 34, width: 956, height: 956),
        cornerWidth: 228, cornerHeight: 228, transform: nil
    )
    context.addPath(backing)
    context.setFillColor(CGColor(gray: 0.946, alpha: 1))
    context.fillPath()

    context.addEllipse(in: CGRect(x: 177, y: 177, width: 670, height: 670))
    context.setFillColor(CGColor(gray: 0.08, alpha: 1))
    context.fillPath()

    let points = [
        CGPoint(x: 212, y: 511), CGPoint(x: 338, y: 511),
        CGPoint(x: 396, y: 592), CGPoint(x: 476, y: 390),
        CGPoint(x: 556, y: 665), CGPoint(x: 624, y: 461),
        CGPoint(x: 692, y: 543), CGPoint(x: 811, y: 543)
    ]
    context.addLines(between: points)
    context.setLineWidth(61)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(CGColor(gray: 0.946, alpha: 1))
    context.strokePath()

    guard let image = context.makeImage() else { throw RenderError.imageCreation }
    guard let png = CGImageDestinationCreateWithURL(
        fileURL as CFURL, "public.png" as CFString, 1, nil
    ) else { throw RenderError.destinationCreation }
    CGImageDestinationAddImage(png, image, nil)
    guard CGImageDestinationFinalize(png) else { throw RenderError.writeFailure }
}

for points in sizes {
    try draw(size: points, fileURL: destination.appendingPathComponent("icon_\(points)x\(points).png"))
    try draw(size: points * 2, fileURL: destination.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
print("Iconset saved: \(destination.path)")
