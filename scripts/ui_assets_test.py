"""Dependency-free checks for the single-texture pill's nine-patch contract."""
import importlib.util
from pathlib import Path
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('ui_assets', ROOT / 'scripts/generate-ui-assets.py')
ASSETS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ASSETS)


class PillPatchTest(unittest.TestCase):
    def test_packaged_masks_match_generator_and_stretch_only_the_center(self):
        for height in range(20, 129, 2):
            with self.subTest(height=height):
                data = (ROOT / f'images/ui-pill-h{height}.9.png').read_bytes()
                self.assertEqual(data, ASSETS.pill_patch_png(height))
                width, rows = struct.unpack('>II', data[16:24])
                self.assertEqual((width, rows), (height + 4, height + 2))
                compressed = bytearray()
                offset = 8
                while offset < len(data):
                    size = struct.unpack('>I', data[offset:offset + 4])[0]
                    if data[offset + 4:offset + 8] == b'IDAT':
                        compressed.extend(data[offset + 8:offset + 8 + size])
                    offset += size + 12
                pixels = zlib.decompress(compressed)
                stride = 1 + width * 4

                def pixel(x, y):
                    start = y * stride + 1 + x * 4
                    return tuple(pixels[start:start + 4])

                center = height // 2 + 1
                self.assertEqual([x for x in range(width) if pixel(x, 0)[3]], [center])
                self.assertEqual([y for y in range(rows) if pixel(0, y)[3]], [center])
                self.assertEqual(pixel(center, 0), (0, 0, 0, 255))
                self.assertEqual(pixel(1, 1)[3], 0, 'outer corners remain transparent')
                self.assertEqual(pixel(center, center), (255, 255, 255, 255))
                self.assertTrue(all(pixel(x, rows - 1)[3] == 0 for x in range(width)))
                self.assertTrue(all(pixel(width - 1, y)[3] == 0 for y in range(rows)))


if __name__ == '__main__':
    unittest.main()
