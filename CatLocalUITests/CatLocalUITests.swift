import XCTest
import UIKit

@MainActor
final class CatLocalUITests: XCTestCase {
    private struct LocalizationGalleryLocale {
        let languageCode: String
        let appleLocale: String
        let welcomeTitle: String
        let backTitle: String
        let readyTitle: String
        let firstCatTitle: String
        let settingsTitle: String
        let cameraTitle: String

        static let english = LocalizationGalleryLocale(
            languageCode: "en",
            appleLocale: "en_US",
            welcomeTitle: "Welcome to CatLocal",
            backTitle: "Back",
            readyTitle: "Ready for Your First Cat",
            firstCatTitle: "Meet Your First Cat",
            settingsTitle: "Settings",
            cameraTitle: "Camera"
        )

        static let turkish = LocalizationGalleryLocale(
            languageCode: "tr",
            appleLocale: "tr_TR",
            welcomeTitle: "CatLocal'a Hoş Geldiniz",
            backTitle: "Geri",
            readyTitle: "İlk kediniz için her şey hazır",
            firstCatTitle: "İlk kedinizle tanışın",
            settingsTitle: "Ayarlar",
            cameraTitle: "Kamera"
        )

    }

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

    private func localizedLaunchArguments(
        for locale: LocalizationGalleryLocale,
        appArguments: [String]
    ) -> [String] {
        appArguments + [
            "-AppleLanguages", "(\(locale.languageCode))",
            "-AppleLocale", locale.appleLocale
        ]
    }

    private func keepScreenshot(
        of app: XCUIApplication,
        named name: String
    ) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertNoRawFormatTokens(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rawFormatPattern = #".*%([0-9]+\$)?(lld|ld|d|@).*"#
        let descendants = app.descendants(matching: .any)
        let rawLabel = descendants.matching(
            NSPredicate(format: "label MATCHES %@", rawFormatPattern)
        ).firstMatch
        let rawValue = descendants.matching(
            NSPredicate(format: "value MATCHES %@", rawFormatPattern)
        ).firstMatch

        XCTAssertFalse(rawLabel.exists, "Raw format token rendered in an accessibility label", file: file, line: line)
        XCTAssertFalse(rawValue.exists, "Raw format token rendered in an accessibility value", file: file, line: line)
    }

    private func verifyLocalizationGallery(
        _ locale: LocalizationGalleryLocale,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let onboardingApp = XCUIApplication()
        onboardingApp.launchArguments = localizedLaunchArguments(
            for: locale,
            appArguments: ["-ui-testing-reset", "-ui-testing-show-onboarding"]
        )
        onboardingApp.launch()

        let primaryAction = onboardingApp.buttons["onboarding-primary-action"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(
            onboardingApp.staticTexts[locale.welcomeTitle].waitForExistence(timeout: 5),
            file: file,
            line: line
        )
        assertNoRawFormatTokens(in: onboardingApp, file: file, line: line)
        keepScreenshot(of: onboardingApp, named: "\(locale.languageCode)-01-onboarding-welcome")

        let privacyTitle = onboardingApp.descendants(matching: .any)["onboarding-privacy-title"]
        tapToNavigate(
            primaryAction,
            destination: privacyTitle,
            file: file,
            line: line
        )
        XCTAssertTrue(onboardingApp.buttons[locale.backTitle].exists, file: file, line: line)
        assertNoRawFormatTokens(in: onboardingApp, file: file, line: line)
        keepScreenshot(of: onboardingApp, named: "\(locale.languageCode)-02-onboarding-privacy")

        tapToNavigate(
            primaryAction,
            destination: onboardingApp.staticTexts[locale.readyTitle],
            file: file,
            line: line
        )
        assertNoRawFormatTokens(in: onboardingApp, file: file, line: line)
        keepScreenshot(of: onboardingApp, named: "\(locale.languageCode)-03-onboarding-first-card")

        tapToNavigate(
            primaryAction,
            destination: onboardingApp.descendants(matching: .any)["collection-screen"],
            file: file,
            line: line
        )
        XCTAssertTrue(
            onboardingApp.staticTexts[locale.firstCatTitle].waitForExistence(timeout: 8),
            file: file,
            line: line
        )
        onboardingApp.terminate()

        let collectionApp = XCUIApplication()
        collectionApp.launchArguments = localizedLaunchArguments(
            for: locale,
            appArguments: ["-ui-testing-reset", "-ui-testing-seed-atlas"]
        )
        collectionApp.launch()

        XCTAssertTrue(
            collectionApp.descendants(matching: .any)["collection-screen"]
                .waitForExistence(timeout: 8),
            file: file,
            line: line
        )
        XCTAssertTrue(
            collectionApp.descendants(matching: .any)["collection-mode-picker"]
                .waitForExistence(timeout: 5),
            file: file,
            line: line
        )
        assertNoRawFormatTokens(in: collectionApp, file: file, line: line)
        keepScreenshot(of: collectionApp, named: "\(locale.languageCode)-04-cards")

        tapWhenHittable(collectionApp.buttons["Catlas"], file: file, line: line)
        XCTAssertTrue(
            collectionApp.descendants(matching: .any)["catlas-cat-row-Miso"]
                .waitForExistence(timeout: 5),
            file: file,
            line: line
        )
        assertNoRawFormatTokens(in: collectionApp, file: file, line: line)
        keepScreenshot(of: collectionApp, named: "\(locale.languageCode)-05-catlas")
        collectionApp.terminate()

        let settingsApp = XCUIApplication()
        settingsApp.launchArguments = localizedLaunchArguments(
            for: locale,
            appArguments: ["-ui-testing-reset", "-ui-testing-open-settings"]
        )
        settingsApp.launch()

        XCTAssertTrue(
            settingsApp.descendants(matching: .any)["settings-screen"]
                .waitForExistence(timeout: 8),
            file: file,
            line: line
        )
        XCTAssertTrue(
            settingsApp.navigationBars[locale.settingsTitle].waitForExistence(timeout: 5),
            file: file,
            line: line
        )
        assertNoRawFormatTokens(in: settingsApp, file: file, line: line)
        keepScreenshot(of: settingsApp, named: "\(locale.languageCode)-06-settings")
        settingsApp.terminate()
    }

    private var localizedRuntimeLaneArguments: [String] {
        if UIScreen.main.bounds.width <= 390 {
            return [
                "-catlocal.appearance", "dark",
                "-UIPreferredContentSizeCategoryName",
                UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue
            ]
        }
        return ["-catlocal.appearance", "light"]
    }

    private func localizedRuntimeApp(
        _ locale: LocalizationGalleryLocale,
        arguments: [String]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
            + [
                "-AppleLanguages", "(\(locale.languageCode))",
                "-AppleLocale", locale.appleLocale
            ]
            + localizedRuntimeLaneArguments
        return app
    }

    private func openCapture(
        in app: XCUIApplication,
        locale: LocalizationGalleryLocale,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identifiedTab = app.tabBars.buttons["capture-tab"]
        let captureTab = identifiedTab.waitForExistence(timeout: 2)
            ? identifiedTab
            : app.tabBars.buttons[locale.cameraTitle]
        tapWhenHittable(captureTab, file: file, line: line)

        let captureScreen = app.descendants(matching: .any)["capture-screen"]
        let validationPhoto = app.buttons["capture-validation-photo"]
        let permissionDenied = app.descendants(matching: .any)["camera-permission-denied-state"]
        if !captureScreen.waitForExistence(timeout: 3)
            && !validationPhoto.exists
            && !permissionDenied.exists {
            captureTab.tap()
        }
        XCTAssertTrue(
            captureScreen.waitForExistence(timeout: 8)
                || validationPhoto.exists
                || permissionDenied.exists,
            file: file,
            line: line
        )
    }

    private func swipeUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        for _ in 0..<attempts where !element.isHittable {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func scrollTowardBottom(_ scrollView: XCUIElement) {
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func hittableButton(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let matches = app.buttons.matching(identifier: identifier)
        for index in 0..<matches.count {
            let candidate = matches.element(boundBy: index)
            if candidate.isHittable {
                return candidate
            }
        }
        return matches.firstMatch
    }

    private func verifyLocalizedRuntimeFlows(
        _ locale: LocalizationGalleryLocale,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTContext.runActivity(named: "Photo import, detection, and multiple cats") { _ in
            let app = localizedRuntimeApp(
                locale,
                arguments: [
                    "-ui-testing-reset",
                    "-catlocal-ui-import-fixture",
                    "-catlocal-ui-synthetic-photo",
                    "-catlocal-ui-multiple-cat-selection"
                ]
            )
            app.launch()
            openCapture(in: app, locale: locale, file: file, line: line)
            tapWhenHittable(app.buttons["capture-validation-photo"], file: file, line: line)
            for number in ["1", "2"] {
                let option = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS %@", number)
                ).firstMatch
                XCTAssertTrue(option.waitForExistence(timeout: 10), file: file, line: line)
                XCTAssertFalse(option.label.isEmpty, file: file, line: line)
            }
            assertNoRawFormatTokens(in: app, file: file, line: line)
            app.terminate()
        }

        XCTContext.runActivity(named: "Cutout progress and recovery") { _ in
            let app = localizedRuntimeApp(
                locale,
                arguments: [
                    "-ui-testing-reset",
                    "-catlocal-ui-import-fixture",
                    "-catlocal-ui-synthetic-photo",
                    "-catlocal-ui-hold-processing"
                ]
            )
            app.launch()
            openCapture(in: app, locale: locale, file: file, line: line)
            tapWhenHittable(app.buttons["capture-validation-photo"], file: file, line: line)
            let stop = app.buttons["capture-stop-processing"]
            XCTAssertTrue(stop.waitForExistence(timeout: 20), file: file, line: line)
            tapWhenHittable(stop, file: file, line: line)
            XCTAssertTrue(
                app.buttons["capture-validation-photo"].waitForExistence(timeout: 8),
                file: file,
                line: line
            )
            assertNoRawFormatTokens(in: app, file: file, line: line)
            app.terminate()
        }

        XCTContext.runActivity(named: "Edit and save long card content") { _ in
            let app = localizedRuntimeApp(
                locale,
                arguments: [
                    "-ui-testing-reset",
                    "-catlocal-ui-import-fixture",
                    "-catlocal-ui-synthetic-photo",
                    "-catlocal-ui-synthetic-cutout",
                    "-catlocal-ui-skip-sticker-reveal",
                    "-ui-testing-seed-long-content"
                ]
            )
            app.launch()
            openCapture(in: app, locale: locale, file: file, line: line)
            tapWhenHittable(app.buttons["capture-validation-photo"], file: file, line: line)
            let customize = app.buttons["tap-to-customize"]
            XCTAssertTrue(customize.waitForExistence(timeout: 15), file: file, line: line)
            swipeUntilHittable(customize, in: app, file: file, line: line)
            tapWhenHittable(customize, file: file, line: line)

            let nickname = app.textFields["capture-editor-nickname"]
            if !nickname.waitForExistence(timeout: 3) {
                app.swipeUp()
            }
            XCTAssertTrue(nickname.waitForExistence(timeout: 5), file: file, line: line)
            XCTAssertEqual(
                nickname.value as? String,
                "Captain Marmalade of the Bosphorus",
                file: file,
                line: line
            )
            assertNoRawFormatTokens(in: app, file: file, line: line)
            keepScreenshot(of: app, named: "\(locale.languageCode)-07-long-card-editor")

            let save = app.buttons["capture-editor-save"]
            let editorScroll = app.scrollViews["capture-editor-scroll"]
            XCTAssertTrue(editorScroll.waitForExistence(timeout: 5), file: file, line: line)
            for _ in 0..<20 where !save.isHittable {
                scrollTowardBottom(editorScroll)
            }
            XCTAssertTrue(save.isHittable, file: file, line: line)
            tapWhenHittable(save, file: file, line: line)
            let home = app.buttons["card-minting-home"]
            XCTAssertTrue(home.waitForExistence(timeout: 15), file: file, line: line)
            tapWhenHittable(home, file: file, line: line)
            XCTAssertTrue(
                app.descendants(matching: .any)["collection-screen"].waitForExistence(timeout: 8),
                file: file,
                line: line
            )
            XCTAssertTrue(
                app.staticTexts["Captain Marmalade of the Bosphorus"].exists,
                file: file,
                line: line
            )
            app.terminate()
        }

        XCTContext.runActivity(named: "Delete one and multiple cards") { _ in
            let app = localizedRuntimeApp(
                locale,
                arguments: ["-ui-testing-reset", "-ui-testing-seed-atlas"]
            )
            app.launch()

            let firstCard = app.buttons["collection-card-1"]
            XCTAssertTrue(firstCard.waitForExistence(timeout: 8), file: file, line: line)
            tapWhenHittable(firstCard, file: file, line: line)
            tapWhenHittable(app.buttons["focused-card-edit"], file: file, line: line)

            let deleteCat = app.buttons["cat-edit-delete"]
            let editForm = app.descendants(matching: .any)["cat-edit-form"]
            XCTAssertTrue(editForm.waitForExistence(timeout: 5), file: file, line: line)
            for _ in 0..<20 where !deleteCat.isHittable {
                scrollTowardBottom(editForm)
            }
            XCTAssertTrue(deleteCat.isHittable, file: file, line: line)
            tapWhenHittable(deleteCat, file: file, line: line)
            keepScreenshot(of: app, named: "\(locale.languageCode)-08-delete-confirmation")
            XCTAssertTrue(
                app.buttons["deletion-confirm"].waitForExistence(timeout: 5),
                file: file,
                line: line
            )
            assertNoRawFormatTokens(in: app, file: file, line: line)
            app.terminate()

            let selectionApp = localizedRuntimeApp(
                locale,
                arguments: ["-ui-testing-reset", "-ui-testing-seed-atlas"]
            )
            selectionApp.launch()
            let selectionToggle = selectionApp.buttons["collection-selection-toggle"]
            XCTAssertTrue(selectionToggle.waitForExistence(timeout: 8), file: file, line: line)
            tapWhenHittable(selectionToggle, file: file, line: line)
            for identifier in ["collection-card-1", "collection-card-2"] {
                let card = hittableButton(identifier, in: selectionApp)
                XCTAssertTrue(card.waitForExistence(timeout: 5), file: file, line: line)
                tapWhenHittable(card, file: file, line: line)
            }
            let selectionStatus = selectionApp.staticTexts["collection-selection-status"]
            XCTAssertTrue(
                selectionStatus.waitForExistence(timeout: 5)
                    && selectionStatus.label.contains("2"),
                file: file,
                line: line
            )
            let deleteSelected = selectionApp.buttons["collection-delete-selected"]
            swipeUntilHittable(deleteSelected, in: selectionApp, file: file, line: line)
            tapWhenHittable(deleteSelected, file: file, line: line)
            XCTAssertTrue(
                selectionApp.buttons["deletion-confirm"].waitForExistence(timeout: 5),
                file: file,
                line: line
            )
            assertNoRawFormatTokens(in: selectionApp, file: file, line: line)
            selectionApp.terminate()
        }

        XCTContext.runActivity(named: "Settings, privacy, storage, and delete all") { _ in
            let app = localizedRuntimeApp(
                locale,
                arguments: ["-ui-testing-reset", "-ui-testing-seed-atlas", "-ui-testing-open-settings"]
            )
            app.launch()

            let privacy = app.descendants(matching: .any)["settings-privacy-receipt"]
            let settingsList = app.descendants(matching: .any)["settings-list"]
            XCTAssertTrue(settingsList.waitForExistence(timeout: 5), file: file, line: line)
            for _ in 0..<20 where !privacy.isHittable {
                scrollTowardBottom(settingsList)
            }
            XCTAssertTrue(privacy.isHittable, file: file, line: line)
            tapWhenHittable(privacy, file: file, line: line)
            XCTAssertTrue(
                app.descendants(matching: .any)["privacy-receipt-screen"]
                    .waitForExistence(timeout: 5),
                file: file,
                line: line
            )
            assertNoRawFormatTokens(in: app, file: file, line: line)
            app.terminate()

            let deleteApp = localizedRuntimeApp(
                locale,
                arguments: ["-ui-testing-reset", "-ui-testing-seed-atlas", "-ui-testing-open-settings"]
            )
            deleteApp.launch()
            let deleteAll = deleteApp.buttons["settings-delete-all-cats"]
            let deleteSettingsList = deleteApp.descendants(matching: .any)["settings-list"]
            XCTAssertTrue(deleteSettingsList.waitForExistence(timeout: 5), file: file, line: line)
            for _ in 0..<20 where !deleteAll.isHittable {
                scrollTowardBottom(deleteSettingsList)
            }
            XCTAssertTrue(deleteAll.isHittable, file: file, line: line)
            tapWhenHittable(deleteAll, file: file, line: line)
            XCTAssertTrue(
                deleteApp.buttons["deletion-confirm"].waitForExistence(timeout: 5),
                file: file,
                line: line
            )
            assertNoRawFormatTokens(in: deleteApp, file: file, line: line)
            deleteApp.terminate()
        }
    }

    private func verifyLocalizedCameraDenied(
        _ locale: LocalizationGalleryLocale,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let app = localizedRuntimeApp(
            locale,
            arguments: ["-ui-testing-reset", "-catlocal-ui-force-camera-denied"]
        )
        app.launch()
        openCapture(in: app, locale: locale, file: file, line: line)
        XCTAssertTrue(
            app.descendants(matching: .any)["camera-permission-denied-state"]
                .waitForExistence(timeout: 5),
            file: file,
            line: line
        )
        assertNoRawFormatTokens(in: app, file: file, line: line)
    }

    func testLocalizationGalleryEnglish() {
        verifyLocalizationGallery(.english)
    }

    func testLocalizationGalleryTurkish() {
        verifyLocalizationGallery(.turkish)
    }

    func testLocalizationFinalCleanupTurkish() {
        let turkishApp = localizedRuntimeApp(
            .turkish,
            arguments: ["-ui-testing-reset", "-ui-testing-open-settings"]
        )
        turkishApp.launch()

        let turkishSettings = turkishApp.descendants(matching: .any)["settings-screen"]
        XCTAssertTrue(turkishSettings.waitForExistence(timeout: 8))

        let settingsList = turkishApp.descendants(matching: .any)["settings-list"]
        XCTAssertTrue(settingsList.waitForExistence(timeout: 5))

        let cardMotion = turkishApp.descendants(matching: .any)["settings-card-motion-toggle"]
        for _ in 0..<10 where !cardMotion.exists {
            scrollTowardBottom(settingsList)
        }
        XCTAssertTrue(cardMotion.waitForExistence(timeout: 5))
        XCTAssertTrue(cardMotion.label.contains("Kart Hareketi"))
        XCTAssertFalse(cardMotion.label.contains("Kart hareketi"))

        let haptics = turkishApp.descendants(matching: .any)["settings-haptics-toggle"]
        for _ in 0..<10 where !haptics.exists {
            scrollTowardBottom(settingsList)
        }
        XCTAssertTrue(haptics.waitForExistence(timeout: 5))
        XCTAssertTrue(haptics.label.contains("Dokunsal Geri Bildirim"))
        XCTAssertFalse(haptics.label.contains("Dokunsal geri bildirim"))

        let localStorage = turkishApp.staticTexts["Yerel Depolama"]
        for _ in 0..<10 where !localStorage.exists {
            scrollTowardBottom(settingsList)
        }
        XCTAssertTrue(localStorage.waitForExistence(timeout: 5))

        let privacy = turkishApp.buttons["settings-privacy-receipt"]
        for _ in 0..<10 where !privacy.exists {
            scrollTowardBottom(settingsList)
        }
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        XCTAssertTrue(privacy.label.hasPrefix("Gizlilik Özeti"))

        let about = turkishApp.buttons["settings-about-catlocal"]
        for _ in 0..<20 where !about.isHittable {
            scrollTowardBottom(settingsList)
        }
        tapWhenHittable(about)
        XCTAssertTrue(turkishApp.navigationBars["CatLocal Hakkında"].waitForExistence(timeout: 5))
        let builtWithoutBody = turkishApp.staticTexts
            .matching(NSPredicate(
                format: "label BEGINSWITH %@",
                "Hesap, herkese açık harita"
            ))
            .firstMatch
        for _ in 0..<10 where !builtWithoutBody.exists {
            turkishApp.swipeUp()
        }
        XCTAssertTrue(builtWithoutBody.waitForExistence(timeout: 5))
        assertNoRawFormatTokens(in: turkishApp)
        turkishApp.terminate()
    }

    func testLocalizationRuntimeFlowsEnglish() {
        verifyLocalizedRuntimeFlows(.english)
    }

    func testLocalizationRuntimeFlowsTurkish() {
        verifyLocalizedRuntimeFlows(.turkish)
    }

    func testLocalizationCameraDeniedEnglish() {
        verifyLocalizedCameraDenied(.english)
    }

    func testLocalizationCameraDeniedTurkish() {
        verifyLocalizedCameraDenied(.turkish)
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
        XCTAssertTrue(app.staticTexts["On-device cutout"].exists)
        XCTAssertTrue(app.staticTexts["Make It Yours"].exists)
        XCTAssertTrue(app.staticTexts["Take a photo or choose one"].exists)
        XCTAssertTrue(app.staticTexts["Finds the cat and removes the background"].exists)
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
        XCTAssertTrue(app.staticTexts["No Account. No Cloud."].exists)
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
        XCTAssertLessThanOrEqual(app.staticTexts["No Account. No Cloud."].frame.maxY, onboardingPrimaryAction.frame.minY)
        XCTAssertTrue(app.buttons["onboarding-skip-home"].exists)
        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingPrimaryAction.label, "Continue")
        tapWhenHittable(onboardingPrimaryAction)

        XCTAssertTrue(app.staticTexts["Ready for Your First Cat"].waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingProgress.label, "Onboarding step 3 of 3")
        XCTAssertLessThanOrEqual(
            onboardingProgress.frame.maxY,
            app.staticTexts["Ready for Your First Cat"].frame.minY
        )
        XCTAssertTrue(app.staticTexts["Home opens next. Tap Camera when you meet a cat, or choose a private photo."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-first-card-anatomy"].exists)
        XCTAssertTrue(app.staticTexts["Your first card keeps the cat cutout, design, notes, and typed place together."].exists)
        XCTAssertTrue(app.staticTexts["Cat cutout"].exists)
        XCTAssertTrue(app.staticTexts["Card details"].exists)
        XCTAssertLessThan(
            app.staticTexts["Saved to Collection"].frame.maxY,
            app.staticTexts["Ready for Your First Cat"].frame.minY
        )
        XCTAssertLessThan(
            app.staticTexts["Ready for Your First Cat"].frame.maxY,
            app.staticTexts["Your first card keeps the cat cutout, design, notes, and typed place together."].frame.minY
        )
        XCTAssertLessThanOrEqual(app.staticTexts["Card details"].frame.maxY, onboardingPrimaryAction.frame.minY)

        XCTAssertTrue(onboardingPrimaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(onboardingPrimaryAction.label, "Open Home")
        XCTAssertFalse(app.buttons["onboarding-skip-home"].exists)
        tapWhenHittable(onboardingPrimaryAction)

        XCTAssertTrue(app.staticTexts["Meet Your First Cat"].waitForExistence(timeout: 8))
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
        XCTAssertFalse(app.staticTexts["Meet Your First Cat"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["Open Home"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.buttons["Open Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready for Your First Cat"].exists)

        tapWhenHittable(onboardingPrimaryAction)
        XCTAssertTrue(app.staticTexts["Meet Your First Cat"].waitForExistence(timeout: 8))
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

        XCTAssertTrue(app.staticTexts["Meet Your First Cat"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Camera"].exists)
        XCTAssertFalse(app.buttons["onboarding-primary-action"].exists)
    }

    func testPreIOS26CameraTabIsCenteredAndAccessible() throws {
        if #available(iOS 26.0, *) {
            throw XCTSkip("iOS 26 uses the system's detached camera tab treatment.")
        }

        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-UIPreferredContentSizeCategoryName",
            UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue
        ]
        app.launch()

        let homeButton = app.tabBars.buttons["Home"]
        let cameraButton = app.tabBars.buttons["Camera"]
        let settingsButton = app.tabBars.buttons["Settings"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 8))
        XCTAssertTrue(cameraButton.exists)
        XCTAssertTrue(settingsButton.exists)

        XCTAssertLessThan(homeButton.frame.midX, cameraButton.frame.midX)
        XCTAssertLessThan(cameraButton.frame.midX, settingsButton.frame.midX)
        XCTAssertEqual(cameraButton.frame.midX, app.windows.firstMatch.frame.midX, accuracy: 4)

        for tab in [homeButton, cameraButton, settingsButton] {
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44)
        }
    }

    func testCaptureDismissalRestoresSettingsTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-open-settings"]
        app.launch()

        let settingsButton = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 8))
        XCTAssertTrue(settingsButton.isSelected)

        tapWhenHittable(app.tabBars.buttons["Camera"])
        let closeButton = app.buttons["Close camera"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 8))
        tapWhenHittable(closeButton)

        XCTAssertTrue(settingsButton.waitForExistence(timeout: 8))
        XCTAssertTrue(settingsButton.isSelected)
    }

    func testEmptyHomeCaptureEntryAndSettingsReceipt() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Meet Your First Cat"].exists)
        XCTAssertTrue(app.staticTexts["Capture an encounter and turn it into a collectible card."].exists)

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
        XCTAssertTrue(app.staticTexts["0 cats saved locally"].exists)
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
        if !privacyReceipt.isHittable {
            app.swipeUp()
        }
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

    func testSettingsTurkishEnglishFallbackSwitchesImmediatelyAndPersists() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-ui-testing-open-settings",
            "-AppleLanguages", "(tr)",
            "-AppleLocale", "tr_TR",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Ayarlar"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["settings-language-picker"].exists)

        let languageFallback = app.buttons["settings-language-fallback"]
        XCTAssertTrue(languageFallback.waitForExistence(timeout: 5))
        XCTAssertTrue(languageFallback.label.contains("İngilizce Kullan"))
        tapWhenHittable(languageFallback)

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Camera"].exists)
        XCTAssertTrue(languageFallback.label.contains("Use System Language"))

        app.terminate()
        app.launchArguments = [
            "-ui-testing-open-settings",
            "-AppleLanguages", "(tr)",
            "-AppleLocale", "tr_TR",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(languageFallback.waitForExistence(timeout: 5))
        XCTAssertTrue(languageFallback.label.contains("Use System Language"))
        tapWhenHittable(languageFallback)

        XCTAssertTrue(app.navigationBars["Ayarlar"].waitForExistence(timeout: 5))
        XCTAssertTrue(languageFallback.label.contains("İngilizce Kullan"))
    }

    func testSettingsUnsupportedUkrainianFallsBackToEnglishWithoutLanguageControl() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-ui-testing-open-settings",
            "-AppleLanguages", "(uk)",
            "-AppleLocale", "uk_UA",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["settings-language-picker"].exists)
        XCTAssertFalse(app.buttons["settings-language-fallback"].exists)
    }

    func testSettingsUnsupportedBulgarianFallsBackToEnglishWithoutLanguageControl() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-ui-testing-open-settings",
            "-AppleLanguages", "(bg)",
            "-AppleLocale", "bg_BG",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["settings-language-picker"].exists)
        XCTAssertFalse(app.buttons["settings-language-fallback"].exists)
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

    func testCameraExposesAccessibleZoomControl() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        let cameraButton = app.tabBars.buttons["Camera"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
        cameraButton.tap()

        let captureScreen = app.descendants(matching: .any)["capture-screen"]
        if !captureScreen.waitForExistence(timeout: 3) {
            cameraButton.tap()
        }
        XCTAssertTrue(captureScreen.waitForExistence(timeout: 5))

        let zoomControl = app.buttons["Camera zoom"]
        XCTAssertTrue(zoomControl.waitForExistence(timeout: 5))
        XCTAssertEqual(zoomControl.value as? String, "1×")
    }

    func testCameraPrivacyBadgeReflowsAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-UIPreferredContentSizeCategoryName",
            UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["CatLocal"].waitForExistence(timeout: 8))
        let cameraButton = app.tabBars.buttons["Camera"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
        cameraButton.tap()

        let captureScreen = app.descendants(matching: .any)["capture-screen"]
        if !captureScreen.waitForExistence(timeout: 3) {
            cameraButton.tap()
        }
        XCTAssertTrue(captureScreen.waitForExistence(timeout: 5))

        let privacyBadge = app.descendants(matching: .any)["Private scan on this iPhone"]
        let closeButton = app.buttons["Close camera"]
        XCTAssertTrue(privacyBadge.waitForExistence(timeout: 5))
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        XCTAssertFalse(privacyBadge.frame.intersects(closeButton.frame))
        XCTAssertGreaterThan(privacyBadge.frame.height, 50)
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
        XCTAssertTrue(
            app.staticTexts["collection-selection-status"].waitForExistence(timeout: 5)
        )

        let selectableCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Cat,")
        ).firstMatch
        XCTAssertTrue(selectableCard.waitForExistence(timeout: 5))
        XCTAssertFalse(selectableCard.isSelected)
        tapWhenHittable(selectableCard)

        let selectedCount = app.staticTexts["1 card selected"]
        if !selectedCount.waitForExistence(timeout: 2) {
            tapWhenHittable(
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cat,")).firstMatch
            )
        }
        XCTAssertTrue(selectedCount.waitForExistence(timeout: 5))

        let selectedCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND selected == true", "Cat,")
        ).firstMatch
        XCTAssertTrue(selectedCard.waitForExistence(timeout: 5))

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

    func testValidationLiftOffersStopAndReturnAfterShortDelay() {
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
        let stopButton = app.buttons["Stop and return"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 4))
        stopButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["capture-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Use validation photo"].exists)
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

    func testCardStyleRecommendationsStackAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-catlocal-ui-import-fixture",
            "-catlocal-ui-synthetic-photo",
            "-catlocal-ui-synthetic-cutout",
            "-catlocal-ui-skip-sticker-reveal",
            "-UIPreferredContentSizeCategoryName",
            UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue
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
        for _ in 0..<3 where !customizeButton.isHittable {
            app.swipeUp()
        }
        tapWhenHittable(customizeButton)

        let archiveStyle = app.buttons["recommended-card-style-archive"]
        if !archiveStyle.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(archiveStyle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(
            archiveStyle.frame.width,
            app.frame.width * 0.7,
            "Recommended styles should stack into wide rows at accessibility text sizes"
        )
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
        XCTAssertTrue(app.staticTexts["Meet Your First Cat"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["Choose private photo"].exists)
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

    func testValidationForegroundFallbackOffersNamedPhotoAreas() {
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
        let areaMenu = app.buttons["Choose photo area"]
        XCTAssertTrue(areaMenu.waitForExistence(timeout: 5))
        areaMenu.tap()

        let topCenterButton = app.buttons["Top center"]
        XCTAssertTrue(topCenterButton.waitForExistence(timeout: 5))
        topCenterButton.tap()

        XCTAssertTrue(app.buttons["save-cat-immediate"].waitForExistence(timeout: 10))
    }
}
