import XCTest
@testable import aiZhijian

@MainActor
final class WorksStoreTests: XCTestCase {

    private var store: WorksStore!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "WorksStore.records")
        UserDefaults.standard.removeObject(forKey: "WorksStore.favorites")
        store = WorksStore()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "WorksStore.records")
        UserDefaults.standard.removeObject(forKey: "WorksStore.favorites")
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSucceededItem(priceUsd: String? = nil, kind: GenerationJobKind = .gptImage) -> GenerationQueueItem {
        let params: JobParams = .gptImage(GptImageJobParams(
            prompt: "test", channel: "official",
            aspectRatio: "1:1", resolution: "2k",
            quality: "medium", photoReal: false
        ))
        var item = GenerationQueueItem(kind: kind, createdAt: Date(), params: params)
        item.status = .succeeded
        item.priceUsd = priceUsd
        item.resultUrls = ["https://example.com/result.png"]
        item.completedAt = Date()
        return item
    }

    private func makeFailedItem(priceUsd: String? = nil) -> GenerationQueueItem {
        let params: JobParams = .gptImage(GptImageJobParams(
            prompt: "test", channel: "official",
            aspectRatio: "1:1", resolution: "2k",
            quality: "medium", photoReal: false
        ))
        var item = GenerationQueueItem(kind: .gptImage, createdAt: Date(), params: params)
        item.status = .failed
        item.priceUsd = priceUsd
        item.errorMessage = "error"
        item.completedAt = Date()
        return item
    }

    // MARK: - totalCost

    func testTotalCostEmptyWhenNoRecords() {
        XCTAssertEqual(store.totalCost, 0, accuracy: 0.001)
    }

    func testTotalCostOnlySucceededRecords() {
        store.addRecord(from: makeSucceededItem(priceUsd: "$0.05"))
        store.addRecord(from: makeSucceededItem(priceUsd: "$0.10"))
        store.addRecord(from: makeFailedItem(priceUsd: "$1.00"))

        XCTAssertEqual(store.totalCost, 0.15, accuracy: 0.001)
    }

    func testTotalCostSkipsFailedRecords() {
        store.addRecord(from: makeFailedItem(priceUsd: "$5.00"))
        XCTAssertEqual(store.totalCost, 0, accuracy: 0.001)
    }

    func testTotalCostSkipsNilPrice() {
        store.addRecord(from: makeSucceededItem(priceUsd: nil))
        store.addRecord(from: makeSucceededItem(priceUsd: "$0.20"))
        XCTAssertEqual(store.totalCost, 0.20, accuracy: 0.001)
    }

    func testTotalCostSkipsEmptyPrice() {
        store.addRecord(from: makeSucceededItem(priceUsd: ""))
        store.addRecord(from: makeSucceededItem(priceUsd: "$0.30"))
        XCTAssertEqual(store.totalCost, 0.30, accuracy: 0.001)
    }

    // MARK: - todayCost

    func testTodayCostCountsSucceededRecordsWithCompletedAtToday() {
        store.addRecord(from: makeSucceededItem(priceUsd: "$0.50"))
        XCTAssertEqual(store.todayCost, 0.50, accuracy: 0.001)
    }

    func testTodayCostSkipsFailedRecords() {
        store.addRecord(from: makeFailedItem(priceUsd: "$0.50"))
        XCTAssertEqual(store.todayCost, 0, accuracy: 0.001)
    }

    func testTodayCostFallsBackToCreatedAtWhenCompletedAtNil() {
        var item = makeSucceededItem(priceUsd: "$0.25")
        item.completedAt = nil
        store.addRecord(from: item)
        XCTAssertEqual(store.todayCost, 0.25, accuracy: 0.001)
    }

    func testTodayCostExcludesYesterday() {
        let params: JobParams = .gptImage(GptImageJobParams(
            prompt: "test", channel: "official",
            aspectRatio: "1:1", resolution: "2k",
            quality: "medium", photoReal: false
        ))
        let yesterday = Date(timeIntervalSinceNow: -86400 * 2)
        var item = GenerationQueueItem(
            kind: .gptImage,
            createdAt: yesterday,
            params: params
        )
        item.status = .succeeded
        item.priceUsd = "$1.00"
        item.resultUrls = ["https://example.com/result.png"]
        item.completedAt = yesterday
        store.addRecord(from: item)
        XCTAssertEqual(store.todayCost, 0, accuracy: 0.001)
    }

    // MARK: - parsePrice

    func testParsePriceFormats() {
        XCTAssertEqual(store.totalCost, 0, accuracy: 0.001)

        store.addRecord(from: makeSucceededItem(priceUsd: "$0.05"))
        XCTAssertEqual(store.totalCost, 0.05, accuracy: 0.001)

        store.addRecord(from: makeSucceededItem(priceUsd: "0.10"))
        XCTAssertEqual(store.totalCost, 0.15, accuracy: 0.001)

        store.addRecord(from: makeSucceededItem(priceUsd: "USD 1.50"))
        XCTAssertEqual(store.totalCost, 1.65, accuracy: 0.001)

        store.addRecord(from: makeSucceededItem(priceUsd: "$1,234.56"))
        XCTAssertEqual(store.totalCost, 1236.21, accuracy: 0.001)

        store.addRecord(from: makeSucceededItem(priceUsd: "US$0.99"))
        XCTAssertEqual(store.totalCost, 1237.20, accuracy: 0.001)
    }

    func testParsePriceBadDataReturnsZero() {
        store.addRecord(from: makeSucceededItem(priceUsd: "not-a-number"))
        store.addRecord(from: makeSucceededItem(priceUsd: nil))
        store.addRecord(from: makeSucceededItem(priceUsd: ""))
        XCTAssertEqual(store.totalCost, 0, accuracy: 0.001)
    }

    // MARK: - addRecord preserves existing priceUsd

    func testAddRecordDoesNotOverwriteExistingPriceWithNil() {
        let item1 = makeSucceededItem(priceUsd: "$0.50")
        store.addRecord(from: item1)

        var item2 = makeSucceededItem(priceUsd: nil)
        item2.id = item1.id
        store.addRecord(from: item2)

        let record = store.records.first { $0.id == item1.id }
        XCTAssertEqual(record?.priceUsd, "$0.50")
    }

    func testAddRecordOverwritesWithNewPrice() {
        let item1 = makeSucceededItem(priceUsd: "$0.50")
        store.addRecord(from: item1)

        var item2 = makeSucceededItem(priceUsd: "$0.75")
        item2.id = item1.id
        store.addRecord(from: item2)

        let record = store.records.first { $0.id == item1.id }
        XCTAssertEqual(record?.priceUsd, "$0.75")
    }

    // MARK: - Record count

    func testSucceededAndFailedBothGetStored() {
        store.addRecord(from: makeSucceededItem())
        store.addRecord(from: makeFailedItem())
        XCTAssertEqual(store.records.count, 2)
    }

    func testPendingItemIsNotStored() {
        let params: JobParams = .gptImage(GptImageJobParams(
            prompt: "test", channel: "official",
            aspectRatio: "1:1", resolution: "2k",
            quality: "medium", photoReal: false
        ))
        var item = GenerationQueueItem(kind: .gptImage, createdAt: Date(), params: params)
        item.status = .pending
        store.addRecord(from: item)
        XCTAssertEqual(store.records.count, 0)
    }

    // MARK: - workflowSource

    func testAddRecordStoresWorkflowSourceWithBatch() {
        let source = WorkRecordWorkflowSource(
            workflowId: "wf-001",
            workflowName: "测试工作流",
            runId: "run-123",
            nodeId: "node-a",
            nodeTitle: "图片生成",
            batchId: "batch-456",
            batchEntryId: "entry-789"
        )
        let record = store.addRecord(
            id: "test-src-1",
            kind: .gptImage,
            prompt: "test prompt",
            metadata: WorkRecordMetadata(model: "GPT-Image-2", channel: "official", aspectRatio: "1:1", resolution: "2k", duration: "—"),
            resultUrls: [],
            videoUrl: nil,
            localImagePath: nil,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: Date(),
            workflowSource: source
        )
        XCTAssertEqual(record.workflowSource?.workflowId, "wf-001")
        XCTAssertEqual(record.workflowSource?.workflowName, "测试工作流")
        XCTAssertEqual(record.workflowSource?.runId, "run-123")
        XCTAssertEqual(record.workflowSource?.nodeId, "node-a")
        XCTAssertEqual(record.workflowSource?.nodeTitle, "图片生成")
        XCTAssertEqual(record.workflowSource?.batchId, "batch-456")
        XCTAssertEqual(record.workflowSource?.batchEntryId, "entry-789")
    }

    func testAddRecordStoresWorkflowSourceWithoutBatch() {
        let source = WorkRecordWorkflowSource(
            workflowId: "wf-002",
            workflowName: "单独运行",
            runId: "run-999",
            nodeId: "node-b",
            nodeTitle: "视频生成",
            batchId: nil,
            batchEntryId: nil
        )
        let record = store.addRecord(
            id: "test-src-2",
            kind: .veo,
            prompt: "batchless prompt",
            metadata: WorkRecordMetadata(model: "Veo", channel: "official", aspectRatio: "16:9", resolution: "1080p", duration: "5s"),
            resultUrls: [],
            videoUrl: "https://example.com/video.mp4",
            localImagePath: nil,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: Date(),
            workflowSource: source
        )
        XCTAssertEqual(record.workflowSource?.workflowId, "wf-002")
        XCTAssertNil(record.workflowSource?.batchId)
        XCTAssertNil(record.workflowSource?.batchEntryId)
    }

    func testAddRecordWithoutWorkflowSourceHasNilSource() {
        let record = store.addRecord(
            id: "test-src-3",
            kind: .gptImage,
            prompt: "no source",
            metadata: WorkRecordMetadata(model: "GPT-Image-2", channel: "official", aspectRatio: "1:1", resolution: "2k", duration: "—"),
            resultUrls: [],
            videoUrl: nil,
            localImagePath: nil,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: Date()
        )
        XCTAssertNil(record.workflowSource)
    }

    func testWorkflowSourcePersistsAndRestores() {
        let source = WorkRecordWorkflowSource(
            workflowId: "wf-persist",
            workflowName: "持久化测试",
            runId: "run-p1",
            nodeId: "node-px",
            nodeTitle: "持久节点",
            batchId: "batch-p99",
            batchEntryId: "entry-p42"
        )
        store.addRecord(
            id: "persist-1",
            kind: .gptImage,
            prompt: "persistence test",
            metadata: WorkRecordMetadata(model: "GPT-Image-2", channel: "official", aspectRatio: "1:1", resolution: "2k", duration: "—"),
            resultUrls: [],
            videoUrl: nil,
            localImagePath: nil,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: Date(),
            workflowSource: source
        )

        let newStore = WorksStore()
        XCTAssertEqual(newStore.records.count, 1)
        let restored = newStore.records.first
        XCTAssertEqual(restored?.id, "persist-1")
        XCTAssertEqual(restored?.workflowSource?.workflowId, "wf-persist")
        XCTAssertEqual(restored?.workflowSource?.workflowName, "持久化测试")
        XCTAssertEqual(restored?.workflowSource?.batchId, "batch-p99")
    }

    // MARK: - Resilient workflowSource decoding

    func testDecodeRecordsWithMalformedWorkflowSourceDoesNotFail() {
        let json = """
        [{"id":"malformed-1","kind":"gptImage","prompt":"Bad source","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img.png"],"createdAt":0,"workflowSource":{"workflowId":"wf-ok"}},{"id":"valid-1","kind":"gptImage","prompt":"Good record","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img2.png"],"createdAt":1}]
        """.data(using: .utf8)!

        let records = try? JSONDecoder().decode([WorkRecord].self, from: json)
        XCTAssertNotNil(records)
        // Both records should decode: first has nil workflowSource (missing required fields),
        // second has no workflowSource key
        XCTAssertEqual(records?.count, 2)
        XCTAssertNil(records?.first?.workflowSource)
        XCTAssertEqual(records?.first?.id, "malformed-1")
        XCTAssertEqual(records?.last?.id, "valid-1")
    }

    func testDecodeRecordsWithMalformedWorkflowSourcePreservesValidRecords() {
        let json = """
        [{"id":"bad-1","kind":"gptImage","prompt":"Broken source","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img.png"],"createdAt":0,"workflowSource":{}},{"id":"good-1","kind":"gptImage","prompt":"Fine","metadata":{"model":"GPT-Image-2","channel":"official","aspectRatio":"16:9","resolution":"2k","duration":"—"},"resultUrls":["https://example.com/img2.png"],"createdAt":1,"workflowSource":{"workflowId":"wf-xxx","workflowName":"ok","runId":"r1","nodeId":"n1","nodeTitle":"ok"}}]
        """.data(using: .utf8)!

        let records = try? JSONDecoder().decode([WorkRecord].self, from: json)
        XCTAssertNotNil(records)
        XCTAssertEqual(records?.count, 2)
        // First record: empty object → missing required fields → workflowSource nil
        XCTAssertNil(records?.first?.workflowSource)
        // Second record: has all required fields
        XCTAssertEqual(records?.last?.workflowSource?.workflowId, "wf-xxx")
        XCTAssertEqual(records?.last?.workflowSource?.runId, "r1")
    }

    // MARK: - Seedance edge case

    func testTotalCostMissedWhenSeedanceMainFailsChildrenSucceed() {
        let batchId = UUID()
        let seedanceParams: JobParams = .seedance(SeedanceJobParams(
            prompt: "a running cat", mode: "reference",
            model: "dreamina-seedance-2-0-260128", ratio: "adaptive",
            resolution: "720p", duration: 5, count: 4, generateAudio: true
        ))

        var mainTask = GenerationQueueItem(kind: .seedance, createdAt: Date(), params: seedanceParams)
        mainTask.status = .failed
        mainTask.priceUsd = "$0.20"
        mainTask.batchId = batchId
        mainTask.batchName = "seedance batch"
        mainTask.errorMessage = "supplier error"
        mainTask.completedAt = Date()
        store.addRecord(from: mainTask)

        for i in 0..<2 {
            var child = GenerationQueueItem(kind: .seedance, createdAt: Date(), params: seedanceParams)
            child.status = .succeeded
            child.videoUrl = "https://example.com/child_\(i).mp4"
            child.batchId = batchId
            child.batchName = "seedance batch"
            child.completedAt = Date()
            // 当前设计：children 没有 priceUsd（主任务持有总价）
            store.addRecord(from: child)
        }

        XCTAssertEqual(store.records.count, 3)
        // 主任务失败不计入 totalCost，children 无 priceUsd
        // 这是已知边界：需要 chargeId 或分摊方案才能完美解决
        XCTAssertEqual(store.totalCost, 0, accuracy: 0.001)
    }
}

// MARK: - seedanceTrackedTaskPrices

final class SeedanceTrackedTaskPricesTests: XCTestCase {
    func testMultipleTasksFirstHasPrice() {
        let result = seedanceTrackedTaskPrices(
            taskIds: ["a", "b", "c"],
            submissionPriceUsd: "$0.20"
        )
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].taskId, "a")
        XCTAssertEqual(result[0].priceUsd, "$0.20")
        XCTAssertEqual(result[1].taskId, "b")
        XCTAssertNil(result[1].priceUsd)
        XCTAssertEqual(result[2].taskId, "c")
        XCTAssertNil(result[2].priceUsd)
    }

    func testEmptyTaskIds() {
        let result = seedanceTrackedTaskPrices(taskIds: [], submissionPriceUsd: "$0.20")
        XCTAssertTrue(result.isEmpty)
    }

    func testNilSubmissionPrice() {
        let result = seedanceTrackedTaskPrices(taskIds: ["a", "b"], submissionPriceUsd: nil)
        XCTAssertEqual(result.count, 2)
        XCTAssertNil(result[0].priceUsd)
        XCTAssertNil(result[1].priceUsd)
    }

    func testSingleTaskPreservesPrice() {
        let result = seedanceTrackedTaskPrices(taskIds: ["x"], submissionPriceUsd: "$1.00")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].taskId, "x")
        XCTAssertEqual(result[0].priceUsd, "$1.00")
    }
}
