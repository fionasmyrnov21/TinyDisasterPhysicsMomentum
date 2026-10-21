import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ProfilePhotoError: Error {
    case unreadableImage
}

enum ProfileImageProcessor {
    nonisolated static func portrait(from data: Data) throws -> Data {
        guard !data.isEmpty, data.count <= 50 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw ProfilePhotoError.unreadableImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ProfilePhotoError.unreadableImage }
        let edge = min(preview.width, preview.height)
        let crop = CGRect(x: (preview.width - edge) / 2, y: (preview.height - edge) / 2, width: edge, height: edge)
        guard let square = preview.cropping(to: crop),
              let context = CGContext(data: nil, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw ProfilePhotoError.unreadableImage }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        context.interpolationQuality = .high
        context.draw(square, in: CGRect(x: 0, y: 0, width: 512, height: 512))
        let encoded = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil) else { throw ProfilePhotoError.unreadableImage }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ProfilePhotoError.unreadableImage }
        return encoded as Data
    }

    nonisolated static func isValidPortrait(_ data: Data) -> Bool {
        guard !data.isEmpty, data.count <= 2 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              properties[kCGImagePropertyPixelWidth] as? Int == 512,
              properties[kCGImagePropertyPixelHeight] as? Int == 512 else { return false }
        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }
}

final class ProfilePhotoStore {
    private let directory: String
    private var path: String { (directory as NSString).appendingPathComponent("avatar.jpg") }

    init(directory: String? = nil) {
        let support = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        self.directory = directory ?? (support as NSString).appendingPathComponent("TinyDisaster/Profile")
    }

    func load() -> Data? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber, size.intValue <= 2 * 1024 * 1024,
              let data = FileManager.default.contents(atPath: path), ProfileImageProcessor.isValidPortrait(data) else { return nil }
        return data
    }

    func save(_ data: Data) throws {
        guard ProfileImageProcessor.isValidPortrait(data) else { throw ProfilePhotoError.unreadableImage }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try (data as NSData).write(toFile: path, options: .atomic)
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        try FileManager.default.removeItem(atPath: path)
    }
}
