def pretty_print(data, indent=0, max_length=150, ignore_keys=None):
    """
    Рекурсивно форматирует словари и списки.

    Короткие списки выводятся в одну строку, длинные — развёрнуто.

    Args:
        data: Словарь, список или другое значение.
        indent: Текущий уровень отступа.
        max_length: Максимальная длина компактного представления.
        ignore_keys: Ключи словаря, которые нужно игнорировать.

    Returns:
        str: Отформатированное представление данных.
    """
    if ignore_keys is None:
        ignore_keys = {"icon_data", "icon"}

    lines = []

    def format_value(value, indent):
        prefix = " " * indent

        if isinstance(value, dict):
            items = [
                (key, val)
                for key, val in value.items()
                if key not in ignore_keys
            ]

            if not items:
                lines.append(f"{prefix}{{}}")
                return

            lines.append(f"{prefix}{{")

            for key, val in items:
                if isinstance(val, (dict, list)):
                    lines.append(f"{' ' * (indent + 4)}{key!r}:")
                    format_value(val, indent + 4)
                else:
                    lines.append(f"{' ' * (indent + 4)}{key!r}: {val!r}")

            lines.append(f"{prefix}}}")

        elif isinstance(value, list):
            if len(repr(value)) <= max_length:
                lines.append(f"{prefix}{value!r}")
                return

            if not value:
                lines.append(f"{prefix}[]")
                return

            lines.append(f"{prefix}[")

            for item in value:
                format_value(item, indent + 4)

            lines.append(f"{prefix}]")

        else:
            lines.append(f"{prefix}{value!r}")

    format_value(data, indent)
    
    print("\n".join(lines))
    return "\n".join(lines)
