import Cocoa
let img = NSImage(size: NSSize(width: 32, height: 32))
img.lockFocus()
let str = NSAttributedString(string: "فا", attributes: [.font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: NSColor.black])
let sz = str.size()
str.draw(at: NSPoint(x: (32 - sz.width) / 2, y: (32 - sz.height) / 2))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .tiff, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
