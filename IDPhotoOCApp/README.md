# IDPhotoOCApp（可直接运行的 Objective-C 工程）

这是一个完整的 **UIKit + Objective-C** iOS 工程，打开 `IDPhotoOCApp.xcodeproj` 即可运行（需 macOS + Xcode）。

## 现在已支持
- 一键换底色（蓝/白/红/灰）
- 智能裁切（基于人脸检测自动构图）
- 高清下载（PNG 导出分享）
- 常见证件照规格（1寸/2寸/小2寸/护照）
- 保存到系统相册

> 人像分割换底色使用 Vision 框架：iOS 15+ 为最佳效果；低版本会自动回退为普通贴图。

## 目录结构
- `IDPhotoOCApp.xcodeproj`：Xcode 工程文件
- `IDPhotoOCApp/main.m`：应用入口
- `IDPhotoOCApp/AppDelegate.*`、`SceneDelegate.*`：应用生命周期
- `IDPhotoOCApp/ViewController.*`：页面与交互
- `IDPhotoOCApp/IDPhotoProcessor.*`：智能裁切 + 人像分割 + 渲染核心
- `IDPhotoOCApp/Info.plist`：权限配置
- `IDPhotoOCApp/Assets.xcassets`：资源目录

## 运行步骤
1. 用 Xcode 打开：`IDPhotoOCApp/IDPhotoOCApp.xcodeproj`
2. 在 Target > Signing & Capabilities 设置 Team
3. 如有需要修改 Bundle Identifier
4. 运行到模拟器或真机

## 权限
已配置：
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
