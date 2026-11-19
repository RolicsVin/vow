# RuntimeProtector — GDExtension (C++) for Godot 4.x

A small GDExtension exposing a `RuntimeProtector` node to GDScript with:

- **Anti-debugging** — `IsDebuggerPresent`, `CheckRemoteDebuggerPresent`,
  `NtQueryInformationProcess(ProcessDebugPort)`, hardware breakpoint
  register check, PEB `BeingDebugged` flag, RDTSC timing heuristic
  (Windows/MSVC); `/proc/self/status` TracerPid + `ptrace(PTRACE_TRACEME)`
  (Linux).
- **Anti-hooking** — loaded-module snapshot/diff (detects injected
  DLLs/`.so`s), IAT walk on Windows (detects redirected imports), and a
  helper to compare a function's prologue bytes against a known-good copy.
- **Anti-tampering** — a dependency-free SHA-256 implementation to hash
  and verify your `.pck` (or any file) at runtime.

> **Disclosure:** this code was written without the ability to compile or
> run it (no network access to fetch `godot-cpp`, no Godot/toolchain in
> that environment). The algorithms and Win32/Linux APIs are implemented
> carefully and the SHA-256 implementation ships with a self-test against
> the official FIPS 180-4 test vectors, but **you must build it yourself
> and verify it before shipping**. See "Verifying before you ship" below.

## Why this exists (and what it doesn't do)

Read this before integrating:

- Every check here is a **userland heuristic**. A motivated attacker with
  kernel-level tooling (driver-based unhookers, hypervisor-based
  debugging) can defeat any single one of them.
- Checking a binary's own integrity **from inside that same binary** is a
  logically weak pattern — find the `if`, patch the jump, you're past it.
  Prefer running checks redundantly, in multiple places, and — more
  importantly — making your protected logic *require* the check to pass
  to function correctly (e.g. derive a decryption key from state the
  check sets) rather than gating it behind a single `if (hacked) exit()`.
- This GDExtension is itself an external file (`.dll`/`.so`). Nothing
  stops someone from patching it, replacing it with a stub exporting the
  same symbols, or editing the `.gdextension` file so Godot never loads
  it — unless you also verify its own integrity from somewhere that
  *isn't* the extension itself (e.g. a forked/recompiled engine).
- For multiplayer games, none of this replaces an authoritative server.
  Client-side anti-tamper slows down cheating; it does not prevent a
  client from lying to an unprotected server.

In short: this is a reasonable baseline against casual reverse engineering,
trainers, and opportunistic tampering — not an EAC/BattlEye-grade system.

## Project layout

```
runtime_protector/
├── SConstruct                   # build script (needs godot-cpp)
├── runtime_protector.gdextension
├── README.md
└── src/
    ├── register_types.{h,cpp}   # GDExtension entry point
    ├── runtime_protector.{h,cpp}# the Node exposed to GDScript
    ├── anti_debug.{h,cpp}
    ├── anti_hook.{h,cpp}
    ├── anti_tamper.{h,cpp}
    └── sha256.{h,cpp}           # dependency-free SHA-256
```

## Building

1. Install [SCons](https://scons.org/) and a C++17 compiler (MSVC on
   Windows, GCC/Clang on Linux).
2. Fetch `godot-cpp`, matching your Godot version, as a sibling folder:

   ```bash
   cd runtime_protector
   git clone --branch 4.2 https://github.com/godotengine/godot-cpp.git
   cd godot-cpp
   git submodule update --init
   cd ..
   ```

   (Use the branch/tag matching your Godot version, e.g. `4.1`, `4.2`,
   `4.3`.)

3. Build:

   ```bash
   # Windows, debug export template
   scons platform=windows target=template_debug

   # Windows, release export template
   scons platform=windows target=template_release

   # Linux, debug export template
   scons platform=linux target=template_debug

   # Linux, release export template
   scons platform=linux target=template_release
   ```

   This produces files under `bin/`, e.g.
   `bin/libruntimeprotector.windows.template_debug.x86_64.dll`, matching
   the paths already listed in `runtime_protector.gdextension`.

4. Copy into your Godot project:

   ```
   your_godot_project/
   ├── bin/                      # the compiled .dll/.so files from step 3
   ├── runtime_protector.gdextension
   └── ... your project files
   ```

   Godot will auto-detect the `.gdextension` file and register the
   `RuntimeProtector` class the next time the project is opened or run.

## Verifying before you ship

Since this wasn't compiled in the environment that wrote it, at minimum:

1. Build it (above) and make sure it compiles cleanly.
2. In Godot, call `self_test_sha256()` — it must return `true`. If it
   returns `false`, do not trust `compute_sha256()` / the anti-tamper
   checks until you've fixed the implementation.
3. Spot-check `compute_sha256()` on a real file against a trusted tool:

   ```bash
   sha256sum your_file.pck          # Linux
   certutil -hashfile your_file.pck SHA256   # Windows
   ```

4. Attach a debugger (e.g. x64dbg, gdb) to a debug build and confirm
   `debugger_detected` actually fires, and that it stops firing once you
   detach.
5. Load the compiled library with something like Cheat Engine or a
   trainer DLL and confirm `hook_detected` fires.

## Release verification

Every exported Release build verifies the local Authenticode signatures of the EXE and
RuntimeProtector DLL, then verifies the local Ed25519 signature of `integrity.manifest`.
These checks run before gameplay starts and do not require an internet connection.
They are independent from the `autostart` setting.

An optional remote SHA-256 check can be configured through `hashes_url`. The URL must use
HTTPS and return a manifest in the same format as `integrity.manifest`:

```text
VOW-INTEGRITY-V1
exe=<64-character SHA-256>
pck=<64-character SHA-256>
dll=<64-character SHA-256>
```

The `integrity.manifest` created by `tools/sign_release.py sign` can be hosted directly
at this URL. If the request cannot be completed (no connection, timeout, or unavailable
server), only the remote hash comparison is skipped. If the file is downloaded but is
malformed or any hash differs, startup is blocked. A valid local Authenticode/Ed25519
signature is still required in all cases.

Set the URL on the RuntimeProtector node:

```gdscript
protector.hashes_url = "https://example.com/game/integrity.manifest"
```

Leave `hashes_url` empty to disable the remote check. The local signature checks remain
enabled in Release builds.

## Usage from GDScript

```gdscript
extends Node

var protector: RuntimeProtector

func _ready() -> void:
    protector = RuntimeProtector.new()
    # Configure startup verification before adding the node to the tree.
    protector.hashes_url = "https://example.com/game/integrity.manifest"
    protector.pck_path = OS.get_executable_path().get_base_dir().path_join("game.pck")
    add_child(protector)

    protector.debugger_detected.connect(_on_debugger_detected)
    protector.hook_detected.connect(_on_hook_detected)
    protector.tampering_detected.connect(_on_tampering_detected)

    if not protector.self_test_sha256():
        push_error("RuntimeProtector: SHA-256 self-test failed — do not trust hash checks!")

    protector.check_interval_ms = 2000
    protector.enable_anti_debug = true
    protector.enable_anti_hook = true

    # Anti-tamper is opt-in: you need the real hash of your shipped .pck.
    # Compute it once at build time (e.g. with sha256sum) and bake it in —
    # ideally not as one obvious plain string literal; split/obfuscate it
    # at the very least, since this is just a string an attacker can read
    # out of the binary otherwise.
    protector.expected_pck_hash = "PUT_THE_REAL_SHA256_HASH_HERE"
    protector.enable_anti_tamper = true

    # 0 = signal only (recommended to start with), 1 = quit, 2 = crash
    protector.reaction_mode = RuntimeProtector.REACTION_SIGNAL_ONLY
    protector.start_protection()

func _on_debugger_detected(reason: String) -> void:
    print("Debugger detected: ", reason)
    # Your call: degrade silently, corrupt save state, flag the session
    # server-side, etc. An instant, obvious crash is the easiest pattern
    # to find and patch out.

func _on_hook_detected(reason: String) -> void:
    print("Hook detected: ", reason)

func _on_tampering_detected(reason: String) -> void:
    print("Tampering detected: ", reason)
```

One-shot checks are also available without the background thread:

```gdscript
if protector.check_debugger_now():
    pass # a debugger is attached right now

if not protector.verify_pck_now():
    pass # pck missing, unreadable, or hash mismatch
```

## Extending this

- `AntiHook::check_function_bytes()` takes a raw pointer and expected
  byte sequence — wire it up to your own exported, performance-critical,
  or license-check functions to catch inline hooks on them specifically.
- Consider running the anti-debug/anti-hook checks from more than one
  call site (e.g. also inline in a hot gameplay function), not only from
  the background thread, since the thread itself is a single point an
  attacker can locate and suspend.
- For the strongest version of the integrity checks, move part of the
  verification into a forked/recompiled Godot engine binary instead of
  (or in addition to) this extension — see the "What this doesn't do"
  section above.
