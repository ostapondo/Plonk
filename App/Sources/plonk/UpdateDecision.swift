import Foundation

// What the updater decides, kept apart from how it finds any of it out.
//
// Every value here is plain: a version, a flag, a string read off a bundle.
// UpdateManager does the network and the filesystem work and hands the results
// over, so the decision that ends in a swapped-in app — the one that costs the
// user their permissions when it goes wrong — can be called with made-up
// values and pinned by tests.

enum UpdateDecision: Equatable {
    /// Nothing newer than the running copy.
    case upToDate
    /// A newer release, worth putting in front of the user.
    case offer(Release)
    /// Everything checked so far passed, and something is still unchecked.
    case proceed
    /// Every check passed. Swap it in.
    case install
    /// Stop, and say why.
    case refuse(UpdateError)
}

/// The copy that is running, as far as installing over it is concerned. All of
/// it is known before anything is downloaded.
struct InstalledCopy: Equatable {
    /// Whether the running copy is a .app at all, rather than a bare binary.
    let isApplicationBundle: Bool
    /// Whether both the bundle and the directory holding it can be written.
    let isWritable: Bool
    /// The directory holding the bundle, named in the refusal when it cannot.
    let parentPath: String
    /// Ad-hoc signing means no certificate, so no download could ever satisfy
    /// this copy's requirement.
    let isAdHoc: Bool
}

/// What was found inside the archive, before any of it is judged.
struct StagedPayload: Equatable {
    /// The bundle name looked for, e.g. "Plonk.app".
    let name: String
    /// False when the archive holds nothing by that name.
    let exists: Bool
    /// The staged bundle's identifier, nil when it has none to read.
    let identifier: String?
    /// CFBundleShortVersionString exactly as read, so a refusal can quote it.
    let shortVersion: String
}

enum SignatureCheck: Equatable {
    case satisfied
    case rejected(String)
}

/// The verification steps, in the order they run, each nil until its step has.
/// A filled-in field means that work is already done — which is why the digest
/// is a field of its own rather than folded in with the rest: it is checked
/// before `ditto` is handed the archive, and nothing below it has happened yet.
struct VerificationResult: Equatable {
    /// nil when the release carries no digest, which is how releases cut before
    /// GitHub published one still install: they fall through to the signature.
    var digestMatched: Bool?
    /// nil until the archive has been unpacked.
    var payload: StagedPayload?
    /// nil until the staged bundle has been checked against the requirement.
    var signature: SignatureCheck?

    init(digestMatched: Bool? = nil, payload: StagedPayload? = nil, signature: SignatureCheck? = nil) {
        self.digestMatched = digestMatched
        self.payload = payload
        self.signature = signature
    }
}

extension UpdateDecision {

    /// Whether the release that came back is newer than what is running.
    static func offering(running: ReleaseVersion?, latest: Release?) -> UpdateDecision {
        guard let latest, let running, running < latest.version else { return .upToDate }
        return .offer(latest)
    }

    /// Whether this copy can install an update at all. Settled before the
    /// download starts, so a copy that could never install one never fetches
    /// the bytes.
    static func preflight(_ copy: InstalledCopy) -> UpdateDecision {
        guard copy.isApplicationBundle else { return .refuse(.notInstalled) }
        guard copy.isWritable else { return .refuse(.notWritable(copy.parentPath)) }
        guard !copy.isAdHoc else { return .refuse(.adHocCopy) }
        return .proceed
    }

    /// The verdict on what has been checked so far. Asked after each step, and
    /// the first failure is the answer: the caller stops there, so a download
    /// that failed the digest is never unpacked, and one that is not the app we
    /// were offered is never handed to the signature check.
    static func verdict(on verification: VerificationResult, expecting release: Release,
                        identifier expected: String?) -> UpdateDecision {
        if verification.digestMatched == false { return .refuse(.digestMismatch) }
        guard let payload = verification.payload else { return .proceed }
        if let refusal = payload.refusal(expecting: release, identifier: expected) {
            return .refuse(refusal)
        }
        guard let signature = verification.signature else { return .proceed }
        if case .rejected(let why) = signature { return .refuse(.signatureRejected(why)) }
        return .install
    }
}

extension UpdateDecision {
    /// The release to put in front of the user, when the decision is one.
    var offered: Release? {
        guard case .offer(let release) = self else { return nil }
        return release
    }

    /// The refusal to throw, when the decision is one.
    var refusal: UpdateError? {
        guard case .refuse(let error) = self else { return nil }
        return error
    }
}

extension VerificationResult {
    /// Puts what has been checked so far to the decision and stops on the first
    /// refusal, which is how the caller runs its steps in order.
    @discardableResult
    func checked(against release: Release, identifier: String?) throws -> UpdateDecision {
        let decision = UpdateDecision.verdict(on: self, expecting: release, identifier: identifier)
        if let refusal = decision.refusal { throw refusal }
        return decision
    }
}

extension StagedPayload {

    /// The archive has to hold the app we were offered, at the version we were
    /// offered. Without this a stale or mismatched asset would pass the
    /// signature check on its way to being installed as an "update".
    func refusal(expecting release: Release, identifier expected: String?) -> UpdateError? {
        guard exists else { return .wrongPayload("it holds no \(name)") }
        guard let identifier, identifier == expected else {
            return .wrongPayload("its bundle identifier is not \(expected ?? "ours")")
        }
        guard let version = ReleaseVersion(shortVersion), version == release.version else {
            return .wrongPayload("it contains \(shortVersion), not \(release.version)")
        }
        return nil
    }
}
