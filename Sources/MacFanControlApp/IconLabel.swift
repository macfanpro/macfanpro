import SwiftUI

/// Icon-and-text content for the app's buttons and status labels: a symbol scaled
/// down to the text's height, centered on the text rather than on its own taller
/// bounding box, 4pt apart, so every icon in the panel and settings reads the same.
/// Used instead of `Label`, whose larger symbol and wider gap looked unbalanced.
struct IconLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.small)
                .font(.body.weight(.regular))
            Text(title)
        }
    }
}
