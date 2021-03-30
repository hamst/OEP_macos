#import "BNBFullImageData+Private.h"
#import "BNBFullImageData.h"

#include <conversion.hpp>

namespace {
    class PixelBufferLockingContext {
    public:
        PixelBufferLockingContext(CVPixelBufferRef pixelBuffer)
        : m_pixelBuffer(CVPixelBufferRetain(pixelBuffer))
        , m_locked(pixelBuffer && kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly)) {

        }
        
        ~PixelBufferLockingContext() {
            if (m_locked && m_pixelBuffer) {
                CVPixelBufferUnlockBaseAddress(m_pixelBuffer, kCVPixelBufferLock_ReadOnly);
            }
            CVPixelBufferRelease(m_pixelBuffer);
        }
        
    private:
        const CVPixelBufferRef m_pixelBuffer;
        const bool m_locked;
    };
}


namespace bnb::objcpp
{
    bpc8_image_t::pixel_format_t convert_pixel_format(uint32_t pixel_format)
    {
        switch (pixel_format) {
            case kCVPixelFormatType_24RGB:
                return bpc8_image_t::pixel_format_t::rgb;
            case kCVPixelFormatType_32RGBA:
                return bpc8_image_t::pixel_format_t::rgba;
            case kCVPixelFormatType_24BGR:
                return bpc8_image_t::pixel_format_t::bgr;
            case kCVPixelFormatType_32BGRA:
                return bpc8_image_t::pixel_format_t::bgra;
            case kCVPixelFormatType_32ARGB:
                return bpc8_image_t::pixel_format_t::argb;
            default:
                [NSException
                     raise:NSInternalInconsistencyException
                    format:@"%@", @"Unsupported pixel format!"];
                __builtin_unreachable();
        }
    }

    auto full_image_data::toCpp(ObjcType objc) -> CppType
    {
        if (!objc) {
            return {};
        }

        auto pixelBuffer = objc.pixelBuffer;
        if (!pixelBuffer) {
            return {};
        }

        auto image_format = bnb::image_format();
        image_format.width = objc.width;
        image_format.height = objc.height;
        image_format.require_mirroring = objc.requireMirroring;
        image_format.orientation = bnb::camera_orientation::deg_0;
        image_format.face_orientation = objc.faceOrientation;
        image_format.fov = objc.fieldOfView;

        uint32_t pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        switch (pixelFormat) {
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: {
                
                auto ctx = std::make_shared<PixelBufferLockingContext>(pixelBuffer);
                auto lumo = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
                auto chromo = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));

                return bnb::make_full_image_from_biplanar_yuv_no_copy(
                    image_format,
                    lumo,
                    int32_t(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)),
                    [ctx]() { },
                    chromo,
                    int32_t(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)),
                    [ctx]() { });

            } break;
            case kCVPixelFormatType_24RGB:
            case kCVPixelFormatType_32RGBA:
            case kCVPixelFormatType_24BGR:
            case kCVPixelFormatType_32BGRA:
            case kCVPixelFormatType_32ARGB: {
                CVPixelBufferRetain(pixelBuffer);
                CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

                auto base_address = static_cast<uint8_t*>(CVPixelBufferGetBaseAddress(pixelBuffer));
                auto row_stride = static_cast<int32_t>(CVPixelBufferGetBytesPerRow(pixelBuffer));

                return bnb::make_full_image_from_nonplanar_bpc8_no_copy(
                    image_format,
                    convert_pixel_format(pixelFormat),
                    base_address,
                    row_stride,
                    [pixelBuffer]() {
                        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                        CVPixelBufferRelease(pixelBuffer);
                    });
            } break;
            default:
                break;
        }

        [NSException
             raise:NSInvalidArgumentException
            format:@"%@", @"Unsupported BNBFullImageData"];
        __builtin_unreachable();
    }

} // bnb::objcpp
