import XCTest
@testable import aiZhijian

@MainActor
final class PromoPromptStoreTests: XCTestCase {
    var sut: PromoPromptStore!
    private var originalData: Data?

    override func setUp() {
        super.setUp()
        originalData = UserDefaults.standard.data(forKey: "PromoPromptStore.presets")
        sut = PromoPromptStore()
    }

    override func tearDown() {
        if let data = originalData {
            UserDefaults.standard.set(data, forKey: "PromoPromptStore.presets")
        } else {
            UserDefaults.standard.removeObject(forKey: "PromoPromptStore.presets")
        }
        super.tearDown()
    }

    // MARK: - Add

    func testAdd_increasesCount() {
        sut.add(name: "手部展示", prompt: "一只手指点三袋产品...")
        XCTAssertEqual(sut.presets.count, 1)
    }

    func testAdd_ignoresEmptyName() {
        sut.add(name: "", prompt: "some prompt")
        XCTAssertTrue(sut.presets.isEmpty)
    }

    func testAdd_ignoresEmptyPrompt() {
        sut.add(name: "test", prompt: "")
        XCTAssertTrue(sut.presets.isEmpty)
    }

    func testAdd_ignoresWhitespaceOnly() {
        sut.add(name: "   ", prompt: "   ")
        XCTAssertTrue(sut.presets.isEmpty)
    }

    func testAdd_multiplePresets() {
        sut.add(name: "A", prompt: "prompt A")
        sut.add(name: "B", prompt: "prompt B")
        sut.add(name: "C", prompt: "prompt C")
        XCTAssertEqual(sut.presets.count, 3)
    }

    // MARK: - Delete

    func testDelete_removesById() {
        sut.add(name: "A", prompt: "pa")
        sut.add(name: "B", prompt: "pb")
        let id = sut.presets[0].id
        sut.delete(id)
        XCTAssertEqual(sut.presets.count, 1)
        XCTAssertEqual(sut.presets[0].name, "B")
    }

    func testDelete_nonexistentId_doesNothing() {
        sut.add(name: "A", prompt: "pa")
        sut.delete(UUID())
        XCTAssertEqual(sut.presets.count, 1)
    }

    // MARK: - Update

    func testUpdate_changesNameAndPrompt() {
        sut.add(name: "A", prompt: "pa")
        var preset = sut.presets[0]
        preset.name = "B"
        preset.prompt = "pb"
        sut.update(preset)
        XCTAssertEqual(sut.presets[0].name, "B")
        XCTAssertEqual(sut.presets[0].prompt, "pb")
    }

    func testUpdate_nonexistent_doesNothing() {
        sut.add(name: "A", prompt: "pa")
        let orphan = PromoPromptPreset(name: "X", prompt: "xx")
        sut.update(orphan)
        XCTAssertEqual(sut.presets.count, 1)
        XCTAssertEqual(sut.presets[0].name, "A")
    }

    // MARK: - Persistence

    func testPersistence_roundTrip() {
        sut.add(name: "Persist", prompt: "should survive")
        let savedId = sut.presets[0].id

        // Create a new store instance (simulate reload)
        let newStore = PromoPromptStore()
        XCTAssertEqual(newStore.presets.count, 1)
        XCTAssertEqual(newStore.presets[0].id, savedId)
        XCTAssertEqual(newStore.presets[0].name, "Persist")
    }

    func testPersistence_emptyAfterDelete() {
        sut.add(name: "Tmp", prompt: "temp")
        sut.delete(sut.presets[0].id)

        let newStore = PromoPromptStore()
        XCTAssertTrue(newStore.presets.isEmpty)
    }

    func testLoad_corruptedData_returnsEmpty() {
        UserDefaults.standard.set("invalid json".data(using: .utf8)!, forKey: "PromoPromptStore.presets")
        let store = PromoPromptStore()
        XCTAssertTrue(store.presets.isEmpty)
    }
}
