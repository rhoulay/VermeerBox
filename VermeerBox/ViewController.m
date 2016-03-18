//
//  ViewController.m
//  VermeerBox
//
//  Created by Felix He on 3/14/16.
//  Copyright © 2016 Felix He. All rights reserved.
//

#define WeakRef(__obj) __weak typeof(self) __obj = self
#define WeakReturn(__obj) if(__obj ==nil)return;

#import <DJISDK/DJISDK.h>
#import "ViewController.h"
#import <VideoPreviewer/VideoPreviewer.h>

@interface ViewController ()<DJICameraDelegate, DJISDKManagerDelegate, UIScrollViewDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *container_view;
@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;
@property (weak, nonatomic) IBOutlet UIView *video_image_container;
@property (weak, nonatomic) IBOutlet UIImageView *image_view;

@property (nonatomic) UIImagePickerController *imagePickerController;

@property(nonatomic, assign) BOOL needToSetMode;

@property (assign, nonatomic) float currentImageAlpha;
@property (weak, nonatomic) IBOutlet UIButton *showHideButton;

@property (weak, nonatomic) IBOutlet UIButton *imageButton;

@end

@implementation ViewController

- (void)registerApp
{
    NSString *appKey = @"1d00621da7536f7df7e31daa";
    [DJISDKManager registerApp:appKey withDelegate:self];
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)sdkManagerDidRegisterAppWithError:(NSError *)error
{
    NSString* message = @"Register App Successed!";
    if (error) {
        message = @"Register App Failed! Please enter your App Key and check the network.";
    }else
    {
        NSLog(@"registerAppSuccess");
        
        [DJISDKManager startConnectionToProduct];
        [[VideoPreviewer instance] start];
    }
    
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    DJICamera* camera = [self fetchCamera];
    
    if (camera) {
        camera.delegate = self;
    }
    
    self.needToSetMode = YES;
    
    [[VideoPreviewer instance] start];
    [[VideoPreviewer instance] setDecoderWithProduct:[DJISDKManager product] andDecoderType:VideoPreviewerDecoderTypeSoftwareDecoder];
    
    // GestureRecognizer
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.container_view addGestureRecognizer:gesture];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [panGesture setDelegate:self];
    [panGesture setMinimumNumberOfTouches:2];
    [panGesture setMaximumNumberOfTouches:2];
    [self.container_view addGestureRecognizer:panGesture];
    
    self.container_view.delegate = self;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self registerApp];
    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    
//    [self updateThermalCameraUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[VideoPreviewer instance] unSetView];
}


- (void)updateThermalCameraUI {
    DJICamera* camera = [self fetchCamera];
    NSLog(@"%d", [camera isThermalImagingCamera]);
    if (camera && [camera isThermalImagingCamera]) {
        [self.fpvPreviewView setHidden:NO];
//        WeakRef(target);
//        [camera getThermalTemperatureDataEnabledWithCompletion:^(BOOL enabled, NSError * _Nullable error) {
//            WeakReturn(target);
//            if (error) {
//                ShowResult(@"Failed to get the Thermal Temperature Data enable status: %@", error.description);
//            }
//            else {
//                [target.fpvTemEnableSwitch setOn:enabled];
//            }
//        }];
    }
    else {
        [self.fpvPreviewView setHidden:YES];
    }
}

#pragma mark Custom Methods
- (DJICamera*) fetchCamera {
    
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).camera;
    }
    else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).camera;
    }
    
    return nil;
}

#pragma mark - DJICameraDelegate
/**
 *  This video data is received through this method. Then the data is passed to VideoPreviewer.
 */
- (void)camera:(DJICamera *)camera didReceiveVideoData:(uint8_t *)videoBuffer length:(size_t)size
{
    uint8_t* pBuffer = (uint8_t*)malloc(size);
    memcpy(pBuffer, videoBuffer, size);
    if(![[[VideoPreviewer instance] dataQueue] isFull]){
        [[VideoPreviewer instance] push:pBuffer length:(int)size];
    }
}

/**
 *  DJICamera will send the live stream only when the mode is in DJICameraModeShootPhoto or DJICameraModeRecordVideo. Therefore, in order
 *  to demonstrate the FPV (first person view), we need to switch to mode to one of them.
 */
-(void)camera:(DJICamera *)camera didUpdateSystemState:(DJICameraSystemState *)systemState
{
    if (systemState.mode == DJICameraModePlayback ||
        systemState.mode == DJICameraModeMediaDownload) {
        if (self.needToSetMode) {
            self.needToSetMode = NO;
            WeakRef(obj);
            [camera setCameraMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    WeakReturn(obj);
                    obj.needToSetMode = YES;
                }
            }];
        }
    }
}


-(void) sdkManagerProductDidChangeFrom:(DJIBaseProduct* _Nullable) oldProduct to:(DJIBaseProduct* _Nullable) newProduct{
    __weak DJICamera* camera = [self fetchCamera];
    if (camera) {
        [camera setDelegate:self];
//        [[VideoPreviewer instance] setType:(VideoPreviewerTypeFullWindow)];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.video_image_container;
}

#pragma mark - UIImagePicker Button

- (IBAction)showImagePickerForPhotoPicker:(id)sender {
    [self showImagePickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    
}

- (IBAction)imageShowHideDown:(id)sender {
    self.image_view.alpha = 0;
    
}
- (IBAction)imageShowHideUp:(id)sender {
    
    self.image_view.alpha = _currentImageAlpha;
    
}

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType
{
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.sourceType = sourceType;
    imagePickerController.delegate = self;
    
    self.imagePickerController = imagePickerController;
    [self presentViewController:self.imagePickerController animated:YES completion:nil];
}


#pragma mark - UIImagePickerControllerDelegate

// This method is called when an image has been chosen from the library or taken from the camera.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    [self.image_view setImage:image];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
    self.imagePickerController = nil;
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)handleTap:(id)sender
{
    BOOL hidden = _showHideButton.hidden;
    
    if(!hidden){
        _showHideButton.hidden = YES;
        _imageButton.hidden = YES;
    }
    else{
        _showHideButton.hidden = NO;
        _imageButton.hidden = NO;

    }
}

- (void)pan:(UIPanGestureRecognizer *)recognizer
{
    if ((recognizer.state == UIGestureRecognizerStateChanged) ||
        (recognizer.state == UIGestureRecognizerStateEnded))
    {
        CGPoint velocity = [recognizer velocityInView:self.view];
        
        if (velocity.y > 0)   // panning down
        {
            
            self.image_view.alpha -= .03;
        }
        else if(velocity.y < 0)                // panning up
        {
            self.image_view.alpha += .03;
        }
        
        _currentImageAlpha = self.image_view.alpha;
    }
}

@end
