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

    // Path to the dynamic library (.dll/.so) that this very code was
    // compiled into - i.e. this RuntimeProtector extension's own file on
    // disk. Found by asking the OS which module owns the address of a
    // function inside this library, so it works regardless of what the
    // file happens to be named.
    static std::string get_own_module_path();

    // Convenience: SHA-256 of this extension's own library file.
    static std::string hash_own_module();

    // SHA-256 over every regular file under `dir_path` (recursive),
    // combined into one aggregate hash: each file is hashed, the
    // (relative_path, file_hash) pairs are sorted by path for a
    // deterministic order, and that sorted list is itself hashed.
    // Returns an empty string if the directory doesn't exist or any
    // file inside it can't be read (a partial/unreadable tree is
    // treated as unverifiable, not silently skipped).
    static std::string hash_directory(const std::string &dir_path);
};

} //namespace godot_rp
