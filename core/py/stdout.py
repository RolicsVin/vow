def pretty_print(data, indent=0, max_length=150):
    """
    Рекурсивно выводит словари и списки.

    Если длина компактного представления структуры превышает
    max_length, содержимое выводится в несколько строк.

    Args:
        data: Словарь, список или другое значение.
        indent: Текущий уровень отступа.
        max_length: Максимальная длина строки.
    """
    prefix = " " * indent

    if isinstance(data, dict):
        if not data:
            print("{}")
            return

        print("{")

        for key, value in data.items():
            print(f"{' ' * (indent + 4)}{key!r}: ", end="")

            if isinstance(value, (dict, list)):
                pretty_print(value, indent + 4, max_length)
            else:
                print(repr(value))

        print(f"{prefix}}}")

    elif isinstance(data, list):
        compact = repr(data)

        if len(compact) <= max_length:
            print(compact)
            return

        if not data:
            print("[]")
            return

        print("[")

        for item in data:
            print(f"{' ' * (indent + 4)}", end="")

            if isinstance(item, (dict, list)):
                pretty_print(item, indent + 4, max_length)
            else:
                print(repr(item))

        print(f"{prefix}]")

    else:
        print(repr(data))
