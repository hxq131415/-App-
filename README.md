# OC 实现图片裁剪

这是一个轻量的 Objective-C 图片裁剪工具，核心文件：

- `ImageCropper.h`
- `ImageCropper.m`

## 功能

1. **按矩形区域裁剪**：`cropImage:toRect:`
2. **按宽高比居中裁剪**：`cropImage:toAspectRatio:`（例如 1:1、16:9）
3. 自动处理 `imageOrientation`，避免旋转图片裁剪错位。

## 使用示例

```objective-c
#import "ImageCropper.h"

UIImage *source = [UIImage imageNamed:@"demo"];

// 1) 按区域裁剪（单位：point）
CGRect rect = CGRectMake(50, 100, 200, 200);
UIImage *croppedRect = [ImageCropper cropImage:source toRect:rect];

// 2) 按比例裁剪（16:9）
UIImage *cropped169 = [ImageCropper cropImage:source toAspectRatio:(16.0 / 9.0)];
```

## 说明

- 裁剪参数 `CGRect` 以图片显示坐标（point）传入，内部会自动按 `scale` 转成像素。
- 若裁剪区域越界，会自动做交集处理。
- 若区域无效，返回 `nil`。
