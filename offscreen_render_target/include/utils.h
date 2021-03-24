#include <functional>

#import <Accelerate/Accelerate.h>

namespace bnb
{
    enum class vrange
    {
        video_range,
        full_range
    };

    void runOnMainQueue(std::function<void()> f);

    void* nsGLGetProcAddress(const char *name);

    CVPixelBufferRef convertRGBAtoNV12(CVPixelBufferRef inputPixelBuffer, vrange range);
} // bnb
