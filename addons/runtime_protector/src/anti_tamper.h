#pragma once

#include <string>

namespace godot_rp {

class AntiTamper {
public:
    // Lowercase hex SHA-256 of the file at `path`, or an empty string if
    // the file could not be opened/read.
    static std::string hash_file(const std::string &path);

    // Convenience: hash of the currently running executable.
    static std::string hash_self_executable();

    // Best-effort path to the currently running executable.
    static std::string get_executable_path();
};

} //namespace godot_rp
