#include "offscreen_render_target.h"

#include "opengl.hpp"
#include "utils.h"

#include <bnb/effect_player/utility.hpp>
#include <bnb/postprocess/interfaces/postprocess_helper.hpp>

#import <Cocoa/Cocoa.h>


namespace bnb
{
    // Macos uses GL_TEXTURE_RECTANGLE instead of GL_TEXTURE_2D.
    // On OS X, CoreVideo produces GL_TEXTURE_RECTANGLE objects, because GL_TEXTURE_2D would
    // waste a lot of memory, while on iOS, it produces GL_TEXTURE_2D objects because
    // GL_TEXTURE_RECTANGLE doesn't exist, nor is it necessary.
    // Is necessary normalization of coordinates. vTexCoord = aTexCoord  * vec2(width, height)
    // https://stackoverflow.com/questions/13933503/core-video-pixel-buffers-as-gl-texture-2d
    const char* vs_default_base =
            " precision highp float; \n "
            " layout (location = 0) in vec3 aPos; \n"
            " layout (location = 1) in vec2 aTexCoord; \n"
            " uniform int width; \n"
            " uniform int height; \n"
            "out vec2 vTexCoord; \n"
            "void main() \n"
            "{ \n"
                " gl_Position = vec4(aPos, 1.0); \n"
                " vTexCoord = aTexCoord  * vec2(width, height); \n"
            "} \n";

    const char* ps_default_base =
            "precision mediump float; \n"
            "in vec2 vTexCoord; \n"
            "out vec4 FragColor; \n"
            "uniform sampler2DRect uTexture; \n"
            "void main() \n"
            "{ \n"
                "FragColor = texture(uTexture, vTexCoord); \n"
            "} \n";

    class ort_frame_surface_handler
    {
    private:
        static const auto v_size = static_cast<uint32_t>(bnb::camera_orientation::deg_270) + 1;

    public:
        /**
        * First array determines texture orientation for vertical flip transformation
        * Second array determines texture's orientation
        * Third one determines the plane vertices` positions in correspondence to the texture coordinates
        */
        static const float vertices[2][v_size][5 * 4];

        explicit ort_frame_surface_handler(bnb::camera_orientation orientation, bool is_y_flip)
            : m_orientation(static_cast<uint32_t>(orientation))
            , m_y_flip(static_cast<uint32_t>(is_y_flip))
        {
            glGenVertexArrays(1, &m_vao);
            glGenBuffers(1, &m_vbo);
            glGenBuffers(1, &m_ebo);

            glBindVertexArray(m_vao);

            glBindBuffer(GL_ARRAY_BUFFER, m_vbo);
            glBufferData(GL_ARRAY_BUFFER, sizeof(vertices[m_y_flip][m_orientation]), vertices[m_y_flip][m_orientation], GL_STATIC_DRAW);

            // clang-format off

            unsigned int indices[] = {
                // clang-format off
                0, 1, 3, // first triangle
                1, 2, 3  // second triangle
                // clang-format on
            };

            // clang-format on

            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_ebo);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

            // position attribute
            glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*) 0);
            glEnableVertexAttribArray(0);
            // texture coord attribute
            glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*) (3 * sizeof(float)));
            glEnableVertexAttribArray(1);

            glBindVertexArray(0);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        }

        virtual ~ort_frame_surface_handler() final
        {
            if (m_vao != 0)
                glDeleteVertexArrays(1, &m_vao);

            if (m_vbo != 0)
                glDeleteBuffers(1, &m_vbo);

            if (m_ebo != 0)
                glDeleteBuffers(1, &m_ebo);

            m_vao = 0;
            m_vbo = 0;
            m_ebo = 0;
        }

        ort_frame_surface_handler(const ort_frame_surface_handler&) = delete;
        ort_frame_surface_handler(ort_frame_surface_handler&&) = delete;

        ort_frame_surface_handler& operator=(const ort_frame_surface_handler&) = delete;
        ort_frame_surface_handler& operator=(ort_frame_surface_handler&&) = delete;

        void update_vertices_buffer()
        {
            glBindBuffer(GL_ARRAY_BUFFER, m_vbo);
            glBufferData(GL_ARRAY_BUFFER, sizeof(vertices[m_y_flip][m_orientation]), vertices[m_y_flip][m_orientation], GL_STATIC_DRAW);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
        }

        void set_orientation(bnb::camera_orientation orientation)
        {
            if (m_orientation != static_cast<uint32_t>(orientation)) {
                m_orientation = static_cast<uint32_t>(orientation);
            }
        }

        void set_y_flip(bool y_flip)
        {
            if (m_y_flip != static_cast<uint32_t>(y_flip)) {
                m_y_flip = static_cast<uint32_t>(y_flip);
            }
        }

        void draw()
        {
            glBindVertexArray(m_vao);
            glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, nullptr);
            glBindVertexArray(0);
        }

    private:
        uint32_t m_orientation = 0;
        uint32_t m_y_flip = 0;
        unsigned int m_vao = 0;
        unsigned int m_vbo = 0;
        unsigned int m_ebo = 0;
    };

    const float ort_frame_surface_handler::vertices[2][ort_frame_surface_handler::v_size][5 * 4] =
    {{ /* verical flip 0 */
    {
            // positions        // texture coords
            1.0f,  1.0f, 0.0f, 1.0f, 0.0f, // top right
            1.0f, -1.0f, 0.0f, 1.0f, 1.0f, // bottom right
            -1.0f, -1.0f, 0.0f, 0.0f, 1.0f, // bottom left
            -1.0f,  1.0f, 0.0f, 0.0f, 0.0f,  // top left
    },
    {
            // positions        // texture coords
            1.0f,  1.0f, 0.0f, 0.0f, 0.0f, // top right
            1.0f, -1.0f, 0.0f, 1.0f, 0.0f, // bottom right
            -1.0f, -1.0f, 0.0f, 1.0f, 1.0f, // bottom left
            -1.0f,  1.0f, 0.0f, 0.0f, 1.0f,  // top left
    },
    {
            // positions        // texture coords
            1.0f,  1.0f, 0.0f, 0.0f, 1.0f, // top right
            1.0f, -1.0f, 0.0f, 0.0f, 0.0f, // bottom right
            -1.0f, -1.0f, 0.0f, 1.0f, 0.0f, // bottom left
            -1.0f,  1.0f, 0.0f, 1.0f, 1.0f,  // top left
    },
    {
            // positions        // texture coords
            1.0f,  1.0f, 0.0f, 1.0f, 1.0f, // top right
            1.0f, -1.0f, 0.0f, 0.0f, 1.0f, // bottom right
            -1.0f, -1.0f, 0.0f, 0.0f, 0.0f, // bottom left
            -1.0f,  1.0f, 0.0f, 1.0f, 0.0f,  // top left
    }
    },
    { /* verical flip 1 */
    {
            // positions        // texture coords
            1.0f, -1.0f, 0.0f, 1.0f, 1.0f, // top right
            1.0f,  1.0f, 0.0f, 1.0f, 0.0f, // bottom right
            -1.0f,  1.0f, 0.0f, 0.0f, 0.0f, // bottom left
            -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,  // top left
    },
    {
            // positions        // texture coords
            1.0f, -1.0f, 0.0f, 1.0f, 0.0f, // top right
            1.0f,  1.0f, 0.0f, 0.0f, 0.0f, // bottom right
            -1.0f,  1.0f, 0.0f, 0.0f, 1.0f, // bottom left
            -1.0f, -1.0f, 0.0f, 1.0f, 1.0f,  // top left
    },
    {
            // positions        // texture coords
            1.0f, -1.0f, 0.0f, 0.0f, 0.0f, // top right
            1.0f,  1.0f, 0.0f, 0.0f, 1.0f, // bottom right
            -1.0f,  1.0f, 0.0f, 1.0f, 1.0f, // bottom left
            -1.0f, -1.0f, 0.0f, 1.0f, 0.0f,  // top left
    },
    {
            // positions        // texture coords
            1.0f, -1.0f, 0.0f, 0.0f, 1.0f, // top right
            1.0f,  1.0f, 0.0f, 1.0f, 1.0f, // bottom right
            -1.0f,  1.0f, 0.0f, 1.0f, 0.0f, // bottom left
            -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,  // top left
    }
    }};
} // bnb

NSOpenGLContext* m_GLContext{nullptr};

namespace bnb
{
    offscreen_render_target::offscreen_render_target(uint32_t width, uint32_t height)
        : m_width(width)
        , m_height(height) {}

    offscreen_render_target::~offscreen_render_target()
    {
        if (m_videoTextureCache) {
            CFRelease(m_videoTextureCache);
        }
        cleanupRenderBuffers();
        destroyContext();
    }

    void offscreen_render_target::cleanupRenderBuffers()
    {
        if (m_offscreenRenderPixelBuffer) {
            CFRelease(m_offscreenRenderPixelBuffer);
            m_offscreenRenderPixelBuffer = nullptr;
        }
        if (m_offscreenRenderTexture) {
            CFRelease(m_offscreenRenderTexture);
            m_offscreenRenderTexture = nullptr;
        }
        if (m_framebuffer != 0) {
            glDeleteFramebuffers(1, &m_framebuffer);
            m_framebuffer = 0;
        }
        cleanPostProcessRenderingTargets();
        if (m_postProcessingFramebuffer != 0) {
            glDeleteFramebuffers(1, &m_postProcessingFramebuffer);
            m_postProcessingFramebuffer = 0;
        }
    }

    void offscreen_render_target::cleanPostProcessRenderingTargets()
    {
        if (m_offscreenPostProcessingPixelBuffer) {
            CFRelease(m_offscreenPostProcessingPixelBuffer);
            m_offscreenPostProcessingPixelBuffer = nullptr;
        }
        if (m_offscreenPostProcessingRenderTexture) {
            CFRelease(m_offscreenPostProcessingRenderTexture);
            m_offscreenPostProcessingRenderTexture = nullptr;
        }
    }

    void offscreen_render_target::init()
    {
        runOnMainQueue([this]() { 
            createContext();
            loadGladFunctions();
            glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
        });
        activate_context();

        setupTextureCache();
        setupRenderBuffers();

        m_program = std::make_unique<program>("OrientationChange", vs_default_base, ps_default_base);
        m_frameSurfaceHandler = std::make_unique<ort_frame_surface_handler>(bnb::camera_orientation::deg_0, false);
    }

    void offscreen_render_target::createContext()
    {
        if (m_GLContext != nil) {
            return;
        }

        static std::once_flag nsGLContextOnceFlag;
        std::call_once(nsGLContextOnceFlag, []() {
            NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
                NSOpenGLPFAOpenGLProfile,
                (NSOpenGLPixelFormatAttribute)NSOpenGLProfileVersion4_1Core,
                NSOpenGLPFADoubleBuffer,
                NSOpenGLPFAAccelerated, 0,
                0
            };

            NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
            if (pixelFormat == nil) {
                NSLog(@"Error: No appropriate pixel format found");
            }
            m_GLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
            if (m_GLContext == nil) {
                NSLog(@"Unable to create an OpenGL context. The GPUImage framework requires OpenGL support to work.");
            }

            [m_GLContext makeCurrentContext];
        });
    }

    void offscreen_render_target::activate_context()
    {
        if ([NSOpenGLContext currentContext] != m_GLContext) {
            if (m_GLContext != nil) {
                [m_GLContext makeCurrentContext];
            } else {
                NSLog(@"Error: The OGL context has not been created yet");
            }
        }
    }

    void offscreen_render_target::destroyContext()
    {
        if ([NSOpenGLContext currentContext] == m_GLContext) {
            [m_GLContext clearCurrentContext];
            m_GLContext = nil;
        }
    }

    void offscreen_render_target::loadGladFunctions()
    {
        // it's only need for use while working with dynamic libs
        utility::load_glad_functions((GLADloadproc) nsGLGetProcAddress);
        bnb::interfaces::postprocess_helper::load_glad_functions(reinterpret_cast<int64_t>(nsGLGetProcAddress));

        if (0 == gladLoadGLLoader((GLADloadproc) nsGLGetProcAddress)) {
            throw std::runtime_error("gladLoadGLLoader error");
        }
    }

    void offscreen_render_target::setupTextureCache()
    {
        if (m_videoTextureCache != NULL) {
            return;
        }
        CVReturn err = CVOpenGLTextureCacheCreate(kCFAllocatorDefault, NULL, m_GLContext.CGLContextObj,
                CGLGetPixelFormat(m_GLContext.CGLContextObj), NULL, &m_videoTextureCache);

        if (err != noErr) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                    reason:@"Cannot initialize texture cache"
                    userInfo:nil];
        }
    }

    void offscreen_render_target::setupRenderBuffers()
    {
        GL_CALL(glGenFramebuffers(1, &m_framebuffer));
        GL_CALL(glGenFramebuffers(1, &m_postProcessingFramebuffer));

        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, m_framebuffer));

        setupOffscreenPixelBuffer(m_offscreenRenderPixelBuffer);
        setupOffscreenRenderTarget(m_offscreenRenderPixelBuffer, m_offscreenRenderTexture);
    }

    void offscreen_render_target::setupOffscreenPixelBuffer(CVPixelBufferRef& pb)
    {
        CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, m_width, m_height, kCVPixelFormatType_32BGRA, attrs, &pb);

        if (err != noErr) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                            reason:@"Cannot create offscreen pixel buffer"
                            userInfo:nil];
        }
        CFRelease(empty);
        CFRelease(attrs);
    }

    void offscreen_render_target::setupOffscreenRenderTarget(CVPixelBufferRef& pb, CVOpenGLTextureRef& texture)
    {
        CVReturn err = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault, m_videoTextureCache,
                pb, NULL, &texture);

        if (err != noErr) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                    reason:@"Cannot create GL texture from pixel buffer"
                    userInfo:nil];
        }
    }

    void offscreen_render_target::surface_changed(int32_t width, int32_t height)
    {
        m_width = width;
        m_height = height;

        cleanupRenderBuffers();
        setupRenderBuffers();
    }

    void offscreen_render_target::prepare_rendering()
    {
        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, m_framebuffer));
        GL_CALL(glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                        CVOpenGLTextureGetTarget(m_offscreenRenderTexture),
                        CVOpenGLTextureGetName(m_offscreenRenderTexture), 0));

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            std::cout << "[ERROR] Failed to make complete framebuffer object " << status << std::endl;
            return;
        }
    }

    void offscreen_render_target::preparePostProcessingRendering()
    {
        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, m_postProcessingFramebuffer));
        GL_CALL(glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                        CVOpenGLTextureGetTarget(m_offscreenPostProcessingRenderTexture),
                        CVOpenGLTextureGetName(m_offscreenPostProcessingRenderTexture), 0));

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            std::cout << "[ERROR] Failed to make complete post processing framebuffer object " << status << std::endl;
            return;
        }

        auto width = CVPixelBufferGetWidth(m_offscreenPostProcessingPixelBuffer);
        auto height = CVPixelBufferGetHeight(m_offscreenPostProcessingPixelBuffer);
        GL_CALL(glViewport(0, 0, GLsizei(width), GLsizei(height)));

        GL_CALL(glActiveTexture(GLenum(GL_TEXTURE0)));

        GL_CALL(glBindTexture(CVOpenGLTextureGetTarget(m_offscreenRenderTexture), CVOpenGLTextureGetName(m_offscreenRenderTexture)));
        glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR);
        glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR);
        glTexParameterf(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE));
        glTexParameterf(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE));
    }

    void offscreen_render_target::orient_image(orient_format orient)
    {
        GL_CALL(glFlush());

        if (orient.orientation == camera_orientation::deg_0 && !orient.is_y_flip) {
            return;
        }

        if (m_program == nullptr) {
            std::cout << "[ERROR] Not initialization m_program" << std::endl;
            return;
        }
        if (m_frameSurfaceHandler == nullptr) {
            std::cout << "[ERROR] Not initialization m_frameSurfaceHandler" << std::endl;
            return;
        }

        if (m_offscreenPostProcessingPixelBuffer == nullptr) {
            setupOffscreenPixelBuffer(m_offscreenPostProcessingPixelBuffer);
            setupOffscreenRenderTarget(m_offscreenPostProcessingPixelBuffer, m_offscreenPostProcessingRenderTexture);
        }

        preparePostProcessingRendering();
        m_program->use();
        m_program->set_uniform("width", (int)m_width);
        m_program->set_uniform("height", (int)m_height);
        m_frameSurfaceHandler->set_orientation(orient.orientation);
        m_frameSurfaceHandler->set_y_flip(orient.is_y_flip);
        // Call once for perf
        m_frameSurfaceHandler->update_vertices_buffer();
        m_frameSurfaceHandler->draw();
        m_program->unuse();
        GL_CALL(glFlush());

        m_oriented = true;
    }

    data_t offscreen_render_target::read_current_buffer()
    {
        size_t size = m_width * m_height * 4;
        data_t data = data_t{ std::make_unique<uint8_t[]>(size), size };

        GL_CALL(glReadPixels(0, 0, m_width, m_height, GL_RGBA, GL_UNSIGNED_BYTE, data.data.get()));
        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, 0));

        return data;
    }

    void* offscreen_render_target::get_image(pixel_format format)
    {
        if (format == pixel_format::texture) {
            if (m_oriented) {
                m_oriented = false;
                return (void*)m_offscreenPostProcessingPixelBuffer;
            }
            return (void*)m_offscreenRenderPixelBuffer;
        }

        CVPixelBufferRef pixel_buffer = NULL;

        NSDictionary* cvBufferProperties = @{
            (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
        };

        CVReturn err = CVPixelBufferCreate(
            kCFAllocatorDefault,
            m_width,
            m_height,
            // We get data from oep in RGBA, macos defined kCVPixelFormatType_32RGBA but not supported
            // and we have to choose a different type. This does not in any way affect further
            // processing, inside bytes still remain in the order of the RGBA.
            kCVPixelFormatType_32BGRA,
            (__bridge CFDictionaryRef)(cvBufferProperties),
            &pixel_buffer);

        if (err) {
            NSLog(@"Pixel buffer not created");
            return nullptr;
        }

        CVPixelBufferLockBaseAddress(pixel_buffer, 0);

        GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
        glReadPixels(0, 0, m_width, m_height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
        if (format == pixel_format::nv12) {
            pixel_buffer = convertRGBAtoNV12(pixel_buffer, vrange::full_range);
        }

        return (void*)pixel_buffer;
    }

} // bnb
