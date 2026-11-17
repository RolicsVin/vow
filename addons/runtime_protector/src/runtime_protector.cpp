#include "runtime_protector.h"

#include "anti_debug.h"
#include "anti_hook.h"
#include "anti_tamper.h"
#include "sha256.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <chrono>
#include <cstdlib>

using namespace godot;

void RuntimeProtector::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_protection"), &RuntimeProtector::start_protection);
    ClassDB::bind_method(D_METHOD("stop_protection"), &RuntimeProtector::stop_protection);
    ClassDB::bind_method(D_METHOD("is_running"), &RuntimeProtector::is_running);

    ClassDB::bind_method(D_METHOD("check_debugger_now"), &RuntimeProtector::check_debugger_now);
    ClassDB::bind_method(D_METHOD("check_hooks_now"), &RuntimeProtector::check_hooks_now);
    ClassDB::bind_method(D_METHOD("verify_pck_now"), &RuntimeProtector::verify_pck_now);

    ClassDB::bind_method(D_METHOD("compute_sha256", "path"), &RuntimeProtector::compute_sha256);
    ClassDB::bind_method(D_METHOD("self_test_sha256"), &RuntimeProtector::self_test_sha256);

    ClassDB::bind_method(D_METHOD("set_check_interval_ms", "ms"), &RuntimeProtector::set_check_interval_ms);
    ClassDB::bind_method(D_METHOD("get_check_interval_ms"), &RuntimeProtector::get_check_interval_ms);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "check_interval_ms"), "set_check_interval_ms", "get_check_interval_ms");

    ClassDB::bind_method(D_METHOD("set_enable_anti_debug", "enabled"), &RuntimeProtector::set_enable_anti_debug);
    ClassDB::bind_method(D_METHOD("get_enable_anti_debug"), &RuntimeProtector::get_enable_anti_debug);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_anti_debug"), "set_enable_anti_debug", "get_enable_anti_debug");

    ClassDB::bind_method(D_METHOD("set_enable_anti_hook", "enabled"), &RuntimeProtector::set_enable_anti_hook);
    ClassDB::bind_method(D_METHOD("get_enable_anti_hook"), &RuntimeProtector::get_enable_anti_hook);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_anti_hook"), "set_enable_anti_hook", "get_enable_anti_hook");

    ClassDB::bind_method(D_METHOD("set_enable_anti_tamper", "enabled"), &RuntimeProtector::set_enable_anti_tamper);
    ClassDB::bind_method(D_METHOD("get_enable_anti_tamper"), &RuntimeProtector::get_enable_anti_tamper);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_anti_tamper"), "set_enable_anti_tamper", "get_enable_anti_tamper");

    ClassDB::bind_method(D_METHOD("set_expected_pck_hash", "hash"), &RuntimeProtector::set_expected_pck_hash);
    ClassDB::bind_method(D_METHOD("get_expected_pck_hash"), &RuntimeProtector::get_expected_pck_hash);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "expected_pck_hash"), "set_expected_pck_hash", "get_expected_pck_hash");

    ClassDB::bind_method(D_METHOD("set_pck_path", "path"), &RuntimeProtector::set_pck_path);
    ClassDB::bind_method(D_METHOD("get_pck_path"), &RuntimeProtector::get_pck_path);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "pck_path"), "set_pck_path", "get_pck_path");

    ClassDB::bind_method(D_METHOD("set_reaction_mode", "mode"), &RuntimeProtector::set_reaction_mode);
    ClassDB::bind_method(D_METHOD("get_reaction_mode"), &RuntimeProtector::get_reaction_mode);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "reaction_mode"), "set_reaction_mode", "get_reaction_mode");

    ClassDB::bind_method(D_METHOD("set_autostart", "autostart"), &RuntimeProtector::set_autostart);
    ClassDB::bind_method(D_METHOD("get_autostart"), &RuntimeProtector::get_autostart);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "autostart"), "set_autostart", "get_autostart");

    ClassDB::bind_method(D_METHOD("_deferred_quit"), &RuntimeProtector::_deferred_quit);

    ADD_SIGNAL(MethodInfo("debugger_detected", PropertyInfo(Variant::STRING, "reason")));
    ADD_SIGNAL(MethodInfo("hook_detected", PropertyInfo(Variant::STRING, "reason")));
    ADD_SIGNAL(MethodInfo("tampering_detected", PropertyInfo(Variant::STRING, "reason")));

    BIND_CONSTANT(REACTION_SIGNAL_ONLY);
    BIND_CONSTANT(REACTION_QUIT);
    BIND_CONSTANT(REACTION_CRASH);
}

RuntimeProtector::RuntimeProtector() {}

RuntimeProtector::~RuntimeProtector() {
    stop_protection();
}

void RuntimeProtector::_ready() {
    // Never run protection logic inside the editor itself.
    if (autostart_ && Engine::get_singleton() && !Engine::get_singleton()->is_editor_hint()) {
        start_protection();
    }
}

void RuntimeProtector::_exit_tree() {
    stop_protection();
}

void RuntimeProtector::start_protection() {
    if (running_.load()) {
        return;
    }
    running_.store(true);
    godot_rp::AntiHook::snapshot_loaded_modules();
    worker_thread_ = std::thread(&RuntimeProtector::_worker_loop, this);
}

void RuntimeProtector::stop_protection() {
    if (!running_.load()) {
        return;
    }
    running_.store(false);
    if (worker_thread_.joinable()) {
        worker_thread_.join();
    }
}

bool RuntimeProtector::is_running() const {
    return running_.load();
}

void RuntimeProtector::_worker_loop() {
    using namespace godot_rp;

    while (running_.load()) {
        if (enable_anti_debug_) {
            DebugCheckResult r = AntiDebug::check_all();
            if (r.detected) {
                _report("debugger_detected", String(r.reason.c_str()));
            }
        }

        if (enable_anti_hook_) {
            std::vector<HookCheckResult> hooks = AntiHook::check_new_modules();
            std::vector<HookCheckResult> iat = AntiHook::check_iat();
            hooks.insert(hooks.end(), iat.begin(), iat.end());
            for (const HookCheckResult &hr : hooks) {
                if (hr.detected) {
                    _report("hook_detected", String(hr.reason.c_str()));
                }
            }
        }

        if (enable_anti_tamper_ && !pck_path_.is_empty() && !expected_pck_hash_.is_empty()) {
            std::string actual = AntiTamper::hash_file(std::string(pck_path_.utf8().get_data()));
            std::string expected = expected_pck_hash_.utf8().get_data();
            if (actual.empty() || actual != expected) {
                _report("tampering_detected", "PCK hash mismatch (or file unreadable) for: " + pck_path_);
            }
        }

        // Sleep in small slices so stop_protection() doesn't have to
        // wait out the full interval before the thread can exit.
        for (int waited = 0; waited < check_interval_ms_ && running_.load(); waited += 50) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    }
}

void RuntimeProtector::_report(const String &p_signal, const String &p_reason) {
    call_deferred("emit_signal", p_signal, p_reason);
    _react();
}

void RuntimeProtector::_react() {
    switch (reaction_mode_) {
        case REACTION_QUIT:
            call_deferred("_deferred_quit");
            break;
        case REACTION_CRASH:
            // Deliberately crash. This is a blunt last-resort option -
            // see the README for why tying gameplay logic itself to
            // detection (rather than a separate "if (hacked) exit()")
            // is a sturdier long-term approach.
            abort();
            break;
        default:
            break;
    }
}

void RuntimeProtector::_deferred_quit() {
    if (!Engine::get_singleton()) {
        return;
    }
    SceneTree *tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
    if (tree) {
        tree->quit();
    }
}

bool RuntimeProtector::check_debugger_now() {
    return godot_rp::AntiDebug::check_all().detected;
}

bool RuntimeProtector::check_hooks_now() {
    for (const auto &h : godot_rp::AntiHook::check_new_modules()) {
        if (h.detected) {
            return true;
        }
    }
    for (const auto &h : godot_rp::AntiHook::check_iat()) {
        if (h.detected) {
            return true;
        }
    }
    return false;
}

bool RuntimeProtector::verify_pck_now() {
    if (pck_path_.is_empty() || expected_pck_hash_.is_empty()) {
        return false;
    }
    std::string actual = godot_rp::AntiTamper::hash_file(std::string(pck_path_.utf8().get_data()));
    return !actual.empty() && actual == std::string(expected_pck_hash_.utf8().get_data());
}

String RuntimeProtector::compute_sha256(const String &p_path) {
    std::string result = godot_rp::SHA256::hash_file(std::string(p_path.utf8().get_data()));
    return String(result.c_str());
}

bool RuntimeProtector::self_test_sha256() {
    return godot_rp::SHA256::self_test();
}

void RuntimeProtector::set_check_interval_ms(int p_ms) { check_interval_ms_ = p_ms > 50 ? p_ms : 50; }
int RuntimeProtector::get_check_interval_ms() const { return check_interval_ms_; }

void RuntimeProtector::set_enable_anti_debug(bool p_enabled) { enable_anti_debug_ = p_enabled; }
bool RuntimeProtector::get_enable_anti_debug() const { return enable_anti_debug_; }

void RuntimeProtector::set_enable_anti_hook(bool p_enabled) { enable_anti_hook_ = p_enabled; }
bool RuntimeProtector::get_enable_anti_hook() const { return enable_anti_hook_; }

void RuntimeProtector::set_enable_anti_tamper(bool p_enabled) { enable_anti_tamper_ = p_enabled; }
bool RuntimeProtector::get_enable_anti_tamper() const { return enable_anti_tamper_; }

void RuntimeProtector::set_expected_pck_hash(const String &p_hash) { expected_pck_hash_ = p_hash; }
String RuntimeProtector::get_expected_pck_hash() const { return expected_pck_hash_; }

void RuntimeProtector::set_pck_path(const String &p_path) { pck_path_ = p_path; }
String RuntimeProtector::get_pck_path() const { return pck_path_; }

void RuntimeProtector::set_reaction_mode(int p_mode) { reaction_mode_ = p_mode; }
int RuntimeProtector::get_reaction_mode() const { return reaction_mode_; }

void RuntimeProtector::set_autostart(bool p_autostart) { autostart_ = p_autostart; }
bool RuntimeProtector::get_autostart() const { return autostart_; }
