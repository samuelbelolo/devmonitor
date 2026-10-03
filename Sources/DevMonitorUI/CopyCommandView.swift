import AppKit
import SwiftUI

/// A command shown in a monospaced box, with a button that copies it.
struct CopyCommandView: View {
    let command: String
    @State private var isCopied = false

    var body: some View {
        HStack(spacing: 6) {
            Text(command).font(.system(size: 11.5, design: .monospaced)).textSelection(.enabled)
            Spacer(minLength: 6)
            Button(action: copy) { Text(isCopied ? Strings.copied : Strings.copy).font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(.plain)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .foregroundStyle(isCopied ? Color.black : Color.primary)
                .background(isCopied ? Palette.ok : Color.primary.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.1)))
    }

    /// Puts the command on the clipboard and says so for a moment.
    /// @example copy()
    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        isCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            isCopied = false
        }
    }
}
