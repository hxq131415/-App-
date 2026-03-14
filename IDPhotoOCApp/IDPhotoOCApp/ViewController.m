#import "ViewController.h"
#import "IDPhotoProcessor.h"
#import <Photos/Photos.h>

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UISegmentedControl *sizeSegment;
@property (nonatomic, strong) UISegmentedControl *bgSegment;
@property (nonatomic, strong) UISlider *zoomSlider;
@property (nonatomic, strong) UILabel *zoomLabel;
@property (nonatomic, strong) UILabel *sizeHintLabel;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIImage *sourceImage;
@property (nonatomic, strong) UIImage *resultImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"证件照工坊 OC";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}

- (void)setupUI {
    UIButton *pickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [pickButton setTitle:@"上传照片" forState:UIControlStateNormal];
    [pickButton.titleLabel setFont:[UIFont boldSystemFontOfSize:17]];
    [pickButton addTarget:self action:@selector(pickImage) forControlEvents:UIControlEventTouchUpInside];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.saveButton setTitle:@"导出到相册" forState:UIControlStateNormal];
    [self.saveButton.titleLabel setFont:[UIFont boldSystemFontOfSize:17]];
    [self.saveButton addTarget:self action:@selector(savePhoto) forControlEvents:UIControlEventTouchUpInside];
    self.saveButton.enabled = NO;

    self.sizeSegment = [[UISegmentedControl alloc] initWithItems:@[@"一寸", @"二寸", @"小二寸", @"护照"]];
    self.sizeSegment.selectedSegmentIndex = 1;
    [self.sizeSegment addTarget:self action:@selector(rebuildResult) forControlEvents:UIControlEventValueChanged];

    self.bgSegment = [[UISegmentedControl alloc] initWithItems:@[@"蓝底", @"白底", @"红底", @"灰底"]];
    self.bgSegment.selectedSegmentIndex = 0;
    [self.bgSegment addTarget:self action:@selector(rebuildResult) forControlEvents:UIControlEventValueChanged];

    self.zoomSlider = [[UISlider alloc] init];
    self.zoomSlider.minimumValue = 0.7;
    self.zoomSlider.maximumValue = 1.4;
    self.zoomSlider.value = 1.0;
    [self.zoomSlider addTarget:self action:@selector(onZoomChange) forControlEvents:UIControlEventValueChanged];

    self.zoomLabel = [[UILabel alloc] init];
    self.zoomLabel.text = @"缩放 100%";
    self.zoomLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

    self.sizeHintLabel = [[UILabel alloc] init];
    self.sizeHintLabel.text = @"当前输出：二寸 (413x579)";
    self.sizeHintLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    self.sizeHintLabel.textColor = [UIColor secondaryLabelColor];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.backgroundColor = [UIColor whiteColor];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.layer.cornerRadius = 14;
    self.previewImageView.clipsToBounds = YES;
    self.previewImageView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1].CGColor;
    self.previewImageView.layer.borderWidth = 1;

    self.previewImageView.image = [self placeholderImage];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        pickButton,
        self.sizeSegment,
        self.bgSegment,
        self.zoomLabel,
        self.zoomSlider,
        self.sizeHintLabel,
        self.saveButton,
        self.previewImageView
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.previewImageView.heightAnchor constraintEqualToConstant:460]
    ]];
}

- (UIImage *)placeholderImage {
    CGSize size = CGSizeMake(413, 579);
    UIGraphicsBeginImageContextWithOptions(size, YES, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    [[UIColor colorWithRed:0.31 green:0.62 blue:0.97 alpha:1] setFill];
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));

    [[UIColor colorWithWhite:1 alpha:0.8] setFill];
    CGContextFillEllipseInRect(context, CGRectMake(size.width * 0.39, size.height * 0.24, size.width * 0.22, size.width * 0.22));
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size.width * 0.31, size.height * 0.42, size.width * 0.38, size.height * 0.34) cornerRadius:24];
    [body fill];

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:24],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.95]
    };
    [@"上传照片开始制作" drawAtPoint:CGPointMake(size.width * 0.2, size.height * 0.86) withAttributes:attrs];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)pickImage {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        [self showAlert:@"无法访问相册，请在系统设置中开启权限"]; 
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)savePhoto {
    if (!self.resultImage) {
        [self showAlert:@"请先上传并生成证件照"]; 
        return;
    }

    UIImageWriteToSavedPhotosAlbum(self.resultImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *message = error ? @"保存失败，请检查相册写入权限" : @"保存成功，已写入系统相册";
    [self showAlert:message];
}

- (void)onZoomChange {
    NSInteger percent = (NSInteger)roundf(self.zoomSlider.value * 100);
    self.zoomLabel.text = [NSString stringWithFormat:@"缩放 %ld%%", (long)percent];
    [self rebuildResult];
}

- (UIColor *)selectedBackgroundColor {
    switch (self.bgSegment.selectedSegmentIndex) {
        case 0:
            return [UIColor colorWithRed:0.31 green:0.62 blue:0.97 alpha:1];
        case 1:
            return [UIColor whiteColor];
        case 2:
            return [UIColor colorWithRed:0.92 green:0.35 blue:0.35 alpha:1];
        case 3:
            return [UIColor colorWithRed:0.83 green:0.85 blue:0.89 alpha:1];
        default:
            return [UIColor whiteColor];
    }
}

- (void)rebuildResult {
    if (!self.sourceImage) {
        return;
    }

    IDPhotoPreset preset = (IDPhotoPreset)self.sizeSegment.selectedSegmentIndex;
    UIColor *bgColor = [self selectedBackgroundColor];

    self.resultImage = [IDPhotoProcessor renderIDPhotoWithSource:self.sourceImage
                                                          preset:preset
                                                 backgroundColor:bgColor
                                                            zoom:self.zoomSlider.value];
    self.previewImageView.image = self.resultImage;
    self.saveButton.enabled = YES;

    CGSize px = [IDPhotoProcessor pixelSizeForPreset:preset];
    NSString *name = [IDPhotoProcessor nameForPreset:preset];
    self.sizeHintLabel.text = [NSString stringWithFormat:@"当前输出：%@ (%.0fx%.0f)", name, px.width, px.height];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    self.sourceImage = image;
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self rebuildResult];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
