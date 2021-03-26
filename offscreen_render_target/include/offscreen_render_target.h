#pragma once

#include <bnb/types/base_types.hpp>

#include "interfaces/offscreen_render_target.hpp"

#include "program.hpp"

#include <glad/glad.h>

#import <CoreMedia/CoreMedia.h>

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

        void* get_image(interfaces::image_format format) override;

    private:
        void cleanupRenderBuffers();
        void cleanPostProcessRenderingTargets();

        void createContext();
        void destroyContext();

        void loadGladFunctions();

        void setupTextureCache();
        void setupRenderBuffers();

        void setupOffscreenPixelBuffer(CVPixelBufferRef& pb);
        void setupOffscreenRenderTarget(CVPixelBufferRef& pb, CVOpenGLTextureRef& texture);

        void preparePostProcessingRendering();


        uint32_t m_width{0};
        uint32_t m_height{0};

        CVOpenGLTextureCacheRef m_videoTextureCache{nullptr};

        GLuint m_framebuffer{0};
        GLuint m_postProcessingFramebuffer{0};

        CVPixelBufferRef m_offscreenRenderPixelBuffer{nullptr};
        CVPixelBufferRef m_offscreenPostProcessingPixelBuffer{nullptr};

        CVOpenGLTextureRef m_offscreenRenderTexture{nullptr};
        CVOpenGLTextureRef m_offscreenPostProcessingRenderTexture{nullptr};

        bool m_oriented{false};

        std::unique_ptr<program> m_program;
        std::unique_ptr<ort_frame_surface_handler> m_frameSurfaceHandler;
    };
} // bnb
