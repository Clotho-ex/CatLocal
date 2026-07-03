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

    func testValidationImportReachesStickerEditor() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-ui-testing-seed-atlas",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-synthetic-cutout",
            "-catlocal-ui-skip-sticker-reveal",
            "-catlocal-ui-prefill-editor-fields"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        let cameraButton = app.tabBars.buttons["Camera"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
        cameraButton.tap()

        let validationButton = app.buttons["Use validation photo"]
        if !validationButton.waitForExistence(timeout: 5) {
            cameraButton.tap()
        }
        XCTAssertTrue(validationButton.waitForExistence(timeout: 8))
        validationButton.tap()

        let customizeButton = app.buttons["tap-to-customize"]
        XCTAssertTrue(customizeButton.waitForExistence(timeout: 15))
        customizeButton.tap()

        XCTAssertTrue(app.staticTexts["Make it Yours"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pick a card for this sticker, then add the details you want to remember."].exists)
        XCTAssertTrue(app.scrollViews["Card design"].exists || app.staticTexts["Archive"].exists)
        XCTAssertTrue(app.buttons["Save Cat"].waitForExistence(timeout: 5))

        app.buttons["Save Cat"].tap()
        let celebrationHomeButton = app.buttons["card-minting-home"]
        let celebrationEditButton = app.buttons["card-minting-edit"]
        XCTAssertTrue(celebrationHomeButton.waitForExistence(timeout: 15))
        XCTAssertTrue(celebrationEditButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pixel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Warm orange hello."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rooftop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["South ledge"].waitForExistence(timeout: 5))

        celebrationEditButton.tap()
        XCTAssertTrue(app.buttons["Save Cat"].waitForExistence(timeout: 5))
        app.buttons["Save Cat"].tap()
        XCTAssertTrue(celebrationHomeButton.waitForExistence(timeout: 8))

        celebrationHomeButton.tap()
        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["4 cats"].waitForExistence(timeout: 5))
    }

    func testValidationImportFallbackExplainsUnconfirmedCutout() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-force-foreground-fallback"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        let cameraButton = app.tabBars.buttons["Camera"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
        cameraButton.tap()

        let validationButton = app.buttons["Use validation photo"]
        if !validationButton.waitForExistence(timeout: 5) {
            cameraButton.tap()
        }
        XCTAssertTrue(validationButton.waitForExistence(timeout: 8))
        validationButton.tap()

        XCTAssertTrue(app.staticTexts["That one was tricky"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Use Cutout Anyway"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CatLocal could not confirm a cat in this photo."].exists)
        XCTAssertTrue(app.staticTexts["You can still use the foreground cutout and edit the card before saving."].exists)
    }
}
