#pragma once

#include <godot_cpp/classes/node.hpp>

#include <atomic>
#include <thread>

namespace godot {

// Reaction mode values (pass as a plain int to set_reaction_mode /
// the `reaction_mode` property):
//   0 = signal only  - just emit the signal, decide the response in GDScript
//   1 = quit          - call SceneTree::quit() when something is detected
//   2 = crash         - deliberately abort() the process (last resort)
class RuntimeProtector : public Node {
    GDCLASS(RuntimeProtector, Node)

public:
    static constexpr int REACTION_SIGNAL_ONLY = 0;
    static constexpr int REACTION_QUIT = 1;
    static constexpr int REACTION_CRASH = 2;

private:
    std::atomic<bool> running_{ false };
    std::thread worker_thread_;

    int check_interval_ms_ = 1500;
    bool enable_anti_debug_ = true;
    bool enable_anti_hook_ = true;
    bool enable_anti_tamper_ = false;
    bool autostart_ = false;
    String expected_pck_hash_;
    String pck_path_;
    String expected_exe_hash_;
    int reaction_mode_ = REACTION_SIGNAL_ONLY;

    void _worker_loop();
    void _report(const String &p_signal, const String &p_reason);
    void _react();
    void _deferred_quit();

protected:
    static void _bind_methods();

public:
    RuntimeProtector();
    ~RuntimeProtector() override;

    void _ready() override;
    void _exit_tree() override;

    void start_protection();
    void stop_protection();
    bool is_running() const;

    // One-shot checks you can call directly from GDScript, e.g. right
    // before decrypting save data or validating a purchase, instead of
    // (or in addition to) the background polling loop.
    bool check_debugger_now();
    bool check_hooks_now();
    bool verify_pck_now();

    String compute_sha256(const String &p_path);
    bool self_test_sha256();

    void set_check_interval_ms(int p_ms);
    int get_check_interval_ms() const;

    void set_enable_anti_debug(bool p_enabled);
    bool get_enable_anti_debug() const;

    void set_enable_anti_hook(bool p_enabled);
    bool get_enable_anti_hook() const;

    void set_enable_anti_tamper(bool p_enabled);
    bool get_enable_anti_tamper() const;

    void set_expected_pck_hash(const String &p_hash);
    String get_expected_pck_hash() const;

    void set_pck_path(const String &p_path);
    String get_pck_path() const;

    void set_reaction_mode(int p_mode);
    int get_reaction_mode() const;

    void set_autostart(bool p_autostart);
    bool get_autostart() const;
};

} //namespace godot