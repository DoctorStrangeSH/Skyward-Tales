"""Compact JSON formatting: numeric arrays stay on one line."""
import json
import re

_NUM_ARRAY = re.compile(r"\[\s*(-?[\d.]+(?:\s*,\s*-?[\d.]+)*)\s*\]")


def dumps(data) -> str:
    text = json.dumps(data, ensure_ascii=False, indent=2)
    collapse = lambda m: "[" + ", ".join(p.strip() for p in m.group(1).split(",")) + "]"
    previous = None
    while previous != text:
        previous = text
        text = _NUM_ARRAY.sub(collapse, text)
    return text + "\n"


if __name__ == "__main__":
    import pathlib
    import sys
    for name in sys.argv[1:]:
        path = pathlib.Path(name)
        path.write_text(dumps(json.loads(path.read_text())))
