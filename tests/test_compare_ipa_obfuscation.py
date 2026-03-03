import unittest

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


if __name__ == "__main__":
    unittest.main()
