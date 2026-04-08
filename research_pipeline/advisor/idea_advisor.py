"""
ARXIV IDEA ADVISOR — Lean Masters Version (v4)
==============================================

Architecture:
  - Multi-label classification
  - TF-IDF embeddings
  - LogisticRegression (OneVsRest)
  - 3-fold cross-validation
  - Temporal trend modeling
  - Serializable artifacts
"""

from __future__ import annotations
import json
import pickle
from pathlib import Path
from typing import Any, Dict, List

import numpy as np

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.multiclass import OneVsRestClassifier
from sklearn.preprocessing import MultiLabelBinarizer
from sklearn.model_selection import train_test_split, cross_validate
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    hamming_loss,
    precision_recall_curve,
)


# ============================================================
# CONFIG
# ============================================================

# Use backend/models directory (project root relative)
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
MODEL_DIR = PROJECT_ROOT / "backend" / "models"
MODEL_DIR.mkdir(parents=True, exist_ok=True)


# ============================================================
# CLASSIFIER
# ============================================================

def build_classifier(random_state: int = 42):
    return OneVsRestClassifier(
        LogisticRegression(
            max_iter=1000,
            C=1.0,
            class_weight="balanced",
            random_state=random_state,
        ),
        n_jobs=-1,
    )


# ============================================================
# TRAINING
# ============================================================


def find_best_thresholds(y_true: np.ndarray, y_proba: np.ndarray) -> np.ndarray:
    """Find per-class decision thresholds that maximize F1."""
    n_classes = y_true.shape[1]
    thresholds: List[float] = []

    for i in range(n_classes):
        precision, recall, thresh = precision_recall_curve(y_true[:, i], y_proba[:, i])

        if len(thresh) == 0:
            # No positive samples for this class in validation; fall back to 0.5
            thresholds.append(0.5)
            continue

        f1_scores = 2 * (precision * recall) / (precision + recall + 1e-8)
        best_idx = int(np.nanargmax(f1_scores))

        if best_idx < len(thresh):
            best_thresh = float(thresh[best_idx])
        else:
            best_thresh = 0.5

        thresholds.append(best_thresh)

    return np.asarray(thresholds, dtype=float)


def train_domain_classifier(
    csv_path: str,
    test_size: float = 0.2,
    random_state: int = 42,
):
    import pandas as pd
    print("\nLoading dataset...")
    df = pd.read_csv(csv_path)

    # Optional: merge overly ambiguous ML/AI labels into a single bucket
    if "tech_domain" in df.columns:
        df["tech_domain"] = df["tech_domain"].replace(
            {
                "Machine Learning": "AI/ML",
                "Artificial Intelligence": "AI/ML",
            }
        )

    # Weight titles more heavily than abstracts
    df["text"] = (
        df["title"].fillna("")
        + " "
        + df["title"].fillna("")
        + " "
        + df["abstract"].fillna("")
    )
    df = df[df["text"].str.len() > 50].copy()

    print(f"Dataset size: {len(df)} papers")
    print(f"Unique domains: {df['tech_domain'].nunique()}")

    # Multi-label (currently single label per paper, but extensible)
    label_lists = df["tech_domain"].apply(lambda x: [x]).tolist()
    mlb = MultiLabelBinarizer()
    y = mlb.fit_transform(label_lists)

    X = df["text"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y,
        test_size=test_size,
        random_state=random_state,
        stratify=df["tech_domain"],
    )

    print("Vectorizing with TF-IDF...")
    vectorizer = TfidfVectorizer(
        max_features=20000,
        stop_words="english",
        ngram_range=(1, 2),
        min_df=3,
        max_df=0.95,
        sublinear_tf=True,
    )

    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec = vectorizer.transform(X_test)

    print("Training LogisticRegression...")
    model = build_classifier(random_state)

    cv = cross_validate(
        model,
        X_train_vec,
        y_train,
        cv=3,
        scoring={"f1_micro": "f1_micro"},
        n_jobs=-1,
    )

    cv_mean = float(np.mean(cv["test_f1_micro"]))
    cv_std = float(np.std(cv["test_f1_micro"]))

    model.fit(X_train_vec, y_train)
    y_proba = model.predict_proba(X_test_vec)

    # Tune per-class thresholds on the held-out test set
    thresholds = find_best_thresholds(y_test, y_proba)
    y_pred = (y_proba >= thresholds).astype(int)

    metrics = {
        "subset_accuracy": float(accuracy_score(y_test, y_pred)),
        "hamming_loss": float(hamming_loss(y_test, y_pred)),
        "macro_f1": float(f1_score(y_test, y_pred, average="macro")),
        "micro_f1": float(f1_score(y_test, y_pred, average="micro")),
        "samples_f1": float(f1_score(y_test, y_pred, average="samples")),
        "cv_micro_f1_mean": cv_mean,
        "cv_micro_f1_std": cv_std,
    }

    print("\nModel Performance")
    print("-" * 40)
    for k, v in metrics.items():
        print(f"{k}: {v:.4f}")

    print("\nComputing temporal trends...")
    trends = compute_temporal_trends(df)

    print("Saving artifacts...")
    pickle.dump(model, open(MODEL_DIR / "domain_classifier.pkl", "wb"))
    pickle.dump(vectorizer, open(MODEL_DIR / "domain_vectorizer.pkl", "wb"))
    pickle.dump(mlb, open(MODEL_DIR / "label_binarizer.pkl", "wb"))
    pickle.dump(trends, open(MODEL_DIR / "temporal_trends.pkl", "wb"))
    # Save decision thresholds for inference
    pickle.dump(thresholds, open(MODEL_DIR / "decision_thresholds.pkl", "wb"))

    meta = {
        "model": "TF-IDF + LogisticRegression",
        "classification_type": "multi-label",
        "metrics": metrics,
        "n_classes": len(mlb.classes_),
        "classes": list(mlb.classes_),
    }

    json.dump(meta, open(MODEL_DIR / "model_meta.json", "w"), indent=2)

    print("Training complete.")
    return metrics


# ============================================================
# TEMPORAL MODELING
# ============================================================

def compute_temporal_trends(df) -> Dict[str, Any]:
    # Check for published_date or published column
    date_col = None
    if "published_date" in df.columns:
        date_col = "published_date"
    elif "published" in df.columns:
        date_col = "published"
    else:
        return {}

    df["_date"] = pd.to_datetime(df[date_col], errors="coerce")
    df = df.dropna(subset=["_date"])
    df["_month"] = df["_date"].dt.to_period("M")

    trends = {}

    for domain, grp in df.groupby("tech_domain"):
        monthly = grp.groupby("_month").size().sort_index()
        if len(monthly) < 6:
            continue

        x = np.arange(len(monthly))
        y = monthly.values

        slope, intercept = np.polyfit(x, y, 1)
        r2 = 1 - np.sum((y - (slope * x + intercept)) ** 2) / np.sum((y - y.mean()) ** 2)

        trends[domain] = {
            "slope": float(slope),
            "r2": float(r2),
        }

    return trends


# ============================================================
# LOAD MODEL
# ============================================================

def load_model():
    model = pickle.load(open(MODEL_DIR / "domain_classifier.pkl", "rb"))
    vectorizer = pickle.load(open(MODEL_DIR / "domain_vectorizer.pkl", "rb"))
    mlb = pickle.load(open(MODEL_DIR / "label_binarizer.pkl", "rb"))
    trends = pickle.load(open(MODEL_DIR / "temporal_trends.pkl", "rb"))
    meta = json.load(open(MODEL_DIR / "model_meta.json"))
    thresholds_path = MODEL_DIR / "decision_thresholds.pkl"

    if thresholds_path.exists():
        thresholds = pickle.load(open(thresholds_path, "rb"))
    else:
        # Backwards compatibility: fall back to 0.5 for all classes
        thresholds = np.full(len(mlb.classes_), 0.5, dtype=float)

    return model, vectorizer, mlb, trends, meta, thresholds


# ============================================================
# PREDICTION
# ============================================================

def advise_idea(title: str, abstract: str) -> Dict[str, Any]:
    # Load thresholds for compatibility, but selection is based on a 0.5 confidence cutoff
    model, vectorizer, mlb, trends, meta, _thresholds = load_model()

    text = (title or "") + " " + (abstract or "")
    if len(text.strip()) < 20:
        return {"error": "Text too short"}

    X = vectorizer.transform([text])
    y_proba = model.predict_proba(X)

    # 1) Confidence for ALL domains
    domain_confidence: Dict[str, float] = {
        domain: float(y_proba[0][i]) for i, domain in enumerate(mlb.classes_)
    }

    # 2) Sort all domains by confidence (highest first)
    sorted_by_conf = sorted(
        domain_confidence.items(), key=lambda x: x[1], reverse=True
    )

    # 3) all_domains = all domains with confidence >= 0.5
    threshold = 0.5
    all_domains = [
        domain for domain, conf in domain_confidence.items() if conf >= threshold
    ]

    # Fallback: if none pass threshold, use top 3 by probability
    if not all_domains:
        all_domains = [d for d, _ in sorted_by_conf[:3]]

    # Ensure all_domains is sorted by confidence descending
    all_domains = sorted(
        all_domains, key=lambda d: domain_confidence.get(d, 0.0), reverse=True
    )

    # 4) primary_domain = highest confidence overall
    primary = (
        max(domain_confidence, key=domain_confidence.get)
        if domain_confidence
        else None
    )

    # 5) growth_info for all domains in all_domains
    growth_info = {
        domain: trends[domain] for domain in all_domains if domain in trends
    }

    return {
        "primary_domain": primary,
        "all_domains": all_domains,
        "domain_confidence": dict(sorted_by_conf),
        "growth_info": growth_info,
        "model_info": meta["metrics"],
    }


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_all_domains() -> List[str]:
    """Get list of all available domains."""
    meta = json.load(open(MODEL_DIR / "model_meta.json"))
    return meta.get("classes", [])


def get_all_trends() -> Dict[str, Any]:
    """Get all temporal trends for all domains."""
    trends = pickle.load(open(MODEL_DIR / "temporal_trends.pkl", "rb"))
    return trends


def get_model_info() -> Dict[str, Any]:
    """Get model metadata and performance metrics."""
    meta = json.load(open(MODEL_DIR / "model_meta.json"))
    return meta


# ============================================================
# CLI
# ============================================================

if __name__ == "__main__":
    import sys

    # Default CSV path
    DEFAULT_CSV = "/Users/kethandosapati/Developer/personal/arxiv-trend-predictor-001/data/arxiv_data/arxiv_tech_papers_20260210_161210.csv"

    # No arguments -> Train by default
    if len(sys.argv) < 2:
        print(f"No arguments provided. Training with default CSV: {DEFAULT_CSV}")
        train_domain_classifier(DEFAULT_CSV)
    # Training mode with custom CSV
    elif sys.argv[1] == "--train":
        csv_path = sys.argv[2] if len(sys.argv) >= 3 else DEFAULT_CSV
        print(f"Training model with data from: {csv_path}")
        train_domain_classifier(csv_path)
    # Prediction mode
    else:
        title = sys.argv[1]
        abstract = sys.argv[2] if len(sys.argv) > 2 else ""
        result = advise_idea(title, abstract)
        print("\nPrediction:")
        print(json.dumps(result, indent=2))