from datetime import date
import unittest

from src.data_generation.config import SCALE_TARGETS, Settings


class SettingsTests(unittest.TestCase):
    def test_profiles_share_required_targets(self) -> None:
        required = {"employees", "suppliers", "products", "customers", "sales", "leads"}
        self.assertEqual(set(SCALE_TARGETS["small"]), required)
        self.assertEqual(set(SCALE_TARGETS["full"]), required)

    def test_invalid_date_range_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            Settings(start_date=date(2026, 1, 1), end_date=date(2020, 1, 1), scale="small")


if __name__ == "__main__":
    unittest.main()
