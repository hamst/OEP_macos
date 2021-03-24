#include "pixel_buffer.hpp"

#include <bnb/types/full_image.hpp>

#include <iostream>

namespace bnb
{
    pixel_buffer::pixel_buffer(oep_sptr oep_sptr, uint32_t width, uint32_t height, camera_orientation orientation)
        : m_oep_ptr(oep_sptr)
        , m_width(width)
        , m_height(height)
        , m_orientation(orientation) {}

    void pixel_buffer::lock()
    {
        ++lock_count;
    }

    void pixel_buffer::unlock()
    {
        if (lock_count > 0) {
            --lock_count;
            return;
        }

        throw std::runtime_error("pixel_buffer already unlocked");
    }

    bool pixel_buffer::is_locked()
    {
        if (lock_count == 0) {
            return false;
        }
        return true;
    }

    void pixel_buffer::get_pixel_buffer(oep_image_ready_pb_cb callback, bool ouput_OGL_texture)
    {
        if (!is_locked()) {
            std::cout << "[WARNING] The pixel buffer must be locked" << std::endl;
            callback(nullptr);
            return;
        }

        if (auto oep_sp = m_oep_ptr.lock()) {
            oep_sp->read_pixel_buffer(callback, ouput_OGL_texture);
        }
        else {
            std::cout << "[ERROR] Offscreen effect player destroyed" << std::endl;
        }
    }
} // bnb
