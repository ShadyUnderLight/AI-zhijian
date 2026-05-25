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

        #expect(csv.hasPrefix("ID,类型,Prompt,模型,渠道,画幅,分辨率,时长,评分,备注,标签,结果URL,视频URL,创建时间,完成时间"))
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

        #expect(csv.hasPrefix("ID,类型,Prompt,模型,渠道,画幅,分辨率,时长,评分,备注,标签,结果URL,视频URL,创建时间,完成时间"))
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
        // Swift 把 \r\n 合成单个 Character [13,10]，needsQuoting 会检测到 \r
        let result = ExportService.escapeCSV("\r\n@SUM")
        #expect(result == "\"'\r\n@SUM\"")
    }

    @Test func escapeCSVLeadingSpacesOnlyIsSafe() {
        let result = ExportService.escapeCSV("   normal text")
        #expect(result == "   normal text")
    }

    // MARK: - Even-count Leading Whitespace Bypass

    @Test func escapeCSVSkipTwoSpacesThenEquals() {
        let result = ExportService.escapeCSV("  =SUM(A1)")
        #expect(result == "'  =SUM(A1)")
    }

    @Test func escapeCSVSkipTwoNewlinesThenEquals() {
        let result = ExportService.escapeCSV("\n\n=SUM(A1)")
        #expect(result == "\"'\n\n=SUM(A1)\"")
    }

    @Test func escapeCSVSkipSpaceNewlineThenEquals() {
        let result = ExportService.escapeCSV(" \n=SUM(A1)")
        #expect(result == "\"' \n=SUM(A1)\"")
    }

    // MARK: - CRLF in Middle of CSV Field

    @Test func escapeCSVQuotesCRLFInMiddle() {
        // Swift 把 \r\n 合成单个 Character，但 unicodeScalars 仍含 0x0D/0x0A
        let result = ExportService.escapeCSV("normal\r\ntext")
        #expect(result == "\"normal\r\ntext\"")
    }

    // MARK: - URL Sanitization in Export

    @Test func exportCSVStripsQueryFromResultUrls() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id, kind: record.kind, prompt: record.prompt,
            metadata: record.metadata,
            resultUrls: ["https://example.com/img.png?token=abc&expires=1700000000"],
            videoUrl: record.videoUrl, localImagePath: record.localImagePath,
            errorMessage: record.errorMessage,
            createdAt: record.createdAt, completedAt: record.completedAt
        )
        let data = ExportService.exportCSV(records: [record])
        let csv = String(data: data, encoding: .utf8) ?? ""

        #expect(csv.contains("https://example.com/img.png"))
        #expect(!csv.contains("token=abc"))
        #expect(!csv.contains("expires=1700000000"))
        // Original record should retain full URL
        #expect(record.resultUrls.first == "https://example.com/img.png?token=abc&expires=1700000000")
    }

    @Test func exportCSVStripsQueryFromVideoUrl() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id, kind: record.kind, prompt: record.prompt,
            metadata: record.metadata,
            resultUrls: [], videoUrl: "https://example.com/video.mp4?token=secret&signature=xyz",
            localImagePath: record.localImagePath, errorMessage: record.errorMessage,
            createdAt: record.createdAt, completedAt: record.completedAt
        )
        let data = ExportService.exportCSV(records: [record])
        let csv = String(data: data, encoding: .utf8) ?? ""

        #expect(csv.contains("https://example.com/video.mp4"))
        #expect(!csv.contains("token=secret"))
        #expect(!csv.contains("signature=xyz"))
        // Original record should retain full URL
        #expect(record.videoUrl == "https://example.com/video.mp4?token=secret&signature=xyz")
    }

    @Test func exportJSONStripsQueryFromResultUrls() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id, kind: record.kind, prompt: record.prompt,
            metadata: record.metadata,
            resultUrls: ["https://example.com/img.png?token=abc&expires=1700000000"],
            videoUrl: record.videoUrl, localImagePath: record.localImagePath,
            errorMessage: record.errorMessage,
            createdAt: record.createdAt, completedAt: record.completedAt
        )
        let data = ExportService.exportJSON(records: [record])

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = jsonArray.first else {
            #expect(Bool(false), "JSON should be an array of objects")
            return
        }

        let exportedUrls = first["resultUrls"] as? [String] ?? []
        #expect(exportedUrls == ["https://example.com/img.png"])
        // Original record should retain full URL
        #expect(record.resultUrls.first == "https://example.com/img.png?token=abc&expires=1700000000")
    }

    @Test func exportJSONStripsQueryFromVideoUrl() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id, kind: record.kind, prompt: record.prompt,
            metadata: record.metadata,
            resultUrls: [], videoUrl: "https://example.com/video.mp4?token=secret&signature=xyz",
            localImagePath: record.localImagePath, errorMessage: record.errorMessage,
            createdAt: record.createdAt, completedAt: record.completedAt
        )
        let data = ExportService.exportJSON(records: [record])

        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = jsonArray.first else {
            #expect(Bool(false), "JSON should be an array of objects")
            return
        }

        #expect(first["videoUrl"] as? String == "https://example.com/video.mp4")
        // Original record should retain full URL
        #expect(record.videoUrl == "https://example.com/video.mp4?token=secret&signature=xyz")
    }

    // MARK: - Rating, Notes, Tags Export

    @Test func exportCSVIncludesRatingNotesTags() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id, kind: record.kind, prompt: record.prompt,
            metadata: record.metadata,
            resultUrls: record.resultUrls, videoUrl: record.videoUrl,
            localImagePath: record.localImagePath, errorMessage: record.errorMessage,
            createdAt: record.createdAt, completedAt: record.completedAt,
            rating: 4, notes: "效果不错，适合发布", tags: ["满意", "发布版"]
        )
        let data = ExportService.exportCSV(records: [record])
        let csv = String(data: data, encoding: .utf8) ?? ""

        #expect(csv.contains("4"))
        #expect(csv.contains("效果不错，适合发布"))
        #expect(csv.contains("满意, 发布版"))
    }

    @Test func exportCSVEmptyRatingNotesTags() {
        var record = makeSampleRecord()
        record = WorkRecord(
            id: record.id, kind: record.kind,
            prompt: "Simple prompt without commas",
            metadata: record.metadata,
            resultUrls: record.resultUrls, videoUrl: record.videoUrl,
            localImagePath: record.localImagePath, errorMessage: record.errorMessage,
            createdAt: record.createdAt, completedAt: record.completedAt
        )
        let data = ExportService.exportCSV(records: [record])
        let csv = String(data: data, encoding: .utf8) ?? ""

        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 2)
        let dataLine = lines[1]
        let columns = dataLine.components(separatedBy: ",")
        #expect(columns.count == 15)
    }

    // MARK: - WorkRecordParams Coding

    @Test func workRecordParamsGptImageEncodeDecode() {
        let params = WorkRecordParams.gptImage(channel: "official", aspectRatio: "16:9", resolution: "2k", quality: "medium", photoReal: true)
        let data = try? JSONEncoder().encode(params)
        #expect(data != nil)
        let decoded = data.flatMap { try? JSONDecoder().decode(WorkRecordParams.self, from: $0) }
        guard case .gptImage(let ch, let ar, let res, let qual, let pr) = decoded else {
            #expect(Bool(false))
            return
        }
        #expect(ch == "official")
        #expect(ar == "16:9")
        #expect(res == "2k")
        #expect(qual == "medium")
        #expect(pr == true)
    }

    @Test func workRecordParamsSeedanceEncodeDecode() {
        let params = WorkRecordParams.seedance(mode: "text", model: "2.0", ratio: "9:16", resolution: "1080p", duration: 5, count: 2, generateAudio: false)
        let data = try? JSONEncoder().encode(params)
        #expect(data != nil)
        let decoded = data.flatMap { try? JSONDecoder().decode(WorkRecordParams.self, from: $0) }
        guard case .seedance(let m, let mdl, let r, let res, let d, let c, let a) = decoded else {
            #expect(Bool(false))
            return
        }
        #expect(m == "text")
        #expect(mdl == "2.0")
        #expect(r == "9:16")
        #expect(res == "1080p")
        #expect(d == 5)
        #expect(c == 2)
        #expect(a == false)
    }

    @Test func workRecordParamsWanEncodeDecode() {
        let params = WorkRecordParams.wan(mode: "image", width: 720, height: 1280, seconds: 5, enable48G: false)
        let data = try? JSONEncoder().encode(params)
        #expect(data != nil)
        let decoded = data.flatMap { try? JSONDecoder().decode(WorkRecordParams.self, from: $0) }
        guard case .wan(let m, let w, let h, let s, let g) = decoded else {
            #expect(Bool(false))
            return
        }
        #expect(m == "image")
        #expect(w == 720)
        #expect(h == 1280)
        #expect(s == 5)
        #expect(g == false)
    }

    @Test func workRecordParamsVeoEncodeDecode() {
        let params = WorkRecordParams.veo(channel: "budget", model: "fast", mode: "text", aspectRatio: "9:16", resolution: "720p", duration: "8", generateAudio: true, negativePrompt: "blurry")
        let data = try? JSONEncoder().encode(params)
        #expect(data != nil)
        let decoded = data.flatMap { try? JSONDecoder().decode(WorkRecordParams.self, from: $0) }
        guard case .veo(let ch, let mdl, let m, let ar, let res, let d, let a, let n) = decoded else {
            #expect(Bool(false))
            return
        }
        #expect(ch == "budget")
        #expect(mdl == "fast")
        #expect(m == "text")
        #expect(ar == "9:16")
        #expect(res == "720p")
        #expect(d == "8")
        #expect(a == true)
        #expect(n == "blurry")
    }

    @Test func workRecordParamsGrokEncodeDecode() {
        let params = WorkRecordParams.grok(channel: "official", mode: "text", aspectRatio: "16:9", resolution: "1080p", duration: "10")
        let data = try? JSONEncoder().encode(params)
        #expect(data != nil)
        let decoded = data.flatMap { try? JSONDecoder().decode(WorkRecordParams.self, from: $0) }
        guard case .grok(let ch, let m, let ar, let res, let d) = decoded else {
            #expect(Bool(false))
            return
        }
        #expect(ch == "official")
        #expect(m == "text")
        #expect(ar == "16:9")
        #expect(res == "1080p")
        #expect(d == "10")
    }

    // MARK: - WorkRecord backwards compatibility

    @Test func decodeWorkRecordFromOldJSONWithoutNewFields() {
        let oldJSON = """
        [{"id":"legacy-1","kind":"gptImage","prompt":"Old prompt","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img.png"],"createdAt":0}]
        """.data(using: .utf8)!

        let records = try? JSONDecoder().decode([WorkRecord].self, from: oldJSON)
        #expect(records != nil)
        let r = records?.first
        #expect(r != nil)
        #expect(r?.id == "legacy-1")
        #expect(r?.tags == [])
        #expect(r?.rating == nil)
        #expect(r?.notes == nil)
        #expect(r?.paramsSnapshot == nil)
        #expect(r?.workflowSource == nil)
    }

    @Test func decodeWorkRecordWithOnlyPartialNewFields() {
        let json = """
        [{"id":"partial-1","kind":"gptImage","prompt":"Partial","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img.png"],"createdAt":0,"rating":3,"tags":["good"]}]
        """.data(using: .utf8)!

        let records = try? JSONDecoder().decode([WorkRecord].self, from: json)
        #expect(records != nil)
        let r = records?.first
        #expect(r != nil)
        #expect(r?.id == "partial-1")
        #expect(r?.rating == 3)
        #expect(r?.tags == ["good"])
        #expect(r?.notes == nil)
        #expect(r?.paramsSnapshot == nil)
        #expect(r?.workflowSource == nil)
    }

    @Test func workRecordRoundTripThroughJSON() {
        let record = WorkRecord(
            id: "rt-1", kind: .gptImage, prompt: "Round trip test",
            metadata: WorkRecordMetadata(model: "GPT-Image-2", channel: "official", aspectRatio: "1:1", resolution: "1k", duration: "—"),
            resultUrls: ["https://example.com/a.png"], videoUrl: nil, localImagePath: nil,
            errorMessage: nil, createdAt: Date(timeIntervalSince1970: 1700000000),
            completedAt: Date(timeIntervalSince1970: 1700000060),
            rating: 5, notes: "Great result", tags: ["keep", "publish"],
            paramsSnapshot: "{\"gptImage\":{}}"
        )
        let data = try? JSONEncoder().encode([record])
        #expect(data != nil)
        let decoded = data.flatMap { try? JSONDecoder().decode([WorkRecord].self, from: $0) }
        #expect(decoded?.count == 1)
        let r = decoded?.first
        #expect(r?.id == "rt-1")
        #expect(r?.rating == 5)
        #expect(r?.notes == "Great result")
        #expect(r?.tags == ["keep", "publish"])
        #expect(r?.paramsSnapshot == "{\"gptImage\":{}}")
    }

    // MARK: - WorkRecord workflowSource

    @Test func decodeWorkRecordWithWorkflowSource() {
        let json = """
        [{"id":"wf-1","kind":"gptImage","prompt":"Test","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img.png"],"createdAt":0,"workflowSource":{"workflowId":"wf-abc","workflowName":"测试工作流","runId":"run-123","nodeId":"node-1","nodeTitle":"图片生成","batchId":"batch-456","batchEntryId":"entry-789"}}]
        """.data(using: .utf8)!

        let records = try? JSONDecoder().decode([WorkRecord].self, from: json)
        #expect(records != nil)
        let r = records?.first
        #expect(r != nil)
        #expect(r?.id == "wf-1")
        let source = r?.workflowSource
        #expect(source != nil)
        #expect(source?.workflowId == "wf-abc")
        #expect(source?.workflowName == "测试工作流")
        #expect(source?.runId == "run-123")
        #expect(source?.nodeId == "node-1")
        #expect(source?.nodeTitle == "图片生成")
        #expect(source?.batchId == "batch-456")
        #expect(source?.batchEntryId == "entry-789")
    }

    @Test func decodeWorkRecordWithWorkflowSourceWithoutBatch() {
        let json = """
        [{"id":"wf-2","kind":"gptImage","prompt":"Single run","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img.png"],"createdAt":0,"workflowSource":{"workflowId":"wf-xyz","workflowName":"单独运行","runId":"run-456","nodeId":"node-2","nodeTitle":"视频生成"}}]
        """.data(using: .utf8)!

        let records = try? JSONDecoder().decode([WorkRecord].self, from: json)
        #expect(records != nil)
        let r = records?.first
        #expect(r != nil)
        let source = r?.workflowSource
        #expect(source != nil)
        #expect(source?.workflowId == "wf-xyz")
        #expect(source?.batchId == nil)
        #expect(source?.batchEntryId == nil)
    }

    @Test func workRecordRoundTripWithWorkflowSource() {
        let source = WorkRecordWorkflowSource(
            workflowId: "wf-001",
            workflowName: "工作流A",
            runId: "run-999",
            nodeId: "node-a",
            nodeTitle: "生成节点",
            batchId: "batch-001",
            batchEntryId: "entry-003"
        )
        let record = WorkRecord(
            id: "rt-src", kind: .gptImage, prompt: "Source test",
            metadata: WorkRecordMetadata(model: "GPT-Image-2", channel: "official", aspectRatio: "1:1", resolution: "1k", duration: "—"),
            resultUrls: ["https://example.com/a.png"], videoUrl: nil, localImagePath: nil,
            errorMessage: nil, createdAt: Date(timeIntervalSince1970: 1700000000),
            completedAt: Date(timeIntervalSince1970: 1700000060),
            workflowSource: source
        )
        let data = try? JSONEncoder().encode([record])
        #expect(data != nil)
        let decoded = data.flatMap { try? JSONDecoder().decode([WorkRecord].self, from: $0) }
        #expect(decoded?.count == 1)
        let r = decoded?.first
        #expect(r?.id == "rt-src")
        let s = r?.workflowSource
        #expect(s?.workflowId == "wf-001")
        #expect(s?.workflowName == "工作流A")
        #expect(s?.runId == "run-999")
        #expect(s?.nodeId == "node-a")
        #expect(s?.nodeTitle == "生成节点")
        #expect(s?.batchId == "batch-001")
        #expect(s?.batchEntryId == "entry-003")
    }
}
