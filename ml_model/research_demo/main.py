"""Serve only six audited examples. Never accept measurements for inference."""

import copy
import hashlib
import json
from contextlib import asynccontextmanager
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import shap
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "models/aiovy_random_forest.joblib"
MODEL_SHA256 = "513edbb98a8964e7569f24a34f304eb1c25db7b2a8d4cfc253b4b01877f58d94"
EXAMPLES_SHA256 = "11d9f3f9a2eaf20dcb9d93d8e18eae7bdac9026191c7bd2faaa6f66a58175f5f"
MODEL_ID = "hossain_6039_rf_experimental_v1"
MODEL_LABEL = "Experimental research model"
WARNING = "Demonstration only. Must not be used for clinical decisions. Clinical validity has not been established."
GLUCOSE_NOTE = "Provisionally mmol/L; source documentation contains conflicting unit labels. Values are unchanged, with no glucose conversion."
FEATURES = ["age", "systolic_bp", "diastolic_bp", "blood_glucose_mmol_l", "body_temperature_c", "heart_rate"]
UNITS = dict(zip(FEATURES, ["years", "mmHg", "mmHg", "provisionally mmol/L", "Celsius", "bpm"]))
CLASSES = ["high risk", "low risk", "mid risk"]
EXAMPLE_IDS = tuple(f"R{i}" for i in range(1, 7))
SOURCE_INDICES = (0, 223, 12, 4803, 5, 147)
TOLERANCE = 1e-6


def feature_frame(example):
    """Model-specific mapping; only temperature changes scale."""
    m = example["measurements"]
    return pd.DataFrame([[
        m["age"], m["systolic_bp"], m["diastolic_bp"], m["blood_glucose"],
        (m["temperature_f"] - 32) * 5 / 9, m["heart_rate"],
    ]], columns=FEATURES, dtype=float)


def explain_example(bundle, explainer, example):
    model, encoder = bundle["model"], bundle["label_encoder"]
    X = feature_frame(example)
    probabilities = model.predict_proba(X)[0]
    code = int(model.predict(X)[0])
    label = str(encoder.inverse_transform([code])[0])
    explanation = explainer(X)
    contributions = explanation.values[0, :, code]
    baseline = float(explanation.base_values[0, code])
    reconstructed = baseline + float(contributions.sum())
    if (not np.isfinite(probabilities).all() or (probabilities < 0).any()
            or (probabilities > 1).any() or abs(float(probabilities.sum()) - 1) > TOLERANCE
            or not np.isfinite(contributions).all() or not np.isfinite(baseline)
            or abs(reconstructed - probabilities[code]) > TOLERANCE):
        raise RuntimeError("Research output failed probability/SHAP validation")
    expected = example["expected_probabilities"]
    if label != example["expected_prediction"] or any(
        abs(float(probabilities[i]) - expected[name]) > 1e-9 for i, name in enumerate(CLASSES)
    ):
        raise RuntimeError("Research artifact no longer matches audited predictions")
    return {
        "model_id": MODEL_ID, "model_label": MODEL_LABEL, "warning": WARNING,
        "glucose_note": GLUCOSE_NOTE, "example_id": example["id"],
        "split": "held-out", "dataset_label": example["dataset_label"],
        "prediction": label,
        "probabilities": {name: float(probabilities[i]) for i, name in enumerate(CLASSES)},
        "measurements": example["measurements"], "feature_units": UNITS,
        "model_inputs": dict(zip(FEATURES, X.iloc[0].tolist())),
        "shap": {
            "explained_class": label, "base_value": baseline,
            "contributions": dict(zip(FEATURES, contributions.tolist())),
            "reconstructed_probability": reconstructed,
        },
    }


@asynccontextmanager
async def lifespan(app):
    if hashlib.sha256(MODEL_PATH.read_bytes()).hexdigest() != MODEL_SHA256:
        raise RuntimeError("Unexpected experimental artifact hash")
    bundle = joblib.load(MODEL_PATH)
    model = bundle["model"]
    if (bundle["features"] != FEATURES or list(model.feature_names_in_) != FEATURES
            or bundle["label_encoder"].classes_.tolist() != CLASSES
            or model.classes_.tolist() != [0, 1, 2]):
        raise RuntimeError("Unexpected experimental feature/class mapping")
    manifest_bytes = Path(__file__).with_name("examples.json").read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != EXAMPLES_SHA256:
        raise RuntimeError("Unexpected fixed example manifest hash")
    manifest = json.loads(manifest_bytes)
    examples = manifest["examples"]
    if (tuple(e["id"] for e in examples) != EXAMPLE_IDS
            or tuple(e["processed_row_index"] for e in examples) != SOURCE_INDICES):
        raise RuntimeError("Unexpected research example roster")
    # Compute and validate all six once. Requests can only retrieve these results.
    explainer = shap.TreeExplainer(model.named_steps["model"])
    app.state.results = {e["id"]: explain_example(bundle, explainer, e) for e in examples}
    yield
    del app.state.results


app = FastAPI(title="AIOVY fixed research demonstration", lifespan=lifespan,
              description=WARNING + " Only the six fixed example IDs are supported.")
app.add_middleware(CORSMiddleware,
                   allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
                   allow_methods=["GET"], allow_headers=[])


@app.middleware("http")
async def fixed_requests_only(request: Request, call_next):
    # Fail closed: even valid IDs cannot be combined with supplied measurements.
    if request.query_params or await request.body():
        return JSONResponse(status_code=400, content={"detail": "Fixed example IDs only; no query parameters or request body accepted."})
    return await call_next(request)


@app.get("/health")
def health():
    return {"status": "ok", "model_id": MODEL_ID, "model_label": MODEL_LABEL,
            "warning": WARNING, "glucose_note": GLUCOSE_NOTE}


@app.get("/research/examples")
def examples():
    return {"model_id": MODEL_ID, "example_ids": EXAMPLE_IDS}


@app.get("/research/examples/{example_id}")
def result(example_id: str, request: Request):
    if example_id not in EXAMPLE_IDS:
        raise HTTPException(status_code=404, detail="Unknown fixed example")
    return copy.deepcopy(request.app.state.results[example_id])
