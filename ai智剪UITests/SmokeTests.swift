import XCTest

@MainActor
final class SmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        if ProcessInfo.processInfo.environment["SKIP_UI_TESTS"] == "1" {
            throw XCTSkip("Skipped via SKIP_UI_TESTS=1")
        }
        app = XCUIApplication()
        app.launchEnvironment["UITEST_SKIP_LOGIN"] = "YES"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15),
                      "App should be running in foreground")
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testAppLaunches() throws {
        XCTAssertTrue(app.staticTexts["AI 智剪"].waitForExistence(timeout: 5))
    }

    func testSettingsMenuItemAccessible() throws {
        let item = app.outlines.firstMatch
            .descendants(matching: .any)
            .matching(identifier: "sidebar-settings")
            .firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5),
                      "Settings sidebar item should exist")
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
