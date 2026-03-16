#import "ImageCropper.h"

@implementation ImageCropper

+ (UIImage *)normalizedImage:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:(CGRect){.origin = CGPointZero, .size = image.size}];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: image;
}

+ (nullable UIImage *)cropImage:(UIImage *)image toRect:(CGRect)cropRect {
    if (!image) { return nil; }

    UIImage *normalized = [self normalizedImage:image];

    // point -> pixel
    CGFloat scale = normalized.scale;
    CGRect pixelRect = CGRectMake(cropRect.origin.x * scale,
                                  cropRect.origin.y * scale,
                                  cropRect.size.width * scale,
                                  cropRect.size.height * scale);

    CGSize pixelSize = CGSizeMake(normalized.size.width * scale,
                                  normalized.size.height * scale);

    CGRect bounds = CGRectMake(0, 0, pixelSize.width, pixelSize.height);
    CGRect validRect = CGRectIntersection(bounds, pixelRect);
    if (CGRectIsNull(validRect) || CGRectIsEmpty(validRect)) {
        return nil;
    }

    CGImageRef cgImage = CGImageCreateWithImageInRect(normalized.CGImage, validRect);
    if (!cgImage) { return nil; }

    UIImage *result = [UIImage imageWithCGImage:cgImage
                                           scale:normalized.scale
                                     orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return result;
}

+ (nullable UIImage *)cropImage:(UIImage *)image toAspectRatio:(CGFloat)aspectRatio {
    if (!image || aspectRatio <= 0) {
        return nil;
    }

    UIImage *normalized = [self normalizedImage:image];

    CGFloat width = normalized.size.width;
    CGFloat height = normalized.size.height;
    CGFloat currentRatio = width / height;

    CGRect cropRect = CGRectZero;
    if (currentRatio > aspectRatio) {
        // 图片偏宽：裁掉左右
        CGFloat targetWidth = height * aspectRatio;
        CGFloat x = (width - targetWidth) / 2.0;
        cropRect = CGRectMake(x, 0, targetWidth, height);
    } else {
        // 图片偏高：裁掉上下
        CGFloat targetHeight = width / aspectRatio;
        CGFloat y = (height - targetHeight) / 2.0;
        cropRect = CGRectMake(0, y, width, targetHeight);
    }

    return [self cropImage:normalized toRect:cropRect];
}

@end
