import Cocoa

func generateIconSet() {
    let iconSizes: [(String, CGFloat)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    let iconsetDir = "Resources/AppIcon.iconset"
    try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
    
    let mouseImg = NSImage(contentsOfFile: "Resources/kreo_top_cutout.png")
    
    for (filename, size) in iconSizes {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        // Draw macOS squircle base
        let cornerRadius = size * 0.2237 // Standard Apple squircle ratio
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: cornerRadius, yRadius: cornerRadius)
        
        // Gradient background
        let gradient = NSGradient(colors: [
            NSColor(red: 22/255, green: 25/255, blue: 31/255, alpha: 1.0),
            NSColor(red: 11/255, green: 13/255, blue: 16/255, alpha: 1.0)
        ])!
        gradient.draw(in: path, angle: -45)
        
        // Subtle cyan border
        NSColor(red: 39/255, green: 199/255, blue: 247/255, alpha: 0.35).setStroke()
        path.lineWidth = max(1.0, size * 0.015)
        path.stroke()
        
        // Mouse image in center
        if let m = mouseImg {
            let mRect = CGRect(
                x: size * 0.18,
                y: size * 0.12,
                width: size * 0.64,
                height: size * 0.76
            )
            m.draw(in: mRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        let pngData = rep.representation(using: .png, properties: [:])!
        let filePath = "\(iconsetDir)/\(filename)"
        try! pngData.write(to: URL(fileURLWithPath: filePath))
    }
    
    print("Iconset generated successfully at \(iconsetDir)")
}

generateIconSet()
