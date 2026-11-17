#include "anti_hook.h"

#include <cstring>
#include <mutex>

#if defined(_WIN32)
#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#elif defined(__linux__)
#include <fstream>
#include <set>
#endif

namespace godot_rp {

namespace {
std::vector<std::string> g_module_snapshot;
std::mutex g_snapshot_mutex;
} // namespace

std::vector<std::string> AntiHook::list_loaded_modules() {
    std::vector<std::string> result;

#if defined(_WIN32)
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, GetCurrentProcessId());
    if (snap == INVALID_HANDLE_VALUE) {
        return result;
    }
    MODULEENTRY32W me;
    me.dwSize = sizeof(MODULEENTRY32W);
    if (Module32FirstW(snap, &me)) {
        do {
            char narrow[MAX_PATH * 2] = { 0 };
            WideCharToMultiByte(CP_UTF8, 0, me.szExePath, -1, narrow, sizeof(narrow), nullptr, nullptr);
            result.push_back(narrow);
        } while (Module32NextW(snap, &me));
    }
    CloseHandle(snap);

#elif defined(__linux__)
    std::ifstream maps("/proc/self/maps");
    std::string line;
    std::set<std::string> seen;
    while (std::getline(maps, line)) {
        auto so_pos = line.find(".so");
        if (so_pos == std::string::npos) {
            continue;
        }
        auto path_start = line.find('/');
        if (path_start == std::string::npos) {
            continue;
        }
        std::string path = line.substr(path_start);
        if (seen.insert(path).second) {
            result.push_back(path);
        }
    }
#endif

    return result;
}

void AntiHook::snapshot_loaded_modules() {
    std::lock_guard<std::mutex> lock(g_snapshot_mutex);
    g_module_snapshot = list_loaded_modules();
}

std::vector<HookCheckResult> AntiHook::check_new_modules() {
    std::vector<HookCheckResult> results;

    std::vector<std::string> snapshot_copy;
    {
        std::lock_guard<std::mutex> lock(g_snapshot_mutex);
        snapshot_copy = g_module_snapshot;
    }

    if (snapshot_copy.empty()) {
        // snapshot_loaded_modules() was never called - nothing to diff against.
        return results;
    }

    std::vector<std::string> current = list_loaded_modules();
    for (const std::string &mod : current) {
        bool found = false;
        for (const std::string &known : snapshot_copy) {
            if (mod == known) {
                found = true;
                break;
            }
        }
        if (!found) {
            HookCheckResult r;
            r.detected = true;
            r.reason = "Module loaded after startup snapshot: " + mod;
            results.push_back(r);
        }
    }

    return results;
}

HookCheckResult AntiHook::check_function_bytes(const uint8_t *function_address,
        const std::vector<uint8_t> &expected_bytes) {
    HookCheckResult r;
    if (!function_address || expected_bytes.empty()) {
        return r;
    }
    if (std::memcmp(function_address, expected_bytes.data(), expected_bytes.size()) != 0) {
        r.detected = true;
        r.reason = "Function prologue bytes do not match the expected baseline (possible inline hook)";
    }
    return r;
}

std::vector<HookCheckResult> AntiHook::check_iat() {
    std::vector<HookCheckResult> results;

#if defined(_WIN32)
    HMODULE main_module = GetModuleHandleW(nullptr);
    if (!main_module) {
        return results;
    }

    auto dos_header = reinterpret_cast<PIMAGE_DOS_HEADER>(main_module);
    auto nt_headers = reinterpret_cast<PIMAGE_NT_HEADERS>(
            reinterpret_cast<BYTE *>(main_module) + dos_header->e_lfanew);

    auto &import_dir = nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    if (import_dir.VirtualAddress == 0) {
        return results;
    }

    auto import_desc = reinterpret_cast<PIMAGE_IMPORT_DESCRIPTOR>(
            reinterpret_cast<BYTE *>(main_module) + import_dir.VirtualAddress);

    while (import_desc->Name != 0) {
        const char *dll_name = reinterpret_cast<const char *>(
                reinterpret_cast<BYTE *>(main_module) + import_desc->Name);
        HMODULE target_module = GetModuleHandleA(dll_name);

        if (target_module) {
            MODULEINFO mod_info;
            if (GetModuleInformation(GetCurrentProcess(), target_module, &mod_info, sizeof(mod_info))) {
                uintptr_t mod_start = reinterpret_cast<uintptr_t>(mod_info.lpBaseOfDll);
                uintptr_t mod_end = mod_start + mod_info.SizeOfImage;

                auto thunk = reinterpret_cast<PIMAGE_THUNK_DATA>(
                        reinterpret_cast<BYTE *>(main_module) + import_desc->FirstThunk);

                while (thunk->u1.Function != 0) {
                    uintptr_t func_addr = static_cast<uintptr_t>(thunk->u1.Function);
                    if (func_addr < mod_start || func_addr >= mod_end) {
                        HookCheckResult r;
                        r.detected = true;
                        r.reason = std::string("IAT entry imported from ") + dll_name +
                                " resolves outside that module's memory range (possible IAT hook)";
                        results.push_back(r);
                    }
                    ++thunk;
                }
            }
        }
        ++import_desc;
    }
#endif

    return results;
}

} //namespace godot_rp
