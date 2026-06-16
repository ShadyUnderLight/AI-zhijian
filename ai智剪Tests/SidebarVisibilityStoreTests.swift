import XCTest
@testable import aiZhijian

@MainActor
final class SidebarVisibilityStoreTests: XCTestCase {
    private var sut: SidebarVisibilityStore!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "sidebar_hidden_tabs")
        sut = SidebarVisibilityStore()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "sidebar_hidden_tabs")
        sut = nil
        super.tearDown()
    }

    // MARK: - 默认状态

    func testDefaultAllTabsVisible() {
        for tab in SidebarTab.allTabs {
            XCTAssertTrue(sut.isVisible(tab), "\(tab.rawValue) 默认应可见")
        }
    }

    // MARK: - 隐藏/显示

    func testHideTabMakesItInvisible() {
        sut.setHidden(.imageGen, true)
        XCTAssertFalse(sut.isVisible(.imageGen))
    }

    func testShowTabMakesItVisible() {
        sut.setHidden(.imageGen, true)
        sut.setHidden(.imageGen, false)
        XCTAssertTrue(sut.isVisible(.imageGen))
    }

    func testHideTabDoesNotAffectOtherTabs() {
        sut.setHidden(.imageGen, true)
        XCTAssertFalse(sut.isVisible(.imageGen))
        XCTAssertTrue(sut.isVisible(.banana))
        XCTAssertTrue(sut.isVisible(.seedance))
        XCTAssertTrue(sut.isVisible(.dashboard))
    }

    // MARK: - Toggle

    func testToggleFlipsVisibility() {
        let initial = sut.isVisible(.wan)
        sut.toggle(.wan)
        XCTAssertEqual(sut.isVisible(.wan), !initial)
        sut.toggle(.wan)
        XCTAssertEqual(sut.isVisible(.wan), initial)
    }

    // MARK: - Reset

    func testResetAllShowsEverything() {
        sut.setHidden(.wan, true)
        sut.setHidden(.grok, true)
        sut.setHidden(.banana, true)
        sut.resetAll()
        for tab in SidebarTab.allTabs {
            XCTAssertTrue(sut.isVisible(tab))
        }
    }

    // MARK: - HideAll

    func testHideAllHidesPinnableTabs() {
        sut.hideAll()
        for tab in SidebarTab.allTabs {
            if tab.isPinnable {
                XCTAssertFalse(sut.isVisible(tab), "\(tab.rawValue) 应被隐藏")
            } else {
                XCTAssertTrue(sut.isVisible(tab), "不可置顶项 \(tab.rawValue) 不应被隐藏")
            }
        }
    }

    // MARK: - 持久化

    func testPersistenceRoundTrip() {
        sut.setHidden(.seedance, true)
        sut.setHidden(.voiceGen, true)
        // 创建新实例模拟重新启动
        let newStore = SidebarVisibilityStore()
        XCTAssertFalse(newStore.isVisible(.seedance))
        XCTAssertFalse(newStore.isVisible(.voiceGen))
        XCTAssertTrue(newStore.isVisible(.dashboard))
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundTrip() throws {
        sut.setHidden(.veo, true)
        sut.setHidden(.grok, true)
        let data = try JSONEncoder().encode(sut.hiddenTabs)
        let decoded = try JSONDecoder().decode(Set<String>.self, from: data)
        XCTAssertEqual(decoded, sut.hiddenTabs)
        XCTAssertTrue(decoded.contains("Veo 视频"))
        XCTAssertTrue(decoded.contains("Grok 视频"))
        XCTAssertFalse(decoded.contains("首页"))
    }

    // MARK: - 不变量

    func testOnlyValidTabRawValuesAreSaved() {
        sut.setHidden(.wan, true)
        sut.setHidden(.veo, true)
        for rawValue in sut.hiddenTabs {
            XCTAssertTrue(SidebarTab.allTabs.contains(where: { $0.rawValue == rawValue }),
                         "\(rawValue) 不是有效的 SidebarTab rawValue")
        }
    }

    // MARK: - 脏数据容错

    func testLoadHandlesCorruptedUserDefaults() {
        UserDefaults.standard.set(Data("not an array".utf8), forKey: "sidebar_hidden_tabs")
        let store = SidebarVisibilityStore()
        XCTAssertTrue(store.hiddenTabs.isEmpty, "损坏数据应恢复为默认状态")
        for tab in SidebarTab.allTabs {
            XCTAssertTrue(store.isVisible(tab))
        }
    }

    func testLoadHandlesInvalidJSON() {
        UserDefaults.standard.set(Data("garbage data".utf8), forKey: "sidebar_hidden_tabs")
        let store = SidebarVisibilityStore()
        XCTAssertTrue(store.hiddenTabs.isEmpty)
    }

    // MARK: - filterVisible

    func testFilterVisibleExcludesHiddenTabs() {
        sut.setHidden(.wan, true)
        sut.setHidden(.grok, true)
        let all = SidebarTab.allTabs
        let visible = sut.filterVisible(all)
        XCTAssertFalse(visible.contains(.wan))
        XCTAssertFalse(visible.contains(.grok))
        XCTAssertTrue(visible.contains(.imageGen))
        XCTAssertTrue(visible.contains(.dashboard))
    }

    func testFilterVisibleIncludesAllWhenNoneHidden() {
        let all = SidebarTab.allTabs
        let visible = sut.filterVisible(all)
        XCTAssertEqual(visible.count, all.count)
    }

    func testFilterVisibleWithEmptyInput() {
        let visible = sut.filterVisible([])
        XCTAssertTrue(visible.isEmpty)
    }

    // MARK: - App Integration

    func testAppCanCreateStore() {
        let store = SidebarVisibilityStore()
        XCTAssertNotNil(store)
        XCTAssertNoThrow(store.isVisible(.dashboard))
    }

    func testMainViewHiddenTabIntegration() {
        let store = SidebarVisibilityStore()
        store.setHidden(.banana, true)
        XCTAssertTrue(store.hiddenTabs.contains("Banana 图片"))
        XCTAssertFalse(store.isVisible(.banana))
        XCTAssertTrue(store.isVisible(.imageGen))
    }

    func testSettingsViewCanUseStore() {
        let store = SidebarVisibilityStore()
        store.setHidden(.seedance, true)
        store.setHidden(.voiceGen, true)
        XCTAssertFalse(store.isVisible(.seedance))
        XCTAssertFalse(store.isVisible(.voiceGen))
        XCTAssertTrue(store.isVisible(.dashboard))
    }
}
