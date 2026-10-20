"""Privacy tests for the AIOVY risk API: patient vital signs must never
appear in server logs or error responses. Uses the real trained model.

Run from ml_model/uci (standard library only, no extra packages):
    .venv\\Scripts\\python -m unittest discover -s api -t . -v
"""

import asyncio
import json
import unittest
from types import SimpleNamespace
from unittest import mock

from fastapi import HTTPException
from fastapi.exceptions import RequestValidationError

from api import main

# Distinctive values, so a leak would be easy to spot in log text.
VITALS = {"Age": 37, "SystolicBP": 143, "DiastolicBP": 91, "BS": 7.3, "BodyTemp": 98.7, "HeartRate": 83}
LEAK_MARKERS = ["143", "7.3", "98.7", "83", "91", "37", *VITALS.keys()]


def assert_no_vitals(test, text):
    for marker in LEAK_MARKERS:
        test.assertNotIn(marker, text, f"log or response contains patient data: {marker!r}")


class ApiPrivacyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Load the model exactly as the server does at start-up.
        cls.loop = asyncio.new_event_loop()
        cls.lifespan = main.lifespan(main.app)
        cls.loop.run_until_complete(cls.lifespan.__aenter__())

    @classmethod
    def tearDownClass(cls):
        cls.loop.run_until_complete(cls.lifespan.__aexit__(None, None, None))
        cls.loop.close()

    def request(self, **values):
        return main.ClassifyRequest(**{**VITALS, **values})

    def test_contract_unchanged_for_documented_example(self):
        """The README example still returns the documented result."""
        response = main.classify(main.ClassifyRequest(
            Age=32, SystolicBP=142, DiastolicBP=92, BS=5.6, BodyTemp=98.4, HeartRate=82))
        self.assertEqual(response.risk_level, "high")
        self.assertAlmostEqual(response.probabilities.high, 0.6486, places=3)
        self.assertEqual(response.model_name, "Random Forest (UCI)")
        self.assertEqual(set(response.feature_contributions), set(VITALS))

    def test_additivity_failure_does_not_log_vitals(self):
        real = main.uc.shap_explain

        def broken(*args, **kwargs):
            e = real(*args, **kwargs)
            return SimpleNamespace(values=e.values, base_values=e.base_values + 0.5)

        with mock.patch.object(main.uc, "shap_explain", broken), \
                self.assertLogs("aiovy.api", level="ERROR") as logs:
            with self.assertRaises(HTTPException) as ctx:
                main.classify(self.request())
        self.assertEqual(ctx.exception.status_code, 500)
        text = "\n".join(logs.output)
        self.assertIn("SHAP additivity check failed", text)
        assert_no_vitals(self, text)
        assert_no_vitals(self, str(ctx.exception.detail))

    def test_unexpected_error_logs_type_only(self):
        """Library errors can quote the input; only the type may be logged."""
        def explode(X):
            raise ValueError(f"cannot handle input {X.to_dict('records')}")

        with mock.patch.object(main.state["model"], "predict_proba", side_effect=explode), \
                self.assertLogs("aiovy.api", level="ERROR") as logs:
            with self.assertRaises(HTTPException) as ctx:
                main.classify(self.request())
        self.assertEqual(ctx.exception.status_code, 500)
        self.assertEqual(ctx.exception.detail, "Classification failed")
        text = "\n".join(logs.output)
        self.assertIn("ValueError", text)
        assert_no_vitals(self, text)
        # Not chained: a server that logs the traceback cannot reach the message.
        self.assertIsNone(ctx.exception.__cause__)
        self.assertTrue(ctx.exception.__suppress_context__)

    def test_validation_error_does_not_echo_input(self):
        exc = RequestValidationError([
            {"type": "float_type", "loc": ("body", "SystolicBP"), "msg": "Input should be a valid number",
             "input": "143 mmHg"},
        ])
        response = self.loop.run_until_complete(main.validation_error(None, exc))
        self.assertEqual(response.status_code, 422)
        body = json.loads(response.body)
        self.assertNotIn("143 mmHg", json.dumps(body))
        self.assertEqual(body["detail"][0]["loc"], ["body", "SystolicBP"])


if __name__ == "__main__":
    unittest.main()
