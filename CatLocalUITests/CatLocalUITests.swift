import XCTest

@MainActor
final class CatLocalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyCollectionPrivacyAndCaptureEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Meet Your First Local"].exists)
        XCTAssertTrue(app.staticTexts["No Account"].exists)
        XCTAssertTrue(app.staticTexts["No Public Map"].exists)
        XCTAssertTrue(app.staticTexts["No Model Training"].exists)

        let settingsButton = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["PRIVACY & STORAGE"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["On this iPhone, by design"].exists)

        app.tabBars.buttons["Collection"].tap()
        let cameraButton = app.tabBars.buttons["Camera"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
        cameraButton.tap()
        XCTAssertTrue(
            app.staticTexts["On-device only"].waitForExistence(timeout: 8)
                || app.staticTexts["No camera is available on this device."].waitForExistence(timeout: 2)
                || app.alerts.firstMatch.waitForExistence(timeout: 2)
        )

        let closeCameraButton = app.buttons["Close camera"]
        if closeCameraButton.waitForExistence(timeout: 2) {
            closeCameraButton.tap()
            XCTAssertTrue(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 5))
        }
    }

    func testSeededMemoryAtlasGroupsPlacesPrivately() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed-atlas"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Cards"].exists)

        let atlasButton = app.buttons["Atlas"]
        XCTAssertTrue(atlasButton.waitForExistence(timeout: 5))
        atlasButton.tap()

        XCTAssertTrue(app.staticTexts["Memory Atlas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ferry Steps"].exists)
        XCTAssertTrue(app.staticTexts["Garden Wall"].exists)
        XCTAssertTrue(app.staticTexts["Unplaced"].exists)
        XCTAssertTrue(app.staticTexts["A private index of the places you type yourself. No GPS, coordinates, or public map."].exists)
    }
}
