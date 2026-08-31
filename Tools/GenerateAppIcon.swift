import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: GenerateAppIcon <input.png> <output.png>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
    sourceImage.width == 1024,
    sourceImage.height == 1024,
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
        data: nil,
        width: 1024,
        height: 1024,
        bitsPerComponent: 8,
        bytesPerRow: 1024 * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )
else {
    fputs("Input must be a readable 1024×1024 PNG.\n", stderr)
    exit(1)
}

context.interpolationQuality = .high
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fillEllipse(in: CGRect(x: 112, y: 112, width: 800, height: 800))
context.draw(sourceImage, in: CGRect(x: 64, y: 64, width: 896, height: 896))

guard
    let outputImage = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    fputs("Unable to create output image.\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, outputImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to write output PNG.\n", stderr)
    exit(1)
}

print("Generated opaque 1024×1024 app icon at \(outputURL.path)")
