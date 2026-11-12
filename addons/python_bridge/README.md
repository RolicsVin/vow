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

## Usage
```python
# res://py/mymath.py
def add(a, b=0):
    return a + b

def slow_square(x):
    print("working...")          # arrives in GDScript via python_log
    return x * x
```
```gdscript
func _ready():
    PythonBridge.python_log.connect(func(level, text): print("[py/%s] %s" % [level, text]))
    await PythonBridge.wait_until_ready()

    var r = await PythonBridge.call_function("mymath", "add", [1, 2])
    if r.ok:
		print(int(r.result))      # 3  (Godot's JSON gives floats, so cast)
	else:
		push_error(r.error)
		print(r.traceback)

	r = await PythonBridge.call_function("mymath", "add", [1], {"b": 5})   # kwargs
```
API: `start()`, `stop()`, `wait_until_ready()`, `call_function(module, function, args, kwargs)`,
`reload_module(name)`, `ping()`; signals `python_ready`, `python_log`, `python_exited`.
`function` may be dotted (`"MyClass.static_method"`); coroutines are awaited automatically.

### Data rules
* JSON types only: `null, bool, int/float, String, Array, Dictionary`. Convert Vector2 etc. yourself.
* `bytes` ⇄ `PackedByteArray`: Python side uses real `bytes`; in GDScript it appears as
  `{"__bytes__": "<base64>"}` (use `Marshalls.base64_to_raw`).
* NaN/Infinity are rejected (Godot's JSON can't parse them) – you get an error response.
* Requests run **one at a time**, in order. A long call delays the next ones; there is no timeout/cancel.
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
