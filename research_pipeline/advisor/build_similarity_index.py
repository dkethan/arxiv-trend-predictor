"""
Build semantic similarity artifacts for advisor retrieval.

Usage:
  python -m research_pipeline.advisor.build_similarity_index
  python -m research_pipeline.advisor.build_similarity_index --csv /path/to/data.csv
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List

import numpy as np
import pandas as pd

from backend.core.config import settings


def _latest_csv() -> Path:
    data_dir = Path(settings.arxiv_data_dir)
    csv_files: List[Path] = sorted(data_dir.glob("*.csv"), key=lambda p: p.stat().st_mtime)
    if not csv_files:
        raise FileNotFoundError(f"No CSV found in {data_dir}")
    return csv_files[-1]


def _build_text(df: pd.DataFrame) -> List[str]:
    titles = df.get("title", pd.Series([""] * len(df))).fillna("")
    abstracts = df.get("abstract", pd.Series([""] * len(df))).fillna("")
    return (titles + " " + abstracts).str.strip().tolist()


def build_similarity_index(csv_path: Path, model_name: str) -> None:
    from sentence_transformers import SentenceTransformer

    output_dir = Path(settings.similarity_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading dataset: {csv_path}")
    df = pd.read_csv(csv_path)
    texts = _build_text(df)

    print(f"Encoding {len(texts)} papers with {model_name}")
    model = SentenceTransformer(model_name)
    embeddings = model.encode(
        texts,
        batch_size=128,
        show_progress_bar=True,
        normalize_embeddings=True,
    )

    embeddings_path = Path(settings.similarity_embeddings_file)
    metadata_path = Path(settings.similarity_metadata_file)
    meta_path = Path(settings.similarity_index_meta_file)

    np.save(embeddings_path, np.asarray(embeddings, dtype=np.float32))

    with open(metadata_path, "w", encoding="utf-8") as handle:
        for _, row in df.iterrows():
            record = {
                "arxiv_id": row.get("arxiv_id"),
                "title": row.get("title"),
                "year": int(row["year"]) if pd.notna(row.get("year")) else None,
                "tech_domain": row.get("tech_domain"),
                "pdf_url": row.get("pdf_url"),
                "arxiv_url": f"https://arxiv.org/abs/{row.get('arxiv_id')}"
                if row.get("arxiv_id")
                else None,
            }
            handle.write(json.dumps(record, ensure_ascii=True) + "\n")

    with open(meta_path, "w", encoding="utf-8") as handle:
        json.dump(
            {
                "model_name": model_name,
                "csv_path": str(csv_path),
                "num_records": len(df),
                "embedding_dim": int(np.asarray(embeddings).shape[1]),
            },
            handle,
            indent=2,
        )

    print("Similarity artifacts written:")
    print(f"- {embeddings_path}")
    print(f"- {metadata_path}")
    print(f"- {meta_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build semantic similarity index files.")
    parser.add_argument("--csv", type=str, default="", help="Path to arXiv CSV file")
    parser.add_argument(
        "--model",
        type=str,
        default=settings.similarity_model_name,
        help="Sentence-transformer model name",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv) if args.csv else _latest_csv()
    build_similarity_index(csv_path=csv_path, model_name=args.model)


if __name__ == "__main__":
    main()
