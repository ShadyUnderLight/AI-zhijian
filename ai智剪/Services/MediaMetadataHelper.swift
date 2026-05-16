import AVFoundation
import AppKit
import Foundation
import UniformTypeIdentifiers

struct MediaMetadata {
    var duration: Double?
    var resolution: String?
}

enum FileMetadataFormatter {
    static func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / 1024.0 / 1024.0)
    }

    static func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--" }
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}

enum MediaMetadataHelper {
    static func extractMetadata(from url: URL) async -> MediaMetadata? {
        let asset = AVURLAsset(url: url)
        return await extractMetadata(from: asset)
    }

    static func extractMetadata(from data: Data, mime: String) async -> MediaMetadata? {
        let ext = preferredExtension(for: mime)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        do {
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            let asset = AVURLAsset(url: tempURL)
            return await extractMetadata(from: asset)
        } catch {
            return nil
        }
    }

    static func extractVideoFirstFrame(from url: URL, maxSize: CGFloat) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        return await extractFirstFrame(from: asset, maxSize: maxSize)
    }

    static func preferredExtension(for mime: String) -> String {
        if let utType = UTType(mimeType: mime),
           let ext = utType.preferredFilenameExtension {
            return ext
        }
        if mime.hasPrefix("audio/") { return "m4a" }
        if mime.hasPrefix("video/") { return "mp4" }
        return "bin"
    }

    // MARK: - Private

    private static func extractMetadata(from asset: AVURLAsset) async -> MediaMetadata? {
        do {
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)

            var meta = MediaMetadata()

            if duration.isNumeric {
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite, seconds >= 0 {
                    meta.duration = seconds
                }
            }

            if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
                let size = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                let transformedSize = size.applying(transform)
                let w = Int(abs(transformedSize.width))
                let h = Int(abs(transformedSize.height))
                if w > 0, h > 0 {
                    meta.resolution = "\(w)×\(h)"
                }
            }

            return (meta.duration != nil || meta.resolution != nil) ? meta : nil
        } catch {
            return nil
        }
    }

    private static func extractFirstFrame(from asset: AVURLAsset, maxSize: CGFloat) async -> NSImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxSize, height: maxSize)
        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            return NSImage(cgImage: cgImage, size: NSSize(width: maxSize, height: maxSize))
        } catch {
            return nil
        }
    }
}
