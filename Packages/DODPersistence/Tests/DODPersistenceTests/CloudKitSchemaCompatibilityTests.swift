import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// Regression guard for **DOD-CRASH-1** — build 3 crashed on *every relaunch*
/// once the user enabled iCloud Sync.
///
/// Root cause: the `@Model` classes had non-optional attributes with no
/// default value (`id: Int`, `title: String`, `bytes: Data`, …). SwiftData's
/// CloudKit mirror (`NSPersistentCloudKitContainer`, reached via
/// `cloudKitDatabase: .private`) requires **every attribute to be optional or
/// have a default value**, and forbids `@Attribute(.unique)`. With sync OFF
/// the `.none` configuration skips that validation, so first launches worked;
/// with sync ON, `productionContainer()` threw at store open and
/// `AppDependencies.init`'s `fatalError` killed the app (SIGTRAP in
/// `AppDependencies.init`, confirmed from the on-device crash log).
///
/// We assert the invariant by **introspecting the schema** rather than
/// constructing a `.private` container: a CloudKit-backed container can't be
/// built in a plain unit-test process (the `NSCloudKitMirroringDelegate`
/// registers with PushKit, which needs the app's CloudKit/push entitlements
/// and throws an `NSException` without them). Introspection checks the exact
/// invariant CloudKit enforces, hermetically, with no entitlements.
///
/// No prior test covered this — the one that would have
/// (`SchemaV4Tests.optInOnPathProducesCloudKitConfiguration`) was `.disabled`.
@Suite("CloudKit schema compatibility (DOD-CRASH-1)")
struct CloudKitSchemaCompatibilityTests {

    /// Every attribute in the production schema must be optional or carry a
    /// default value, and none may be unique — the contract
    /// `NSPersistentCloudKitContainer` enforces at store open. A regression
    /// (a new non-optional, non-defaulted field) reintroduces the launch
    /// crash for every synced user, so it must fail here first.
    @Test func everyV4AttributeIsCloudKitCompatible() throws {
        let schema = Schema(SchemaV4.models)

        var violations: [String] = []
        for entity in schema.entities {
            for attribute in entity.attributes {
                let qualified = "\(entity.name).\(attribute.name)"
                if !(attribute.isOptional || attribute.defaultValue != nil) {
                    violations.append("\(qualified) — non-optional with no default")
                }
                if attribute.isUnique {
                    violations.append("\(qualified) — @Attribute(.unique) is forbidden by CloudKit")
                }
            }
        }

        #expect(
            violations.isEmpty,
            """
            CloudKit mirroring requires every attribute to be optional or \
            defaulted and forbids unique constraints. Violations: \
            \(violations.joined(separator: "; "))
            """
        )
    }
}
