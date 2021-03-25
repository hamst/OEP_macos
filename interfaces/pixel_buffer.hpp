#pragma once

#include <bnb/types/full_image.hpp>

using oep_image_ready_cb = std::function<void(std::optional<bnb::full_image_t> image)>;

// Lambda gets void* which is the CVPixelBufferRef in nv12
using oep_image_ready_pb_cb = std::function<void(void* image)>;

namespace bnb {
    enum class pixel_format
    {
        rgba,
        nv12,
        texture
    };
} // bnb

namespace bnb::interfaces
{
    class pixel_buffer
    {
    public:
        virtual ~pixel_buffer() = default;

        /**
         * Lock pixel buffer. If you want to keep lock of pixel buffer
         * longer than output image callback scope you should lock pixel buffer.
         * 
         * Example lock()
         */
        virtual void lock() = 0;

        /**
         * Unlock pixel_buffer. Must be called if user explicitly called lock()
         * after the work to process output pixel buffer completed.
         * 
         * Example unlock()
         */
        virtual void unlock() = 0;

        /**
         * Returns the locking state of pixel_buffer.
         * 
         * @return true if pixel_buffer locked else false
         * 
         * Example is_locked()
         */
        virtual bool is_locked() = 0;

        /**
         * In thread with active texture get CVPixelBufferRef from Offscreen_render_target.
         * CVPixelBufferRef can keep rgba, nv12 or texture.
         * If we get rgba the type of CVPixelBufferRef will be bgra. Macos defined kCVPixelFormatType_32RGBA
         * but not supported and we have to choose a different type.
         * 
         * @param callback calling with void*. void* keep CVPixelBufferRef
         * @param image format of ouput
         * 
         * Example get_image([](void* cv_pixel_buffer_ref){}, true)
         */
        virtual void get_image(oep_image_ready_pb_cb callback, ::bnb::pixel_format format) = 0;
    };
} // bnb::interfaces

