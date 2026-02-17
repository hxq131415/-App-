# Wallpaper Studio（iOS SwiftUI）

一个可直接用于上线准备的壁纸 App 模板，主打高颜值视觉风格、收藏与分类筛选体验。

## 功能亮点

- 精美首页：渐变卡片 + 分类筛选 + 搜索。
- 详情页：沉浸式展示、收藏、下载（示例逻辑）、分享入口。
- 收藏页：本地持久化（`UserDefaults`）。
- 设置页：隐私政策、用户协议、开发者邮箱。
- 架构清晰：`Models / Services / ViewModels / Views`。

## 目录结构

- `WallpaperApp/WallpaperApp.swift`：应用入口。
- `WallpaperApp/Models`：数据模型。
- `WallpaperApp/Services`：仓库和本地收藏存储。
- `WallpaperApp/ViewModels`：页面状态管理。
- `WallpaperApp/Views`：UI 页面与组件。

## 上架前必做（App Store）

1. 在 Xcode 中创建 iOS App 工程并导入 `WallpaperApp` 目录源码。
2. 补齐真实图片资源（当前为渐变占位视觉）。
3. 接入真实下载保存逻辑（PhotoKit）与分享逻辑（`ShareLink` 或 `UIActivityViewController`）。
4. 完成以下合规项：
   - 隐私政策与用户协议真实链接。
   - `Info.plist` 中照片权限文案。
   - 如果有订阅，接入 StoreKit2 与恢复购买。
5. 通过真机测试：
   - 暗黑模式
   - 刘海屏适配
   - 弱网和离线场景
6. 准备 App Store Connect 元数据、截图、年龄分级、关键词。

## 设计建议（提升“可上架即用”质量）

- 建立「每日推荐」和「专题合集」模块，提高留存。
- 引入远程配置（如 Firebase Remote Config）以动态运营分类。
- 加入 A/B 测试：按钮文案、订阅弹窗、推荐位排序。

---

如需我继续，我可以下一步直接补齐：
- PhotoKit 真下载保存
- StoreKit2 订阅页
- App Tracking Transparency 与隐私埋点开关
- App Store 审核用的“演示账号说明”和“审核备注模板”
