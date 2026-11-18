"""Модуль безопасной обфускации локальных идентификаторов GDScript."""

from __future__ import annotations

import argparse
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


def _new_identifier(used_names: set[str]) -> str:
    """Создаёт уникальное имя, не совпадающее с исходными идентификаторами."""
    while True:
        candidate: str = "_v_" + secrets.token_hex(4)
        if candidate not in used_names:
            used_names.add(candidate)
            return candidate


def _obfuscate_function(function_code: str) -> str:
    """Переименовывает только локальные идентификаторы одной функции."""
    local_names: set[str] = _parameter_names(function_code)
    local_names: set[str] = _parameter_names(header)
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
    tokens = list(_TOKEN_RE.finditer(function_code))

    for index, token in enumerate(tokens):
        value: str = token.group(0)

        if token.lastgroup != "identifier" or value not in replacements:
            output.append(value)
            if token.lastgroup not in ("string", "comment") and not value.isspace():
                previous_significant = value
            continue

        next_significant: str = ""
        for following in tokens[index + 1:]:
            if following.lastgroup in ("string", "comment"):
                break
            if not following.group(0).isspace():
                next_significant = following.group(0)
                break

        is_member: bool = previous_significant == "."
        is_dictionary_key: bool = (
            next_significant == ":"
            and previous_significant == ":"
        )
        is_named_argument: bool = (
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


def main() -> int:
    """Обрабатывает файл через CLI для синхронного вызова из экспортного плагина."""
    parser = argparse.ArgumentParser(description="GDScript local identifier obfuscator")
    parser.add_argument("--input", required=True, help="Путь к исходному GDScript-файлу")
    parser.add_argument("--output", required=True, help="Путь к обработанному файлу")
    arguments = parser.parse_args()

    source_path: Path = Path(arguments.input)
    output_path: Path = Path(arguments.output)

    try:
        source_code: str = source_path.read_text(encoding="utf-8")
        output_path.write_text(obfuscate(source_code), encoding="utf-8", newline="\n")
    except (OSError, UnicodeError, ValueError, TypeError) as error:
        parser.exit(1, f"obfuscate: {error}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
