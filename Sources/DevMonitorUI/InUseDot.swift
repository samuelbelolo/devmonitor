import SwiftUI

/// The blue dot beside an account's name, with the count of running sessions that draw on it. Blue, because the
/// gauges are green while an account has room; the pointer over it reads « en cours · 4 sessions ».
struct InUseDot: View {
    /// The blue of an account in use, used nowhere else in the window.
    private static let tint = Color(red: 0.30, green: 0.58, blue: 1.0)

    let sessions: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Self.tint).frame(width: 7, height: 7)
            Text("\(sessions)").font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(Self.tint)
        }
        .fixedSize()
        .help(UsageStrings.inUse(sessions))
    }
}
