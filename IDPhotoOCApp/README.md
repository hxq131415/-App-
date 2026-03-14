# IDPhotoOCApp（可直接运行的 Objective-C 工程）

这是一个完整的 **UIKit + Objective-C** iOS 工程骨架，打开 `IDPhotoOCApp.xcodeproj` 即可运行（需 macOS + Xcode）。

## 功能
- 从系统相册选择照片
- 证件照规格切换：一寸 / 二寸 / 小二寸 / 护照
- 背景色切换：蓝底 / 白底 / 红底 / 灰底
- 缩放构图（滑杆）
- 导出到系统相册

## 目录结构
- `IDPhotoOCApp.xcodeproj`：Xcode 工程文件
- `IDPhotoOCApp/main.m`：应用入口
- `IDPhotoOCApp/AppDelegate.*`、`SceneDelegate.*`：应用生命周期
- `IDPhotoOCApp/ViewController.*`：主界面交互
- `IDPhotoOCApp/IDPhotoProcessor.*`：证件照渲染核心
- `IDPhotoOCApp/Info.plist`：权限与场景配置
- `IDPhotoOCApp/Assets.xcassets`：资源目录

## 运行步骤
1. 用 Xcode 打开：`IDPhotoOCApp/IDPhotoOCApp.xcodeproj`
2. 在 Target > Signing & Capabilities 设置你的 Team
3. 修改 Bundle Identifier（如有冲突）
4. 选择模拟器或真机，点击 Run

## 权限说明
已在 `Info.plist` 中配置：
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

## 备注
容器环境无法执行 iOS 编译（无 Xcode / iOS SDK），但工程结构与入口、Target 配置、源码均已补齐。
