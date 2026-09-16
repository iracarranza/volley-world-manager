import tempfile
import unittest
from pathlib import Path

from tools.audit_shadow_economic_inputs import REQUIRED_DOCUMENTS, SEEDS, inventory


class ShadowEconomicInputAuditTest(unittest.TestCase):
    def test_missing_inputs_are_not_promoted_to_measurements(self):
        with tempfile.TemporaryDirectory() as directory:
            result = inventory(Path(directory))
        self.assertFalse(result["measurement_ready"])
        self.assertEqual(result["blocking_inputs"]["missing_documents"], list(REQUIRED_DOCUMENTS))
        self.assertEqual(result["blocking_inputs"]["missing_seed_records"], list(SEEDS))
        self.assertTrue(all(not item["observable"] for item in result["capability_keyword_inventory"].values()))

    def test_complete_minimal_evidence_is_discovered_deterministically(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in REQUIRED_DOCUMENTS:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("authority\n")
            evidence = root / "seed-analysis.json"
            evidence.write_text(
                " ".join(SEEDS)
                + " ore deposit cave terrain graph pathfinding travel cost biome ecology "
                "village structure poi water coast ocean homeland depth starter route "
                "handoff opportunity relationship"
            )
            first = inventory(root)
            second = inventory(root)
        self.assertEqual(first, second)
        self.assertTrue(first["measurement_ready"])
        self.assertTrue(all(item["observable"] for item in first["capability_keyword_inventory"].values()))


if __name__ == "__main__":
    unittest.main()
