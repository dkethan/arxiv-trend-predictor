from backend.api.services import similarity_service


def test_similarity_returns_note_when_pinecone_not_configured(monkeypatch):
    monkeypatch.setattr(similarity_service.settings, "pinecone_api_key", "")
    monkeypatch.setattr(similarity_service.settings, "pinecone_index_host", "")
    papers, note = similarity_service.get_similar_papers_with_note(
        "Transformer architecture for long-context scientific summarization."
    )
    assert papers == []
    assert note == "Similarity unavailable: not connected to Pinecone."


def test_similarity_maps_pinecone_hits(monkeypatch):
    monkeypatch.setattr(similarity_service.settings, "pinecone_api_key", "dummy")
    monkeypatch.setattr(similarity_service.settings, "pinecone_index_host", "index-host.pinecone.io")
    monkeypatch.setattr(similarity_service.settings, "pinecone_index_namespace", "__default__")

    class FakeResponse:
        def raise_for_status(self):
            return None

        def json(self):
            return {
                "result": {
                    "hits": [
                        {
                            "_id": "1706.03762",
                            "_score": 0.91,
                            "fields": {
                                "title": "Attention Is All You Need",
                                "year": 2017,
                                "tech_domain": "Machine Learning",
                                "arxiv_url": "https://arxiv.org/abs/1706.03762",
                                "arxiv_id": "1706.03762",
                            },
                        }
                    ]
                }
            }

    monkeypatch.setattr(similarity_service.httpx, "post", lambda *args, **kwargs: FakeResponse())
    papers, note = similarity_service.get_similar_papers_with_note(
        "Transformer architecture for long-context scientific summarization."
    )
    assert note is None
    assert len(papers) == 1
    assert papers[0]["title"] == "Attention Is All You Need"
    assert papers[0]["domain"] == "Machine Learning"
    assert papers[0]["link"] == "https://arxiv.org/abs/1706.03762"
    assert papers[0]["similarity_score"] == 0.91
