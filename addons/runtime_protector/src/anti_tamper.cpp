#include "anti_tamper.h"
#include "sha256.h"

#include <algorithm>
#include <filesystem>
#include <utility>
#include <vector>

#if defined(_WIN32)
#include <windows.h>
#elif defined(__linux__)
#include <climits>
#include <dlfcn.h>
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

namespace {
// Any function defined in this translation unit works as the "address
// inside this module" anchor - its own identity doesn't matter, only
// which .dll/.so it lives in.
void anchor_in_this_module() {}
} // namespace

std::string AntiTamper::get_own_module_path() {
#if defined(_WIN32)
    HMODULE this_module = nullptr;
    if (!GetModuleHandleExW(
                GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                reinterpret_cast<LPCWSTR>(&anchor_in_this_module),
                &this_module)) {
        return std::string();
    }
    wchar_t path[MAX_PATH] = { 0 };
    DWORD len = GetModuleFileNameW(this_module, path, MAX_PATH);
    if (len == 0) {
        return std::string();
    }
    char narrow[MAX_PATH * 2] = { 0 };
    WideCharToMultiByte(CP_UTF8, 0, path, -1, narrow, sizeof(narrow), nullptr, nullptr);
    return std::string(narrow);

#elif defined(__linux__)
    Dl_info info;
    if (dladdr(reinterpret_cast<void *>(&anchor_in_this_module), &info) == 0 || !info.dli_fname) {
        return std::string();
    }
    return std::string(info.dli_fname);

#else
    return std::string();
#endif
}

std::string AntiTamper::hash_own_module() {
    std::string path = get_own_module_path();
    if (path.empty()) {
        return std::string();
    }
    return SHA256::hash_file(path);
}

std::string AntiTamper::hash_directory(const std::string &dir_path) {
    namespace fs = std::filesystem;

    std::error_code ec;
    fs::path root(dir_path);
    if (!fs::exists(root, ec) || ec || !fs::is_directory(root, ec) || ec) {
        return std::string();
    }

    std::vector<std::pair<std::string, std::string>> entries; // (relative_path, file_hash)

    fs::recursive_directory_iterator it(root, fs::directory_options::skip_permission_denied, ec);
    fs::recursive_directory_iterator end;
    for (; !ec && it != end; it.increment(ec)) {
        std::error_code is_file_ec;
        if (!it->is_regular_file(is_file_ec) || is_file_ec) {
            continue;
        }

        std::error_code rel_ec;
        fs::path rel = fs::relative(it->path(), root, rel_ec);
        if (rel_ec) {
            return std::string();
        }

        std::string file_hash = SHA256::hash_file(it->path().string());
        if (file_hash.empty()) {
            // Unreadable file inside the tree - treat the whole
            // directory as unverifiable rather than silently skipping it.
            return std::string();
        }

        entries.emplace_back(rel.generic_string(), file_hash);
    }
    if (ec) {
        return std::string();
    }

    if (entries.empty()) {
        return std::string();
    }

    std::sort(entries.begin(), entries.end(),
            [](const std::pair<std::string, std::string> &a, const std::pair<std::string, std::string> &b) {
                return a.first < b.first;
            });

    std::string canonical;
    for (const auto &entry : entries) {
        canonical += entry.first;
        canonical += ':';
        canonical += entry.second;
        canonical += '\n';
    }

    return SHA256::hash_bytes(reinterpret_cast<const uint8_t *>(canonical.data()), canonical.size());
}

} //namespace godot_rp
