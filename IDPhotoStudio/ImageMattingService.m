#import "ImageMattingService.h"
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

static NSString *const MattingErrorDomain = @"com.idphotostudio.matting";

@implementation ImageMattingService {
    CIContext *_ciContext;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _ciContext = [CIContext contextWithOptions:@{kCIContextCacheIntermediates: @NO}];
    }
    return self;
}

- (UIImage *)processImage:(UIImage *)image backgroundColor:(UIColor *)backgroundColor error:(NSError **)error {
    CGImageRef cgImage = image.CGImage;
    if (cgImage == nil) {
        if (error) {
            *error = [NSError errorWithDomain:MattingErrorDomain code:100 userInfo:@{NSLocalizedDescriptionKey: @"无法读取图片像素。"}];
        }
        return nil;
    }

    CIImage *maskImage = [self personMaskFromImage:cgImage orientation:[self cgOrientationFromUIImageOrientation:image.imageOrientation] error:error];
    if (maskImage == nil) {
        return nil;
    }

    CIImage *inputImage = [CIImage imageWithCGImage:cgImage];
    CGSize targetSize = inputImage.extent.size;
    CIImage *resizedMask = [self resizeMask:maskImage toSize:targetSize];
    CIImage *refinedMask = [self softenMask:resizedMask];

    CIImage *background = [[CIImage imageWithColor:[[CIColor alloc] initWithColor:backgroundColor]] imageByCroppingToRect:inputImage.extent];

    CIFilter *blend = [CIFilter filterWithName:@"CIBlendWithMask"];
    [blend setValue:inputImage forKey:kCIInputImageKey];
    [blend setValue:background forKey:kCIInputBackgroundImageKey];
    [blend setValue:refinedMask forKey:kCIInputMaskImageKey];

    CIImage *outputImage = blend.outputImage;
    if (outputImage == nil) {
        if (error) {
            *error = [NSError errorWithDomain:MattingErrorDomain code:101 userInfo:@{NSLocalizedDescriptionKey: @"处理失败，请重试。"}];
        }
        return nil;
    }

    CGImageRef rendered = [_ciContext createCGImage:outputImage fromRect:outputImage.extent];
    if (rendered == nil) {
        if (error) {
            *error = [NSError errorWithDomain:MattingErrorDomain code:102 userInfo:@{NSLocalizedDescriptionKey: @"处理失败，请重试。"}];
        }
        return nil;
    }

    UIImage *result = [UIImage imageWithCGImage:rendered scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(rendered);
    return result;
}

- (nullable CIImage *)personMaskFromImage:(CGImageRef)cgImage
                               orientation:(CGImagePropertyOrientation)orientation
                                     error:(NSError **)error {
    VNGeneratePersonSegmentationRequest *request = [[VNGeneratePersonSegmentationRequest alloc] init];
    request.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelAccurate;
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8;
    request.usesCPUOnly = NO;

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage orientation:orientation options:@{}];
    NSError *visionError = nil;
    [handler performRequests:@[request] error:&visionError];
    if (visionError != nil) {
        if (error) {
            *error = visionError;
        }
        return nil;
    }

    VNPixelBufferObservation *observation = request.results.firstObject;
    if (observation.pixelBuffer == nil) {
        if (error) {
            *error = [NSError errorWithDomain:MattingErrorDomain code:103 userInfo:@{NSLocalizedDescriptionKey: @"未识别到清晰的人像主体，请尝试更换图片。"}];
        }
        return nil;
    }

    return [CIImage imageWithCVPixelBuffer:observation.pixelBuffer];
}

- (CIImage *)resizeMask:(CIImage *)mask toSize:(CGSize)targetSize {
    CGFloat scaleX = targetSize.width / CGRectGetWidth(mask.extent);
    CGFloat scaleY = targetSize.height / CGRectGetHeight(mask.extent);
    CIImage *scaled = [mask imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];

    CIFilter *clamp = [CIFilter filterWithName:@"CIAffineClamp"];
    [clamp setValue:scaled forKey:kCIInputImageKey];
    [clamp setValue:[NSValue valueWithCGAffineTransform:CGAffineTransformIdentity] forKey:kCIInputTransformKey];
    CIImage *clamped = clamp.outputImage ?: scaled;

    return [clamped imageByCroppingToRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
}

- (CIImage *)softenMask:(CIImage *)mask {
    CIFilter *gaussian = [CIFilter filterWithName:@"CIGaussianBlur"];
    [gaussian setValue:mask forKey:kCIInputImageKey];
    [gaussian setValue:@1.2 forKey:kCIInputRadiusKey];
    CIImage *blurred = [gaussian.outputImage imageByCroppingToRect:mask.extent] ?: mask;

    CIFilter *controls = [CIFilter filterWithName:@"CIColorControls"];
    [controls setValue:blurred forKey:kCIInputImageKey];
    [controls setValue:@1.15 forKey:kCIInputContrastKey];
    [controls setValue:@0 forKey:kCIInputBrightnessKey];
    [controls setValue:@0 forKey:kCIInputSaturationKey];

    return [controls.outputImage imageByCroppingToRect:mask.extent] ?: mask;
}

- (CGImagePropertyOrientation)cgOrientationFromUIImageOrientation:(UIImageOrientation)orientation {
    switch (orientation) {
        case UIImageOrientationUp: return kCGImagePropertyOrientationUp;
        case UIImageOrientationDown: return kCGImagePropertyOrientationDown;
        case UIImageOrientationLeft: return kCGImagePropertyOrientationLeft;
        case UIImageOrientationRight: return kCGImagePropertyOrientationRight;
        case UIImageOrientationUpMirrored: return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDownMirrored: return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored: return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRightMirrored: return kCGImagePropertyOrientationRightMirrored;
    }
}

@end
