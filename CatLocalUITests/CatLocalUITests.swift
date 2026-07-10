import XCTest

@MainActor
final class CatLocalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func tapCaptureEditorCancel(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let cancelButton = app.buttons["capture-editor-cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), file: file, line: line)

        let hittable = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: hittable, object: cancelButton)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, file: file, line: line)

        cancelButton.tap()
    }

    private func tapWhenHittable(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)

        let hittable = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: hittable, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, file: file, line: line)

        element.tap()
    }

    func testOnboardingMovesThroughWelcomePrivacyAndFirstCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-show-onboarding"]
        app.launch()

        let onboardingPrimaryAction = app.buttons["onboarding-primary-action"]
        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 8))
        XCTAssertEqual(onboardingPrimaryAction.label, "Continue")
        XCTAssertFalse(app.buttons["onboarding-skip-home"].exists)
        XCTAssertTrue(app.staticTexts["Welcome to CatLocal"].exists)
        XCTAssertTrue(app.staticTexts["A private place for the cats you meet."].exists)
        XCTAssertTrue(app.staticTexts["Capture or Import"].exists)
        XCTAssertTrue(app.staticTexts["Lift On Device"].exists)
        XCTAssertTrue(app.staticTexts["Make It Yours"].exists)

        tapWhenHittable(onboardingPrimaryAction)

        XCTAssertTrue(app.descendants(matching: .any)["onboarding-privacy-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Photos stay on this iPhone."].exists)
        XCTAssertTrue(app.staticTexts["On this iPhone, by design"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-privacy-cues"].exists)
        XCTAssertTrue(app.staticTexts["On-device Vision"].exists)
        XCTAssertTrue(app.staticTexts["Location Data Stripped"].exists)
        XCTAssertTrue(app.staticTexts["No Account or Cloud"].exists)
        XCTAssertFalse(app.buttons["onboarding-skip-home"].exists)
        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingPrimaryAction.label, "Continue")
        tapWhenHittable(onboardingPrimaryAction)

        XCTAssertTrue(app.staticTexts["Ready for Your First Local"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Home opens next. Tap Camera when you meet a cat, or choose a private photo."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-first-card-anatomy"].exists)
        XCTAssertTrue(app.staticTexts["Your first card keeps the lifted cutout, design, notes, and typed place together."].exists)
        XCTAssertTrue(app.staticTexts["Lifted cutout"].exists)
        XCTAssertTrue(app.staticTexts["Card details"].exists)

        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingPrimaryAction.label, "Start Collecting")
        tapWhenHittable(onboardingPrimaryAction)

        XCTAssertTrue(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start Collecting"].exists)
    }

    func testOnboardingKeepsThreeStepCompletion() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-show-onboarding"]
        app.launch()

        let onboardingPrimaryAction = app.buttons["onboarding-primary-action"]
        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["onboarding-skip-home"].exists)
        XCTAssertFalse(app.buttons["Start Collecting"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-privacy-title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["Start Collecting"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.buttons["Start Collecting"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready for Your First Local"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 5))
    }

    func testEmptyHomeCaptureEntryAndSettingsReceipt() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Meet Your First Local"].exists)
        XCTAssertTrue(app.staticTexts["Capture an encounter and turn it into a local card."].exists)

        let settingsButton = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Privacy Receipt"].exists)
        XCTAssertTrue(app.staticTexts["Photos"].exists)
        XCTAssertTrue(app.staticTexts["Recognition"].exists)
        XCTAssertTrue(app.staticTexts["Location"].exists)
        XCTAssertTrue(app.staticTexts["Network"].exists)
        XCTAssertTrue(app.staticTexts["The collection requires no account, upload, cloud AI, or model-training use."].exists)
        XCTAssertTrue(app.staticTexts["Local Storage"].exists)
        XCTAssertFalse(app.staticTexts["Includes card details, notes, typed Catlas labels, originals, cutouts, and thumbnails."].exists)

        app.tabBars.buttons["Home"].tap()
        let cameraButton = app.tabBars.buttons["Camera"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
        cameraButton.tap()
        let captureScreen = app.descendants(matching: .any)["capture-screen"]
        XCTAssertTrue(
            captureScreen.waitForExistence(timeout: 8)
                || app.staticTexts["Private scan"].waitForExistence(timeout: 2)
                || app.staticTexts["Camera access is off"].waitForExistence(timeout: 2)
                || app.staticTexts["No camera is available on this device."].waitForExistence(timeout: 2)
                || app.alerts.firstMatch.waitForExistence(timeout: 2)
        )

        let closeCameraButton = app.buttons["Close camera"]
        if closeCameraButton.waitForExistence(timeout: 2) {
            closeCameraButton.tap()
            app.tabBars.buttons["Home"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["empty-collection"].waitForExistence(timeout: 8))
        }
    }

    func testSettingsDeleteConfirmationExplainsStoredData() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed-atlas"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        let settingsButton = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))

        let deleteAllButton = app.buttons["Delete All Cats"]
        if !deleteAllButton.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5))
        deleteAllButton.tap()

        XCTAssertTrue(app.staticTexts["Delete every cat?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This permanently removes every saved cat from this iPhone."].exists)
        XCTAssertTrue(app.staticTexts["This cannot be undone."].exists)
        XCTAssertTrue(app.staticTexts["Includes card details, notes, typed Catlas labels, originals, cutouts, and thumbnails."].exists)
        XCTAssertTrue(app.buttons["Delete All"].exists)

        app.buttons["Cancel"].tap()
    }

    func testSeededCatlasGroupsPlacesPrivately() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed-atlas"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Cards"].exists)

        let atlasButton = app.buttons["Catlas"]
        XCTAssertTrue(atlasButton.waitForExistence(timeout: 5))
        atlasButton.tap()

        XCTAssertTrue(app.staticTexts["2 places typed by you."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Ferry Steps, 1 cat"].exists)
        XCTAssertTrue(app.buttons["Garden Wall, 1 cat"].exists)

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Unplaced for now"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add Memory Place"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["Unplaced, 1 cat"].waitForExistence(timeout: 5))
        app.buttons["Unplaced, 1 cat"].tap()

        XCTAssertTrue(app.staticTexts["1 cat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sort saved cards"].waitForExistence(timeout: 5))
        let selectButton = app.buttons["Select cards for deletion"]
        XCTAssertTrue(selectButton.exists)
        selectButton.tap()
        XCTAssertTrue(app.buttons["Done selecting cards"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose cards to delete"].waitForExistence(timeout: 5))
        app.buttons["Done selecting cards"].tap()
        XCTAssertTrue(app.buttons["Select cards for deletion"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add Memory Place"].waitForExistence(timeout: 1))

        let unplacedCard = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cat,")).firstMatch
        XCTAssertTrue(unplacedCard.waitForExistence(timeout: 5))
        unplacedCard.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
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

        let saveNowButton = app.buttons["save-cat-immediate"]
        XCTAssertTrue(saveNowButton.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["tap-to-customize"].exists)
        saveNowButton.tap()

        let celebrationHomeButton = app.buttons["card-minting-home"]
        let celebrationEditButton = app.buttons["card-minting-edit"]
        XCTAssertTrue(celebrationHomeButton.waitForExistence(timeout: 15))
        XCTAssertTrue(celebrationEditButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Card ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pixel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Warm orange hello."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rooftop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["South ledge"].waitForExistence(timeout: 5))

        celebrationEditButton.tap()
        XCTAssertTrue(app.staticTexts["Make It Yours"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose a card design now, or save first and edit later."].exists)
        XCTAssertTrue(app.scrollViews["Card design"].exists || app.staticTexts["Archive"].exists)
        let nicknameField = app.textFields["Nickname (optional)"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nicknameField.value as? String, "Pixel")
        XCTAssertTrue(app.buttons["Save Cat"].waitForExistence(timeout: 5))
        app.buttons["Save Cat"].tap()
        XCTAssertTrue(celebrationHomeButton.waitForExistence(timeout: 8))

        celebrationHomeButton.tap()
        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["4 saved"].waitForExistence(timeout: 5))
    }

    func testValidationImportShowsCutoutRevealBeforeEditor() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-synthetic-cutout"
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

        let cutoutReveal = app.descendants(matching: .any)["cutout-reveal"]
        XCTAssertTrue(cutoutReveal.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Lifting the subject"].exists)
        XCTAssertTrue(app.buttons["save-cat-immediate"].waitForExistence(timeout: 15))
    }

    func testValidationImportPromptsBeforeDiscardingDraftCutout() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-synthetic-cutout",
            "-catlocal-ui-skip-sticker-reveal"
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

        let saveNowButton = app.buttons["save-cat-immediate"]
        XCTAssertTrue(saveNowButton.waitForExistence(timeout: 15))

        tapCaptureEditorCancel(in: app)
        XCTAssertTrue(app.buttons["Discard Draft"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Keep Draft"].exists)

        app.buttons["Keep Draft"].tap()
        XCTAssertTrue(saveNowButton.waitForExistence(timeout: 5))

        tapCaptureEditorCancel(in: app)
        XCTAssertTrue(app.buttons["Discard Draft"].waitForExistence(timeout: 5))
        app.buttons["Discard Draft"].tap()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 5))
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

        XCTAssertTrue(app.staticTexts["I couldn't find the cat clearly"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Use Foreground Cutout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No confirmed cat in this photo."].exists)
        XCTAssertTrue(app.staticTexts["You can review the foreground cutout and save only if it looks right."].exists)
    }
}
