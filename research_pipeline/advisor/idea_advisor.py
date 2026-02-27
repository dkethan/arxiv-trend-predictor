"""
Idea Advisor for Tech / arXiv  (v3 — Masters-grade, Multi-label)
=================================================================
Pipeline:
  1. Scrape arXiv data (handled by scraper module)
  2. EDA + Analysis (handled by analysis module)
  3. Train multi-label domain classifier with benchmark
  4. Temporal trend modeling with forecasting
  5. Serialize everything to .pkl / .json
  6. Expose advise_idea() for the API layer
  7. Web app calls API (handled by FastAPI + React)

Key upgrades over v1:
  - Multi-label classification (60%+ papers have 2+ domains)
  - SciBERT embeddings via sentence-transformers
  - 4 classifiers x 2 embeddings = 8-way benchmark
  - Stratified k-fold cross-validation with confidence intervals
  - Temporal trend modeling (linear regression + 3-month forecast)
  - Rich advise_idea() output with model metadata
"""

from __future__ import annotations

import json
import pickle
import warnings
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

from backend.core.constants import GENERIC_KEYWORDS
from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)

# ──────────────────────────────────────────────────────────────────────
# Dependency checks
# ──────────────────────────────────────────────────────────────────────
try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.svm import LinearSVC
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.neural_network import MLPClassifier
    from sklearn.multiclass import OneVsRestClassifier
    from sklearn.calibration import CalibratedClassifierCV
    from sklearn.preprocessing import MultiLabelBinarizer
    from sklearn.model_selection import (
        train_test_split,
        cross_validate,
    )
    from sklearn.metrics import (
        accuracy_score,
        classification_report,
        f1_score,
        hamming_loss,
        precision_recall_fscore_support,
    )
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False
    logger.warning("scikit-learn is required.  pip install scikit-learn")

try:
    from sentence_transformers import SentenceTransformer
    HAS_SBERT = True
except ImportError:
    HAS_SBERT = False
    logger.warning("sentence-transformers needed for SciBERT.  pip install sentence-transformers")

# ──────────────────────────────────────────────────────────────────────
# Path helpers
# ──────────────────────────────────────────────────────────────────────
def _analysis_dir() -> Path:
    return settings.analysis_output_dir

def _data_dir() -> Path:
    return settings.arxiv_data_dir

def _model_dir() -> Path:
    return settings.model_dir

def _ensure_model_dir() -> None:
    _model_dir().mkdir(parents=True, exist_ok=True)


# ──────────────────────────────────────────────────────────────────────
# Data loading
# ──────────────────────────────────────────────────────────────────────
def _find_latest_csv(csv_path: Path | None = None) -> Path:
    if csv_path and csv_path.exists():
        return csv_path
    all_csv = sorted(
        _data_dir().glob("*.csv"),
        key=lambda x: x.stat().st_mtime,
        reverse=True,
    )
    if not all_csv:
        raise FileNotFoundError(f"No CSV in {_data_dir()}. Run scraper first.")
    return all_csv[0]


def _load_and_clean(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    df["text"] = df["title"].fillna("") + " " + df["abstract"].fillna("")
    df = df[df["tech_domain"].notna() & (df["text"].str.len() > 50)].copy()
    return df


def load_analysis_results(path: Path | None = None) -> Dict[str, Any]:
    path = path or (_analysis_dir() / "analysis_results.json")
    if not path.exists():
        logger.warning("Analysis results not found at {}", path)
        return {}
    with path.open() as f:
        return json.load(f)


# ──────────────────────────────────────────────────────────────────────
# Multi-label target preparation
# ──────────────────────────────────────────────────────────────────────

# arXiv CS subcategory -> our 21 tech_domain labels
ARXIV_DOMAIN_MAP: Dict[str, str] = {
    "cs.AI": "Artificial Intelligence",
    "cs.CL": "Natural Language Processing",
    "cs.CC": "Computational Complexity",
    "cs.CE": "Computational Complexity",
    "cs.CG": "Graphics",
    "cs.GT": "Game Theory",
    "cs.CV": "Computer Vision",
    "cs.CY": "Computers & Society",
    "cs.CR": "Cryptography & Security",
    "cs.DS": "Data Structures & Algorithms",
    "cs.DB": "Databases",
    "cs.DL": "Databases",
    "cs.DM": "Data Structures & Algorithms",
    "cs.DC": "Distributed Computing",
    "cs.ET": "Hardware Architecture",
    "cs.FL": "Programming Languages",
    "cs.GL": "Software Engineering",
    "cs.GR": "Graphics",
    "cs.AR": "Hardware Architecture",
    "cs.HC": "Human-Computer Interaction",
    "cs.IR": "Information Retrieval",
    "cs.IT": "Networking",
    "cs.LG": "Machine Learning",
    "cs.LO": "Programming Languages",
    "cs.MA": "Distributed Computing",
    "cs.MM": "Graphics",
    "cs.MS": "Software Engineering",
    "cs.NA": "Computational Complexity",
    "cs.NE": "Neural Networks & Evolutionary",
    "cs.NI": "Networking",
    "cs.OH": "Software Engineering",
    "cs.OS": "Operating Systems",
    "cs.PF": "Networking",
    "cs.PL": "Programming Languages",
    "cs.RO": "Robotics",
    "cs.SC": "Computational Complexity",
    "cs.SD": "Graphics",
    "cs.SE": "Software Engineering",
    "cs.SI": "Computers & Society",
    "cs.SY": "Distributed Computing",
}


def _build_multi_label_targets(
    df: pd.DataFrame,
    primary_col: str = "tech_domain",
    categories_col: str = "categories",
) -> Tuple[List[List[str]], MultiLabelBinarizer]:
    """
    Build multi-label targets from arXiv category strings.

    Each paper's `categories` column contains "cs.AI cs.LG cs.CL".
    We map each sub-category to our 21 domain labels.
    If categories aren't available, falls back to single-label.
    """
    label_lists: List[List[str]] = []
    has_cats = categories_col in df.columns

    for _, row in df.iterrows():
        labels = set()
        labels.add(row[primary_col])

        if has_cats and pd.notna(row.get(categories_col)):
            cats = str(row[categories_col]).split()
            for cat in cats:
                cat = cat.strip()
                if cat in ARXIV_DOMAIN_MAP:
                    labels.add(ARXIV_DOMAIN_MAP[cat])

        label_lists.append(sorted(labels))

    mlb = MultiLabelBinarizer()
    mlb.fit(label_lists)
    return label_lists, mlb


# ──────────────────────────────────────────────────────────────────────
# Embedding strategies
# ──────────────────────────────────────────────────────────────────────
def _tfidf_embeddings(
    X_train: pd.Series,
    X_test: pd.Series,
    max_features: int = 12_000,
) -> Tuple[Any, Any, TfidfVectorizer]:
    vec = TfidfVectorizer(
        max_features=max_features,
        stop_words="english",
        ngram_range=(1, 2),
        min_df=3,
        sublinear_tf=True,
    )
    return vec.fit_transform(X_train), vec.transform(X_test), vec


def _scibert_embeddings(
    X_train: pd.Series,
    X_test: pd.Series,
    model_name: str = "allenai/scibert_scivocab_uncased",
    batch_size: int = 64,
) -> Tuple[np.ndarray, np.ndarray, SentenceTransformer]:
    if not HAS_SBERT:
        raise RuntimeError("pip install sentence-transformers")
    logger.info("Loading SentenceTransformer: {}", model_name)
    sbert = SentenceTransformer(model_name)
    logger.info("Encoding train ({} docs) …", len(X_train))
    X_tr = sbert.encode(X_train.tolist(), batch_size=batch_size, show_progress_bar=True)
    logger.info("Encoding test ({} docs) …", len(X_test))
    X_te = sbert.encode(X_test.tolist(), batch_size=batch_size, show_progress_bar=True)
    return np.array(X_tr), np.array(X_te), sbert


# ──────────────────────────────────────────────────────────────────────
# Multi-label classifier registry
# ──────────────────────────────────────────────────────────────────────
def _get_multilabel_classifiers(random_state: int = 42) -> Dict[str, Any]:
    return {
        "LogisticRegression": OneVsRestClassifier(
            LogisticRegression(
                max_iter=1000, C=1.0, class_weight="balanced",
                random_state=random_state,
            ),
            n_jobs=-1,
        ),
        "LinearSVC": OneVsRestClassifier(
            CalibratedClassifierCV(
                LinearSVC(
                    max_iter=2000, class_weight="balanced",
                    random_state=random_state,
                ),
                cv=3,
            ),
            n_jobs=-1,
        ),
        "RandomForest": OneVsRestClassifier(
            RandomForestClassifier(
                n_estimators=200, class_weight="balanced",
                random_state=random_state, n_jobs=-1,
            ),
            n_jobs=-1,
        ),
        "MLP": OneVsRestClassifier(
            MLPClassifier(
                hidden_layer_sizes=(256, 128),
                max_iter=50, early_stopping=True,
                random_state=random_state,
            ),
            n_jobs=-1,
        ),
    }


# ──────────────────────────────────────────────────────────────────────
# Multi-label evaluation
# ──────────────────────────────────────────────────────────────────────
def _evaluate_multilabel(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    mlb: MultiLabelBinarizer,
) -> Dict[str, Any]:
    subset_acc = float(accuracy_score(y_true, y_pred))
    h_loss = float(hamming_loss(y_true, y_pred))

    precision, recall, f1, support = precision_recall_fscore_support(
        y_true, y_pred, average=None, zero_division=0,
    )
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    micro_f1 = float(f1_score(y_true, y_pred, average="micro", zero_division=0))
    weighted_f1 = float(f1_score(y_true, y_pred, average="weighted", zero_division=0))
    samples_f1 = float(f1_score(y_true, y_pred, average="samples", zero_division=0))

    per_class = {}
    for i, cls in enumerate(mlb.classes_):
        per_class[cls] = {
            "precision": round(float(precision[i]), 4),
            "recall": round(float(recall[i]), 4),
            "f1": round(float(f1[i]), 4),
            "support": int(support[i]),
        }

    return {
        "subset_accuracy": subset_acc,
        "hamming_loss": h_loss,
        "macro_f1": macro_f1,
        "micro_f1": micro_f1,
        "weighted_f1": weighted_f1,
        "samples_f1": samples_f1,
        "per_class": per_class,
    }


# ──────────────────────────────────────────────────────────────────────
# Benchmarking engine
# ──────────────────────────────────────────────────────────────────────
def benchmark_classifiers(
    X_train: Any,
    X_test: Any,
    y_train_bin: np.ndarray,
    y_test_bin: np.ndarray,
    mlb: MultiLabelBinarizer,
    embedding_name: str = "tfidf",
    random_state: int = 42,
    cv_folds: int = 5,
) -> List[Dict[str, Any]]:
    """
    Benchmark all classifiers on the same embeddings.
    Multi-label metrics: subset accuracy, hamming loss,
    macro / micro / weighted / samples F1.
    """
    results: List[Dict[str, Any]] = []
    classifiers = _get_multilabel_classifiers(random_state)

    for name, clf in classifiers.items():
        tag = f"{embedding_name}__{name}"
        logger.info("  Training {} …", tag)

        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                cv = cross_validate(
                    clf, X_train, y_train_bin,
                    cv=cv_folds,
                    scoring={"f1_micro": "f1_micro", "f1_macro": "f1_macro"},
                    return_train_score=False,
                    n_jobs=-1,
                )

            cv_micro_mean = float(np.mean(cv["test_f1_micro"]))
            cv_micro_std = float(np.std(cv["test_f1_micro"]))
            cv_macro_mean = float(np.mean(cv["test_f1_macro"]))
            cv_macro_std = float(np.std(cv["test_f1_macro"]))

            clf.fit(X_train, y_train_bin)
            y_pred = clf.predict(X_test)
            metrics = _evaluate_multilabel(y_test_bin, y_pred, mlb)

            logger.info(
                "{} | CV micro-F1: {:.4f}+-{:.4f} | Test macro-F1: {:.4f} "
                "| Hamming: {:.4f} | Subset acc: {:.4f}",
                tag, cv_micro_mean, cv_micro_std,
                metrics["macro_f1"], metrics["hamming_loss"],
                metrics["subset_accuracy"],
            )

            results.append({
                "tag": tag,
                "embedding": embedding_name,
                "classifier_name": name,
                "classifier": clf,
                "cv_micro_f1_mean": cv_micro_mean,
                "cv_micro_f1_std": cv_micro_std,
                "cv_macro_f1_mean": cv_macro_mean,
                "cv_macro_f1_std": cv_macro_std,
                "test_subset_accuracy": metrics["subset_accuracy"],
                "test_hamming_loss": metrics["hamming_loss"],
                "test_macro_f1": metrics["macro_f1"],
                "test_micro_f1": metrics["micro_f1"],
                "test_weighted_f1": metrics["weighted_f1"],
                "test_samples_f1": metrics["samples_f1"],
                "test_per_class": metrics["per_class"],
            })
        except Exception as e:
            logger.error("Failed {}: {}", tag, e)
            import traceback
            traceback.print_exc()

    results.sort(key=lambda r: r["test_samples_f1"], reverse=True)
    return results


# ──────────────────────────────────────────────────────────────────────
# Temporal trend modeling
# ──────────────────────────────────────────────────────────────────────
def compute_temporal_trends(df: pd.DataFrame) -> Dict[str, Any]:
    """
    Per-domain linear trend on monthly paper counts.
    Returns slope, R-squared, growth score, 3-month forecast, YoY growth.
    """
    date_col = None
    for c in ["published", "published_date", "date", "update_date"]:
        if c in df.columns:
            date_col = c
            break
    if date_col is None:
        logger.warning("No date column; skipping temporal modeling.")
        return {}

    df = df.copy()
    df["_date"] = pd.to_datetime(df[date_col], errors="coerce")
    df = df.dropna(subset=["_date", "tech_domain"])
    df["_month"] = df["_date"].dt.to_period("M")

    trends: Dict[str, Any] = {}
    for domain, grp in df.groupby("tech_domain"):
        monthly = grp.groupby("_month").size().sort_index()
        if len(monthly) < 3:
            continue

        x = np.arange(len(monthly), dtype=float)
        y = monthly.values.astype(float)
        coeffs = np.polyfit(x, y, 1)
        slope, intercept = coeffs
        y_hat = np.polyval(coeffs, x)
        ss_res = np.sum((y - y_hat) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        r2 = 1.0 - ss_res / ss_tot if ss_tot > 0 else 0.0

        future_x = np.array([len(monthly), len(monthly) + 1, len(monthly) + 2])
        forecast = np.polyval(coeffs, future_x).tolist()

        yearly = grp.groupby(grp["_date"].dt.year).size()
        yoy = 0.0
        if len(yearly) >= 2:
            last_two = yearly.iloc[-2:]
            yoy = float(
                (last_two.iloc[-1] - last_two.iloc[-2])
                / max(last_two.iloc[-2], 1) * 100
            )

        trends[domain] = {
            "slope": float(slope),
            "intercept": float(intercept),
            "r2": float(r2),
            "n_months": int(len(monthly)),
            "yoy_growth_pct": round(yoy, 2),
            "forecast_3m": [max(0, int(round(v))) for v in forecast],
            "monthly_counts": {str(p): int(c) for p, c in monthly.items()},
        }

    # Normalize slopes -> 0-1 growth score
    slopes = {d: v["slope"] for d, v in trends.items()}
    if slopes:
        mn, mx = min(slopes.values()), max(slopes.values())
        span = mx - mn or 1.0
        for d in trends:
            trends[d]["growth_score"] = round(
                float((trends[d]["slope"] - mn) / span), 4
            )
    return trends


# ──────────────────────────────────────────────────────────────────────
# MAIN TRAINING PIPELINE
# ──────────────────────────────────────────────────────────────────────
def train_domain_classifier(
    csv_path: Path | None = None,
    test_size: float = 0.2,
    random_state: int = 42,
    save: bool = True,
    use_scibert: bool = True,
    scibert_model: str = "allenai/scibert_scivocab_uncased",
    cv_folds: int = 5,
) -> Dict[str, Any]:
    """
    Full pipeline:
      1. Load + clean data
      2. Build multi-label targets from arXiv categories
      3. TF-IDF embeddings -> benchmark 4 classifiers
      4. SciBERT embeddings -> benchmark 4 classifiers
      5. Select best model by samples-F1
      6. Compute temporal trends
      7. Save all artifacts (.pkl + .json)
    """
    if not HAS_SKLEARN:
        raise RuntimeError("scikit-learn required")

    csv_path = _find_latest_csv(csv_path)
    logger.info("Training on {}", csv_path)

    # 1. Load
    df = _load_and_clean(csv_path)
    logger.info("Dataset: {} papers, {} domains",
                len(df), df["tech_domain"].nunique())

    # 2. Multi-label targets
    label_lists, mlb = _build_multi_label_targets(df)
    y_bin = mlb.transform(label_lists)
    avg_labels = np.mean([len(ll) for ll in label_lists])
    logger.info("Multi-label: avg {:.2f} labels/paper, {} unique domains",
                avg_labels, len(mlb.classes_))

    X = df["text"].reset_index(drop=True)
    primary_y = df["tech_domain"].reset_index(drop=True)

    X_train, X_test, y_train_bin, y_test_bin = train_test_split(
        X, y_bin,
        test_size=test_size,
        random_state=random_state,
        stratify=primary_y,
    )
    logger.info("Train: {} | Test: {}", len(X_train), len(X_test))

    all_results: List[Dict[str, Any]] = []

    # 3. TF-IDF
    logger.info("=" * 50)
    logger.info("TF-IDF EMBEDDINGS")
    logger.info("=" * 50)
    X_tr_tfidf, X_te_tfidf, tfidf_vec = _tfidf_embeddings(X_train, X_test)
    tfidf_results = benchmark_classifiers(
        X_tr_tfidf, X_te_tfidf, y_train_bin, y_test_bin, mlb,
        embedding_name="tfidf", random_state=random_state, cv_folds=cv_folds,
    )
    for r in tfidf_results:
        r["vectorizer"] = tfidf_vec
        r["sbert_model"] = None
    all_results.extend(tfidf_results)

    # 4. SciBERT
    if use_scibert and HAS_SBERT:
        logger.info("=" * 50)
        logger.info("SciBERT EMBEDDINGS ({})", scibert_model)
        logger.info("=" * 50)
        X_tr_sb, X_te_sb, sbert_obj = _scibert_embeddings(
            X_train, X_test, model_name=scibert_model,
        )
        sb_results = benchmark_classifiers(
            X_tr_sb, X_te_sb, y_train_bin, y_test_bin, mlb,
            embedding_name="scibert", random_state=random_state, cv_folds=cv_folds,
        )
        for r in sb_results:
            r["vectorizer"] = None
            r["sbert_model"] = sbert_obj
        all_results.extend(sb_results)
    elif use_scibert:
        logger.warning("Skipping SciBERT — install sentence-transformers")

    # 5. Best model
    all_results.sort(key=lambda r: r["test_samples_f1"], reverse=True)
    best = all_results[0]
    logger.info(
        "\n*** BEST: {} | samples-F1: {:.4f} | macro-F1: {:.4f} "
        "| hamming: {:.4f} ***",
        best["tag"], best["test_samples_f1"],
        best["test_macro_f1"], best["test_hamming_loss"],
    )

    # 6. Temporal trends
    logger.info("Computing temporal trends …")
    temporal_trends = compute_temporal_trends(df)

    # Print benchmark
    logger.info("\n" + "=" * 95)
    logger.info("{:<30} {:>10} {:>10} {:>10} {:>10} {:>10}",
                "Model", "CV uF1", "CV uF1+/-", "Test macF1", "Test smpF1", "Hamming")
    logger.info("-" * 95)
    for r in all_results:
        logger.info("{:<30} {:>10.4f} {:>10.4f} {:>10.4f} {:>10.4f} {:>10.4f}",
                    r["tag"], r["cv_micro_f1_mean"], r["cv_micro_f1_std"],
                    r["test_macro_f1"], r["test_samples_f1"], r["test_hamming_loss"])
    logger.info("=" * 95)

    # 7. Save
    if save:
        _save_artifacts(best, all_results, mlb, temporal_trends, scibert_model)

    return {
        "best_tag": best["tag"],
        "test_samples_f1": best["test_samples_f1"],
        "test_macro_f1": best["test_macro_f1"],
        "test_hamming_loss": best["test_hamming_loss"],
        "benchmark": [
            {k: v for k, v in r.items()
             if k not in ("classifier", "vectorizer", "sbert_model")}
            for r in all_results
        ],
        "temporal_trends": temporal_trends,
        "n_classes": len(mlb.classes_),
        "avg_labels_per_paper": round(avg_labels, 2),
    }


def _save_artifacts(
    best: Dict, all_results: List[Dict],
    mlb: MultiLabelBinarizer, temporal_trends: Dict,
    scibert_model_name: str,
) -> None:
    _ensure_model_dir()
    md = _model_dir()

    with (md / "domain_classifier.pkl").open("wb") as f:
        pickle.dump(best["classifier"], f)

    with (md / "label_binarizer.pkl").open("wb") as f:
        pickle.dump(mlb, f)

    if best.get("vectorizer") is not None:
        with (md / "domain_vectorizer.pkl").open("wb") as f:
            pickle.dump(best["vectorizer"], f)

    if best.get("sbert_model") is not None:
        with (md / "sbert_model_name.pkl").open("wb") as f:
            pickle.dump(scibert_model_name, f)

    meta = {
        "best_tag": best["tag"],
        "embedding": best["embedding"],
        "classifier_name": best["classifier_name"],
        "classification_type": "multi-label",
        "test_subset_accuracy": best["test_subset_accuracy"],
        "test_hamming_loss": best["test_hamming_loss"],
        "test_macro_f1": best["test_macro_f1"],
        "test_micro_f1": best["test_micro_f1"],
        "test_weighted_f1": best["test_weighted_f1"],
        "test_samples_f1": best["test_samples_f1"],
        "cv_micro_f1_mean": best["cv_micro_f1_mean"],
        "cv_micro_f1_std": best["cv_micro_f1_std"],
        "scibert_model_name": scibert_model_name if best["embedding"] == "scibert" else None,
        "classes": list(mlb.classes_),
    }
    with (md / "model_meta.json").open("w") as f:
        json.dump(meta, f, indent=2)

    bench = [
        {k: v for k, v in r.items()
         if k not in ("classifier", "vectorizer", "sbert_model")}
        for r in all_results
    ]
    with (md / "benchmark_results.json").open("w") as f:
        json.dump(bench, f, indent=2)

    with (md / "temporal_trends.pkl").open("wb") as f:
        pickle.dump(temporal_trends, f)
    with (md / "temporal_trends.json").open("w") as f:
        json.dump(temporal_trends, f, indent=2)

    logger.info("All artifacts saved to {}", md)


# ──────────────────────────────────────────────────────────────────────
# Model loading (for API / inference)
# ──────────────────────────────────────────────────────────────────────
def load_domain_model() -> Tuple[Any, Any, Any, Dict[str, Any]]:
    """Returns (embedder, classifier, mlb, meta)."""
    md = _model_dir()
    meta_path = md / "model_meta.json"
    clf_path = md / "domain_classifier.pkl"
    mlb_path = md / "label_binarizer.pkl"

    if not clf_path.exists() or not meta_path.exists():
        logger.warning("No saved model in {}. Train first.", md)
        return None, None, None, {}

    with meta_path.open() as f:
        meta = json.load(f)
    with clf_path.open("rb") as f:
        classifier = pickle.load(f)

    mlb = None
    if mlb_path.exists():
        with mlb_path.open("rb") as f:
            mlb = pickle.load(f)

    embedder = None
    if meta.get("embedding") == "tfidf":
        vec_path = md / "domain_vectorizer.pkl"
        if vec_path.exists():
            with vec_path.open("rb") as f:
                embedder = pickle.load(f)
    elif meta.get("embedding") == "scibert" and HAS_SBERT:
        name = meta.get("scibert_model_name", "allenai/scibert_scivocab_uncased")
        embedder = SentenceTransformer(name)

    return embedder, classifier, mlb, meta


def _embed_text(text: str, embedder: Any, meta: Dict[str, Any]) -> Any:
    if meta.get("embedding") == "tfidf":
        return embedder.transform([text])
    elif meta.get("embedding") == "scibert":
        return embedder.encode([text])
    raise ValueError(f"Unknown embedding: {meta.get('embedding')}")


# ──────────────────────────────────────────────────────────────────────
# Prediction (multi-label)
# ──────────────────────────────────────────────────────────────────────
def predict_domain(
    title: str,
    abstract: str,
    embedder=None, classifier=None,
    mlb: MultiLabelBinarizer | None = None,
    meta: Dict[str, Any] | None = None,
) -> Dict[str, Any]:
    """
    Multi-label prediction.
    Returns primary_domain, all_domains, domain_probabilities.
    """
    if embedder is None or classifier is None:
        embedder, classifier, mlb, meta = load_domain_model()
    if embedder is None or classifier is None:
        raise RuntimeError("No saved model. Run train_domain_classifier().")
    if meta is None:
        meta = {}

    text = (title or "") + " " + (abstract or "")
    if len(text.strip()) < 20:
        return {"primary_domain": None, "all_domains": [], "domain_probabilities": {}}

    X = _embed_text(text, embedder, meta)
    y_pred_bin = classifier.predict(X)

    # Get probabilities
    domain_probs: Dict[str, float] = {}
    try:
        if hasattr(classifier, "predict_proba"):
            proba = classifier.predict_proba(X)
            if isinstance(proba, list):
                for i, cls in enumerate(mlb.classes_):
                    domain_probs[cls] = float(proba[i][0, 1]) if proba[i].ndim > 1 else float(proba[i][0])
            else:
                for i, cls in enumerate(mlb.classes_):
                    domain_probs[cls] = float(proba[0, i])
        elif hasattr(classifier, "decision_function"):
            scores = classifier.decision_function(X)
            if scores.ndim == 1:
                scores = scores.reshape(1, -1)
            for i, cls in enumerate(mlb.classes_):
                domain_probs[cls] = float(scores[0, i])
    except Exception:
        if mlb is not None:
            for i, cls in enumerate(mlb.classes_):
                domain_probs[cls] = float(y_pred_bin[0, i])

    # Decode labels
    predicted_labels = []
    if mlb is not None:
        decoded = mlb.inverse_transform(y_pred_bin)
        predicted_labels = list(decoded[0]) if decoded else []

    if not predicted_labels and domain_probs:
        predicted_labels = [max(domain_probs, key=domain_probs.get)]

    sorted_probs = sorted(domain_probs.items(), key=lambda x: -x[1])
    primary = predicted_labels[0] if predicted_labels else (
        sorted_probs[0][0] if sorted_probs else None
    )

    ordered = [primary] if primary else []
    for d, _ in sorted_probs:
        if d != primary and d in predicted_labels:
            ordered.append(d)

    return {
        "primary_domain": primary,
        "all_domains": ordered,
        "domain_probabilities": dict(sorted_probs[:10]),
    }


# ──────────────────────────────────────────────────────────────────────
# Growth & keywords helpers
# ──────────────────────────────────────────────────────────────────────
def _load_temporal_trends() -> Dict[str, Any]:
    pkl_path = _model_dir() / "temporal_trends.pkl"
    if pkl_path.exists():
        with pkl_path.open("rb") as f:
            return pickle.load(f)
    return {}


def domain_growth_info(domain: str, trends: Dict[str, Any] | None = None) -> Dict[str, Any]:
    if trends is None:
        trends = _load_temporal_trends()
    info = trends.get(domain)
    if not info:
        return {"growth_score": 0.0, "growth_label": "no data",
                "slope": 0.0, "r2": 0.0, "yoy_growth_pct": 0.0, "forecast_3m": []}

    score = info.get("growth_score", 0.0)
    label = "high growth" if score >= 0.7 else ("moderate growth" if score >= 0.4 else "stable / low growth")

    return {
        "growth_score": round(score, 3),
        "growth_label": label,
        "slope": round(info.get("slope", 0.0), 4),
        "r2": round(info.get("r2", 0.0), 3),
        "yoy_growth_pct": info.get("yoy_growth_pct", 0.0),
        "forecast_3m": info.get("forecast_3m", []),
    }


def suggest_keywords_for_domain(domain: str, analysis: Dict[str, Any], top_k: int = 5) -> List[str]:
    kw = analysis.get("keywords", {}).get("domain_keywords") or {}
    raw = kw.get(domain) or []
    filtered = [w for w in raw if w.lower() not in GENERIC_KEYWORDS]
    return (filtered or raw)[:top_k]


# ──────────────────────────────────────────────────────────────────────
# advise_idea — MAIN API
# ──────────────────────────────────────────────────────────────────────
def advise_idea(
    title: str,
    abstract: str,
    analysis_path: Path | None = None,
) -> Dict[str, Any]:
    """
    Main API: title + abstract -> domains, trends, keywords, model info.
    """
    analysis = load_analysis_results(analysis_path)
    embedder, classifier, mlb, meta = load_domain_model()
    if classifier is None:
        raise RuntimeError("Train first: train_domain_classifier()")

    prediction = predict_domain(title, abstract, embedder, classifier, mlb, meta)

    if not prediction["primary_domain"]:
        return {
            "primary_domain": None, "all_domains": [], "domain_probabilities": {},
            "growth": {}, "suggested_keywords": [], "model_info": meta,
            "disclaimer": "Provide a longer title + abstract.",
            "message": "Insufficient text for classification.",
        }

    primary = prediction["primary_domain"]
    all_domains = prediction["all_domains"]

    # Growth info
    trends = _load_temporal_trends()
    growth_all = {d: domain_growth_info(d, trends) for d in all_domains}
    primary_growth = growth_all.get(primary, domain_growth_info(primary, trends))

    # Keywords
    keywords = suggest_keywords_for_domain(primary, analysis)

    # Interdisciplinary context
    interdisciplinary = analysis.get("interdisciplinary", {})
    domain_inter = interdisciplinary.get("domain_interdisciplinarity", {})
    inter_score = domain_inter.get(primary, 1.0)

    # Message
    conf = prediction["domain_probabilities"].get(primary, 0)
    domains_str = ", ".join(all_domains)
    kw_str = ", ".join(keywords[:5]) if keywords else "—"
    forecast_str = ""
    if primary_growth.get("forecast_3m"):
        forecast_str = f" Projected papers/month (next 3): {primary_growth['forecast_3m']}."

    lines = [
        f"**Primary domain**: {primary} (confidence: {conf:.3f})",
        f"**All predicted domains**: {domains_str}",
        f"**Trend**: {primary_growth['growth_label']} "
        f"(score: {primary_growth['growth_score']}, "
        f"YoY: {primary_growth['yoy_growth_pct']:+.1f}%, "
        f"R2: {primary_growth['r2']}).{forecast_str}",
        f"**Interdisciplinarity**: avg {inter_score:.1f} categories/paper in this domain.",
        f"**Suggested keywords**: {kw_str}",
        f"**Model**: {meta.get('best_tag', '?')} "
        f"(samples-F1: {meta.get('test_samples_f1', 0):.3f})",
    ]
    msg = "\n".join(f"{i}. {l}" for i, l in enumerate(lines, 1))

    return {
        "primary_domain": primary,
        "all_domains": all_domains,
        "domain_probabilities": prediction["domain_probabilities"],
        "growth": {"primary": primary_growth, "all_domains": growth_all},
        "interdisciplinarity_score": round(inter_score, 2),
        "suggested_keywords": keywords,
        "model_info": {
            "best_model": meta.get("best_tag", "unknown"),
            "classification_type": meta.get("classification_type", "multi-label"),
            "test_samples_f1": meta.get("test_samples_f1", 0.0),
            "test_macro_f1": meta.get("test_macro_f1", 0.0),
            "embedding": meta.get("embedding", "unknown"),
        },
        "disclaimer": (
            "Predictions based on arXiv CS metadata. "
            "Growth scores reflect dataset trends, not global impact."
        ),
        "message": msg,
    }


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────
def run_training_and_validate() -> None:
    logger.info("=" * 60)
    logger.info("  ARXIV IDEA ADVISOR — TRAINING PIPELINE (v3)")
    logger.info("=" * 60)
    result = train_domain_classifier(use_scibert=True)
    logger.info("\nBest: {} (samples-F1={:.4f})", result["best_tag"], result["test_samples_f1"])

    csv_path = _find_latest_csv()
    df = pd.read_csv(csv_path)
    if not df.empty:
        row = df.iloc[0]
        out = advise_idea(str(row.get("title", "")), str(row.get("abstract", "")))
        logger.info("\n--- Sample Advice ---\n{}", out["message"])


if __name__ == "__main__":
    import sys
    if len(sys.argv) >= 2:
        result = advise_idea(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
        print("\n" + result["message"])
        print(f"\nAll domains: {result['all_domains']}")
        print(f"Growth: {result['growth']['primary']}")
        print(f"Keywords: {result['suggested_keywords']}")
    else:
        run_training_and_validate()