import json
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "cheats"))
from profile2cht import convert
import gbacht
import cht2bin

def profile():
    return {"schema_version": 1, "game": {"name": "Example"},
            "cheats": [{"id": "hp", "name": "Health", "format": "codebreaker-raw",
                        "codes": ["3200E924 0096"], "enabled": True}]}

class ProfileTests(unittest.TestCase):
    def test_output(self):
        result = convert(profile()).decode()
        self.assertIn('cheat0_code = "3200E924+0096"', result)
        self.assertIn("cheat0_enable = true", result)
    def test_parser_round_trip(self):
        p = profile()
        data = convert(p)
        groups, stats = gbacht.parse(data)
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0].desc, "Health")
        self.assertEqual(len(groups[0].entries), 1)
        self.assertEqual(groups[0].entries[0].address, 0x0200E924)
        self.assertEqual(groups[0].entries[0].value, 0x96)
        self.assertEqual(groups[0].entries[0].bytemask, 1)
        packed = cht2bin.convert(data)
        self.assertEqual(cht2bin.unpack(packed.blob), gbacht.words(groups))

    def test_disabled_not_loaded(self):
        p = profile()
        p["cheats"][0]["enabled"] = False
        groups, _ = gbacht.parse(convert(p))
        self.assertEqual(groups, [])

    def test_reject_encrypted(self):
        p = profile()
        p["cheats"][0]["format"] = "gameshark-v3-encrypted"
        with self.assertRaises(ValueError):
            convert(p)
    def test_duplicate_ids(self):
        p = profile()
        p["cheats"].append(dict(p["cheats"][0]))
        with self.assertRaises(ValueError):
            convert(p)
    def test_invalid_hex(self):
        p = profile()
        p["cheats"][0]["codes"] = ["3200E924 ZZZZ"]
        with self.assertRaises(ValueError):
            convert(p)

if __name__ == "__main__":
    unittest.main()
