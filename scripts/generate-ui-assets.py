"""Generate original white, antialiased corner masks; no external dependencies."""
import pathlib
import struct
import zlib
import math


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def corner_png(size, right=False, bottom=False, cutout=False):
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
            alpha = round(255 * hits / 16)
            rows.extend((255, 255, 255, 255 - alpha if cutout else alpha))
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))


def icon_png(kind, size=48):
    def ink(x, y):
        def rect(l, t, r, b):
            return l <= x <= r and t <= y <= b
        def ellipse(cx, cy, rx, ry):
            return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1
        def polygon(points):
            inside = False
            j = len(points) - 1
            for i, (px, py) in enumerate(points):
                qx, qy = points[j]
                if (py > y) != (qy > y) and x < (qx - px) * (y - py) / (qy - py) + px:
                    inside = not inside
                j = i
            return inside
        if kind in ('avatar-person', 'avatar-child'):
            scale = .85 if kind == 'avatar-child' else 1
            return ellipse(.5, .29, .14 * scale, .14 * scale) or (y >= .5 and ellipse(.5, .76, .29 * scale, .27))
        if kind == 'avatar-face':
            ring = .31 <= math.hypot(x - .5, y - .5) <= .37
            eyes = ellipse(.38, .43, .035, .045) or ellipse(.62, .43, .035, .045)
            smile = y > .53 and .15 <= math.hypot(x - .5, y - .5) <= .20
            return ring or eyes or smile
        if kind == 'avatar-paw':
            return ellipse(.5, .65, .22, .16) or any(ellipse(cx, cy, .075, .105) for cx, cy in [(.25, .43), (.4, .27), (.6, .27), (.75, .43)])
        if kind == 'avatar-cat':
            head = ellipse(.5, .57, .31, .26)
            ears = polygon([(.2, .51), (.2, .17), (.43, .35)]) or polygon([(.57, .35), (.8, .17), (.8, .51)])
            eyes = ellipse(.38, .52, .035, .05) or ellipse(.62, .52, .035, .05)
            return (head or ears) and not eyes
        if kind == 'avatar-fish':
            return (ellipse(.43, .5, .29, .2) or polygon([(.65, .5), (.88, .27), (.88, .73)])) and not ellipse(.29, .46, .03, .03)
        if kind == 'avatar-star':
            points = [(.5 + (.38 if i % 2 == 0 else .17) * math.cos(-math.pi / 2 + i * math.pi / 5),
                       .5 + (.38 if i % 2 == 0 else .17) * math.sin(-math.pi / 2 + i * math.pi / 5)) for i in range(10)]
            return polygon(points)
        if kind == 'avatar-rocket':
            body = ellipse(.5, .42, .16, .31) and not ellipse(.5, .36, .065, .065)
            fins = polygon([(.36, .48), (.22, .76), (.39, .68)]) or polygon([(.64, .48), (.78, .76), (.61, .68)])
            return body or fins or polygon([(.42, .75), (.58, .75), (.5, .92)])
        if kind == 'avatar-music':
            return rect(.36, .22, .42, .71) or rect(.7, .15, .76, .64) or polygon([(.36, .22), (.76, .15), (.76, .29), (.36, .36)]) or ellipse(.29, .73, .13, .09) or ellipse(.63, .66, .13, .09)
        if kind == 'avatar-soccer':
            ring = .31 <= math.hypot(x - .5, y - .5) <= .37
            center = polygon([(.5 + .13 * math.cos(-math.pi / 2 + i * 2 * math.pi / 5), .5 + .13 * math.sin(-math.pi / 2 + i * 2 * math.pi / 5)) for i in range(5)])
            seams = math.hypot(x - .5, y - .5) < .34 and abs(math.sin((math.atan2(y - .5, x - .5) + math.pi / 2) * 2.5)) < .14
            return ring or center or seams
        if kind == 'avatar-gamepad':
            body = (rect(.29, .3, .71, .7) or ellipse(.29, .54, .17, .24) or ellipse(.71, .54, .17, .24))
            controls = rect(.25, .43, .31, .65) or rect(.18, .51, .38, .57) or ellipse(.7, .46, .04, .04) or ellipse(.78, .57, .04, .04)
            return body and not controls
        if kind == 'avatar-movie':
            return (rect(.16, .2, .84, .8) and not rect(.25, .29, .75, .71)) or rect(.16, .43, .84, .5)
        if kind == 'live':
            return ((rect(.12, .2, .88, .72) and not rect(.19, .27, .81, .65))
                    or rect(.44, .72, .56, .82) or rect(.3, .82, .7, .88))
        if kind in ('vod', 'movie', 'series'):
            return ((rect(.16, .13, .84, .87) and not rect(.25, .22, .75, .78))
                    or rect(.16, .43, .84, .5))
        if kind in ('settings', 'options'):
            d = math.hypot(x - .5, y - .5)
            return .18 <= d <= .32 or (.29 <= d <= .42 and abs(math.sin(math.atan2(y - .5, x - .5) * 4)) > .65)
        if kind == 'buffering':
            angle = math.atan2(y - .5, x - .5)
            return .26 <= math.hypot(x - .5, y - .5) <= .4 and -1.9 < angle < 2.9
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


def pill_png(width=900, height=64, radius=None):
    rows = bytearray()
    r = height / 2 if radius is None else radius
    for y in range(height):
        rows.append(0)
        for x in range(width):
            hits = 0
            for sy in range(4):
                for sx in range(4):
                    px, py = x + (sx + .5) / 4, y + (sy + .5) / 4
                    cx = max(r, min(width - r, px))
                    cy = max(r, min(height - r, py))
                    hits += (px - cx) ** 2 + (py - cy) ** 2 <= r ** 2
            rows.extend((255, 255, 255, round(255 * hits / 16)))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b'')


def cap_png(right=False, radius=128):
    """Full-height semicircle; never split/stretched into corner quadrants."""
    rows = bytearray()
    for y in range(radius * 2):
        rows.append(0)
        for x in range(radius):
            hits = 0
            for sy in range(4):
                for sx in range(4):
                    px = x + (sx + .5) / 4
                    if right:
                        px = radius - px
                    py = y + (sy + .5) / 4
                    hits += (px - radius) ** 2 + (py - radius) ** 2 <= radius ** 2
            rows.extend((255, 255, 255, round(255 * hits / 16)))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', radius, radius * 2, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b'')


def pill_patch_png(height):
    """One textured pill; stretch only the center, never the circular caps."""
    width = height + 2
    radius = height / 2
    rows = bytearray()
    for y in range(height + 2):
        rows.append(0)
        for x in range(width + 2):
            if x == 0 or y == 0 or x == width + 1 or y == height + 1:
                stretch = (y == 0 and x == int(radius) + 1) or (x == 0 and y == int(radius) + 1)
                rows.extend((0, 0, 0, 255 if stretch else 0))
            else:
                hits = 0
                for sy in range(4):
                    for sx in range(4):
                        px, py = x - 1 + (sx + .5) / 4, y - 1 + (sy + .5) / 4
                        cx = max(radius, min(width - radius, px))
                        hits += (px - cx) ** 2 + (py - radius) ** 2 <= radius ** 2
                rows.extend((255, 255, 255, round(255 * hits / 16)))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width + 2, height + 2, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b'')


def transparent_icon_png(size=28):
    # LabelList places item text after its icon. A transparent fixed-width icon
    # creates real text padding without adding spaces to spoken ContentNode text.
    rows = (b'\x00' + b'\xff\xff\xff\x00' * size) * size
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


if __name__ == '__main__':
    root = pathlib.Path(__file__).resolve().parent.parent / 'images'
    for height in range(20, 129, 2):
        (root / f'ui-pill-h{height}.9.png').write_bytes(pill_patch_png(height))
    for side in ['left', 'right']:
        (root / f'ui-cap-{side}.png').write_bytes(cap_png(side == 'right'))
    for name, right, bottom in [('tl', False, False), ('tr', True, False), ('bl', False, True), ('br', True, True)]:
        (root / f'ui-corner-{name}.png').write_bytes(corner_png(64, right, bottom))
        (root / f'ui-cutout-{name}.png').write_bytes(corner_png(64, right, bottom, cutout=True))
    print('Generated four reusable 64px UI corner masks.')
    for name in ['live', 'vod', 'settings', 'movie', 'series', 'continue', 'watchlist', 'hidden', 'categories', 'play', 'pause', 'channels', 'recent', 'minimize', 'options', 'stop', 'buffering']:
        (root / f'ui-icon-{name}.png').write_bytes(icon_png(name))
    print('Generated original navigation and transport glyphs.')
    for name in ['person', 'face', 'child', 'paw', 'cat', 'fish', 'star', 'rocket', 'music', 'soccer', 'gamepad', 'movie']:
        (root / f'profile-avatar-{name}.png').write_bytes(icon_png('avatar-' + name, 96))
    (root / 'ui-focus-pill.png').write_bytes(pill_png())
    (root / 'ui-focus-row.png').write_bytes(pill_png(1204, 68, 14))
    (root / 'ui-settings-rail.png').write_bytes(pill_png(408, 78, 12))
    (root / 'ui-list-inset.png').write_bytes(transparent_icon_png())
