"""Модуль безопасной обфускации локальных идентификаторов GDScript."""

from __future__ import annotations

import argparse
import re
import secrets
from pathlib import Path


_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_FUNCTION_RE = re.compile(r"^([ \t]*)func[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\\(")
_TOKEN_RE = re.compile(
    r"(?P<string>&?[rR]?(?:\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''|"
    r"\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'))"
    r"|(?P<comment>\#[^\r\n]*)"
    r"|(?P<identifier>[A-Za-z_][A-Za-z0-9_]*)"
    r"|(?P<other>.)",
    re.DOTALL,
)


def _indent_width(line: str) -> int:
    """Возвращает ширину отступа строки с учётом табуляции."""
    return len(line) - len(line.lstrip(" \t"))


def _function_ranges(code: str) -> list[tuple[int, int, int, int]]:
    """Находит диапазоны функций и позиции начала их заголовков."""
    lines = code.splitlines(keepends=True)
    ranges: list[tuple[int, int, int, int]] = []
    offsets: list[int] = []
    offset = 0

    for line in lines:
        offsets.append(offset)
        offset += len(line)

    for index, line in enumerate(lines):
        match = _FUNCTION_RE.match(line)
        if match is None:
            continue

        base_indent = _indent_width(line)
        end_index = len(lines)

        for next_index in range(index + 1, len(lines)):
            candidate = lines[next_index]
            stripped = candidate.strip()

            if not stripped or stripped.startswith("#"):
                continue

            if _indent_width(candidate) <= base_indent:
                end_index = next_index
                break

        end_offset = offsets[end_index] if end_index < len(offsets) else len(code)
        ranges.append((offsets[index], end_offset, offsets[index], end_offset))

    return ranges


def _parameter_names(header: str) -> set[str]:
    """Извлекает имена параметров из заголовка функции."""
    opening = header.find("(")
    if opening < 0:
        return set()

    depth = 0
    closing = -1
    quote = ""
    escaped = False

    for index in range(opening, len(header)):
        char = header[index]

        if quote:
            if escaped:
                escaped = False
            elif char == "\\\\":
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

    arguments = header[opening + 1:closing]
    names: set[str] = set()
    depth = 0
    start = 0
    quote = ""
    escaped = False

    for index, char in enumerate(arguments + ","):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\\\":
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
            part = arguments[start:index].strip()
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
            r"^[ \t]*(?:var|const)[ \t]+([A-Za-z_][A-Za-z0-9_]*)\\b", line
        )
        loop_variable = re.match(
            r"^[ \t]*for[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+in\\b", line
        )

        if declaration:
            names.add(declaration.group(1))
        if loop_variable:
            names.add(loop_variable.group(1))

    return names


def _new_identifier(used_names: set[str]) -> str:
    """Создаёт уникальное имя, не совпадающее с исходными идентификаторами."""
    while True:
        candidate = "_v_" + secrets.token_hex(4)
        if candidate not in used_names:
            used_names.add(candidate)
            return candidate


def _obfuscate_function(function_code: str) -> str:
    """Переименовывает только локальные идентификаторы одной функции."""
    header_end = function_code.find("\\n")
    header = function_code if header_end < 0 else function_code[:header_end]
    local_names = _parameter_names(header)
    local_names.update(_declared_local_names(function_code))

    if not local_names:
        return function_code

    used_names = set(
        match.group(0)
        for match in re.finditer(r"[A-Za-z_][A-Za-z0-9_]*", function_code)
    )
    replacements = {
        name: _new_identifier(used_names)
        for name in sorted(local_names)
        if _IDENTIFIER_RE.match(name)
    }

    if not replacements:
        return function_code

    output: list[str] = []
    previous_significant = ""
    tokens = list(_TOKEN_RE.finditer(function_code))

    for index, token in enumerate(tokens):
        value = token.group(0)

        if token.lastgroup != "identifier" or value not in replacements:
            output.append(value)
            if token.lastgroup not in ("string", "comment") and not value.isspace():
                previous_significant = value
            continue

        next_significant = ""
        for following in tokens[index + 1:]:
            if following.lastgroup in ("string", "comment"):
                break
            if not following.group(0).isspace():
                next_significant = following.group(0)
                break

        is_member = previous_significant == "."
        is_dictionary_key = (
            next_significant == ":"
            and previous_significant not in ("var", "const", "for", "(", ",")
        )
        is_named_argument = (
            next_significant == "=" and previous_significant in ("(", ",")
        )

        if is_member or is_dictionary_key or is_named_argument:
            output.append(value)
        else:
            output.append(replacements[value])

        previous_significant = output[-1]

    return "".join(output)


def obfuscate(code: str) -> str:
    """Обфусцирует локальные переменные и параметры, сохраняя структуру GDScript."""
    if not isinstance(code, str):
        raise TypeError("code должен иметь тип str")

    ranges = _function_ranges(code)
    if not ranges:
        return code

    result: list[str] = []
    cursor = 0

    for start, end, _, _ in ranges:
        if start < cursor:
            continue

        result.append(code[cursor:start])
        result.append(_obfuscate_function(code[start:end]))
        cursor = end

    result.append(code[cursor:])
    return "".join(result)


def main() -> int:
    """Обрабатывает файл через CLI для синхронного вызова из экспортного плагина."""
    parser = argparse.ArgumentParser(description="GDScript local identifier obfuscator")
    parser.add_argument("--input", required=True, help="Путь к исходному GDScript-файлу")
    parser.add_argument("--output", required=True, help="Путь к обработанному файлу")
    arguments = parser.parse_args()

    source_path = Path(arguments.input)
    output_path = Path(arguments.output)

    try:
        source_code = source_path.read_text(encoding="utf-8")
        output_path.write_text(obfuscate(source_code), encoding="utf-8", newline="\n")
    except (OSError, UnicodeError, ValueError, TypeError) as error:
        parser.exit(1, f"obfuscate: {error}\\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
