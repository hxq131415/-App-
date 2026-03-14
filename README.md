# IDPhotoStudio (Objective-C)

一个可直接在 Xcode 打开的 iOS Objective-C 证件照应用：支持**首页自拍构图拍摄**，并在**下一页**完成 AI 抠图、换底色、美颜与保存。

## 主要功能
- 首页拍摄页：前置相机实时预览 + 人像构图框 + 自拍拍摄 / 相册导入。
- 编辑页：单独进行 AI 人像抠图、证件照底色切换、自定义颜色、美颜强度调节。
- 抠图增强：Vision 人像分割 + 形态学闭运算（膨胀/腐蚀）+ 模糊平滑，降低发丝/边缘缺失。
- 一键保存：将处理后的证件照保存到系统相册。

## 技术实现
- Objective-C + UIKit（纯代码布局，无 Storyboard）
- AVFoundation（前置相机预览与拍照）
- Vision + Core Image（人像分割、遮罩增强、图像合成）

## 运行
1. 使用 Xcode 打开 `IDPhotoStudio.xcodeproj`
2. 选择 iPhone 模拟器或真机
3. 首次运行允许相机/相册权限后使用
