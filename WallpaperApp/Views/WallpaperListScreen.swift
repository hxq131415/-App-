import SwiftUI

struct WallpaperListScreen: View {
    @StateObject private var viewModel = WallpaperListViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemBackground), Color.purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    ProgressView("正在加载精选壁纸…")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("加载失败", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            categoryFilter
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.filteredWallpapers) { wallpaper in
                                    NavigationLink {
                                        WallpaperDetailScreen(wallpaper: wallpaper)
                                    } label: {
                                        WallpaperCard(wallpaper: wallpaper)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("壁纸精选")
        .searchable(text: $viewModel.searchText, prompt: "搜索壁纸名称")
        .task {
            await viewModel.load()
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(title: "全部", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }

                ForEach(WallpaperCategory.allCases) { category in
                    filterChip(title: category.rawValue, isSelected: viewModel.selectedCategory == category) {
                        viewModel.selectedCategory = category
                    }
                }
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.purple : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
