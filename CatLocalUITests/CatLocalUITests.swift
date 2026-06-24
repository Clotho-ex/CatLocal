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
        XCTAssertTrue(app.staticTexts["Your first local is out there"].exists)

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["PRIVACY & STORAGE"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["On this iPhone, by design"].exists)

        app.buttons["Collection"].tap()
        let cameraButton = app.buttons["Photograph or import a cat"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
        cameraButton.tap()
        XCTAssertTrue(
            app.staticTexts["On-device only"].waitForExistence(timeout: 8)
                || app.staticTexts["No camera is available on this device."].waitForExistence(timeout: 2)
                || app.alerts.firstMatch.waitForExistence(timeout: 2)
        )
    }
}
