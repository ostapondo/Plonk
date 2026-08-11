import Foundation
import Security

// The gate every downloaded build has to pass.
//
// The test is deliberately the same one macOS applies to permissions: TCC pins
// Accessibility and Screen Recording to the running copy's designated
// requirement, so a build that satisfies that requirement is exactly a build
// the user will not have to re-authorize. One check, both guarantees — and the
// app has no other authentication to fall back on, since the download travels
// over a link we do not control the far end of.

enum CodeSignature {

    /// What the running copy is signed with, as a requirement a candidate can
    /// be checked against.
    static func selfRequirement() throws -> SecRequirement {
        let code = try selfStaticCode()
        var requirement: SecRequirement?
        let status = SecCodeCopyDesignatedRequirement(code, [], &requirement)
        guard status == errSecSuccess, let requirement else {
            throw UpdateError.signatureRejected("this copy has no designated requirement (OSStatus \(status))")
        }
        return requirement
    }

    /// True when the running copy carries no certificate, which is what ad-hoc
    /// signing means. Its requirement names a hash that changes with every
    /// build, so no future download could ever satisfy it — worth saying
    /// plainly instead of failing at the last step.
    static func selfIsAdHoc() -> Bool {
        guard let code = try? selfStaticCode() else { return true }
        var info: CFDictionary?
        let status = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
        guard status == errSecSuccess,
              let dictionary = info as? [String: Any] else { return true }
        let certificates = dictionary[kSecCodeInfoCertificates as String] as? [Any]
        return (certificates?.isEmpty ?? true)
    }

    /// Whether the bundle at `url` is intact and signed the same way this copy
    /// is, and what to say when it is not. Nested code is checked too, so a
    /// tampered helper inside an otherwise valid bundle is caught.
    static func check(bundleAt url: URL, satisfies requirement: SecRequirement) -> SignatureCheck {
        var candidate: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(url as CFURL, [], &candidate)
        guard created == errSecSuccess, let candidate else {
            return .rejected("the download is not signed code (OSStatus \(created))")
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        var failure: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(candidate, flags, requirement, &failure)
        guard status == errSecSuccess else {
            let detail = (failure?.takeRetainedValue() as Error?)?.localizedDescription
                ?? "it is not signed by the certificate this copy was signed with (OSStatus \(status))"
            return .rejected(detail)
        }
        return .satisfied
    }

    private static func selfStaticCode() throws -> SecStaticCode {
        var running: SecCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running else {
            throw UpdateError.signatureRejected("this copy could not be inspected")
        }
        var stat: SecStaticCode?
        guard SecCodeCopyStaticCode(running, [], &stat) == errSecSuccess, let stat else {
            throw UpdateError.signatureRejected("this copy has no signature on disk")
        }
        return stat
    }
}
