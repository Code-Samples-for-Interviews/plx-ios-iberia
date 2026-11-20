import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// DECISIÓN: Icono geométrico propio, sin dependencias ni recursos de terceros.
// Ejecutar desde la raíz: swift scripts/generate-app-icon.swift
let output = URL(fileURLWithPath:
    "AlbumSearch/AlbumSearch/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let size = 1024
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

func circle(diameter: CGFloat, fill: CGColor) {
    let inset = (CGFloat(size) - diameter) / 2
    context.setFillColor(fill)
    context.fillEllipse(in: CGRect(x: inset, y: inset, width: diameter, height: diameter))
}

// Fondo cuadrado y opaco: iOS aplica el recorte de las esquinas.
context.setFillColor(color(12, 100, 120))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
circle(diameter: 744, fill: color(226, 237, 235))
circle(diameter: 728, fill: color(19, 37, 57))
context.setStrokeColor(color(65, 83, 97))
context.setLineWidth(5)
for diameter: CGFloat in [624, 548, 472] {
    let inset = (CGFloat(size) - diameter) / 2
    context.strokeEllipse(in: CGRect(x: inset, y: inset, width: diameter, height: diameter))
}
circle(diameter: 232, fill: color(243, 218, 161))
circle(diameter: 44, fill: color(19, 37, 57))

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("No se ha podido guardar el icono en \(output.path)")
}
print("Icono generado: \(output.path)")
