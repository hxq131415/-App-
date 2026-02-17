import SwiftUI

struct WallpaperCard: View {
    let wallpaper: Wallpaper

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(hex: wallpaper.colorHex).gradient)
                .frame(height: 220)
                .overlay(alignment: .topTrailing) {
                    if wallpaper.isPremium {
                        Text("PRO")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(14)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(wallpaper.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(wallpaper.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
