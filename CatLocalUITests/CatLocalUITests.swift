import XCTest

@MainActor
final class CatLocalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyHomePrivacyAndCaptureEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Meet Your First Cat"].exists)
        XCTAssertTrue(app.staticTexts["No Account"].exists)
        XCTAssertTrue(app.staticTexts["No Public Map"].exists)
        XCTAssertTrue(app.staticTexts["No AI Training"].exists)

        let settingsButton = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["On this iPhone, by Design"].exists)
        XCTAssertTrue(app.staticTexts["Local Storage"].exists)

        app.tabBars.buttons["Home"].tap()
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
            XCTAssertTrue(app.staticTexts["Meet Your First Cat"].waitForExistence(timeout: 5))
        }
    }

    func testSeededCatlasGroupsPlacesPrivately() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed-atlas"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Cats"].exists)

        let atlasButton = app.buttons["Catlas"]
        XCTAssertTrue(atlasButton.waitForExistence(timeout: 5))
        atlasButton.tap()

        XCTAssertTrue(app.staticTexts["A private index of the places you type yourself. No GPS, coordinates, or public map."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Ferry Steps, 1 cat"].exists)
        XCTAssertTrue(app.buttons["Garden Wall, 1 cat"].exists)

        app.swipeUp()
        XCTAssertTrue(app.buttons["Unplaced cats, 1 cat"].waitForExistence(timeout: 5))
    }
}
