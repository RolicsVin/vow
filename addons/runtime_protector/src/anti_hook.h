#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace godot_rp {

struct HookCheckResult {
    bool detected = false;
    std::string reason;
};

class AntiHook {
public:
    // Call once, early (ideally right after the extension loads), to
    // record which modules/shared libraries are currently loaded.
    static void snapshot_loaded_modules();

    // Compares the current module list against the snapshot and reports
    // anything new - the classic signature of DLL/so injection (Cheat
    // Engine, trainers, hook frameworks, etc.). Benign late-loaded
    // modules (some audio/video codecs, GPU vendor overlays) can also
    // show up here, so treat a single hit with some skepticism.
    static std::vector<HookCheckResult> check_new_modules();

    // Compares `len` bytes at `function_address` against
    // `expected_bytes`. Use this on your own exported/critical functions
    // to catch inline hooking (a JMP/CALL patched into the function's
    // prologue). The caller is responsible for the address and length
    // being valid and readable.
    static HookCheckResult check_function_bytes(const uint8_t *function_address,
            const std::vector<uint8_t> &expected_bytes);

    // Windows only: walks the main module's Import Address Table and
    // flags any resolved import address that does not fall inside the
    // exporting module's own mapped memory range (IAT hooking /
    // redirection). Returns an empty vector on other platforms.
    static std::vector<HookCheckResult> check_iat();

private:
    static std::vector<std::string> list_loaded_modules();
};

} //namespace godot_rp
