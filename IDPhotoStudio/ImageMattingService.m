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
    UIImage *normalized = [self normalizedImage:image];
    CGImageRef cgImage = normalized.CGImage;
    if (cgImage == nil) {
        if (error) {
            *error = [NSError errorWithDomain:MattingErrorDomain code:100 userInfo:@{NSLocalizedDescriptionKey: @"无法读取图片像素。"}];
        }
        return nil;
    }

    CIImage *maskImage = [self personMaskFromImage:cgImage orientation:kCGImagePropertyOrientationUp error:error];
    if (maskImage == nil) {
        return nil;
    }

    CIImage *inputImage = [CIImage imageWithCGImage:cgImage];
    CGSize targetSize = inputImage.extent.size;

    CIImage *resizedMask = [self resizeMask:maskImage toSize:targetSize];
    CIImage *refinedMask = [self strengthenMask:resizedMask];

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

    UIImage *result = [UIImage imageWithCGImage:rendered scale:normalized.scale orientation:UIImageOrientationUp];
    CGImageRelease(rendered);
    return result;
}

- (nullable CIImage *)personMaskFromImage:(CGImageRef)cgImage
                               orientation:(CGImagePropertyOrientation)orientation
                                     error:(NSError **)error {
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage orientation:orientation options:@{}];

    NSError *visionError = nil;
    VNGeneratePersonSegmentationRequest *request = [[VNGeneratePersonSegmentationRequest alloc] init];
    request.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelAccurate;
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8;
    request.usesCPUOnly = NO;
    [handler performRequests:@[request] error:&visionError];

    if (visionError != nil) {
        visionError = nil;
        request = [[VNGeneratePersonSegmentationRequest alloc] init];
        request.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelAccurate;
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8;
        request.usesCPUOnly = YES;
        [handler performRequests:@[request] error:&visionError];
    }

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

    CIFilter *lanczos = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    [lanczos setValue:scaled forKey:kCIInputImageKey];
    [lanczos setValue:@1.0 forKey:kCIInputScaleKey];
    [lanczos setValue:@1.0 forKey:kCIInputAspectRatioKey];
    CIImage *resized = lanczos.outputImage ?: scaled;
    return [resized imageByCroppingToRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
}

- (CIImage *)strengthenMask:(CIImage *)mask {
    CIFilter *maximum = [CIFilter filterWithName:@"CIMorphologyMaximum"];
    [maximum setValue:mask forKey:kCIInputImageKey];
    [maximum setValue:@6.0 forKey:kCIInputRadiusKey];
    CIImage *expanded = maximum.outputImage ?: mask;

    CIFilter *minimum = [CIFilter filterWithName:@"CIMorphologyMinimum"];
    [minimum setValue:expanded forKey:kCIInputImageKey];
    [minimum setValue:@3.0 forKey:kCIInputRadiusKey];
    CIImage *closed = minimum.outputImage ?: expanded;

    CIFilter *gaussian = [CIFilter filterWithName:@"CIGaussianBlur"];
    [gaussian setValue:closed forKey:kCIInputImageKey];
    [gaussian setValue:@1.8 forKey:kCIInputRadiusKey];
    CIImage *blurred = [gaussian.outputImage imageByCroppingToRect:mask.extent] ?: closed;

    CIFilter *controls = [CIFilter filterWithName:@"CIColorControls"];
    [controls setValue:blurred forKey:kCIInputImageKey];
    [controls setValue:@1.35 forKey:kCIInputContrastKey];
    [controls setValue:@0.0 forKey:kCIInputBrightnessKey];
    [controls setValue:@0.0 forKey:kCIInputSaturationKey];
    CIImage *contrasted = controls.outputImage ?: blurred;

    CIFilter *clamp = [CIFilter filterWithName:@"CIColorClamp"];
    [clamp setValue:contrasted forKey:kCIInputImageKey];
    [clamp setValue:[CIVector vectorWithX:0.04 Y:0.04 Z:0.04 W:0.04] forKey:@"inputMinComponents"];
    [clamp setValue:[CIVector vectorWithX:1.0 Y:1.0 Z:1.0 W:1.0] forKey:@"inputMaxComponents"];

    return [clamp.outputImage imageByCroppingToRect:mask.extent] ?: contrasted;
}

- (UIImage *)normalizedImage:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: image;
}

@end
