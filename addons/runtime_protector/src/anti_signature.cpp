#include "anti_signature.h"

#include "integrity_public_key.h"
#include "sha256.h"
#include "monocypher-ed25519.h"

#include <windows.h>
#include <wintrust.h>
#include <softpub.h>

#include <array>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

namespace godot_rp {

namespace {

constexpr wchar_t MANIFEST_FILE[] = L"integrity.manifest";
constexpr wchar_t SIGNATURE_FILE[] = L"integrity.sig";

std::wstring get_module_path(HMODULE module) {
    std::vector<wchar_t> buffer(32768, L'\\0');
    DWORD length = GetModuleFileNameW(module, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length == 0 || length >= buffer.size()) {
        return {};
    }
    return std::wstring(buffer.data(), length);
}

std::string read_text_file(const std::filesystem::path &path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {};
    }

    std::string content(
        (std::istreambuf_iterator<char>(file)),
        std::istreambuf_iterator<char>()
    );
    return content.size() <= 1024 * 1024 ? content : std::string();
}

int hex_value(char value) {
    if (value >= '0' && value <= '9') {
        return value - '0';
    }
    if (value >= 'a' && value <= 'f') {
        return value - 'a' + 10;
    }
    if (value >= 'A' && value <= 'F') {
        return value - 'A' + 10;
    }
    return -1;
}

bool decode_signature(const std::string &text, std::array<uint8_t, 64> &signature) {
    std::string compact;
    compact.reserve(text.size());

    for (char value : text) {
        if (value == ' ' || value == '\r' || value == '\n' || value == '\t') {
            continue;
        }
        compact.push_back(value);
    }

    if (compact.size() != signature.size() * 2) {
        return false;
    }

    for (size_t index = 0; index < signature.size(); ++index) {
        const int high = hex_value(compact[index * 2]);
        const int low = hex_value(compact[index * 2 + 1]);
        if (high < 0 || low < 0) {
            return false;
        }
        signature[index] = static_cast<uint8_t>((high << 4) | low);
    }
    return true;
}

std::string make_manifest(
    const std::wstring &executable_path,
    const std::wstring &pck_path,
    const std::wstring &library_path
) {
    const std::string executable_hash = SHA256::hash_file(executable_path);
    const std::string pck_hash = SHA256::hash_file(pck_path);
    const std::string library_hash = SHA256::hash_file(library_path);

    if (executable_hash.empty() || pck_hash.empty() || library_hash.empty()) {
        return {};
    }

    return "VOW-INTEGRITY-V1\n"
           "exe=" + executable_hash + "\n"
           "pck=" + pck_hash + "\n"
           "dll=" + library_hash + "\n";
}

} // namespace

std::wstring AntiSignature::get_executable_path() {
    return get_module_path(nullptr);
}

std::wstring AntiSignature::get_loaded_library_path() {
    static int module_anchor = 0;
    HMODULE module = nullptr;

    if (!GetModuleHandleExW(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            reinterpret_cast<LPCWSTR>(&module_anchor),
            &module)) {
        return {};
    }

    return get_module_path(module);
}

bool AntiSignature::verify_authenticode(const std::wstring &path) {
    if (path.empty()) {
        return false;
    }

    WINTRUST_FILE_INFO file_info{};
    file_info.cbStruct = sizeof(file_info);
    file_info.pcwszFilePath = path.c_str();

    WINTRUST_DATA trust_data{};
    trust_data.cbStruct = sizeof(trust_data);
    trust_data.dwUIChoice = WTD_UI_NONE;
    trust_data.fdwRevocationChecks = WTD_REVOKE_NONE;
    trust_data.dwUnionChoice = WTD_CHOICE_FILE;
    trust_data.pFile = &file_info;
    trust_data.dwStateAction = WTD_STATEACTION_VERIFY;
    trust_data.dwProvFlags = WTD_CACHE_ONLY_URL_RETRIEVAL | WTD_REVOCATION_CHECK_NONE;

    GUID policy = WINTRUST_ACTION_GENERIC_VERIFY_V2;
    const LONG status = WinVerifyTrust(nullptr, &policy, &trust_data);

    trust_data.dwStateAction = WTD_STATEACTION_CLOSE;
    WinVerifyTrust(nullptr, &policy, &trust_data);

    return status == ERROR_SUCCESS;
}

bool AntiSignature::verify_release_files(const std::string &pck_path_utf8, std::string &reason) {
    const std::wstring executable_path = get_executable_path();
    const std::wstring library_path = get_loaded_library_path();

    if (executable_path.empty()) {
        reason = "Cannot resolve the running executable path";
        return false;
    }
    if (library_path.empty()) {
        reason = "Cannot resolve the loaded RuntimeProtector DLL path";
        return false;
    }

    const std::filesystem::path executable(executable_path);
    const std::filesystem::path pck = pck_path_utf8.empty()
        ? executable.parent_path() / (executable.stem().wstring() + L".pck")
        : std::filesystem::u8path(pck_path_utf8);
    const std::filesystem::path library(library_path);
    const std::filesystem::path manifest_path = executable.parent_path() / MANIFEST_FILE;
    const std::filesystem::path signature_path = executable.parent_path() / SIGNATURE_FILE;

    if (!verify_authenticode(executable_path)) {
        reason = "EXE Authenticode signature is missing, invalid, or untrusted";
        return false;
    }
    if (!verify_authenticode(library_path)) {
        reason = "RuntimeProtector DLL Authenticode signature is missing, invalid, or untrusted";
        return false;
    }

    const std::string expected_manifest = make_manifest(
        executable_path,
        pck.wstring(),
        library_path
    );
    if (expected_manifest.empty()) {
        reason = "EXE, PCK, or RuntimeProtector DLL is missing or unreadable";
        return false;
    }

    const std::string actual_manifest = read_text_file(manifest_path);
    if (actual_manifest.empty() || actual_manifest != expected_manifest) {
        reason = "Integrity manifest is missing or file hashes do not match";
        return false;
    }

    const std::string signature_text = read_text_file(signature_path);
    std::array<uint8_t, 64> signature{};
    if (!decode_signature(signature_text, signature)) {
        reason = "Ed25519 signature file is missing or malformed";
        return false;
    }

    const int verification_result = crypto_ed25519_check(
        signature.data(),
        VOW_INTEGRITY_PUBLIC_KEY,
        reinterpret_cast<const uint8_t *>(actual_manifest.data()),
        actual_manifest.size()
    );
    if (verification_result != 0) {
        reason = "Ed25519 signature verification failed";
        return false;
    }

    reason.clear();
    return true;
}

} // namespace godot_rp
