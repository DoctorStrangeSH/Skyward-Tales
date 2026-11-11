#!/usr/bin/env python3
"""Check actual PE icon resources against the stock Godot template.

The exporter may re-encode the ICO. Compare RT_ICON resources, excluding
version metadata and the copy of assets/icon.ico inside the appended PCK.
"""
import mmap
import struct
import sys


def icons(executable):
    with open(executable, 'rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        if data[:2] != b'MZ':
            raise ValueError('Not a Windows executable')
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[pe:pe + 4] != b'PE\0\0':
            raise ValueError('Missing PE header')
        count = struct.unpack_from('<H', data, pe + 6)[0]
        optional_size = struct.unpack_from('<H', data, pe + 20)[0]
        optional = pe + 24
        magic = struct.unpack_from('<H', data, optional)[0]
        if magic not in (0x10b, 0x20b):
            raise ValueError('Unknown PE optional header')
        directory = optional + (112 if magic == 0x20b else 96)
        resource_rva = struct.unpack_from('<I', data, directory + 16)[0]
        table = optional + optional_size
        sections = []
        for index in range(count):
            virtual_size, address, raw_size, offset = struct.unpack_from('<IIII', data, table + index * 40 + 8)
            sections.append((address, max(virtual_size, raw_size), offset))

        def at(rva):
            for address, size, offset in sections:
                if address <= rva < address + size:
                    return offset + rva - address
            raise ValueError('Resource RVA is outside PE sections')

        base = at(resource_rva)
        found = {3: [], 14: []}

        def entries(relative):
            named, numbered = struct.unpack_from('<HH', data, base + relative + 12)
            return [struct.unpack_from('<II', data, base + relative + 16 + i * 8) for i in range(named + numbered)]

        def visit(pointer, kind, depth=0):
            if depth > 8:
                raise ValueError('Invalid resource directory depth')
            if pointer & 0x80000000:
                for _, child in entries(pointer & 0x7fffffff):
                    visit(child, kind, depth + 1)
            else:
                rva, size = struct.unpack_from('<II', data, base + pointer)
                offset = at(rva)
                blob = data[offset:offset + size]
                if not size or len(blob) != size:
                    raise ValueError('Truncated icon resource')
                found[kind].append(blob)

        for kind, pointer in entries(0):
            if kind in found:
                visit(pointer, kind)
        if not found[3] or not found[14]:
            raise ValueError('Missing RT_ICON or RT_GROUP_ICON resources')
        return tuple(sorted(found[3]))


def verify(executable, stock):
    game_icons = icons(executable)
    if game_icons == icons(stock):
        raise ValueError('The executable still has the stock Godot icon')
    return len(game_icons)


if __name__ == '__main__':
    try:
        count = verify(sys.argv[1], sys.argv[2])
        print(f'WINDOWS ICON OK: {count} icon resources differ from the stock template')
    except (ValueError, OSError, struct.error, IndexError) as error:
        print(f'WINDOWS ICON FAILED: {error}', file=sys.stderr)
        sys.exit(1)
