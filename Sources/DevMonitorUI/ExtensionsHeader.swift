import DevMonitorCore
import SwiftUI

/// The title of the Extensions section, when GitHub last answered, and a button that checks again now.
struct ExtensionsHeader: View {
    @EnvironmentObject private var extensions: ExtensionStore

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            SectionTitle(title: Strings.extensions)
            Spacer()
            if let checkedAt = extensions.checkedAt {
                // Ticks on its own, so the age stays right while the window stays open.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    let seconds = max(0, Int(context.date.timeIntervalSince(checkedAt)))
                    Text(Strings.checked(ago: DisplayFormat.duration(seconds: seconds))).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
            Button {
                Task { await extensions.refresh(fetchingUpstream: true) }
            } label: {
                if extensions.isChecking {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10.5, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)
            .disabled(extensions.isChecking)
            .help(Strings.checkNow)
        }
    }
}
