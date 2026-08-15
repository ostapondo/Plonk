import Testing
import Foundation
@testable import plonk

// The decision that ends in a swapped-in app. Every case here is a refusal the
// user's permissions depend on: TCC pins Accessibility and Screen Recording to
// the running copy's signature, so a build that gets past these checks without
// satisfying it costs them both. None of this touches the network or a real
// bundle — that is the point of the split.

private let ours = "dev.plonk.app"

private func release(_ version: String = "0.2.5", digest: String? = nil) -> Release {
    Release(
        version: ReleaseVersion(version)!,
        downloadURL: URL(string: "https://example.invalid/Plonk-\(version).zip")!,
        pageURL: URL(string: "https://example.invalid/releases/v\(version)")!,
        notes: "",
        size: 0,
        digest: digest
    )
}

private func payload(name: String = "Plonk.app", exists: Bool = true,
                     identifier: String? = ours, shortVersion: String = "0.2.5") -> StagedPayload {
    StagedPayload(name: name, exists: exists, identifier: identifier, shortVersion: shortVersion)
}

private func verdict(_ verification: VerificationResult,
                     expecting offered: Release = release(),
                     identifier: String? = ours) -> UpdateDecision {
    UpdateDecision.verdict(on: verification, expecting: offered, identifier: identifier)
}

struct UpdateOfferTests {

    @Test func aNewerReleaseIsOffered() {
        #expect(UpdateDecision.offering(running: ReleaseVersion("0.2.4"), latest: release("0.2.5"))
            == .offer(release("0.2.5")))
    }

    @Test func theVersionAlreadyRunningIsNotOffered() {
        #expect(UpdateDecision.offering(running: ReleaseVersion("0.2.5"), latest: release("0.2.5"))
            == .upToDate)
    }

    @Test func aCopyAheadOfTheFeedIsLeftAlone() {
        // A build made from a branch, or a release pulled after it went out.
        #expect(UpdateDecision.offering(running: ReleaseVersion("0.3.0"), latest: release("0.2.5"))
            == .upToDate)
    }

    @Test func nothingIsOfferedUntilTheFeedHasBeenRead() {
        #expect(UpdateDecision.offering(running: ReleaseVersion("0.2.4"), latest: nil) == .upToDate)
    }

    @Test func aCopyWithNoReadableVersionIsOfferedNothing() {
        // Nothing to compare against, so there is no case for replacing it.
        #expect(UpdateDecision.offering(running: nil, latest: release("0.2.5")) == .upToDate)
    }
}

struct UpdatePreflightTests {

    private func copy(bundle: Bool = true, writable: Bool = true,
                      parent: String = "/Applications", adHoc: Bool = false) -> InstalledCopy {
        InstalledCopy(isApplicationBundle: bundle, isWritable: writable,
                      parentPath: parent, isAdHoc: adHoc)
    }

    @Test func anOrdinaryInstalledCopyGetsToDownload() {
        #expect(UpdateDecision.preflight(copy()) == .proceed)
    }

    @Test func anAdHocCopyIsRefusedBeforeAnythingIsFetched() {
        // Its requirement names a hash that changes with every build, so no
        // download could ever satisfy it. Better said plainly than at the end.
        #expect(UpdateDecision.preflight(copy(adHoc: true)) == .refuse(.adHocCopy))
    }

    @Test func aCopyRunningUnbundledHasNothingToInstallOver() {
        #expect(UpdateDecision.preflight(copy(bundle: false)) == .refuse(.notInstalled))
    }

    @Test func aCopySomewhereUnwritableNamesTheDirectoryItCannotWrite() {
        #expect(UpdateDecision.preflight(copy(writable: false, parent: "/Volumes/Plonk"))
            == .refuse(.notWritable("/Volumes/Plonk")))
    }

    @Test func beingUnbundledIsSaidFirst() {
        // A binary run out of .build is both unbundled and ad-hoc signed;
        // telling the user to install by hand is the useful half.
        #expect(UpdateDecision.preflight(copy(bundle: false, writable: false, adHoc: true))
            == .refuse(.notInstalled))
    }
}

struct UpdateVerdictTests {

    @Test func aDownloadThatMatchesEveryCheckIsInstalled() {
        #expect(verdict(VerificationResult(digestMatched: true, payload: payload(),
                                           signature: .satisfied)) == .install)
    }

    @Test func aDigestThatDoesNotMatchIsRefused() {
        #expect(verdict(VerificationResult(digestMatched: false)) == .refuse(.digestMismatch))
    }

    @Test func aReleaseWithNoPublishedDigestStillInstalls() {
        // Releases cut before GitHub published digests carry none. They fall
        // through to the signature check, which is the one that matters, and
        // that has not moved. nil here means "none published", not "matched".
        let none = VerificationResult(digestMatched: nil, payload: payload(), signature: .satisfied)
        #expect(verdict(none, expecting: release("0.2.5", digest: nil)) == .install)
    }

    @Test func theDigestIsAnsweredBeforeTheArchiveIsOpened() {
        // Nothing below the digest has run yet, so a mangled download is
        // refused without ditto ever being handed it.
        #expect(verdict(VerificationResult(digestMatched: true)) == .proceed)
        #expect(verdict(VerificationResult()) == .proceed)
    }

    @Test func aBadDigestOutranksWhateverTheArchiveHolds() {
        let both = VerificationResult(digestMatched: false, payload: payload(exists: false),
                                      signature: .rejected("wrong certificate"))
        #expect(verdict(both) == .refuse(.digestMismatch))
    }

    @Test func anArchiveWithoutTheAppInsideIsRefused() {
        #expect(verdict(VerificationResult(digestMatched: true, payload: payload(exists: false)))
            == .refuse(.wrongPayload("it holds no Plonk.app")))
    }

    @Test func anArchiveHoldingSomeoneElsesAppIsRefused() {
        #expect(verdict(VerificationResult(digestMatched: true,
                                           payload: payload(identifier: "com.example.other")))
            == .refuse(.wrongPayload("its bundle identifier is not dev.plonk.app")))
        // A bundle we cannot read an identifier out of is the same refusal.
        #expect(verdict(VerificationResult(digestMatched: true, payload: payload(identifier: nil)))
            == .refuse(.wrongPayload("its bundle identifier is not dev.plonk.app")))
    }

    @Test func anArchiveHoldingAnotherVersionIsRefused() {
        // Not the build that was offered: a stale asset would otherwise pass
        // the signature check on its way in as an "update".
        #expect(verdict(VerificationResult(digestMatched: true,
                                           payload: payload(shortVersion: "0.2.1")))
            == .refuse(.wrongPayload("it contains 0.2.1, not 0.2.5")))
        #expect(verdict(VerificationResult(digestMatched: true, payload: payload(shortVersion: "")))
            == .refuse(.wrongPayload("it contains , not 0.2.5")))
    }

    @Test func aBundleSignedWithAnotherCertificateIsRefused() {
        // The check the whole update path exists to make. Installing this would
        // take Accessibility and Screen Recording from everyone who has them.
        let detail = "it is not signed by the certificate this copy was signed with"
        let rejected = VerificationResult(digestMatched: true, payload: payload(),
                                          signature: .rejected(detail))
        #expect(verdict(rejected) == .refuse(.signatureRejected(detail)))
    }

    @Test func theRightAppIsStillNotInstalledUntilItsSignatureIsChecked() {
        #expect(verdict(VerificationResult(digestMatched: true, payload: payload())) == .proceed)
    }

    @Test func theWrongAppIsRefusedWithoutBlamingItsSignature() {
        // Order again: the payload is answered first, so the message names what
        // actually went wrong.
        let both = VerificationResult(digestMatched: true, payload: payload(shortVersion: "0.2.1"),
                                      signature: .rejected("wrong certificate"))
        #expect(both.payload != nil)
        #expect(verdict(both) == .refuse(.wrongPayload("it contains 0.2.1, not 0.2.5")))
    }

    @Test func aCopyWithNoIdentifierOfItsOwnCanMatchNothing() {
        // Bundle.main has no identifier when the tests run unbundled, and that
        // has to read as a refusal rather than as anything matching.
        #expect(verdict(VerificationResult(digestMatched: true, payload: payload()), identifier: nil)
            == .refuse(.wrongPayload("its bundle identifier is not ours")))
    }
}

struct UpdateRetryTests {

    @Test func theNetworkComingBackRetriesACheckThatGaveUpWithoutOne() {
        #expect(ConnectivityChange(isSatisfied: true, awaitingNetwork: true, automatic: true)
            .warrantsCheck)
    }

    @Test func aPathChangeOnItsOwnIsNotWorthACheck() {
        // Wi-Fi hops, VPNs, a cable pulled and put back: none of them is a
        // reason to ask GitHub anything when the last check got an answer.
        #expect(!ConnectivityChange(isSatisfied: true, awaitingNetwork: false, automatic: true)
            .warrantsCheck)
    }

    @Test func theNetworkGoingAwayIsNotACheck() {
        #expect(!ConnectivityChange(isSatisfied: false, awaitingNetwork: true, automatic: true)
            .warrantsCheck)
    }

    @Test func nothingIsRetriedWhenTheUserTurnedCheckingOff() {
        // The settings page promises the buttons are the only way a connection
        // is opened, and a check that failed does not get to be an exception.
        #expect(!ConnectivityChange(isSatisfied: true, awaitingNetwork: true, automatic: false)
            .warrantsCheck)
    }
}
