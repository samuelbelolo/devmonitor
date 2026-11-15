import SwiftUI

/// The pill every button of the accounts window wears, the same as the stop button of the memory window: grey, or
/// filled orange for the action a panel asks for. Drawn by hand: a bordered or prominent button turns grey and
/// changes its look whenever a menu bar window is not the key one, which it often is not.
struct PillButtonStyle: ButtonStyle {
    /// Whether the button is the action the panel asks for.
    var prominent = false

    /// Returns the label drawn as a pill, dimmed while pressed or disabled.
    /// @example Button("Annuler") {}.buttonStyle(.pill)
    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration, prominent: prominent)
    }

    /// The pill itself, a view so that it can read whether its button is enabled.
    private struct Pill: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background(prominent ? Color.orange : Color.primary.opacity(0.1), in: Capsule())
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    /// A grey pill.
    static var pill: PillButtonStyle { PillButtonStyle() }
    /// An orange pill, for the action a panel asks for.
    static var prominentPill: PillButtonStyle { PillButtonStyle(prominent: true) }
}
