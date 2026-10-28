import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "cheats"))
import grouped_chtbin as v2


class GroupedBinaryTests(unittest.TestCase):
    def test_round_trip_multiple_entries_per_group(self):
        rows = [v2.GroupedEntry(0x1234, 0), v2.GroupedEntry(0x5678, 0),
                v2.GroupedEntry(0x9abc, 1)]
        blob = v2.pack(rows, 2)
        self.assertEqual(blob[:4], b"GBAC")
        self.assertEqual(blob[4], 2)
        self.assertEqual(v2.unpack(blob), (rows, 2))
        self.assertEqual(len(blob), 64)

    def test_empty(self):
        self.assertEqual(v2.unpack(v2.pack([], 0)), ([], 0))

    def test_reject_reserved_bits(self):
        with self.assertRaises(ValueError):
            v2.pack([v2.GroupedEntry(1 << 105, 0)], 1)

    def test_reject_out_of_range_group(self):
        with self.assertRaises(ValueError):
            v2.pack([v2.GroupedEntry(1, 2)], 2)

    def test_reject_reordered_groups(self):
        with self.assertRaises(ValueError):
            v2.pack([v2.GroupedEntry(1, 1), v2.GroupedEntry(2, 0)], 2)

    def test_reject_truncation(self):
        with self.assertRaises(ValueError):
            v2.unpack(v2.pack([v2.GroupedEntry(1, 0)], 1)[:-1])

    def test_legacy_v1_rejected_by_v2_codec(self):
        with self.assertRaises(ValueError):
            v2.unpack(b"GBAC" + bytes((1, 0)) + bytes(10))


if __name__ == "__main__":
    unittest.main()
