#import "BNBOffscreenEffectPlayer.h"

#import <Accelerate/Accelerate.h>

#include "offscreen_effect_player.hpp"
#include "offscreen_render_target.h"

#include <bnb/effect_player/utility.hpp>
#include <bnb/postprocess/interfaces/postprocess_helper.hpp>

#include <conversion.hpp>

namespace {

class PixelBufferLockContext {
public:
    PixelBufferLockContext(CVPixelBufferRef pixelBuffer)
    : m_pixelBuffer(CVPixelBufferRetain(pixelBuffer))
    , m_locked(pixelBuffer && kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly)) {

    }
    
    ~PixelBufferLockContext() {
        if (m_locked && m_pixelBuffer) {
            CVPixelBufferUnlockBaseAddress(m_pixelBuffer, kCVPixelBufferLock_ReadOnly);
        }
        CVPixelBufferRelease(m_pixelBuffer);
    }
    
private:
    const CVPixelBufferRef m_pixelBuffer;
    const bool m_locked;
};


std::shared_ptr<bnb::full_image_t>  create_full_image(CVPixelBufferRef pixelBuffer) {
    auto image_format = bnb::image_format();
    image_format.width = static_cast<uint32_t>(CVPixelBufferGetWidth(pixelBuffer));
    image_format.height = static_cast<uint32_t>(CVPixelBufferGetHeight(pixelBuffer));
    image_format.require_mirroring = false;
    image_format.orientation = bnb::camera_orientation::deg_0;
    image_format.face_orientation = 0;
    image_format.fov = 60;

    uint32_t pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: {
                auto ctx = std::make_shared<PixelBufferLockContext>(pixelBuffer);
                auto lumo = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
                auto chromo = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
                auto image = bnb::make_full_image_from_biplanar_yuv_no_copy(
                                                                        image_format,
                                                                        lumo,
                                                                        int32_t(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)),
                                                                        [ctx]() { },
                                                                        chromo,
                                                                        int32_t(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)),
                                                                        [ctx]() { });
                return std::make_shared<bnb::full_image_t>(std::move(image));
            }
            break;
        default:
            NSCAssert(NO, @"");
            return nullptr;
    }
}
    
}

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
    auto image = create_full_image(pixelBuffer);
    auto get_pixel_buffer_callback = [image, completion](std::optional<ipb_sptr> pb) {
        if (pb.has_value()) {
            auto render_callback = [completion](void* cv_pixel_buffer_ref) {
                if (cv_pixel_buffer_ref != nullptr) {
                    CVPixelBufferRef retBuffer = (CVPixelBufferRef)cv_pixel_buffer_ref;

                    if (completion) {
                        @autoreleasepool {
                            completion(retBuffer);
                        }
                    }

                    CVPixelBufferRelease(retBuffer);
                }
            };
            (*pb)->get_image(render_callback, bnb::interfaces::image_format::texture);
        }
    };
    std::optional<bnb::interfaces::orient_format> target_orient{ { bnb::camera_orientation::deg_0, true } };
    _oep->process_image_async(image, get_pixel_buffer_callback, target_orient);
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
