import AVFoundation
import CoreImage
import ImageIO
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import CatLocal

struct CatLocalCoreTests {
    @Test
    func appLanguageCatalogSupportsLaunchRegionsAndSystemFallback() {
        #expect(CatLocalLanguage.allCases == [
            .system,
            .english,
            .turkish,
            .romanian,
            .polish,
            .ukrainian,
            .greek,
            .croatian,
        ])
        #expect(CatLocalLanguage.resolved("tr") == .turkish)
        #expect(CatLocalLanguage.resolved("not-a-language") == .system)
        #expect(CatLocalLanguage.turkish.locale.identifier == "tr")
    }

    @Test
    func englishFallbackIsOfferedForEverySupportedNonEnglishPreferredLanguage() {
        #expect(CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["tr-TR"]))
        #expect(CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["ro-RO"]))
        #expect(CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["pl-PL"]))
        #expect(CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["uk-UA"]))
        #expect(CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["el-GR"]))
        #expect(CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["hr-HR"]))
        #expect(CatLocalLanguage.shouldOfferEnglishFallback(
            preferredLanguages: ["es-ES", "uk-UA", "en-US"]
        ))
        #expect(!CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["en-TR"]))
        #expect(!CatLocalLanguage.shouldOfferEnglishFallback(
            preferredLanguages: ["es-ES", "en-US", "uk-UA"]
        ))
        #expect(!CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: ["es-ES"]))
        #expect(!CatLocalLanguage.shouldOfferEnglishFallback(preferredLanguages: []))
    }

    @Test
    func englishFallbackAlternatesBetweenSystemLanguageAndEnglish() {
        #expect(CatLocalLanguage.englishFallbackSelection(from: .system) == .english)
        #expect(CatLocalLanguage.englishFallbackSelection(from: .turkish) == .english)
        #expect(CatLocalLanguage.englishFallbackSelection(from: .ukrainian) == .english)
        #expect(CatLocalLanguage.englishFallbackSelection(from: .english) == .system)
    }

    @Test
    func appLanguageCatalogResolvesLocalizedInterfaceCopy() {
        #expect(CatLocalLocalization.string("Settings", language: .turkish) == "Ayarlar")
        #expect(CatLocalLocalization.string("Settings", language: .polish) == "Ustawienia")
        #expect(CatLocalLocalization.string("Camera", language: .ukrainian) == "Камера")
        #expect(CatLocalLocalization.string("Privacy Receipt", language: .romanian) == "Raport de confidențialitate")
        #expect(CatLocalLocalization.format("%lld cats", language: .turkish, Int64(3)) == "3 kedi")
        #expect(
            CatLocalLocalization.cardStyleSummary(
                styleCount: 20,
                familyCount: 4,
                language: .turkish,
            ) == "4 ailede 20"
        )
        #expect(
            CatLocalLocalization.format(
                "Step %1$@ of %2$@",
                language: .ukrainian,
                "2",
                "3"
            ) == "Крок 2 з 3"
        )
    }

    @Test(arguments: [
        (CatLocalLanguage.english, ["0 cats", "1 cat", "2 cats", "3 cats", "4 cats", "5 cats", "11 cats", "12 cats", "21 cats", "22 cats", "25 cats", "101 cats"]),
        (CatLocalLanguage.turkish, ["0 kedi", "1 kedi", "2 kedi", "3 kedi", "4 kedi", "5 kedi", "11 kedi", "12 kedi", "21 kedi", "22 kedi", "25 kedi", "101 kedi"]),
        (CatLocalLanguage.romanian, ["0 pisici", "1 pisică", "2 pisici", "3 pisici", "4 pisici", "5 pisici", "11 pisici", "12 pisici", "21 de pisici", "22 de pisici", "25 de pisici", "101 pisici"]),
        (CatLocalLanguage.polish, ["0 kotów", "1 kot", "2 koty", "3 koty", "4 koty", "5 kotów", "11 kotów", "12 kotów", "21 kotów", "22 koty", "25 kotów", "101 kotów"]),
        (CatLocalLanguage.ukrainian, ["0 котів", "1 кіт", "2 коти", "3 коти", "4 коти", "5 котів", "11 котів", "12 котів", "21 кіт", "22 коти", "25 котів", "101 кіт"]),
        (CatLocalLanguage.greek, ["0 γάτες", "1 γάτα", "2 γάτες", "3 γάτες", "4 γάτες", "5 γάτες", "11 γάτες", "12 γάτες", "21 γάτες", "22 γάτες", "25 γάτες", "101 γάτες"]),
        (CatLocalLanguage.croatian, ["0 mačaka", "1 mačka", "2 mačke", "3 mačke", "4 mačke", "5 mačaka", "11 mačaka", "12 mačaka", "21 mačka", "22 mačke", "25 mačaka", "101 mačka"]),
    ])
    func catCountUsesLocalePluralRules(
        language: CatLocalLanguage,
        expected: [String]
    ) {
        let counts = [0, 1, 2, 3, 4, 5, 11, 12, 21, 22, 25, 101]
        let rendered = counts.map {
            CatLocalLocalization.format("%lld cats", language: language, Int64($0))
        }

        #expect(rendered == expected, "\(language.rawValue): \(rendered)")
    }

    @Test
    func everyPluralizedInterfaceKeyRendersAllRequiredCounts() {
        let keys = [
            "%lld cards selected",
            "%lld cats",
            "%lld cats found",
            "%lld cats saved locally",
            "%lld more cats",
            "%lld places",
            "%lld places typed by you.",
            "%lld saved cards",
            "%lld styles",
            "Delete %lld Cards",
            "Photo with %lld cats marked by number",
            "Shows %lld styles",
        ]
        let counts = [0, 1, 2, 3, 4, 5, 11, 12, 21, 22, 25, 101]

        for language in CatLocalLanguage.allCases.dropFirst() {
            for key in keys {
                for count in counts {
                    let rendered = CatLocalLocalization.plural(key, count: count, language: language)
                    #expect(!rendered.isEmpty, "key=\(key) locale=\(language.rawValue) count=\(count)")
                    #expect(!rendered.contains("%"), "key=\(key) locale=\(language.rawValue) count=\(count): \(rendered)")
                    #expect(rendered.contains(String(count)), "key=\(key) locale=\(language.rawValue) count=\(count): \(rendered)")
                }
            }
        }
    }

    @Test(arguments: [
        (CatLocalLanguage.english, ["37 in 0 families", "37 in 1 family", "37 in 2 families", "37 in 3 families", "37 in 4 families", "37 in 5 families", "37 in 11 families", "37 in 12 families", "37 in 21 families", "37 in 22 families", "37 in 25 families", "37 in 101 families"]),
        (CatLocalLanguage.turkish, ["0 ailede 37", "1 ailede 37", "2 ailede 37", "3 ailede 37", "4 ailede 37", "5 ailede 37", "11 ailede 37", "12 ailede 37", "21 ailede 37", "22 ailede 37", "25 ailede 37", "101 ailede 37"]),
        (CatLocalLanguage.romanian, ["37 în 0 familii", "37 în 1 familie", "37 în 2 familii", "37 în 3 familii", "37 în 4 familii", "37 în 5 familii", "37 în 11 familii", "37 în 12 familii", "37 în 21 de familii", "37 în 22 de familii", "37 în 25 de familii", "37 în 101 familii"]),
        (CatLocalLanguage.polish, ["37 w 0 rodzinach", "37 w 1 rodzinie", "37 w 2 rodzinach", "37 w 3 rodzinach", "37 w 4 rodzinach", "37 w 5 rodzinach", "37 w 11 rodzinach", "37 w 12 rodzinach", "37 w 21 rodzinach", "37 w 22 rodzinach", "37 w 25 rodzinach", "37 w 101 rodzinach"]),
        (CatLocalLanguage.ukrainian, ["37 у 0 сімействах", "37 у 1 сімействі", "37 у 2 сімействах", "37 у 3 сімействах", "37 у 4 сімействах", "37 у 5 сімействах", "37 у 11 сімействах", "37 у 12 сімействах", "37 у 21 сімействі", "37 у 22 сімействах", "37 у 25 сімействах", "37 у 101 сімействі"]),
        (CatLocalLanguage.greek, ["37 σε 0 οικογένειες", "37 σε 1 οικογένεια", "37 σε 2 οικογένειες", "37 σε 3 οικογένειες", "37 σε 4 οικογένειες", "37 σε 5 οικογένειες", "37 σε 11 οικογένειες", "37 σε 12 οικογένειες", "37 σε 21 οικογένειες", "37 σε 22 οικογένειες", "37 σε 25 οικογένειες", "37 σε 101 οικογένειες"]),
        (CatLocalLanguage.croatian, ["37 u 0 obitelji", "37 u 1 obitelji", "37 u 2 obitelji", "37 u 3 obitelji", "37 u 4 obitelji", "37 u 5 obitelji", "37 u 11 obitelji", "37 u 12 obitelji", "37 u 21 obitelji", "37 u 22 obitelji", "37 u 25 obitelji", "37 u 101 obitelji"]),
    ])
    func cardStyleFamilyCountUsesTheSecondArgumentPluralRule(
        language: CatLocalLanguage,
        expected: [String]
    ) {
        let counts = [0, 1, 2, 3, 4, 5, 11, 12, 21, 22, 25, 101]
        let rendered = counts.map {
            CatLocalLocalization.cardStyleSummary(
                styleCount: 37,
                familyCount: $0,
                language: language
            )
        }

        #expect(rendered == expected, "\(language.rawValue): \(rendered)")
    }

    @Test
    func launchInterfaceHasTranslationsAcrossEverySupportedLocale() {
        let keys = [
            "Home",
            "Settings",
            "Use English",
            "Privacy Receipt",
            "Welcome to CatLocal",
            "Back",
            "Capture or Import",
            "Your cat encounters stay private",
            "Ready for Your First Cat",
            "Meet Your First Cat",
            "Choose private photo",
            "Looking for cats",
            "Removing the background",
            "Which cat gets the card?",
            "Make It Yours",
            "Memory Place",
            "Save to Collection",
            "Delete this cat?",
            "On this iPhone",
            "Nothing leaves your phone",
        ]

        for language in CatLocalLanguage.allCases.dropFirst(2) {
            for key in keys {
                let translation = CatLocalLocalization.string(key, language: language)
                #expect(!translation.isEmpty)
                #expect(translation != key)
            }
        }
    }

    @Test
    func localizationFinalCleanupUsesCanonicalKeysAndReviewedTranslations() {
        #expect(CatLocalLocalization.string("Edit Before Saving", language: .turkish) == "Kaydetmeden önce düzenle")
        #expect(CatLocalLocalization.string("On this iPhone", language: .croatian) == "Na ovom iPhoneu")
        #expect(CatLocalLocalization.string("Preparing cat card", language: .ukrainian) == "Підготовка картки кота")
        #expect(CatLocalLocalization.string("Built Without", language: .turkish) == "İçermediklerimiz")
        #expect(CatLocalLocalization.string("Haptic Feedback", language: .croatian) == "Haptičke povratne informacije")

        let turkishHeadingTranslations = [
            "A New Cat": "Yeni Bir Kedi",
            "About CatLocal": "CatLocal Hakkında",
            "App Information": "Uygulama Bilgileri",
            "Capture or Import": "Çek veya İçe Aktar",
            "Card Motion": "Kart Hareketi",
            "Delete Cat": "Kediyi Sil",
            "Haptic Feedback": "Dokunsal Geri Bildirim",
            "Home": "Ana Sayfa",
            "Image Storage": "Görsel Depolama",
            "Local Storage": "Yerel Depolama",
            "Make It Yours": "Kendinize Göre Yapın",
            "Memory Place": "Anı Konumu",
            "Place Detail": "Konum Ayrıntısı",
            "Privacy Receipt": "Gizlilik Özeti",
            "Welcome to CatLocal": "CatLocal'a Hoş Geldiniz",
        ]
        for (key, expected) in turkishHeadingTranslations {
            #expect(CatLocalLocalization.string(key, language: .turkish) == expected)
        }

        #expect(CatLocalLocalization.string("Edit before saving", language: .turkish) == "Edit before saving")
        #expect(CatLocalLocalization.string("On This iPhone", language: .turkish) == "On This iPhone")
        #expect(CatLocalLocalization.string("Preparing Cat Card", language: .turkish) == "Preparing Cat Card")
        #expect(CatLocalLocalization.string("Storage used", language: .turkish) == "Storage used")
    }

    @Test
    func capturePresentationRestoresTheOriginatingContentTabAndRejectsReentry() {
        var state = AppTabPresentationState(initialTab: .settings)

        let didPresent = state.presentCapture()
        #expect(didPresent)
        #expect(state.selectedTab == .capture)
        #expect(state.lastContentTab == .settings)
        #expect(state.presentedSheet == .capture)
        let didPresentAgain = state.presentCapture()
        #expect(!didPresentAgain)

        let restoredTab = state.restoreContentTabSelection()
        #expect(restoredTab == .settings)
        #expect(state.selectedTab == .settings)
        #expect(state.presentedSheet == nil)
    }

    @Test
    func selectingContentTabsNeverMakesCaptureRestorable() {
        var state = AppTabPresentationState(initialTab: .home)

        state.selectContentTab(.settings)
        #expect(state.selectedTab == .settings)
        #expect(state.lastContentTab == .settings)

        state.selectContentTab(.capture)
        #expect(state.selectedTab == .settings)
        #expect(state.lastContentTab == .settings)
    }

    @Test
    func restoringCaptureAsTheInitialTabFallsBackToHome() {
        let state = AppTabPresentationState(initialTab: .capture)

        #expect(state.selectedTab == .home)
        #expect(state.lastContentTab == .home)
        #expect(state.presentedSheet == nil)
    }

    @Test
    func legacySurfaceMetricsCapGeometryBySemanticRole() {
        let compact = CatLegacySurfaceMetrics.resolve(
            role: .compactControl,
            requestedCornerRadius: 28,
            reduceTransparency: false,
            increasedContrast: false
        )
        let grouped = CatLegacySurfaceMetrics.resolve(
            role: .groupedAction,
            requestedCornerRadius: 28,
            reduceTransparency: false,
            increasedContrast: false
        )

        #expect(compact.cornerRadius == 16)
        #expect(grouped.cornerRadius == 20)
        #expect(grouped.shadowRadius <= 6)
    }

    @Test
    func legacySurfaceMetricsStrengthenSeparationWithoutChangingGeometry() {
        let standard = CatLegacySurfaceMetrics.resolve(
            role: .cameraOverlay,
            requestedCornerRadius: 28,
            reduceTransparency: false,
            increasedContrast: false
        )
        let accessible = CatLegacySurfaceMetrics.resolve(
            role: .cameraOverlay,
            requestedCornerRadius: 28,
            reduceTransparency: true,
            increasedContrast: true
        )

        #expect(accessible.cornerRadius == standard.cornerRadius)
        #expect(accessible.outlineOpacity > standard.outlineOpacity)
        #expect(accessible.usesOpaqueSurface)
    }

    @Test
    func cameraPrivacyBadgePreservesCopyAtAccessibilitySizes() {
        #expect(CameraPrivacyBadgeLayout.textLineLimit(for: .large) == 1)
        #expect(CameraPrivacyBadgeLayout.minimumScaleFactor(for: .large) == 0.86)
        #expect(CameraPrivacyBadgeLayout.textLineLimit(for: .accessibility3) == nil)
        #expect(CameraPrivacyBadgeLayout.minimumScaleFactor(for: .accessibility3) == 1)
    }

    @Test
    func cameraZoomMathConvertsAndClampsDisplayFactors() {
        #expect(CameraZoomMath.deviceFactor(
            forDisplayFactor: 0.5,
            displayMultiplier: 0.5,
            minimumDeviceFactor: 1,
            maximumDeviceFactor: 8
        ) == 1)
        #expect(CameraZoomMath.deviceFactor(
            forDisplayFactor: 1,
            displayMultiplier: 0.5,
            minimumDeviceFactor: 1,
            maximumDeviceFactor: 8
        ) == 2)
        #expect(CameraZoomMath.deviceFactor(
            forDisplayFactor: 20,
            displayMultiplier: 0.5,
            minimumDeviceFactor: 1,
            maximumDeviceFactor: 8
        ) == 8)
        #expect(CameraZoomMath.displayFactor(
            baseDisplayFactor: 1,
            magnification: 1.8,
            minimumDisplayFactor: 0.5,
            maximumDisplayFactor: 4
        ) == 1.8)
        #expect(CameraZoomMath.displayFactor(
            baseDisplayFactor: 0.5,
            magnification: 0.1,
            minimumDisplayFactor: 0.5,
            maximumDisplayFactor: 4
        ) == 0.5)
        #expect(CameraZoomMath.displayFactor(
            baseDisplayFactor: 4,
            magnification: 3,
            minimumDisplayFactor: 0.5,
            maximumDisplayFactor: 4
        ) == 4)
    }

    @Test
    func cameraDiscoveryPrefersVirtualRearCameraDevices() {
        #expect(CameraDeviceDiscovery.preferredDeviceTypes == [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
        ])
    }

    @Test
    func cameraCaptureStateRejectsOverlappingRequestsUntilCompletion() throws {
        var state = CameraCaptureState()

        try state.begin()
        #expect(state.isCapturing)
        #expect(throws: CameraError.busy) {
            try state.begin()
        }

        state.finish()
        #expect(!state.isCapturing)
        try state.begin()
    }

    @Test
    func cameraPhotoSettingsPreferQualityAndOnlyUseSupportedAutoFlash() {
        #expect(CameraPhotoSettingsPolicy.qualityPrioritization == .quality)
        #expect(CameraPhotoSettingsPolicy.flashMode(supportedModes: [.off, .auto]) == .auto)
        #expect(CameraPhotoSettingsPolicy.flashMode(supportedModes: [.off]) == .off)
        #expect(CameraPhotoSettingsPolicy.flashMode(supportedModes: []) == .off)
    }

    @Test
    func cameraConfigurationStateCachesOnlySuccessfullyCommittedCapabilities() {
        let capabilities = CameraZoomCapabilities(
            minimumDeviceFactor: 1,
            maximumDeviceFactor: 8,
            displayMultiplier: 0.5,
            currentDeviceFactor: 2
        )
        var state = CameraSessionConfigurationState()

        let firstBegin = state.begin()
        let overlappingBegin = state.begin()
        #expect(firstBegin)
        #expect(!overlappingBegin)
        #expect(state.cachedCapabilities == nil)

        state.fail()
        #expect(!state.isConfigured)
        #expect(state.cachedCapabilities == nil)
        let retryBegin = state.begin()
        #expect(retryBegin)

        state.commit(capabilities)
        #expect(state.isConfigured)
        #expect(state.cachedCapabilities == capabilities)
        let configuredBegin = state.begin()
        #expect(!configuredBegin)
    }

    @Test
    func cameraConfigurationRequestsCoalesceAndFailureCanRetry() async throws {
        let expected = CameraZoomCapabilities(
            minimumDeviceFactor: 1,
            maximumDeviceFactor: 8,
            displayMultiplier: 0.5,
            currentDeviceFactor: 2
        )
        let gate = CameraConfigurationRequestGate<CameraZoomCapabilities>()
        let probe = CameraConfigurationOperationProbe()
        let callerCount = 8

        async let coalescedResults: [CameraZoomCapabilities] = withThrowingTaskGroup(
            of: CameraZoomCapabilities.self,
            returning: [CameraZoomCapabilities].self
        ) { group in
            for _ in 0..<callerCount {
                group.addTask {
                    try await gate.value {
                        try await probe.run(returning: expected)
                    }
                }
            }

            var results: [CameraZoomCapabilities] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        await probe.waitForInvocationCount(1)
        for _ in 0..<20 {
            await Task.yield()
        }
        await probe.releaseBlockedInvocations()

        let results = try await coalescedResults
        #expect(results == Array(repeating: expected, count: callerCount))
        #expect(await probe.invocationCount == 1)

        await probe.failNextInvocation()
        do {
            _ = try await gate.value {
                try await probe.run(returning: expected)
            }
            Issue.record("Expected the configuration operation to fail")
        } catch CameraConfigurationOperationProbe.ExpectedFailure.requested {
            // The failed request must clear the gate so the next caller can retry.
        }

        let retried = try await gate.value {
            try await probe.run(returning: expected)
        }
        #expect(retried == expected)
        #expect(await probe.invocationCount == 3)
    }

    @Test
    func cameraCapturePreparationKeepsTheCompleteNormalizedPhotograph() throws {
        let source = renderedImage(size: CGSize(width: 400, height: 300), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let data = try #require(source.jpegData(compressionQuality: 1))

        let prepared = try CaptureImagePreparation.cameraImage(
            from: data,
            maximumDimension: 300
        )

        #expect(DustRevealGeometry.pixelSize(of: prepared) == CGSize(width: 300, height: 225))
        #expect(prepared.imageOrientation == .up)
        #expect(prepared.scale == 1)

        let orientedSource = renderedImage(
            size: CGSize(width: 400, height: 300),
            opaque: true
        ) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 200, y: 0, width: 200, height: 300))
        }
        let orientedData = try jpegData(from: orientedSource, orientation: .right)
        let orientedPrepared = try CaptureImagePreparation.cameraImage(
            from: orientedData,
            maximumDimension: 300
        )
        let orientedCGImage = try #require(orientedPrepared.cgImage)
        let firstEdge = try rgbValue(in: orientedCGImage, x: 110, y: 20)
        let secondEdge = try rgbValue(in: orientedCGImage, x: 110, y: 280)

        #expect(DustRevealGeometry.pixelSize(of: orientedPrepared) == CGSize(width: 225, height: 300))
        #expect(orientedPrepared.imageOrientation == .up)
        #expect(Int(firstEdge.red) > Int(firstEdge.blue) * 2)
        #expect(Int(secondEdge.blue) > Int(secondEdge.red) * 2)
    }

    @Test
    func galleryPreparationUsesImageIOAndReportsCancellationCheckpoints() throws {
        let source = renderedImage(
            size: CGSize(width: 400, height: 300),
            opaque: true
        ) { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let data = try #require(source.jpegData(compressionQuality: 1))
        var checkpoints: [GalleryImagePreparationCheckpoint] = []

        let prepared = try CaptureImagePreparation.galleryImage(
            from: data,
            maximumDimension: 200
        ) { checkpoint in
            checkpoints.append(checkpoint)
        }

        #expect(CGSize(width: prepared.width, height: prepared.height) == CGSize(width: 200, height: 150))
        #expect(checkpoints == [
            .beforeSourceDecode,
            .beforeOrientationNormalization,
            .afterThumbnailCreation,
            .afterDownsampling,
            .beforeReturn,
        ])
    }

    @Test
    func galleryPreparationStopsAtACancelledCheckpoint() throws {
        let source = renderedImage(
            size: CGSize(width: 400, height: 300),
            opaque: true
        ) { context in
            UIColor.systemMint.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let data = try #require(source.jpegData(compressionQuality: 1))
        var reachedThumbnailCreation = false
        var reachedBeforeReturn = false

        #expect(throws: CancellationError.self) {
            _ = try CaptureImagePreparation.galleryImage(
                from: data,
                maximumDimension: 200
            ) { checkpoint in
                if checkpoint == .beforeOrientationNormalization {
                    throw CancellationError()
                }
                if checkpoint == .afterThumbnailCreation {
                    reachedThumbnailCreation = true
                }
                if checkpoint == .beforeReturn {
                    reachedBeforeReturn = true
                }
            }
        }
        #expect(!reachedThumbnailCreation)
        #expect(!reachedBeforeReturn)
    }

    @Test
    func galleryPreparationCancellationReachesTheDetachedWorker() async throws {
        let fallbackImage = try solidCGImage(
            size: CGSize(width: 8, height: 8),
            colorSpace: try #require(CGColorSpace(name: CGColorSpace.sRGB))
        )
        let cancellationHandlerInstalled = AsyncStream<Void>.makeStream()
        let started = AsyncStream<Void>.makeStream()
        let cancellationObservation = AsyncStream<Bool>.makeStream()
        let releaseWorker = DispatchSemaphore(value: 0)
        var handlerIterator = cancellationHandlerInstalled.stream.makeAsyncIterator()
        var startedIterator = started.stream.makeAsyncIterator()
        var observationIterator = cancellationObservation.stream.makeAsyncIterator()

        let task = Task {
            try await CaptureImagePreparation.runGalleryWorker(
                didInstallCancellationHandler: {
                    cancellationHandlerInstalled.continuation.yield()
                }
            ) {
                started.continuation.yield()
                releaseWorker.wait()
                cancellationObservation.continuation.yield(Task.isCancelled)
                try Task.checkCancellation()
                return fallbackImage
            }
        }

        _ = await handlerIterator.next()
        _ = await startedIterator.next()
        task.cancel()
        releaseWorker.signal()

        #expect(await observationIterator.next() == true)
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test
    func aspectFitPointMappingReturnsTopLeftSourceCoordinates() throws {
        let imageSize = CGSize(width: 400, height: 200)
        let containerSize = CGSize(width: 300, height: 300)
        let tolerance: CGFloat = 0.000_001

        let mapped = AspectFitPointMapping.normalizedSourcePoint(
            at: CGPoint(x: 75, y: 105),
            imageSize: imageSize,
            containerSize: containerSize
        )

        #expect(abs(try #require(mapped).x - 0.25) < tolerance)
        #expect(abs(try #require(mapped).y - 0.20) < tolerance)
        #expect(AspectFitPointMapping.normalizedSourcePoint(
            at: CGPoint(x: 150, y: 74),
            imageSize: imageSize,
            containerSize: containerSize
        ) == nil)
        #expect(AspectFitPointMapping.normalizedSourcePoint(
            at: CGPoint(x: 301, y: 150),
            imageSize: imageSize,
            containerSize: containerSize
        ) == nil)
    }

    @Test
    func aspectFitPointMappingRejectsInvalidGeometryAndFarImageEdge() {
        #expect(AspectFitPointMapping.normalizedSourcePoint(
            at: .zero,
            imageSize: .zero,
            containerSize: CGSize(width: 300, height: 300)
        ) == nil)
        #expect(AspectFitPointMapping.normalizedSourcePoint(
            at: CGPoint(x: 300, y: 225),
            imageSize: CGSize(width: 400, height: 200),
            containerSize: CGSize(width: 300, height: 300)
        ) == nil)
    }

    @Test
    func captureTransitionPreparationRemovesTheSubjectFromTheMetalBackground() throws {
        let original = renderedImage(
            size: CGSize(width: 300, height: 300),
            opaque: true
        ) { context in
            UIColor(red: 0.20, green: 0.60, blue: 0.30, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        let alignedCutout = renderedImage(
            size: CGSize(width: 300, height: 300),
            opaque: false
        ) { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
            UIColor.black.setFill()
            context.fill(CGRect(x: 100, y: 60, width: 80, height: 180))
        }

        let prepared = try CaptureImagePreparation.transitionAssets(
            original: try #require(original.cgImage),
            alignedCutout: try #require(alignedCutout.cgImage),
            maximumDimension: 1600
        )
        requireSendable(prepared)

        let removedSubjectPixel = try rgbaValue(in: prepared.backgroundOnly, x: 140, y: 150)
        let preservedBackgroundPixel = try rgbaValue(in: prepared.backgroundOnly, x: 20, y: 20)

        #expect(CGSize(width: prepared.alignedCutout.width, height: prepared.alignedCutout.height)
            == CGSize(width: 300, height: 300))
        #expect(CGSize(width: prepared.backgroundOnly.width, height: prepared.backgroundOnly.height)
            == CGSize(width: 300, height: 300))
        #expect(CGSize(width: prepared.subjectProtectionMask.width, height: prepared.subjectProtectionMask.height)
            == CGSize(width: 300, height: 300))
        #expect(removedSubjectPixel == RGBAValue(red: 0, green: 0, blue: 0, alpha: 0))
        #expect(preservedBackgroundPixel.alpha == 255)
        #expect(preservedBackgroundPixel.green > preservedBackgroundPixel.red * 2)
    }

    @Test
    func captureTransitionBackgroundMultipliesByInversePartialCutoutAlpha() throws {
        let original = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor(red: 0.80, green: 0.40, blue: 0.20, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let cutout = renderedImage(size: CGSize(width: 80, height: 80), opaque: false) { context in
            UIColor.black.withAlphaComponent(0.5).setFill()
            context.fill(CGRect(x: 20, y: 20, width: 40, height: 40))
        }

        let prepared = try CaptureImagePreparation.transitionAssets(
            original: try #require(original.cgImage),
            alignedCutout: try #require(cutout.cgImage)
        )
        let sourcePixel = try rgbaValue(in: try #require(original.cgImage), x: 40, y: 40)
        let cutoutPixel = try rgbaValue(in: try #require(cutout.cgImage), x: 40, y: 40)
        let backgroundPixel = try rgbaValue(in: prepared.backgroundOnly, x: 40, y: 40)
        let inverseAlpha = 1 - Double(cutoutPixel.alpha) / 255

        #expect(abs(Double(backgroundPixel.alpha) - 255 * inverseAlpha) <= 2)
        #expect(abs(Double(backgroundPixel.red) - Double(sourcePixel.red) * inverseAlpha) <= 2)
        #expect(abs(Double(backgroundPixel.green) - Double(sourcePixel.green) * inverseAlpha) <= 2)
        #expect(abs(Double(backgroundPixel.blue) - Double(sourcePixel.blue) * inverseAlpha) <= 2)
    }

    @Test
    func captureTransitionPreparationAlignsStickerOutlineAndNormalizedBounds() throws {
        let original = renderedImage(size: CGSize(width: 300, height: 300), opaque: true) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        let alignedCutout = renderedImage(size: CGSize(width: 300, height: 300), opaque: false) { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 100, y: 60, width: 80, height: 180))
        }

        let prepared = try CaptureImagePreparation.transitionAssets(
            original: try #require(original.cgImage),
            alignedCutout: try #require(alignedCutout.cgImage),
            maximumDimension: 1600
        )

        #expect(CGSize(width: prepared.sticker.width, height: prepared.sticker.height)
            == CGSize(width: prepared.outlineMask.width, height: prepared.outlineMask.height))
        #expect(abs(prepared.normalizedSubjectBounds.minX - (100.0 / 300.0)) < 0.01)
        #expect(abs(prepared.normalizedSubjectBounds.minY - (60.0 / 300.0)) < 0.01)
        #expect(abs(prepared.normalizedSubjectBounds.width - (80.0 / 300.0)) < 0.01)
        #expect(abs(prepared.normalizedSubjectBounds.height - (180.0 / 300.0)) < 0.01)
        #expect(prepared.normalizedPaddedCropBounds.contains(prepared.normalizedSubjectBounds))
        let outlineEdgeAlpha = try alphaValue(
            in: prepared.outlineMask,
            x: 2,
            y: prepared.outlineMask.height / 2
        )
        let stickerEdgeAlpha = try alphaValue(
            in: prepared.sticker,
            x: 2,
            y: prepared.sticker.height / 2
        )
        #expect(outlineEdgeAlpha > stickerEdgeAlpha)
    }

    @Test
    func captureTransitionNearTopCropKeepsOutlineAndStickerOnTheSameYAxis() throws {
        let original = renderedImage(size: CGSize(width: 120, height: 240), opaque: true) { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 240))
        }
        let cutout = renderedImage(size: CGSize(width: 120, height: 240), opaque: false) { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 45, y: 8, width: 30, height: 34))
        }

        let prepared = try CaptureImagePreparation.transitionAssets(
            original: try #require(original.cgImage),
            alignedCutout: try #require(cutout.cgImage)
        )
        let relativeSubjectCenterX = prepared.sticker.width / 2
        let nearTopY = 8
        let mirroredBottomY = prepared.sticker.height - 1

        #expect(abs(prepared.normalizedSubjectBounds.minY - (8.0 / 240.0)) < 0.01)
        #expect(prepared.normalizedPaddedCropBounds.minY == 0)
        #expect(try alphaValue(
            in: prepared.sticker,
            x: relativeSubjectCenterX,
            y: nearTopY
        ) > 200)
        #expect(try alphaValue(
            in: prepared.outlineMask,
            x: relativeSubjectCenterX,
            y: nearTopY
        ) > 200)
        #expect(try alphaValue(
            in: prepared.outlineMask,
            x: relativeSubjectCenterX,
            y: mirroredBottomY
        ) < 10)
    }

    @Test
    func captureTransitionPreparationDownsamplesAllFullCanvasAssetsTogether() throws {
        let original = renderedImage(size: CGSize(width: 2400, height: 1200), opaque: true) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
        }
        let cutout = renderedImage(size: CGSize(width: 2400, height: 1200), opaque: false) { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 900, y: 200, width: 600, height: 800))
        }

        let prepared = try CaptureImagePreparation.transitionAssets(
            original: try #require(original.cgImage),
            alignedCutout: try #require(cutout.cgImage),
            maximumDimension: 1600
        )

        #expect(prepared.sourceSize == CGSize(width: 1600, height: 800))
        #expect(prepared.alignedCutout.width == 1600)
        #expect(prepared.backgroundOnly.width == 1600)
        #expect(prepared.subjectProtectionMask.width == 1600)
    }

    @Test
    func captureTransitionWorkingColorSpaceKeepsTaggedRGBAndRejectsGray() throws {
        let displayP3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let p3Image = try solidCGImage(size: CGSize(width: 12, height: 12), colorSpace: displayP3)
        let grayImage = try solidGrayCGImage(size: CGSize(width: 12, height: 12))

        let p3Policy = CaptureTransitionColorSpace.resolve(for: p3Image)
        let grayPolicy = CaptureTransitionColorSpace.resolve(for: grayImage)

        #expect(p3Policy.source == .sourceRGB)
        #expect(p3Policy.name == displayP3.name as String?)
        #expect(grayPolicy.source == .extendedSRGB || grayPolicy.source == .sRGB)
        #expect(grayPolicy.name != CGColorSpaceCreateDeviceRGB().name as String?)
    }

    @Test
    func captureTransitionConvertsSRGBCutoutIntoDisplayP3WorkingSpace() throws {
        let displayP3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let original = try solidCGImage(size: CGSize(width: 24, height: 24), colorSpace: displayP3)
        let cutout = try solidCGImage(size: CGSize(width: 24, height: 24), colorSpace: sRGB)

        let prepared = try CaptureImagePreparation.transitionAssets(
            original: original,
            alignedCutout: cutout
        )

        try expectPreparedTransition(
            prepared,
            convertsCutout: cutout,
            into: displayP3
        )
    }

    @Test
    func captureTransitionConvertsDeviceRGBCutoutWithoutRetaggingItAsDisplayP3() throws {
        let displayP3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let deviceRGB = CGColorSpaceCreateDeviceRGB()
        let original = try solidCGImage(size: CGSize(width: 24, height: 24), colorSpace: displayP3)
        let cutout = try solidCGImage(size: CGSize(width: 24, height: 24), colorSpace: deviceRGB)

        let prepared = try CaptureImagePreparation.transitionAssets(
            original: original,
            alignedCutout: cutout
        )

        try expectPreparedTransition(
            prepared,
            convertsCutout: cutout,
            into: displayP3
        )
    }

    @Test
    func subjectLiftTimelineUsesOneReadableDustPassWithoutExtraHolds() {
        #expect(DustRevealTimeline.standardDuration == 1.10)
        #expect(DustRevealTimeline.progress(elapsed: 0.55, duration: 1.10) == 0.5)
        #expect(DustRevealTimeline.isComplete(elapsed: 1.10, duration: 1.10))
    }

    @Test
    func subjectToCardSourceRectUsesTheAspectFitPhotoAtAnyContainerOrigin() {
        let crop = CGRect(x: 0.25, y: 0.20, width: 0.50, height: 0.60)

        let landscape = SubjectToCardTransitionGeometry.sourceRect(
            normalizedCropBounds: crop,
            imageSize: CGSize(width: 400, height: 200),
            containerRect: CGRect(x: 20, y: 40, width: 300, height: 300)
        )
        #expect(landscape == CGRect(x: 95, y: 145, width: 150, height: 90))

        let portrait = SubjectToCardTransitionGeometry.sourceRect(
            normalizedCropBounds: crop,
            imageSize: CGSize(width: 200, height: 400),
            containerRect: CGRect(x: 10, y: 30, width: 300, height: 300)
        )
        #expect(portrait == CGRect(x: 122.5, y: 90, width: 75, height: 180))

        let square = SubjectToCardTransitionGeometry.sourceRect(
            normalizedCropBounds: crop,
            imageSize: CGSize(width: 300, height: 300),
            containerRect: CGRect(x: 7, y: 11, width: 240, height: 240)
        )
        #expect(square == CGRect(x: 67, y: 59, width: 120, height: 144))
    }

    @Test
    func subjectToCardRectInterpolationClampsAndTracksDestinationResize() {
        let source = CGRect(x: 20, y: 40, width: 200, height: 300)
        let destination = CGRect(x: 80, y: 120, width: 120, height: 180)

        #expect(SubjectToCardTransitionGeometry.interpolatedRect(
            from: source,
            to: destination,
            progress: -1
        ) == source)
        #expect(SubjectToCardTransitionGeometry.interpolatedRect(
            from: source,
            to: destination,
            progress: 0.5
        ) == CGRect(x: 50, y: 80, width: 160, height: 240))
        #expect(SubjectToCardTransitionGeometry.interpolatedRect(
            from: source,
            to: destination,
            progress: 2
        ) == destination)

        let resizedDestination = CGRect(x: 50, y: 100, width: 180, height: 210)
        #expect(SubjectToCardTransitionGeometry.interpolatedRect(
            from: source,
            to: resizedDestination,
            progress: 1
        ) == resizedDestination)
    }

    @Test
    func subjectToCardTimelineOverlapsDustLiftAndSettlesOnce() {
        #expect(SubjectToCardTransitionTimeline.dustDuration == 1.10)
        #expect(SubjectToCardTransitionTimeline.outlineStart == 0.68)
        #expect(SubjectToCardTransitionTimeline.outlineDuration == 0.28)
        #expect(SubjectToCardTransitionTimeline.liftStart == 0.92)
        #expect(SubjectToCardTransitionTimeline.liftDuration == 0.64)
        #expect(SubjectToCardTransitionTimeline.settleDuration == 0.28)
        #expect(SubjectToCardTransitionTimeline.scaleRiseDuration == 0.16)
        #expect(SubjectToCardTransitionTimeline.cardRevealDuration == 0.42)
        #expect(SubjectToCardTransitionTimeline.backdropRevealDuration == 0.44)
        #expect(SubjectToCardTransitionTimeline.totalDuration == 1.84)
        #expect(SubjectToCardTransitionTimeline.reducedMotionDuration == 0.25)

        #expect(SubjectToCardTransitionTimeline.phase(elapsed: -1) == .preparing)
        #expect(SubjectToCardTransitionTimeline.phase(elapsed: 0.5) == .dusting)
        #expect(SubjectToCardTransitionTimeline.phase(elapsed: 1.1) == .lifting)
        #expect(SubjectToCardTransitionTimeline.phase(elapsed: 1.7) == .settling)
        #expect(SubjectToCardTransitionTimeline.phase(elapsed: 1.84) == .completed)
        #expect(SubjectToCardTransitionTimeline.liftProgress(elapsed: 0.91) == 0)
        #expect(SubjectToCardTransitionTimeline.liftProgress(elapsed: 1.56) == 1)
        #expect(SubjectToCardTransitionTimeline.outlineOpacity(elapsed: 0.67) == 0)
        #expect(SubjectToCardTransitionTimeline.outlineOpacity(elapsed: 0.97) == 1)
        #expect(SubjectToCardTransitionTimeline.cardOpacity(elapsed: 0.67) == 0)
        #expect(SubjectToCardTransitionTimeline.cardOpacity(elapsed: 1.11) == 1)
        #expect(SubjectToCardTransitionTimeline.backdropOpacity(elapsed: 1.09) == 0)
        #expect(SubjectToCardTransitionTimeline.backdropOpacity(elapsed: 1.55) == 1)
        #expect(SubjectToCardTransitionTimeline.maximumScale == 1.035)

        let riseStart = SubjectToCardTransitionTimeline.liftStart
            + SubjectToCardTransitionTimeline.liftDuration
            - SubjectToCardTransitionTimeline.scaleRiseDuration
        let peak = SubjectToCardTransitionTimeline.liftStart
            + SubjectToCardTransitionTimeline.liftDuration
        let justBeforePeak = SubjectToCardTransitionTimeline.cardScale(elapsed: peak - 0.000_001)
        let justAfterPeak = SubjectToCardTransitionTimeline.cardScale(elapsed: peak + 0.000_001)
        #expect(SubjectToCardTransitionTimeline.cardScale(elapsed: riseStart) == 1)
        #expect(SubjectToCardTransitionTimeline.cardScale(elapsed: peak) == 1.035)
        #expect(abs(justBeforePeak - justAfterPeak) < 0.000_001)
        #expect(SubjectToCardTransitionTimeline.cardScale(elapsed: 1.84) == 1)
        #expect(SubjectToCardTransitionTimeline.cardScale(elapsed: 100) == 1)
    }

    @Test
    func subjectToCardFailureContinuityPreservesIndependentLayerOpacities() {
        let elapsed: TimeInterval = 1.20
        let snapshot = SubjectToCardTransitionTimeline.opacitySnapshot(elapsed: elapsed)

        #expect(snapshot.card == SubjectToCardTransitionTimeline.cardOpacity(elapsed: elapsed))
        #expect(snapshot.backdrop == SubjectToCardTransitionTimeline.backdropOpacity(elapsed: elapsed))
        #expect(snapshot.card != snapshot.backdrop)
    }

    @Test
    func subjectToCardTimelineWaitsForTheFirstPresentedMetalFrame() {
        var metalGate = SubjectToCardTimelineStartGate(requiresMetalFirstFrame: true)
        let initiallyStopped = !metalGate.isStarted
        let ignoredFallback = metalGate.startIfReady(for: .fallback)
        let firstMetalFrame = metalGate.startIfReady(for: .metalFirstFrame)
        let duplicateMetalFrame = metalGate.startIfReady(for: .metalFirstFrame)
        #expect(initiallyStopped)
        #expect(!ignoredFallback)
        #expect(firstMetalFrame)
        #expect(!duplicateMetalFrame)
        #expect(metalGate.isStarted)

        var fallbackGate = SubjectToCardTimelineStartGate(requiresMetalFirstFrame: false)
        let firstFallback = fallbackGate.startIfReady(for: .fallback)
        let lateMetalFrame = fallbackGate.startIfReady(for: .metalFirstFrame)
        #expect(firstFallback)
        #expect(!lateMetalFrame)
    }

    @Test
    func subjectToCardCompletionGateAllowsFeedbackAndHandoffAtMostOnce() {
        var gate = SubjectToCardCompletionGate()
        let firstCompletion = gate.complete()
        let duplicateCompletion = gate.complete()

        #expect(firstCompletion)
        #expect(!duplicateCompletion)
        #expect(gate.isCompleted)
    }

    @Test
    func captureTransitionSessionRejectsStaleCompletionAfterInvalidationAndRetry() throws {
        var gate = CaptureTransitionSessionGate()
        let staleID = gate.begin()
        gate.invalidate()
        let currentID = gate.begin()
        let staleCompletion = gate.consume(staleID)
        let currentWasPreserved = gate.isCurrent(currentID)
        let currentCompletion = gate.consume(currentID)
        let duplicateCompletion = gate.consume(currentID)

        #expect(!staleCompletion)
        #expect(currentWasPreserved)
        #expect(currentCompletion)
        #expect(!duplicateCompletion)
        #expect(gate.activeID == nil)
    }

    @Test
    func preferenceCatalogUsesStablePersistedValues() {
        #expect(CatLocalAppearance.allCases == [.system, .light, .dark])
        #expect(CatLocalHomeView.allCases == [.cards, .catlas])
        #expect(CatLocalSortOrder.allCases == [.number, .place, .alphabetical])

        #expect(CatLocalAppearance.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(CatLocalHomeView.allCases.map(\.rawValue) == ["cards", "catlas"])
        #expect(CatLocalSortOrder.allCases.map(\.rawValue) == ["number", "place", "alphabetical"])
    }

    @Test
    func invalidPersistedPreferencesRecoverToSafeDefaults() {
        #expect(CatLocalAppearance.resolved("unknown") == .system)
        #expect(CatLocalHomeView.resolved("unknown") == .cards)
        #expect(CatLocalSortOrder.resolved("unknown") == .number)
    }

    @Test
    func appearancePreferenceMapsToSwiftUIColorSchemes() {
        #expect(CatLocalAppearance.system.preferredColorScheme == nil)
        #expect(CatLocalAppearance.light.preferredColorScheme == .light)
        #expect(CatLocalAppearance.dark.preferredColorScheme == .dark)
    }

    @Test
    func lociPoseRawValuesMatchAssetNames() {
        #expect(LociPose.allCases.map(\.rawValue) == [
            "loci_presenting",
            "loci_curious",
            "loci_noCatFound",
            "loci_inspecting",
            "loci_cardReady",
            "loci_hint",
            "loci_privacy"
        ])
    }

    @Test
    func lociAssetCatalogContainsEveryPose() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let lociRoot = repository
            .appendingPathComponent("CatLocal")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("Loci")

        for pose in LociPose.allCases {
            let imageSet = lociRoot.appendingPathComponent("\(pose.rawValue).imageset", isDirectory: true)
            let contents = imageSet.appendingPathComponent("Contents.json")
            let image = imageSet.appendingPathComponent("\(pose.rawValue).png")

            #expect(FileManager.default.fileExists(atPath: contents.path))
            #expect(FileManager.default.fileExists(atPath: image.path))
        }
    }

    @Test
    func lociContextCatalogMatchesExpandedGuide() {
        #expect(LociContext.allCases == [
            .emptyCollection,
            .cardSaved,
            .recoverableWarning,
            .failureRecovery,
            .noCatFound,
            .imageQualityWarning,
            .glintHint,
            .privacyEducation
        ])
    }

    @Test
    func lociContextsMapToExpectedPosesAndMotion() {
        let expected: [(LociContext, LociPose, LociMascotAnimation)] = [
            (.emptyCollection, .presenting, .idle),
            (.cardSaved, .cardReady, .successPop),
            (.recoverableWarning, .inspecting, .thinking),
            (.failureRecovery, .curious, .errorTilt),
            (.noCatFound, .noCatFound, .errorTilt),
            (.imageQualityWarning, .inspecting, .thinking),
            (.glintHint, .hint, .idle),
            (.privacyEducation, .privacy, .none)
        ]

        for (context, pose, motion) in expected {
            #expect(context.pose == pose)
            #expect(context.motion == motion)
        }
    }

    @Test
    func lociMascotStateCarriesContextCopyAndMotion() {
        let successState = LociMascotState.state(for: .cardSaved)
        #expect(successState.context == .cardSaved)
        #expect(successState.pose == .cardReady)
        #expect(successState.motion == .successPop)
        #expect(successState.title == "Card ready")
        #expect(successState.subtitle == "Saved locally to your collection.")

        let customState = LociMascotState(
            context: .imageQualityWarning,
            motion: .errorTilt,
            title: "Try another photo",
            subtitle: "Keep the whole cat in frame."
        )
        #expect(customState.pose == .inspecting)
        #expect(customState.motion == .errorTilt)
        #expect(customState.title == "Try another photo")
        #expect(customState.subtitle == "Keep the whole cat in frame.")
    }

    @Test
    func lociMotionCatalogIsStateDriven() {
        #expect(LociMascotAnimation.allCases == [
            .none,
            .idle,
            .thinking,
            .successPop,
            .errorTilt
        ])
    }

    @Test
    func lociContextCopyUsesExistingCatLocalLanguage() {
        #expect(LociContext.emptyCollection.title == "Meet Your First Cat")
        #expect(LociContext.emptyCollection.subtitle == "Capture an encounter and turn it into a collectible card.")
        #expect(LociContext.noCatFound.title == "I couldn't find the cat clearly")
        #expect(LociContext.imageQualityWarning.title == "This photo looks a little unclear")
        #expect(LociContext.glintHint.subtitle == "Your cards react to touch.")
        #expect(LociContext.privacyEducation.subtitle == "CatLocal processes your cat images on-device.")
    }

    @Test
    func cardStyleDefaultsToArchiveForLegacySeeds() {
        for seed in [0, 1, 2, 3, 77, 9_999] {
            #expect(CardStyle.deterministic(seed: seed) == .archive)
        }
    }

    @Test
    func cardStyleCatalogIncludesContourVariants() {
        let contourStyles = CardStyle.orderedCases.filter(\.isTopographic)

        #expect(contourStyles == [.topo, .topoEmber, .topoLagoon, .topoMoss, .topoDusk])
        #expect(Set(CardStyle.orderedCases.map(\.rawValue)).count == CardStyle.orderedCases.count)
    }

    @Test
    func cardStyleCatalogIncludesArchiveMaterialVariants() {
        let archiveMaterialStyles = CardStyle.orderedCases.filter(\.isArchiveMaterial)

        #expect(archiveMaterialStyles == [.pineShadow, .cedarShade, .fernTrace, .mossVeil])
        #expect(archiveMaterialStyles.map(\.archiveMaterialVariantIndex) == [0, 1, 2, 3])
    }

    @Test
    func cardStyleCatalogIncludesLightEffectVariants() {
        let lightEffectStyles = CardStyle.orderedCases.filter(\.isLightEffect)

        #expect(lightEffectStyles == [.cobaltHalo, .apricotBeam, .auroraPool])
        #expect(lightEffectStyles.map(\.lightEffectVariantIndex) == [0, 1, 2])
    }

    @Test
    func lightEffectProgressIsQuietAtRestAndInsideDeadZone() {
        #expect(CatCardLightEffectMath.progress(rotateX: 0, rotateY: 0) == 0)
        #expect(CatCardLightEffectMath.progress(rotateX: 1.2, rotateY: 0) == 0)
        #expect(CatCardLightEffectMath.progress(rotateX: 0, rotateY: -1.19) == 0)
    }

    @Test
    func lightEffectProgressGrowsSmoothlyWithTilt() {
        let low = CatCardLightEffectMath.progress(rotateX: 3, rotateY: 0)
        let middle = CatCardLightEffectMath.progress(rotateX: 0, rotateY: 6)
        let high = CatCardLightEffectMath.progress(rotateX: -9, rotateY: 2)

        #expect(low > 0)
        #expect(low < middle)
        #expect(middle < high)
        #expect(high < 1)
    }

    @Test
    func lightEffectProgressReachesAndClampsAtMaximumTilt() {
        #expect(CatCardLightEffectMath.progress(rotateX: 12, rotateY: 0) == 1)
        #expect(CatCardLightEffectMath.progress(rotateX: -24, rotateY: 18) == 1)
    }

    @Test
    func lightThumbnailPresentationPolicyDisablesEveryOverlay() {
        let policy = CatCardEffectPresentationPolicy(
            style: .cobaltHalo,
            presentation: .thumbnail
        )

        #expect(!policy.showsStandardAura)
        #expect(!policy.showsStandardSheen)
        #expect(!policy.showsFamilyAura)
        #expect(!policy.showsLightBand)
        #expect(!policy.showsGenericGlint)
        #expect(policy.illustrativeLightProgress == 0)
    }

    @Test
    func lightStylePreviewPresentationPolicyKeepsIllustrativeEffect() {
        let policy = CatCardEffectPresentationPolicy(
            style: .cobaltHalo,
            presentation: .stylePreview
        )

        #expect(!policy.showsStandardAura)
        #expect(!policy.showsStandardSheen)
        #expect(policy.showsFamilyAura)
        #expect(policy.showsLightBand)
        #expect(policy.illustrativeLightProgress == 0.55)
    }

    @Test
    func contourSamplesReachEveryCardEdgeBand() {
        for aspectRatio in [CGFloat(0.64), CGFloat(0.72)] {
            let rect = CGRect(x: 0, y: 0, width: 1_000 * aspectRatio, height: 1_000)
            let points = CatCardContourMath.samplePoints(
                index: 14,
                total: 15,
                patternSeed: 73,
                in: rect
            )
            let horizontalBand = rect.width * 0.04
            let verticalBand = rect.height * 0.04

            #expect(points.contains { $0.x <= rect.minX + horizontalBand })
            #expect(points.contains { $0.x >= rect.maxX - horizontalBand })
            #expect(points.contains { $0.y <= rect.minY + verticalBand })
            #expect(points.contains { $0.y >= rect.maxY - verticalBand })
        }
    }

    @Test
    func botanicalPatternsAreDeterministicAndSeeded() {
        let first = CatCardBotanicalPattern.signature(style: .pineShadow, patternSeed: 41)
        let repeated = CatCardBotanicalPattern.signature(style: .pineShadow, patternSeed: 41)
        let differentSeed = CatCardBotanicalPattern.signature(style: .pineShadow, patternSeed: 42)

        #expect(first == repeated)
        #expect(first != differentSeed)
        #expect(!first.isEmpty)
    }

    @Test
    func botanicalStylesProduceDistinctBroadGeometry() {
        let styles: [CardStyle] = [.pineShadow, .cedarShade, .fernTrace, .mossVeil]
        let signatures = styles.map {
            CatCardBotanicalPattern.signature(style: $0, patternSeed: 18)
        }

        #expect(Set(signatures).count == styles.count)

        for style in styles {
            let bounds = CatCardBotanicalPattern.normalizedBounds(style: style, patternSeed: 18)
            #expect(!bounds.isNull)
            #expect(bounds.width > 0.72)
            #expect(bounds.height > 0.72)
        }
    }

    @Test
    func mossPatternIsDenseDeterministicAndBroad() {
        let first = CatCardBotanicalPattern.commands(style: .mossVeil, patternSeed: 91)
        let repeated = CatCardBotanicalPattern.signature(style: .mossVeil, patternSeed: 91)
        let repeatedAgain = CatCardBotanicalPattern.signature(style: .mossVeil, patternSeed: 91)
        let bounds = CatCardBotanicalPattern.normalizedBounds(style: .mossVeil, patternSeed: 91)

        #expect(first.count > 60)
        #expect(repeated == repeatedAgain)
        #expect(bounds.width > 0.90)
        #expect(bounds.height > 0.90)
    }

    @Test
    func cardPatternSeedUsesStableSequenceContract() {
        #expect(CatCardPatternSeed.forSequence(1) == 1)
        #expect(CatCardPatternSeed.forSequence(4_271) == 4_271)
    }

    @Test
    func cardStyleFamiliesPartitionTheCatalog() {
        let groupedStyles = CardStyleFamily.allCases.flatMap(\.styles)

        #expect(CardStyleFamily.allCases.map(\.title) == ["Archive", "Contour", "Botanical", "Light"])
        #expect(groupedStyles.count == CardStyle.orderedCases.count)
        #expect(Set(groupedStyles) == Set(CardStyle.orderedCases))
        #expect(Set(groupedStyles).count == groupedStyles.count)
    }

    @Test
    func cardStyleRecommendationsLeadWithOneStylePerFamily() {
        let recommendations = CardStyleFamily.recommendedStyles

        #expect(recommendations == [.archive, .topoLagoon, .fernTrace, .cobaltHalo])
        #expect(recommendations.count == 4)
        #expect(Set(recommendations.map(\.family)) == Set(CardStyleFamily.allCases))
    }

    @Test
    func visibleCardStyleTitlesAvoidRetiredNames() {
        let titles = CardStyle.orderedCases.map(\.title)
        let retiredTitles = ["Porcelain Tile", "Rain Glass", "Lantern Glow"]

        for title in titles {
            #expect(title.range(of: "topo", options: .caseInsensitive) == nil)
            #expect(title.range(of: "topographic", options: .caseInsensitive) == nil)
        }

        for retiredTitle in retiredTitles {
            #expect(!titles.contains(retiredTitle))
        }
    }

    @Test
    func compactSequencesKeepsRemainingCardNumbersContiguous() {
        let first = makeRecord(sequence: 1)
        let third = makeRecord(sequence: 3)

        CatRecord.compactSequences([third, first])

        #expect(first.sequence == 1)
        #expect(third.sequence == 2)
    }

    @Test
    func unnamedCatsUseFriendlyNamePool() {
        #expect(CatNamePool.names.count == 130)
        #expect(Set(CatNamePool.names).count == 130)
        #expect(!CatNamePool.names.contains("Fresh Pawprint"))
        #expect(!CatNamePool.names.contains("Fresh Paw Print"))

        let record = CatRecord(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            sequence: 1,
            nickname: "",
            note: "",
            source: .camera,
            cardStyle: .archive,
            styleSeed: 0,
            originalImagePath: "id/original.heic",
            cutoutImagePath: "id/cutout.png",
            thumbnailImagePath: "id/thumbnail.png"
        )

        #expect(CatNamePool.names.contains(record.displayName))
        #expect(record.displayName != "Cat 1")
    }

    @Test
    func randomNameAvoidsExistingNamesWhenPossible() {
        let existingNames = Set(CatNamePool.names.dropLast())
        #expect(CatNamePool.randomName(excluding: existingNames) == CatNamePool.names.last)
    }

    @Test
    func recordPersistsMetadata() throws {
        let schema = Schema([CatRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let record = CatRecord(
            sequence: 4,
            nickname: "Local Cat",
            note: "Watched the ferry.",
            placeName: "Ferry Steps",
            placeDetail: "Beside the ticket booth",
            source: .photoLibrary,
            cardStyle: .sunstamp,
            styleSeed: 19,
            catBoundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5),
            originalImagePath: "id/original.heic",
            cutoutImagePath: "id/cutout.png",
            thumbnailImagePath: "id/thumbnail.png"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CatRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].displayName == "Local Cat")
        #expect(fetched[0].memoryPlaceName == "Ferry Steps")
        #expect(fetched[0].memoryPlaceDetail == "Beside the ticket booth")
        #expect(fetched[0].memoryPlaceLabel == "Ferry Steps, Beside the ticket booth")
        #expect(fetched[0].source == .photoLibrary)
        #expect(fetched[0].cardStyle == .sunstamp)
        #expect(fetched[0].catBoundingBox == CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5))
    }

    @Test
    func recordPlaceMemoryCanBeCleared() {
        let record = CatRecord(
            sequence: 7,
            nickname: "",
            note: "",
            placeName: "  Garden Wall  ",
            placeDetail: "  Afternoon sun  ",
            source: .camera,
            cardStyle: .archive,
            styleSeed: 0,
            originalImagePath: "id/original.heic",
            cutoutImagePath: "id/cutout.png",
            thumbnailImagePath: "id/thumbnail.png"
        )

        #expect(record.memoryPlaceName == "Garden Wall")
        #expect(record.memoryPlaceDetail == "Afternoon sun")
        record.placeName = "  "
        record.placeDetail = "\n"
        #expect(record.memoryPlaceName == nil)
        #expect(record.memoryPlaceDetail == nil)
        #expect(record.atlasGroupTitle == "Unplaced")
    }

    @Test
    func projectDoesNotRequestCoordinateLocationForAtlas() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectFile = repository
            .appendingPathComponent("CatLocal.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        let projectText = try String(contentsOf: projectFile, encoding: .utf8)
        #expect(!projectText.contains("NSLocation"))

        let sourceRoot = repository.appendingPathComponent("CatLocal")
        let sourcePaths = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }

        for path in sourcePaths {
            let text = try String(
                contentsOf: sourceRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            #expect(!text.contains("import CoreLocation"))
            #expect(!text.contains("import MapKit"))
        }
    }

    @Test @MainActor
    func imageStoreWritesExifFreeFilesAndDeletesThem() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CatImageStore(rootURL: root)
        let id = UUID()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }

        let paths = try await store.save(
            id: id,
            original: SendableImage(value: image),
            cutout: SendableImage(value: image)
        )

        #expect(paths.originalPath == "\(id.uuidString)/original.heic")
        #expect(paths.cutoutPath == "\(id.uuidString)/cutout.png")
        #expect(paths.thumbnailPath == "\(id.uuidString)/thumbnail.png")

        let originalData = try await store.data(at: paths.originalPath)
        let source = CGImageSourceCreateWithData(originalData as CFData, nil)
        let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let gps = properties?[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        #expect(exif?.isEmpty != false)
        #expect(gps?.isEmpty != false)

        try await store.deleteRecord(id: id)
        await #expect(throws: Error.self) {
            try await store.data(at: paths.originalPath)
        }
    }

    @Test @MainActor
    func imageStoreSanitizesRetainedOriginalMetadataAndOrientation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CatImageStore(rootURL: root)
        let id = UUID()
        let sourceImage = renderedImage(size: CGSize(width: 60, height: 40), opaque: true) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 15, height: 12))
        }
        let sourceData = try imageDataWithPrivateMetadata(from: sourceImage)
        let sourceProperties = try imageProperties(from: sourceData)
        #expect(sourceProperties[kCGImagePropertyExifDictionary] != nil)
        #expect(sourceProperties[kCGImagePropertyGPSDictionary] != nil)
        #expect(sourceProperties[kCGImagePropertyTIFFDictionary] != nil)
        #expect(sourceProperties[kCGImagePropertyIPTCDictionary] != nil)
        #expect((sourceProperties[kCGImagePropertyOrientation] as? NSNumber)?.intValue == 6)

        let importedImage = try #require(UIImage(data: sourceData))
        let paths = try await store.save(
            id: id,
            original: SendableImage(value: importedImage),
            cutout: SendableImage(value: importedImage)
        )

        let storedProperties = try imageProperties(from: await store.data(at: paths.originalPath))
        #expect(metadataDictionaryIsAbsentOrEmpty(storedProperties[kCGImagePropertyExifDictionary]))
        #expect(metadataDictionaryIsAbsentOrEmpty(storedProperties[kCGImagePropertyGPSDictionary]))
        #expect(metadataDictionaryIsAbsentOrEmpty(storedProperties[kCGImagePropertyIPTCDictionary]))
        let storedTIFF = storedProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(storedTIFF?[kCGImagePropertyTIFFMake] == nil)
        #expect(storedTIFF?[kCGImagePropertyTIFFModel] == nil)
        #expect(storedTIFF?[kCGImagePropertyTIFFSoftware] == nil)
        #expect(storedTIFF?[kCGImagePropertyTIFFDateTime] == nil)
        let storedOrientation = (storedProperties[kCGImagePropertyOrientation] as? NSNumber)?.intValue
        #expect(storedOrientation == nil || storedOrientation == 1)
        #expect((storedProperties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == 40)
        #expect((storedProperties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue == 60)
    }

    @Test @MainActor
    func imageStoreHardensFinalRecordDirectoryAndStoredFiles() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CatImageStore(rootURL: root)
        let id = UUID()
        let image = renderedImage(size: CGSize(width: 40, height: 40), opaque: true) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        _ = try await store.save(
            id: id,
            original: SendableImage(value: image),
            cutout: SendableImage(value: image)
        )

        let recordDirectory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        let backupValues = try recordDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(backupValues.isExcludedFromBackup == true)

        let protectedURLs = [
            recordDirectory,
            recordDirectory.appendingPathComponent("original.heic"),
            recordDirectory.appendingPathComponent("cutout.png"),
            recordDirectory.appendingPathComponent("thumbnail.png"),
        ]
        var reportedProtectionCount = 0
        for url in protectedURLs {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let rawProtection = attributes[.protectionKey] as? String {
                reportedProtectionCount += 1
                #expect(rawProtection == FileProtectionType.completeUntilFirstUserAuthentication.rawValue)
            }
        }
        #expect(reportedProtectionCount == 0 || reportedProtectionCount == protectedURLs.count)
    }

    @Test
    func imageStoreBackupExclusionReadbackReflectsFreshFilesystemState() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var settingURL = directory
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try settingURL.setResourceValues(resourceValues)

        #expect(try CatImageStore.backupExclusionIsEnabledOnDisk(at: directory))

        settingURL = URL(fileURLWithPath: directory.path, isDirectory: true)
        resourceValues.isExcludedFromBackup = false
        try settingURL.setResourceValues(resourceValues)
        #expect(try !CatImageStore.backupExclusionIsEnabledOnDisk(at: directory))
    }

    @Test
    func imageStoreRollbackErrorsSurfacePrimaryAndCleanupFailures() throws {
        let imageError = CatImageStoreError.imageSaveCleanupFailed(
            saveError: "backup verification failed",
            cleanupError: "permission denied"
        )
        let persistenceError = CatImageStoreError.persistenceSaveCleanupFailed(
            persistenceError: "database write failed",
            cleanupError: "directory removal failed"
        )

        let imageDescription = try #require(imageError.errorDescription)
        #expect(imageDescription.contains("backup verification failed"))
        #expect(imageDescription.contains("permission denied"))
        let persistenceDescription = try #require(persistenceError.errorDescription)
        #expect(persistenceDescription.contains("database write failed"))
        #expect(persistenceDescription.contains("directory removal failed"))
    }

    @Test @MainActor
    func imageStoreDeleteRecordRemovesEntireRecordDirectory() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CatImageStore(rootURL: root)
        let id = UUID()
        let image = renderedImage(size: CGSize(width: 40, height: 40), opaque: true) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        _ = try await store.save(
            id: id,
            original: SendableImage(value: image),
            cutout: SendableImage(value: image)
        )
        let recordDirectory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try Data("future associated file".utf8).write(
            to: recordDirectory.appendingPathComponent("future-variant.bin")
        )

        try await store.deleteRecord(id: id)

        #expect(!fileManager.fileExists(atPath: recordDirectory.path))
    }

    @Test
    func imageStoreCleanupRemovesOnlyOrphanedExactUUIDDirectories() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let validID = UUID()
        let orphanID = UUID()
        let temporaryName = "\(UUID().uuidString).tmp-\(UUID().uuidString)"
        let lowercaseUUIDName = UUID().uuidString.lowercased()
        let exactUUIDFileName = UUID().uuidString
        let preservedNames = [validID.uuidString, temporaryName, "notes", lowercaseUUIDName]

        for name in preservedNames + [orphanID.uuidString] {
            let directory = root.appendingPathComponent(name, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(name.utf8).write(to: directory.appendingPathComponent("original.heic"))
        }
        try Data("not a directory".utf8).write(
            to: root.appendingPathComponent(exactUUIDFileName)
        )

        let store = CatImageStore(rootURL: root)
        try await store.cleanupOrphanedDirectories(validRecordIDs: Set([validID]))

        #expect(fileManager.fileExists(atPath: root.appendingPathComponent(validID.uuidString).path))
        #expect(!fileManager.fileExists(atPath: root.appendingPathComponent(orphanID.uuidString).path))
        #expect(fileManager.fileExists(atPath: root.appendingPathComponent(temporaryName).path))
        #expect(fileManager.fileExists(atPath: root.appendingPathComponent("notes").path))
        #expect(fileManager.fileExists(atPath: root.appendingPathComponent(lowercaseUUIDName).path))
        #expect(fileManager.fileExists(atPath: root.appendingPathComponent(exactUUIDFileName).path))
    }

    @Test @MainActor
    func imageStoreCleanupPreservesCurrentProcessSaveAgainstStaleSnapshot() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let orphanID = UUID()
        let orphanDirectory = root.appendingPathComponent(orphanID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: orphanDirectory, withIntermediateDirectories: true)
        try Data("pre-existing original".utf8).write(
            to: orphanDirectory.appendingPathComponent("original.heic")
        )

        let store = CatImageStore(rootURL: root)
        let savedID = UUID()
        let image = renderedImage(size: CGSize(width: 40, height: 40), opaque: true) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        _ = try await store.save(
            id: savedID,
            original: SendableImage(value: image),
            cutout: SendableImage(value: image)
        )

        try await store.cleanupOrphanedDirectories(validRecordIDs: [])

        #expect(fileManager.fileExists(
            atPath: root.appendingPathComponent(savedID.uuidString).path
        ))
        #expect(!fileManager.fileExists(atPath: orphanDirectory.path))
    }

    @Test
    func imageStoreCleanupReportsEnumerationFailures() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data("root is a file".utf8).write(to: root)
        let store = CatImageStore(rootURL: root)

        await #expect(throws: Error.self) {
            try await store.cleanupOrphanedDirectories(validRecordIDs: [])
        }
    }

    @Test
    func imageStoreRejectsSiblingPrefixTraversal() async throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("Cats", isDirectory: true)
        let sibling = parent.appendingPathComponent("CatsBackup", isDirectory: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try Data("outside".utf8).write(to: sibling.appendingPathComponent("secret.txt"))

        let store = CatImageStore(rootURL: root)
        await expectInvalidStoredImagePath {
            _ = try await store.data(at: "../CatsBackup/secret.txt")
        }
    }

    @Test
    func imageStoreLoadsOnlyCanonicalStoredImageContracts() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let id = UUID()
        let recordDirectory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: recordDirectory, withIntermediateDirectories: true)

        let expected = Data("private cat image".utf8)
        for filename in ["original.heic", "cutout.png", "thumbnail.png"] {
            try expected.write(to: recordDirectory.appendingPathComponent(filename))
        }

        let store = CatImageStore(rootURL: root)
        #expect(try await store.data(at: "\(id.uuidString)/original.heic") == expected)
        #expect(try await store.data(at: "\(id.uuidString)/cutout.png") == expected)
        #expect(try await store.data(at: "\(id.uuidString)/thumbnail.png") == expected)
    }

    @Test
    func imageStoreRejectsMalformedStoredImageContracts() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let id = UUID()
        let recordDirectory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: recordDirectory, withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: recordDirectory.appendingPathComponent("original.heic"))
        try Data("unknown".utf8).write(to: recordDirectory.appendingPathComponent("preview.png"))

        let invalidRecordDirectory = root.appendingPathComponent("not-a-uuid", isDirectory: true)
        try fileManager.createDirectory(at: invalidRecordDirectory, withIntermediateDirectories: true)
        try Data("invalid UUID".utf8).write(
            to: invalidRecordDirectory.appendingPathComponent("original.heic")
        )

        let lowercaseID = UUID()
        let lowercaseRecordDirectory = root.appendingPathComponent(
            lowercaseID.uuidString.lowercased(),
            isDirectory: true
        )
        try fileManager.createDirectory(at: lowercaseRecordDirectory, withIntermediateDirectories: true)
        try Data("lowercase UUID".utf8).write(
            to: lowercaseRecordDirectory.appendingPathComponent("original.heic")
        )

        let store = CatImageStore(rootURL: root)
        let invalidPaths = [
            recordDirectory.appendingPathComponent("original.heic").path,
            "",
            "\(id.uuidString)",
            "\(id.uuidString)//original.heic",
            "\(id.uuidString)/./original.heic",
            "\(id.uuidString)/nested/../original.heic",
            "\(id.uuidString)/../\(id.uuidString)/original.heic",
            "not-a-uuid/original.heic",
            "\(lowercaseID.uuidString.lowercased())/original.heic",
            "\(id.uuidString)/preview.png",
        ]

        for invalidPath in invalidPaths {
            await expectInvalidStoredImagePath {
                _ = try await store.data(at: invalidPath)
            }
        }
    }

    @Test
    func imageStoreRejectsSymbolicLinkRecordDirectory() async throws {
        let fileManager = FileManager.default
        let parent = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: parent) }
        let root = parent.appendingPathComponent("Cats", isDirectory: true)
        let externalDirectory = parent.appendingPathComponent("External", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalDirectory, withIntermediateDirectories: true)
        try Data("outside".utf8).write(
            to: externalDirectory.appendingPathComponent("original.heic")
        )

        let id = UUID()
        try fileManager.createSymbolicLink(
            at: root.appendingPathComponent(id.uuidString, isDirectory: true),
            withDestinationURL: externalDirectory
        )

        let store = CatImageStore(rootURL: root)
        await expectInvalidStoredImagePath {
            _ = try await store.data(at: "\(id.uuidString)/original.heic")
        }
    }

    @Test
    func imageStoreRejectsSymbolicLinkStoredFile() async throws {
        let fileManager = FileManager.default
        let parent = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: parent) }
        let root = parent.appendingPathComponent("Cats", isDirectory: true)
        let id = UUID()
        let recordDirectory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        let externalFile = parent.appendingPathComponent("external.heic")
        try fileManager.createDirectory(at: recordDirectory, withIntermediateDirectories: true)
        try Data("outside".utf8).write(to: externalFile)
        try fileManager.createSymbolicLink(
            at: recordDirectory.appendingPathComponent("original.heic"),
            withDestinationURL: externalFile
        )

        let store = CatImageStore(rootURL: root)
        await expectInvalidStoredImagePath {
            _ = try await store.data(at: "\(id.uuidString)/original.heic")
        }
    }

    @Test
    func imageStoreRejectsSymbolicLinkStorageRoot() async throws {
        let fileManager = FileManager.default
        let parent = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: parent) }
        let externalRoot = parent.appendingPathComponent("ExternalCats", isDirectory: true)
        let linkedRoot = parent.appendingPathComponent("Cats", isDirectory: true)
        let id = UUID()
        let recordDirectory = externalRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: recordDirectory, withIntermediateDirectories: true)
        try Data("outside".utf8).write(
            to: recordDirectory.appendingPathComponent("original.heic")
        )
        try fileManager.createSymbolicLink(at: linkedRoot, withDestinationURL: externalRoot)

        let store = CatImageStore(rootURL: linkedRoot)
        await expectInvalidStoredImagePath {
            _ = try await store.data(at: "\(id.uuidString)/original.heic")
        }
    }

    private func expectInvalidStoredImagePath(
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected CatImageStoreError.invalidPath")
        } catch CatImageStoreError.invalidPath {
            // Expected containment rejection.
        } catch {
            Issue.record("Expected invalidPath, received \(error)")
        }
    }

    @Test @MainActor
    func imageStoreDownsamplesAndTrimsStoredImages() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CatImageStore(rootURL: root)
        let id = UUID()
        let original = renderedImage(size: CGSize(width: 2_400, height: 1_600), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 1_600))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 160, y: 160, width: 280, height: 240))
        }
        let cutout = renderedImage(size: CGSize(width: 1_000, height: 1_000), opaque: false) { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_000, height: 1_000))
            UIColor.black.setFill()
            context.fill(CGRect(x: 380, y: 330, width: 220, height: 260))
        }

        let paths = try await store.save(
            id: id,
            original: SendableImage(value: original),
            cutout: SendableImage(value: cutout)
        )

        let originalData = try await store.data(at: paths.originalPath)
        let cutoutData = try await store.data(at: paths.cutoutPath)
        let thumbnailData = try await store.data(at: paths.thumbnailPath)

        #expect(originalData.count < 1_500_000)
        #expect(cutoutData.count < 1_500_000)
        #expect(thumbnailData.count < 250_000)
        #expect(try imagePixelSize(from: originalData).width <= CatImageStore.originalMaximumDimension)
        #expect(try imagePixelSize(from: thumbnailData).width <= CatImageStore.thumbnailMaximumDimension)

        let cutoutSize = try imagePixelSize(from: cutoutData)
        #expect(cutoutSize.width < 340)
        #expect(cutoutSize.height < 380)
    }

    @Test
    func dustRevealGeometryAspectFitsPortraitImages() {
        let rect = DustRevealGeometry.imageRect(
            imageSize: CGSize(width: 3, height: 4),
            containerSize: CGSize(width: 400, height: 300)
        )

        #expect(rect == CGRect(x: 87.5, y: 0, width: 225, height: 300))
    }

    @Test
    func dustRevealGeometryAspectFitsLandscapeImages() {
        let rect = DustRevealGeometry.imageRect(
            imageSize: CGSize(width: 16, height: 9),
            containerSize: CGSize(width: 300, height: 400)
        )

        #expect(rect == CGRect(x: 0, y: 115.625, width: 300, height: 168.75))
    }

    @Test
    func dustRevealGeometryAspectFitsSquareImages() {
        let rect = DustRevealGeometry.imageRect(
            imageSize: CGSize(width: 1, height: 1),
            containerSize: CGSize(width: 390, height: 844)
        )

        #expect(rect == CGRect(x: 0, y: 227, width: 390, height: 390))
    }

    @Test
    func dustRevealGeometryCentersInsideRetinaDrawablePixels() {
        let rect = DustRevealGeometry.imageRect(
            imageSize: CGSize(width: 3000, height: 4000),
            containerSize: CGSize(width: 1170, height: 2532)
        )

        #expect(rect == CGRect(x: 0, y: 486, width: 1170, height: 1560))
        #expect(rect.midX == 585)
        #expect(rect.midY == 1266)
    }

    @Test
    func dustRevealEffectIsConfinedToAspectFitImageRect() {
        let rect = DustRevealGeometry.imageRect(
            imageSize: CGSize(width: 1600, height: 900),
            containerSize: CGSize(width: 390, height: 844)
        )

        #expect(DustRevealGeometry.containsEffectPoint(
            CGPoint(x: rect.midX, y: rect.midY),
            imageRect: rect
        ))
        #expect(!DustRevealGeometry.containsEffectPoint(
            CGPoint(x: rect.midX, y: rect.minY - 1),
            imageRect: rect
        ))
        #expect(!DustRevealGeometry.containsEffectPoint(
            CGPoint(x: rect.midX, y: rect.maxY + 1),
            imageRect: rect
        ))
    }

    @Test
    func dustRevealTimelineClampsAndCompletesAtDuration() {
        #expect(DustRevealTimeline.progress(elapsed: -1, duration: 2.6) == 0)
        #expect(DustRevealTimeline.progress(elapsed: 1.3, duration: 2.6) == 0.5)
        #expect(DustRevealTimeline.progress(elapsed: 3.0, duration: 2.6) == 1)
        #expect(!DustRevealTimeline.isComplete(elapsed: 2.59, duration: 2.6))
        #expect(DustRevealTimeline.isComplete(elapsed: 2.6, duration: 2.6))
    }

    @Test
    func dustRevealAlphaProvidesContinuousInverseWeight() {
        #expect(DustRevealAlpha.inverseWeight(alpha: 0) == 1)
        #expect(DustRevealAlpha.inverseWeight(alpha: 0.5) == 0.5)
        #expect(DustRevealAlpha.inverseWeight(alpha: 1) == 0)
    }

    @Test
    func dustBlendMathProducesPremultipliedBackgroundAndParticles() {
        let background = DustRevealBlend.backgroundOutput(
            premultipliedSource: SIMD4(0.24, 0.12, 0.06, 0.30),
            survival: 0.5
        )
        let particle = DustRevealBlend.particleOutput(
            straightRGB: SIMD3(0.8, 0.4, 0.2),
            sourceAlpha: 0.5,
            particleAlpha: 0.25
        )

        #expect(background == SIMD4(0.12, 0.06, 0.03, 0.15))
        #expect(particle == SIMD4(0.1, 0.05, 0.025, 0.125))
    }

    @Test
    func dustProtectionUsesSoftWeightsAndRequiresRealBackgroundContent() {
        #expect(DustSubjectProtection.weight(maskValue: 0) == 0)
        #expect(DustSubjectProtection.weight(maskValue: 1) == 1)
        let softEdge = DustSubjectProtection.weight(maskValue: 0.35)
        #expect(softEdge > 0 && softEdge < 1)

        #expect(DustParticleEligibility.contribution(
            background: SIMD4(0.20, 0.10, 0.05, 0.40),
            subjectProtection: 0
        ) == 1)
        #expect(DustParticleEligibility.contribution(
            background: .zero,
            subjectProtection: 0
        ) == 0)
        let partialContribution = DustParticleEligibility.contribution(
            background: SIMD4(0.20, 0.10, 0.05, 0.40),
            subjectProtection: softEdge
        )
        #expect(partialContribution > 0 && partialContribution < 1)
        #expect(abs(partialContribution - (1 - softEdge)) < 0.000_001)
    }

    @Test
    func dustRevealErosionUsesOneContinuousDirectionalFront() {
        let earlyThreshold = DustRevealDissolve.erosionThreshold(
            noise: 0.5,
            horizontalPosition: 0,
            verticalPosition: 1
        )
        let middleThreshold = DustRevealDissolve.erosionThreshold(
            noise: 0.5,
            horizontalPosition: 0.5,
            verticalPosition: 0.5
        )
        let lateThreshold = DustRevealDissolve.erosionThreshold(
            noise: 0.5,
            horizontalPosition: 1,
            verticalPosition: 0
        )
        let nearbyNoiseThreshold = DustRevealDissolve.erosionThreshold(
            noise: 0.55,
            horizontalPosition: 0.5,
            verticalPosition: 0.5
        )

        #expect(earlyThreshold < middleThreshold)
        #expect(middleThreshold < lateThreshold)
        #expect(earlyThreshold < lateThreshold)
        #expect(lateThreshold - earlyThreshold > 0.7)
        #expect(abs(nearbyNoiseThreshold - middleThreshold) < 0.02)
        #expect(DustRevealDissolve.survival(progress: 0, threshold: 0.5) == 1)
        #expect(DustRevealDissolve.survival(progress: 1, threshold: 0.5) == 0)
        #expect(DustRevealDissolve.sourceSurvival(
            progress: 1,
            noise: 0.5,
            horizontalPosition: 0.5,
            verticalPosition: 0.5
        ) == 0)
        #expect(DustRevealDissolve.survival(progress: 0.5, threshold: 0.8)
            > DustRevealDissolve.survival(progress: 0.5, threshold: 0.2))

        for alpha in [0.0, 0.5, 1.0] {
            #expect(DustRevealDissolve.combinedAlpha(
                cutoutAlpha: alpha,
                progress: 0,
                noise: 0.5
            ) == 1)
            #expect(DustRevealDissolve.combinedAlpha(
                cutoutAlpha: alpha,
                progress: 1,
                noise: 0.5
            ) == alpha)
        }
    }

    @Test
    func dustParticlesEmitThroughoutRevealAndEndWithTheTimeline() {
        #expect(DustParticleTimeline.age(progress: 0.2, emissionThreshold: 0.3) == 0)
        #expect(DustParticleTimeline.age(progress: 0.45, emissionThreshold: 0.3) > 0)
        #expect(DustParticleTimeline.age(progress: 0.9, emissionThreshold: 0.3) < 1)
        #expect(DustParticleTimeline.age(progress: 1, emissionThreshold: 0.3) == 1)
        #expect(DustParticleTimeline.age(progress: 0.96, emissionThreshold: 0.94) > 0)
        #expect(DustParticleTimeline.age(progress: 1, emissionThreshold: 0.94) == 1)
    }

    @Test
    func dustParticleDepthMotionGrowsForwardAndFadesBeforeMaximumScale() {
        let early = DustParticleMotion.sample(
            textureCoordinate: SIMD2(0.5, 0.5),
            age: 0.18,
            directionSeed: 0.25,
            depthSeed: 0.5,
            basePointSize: 8,
            imageAspectRatio: 1
        )
        let late = DustParticleMotion.sample(
            textureCoordinate: SIMD2(0.5, 0.5),
            age: 0.82,
            directionSeed: 0.25,
            depthSeed: 0.5,
            basePointSize: 8,
            imageAspectRatio: 1
        )
        let maximum = DustParticleMotion.sample(
            textureCoordinate: SIMD2(0.5, 0.5),
            age: 1,
            directionSeed: 0.25,
            depthSeed: 0.5,
            basePointSize: 8,
            imageAspectRatio: 1
        )

        #expect(early.forwardProgress < late.forwardProgress)
        #expect(early.pointSize < late.pointSize)
        #expect(late.pointSize < maximum.pointSize)
        #expect(maximum.pointSize >= 8 * 1.8)
        #expect(maximum.pointSize <= 8 * 2.4)
        #expect(maximum.pointSize <= DustParticleMotion.maximumPointSize)
        #expect(late.opacity > 0)
        #expect(DustParticleMotion.opacity(age: 0) == 0)
        #expect(DustParticleMotion.opacity(age: 0.10) > DustParticleMotion.opacity(age: 0.02))
        #expect(DustParticleMotion.opacity(age: DustParticleMotion.fadeEndAge) == 0)
        #expect(!DustParticleMotion.isExpired(age: DustParticleMotion.fadeEndAge - 0.001))
        #expect(DustParticleMotion.isExpired(age: DustParticleMotion.fadeEndAge))
        #expect(DustParticleMotion.isExpired(age: 1))
    }

    @Test
    func dustParticleLateralMotionHasNoSharedScreenDirection() {
        let sampleCount = 4_096
        var accumulatedOffset = SIMD2<Double>.zero
        var positiveX = 0
        var positiveY = 0

        for index in 0..<sampleCount {
            let directionSeed = (Double(index) + 0.5) / Double(sampleCount)
            let depthSeed = Double((index * 2_653) % sampleCount) / Double(sampleCount)
            let sample = DustParticleMotion.sample(
                textureCoordinate: SIMD2(0.5, 0.5),
                age: 0.75,
                directionSeed: directionSeed,
                depthSeed: depthSeed,
                basePointSize: 8,
                imageAspectRatio: 1
            )
            let offset = sample.textureCoordinate - SIMD2(0.5, 0.5)
            accumulatedOffset += offset
            positiveX += offset.x > 0 ? 1 : 0
            positiveY += offset.y > 0 ? 1 : 0
        }

        let meanOffset = accumulatedOffset / Double(sampleCount)
        #expect(abs(meanOffset.x) < 0.000_05)
        #expect(abs(meanOffset.y) < 0.000_05)
        #expect(abs(positiveX - sampleCount / 2) <= 2)
        #expect(abs(positiveY - sampleCount / 2) <= 2)
    }

    @Test
    func dustParticlePerspectiveExpansionIsAspectCorrectAndRestrained() {
        let coordinate = SIMD2<Double>(0.72, 0.64)
        let aspectRatio = 2.0
        let sample = DustParticleMotion.sample(
            textureCoordinate: coordinate,
            age: 0.7,
            directionSeed: 0,
            depthSeed: 0.5,
            basePointSize: 8,
            imageAspectRatio: aspectRatio,
            lateralVariation: 0
        )
        let originalCentered = SIMD2(
            (coordinate.x * 2 - 1) * aspectRatio,
            coordinate.y * 2 - 1
        )
        let expandedCentered = SIMD2(
            (sample.textureCoordinate.x * 2 - 1) * aspectRatio,
            sample.textureCoordinate.y * 2 - 1
        )
        let xScale = expandedCentered.x / originalCentered.x
        let yScale = expandedCentered.y / originalCentered.y

        #expect(abs(xScale - yScale) < 0.000_001)
        #expect(xScale > 1)
        #expect(xScale <= 1 + DustParticleMotion.maximumPerspectiveExpansion)
    }

    @Test
    func dustParticleDepthMotionIsDeterministicClampedAndFinite() {
        let first = DustParticleMotion.sample(
            textureCoordinate: SIMD2(0.2, 0.8),
            age: 4,
            directionSeed: -2,
            depthSeed: 9,
            basePointSize: 100,
            imageAspectRatio: 0
        )
        let second = DustParticleMotion.sample(
            textureCoordinate: SIMD2(0.2, 0.8),
            age: 4,
            directionSeed: -2,
            depthSeed: 9,
            basePointSize: 100,
            imageAspectRatio: 0
        )

        #expect(first == second)
        #expect(first.forwardProgress >= 0 && first.forwardProgress <= 1)
        #expect(first.pointSize == DustParticleMotion.maximumPointSize)
        #expect(first.textureCoordinate.x.isFinite)
        #expect(first.textureCoordinate.y.isFinite)
        #expect(first.opacity == 0)
    }

    @Test
    func dustParticleDensityIsCappedButVisiblyDense() {
        #expect(DustRendererResourcePreparer.adaptiveParticleCount(pixelCount: 100) == 90_000)
        #expect(DustRendererResourcePreparer.adaptiveParticleCount(pixelCount: 800_000) == 133_333)
        #expect(DustRendererResourcePreparer.adaptiveParticleCount(pixelCount: 20_000_000) == 180_000)
    }

    @Test
    func dustRevealFallbackUsesOnlyRemainingSourceContribution() {
        #expect(DustRevealFallback.remainingSourceContribution(progress: -1) == 1)
        #expect(DustRevealFallback.remainingSourceContribution(progress: 0) == 1)
        #expect(DustRevealFallback.remainingSourceContribution(progress: 0.75) == 0.25)
        #expect(DustRevealFallback.remainingSourceContribution(progress: 1) == 0)
        #expect(DustRevealFallback.remainingSourceContribution(progress: 2) == 0)
    }

    @Test
    func dustRevealFallbackCompletesImmediatelyWhenNothingRemainsToFade() {
        #expect(DustRevealFallback.action(remainingSourceContribution: 0.25) == .crossfade)
        #expect(DustRevealFallback.action(remainingSourceContribution: 0) == .completeImmediately)
        #expect(DustRevealFallback.action(remainingSourceContribution: -0.1) == .completeImmediately)
    }

    @Test
    func dustRevealPreparationGateRejectsCancelledAndLateResults() {
        var gate = DustRevealPreparationGate()
        let cancelled = gate.begin()

        gate.cancel()

        let acceptedCancelled = gate.consume(cancelled)
        #expect(!acceptedCancelled)

        let current = gate.begin()
        let acceptedCurrent = gate.consume(current)
        let acceptedCurrentAgain = gate.consume(current)
        #expect(current != cancelled)
        #expect(acceptedCurrent)
        #expect(!acceptedCurrentAgain)
    }

    @Test
    func dustRevealPresentationStartsOnOriginalWithoutRawCutout() {
        let state = DustRevealPresentationState()

        #expect(state.showsSourcePlaceholder)
        #expect(!state.showsRawCutout)
    }

    @Test
    func dustRevealPresentationSwapsAtomicallyAfterFirstFrame() {
        var state = DustRevealPresentationState()

        let accepted = state.presentFirstFrame()

        #expect(accepted)
        #expect(!state.showsSourcePlaceholder)
        #expect(state.showsRawCutout)
    }

    @Test
    func dustRevealPresentationIgnoresLateFirstFrameAfterCancellation() {
        var state = DustRevealPresentationState()

        state.cancel()
        let accepted = state.presentFirstFrame()

        #expect(!accepted)
        #expect(!state.showsSourcePlaceholder)
        #expect(!state.showsRawCutout)
    }

    @Test
    func dustFirstFrameGateResolvesAfterSuccessThenPresentation() {
        let gate = DustFirstFramePresentationGate()

        #expect(!gate.commandCompleted(succeeded: true))
        #expect(gate.drawablePresented())
    }

    @Test
    func dustFirstFrameGateResolvesAfterPresentationThenSuccess() {
        let gate = DustFirstFramePresentationGate()

        #expect(!gate.drawablePresented())
        #expect(gate.commandCompleted(succeeded: true))
    }

    @Test
    func dustFirstFrameGateRejectsCommandFailure() {
        let gate = DustFirstFramePresentationGate()

        #expect(!gate.commandCompleted(succeeded: false))
        #expect(!gate.drawablePresented())
        #expect(!gate.commandCompleted(succeeded: true))
    }

    @Test
    func dustFirstFrameGateIgnoresDuplicateCallbacks() {
        let gate = DustFirstFramePresentationGate()

        #expect(!gate.drawablePresented())
        #expect(!gate.drawablePresented())
        #expect(gate.commandCompleted(succeeded: true))
        #expect(!gate.commandCompleted(succeeded: true))
        #expect(!gate.drawablePresented())
    }

    @Test
    func dustFirstFrameGateIgnoresCallbacksAfterCancellation() {
        let gate = DustFirstFramePresentationGate()

        gate.cancel()

        #expect(!gate.drawablePresented())
        #expect(!gate.commandCompleted(succeeded: true))
    }

    @Test
    func dustCommandTrackerWaitsForEarlierFailureBeforeTerminalSuccess() throws {
        let tracker = DustCommandCompletionTracker()
        let earlier = try #require(tracker.submit(isTerminalFrame: false))
        let terminal = try #require(tracker.submit(isTerminalFrame: true))

        #expect(tracker.complete(
            submission: terminal,
            succeeded: true,
            errorDescription: nil
        ) == nil)
        #expect(tracker.complete(
            submission: earlier,
            succeeded: false,
            errorDescription: "Earlier GPU failure"
        ) == .fallback("Earlier GPU failure"))
    }

    @Test
    func dustCommandTrackerFinishesAfterEveryTerminalSubmissionSucceeds() throws {
        let tracker = DustCommandCompletionTracker()
        let earlier = try #require(tracker.submit(isTerminalFrame: false))
        let terminal = try #require(tracker.submit(isTerminalFrame: true))

        #expect(tracker.complete(
            submission: terminal,
            succeeded: true,
            errorDescription: nil
        ) == nil)
        #expect(tracker.complete(
            submission: earlier,
            succeeded: true,
            errorDescription: nil
        ) == .finish)
    }

    @Test
    func dustCommandTrackerIgnoresLateCompletionAfterCancellation() throws {
        let tracker = DustCommandCompletionTracker()
        let terminal = try #require(tracker.submit(isTerminalFrame: true))

        tracker.cancel()

        #expect(tracker.complete(
            submission: terminal,
            succeeded: false,
            errorDescription: "Late GPU failure"
        ) == nil)
        #expect(tracker.submit(isTerminalFrame: false) == nil)
    }

    @Test
    func dustRendererTerminalGateAcceptsExactlyOneTerminalOutcome() {
        let completed = DustRendererTerminalGate()
        #expect(completed.state == .active)
        #expect(completed.resolve(.completed))
        #expect(completed.state == .completed)
        #expect(!completed.resolve(.failed))
        #expect(!completed.resolve(.cancelled))

        let cancelled = DustRendererTerminalGate()
        #expect(cancelled.resolve(.cancelled))
        #expect(!cancelled.resolve(.completed))
        #expect(cancelled.state == .cancelled)
    }

    @Test
    func dustRendererClockStartsOnceOnTheFirstDrawable() throws {
        var clock = DustRendererClock()

        #expect(clock.progress(at: 10, hasDrawable: false, duration: 0.72) == nil)
        #expect(clock.progress(at: 20, hasDrawable: true, duration: 0.72) == 0)
        let sampledProgress = clock.progress(at: 20.36, hasDrawable: true, duration: 0.72)
        guard let middleProgress = sampledProgress else {
            Issue.record("Expected progress after the first drawable")
            return
        }
        #expect(middleProgress > 0.49)
        #expect(middleProgress < 0.51)
        #expect(clock.startedAt == 20)
    }

    @Test
    func dustRevealGeometryRequiresMatchingOriginalAndCutoutDimensions() {
        #expect(DustRevealGeometry.imagesAreAligned(
            originalSize: CGSize(width: 1200, height: 1600),
            cutoutSize: CGSize(width: 1200, height: 1600)
        ))
        #expect(!DustRevealGeometry.imagesAreAligned(
            originalSize: CGSize(width: 1200, height: 1600),
            cutoutSize: CGSize(width: 600, height: 800)
        ))
    }

    @Test
    func detectionResolutionCoversEmptySingleAndMultipleResults() {
        let low = CatDetection(
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            confidence: 0.55
        )
        let high = CatDetection(
            boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.3, height: 0.4),
            confidence: 0.91
        )

        #expect(CatDetectionSelector.resolve([]) == .none)
        #expect(CatDetectionSelector.resolve([low]) == .single(low))
        #expect(CatDetectionSelector.resolve([low, high]) == .multiple([high, low]))
    }

    @Test
    func visionDetectionFilterUsesNamedMinimumConfidence() {
        let below = CatDetection(
            boundingBox: CGRect(x: 0, y: 0, width: 0.2, height: 0.2),
            confidence: 0.549
        )
        let boundary = CatDetection(
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
            confidence: 0.55
        )
        let high = CatDetection(
            boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
            confidence: 0.91
        )

        #expect(CatVisionProcessor.minimumDetectionConfidence == 0.55)
        #expect(CatVisionProcessor.confidentDetections([boundary, below, high]) == [high, boundary])
    }

    @Test
    func catSelectionOverlayMapsVisionBoundsIntoAspectFitImage() {
        let overlayRect = CatSelectionOverlayLayout.rect(
            for: CGRect(x: 0.25, y: 0.6, width: 0.5, height: 0.2),
            imageSize: CGSize(width: 400, height: 200),
            containerSize: CGSize(width: 300, height: 300)
        )
        let tolerance: CGFloat = 0.000_001

        #expect(abs(overlayRect.minX - 75) < tolerance)
        #expect(abs(overlayRect.minY - 105) < tolerance)
        #expect(abs(overlayRect.width - 150) < tolerance)
        #expect(abs(overlayRect.height - 30) < tolerance)
    }

    @Test
    func captureProcessingGateIgnoresStaleCompletionAfterCancelAndRetry() throws {
        var gate = CaptureProcessingSessionGate()
        let firstSessionValue = gate.begin()
        let firstSession = try #require(firstSessionValue)

        gate.cancel()
        let retrySessionValue = gate.begin()
        let retrySession = try #require(retrySessionValue)
        let staleSessionFinished = gate.finish(firstSession)

        #expect(!staleSessionFinished)
        #expect(gate.isCurrent(retrySession))
        let retrySessionFinished = gate.finish(retrySession)
        #expect(retrySessionFinished)
        #expect(!gate.isActive)
    }

    @Test
    func replacementGalleryImportWinsAndStaleCompletionCannotReleaseItsGate() throws {
        var gate = CaptureProcessingSessionGate()
        let firstValue = gate.start(.gallery)
        let first = try #require(firstValue)
        let replacementValue = gate.start(.gallery)
        let replacement = try #require(replacementValue)

        #expect(replacement.replacedSessionID == first.sessionID)
        #expect(!gate.isCurrent(first.sessionID))
        #expect(gate.isCurrent(replacement.sessionID))
        let staleFinished = gate.finish(first.sessionID)
        #expect(!staleFinished)
        #expect(gate.isActive)
        let replacementFinished = gate.finish(replacement.sessionID)
        #expect(replacementFinished)
        #expect(!gate.isActive)
    }

    @Test
    func cameraCaptureWinsOverAnOlderGalleryImport() throws {
        var gate = CaptureProcessingSessionGate()
        let galleryValue = gate.start(.gallery)
        let gallery = try #require(galleryValue)
        let cameraValue = gate.start(.camera)
        let camera = try #require(cameraValue)

        #expect(camera.replacedSessionID == gallery.sessionID)
        #expect(!gate.isCurrent(gallery.sessionID))
        #expect(gate.isCurrent(camera.sessionID))
        #expect(!gate.canStart(.gallery))
    }

    @Test
    func galleryCompletionDecisionIgnoresCancellationAndStaleResults() {
        #expect(CaptureGalleryCompletionDecision.resolve(
            outcome: .success,
            isCurrentSession: false
        ) == .ignore)
        #expect(CaptureGalleryCompletionDecision.resolve(
            outcome: .cancelled,
            isCurrentSession: true
        ) == .ignore)
        #expect(CaptureGalleryCompletionDecision.resolve(
            outcome: .failure,
            isCurrentSession: false
        ) == .ignore)
    }

    @Test
    func currentGalleryFailureShowsRecoveryWhileSuccessCanApply() {
        #expect(CaptureGalleryCompletionDecision.resolve(
            outcome: .success,
            isCurrentSession: true
        ) == .apply)
        #expect(CaptureGalleryCompletionDecision.resolve(
            outcome: .failure,
            isCurrentSession: true
        ) == .showRecovery)
    }

    @Test
    func visionCutoutUsesMaskLuminanceForTransparency() async throws {
        let original = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let mask = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
            UIColor.white.setFill()
            context.fill(CGRect(x: 24, y: 24, width: 32, height: 32))
        }

        let processor = CatVisionProcessor()
        let cutout = try await processor.makeTransparentCutout(
            from: try #require(original.cgImage),
            mask: CIImage(cgImage: try #require(mask.cgImage))
        )

        #expect(processor.hasVisibleSubjectAndTransparentBackground(cutout))
        #expect(try alphaValue(in: cutout, x: 4, y: 4) == 0)
        #expect(try alphaValue(in: cutout, x: 40, y: 40) > 200)
    }

    @Test
    func visionCutoutPreservesNamedDisplayP3InsteadOfProducingDeviceRGB() async throws {
        let displayP3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let original = try solidCGImage(
            size: CGSize(width: 80, height: 80),
            colorSpace: displayP3
        )
        let mask = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
            UIColor.white.setFill()
            context.fill(CGRect(x: 24, y: 24, width: 32, height: 32))
        }
        let processor = CatVisionProcessor()

        let cutout = try await processor.makeTransparentCutout(
            from: original,
            mask: CIImage(cgImage: try #require(mask.cgImage))
        )

        #expect(cutout.colorSpace?.name == displayP3.name)
        #expect(cutout.colorSpace?.name != CGColorSpaceCreateDeviceRGB().name)
        #expect(
            try rgbaValue(in: cutout, x: 40, y: 40, colorSpace: displayP3)
                == rgbaValue(in: original, x: 40, y: 40, colorSpace: displayP3)
        )
    }

    @Test
    func visionCutoutPreservesPawsBeyondDetectionBounds() async throws {
        let original = renderedImage(size: CGSize(width: 100, height: 100), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let mask = try oneComponentMask(
            size: CGSize(width: 100, height: 100),
            visibleRects: [
                CGRect(x: 35, y: 25, width: 30, height: 40),
                CGRect(x: 37, y: 65, width: 11, height: 18),
                CGRect(x: 52, y: 65, width: 11, height: 18)
            ]
        )
        let processor = CatVisionProcessor()

        let cutout = try await processor.makeTransparentCutout(
            from: try #require(original.cgImage),
            mask: CIImage(cvPixelBuffer: mask)
        )

        #expect(try alphaValue(in: cutout, x: 42, y: 75) > 200)
        #expect(try alphaValue(in: cutout, x: 57, y: 75) > 200)
        #expect(try alphaValue(in: cutout, x: 10, y: 90) == 0)
    }

    @Test
    func visionInstancePointMappingUsesExactTopLeftMaskPixel() {
        #expect(InstanceMaskPointMapping.pixelCoordinate(
            at: CGPoint(x: 0.26, y: 0.34),
            width: 4,
            height: 3
        ) == InstanceMaskPixelCoordinate(x: 1, y: 1))
        #expect(InstanceMaskPointMapping.pixelCoordinate(
            at: CGPoint(x: 0.51, y: 0.68),
            width: 4,
            height: 3
        ) == InstanceMaskPixelCoordinate(x: 2, y: 2))
    }

    @Test
    func visionInstancePointMappingRejectsOutsidePointsAndInvalidMasks() {
        #expect(InstanceMaskPointMapping.pixelCoordinate(
            at: CGPoint(x: -0.01, y: 0.5),
            width: 2,
            height: 2
        ) == nil)
        #expect(InstanceMaskPointMapping.pixelCoordinate(
            at: CGPoint(x: 1, y: 0.5),
            width: 2,
            height: 2
        ) == nil)
        #expect(InstanceMaskPointMapping.pixelCoordinate(
            at: CGPoint(x: 0.5, y: 1),
            width: 2,
            height: 2
        ) == nil)
        #expect(InstanceMaskPointMapping.pixelCoordinate(
            at: CGPoint(x: 0.5, y: 0.5),
            width: 0,
            height: 2
        ) == nil)
    }

    @Test
    func visionInstanceLabelDecoderAcceptsOnlyAvailableNonzeroUInt8Labels() {
        let available = IndexSet([3, 7])

        #expect(InstanceMaskLabelDecoder.label(from: UInt8(0), availableInstances: available) == nil)
        #expect(InstanceMaskLabelDecoder.label(from: UInt8(7), availableInstances: available) == 7)
        #expect(InstanceMaskLabelDecoder.label(from: UInt8(4), availableInstances: available) == nil)
    }

    @Test
    func visionInstanceLabelDecoderRejectsInvalidFloatLabels() {
        let available = IndexSet([3, 7])

        #expect(InstanceMaskLabelDecoder.label(from: Float(3), availableInstances: available) == 3)
        #expect(InstanceMaskLabelDecoder.label(from: Float(3.25), availableInstances: available) == nil)
        #expect(InstanceMaskLabelDecoder.label(from: Float.nan, availableInstances: available) == nil)
        #expect(InstanceMaskLabelDecoder.label(from: Float(0), availableInstances: available) == nil)
        #expect(InstanceMaskLabelDecoder.label(from: Float(9), availableInstances: available) == nil)
    }

    @Test
    func visionInstanceLabelDecoderRecognizesOnlySupportedMaskFormats() {
        #expect(InstanceMaskLabelDecoder.encoding(
            for: kCVPixelFormatType_OneComponent8
        ) == .oneComponent8)
        #expect(InstanceMaskLabelDecoder.encoding(
            for: kCVPixelFormatType_OneComponent32Float
        ) == .oneComponent32Float)
        #expect(InstanceMaskLabelDecoder.encoding(
            for: kCVPixelFormatType_32BGRA
        ) == nil)
    }

    @Test
    func foregroundSelectionAccessibilityUsesOnlyTheExactImageCenter() {
        #expect(ForegroundSelectionAccessibility.defaultNormalizedPoint == CGPoint(x: 0.5, y: 0.5))
    }

    @Test
    func visionCutoutRejectsWholeRectangleMask() async throws {
        let original = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let mask = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }

        let processor = CatVisionProcessor()
        await #expect(throws: CatVisionError.self) {
            _ = try await processor.makeTransparentCutout(
                from: try #require(original.cgImage),
                mask: CIImage(cgImage: try #require(mask.cgImage))
            )
        }
    }

    @Test
    func liveInteractiveCardTiltClampsAndDetectsLimit() {
        let size = CGSize(width: 350, height: 220)
        let center = LiveInteractiveCardMath.tilt(
            for: CGPoint(x: 175, y: 110),
            in: size,
            maxTiltAngle: 12
        )
        #expect(center.rotateX == 0)
        #expect(center.rotateY == 0)
        #expect(center.isAtLimit == false)

        let edge = LiveInteractiveCardMath.tilt(
            for: CGPoint(x: 350, y: 0),
            in: size,
            maxTiltAngle: 12
        )
        #expect(edge.rotateX == 12)
        #expect(edge.rotateY == 12)
        #expect(edge.isAtLimit)

        let outOfBounds = LiveInteractiveCardMath.tilt(
            for: CGPoint(x: 700, y: -220),
            in: size,
            maxTiltAngle: 12
        )
        #expect(outOfBounds.location == CGPoint(x: 350, y: 0))
        #expect(outOfBounds.rotateX == 12)
        #expect(outOfBounds.rotateY == 12)
        #expect(outOfBounds.isAtLimit)
    }

    @Test
    func liveInteractiveCardLightingPositionsExposeVoiceOverValues() {
        #expect(LiveInteractiveCardLightingPosition.left.accessibilityValue == "Light left")
        #expect(LiveInteractiveCardLightingPosition.center.accessibilityValue == "Light centered")
        #expect(LiveInteractiveCardLightingPosition.right.accessibilityValue == "Light right")
    }

    @Test
    func liveInteractiveCardLightingAdjustmentsMoveOnePositionAtATime() {
        #expect(LiveInteractiveCardLightingPosition.center.movingLeft() == .left)
        #expect(LiveInteractiveCardLightingPosition.left.movingLeft() == nil)
        #expect(LiveInteractiveCardLightingPosition.left.movingRight() == .center)
        #expect(LiveInteractiveCardLightingPosition.center.movingRight() == .right)
        #expect(LiveInteractiveCardLightingPosition.right.movingRight() == nil)
    }

    private func makeRecord(sequence: Int) -> CatRecord {
        CatRecord(
            id: UUID(),
            sequence: sequence,
            capturedAt: Date(timeIntervalSinceReferenceDate: TimeInterval(sequence)),
            nickname: "Cat \(sequence)",
            note: "",
            source: .camera,
            cardStyle: .archive,
            styleSeed: 0,
            originalImagePath: "\(sequence)/original.heic",
            cutoutImagePath: "\(sequence)/cutout.png",
            thumbnailImagePath: "\(sequence)/thumbnail.png"
        )
    }

    private func renderedImage(
        size: CGSize,
        opaque: Bool,
        actions: (CGContext) -> Void
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = opaque
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            actions(context.cgContext)
        }
    }

    private func imagePixelSize(from data: Data) throws -> CGSize {
        let source = CGImageSourceCreateWithData(data as CFData, nil)
        let properties = source.flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        }
        guard
            let width = properties?[kCGImagePropertyPixelWidth] as? Int,
            let height = properties?[kCGImagePropertyPixelHeight] as? Int
        else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return CGSize(width: width, height: height)
    }

    private func imageProperties(from data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
    }

    private func metadataDictionaryIsAbsentOrEmpty(_ value: Any?) -> Bool {
        guard let value else { return true }
        return (value as? [CFString: Any])?.isEmpty == true
    }

    private func imageDataWithPrivateMetadata(from image: UIImage) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw CatImageStoreError.imageEncodingFailed
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:07:15 12:00:00",
                kCGImagePropertyExifLensModel: "Private Lens",
            ],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLatitude: 41.0082,
                kCGImagePropertyGPSLongitudeRef: "E",
                kCGImagePropertyGPSLongitude: 28.9784,
            ],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Private Camera Maker",
                kCGImagePropertyTIFFModel: "Private Camera Model",
                kCGImagePropertyTIFFSoftware: "Private Camera Software",
            ],
            kCGImagePropertyIPTCDictionary: [
                kCGImagePropertyIPTCCaptionAbstract: "Private source caption",
            ],
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return data as Data
    }

    private func jpegData(
        from image: UIImage,
        orientation: CGImagePropertyOrientation
    ) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw CatImageStoreError.imageEncodingFailed
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        CGImageDestinationAddImage(
            destination,
            cgImage,
            [
                kCGImagePropertyOrientation: orientation.rawValue,
                kCGImageDestinationLossyCompressionQuality: 1,
            ] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return data as Data
    }

    private func rgbValue(in image: CGImage, x: Int, y: Int) throws -> RGBValue {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        return RGBValue(
            red: pixels[offset],
            green: pixels[offset + 1],
            blue: pixels[offset + 2]
        )
    }

    private func rgbaValue(in image: CGImage, x: Int, y: Int) throws -> RGBAValue {
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        return try rgbaValue(in: image, x: x, y: y, colorSpace: sRGB)
    }

    private func rgbaValue(
        in image: CGImage,
        x: Int,
        y: Int,
        colorSpace: CGColorSpace
    ) throws -> RGBAValue {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        return RGBAValue(
            red: pixels[offset],
            green: pixels[offset + 1],
            blue: pixels[offset + 2],
            alpha: pixels[offset + 3]
        )
    }

    private func expectPreparedTransition(
        _ prepared: PreparedCaptureTransition,
        convertsCutout cutout: CGImage,
        into workingColorSpace: CGColorSpace
    ) throws {
        let expected = try rgbaValue(
            in: cutout,
            x: cutout.width / 2,
            y: cutout.height / 2,
            colorSpace: workingColorSpace
        )
        let actual = try rgbaValue(
            in: prepared.alignedCutout,
            x: prepared.alignedCutout.width / 2,
            y: prepared.alignedCutout.height / 2,
            colorSpace: workingColorSpace
        )
        let tolerance = 2

        #expect(abs(Int(actual.red) - Int(expected.red)) <= tolerance)
        #expect(abs(Int(actual.green) - Int(expected.green)) <= tolerance)
        #expect(abs(Int(actual.blue) - Int(expected.blue)) <= tolerance)
        #expect(actual.alpha == expected.alpha)

        let outputImages = [
            prepared.alignedCutout,
            prepared.sticker,
            prepared.backgroundOnly,
            prepared.subjectProtectionMask,
            prepared.outlineMask,
        ]
        for image in outputImages {
            #expect(image.colorSpace?.name == workingColorSpace.name)
            #expect(image.colorSpace?.name != CGColorSpaceCreateDeviceRGB().name)
        }

        let displayImage = UIImage(cgImage: prepared.sticker, scale: 1, orientation: .up)
        #expect(displayImage.cgImage?.colorSpace?.name == workingColorSpace.name)
    }

    private func solidCGImage(size: CGSize, colorSpace: CGColorSpace) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        context.setFillColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        return try #require(context.makeImage())
    }

    private func solidGrayCGImage(size: CGSize) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        return try #require(context.makeImage())
    }

    private func alphaValue(in image: CGImage, x: Int, y: Int) throws -> UInt8 {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CatImageStoreError.imageEncodingFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels[(y * bytesPerRow) + (x * bytesPerPixel) + 3]
    }

    private func oneComponentMask(
        size: CGSize,
        visibleRects: [CGRect]
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_OneComponent8,
            nil,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw CatImageStoreError.imageEncodingFailed
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw CatImageStoreError.imageEncodingFailed
        }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        memset(baseAddress, 0, rowBytes * height)

        for rect in visibleRects {
            let minX = max(0, Int(rect.minX))
            let maxX = min(width, Int(rect.maxX))
            let minY = max(0, Int(rect.minY))
            let maxY = min(height, Int(rect.maxY))
            for y in minY..<maxY {
                let row = baseAddress
                    .advanced(by: y * rowBytes)
                    .assumingMemoryBound(to: UInt8.self)
                for x in minX..<maxX {
                    row[x] = 255
                }
            }
        }
        return buffer
    }

}

private struct RGBValue {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

private struct RGBAValue: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

private func requireSendable<T: Sendable>(_ value: T) {}

private actor CameraConfigurationOperationProbe {
    enum ExpectedFailure: Error {
        case requested
    }

    private(set) var invocationCount = 0
    private var isBlocked = true
    private var shouldFailNext = false
    private var blockedContinuations: [CheckedContinuation<Void, Never>] = []
    private var invocationWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func run(returning capabilities: CameraZoomCapabilities) async throws -> CameraZoomCapabilities {
        invocationCount += 1
        resumeSatisfiedInvocationWaiters()

        if isBlocked {
            await withCheckedContinuation { continuation in
                blockedContinuations.append(continuation)
            }
        }

        if shouldFailNext {
            shouldFailNext = false
            throw ExpectedFailure.requested
        }
        return capabilities
    }

    func waitForInvocationCount(_ count: Int) async {
        guard invocationCount < count else { return }
        await withCheckedContinuation { continuation in
            invocationWaiters.append((count, continuation))
        }
    }

    func releaseBlockedInvocations() {
        isBlocked = false
        let continuations = blockedContinuations
        blockedContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func failNextInvocation() {
        shouldFailNext = true
    }

    private func resumeSatisfiedInvocationWaiters() {
        let ready = invocationWaiters.filter { $0.count <= invocationCount }
        invocationWaiters.removeAll { $0.count <= invocationCount }
        ready.forEach { $0.continuation.resume() }
    }
}
