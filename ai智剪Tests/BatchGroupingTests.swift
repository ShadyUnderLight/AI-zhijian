import XCTest
@testable import aiZhijian

@MainActor
final class BatchGroupingTests: XCTestCase {

    private var store: GenerationQueueStore!

    override func setUp() {
        super.setUp()
        store = GenerationQueueStore(api: APIService.shared)
        store.items.removeAll()
        store.pausedBatchIds.removeAll()
    }

    override func tearDown() {
        store.items.removeAll()
        store.pausedBatchIds.removeAll()
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeItem(prompt: String = "test") -> GenerationQueueItem {
        GenerationQueueItem(
            kind: .gptImage,
            createdAt: Date(),
            params: .gptImage(GptImageJobParams(
                prompt: prompt, channel: "official",
                aspectRatio: "1:1", resolution: "2k",
                quality: "medium", photoReal: false
            ))
        )
    }

    // MARK: - enqueueBatch

    func testEnqueueBatchSetsBatchIdOnAllItems() {
        let items = (0..<3).map { makeItem(prompt: "item \($0)") }
        store.enqueueBatch(items)

        let batchIds = Set(store.items.compactMap(\.batchId))
        XCTAssertEqual(batchIds.count, 1, "同一批次应共享一个 batchId")
        XCTAssertTrue(store.items.allSatisfy { $0.batchId != nil })
    }

    func testEnqueueBatchSetsNameFromFirstPrompt() {
        let items = [makeItem(prompt: "hello world")]
        store.enqueueBatch(items)

        XCTAssertEqual(store.items.first?.batchName, "hello world")
    }

    func testEnqueueBatchTruncatesNameTo30Chars() {
        let long = String(repeating: "a", count: 100)
        store.enqueueBatch([makeItem(prompt: long)])

        XCTAssertLessThanOrEqual(store.items.first?.batchName?.count ?? 0, 30)
    }

    func testEnqueueBatchAcceptsCustomName() {
        store.enqueueBatch([makeItem()], batchName: "My Batch")
        XCTAssertEqual(store.items.first?.batchName, "My Batch")
    }

    func testTwoBatchesHaveDifferentIds() {
        store.enqueueBatch([makeItem(prompt: "a")])
        store.enqueueBatch([makeItem(prompt: "b")])

        let ids = Set(store.items.compactMap(\.batchId))
        XCTAssertEqual(ids.count, 2)
    }

    // MARK: - groupedBatches

    func testGroupedBatchesReturnsCorrectCount() {
        store.enqueueBatch([makeItem(prompt: "a"), makeItem(prompt: "b")])
        store.enqueueBatch([makeItem(prompt: "c")])

        XCTAssertEqual(store.groupedBatches.count, 2)
    }

    func testGroupedBatchesItemsMatch() {
        store.enqueueBatch([makeItem(prompt: "x"), makeItem(prompt: "y")])
        let batch = store.groupedBatches.first!
        XCTAssertEqual(batch.items.count, 2)
    }

    func testUnbatchedItemsIsEmptyWhenAllBatched() {
        store.enqueueBatch([makeItem()])
        XCTAssertTrue(store.unbatchedItems.isEmpty)
    }

    func testUnbatchedItemsReturnsNonBatched() {
        store.enqueueBatch([makeItem()])
        store.items.append(makeItem(prompt: "single"))

        XCTAssertEqual(store.unbatchedItems.count, 1)
        XCTAssertEqual(store.unbatchedItems.first?.summary, "single")
    }

    // MARK: - renameBatch

    func testRenameBatchUpdatesAllItems() {
        store.enqueueBatch([makeItem(prompt: "a"), makeItem(prompt: "b")])
        let batchId = store.items.first!.batchId!

        store.renameBatch(batchId, to: "New Name")
        XCTAssertTrue(store.items.allSatisfy { $0.batchName == "New Name" })
    }

    func testRenameBatchTrimsWhitespace() {
        store.enqueueBatch([makeItem()])
        let batchId = store.items.first!.batchId!

        store.renameBatch(batchId, to: "  trimmed  ")
        XCTAssertEqual(store.items.first?.batchName, "trimmed")
    }

    func testRenameBatchEmptyStringFallsBackToNil() {
        store.enqueueBatch([makeItem(prompt: "original")])
        let batchId = store.items.first!.batchId!

        store.renameBatch(batchId, to: "   ")
        // After rename to empty/whitespace, batchName becomes nil
        XCTAssertNil(store.items.first?.batchName)
    }

    func testRenameBatchLimitsLength() {
        store.enqueueBatch([makeItem()])
        let batchId = store.items.first!.batchId!
        let long = String(repeating: "x", count: 200)

        store.renameBatch(batchId, to: long)
        XCTAssertLessThanOrEqual(store.items.first?.batchName?.count ?? 0, 60)
    }

    // MARK: - cancelBatch

    func testCancelBatchCancelsPending() {
        store.enqueueBatch([makeItem(prompt: "a"), makeItem(prompt: "b")])
        let batchId = store.items.first!.batchId!

        store.cancelBatch(batchId)
        XCTAssertTrue(store.items.allSatisfy { $0.status == .cancelled })
    }

    func testCancelBatchSkipsSucceeded() {
        store.enqueueBatch([makeItem(prompt: "a"), makeItem(prompt: "b")])
        let batchId = store.items.first!.batchId!
        store.items[0].markSucceeded()

        store.cancelBatch(batchId)
        XCTAssertEqual(store.items[0].status, .succeeded)
        XCTAssertEqual(store.items[1].status, .cancelled)
    }

    // MARK: - clearBatch

    func testClearBatchRemovesOnlyTerminalStates() {
        store.enqueueBatch([makeItem(prompt: "a"), makeItem(prompt: "b"), makeItem(prompt: "c")])
        let batchId = store.items.first!.batchId!
        store.items[0].markSucceeded()
        store.items[1].markFailed("err")
        // items[2] is still pending

        store.clearBatch(batchId)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.status, .pending)
    }

    func testClearBatchDoesNotTouchOtherBatches() {
        store.enqueueBatch([makeItem(prompt: "a")])
        store.enqueueBatch([makeItem(prompt: "b")])
        let batch1 = store.items.first!.batchId!
        store.items[0].markSucceeded()

        store.clearBatch(batch1)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNotNil(store.items.first?.batchId)
    }

    // MARK: - retryBatch

    func testRetryBatchRetainsBatchId() {
        store.enqueueBatch([makeItem()])
        let batchId = store.items.first!.batchId!
        store.items[0].markFailed("err")

        store.retryBatch(batchId)
        XCTAssertEqual(store.items.first?.status, .pending)
        XCTAssertEqual(store.items.first?.batchId, batchId)
    }

    // MARK: - pauseBatch / resumeBatch

    func testPauseBatchAddsToPausedSet() {
        store.enqueueBatch([makeItem()])
        let batchId = store.items.first!.batchId!

        store.pauseBatch(batchId)
        XCTAssertTrue(store.isBatchPaused(batchId))
    }

    func testResumeBatchRemovesFromPausedSet() {
        store.enqueueBatch([makeItem()])
        let batchId = store.items.first!.batchId!

        store.pauseBatch(batchId)
        store.resumeBatch(batchId)
        XCTAssertFalse(store.isBatchPaused(batchId))
    }

    func testBatchInfoReportsPausedState() {
        store.enqueueBatch([makeItem()])
        let batchId = store.items.first!.batchId!
        store.pauseBatch(batchId)

        let batch = store.groupedBatches.first!
        XCTAssertTrue(batch.isPaused)
    }

    // MARK: - Seedance child inherits batchId

    func testSeedanceChildInheritsBatchId() {
        // This tests the data model, not the async submission
        var parent = makeItem(prompt: "parent")
        let batchId = UUID()
        parent.batchId = batchId
        parent.batchName = "test"

        // Simulate what submitItem does for extra tasks
        var child = GenerationQueueItem(
            kind: .seedance,
            createdAt: Date(),
            params: .seedance(SeedanceJobParams(
                prompt: "child", mode: "reference",
                model: "test", ratio: "adaptive",
                resolution: "720p", duration: 5,
                count: 1, generateAudio: true
            ))
        )
        child.batchId = parent.batchId
        child.batchName = parent.batchName

        XCTAssertEqual(child.batchId, batchId)
        XCTAssertEqual(child.batchName, "test")
    }

    // MARK: - Snapshot backward compatibility

    func testSnapshotDecodesWithoutBatchFields() throws {
        let json = """
        {
            "id": "test-1",
            "kind": "gptImage",
            "status": "pending",
            "createdAt": 1000,
            "summaryText": "hello"
        }
        """
        let snapshot = try JSONDecoder().decode(QueueItemSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snapshot.batchId)
        XCTAssertNil(snapshot.batchName)
    }

    func testSnapshotEncodesAndDecodesBatchFields() throws {
        let id = UUID()
        let snapshot = QueueItemSnapshot(
            id: "s1", kind: .gptImage, status: .pending,
            createdAt: Date(), summaryText: "test",
            batchId: id, batchName: "my batch"
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(QueueItemSnapshot.self, from: data)
        XCTAssertEqual(decoded.batchId, id)
        XCTAssertEqual(decoded.batchName, "my batch")
    }
}
