import XCTest

@MainActor
final class SmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["RUN_UI_TESTS"] == "1" else {
            throw XCTSkip("Skipping foreground UI tests by default. Use the ai智剪UITests scheme to run them.")
        }
        app = XCUIApplication()
        app.launchEnvironment["UITEST_SKIP_LOGIN"] = "YES"
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testSidebarContainsExpectedTitles() throws {
        let titles = ["图片生成", "Seedance 视频", "Banana 图片", "Wan 视频", "Veo 视频", "设置"]
        for title in titles {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5),
                          "Should find '\(title)' in sidebar")
        }
    }

    func testSettingsSidebarExists() throws {
        let item = app.descendants(matching: .any).matching(identifier: "sidebar-settings").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Settings sidebar item should exist")
    }

    func testSidebarNavigationToImageGen() throws {
        clickSidebarItem("sidebar-imageGen")
        XCTAssertTrue(app.staticTexts.matching(identifier: "imagegen-prompt-heading").firstMatch.waitForExistence(timeout: 5))
    }

    func testSidebarNavigationToBanana() throws {
        clickSidebarItem("sidebar-banana")
        XCTAssertTrue(app.staticTexts.matching(identifier: "banana-provider-label").firstMatch.waitForExistence(timeout: 5))
    }

    func testSidebarNavigationToWan() throws {
        clickSidebarItem("sidebar-wan")
        XCTAssertTrue(app.staticTexts.matching(identifier: "wan-prompt-heading").firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func clickSidebarItem(_ identifier: String) {
        let outline = app.outlines.firstMatch
        let element = outline.descendants(matching: .any).matching(identifier: identifier).firstMatch
        if element.waitForExistence(timeout: 5) {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }
}
