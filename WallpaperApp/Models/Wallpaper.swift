import Foundation

struct Wallpaper: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let category: WallpaperCategory
    let author: String
    let colorHex: String
    let previewImageName: String
    let fullImageName: String
    let isPremium: Bool

    var description: String {
        "\(category.rawValue) · by \(author)"
    }
}

enum WallpaperCategory: String, CaseIterable, Codable, Identifiable {
    case minimal = "极简"
    case nature = "自然"
    case abstract = "抽象"
    case neon = "霓虹"
    case gradient = "渐变"

    var id: String { rawValue }
}
