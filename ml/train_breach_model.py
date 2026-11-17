"""Train the SLA-breach risk model on the UCI incident event log (FR-16, NFR-12).

Run from the repo root with the project venv:
    .venv/bin/python ml/train_breach_model.py

What it does
- Builds one row per incident from its FIRST logged event (open-time values only, FR-16).
- Target: breach = NOT made_sla on the LAST event (direction confirmed in docs/eda-findings.md).
- Time-based split (D-54), seed 42 (NFR-12), written leakage check (FR-16).
- Baseline: logistic regression. Main model: HistGradientBoosting.
- Calibrates on the latest slice of the training period only, never on test data (D-55).
- Saves the calibrated main model and metrics_v1.json to ml/models/ (D-47, NFR-12).
"""
import argparse
import json
import random
from datetime import date
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import sklearn
from sklearn.calibration import CalibratedClassifierCV
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.frozen import FrozenEstimator
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (average_precision_score, brier_score_loss,
                             precision_score, recall_score, roc_auc_score)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, OrdinalEncoder

# ---------------------------------------------------------------- constants
SEED = 42                       # NFR-12
MODEL_VERSION = "v1"
SPLIT_DATE = "2016-05-11"       # D-54: train = opened before, test = opened on or after
CALIB_START = "2016-04-21"      # D-55: latest slice of the TRAINING period, used only for calibration
MIN_LEVEL_COUNT = 50            # subcategory / u_symptom levels seen fewer times in the fit data -> "Other"
THRESHOLD = 0.5                 # for the precision / recall that FR-16 asks to save
MISSING, OTHER = "Missing", "Other"

REPO = Path(__file__).resolve().parents[1]
DATA_PATH = REPO / "data" / "raw" / "incident_event_log.csv"
OUT_DIR = REPO / "ml" / "models"

# ---------------------------------------------------------------- features (FR-16)
# Every feature is read from the incident's first event. `knowledge` was dropped by D-53.
CAT_FEATURES = ["contact_type", "category", "subcategory", "u_symptom", "impact", "urgency",
                "priority", "assignment_group", "open_weekday"]
NUM_FEATURES = ["open_hour"]                    # 0-23, derived from opened_at
FEATURES = CAT_FEATURES + NUM_FEATURES
RARE_GROUPED = ["subcategory", "u_symptom"]     # hundreds of small levels (EDA "Not verified")

# Raw column each feature is read from. opened_at is used only for hour, weekday and the split.
FEATURE_SOURCE = {f: f for f in CAT_FEATURES if f != "open_weekday"}
FEATURE_SOURCE.update({"open_weekday": "opened_at", "open_hour": "opened_at"})

# Every other column in the file, with the reason it is not a feature.
EXCLUDED = {
    # set or changed after the ticket opens -> leakage
    "incident_state": "post-open: workflow state changes as the ticket is worked",
    "active": "post-open: turns false when the ticket closes",
    "reassignment_count": "post-open: running counter",
    "reopen_count": "post-open: running counter",
    "sys_mod_count": "post-open: running counter of updates",
    "made_sla": "post-open: this is the target (last event); never a feature",
    "sys_updated_by": "post-open: who made each later update",
    "sys_updated_at": "post-open: time of each later update",
    "assigned_to": "post-open: set when the ticket is picked up (EDA: never use)",
    "closed_code": "post-open: resolution field, back-filled onto every row",
    "resolved_by": "post-open: resolution field, back-filled onto every row",
    "resolved_at": "post-open: resolution field, back-filled onto every row",
    "closed_at": "post-open: closure field, back-filled onto every row",
    "problem_id": "post-open: linked later; almost entirely missing",
    "rfc": "post-open: linked later; almost entirely missing",
    "vendor": "post-open: linked later; almost entirely missing",
    "caused_by": "post-open: linked later; almost entirely missing",
    "u_priority_confirmation": "post-open: confirmation step after open; not verified as open-time",
    "notify": "post-open: notification setting; not verified as open-time",
    # known at open but not used
    "knowledge": "dropped by D-53: flags tickets opened before 2016-03-11, a date proxy",
    "number": "identifier",
    "caller_id": "identifier, high cardinality; not in the FR-16 candidate list",
    "opened_by": "identifier, high cardinality; not in the FR-16 candidate list",
    "sys_created_by": "identifier; not in the FR-16 candidate list",
    "sys_created_at": "duplicate of opened_at; the raw date would act as a date proxy",
    "location": "not in the FR-16 candidate list; high cardinality",
    "cmdb_ci": "almost entirely missing",
}
POST_OPEN_FIELDS = {c for c, why in EXCLUDED.items() if why.startswith("post-open")}


# ---------------------------------------------------------------- data
def load_incidents(path):
    """One row per incident: open-time values from the first event, target from the last."""
    raw = pd.read_csv(path, dtype=str, keep_default_na=False, na_values=["?"])   # "?" = unknown
    raw["_row"] = np.arange(len(raw))                 # file order, tie-breaker only
    raw["sys_mod_count"] = raw["sys_mod_count"].astype(int)
    for c in ["opened_at", "sys_updated_at"]:
        raw[c] = pd.to_datetime(raw[c], format="%d/%m/%Y %H:%M")
    raw = raw.sort_values(["number", "sys_mod_count", "sys_updated_at", "_row"], kind="mergesort")
    g = raw.groupby("number", sort=False)
    first, last = g.first(skipna=False), g.last(skipna=False)   # skipna=False: do not borrow later values

    assert set(last["made_sla"].unique()) <= {"true", "false"}
    inc = first[sorted(set(FEATURE_SOURCE.values()))].copy()
    inc["breach"] = (last["made_sla"] == "false").astype(int)   # breach = NOT made_sla (EDA answer 3)
    return inc, list(raw.columns.drop("_row"))


def prepare_features(inc, kept_levels):
    """Open-time feature table. Also used by batch scoring (FR-17) with the saved kept_levels."""
    X = pd.DataFrame(index=inc.index)
    for f in CAT_FEATURES:
        if f != "open_weekday":
            X[f] = inc[FEATURE_SOURCE[f]].fillna(MISSING)       # missing stays a level of its own
    X["open_weekday"] = inc["opened_at"].dt.day_name()
    X["open_hour"] = inc["opened_at"].dt.hour
    for f in RARE_GROUPED:
        X[f] = X[f].where(X[f].isin(kept_levels[f]), OTHER)
    return X[FEATURES]


def leakage_check(all_columns):
    """FR-16: no feature may come from a field that is set after the ticket opens."""
    sources = set(FEATURE_SOURCE.values())
    leaked = sources & POST_OPEN_FIELDS
    assert not leaked, f"post-open fields in the feature set: {leaked}"
    assert "knowledge" not in sources, "knowledge was dropped by D-53"
    assert not sources & set(EXCLUDED), "a field is listed as both used and excluded"
    unlisted = set(all_columns) - sources - set(EXCLUDED)
    assert not unlisted, f"columns neither used nor excluded: {unlisted}"
    print(f"Leakage check passed: {len(FEATURES)} features from {len(sources)} open-time columns, "
          f"first event only; {len(POST_OPEN_FIELDS)} post-open fields excluded.")


# ---------------------------------------------------------------- models
def make_baseline():
    pre = ColumnTransformer([("onehot", OneHotEncoder(handle_unknown="ignore"), FEATURES)])  # hour as a level
    return Pipeline([("pre", pre), ("clf", LogisticRegression(max_iter=2000, random_state=SEED))])


def make_main():
    pre = ColumnTransformer([
        ("cat", OrdinalEncoder(handle_unknown="use_encoded_value", unknown_value=-1), CAT_FEATURES),
        ("num", "passthrough", NUM_FEATURES),
    ])
    clf = HistGradientBoostingClassifier(
        categorical_features=list(range(len(CAT_FEATURES))),   # unseen level (-1) is treated as missing
        learning_rate=0.05, max_iter=200, max_leaf_nodes=15, min_samples_leaf=50,
        early_stopping=False, random_state=SEED)
    return Pipeline([("pre", pre), ("clf", clf)])


def evaluate(model, X, y):
    p = model.predict_proba(X)[:, 1]
    pred = (p >= THRESHOLD).astype(int)
    return {"roc_auc": round(roc_auc_score(y, p), 4),
            "pr_auc": round(average_precision_score(y, p), 4),
            "brier": round(brier_score_loss(y, p), 4),
            "mean_predicted_risk": round(float(p.mean()), 4),
            f"precision_at_{THRESHOLD}": round(precision_score(y, pred, zero_division=0), 4),
            f"recall_at_{THRESHOLD}": round(recall_score(y, pred), 4)}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--data", type=Path, default=DATA_PATH)
    ap.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = ap.parse_args()
    random.seed(SEED)
    np.random.seed(SEED)

    inc, all_columns = load_incidents(args.data)
    leakage_check(all_columns)

    # D-54 time split; D-55 calibration slice = latest part of the training period
    is_test = inc["opened_at"] >= SPLIT_DATE
    is_calib = ~is_test & (inc["opened_at"] >= CALIB_START)
    is_fit = ~is_test & ~is_calib
    assert inc.loc[is_fit, "opened_at"].max() < inc.loc[is_calib, "opened_at"].min()
    assert inc.loc[is_calib, "opened_at"].max() < inc.loc[is_test, "opened_at"].min()

    # rare-level grouping is learned from the fit rows only
    kept_levels = {}
    for f in RARE_GROUPED:
        vc = inc.loc[is_fit, f].fillna(MISSING).value_counts()
        kept_levels[f] = sorted(vc[vc >= MIN_LEVEL_COUNT].index)
    X, y = prepare_features(inc, kept_levels), inc["breach"]
    X_fit, y_fit = X[is_fit], y[is_fit]
    X_cal, y_cal = X[is_calib], y[is_calib]
    X_test, y_test = X[is_test], y[is_test]

    rows = {"train_total": int((~is_test).sum()), "fit": int(is_fit.sum()),
            "calibration": int(is_calib.sum()), "test": int(is_test.sum())}
    breach_rate = {"train_total": round(float(y[~is_test].mean()), 4), "fit": round(float(y_fit.mean()), 4),
                   "calibration": round(float(y_cal.mean()), 4), "test": round(float(y_test.mean()), 4)}
    print("Rows:", rows)
    print("Breach rate:", breach_rate)

    metrics, calibrated = {}, {}
    for name, make in [("baseline_logreg", make_baseline), ("main_hgb", make_main)]:
        model = make().fit(X_fit, y_fit)
        # sigmoid (Platt) calibration fitted on the calibration slice only; the model itself is frozen
        cal = CalibratedClassifierCV(FrozenEstimator(model), method="sigmoid").fit(X_cal, y_cal)
        calibrated[name] = cal
        metrics[name] = {"before_calibration": evaluate(model, X_test, y_test),
                         "after_calibration": evaluate(cal, X_test, y_test)}

    print(f"\nTest set: {rows['test']:,} incidents, breach rate {breach_rate['test']:.1%}")
    print(f"{'model':<18}{'calibration':<10}{'ROC-AUC':>9}{'PR-AUC':>9}{'Brier':>9}{'mean risk':>11}")
    for name, m in metrics.items():
        for stage in ["before_calibration", "after_calibration"]:
            r = m[stage]
            print(f"{name:<18}{stage.split('_')[0]:<10}{r['roc_auc']:>9.4f}{r['pr_auc']:>9.4f}"
                  f"{r['brier']:>9.4f}{r['mean_predicted_risk']:>11.4f}")

    # Top features (part of the leakage check, FR-16): a single feature that dominates would be suspect.
    final = calibrated["main_hgb"]
    perm = permutation_importance(final, X_test, y_test, scoring="roc_auc", n_repeats=10, random_state=SEED)
    top = sorted(zip(FEATURES, perm.importances_mean), key=lambda t: -t[1])
    top_features = [{"feature": f, "roc_auc_drop_when_shuffled": round(float(v), 4)} for f, v in top]
    print("\nTop features, main model (drop in test ROC-AUC when the feature is shuffled):")
    for i, t in enumerate(top_features, 1):
        print(f"{i:>3}. {t['feature']:<18}{t['roc_auc_drop_when_shuffled']:>8.4f}")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    model_path = args.out_dir / f"breach_model_{MODEL_VERSION}.joblib"
    joblib.dump({"model": final, "model_version": MODEL_VERSION, "features": FEATURES,
                 "kept_levels": kept_levels, "missing_label": MISSING, "other_label": OTHER},
                model_path, compress=3)
    out = {
        "model_version": MODEL_VERSION,
        "trained_on": date.today().isoformat(),
        "seed": SEED,
        "target": "breach = NOT made_sla (last event)",
        "split_date": SPLIT_DATE,
        "calibration": {"method": "sigmoid", "slice_start": CALIB_START, "slice_end_exclusive": SPLIT_DATE},
        "features": FEATURES,
        "rare_level_grouping": {"min_level_count": MIN_LEVEL_COUNT,
                                "levels_kept": {f: len(v) for f, v in kept_levels.items()}},
        "excluded_fields": EXCLUDED,
        "rows": rows,
        "breach_rate": breach_rate,
        "threshold_for_precision_recall": THRESHOLD,
        "metrics_test": metrics,
        "top_features_main_model": top_features,
        "saved_model": {"file": model_path.name, "what": "main_hgb, calibrated",
                        "size_kb": round(model_path.stat().st_size / 1024, 1)},
        "library_versions": {"pandas": pd.__version__, "numpy": np.__version__,
                             "scikit-learn": sklearn.__version__, "joblib": joblib.__version__},
    }
    metrics_path = args.out_dir / f"metrics_{MODEL_VERSION}.json"
    metrics_path.write_text(json.dumps(out, indent=2) + "\n")
    print(f"\nSaved {model_path} ({out['saved_model']['size_kb']} KB) and {metrics_path}")


if __name__ == "__main__":
    main()
