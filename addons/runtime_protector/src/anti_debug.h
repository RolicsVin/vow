#pragma once

#include <string>

namespace godot_rp {

struct DebugCheckResult {
    bool detected = false;
    std::string reason;
};

// A set of heuristic debugger-detection techniques. None of these are
// bulletproof on their own (see the project README) - they raise the
// cost of casually attaching a debugger, they do not guarantee it is
// impossible. A motivated attacker with kernel-level tooling (e.g.
// ScyllaHide-style unhooking, a custom hypervisor) can defeat any single
// userland check.
class AntiDebug {
public:
    // Runs every check available on the current platform and returns the
    // first positive hit (if any). Meant to be polled periodically from
    // a background thread rather than once at startup, since a one-time
    // check is trivial to patch out.
    static DebugCheckResult check_all();
};

} //namespace godot_rp
