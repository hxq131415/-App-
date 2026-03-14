#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDPhotoPreset) {
    IDPhotoPresetOneInch,
    IDPhotoPresetTwoInch,
    IDPhotoPresetSmallTwoInch,
    IDPhotoPresetPassport,
};

@interface IDPhotoProcessor : NSObject

+ (CGSize)pixelSizeForPreset:(IDPhotoPreset)preset;
+ (NSString *)nameForPreset:(IDPhotoPreset)preset;

/// 生成证件照（支持智能裁切 + 人像前景分离换底色）
+ (UIImage *)renderIDPhotoWithSource:(UIImage *)sourceImage
                              preset:(IDPhotoPreset)preset
                     backgroundColor:(UIColor *)backgroundColor
                                zoom:(CGFloat)zoom;

/// 导出高清 PNG 数据
+ (NSData *)pngDataForImage:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
