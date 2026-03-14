#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageMattingService : NSObject

- (nullable UIImage *)processImage:(UIImage *)image
                    backgroundColor:(UIColor *)backgroundColor
                              error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
