import json
import math
import re
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional

from backend.core.config import settings

WORD_PATTERN = re.compile(r"[a-zA-Z][a-zA-Z0-9\-]{2,}")

# Generic words that add no signal to domain matching
_STOP_WORDS = {
    "the", "and", "for", "with", "this", "that", "are", "from", "was", "has",
    "have", "been", "their", "which", "they", "also", "can", "new", "two",
    "one", "our", "its", "not", "but", "use", "used", "using", "show",
    "shown", "shows", "based", "method", "methods", "approach", "approaches",
    "paper", "work", "works", "results", "result", "propose", "proposed",
    "model", "models", "data", "task", "tasks", "set", "sets", "more",
    "than", "such", "both", "into", "each", "may", "all", "how", "well",
    "high", "low", "large", "small", "between", "different", "training",
    "test", "via", "able", "over", "out", "per", "across",
}

_DOMAIN_KNOWLEDGE: Dict[str, Dict[str, Any]] = {
    "AI/ML": {
        "focus": "machine learning, model training, and algorithmic innovation",
        "going": "Research is shifting toward foundation models, few-shot learning, and more interpretable AI systems.",
        "position": [
            "focus on data efficiency or low-resource settings",
            "address fairness, explainability, or robustness",
            "apply ML to a domain with limited existing work",
        ],
    },
    "Natural Language Processing": {
        "focus": "text understanding, generation, and language modeling",
        "going": "Research is moving toward multimodal language models, efficient transformers, and retrieval-augmented generation.",
        "position": [
            "focus on efficiency or low-resource languages",
            "combine language with vision or structured data",
            "explore retrieval-augmented or tool-using models",
        ],
    },
    "Computer Vision": {
        "focus": "visual perception, image understanding, and scene analysis",
        "going": "Research is converging on vision-language models, 3D understanding, and efficient architectures for edge deployment.",
        "position": [
            "target a specialized domain like medical imaging or satellite data",
            "work on 3D or video understanding",
            "focus on data-efficient or zero-shot visual recognition",
        ],
    },
    "Graphics": {
        "focus": "rendering, 3D modeling, and visual synthesis",
        "going": "Research is rapidly embracing neural rendering, generative 3D content creation, and real-time techniques.",
        "position": [
            "explore neural radiance fields or Gaussian splatting variants",
            "target real-time or mobile-friendly rendering",
            "focus on human avatar or scene generation",
        ],
    },
    "Robotics": {
        "focus": "autonomous systems, motion planning, and physical interaction",
        "going": "Research is trending toward learning-based control, sim-to-real transfer, and robot foundation models.",
        "position": [
            "work on dexterous manipulation or locomotion in unstructured environments",
            "explore language-conditioned robot control",
            "focus on sim-to-real generalization",
        ],
    },
    "Cryptography & Security": {
        "focus": "secure computation, privacy-preserving techniques, and threat modeling",
        "going": "Research is expanding into post-quantum cryptography, federated privacy, and LLM security.",
        "position": [
            "target post-quantum or zero-knowledge proof systems",
            "explore security implications of AI systems",
            "focus on privacy-preserving machine learning",
        ],
    },
    "Distributed Computing": {
        "focus": "coordination, fault tolerance, and scalable system design",
        "going": "Research is focused on decentralized AI training, federated systems, and cloud-native architectures.",
        "position": [
            "target federated learning or edge computing scenarios",
            "address consistency and fault tolerance at scale",
            "explore serverless or heterogeneous compute environments",
        ],
    },
    "Data Structures & Algorithms": {
        "focus": "algorithmic efficiency, complexity analysis, and data organization",
        "going": "Research is exploring algorithms for massive datasets, streaming computation, and quantum-inspired approaches.",
        "position": [
            "target cache-oblivious or memory-efficient structures",
            "focus on approximation algorithms for hard problems",
            "explore learned data structures",
        ],
    },
    "Computational Complexity": {
        "focus": "hardness results, reductions, and complexity class relationships",
        "going": "Research continues into fine-grained complexity, quantum complexity classes, and interactive proof systems.",
        "position": [
            "connect to practical hardness assumptions in cryptography",
            "explore quantum vs classical complexity gaps",
            "focus on parameterized or approximation complexity",
        ],
    },
    "Databases": {
        "focus": "data storage, querying, and transaction management",
        "going": "Research is trending toward learned query optimizers, vector databases, and cloud-native storage engines.",
        "position": [
            "focus on vector similarity search or ML-integrated databases",
            "target streaming or real-time analytics workloads",
            "explore learned indexing or query optimization",
        ],
    },
    "Information Retrieval": {
        "focus": "search, ranking, and recommendation systems",
        "going": "Research is moving toward neural retrieval, dense passage retrieval, and RAG-integrated search.",
        "position": [
            "explore dense retrieval or neural re-ranking",
            "focus on personalization or conversational search",
            "combine retrieval with generative models",
        ],
    },
    "Networking": {
        "focus": "protocols, traffic management, and network optimization",
        "going": "Research is expanding into programmable networks, 5G/6G, and ML-driven traffic engineering.",
        "position": [
            "target ML-driven congestion control or routing",
            "focus on edge networking or IoT protocols",
            "explore programmable data planes",
        ],
    },
    "Human-Computer Interaction": {
        "focus": "user interfaces, interaction design, and accessibility",
        "going": "Research is shifting toward AI-augmented interfaces, mixed reality, and inclusive design.",
        "position": [
            "focus on AI-in-the-loop interaction paradigms",
            "target accessibility or assistive technology",
            "explore immersive or multimodal interfaces",
        ],
    },
    "Software Engineering": {
        "focus": "code quality, development processes, and software reliability",
        "going": "Research is rapidly exploring AI-assisted coding, automated testing, and program synthesis.",
        "position": [
            "focus on LLM-assisted code generation or verification",
            "target automated bug detection or repair",
            "explore formal methods combined with ML",
        ],
    },
    "Programming Languages": {
        "focus": "language design, type systems, and program analysis",
        "going": "Research is exploring dependently typed languages, gradual typing, and verified compilation.",
        "position": [
            "work on type inference or program synthesis",
            "explore language-level support for concurrency or security",
            "focus on verified or certified compilers",
        ],
    },
    "Operating Systems": {
        "focus": "resource management, kernel design, and system performance",
        "going": "Research is focusing on unikernels, OS support for heterogeneous hardware, and security isolation.",
        "position": [
            "target ML workload scheduling or memory management",
            "focus on secure enclaves or confidential computing",
            "explore library OS or microkernel architectures",
        ],
    },
    "Hardware Architecture": {
        "focus": "processor design, memory systems, and hardware accelerators",
        "going": "Research is advancing rapidly in AI accelerators, near-memory computing, and domain-specific architectures.",
        "position": [
            "target ML inference accelerators or sparse computation",
            "explore near-memory or processing-in-memory designs",
            "focus on energy efficiency for edge devices",
        ],
    },
    "Neural Networks & Evolutionary": {
        "focus": "neural architectures, optimization, and biologically-inspired computation",
        "going": "Research is exploring neuro-symbolic integration, neuromorphic computing, and evolutionary architecture search.",
        "position": [
            "explore neuro-symbolic or hybrid architectures",
            "focus on neural architecture search efficiency",
            "target continual or lifelong learning",
        ],
    },
    "Game Theory": {
        "focus": "strategic reasoning, mechanism design, and multi-agent equilibria",
        "going": "Research is expanding into multi-agent reinforcement learning, auction design for AI markets, and cooperative AI.",
        "position": [
            "explore multi-agent RL from a game-theoretic lens",
            "focus on mechanism design for fair AI systems",
            "target cooperative or mixed-motive settings",
        ],
    },
    "Computers & Society": {
        "focus": "societal impact, fairness, ethics, and policy implications of computing",
        "going": "Research is intensifying around AI governance, algorithmic accountability, and digital equity.",
        "position": [
            "focus on bias measurement and mitigation in deployed systems",
            "explore privacy-preserving technologies with social impact",
            "target underserved communities or global south applications",
        ],
    },
}

_STANDING_BY_SIGNAL = {
    "strong_bet": "This is a high-momentum area with strong and growing research activity. Competition is real, but the opportunities are significant.",
    "emerging": "This area is actively growing with increasing research interest. It's still early enough to stake a meaningful claim.",
    "saturated": "This is a mature and competitive field with well-established baselines. Standing out requires a sharper angle or niche focus.",
}


def _score_breakdown(
    primary_conf: float,
    growth_score: float,
    cluster: Dict[str, Any],
    all_domains_count: int,
) -> Dict[str, Any]:
    if primary_conf >= 0.65:
        alignment = {"level": "Strong", "detail": "High confidence match with domain keywords"}
    elif primary_conf >= 0.45:
        alignment = {"level": "Moderate", "detail": "Reasonable fit with domain signals"}
    else:
        alignment = {"level": "Weak", "detail": "Limited alignment with known domain signals"}

    if growth_score >= 0.55:
        growth = {"level": "Strong", "detail": "Domain is on a steep upward trajectory"}
    elif growth_score >= 0.40:
        growth = {"level": "Emerging", "detail": "Domain shows early growth momentum"}
    else:
        growth = {"level": "Slow", "detail": "Domain growth is plateauing or saturated"}

    cluster_size = cluster.get("size") or 0
    if cluster_size == 0:
        density = {"level": "Unknown", "detail": "Cluster data unavailable"}
    elif cluster_size < 50:
        density = {"level": "Low saturation", "detail": "Small cluster — less competition"}
    elif cluster_size < 150:
        density = {"level": "Moderate", "detail": "Active cluster with established work"}
    else:
        density = {"level": "High saturation", "detail": "Large cluster — hard to stand out"}

    if all_domains_count >= 3:
        cross = {"level": "High", "detail": "Bridges multiple research communities"}
    elif all_domains_count == 2:
        cross = {"level": "Moderate", "detail": "Connects two research areas"}
    else:
        cross = {"level": "Narrow", "detail": "Focused within a single domain"}

    return {
        "semantic_alignment": alignment,
        "growth_trajectory": growth,
        "cluster_density": density,
        "cross_domain_potential": cross,
    }


def _improvement_tips(
    primary_domain: str,
    breakdown: Dict[str, Any],
) -> List[str]:
    dk = _DOMAIN_KNOWLEDGE.get(primary_domain, {})
    position = list(dk.get("position", []))
    going = dk.get("going", "")

    alignment_level = (breakdown.get("semantic_alignment") or {}).get("level", "")
    growth_level = (breakdown.get("growth_trajectory") or {}).get("level", "")
    density_level = (breakdown.get("cluster_density") or {}).get("level", "")
    cross_level = (breakdown.get("cross_domain_potential") or {}).get("level", "")

    tips: List[str] = []

    # Weak semantic alignment → lead with domain-specific positioning
    if alignment_level in ("Weak", "Moderate") and position:
        tips.append(position[0])

    # Slow or emerging growth → steer toward where the domain is heading
    if growth_level in ("Slow", "Emerging") and going:
        direction = going.split(".")[0].rstrip()
        tips.append(f"Pivot toward current momentum: {direction[0].lower()}{direction[1:]}")

    # Saturated cluster → suggest differentiation
    if density_level == "High saturation":
        tips.append("Target under-explored datasets or niche sub-problems to differentiate")
        if len(position) > 1:
            tips.append(position[1])

    # Narrow cross-domain → encourage bridging
    if cross_level == "Narrow":
        tips.append("Bridge your idea to an adjacent domain to broaden research impact")

    # Fill remaining slots with domain-specific positioning hints
    for p in position:
        if p not in tips and len(tips) < 4:
            tips.append(p)

    return [t[0].upper() + t[1:] if t else t for t in tips[:4]]


def _build_narrative(
    title: str,
    abstract: str,
    primary_domain: str,
    signal_type: str,
    matched_keywords: List[str],
    cluster: Dict[str, Any],
) -> Dict[str, Any]:
    dk = _DOMAIN_KNOWLEDGE.get(primary_domain, {})
    focus = dk.get("focus", f"core techniques in {primary_domain}")
    going = dk.get("going", f"Research in {primary_domain} is evolving rapidly.")
    position = dk.get("position", ["identify a niche problem", "focus on reproducibility and benchmarks"])

    # Why this fits
    if matched_keywords:
        kw_str = ", ".join(matched_keywords[:4])
        why = (
            f"Your idea engages with {kw_str} — concepts that sit at the heart of "
            f"{primary_domain} research. These themes directly align with {focus}."
        )
    else:
        why = (
            f"Your idea touches on {focus}, which is the core of {primary_domain}. "
            f"The classifier picked this domain based on the overall framing and vocabulary of your abstract."
        )

    # Where it stands
    standing = _STANDING_BY_SIGNAL.get(signal_type, _STANDING_BY_SIGNAL["emerging"])

    # Supporting signals from cluster
    cluster_kws = [k for k in (cluster.get("keywords") or []) if k.lower() not in _STOP_WORDS]
    sample_titles = cluster.get("sample_titles") or []
    if cluster_kws or sample_titles:
        signals_parts = []
        if cluster_kws:
            signals_parts.append(f"Closely related work focuses on {', '.join(cluster_kws[:4])}.")
        if sample_titles:
            signals_parts.append(
                "Representative papers in this cluster include: "
                + "; ".join(f'"{t}"' for t in sample_titles[:2]) + "."
            )
        supporting = " ".join(signals_parts)
    else:
        supporting = f"Research in this cluster spans the breadth of {primary_domain} with diverse application areas."

    return {
        "why_this_fits": why,
        "where_it_stands": standing,
        "where_its_going": going,
        "how_to_position": position,
        "supporting_signals": supporting,
    }


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
    normalized_keywords = [
        str(k).lower() for k in keywords
        if isinstance(k, str) and str(k).lower() not in _STOP_WORDS and len(str(k)) > 3
    ]

    matched = []
    for keyword in normalized_keywords:
        parts = keyword.split()
        if all(p in input_tokens for p in parts) and not all(p in _STOP_WORDS for p in parts):
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

    raw_keywords = best_cluster.get("keywords") or []
    seen = set()
    clean_keywords = []
    for kw in raw_keywords:
        kw_lower = str(kw).lower()
        if kw_lower not in _STOP_WORDS and len(kw_lower) > 3 and kw_lower not in seen:
            seen.add(kw_lower)
            clean_keywords.append(kw)

    return {
        "cluster_id": best_cluster.get("cluster_id"),
        "size": best_cluster.get("size"),
        "top_domains": best_cluster.get("top_domains", {}),
        "keywords": clean_keywords[:6],
        "sample_titles": (best_cluster.get("sample_titles") or [])[:2],
    }


def build_advisory_payload(
    title: str,
    abstract: str,
    primary_domain: str,
    domain_confidence: Dict[str, Any],
    growth_info: Dict[str, Any],
    all_domains: Optional[List[str]] = None,
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
    narrative = _build_narrative(
        title=title,
        abstract=abstract,
        primary_domain=primary_domain,
        signal_type=signal,
        matched_keywords=why.get("matched_keywords", []),
        cluster=cluster,
    )
    all_domains_count = len(all_domains) if all_domains else 1
    breakdown = _score_breakdown(primary_conf, growth_score, cluster, all_domains_count)
    improvement_tips = _improvement_tips(primary_domain, breakdown)

    return {
        "opportunity_score": opportunity,
        "signal_type": signal,
        "growth_score": round(growth_score, 4),
        "why_this_prediction": why,
        "cluster_insight": cluster,
        "narrative": narrative,
        "score_breakdown": breakdown,
        "improvement_tips": improvement_tips,
    }
