#pragma once

#include <string>
#include <filesystem>
namespace fs = std::filesystem;
#include <map>
#include <memory>
#include <vector>
#include <GL/glew.h>
#include <GL/gl.h>
#include <glm/glm.hpp>

#include "named_map.h"
#include "texture.h"

class Shader : public NamedMap<Shader> {
public:
    Shader(const std::string& name);
    Shader(const std::string& name, const fs::path& compute_source);
    Shader(const std::string& name, const fs::path& vertex_source, const fs::path& fragment_source);
    Shader(const std::string& name, const fs::path& vertex_source, const fs::path& geometry_source, const fs::path& fragment_source);
    virtual ~Shader();

    // prevent copies and moves, since GL buffers aren't reference counted
    Shader(const Shader&) = delete;
    Shader& operator=(const Shader&) = delete;
    Shader& operator=(const Shader&&) = delete;

    explicit inline operator bool() const  { return glIsProgram(id); }
    inline operator GLuint() const { return id; }

    // bind/unbind to/from OpenGL
    void bind() const;
    void unbind() const;

    // set the path to the source file for the shader type
    void set_source(GLenum type, const fs::path& path);
    void set_vertex_source(const fs::path& path);
    void set_tesselation_control_source(const fs::path& path);
    void set_tesselation_evaluation_source(const fs::path& path);
    void set_geometry_source(const fs::path& path);
    void set_fragment_source(const fs::path& path);
    void set_compute_source(const fs::path& path);

    // compile and link shader from previously given source files
    void compile(bool throw_error = false);

    // compute shader dispatch (call with actual amount of threads, will internally divide by workgroup size)
    void dispatch_compute(uint32_t w, uint32_t h = 1, uint32_t d = 1) const;

    // uniform upload handling
    void uniform(const std::string& name, int val) const;
    void uniform(const std::string& name, int* val, uint32_t count) const;
    void uniform(const std::string& name, float val) const;
    void uniform(const std::string& name, float* val, uint32_t count) const;
    void uniform(const std::string& name, const glm::vec2& val) const;
    void uniform(const std::string& name, const glm::vec3& val) const;
    void uniform(const std::string& name, const glm::vec4& val) const;
    void uniform(const std::string& name, const glm::ivec2& val) const;
    void uniform(const std::string& name, const glm::ivec3& val) const;
    void uniform(const std::string& name, const glm::ivec4& val) const;
    void uniform(const std::string& name, const glm::uvec2& val) const;
    void uniform(const std::string& name, const glm::uvec3& val) const;
    void uniform(const std::string& name, const glm::uvec4& val) const;
    void uniform(const std::string& name, const glm::mat3& val) const;
    void uniform(const std::string& name, const glm::mat4& val) const;
    void uniform(const std::string& name, const Texture2D& tex, uint32_t unit) const;
    void uniform(const std::string& name, const Texture2D* tex, uint32_t unit) const;
    void uniform(const std::string& name, const std::shared_ptr<Texture2D>& tex, uint32_t unit) const;

    // management/reload
    void clear();
    void reload_if_modified();
    static void reload();

    // data
    GLuint id;
    std::map<GLenum, fs::path> source_files;
    std::map<GLenum, fs::file_time_type> timestamps;
};

// variadic alias for std::make_shared<>(...)
template <class... Args> std::shared_ptr<Shader> make_shader(Args&&... args) {
    return std::make_shared<Shader>(args...);
}
