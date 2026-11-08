"""Moves functions out of scripts/main.gd into a helper module (tech debt:
main.gd grew past 2500 lines). The moved bodies get `game.` before every
SkywardGame member they use; main.gd keeps a one-line wrapper with the
same signature, so callers (other scripts, tests) see no change.

    python3 tools/extract_module.py <ClassName> <res-path> <func> [<func> ...]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "scripts" / "main.gd"

NODE_METHODS = {
    "add_child", "remove_child", "get_children", "get_child_count", "get_tree", "get_viewport", "get_node",
    "has_node", "get_parent", "create_tween", "get_world_2d", "to_local", "to_global", "set_process",
    "is_inside_tree", "get_global_mouse_position", "get_viewport_rect", "move_child", "get_node_or_null",
    "has_method", "set_meta", "get_meta", "has_meta", "emit_signal", "queue_redraw", "find_child",
}
TOKEN = re.compile(r'("(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|[A-Za-z_][A-Za-z0-9_]*|.)', re.S)


def members(text: str) -> dict[str, str]:
    """name -> prefix: constants and static functions go through the class."""
    names = {n: "game." for n in NODE_METHODS}
    for m in re.finditer(r"^(?:@onready\s+|@export\s+)?(static\s+)?(var|const|func|signal|enum)\s+([A-Za-z_]\w*)", text, re.M):
        static, kind, name = m.group(1), m.group(2), m.group(3)
        names[name] = "SkywardGame." if (kind in ("const", "enum") or (static and kind == "func")) else "game."
    return names


def split_functions(text: str) -> list[tuple[str, str]]:
    """Top-level chunks: ('func:name', text) or ('other', text). Doc comments
    (##) right above a func travel with it."""
    lines = text.split("\n")
    chunks: list[tuple[str, list[str]]] = []
    current: tuple[str, list[str]] = ("other", [])
    pending_doc: list[str] = []
    for line in lines:
        m = re.match(r"^(?:static\s+)?func\s+([A-Za-z_]\w*)", line)
        top = line and not line[0].isspace()
        if m:
            chunks.append(current)
            current = ("func:" + m.group(1), pending_doc + [line])
            pending_doc = []
        elif top and line.startswith("##") and current[0].startswith("func:"):
            pending_doc.append(line)
        elif top and current[0].startswith("func:"):
            chunks.append(current)
            current = ("other", pending_doc + [line])
            pending_doc = []
        elif top and line.startswith("##"):
            pending_doc.append(line)
        else:
            if pending_doc:
                current[1].extend(pending_doc)
                pending_doc = []
            current[1].append(line)
    if pending_doc:
        current[1].extend(pending_doc)
    chunks.append(current)
    return [(k, "\n".join(v)) for k, v in chunks if v]


def locals_of(func_text: str) -> set[str]:
    names = set()
    header = func_text[func_text.index("func"):]
    m = re.search(r"func\s+\w+\s*\((.*?)\)\s*(->|:)", header, re.S)
    if m:
        for p in m.group(1).split(","):
            p = p.strip()
            if p:
                names.add(re.match(r"[A-Za-z_]\w*", p).group(0))
    for m in re.finditer(r"\bvar\s+([A-Za-z_]\w*)", func_text):
        names.add(m.group(1))
    for m in re.finditer(r"\bfor\s+([A-Za-z_]\w*)\s+in\b", func_text):
        names.add(m.group(1))
    for m in re.finditer(r"\bfunc\s*\(([^)]*)\)", func_text):
        for p in m.group(1).split(","):
            p = p.strip()
            if p:
                names.add(re.match(r"[A-Za-z_]\w*", p).group(0))
    return names


def rewrite(func_text: str, member_names: set[str]) -> str:
    local = locals_of(func_text)
    out = []
    prev_sig = ""  # previous significant token
    for tok in TOKEN.findall(func_text):
        if re.match(r"[A-Za-z_]\w*$", tok):
            if tok == "self" and prev_sig != ".":
                out.append("game")
            elif tok in member_names and tok not in local and prev_sig not in (".", "func"):
                out.append(member_names[tok] + tok)
            else:
                out.append(tok)
            prev_sig = tok
        else:
            out.append(tok)
            if not tok.isspace():
                prev_sig = tok
    return "".join(out)


def wrapper(func_text: str, field: str) -> str:
    lines = func_text.split("\n")
    doc = [l for l in lines if l.startswith("##")]
    header_start = next(i for i, l in enumerate(lines) if re.match(r"^(?:static\s+)?func", l))
    header = lines[header_start]
    j = header_start
    while not header.rstrip().endswith(":"):
        j += 1
        header += " " + lines[j].strip()
    m = re.match(r"^func\s+(\w+)\s*\((.*)\)\s*(->\s*([\w\[\], ]+))?\s*:\s*$", header)
    name, params, ret = m.group(1), m.group(2), (m.group(4) or "").strip()
    args = []
    for p in params.split(","):
        p = p.strip()
        if p:
            args.append(re.match(r"[A-Za-z_]\w*", p).group(0))
    call = "%s.%s(%s)" % (field, name, ", ".join(args))
    body = "\t" + (call if ret == "void" else "return " + call)
    return "\n".join(doc + [header, body]) + "\n"


def main() -> int:
    cls, res_path, field, *funcs = sys.argv[1:]
    text = MAIN.read_text()
    member_names = members(text)
    chunks = split_functions(text)
    found = {k[5:]: t for k, t in chunks if k.startswith("func:") and k[5:] in funcs}
    missing = [f for f in funcs if f not in found]
    if missing:
        print("missing:", missing)
        return 1
    for f in funcs:
        if "await " in found[f]:
            print("coroutines are not moved:", f)
            return 1
        if re.search(r"^static func", found[f], re.M):
            print("static funcs are not moved:", f)
            return 1
    moved = []
    new_main = []
    for kind, chunk in chunks:
        if kind.startswith("func:") and kind[5:] in funcs:
            moved.append(rewrite(chunk.rstrip("\n"), member_names))
            new_main.append(wrapper(chunk.rstrip("\n"), field))
        else:
            new_main.append(chunk)
    MAIN.write_text("\n".join(new_main))
    target = ROOT / res_path.replace("res://", "")
    if target.exists():
        body = target.read_text().rstrip("\n") + "\n\n" + "\n\n".join(moved) + "\n"
    else:
        body = ("extends RefCounted\nclass_name %s\n\n## Split out of main.gd (Этап 18, tech debt). Every SkywardGame member is\n## reached through `game`; main.gd keeps one-line wrappers with the old names.\n\nvar game: SkywardGame\n\nfunc _init(owner_game: SkywardGame) -> void:\n\tgame = owner_game\n\n" % cls) + "\n\n".join(moved) + "\n"
    target.write_text(body)
    print("moved %d functions to %s" % (len(moved), res_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
