"""
Model Evaluation & Report Generator
=====================================
Generates publication-quality figures and a summary report
for the arXiv Idea Advisor multi-label classifier.

Run AFTER train_domain_classifier() has saved artifacts.

Outputs (saved to analysis_output_dir):
  - benchmark_comparison.png      — bar chart of all 8 models
  - per_class_f1_heatmap.png      — heatmap of F1 per domain per model
  - multilabel_distribution.png   — histogram of labels per paper
  - confusion_analysis.png        — top confused domain pairs
  - temporal_forecast.png         — growth trends + 3-month forecast
  - evaluation_report.json        — machine-readable summary
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List

import numpy as np
import pandas as pd

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import matplotlib.gridspec as gridspec
    HAS_MPL = True
except ImportError:
    HAS_MPL = False

try:
    import seaborn as sns
    HAS_SNS = True
except ImportError:
    HAS_SNS = False

from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)


def _model_dir() -> Path:
    return settings.model_dir

def _output_dir() -> Path:
    d = settings.analysis_output_dir / "evaluation"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _load_benchmark() -> List[Dict[str, Any]]:
    p = _model_dir() / "benchmark_results.json"
    if not p.exists():
        raise FileNotFoundError(f"No benchmark results at {p}. Train first.")
    with p.open() as f:
        return json.load(f)


def _load_meta() -> Dict[str, Any]:
    p = _model_dir() / "model_meta.json"
    if not p.exists():
        return {}
    with p.open() as f:
        return json.load(f)


def _load_trends() -> Dict[str, Any]:
    p = _model_dir() / "temporal_trends.json"
    if not p.exists():
        return {}
    with p.open() as f:
        return json.load(f)


# ──────────────────────────────────────────────────────────────────
# 1. Benchmark comparison bar chart
# ──────────────────────────────────────────────────────────────────
def plot_benchmark_comparison(bench: List[Dict], out_dir: Path) -> None:
    """Side-by-side bar chart: macro-F1, micro-F1, samples-F1, hamming loss."""
    if not HAS_MPL:
        return

    tags = [r["tag"].replace("__", "\n") for r in bench]
    macro = [r["test_macro_f1"] for r in bench]
    micro = [r["test_micro_f1"] for r in bench]
    samples = [r["test_samples_f1"] for r in bench]
    hamming = [r["test_hamming_loss"] for r in bench]

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))

    # F1 scores
    x = np.arange(len(tags))
    w = 0.25
    axes[0].bar(x - w, macro, w, label="Macro F1", color="#2196F3")
    axes[0].bar(x, micro, w, label="Micro F1", color="#4CAF50")
    axes[0].bar(x + w, samples, w, label="Samples F1", color="#FF9800")
    axes[0].set_xticks(x)
    axes[0].set_xticklabels(tags, fontsize=8, ha="center")
    axes[0].set_ylabel("F1 Score")
    axes[0].set_title("Multi-Label F1 Scores by Model", fontweight="bold")
    axes[0].legend()
    axes[0].set_ylim(0, 1)
    axes[0].grid(axis="y", alpha=0.3)

    # Add value labels on best model
    best_idx = np.argmax(samples)
    axes[0].annotate(
        f"Best: {samples[best_idx]:.3f}",
        xy=(best_idx + w, samples[best_idx]),
        fontsize=9, fontweight="bold", color="#E65100",
        ha="center", va="bottom",
    )

    # Hamming loss (lower is better)
    colors = ["#E53935" if i != np.argmin(hamming) else "#43A047" for i in range(len(tags))]
    axes[1].bar(x, hamming, color=colors)
    axes[1].set_xticks(x)
    axes[1].set_xticklabels(tags, fontsize=8, ha="center")
    axes[1].set_ylabel("Hamming Loss (lower = better)")
    axes[1].set_title("Hamming Loss by Model", fontweight="bold")
    axes[1].grid(axis="y", alpha=0.3)

    plt.tight_layout()
    path = out_dir / "benchmark_comparison.png"
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    logger.info("Saved {}", path)


# ──────────────────────────────────────────────────────────────────
# 2. Per-class F1 heatmap
# ──────────────────────────────────────────────────────────────────
def plot_per_class_heatmap(bench: List[Dict], out_dir: Path) -> None:
    """Heatmap: rows = domains, columns = models, values = F1."""
    if not HAS_MPL or not HAS_SNS:
        return

    # Build matrix
    models = [r["tag"] for r in bench]
    all_classes = set()
    for r in bench:
        if "test_per_class" in r:
            all_classes.update(r["test_per_class"].keys())
    classes = sorted(all_classes)

    matrix = []
    for cls in classes:
        row = []
        for r in bench:
            f1 = r.get("test_per_class", {}).get(cls, {}).get("f1", 0)
            row.append(f1)
        matrix.append(row)

    df = pd.DataFrame(matrix, index=classes,
                       columns=[m.replace("__", "\n") for m in models])

    fig, ax = plt.subplots(figsize=(14, 10))
    sns.heatmap(
        df, annot=True, fmt=".2f", cmap="RdYlGn",
        vmin=0, vmax=1, ax=ax, linewidths=0.5,
        cbar_kws={"label": "F1 Score"},
    )
    ax.set_title("Per-Domain F1 Score Across All Models", fontsize=14, fontweight="bold")
    ax.set_xlabel("Model")
    ax.set_ylabel("Domain")
    plt.tight_layout()

    path = out_dir / "per_class_f1_heatmap.png"
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    logger.info("Saved {}", path)


# ──────────────────────────────────────────────────────────────────
# 3. CV confidence intervals
# ──────────────────────────────────────────────────────────────────
def plot_cv_confidence(bench: List[Dict], out_dir: Path) -> None:
    """Error bar plot showing CV mean +/- std for each model."""
    if not HAS_MPL:
        return

    tags = [r["tag"].replace("__", "\n") for r in bench]
    means = [r["cv_micro_f1_mean"] for r in bench]
    stds = [r["cv_micro_f1_std"] for r in bench]

    fig, ax = plt.subplots(figsize=(12, 5))
    x = np.arange(len(tags))

    colors = ["#1976D2" if "tfidf" in r["tag"] else "#E64A19" for r in bench]
    ax.barh(x, means, xerr=stds, color=colors, capsize=5, edgecolor="white")
    ax.set_yticks(x)
    ax.set_yticklabels(tags, fontsize=9)
    ax.set_xlabel("Cross-Validation Micro-F1 (mean +/- std)")
    ax.set_title("5-Fold CV with Confidence Intervals", fontweight="bold")
    ax.axvline(x=max(means), color="green", linestyle="--", alpha=0.5, label="Best")

    # Legend for embedding type
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor="#1976D2", label="TF-IDF"),
        Patch(facecolor="#E64A19", label="SciBERT"),
    ]
    ax.legend(handles=legend_elements, loc="lower right")
    ax.grid(axis="x", alpha=0.3)

    plt.tight_layout()
    path = out_dir / "cv_confidence_intervals.png"
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    logger.info("Saved {}", path)


# ──────────────────────────────────────────────────────────────────
# 4. Temporal forecasting visualization
# ──────────────────────────────────────────────────────────────────
def plot_temporal_forecasts(trends: Dict[str, Any], out_dir: Path, top_n: int = 6) -> None:
    """Per-domain time series + linear fit + 3-month forecast."""
    if not HAS_MPL or not trends:
        return

    # Pick top N by growth score
    sorted_domains = sorted(
        trends.items(),
        key=lambda x: x[1].get("growth_score", 0),
        reverse=True,
    )[:top_n]

    fig, axes = plt.subplots(2, 3, figsize=(18, 10))
    axes = axes.flatten()

    for idx, (domain, info) in enumerate(sorted_domains):
        ax = axes[idx]
        monthly = info.get("monthly_counts", {})
        if not monthly:
            continue

        periods = list(monthly.keys())
        counts = list(monthly.values())
        x = np.arange(len(counts))

        # Actual data
        ax.plot(x, counts, "o-", color="#1976D2", markersize=3, label="Actual")

        # Linear fit
        slope = info["slope"]
        intercept = info["intercept"]
        fit_y = [slope * xi + intercept for xi in x]
        ax.plot(x, fit_y, "--", color="#E53935", alpha=0.7, label=f"Fit (R2={info['r2']:.2f})")

        # Forecast
        forecast = info.get("forecast_3m", [])
        if forecast:
            fx = [len(x), len(x) + 1, len(x) + 2]
            ax.plot(fx, forecast, "s-", color="#FF9800", markersize=6, label="3-mo forecast")
            ax.axvspan(len(x) - 0.5, len(x) + 2.5, alpha=0.1, color="orange")

        ax.set_title(f"{domain}\n(growth: {info.get('growth_score', 0):.2f}, "
                     f"YoY: {info.get('yoy_growth_pct', 0):+.0f}%)",
                     fontsize=10, fontweight="bold")
        ax.legend(fontsize=7)
        ax.grid(alpha=0.3)

        # Show only a few x-tick labels
        n_ticks = min(6, len(periods))
        tick_indices = np.linspace(0, len(periods) - 1, n_ticks, dtype=int)
        ax.set_xticks(tick_indices)
        ax.set_xticklabels([periods[i][-7:] for i in tick_indices], fontsize=7, rotation=45)

    fig.suptitle("Temporal Trends & 3-Month Forecast (Top Growing Domains)",
                 fontsize=14, fontweight="bold")
    plt.tight_layout()
    path = out_dir / "temporal_forecast.png"
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    logger.info("Saved {}", path)


# ──────────────────────────────────────────────────────────────────
# 5. Growth score ranking
# ──────────────────────────────────────────────────────────────────
def plot_growth_ranking(trends: Dict[str, Any], out_dir: Path) -> None:
    """Horizontal bar chart of all domains ranked by growth score."""
    if not HAS_MPL or not trends:
        return

    data = sorted(
        [(d, v.get("growth_score", 0), v.get("yoy_growth_pct", 0))
         for d, v in trends.items()],
        key=lambda x: x[1],
    )
    domains = [d[0] for d in data]
    scores = [d[1] for d in data]
    yoy = [d[2] for d in data]

    fig, ax = plt.subplots(figsize=(10, 8))
    colors = plt.cm.RdYlGn(np.array(scores))
    bars = ax.barh(domains, scores, color=colors, edgecolor="white")

    # Annotate with YoY %
    for i, (s, y) in enumerate(zip(scores, yoy)):
        ax.text(s + 0.01, i, f"YoY: {y:+.0f}%", va="center", fontsize=8, color="#555")

    ax.set_xlabel("Growth Score (0-1)")
    ax.set_title("Domain Growth Ranking (Linear Trend)", fontweight="bold")
    ax.grid(axis="x", alpha=0.3)
    plt.tight_layout()

    path = out_dir / "growth_ranking.png"
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    logger.info("Saved {}", path)


# ──────────────────────────────────────────────────────────────────
# 6. Embedding comparison radar chart
# ──────────────────────────────────────────────────────────────────
def plot_embedding_comparison(bench: List[Dict], out_dir: Path) -> None:
    """Compare TF-IDF vs SciBERT averaged across classifiers."""
    if not HAS_MPL:
        return

    metrics = ["test_macro_f1", "test_micro_f1", "test_samples_f1",
               "test_weighted_f1", "test_subset_accuracy"]
    labels = ["Macro F1", "Micro F1", "Samples F1", "Weighted F1", "Subset Acc"]

    tfidf_avg = []
    scibert_avg = []
    for m in metrics:
        tfidf_vals = [r[m] for r in bench if r["embedding"] == "tfidf"]
        scibert_vals = [r[m] for r in bench if r["embedding"] == "scibert"]
        tfidf_avg.append(np.mean(tfidf_vals) if tfidf_vals else 0)
        scibert_avg.append(np.mean(scibert_vals) if scibert_vals else 0)

    if not any(scibert_avg):
        # No SciBERT results, skip
        return

    angles = np.linspace(0, 2 * np.pi, len(labels), endpoint=False).tolist()
    tfidf_avg += tfidf_avg[:1]
    scibert_avg += scibert_avg[:1]
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True))
    ax.plot(angles, tfidf_avg, "o-", linewidth=2, label="TF-IDF", color="#1976D2")
    ax.fill(angles, tfidf_avg, alpha=0.15, color="#1976D2")
    ax.plot(angles, scibert_avg, "s-", linewidth=2, label="SciBERT", color="#E64A19")
    ax.fill(angles, scibert_avg, alpha=0.15, color="#E64A19")

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(labels, fontsize=10)
    ax.set_ylim(0, 1)
    ax.set_title("TF-IDF vs SciBERT (Averaged Across Classifiers)",
                 fontsize=12, fontweight="bold", pad=20)
    ax.legend(loc="upper right", bbox_to_anchor=(1.3, 1.1))
    ax.grid(True)

    plt.tight_layout()
    path = out_dir / "embedding_comparison_radar.png"
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    logger.info("Saved {}", path)


# ──────────────────────────────────────────────────────────────────
# 7. Summary report (JSON)
# ──────────────────────────────────────────────────────────────────
def generate_summary_report(
    bench: List[Dict], meta: Dict, trends: Dict, out_dir: Path,
) -> Dict[str, Any]:
    """Machine-readable evaluation summary."""
    best = bench[0] if bench else {}

    # Find best per embedding type
    best_tfidf = next((r for r in bench if r["embedding"] == "tfidf"), {})
    best_scibert = next((r for r in bench if r["embedding"] == "scibert"), {})

    # Hardest / easiest domains
    per_class = best.get("test_per_class", {})
    if per_class:
        sorted_cls = sorted(per_class.items(), key=lambda x: x[1]["f1"])
        hardest = [(c, v["f1"]) for c, v in sorted_cls[:3]]
        easiest = [(c, v["f1"]) for c, v in sorted_cls[-3:]]
    else:
        hardest = easiest = []

    # Fastest growing domains
    growing = sorted(
        trends.items(),
        key=lambda x: x[1].get("growth_score", 0),
        reverse=True,
    )[:5]

    report = {
        "best_model": {
            "tag": best.get("tag"),
            "samples_f1": best.get("test_samples_f1"),
            "macro_f1": best.get("test_macro_f1"),
            "hamming_loss": best.get("test_hamming_loss"),
            "cv_micro_f1": f"{best.get('cv_micro_f1_mean', 0):.4f} +/- {best.get('cv_micro_f1_std', 0):.4f}",
        },
        "embedding_comparison": {
            "tfidf_best": {
                "tag": best_tfidf.get("tag"),
                "samples_f1": best_tfidf.get("test_samples_f1"),
            },
            "scibert_best": {
                "tag": best_scibert.get("tag"),
                "samples_f1": best_scibert.get("test_samples_f1"),
            },
        },
        "classification_type": "multi-label",
        "n_models_benchmarked": len(bench),
        "hardest_domains": hardest,
        "easiest_domains": easiest,
        "top_growing_domains": [
            {"domain": d, "growth_score": v.get("growth_score"),
             "yoy_pct": v.get("yoy_growth_pct")}
            for d, v in growing
        ],
        "all_model_rankings": [
            {"rank": i + 1, "tag": r["tag"],
             "samples_f1": round(r.get("test_samples_f1", 0), 4),
             "macro_f1": round(r.get("test_macro_f1", 0), 4),
             "hamming": round(r.get("test_hamming_loss", 0), 4)}
            for i, r in enumerate(bench)
        ],
    }

    path = out_dir / "evaluation_report.json"
    with path.open("w") as f:
        json.dump(report, f, indent=2)
    logger.info("Saved {}", path)
    return report


# ──────────────────────────────────────────────────────────────────
# Main runner
# ──────────────────────────────────────────────────────────────────
def generate_full_evaluation() -> None:
    """Generate all evaluation plots and report."""
    logger.info("=" * 60)
    logger.info("  GENERATING EVALUATION REPORT")
    logger.info("=" * 60)

    bench = _load_benchmark()
    meta = _load_meta()
    trends = _load_trends()
    out = _output_dir()

    logger.info("Found {} benchmark results", len(bench))
    logger.info("Output directory: {}", out)

    # Sort by best
    bench.sort(key=lambda r: r.get("test_samples_f1", 0), reverse=True)

    # Generate all plots
    plot_benchmark_comparison(bench, out)
    plot_per_class_heatmap(bench, out)
    plot_cv_confidence(bench, out)
    plot_temporal_forecasts(trends, out)
    plot_growth_ranking(trends, out)
    plot_embedding_comparison(bench, out)

    # Summary report
    report = generate_summary_report(bench, meta, trends, out)

    logger.info("\n" + "=" * 60)
    logger.info("  EVALUATION COMPLETE")
    logger.info("=" * 60)
    logger.info("Best model: {}", report["best_model"]["tag"])
    logger.info("  Samples F1: {}", report["best_model"]["samples_f1"])
    logger.info("  Macro F1:   {}", report["best_model"]["macro_f1"])
    logger.info("  Hamming:    {}", report["best_model"]["hamming_loss"])
    logger.info("\nHardest domains: {}", report["hardest_domains"])
    logger.info("Easiest domains: {}", report["easiest_domains"])
    logger.info("\nTop growing: {}", [d["domain"] for d in report["top_growing_domains"]])
    logger.info("\nAll outputs in: {}", out)


if __name__ == "__main__":
    generate_full_evaluation()
