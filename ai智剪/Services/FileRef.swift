import Foundation
import UniformTypeIdentifiers

struct FileRef: Codable, Equatable, Hashable {
    let data: Data
    let name: String
    let mime: String
}

// MARK: - File loading (used by both NSOpenPanel pickers and Finder drag-drop)

extension FileRef {
    /// Errors that can occur when loading a file from disk.
    enum LoadError: LocalizedError, Equatable {
        case unsupportedType
        case emptyFile
        case fileTooLarge(maxBytes: Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedType:
                return "文件类型不支持"
            case .emptyFile:
                return "文件为空"
            case .fileTooLarge(let maxBytes):
                let mb = max(1, maxBytes / 1024 / 1024)
                return "文件过大，最大支持 \(mb) MB"
            }
        }
    }

    /// Load a `FileRef` from a URL, validating it is an image within size limit.
    /// - Parameters:
    ///   - url: File URL to load.
    ///   - maxSizeBytes: Maximum allowed file size in bytes (default 25 MB).
    /// - Throws: `LoadError.unsupportedType`, `LoadError.emptyFile`, `LoadError.fileTooLarge`.
    static func loadImage(from url: URL, maxSizeBytes: Int = 25 * 1024 * 1024) throws -> FileRef {
        try load(from: url, acceptedTypes: [.image], maxSizeBytes: maxSizeBytes)
    }

    /// Load a `FileRef` from a URL, validating it conforms to one of the accepted types.
    /// - Parameters:
    ///   - url: File URL to load.
    ///   - acceptedTypes: Accepted UTType values (e.g. `[.image]`, `[.image, .video]`).
    ///   - maxSizeBytes: Maximum allowed file size in bytes.
    /// - Throws: `LoadError.unsupportedType`, `LoadError.emptyFile`, `LoadError.fileTooLarge`.
    static func load(from url: URL, acceptedTypes: [UTType], maxSizeBytes: Int) throws -> FileRef {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])

        guard let contentType = values.contentType,
              acceptedTypes.contains(where: { contentType.conforms(to: $0) })
        else {
            throw LoadError.unsupportedType
        }

        let fileSize = values.fileSize ?? 0
        guard fileSize > 0 else { throw LoadError.emptyFile }
        guard fileSize <= maxSizeBytes else { throw LoadError.fileTooLarge(maxBytes: maxSizeBytes) }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let mime = contentType.preferredMIMEType ?? url.mimeType()
        return FileRef(data: data, name: url.lastPathComponent, mime: mime)
    }
}
