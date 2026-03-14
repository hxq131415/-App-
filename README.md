# IDPhotoStudio (Objective-C)

一个可直接在 Xcode 打开的 iOS Objective-C 证件照应用：支持**自拍取景框拍摄**、**AI人像抠图换底色**、**美颜强度调节**与保存相册。

## 主要功能
- 自拍模式：前置相机实时预览，带人像构图框引导。
- 智能抠图：使用 Vision `VNGeneratePersonSegmentationRequest` 进行高精度人像分割。
- 换底色：内置蓝/红/白等证件照常用背景，支持自定义颜色。
- 美颜：可调节美颜强度（降噪+亮度/对比度/饱和度微调）。
- 一键保存：将处理后的证件照保存到系统相册。

## 技术实现
- Objective-C + UIKit（纯代码布局，无 Storyboard）
- AVFoundation（前置相机预览与拍照）
- Vision + Core Image（人像分割与图像合成）

## 运行
1. 使用 Xcode 打开 `IDPhotoStudio.xcodeproj`
2. 选择 iPhone 模拟器或真机
3. 首次运行允许相机/相册权限后使用
