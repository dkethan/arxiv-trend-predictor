from fastapi.testclient import TestClient

from backend.api.main import app
from backend.api.endpoints import advisor as advisor_endpoint


client = TestClient(app)


def test_health_ok():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_root_message():
    resp = client.get("/")
    assert resp.status_code == 200
    assert "arxiv-trend-predictor" in resp.json()["message"]


def test_advise_extended_response_contract(monkeypatch):
    def fake_advise(title: str, abstract: str):
        return {
            "primary_domain": "Machine Learning",
            "all_domains": ["Machine Learning", "Artificial Intelligence"],
            "domain_confidence": {"Machine Learning": 0.81, "Artificial Intelligence": 0.63},
            "growth_info": {"Machine Learning": {"slope": 0.44, "r2": 0.71}},
            "model_info": {"micro_f1": 0.58},
            "advisory": {
                "opportunity_score": 7.8,
                "signal_type": "strong_bet",
                "growth_score": 0.67,
                "why_this_prediction": {"matched_keywords": ["transformer"]},
                "cluster_insight": {"cluster_id": 2},
            },
            "similar_papers": [
                {
                    "title": "Transformer paper",
                    "similarity_score": 0.91,
                    "year": 2023,
                    "domain": "Machine Learning",
                    "link": "https://arxiv.org/abs/1706.03762",
                }
            ],
            "similarity_note": "Similarity unavailable: not connected to Pinecone.",
            "opportunity_score": 7.8,
            "signal_type": "strong_bet",
            "domain_growth_score": 0.67,
        }

    monkeypatch.setattr(advisor_endpoint, "advise", fake_advise)

    resp = client.post(
        "/api/v1/advisor/advise",
        json={"title": "Test title", "abstract": "Test abstract with enough content."},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "advisory" in body
    assert "similar_papers" in body
    assert "similarity_note" in body
    assert body["signal_type"] == "strong_bet"
    assert body["similar_papers"][0]["link"].startswith("https://")


def test_compare_ideas_contract(monkeypatch):
    def fake_compare(*_args, **_kwargs):
        return {
            "idea_a_result": {
                "advisory": {"opportunity_score": 7.1, "signal_type": "emerging", "growth_score": 0.55}
            },
            "idea_b_result": {
                "advisory": {"opportunity_score": 8.4, "signal_type": "strong_bet", "growth_score": 0.64}
            },
            "final_verdict": "Idea B shows higher potential right now.",
        }

    monkeypatch.setattr(advisor_endpoint, "compare_ideas", fake_compare)

    resp = client.post(
        "/api/v1/advisor/compare",
        json={
            "idea_a": {"title": "Idea A", "abstract": "Idea A abstract text for test."},
            "idea_b": {"title": "Idea B", "abstract": "Idea B abstract text for test."},
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "idea_a_result" in body
    assert "idea_b_result" in body
    assert "final_verdict" in body
    assert "higher potential" in body["final_verdict"]


def test_compare_validation_error_for_partial_payload():
    resp = client.post(
        "/api/v1/advisor/compare",
        json={
            "idea_a": {"title": "Idea A", "abstract": "Idea A abstract text for test."},
            "idea_b": {"title": "Idea B"},
        },
    )
    assert resp.status_code == 422

