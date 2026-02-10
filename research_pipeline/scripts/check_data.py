"""
Data Check Script — Run before training
========================================
Validates arXiv data and reports readiness for model training.

Usage:
    python -m research_pipeline.scripts.check_data
    python -m research_pipeline.scripts.check_data --csv path/to/file.csv
"""

from __future__ import annotations

import argparse
from pathlib import Path

from backend.core.config import settings


def main() -> None:
    parser = argparse.ArgumentParser(description="Check data before training")
    parser.add_argument(
        "--csv",
        type=str,
        default=None,
        help="Path to specific CSV (default: latest in data/arxiv_data)",
    )
    args = parser.parse_args()

    try:
        import pandas as pd
    except ImportError:
        print("❌ pandas required. Run: pip install pandas")
        return

    data_dir = settings.arxiv_data_dir
    if args.csv:
        csv_path = Path(args.csv)
        if not csv_path.exists():
            print(f"❌ File not found: {csv_path}")
            return
    else:
        data_dir.mkdir(parents=True, exist_ok=True)
        all_csv = sorted(
            data_dir.glob("*.csv"),
            key=lambda x: x.stat().st_mtime,
            reverse=True,
        )
        if not all_csv:
            print(f"❌ No CSV found in {data_dir}")
            print("   Run: python -m research_pipeline.scraper.arxiv_scraper")
            return
        csv_path = all_csv[0]

    print("=" * 60)
    print("DATA HEALTH CHECK")
    print("=" * 60)
    print(f"File: {csv_path.name}")
    print()

    df = pd.read_csv(csv_path)
    df["text"] = df["title"].fillna("") + " " + df["abstract"].fillna("")

    # 1. Basic stats
    print("--- BASIC STATS ---")
    print(f"Total rows: {len(df):,}")
    print(f"Columns: {list(df.columns)}")
    print()

    # 2. Missing values
    print("--- MISSING VALUES ---")
    missing = df.isnull().sum()
    for col in ["title", "abstract", "tech_domain", "year"]:
        if col in missing.index:
            c = missing[col]
            print(f"  {col}: {c} nulls ({100*c/len(df):.1f}%)" if c else f"  {col}: OK")
    print()

    # 3. Trainability
    print("--- TRAINABILITY ---")
    trainable = df[df["tech_domain"].notna() & (df["text"].str.len() > 50)]
    dropped = len(df) - len(trainable)
    print(f"  Trainable rows: {len(trainable):,} ({100*len(trainable)/len(df):.1f}%)")
    print(f"  Dropped (null domain or short text): {dropped:,}")
    if dropped > len(df) * 0.1:
        print("  ⚠️  >10% dropped — consider investigating")
    print()

    # 4. Class balance
    print("--- CLASS BALANCE (tech_domain) ---")
    vc = trainable["tech_domain"].value_counts()
    print(f"  Unique domains: {len(vc)}")
    print(f"  Min samples/class: {vc.min():,}")
    print(f"  Max samples/class: {vc.max():,}")
    print(f"  Median samples/class: {vc.median():.0f}")

    can_stratify = (vc >= 2).all()
    print(f"  Stratifiable (all ≥2): {'✅ Yes' if can_stratify else '❌ No'}")
    if not can_stratify:
        bad = vc[vc < 2].index.tolist()
        print(f"  Domains with <2 samples: {bad}")

    imbalance_ratio = vc.max() / vc.min() if vc.min() > 0 else float("inf")
    if imbalance_ratio > 10:
        print(f"  ⚠️  High imbalance ratio: {imbalance_ratio:.1f}x")
    print()

    # 5. Year range
    print("--- TEMPORAL COVERAGE ---")
    print(f"  Year range: {int(df['year'].min())} - {int(df['year'].max())}")
    print()

    # 6. Recommendation
    print("=" * 60)
    print("RECOMMENDATION")
    print("=" * 60)
    issues = []
    if len(trainable) < 1000:
        issues.append("Very small dataset (<1000 trainable rows)")
    elif len(trainable) < 5000:
        issues.append("Small dataset — consider more data for better accuracy")
    if not can_stratify:
        issues.append("Some domains have <2 samples — stratification may fail")
    if dropped > len(df) * 0.1:
        issues.append("High drop rate — check data quality")

    if not issues:
        print("✅ Data looks ready for training.")
        print()
        print("Next steps:")
        print("  1. python -m research_pipeline.analysis.arxiv_analysis   # regenerate analysis")
        print("  2. python -m research_pipeline.scripts.run_advisor train")
    else:
        print("⚠️  Issues found:")
        for i in issues:
            print(f"  • {i}")
        print()
        print("Consider fixing these before training. You can still proceed with:")
        print("  python -m research_pipeline.scripts.run_advisor train")


if __name__ == "__main__":
    main()
