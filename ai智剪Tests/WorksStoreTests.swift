import XCTest
@testable import aiZhijian

@MainActor
final class WorksStoreTests: XCTestCase {

    private var store: WorksStore!

    override func setUp() {
        super.setUp()
        store = WorksStore()
        store.records.removeAll()
    }

    override func tearDown() {
        store.records.removeAll()
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
}
