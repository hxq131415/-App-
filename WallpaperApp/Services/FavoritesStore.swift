import Foundation

final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String> = []

    private let defaultsKey = "favorite_wallpaper_ids"

    init() {
        favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }

    func isFavorite(_ wallpaper: Wallpaper) -> Bool {
        favoriteIDs.contains(wallpaper.id)
    }

    func toggle(_ wallpaper: Wallpaper) {
        if favoriteIDs.contains(wallpaper.id) {
            favoriteIDs.remove(wallpaper.id)
        } else {
            favoriteIDs.insert(wallpaper.id)
        }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: defaultsKey)
    }
}
