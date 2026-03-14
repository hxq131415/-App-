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
+ (UIImage *)renderIDPhotoWithSource:(UIImage *)sourceImage
                              preset:(IDPhotoPreset)preset
                     backgroundColor:(UIColor *)backgroundColor
                                zoom:(CGFloat)zoom;

@end

NS_ASSUME_NONNULL_END
