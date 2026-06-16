import XCTest
@testable import aiZhijian

// MARK: - Property-Based Contract Tests for FileRef File Loading

/// These tests verify the type contracts defined in SDD:
///
/// `FileRef.loadImage(from:maxSizeBytes:)`
///   ∀ validImage ∧ size ≤ maxSize → returns FileRef
///   ∀ ¬image → throws .unsupportedType
///   ∀ size > maxSize → throws .fileTooLarge
///   ∀ empty → throws .emptyFile
///
/// `FileRef.load(from:acceptedTypes:maxSizeBytes:)`
///   ∀ conformsTo(acceptedTypes) ∧ size ≤ maxSize → returns FileRef
///   ∀ ¬conformsTo → throws .unsupportedType
///   ∀ size > maxSize → throws .fileTooLarge
///
/// Invariants:
///   ∀ valid FileRef: name == sourceURL.lastPathComponent
///   ∀ valid FileRef: mime.starts(with: "image/") ∨ conformsTo(acceptedTypes)
///   ∀ valid FileRef: data.count > 0
///   ∀ valid FileRef: Codable round-trip preserves identity

final class FileRefLoadingTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileRefLoadingTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a minimal valid 1×1 red PNG
    private func createValidPNG(name: String = "test.png") -> URL {
        let url = tempDir.appendingPathComponent(name)
        // Minimal valid PNG: 1×1 red pixel
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x00, 0x03, 0x00, 0x01, 0x36, 0x28, 0x19,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
            0xAE, 0x42, 0x60, 0x82
        ])
        try! pngData.write(to: url)
        return url
    }

    private func createValidJPEG(name: String = "test.jpg") -> URL {
        let url = tempDir.appendingPathComponent(name)
        // Minimal valid JPEG
        let jpegData = Data([
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
            0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
            0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
            0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08,
            0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C,
            0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
            0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D,
            0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20,
            0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
            0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
            0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34,
            0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4,
            0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01,
            0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04,
            0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF,
            0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
            0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
            0x02, 0x03, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31,
            0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71,
            0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42,
            0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33,
            0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18,
            0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A,
            0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43,
            0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53,
            0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63,
            0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73,
            0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83,
            0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92,
            0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A,
            0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9,
            0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8,
            0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7,
            0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6,
            0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4,
            0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2,
            0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
            0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00,
            0x3F, 0x00, 0x7B, 0x94, 0x11, 0x00, 0x00, 0x00,
            0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
            0x82
        ])
        try! jpegData.write(to: url)
        return url
    }

    private func createTextFile(name: String = "test.txt") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! Data("hello world".utf8).write(to: url)
        return url
    }

    private func createEmptyFile(name: String = "empty.png") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! Data().write(to: url)
        return url
    }

    private func createLargeFile(name: String = "large.png", sizeBytes: Int = 30 * 1024 * 1024) -> URL {
        let url = tempDir.appendingPathComponent(name)
        let data = Data(repeating: 0x00, count: sizeBytes)
        try! data.write(to: url)
        return url
    }

    // MARK: - Property: Valid Image → FileRef with matching metadata

    func testLoadImageValidPNG() throws {
        let url = createValidPNG()
        let ref = try FileRef.loadImage(from: url)
        XCTAssertEqual(ref.name, "test.png")
        XCTAssertTrue(ref.mime.hasPrefix("image/"), "Expected image MIME, got \(ref.mime)")
        XCTAssertGreaterThan(ref.data.count, 0)
    }

    func testLoadImageValidJPEG() throws {
        let url = createValidJPEG()
        let ref = try FileRef.loadImage(from: url)
        XCTAssertEqual(ref.name, "test.jpg")
        XCTAssertTrue(ref.mime.hasPrefix("image/"), "Expected image MIME, got \(ref.mime)")
        XCTAssertGreaterThan(ref.data.count, 0)
    }

    /// Property: loadImage accepts exactly the max size
    func testLoadImageExactMaxSize() throws {
        let url = createLargeFile(name: "exactMax.png", sizeBytes: 25 * 1024 * 1024)
        let ref = try FileRef.loadImage(from: url, maxSizeBytes: 25 * 1024 * 1024)
        XCTAssertEqual(ref.data.count, 25 * 1024 * 1024)
    }

    // MARK: - Property: ¬image → throws .unsupportedType

    func testLoadImageRejectsTextFile() {
        let url = createTextFile()
        XCTAssertThrowsError(try FileRef.loadImage(from: url)) { error in
            guard case FileRef.LoadError.unsupportedType = error else {
                XCTFail("Expected unsupportedType, got \(error)")
                return
            }
        }
    }

    func testLoadImageRejectsPDF() {
        let url = tempDir.appendingPathComponent("test.pdf")
        try! Data("%PDF-1.4 fake pdf content".utf8).write(to: url)
        XCTAssertThrowsError(try FileRef.loadImage(from: url)) { error in
            guard case FileRef.LoadError.unsupportedType = error else {
                XCTFail("Expected unsupportedType, got \(error)")
                return
            }
        }
    }

    // MARK: - Property: size > maxSize → throws .fileTooLarge

    func testLoadImageRejectsOversizedFile() {
        let url = createLargeFile(name: "oversized.png", sizeBytes: 30 * 1024 * 1024)
        XCTAssertThrowsError(try FileRef.loadImage(from: url, maxSizeBytes: 25 * 1024 * 1024)) { error in
            guard case FileRef.LoadError.fileTooLarge = error else {
                XCTFail("Expected fileTooLarge, got \(error)")
                return
            }
        }
    }

    // MARK: - Property: empty → throws .emptyFile

    func testLoadImageRejectsEmptyFile() {
        let url = createEmptyFile()
        XCTAssertThrowsError(try FileRef.loadImage(from: url)) { error in
            guard case FileRef.LoadError.emptyFile = error else {
                XCTFail("Expected emptyFile, got \(error)")
                return
            }
        }
    }

    // MARK: - Property: Codable round-trip preserves identity

    func testLoadImageResultCodableRoundTrip() throws {
        let url = createValidPNG()
        let ref = try FileRef.loadImage(from: url)
        let data = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(FileRef.self, from: data)
        XCTAssertEqual(decoded, ref)
        XCTAssertEqual(decoded.name, ref.name)
        XCTAssertEqual(decoded.mime, ref.mime)
        XCTAssertEqual(decoded.data, ref.data)
    }

    // MARK: - FileRef.load() with accepted types

    func testLoadWithAcceptedTypesAcceptsPNG() throws {
        let url = createValidPNG()
        let ref = try FileRef.load(from: url, acceptedTypes: [.image, .video], maxSizeBytes: 25 * 1024 * 1024)
        XCTAssertEqual(ref.name, "test.png")
        XCTAssertTrue(ref.mime.hasPrefix("image/"))
    }

    func testLoadWithAcceptedTypesRejectsText() {
        let url = createTextFile()
        XCTAssertThrowsError(try FileRef.load(from: url, acceptedTypes: [.image], maxSizeBytes: 25 * 1024 * 1024)) { error in
            guard case FileRef.LoadError.unsupportedType = error else {
                XCTFail("Expected unsupportedType, got \(error)")
                return
            }
        }
    }

    func testLoadWithAcceptedTypesRespectsCustomMaxSize() {
        let url = createLargeFile(name: "big.png", sizeBytes: 10 * 1024 * 1024)
        XCTAssertThrowsError(try FileRef.load(from: url, acceptedTypes: [.image], maxSizeBytes: 5 * 1024 * 1024)) { error in
            guard case FileRef.LoadError.fileTooLarge = error else {
                XCTFail("Expected fileTooLarge, got \(error)")
                return
            }
        }
    }

    // MARK: - Property-based: Multiple URLs (parameterized)

    func testLoadImageMultipleValidImages() throws {
        let urls = [createValidPNG(name: "a.png"), createValidJPEG(name: "b.jpg"), createValidPNG(name: "c.png")]
        let refs = try urls.map { try FileRef.loadImage(from: $0) }
        XCTAssertEqual(refs.count, 3)
        XCTAssertEqual(refs[0].name, "a.png")
        XCTAssertEqual(refs[1].name, "b.jpg")
        XCTAssertEqual(refs[2].name, "c.png")
        for ref in refs {
            XCTAssertTrue(ref.mime.hasPrefix("image/"))
            XCTAssertGreaterThan(ref.data.count, 0)
        }
    }

    func testLoadImageHandlesMixedSuccessAndFailure() {
        let validURL = createValidPNG(name: "valid.png")
        let invalidURL = createTextFile(name: "bad.txt")
        let urls = [validURL, invalidURL]

        var succeeded: [FileRef] = []
        var errors: [Error] = []

        for url in urls {
            do {
                let ref = try FileRef.loadImage(from: url)
                succeeded.append(ref)
            } catch {
                errors.append(error)
            }
        }

        XCTAssertEqual(succeeded.count, 1)
        XCTAssertEqual(succeeded[0].name, "valid.png")
        XCTAssertEqual(errors.count, 1)
        guard case FileRef.LoadError.unsupportedType = errors[0] else {
            XCTFail("Expected unsupportedType")
            return
        }
    }
}
