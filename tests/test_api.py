from fastapi.testclient import TestClient

from backend.api.main import app


client = TestClient(app)


def test_health_ok():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_root_message():
    resp = client.get("/")
    assert resp.status_code == 200
    assert "arxiv-trend-predictor" in resp.json()["message"]

