import SwiftUI
import Cocoa

// For testing.
struct ColorizedSpectreProIconView: View {
    var body: some View {
        Image(nsImage: ColorizedSpectreProIcon(
            screenColors: [.purple, .blue],
            ghostColor: .yellow,
            frame: .aluminum
        ).makeImage(in: .main)!)
    }
}
