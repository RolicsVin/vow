import re


def drive_direct_url(share_url: str) -> str:
    """Превращает ссылку .../file/d/<ID>/view в прямую ссылку на скачивание."""
    match = (re.search(r"/d/([\w-]+)", share_url)
             or re.search(r"[?&]id=([\w-]+)", share_url))
    if not match:
        raise ValueError(f"Не удалось найти ID файла в ссылке: {share_url}")
    return ("https://drive.usercontent.google.com/download"
            f"?id={match.group(1)}&export=download&confirm=t")
