"""
bridge_worker.py - Python side of the Godot "Python Bridge" addon.

Two ways to run it:
  * Desktop:   python bridge_worker.py --path <scripts_dir> [--path ...]
               (JSON lines over stdin/stdout)
  * Embedded:  bridge_worker.create_embedded(sink, paths)
               (Android / Chaquopy; `sink` is a java.util.function.Consumer<String>)

Protocol: one JSON object per line.

  Godot -> Python
    {"id": 1, "op": "call", "module": "m", "function": "f", "args": [...], "kwargs": {...}}
    {"id": 2, "op": "reload", "module": "m"}
    {"id": 3, "op": "ping"}
    {"id": 4, "op": "shutdown"}

  Python -> Godot
    {"type": "ready", "protocol": 1, "python": "3.12.8", "platform": "win32"}
    {"type": "log", "level": "stdout" | "stderr", "text": "..."}
    {"type": "response", "id": 1, "ok": true,  "result": ...}
    {"type": "response", "id": 1, "ok": false, "error": "...", "traceback": "..."}

bytes are transferred as {"__bytes__": "<base64>"} in both directions.
Requests are handled one at a time, in order.
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import dataclasses
import importlib
import inspect
import io
import json
import os
import sys
import threading
import traceback

PROTOCOL_VERSION = 1
BYTES_KEY = "__bytes__"


# --------------------------------------------------------------------------- #
# (de)serialisation
# --------------------------------------------------------------------------- #
def _json_default(obj):
    if isinstance(obj, (bytes, bytearray, memoryview)):
        return {BYTES_KEY: base64.b64encode(bytes(obj)).decode("ascii")}
    if isinstance(obj, (set, frozenset)):
        return list(obj)
    if dataclasses.is_dataclass(obj) and not isinstance(obj, type):
        return dataclasses.asdict(obj)
    if hasattr(obj, "tolist"):  # numpy scalars / arrays
        return obj.tolist()
    return str(obj)


def _dumps(msg) -> str:
    # ensure_ascii keeps the channel pure ASCII; allow_nan=False because
    # Godot's JSON parser cannot read NaN/Infinity.
    return json.dumps(
        msg, default=_json_default, ensure_ascii=True, allow_nan=False, separators=(",", ":")
    )


def _decode(value):
    if isinstance(value, dict):
        if len(value) == 1 and isinstance(value.get(BYTES_KEY), str):
            return base64.b64decode(value[BYTES_KEY])
        return {k: _decode(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_decode(v) for v in value]
    return value


async def _await(awaitable):
    return await awaitable


# --------------------------------------------------------------------------- #
# print() / stderr -> "log" messages
# --------------------------------------------------------------------------- #
class _LogStream(io.TextIOBase):
    encoding = "utf-8"

    def __init__(self, bridge: "Bridge", level: str):
        super().__init__()
        self._bridge = bridge
        self._level = level
        self._buf = ""
        self._lock = threading.Lock()

    def writable(self):
        return True

    def isatty(self):
        return False

    def write(self, s):
        if not isinstance(s, str):
            s = str(s)
        lines = []
        with self._lock:
            self._buf += s
            while "\n" in self._buf:
                line, self._buf = self._buf.split("\n", 1)
                lines.append(line)
        for line in lines:
            self._emit(line)
        return len(s)

    def flush(self):
        with self._lock:
            rest, self._buf = self._buf, ""
        if rest:
            self._emit(rest)

    def _emit(self, text):
        try:
            self._bridge.log(self._level, text.rstrip("\r"))
        except Exception:
            pass  # never recurse into the stream that is failing


# --------------------------------------------------------------------------- #
# Bridge
# --------------------------------------------------------------------------- #
class Bridge:
    def __init__(self, emit, paths=()):
        self._emit = emit
        self._lock = threading.Lock()
        self._closed = False
        self._paths = [p for p in paths if p]
        for p in paths:
            if p and p not in sys.path:
                sys.path.insert(0, p)
        importlib.invalidate_caches()

        self._orig_streams = (sys.stdout, sys.stderr)
        sys.stdout = _LogStream(self, "stdout")
        sys.stderr = _LogStream(self, "stderr")

        self._write(_dumps({
            "type": "ready",
            "protocol": PROTOCOL_VERSION,
            "python": sys.version.split()[0],
            "platform": sys.platform,
        }))

    # -- output -------------------------------------------------------------
    def _write(self, line: str) -> None:
        with self._lock:
            self._emit(line)

    def log(self, level: str, text: str) -> None:
        self._write(_dumps({"type": "log", "level": level, "text": text}))

    def _respond(self, rid, ok, result=None, error="", tb="") -> None:
        msg = {"type": "response", "id": rid, "ok": ok}
        if ok:
            msg["result"] = result
        else:
            msg["error"], msg["traceback"] = error, tb
        try:
            line = _dumps(msg)
        except (TypeError, ValueError) as e:
            line = _dumps({"type": "response", "id": rid, "ok": False,
                           "error": f"result is not JSON-serialisable: {e}", "traceback": ""})
        self._write(line)

    # -- input --------------------------------------------------------------
    def handle_line(self, line: str) -> bool:
        """Handle one request line. Returns False once shutdown was requested."""
        line = line.strip()
        if not line:
            return True
        try:
            req = json.loads(line)
            if not isinstance(req, dict):
                raise ValueError("request must be a JSON object")
        except ValueError as e:
            self.log("stderr", f"[bridge] bad request: {e}")
            return True

        rid = req.get("id")
        op = req.get("op", "call")
        try:
            if op == "call":
                result = self._call(req)
            elif op == "reload":
                importlib.reload(importlib.import_module(req["module"]))
                result = None
            elif op == "ping":
                result = "pong"
            elif op == "shutdown":
                self._respond(rid, True, None)
                self.close()
                return False
            else:
                raise ValueError(f"unknown op {op!r}")
            self._flush_streams()
            self._respond(rid, True, result)
        except BaseException as e:  # includes SystemExit from user code
            tb = traceback.format_exc()
            self._flush_streams()
            self._respond(rid, False, error=f"{type(e).__name__}: {e}", tb=tb)
        return True

    @staticmethod
    def _flush_streams() -> None:
        for s in (sys.stdout, sys.stderr):
            try:
                s.flush()
            except Exception:
                pass

    def _call(self, req):
        module, function = req["module"], req["function"]
        args = _decode(req.get("args") or [])
        kwargs = _decode(req.get("kwargs") or {})
        target = self._import(module)
        for part in function.split("."):
            target = getattr(target, part)
        result = target(*args, **kwargs)
        if inspect.isawaitable(result):
            result = asyncio.run(_await(result))
        return result

    def _import(self, module: str):
        def is_missing(e: ModuleNotFoundError) -> bool:
            return e.name is not None and (module == e.name or module.startswith(e.name + "."))

        try:
            return importlib.import_module(module)
        except ModuleNotFoundError as e:
            if not is_missing(e):
                raise  # the module exists but one of *its* imports is missing
        # The file may have been created after startup: drop import caches, retry once.
        importlib.invalidate_caches()
        try:
            return importlib.import_module(module)
        except ModuleNotFoundError as e:
            if not is_missing(e):
                raise
            looked = ", ".join(
                p if os.path.isdir(p) else p + " (does not exist)" for p in self._paths
            ) or "(no script dirs)"
            raise ModuleNotFoundError(
                f"No module named {module!r}. Script dirs searched: {looked}", name=e.name
            ) from None

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        self._flush_streams()
        sys.stdout, sys.stderr = self._orig_streams


# --------------------------------------------------------------------------- #
# entry points
# --------------------------------------------------------------------------- #
def create_embedded(sink, paths=()):
    """Android/Chaquopy entry point. Java calls bridge.handle_line(json)."""
    return Bridge(lambda line: sink.accept(line), [str(p) for p in paths])


def main(argv=None) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", action="append", default=[], help="extra sys.path entry")
    args = ap.parse_args(argv)

    # Keep the real stdout for the protocol; anything else that writes to fd 1
    # (print, C extensions) is diverted to stderr.
    proto = os.fdopen(os.dup(1), "w", encoding="utf-8", newline="\n")
    os.dup2(2, 1)
    try:
        sys.stdin.reconfigure(encoding="utf-8")
    except Exception:
        pass

    def emit(line: str) -> None:
        proto.write(line + "\n")
        proto.flush()

    bridge = Bridge(emit, args.path)
    try:
        for line in sys.stdin:
            if not bridge.handle_line(line):
                break
    finally:
        bridge.close()


if __name__ == "__main__":
    main()
