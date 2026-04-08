from functools import lru_cache
from typing import Any, Dict, List, Optional, Tuple

import httpx

from backend.core.config import settings

PINECONE_UNAVAILABLE_NOTE = "Similarity unavailable: not connected to Pinecone."


def _pinecone_is_configured() -> bool:
    return bool(settings.pinecone_api_key and settings.pinecone_index_host)


@lru_cache(maxsize=1)
def _pinecone_search_url() -> str:
    host = settings.pinecone_index_host.strip()
    if host.startswith("http://") or host.startswith("https://"):
        base = host.rstrip("/")
    else:
        base = f"https://{host.rstrip('/')}"
    namespace = settings.pinecone_index_namespace.strip() or "__default__"
    return f"{base}/records/namespaces/{namespace}/search"


def _coerce_similarity_score(hit: Dict[str, Any]) -> float:
    score = hit.get("_score")
    if score is None:
        score = hit.get("score")
    if score is None:
        return 0.0
    try:
        return round(max(0.0, min(1.0, float(score))), 4)
    except Exception:
        return 0.0


def _hit_fields(hit: Dict[str, Any]) -> Dict[str, Any]:
    fields = hit.get("fields")
    if isinstance(fields, dict):
        return fields
    metadata = hit.get("metadata")
    if isinstance(metadata, dict):
        return metadata
    return {}


def _map_hit_to_paper(hit: Dict[str, Any]) -> Dict[str, Any]:
    fields = _hit_fields(hit)
    arxiv_id = fields.get("arxiv_id") or hit.get("_id") or hit.get("id")
    link = fields.get("link") or fields.get("pdf_url") or fields.get("arxiv_url")
    if not link and arxiv_id:
        link = f"https://arxiv.org/abs/{arxiv_id}"
    return {
        "title": fields.get("title") or fields.get(settings.pinecone_text_field, ""),
        "similarity_score": _coerce_similarity_score(hit),
        "year": fields.get("year"),
        "domain": fields.get("domain") or fields.get("tech_domain"),
        "link": link,
        "arxiv_id": arxiv_id,
    }


def _extract_hits(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    result = payload.get("result")
    if isinstance(result, dict):
        hits = result.get("hits")
        if isinstance(hits, list):
            return [h for h in hits if isinstance(h, dict)]
    matches = payload.get("matches")
    if isinstance(matches, list):
        return [m for m in matches if isinstance(m, dict)]
    hits = payload.get("hits")
    if isinstance(hits, list):
        return [h for h in hits if isinstance(h, dict)]
    return []


def get_similar_papers_with_note(
    text: str, top_k: Optional[int] = None
) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    if not text or len(text.strip()) < 20:
        return [], None

    if not _pinecone_is_configured():
        return [], PINECONE_UNAVAILABLE_NOTE

    k = top_k or settings.similarity_top_k
    k = max(1, int(k))
    body = {
        "query": {
            "inputs": {"text": text},
            "top_k": k,
        },
        "fields": ["title", "year", "domain", "tech_domain", "pdf_url", "arxiv_url", "link", "arxiv_id"],
    }
    headers = {
        "Api-Key": settings.pinecone_api_key,
        "X-Pinecone-Api-Version": settings.pinecone_api_version,
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    try:
        response = httpx.post(
            _pinecone_search_url(),
            headers=headers,
            json=body,
            timeout=settings.pinecone_timeout_seconds,
        )
        response.raise_for_status()
        payload = response.json()
    except Exception:
        return [], PINECONE_UNAVAILABLE_NOTE

    hits = _extract_hits(payload)
    papers = [_map_hit_to_paper(hit) for hit in hits]
    return papers, None


def get_similar_papers(text: str, top_k: Optional[int] = None) -> List[Dict[str, Any]]:
    papers, _note = get_similar_papers_with_note(text=text, top_k=top_k)
    return papers
