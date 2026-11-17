#include "anti_tamper.h"
#include "sha256.h"

#if defined(_WIN32)
#include <windows.h>
#elif defined(__linux__)
#include <climits>
#include <unistd.h>
#endif

namespace godot_rp {

std::string AntiTamper::hash_file(const std::string &path) {
    return SHA256::hash_file(path);
}

std::string AntiTamper::get_executable_path() {
#if defined(_WIN32)
    char path[MAX_PATH] = { 0 };
    DWORD len = GetModuleFileNameA(nullptr, path, MAX_PATH);
    if (len == 0) {
        return std::string();
    }
    return std::string(path, len);

#elif defined(__linux__)
    char path[PATH_MAX] = { 0 };
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path) - 1);
    if (len <= 0) {
        return std::string();
    }
    return std::string(path, static_cast<size_t>(len));

#else
    return std::string();
#endif
}

std::string AntiTamper::hash_self_executable() {
    std::string path = get_executable_path();
    if (path.empty()) {
        return std::string();
    }
    return SHA256::hash_file(path);
}

} //namespace godot_rp
