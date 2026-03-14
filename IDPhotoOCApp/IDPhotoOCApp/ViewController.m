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
@property (nonatomic, strong) UIButton *downloadButton;
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
    [self.saveButton setTitle:@"保存到相册" forState:UIControlStateNormal];
    [self.saveButton addTarget:self action:@selector(savePhoto) forControlEvents:UIControlEventTouchUpInside];
    self.saveButton.enabled = NO;

    self.downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.downloadButton setTitle:@"高清下载 PNG" forState:UIControlStateNormal];
    [self.downloadButton addTarget:self action:@selector(downloadPNG) forControlEvents:UIControlEventTouchUpInside];
    self.downloadButton.enabled = NO;

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

    self.sizeHintLabel = [[UILabel alloc] init];
    self.sizeHintLabel.text = @"当前输出：二寸 (413x579)";
    self.sizeHintLabel.font = [UIFont systemFontOfSize:13];
    self.sizeHintLabel.textColor = [UIColor secondaryLabelColor];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.backgroundColor = [UIColor whiteColor];
    self.previewImageView.layer.cornerRadius = 14;
    self.previewImageView.clipsToBounds = YES;
    self.previewImageView.image = [self placeholderImage];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        pickButton,
        self.sizeSegment,
        self.bgSegment,
        self.zoomLabel,
        self.zoomSlider,
        self.sizeHintLabel,
        self.saveButton,
        self.downloadButton,
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
    [[UIColor colorWithRed:0.31 green:0.62 blue:0.97 alpha:1] setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)pickImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)savePhoto {
    if (!self.resultImage) {
        [self showAlert:@"请先上传并生成证件照"]; return;
    }
    UIImageWriteToSavedPhotosAlbum(self.resultImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)downloadPNG {
    if (!self.resultImage) {
        [self showAlert:@"请先上传并生成证件照"]; return;
    }

    NSData *png = [IDPhotoProcessor pngDataForImage:self.resultImage];
    if (png.length == 0) {
        [self showAlert:@"导出失败"]; return;
    }

    IDPhotoPreset preset = (IDPhotoPreset)self.sizeSegment.selectedSegmentIndex;
    CGSize px = [IDPhotoProcessor pixelSizeForPreset:preset];
    NSString *filename = [NSString stringWithFormat:@"证件照-%.0fx%.0f.png", px.width, px.height];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    [png writeToFile:path atomically:YES];

    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        vc.popoverPresentationController.sourceView = self.downloadButton;
        vc.popoverPresentationController.sourceRect = self.downloadButton.bounds;
    }
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self showAlert:(error ? @"保存失败" : @"已保存到相册")];
}

- (void)onZoomChange {
    NSInteger percent = (NSInteger)roundf(self.zoomSlider.value * 100);
    self.zoomLabel.text = [NSString stringWithFormat:@"缩放 %ld%%", (long)percent];
    [self rebuildResult];
}

- (UIColor *)selectedBackgroundColor {
    switch (self.bgSegment.selectedSegmentIndex) {
        case 0: return [UIColor colorWithRed:0.31 green:0.62 blue:0.97 alpha:1];
        case 1: return [UIColor whiteColor];
        case 2: return [UIColor colorWithRed:0.92 green:0.35 blue:0.35 alpha:1];
        case 3: return [UIColor colorWithRed:0.83 green:0.85 blue:0.89 alpha:1];
        default: return [UIColor whiteColor];
    }
}

- (void)rebuildResult {
    if (!self.sourceImage) return;

    IDPhotoPreset preset = (IDPhotoPreset)self.sizeSegment.selectedSegmentIndex;
    self.resultImage = [IDPhotoProcessor renderIDPhotoWithSource:self.sourceImage
                                                          preset:preset
                                                 backgroundColor:[self selectedBackgroundColor]
                                                            zoom:self.zoomSlider.value];

    self.previewImageView.image = self.resultImage;
    self.saveButton.enabled = YES;
    self.downloadButton.enabled = YES;

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
