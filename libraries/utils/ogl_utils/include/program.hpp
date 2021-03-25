#pragma once

#include <iostream>
#include <unordered_map>

namespace bnb
{
    class program
    {
    public:
        program(const char* name, const char* vertex_shader_code, const char* fragmant_shader_code);
        ~program();

        void use() const;
        void unuse() const;

        void set_uniform(const char* name, int value) const;
        void set_uniform(const char* name, float value) const;
        void set_uniform(const char* name, float v1, float v2);
        void set_uniform(const char* name, float v1, float v2, float v3);
        void set_uniform(const char* name, float v1, float v2, float v3, float v4);
        void set_uniform_mat4(const char* name, const float* value) const;

        unsigned int get_uniform_location(const char* name) const;

        unsigned int handle() const { return m_handle; }

    private:
        unsigned int m_handle;
        mutable std::unordered_map<const void*, unsigned int> m_uniforms;
    };
}
