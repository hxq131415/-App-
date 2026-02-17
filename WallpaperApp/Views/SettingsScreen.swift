import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        List {
            Section("订阅与权限") {
                Label("恢复购买", systemImage: "arrow.clockwise")
                Label("通知提醒", systemImage: "bell.badge")
                Label("照片权限", systemImage: "photo")
            }

            Section("支持") {
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    Label("隐私政策", systemImage: "lock.shield")
                }
                Link(destination: URL(string: "https://example.com/terms")!) {
                    Label("用户协议", systemImage: "doc.text")
                }
                Link(destination: URL(string: "mailto:support@example.com")!) {
                    Label("联系开发者", systemImage: "envelope")
                }
            }

            Section("版本") {
                Text("Wallpaper Studio 1.0.0")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .listStyle(.insetGrouped)
    }
}
