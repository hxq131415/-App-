import SwiftUI

struct WallpaperTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WallpaperListScreen()
            }
            .tabItem {
                Label("发现", systemImage: "sparkles")
            }

            NavigationStack {
                FavoritesScreen()
            }
            .tabItem {
                Label("收藏", systemImage: "heart.fill")
            }

            NavigationStack {
                SettingsScreen()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
        }
        .tint(.purple)
    }
}
