import SwiftUI

/// A brand logo drawn at a given size in the current text color.
struct BrandIconView: View {
    let icon: BrandIcon
    var size: CGFloat = 13

    var body: some View {
        Image(nsImage: icon.image).resizable().renderingMode(.template).frame(width: size, height: size)
    }
}
