import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let input = CommandLine.arguments.count > 2 ? NSImage(contentsOfFile: CommandLine.arguments[2]) : nil
let orange = NSColor(calibratedRed: 1.0, green: 0.40, blue: 0.09, alpha: 1.0)

func contextImage(_ width: Int, _ height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    draw()
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, to file: URL) {
    try! rep.representation(using: .png, properties: [:])!.write(to: file)
}

func star(_ cx: CGFloat, _ cy: CGFloat, _ outer: CGFloat) {
    let p = NSBezierPath()
    for i in 0..<10 {
        let a = CGFloat(i) * .pi / 5 + .pi / 2
        let radius = i.isMultiple(of: 2) ? outer : outer * 0.40
        let pt = NSPoint(x: cx + cos(a)*radius, y: cy + sin(a)*radius)
        if i == 0 { p.move(to:pt) } else { p.line(to:pt) }
    }
    p.close()
    orange.setFill()
    p.fill()
    for j in 0..<2 {
        let sweep = NSBezierPath()
        sweep.lineWidth = 8 - CGFloat(j)*2
        sweep.move(to: NSPoint(x:cx + 6, y:cy + 11 + CGFloat(j)*20))
        sweep.curve(to: NSPoint(x:cx + outer*1.9, y:cy + outer*0.75 + CGFloat(j)*16),
            controlPoint1:NSPoint(x:cx + outer*0.60, y:cy + outer*0.93),
            controlPoint2:NSPoint(x:cx + outer*1.30, y:cy + outer*0.92))
        orange.setStroke()
        sweep.stroke()
    }
}

let icon = contextImage(1024, 1024) {
    NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.09, alpha: 1).setFill()
    NSRect(x:0,y:0,width:1024,height:1024).fill()
    if let image = input, image.size.width > 300 {
        image.draw(in:NSRect(x:115,y:270,width:790,height:640),
                   from:NSRect(x:0,y:140,width:200,height:230),
                   operation:.sourceOver,fraction:1)
    } else {
        star(370,565,218)
    }
    let text = "GTA5 RP" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize:130, weight:.black),
        .foregroundColor: NSColor.white
    ]
    let size = text.size(withAttributes: attributes)
    text.draw(at:NSPoint(x:(1024-size.width)/2,y:120),withAttributes:attributes)
}
save(icon, to:root.appendingPathComponent("AppIcon.appiconset/icon.png"))

let logo = contextImage(700, 250) {
    NSColor.clear.setFill()
    NSRect(x:0,y:0,width:700,height:250).fill()
    star(100,109,94)
    ("GTA5" as NSString).draw(at:NSPoint(x:192,y:60),withAttributes:[
        .font:NSFont.systemFont(ofSize:90, weight:.black),.foregroundColor:NSColor.white])
    (" RP" as NSString).draw(at:NSPoint(x:452,y:60),withAttributes:[
        .font:NSFont.systemFont(ofSize:87, weight:.regular),.foregroundColor:NSColor.white])
}
save(logo, to:root.appendingPathComponent("GTA5RPLogo.imageset/logo.png"))
try! #"""
{"images":[{"filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""#.write(to: root.appendingPathComponent("AppIcon.appiconset/Contents.json"),atomically:true,encoding:.utf8)
try! #"""
{"images":[{"filename":"logo.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}
"""#.write(to: root.appendingPathComponent("GTA5RPLogo.imageset/Contents.json"),atomically:true,encoding:.utf8)
