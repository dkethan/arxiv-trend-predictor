import json
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np
from sklearn.neighbors import NearestNeighbors

from backend.core.config import settings


def _read_jsonl(path: Path) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    if not path.exists():
        return rows
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                continue
    return rows


def _load_index_meta() -> Dict[str, Any]:
    if not settings.similarity_index_meta_file.exists():
        return {}
    try:
        with open(settings.similarity_index_meta_file, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {}


@lru_cache(maxsize=1)
def _load_similarity_assets() -> Tuple[np.ndarray, List[Dict[str, Any]], NearestNeighbors, str]:
    embeddings_file = settings.similarity_embeddings_file
    metadata_file = settings.similarity_metadata_file
    if not embeddings_file.exists() or not metadata_file.exists():
        raise FileNotFoundError("Similarity index artifacts are not available.")

    embeddings = np.load(embeddings_file)
    if embeddings.ndim != 2:
        raise ValueError("Embeddings matrix must be 2-dimensional.")

    metadata = _read_jsonl(metadata_file)
    if len(metadata) != embeddings.shape[0]:
        raise ValueError("Embeddings row count does not match metadata records.")

    nn = NearestNeighbors(metric="cosine", algorithm="brute")
    nn.fit(embeddings)

    index_meta = _load_index_meta()
    model_name = index_meta.get("model_name", settings.similarity_model_name)
    return embeddings, metadata, nn, model_name


@lru_cache(maxsize=1)
def _load_query_encoder(model_name: str):
    from sentence_transformers import SentenceTransformer

    return SentenceTransformer(model_name)


def get_similar_papers(text: str, top_k: int = None) -> List[Dict[str, Any]]:
    if not text or len(text.strip()) < 20:
        return []

    try:
        _embeddings, metadata, nn, model_name = _load_similarity_assets()
    except Exception:
        return []

    k = top_k or settings.similarity_top_k
    k = max(1, min(k, len(metadata)))

    encoder = _load_query_encoder(model_name)
    query_vec = encoder.encode([text], normalize_embeddings=True)
    distances, indices = nn.kneighbors(query_vec, n_neighbors=k)

    results: List[Dict[str, Any]] = []
    for distance, idx in zip(distances[0], indices[0]):
        paper = metadata[int(idx)]
        similarity = max(0.0, min(1.0, 1.0 - float(distance)))
        results.append(
            {
                "title": paper.get("title", ""),
                "similarity_score": round(similarity, 4),
                "year": paper.get("year"),
                "domain": paper.get("tech_domain"),
                "link": paper.get("pdf_url") or paper.get("arxiv_url"),
                "arxiv_id": paper.get("arxiv_id"),
            }
        )
    return results
