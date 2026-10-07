import Cocoa
import CoreText

// Menu-bar icon: Persian letters centred on their real ink bounds (not the font's line box),
// drawn at 2x (32 px) for a 16 pt icon, black on transparent so macOS renders it as a template.
let px = 32
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let ctx = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }
rep.size = NSSize(width: 16, height: 16)

let font = NSFont.systemFont(ofSize: 22, weight: .semibold)
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "فا", attributes: [.font: font, .foregroundColor: NSColor.black]))
let ink = CTLineGetImageBounds(line, ctx.cgContext)
NSGraphicsContext.current = ctx
ctx.cgContext.textPosition = CGPoint(x: (CGFloat(px) - ink.width) / 2 - ink.minX,
                                     y: (CGFloat(px) - ink.height) / 2 - ink.minY)
CTLineDraw(line, ctx.cgContext)

try! rep.representation(using: .tiff, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
if CommandLine.arguments.count > 2 {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
