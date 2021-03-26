#pragma once

#include <bnb/types/base_types.hpp>

namespace bnb::interfaces {

    enum class image_format
    {
        // CVPixelBufferRef with image on rgba
        rgba,
        // CVPixelBufferRef with image on nv12
        nv12,
        // CVPixelBufferRef with image on OGL texture
        // It is useful if you want to avoid GPU-CPU data sync for performance.
        // Please take into the account that on first pixel buffer lock sync will take place,
        // so it is assumed that data will not leave OGL context.
        texture
    };

    struct orient_format
    {
        bnb::camera_orientation orientation;
        bool is_y_flip;
    };

} // bnb::interfaces
