import SwiftUI

struct FavoritesScreen: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @StateObject private var viewModel = WallpaperListViewModel()

    var body: some View {
        Group {
            if favoriteWallpapers.isEmpty {
                ContentUnavailableView("还没有收藏", systemImage: "heart.slash", description: Text("去“发现”页把喜欢的壁纸加到收藏。"))
            } else {
                List(favoriteWallpapers) { wallpaper in
                    NavigationLink {
                        WallpaperDetailScreen(wallpaper: wallpaper)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(wallpaper.title)
                                .font(.headline)
                            Text(wallpaper.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("我的收藏")
        .task {
            await viewModel.load()
        }
    }

    private var favoriteWallpapers: [Wallpaper] {
        viewModel.wallpapers.filter { favoritesStore.favoriteIDs.contains($0.id) }
    }
}
