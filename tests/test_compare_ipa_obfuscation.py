import unittest
from pathlib import Path

import compare_ipa_obfuscation as cmp


class TestHeuristics(unittest.TestCase):
    def test_readable_identifier(self):
        self.assertTrue(cmp.looks_readable("getUserProfile"))
        self.assertFalse(cmp.looks_readable("a8f9c2"))

    def test_randomish_identifier(self):
        self.assertTrue(cmp.looks_randomish("xqtrnzvpkm"))
        self.assertFalse(cmp.looks_randomish("userProfile"))

    def test_entropy_monotonicity(self):
        low = cmp.token_entropy("aaaaaaa")
        high = cmp.token_entropy("abcdefg")
        self.assertGreater(high, low)


class TestReportFormatting(unittest.TestCase):
    def test_print_report_with_integer_row_format(self):
        before = cmp.IpaMetrics(
            ipa_path=Path("before.ipa"),
            macho_files=1,
            identifiers_total=10,
            identifiers_unique=8,
            readable_count=5,
            randomish_count=2,
            mean_len=7.1,
            entropy_mean=2.6,
            obfuscation_score=45.0,
        )
        after = cmp.IpaMetrics(
            ipa_path=Path("after.ipa"),
            macho_files=2,
            identifiers_total=12,
            identifiers_unique=9,
            readable_count=4,
            randomish_count=4,
            mean_len=7.6,
            entropy_mean=2.9,
            obfuscation_score=55.0,
        )

        # Should not raise ValueError for integer-format rows.
        cmp.print_report(before, after)


if __name__ == "__main__":
    unittest.main()
