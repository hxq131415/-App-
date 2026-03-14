import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var selectedColor: Color = .blue
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private let mattingService = ImageMattingService()

    private let presetColors: [Color] = [
        .blue,
        .red,
        .white,
        Color(red: 0.2, green: 0.7, blue: 1.0)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewSection
                    controlSection
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("证件照换底色")
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadImage(from: newValue)
            }
        }
    }

    private var previewSection: some View {
        Group {
            if let displayImage = processedImage ?? originalImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.quaternary, lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.secondary.opacity(0.15))
                    .frame(height: 340)
                    .overlay {
                        ContentUnavailableView(
                            "请选择正面人像",
                            systemImage: "person.crop.rectangle",
                            description: Text("支持从相册导入，自动进行高精度人像抠图")
                        )
                    }
            }
        }
        .frame(minHeight: 280)
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("从相册选择照片", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if originalImage != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("背景颜色")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(presetColors, id: \.self) { color in
                            Button {
                                selectedColor = color
                                Task { await render() }
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if selectedColor == color {
                                            Circle()
                                                .stroke(.black.opacity(0.6), lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        ColorPicker("自定义", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: selectedColor) { _, _ in
                                Task { await render() }
                            }
                    }
                }

                Button {
                    saveToAlbum()
                } label: {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(processedImage == nil)
            }

            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("AI 抠图处理中...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @MainActor
    private func loadImage(from item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "图片加载失败，请重试。"
                return
            }

            originalImage = image
            errorMessage = nil
            await render()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func render() async {
        guard let originalImage else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let uiColor = UIColor(selectedColor)
            let output = try mattingService.process(image: originalImage, background: uiColor)
            processedImage = output
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveToAlbum() {
        guard let processedImage else { return }
        UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
    }
}
