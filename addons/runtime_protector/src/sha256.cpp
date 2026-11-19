#include "sha256.h"

#include <cstring>
#include <filesystem>
#include <fstream>
#include <vector>

namespace godot_rp {

namespace {

constexpr uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

inline uint32_t rotr(uint32_t x, uint32_t n) {
    return (x >> n) | (x << (32 - n));
}

} // namespace

SHA256::SHA256() {
    state_[0] = 0x6a09e667;
    state_[1] = 0xbb67ae85;
    state_[2] = 0x3c6ef372;
    state_[3] = 0xa54ff53a;
    state_[4] = 0x510e527f;
    state_[5] = 0x9b05688c;
    state_[6] = 0x1f83d9ab;
    state_[7] = 0x5be0cd19;
    bit_len_ = 0;
    buffer_len_ = 0;
}

void SHA256::transform(const uint8_t chunk[64]) {
    uint32_t w[64];
    for (int i = 0; i < 16; ++i) {
        w[i] = (uint32_t(chunk[i * 4]) << 24) |
               (uint32_t(chunk[i * 4 + 1]) << 16) |
               (uint32_t(chunk[i * 4 + 2]) << 8) |
               (uint32_t(chunk[i * 4 + 3]));
    }
    for (int i = 16; i < 64; ++i) {
        uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }

    uint32_t a = state_[0], b = state_[1], c = state_[2], d = state_[3];
    uint32_t e = state_[4], f = state_[5], g = state_[6], h = state_[7];

    for (int i = 0; i < 64; ++i) {
        uint32_t S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        uint32_t ch = (e & f) ^ ((~e) & g);
        uint32_t temp1 = h + S1 + ch + K[i] + w[i];
        uint32_t S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint32_t temp2 = S0 + maj;

        h = g;
        g = f;
        f = e;
        e = d + temp1;
        d = c;
        c = b;
        b = a;
        a = temp1 + temp2;
    }

    state_[0] += a;
    state_[1] += b;
    state_[2] += c;
    state_[3] += d;
    state_[4] += e;
    state_[5] += f;
    state_[6] += g;
    state_[7] += h;
}

void SHA256::update(const uint8_t *data, size_t len) {
    bit_len_ += uint64_t(len) * 8;

    while (len > 0) {
        size_t take = 64 - buffer_len_;
        if (take > len) {
            take = len;
        }
        memcpy(buffer_ + buffer_len_, data, take);
        buffer_len_ += take;
        data += take;
        len -= take;

        if (buffer_len_ == 64) {
            transform(buffer_);
            buffer_len_ = 0;
        }
    }
}

void SHA256::update(const std::string &data) {
    update(reinterpret_cast<const uint8_t *>(data.data()), data.size());
}

void SHA256::finish(uint8_t out_hash[32]) {
    uint64_t total_bits = bit_len_;

    uint8_t pad = 0x80;
    update(&pad, 1);

    uint8_t zero = 0x00;
    while (buffer_len_ != 56) {
        update(&zero, 1);
    }

    uint8_t len_bytes[8];
    for (int i = 0; i < 8; ++i) {
        len_bytes[i] = uint8_t(total_bits >> (56 - i * 8));
    }
    // Written directly into the buffer (not via update()) so bit_len_
    // bookkeeping isn't disturbed after we've already captured it above.
    memcpy(buffer_ + 56, len_bytes, 8);
    transform(buffer_);

    for (int i = 0; i < 8; ++i) {
        out_hash[i * 4] = uint8_t(state_[i] >> 24);
        out_hash[i * 4 + 1] = uint8_t(state_[i] >> 16);
        out_hash[i * 4 + 2] = uint8_t(state_[i] >> 8);
        out_hash[i * 4 + 3] = uint8_t(state_[i]);
    }
}

std::string SHA256::to_hex(const uint8_t hash[32]) {
    static const char *digits = "0123456789abcdef";
    std::string result;
    result.reserve(64);
    for (int i = 0; i < 32; ++i) {
        result.push_back(digits[hash[i] >> 4]);
        result.push_back(digits[hash[i] & 0x0F]);
    }
    return result;
}

std::string SHA256::hash_bytes(const uint8_t *data, size_t len) {
    SHA256 ctx;
    ctx.update(data, len);
    uint8_t hash[32];
    ctx.finish(hash);
    return to_hex(hash);
}

std::string SHA256::hash_file(const std::string &path) {
    return hash_file(std::filesystem::u8path(path));
}

std::string SHA256::hash_file(const std::wstring &path) {
    return hash_file(std::filesystem::path(path));
}

std::string SHA256::hash_file(const std::filesystem::path &path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return std::string();
    }
    SHA256 ctx;
    std::vector<uint8_t> chunk(1 << 16); // 64 KB chunks
    while (file) {
        file.read(reinterpret_cast<char *>(chunk.data()), static_cast<std::streamsize>(chunk.size()));
        std::streamsize got = file.gcount();
        if (got > 0) {
            ctx.update(chunk.data(), static_cast<size_t>(got));
        }
    }
    uint8_t hash[32];
    ctx.finish(hash);
    return to_hex(hash);
}

bool SHA256::self_test() {
    bool ok = true;

    std::string empty_hash = hash_bytes(reinterpret_cast<const uint8_t *>(""), 0);
    ok = ok && (empty_hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");

    const char *abc = "abc";
    std::string abc_hash = hash_bytes(reinterpret_cast<const uint8_t *>(abc), 3);
    ok = ok && (abc_hash == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");

    return ok;
}

} //namespace godot_rp
