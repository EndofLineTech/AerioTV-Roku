import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "measure_roku_resources", Path(__file__).with_name("measure_roku_resources.py")
)
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)


class RokuResourceTests(unittest.TestCase):
    def test_parses_dev_memory_without_process_or_identity_fields(self):
        result = metrics.parse_chanperf("""
            <chanperf><plugin><id>dev</id><memory>
              <used>87785472</used><res>87000000</res><swap>785472</swap>
              <anon>24027136</anon><file>24727552</file><shared>39030784</shared>
              <limit>513802240</limit>
            </memory><unsecured><process-id>secret</process-id></unsecured>
            </plugin><status>OK</status></chanperf>
        """)
        self.assertEqual(result, {
            "used_bytes": 87785472, "resident_bytes": 87000000,
            "swap_bytes": 785472, "anonymous_bytes": 24027136,
            "file_bytes": 24727552, "shared_bytes": 39030784,
            "memory_limit_bytes": 513802240,
        })

    def test_aggregates_graphics_instances_without_exposing_bitmap_names(self):
        result = metrics.parse_graphics("""
            <r2d2-bitmaps><graphics-instances>
              <rographics><texture-memory><used>0</used><max>100000000</max></texture-memory></rographics>
              <rographics><sytem-memory><used>4096</used></sytem-memory>
                <texture-memory><used>27000000</used><max>100000000</max></texture-memory>
                <bitmap><name>https://private.example/token=secret</name></bitmap>
              </rographics>
            </graphics-instances><status>OK</status></r2d2-bitmaps>
        """)
        self.assertEqual(result, {
            "texture_bytes": 27000000, "texture_limit_bytes": 100000000,
            "graphics_system_bytes": 4096, "bitmap_count": 1,
            "graphics_instances": 2, "peak_instance_texture_bytes": 27000000,
        })
        self.assertNotIn("secret", str(result))

    def test_rejects_unavailable_or_incomplete_metrics_without_fabricating_zero(self):
        for parser, payload in (
            (metrics.parse_chanperf, "<chanperf><status>FAILED</status></chanperf>"),
            (metrics.parse_graphics, "<r2d2-bitmaps><status>FAILED</status></r2d2-bitmaps>"),
            (metrics.parse_graphics, "<r2d2-bitmaps><status>OK</status></r2d2-bitmaps>"),
        ):
            with self.subTest(parser=parser.__name__, payload=payload):
                with self.assertRaises(ValueError):
                    parser(payload)


if __name__ == "__main__":
    unittest.main()
