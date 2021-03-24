#pragma once

#include <bnb/types/base_types.hpp>

#include "offscreen_effect_player.hpp"

namespace bnb::interfaces
{
    class offscreen_render_target
    {
    public:
        virtual ~offscreen_render_target() = default;

        /**
         * Offscreen Render Target initialization. Includes initialization of gl context,
         * buffers, support objects.
         * 
         * Example init()
         */
        virtual void init() = 0;

        /**
         * Notify about rendering surface being resized.
         * 
         * @param width New width for the rendering surface
         * @param height New height for the rendering surface
         * 
         * Example surface_changed(1280, 720)
         */
        virtual void surface_changed(int32_t width, int32_t height) = 0;

        /**
         * Activate context for current thread
         * 
         * Example activate_context()
         */
        virtual void activate_context() = 0;

        /**
         * Preparing texture for effect_player
         * 
         * Example prepare_rendering()
         */
        virtual void prepare_rendering() = 0;

        /**
         * Orientates the image
         * 
         * @param orient
         * 
         * Example prepare_rendering()
         */
        virtual void orient_image(orient_format orient) = 0;

        /**
         * Reading current buffer of active texture
         * 
         * @return a data_t with bytes of the processed frame 
         * 
         * Example read_current_buffer()
         */
        virtual bnb::data_t read_current_buffer() = 0;

        /**
         * In thread with active texture get CVPixelBufferRef in nv12 or OGL texture from Offscreen_render_target.
         * 
         * @param ouput_OGL_texture true if need return the OGL texture in CVPixelBufferRef
         * @return a void*. void* keep CVPixelBufferRef in nv12 or OGL texture
         * 
         * Example get_pixel_buffer(true)
         */
        virtual void* get_pixel_buffer(bool ouput_OGL_texture) = 0;
    };
} // bnb::interfaces