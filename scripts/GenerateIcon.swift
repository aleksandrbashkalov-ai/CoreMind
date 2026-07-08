// CoreMind App Icon Generator
// Swift script — run: swift Scripts/GenerateIcon.swift
// Generates 1024x1024 PNG icon at Scripts/icon_1024.png

import Cocoa

let size = CGSize(width: 1024, height: 1024)
let brandPurple = CGColor(red: 0.42, green: 0.22, blue: 0.80, alpha: 1.0)   // #6B38CC
let brandLight = CGColor(red: 0.55, green: 0.32, blue: 0.90, alpha: 1.0)    // #8C52E6
let accentCyan = CGColor(red: 0.20, green: 0.80, blue: 0.80, alpha: 1.0)    // #33CCCC

func createIcon() -> NSImage {
    let image = NSImage(size: size)
    
    image.lockFocusFlipped(false)
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    let rect = CGRect(origin: .zero, size: size)
    let inset: CGFloat = 40
    let inner = rect.insetBy(dx: inset, dy: inset)
    
    // === 1. Background: rounded rect with purple gradient ===
    let bgPath = CGPath(roundedRect: rect, cornerWidth: 180, cornerHeight: 180, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()
    
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [brandLight, brandPurple] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: size.width, y: size.height),
        options: []
    )
    
    // Subtle radial overlay for depth
    let radialGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.12),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(
        radialGradient,
        startCenter: CGPoint(x: size.width * 0.3, y: size.height * 0.3),
        startRadius: 0,
        endCenter: CGPoint(x: size.width * 0.3, y: size.height * 0.3),
        endRadius: size.width * 0.8,
        options: []
    )
    
    // === 2. Brain icon (stylized) ===
    ctx.translateBy(x: size.width / 2, y: size.height / 2)
    
    let brainColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    ctx.setFillColor(brainColor)
    ctx.setStrokeColor(brainColor)
    ctx.setLineWidth(6)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    
    // Draw a stylized brain using two hemispheres connected
    
    // Left hemisphere
    let leftBrain = CGMutablePath()
    leftBrain.move(to: CGPoint(x: -30, y: 60))
    // Top of left hemisphere
    leftBrain.addCurve(to: CGPoint(x: -150, y: 80),
                        control1: CGPoint(x: -70, y: 140),
                        control2: CGPoint(x: -140, y: 130))
    // Left side
    leftBrain.addCurve(to: CGPoint(x: -170, y: -20),
                        control1: CGPoint(x: -160, y: 60),
                        control2: CGPoint(x: -180, y: 10))
    // Bottom
    leftBrain.addCurve(to: CGPoint(x: -130, y: -110),
                        control1: CGPoint(x: -160, y: -60),
                        control2: CGPoint(x: -150, y: -110))
    leftBrain.addCurve(to: CGPoint(x: -40, y: -100),
                        control1: CGPoint(x: -100, y: -110),
                        control2: CGPoint(x: -60, y: -120))
    // Center bottom
    leftBrain.addCurve(to: CGPoint(x: -20, y: -60),
                        control1: CGPoint(x: -20, y: -90),
                        control2: CGPoint(x: -10, y: -70))
    
    // Right hemisphere
    let rightBrain = CGMutablePath()
    rightBrain.move(to: CGPoint(x: 30, y: 60))
    rightBrain.addCurve(to: CGPoint(x: 150, y: 80),
                         control1: CGPoint(x: 70, y: 140),
                         control2: CGPoint(x: 140, y: 130))
    rightBrain.addCurve(to: CGPoint(x: 170, y: -20),
                         control1: CGPoint(x: 160, y: 60),
                         control2: CGPoint(x: 180, y: 10))
    rightBrain.addCurve(to: CGPoint(x: 130, y: -110),
                         control1: CGPoint(x: 160, y: -60),
                         control2: CGPoint(x: 150, y: -110))
    rightBrain.addCurve(to: CGPoint(x: 40, y: -100),
                         control1: CGPoint(x: 100, y: -110),
                         control2: CGPoint(x: 60, y: -120))
    rightBrain.addCurve(to: CGPoint(x: 20, y: -60),
                         control1: CGPoint(x: 20, y: -90),
                         control2: CGPoint(x: 10, y: -70))
    
    // Draw hemispheres
    ctx.beginPath()
    ctx.addPath(leftBrain)
    ctx.addPath(rightBrain)
    ctx.drawPath(using: .fill)
    
    // === 3. Brain sulci/gyri lines (detail) ===
    ctx.setStrokeColor(CGColor(red: 0.42, green: 0.22, blue: 0.80, alpha: 0.3))
    ctx.setLineWidth(3)
    
    // Left hemisphere folds
    let folds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (-100, 50, -60, 70),
        (-130, 20, -90, 40),
        (-140, -20, -100, 0),
        (-120, -60, -80, -40),
        (-80, -70, -50, -50),
    ]
    
    for (x1, y1, x2, y2) in folds {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addCurve(to: CGPoint(x: x2, y: y2),
                      control1: CGPoint(x: (x1 + x2) / 2, y: y1 + 10),
                      control2: CGPoint(x: (x1 + x2) / 2, y: y2 - 10))
        ctx.drawPath(using: .stroke)
    }
    
    // Right hemisphere folds (mirrored)
    let foldsR: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (100, 50, 60, 70),
        (130, 20, 90, 40),
        (140, -20, 100, 0),
        (120, -60, 80, -40),
        (80, -70, 50, -50),
    ]
    
    for (x1, y1, x2, y2) in foldsR {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addCurve(to: CGPoint(x: x2, y: y2),
                      control1: CGPoint(x: (x1 + x2) / 2, y: y1 + 10),
                      control2: CGPoint(x: (x1 + x2) / 2, y: y2 - 10))
        ctx.drawPath(using: .stroke)
    }
    
    // === 4. Central accent line (mindfulness) ===
    ctx.setStrokeColor(accentCyan)
    ctx.setLineWidth(5)
    ctx.setAlpha(0.6)
    
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 0, y: 100))
    ctx.addCurve(to: CGPoint(x: 0, y: -120),
                  control1: CGPoint(x: -15, y: 40),
                  control2: CGPoint(x: 15, y: -20))
    ctx.drawPath(using: .stroke)
    
    // Small dot at top
    ctx.setAlpha(1.0)
    ctx.setFillColor(accentCyan)
    ctx.fillEllipse(in: CGRect(x: -6, y: 94, width: 12, height: 12))
    
    ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
    image.unlockFocus()
    return image
}

// Generate and save
let icon = createIcon()
let outputPath = "Scripts/icon_1024.png"
guard let data = icon.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: data),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR: Failed to generate PNG")
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
print("OK: \(outputPath) (\(pngData.count) bytes)")
