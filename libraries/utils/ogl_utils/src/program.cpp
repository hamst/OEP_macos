#include "program.hpp"

#include "opengl.hpp"
#include <sstream>

#define BNB_GLSL_VERSION "#version 330 core \n"

using namespace bnb;
using namespace std;

program::program(const char* name, const char* vertex_shader_code, const char* fragmant_shader_code)
    : m_handle(0)
{
    ostringstream vsc;
    vsc << BNB_GLSL_VERSION << endl;
    vsc << vertex_shader_code << endl;
    vsc.flush();

    ostringstream fsc;
    fsc << BNB_GLSL_VERSION << endl;
    fsc << fragmant_shader_code << endl;
    fsc.flush();

    string vsc_str = vsc.str();
    string fsc_str = fsc.str();

    const char* vsc_str_c = vsc_str.c_str();
    const char* fsc_str_c = fsc_str.c_str();

    int vertexShader = glCreateShader(GL_VERTEX_SHADER);
    GL_CALL(glShaderSource(vertexShader, 1, &vsc_str_c, NULL));
    GL_CALL(glCompileShader(vertexShader));

    // check for shader compile errors
    int success;
    char infoLog[512];
    GL_CALL(glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success));
    if (!success)
    {
        GL_CALL(glGetShaderInfoLog(vertexShader, 512, NULL, infoLog));
        throw std::exception();
    }

    // fragment shader
    int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    GL_CALL(glShaderSource(fragmentShader, 1, &fsc_str_c, NULL));
    GL_CALL(glCompileShader(fragmentShader));
    // check for shader compile errors
    GL_CALL(glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success));
    if (!success)
    {
        GL_CALL(glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog));
        throw std::exception();
    }

    // link shaders
    unsigned int shaderProgram = glCreateProgram();
    GL_CALL(glAttachShader(shaderProgram, vertexShader));
    GL_CALL(glAttachShader(shaderProgram, fragmentShader));
    GL_CALL(glLinkProgram(shaderProgram));
    // check for linking errors
    GL_CALL(glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success));
    if (!success) {
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        throw std::exception();
    }
    GL_CALL(glDeleteShader(vertexShader));
    GL_CALL(glDeleteShader(fragmentShader));

    m_handle = shaderProgram;
}

program::~program()
{
    GL_CALL(glDeleteProgram(m_handle));
}

void program::use() const
{
    GL_CALL(glUseProgram(m_handle));
}

void program::unuse() const
{
    GL_CALL(glUseProgram(0));
}

void program::set_uniform(const char* name, float value) const
{
    GL_CALL(glUniform1f(get_uniform_location(name), value));
}

void program::set_uniform(const char* name, float v1, float v2)
{
    GL_CALL(glUniform2f(get_uniform_location(name), v1, v2));
}

void program::set_uniform(const char* name, float v1, float v2, float v3)
{
    GL_CALL(glUniform3f(get_uniform_location(name), v1, v2, v3));
}

void program::set_uniform(const char* name, float v1, float v2, float v3, float v4)
{
    GL_CALL(glUniform4f(get_uniform_location(name), v1, v2, v3, v4));
}


void program::set_uniform(const char* name, int value) const
{
    GL_CALL(glUniform1i(get_uniform_location(name), value));
}

void program::set_uniform_mat4(const char* name, const float* value) const
{
    GL_CALL(glUniformMatrix4fv(get_uniform_location(name), 1, GL_FALSE, value));
}

unsigned int program::get_uniform_location(const char* name) const
{
    GLint loc;
    auto it = m_uniforms.find(name);
    if (it != m_uniforms.end()) {
        loc = it->second;
    } else {
        GL_CALL(loc = glGetUniformLocation(m_handle, name));
        m_uniforms.emplace(name, loc);
    }

    return static_cast<unsigned int>(loc);
}
