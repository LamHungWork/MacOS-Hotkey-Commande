import Cocoa
import UniformTypeIdentifiers

/// The app's own copies of the buttons' icons, as square PNG files.
final class IconStore {
    private var cache: [String: NSImage] = [:]

    static let fileTypes: [UTType] = [.png, .jpeg, .svg, .icns, .application]

    private static let pixels = 512

    func image(named name: String) -> NSImage? {
        if let image = cache[name] {
            return image
        }
        guard let data = try? Data(contentsOf: AppPaths.icons.appendingPathComponent(name)),
              let image = try? Self.decode(data) else {
            return nil
        }
        cache[name] = image
        return image
    }

    /// Writes a new file, so a button that still shows the old icon is not affected.
    func save(_ png: Data) throws -> String {
        try FileManager.default.createDirectory(at: AppPaths.icons, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".png"
        try png.write(to: AppPaths.icons.appendingPathComponent(name), options: .atomic)
        return name
    }

    func remove(named name: String) {
        cache[name] = nil
        try? FileManager.default.removeItem(at: AppPaths.icons.appendingPathComponent(name))
    }

    /// Decoded now, not the first time it is drawn.
    static func decode(_ png: Data) throws -> NSImage {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    /// The icon of an app, or the picture in an image file, without its transparent margin and filling a
    /// square.
    static func squarePNG(from file: URL) throws -> Data {
        let type = try file.resourceValues(forKeys: [.contentTypeKey]).contentType
        let image: NSImage?
        if type?.conforms(to: .application) == true {
            image = appIcon(of: file)
        } else {
            let data = try Data(contentsOf: file)
            let isPhoto = type?.conforms(to: .png) == true || type?.conforms(to: .jpeg) == true
            image = isPhoto ? photo(from: data) : NSImage(data: data)
        }

        guard let image = image, let png = squarePNG(of: image) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return png
    }

    /// macOS prepares an app's icon when it is first asked for, and can hand out an empty picture until
    /// then. So it is taken once, at a size it comes in, and only when it is there.
    private static func appIcon(of file: URL) -> NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: file.path)
        let side = 1024
        let frame = NSRect(x: 0, y: 0, width: side, height: side)
        for _ in 0..<20 {
            if let bitmap = draw(icon, in: frame, pixelsWide: side, pixelsHigh: side), visiblePart(of: bitmap, least: solid) != nil {
                let image = NSImage(size: frame.size)
                image.addRepresentation(bitmap)
                return image
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return nil
    }

    /// ImageIO, because it applies the rotation stored in a photo.
    private static func photo(from data: Data) -> NSImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels * 4
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private static func squarePNG(of image: NSImage) -> Data? {
        guard image.isValid, image.size.width > 0, image.size.height > 0 else { return nil }

        let part = visiblePart(of: image)
        let side = CGFloat(pixels)
        let scale = max(side / (part.width * image.size.width), side / (part.height * image.size.height))
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let frame = NSRect(
            x: side / 2 - part.midX * size.width, y: side / 2 - part.midY * size.height, width: size.width, height: size.height
        )
        return draw(image, in: frame, pixelsWide: pixels, pixelsHigh: pixels)?.representation(using: .png, properties: [:])
    }

    /// Opacity, of 255, from which a pixel counts as part of the picture. The soft shadow macOS draws around
    /// an app's icon stays below it.
    private static let solid: UInt8 = 64

    /// Where the picture is, in fractions of the image's size, from its bottom left.
    private static func visiblePart(of image: NSImage) -> NSRect {
        let scale = CGFloat(pixels) / max(image.size.width, image.size.height)
        let wide = max(1, Int((image.size.width * scale).rounded()))
        let high = max(1, Int((image.size.height * scale).rounded()))
        let frame = NSRect(x: 0, y: 0, width: wide, height: high)
        let bitmap = draw(image, in: frame, pixelsWide: wide, pixelsHigh: high)

        // A picture that is faint everywhere is taken as it is.
        return bitmap.flatMap { visiblePart(of: $0, least: solid) ?? visiblePart(of: $0, least: 1) }
            ?? NSRect(x: 0, y: 0, width: 1, height: 1)
    }

    /// nil when no pixel is as opaque as `least`.
    private static func visiblePart(of bitmap: NSBitmapImageRep, least: UInt8) -> NSRect? {
        guard let data = bitmap.bitmapData else { return nil }
        let (wide, high) = (bitmap.pixelsWide, bitmap.pixelsHigh)
        var (left, right, top, bottom) = (wide, -1, high, -1)
        for row in 0..<high {
            for column in 0..<wide where data[row * bitmap.bytesPerRow + column * 4 + 3] >= least {
                left = min(left, column)
                right = max(right, column)
                top = min(top, row)
                bottom = max(bottom, row)
            }
        }
        guard right >= 0 else { return nil }
        return NSRect(
            x: CGFloat(left) / CGFloat(wide),
            y: CGFloat(high - 1 - bottom) / CGFloat(high),
            width: CGFloat(right - left + 1) / CGFloat(wide),
            height: CGFloat(bottom - top + 1) / CGFloat(high)
        )
    }

    private static func draw(_ image: NSImage, in frame: NSRect, pixelsWide: Int, pixelsHigh: Int) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
              ),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: frame, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}
