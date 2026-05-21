import Foundation

enum ExportService {
    static func exportCSV(records: [WorkRecord]) -> Data {
        var csv = "ID,类型,Prompt,模型,渠道,画幅,分辨率,时长,结果URL,视频URL,创建时间,完成时间\n"

        for record in records {
            let id = escapeCSV(record.id)
            let kind = escapeCSV(record.displayType)
            let prompt = escapeCSV(record.prompt)
            let model = escapeCSV(record.metadata.model)
            let channel = escapeCSV(record.metadata.channel)
            let aspectRatio = escapeCSV(record.metadata.aspectRatio)
            let resolution = escapeCSV(record.metadata.resolution)
            let duration = escapeCSV(record.metadata.duration)
            let resultUrls = escapeCSV(record.resultUrls.map(sanitizeURL).joined(separator: " | "))
            let videoUrl = escapeCSV(record.videoUrl.map(sanitizeURL) ?? "")
            let createdAt = escapeCSV(formatDate(record.createdAt))
            let completedAt = escapeCSV(record.completedAt.map(formatDate) ?? "")

            csv += "\(id),\(kind),\(prompt),\(model),\(channel),\(aspectRatio),\(resolution),\(duration),\(resultUrls),\(videoUrl),\(createdAt),\(completedAt)\n"
        }

        return csv.data(using: .utf8) ?? Data()
    }

    static func exportJSON(records: [WorkRecord]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let rawData = try? encoder.encode(records),
              let json = try? JSONSerialization.jsonObject(with: rawData) as? [[String: Any]] else {
            return Data()
        }
        let sanitized = json.map(sanitizeJSONRecord)
        return (try? JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    private static func sanitizeJSONRecord(_ record: [String: Any]) -> [String: Any] {
        var r = record
        if let urls = r["resultUrls"] as? [String] {
            r["resultUrls"] = urls.map { sanitizeURL($0) }
        }
        if let videoUrl = r["videoUrl"] as? String {
            r["videoUrl"] = sanitizeURL(videoUrl)
        }
        return r
    }

    private static func sanitizeURL(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.query = nil
        components.fragment = nil
        return components.string ?? urlString
    }

    static func escapeCSV(_ value: String) -> String {
        let sanitized = sanitizeFormulaPrefix(value)
        if needsQuoting(sanitized) {
            let escaped = sanitized.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return sanitized
    }

    private static func needsQuoting(_ value: String) -> Bool {
        for scalar in value.unicodeScalars {
            let v = scalar.value
            if v == 0x2C || v == 0x22 || v == 0x0A || v == 0x0D { return true }
        }
        return false
    }

    private static func sanitizeFormulaPrefix(_ value: String) -> String {
        let dangerous: Set<UInt32> = [0x3D, 0x2B, 0x2D, 0x40, 0x09, 0x0D]
        let skipable: Set<UInt32> = [0x20, 0x0A]

        var iter = value.unicodeScalars.makeIterator()
        guard var current = iter.next() else { return value }

        while skipable.contains(current.value) {
            guard let next = iter.next() else { return value }
            current = next
        }

        if dangerous.contains(current.value) {
            return "'" + value
        }

        return value
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
