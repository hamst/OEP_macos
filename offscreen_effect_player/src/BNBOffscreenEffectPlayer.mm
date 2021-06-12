#import "BNBOffscreenEffectPlayer.h"

#import <Accelerate/Accelerate.h>

#import "BNBFullImageData.h"
#import "BNBFullImageData+Private.h"

#include "offscreen_effect_player.hpp"
#include "offscreen_render_target.h"


@implementation BNBOffscreenEffectPlayer
{
    NSUInteger _width;
    NSUInteger _height;

    ioep_sptr oep;
}

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class BNBOffscreenEffectPlayer"
                                 userInfo:nil];
}

- (instancetype)initWithWidth:(NSUInteger)width
                       height:(NSUInteger)height
                  manualAudio:(BOOL)manual
                        token:(NSString*)token;
{
    _width = width;
    _height = height;

    std::optional<iort_sptr> ort = std::make_shared<bnb::offscreen_render_target>(width, height);
    oep = bnb::offscreen_effect_player::create({ BNB_RESOURCES_FOLDER }, std::string([token UTF8String]), width, height, manual, ort);

    return self;
}

- (void)processImage:(CVPixelBufferRef)pixelBuffer completion:(BNBOEPImageReadyBlock _Nonnull)completion
{
    __block OSType pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
    // TODO: BanubaSdk doesn't support videoRannge(420v) only fullRange(420f) (the YUV on rendering will be processed as 420f), need to add support for BT601 and BT709 videoRange, process as ARGB
    if (pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        pixelBuffer = [self convertYUVVideoRangeToARGB:pixelBuffer];
    }
    BNBFullImageData* inputData = [[BNBFullImageData alloc] init:pixelBuffer requireMirroring:(YES) faceOrientation:0 fieldOfView:(float) 60];
    ::bnb::full_image_t image = bnb::objcpp::full_image_data::toCpp(inputData);

    auto image_ptr = std::make_shared<bnb::full_image_t>(std::move(image));
    auto get_pixel_buffer_callback = [image_ptr, completion](std::optional<ipb_sptr> pb) {
        if (pb.has_value()) {
            auto render_callback = [completion](void* cv_pixel_buffer_ref) {
                if (cv_pixel_buffer_ref != nullptr) {
                    CVPixelBufferRef retBuffer = (CVPixelBufferRef)cv_pixel_buffer_ref;

                    if (completion) {
                        completion(retBuffer);
                    }

                    CVPixelBufferRelease(retBuffer);
                }
            };
            (*pb)->get_image(render_callback, bnb::interfaces::image_format::texture);
        }
    };
    std::optional<bnb::interfaces::orient_format> target_orient{ { bnb::camera_orientation::deg_0, true } };
    oep->process_image_async(image_ptr, get_pixel_buffer_callback, target_orient);
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

- (void)loadEffect:(NSString* _Nonnull)effectName
{
    NSAssert(self->oep != nil, @"No OffscreenEffectPlayer");
    oep->load_effect(std::string([effectName UTF8String]), nullptr);
}

- (void)unloadEffect
{
    NSAssert(self->oep != nil, @"No OffscreenEffectPlayer");
    oep->unload_effect();
}

- (void)callJsMethod:(NSString* _Nonnull)method withParam:(NSString* _Nonnull)param
{
    NSAssert(self->oep != nil, @"No OffscreenEffectPlayer");
    oep->call_js_method(std::string([method UTF8String]), std::string([param UTF8String]));
}

@end
