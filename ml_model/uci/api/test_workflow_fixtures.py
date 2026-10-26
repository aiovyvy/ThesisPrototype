"""Verify synthetic Flutter workflow fixtures against the unchanged saved model."""
import asyncio
import hashlib
import json
import unittest
from pathlib import Path

from ml_model.uci.api import main as uci


class WorkflowFixturesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.loop = asyncio.new_event_loop()
        cls.lifespan = uci.lifespan(uci.app)
        cls.loop.run_until_complete(cls.lifespan.__aenter__())
        cls.fixture = json.loads((Path(__file__).resolve().parents[3] /
                                  "test/fixtures/uci_workflow_responses.json").read_text())

    @classmethod
    def tearDownClass(cls):
        cls.loop.run_until_complete(cls.lifespan.__aexit__(None, None, None))
        cls.loop.close()

    def test_fixture_identifies_current_artifact(self):
        self.assertEqual(hashlib.sha256(uci.MODEL_PATH.read_bytes()).hexdigest(),
                         self.fixture["model_sha256"])

    def test_all_three_synthetic_workflow_responses(self):
        labels = set()
        for case in self.fixture["cases"]:
            with self.subTest(label=case["response"]["risk_level"]):
                # classify also enforces predicted-class SHAP reconstruction.
                result = uci.classify(uci.ClassifyRequest(**case["request"])).model_dump()
                expected = case["response"]
                labels.add(result["risk_level"])
                self.assertEqual(result["risk_level"], expected["risk_level"])
                self.assertEqual(result["model_name"], expected["model_name"])
                for group in ["probabilities", "feature_contributions"]:
                    self.assertEqual(set(result[group]), set(expected[group]))
                    for key, value in expected[group].items():
                        self.assertAlmostEqual(result[group][key], value, delta=1e-12)
        self.assertEqual(labels, {"low", "moderate", "high"})


if __name__ == "__main__":
    unittest.main()
