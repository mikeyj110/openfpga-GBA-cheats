import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "cheats"))
import cht2bin
import grouped_chtbin


class ConverterVersionTests(unittest.TestCase):
    SOURCE = (b'cheats = 2\n'
              b'cheat0_desc = "First"\n'
              b'cheat0_code = "32000010+0001"\n'
              b'cheat0_enable = true\n'
              b'cheat1_desc = "Second"\n'
              b'cheat1_code = "32000020+0002"\n'
              b'cheat1_enable = true\n')

    def test_default_remains_v1(self):
        result = cht2bin.convert(self.SOURCE)
        self.assertEqual(result.blob[4], 1)
        self.assertEqual(cht2bin.unpack(result.blob), cht2bin.unpack(
            cht2bin.convert(self.SOURCE, format_version=1).blob))

    def test_v2_group_identity_and_operation_equivalence(self):
        legacy = cht2bin.convert(self.SOURCE)
        modern = cht2bin.convert(self.SOURCE, format_version=2)
        entries, groups = grouped_chtbin.unpack(modern.blob)
        self.assertEqual(groups, 2)
        self.assertEqual([e.group_id for e in entries], [0, 1])
        self.assertEqual([e.word for e in entries], cht2bin.unpack(legacy.blob))

    def test_unknown_format_rejected(self):
        with self.assertRaises(ValueError):
            cht2bin.convert(self.SOURCE, format_version=3)


if __name__ == "__main__":
    unittest.main()
