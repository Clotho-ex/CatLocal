import CoreImage
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import CatLocal

struct CatLocalCoreTests {
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
        #expect(LociContext.emptyCollection.title == "Meet Your First Local")
        #expect(LociContext.emptyCollection.subtitle == "Capture an encounter and turn it into a local card.")
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

    @Test
    func imageStoreRejectsSiblingPrefixTraversal() async throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = parent.appendingPathComponent("Cats", isDirectory: true)
        let sibling = parent.appendingPathComponent("CatsBackup", isDirectory: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try Data("outside".utf8).write(to: sibling.appendingPathComponent("secret.txt"))

        let store = CatImageStore(rootURL: root)
        await #expect(throws: CatImageStoreError.self) {
            _ = try await store.data(at: "../CatsBackup/secret.txt")
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
    func dustRevealTimelineClampsAndCompletesAtDuration() {
        #expect(DustRevealTimeline.progress(elapsed: -1, duration: 2.6) == 0)
        #expect(DustRevealTimeline.progress(elapsed: 1.3, duration: 2.6) == 0.5)
        #expect(DustRevealTimeline.progress(elapsed: 3.0, duration: 2.6) == 1)
        #expect(!DustRevealTimeline.isComplete(elapsed: 2.59, duration: 2.6))
        #expect(DustRevealTimeline.isComplete(elapsed: 2.6, duration: 2.6))
    }

    @Test
    func dustRevealAlphaClassifiesOnlyInverseAlphaAsBackground() {
        #expect(DustRevealAlpha.isBackground(alpha: 0))
        #expect(DustRevealAlpha.isBackground(alpha: 31.0 / 255.0))
        #expect(!DustRevealAlpha.isBackground(alpha: 32.0 / 255.0))
        #expect(!DustRevealAlpha.isBackground(alpha: 1))
        #expect(DustRevealAlpha.inverseWeight(alpha: 0) == 1)
        #expect(DustRevealAlpha.inverseWeight(alpha: 1) == 0)
    }

    @Test
    func dustRevealSourceContributionReconstructsStartAndClearsTerminalFrame() {
        #expect(DustRevealTimeline.staggeredProgress(progress: 0, stagger: 0.18) == 0)
        #expect(DustRevealTimeline.staggeredProgress(progress: 1, stagger: 0.18) == 1)
        #expect(DustRevealTimeline.terminalSourceFade(progress: 0) == 1)
        #expect(DustRevealTimeline.terminalSourceFade(progress: 1) == 0)

        for alpha in [0.0, 0.5, 1.0] {
            #expect(DustRevealAlpha.sourceContribution(
                cutoutAlpha: alpha,
                progress: 0,
                stagger: 0.18
            ) == 1)
            #expect(DustRevealAlpha.sourceContribution(
                cutoutAlpha: alpha,
                progress: 1,
                stagger: 0.18
            ) == 0)
        }
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
        let detectionBounds = CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.40)

        let processor = CatVisionProcessor()
        #expect(processor.maskOverlapScore(mask, boundingBox: detectionBounds) > 0.9)

        let cutout = try await processor.makeTransparentCutout(
            from: try #require(original.cgImage),
            mask: CIImage(cvPixelBuffer: mask)
        )

        #expect(try alphaValue(in: cutout, x: 42, y: 75) > 200)
        #expect(try alphaValue(in: cutout, x: 57, y: 75) > 200)
        #expect(try alphaValue(in: cutout, x: 10, y: 90) == 0)
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
