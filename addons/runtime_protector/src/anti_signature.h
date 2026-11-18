#pragma once

#include <string>

namespace godot_rp {

class AntiSignature {
public:
    static bool verify_release_files(const std::string &pck_path_utf8, std::string &reason);
    static std::wstring get_executable_path();
    static std::wstring get_loaded_library_path();

private:
    static bool verify_authenticode(const std::wstring &path);
};

} // namespace godot_rp
