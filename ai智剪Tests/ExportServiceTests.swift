import Testing
@testable import aiZhijian
import Foundation

struct ExportServiceTests {
    private func makeSampleRecord() -> WorkRecord {
        WorkRecord(
            id: "test-id-123",
            kind: .gptImage,
            prompt: "A beautiful sunset, with mountains",
            metadata: WorkRecordMetadata(
                model: "GPT-Image-2",
                channel: "official",
                aspectRatio: "16:9",
                resolution: "1024x1024",
                duration: "—"
            ),
            resultUrls: ["https://example.com/image1.png", "https://example.com/image2.png"],
            videoUrl: nil,
            localImagePath: nil,
            errorMessage: nil,
            createdAt: Date(timeIntervalSince1970: 1700000000),
            completedAt: Date(timeIntervalSince1970: 1700000060)
        )
    }

    @Test func exportCSVContainsHeader() {
        let records = [makeSampleRecord()]
        let data = ExportService.exportCSV(records: records)
        let csv = String(data: data, encoding: .utf8) ?? ""

        #expect(csv.hasPrefix("ID,类型,Prompt,模型,渠道,画幅,分辨率,时长,结果URL,视频URL,创建时间,完成时间"))
    }

    @Test func exportCSVContainsRecordData() {
        let records = [makeSampleRecord()]
        let data = ExportService.exportCSV(records: records)
        let csv = String(data: data, encoding: .utf8) ?? ""

        #expect(csv.contains("test-id-123"))
        #expect(csv.contains("GPT-Image-2"))
        #expect(csv.contains("A beautiful sunset, with mountains"))
        #expect(csv.contains("official"))
        #expect(csv.contains("16:9"))
        #expect(csv.contains("1024x1024"))
    }

    @Test func exportCSVEscapesCommasInPrompt() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id,
            kind: record.kind,
            prompt: "Prompt with, commas",
            metadata: record.metadata,
            resultUrls: record.resultUrls,
            videoUrl: record.videoUrl,
            localImagePath: record.localImagePath,
            errorMessage: record.errorMessage,
            createdAt: record.createdAt,
            completedAt: record.completedAt
        )
        let data = ExportService.exportCSV(records: [record])
        let csv = String(data: data, encoding: .utf8) ?? ""

        #expect(csv.contains("\"Prompt with, commas\""))
    }

    @Test func exportJSONIsValidJSON() {
        let records = [makeSampleRecord()]
        let data = ExportService.exportJSON(records: records)

        let parsed = try? JSONSerialization.jsonObject(with: data)
        #expect(parsed != nil)
    }

    @Test func exportJSONContainsRecords() {
        let records = [makeSampleRecord()]
        let data = ExportService.exportJSON(records: records)

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = jsonArray.first else {
            #expect(Bool(false), "JSON should be an array of objects")
            return
        }

        #expect(first["id"] as? String == "test-id-123")
        #expect(first["prompt"] as? String == "A beautiful sunset, with mountains")
    }

    @Test func exportEmptyRecordsProducesValidCSV() {
        let data = ExportService.exportCSV(records: [])
        let csv = String(data: data, encoding: .utf8) ?? ""

        #expect(csv.hasPrefix("ID,类型,Prompt,模型,渠道,画幅,分辨率,时长,结果URL,视频URL,创建时间,完成时间"))
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
    }

    @Test func exportEmptyRecordsProducesValidJSON() {
        let data = ExportService.exportJSON(records: [])

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            #expect(Bool(false), "JSON should be an array")
            return
        }

        #expect(jsonArray.isEmpty)
    }

    @Test func exportMultipleRecords() {
        let record1 = makeSampleRecord()
        let record2 = WorkRecord(
            id: "test-id-456",
            kind: .seedance,
            prompt: "A dancing robot",
            metadata: WorkRecordMetadata(
                model: "Seedance 2.0",
                channel: "—",
                aspectRatio: "16:9",
                resolution: "720p",
                duration: "5s"
            ),
            resultUrls: [],
            videoUrl: "https://example.com/video.mp4",
            localImagePath: nil,
            errorMessage: nil,
            createdAt: Date(timeIntervalSince1970: 1700001000),
            completedAt: Date(timeIntervalSince1970: 1700001060)
        )

        let csvData = ExportService.exportCSV(records: [record1, record2])
        let csv = String(data: csvData, encoding: .utf8) ?? ""
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        #expect(lines.count == 3)
        #expect(csv.contains("test-id-123"))
        #expect(csv.contains("test-id-456"))
        #expect(csv.contains("A dancing robot"))
    }
}
