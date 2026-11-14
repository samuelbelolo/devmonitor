import DevMonitorCore
import SwiftUI

/// The swap in use: grey while it is fine, orange once it is high, red with the call to restart once it is critical.
struct SwapLineView: View {
    let swap: SwapUsage
    /// When the Mac last started; nil when the system did not say.
    let startedAt: Date?
    /// The moment the line is drawn at, which the time since the last start is counted to.
    var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(Strings.swap).fontWeight(.semibold)
                Text(DisplayFormat.memory(swap.usedBytes)).monospacedDigit()
                if swap.state == .critical { Chip(text: Strings.critical, tint: Palette.orphan) }
                Spacer(minLength: 0)
            }
            .foregroundStyle(SwapTint.color(for: swap.state) ?? Color.secondary)
            if swap.state == .critical {
                Text(Strings.restartFreesSwap(upFor: startedAt.map { DisplayFormat.duration(seconds: Int(now.timeIntervalSince($0))) }))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 6)
    }
}
