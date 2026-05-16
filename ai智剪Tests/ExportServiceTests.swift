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

    // MARK: - Formula Injection Tests

    @Test func escapeCSVPrependsApostropheToEqualsPrefix() {
        let result = ExportService.escapeCSV("=SUM(A1)")
        #expect(result == "'=SUM(A1)")
    }

    @Test func escapeCSVPrependsApostropheToPlusPrefix() {
        let result = ExportService.escapeCSV("+cmd")
        #expect(result == "'+cmd")
    }

    @Test func escapeCSVPrependsApostropheToMinusPrefix() {
        let result = ExportService.escapeCSV("-2+3")
        #expect(result == "'-2+3")
    }

    @Test func escapeCSVPrependsApostropheToAtPrefix() {
        let result = ExportService.escapeCSV("@SUM")
        #expect(result == "'@SUM")
    }

    @Test func escapeCSVPrependsApostropheToTabPrefix() {
        let result = ExportService.escapeCSV("\tsomething")
        #expect(result == "'\tsomething")
    }

    @Test func escapeCSVPrependsApostropheToCRPrefix() {
        let result = ExportService.escapeCSV("\rsomething")
        // \r 触发引号包裹，且前面加了 '
        #expect(result == "\"'\rsomething\"")
    }

    @Test func escapeCSVDoesNotModifyNormalText() {
        let result = ExportService.escapeCSV("normal text")
        #expect(result == "normal text")
    }

    @Test func escapeCSVCombinesFormulaPrefixAndComma() {
        let result = ExportService.escapeCSV("=SUM(A1),extra")
        // 先加 ' 前缀，逗号触发引号包裹
        #expect(result == "\"'=SUM(A1),extra\"")
    }

    @Test func exportCSVFormulaInjectionInPrompt() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id,
            kind: record.kind,
            prompt: "=cmd|'/C calc'!A0",
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

        #expect(csv.contains("'=cmd|'/C calc'!A0"))
    }

    // MARK: - Leading Whitespace/Control Char Bypass Tests

    @Test func escapeCSVSkipLeadingNewlineThenEquals() {
        // \n 包含在字符串中，escapeCSV 会加引号包裹
        let result = ExportService.escapeCSV("\n=SUM(A1)")
        #expect(result == "\"'\n=SUM(A1)\"")
    }

    @Test func escapeCSVSkipLeadingSpaceThenEquals() {
        let result = ExportService.escapeCSV(" =SUM(A1)")
        #expect(result == "' =SUM(A1)")
    }

    @Test func escapeCSVSkipLeadingTabThenPlus() {
        // \t 本身是危险前缀，不需要跳过
        let result = ExportService.escapeCSV("\t+cmd")
        #expect(result == "'\t+cmd")
    }

    @Test func escapeCSVSkipLeadingSpacesThenMinus() {
        let result = ExportService.escapeCSV("   -2+3")
        #expect(result == "'   -2+3")
    }

    @Test func escapeCSVSkipLeadingCRLFThenAt() {
        // Swift 把 \r\n 合成单个 Character [13,10]，contains("\n") 检测不到，不加引号
        let result = ExportService.escapeCSV("\r\n@SUM")
        #expect(result == "'\r\n@SUM")
    }

    @Test func escapeCSVLeadingSpacesOnlyIsSafe() {
        let result = ExportService.escapeCSV("   normal text")
        #expect(result == "   normal text")
    }
}
