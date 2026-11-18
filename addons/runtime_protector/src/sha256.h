#pragma once

#include <cstdint>
#include <cstddef>
#include <string>

namespace godot_rp {

class SHA256 {
public:
    SHA256();

    void update(const uint8_t *data, size_t len);
    void update(const std::string &data);
    void finish(uint8_t out_hash[32]);

    static std::string to_hex(const uint8_t hash[32]);
    static std::string hash_file(const std::string &path);
    static std::string hash_file(const std::wstring &path);
    static std::string hash_bytes(const uint8_t *data, size_t len);
    static bool self_test();

private:
    void transform(const uint8_t chunk[64]);

    uint32_t state_[8];
    uint64_t bit_len_;
    uint8_t buffer_[64];
    size_t buffer_len_;
};

} // namespace godot_rp
