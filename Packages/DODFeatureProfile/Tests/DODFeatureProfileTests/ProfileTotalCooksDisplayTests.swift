import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the DUT-942 "Total Cooks" cell display helper
/// (`ProfileEditView.totalCooksDisplay`). The owner ("The Dutch Oven Daddy")
/// always sees the infinity symbol in that cell, regardless of their actual
/// cook count; everyone else sees the decimal count.
///
/// Spec trace: DUT-942.
@Suite("ProfileEditView total cooks display (DUT-942)")
struct ProfileTotalCooksDisplayTests {

    /// Owner, zero cooks logged — still infinity, not "0".
    @Test func ownerWithZeroCooksShowsInfinity() {
        let display = ProfileEditView.totalCooksDisplay(totalCooks: 0, isOwner: true)
        #expect(display == "∞")
    }

    /// Owner with a positive count — infinity wins regardless of the count.
    @Test func ownerWithPositiveCooksShowsInfinity() {
        let display = ProfileEditView.totalCooksDisplay(totalCooks: 42, isOwner: true)
        #expect(display == "∞")
    }

    /// Non-owner, zero cooks logged — plain decimal string.
    @Test func nonOwnerWithZeroCooksShowsZero() {
        let display = ProfileEditView.totalCooksDisplay(totalCooks: 0, isOwner: false)
        #expect(display == "0")
    }

    /// Non-owner with a positive count — plain decimal string.
    @Test func nonOwnerWithPositiveCooksShowsCount() {
        let display = ProfileEditView.totalCooksDisplay(totalCooks: 42, isOwner: false)
        #expect(display == "42")
    }
}
