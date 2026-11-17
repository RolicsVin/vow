#include "anti_debug.h"

#if defined(_WIN32)
#include <windows.h>
#include <winternl.h>
#if defined(_MSC_VER)
#include <intrin.h>
#endif
#elif defined(__linux__)
#include <fstream>
#include <sys/ptrace.h>
#include <unistd.h>
#endif

namespace godot_rp {

namespace {

#if defined(_WIN32)

typedef NTSTATUS(NTAPI *NtQueryInformationProcess_t)(
        HANDLE ProcessHandle,
        PROCESSINFOCLASS ProcessInformationClass,
        PVOID ProcessInformation,
        ULONG ProcessInformationLength,
        PULONG ReturnLength);

DebugCheckResult check_is_debugger_present() {
    DebugCheckResult r;
    if (IsDebuggerPresent()) {
        r.detected = true;
        r.reason = "IsDebuggerPresent() returned TRUE";
    }
    return r;
}

DebugCheckResult check_remote_debugger() {
    DebugCheckResult r;
    BOOL present = FALSE;
    if (CheckRemoteDebuggerPresent(GetCurrentProcess(), &present) && present) {
        r.detected = true;
        r.reason = "CheckRemoteDebuggerPresent() returned TRUE";
    }
    return r;
}

DebugCheckResult check_debug_port() {
    DebugCheckResult r;
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    if (!ntdll) {
        return r;
    }
    auto NtQIP = reinterpret_cast<NtQueryInformationProcess_t>(
            GetProcAddress(ntdll, "NtQueryInformationProcess"));
    if (!NtQIP) {
        return r;
    }
    DWORD_PTR debug_port = 0;
    ULONG ret_len = 0;
    NTSTATUS status = NtQIP(GetCurrentProcess(), ProcessDebugPort, &debug_port, sizeof(debug_port), &ret_len);
    if (status == 0 && debug_port != 0) {
        r.detected = true;
        r.reason = "NtQueryInformationProcess(ProcessDebugPort) != 0";
    }
    return r;
}

DebugCheckResult check_hardware_breakpoints() {
    DebugCheckResult r;
    // NOTE: querying the debug registers of the *currently executing*
    // thread via GetThreadContext is a commonly cited technique but its
    // reliability varies across Windows versions/CPUs. For a sturdier
    // version, have a separate watcher thread suspend the target thread
    // before calling GetThreadContext on it. Test on your real targets.
    CONTEXT ctx;
    ZeroMemory(&ctx, sizeof(CONTEXT));
    ctx.ContextFlags = CONTEXT_DEBUG_REGISTERS;
    if (GetThreadContext(GetCurrentThread(), &ctx)) {
        if (ctx.Dr0 != 0 || ctx.Dr1 != 0 || ctx.Dr2 != 0 || ctx.Dr3 != 0) {
            r.detected = true;
            r.reason = "Hardware breakpoint registers (Dr0-Dr3) are set";
        }
    }
    return r;
}

#if defined(_MSC_VER)

DebugCheckResult check_peb_flag() {
    DebugCheckResult r;
#if defined(_WIN64)
    PPEB peb = reinterpret_cast<PPEB>(__readgsqword(0x60));
#else
    PPEB peb = reinterpret_cast<PPEB>(__readfsdword(0x30));
#endif
    if (peb && peb->BeingDebugged) {
        r.detected = true;
        r.reason = "PEB->BeingDebugged flag is set";
    }
    return r;
}

DebugCheckResult check_timing() {
    DebugCheckResult r;
    // NOTE: this threshold is a rough heuristic that WILL need tuning
    // per target hardware and can false-positive on slow, throttled or
    // virtualized machines. Treat it as a weak corroborating signal, not
    // a sole trigger - e.g. require several consecutive hits before
    // reacting to it.
    unsigned __int64 start = __rdtsc();
    volatile int sink = 0;
    for (int i = 0; i < 1000; ++i) {
        sink += i;
    }
    unsigned __int64 elapsed = __rdtsc() - start;
    constexpr unsigned __int64 kSuspiciousThreshold = 2000000; // cycles
    if (elapsed > kSuspiciousThreshold) {
        r.detected = true;
        r.reason = "RDTSC timing anomaly around a tight loop (possible single-stepping)";
    }
    return r;
}

#endif // _MSC_VER

#elif defined(__linux__)

DebugCheckResult check_tracer_pid() {
    DebugCheckResult r;
    std::ifstream status_file("/proc/self/status");
    std::string line;
    while (std::getline(status_file, line)) {
        if (line.rfind("TracerPid:", 0) == 0) {
            int pid = 0;
            try {
                pid = std::stoi(line.substr(10));
            } catch (...) {
                pid = 0;
            }
            if (pid != 0) {
                r.detected = true;
                r.reason = "TracerPid != 0 in /proc/self/status";
            }
            break;
        }
    }
    return r;
}

DebugCheckResult check_ptrace_traceme() {
    DebugCheckResult r;
    // Classic Linux trick: a process can only be ptrace-d by one tracer
    // at a time. If a debugger is already attached, PTRACE_TRACEME on
    // ourselves fails. We detach immediately afterwards so we don't
    // block a legitimate tool, or our own next check, later on.
    //
    // Known limitations: behavior interacts with the kernel's YAMA
    // ptrace_scope setting, and this only catches a tracer attached
    // *before* this call runs. Test on your target distros.
    if (ptrace(PTRACE_TRACEME, 0, 1, 0) == -1) {
        r.detected = true;
        r.reason = "ptrace(PTRACE_TRACEME) failed - process is already traced";
    } else {
        ptrace(PTRACE_DETACH, 0, 1, 0);
    }
    return r;
}

#endif

} // namespace

DebugCheckResult AntiDebug::check_all() {
#if defined(_WIN32)
    DebugCheckResult r = check_is_debugger_present();
    if (r.detected) return r;

    r = check_remote_debugger();
    if (r.detected) return r;

    r = check_debug_port();
    if (r.detected) return r;

    r = check_hardware_breakpoints();
    if (r.detected) return r;

#if defined(_MSC_VER)
    r = check_peb_flag();
    if (r.detected) return r;

    r = check_timing();
    if (r.detected) return r;
#endif

    return r; // not detected

#elif defined(__linux__)
    DebugCheckResult r = check_tracer_pid();
    if (r.detected) return r;

    r = check_ptrace_traceme();
    return r;

#else
    DebugCheckResult r;
    r.detected = false;
    r.reason = "AntiDebug: platform not implemented";
    return r;
#endif
}

} //namespace godot_rp
