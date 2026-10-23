"""Real-artifact, HTTP/ASGI and UCI regression checks; no network or retraining."""

import asyncio
import hashlib
import json
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import joblib
import numpy as np
import pandas as pd
import shap
from sklearn.model_selection import GroupShuffleSplit

from ml_model.research_demo import main as research
from ml_model.uci.api import main as uci


async def request(app, path, method="GET", body=b"", query=b"", headers=None):
    """Exercise the complete ASGI middleware/router without extra dependencies."""
    sent = []
    received = False

    async def receive():
        nonlocal received
        if not received:
            received = True
            return {"type": "http.request", "body": body, "more_body": False}
        await asyncio.Event().wait()

    async def send(message):
        sent.append(message)

    await app({"type": "http", "asgi": {"version": "3.0", "spec_version": "2.4"},
               "http_version": "1.1", "method": method, "scheme": "http",
               "path": path, "raw_path": path.encode(), "query_string": query,
               "root_path": "", "headers": headers or [], "client": ("127.0.0.1", 1),
               "server": ("test", 8001)}, receive, send)
    status = next(m["status"] for m in sent if m["type"] == "http.response.start")
    data = b"".join(m.get("body", b"") for m in sent if m["type"] == "http.response.body")
    try:
        data = json.loads(data)
    except json.JSONDecodeError:
        data = data.decode()
    return status, data


class ResearchDemoTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.loop = asyncio.new_event_loop()
        cls.research_lifespan = research.lifespan(research.app)
        cls.uci_lifespan = uci.lifespan(uci.app)
        cls.loop.run_until_complete(cls.research_lifespan.__aenter__())
        cls.loop.run_until_complete(cls.uci_lifespan.__aenter__())
        cls.manifest = json.loads(Path(research.__file__).with_name("examples.json").read_text())
        cls.bundle = joblib.load(research.MODEL_PATH)

    @classmethod
    def tearDownClass(cls):
        cls.loop.run_until_complete(cls.research_lifespan.__aexit__(None, None, None))
        cls.loop.run_until_complete(cls.uci_lifespan.__aexit__(None, None, None))
        cls.loop.close()

    def call(self, path, **kwargs):
        return self.loop.run_until_complete(request(research.app, path, **kwargs))

    def test_provenance_hashes_and_heldout_membership(self):
        for name, digest in self.manifest["sha256"].items():
            self.assertEqual(hashlib.sha256((research.ROOT / name).read_bytes()).hexdigest(), digest)
        data = pd.read_csv(research.ROOT / "data/processed/maternal_aiovy_candidate_6039.csv")
        saved = pd.read_csv(research.ROOT / "reports/notebook_04/heldout_test_predictions.csv")
        groups = pd.util.hash_pandas_object(data[research.FEATURES], index=False)
        train, test = next(GroupShuffleSplit(n_splits=1, test_size=.2, random_state=42).split(
            data[research.FEATURES], data.risk_level, groups=groups))
        self.assertEqual((len(train), len(test)), (4826, 1213))
        np.testing.assert_array_equal(test, saved.source_row_index)
        self.assertFalse(set(groups.iloc[train]) & set(groups.iloc[test]))
        self.assertEqual(len(self.manifest["examples"]), 6)
        for e in self.manifest["examples"]:
            index = e["processed_row_index"]
            self.assertIn(index, test)
            self.assertNotIn(index, train)
            np.testing.assert_allclose(research.feature_frame(e).iloc[0], data.loc[index, research.FEATURES].astype(float), atol=1e-12)
            self.assertEqual(e["dataset_label"], data.loc[index, "risk_level"])

    def test_feature_order_units_and_class_mapping(self):
        self.assertEqual(self.bundle["features"], research.FEATURES)
        self.assertEqual(self.bundle["label_encoder"].classes_.tolist(), ["high risk", "low risk", "mid risk"])
        self.assertEqual(self.bundle["model"].classes_.tolist(), [0, 1, 2])
        first = research.feature_frame(self.manifest["examples"][0])
        self.assertEqual(first.columns.tolist(), research.FEATURES)
        self.assertEqual(first.iloc[0].blood_glucose_mmol_l, 5.8)
        self.assertAlmostEqual(first.iloc[0].body_temperature_c, (97.5 - 32) * 5 / 9)
        self.assertEqual(research.UNITS["blood_glucose_mmol_l"], "provisionally mmol/L")

    def test_all_outputs_match_saved_predictions_and_shap(self):
        for e in self.manifest["examples"]:
            with self.subTest(example=e["id"]):
                status, result = self.call(f'/research/examples/{e["id"]}')
                self.assertEqual(status, 200)
                self.assertEqual(result["model_id"], research.MODEL_ID)
                self.assertIn("Must not be used for clinical decisions", result["warning"])
                self.assertEqual(result["prediction"], e["expected_prediction"])
                self.assertEqual(result["dataset_label"], e["dataset_label"])
                p = result["probabilities"]
                self.assertAlmostEqual(sum(p.values()), 1)
                for label, value in p.items():
                    self.assertTrue(np.isfinite(value) and 0 <= value <= 1)
                    self.assertAlmostEqual(value, e["expected_probabilities"][label], places=9)
                s = result["shap"]
                self.assertEqual(s["explained_class"], result["prediction"])
                self.assertEqual(list(s["contributions"]), research.FEATURES)
                self.assertAlmostEqual(s["base_value"] + sum(s["contributions"].values()), p[result["prediction"]], delta=1e-6)
        self.assertEqual(sum(e["dataset_label"] != e["expected_prediction"] for e in self.manifest["examples"]), 3)

    def test_only_fixed_get_requests_are_supported(self):
        status, listing = self.call('/research/examples')
        self.assertEqual(status, 200)
        self.assertEqual(listing["example_ids"], list(research.EXAMPLE_IDS))
        for path, options, expected in [
            ('/research/examples/R7', {}, 404),
            ('/research/examples/0', {}, 404),
            ('/research/examples/R1', {"query": b"age=35"}, 400),
            ('/research/examples/R1', {"body": b'{"age":35}'}, 400),
            ('/research/examples/R1', {"method": "POST"}, 405),
            ('/classify', {"method": "POST", "body": b'{"Age":35}'}, 400),
            ('/classify', {"method": "POST"}, 404),
        ]:
            with self.subTest(path=path, options=options):
                self.assertEqual(self.call(path, **options)[0], expected)

    def test_docs_and_openapi_are_reachable_without_classify_endpoint(self):
        status, docs = self.call('/docs')
        self.assertEqual(status, 200)
        self.assertIn('swagger-ui', docs)
        status, schema = self.call('/openapi.json')
        self.assertEqual(status, 200)
        self.assertEqual(set(schema['paths']), {'/health', '/research/examples', '/research/examples/{example_id}'})
        self.assertTrue(all(set(methods) == {'get'} for methods in schema['paths'].values()))

    def test_localhost_browser_preflight(self):
        status, _ = self.call('/research/examples/R1', method='OPTIONS', headers=[
            (b'origin', b'http://localhost:8080'),
            (b'access-control-request-method', b'GET'),
        ])
        self.assertEqual(status, 200)

    def test_invalid_shap_fails_closed(self):
        real = shap.TreeExplainer(self.bundle["model"].named_steps["model"])

        def broken(X):
            e = real(X)
            return SimpleNamespace(values=e.values, base_values=e.base_values + .1)

        with self.assertRaisesRegex(RuntimeError, "SHAP"):
            research.explain_example(self.bundle, broken, self.manifest["examples"][0])

    def test_flutter_fixtures_match_real_backend(self):
        path = research.ROOT.parent / "test/fixtures/research_examples.json"
        fixtures = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual([e["example_id"] for e in fixtures], list(research.EXAMPLE_IDS))
        for expected in fixtures:
            status, actual = self.call('/research/examples/' + expected["example_id"])
            self.assertEqual(status, 200)
            # Parallel RF sums can differ in the last binary floating-point bit.
            # Keep schema/labels exact and numerical parity far tighter than the
            # production SHAP/probability tolerances.
            for key in actual:
                if key in ('probabilities', 'model_inputs'):
                    self.assertEqual(actual[key].keys(), expected[key].keys())
                    np.testing.assert_allclose(list(actual[key].values()), list(expected[key].values()), atol=1e-12, rtol=0)
                elif key == 'shap':
                    self.assertEqual(actual[key]['explained_class'], expected[key]['explained_class'])
                    for field in ('base_value', 'reconstructed_probability'):
                        self.assertAlmostEqual(actual[key][field], expected[key][field], delta=1e-12)
                    self.assertEqual(actual[key]['contributions'].keys(), expected[key]['contributions'].keys())
                    np.testing.assert_allclose(list(actual[key]['contributions'].values()),
                                               list(expected[key]['contributions'].values()), atol=1e-12, rtol=0)
                else:
                    self.assertEqual(actual[key], expected[key])

    def test_wrong_artifact_fails_startup(self):
        async def start():
            async with research.lifespan(research.FastAPI()):
                self.fail("Unexpected artifact accepted")
        with patch.object(research, "MODEL_SHA256", "wrong"):
            with self.assertRaisesRegex(RuntimeError, "hash"):
                self.loop.run_until_complete(start())

    def test_uci_isolation_and_all_92_saved_predictions(self):
        original_model = uci.state["model"]
        original_explainer = uci.state["explainer"]
        self.call('/research/examples/R2')
        self.assertIs(uci.state["model"], original_model)
        self.assertIs(uci.state["explainer"], original_explainer)
        self.assertIsNot(original_model, self.bundle["model"])
        self.assertNotIn('/research/examples', {r.path for r in uci.app.routes})
        self.assertNotIn('/classify', {r.path for r in research.app.routes})
        saved = pd.read_csv(uci.UCI_DIR / 'reports/final_model/heldout_test_predictions.csv')
        self.assertEqual(len(saved), 92)
        for _, row in saved.iterrows():
            response = uci.classify(uci.ClassifyRequest(**{f: float(row[f]) for f in uci.uc.FEATURES}))
            self.assertEqual(response.risk_level, uci.APP_LEVELS[row.predicted_risk])
            for label, col in [('high', 'prob_high_risk'), ('low', 'prob_low_risk'), ('moderate', 'prob_mid_risk')]:
                self.assertAlmostEqual(getattr(response.probabilities, label), row[col], delta=1e-9)
        # UCI shutdown/startup is independent of the research result cache.
        self.assertEqual(len(research.app.state.results), 6)


if __name__ == "__main__":
    unittest.main()
