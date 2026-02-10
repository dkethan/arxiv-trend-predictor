"""
arXiv Tech/CS Papers Data Collector
===================================
Collects academic paper metadata from arXiv across different tech
subfields from year 2000 to present for temporal and semantic analysis.

This module is a refactored version of the original `arxiv_tech_scraper.py`
that is now:
- Config-driven (years, data directory, paper limits)
- Using the shared Loguru-based logger
- Safe to call from both CLI scripts and the API layer.
"""

from __future__ import annotations

import json
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import arxiv
import pandas as pd

from backend.core.constants import ARXIV_DELAY_SECONDS, ARXIV_NUM_RETRIES, TECH_CATEGORIES
from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)


# =============================================================================
# DATA COLLECTION FUNCTIONS
# =============================================================================

def fetch_papers_for_category_year(
    category: str,
    year: int,
    max_results: int,
) -> List[Dict]:
    """
    Fetch papers for a specific category and year from arXiv.

    Args:
        category: arXiv category code (e.g., 'cs.AI')
        year: Year to fetch papers from
        max_results: Maximum number of papers to fetch

    Returns:
        List of paper dictionaries
    """
    papers: List[Dict] = []

    # Build query for specific category and year
    # arXiv date format: YYYYMMDD
    start_date = f"{year}0101"
    end_date = f"{year}1231"

    query = f"cat:{category} AND submittedDate:[{start_date} TO {end_date}]"

    try:
        client = arxiv.Client(
            page_size=100,
            delay_seconds=ARXIV_DELAY_SECONDS,
            num_retries=ARXIV_NUM_RETRIES,
        )

        search = arxiv.Search(
            query=query,
            max_results=max_results,
            sort_by=arxiv.SortCriterion.SubmittedDate,
            sort_order=arxiv.SortOrder.Descending,
        )

        for result in client.results(search):
            paper = {
                # Basic metadata
                "arxiv_id": result.entry_id.split("/")[-1],
                "title": result.title.replace("\n", " ").strip(),
                "abstract": result.summary.replace("\n", " ").strip(),
                # Temporal info
                "published_date": result.published.strftime("%Y-%m-%d"),
                "updated_date": (
                    result.updated.strftime("%Y-%m-%d") if result.updated else None
                ),
                "year": result.published.year,
                "month": result.published.month,
                # Categories/Domain
                "primary_category": result.primary_category,
                "all_categories": ", ".join(result.categories),
                "tech_domain": TECH_CATEGORIES.get(category, "Other"),
                # Authors
                "authors": ", ".join(a.name for a in result.authors[:10]),
                "author_count": len(result.authors),
                # Additional metadata
                "doi": result.doi,
                "journal_ref": result.journal_ref,
                "pdf_url": result.pdf_url,
                # For analysis
                "title_length": len(result.title.split()),
                "abstract_length": len(result.summary.split()),
            }
            papers.append(paper)
    except Exception as exc:  # pragma: no cover - network errors
        logger.error(f"Error fetching {category} for {year}: {exc}")

    return papers


def collect_all_data(
    categories: Dict[str, str] | None = None,
    start_year: int | None = None,
    end_year: int | None = None,
    papers_per_cat_year: int | None = None,
    save_incremental: bool = False,
    output_dir: Path | None = None,
) -> pd.DataFrame:
    """
    Main collection function - iterates through all categories and years.

    Args:
        categories: Dictionary of arXiv categories to collect
        start_year: Starting year (defaults to settings.arxiv_start_year)
        end_year: Ending year (defaults to settings.arxiv_end_year)
        papers_per_cat_year: Max papers per category per year
        save_incremental: Deprecated; kept for API compatibility
        output_dir: Directory to write CSV/JSON files (defaults to settings.arxiv_data_dir)

    Returns:
        DataFrame with all collected papers
    """
    cats = categories or TECH_CATEGORIES
    start = start_year or settings.arxiv_start_year
    end = end_year or settings.arxiv_end_year
    per_year = papers_per_cat_year or settings.papers_per_category_per_year
    out_dir = output_dir or settings.arxiv_data_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    all_papers: List[Dict] = []
    total_categories = len(cats)
    total_years = end - start + 1
    total_iterations = total_categories * total_years
    current_iteration = 0

    logger.info(
        "Starting collection: {} categories × {} years (max ~{} papers)",
        total_categories,
        total_years,
        total_categories * total_years * per_year,
    )

    for cat_code, cat_name in cats.items():
        for year in range(start, end + 1):
            current_iteration += 1
            progress = (current_iteration / total_iterations) * 100

            logger.info("[{:.1f}%] Fetching {} ({}) - {}", progress, cat_name, cat_code, year)

            papers = fetch_papers_for_category_year(
                category=cat_code,
                year=year,
                max_results=per_year,
            )

            all_papers.extend(papers)
            logger.info("→ Got {} papers (Total: {:,})", len(papers), len(all_papers))

            # Be nice to arXiv
            time.sleep(1)

    df = pd.DataFrame(all_papers)

    if df.empty:
        logger.warning("No papers collected.")
        return df

    # Remove duplicates (papers can appear in multiple categories)
    before = len(df)
    df = df.drop_duplicates(subset=["arxiv_id"], keep="first")
    after = len(df)
    logger.info(
        "Collection complete! Total unique papers: {:,} (removed {:,} duplicates)",
        after,
        before - after,
    )

    return df


def save_data(
    df: pd.DataFrame,
    filename_prefix: str = "arxiv_tech_papers",
    output_dir: Path | None = None,
) -> Tuple[Path, Path, Path]:
    """
    Save the collected data in multiple formats.

    Returns:
        (csv_path, json_path, stats_path)
    """
    out_dir = output_dir or settings.arxiv_data_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Save as CSV
    csv_path = out_dir / f"{filename_prefix}_{timestamp}.csv"
    df.to_csv(csv_path, index=False)
    logger.info("Saved CSV: {}", csv_path)

    # Save as JSON (for easier text processing)
    json_path = out_dir / f"{filename_prefix}_{timestamp}.json"
    df.to_json(json_path, orient="records", indent=2)
    logger.info("Saved JSON: {}", json_path)

    # Save summary statistics
    stats = {
        "total_papers": int(len(df)),
        "date_range": f"{int(df['year'].min())} - {int(df['year'].max())}",
        "categories": df["tech_domain"].value_counts().to_dict(),
        "papers_per_year": df["year"].value_counts().sort_index().to_dict(),
        "collection_date": timestamp,
    }

    stats_path = out_dir / f"{filename_prefix}_{timestamp}_stats.json"
    stats_path.write_text(json.dumps(stats, indent=2))
    logger.info("Saved stats: {}", stats_path)

    return csv_path, json_path, stats_path


def quick_sample(
    n_per_category: int = 50,
    years: Iterable[int] | None = None,
) -> pd.DataFrame:
    """
    Quick sample collection for testing the pipeline.

    Gets a small sample from selected years.
    """
    years = list(years or [2015, 2018, 2021, 2024])
    logger.info(
        "Quick sample: {} papers × {} categories × {} years",
        n_per_category,
        len(TECH_CATEGORIES),
        len(years),
    )

    all_papers: List[Dict] = []

    for cat_code, cat_name in TECH_CATEGORIES.items():
        for year in years:
            logger.info("Sampling {} - {}", cat_name, year)
            papers = fetch_papers_for_category_year(cat_code, year, n_per_category)
            all_papers.extend(papers)
            time.sleep(0.5)

    df = pd.DataFrame(all_papers)
    if not df.empty:
        df = df.drop_duplicates(subset=["arxiv_id"], keep="first")

    return df


def collect_specific_domains(
    domains: Iterable[str],
    start_year: int = 2015,
    end_year: int = 2024,
    papers_per_year: int = 200,
) -> pd.DataFrame:
    """
    Collect data for specific tech domains only.

    Args:
        domains: List of domain names (e.g., ['Machine Learning', 'Computer Vision'])
        start_year: Starting year
        end_year: Ending year
        papers_per_year: Papers per domain per year
    """
    domains_set = set(domains)
    selected_cats = {
        code: name for code, name in TECH_CATEGORIES.items() if name in domains_set
    }

    if not selected_cats:
        logger.error(
            "No matching domains found. Requested: {}. Available: {}",
            sorted(domains_set),
            sorted(set(TECH_CATEGORIES.values())),
        )
        return pd.DataFrame()

    return collect_all_data(
        categories=selected_cats,
        start_year=start_year,
        end_year=end_year,
        papers_per_cat_year=papers_per_year,
    )


if __name__ == "__main__":  # pragma: no cover - manual CLI usage
    print(
        """
    ╔══════════════════════════════════════════════════════════════╗
    ║         arXiv Tech Papers Data Collector                     ║
    ║         For Academic Evolution Analysis                      ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  Options:                                                    ║
    ║  1. Quick sample (fast, for testing)                         ║
    ║  2. Full collection (slow, comprehensive)                    ║
    ║  3. Custom domains only                                      ║
    ╚══════════════════════════════════════════════════════════════╝
    """
    )

    choice = input("Enter choice (1/2/3) [default=1]: ").strip() or "1"

    if choice == "1":
        print("\n🚀 Running quick sample collection...")
        df_result = quick_sample()
    elif choice == "2":
        print("\n🚀 Running FULL collection (this may take several hours)...")
        confirm = input("Are you sure? (yes/no): ").strip().lower()
        if confirm == "yes":
            df_result = collect_all_data()
        else:
            print("Cancelled.")
            raise SystemExit(0)
    elif choice == "3":
        print("\nAvailable domains:")
        domain_list = list(TECH_CATEGORIES.values())
        for i, domain in enumerate(domain_list, 1):
            print(f"  {i}. {domain}")

        selected = input(
            "\nEnter domain numbers (comma-separated, e.g., 1,2,3): "
        ).strip()
        selected_domains = [domain_list[int(i) - 1] for i in selected.split(",")]

        print(f"\nCollecting: {selected_domains}")
        df_result = collect_specific_domains(selected_domains)
    else:
        print("Invalid choice")
        raise SystemExit(1)

    if not df_result.empty:
        csv_path, json_path, stats_path = save_data(df_result)
        print(
            f"""
    ✅ Collection Complete!
    ════════════════════════════════════════
    Total papers: {len(df_result):,}
    Year range:   {int(df_result['year'].min())} - {int(df_result['year'].max())}

    Files saved:
    📄 {csv_path}
    📄 {json_path}
    📄 {stats_path}
    """
        )
    else:
        print("❌ No data collected")

