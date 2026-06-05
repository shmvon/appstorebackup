import AppKit
import CoreGraphics

func createIconImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    let context = NSGraphicsContext.current!.cgContext
    
    // Draw rounded rect background with gradient (matching macOS app icon standard)
    let padding = size * 0.082
    let iconSize = size - (padding * 2)
    let rect = CGRect(x: padding, y: padding, width: iconSize, height: iconSize)
    
    let clipPath = CGPath(roundedRect: rect, cornerWidth: iconSize * 0.225, cornerHeight: iconSize * 0.225, transform: nil)
    context.addPath(clipPath)
    context.clip()
    
    // Gradient colors (Blue to Purple)
    let colors = [
        NSColor(red: 0.11, green: 0.38, blue: 0.94, alpha: 1.0).cgColor,
        NSColor(red: 0.58, green: 0.22, blue: 0.88, alpha: 1.0).cgColor
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    context.drawLinearGradient(gradient, start: CGPoint(x: padding, y: padding + iconSize), end: CGPoint(x: padding + iconSize, y: padding), options: [])
    
    // Draw SF Symbol in white in the center
    if let symbol = NSImage(systemSymbolName: "square.and.arrow.down.on.square.fill", accessibilityDescription: nil) {
        let symbolSize = iconSize * 0.52
        let symbolRect = NSRect(
            x: padding + (iconSize - symbolSize) / 2,
            y: padding + (iconSize - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )
        
        let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .bold)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
        
        if let configuredSymbol = symbol.withSymbolConfiguration(config) {
            configuredSymbol.draw(in: symbolRect)
        } else {
            symbol.draw(in: symbolRect)
        }
    }
    
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    var proposedRect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
        print("Failed to get CGImage representation for \(path)")
        return
    }
    
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = image.size
    
    guard
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to get PNG representation for \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Error saving image to \(path): \(error.localizedDescription)")
    }
}

let fileManager = FileManager.default
let iconsetDir = "AppIcon.iconset"
try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true, attributes: nil)

let sizes: [(name: String, px: CGFloat)] = [
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

print("Generating PNG assets for AppIcon...")
for sizeInfo in sizes {
    let img = createIconImage(size: sizeInfo.px)
    savePNG(image: img, path: "\(iconsetDir)/\(sizeInfo.name)")
}

print("Running iconutil to compile AppIcon.icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir, "-o", "AppIcon.icns"]
do {
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        print("iconutil failed with status \(process.terminationStatus)")
        exit(1)
    }
} catch {
    print("Failed running iconutil: \(error.localizedDescription)")
    exit(1)
}

// Cleanup
try? fileManager.removeItem(atPath: iconsetDir)
print("AppIcon.icns generated successfully!")
