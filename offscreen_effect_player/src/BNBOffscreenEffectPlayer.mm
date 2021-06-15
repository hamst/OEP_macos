#import "BNBOffscreenEffectPlayer.h"

#import <Accelerate/Accelerate.h>

#import "BNBFullImageData.h"
#import "BNBFullImageData+Private.h"

#include "offscreen_effect_player.hpp"
#include "offscreen_render_target.h"

#include <bnb/effect_player/utility.hpp>
#include <bnb/postprocess/interfaces/postprocess_helper.hpp>

@implementation BNBOffscreenEffectPlayer {
    NSUInteger _width;
    NSUInteger _height;
    ioep_sptr _oep;
}

- (instancetype)initWithWidth:(NSUInteger)width
                       height:(NSUInteger)height
                  manualAudio:(BOOL)manual {
    if (self = [super init]) {
        _width = width;
        _height = height;

        iort_sptr ort = std::make_shared<bnb::offscreen_render_target>(width, height);
        _oep = bnb::offscreen_effect_player::create(width, height, manual, ort);
    }
    return self;
}

- (void)processImage:(CVPixelBufferRef)pixelBuffer completion:(BNBOEPImageReadyBlock _Nonnull)completion {
    CVPixelBufferRetain(pixelBuffer);
    __block OSType pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
    // TODO: BanubaSdk doesn't support videoRannge(420v) only fullRange(420f) (the YUV on rendering will be processed as 420f), need to add support for BT601 and BT709 videoRange, process as ARGB
    if (pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        pixelBuffer = [self convertYUVVideoRangeToARGB:pixelBuffer];
    }
    BNBFullImageData* inputData = [[BNBFullImageData alloc] init:pixelBuffer requireMirroring:NO faceOrientation:0 fieldOfView:(float) 60];
    ::bnb::full_image_t image = bnb::objcpp::full_image_data::toCpp(inputData);

    auto image_ptr = std::make_shared<bnb::full_image_t>(std::move(image));
    auto get_pixel_buffer_callback = [image_ptr, completion, pixelBuffer](std::optional<ipb_sptr> pb) {
        if (pb.has_value()) {
            auto render_callback = [completion, pixelBuffer](void* cv_pixel_buffer_ref) {
                if (cv_pixel_buffer_ref != nullptr) {
                    CVPixelBufferRef retBuffer = (CVPixelBufferRef)cv_pixel_buffer_ref;

                    if (completion) {
                        @autoreleasepool {
                            completion(retBuffer);
                        }
                    }

                    CVPixelBufferRelease(retBuffer);
                    CVPixelBufferRelease(pixelBuffer);
                }
            };
            (*pb)->get_image(render_callback, bnb::interfaces::image_format::texture);
        }
    };
    std::optional<bnb::interfaces::orient_format> target_orient{ { bnb::camera_orientation::deg_0, true } };
    _oep->process_image_async(image_ptr, get_pixel_buffer_callback, target_orient);
}

- (CVPixelBufferRef)convertYUVVideoRangeToARGB:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void* yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);

    void* uvPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
    size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    size_t uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

    NSDictionary* pixelAttributes = @{(id) kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferRef pixelBufferTmp = NULL;
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        yWidth,
        yHeight,
        kCVPixelFormatType_32ARGB,
        (__bridge CFDictionaryRef)(pixelAttributes),
        &pixelBufferTmp);
    CFAutorelease(pixelBufferTmp);
    CVPixelBufferLockBaseAddress(pixelBufferTmp, 0);

    void* rgbTmp = CVPixelBufferGetBaseAddress(pixelBufferTmp);
    size_t rgbTmpWidth = CVPixelBufferGetWidthOfPlane(pixelBufferTmp, 0);
    size_t rgbTmpHeight = CVPixelBufferGetHeightOfPlane(pixelBufferTmp, 0);
    size_t rgbTmpBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBufferTmp, 0);

    vImage_Buffer ySrcBufferInfo = {
        .width = yWidth,
        .height = yHeight,
        .rowBytes = yBytesPerRow,
        .data = yPlane};
    vImage_Buffer uvSrcBufferInfo = {
        .width = uvWidth,
        .height = uvHeight,
        .rowBytes = uvBytesPerRow,
        .data = uvPlane};

    vImage_Buffer tmpBufferInfo = {
        .width = rgbTmpWidth,
        .height = rgbTmpHeight,
        .rowBytes = rgbTmpBytesPerRow,
        .data = rgbTmp};

    const uint8_t permuteMap[4] = {0, 1, 2, 3};

    static vImage_YpCbCrToARGB infoYpCbCr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      vImage_YpCbCrPixelRange pixelRangeVideoRange = (vImage_YpCbCrPixelRange){16, 128, 235, 240, 255, 0, 255, 1};
      vImageConvert_YpCbCrToARGB_GenerateConversion(
          kvImage_YpCbCrToARGBMatrix_ITU_R_709_2,
          &pixelRangeVideoRange,
          &infoYpCbCr,
          kvImage420Yp8_Cb8_Cr8,
          kvImageARGB8888,
          0);
    });

    vImageConvert_420Yp8_CbCr8ToARGB8888(
        &ySrcBufferInfo,
        &uvSrcBufferInfo,
        &tmpBufferInfo,
        &infoYpCbCr,
        permuteMap,
        0,
        kvImageDoNotTile);


    CVPixelBufferUnlockBaseAddress(pixelBufferTmp, 0);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBufferTmp;
}

- (void)loadEffect:(NSString* _Nonnull)effectName completion:(BNBLoadEffectCompletionBlock _Nullable)completion
{
    NSAssert(self->_oep != nil, @"No OffscreenEffectPlayer");
    bnb::oep_load_effect_cb callback = nullptr;
    if (completion)
    {
        callback = [completion](bool result) {
            @autoreleasepool {
                completion(result);
            }
        };
    }
    _oep->load_effect(std::string([effectName UTF8String]), callback);
}

- (void)unloadEffect
{
    NSAssert(_oep != nil, @"No OffscreenEffectPlayer");
    _oep->unload_effect();
}

- (void)callJsMethod:(NSString* _Nonnull)method withParam:(NSString* _Nonnull)param
{
    NSAssert(_oep != nil, @"No OffscreenEffectPlayer");
    _oep->call_js_method(std::string([method UTF8String]), std::string([param UTF8String]));
}

+ (BOOL)initializeIfNeeded:(NSString * _Nonnull)token resources:(NSArray<NSString *> *_Nonnull)resources
{
    std::string client_token(token.UTF8String);
    std::vector<std::string> path_to_resources = {BNB_RESOURCES_FOLDER};
    for (NSString *path in resources) {
        path_to_resources.emplace_back(path.UTF8String);
    }
    return bnb::interfaces::offscreen_effect_player::initialize_if_needed(path_to_resources, client_token);
}

@end
