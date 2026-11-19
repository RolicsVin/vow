#include "anti_signature.h"

#include "integrity_public_key.h"
#include "sha256.h"
#include "monocypher-ed25519.h"

#include <windows.h>
#include <winhttp.h>
#include <wintrust.h>
#include <softpub.h>

#include <array>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <sstream>
#include <string>
#include <vector>

namespace godot_rp {

namespace {

constexpr wchar_t MANIFEST_FILE[] = L"integrity.manifest";
constexpr wchar_t SIGNATURE_FILE[] = L"integrity.sig";
constexpr size_t MAX_REMOTE_FILE_SIZE = 1024 * 1024;

struct ManifestHashes {
    std::string executable;
    std::string pck;
    std::string library;
};

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
    return content.size() <= MAX_REMOTE_FILE_SIZE ? content : std::string();
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

bool is_sha256(const std::string &value) {
    if (value.size() != 64) {
        return false;
    }
    for (char character : value) {
        if (hex_value(character) < 0) {
            return false;
        }
    }
    return true;
}

std::string normalize_hash(std::string value) {
    for (char &character : value) {
        if (character >= 'A' && character <= 'F') {
            character = static_cast<char>(character - 'A' + 'a');
        }
    }
    return value;
}

bool parse_manifest(const std::string &content, ManifestHashes &hashes) {
    std::istringstream stream(content);
    std::string header;
    std::string executable_line;
    std::string pck_line;
    std::string library_line;
    std::string extra_line;

    if (!std::getline(stream, header) ||
        !std::getline(stream, executable_line) ||
        !std::getline(stream, pck_line) ||
        !std::getline(stream, library_line)) {
        return false;
    }

    if (!header.empty() && header.back() == '\\r') {
        header.pop_back();
    }
    if (!executable_line.empty() && executable_line.back() == '\\r') {
        executable_line.pop_back();
    }
    if (!pck_line.empty() && pck_line.back() == '\\r') {
        pck_line.pop_back();
    }
    if (!library_line.empty() && library_line.back() == '\\r') {
        library_line.pop_back();
    }

    if (header != "VOW-INTEGRITY-V1" ||
        executable_line.rfind("exe=", 0) != 0 ||
        pck_line.rfind("pck=", 0) != 0 ||
        library_line.rfind("dll=", 0) != 0) {
        return false;
    }

    hashes.executable = normalize_hash(executable_line.substr(4));
    hashes.pck = normalize_hash(pck_line.substr(4));
    hashes.library = normalize_hash(library_line.substr(4));

    if (!is_sha256(hashes.executable) ||
        !is_sha256(hashes.pck) ||
        !is_sha256(hashes.library)) {
        return false;
    }

    while (std::getline(stream, extra_line)) {
        if (!extra_line.empty() && extra_line != "\\r") {
            return false;
        }
    }
    return true;
}

bool decode_signature(const std::string &text, std::array<uint8_t, 64> &signature) {
    std::string compact;
    compact.reserve(text.size());

    for (char value : text) {
        if (value == ' ' || value == '\\r' || value == '\\n' || value == '\\t') {
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

bool utf8_to_wide(const std::string &value, std::wstring &result) {
    if (value.empty()) {
        result.clear();
        return true;
    }

    const int required = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
        static_cast<int>(value.size()), nullptr, 0
    );
    if (required <= 0) {
        return false;
    }

    result.resize(static_cast<size_t>(required));
    return MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
        static_cast<int>(value.size()), result.data(), required
    ) == required;
}

bool download_hash_manifest(const std::string &url_utf8, std::string &content) {
    std::wstring url;
    if (!utf8_to_wide(url_utf8, url) || url.empty()) {
        return false;
    }

    URL_COMPONENTS components{};
    components.dwStructSize = sizeof(components);
    components.dwSchemeLength = static_cast<DWORD>(-1);
    components.dwHostNameLength = static_cast<DWORD>(-1);
    components.dwUrlPathLength = static_cast<DWORD>(-1);
    components.dwExtraInfoLength = static_cast<DWORD>(-1);

    if (!WinHttpCrackUrl(url.c_str(), 0, 0, &components) ||
        components.nScheme != INTERNET_SCHEME_HTTPS ||
        components.dwHostNameLength == 0) {
        return false;
    }

    const std::wstring host(components.lpszHostName, components.dwHostNameLength);
    std::wstring request_path;
    if (components.dwUrlPathLength > 0) {
        request_path.assign(components.lpszUrlPath, components.dwUrlPathLength);
    }
    if (components.dwExtraInfoLength > 0) {
        request_path.append(components.lpszExtraInfo, components.dwExtraInfoLength);
    }
    if (request_path.empty()) {
        request_path = L"/";
    }

    HINTERNET session = WinHttpOpen(
        L"VOW-RuntimeProtector/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS,
        0
    );
    if (!session) {
        return false;
    }

    WinHttpSetTimeouts(session, 3000, 3000, 3000, 3000);
    HINTERNET connection = WinHttpConnect(session, host.c_str(), components.nPort, 0);
    if (!connection) {
        WinHttpCloseHandle(session);
        return false;
    }

    HINTERNET request = WinHttpOpenRequest(
        connection, L"GET", request_path.c_str(), nullptr,
        WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE
    );
    if (!request) {
        WinHttpCloseHandle(connection);
        WinHttpCloseHandle(session);
        return false;
    }

    bool downloaded = false;
    if (WinHttpSendRequest(
            request, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
            WINHTTP_NO_REQUEST_DATA, 0, 0, 0
        ) && WinHttpReceiveResponse(request, nullptr)) {
        DWORD status_code = 0;
        DWORD status_size = sizeof(status_code);
        if (WinHttpQueryHeaders(
                request,
                WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                WINHTTP_HEADER_NAME_BY_INDEX,
                &status_code,
                &status_size,
                WINHTTP_NO_HEADER_INDEX
            ) && status_code == 200) {
            downloaded = true;
            content.clear();

            for (;;) {
                DWORD available = 0;
                if (!WinHttpQueryDataAvailable(request, &available)) {
                    downloaded = false;
                    break;
                }
                if (available == 0) {
                    break;
                }
                if (content.size() + available > MAX_REMOTE_FILE_SIZE) {
                    content = "REMOTE_MANIFEST_TOO_LARGE";
                    break;
                }

                const size_t offset = content.size();
                content.resize(offset + available);
                DWORD bytes_read = 0;
                if (!WinHttpReadData(
                        request, content.data() + offset, available, &bytes_read
                    ) || bytes_read == 0) {
                    downloaded = false;
                    break;
                }
                content.resize(offset + bytes_read);
            }
        }
    }

    WinHttpCloseHandle(request);
    WinHttpCloseHandle(connection);
    WinHttpCloseHandle(session);
    return downloaded;
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

bool AntiSignature::verify_release_files(
    const std::string &pck_path_utf8,
    const std::string &hashes_url_utf8,
    std::string &reason
) {
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

    // Authenticode is a mandatory local check and does not require a network connection.
    if (!verify_authenticode(executable_path)) {
        reason = "EXE Authenticode signature is missing, invalid, or untrusted";
        return false;
    }
    if (!verify_authenticode(library_path)) {
        reason = "RuntimeProtector DLL Authenticode signature is missing, invalid, or untrusted";
        return false;
    }

    // Verify the local Ed25519 signature independently from the optional remote hash check.
    const std::string local_manifest = read_text_file(manifest_path);
    ManifestHashes local_hashes;
    if (local_manifest.empty() || !parse_manifest(local_manifest, local_hashes)) {
        reason = "Local integrity manifest is missing or malformed";
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
        reinterpret_cast<const uint8_t *>(local_manifest.data()),
        local_manifest.size()
    );
    if (verification_result != 0) {
        reason = "Ed25519 signature verification failed";
        return false;
    }

    // A missing URL or failed download skips only the remote SHA-256 comparison.
    if (hashes_url_utf8.empty()) {
        reason.clear();
        return true;
    }

    std::string remote_manifest;
    if (!download_hash_manifest(hashes_url_utf8, remote_manifest)) {
        reason.clear();
        return true;
    }

    ManifestHashes remote_hashes;
    if (!parse_manifest(remote_manifest, remote_hashes)) {
        reason = "Downloaded hash manifest is malformed";
        return false;
    }

    const std::string actual_executable_hash = SHA256::hash_file(executable_path);
    const std::string actual_pck_hash = SHA256::hash_file(pck);
    const std::string actual_library_hash = SHA256::hash_file(library_path);

    if (actual_executable_hash.empty() ||
        actual_pck_hash.empty() ||
        actual_library_hash.empty()) {
        reason = "Cannot calculate one or more local file hashes";
        return false;
    }

    if (actual_executable_hash != remote_hashes.executable ||
        actual_pck_hash != remote_hashes.pck ||
        actual_library_hash != remote_hashes.library) {
        reason = "One or more downloaded SHA-256 hashes do not match the local release files";
        return false;
    }

    reason.clear();
    return true;
}

} // namespace godot_rp
