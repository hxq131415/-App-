# IDPhotoStudio

一个可直接在 Xcode 打开的 iOS SwiftUI 工程，用于证件照的人像抠图与换底色。

## 功能
- 从相册选择人像照片
- 使用 Vision `VNGeneratePersonSegmentationRequest` 高精度抠图
- 一键切换常用证件照底色（蓝/红/白）和自定义颜色
- 保存处理结果到系统相册

## 运行
1. 使用 Xcode 打开 `IDPhotoStudio.xcodeproj`
2. 选择 iPhone 模拟器或真机
3. 运行后从相册选择照片进行处理
