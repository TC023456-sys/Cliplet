// Mechanical asset preparation, not a redesign of the approved artwork.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

precondition(CommandLine.arguments.count == 3, "Usage: compile-icon input.png output.png")
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
  fatalError("Cannot read approved icon artwork")
}
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let options = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
let scan = CGContext(data: nil, width: image.width, height: image.height,
                     bitsPerComponent: 8, bytesPerRow: image.width * 4,
                     space: colorSpace, bitmapInfo: options)!
scan.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
let pixels = scan.data!.assumingMemoryBound(to: UInt8.self)
var minX = image.width, minY = image.height, maxX = 0, maxY = 0
for y in 0..<image.height {
  for x in 0..<image.width where pixels[y * scan.bytesPerRow + x * 4 + 3] >= 250 {
    minX = min(minX, x); maxX = max(maxX, x)
    minY = min(minY, y); maxY = max(maxY, y)
  }
}
precondition(maxX > minX && maxY > minY)
let side = min(max(maxX - minX + 1, maxY - minY + 1), min(image.width, image.height))
let x = max(0, min(image.width - side, (minX + maxX + 1 - side) / 2))
let y = max(0, min(image.height - side, (minY + maxY + 1 - side) / 2))
let crop = image.cropping(to: CGRect(x: x, y: y, width: side, height: side))!
let canvas = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                       bytesPerRow: 4096, space: colorSpace, bitmapInfo: options)!
canvas.setFillColor(CGColor(red: 0.07, green: 0.075, blue: 0.075, alpha: 1))
canvas.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
canvas.interpolationQuality = .high
canvas.draw(crop, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let result = canvas.makeImage()!
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("Cannot create icon asset") }
CGImageDestinationAddImage(destination, result, nil)
precondition(CGImageDestinationFinalize(destination))
print("PASS: 1024px full-bleed opaque Icon Composer layer; original artwork retained.")
