#include "anti_hook.h"

#include <cctype>
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

#if defined(_WIN32)
struct ModuleRange {
    uintptr_t start;
    uintptr_t end;
};

// Snapshot of [base, base+size) for every currently loaded module. Used
// to check whether a resolved import address lands inside *some*
// legitimately loaded module - not necessarily the one literally named
// in the import descriptor.
//
// This matters because modern Windows routinely resolves an import to a
// *different* module than the one named: many kernel32.dll functions
// are thin forwarders actually implemented in kernelbase.dll, ole32.dll
// often forwards into combase.dll, and api-ms-win-core-*.dll names are
// virtual "API set" names that never correspond to a real file on disk
// at all - they're redirected by the OS loader. None of that is
// hooking; checking against the single named module's range alone
// flags all of it as a false positive.
std::vector<ModuleRange> get_loaded_module_ranges() {
    std::vector<ModuleRange> ranges;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, GetCurrentProcessId());
    if (snap == INVALID_HANDLE_VALUE) {
        return ranges;
    }
    MODULEENTRY32W me;
    me.dwSize = sizeof(MODULEENTRY32W);
    if (Module32FirstW(snap, &me)) {
        do {
            uintptr_t start = reinterpret_cast<uintptr_t>(me.modBaseAddr);
            ranges.push_back({ start, start + me.modBaseSize });
        } while (Module32NextW(snap, &me));
    }
    CloseHandle(snap);
    return ranges;
}

bool address_in_any_module(uintptr_t addr, const std::vector<ModuleRange> &ranges) {
    for (const ModuleRange &r : ranges) {
        if (addr >= r.start && addr < r.end) {
            return true;
        }
    }
    return false;
}

bool starts_with_ci(const std::string &s, const std::string &prefix) {
    if (s.size() < prefix.size()) {
        return false;
    }
    for (size_t i = 0; i < prefix.size(); ++i) {
        if (std::tolower(static_cast<unsigned char>(s[i])) != std::tolower(static_cast<unsigned char>(prefix[i]))) {
            return false;
        }
    }
    return true;
}

// The Windows directory itself (C:\Windows). Windows routinely lazy-loads
// its own DLLs (networking, DNS, audio codecs, common controls, etc.) the
// first time a feature is used - e.g. the first HTTPRequest triggers
// mswsock.dll, DNSAPI.dll, NSI.dll, fwpuclnt.dll and similar to load, long
// after our startup snapshot was taken. None of that is injection: placing
// a malicious DLL under C:\Windows\... requires admin rights, which real
// cheat trainers/injectors essentially never bother with when the game's
// own folder, %TEMP%, or the tool's own install directory work just as
// well. So modules loaded from under the Windows directory are treated as
// trusted and excluded from the "new module" check, rather than chasing an
// ever-growing list of specific DLL names.
std::string get_windows_dir() {
    wchar_t buf[MAX_PATH];
    UINT len = GetWindowsDirectoryW(buf, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
        return std::string();
    }
    char narrow[MAX_PATH * 2] = { 0 };
    WideCharToMultiByte(CP_UTF8, 0, buf, -1, narrow, sizeof(narrow), nullptr, nullptr);
    return std::string(narrow);
}
#endif
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

#if defined(_WIN32)
    static const std::string windows_dir = get_windows_dir();
#endif

    std::vector<std::string> current = list_loaded_modules();
    for (const std::string &mod : current) {
        bool found = false;
        for (const std::string &known : snapshot_copy) {
            if (mod == known) {
                found = true;
                break;
            }
        }
        if (found) {
            continue;
        }

#if defined(_WIN32)
        if (!windows_dir.empty() && starts_with_ci(mod, windows_dir)) {
            continue; // legitimate OS-owned module lazily loaded from C:\Windows\...
        }
#endif

        HookCheckResult r;
        r.detected = true;
        r.reason = "Module loaded after startup snapshot: " + mod;
        results.push_back(r);
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

    // Compare against every loaded module, not just the one literally
    // named in the import descriptor - see get_loaded_module_ranges()
    // for why (API forwarding, API sets). If this comes back empty we
    // have nothing trustworthy to compare against, so skip rather than
    // risk false positives.
    std::vector<ModuleRange> module_ranges = get_loaded_module_ranges();
    if (module_ranges.empty()) {
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

        auto thunk = reinterpret_cast<PIMAGE_THUNK_DATA>(
                reinterpret_cast<BYTE *>(main_module) + import_desc->FirstThunk);

        while (thunk->u1.Function != 0) {
            uintptr_t func_addr = static_cast<uintptr_t>(thunk->u1.Function);
            if (!address_in_any_module(func_addr, module_ranges)) {
                HookCheckResult r;
                r.detected = true;
                r.reason = std::string("IAT entry imported from ") + dll_name +
                        " resolves to an address outside every loaded module "
                        "(likely IAT hook or injected trampoline, not legitimate API forwarding)";
                results.push_back(r);
            }
            ++thunk;
        }
        ++import_desc;
    }
#endif

    return results;
}

} //namespace godot_rp
