#pragma once

#include <bnb/types/base_types.hpp>

namespace bnb {

    enum class pixel_format
    {
        rgba,
        nv12,
        texture
    };

    struct orient_format
    {
        bnb::camera_orientation orientation;
        bool is_y_flip;
    };

} // bnb
