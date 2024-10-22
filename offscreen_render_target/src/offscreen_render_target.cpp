#include "offscreen_render_target.hpp"

#include "opengl.hpp"

#include <bnb/effect_player/utility.hpp>
#include <bnb/postprocess/interfaces/postprocess_helper.hpp>

namespace bnb
{
    const char* vs_default_base =
            " precision highp float; \n "
            " layout (location = 0) in vec3 aPos; \n"
            " layout (location = 1) in vec2 aTexCoord; \n"
            "out vec2 vTexCoord;\n"
            "void main()\n"
            "{\n"
                " gl_Position = vec4(aPos, 1.0); \n"
                " vTexCoord = aTexCoord; \n"
            "}\n";

    const char* ps_default_base =
            "precision mediump float;\n"
            "in vec2 vTexCoord;\n"
            "out vec4 FragColor;\n"
            "uniform sampler2D uTexture;\n"
            "void main()\n"
            "{\n"
                "FragColor = texture(uTexture, vTexCoord);\n"
            "}\n";

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

extern void run_on_main_queue(std::function<void()> f);
extern void create_context_NS();
extern void activate_context_NS();
extern void destroy_context_NS();
extern void* ns_GL_get_proc_address(const char *name);
extern void* get_pixel_buffer_native(int width, int height);

namespace bnb
{
    offscreen_render_target::offscreen_render_target(uint32_t width, uint32_t height)
        : m_width(width)
        , m_height(height) {}

    offscreen_render_target::~offscreen_render_target()
    {
        if (m_framebuffer != 0) {
            GL_CALL(glDeleteFramebuffers(1, &m_framebuffer));
        }
        if (m_post_processing_framebuffer != 0) {
            GL_CALL(glDeleteFramebuffers(1, &m_post_processing_framebuffer));
        }
        delete_textures();
        destroy_context_NS();
    }

    void offscreen_render_target::delete_textures()
    {
        if (m_offscreen_render_texture != 0) {
            GL_CALL(glDeleteTextures(1, &m_offscreen_render_texture));
            m_offscreen_render_texture = 0;
        }
        if (m_offscreen_post_processuing_render_texture != 0) {
            GL_CALL(glDeleteTextures(1, &m_offscreen_post_processuing_render_texture));
            m_offscreen_post_processuing_render_texture = 0;
        }
    }

    void offscreen_render_target::init()
    {
        create_context();
        activate_context();

        GL_CALL(glGenFramebuffers(1, &m_framebuffer));
        GL_CALL(glGenFramebuffers(1, &m_post_processing_framebuffer));

        m_program = std::make_unique<program>("OrientationChange", vs_default_base, ps_default_base);
        m_frame_surface_handler = std::make_unique<ort_frame_surface_handler>(bnb::camera_orientation::deg_0, false);
    }

    void offscreen_render_target::surface_changed(int32_t width, int32_t height)
    {
        m_width = width;
        m_height = height;

        delete_textures();
    }

    void offscreen_render_target::create_context()
    {
        run_on_main_queue([this]() { 
            create_context_NS();
            load_glad_functions();
            glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
        });
    }

    void offscreen_render_target::activate_context()
    {
        activate_context_NS();
    }

    void offscreen_render_target::load_glad_functions()
    {
    #if BNB_OS_WINDOWS || BNB_OS_MACOS
        // it's only need for use while working with dynamic libs
        utility::load_glad_functions((GLADloadproc) ns_GL_get_proc_address);
        bnb::interfaces::postprocess_helper::load_glad_functions(reinterpret_cast<int64_t>(ns_GL_get_proc_address));
    #endif

        if (0 == gladLoadGLLoader((GLADloadproc) ns_GL_get_proc_address)) {
            throw std::runtime_error("gladLoadGLLoader error");
        }
    }

    void offscreen_render_target::generate_texture(GLuint& texture)
    {
        GL_CALL(glGenTextures(1, &texture));
        GL_CALL(glBindTexture(GL_TEXTURE_2D, texture));
        GL_CALL(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  m_width, m_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL));

        GL_CALL(glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST));
        GL_CALL(glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST));
        GL_CALL(glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE)));
        GL_CALL(glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE)));
    }

    void offscreen_render_target::prepare_rendering()
    {
        if (m_offscreen_render_texture == 0) {
            generate_texture(m_offscreen_render_texture);
        }

        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, m_framebuffer));
        GL_CALL(glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_offscreen_render_texture, 0));

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            std::cout << "[ERROR] Failed to make complete framebuffer object " << status << std::endl;
            return;
        }
    }

    void offscreen_render_target::prepare_post_processing_rendering()
    {
        if (m_offscreen_post_processuing_render_texture == 0) {
            generate_texture(m_offscreen_post_processuing_render_texture);
        }
        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, m_post_processing_framebuffer));
        GL_CALL(glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_offscreen_post_processuing_render_texture, 0));

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            std::cout << "[ERROR] Failed to make complete post processing framebuffer object " << status << std::endl;
            return;
        }

        GL_CALL(glViewport(0, 0, GLsizei(m_width), GLsizei(m_height)));

        GL_CALL(glActiveTexture(GLenum(GL_TEXTURE0)));
        GL_CALL(glBindTexture(GL_TEXTURE_2D, m_offscreen_render_texture));
    }

    void offscreen_render_target::orient_image(interfaces::orient_format orient)
    {
        GL_CALL(glFlush());

        if (orient.orientation == camera_orientation::deg_0 && !orient.is_y_flip) {
            return;
        }

        if (m_program == nullptr) {
            std::cout << "[ERROR] Not initialization m_program" << std::endl;
            return;
        }
        if (m_frame_surface_handler == nullptr) {
            std::cout << "[ERROR] Not initialization m_frame_surface_handler" << std::endl;
            return;
        }

        prepare_post_processing_rendering();
        m_program->use();
        m_frame_surface_handler->set_orientation(orient.orientation);
        m_frame_surface_handler->set_y_flip(orient.is_y_flip);
        // Call once for perf
        m_frame_surface_handler->update_vertices_buffer();
        m_frame_surface_handler->draw();
        m_program->unuse();
        glFlush();
    }

    data_t offscreen_render_target::read_current_buffer()
    {
        size_t size = m_width * m_height * 4;
        data_t data = data_t{ std::make_unique<uint8_t[]>(size), size };

        GL_CALL(glReadPixels(0, 0, m_width, m_height, GL_RGBA, GL_UNSIGNED_BYTE, data.data.get()));
        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, 0));

        return data;
    }

    void* offscreen_render_target::get_pixel_buffer()
    {
        return get_pixel_buffer_native(m_width, m_height);
    }
} // bnb
