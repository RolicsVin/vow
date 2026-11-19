# Python Bridge for Godot 4.4+

Call Python functions from GDScript and get the results back. Python runs
**outside** Godot's scripting layer; only JSON-compatible data crosses over.

| Platform | How Python runs |
|----------|-----------------|
| Windows  | Official *embeddable* CPython, shipped next to your `.exe`, started as a child process (JSON lines over stdin/stdout). |
| Android  | In-process via [Chaquopy](https://chaquo.com/chaquopy/), driven by a small Godot Android plugin. |
| Linux/macOS (editor only) | System `python3` – for development convenience, not packaged on export. |

## Install
1. Copy `addons/python_bridge/` into your project, enable it in *Project Settings → Plugins*
   (this registers the autoload **`PythonBridge`** and the export plugin).
2. Put your scripts into `res://py/` (change in Project Settings → `python_bridge/scripts_dir`).

## Editing .py files inside Godot
On first start the addon adds `py` to the editor setting *docks/filesystem/textfile_extensions*
(this is a global editor setting, not per project) and offers to restart the editor.
After that:
* `.py` files show up in the FileSystem dock and open in the script editor
  (FileSystem → right click on a folder or empty space → **Create New → Python Script...**, or (experimental, off by default: project setting `python_bridge/script_dialog_hook`) via **Create New → Script...** → *Python* in the language list, or **Project → Tools → New Python script...**).
* Syntax highlighting using your editor theme colours, 4 spaces for indentation, auto-indent after `:`.
  Ctrl+K toggles `#` comments.
* Editor integration can be switched off with the project setting `python_bridge/editor_support`
  (restart the editor afterwards).
* Not included: autocompletion, linting, running/debugging - use VS Code / PyCharm when you need those.

## Usage

Python module `res://py/mymath.py`:
```python
def add(a, b=0):
    return a + b

def slow_square(x):
    print("working...")
    return x * x
```

GDScript:
```gdscript
func _ready() -> void:
    PythonBridge.python_log.connect(
        func(level: String, text: String) -> void:
            print("[py/%s] %s" % [level, text])
    )

    var response: Dictionary = PythonBridge.call_function("mymath", "add", [1, 2])
    if response.ok:
        print(int(response.result))
    else:
        push_error(response.error)
        print(response.traceback)

    response = PythonBridge.call_function("mymath", "add", [1], {"b": 5})
```

All public calls are synchronous: `call_function()`, `reload_module()`, `ping()`,
and `wait_until_ready()` return their results directly. **Do not use `await`** with them.

API: `start()`, `stop()`, `wait_until_ready()`, `call_function(module, function, args, kwargs)`,
`reload_module(name)`, `ping()`; signals `python_ready`, `python_log`, `python_exited`.
`function` may be dotted (`"MyClass.static_method"`); Python coroutines are awaited automatically
inside the worker before the result is returned.

### Important: synchronous execution

A synchronous call blocks the calling Godot thread until Python responds. The rendering and input
processing will pause for the duration of the call. Keep Python functions short; use a separate
thread or an asynchronous application-level workflow for long-running operations.

Startup timeout: 30 seconds. Request timeout: 5 minutes. While waiting, the bridge actively polls
the backend, so responses and log signals are still processed even though the main thread is blocked.

### Data rules
* JSON types only: `null, bool, int/float, String, Array, Dictionary`. Convert Vector2 etc. yourself.
* `bytes` ⇄ `PackedByteArray`: Python side uses real `bytes`; in GDScript it appears as
  `{"__bytes__": "<base64>"}` (use `Marshalls.base64_to_raw`).
* NaN/Infinity are rejected (Godot's JSON can't parse them) – you get an error response.
* Requests run **one at a time**, in order.
* `print()`/stderr output and uncaught tracebacks come through `python_log`.

## Windows
```
python addons/python_bridge/tools/setup_windows_runtime.py -r requirements.txt
```
Downloads the embeddable Python into `addons/python_bridge/runtime/windows/` (has `.gdignore`,
so the editor doesn't scan it) and installs pure-Python / win_amd64-wheel packages into it.
On export the runtime is copied to `<export dir>/python_runtime/` – ship that folder with the exe.
Scripts are packed into the `.pck` automatically and unpacked to `user://python_bridge/` at startup
(Python can't read a `.pck`).

## Android
Needs the **Gradle build** (no Gradle = no way to add Python).
1. *Project → Install Android Build Template…*, enable **Use Gradle Build** in the Android export preset.
2. Add Chaquopy to `android/build/build.gradle`. The exact syntax depends on your Chaquopy / Android
   Gradle Plugin versions – follow the official "Adding to an existing project" docs. In outline:
   * add the Chaquopy Gradle plugin to the `buildscript` classpath and `apply plugin: 'com.chaquo.python'`
   * set the Python version and `abiFilters` (must match the architectures ticked in your export preset)
   * list pip packages for the app, if any
3. Export. The export plugin copies `android/PythonBridgePlugin.java` into
   `android/build/src/main/java/io/github/pythonbridge/` and registers it in the manifest.

Pure-Python packages and Chaquopy-hosted binary wheels (numpy etc.) work; arbitrary C extensions don't.
Your scripts are the same files as on Windows – keep them to the stdlib + packages available on both.

## Not verified yet
The Python worker is tested (calls, kwargs, errors, print capture, bytes, async, unicode, NaN).
The GDScript and Android Java code were written against the Godot 4.4 / Chaquopy APIs but have **not**
been run on a real Godot/Android toolchain – expect to fix small things on first run.
