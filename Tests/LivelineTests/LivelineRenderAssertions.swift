#if os(macOS)
import AppKit
import XCTest

/// Fails unless the image holds more than `minimumPixels` pixels that differ
/// from its top-left pixel. An encoded image always has a size, even blank, so
/// the rendered pixels are the only proof that something was drawn.
func XCTAssertDrawsContent(
    _ image: NSImage,
    minimumPixels: Int = 50,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff)
    else {
        XCTFail("Could not read the rendered pixels. \(message())", file: file, line: line)
        return
    }
    let background = bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB)
    var drawn = 0
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
            let differs = background.map {
                abs(color.redComponent - $0.redComponent)
                    + abs(color.greenComponent - $0.greenComponent)
                    + abs(color.blueComponent - $0.blueComponent)
                    + abs(color.alphaComponent - $0.alphaComponent) > 0.05
            } ?? true
            if differs { drawn += 1 }
        }
    }
    XCTAssertGreaterThan(drawn, minimumPixels, "Nothing was drawn. \(message())", file: file, line: line)
}
#endif
