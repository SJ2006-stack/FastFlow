import XCTest
@testable import FastFlowPlugins

final class InsertionResolverTests: XCTestCase {
    private func snap(
        pid: Int32 = 1,
        bundle: String = "com.apple.Notes",
        token: String = "field-a",
        text: Bool = true
    ) -> FocusSnapshot {
        FocusSnapshot(
            pid: pid,
            bundleID: bundle,
            role: text ? "AXTextArea" : "AXButton",
            subrole: nil,
            title: "t",
            isTextInput: text,
            identityToken: token
        )
    }

    func testSameElementVerified() {
        let a = snap()
        let v = InsertionResolver.resolve(trigger: .hotkey, initial: a, current: a)
        XCTAssertEqual(v, .verified)
    }

    func testHotkeySameAppDifferentFieldVerified() {
        let a = snap(token: "a")
        let b = snap(token: "b")
        let v = InsertionResolver.resolve(trigger: .hotkey, initial: a, current: b)
        XCTAssertEqual(v, .verified)
    }

    func testDifferentAppAmbiguous() {
        let a = snap(bundle: "com.apple.Notes")
        let b = snap(bundle: "com.apple.Terminal", token: "x")
        let v = InsertionResolver.resolve(trigger: .hotkey, initial: a, current: b)
        guard case .ambiguous = v else {
            return XCTFail("expected ambiguous, got \(v)")
        }
    }

    func testHotkeyNilInitialVerifiedWhenCurrentIsText() {
        let current = snap()
        let v = InsertionResolver.resolve(trigger: .hotkey, initial: nil, current: current)
        XCTAssertEqual(v, .verified)
    }

    func testNoCurrentUnavailable() {
        let v = InsertionResolver.resolve(trigger: .hotkey, initial: snap(), current: nil)
        guard case .unavailable = v else {
            return XCTFail("expected unavailable, got \(v)")
        }
    }

    func testCurrentNonTextUnavailable() {
        let v = InsertionResolver.resolve(
            trigger: .hotkey,
            initial: snap(),
            current: snap(text: false)
        )
        guard case .unavailable = v else {
            return XCTFail("expected unavailable, got \(v)")
        }
    }
}
