#import "IDPhotoProcessor.h"
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>

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

+ (NSData *)pngDataForImage:(UIImage *)image {
    return UIImagePNGRepresentation(image);
}

+ (UIImage *)renderIDPhotoWithSource:(UIImage *)sourceImage
                              preset:(IDPhotoPreset)preset
                     backgroundColor:(UIColor *)backgroundColor
                                zoom:(CGFloat)zoom {
    CGSize targetSize = [self pixelSizeForPreset:preset];
    CGFloat safeZoom = MAX(0.7, MIN(1.6, zoom));

    UIImage *fixedImage = [self normalizedImage:sourceImage];
    UIImage *cropped = [self smartCropImage:fixedImage targetRatio:targetSize.width / targetSize.height zoom:safeZoom];
    UIImage *foreground = [self cutoutPersonFromImage:cropped];

    UIGraphicsBeginImageContextWithOptions(targetSize, YES, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, targetSize.width, targetSize.height));

    [foreground drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];

    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1 alpha:0.8].CGColor);
    CGContextSetLineWidth(context, MAX(2, targetSize.width * 0.005));
    CGContextStrokeRect(context, CGRectMake(0, 0, targetSize.width, targetSize.height));

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

+ (UIImage *)normalizedImage:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized;
}

+ (UIImage *)smartCropImage:(UIImage *)image targetRatio:(CGFloat)targetRatio zoom:(CGFloat)zoom {
    CGSize size = image.size;
    CGRect faceRect = [self detectPrimaryFaceInImage:image];

    CGPoint focus;
    if (CGRectIsEmpty(faceRect)) {
        focus = CGPointMake(size.width * 0.5, size.height * 0.42);
    } else {
        focus = CGPointMake(CGRectGetMidX(faceRect), CGRectGetMidY(faceRect) + CGRectGetHeight(faceRect) * 0.45);
    }

    CGFloat cropW;
    CGFloat cropH;
    CGFloat srcRatio = size.width / size.height;

    if (srcRatio > targetRatio) {
        cropH = size.height / zoom;
        cropW = cropH * targetRatio;
    } else {
        cropW = size.width / zoom;
        cropH = cropW / targetRatio;
    }

    cropW = MIN(cropW, size.width);
    cropH = MIN(cropH, size.height);

    CGFloat x = focus.x - cropW * 0.5;
    CGFloat y = focus.y - cropH * 0.5;

    x = MAX(0, MIN(x, size.width - cropW));
    y = MAX(0, MIN(y, size.height - cropH));

    CGRect cropRect = CGRectIntegral(CGRectMake(x, y, cropW, cropH));
    CGImageRef cg = CGImageCreateWithImageInRect(image.CGImage, cropRect);
    UIImage *cropped = [UIImage imageWithCGImage:cg scale:image.scale orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    return cropped;
}

+ (CGRect)detectPrimaryFaceInImage:(UIImage *)image {
    if (!image.CGImage) {
        return CGRectZero;
    }

    VNDetectFaceRectanglesRequest *request = [[VNDetectFaceRectanglesRequest alloc] init];
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage options:@{}];
    NSError *error = nil;
    [handler performRequests:@[request] error:&error];
    if (error || request.results.count == 0) {
        return CGRectZero;
    }

    VNFaceObservation *best = request.results.firstObject;
    for (VNFaceObservation *obs in request.results) {
        if (obs.boundingBox.size.width * obs.boundingBox.size.height > best.boundingBox.size.width * best.boundingBox.size.height) {
            best = obs;
        }
    }

    CGRect n = best.boundingBox;
    CGSize s = image.size;
    CGRect imgRect = CGRectMake(n.origin.x * s.width,
                                (1 - n.origin.y - n.size.height) * s.height,
                                n.size.width * s.width,
                                n.size.height * s.height);
    return imgRect;
}

+ (UIImage *)cutoutPersonFromImage:(UIImage *)image {
    if (@available(iOS 15.0, *)) {
        if (!image.CGImage) {
            return image;
        }

        VNGeneratePersonSegmentationRequest *request = [[VNGeneratePersonSegmentationRequest alloc] init];
        request.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelAccurate;
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8;

        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage options:@{}];
        NSError *error = nil;
        [handler performRequests:@[request] error:&error];
        if (error || request.results.count == 0) {
            return image;
        }

        VNPixelBufferObservation *obs = request.results.firstObject;
        CIImage *person = [CIImage imageWithCGImage:image.CGImage];
        CIImage *mask = [CIImage imageWithCVPixelBuffer:obs.pixelBuffer];

        CGFloat sx = person.extent.size.width / MAX(mask.extent.size.width, 1);
        CGFloat sy = person.extent.size.height / MAX(mask.extent.size.height, 1);
        mask = [mask imageByApplyingTransform:CGAffineTransformMakeScale(sx, sy)];

        CIFilter *blend = [CIFilter filterWithName:@"CIBlendWithMask"];
        [blend setValue:person forKey:kCIInputImageKey];
        [blend setValue:[CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:0]] forKey:kCIInputBackgroundImageKey];
        [blend setValue:mask forKey:kCIInputMaskImageKey];

        CIImage *out = blend.outputImage;
        CIContext *context = [CIContext contextWithOptions:nil];
        CGImageRef cg = [context createCGImage:out fromRect:person.extent];
        UIImage *foreground = [UIImage imageWithCGImage:cg scale:image.scale orientation:UIImageOrientationUp];
        CGImageRelease(cg);
        return foreground;
    }
    return image;
}

@end
