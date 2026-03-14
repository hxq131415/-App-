# OC 版证件照 App（UIKit）

这是一个 Objective-C 实现的证件照核心模块，适合直接放进 iOS 工程中使用。

## 功能
- 从相册上传照片
- 常见证件照尺寸切换（1 寸 / 2 寸 / 小 2 寸 / 护照）
- 背景色切换（蓝/白/红/灰）
- 缩放调节构图
- 导出到系统相册

## 文件说明
- `IDPhotoProcessor.h/.m`：证件照渲染核心（尺寸、背景填充、按比例裁切与缩放）
- `ViewController.h/.m`：示例页面（上传、参数调整、预览、保存）

## 集成步骤
1. 新建 iOS App（UIKit + Objective-C）。
2. 把本目录 4 个源码文件拖进工程。
3. 在 `Info.plist` 增加相册权限：
   - `NSPhotoLibraryUsageDescription`
   - `NSPhotoLibraryAddUsageDescription`
4. 把 `ViewController` 设为首页控制器（可在 `SceneDelegate` 或 Storyboard 设置）。

## 说明
当前实现聚焦“可直接落地”的证件照核心流程。后续可继续加：
- 人像抠图（分离前景/背景）
- 服装模板替换
- 批量规格导出
- 美颜与光照优化
