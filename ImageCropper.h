#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageCropper : NSObject

/// 按像素精度裁剪图片（会自动处理 imageOrientation）
/// @param image 原图
/// @param cropRect 裁剪区域（以 point 为单位，基于图片显示坐标）
+ (nullable UIImage *)cropImage:(UIImage *)image toRect:(CGRect)cropRect;

/// 按目标宽高比进行居中裁剪
/// @param image 原图
/// @param aspectRatio 宽高比（例如 1:1 传 1.0，16:9 传 16.0/9.0）
+ (nullable UIImage *)cropImage:(UIImage *)image toAspectRatio:(CGFloat)aspectRatio;

@end

NS_ASSUME_NONNULL_END
