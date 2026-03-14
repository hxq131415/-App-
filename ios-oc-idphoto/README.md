# OC 版证件照 App（UIKit）

这是一个 Objective-C 实现的证件照核心模块，适合直接放进 iOS 工程中使用。

## 功能
- 从相册上传照片
- 常见证件照尺寸切换（1 寸 / 2 寸 / 小 2 寸 / 护照）
- 人像抠图 + 一键换底色（蓝/白/红/灰）
- 人脸检测辅助的智能裁切
- 缩放调节构图
- 导出到系统相册

## 文件说明
- `IDPhotoProcessor.h/.m`：证件照渲染核心（人像抠图、背景替换、智能裁切与缩放）
- `ViewController.h/.m`：示例页面（上传、参数调整、预览、保存）

## 集成步骤
1. 新建 iOS App（UIKit + Objective-C）。
2. 把本目录源码文件拖进工程。
3. 在 `Info.plist` 增加相册权限：
   - `NSPhotoLibraryUsageDescription`
   - `NSPhotoLibraryAddUsageDescription`
4. 在 Target -> Build Phases -> Link Binary With Libraries 添加：
   - `Vision.framework`
   - `CoreImage.framework`
5. 把 `ViewController` 设为首页控制器（可在 `SceneDelegate` 或 Storyboard 设置）。

## 兼容性说明
- `Vision` 人脸检测：iOS 11+
- `VNGeneratePersonSegmentationRequest` 人像抠图：iOS 15+
- iOS 15 以下会自动回退为普通贴图（仅裁切 + 换底）
