#import "IDPhotoProcessor.h"

@implementation IDPhotoProcessor

+ (CGSize)pixelSizeForPreset:(IDPhotoPreset)preset {
    switch (preset) {
        case IDPhotoPresetOneInch:
            return CGSizeMake(295, 413);
        case IDPhotoPresetTwoInch:
            return CGSizeMake(413, 579);
        case IDPhotoPresetSmallTwoInch:
            return CGSizeMake(413, 531);
        case IDPhotoPresetPassport:
            return CGSizeMake(354, 472);
    }
}

+ (NSString *)nameForPreset:(IDPhotoPreset)preset {
    switch (preset) {
        case IDPhotoPresetOneInch:
            return @"一寸";
        case IDPhotoPresetTwoInch:
            return @"二寸";
        case IDPhotoPresetSmallTwoInch:
            return @"小二寸";
        case IDPhotoPresetPassport:
            return @"护照";
    }
}

+ (UIImage *)renderIDPhotoWithSource:(UIImage *)sourceImage
                              preset:(IDPhotoPreset)preset
                     backgroundColor:(UIColor *)backgroundColor
                                zoom:(CGFloat)zoom {
    CGSize targetSize = [self pixelSizeForPreset:preset];
    CGFloat safeZoom = MAX(0.7, MIN(1.6, zoom));

    UIGraphicsBeginImageContextWithOptions(targetSize, YES, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, targetSize.width, targetSize.height));

    CGSize srcSize = sourceImage.size;
    CGFloat targetRatio = targetSize.width / targetSize.height;
    CGFloat srcRatio = srcSize.width / srcSize.height;

    CGFloat drawW;
    CGFloat drawH;

    if (srcRatio > targetRatio) {
        drawH = targetSize.height * safeZoom;
        drawW = drawH * srcRatio;
    } else {
        drawW = targetSize.width * safeZoom;
        drawH = drawW / srcRatio;
    }

    CGRect drawRect = CGRectMake((targetSize.width - drawW) * 0.5,
                                 (targetSize.height - drawH) * 0.5,
                                 drawW,
                                 drawH);
    [sourceImage drawInRect:drawRect];

    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1 alpha:0.8].CGColor);
    CGContextSetLineWidth(context, MAX(2, targetSize.width * 0.005));
    CGContextStrokeRect(context, CGRectMake(0, 0, targetSize.width, targetSize.height));

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@end
