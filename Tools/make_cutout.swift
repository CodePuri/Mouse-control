import AppKit
import CoreGraphics

func processImage(inputPath: String, outputPath: String) {
    guard let srcImage = NSImage(contentsOfFile: inputPath),
          let tiffData = srcImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        print("Failed to load \(inputPath)")
        return
    }
    
    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh
    
    // Create RGBA context
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
    defer { rawData.deallocate() }
    
    guard let context = CGContext(
        data: rawData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create context")
        return
    }
    
    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = graphicsContext
    srcImage.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    
    // Flood fill background from corners (0,0), (width-1, 0), (0, height-1), (width-1, height-1)
    var visited = [Bool](repeating: false, count: width * height)
    var queue: [(Int, Int)] = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1),
                               (width / 2, 0), (width / 2, height - 1), (0, height / 2), (width - 1, height / 2)]
    
    for (qx, qy) in queue {
        visited[qy * width + qx] = true
    }
    
    func isNearWhite(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        // Kreo background is ~250, 250, 250
        let minC = min(r, min(g, b))
        let maxC = max(r, max(g, b))
        let diff = Int(maxC) - Int(minC)
        return minC > 235 && diff < 20
    }
    
    var head = 0
    while head < queue.count {
        let (x, y) = queue[head]
        head += 1
        
        let offset = (y * width + x) * 4
        let r = rawData[offset]
        let g = rawData[offset + 1]
        let b = rawData[offset + 2]
        
        if isNearWhite(r: r, g: g, b: b) {
            // Set alpha to 0
            rawData[offset + 3] = 0
            
            // Check 4-neighbors
            let neighbors = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            for (nx, ny) in neighbors {
                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let nIdx = ny * width + nx
                    if !visited[nIdx] {
                        visited[nIdx] = true
                        queue.append((nx, ny))
                    }
                }
            }
        }
    }
    
    guard let newCGImage = context.makeImage() else {
        print("Failed to make image")
        return
    }
    
    let newRep = NSBitmapImageRep(cgImage: newCGImage)
    guard let pngData = newRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }
    
    try? pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote cutout to \(outputPath)")
}

processImage(inputPath: "Mac_Peripheral_Control_Reference_Pack/references/kreo_black_1.png",
             outputPath: "Resources/kreo_top_cutout.png")
processImage(inputPath: "Mac_Peripheral_Control_Reference_Pack/references/kreo_black_5.png",
             outputPath: "Resources/kreo_side_cutout.png")
