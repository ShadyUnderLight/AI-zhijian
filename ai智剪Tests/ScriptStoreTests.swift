import XCTest
@testable import aiZhijian

@MainActor
final class ScriptStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "ScriptStore.scripts")
        defaults.removeObject(forKey: "ScriptStore.scripts.backup")
    }

    // MARK: - ScriptShot backward compat

    func testScriptShotDecodesMissingOptionalFields() throws {
        let json = """
        {"id":"s1","title":"开场"}
        """
        let shot = try JSONDecoder().decode(ScriptShot.self, from: Data(json.utf8))
        XCTAssertEqual(shot.id, "s1")
        XCTAssertEqual(shot.title, "开场")
        XCTAssertEqual(shot.referencePrompt, "")
        XCTAssertEqual(shot.videoPrompt, "")
        XCTAssertEqual(shot.sortOrder, 0)
    }

    func testScriptShotDecodesMissingId() throws {
        let json = """
        {"title":"开场","referencePrompt":"ref","videoPrompt":"vid","sortOrder":1}
        """
        let shot = try JSONDecoder().decode(ScriptShot.self, from: Data(json.utf8))
        XCTAssertFalse(shot.id.isEmpty)
        XCTAssertEqual(shot.title, "开场")
        XCTAssertEqual(shot.referencePrompt, "ref")
    }

    func testScriptShotDecodesEmptyObject() throws {
        let json = "{}"
        let shot = try JSONDecoder().decode(ScriptShot.self, from: Data(json.utf8))
        XCTAssertFalse(shot.id.isEmpty)
        XCTAssertEqual(shot.title, "")
        XCTAssertEqual(shot.referencePrompt, "")
        XCTAssertEqual(shot.videoPrompt, "")
        XCTAssertEqual(shot.sortOrder, 0)
    }

    // MARK: - Script backward compat

    func testScriptDecodesMissingOptionalFields() throws {
        let json = """
        {"title":"测试脚本","product":"测试产品","shots":[]}
        """
        let script = try JSONDecoder().decode(Script.self, from: Data(json.utf8))
        XCTAssertEqual(script.title, "测试脚本")
        XCTAssertEqual(script.product, "测试产品")
        XCTAssertTrue(script.shots.isEmpty)
        XCTAssertFalse(script.id.isEmpty)
    }

    func testScriptDecodesMissingShotsDefaultsToEmpty() throws {
        let json = """
        {"id":"s1","title":"测试","product":"产品"}
        """
        let script = try JSONDecoder().decode(Script.self, from: Data(json.utf8))
        XCTAssertEqual(script.id, "s1")
        XCTAssertTrue(script.shots.isEmpty)
    }

    func testScriptDecodesMissingId() throws {
        let json = """
        {"title":"测试","product":"产品","shots":[]}
        """
        let script = try JSONDecoder().decode(Script.self, from: Data(json.utf8))
        XCTAssertFalse(script.id.isEmpty)
        XCTAssertEqual(script.title, "测试")
    }

    // MARK: - ScriptShot Codable round-trip

    func testScriptShotRoundTrip() throws {
        let shot = ScriptShot(title: "开场", referencePrompt: "一只猫", videoPrompt: "猫在跑", sortOrder: 0)
        let data = try JSONEncoder().encode(shot)
        let decoded = try JSONDecoder().decode(ScriptShot.self, from: data)
        XCTAssertEqual(decoded.id, shot.id)
        XCTAssertEqual(decoded.title, shot.title)
        XCTAssertEqual(decoded.referencePrompt, shot.referencePrompt)
        XCTAssertEqual(decoded.videoPrompt, shot.videoPrompt)
        XCTAssertEqual(decoded.sortOrder, shot.sortOrder)
    }

    // MARK: - Script Codable round-trip

    func testScriptRoundTrip() throws {
        let shots = [
            ScriptShot(title: "镜头1", referencePrompt: "ref1", videoPrompt: "vid1", sortOrder: 0),
            ScriptShot(title: "镜头2", referencePrompt: "ref2", videoPrompt: "vid2", sortOrder: 1),
        ]
        let script = Script(title: "我的脚本", product: "测试商品", shots: shots)
        let data = try JSONEncoder().encode(script)
        let decoded = try JSONDecoder().decode(Script.self, from: data)
        XCTAssertEqual(decoded.id, script.id)
        XCTAssertEqual(decoded.title, script.title)
        XCTAssertEqual(decoded.product, script.product)
        XCTAssertEqual(decoded.shots.count, 2)
        XCTAssertEqual(decoded.shots[0].title, "镜头1")
        XCTAssertEqual(decoded.shots[1].referencePrompt, "ref2")
    }

    // MARK: - ScriptStore persistence

    func testScriptStoreSaveAndLoad() {
        let store = ScriptStore()
        let script = Script(title: "持久化测试", product: "商品", shots: [
            ScriptShot(title: "镜头1", referencePrompt: "ref")
        ])
        store.save(script: script)

        let loaded = ScriptStore()
        XCTAssertEqual(loaded.scripts.count, 1)
        XCTAssertEqual(loaded.scripts[0].title, "持久化测试")
        XCTAssertEqual(loaded.scripts[0].shots.count, 1)
    }

    func testScriptStoreDelete() {
        let store = ScriptStore()
        let s1 = Script(title: "s1", product: "p1", shots: [])
        let s2 = Script(title: "s2", product: "p2", shots: [])
        store.save(script: s1)
        store.save(script: s2)
        XCTAssertEqual(store.scripts.count, 2)

        store.delete(s1.id)
        XCTAssertEqual(store.scripts.count, 1)
        XCTAssertEqual(store.scripts[0].id, s2.id)
    }

    func testScriptStoreUpdateExisting() {
        let store = ScriptStore()
        var script = Script(title: "原标题", product: "原产品", shots: [])
        store.save(script: script)

        script.title = "新标题"
        store.save(script: script)

        let loaded = ScriptStore()
        XCTAssertEqual(loaded.scripts.count, 1)
        XCTAssertEqual(loaded.scripts[0].title, "新标题")
    }

    func testScriptStoreScriptById() {
        let store = ScriptStore()
        let script = Script(title: "查找测试", product: "p", shots: [])
        store.save(script: script)

        let found = store.script(with: script.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "查找测试")

        let notFound = store.script(with: "nonexistent")
        XCTAssertNil(notFound)
    }

    // MARK: - Legacy format compatibility

    func testScriptStoreLoadsUnversionedArray() {
        let script = Script(title: "旧格式", product: "p", shots: [])
        let data = try! JSONEncoder().encode([script])
        UserDefaults.standard.set(data, forKey: "ScriptStore.scripts")

        let store = ScriptStore()
        XCTAssertEqual(store.scripts.count, 1)
        XCTAssertEqual(store.scripts[0].title, "旧格式")
    }

    func testScriptStoreHandlesCorruptedData() {
        UserDefaults.standard.set(Data("garbage".utf8), forKey: "ScriptStore.scripts")

        let store = ScriptStore()
        XCTAssertTrue(store.scripts.isEmpty)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "ScriptStore.scripts.backup"))
    }

    func testScriptStoreHandlesPartialCorruptionInLegacyArray() {
        let valid = Script(title: "好数据", product: "p", shots: [])
        let validData = try! JSONEncoder().encode(valid)
        let validDict = try! JSONSerialization.jsonObject(with: validData) as! [String: Any]

        let raw: [[String: Any]] = [
            validDict,
            ["id": "bad", "title": "残缺"],
        ]
        let data = try! JSONSerialization.data(withJSONObject: raw)
        UserDefaults.standard.set(data, forKey: "ScriptStore.scripts")

        let store = ScriptStore()
        XCTAssertEqual(store.scripts.count, 1)
        XCTAssertEqual(store.scripts[0].title, "好数据")
    }

    // MARK: - Edge cases

    func testScriptStoreEmptyOnFirstLaunch() {
        let store = ScriptStore()
        XCTAssertTrue(store.scripts.isEmpty)
    }

    func testScriptShotAutoSortOrderOnSave() {
        let store = ScriptStore()
        let s1 = ScriptShot(title: "A", sortOrder: 999)
        let s2 = ScriptShot(title: "B", sortOrder: 888)
        var script = Script(title: "排序", product: "p", shots: [s1, s2])
        // Simulate what ScriptEditorView.save does
        for i in script.shots.indices {
            script.shots[i].sortOrder = i
        }
        store.save(script: script)

        let loaded = ScriptStore()
        XCTAssertEqual(loaded.scripts[0].shots[0].sortOrder, 0)
        XCTAssertEqual(loaded.scripts[0].shots[1].sortOrder, 1)
    }
}


