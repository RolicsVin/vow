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
- **Anti-tampering** — SHA-256 file hashing plus signed-release verification.
- **Release signatures (Windows x64)** — Authenticode for the EXE and loaded
  GDExtension DLL, plus Ed25519 verification of a signed manifest containing
  hashes for the EXE, PCK, and DLL.

> **Build status:** the repository changes have not been compiled in this
> environment. Build the Windows x64 extension and complete the release
> verification steps below before shipping.

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
├── tools/
│   └── sign_release.py          # Ed25519 key generation and release signing
└── src/
    ├── register_types.{h,cpp}   # GDExtension entry point
    ├── runtime_protector.{h,cpp}
    ├── anti_debug.{h,cpp}
    ├── anti_hook.{h,cpp}
    ├── anti_tamper.{h,cpp}
    ├── anti_signature.{h,cpp}  # Authenticode and Ed25519 verification
    ├── integrity_public_key.h
    ├── sha256.{h,cpp}
    └── third_party/             # Monocypher 4.0.3 (Ed25519 verification)
```

## Building

1. Install SCons and Visual Studio 2022 with the **Desktop development with C++**
   workload. Open the x64 Native Tools Command Prompt.
2. Fetch `godot-cpp` matching the Godot version used by the project:

   ```powershell
   cd addons/runtime_protector
   git clone --branch 4.7 https://github.com/godotengine/godot-cpp.git
   cd godot-cpp
   git submodule update --init
   cd ..
   ```

3. Build the Windows x64 templates:

   ```powershell
   scons platform=windows target=template_debug arch=x86_64 api_version=4.7
   scons platform=windows target=template_release arch=x86_64 api_version=4.7
   ```

   The DLLs are written to `bin/` and match the paths in
   `runtime_protector.gdextension`. This build configuration intentionally
   rejects platforms other than Windows x64.

4. Ensure the exported project contains the matching GDExtension DLL and a
   separate PCK file next to the EXE. The integrity verifier currently expects
   an external PCK; an embedded PCK is not supported by this release workflow.

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

## Usage from GDScript

```gdscript
extends Node

var protector: RuntimeProtector

func _ready() -> void:
    protector = RuntimeProtector.new()
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
    protector.pck_path = OS.get_executable_path().get_base_dir().path_join("game.pck")
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


## Windows x64 release signature verification

Release startup verification is enabled by default when a `RuntimeProtector`
node is present in the running project. The node must be present in the first loaded scene (or an autoload)
and its `autostart` property must be enabled. It is enabled by default.
Editor sessions skip the check.

The verifier requires all of the following:

- The running EXE has a valid, trusted Authenticode signature.
- The loaded RuntimeProtector DLL has a valid, trusted Authenticode signature.
- The adjacent PCK matches the SHA-256 value in the signed manifest.
- The EXE, PCK, and loaded DLL hashes all match a valid Ed25519-signed
  manifest.

The manifest and signature are placed next to the EXE as
`integrity.manifest` and `integrity.sig`. By default, the PCK is expected next
to the EXE with the same base filename. Set `pck_path` to an absolute path
before calling `start_protection()` if the PCK is stored elsewhere.

### 1. Generate a signing key pair (once)

Install the Python dependency:

```powershell
py -m pip install cryptography
```

From `addons/runtime_protector`:

```powershell
py tools/sign_release.py keygen
```

This creates `keys/integrity_private.key` and writes the public key to
`src/integrity_public_key.h`. Keep the private key offline and never commit it.
Rebuild the Windows x64 GDExtension after generating the public key.

### 2. Build and Authenticode-sign the binaries

Build the release DLL, export the game, and sign both PE files with your
code-signing certificate:

```powershell
signtool sign /fd SHA256 /tr <timestamp-server-url> /td SHA256 /a path\to\game.exe
signtool sign /fd SHA256 /tr <timestamp-server-url> /td SHA256 /a path\to\libruntimeprotector.windows.template_release.x86_64.dll
```

The DLL must be the exact library loaded by the exported game. Sign it before
generating the Ed25519 manifest. The executable must also be signed before
generating the manifest. Do not modify either binary after the manifest is
generated.

### 3. Generate the Ed25519 manifest

Run the signing command after Authenticode signing. Use the actual exported
PCK and the exact DLL shipped with the game:

```powershell
py tools/sign_release.py sign `
  --private-key keys/integrity_private.key `
  --exe path\to\game.exe `
  --pck path\to\game.pck `
  --dll path\to\libruntimeprotector.windows.template_release.x86_64.dll `
  --output path\to\export
```

The output directory must be the same directory as the EXE. Ship
`integrity.manifest` and `integrity.sig` alongside the EXE and PCK.

### Runtime behaviour

If any required file is missing, unreadable, unsigned, untrusted, changed, or
has an invalid Ed25519 signature, `RuntimeProtector` emits
`tampering_detected` and requests immediate game shutdown. This check runs
synchronously before the background protection thread starts.

For local development builds, disable `enable_signature_verification` on the
node. Do not disable it in a release build.

The Ed25519 public key is embedded in the extension; the private key is never
needed by the game. The detached manifest signature prevents replacement of
the manifest with new hashes without the private key. Authenticode verification
uses the Windows trust policy and cached certificate data; the signing tool
runs `signtool verify /pa` before creating a manifest.

**Important limitation:** because the verifier runs inside the client process,
a determined attacker can patch or bypass it. For stronger protection, verify
critical game state on a trusted server or move an independent check into a
custom Godot engine build.
