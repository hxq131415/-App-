import SwiftUI

struct WallpaperDetailScreen: View {
    let wallpaper: Wallpaper
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @State private var showSavedToast = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: wallpaper.colorHex), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 20)

                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .overlay {
                        VStack(spacing: 12) {
                            Text(wallpaper.title)
                                .font(.largeTitle.bold())
                            Text(wallpaper.description)
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(height: 440)
                    .padding(.horizontal)

                actionBar
            }
            .padding(.bottom, 40)

            if showSavedToast {
                Text("已保存到系统照片（示例逻辑）")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .animation(.spring, value: showSavedToast)
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            Button {
                favoritesStore.toggle(wallpaper)
            } label: {
                Label(
                    favoritesStore.isFavorite(wallpaper) ? "已收藏" : "收藏",
                    systemImage: favoritesStore.isFavorite(wallpaper) ? "heart.fill" : "heart"
                )
            }
            .buttonStyle(GlassButtonStyle())

            Button {
                showSavedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    showSavedToast = false
                }
            } label: {
                Label("下载", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(GlassButtonStyle())

            Button {} label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(GlassButtonStyle())
        }
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

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
