#pragma once

#include <bnb/types/full_image.hpp>

using oep_image_ready_cb = std::function<void(std::optional<bnb::full_image_t> image)>;

// Lambda gets void* which is the CVPixelBufferRef in nv12
using oep_image_ready_pb_cb = std::function<void(void* image)>;

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
         * In thread with active texture get CVPixelBufferRef in nv12 or OGL texture from Offscreen_render_target.
         * 
         * @param callback calling with void*. void* keep CVPixelBufferRef in nv12 or OGL texture
         * @param ouput_OGL_texture true if need return the OGL texture in CVPixelBufferRef
         * 
         * Example process_image_async([](void* cv_pixel_buffer_ref){}, true)
         */
        virtual void get_pixel_buffer(oep_image_ready_pb_cb callback, bool ouput_OGL_texture) = 0;
    };
} // bnb::interfaces

