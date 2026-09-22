"""Generate original white, antialiased corner masks; no external dependencies."""
import pathlib
import struct
import zlib


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def corner_png(size, right=False, bottom=False):
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            hits = 0
            for sy in range(4):
                for sx in range(4):
                    px = x + (sx + .5) / 4
                    py = y + (sy + .5) / 4
                    if right:
                        px = size - px
                    if bottom:
                        py = size - py
                    hits += (px - size) ** 2 + (py - size) ** 2 <= size ** 2
            rows.extend((255, 255, 255, round(255 * hits / 16)))
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))


if __name__ == '__main__':
    root = pathlib.Path(__file__).resolve().parent.parent / 'images'
    for name, right, bottom in [('tl', False, False), ('tr', True, False), ('bl', False, True), ('br', True, True)]:
        (root / f'ui-corner-{name}.png').write_bytes(corner_png(64, right, bottom))
    print('Generated four reusable 64px UI corner masks.')
