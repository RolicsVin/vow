"""Модуль обфускации идентификаторов GDScript.

Режимы:
  locals  — безопасный режим (как раньше): переименовывает только локальные
            идентификаторы внутри функций (параметры, var/const, переменные
            циклов). Поведение этого режима не изменилось.
  scan    — полный режим, шаг 1: сканирует весь проект и строит общую карту
            переименований функций/переменных класса/сигналов, одинаковую
            для всех файлов проекта.
  apply   — полный режим, шаг 2 (для .gd): применяет карту из scan к файлу,
            затем прогоняет его через безопасный локальный проход (locals).
  scene   — полный режим, шаг 2 (для .tscn/.tres): обновляет свойства узлов
            и секции [connection], ссылающиеся на переименованные имена.
"""

from __future__ import annotations

import argparse
import json
import re
import secrets
from pathlib import Path


_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_FUNCTION_RE = re.compile(r"^([ \t]*)(?:static[ \t]+)?func[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(")
_TOKEN_RE = re.compile(
    r"(?P<string>&?[rR]?(?:\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''|"
    r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'))"
    r"|(?P<comment>\#[^\r\n]*)"
    r"|(?P<identifier>[A-Za-z_][A-Za-z0-9_]*)"
    r"|(?P<other>.)",
    re.DOTALL,
)


def _indent_width(line: str) -> int:
    """Возвращает ширину отступа строки с учётом табуляции."""
    return len(line) - len(line.lstrip(" \t"))


def _function_ranges(code: str) -> list[tuple[int, int]]:
    """Находит диапазоны функций в исходном коде."""
    lines: list[str] = code.splitlines(keepends=True)
    ranges: list[tuple[int, int]] = []
    offsets: list[int] = []
    offset: int = 0

    for line in lines:
        offsets.append(offset)
        offset += len(line)

    for index, line in enumerate(lines):
        if _FUNCTION_RE.match(line) is None:
            continue

        base_indent: int = _indent_width(line)
        end_index: int = len(lines)

        # Конец функции определяется следующей строкой с равным или меньшим отступом
        for next_index in range(index + 1, len(lines)):
            candidate: str = lines[next_index]
            stripped: str = candidate.strip()

            if not stripped or stripped.startswith("#"):
                continue

            if _indent_width(candidate) <= base_indent:
                end_index = next_index
                break

        end_offset: int = offsets[end_index] if end_index < len(offsets) else len(code)
        ranges.append((offsets[index], end_offset))

    return ranges


def _parameter_names(header: str) -> set[str]:
    """Извлекает имена параметров из заголовка функции."""
    opening: int = header.find("(")
    if opening < 0:
        return set()

    depth: int = 0
    closing: int = -1
    quote: str = ""
    escaped: bool = False

    for index in range(opening, len(header)):
        char: str = header[index]

        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue

        if char in ("'", '"'):
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                closing = index
                break

    if closing < 0:
        return set()

    arguments: str = header[opening + 1:closing]
    names: set[str] = set()
    depth = 0
    start = 0
    quote = ""
    escaped = False

    # Разделяем параметры только по запятым верхнего уровня
    for index, char in enumerate(arguments + ","):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue

        if char in ("'", '"'):
            quote = char
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            part: str = arguments[start:index].strip()
            match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)", part)
            if match:
                names.add(match.group(1))
            start = index + 1

    return names


def _declared_local_names(body: str) -> set[str]:
    """Находит локальные переменные и переменные циклов внутри функции."""
    names: set[str] = set()

    for line in body.splitlines():
        declaration = re.match(
            r"^[ \t]*(?:var|const)[ \t]+([A-Za-z_][A-Za-z0-9_]*)\b", line
        )
        loop_variable = re.match(
            r"^[ \t]*for[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+in\b", line
        )

        if declaration:
            names.add(declaration.group(1))
        if loop_variable:
            names.add(loop_variable.group(1))

    return names


def _new_identifier(used_names: set[str], prefix: str = "_v_") -> str:
    """Создаёт уникальное имя, не совпадающее с исходными идентификаторами."""
    while True:
        candidate: str = prefix + secrets.token_hex(4)
        if candidate not in used_names:
            used_names.add(candidate)
            return candidate


def _obfuscate_function(function_code: str) -> str:
    """Переименовывает только локальные идентификаторы одной функции."""
    local_names: set[str] = _parameter_names(function_code)
    local_names.update(_declared_local_names(function_code))

    if not local_names:
        return function_code

    used_names: set[str] = {
        match.group(0)
        for match in re.finditer(r"[A-Za-z_][A-Za-z0-9_]*", function_code)
    }
    replacements: dict[str, str] = {
        name: _new_identifier(used_names)
        for name in sorted(local_names)
        if _IDENTIFIER_RE.match(name)
    }

    if not replacements:
        return function_code

    output: list[str] = []
    previous_significant: str = ""
    bracket_stack: list[str] = []
    tokens = list(_TOKEN_RE.finditer(function_code))

    for index, token in enumerate(tokens):
        value: str = token.group(0)

        if token.lastgroup == "other":
            if value in "([{":
                bracket_stack.append(value)
            elif value in ")]}" and bracket_stack:
                bracket_stack.pop()

        if token.lastgroup != "identifier" or value not in replacements:
            output.append(value)
            if token.lastgroup not in ("string", "comment") and not value.isspace():
                previous_significant = value
            elif "\n" in value:
                previous_significant = ""
            continue

        next_significant: str = ""
        for following in tokens[index + 1:]:
            if following.lastgroup in ("string", "comment"):
                break
            if not following.group(0).isspace():
                next_significant = following.group(0)
                break

        is_member: bool = previous_significant == "."
        # Это ключ словарного литерала { key = value, ... }, а не наш
        # локальный идентификатор, только если непосредственно окружающая
        # скобка — фигурная. Для круглой скобки "(" это значение параметра
        # по умолчанию в заголовке функции — его нужно переименовывать, как
        # и любое другое объявление параметра.
        is_dict_key: bool = (
            next_significant == "=" and bool(bracket_stack) and bracket_stack[-1] == "{"
        )

        if is_member or is_dict_key:
            output.append(value)
        else:
            output.append(replacements[value])

        previous_significant = output[-1]

    return "".join(output)


def obfuscate(code: str) -> str:
    """Обфусцирует локальные переменные и параметры, сохраняя структуру GDScript.

    Это безопасный режим — его поведение и результат не изменились.
    """
    if not isinstance(code, str):
        raise TypeError("code должен иметь тип str")

    ranges: list[tuple[int, int]] = _function_ranges(code)
    if not ranges:
        return code

    result: list[str] = []
    cursor: int = 0

    for start, end in ranges:
        if start < cursor:
            continue

        result.append(code[cursor:start])
        result.append(_obfuscate_function(code[start:end]))
        cursor = end

    result.append(code[cursor:])
    return "".join(result)


# ---------------------------------------------------------------------------
# Полный режим: общий словарь переименований функций/переменных класса/сигналов
# ---------------------------------------------------------------------------

# Виртуальные методы и колбэки движка — их имена Godot вызывает по строке,
# поэтому они никогда не переименовываются.
_VIRTUAL_METHODS: frozenset[str] = frozenset({
    "_init", "_ready", "_enter_tree", "_exit_tree", "_process",
    "_physics_process", "_input", "_unhandled_input", "_unhandled_key_input",
    "_shortcut_input", "_gui_input", "_draw", "_notification", "_get",
    "_set", "_get_property_list", "_property_can_revert",
    "_property_get_revert", "_validate_property", "_to_string",
    "_get_minimum_size", "_get_configuration_warnings", "_get_tooltip",
    "_can_drop_data", "_drop_data", "_get_drag_data", "_integrate_forces",
    "_static_init", "_get_rid", "_input_event",
})

# Частые встроенные свойства/сигналы узлов Godot. Если в проекте объявлено
# собственное имя, совпадающее с одним из них, оно не переименовывается —
# иначе обращение к ЧУЖОМУ узлу с таким же встроенным свойством/сигналом
# в другом месте проекта могло бы случайно сломаться.
_COMMON_ENGINE_MEMBERS: frozenset[str] = frozenset({
    "position", "global_position", "rotation", "rotation_degrees", "scale",
    "size", "custom_minimum_size", "visible", "modulate", "self_modulate",
    "text", "value", "name", "color", "texture", "disabled", "z_index",
    "process_mode", "pressed", "toggled", "value_changed", "text_changed",
    "text_submitted", "item_selected", "item_activated", "timeout",
    "finished", "animation_finished", "body_entered", "body_exited",
    "area_entered", "area_exited", "tree_entered", "tree_exited",
    "tree_exiting", "ready", "renamed", "resized", "draw", "gui_input",
    "focus_entered", "focus_exited", "mouse_entered", "mouse_exited",
    "input_event", "property_list_changed", "script_changed", "changed",
    "confirmed", "canceled", "popup_hide", "about_to_popup", "id_pressed",
    "button_up", "button_down", "screen_entered", "screen_exited",
    "started", "stopped",
})

# Аннотация (@export, @export_range(...), @onready и т.п.), которая может
# стоять прямо перед func/var/const на той же строке.
_ANNOTATION_PREFIX: str = r"(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?[ \t]+)*"

_CLASS_FUNC_RE = re.compile(
    r"^" + _ANNOTATION_PREFIX + r"(?:static[ \t]+)?func[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\("
)
_CLASS_SIGNAL_RE = re.compile(r"^" + _ANNOTATION_PREFIX + r"signal[ \t]+([A-Za-z_][A-Za-z0-9_]*)\b")
_CLASS_VAR_RE = re.compile(
    r"^" + _ANNOTATION_PREFIX + r"(?:static[ \t]+)?(?:var|const)[ \t]+([A-Za-z_][A-Za-z0-9_]*)\b"
)

# Вызовы, у которых строковый аргумент может ссылаться на имя функции/сигнала
# по строке (а не напрямую идентификатором) — такие строки тоже переименовываются.
_DYNAMIC_REF_CALLS: frozenset[str] = frozenset({
    "connect", "disconnect", "is_connected", "emit_signal", "has_signal",
    "call", "call_deferred", "callv", "rpc", "rpc_id", "has_method",
    "get", "set", "get_indexed", "set_indexed", "Callable",
})


def _is_relative_to(path: Path, base: Path) -> bool:
    """Проверяет, находится ли path внутри base (без Path.is_relative_to)."""
    try:
        path.resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def _iter_gd_files(project_root: Path, excludes: list[Path]):
    """Перебирает .gd файлы проекта, пропуская исключённые директории."""
    for path in sorted(project_root.rglob("*.gd")):
        if any(_is_relative_to(path, excluded) for excluded in excludes):
            continue
        yield path


def _class_level_declarations(text: str) -> tuple[set[str], list[str]]:
    """Находит объявления функций/сигналов/переменных верхнего уровня файла.

    Возвращает (все_имена, имена_переменных) — переменные нужны отдельно,
    чтобы сопоставлять их со свойствами узлов в .tscn/.tres.
    """
    names: set[str] = set()
    var_names: list[str] = []

    for line in text.splitlines():
        if _indent_width(line) != 0:
            continue

        stripped = line.lstrip(" \t")

        func_match = _CLASS_FUNC_RE.match(stripped)
        if func_match:
            names.add(func_match.group(1))
            continue

        signal_match = _CLASS_SIGNAL_RE.match(stripped)
        if signal_match:
            names.add(signal_match.group(1))
            continue

        var_match = _CLASS_VAR_RE.match(stripped)
        if var_match:
            names.add(var_match.group(1))
            var_names.append(var_match.group(1))

    return names, var_names


def _build_rename_map(
    names: set[str], used_names: set[str], reserved: set[str]
) -> dict[str, str]:
    """Строит единую карту старое_имя -> новое_имя для всего проекта."""
    mapping: dict[str, str] = {}
    for name in sorted(names):
        if name in reserved or not _IDENTIFIER_RE.match(name):
            continue
        mapping[name] = _new_identifier(used_names, prefix="_g_")
    return mapping


def scan_project(
    project_root: Path, excludes: list[Path], extra_reserved: set[str]
) -> dict:
    """Сканирует проект и строит общую карту переименований для полного режима."""
    reserved: set[str] = set(_VIRTUAL_METHODS) | set(_COMMON_ENGINE_MEMBERS) | set(extra_reserved)

    declared_names: set[str] = set()
    used_names: set[str] = set()
    file_vars: dict[str, list[str]] = {}

    for gd_path in _iter_gd_files(project_root, excludes):
        try:
            text: str = gd_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError):
            continue

        used_names.update(
            match.group(0) for match in re.finditer(r"[A-Za-z_][A-Za-z0-9_]*", text)
        )

        file_names, file_var_names = _class_level_declarations(text)
        declared_names.update(file_names)

        relative_path = "res://" + gd_path.resolve().relative_to(
            project_root.resolve()
        ).as_posix()
        file_vars[relative_path] = file_var_names

    symbol_map: dict[str, str] = _build_rename_map(declared_names, used_names, reserved)
    risky: list[str] = sorted(name for name in symbol_map if name in _COMMON_ENGINE_MEMBERS)

    return {
        "symbols": symbol_map,
        "file_vars": file_vars,
        "risky": risky,
    }


def _string_literal_identifier(token: str) -> str | None:
    """Если строковый токен — это ровно одно имя идентификатора, возвращает его."""
    body: str = token

    if body.startswith("&"):
        body = body[1:]
    if body[:1] in ("r", "R") and body[1:2] in ("'", '"'):
        body = body[1:]

    if len(body) < 2:
        return None

    quote: str = body[0]
    if quote not in ("'", '"'):
        return None

    if body.startswith(quote * 3):
        if not body.endswith(quote * 3) or len(body) < 6:
            return None
        inner: str = body[3:-3]
    else:
        if not body.endswith(quote):
            return None
        inner = body[1:-1]

    return inner if _IDENTIFIER_RE.match(inner) else None


def _next_significant(tokens: list[re.Match], index: int) -> str:
    """Возвращает следующий значимый токен (без пробелов/строк/комментариев)."""
    for following in tokens[index + 1:]:
        if following.lastgroup in ("string", "comment"):
            break
        if not following.group(0).isspace():
            return following.group(0)
    return ""


# "%" в GDScript — это и бинарный оператор (деление по модулю, форматирование
# строк "%s" % value), и префикс обращения к уникальному узлу (%NodeName).
# "%" считается префиксом уникального узла только тогда, когда непосредственно
# перед ним стоит что-то, после чего ожидается НАЧАЛО нового выражения — иначе
# это бинарный оператор, и то, что после него, нужно переименовывать как
# обычно. У "$" такой неоднозначности нет — это всегда префикс пути к узлу.
_EXPRESSION_START_TOKENS: frozenset[str] = frozenset({
    "", "(", "[", "{", ",", "=", "+", "-", "*", "/", "%", ":", "<", ">", "!",
    "return", "await", "and", "or", "not", "in", "if", "elif", "while", "else",
})


def _apply_global_rename(code: str, symbol_map: dict[str, str]) -> str:
    """Переименовывает функции/переменные класса/сигналы по всему файлу.

    В отличие от локального прохода, обращения через точку (obj.name) тоже
    переименовываются — это нужно, чтобы вызовы чужих (но своих, проектных)
    методов и обращения к публичным переменным оставались согласованными.
    """
    if not symbol_map:
        return code

    tokens: list[re.Match] = list(_TOKEN_RE.finditer(code))
    output: list[str] = []
    previous_significant: str = ""
    pending_call_name: str = ""
    call_name_stack: list[str] = []
    bracket_stack: list[str] = []
    percent_is_node_prefix: bool = False

    for index, token in enumerate(tokens):
        value: str = token.group(0)
        kind: str = token.lastgroup

        if kind == "string":
            literal_name = _string_literal_identifier(value)
            current_call = call_name_stack[-1] if call_name_stack else ""
            if (
                literal_name is not None
                and current_call in _DYNAMIC_REF_CALLS
                and literal_name in symbol_map
            ):
                output.append(value.replace(literal_name, symbol_map[literal_name], 1))
            else:
                output.append(value)
            previous_significant = value
            pending_call_name = ""
            continue

        if kind == "comment":
            output.append(value)
            continue

        if value.isspace():
            output.append(value)
            if "\n" in value:
                # Новая строка — конец выражения/оператора. Не тащим контекст
                # предыдущей строки дальше (важно для $/%/словарных ключей).
                previous_significant = ""
                pending_call_name = ""
            continue

        if kind == "identifier":
            if value in symbol_map:
                is_dict_key: bool = (
                    _next_significant(tokens, index) == "="
                    and bool(bracket_stack)
                    and bracket_stack[-1] == "{"
                )
                is_node_path: bool = previous_significant == "$" or (
                    previous_significant == "%" and percent_is_node_prefix
                )

                if is_dict_key or is_node_path:
                    output.append(value)
                else:
                    output.append(symbol_map[value])
            else:
                output.append(value)

            pending_call_name = value
            previous_significant = value
            continue

        # Однознаковые токены (скобки, точки, операторы и т.п.)
        if value == "%":
            percent_is_node_prefix = previous_significant in _EXPRESSION_START_TOKENS

        if value in "([{":
            bracket_stack.append(value)
        elif value in ")]}" and bracket_stack:
            bracket_stack.pop()

        if value == "(":
            call_name_stack.append(pending_call_name)
        elif value == ")" and call_name_stack:
            call_name_stack.pop()

        if value not in ("(", ")"):
            pending_call_name = ""

        output.append(value)
        previous_significant = value

    return "".join(output)


def _load_map(map_path: Path) -> dict:
    data: dict = json.loads(map_path.read_text(encoding="utf-8"))
    data.setdefault("symbols", {})
    data.setdefault("file_vars", {})
    return data


def apply_full(code: str, rename_map: dict) -> str:
    """Полный режим для .gd: сначала глобальное переименование, затем локальное."""
    symbol_map: dict[str, str] = rename_map.get("symbols", {})
    globally_renamed: str = _apply_global_rename(code, symbol_map)
    return obfuscate(globally_renamed)


# ---------------------------------------------------------------------------
# Полный режим: обновление .tscn/.tres
# ---------------------------------------------------------------------------

_EXT_RESOURCE_RE = re.compile(r"^\[ext_resource\b(?P<attrs>.*)\]\s*$")
_SCRIPTABLE_SECTION_RE = re.compile(r"^\[(?:node|resource|sub_resource)\b")
_SECTION_RE = re.compile(r"^\[[A-Za-z_]+\b")
_SCRIPT_PROPERTY_RE = re.compile(r'^script\s*=\s*ExtResource\(\s*"([^"]+)"\s*\)')
_PROPERTY_KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)([ \t]*=[ \t]*)(.*)$")
_CONNECTION_RE = re.compile(r"^\[connection\b.*\]\s*$")
_ATTR_RE = re.compile(r'(\w+)="([^"]*)"')


def _parse_attrs(attrs_text: str) -> dict[str, str]:
    return {key: value for key, value in _ATTR_RE.findall(attrs_text)}


def _rename_connection_line(line: str, symbol_map: dict[str, str]) -> str:
    """Переименовывает signal="..." и method="..." в строке [connection ...]."""

    def _replace(match: re.Match) -> str:
        attr_name, old_value = match.group(1), match.group(2)
        if attr_name in ("signal", "method") and old_value in symbol_map:
            return '%s="%s"' % (attr_name, symbol_map[old_value])
        return match.group(0)

    return _ATTR_RE.sub(_replace, line)


def apply_scene(text: str, rename_map: dict) -> str:
    """Полный режим для .tscn/.tres: обновляет свойства узлов и [connection].

    Свойства узлов переименовываются только если известно, что к узлу
    подключён скрипт, который действительно объявляет такую переменную
    (чтобы не задеть встроенные свойства Node с совпадающим именем).
    Имена в [connection] переименовываются по общей карте проекта — это
    безопасно, так как частые встроенные сигналы заранее исключены из карты
    (см. _COMMON_ENGINE_MEMBERS).
    """
    symbol_map: dict[str, str] = rename_map.get("symbols", {})
    file_vars: dict[str, list[str]] = rename_map.get("file_vars", {})

    if not symbol_map:
        return text

    lines: list[str] = text.splitlines(keepends=True)
    ext_resources: dict[str, str] = {}
    output: list[str] = []
    current_script_vars: set[str] = set()
    in_scriptable_section: bool = False

    for line in lines:
        stripped: str = line.rstrip("\r\n")
        line_ending: str = line[len(stripped):]

        ext_match = _EXT_RESOURCE_RE.match(stripped)
        if ext_match:
            attrs = _parse_attrs(ext_match.group("attrs"))
            if attrs.get("type") == "Script" and "id" in attrs and "path" in attrs:
                ext_resources[attrs["id"]] = attrs["path"]
            output.append(line)
            in_scriptable_section = False
            continue

        if _CONNECTION_RE.match(stripped):
            output.append(_rename_connection_line(stripped, symbol_map) + line_ending)
            continue

        if _SCRIPTABLE_SECTION_RE.match(stripped):
            in_scriptable_section = True
            current_script_vars = set()
            output.append(line)
            continue

        if _SECTION_RE.match(stripped):
            in_scriptable_section = False
            current_script_vars = set()
            output.append(line)
            continue

        if in_scriptable_section:
            script_match = _SCRIPT_PROPERTY_RE.match(stripped)
            if script_match:
                script_path = ext_resources.get(script_match.group(1), "")
                current_script_vars = set(file_vars.get(script_path, []))
                output.append(line)
                continue

            property_match = _PROPERTY_KEY_RE.match(stripped)
            if property_match:
                key = property_match.group(1)
                if key in current_script_vars and key in symbol_map:
                    output.append(
                        symbol_map[key]
                        + property_match.group(2)
                        + property_match.group(3)
                        + line_ending
                    )
                    continue

        output.append(line)

    return "".join(output)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> int:
    """Обрабатывает файл/проект через CLI для синхронного вызова из плагина."""
    parser = argparse.ArgumentParser(description="GDScript identifier obfuscator")
    parser.add_argument(
        "--mode",
        choices=["locals", "scan", "apply", "scene"],
        default="locals",
        help="locals — безопасный режим (по умолчанию, как раньше)",
    )
    parser.add_argument("--input", help="Путь к исходному файлу (locals/apply/scene)")
    parser.add_argument("--output", help="Путь к обработанному файлу (locals/apply/scene)")
    parser.add_argument("--map", help="Путь к JSON карте переименований (apply/scene)")
    parser.add_argument("--project-root", help="Корень проекта res:// (scan)")
    parser.add_argument("--map-output", help="Куда сохранить JSON карту (scan)")
    parser.add_argument("--exclude", action="append", default=[], help="Исключаемая папка (scan)")
    parser.add_argument("--reserve", action="append", default=[], help="Доп. защищённое имя (scan)")
    arguments = parser.parse_args()

    try:
        if arguments.mode == "locals":
            source_code: str = Path(arguments.input).read_text(encoding="utf-8")
            Path(arguments.output).write_text(
                obfuscate(source_code), encoding="utf-8", newline="\n"
            )
        elif arguments.mode == "scan":
            project_root = Path(arguments.project_root)
            excludes = [Path(item) for item in arguments.exclude]
            result = scan_project(project_root, excludes, set(arguments.reserve))
            Path(arguments.map_output).write_text(
                json.dumps(result, ensure_ascii=False), encoding="utf-8"
            )
        elif arguments.mode == "apply":
            rename_map = _load_map(Path(arguments.map))
            source_code = Path(arguments.input).read_text(encoding="utf-8")
            Path(arguments.output).write_text(
                apply_full(source_code, rename_map), encoding="utf-8", newline="\n"
            )
        elif arguments.mode == "scene":
            rename_map = _load_map(Path(arguments.map))
            source_text = Path(arguments.input).read_text(encoding="utf-8")
            Path(arguments.output).write_text(
                apply_scene(source_text, rename_map), encoding="utf-8", newline="\n"
            )
    except (OSError, UnicodeError, ValueError, TypeError, KeyError) as error:
        parser.exit(1, f"obfuscate: {error}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
