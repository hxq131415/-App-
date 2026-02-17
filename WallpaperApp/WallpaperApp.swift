import SwiftUI

@main
struct WallpaperApp: App {
    @StateObject private var favoritesStore = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            WallpaperTabView()
                .environmentObject(favoritesStore)
        }
    }
}
