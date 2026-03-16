# iOS 图片裁剪示例

这个仓库提供了一个纯 UIKit 的图片裁剪实现，包含：

- `UIImage` 的基础裁剪扩展（按像素坐标裁剪）
- 基于 `UIScrollView` 的交互式裁剪页面（支持拖拽、缩放）
- 固定比例裁剪框（默认 1:1，可改成任意比例）

核心文件：`ios/ImageCropViewController.swift`。

## 用法

1. 将 `ios/ImageCropViewController.swift` 拷贝到你的项目。
2. 从相册拿到 `UIImage` 后初始化控制器：

```swift
let cropVC = ImageCropViewController(image: originalImage, aspectRatio: CGSize(width: 1, height: 1)) { croppedImage in
    // 使用裁剪结果
    imageView.image = croppedImage
}
navigationController?.pushViewController(cropVC, animated: true)
```

3. 点击右上角“裁剪”拿到结果。

## 说明

- 裁剪时会把界面坐标转换到原图像素坐标，保证导出清晰度。
- 如需圆形头像裁剪，可在拿到方图后再做遮罩处理。
