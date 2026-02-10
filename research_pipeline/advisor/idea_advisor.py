"""
Idea Advisor for Tech / arXiv
=============================
Answers:
- Is my idea trending?
- Which domain does it fit?
- How can I shape it for arXiv (tech)?

This module is a refactored version of the original `idea_advisor.py` that:
- Uses shared config for paths and models
- Uses shared constants for generic keyword filtering
- Is safe to call from both CLI scripts and the API layer.
"""

from __future__ import annotations

import json
import pickle
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

from backend.core.constants import GENERIC_KEYWORDS
from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)

try:  # pragma: no cover - dependency check
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import (
        accuracy_score,
        classification_report,
        f1_score,
    )

    HAS_SKLEARN = True
except ImportError:  # pragma: no cover
    HAS_SKLEARN = False
    logger.warning(
        "scikit-learn is required for the domain classifier. "
        "Install it with: pip install scikit-learn"
    )


def _analysis_dir() -> Path:
    return settings.analysis_output_dir


def _data_dir() -> Path:
    return settings.arxiv_data_dir


def _model_dir() -> Path:
    return settings.model_dir


def _ensure_model_dir() -> None:
    _model_dir().mkdir(parents=True, exist_ok=True)


def load_analysis_results(path: Path | None = None) -> Dict[str, Any]:
    """Load precomputed temporal + keyword analysis (from arxiv_analysis.py)."""
    path = path or (_analysis_dir() / "analysis_results.json")
    if not path.exists():
        logger.warning("Analysis results not found at {}", path)
        return {}
    with path.open() as f:
        return json.load(f)


def _normalize_growth(growth_rates: Dict[str, float]) -> Dict[str, float]:
    """Cap inf and normalize growth rates to 0-1 for scoring."""
    if not growth_rates:
        return {}

    vals = [float(v) if np.isfinite(v) else 50.0 for v in growth_rates.values()]
    mn, mx = min(vals), max(vals)
    span = mx - mn or 1.0
    return {
        k: (float(v) if np.isfinite(v) else 50.0 - mn) / span for k, v in growth_rates.items()
    }


def train_domain_classifier(
    csv_path: Path | None = None,
    test_size: float = 0.2,
    random_state: int = 42,
    save: bool = True,
) -> Dict[str, Any]:
    """
    Train (title + abstract) -> tech_domain. Returns metrics and saves model + vectorizer.
    """
    if not HAS_SKLEARN:  # pragma: no cover
        raise RuntimeError("scikit-learn is required for the domain classifier")

    if csv_path is None:
        all_csv = sorted(
            _data_dir().glob("*.csv"),
            key=lambda x: x.stat().st_mtime,
            reverse=True,
        )
        csv_path = all_csv[0] if all_csv else None
    if not csv_path or not csv_path.exists():
        raise FileNotFoundError(
            f"No CSV found in data directory {_data_dir()}. Run the scraper first."
        )

    logger.info("Training domain classifier on {}", csv_path)
    df = pd.read_csv(csv_path)
    df["text"] = df["title"].fillna("") + " " + df["abstract"].fillna("")
    df = df[df["tech_domain"].notna() & (df["text"].str.len() > 50)]

    X = df["text"]
    y = df["tech_domain"]

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=test_size,
        random_state=random_state,
        stratify=y,
    )

    vectorizer = TfidfVectorizer(
        max_features=8000,
        stop_words="english",
        ngram_range=(1, 2),
        min_df=3,
    )
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec = vectorizer.transform(X_test)

    clf = LogisticRegression(
        max_iter=500,
        class_weight="balanced",
        random_state=random_state,
    )
    clf.fit(X_train_vec, y_train)

    y_pred = clf.predict(X_test_vec)
    acc = float(accuracy_score(y_test, y_pred))
    f1 = float(f1_score(y_test, y_pred, average="macro"))

    logger.info("Domain classifier – validation metrics:\n{}", classification_report(y_test, y_pred))
    logger.info("Accuracy: {:.4f}  Macro F1: {:.4f}", acc, f1)

    if save:
        _ensure_model_dir()
        v_path = _model_dir() / "domain_vectorizer.pkl"
        c_path = _model_dir() / "domain_classifier.pkl"
        with v_path.open("wb") as f:
            pickle.dump(vectorizer, f)
        with c_path.open("wb") as f:
            pickle.dump(clf, f)
        logger.info("Saved domain model and vectorizer to {}", _model_dir())

    return {
        "accuracy": acc,
        "macro_f1": f1,
        "vectorizer": vectorizer,
        "classifier": clf,
    }


def load_domain_model() -> Tuple[Any | None, Any | None]:
    """Load saved vectorizer and classifier."""
    v_path = _model_dir() / "domain_vectorizer.pkl"
    c_path = _model_dir() / "domain_classifier.pkl"
    if not v_path.exists() or not c_path.exists():
        logger.warning(
            "Domain model files not found in {}. "
            "Train the model first via train_domain_classifier().",
            _model_dir(),
        )
        return None, None
    with v_path.open("rb") as f:
        vectorizer = pickle.load(f)
    with c_path.open("rb") as f:
        classifier = pickle.load(f)
    return vectorizer, classifier


def predict_domain(
    title: str,
    abstract: str,
    vectorizer=None,
    classifier=None,
) -> Tuple[Optional[str], Dict[str, float]]:
    """Predict tech domain for an idea (title + abstract)."""
    if vectorizer is None or classifier is None:
        vectorizer, classifier = load_domain_model()
    if vectorizer is None or classifier is None:
        raise RuntimeError("No saved domain model. Run train_domain_classifier() first.")

    text = (title or "") + " " + (abstract or "")
    if len(text.strip()) < 20:
        return None, {}
    X = vectorizer.transform([text])
    pred = classifier.predict(X)[0]
    probs = classifier.predict_proba(X)[0]
    classes = classifier.classes_
    top_probs = sorted(zip(classes, probs), key=lambda x: -x[1])[:5]
    return pred, {label: float(p) for label, p in top_probs}


def domain_growth_score(domain: str, analysis: Dict[str, Any]) -> float:
    """
    0–1 score: how much did this *category* grow on arXiv in our dataset.
    Uses growth_rates and emerging_domains from temporal analysis.
    """
    temporal = analysis.get("temporal", {})
    growth = temporal.get("growth_rates") or {}
    emerging = temporal.get("emerging_domains") or {}

    growth_norm = _normalize_growth(growth)
    emergence_norm = _normalize_growth(emerging) if emerging else {}

    g = growth_norm.get(domain, 0.0)
    e = emergence_norm.get(domain, 0.0)
    # Combine: 0.5 * growth + 0.5 * emergence, then clamp
    raw = 0.5 * g + 0.5 * e
    return float(min(1.0, max(0.0, raw)))


def suggest_keywords_for_domain(
    domain: str,
    analysis: Dict[str, Any],
    top_k: int = 5,
) -> List[str]:
    """Suggest keywords to align with for this domain (from our TF-IDF analysis)."""
    kw = analysis.get("keywords", {}).get("domain_keywords") or {}
    raw = kw.get(domain) or []
    filtered = [w for w in raw if w.lower() not in GENERIC_KEYWORDS]
    return (filtered or raw)[:top_k]


def advise_idea(
    title: str,
    abstract: str,
    analysis_path: Path | None = None,
) -> Dict[str, Any]:
    """
    Main API: give title + abstract, get domain, trending score, and reshaping suggestions.
    """
    analysis = load_analysis_results(analysis_path)
    vectorizer, classifier = load_domain_model()
    if classifier is None:
        raise RuntimeError("Train the domain model first: train_domain_classifier()")

    domain, domain_probs = predict_domain(title, abstract, vectorizer, classifier)
    if not domain:
        return {
            "domain": None,
            "domain_confidence": 0.0,
            "alternate_domains": [],
            "domain_growth_score": 0.0,
            "domain_growth_label": "insufficient text to classify",
            "disclaimer": "Provide a longer title/abstract for reliable advice.",
            "suggested_keywords": [],
            "message": "Please provide more detail (title + abstract) for meaningful advice.",
        }

    growth = domain_growth_score(domain, analysis)
    keywords = suggest_keywords_for_domain(domain, analysis)

    sorted_probs = sorted(domain_probs.items(), key=lambda x: -x[1])
    alternate_domains = [(d, float(p)) for d, p in sorted_probs[1:4] if d != domain]

    if growth >= 0.6:
        growth_label = "high growth on arXiv"
    elif growth >= 0.35:
        growth_label = "moderate growth on arXiv"
    else:
        growth_label = "lower growth on arXiv (in our dataset)"

    disclaimer = (
        "This is category growth in our dataset of arXiv tech papers, "
        "not a global \"hot topic\" measure."
    )

    kw_str = ", ".join(keywords[:5]) if keywords else "—"
    alt_str = "; ".join(f"{d} ({p:.2f})" for d, p in alternate_domains[:3])

    msg = f"Your idea fits best in **{domain}** (confidence: {domain_probs.get(domain, 0):.2f}). "
    if alternate_domains:
        msg += f"Also close: {alt_str}. "
    msg += (
        f"This category has **{growth_label}**. "
        f"Consider emphasizing: {kw_str}."
    )

    return {
        "domain": domain,
        "domain_confidence": float(domain_probs.get(domain, 0.0)),
        "alternate_domains": alternate_domains,
        "domain_growth_score": round(growth, 3),
        "domain_growth_label": growth_label,
        "disclaimer": disclaimer,
        "suggested_keywords": keywords,
        "message": msg,
    }


def run_training_and_validate() -> None:
    """Train the domain model and run a quick sanity check on trending score."""
    logger.info("Training domain classifier on arXiv tech data …")
    train_domain_classifier()

    logger.info("Loading analysis for trending score …")
    analysis = load_analysis_results()
    if analysis:
        for d in ["Robotics", "Graphics", "Artificial Intelligence"]:
            s = domain_growth_score(d, analysis)
            logger.info("Domain growth score for '{}': {:.3f}", d, s)
    else:
        logger.warning("No analysis_results.json found; run arxiv_analysis.py first.")

    logger.info("Example: advise one paper from the dataset …")
    all_csv = sorted(
        _data_dir().glob("*.csv"),
        key=lambda x: x.stat().st_mtime,
        reverse=True,
    )
    csv_path = all_csv[0] if all_csv else None
    if csv_path:
        df = pd.read_csv(csv_path)
        if not df.empty:
            row = df.iloc[0]
            out = advise_idea(
                str(row.get("title", "")),
                str(row.get("abstract", "")),
                _analysis_dir() / "analysis_results.json",
            )
            for k, v in out.items():
                logger.info("   {}: {}", k, v)


if __name__ == "__main__":  # pragma: no cover - manual CLI usage
    import sys

    if len(sys.argv) >= 2:
        title_arg = sys.argv[1]
        abstract_arg = sys.argv[2] if len(sys.argv) > 2 else ""
        result = advise_idea(title_arg, abstract_arg)
        print("\n" + result["message"])
        if result.get("alternate_domains"):
            print(
                "\nOther likely domains:",
                [d for d, _ in result["alternate_domains"]],
            )
        print(
            f"\nDomain growth on arXiv: {result['domain_growth_score']} "
            f"— {result['domain_growth_label']}"
        )
        print("Note:", result.get("disclaimer", ""))
        print("Suggested keywords:", result["suggested_keywords"])
    else:
        run_training_and_validate()

