"""
Tech Papers Analysis Pipeline
==============================
Analyzes collected arXiv data for:
- Temporal trends (topic evolution over years)
- Semantic clustering (grouping similar papers)
- Cross-domain analysis (interdisciplinary overlap)
- Emerging topic detection

Refactored to:
- Use shared configuration for paths and feature flags
- Use structured logging instead of prints where appropriate
- Be callable from both CLI scripts and the API layer
"""

from __future__ import annotations

import json
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

import numpy as np
import pandas as pd

from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)

# Optional imports - will check availability
try:  # pragma: no cover - optional dependency
    from sentence_transformers import SentenceTransformer

    HAS_EMBEDDINGS = True
except ImportError:  # pragma: no cover - handled gracefully
    HAS_EMBEDDINGS = False
    logger.warning(
        "sentence-transformers not installed. "
        "Install it to enable semantic clustering (pip install sentence-transformers)."
    )

try:  # pragma: no cover - optional dependency
    from sklearn.cluster import KMeans
    from sklearn.decomposition import PCA
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.manifold import TSNE

    HAS_SKLEARN = True
except ImportError:  # pragma: no cover
    HAS_SKLEARN = False
    logger.warning(
        "scikit-learn not installed. "
        "Install it to enable TF-IDF keywords and clustering (pip install scikit-learn)."
    )

try:  # pragma: no cover - plotting often skipped in tests
    import matplotlib.pyplot as plt
    import seaborn as sns  # noqa: F401

    HAS_PLOTTING = True
except ImportError:  # pragma: no cover
    HAS_PLOTTING = False
    logger.warning(
        "matplotlib/seaborn not installed. "
        "Install them to enable plotting (pip install matplotlib seaborn)."
    )


# =============================================================================
# DATA LOADING
# =============================================================================


def load_data(filepath: str | Path) -> pd.DataFrame:
    """Load the collected arxiv data."""
    df = pd.read_csv(filepath)
    logger.info("Loaded {:,} papers from {}", len(df), filepath)
    logger.info(
        "Year range: {} - {}, Domains: {}",
        df["year"].min(),
        df["year"].max(),
        df["tech_domain"].nunique(),
    )
    return df


# =============================================================================
# TEMPORAL ANALYSIS
# =============================================================================


def analyze_temporal_trends(
    df: pd.DataFrame,
    output_dir: Path | None = None,
) -> Dict[str, Any]:
    """
    Analyze how different tech domains evolved over time.
    """
    logger.info("Starting temporal trend analysis …")

    # Papers per year
    yearly_counts = df.groupby("year").size()
    logger.info("Papers per year (last 10 years):\n{}", yearly_counts.tail(10))

    # Domain evolution over time
    domain_year = df.groupby(["year", "tech_domain"]).size().unstack(fill_value=0)

    # Calculate year-over-year growth rates
    growth_rates = domain_year.pct_change().mean() * 100
    logger.info(
        "Average yearly growth rate by domain (top 10):\n{}",
        growth_rates.sort_values(ascending=False).head(10),
    )

    # Find emerging domains (high recent growth)
    recent_years = domain_year.tail(5)
    older_years = domain_year.head(5)

    recent_avg = recent_years.mean()
    older_avg = older_years.mean()

    emergence_ratio = (recent_avg / older_avg.replace(0, 1)).sort_values(
        ascending=False
    )
    logger.info(
        "Emerging domains (recent vs early activity ratio, top 10):\n{}",
        emergence_ratio.head(10),
    )
    logger.info(
        "Declining domains (bottom 5):\n{}", emergence_ratio.tail(5)
    )

    # Plot if available
    if HAS_PLOTTING and settings.enable_plotting and output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))

        # Plot 1: Overall trend
        yearly_counts.plot(ax=axes[0, 0], marker="o")
        axes[0, 0].set_title("Total Papers Per Year")
        axes[0, 0].set_xlabel("Year")
        axes[0, 0].set_ylabel("Number of Papers")

        # Plot 2: Top domains over time
        top_domains = df["tech_domain"].value_counts().head(6).index
        domain_year[top_domains].plot(ax=axes[0, 1], marker="o")
        axes[0, 1].set_title("Top Domains Over Time")
        axes[0, 1].legend(bbox_to_anchor=(1.05, 1), loc="upper left")

        # Plot 3: Domain distribution (recent)
        recent_dist = df[df["year"] >= 2020]["tech_domain"].value_counts()
        recent_dist.plot(kind="barh", ax=axes[1, 0])
        axes[1, 0].set_title("Domain Distribution (2020+)")

        # Plot 4: Growth rates
        growth_rates.sort_values().plot(kind="barh", ax=axes[1, 1])
        axes[1, 1].set_title("Avg Yearly Growth Rate (%)")

        plt.tight_layout()
        out_path = output_dir / "temporal_analysis.png"
        plt.savefig(out_path, dpi=150, bbox_inches="tight")
        logger.info("Saved temporal analysis plot to {}", out_path)

    return {
        "yearly_counts": yearly_counts.to_dict(),
        "domain_evolution": domain_year.to_dict(),
        "growth_rates": growth_rates.to_dict(),
        "emerging_domains": emergence_ratio.head(5).to_dict(),
    }


# =============================================================================
# SEMANTIC ANALYSIS
# =============================================================================


def extract_keywords_tfidf(
    df: pd.DataFrame,
    n_keywords: int = 20,
) -> Dict[str, Any]:
    """
    Extract important keywords using TF-IDF.
    """
    if not HAS_SKLEARN:  # pragma: no cover - dependency check
        logger.warning("scikit-learn required for keyword extraction")
        return {}

    logger.info("Starting TF-IDF keyword extraction …")

    # Combine title and abstract
    df = df.copy()
    df["text"] = df["title"] + " " + df["abstract"].fillna("")

    vectorizer = TfidfVectorizer(
        max_features=1000,
        stop_words="english",
        ngram_range=(1, 2),
        min_df=5,
    )

    tfidf_matrix = vectorizer.fit_transform(df["text"])
    feature_names = vectorizer.get_feature_names_out()

    # Get top keywords overall
    mean_tfidf = np.asarray(tfidf_matrix.mean(axis=0)).flatten()
    top_indices = mean_tfidf.argsort()[-n_keywords:][::-1]

    logger.info("Top {} TF-IDF keywords (overall):", n_keywords)
    for idx in top_indices:
        logger.info("  {}: {:.4f}", feature_names[idx], float(mean_tfidf[idx]))

    # Keywords by domain
    domain_keywords: Dict[str, Any] = {}
    for domain in df["tech_domain"].dropna().unique():
        domain_mask = (df["tech_domain"] == domain).values
        if not domain_mask.any():
            continue
        domain_tfidf = tfidf_matrix[domain_mask].mean(axis=0)
        domain_tfidf = np.asarray(domain_tfidf).flatten()

        top_idx = domain_tfidf.argsort()[-10:][::-1]
        domain_keywords[domain] = [feature_names[i] for i in top_idx]

    logger.info("Computed TF-IDF keywords for {} domains", len(domain_keywords))

    return {
        "top_keywords": [feature_names[i] for i in top_indices],
        "domain_keywords": domain_keywords,
    }


def semantic_clustering(
    df: pd.DataFrame,
    n_clusters: int = 15,
    output_dir: Path | None = None,
) -> Dict[str, Any]:
    """
    Cluster papers semantically using embeddings.
    """
    if not (HAS_EMBEDDINGS and HAS_SKLEARN):  # pragma: no cover
        logger.warning(
            "sentence-transformers and scikit-learn required for clustering; "
            "skipping semantic clustering."
        )
        return {}

    logger.info("Starting semantic clustering into {} clusters …", n_clusters)

    # Sample if too large (embeddings are slow)
    if len(df) > 10_000:
        logger.info(
            "Sampling 10,000 papers for clustering (from {:,})", len(df)
        )
        df_sample = df.sample(n=10_000, random_state=42)
    else:
        df_sample = df.copy()

    texts = (df_sample["title"] + ". " + df_sample["abstract"].fillna("")).tolist()

    logger.info("Loading embedding model …")
    model = SentenceTransformer("all-MiniLM-L6-v2")

    logger.info("Generating embeddings (this may take a while) …")
    embeddings = model.encode(texts, show_progress_bar=True, batch_size=32)

    logger.info("Clustering into {} groups …", n_clusters)
    kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
    df_sample["cluster"] = kmeans.fit_predict(embeddings)

    # Analyze clusters
    cluster_analysis = []
    for cluster_id in range(n_clusters):
        cluster_papers = df_sample[df_sample["cluster"] == cluster_id]
        if cluster_papers.empty:
            continue

        top_domains = cluster_papers["tech_domain"].value_counts().head(3)
        sample_titles = cluster_papers["title"].head(3).tolist()

        all_words = " ".join(cluster_papers["title"].tolist()).lower().split()
        word_freq = Counter(all_words)
        stopwords = {
            "a",
            "an",
            "the",
            "for",
            "of",
            "in",
            "to",
            "and",
            "with",
            "on",
            "using",
            "based",
            "via",
        }
        common_words = [
            w
            for w, _ in word_freq.most_common(20)
            if w not in stopwords and len(w) > 2
        ][:5]

        cluster_info = {
            "cluster_id": cluster_id,
            "size": int(len(cluster_papers)),
            "top_domains": top_domains.to_dict(),
            "keywords": common_words,
            "sample_titles": sample_titles,
        }
        cluster_analysis.append(cluster_info)

        logger.info(
            "Cluster {} ({} papers): keywords={}, top_domains={}",
            cluster_id,
            len(cluster_papers),
            ", ".join(common_words),
            ", ".join(top_domains.index[:2]),
        )

    # Visualize if plotting available
    if HAS_PLOTTING and settings.enable_plotting and output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        logger.info("Creating clustering visualizations …")

        pca = PCA(n_components=50)
        embeddings_pca = pca.fit_transform(embeddings)

        tsne = TSNE(n_components=2, random_state=42, perplexity=30)
        embeddings_2d = tsne.fit_transform(embeddings_pca)

        # Cluster-colored
        plt.figure(figsize=(14, 10))
        scatter = plt.scatter(
            embeddings_2d[:, 0],
            embeddings_2d[:, 1],
            c=df_sample["cluster"],
            cmap="tab20",
            alpha=0.6,
            s=10,
        )
        plt.colorbar(scatter, label="Cluster")
        plt.title("Semantic Clustering of Tech Papers (t-SNE projection)")
        plt.xlabel("Dimension 1")
        plt.ylabel("Dimension 2")

        out_clusters = output_dir / "semantic_clusters.png"
        plt.savefig(out_clusters, dpi=150, bbox_inches="tight")
        logger.info("Saved cluster plot to {}", out_clusters)

        # Domain-colored
        plt.figure(figsize=(14, 10))
        domain_codes = pd.Categorical(df_sample["tech_domain"]).codes
        scatter = plt.scatter(
            embeddings_2d[:, 0],
            embeddings_2d[:, 1],
            c=domain_codes,
            cmap="tab20",
            alpha=0.6,
            s=10,
        )
        plt.title("Papers by Domain (t-SNE projection)")
        plt.xlabel("Dimension 1")
        plt.ylabel("Dimension 2")

        out_domains = output_dir / "domain_distribution.png"
        plt.savefig(out_domains, dpi=150, bbox_inches="tight")
        logger.info("Saved domain distribution plot to {}", out_domains)

    return {
        "n_clusters": n_clusters,
        "cluster_analysis": cluster_analysis,
    }


# =============================================================================
# CROSS-DOMAIN ANALYSIS
# =============================================================================


def analyze_interdisciplinary(
    df: pd.DataFrame,
    output_dir: Path | None = None,
) -> Dict[str, Any]:
    """
    Analyze cross-domain/interdisciplinary patterns.
    """
    logger.info("Starting interdisciplinary analysis …")

    df = df.copy()
    df["category_count"] = df["all_categories"].apply(
        lambda x: len(str(x).split(", "))
    )

    multi_cat = df[df["category_count"] > 1]
    share_multi = float(len(multi_cat) / len(df)) if len(df) else 0.0
    logger.info(
        "Papers with multiple categories: {:,} ({:.1f}%)",
        len(multi_cat),
        share_multi * 100.0,
    )

    # Interdisciplinary trend over time
    yearly_multi = df.groupby("year")["category_count"].apply(
        lambda x: (x > 1).mean() * 100
    )
    logger.info(
        "Interdisciplinary rate over time (last 10 years):\n{}",
        yearly_multi.tail(10),
    )

    # Which domains are most interdisciplinary?
    domain_inter = (
        df.groupby("tech_domain")["category_count"]
        .mean()
        .sort_values(ascending=False)
    )
    logger.info(
        "Most interdisciplinary domains (top 10):\n{}",
        domain_inter.head(10),
    )

    if HAS_PLOTTING and settings.enable_plotting and output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        import matplotlib.pyplot as plt  # local alias

        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        yearly_multi.plot(ax=axes[0], marker="o")
        axes[0].set_title("Interdisciplinary Rate Over Time")
        axes[0].set_ylabel("% Papers with 2+ Categories")
        axes[0].set_xlabel("Year")

        domain_inter.plot(kind="barh", ax=axes[1])
        axes[1].set_title("Interdisciplinarity by Domain")
        axes[1].set_xlabel("Avg Categories per Paper")

        plt.tight_layout()
        out_path = output_dir / "interdisciplinary_analysis.png"
        plt.savefig(out_path, dpi=150, bbox_inches="tight")
        logger.info("Saved interdisciplinary analysis plot to {}", out_path)

    return {
        "multi_category_rate": share_multi,
        "yearly_trend": yearly_multi.to_dict(),
        "domain_interdisciplinarity": domain_inter.to_dict(),
    }


# =============================================================================
# GENERATE FULL REPORT
# =============================================================================


def generate_full_report(
    df: pd.DataFrame,
    output_dir: Path | None = None,
    run_clustering: bool | None = None,
) -> Dict[str, Any]:
    """
    Run all analyses and generate a comprehensive report.

    Args:
        df: DataFrame with arXiv papers.
        output_dir: Directory where analysis artifacts are written.
                    Defaults to `settings.analysis_output_dir`.
        run_clustering: Whether to run semantic clustering.
                        Defaults to `settings.enable_analysis_embeddings`.
    """
    output_path = output_dir or settings.analysis_output_dir
    output_path = Path(output_path)
    output_path.mkdir(parents=True, exist_ok=True)

    if run_clustering is None:
        run_clustering = settings.enable_analysis_embeddings

    logger.info(
        "Starting full analysis pipeline on {:,} papers. Output dir: {}",
        len(df),
        output_path,
    )

    results: Dict[str, Any] = {}

    # 1. Temporal Analysis
    results["temporal"] = analyze_temporal_trends(df, output_path)

    # 2. Keyword Extraction
    results["keywords"] = extract_keywords_tfidf(df)

    # 3. Interdisciplinary Analysis
    results["interdisciplinary"] = analyze_interdisciplinary(df, output_path)

    # 4. Semantic Clustering (optional - slow)
    if run_clustering:
        logger.info("Semantic clustering enabled; running …")
        results["clustering"] = semantic_clustering(
            df,
            n_clusters=12,
            output_dir=output_path,
        )
    else:
        logger.info("Semantic clustering disabled; skipping.")

    # Save results
    results_path = output_path / "analysis_results.json"

    def make_serializable(obj: Any) -> Any:
        if isinstance(obj, dict):
            return {k: make_serializable(v) for k, v in obj.items()}
        if isinstance(obj, (list, tuple)):
            return [make_serializable(v) for v in obj]
        if isinstance(obj, (np.integer, np.floating)):
            return float(obj)
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        return obj

    with results_path.open("w") as f:
        json.dump(make_serializable(results), f, indent=2)

    logger.info("Analysis complete; results written to {}", results_path)
    return results


if __name__ == "__main__":  # pragma: no cover - manual CLI usage
    print(
        """
    ╔══════════════════════════════════════════════════════════════╗
    ║         Tech Papers Analysis Pipeline                        ║
    ║         Temporal & Semantic Evolution Analysis               ║
    ╚══════════════════════════════════════════════════════════════╝
    """
    )

    data_dir = settings.arxiv_data_dir
    data_dir.mkdir(parents=True, exist_ok=True)
    csv_files = sorted(
        data_dir.glob("*.csv"),
        key=lambda x: x.stat().st_mtime,
        reverse=True,
    )

    if not csv_files:
        print(f"❌ No data files found in {data_dir}")
        filepath_str = input("\nEnter path to your CSV file: ").strip()
        filepath = Path(filepath_str)
    else:
        print("Found data files (newest first):")
        for i, f in enumerate(csv_files, 1):
            print(f"  {i}. {f.name}")

        choice = input(f"\nSelect file (1-{len(csv_files)}) [default=1]: ").strip() or "1"
        filepath = csv_files[int(choice) - 1]

    df_loaded = load_data(filepath)
    generate_full_report(df_loaded)

