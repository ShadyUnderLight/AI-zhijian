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
            let resultUrls = escapeCSV(record.resultUrls.joined(separator: " | "))
            let videoUrl = escapeCSV(record.videoUrl ?? "")
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
        return (try? encoder.encode(records)) ?? Data()
    }

    static func escapeCSV(_ value: String) -> String {
        let sanitized = sanitizeFormulaPrefix(value)
        if sanitized.contains(",") || sanitized.contains("\"") || sanitized.contains("\n") || sanitized.contains("\r") {
            let escaped = sanitized.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return sanitized
    }

    private static func sanitizeFormulaPrefix(_ value: String) -> String {
        guard let first = value.first else { return value }
        if first == "=" || first == "+" || first == "-" || first == "@" || first == "\t" || first == "\r" {
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
