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
            private_api_hits=0,
            jailbreak_hits=0,
            dynamic_code_hits=1,
            ats_risk_hits=0,
            private_framework_hits=0,
            review_risk_score=3.0,
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
            private_api_hits=0,
            jailbreak_hits=0,
            dynamic_code_hits=1,
            ats_risk_hits=0,
            private_framework_hits=0,
            review_risk_score=3.0,
        )

        # Should not raise ValueError for integer-format rows.
        cmp.print_report(before, after)


class TestReviewRisk(unittest.TestCase):
    def test_review_risk_score_weighted(self):
        score = cmp.score_review_risk(
            private_api_hits=2,
            jailbreak_hits=1,
            dynamic_code_hits=3,
            ats_risk_hits=0,
            private_framework_hits=1,
        )
        self.assertEqual(score, 29)


if __name__ == "__main__":
    unittest.main()
