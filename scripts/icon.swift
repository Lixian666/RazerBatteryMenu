import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let factor = CGFloat(pixels) / 1024
    let t = NSAffineTransform()
    t.scale(by: factor)
    t.concat()
    NSColor(calibratedRed: 0.07, green: 0.12, blue: 0.10, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 210, yRadius: 210
    ).fill()
    NSColor(calibratedRed: 0.35, green: 0.90, blue: 0.55, alpha: 1).setStroke()
    let mouse = NSBezierPath(
      roundedRect: NSRect(x: 300, y: 214, width: 424, height: 596), xRadius: 195, yRadius: 195)
    mouse.lineWidth = 44
    mouse.stroke()
    NSColor(calibratedRed: 0.35, green: 0.90, blue: 0.55, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 486, y: 636, width: 52, height: 108), xRadius: 26, yRadius: 26
    ).fill()
    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: 539, y: 579))
    bolt.line(to: NSPoint(x: 422, y: 418))
    bolt.line(to: NSPoint(x: 499, y: 418))
    bolt.line(to: NSPoint(x: 476, y: 322))
    bolt.line(to: NSPoint(x: 600, y: 482))
    bolt.line(to: NSPoint(x: 524, y: 482))
    bolt.close()
    bolt.fill()
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
    try rep.representation(using: .png, properties: [:])!.write(
      to: directory.appendingPathComponent(name))
  }
}
