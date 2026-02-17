import Foundation

protocol WallpaperRepositoryProtocol {
    func loadWallpapers() async throws -> [Wallpaper]
}

final class WallpaperRepository: WallpaperRepositoryProtocol {
    func loadWallpapers() async throws -> [Wallpaper] {
        try await Task.sleep(for: .milliseconds(200))

        return [
            Wallpaper(id: "1", title: "Velvet Dawn", category: .gradient, author: "Studio Nova", colorHex: "#FDA085", previewImageName: "wallpaper-1-preview", fullImageName: "wallpaper-1", isPremium: false),
            Wallpaper(id: "2", title: "Neo Skyline", category: .neon, author: "Pixel Arc", colorHex: "#6A11CB", previewImageName: "wallpaper-2-preview", fullImageName: "wallpaper-2", isPremium: true),
            Wallpaper(id: "3", title: "Zen Stones", category: .minimal, author: "Sora Lab", colorHex: "#B8C6DB", previewImageName: "wallpaper-3-preview", fullImageName: "wallpaper-3", isPremium: false),
            Wallpaper(id: "4", title: "Misty Forest", category: .nature, author: "Green Lens", colorHex: "#5A7D7C", previewImageName: "wallpaper-4-preview", fullImageName: "wallpaper-4", isPremium: false),
            Wallpaper(id: "5", title: "Liquid Motion", category: .abstract, author: "Fluid Works", colorHex: "#00C9FF", previewImageName: "wallpaper-5-preview", fullImageName: "wallpaper-5", isPremium: true),
            Wallpaper(id: "6", title: "Aurora Silk", category: .gradient, author: "Lightform", colorHex: "#43E97B", previewImageName: "wallpaper-6-preview", fullImageName: "wallpaper-6", isPremium: false)
        ]
    }
}
