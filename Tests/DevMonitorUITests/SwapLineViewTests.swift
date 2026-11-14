import DevMonitorCore
import SwiftUI
import XCTest
@testable import DevMonitorUI

@MainActor
final class SwapLineViewTests: XCTestCase {
    private let gigabyte: UInt64 = 1_073_741_824

    /// Returns the height of the swap line of a Mac with 48 GB of memory and `used` gigabytes of swap in use.
    /// @example height(used: 30) // two lines: the swap, then the call to restart
    private func height(used: UInt64) -> CGFloat {
        let swap = SwapUsage(usedBytes: used * gigabyte, installedBytes: 48 * gigabyte)
        return HostedView(sizedByContent: SwapLineView(swap: swap, startedAt: Date().addingTimeInterval(-11 * 86_400)).font(.system(size: 12.5)), width: 372).height
    }

    func testOnlyACriticalSwapCallsForARestart() {
        let fine = height(used: 2)
        XCTAssertEqual(height(used: 20), fine, accuracy: 1)
        XCTAssertGreaterThan(height(used: 30), fine + 10)
    }

    func testTheMenuBarChipTakesAColorOnlyOnceTheSwapNeedsAttention() {
        XCTAssertNil(MemoryGlyph.image(for: .fine))
        XCTAssertEqual(MemoryGlyph.image(for: .high)?.isTemplate, false)
        XCTAssertEqual(MemoryGlyph.image(for: .critical)?.isTemplate, false)
    }

    func testTheCallToRestartSaysHowLongTheMacHasBeenUp() {
        XCTAssertTrue(Strings.restartFreesSwap(upFor: "11 j").contains("11 j"))
        XCTAssertFalse(Strings.restartFreesSwap(upFor: nil).isEmpty)
    }
}
