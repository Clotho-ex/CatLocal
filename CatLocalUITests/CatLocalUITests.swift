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

    private func selectTab(
        _ tab: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenHittable(tab, file: file, line: line)

        let selected = NSPredicate(format: "selected == true")
        let initialSelection = XCTNSPredicateExpectation(predicate: selected, object: tab)
        if XCTWaiter.wait(for: [initialSelection], timeout: 1) != .completed {
            tab.tap()
        }

        let confirmedSelection = XCTNSPredicateExpectation(predicate: selected, object: tab)
        XCTAssertEqual(
            XCTWaiter.wait(for: [confirmedSelection], timeout: 5),
            .completed,
            file: file,
            line: line
        )
    }

    private func tapToNavigate(
        _ element: XCUIElement,
        destination: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenHittable(element, file: file, line: line)
        if !destination.waitForExistence(timeout: 2) {
            element.tap()
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 5), file: file, line: line)
    }

    func testOnboardingMovesThroughWelcomePrivacyAndFirstCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-show-onboarding"]
        app.launch()

        let onboardingPrimaryAction = app.buttons["onboarding-primary-action"]
        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 8))
        let onboardingProgress = app.descendants(matching: .any)["onboarding-progress"]
        XCTAssertTrue(onboardingProgress.waitForExistence(timeout: 5))
        let onboardingStep = app.descendants(matching: .any)["onboarding-step"]
        let skipButton = app.buttons["onboarding-skip-home"]
        XCTAssertTrue(onboardingStep.waitForExistence(timeout: 5))
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(skipButton.frame.height, 44)
        XCTAssertFalse(app.scrollViews["onboarding-scroll"].exists)
        XCTAssertGreaterThanOrEqual(
            onboardingProgress.frame.width,
            app.windows.firstMatch.frame.width * 0.8
        )
        XCTAssertEqual(onboardingProgress.label, "Onboarding step 1 of 3")
        XCTAssertLessThan(onboardingStep.frame.midX, app.windows.firstMatch.frame.midX)
        XCTAssertGreaterThan(skipButton.frame.midX, app.windows.firstMatch.frame.midX)
        XCTAssertLessThanOrEqual(app.staticTexts["Make It Yours"].frame.maxY, onboardingPrimaryAction.frame.minY)
        XCTAssertEqual(onboardingPrimaryAction.label, "Continue")
        XCTAssertTrue(skipButton.exists)
        XCTAssertTrue(app.staticTexts["Welcome to CatLocal"].exists)
        XCTAssertTrue(app.staticTexts["A private place for the cats you meet."].exists)
        XCTAssertTrue(app.staticTexts["Capture or Import"].exists)
        XCTAssertTrue(app.staticTexts["Lift On Device"].exists)
        XCTAssertTrue(app.staticTexts["Make It Yours"].exists)
        XCTAssertTrue(app.staticTexts["Camera or private photo"].exists)
        XCTAssertTrue(app.staticTexts["Looking for cats, then lifting the subject"].exists)
        XCTAssertTrue(app.staticTexts["Choose a design, notes, and typed place"].exists)
        XCTAssertLessThan(
            app.staticTexts["Saved here"].frame.maxY,
            app.staticTexts["Welcome to CatLocal"].frame.minY
        )
        XCTAssertLessThan(
            app.staticTexts["Welcome to CatLocal"].frame.maxY,
            app.staticTexts["Capture or Import"].frame.minY
        )

        tapWhenHittable(onboardingPrimaryAction)

        let privacyTitle = app.descendants(matching: .any)["onboarding-privacy-title"]
        XCTAssertTrue(privacyTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingProgress.label, "Onboarding step 2 of 3")
        XCTAssertLessThanOrEqual(onboardingProgress.frame.maxY, privacyTitle.frame.minY)
        XCTAssertTrue(app.staticTexts["Photos stay on this iPhone."].exists)
        XCTAssertTrue(app.staticTexts["On this iPhone, by design"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-privacy-cues"].exists)
        let onDeviceVision = app.staticTexts["On-device Vision"]
        XCTAssertTrue(onDeviceVision.exists)
        XCTAssertGreaterThan(onDeviceVision.frame.height, 20)
        XCTAssertTrue(app.staticTexts["Location Data Stripped"].exists)
        XCTAssertTrue(app.staticTexts["No Account No Cloud"].exists)
        XCTAssertTrue(app.staticTexts["CatLocal looks for cats here."].exists)
        XCTAssertTrue(app.staticTexts["Saved images are GPS-free."].exists)
        XCTAssertTrue(app.staticTexts["Cards save to this iPhone."].exists)
        XCTAssertLessThan(
            app.descendants(matching: .any)["onboarding-privacy-pill"].frame.maxY,
            privacyTitle.frame.minY
        )
        XCTAssertLessThan(
            privacyTitle.frame.maxY,
            onDeviceVision.frame.minY
        )
        XCTAssertLessThanOrEqual(app.staticTexts["No Account No Cloud"].frame.maxY, onboardingPrimaryAction.frame.minY)
        XCTAssertTrue(app.buttons["onboarding-skip-home"].exists)
        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingPrimaryAction.label, "Continue")
        tapWhenHittable(onboardingPrimaryAction)

        XCTAssertTrue(app.staticTexts["Ready for Your First Local"].waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingProgress.label, "Onboarding step 3 of 3")
        XCTAssertLessThanOrEqual(
            onboardingProgress.frame.maxY,
            app.staticTexts["Ready for Your First Local"].frame.minY
        )
        XCTAssertTrue(app.staticTexts["Home opens next. Tap Camera when you meet a cat, or choose a private photo."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-first-card-anatomy"].exists)
        XCTAssertTrue(app.staticTexts["Your first card keeps the lifted cutout, design, notes, and typed place together."].exists)
        XCTAssertTrue(app.staticTexts["Lifted cutout"].exists)
        XCTAssertTrue(app.staticTexts["Card details"].exists)
        XCTAssertLessThan(
            app.staticTexts["Saved to Home"].frame.maxY,
            app.staticTexts["Ready for Your First Local"].frame.minY
        )
        XCTAssertLessThan(
            app.staticTexts["Ready for Your First Local"].frame.maxY,
            app.staticTexts["Your first card keeps the lifted cutout, design, notes, and typed place together."].frame.minY
        )
        XCTAssertLessThanOrEqual(app.staticTexts["Card details"].frame.maxY, onboardingPrimaryAction.frame.minY)

        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingPrimaryAction.label, "Open Home")
        XCTAssertFalse(app.buttons["onboarding-skip-home"].exists)
        tapWhenHittable(onboardingPrimaryAction)

        XCTAssertTrue(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Camera"].exists)
        XCTAssertFalse(app.buttons["Open Home"].exists)
    }

    func testOnboardingKeepsThreeStepCompletion() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-show-onboarding"]
        app.launch()

        let onboardingPrimaryAction = app.buttons["onboarding-primary-action"]
        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["onboarding-skip-home"].exists)
        XCTAssertFalse(app.buttons["Open Home"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-privacy-title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["Open Home"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.buttons["Open Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready for Your First Local"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Camera"].exists)
    }

    func testOnboardingCanSkipFromWelcomeToHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-show-onboarding"]
        app.launch()

        let skipButton = app.buttons["onboarding-skip-home"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 8))
        XCTAssertEqual(skipButton.label, "Skip to Home")
        tapWhenHittable(skipButton)

        XCTAssertTrue(app.staticTexts["Meet Your First Local"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Camera"].exists)
        XCTAssertFalse(app.buttons["onboarding-primary-action"].exists)
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
        selectTab(settingsButton)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))

        XCTAssertTrue(app.descendants(matching: .any)["settings-appearance-picker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings-card-motion-toggle"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings-haptics-toggle"].exists)
        XCTAssertFalse(app.staticTexts["Home View"].exists)
        XCTAssertFalse(app.staticTexts["Sort Order"].exists)

        let storageSummary = app.descendants(matching: .any)["settings-storage-summary"]
        if !storageSummary.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(storageSummary.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Local Storage"].exists)
        XCTAssertFalse(app.staticTexts["CatLocal Data"].exists)
        XCTAssertTrue(app.staticTexts["No cats saved yet"].exists)
        XCTAssertTrue(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", "Zero KB"))
                .firstMatch
                .exists
        )

        let privacyReceipt = app.descendants(matching: .any)["settings-privacy-receipt"]
        if !privacyReceipt.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(privacyReceipt.waitForExistence(timeout: 5))
        tapWhenHittable(privacyReceipt)

        XCTAssertTrue(app.navigationBars["Privacy Receipt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Photos"].exists)
        XCTAssertTrue(app.staticTexts["Recognition"].exists)
        XCTAssertTrue(app.staticTexts["Location"].exists)
        XCTAssertTrue(app.staticTexts["Network"].exists)
        XCTAssertTrue(app.staticTexts["The collection requires no account, upload, cloud AI, or model-training use."].exists)
        let metadataReceipt = app.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                "Before storage, CatLocal redraws the selected photo and re-encodes it without source EXIF, GPS, camera/device, or orientation metadata."
            )
        ).firstMatch
        XCTAssertTrue(metadataReceipt.exists)

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
        selectTab(settingsButton)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))

        let deleteAllButton = app.descendants(matching: .any)["settings-delete-all-cats"]
        if !deleteAllButton.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Delete All Cats"].exists)
        XCTAssertLessThan(deleteAllButton.frame.width, app.windows.firstMatch.frame.width * 0.7)
        XCTAssertEqual(deleteAllButton.frame.midX, app.windows.firstMatch.frame.midX, accuracy: 4)
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
        selectTab(atlasButton)

        XCTAssertTrue(app.staticTexts["2 places typed by you."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Ferry Steps, 1 cat"].exists)
        XCTAssertTrue(app.buttons["Garden Wall, 1 cat"].exists)

        let misoRow = app.descendants(matching: .any)["catlas-cat-row-Miso"]
        XCTAssertTrue(misoRow.exists)
        XCTAssertGreaterThanOrEqual(misoRow.frame.height, 64)

        let simitRow = app.descendants(matching: .any)["catlas-cat-row-Simit"]
        XCTAssertTrue(simitRow.exists)
        XCTAssertGreaterThanOrEqual(simitRow.frame.height, 64)

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
        tapToNavigate(unplacedCard, destination: app.buttons["Edit"])
    }

    func testValidationMultipleCatSelectionMapsNumbersAndHidesConfidence() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-multiple-cat-selection"
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

        XCTAssertTrue(app.staticTexts["Which cat gets the card?"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Match a number in the photo, then choose that cat."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Photo with 2 cats marked by number"].exists)
        XCTAssertTrue(app.buttons["Cat 1, Marked 1 in the photo"].exists)
        XCTAssertTrue(app.buttons["Cat 2, Marked 2 in the photo"].exists)
        XCTAssertFalse(app.staticTexts["98%"].exists)
        XCTAssertFalse(app.staticTexts["87%"].exists)
    }

    func testValidationLiftKeepsFocusOnPhotoWithoutStopAction() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-hold-processing"
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

        XCTAssertTrue(app.descendants(matching: .any)["lifting-status"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Stop and return"].exists)
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
        XCTAssertTrue(app.descendants(matching: .any)["draft-card-inspection"].exists)
        let customizeButton = app.buttons["tap-to-customize"]
        XCTAssertTrue(customizeButton.exists)
        tapWhenHittable(customizeButton)

        XCTAssertTrue(app.staticTexts["Make It Yours"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose a card design now, or save first and edit later."].exists)
        let recommendedHeading = app.staticTexts["Recommended"]
        if !recommendedHeading.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(recommendedHeading.waitForExistence(timeout: 5))
        for identifier in [
            "recommended-card-style-archive",
            "recommended-card-style-topoLagoon"
        ] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(button.frame.height, 124)
        }

        app.swipeUp()

        for identifier in [
            "recommended-card-style-fernTrace",
            "recommended-card-style-cobaltHalo"
        ] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(button.frame.height, 124)
        }

        let contourFamilyButton = app.buttons["card-style-family-contour"]
        if !contourFamilyButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(contourFamilyButton.exists)
        XCTAssertTrue(app.buttons["card-style-family-archive"].exists)
        XCTAssertTrue(app.buttons["card-style-family-botanical"].exists)
        XCTAssertTrue(app.buttons["card-style-family-light"].exists)
        contourFamilyButton.tap()
        XCTAssertTrue(app.staticTexts["5 styles"].waitForExistence(timeout: 5))

        let nicknameField = app.textFields["Nickname"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nicknameField.value as? String, "Pixel")
        XCTAssertTrue(app.textFields["Memory Place"].exists)

        let placeDetailField = app.descendants(matching: .any)["Place Detail"]
        if !placeDetailField.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(placeDetailField.waitForExistence(timeout: 5))

        let noteHeading = app.staticTexts["Encounter Note"]
        if !noteHeading.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(noteHeading.waitForExistence(timeout: 5))
    }

    func testValidationImportShowsCutoutRevealBeforeEditor() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-synthetic-cutout",
            "-catlocal-ui-reduce-motion-reveal"
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

        let draftInspection = app.descendants(matching: .any)["draft-card-inspection"]
        XCTAssertTrue(draftInspection.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["save-cat-immediate"].exists)
        XCTAssertTrue(app.buttons["tap-to-customize"].exists)
    }

    func testValidationImportMetalDustRevealCompletesBeforeEditor() {
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

        let transition = app.descendants(matching: .any)["subject-card-transition-active"]
        XCTAssertTrue(transition.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["save-cat-immediate"].exists)
        XCTAssertFalse(app.buttons["tap-to-customize"].exists)

        let draftInspection = app.descendants(matching: .any)["draft-card-inspection"]
        XCTAssertTrue(draftInspection.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["save-cat-immediate"].exists)
        XCTAssertTrue(app.buttons["tap-to-customize"].exists)
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

    func testValidationImportLetsTheUserTapTheCatWhenDetectionMisses() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-force-foreground-fallback",
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

        XCTAssertTrue(app.staticTexts["Tap the cat"].waitForExistence(timeout: 8))
        let selectionPhoto = app.descendants(matching: .any)["foreground-selection-photo"]
        XCTAssertTrue(selectionPhoto.exists)
        XCTAssertTrue(app.buttons["Retake"].exists)
        XCTAssertTrue(app.buttons["Choose Private Photo"].exists)
        XCTAssertFalse(app.buttons["Use Foreground Cutout"].exists)

        let photoFrame = selectionPhoto.frame
        XCTAssertGreaterThan(photoFrame.height, photoFrame.width)
        selectionPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).tap()

        let retryGuidance = app.descendants(matching: .any)["foreground-selection-guidance"]
        XCTAssertTrue(retryGuidance.waitForExistence(timeout: 5))
        XCTAssertTrue(selectionPhoto.exists)

        let fittedSide = min(photoFrame.width, photoFrame.height)
        let fittedOriginX = (photoFrame.width - fittedSide) / 2
        let fittedOriginY = (photoFrame.height - fittedSide) / 2
        let backgroundOffset = CGVector(
            dx: (fittedOriginX + fittedSide * 0.05) / photoFrame.width,
            dy: (fittedOriginY + fittedSide * 0.05) / photoFrame.height
        )
        selectionPhoto.coordinate(withNormalizedOffset: backgroundOffset).tap()

        XCTAssertTrue(selectionPhoto.waitForExistence(timeout: 5))
        XCTAssertTrue(retryGuidance.exists)

        selectionPhoto.tap()
        XCTAssertTrue(app.buttons["save-cat-immediate"].waitForExistence(timeout: 10))
    }
}
