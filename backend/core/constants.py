"""
Static constants shared across the arxiv-trend-predictor application.

Includes:
- TECH_CATEGORIES: mapping of arXiv category codes to human-readable domains
- GENERIC_KEYWORDS: common words to filter out of keyword suggestions
- Rate limiting defaults for arXiv API access
"""

from typing import Dict, Set


# arXiv CS subcategories mapped to readable tech domains
TECH_CATEGORIES: Dict[str, str] = {
    # AI & Machine Learning
    "cs.AI": "Artificial Intelligence",
    "cs.LG": "Machine Learning",
    "cs.NE": "Neural Networks & Evolutionary",
    # Vision & Graphics
    "cs.CV": "Computer Vision",
    "cs.GR": "Graphics",
    # Language & Text
    "cs.CL": "Natural Language Processing",
    "cs.IR": "Information Retrieval",
    # Data & Databases
    "cs.DB": "Databases",
    "cs.DS": "Data Structures & Algorithms",
    # Software & Systems
    "cs.SE": "Software Engineering",
    "cs.PL": "Programming Languages",
    "cs.OS": "Operating Systems",
    "cs.DC": "Distributed Computing",
    "cs.AR": "Hardware Architecture",
    # Security & Networks
    "cs.CR": "Cryptography & Security",
    "cs.NI": "Networking",
    # Human & Social
    "cs.HC": "Human-Computer Interaction",
    "cs.CY": "Computers & Society",
    # Robotics & Control
    "cs.RO": "Robotics",
    "cs.SY": "Systems & Control",
    # Theory
    "cs.CC": "Computational Complexity",
    "cs.GT": "Game Theory",
}


# Filter these out of keyword suggestions (too generic to be useful)
GENERIC_KEYWORDS: Set[str] = {
    "based",
    "using",
    "paper",
    "new",
    "data",
    "model",
    "models",
    "method",
    "approach",
    "results",
    "problem",
    "time",
    "systems",
    "information",
    "performance",
}


# Default arXiv client rate limiting parameters
ARXIV_DELAY_SECONDS: float = 3.0
ARXIV_NUM_RETRIES: int = 3

