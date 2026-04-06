import json
import math
import re
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional

from backend.core.config import settings

WORD_PATTERN = re.compile(r"[a-zA-Z][a-zA-Z0-9\-]{2,}")


@lru_cache(maxsize=1)
def _load_analysis_results() -> Dict[str, Any]:
    analysis_file = Path(settings.analysis_output_dir) / "analysis_results.json"
    if not analysis_file.exists():
        return {}
    try:
        with open(analysis_file, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {}


def _safe_float(value: Any, default: float = 0.0) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return default


def _tokenize(text: str) -> List[str]:
    if not text:
        return []
    return [m.group(0).lower() for m in WORD_PATTERN.finditer(text)]


def _compute_momentum_score(primary_domain: str, analysis_data: Dict[str, Any]) -> float:
    temporal = analysis_data.get("temporal", {})
    evolution = temporal.get("domain_evolution", {})
    domain_series = evolution.get(primary_domain, {})
    if not isinstance(domain_series, dict) or len(domain_series) < 3:
        return 0.5

    sorted_years = sorted(domain_series.keys())
    recent_years = sorted_years[-4:]
    recent_values = [_safe_float(domain_series.get(y, 0.0), 0.0) for y in recent_years]
    if not recent_values or recent_values[0] <= 0:
        return 0.5

    start = recent_values[0]
    end = recent_values[-1]
    years_delta = max(1, len(recent_values) - 1)
    growth_rate = (end / start) ** (1 / years_delta) - 1 if start > 0 else 0.0
    return max(0.0, min(1.0, (math.tanh(growth_rate * 4.0) + 1.0) / 2.0))


def _compute_growth_score(primary_domain: str, growth_info: Dict[str, Any], momentum: float) -> float:
    g = growth_info.get(primary_domain, {}) if isinstance(growth_info, dict) else {}
    slope = _safe_float(g.get("slope"), 0.0)
    r2 = _safe_float(g.get("r2"), 0.0)
    slope_score = max(0.0, min(1.0, (math.tanh(slope) + 1.0) / 2.0))
    return max(0.0, min(1.0, 0.55 * slope_score + 0.30 * r2 + 0.15 * momentum))


def _signal_type(confidence: float, growth_score: float) -> str:
    if confidence >= 0.65 and growth_score >= 0.55:
        return "strong_bet"
    if growth_score >= 0.5 or (confidence >= 0.45 and growth_score >= 0.4):
        return "emerging"
    return "saturated"


def _why_prediction(
    title: str, abstract: str, primary_domain: str, analysis_data: Dict[str, Any]
) -> Dict[str, Any]:
    keywords = (
        analysis_data.get("keywords", {})
        .get("domain_keywords", {})
        .get(primary_domain, [])
    )
    if not isinstance(keywords, list):
        keywords = []

    input_tokens = set(_tokenize(f"{title} {abstract}"))
    normalized_keywords = [str(k).lower() for k in keywords if isinstance(k, str)]

    matched = []
    for keyword in normalized_keywords:
        parts = keyword.split()
        if all(p in input_tokens for p in parts):
            matched.append(keyword)

    return {
        "matched_keywords": matched[:8],
        "domain_keywords": normalized_keywords[:10],
        "match_count": len(matched),
    }


def _cluster_insight(primary_domain: str, analysis_data: Dict[str, Any]) -> Dict[str, Any]:
    clusters = analysis_data.get("clustering", {}).get("cluster_analysis", [])
    if not isinstance(clusters, list) or not clusters:
        return {}

    best_cluster: Optional[Dict[str, Any]] = None
    best_score = -1.0
    for cluster in clusters:
        if not isinstance(cluster, dict):
            continue
        top_domains = cluster.get("top_domains", {})
        if not isinstance(top_domains, dict):
            continue
        score = _safe_float(top_domains.get(primary_domain), 0.0)
        if score > best_score:
            best_score = score
            best_cluster = cluster

    if not best_cluster:
        return {}

    return {
        "cluster_id": best_cluster.get("cluster_id"),
        "size": best_cluster.get("size"),
        "top_domains": best_cluster.get("top_domains", {}),
        "keywords": (best_cluster.get("keywords") or [])[:5],
        "sample_titles": (best_cluster.get("sample_titles") or [])[:2],
    }


def build_advisory_payload(
    title: str,
    abstract: str,
    primary_domain: str,
    domain_confidence: Dict[str, Any],
    growth_info: Dict[str, Any],
) -> Dict[str, Any]:
    analysis_data = _load_analysis_results()

    primary_conf = _safe_float((domain_confidence or {}).get(primary_domain), 0.0)
    momentum = _compute_momentum_score(primary_domain, analysis_data)
    growth_score = _compute_growth_score(primary_domain, growth_info, momentum)
    opportunity = max(
        0.0, min(10.0, round((0.55 * primary_conf + 0.45 * growth_score) * 10.0, 2))
    )
    signal = _signal_type(primary_conf, growth_score)
    why = _why_prediction(title, abstract, primary_domain, analysis_data)
    cluster = _cluster_insight(primary_domain, analysis_data)

    return {
        "opportunity_score": opportunity,
        "signal_type": signal,
        "growth_score": round(growth_score, 4),
        "why_this_prediction": why,
        "cluster_insight": cluster,
    }
