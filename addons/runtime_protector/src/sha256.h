#pragma once

#include <cstdint>
#include <cstddef>
#include <string>

namespace godot_rp {

// Minimal, dependency-free SHA-256 implementation (written directly from
// the FIPS 180-4 specification). No external crypto library is needed to
// build this extension.
//
// IMPORTANT: this code has not been compiled/run in the environment that
// produced it (no network / toolchain access there). Before relying on
// it for anything real, call SHA256::self_test() (also exposed to
// GDScript as RuntimeProtector.self_test_sha256()) and compare
// SHA256::hash_file() output against a trusted tool such as
// `sha256sum` / `certutil -hashfile ... SHA256` on a known file.
class SHA256 {
public:
    SHA256();

    void update(const uint8_t *data, size_t len);
    void update(const std::string &data);

    // Finalizes the hash. The instance must not be reused afterwards -
    // construct a new SHA256 object for the next hash.
    void finish(uint8_t out_hash[32]);

    static std::string to_hex(const uint8_t hash[32]);

    // Hashes a whole file in fixed-size chunks (safe for large .pck
    // files). Returns an empty string if the file cannot be opened.
    static std::string hash_file(const std::string &path);
    static std::string hash_file(const std::wstring &path);

    static std::string hash_bytes(const uint8_t *data, size_t len);

    // Hashes the well-known FIPS 180-4 test vectors for "" and "abc" and
    // compares them against the published values. Returns true only if
    // both match, which is strong evidence this implementation is
    // correct on the platform it was compiled for.
    static bool self_test();

private:
    void transform(const uint8_t chunk[64]);

    uint32_t state_[8];
    uint64_t bit_len_;
    uint8_t buffer_[64];
    size_t buffer_len_;
};

} //namespace godot_rp
