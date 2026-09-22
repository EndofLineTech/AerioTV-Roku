"""Generate original white, antialiased corner masks; no external dependencies."""
import pathlib
import struct
import zlib
import math


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


def icon_png(kind, size=48):
    def ink(x, y):
        def rect(l, t, r, b):
            return l <= x <= r and t <= y <= b
        if kind == 'live':
            return ((rect(.12, .2, .88, .72) and not rect(.19, .27, .81, .65))
                    or rect(.44, .72, .56, .82) or rect(.3, .82, .7, .88))
        if kind in ('vod', 'movie', 'series'):
            return ((rect(.16, .13, .84, .87) and not rect(.25, .22, .75, .78))
                    or rect(.16, .43, .84, .5))
        if kind in ('settings', 'options'):
            d = math.hypot(x - .5, y - .5)
            return .18 <= d <= .32 or (.29 <= d <= .42 and abs(math.sin(math.atan2(y - .5, x - .5) * 4)) > .65)
        if kind in ('play', 'continue'):
            return .3 <= x <= .78 and abs(y - .5) <= (.78 - x) * .7
        if kind == 'pause':
            return rect(.25, .2, .41, .8) or rect(.59, .2, .75, .8)
        if kind == 'stop':
            return rect(.24, .24, .76, .76)
        if kind in ('recent', 'watchlist'):
            d = math.hypot(x - .5, y - .5)
            return .31 <= d <= .38 or rect(.47, .27, .53, .53) or rect(.5, .47, .7, .53)
        if kind == 'minimize':
            return (rect(.1, .18, .9, .82) and not rect(.16, .24, .84, .76)) or rect(.55, .5, .8, .72)
        if kind == 'hidden':
            return abs(y - x) < .05 and .2 < x < .8
        return any(rect(.18, t, .82, t + .08) for t in [.22, .46, .7])
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            hits = sum(ink((x + (sx + .5) / 4) / size, (y + (sy + .5) / 4) / size) for sy in range(4) for sx in range(4))
            rows.extend((255, 255, 255, round(255 * hits / 16)))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b'')


if __name__ == '__main__':
    root = pathlib.Path(__file__).resolve().parent.parent / 'images'
    for name, right, bottom in [('tl', False, False), ('tr', True, False), ('bl', False, True), ('br', True, True)]:
        (root / f'ui-corner-{name}.png').write_bytes(corner_png(64, right, bottom))
    print('Generated four reusable 64px UI corner masks.')
    for name in ['live', 'vod', 'settings', 'movie', 'series', 'continue', 'watchlist', 'hidden', 'categories', 'play', 'pause', 'channels', 'recent', 'minimize', 'options', 'stop']:
        (root / f'ui-icon-{name}.png').write_bytes(icon_png(name))
    print('Generated original navigation and transport glyphs.')
