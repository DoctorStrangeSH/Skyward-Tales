#!/usr/bin/env python3
"""Check the source ICO payloads inside the PE resource section, not its PCK.

Godot embeds the ICO images unchanged. Looking through the whole executable
would also find the copy of assets/icon.ico shipped in the game pack.
"""
import mmap
import struct
import sys
from pathlib import Path


def ico_images(data):
    reserved, kind, count = struct.unpack_from('<HHH', data)
    if reserved != 0 or kind != 1 or count == 0:
        raise ValueError('Invalid source ICO')
    images = []
    for index in range(count):
        size, offset = struct.unpack_from('<II', data, 6 + index * 16 + 8)
        image = data[offset:offset + size]
        if not size or len(image) != size:
            raise ValueError('Truncated source ICO')
        images.append(image)
    return images


def verify(executable, icon):
    images = ico_images(Path(icon).read_bytes())
    with open(executable, 'rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        if data[:2] != b'MZ':
            raise ValueError('Not a Windows executable')
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[pe:pe + 4] != b'PE\0\0':
            raise ValueError('Missing PE header')
        count = struct.unpack_from('<H', data, pe + 6)[0]
        optional_size = struct.unpack_from('<H', data, pe + 20)[0]
        table = pe + 24 + optional_size
        for index in range(count):
            entry = table + index * 40
            if data[entry:entry + 8].rstrip(b'\0') != b'.rsrc':
                continue
            size, offset = struct.unpack_from('<II', data, entry + 16)
            resources = data[offset:offset + size]
            if len(resources) != size or not all(image in resources for image in images):
                raise ValueError('The PE resources do not contain the game icon')
            return len(images)
        raise ValueError('Missing PE resource section')


if __name__ == '__main__':
    try:
        count = verify(sys.argv[1], sys.argv[2])
        print(f'WINDOWS ICON OK: {count} source ICO images embedded in PE resources')
    except (ValueError, OSError, struct.error, IndexError) as error:
        print(f'WINDOWS ICON FAILED: {error}', file=sys.stderr)
        sys.exit(1)
