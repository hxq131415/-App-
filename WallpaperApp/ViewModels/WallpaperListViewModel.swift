import Foundation

@MainActor
final class WallpaperListViewModel: ObservableObject {
    @Published var wallpapers: [Wallpaper] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: WallpaperCategory?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: WallpaperRepositoryProtocol

    init(repository: WallpaperRepositoryProtocol = WallpaperRepository()) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            wallpapers = try await repository.loadWallpapers()
            errorMessage = nil
        } catch {
            errorMessage = "加载壁纸失败，请稍后再试。"
        }
    }

    var filteredWallpapers: [Wallpaper] {
        wallpapers.filter { wallpaper in
            let matchesCategory = selectedCategory == nil || wallpaper.category == selectedCategory
            let matchesSearch = searchText.isEmpty || wallpaper.title.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    func clearFilters() {
        selectedCategory = nil
        searchText = ""
    }
}
