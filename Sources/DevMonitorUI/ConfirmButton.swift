import SwiftUI

/// A button that asks for a second click before running its action.
struct ConfirmButton: View {
    let title: String
    /// When set, the button rests as this icon alone and shows a confirm button over the line once clicked.
    var systemImage: String?
    /// Runs on the first click, to record what the second click will confirm.
    var onArm: () -> Void = {}
    let action: () -> Void
    @State private var isArmed = false

    var body: some View {
        Group {
            if let systemImage {
                // The icon keeps its place. The confirm label is a button of its own laid over the line, growing
                // to the left of the icon: the line never shifts, the label opens under the pointer, and all of
                // it can be clicked. Drawn inside the icon's label, only the icon's own area would react.
                Button(action: arm) { Image(systemName: systemImage).foregroundStyle(.secondary) }
                    .opacity(isArmed ? 0 : 1)
                    .overlay(alignment: .trailing) {
                        if isArmed { Button(action: confirm) { pill(Text(Strings.confirm)) }.fixedSize() }
                    }
            } else {
                Button {
                    if isArmed { confirm() } else { arm() }
                } label: {
                    // Both labels are laid out so the button keeps one width and its neighbours never move.
                    pill(ZStack {
                        Text(title).opacity(isArmed ? 0 : 1)
                        Text(Strings.confirm).opacity(isArmed ? 1 : 0)
                    })
                }
            }
        }
        .buttonStyle(.plain)
        .help(title)
    }

    /// Draws a label as the pill of the button, red once the button is armed.
    /// @example pill(Text("Stop"))
    private func pill<Label: View>(_ label: Label) -> some View {
        label
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .foregroundStyle(isArmed ? Color.white : Color.primary)
            .background(isArmed ? Palette.orphan : Color.primary.opacity(0.1), in: Capsule())
    }

    /// Shows the confirm label for three seconds, then falls back to the resting state.
    /// @example arm()
    private func arm() {
        onArm()
        isArmed = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            isArmed = false
        }
    }

    /// Runs the action and returns to the resting state.
    /// @example confirm()
    private func confirm() {
        isArmed = false
        action()
    }
}
