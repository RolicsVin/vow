"""tools.py

Call from GDScript:
    var r = await PythonBridge.call_function("tools", "hello", ["Godot"])
"""


def hello(name="world"):
    return f"Hello, {name}!"
