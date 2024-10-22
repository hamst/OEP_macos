#pragma once

#include <bnb/types/base_types.hpp>

#include "interfaces/offscreen_render_target.hpp"

#include "program.hpp"

#include <glad/glad.h>

namespace bnb
{
    class ort_frame_surface_handler;

    class offscreen_render_target : public interfaces::offscreen_render_target
    {
    public:
        offscreen_render_target(uint32_t width, uint32_t height);

        ~offscreen_render_target();

        void init() override;

        void surface_changed(int32_t width, int32_t height) override;

        void activate_context() override;
        void prepare_rendering() override;
        void orient_image(interfaces::orient_format orient) override;

        bnb::data_t read_current_buffer() override;

        void* get_pixel_buffer() override;

    private:
        void create_context();
        void load_glad_functions();

        void generate_texture(GLuint& texture);
        void prepare_post_processing_rendering();

        void delete_textures();

        uint32_t m_width;
        uint32_t m_height;

        GLuint m_framebuffer{ 0 };
        GLuint m_post_processing_framebuffer{ 0 };
        GLuint m_offscreen_render_texture{ 0 };
        GLuint m_offscreen_post_processuing_render_texture{ 0 };

        std::unique_ptr<program> m_program;
        std::unique_ptr<ort_frame_surface_handler> m_frame_surface_handler;
    };
} // bnb
