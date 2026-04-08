"""
Upsert advisor similarity records into a Pinecone integrated-embedding index.

Usage:
  python -m research_pipeline.advisor.upsert_similarity_to_pinecone
  python -m research_pipeline.advisor.upsert_similarity_to_pinecone --csv /path/to/data.csv
"""

from __future__ import annotations

import argparse
import json
import os
import random
import time
from pathlib import Path
from typing import Any, Dict, List

import httpx
import pandas as pd


def _load_local_dotenv() -> None:
    """
    Minimal `.env` loader for local script execution.
    Keeps existing process env vars unchanged.
    """
    env_path = Path(__file__).resolve().parents[2] / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


_load_local_dotenv()
from backend.core.config import settings

MAX_TEXT_UPSERT_BATCH = 96
MAX_UPSERT_RETRIES = int(os.getenv("PINECONE_UPSERT_MAX_RETRIES", "8"))
RETRY_BASE_DELAY_SECONDS = float(os.getenv("PINECONE_UPSERT_RETRY_BASE_SECONDS", "0.5"))
RETRY_MAX_DELAY_SECONDS = float(os.getenv("PINECONE_UPSERT_RETRY_MAX_SECONDS", "10.0"))
SINGLE_RECORD_DELAY_SECONDS = float(
    os.getenv("PINECONE_SINGLE_RECORD_DELAY_SECONDS", "0.10")
)
UPSERT_CONNECT_TIMEOUT_SECONDS = float(
    os.getenv("PINECONE_UPSERT_CONNECT_TIMEOUT_SECONDS", "10.0")
)
UPSERT_READ_TIMEOUT_SECONDS = float(
    os.getenv(
        "PINECONE_UPSERT_READ_TIMEOUT_SECONDS",
        str(max(settings.pinecone_timeout_seconds, 30.0)),
    )
)
UPSERT_WRITE_TIMEOUT_SECONDS = float(
    os.getenv("PINECONE_UPSERT_WRITE_TIMEOUT_SECONDS", "30.0")
)
UPSERT_POOL_TIMEOUT_SECONDS = float(
    os.getenv("PINECONE_UPSERT_POOL_TIMEOUT_SECONDS", "30.0")
)


def _latest_csv() -> Path:
    data_dir = Path(settings.arxiv_data_dir)
    csv_files: List[Path] = sorted(data_dir.glob("*.csv"), key=lambda p: p.stat().st_mtime)
    if not csv_files:
        raise FileNotFoundError(f"No CSV found in {data_dir}")
    return csv_files[-1]


def _pinecone_upsert_url() -> str:
    host = settings.pinecone_index_host.strip()
    if not host:
        raise ValueError("PINECONE_INDEX_HOST is required.")
    if host.startswith("http://") or host.startswith("https://"):
        base = host.rstrip("/")
    else:
        base = f"https://{host.rstrip('/')}"
    namespace = settings.pinecone_index_namespace.strip() or "__default__"
    return f"{base}/records/namespaces/{namespace}/upsert"


def _as_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        if pd.isna(value):
            return None
        return int(value)
    except Exception:
        return None


def _row_to_record(row: Dict[str, Any]) -> Dict[str, Any]:
    arxiv_id = row.get("arxiv_id")
    title = row.get("title") or ""
    abstract = row.get("abstract") or ""
    text_value = f"{title} {abstract}".strip()
    return {
        "_id": str(arxiv_id or title or hash(text_value)),
        settings.pinecone_text_field: text_value,
        "title": title,
        "year": _as_int(row.get("year")),
        "tech_domain": row.get("tech_domain"),
        "pdf_url": row.get("pdf_url"),
        "arxiv_url": f"https://arxiv.org/abs/{arxiv_id}" if arxiv_id else None,
        "arxiv_id": arxiv_id,
    }


def _chunks(items: List[Dict[str, Any]], size: int) -> List[List[Dict[str, Any]]]:
    return [items[idx : idx + size] for idx in range(0, len(items), size)]


def _response_text_snippet(response: httpx.Response, limit: int = 500) -> str:
    text = (response.text or "").strip()
    return text[:limit]


def _is_retryable_status(status_code: int) -> bool:
    return status_code in {408, 429, 500, 502, 503, 504}


def _compute_retry_delay(attempt: int, retry_after_header: str | None) -> float:
    if retry_after_header:
        try:
            return min(float(retry_after_header), RETRY_MAX_DELAY_SECONDS)
        except ValueError:
            pass

    backoff = RETRY_BASE_DELAY_SECONDS * (2 ** attempt)
    jitter_multiplier = 1.0 + random.uniform(0.0, 0.25)
    return min(backoff * jitter_multiplier, RETRY_MAX_DELAY_SECONDS)


def _to_ndjson(records: List[Dict[str, Any]]) -> str:
    return "\n".join(json.dumps(r, ensure_ascii=False) for r in records)


def _post_with_retry(
    client: httpx.Client,
    url: str,
    headers: Dict[str, str],
    body: str,
    context: str,
) -> httpx.Response:
    last_exception: Exception | None = None
    for attempt in range(MAX_UPSERT_RETRIES + 1):
        try:
            response = client.post(url, headers=headers, content=body.encode("utf-8"))
        except (
            httpx.TimeoutException,
            httpx.NetworkError,
            httpx.RemoteProtocolError,
            httpx.WriteError,
        ) as exc:
            last_exception = exc
            if attempt >= MAX_UPSERT_RETRIES:
                raise RuntimeError(
                    f"Pinecone request failed after retries ({context}): {exc}"
                ) from exc
            delay_seconds = _compute_retry_delay(attempt=attempt, retry_after_header=None)
            print(
                f"Transient transport error ({context}, attempt {attempt + 1}/"
                f"{MAX_UPSERT_RETRIES + 1}): {exc}. Retrying in {delay_seconds:.2f}s..."
            )
            time.sleep(delay_seconds)
            continue

        if _is_retryable_status(response.status_code):
            if attempt >= MAX_UPSERT_RETRIES:
                snippet = _response_text_snippet(response)
                raise RuntimeError(
                    "Pinecone request failed after retries "
                    f"({context}, status={response.status_code}): {snippet}"
                )
            delay_seconds = _compute_retry_delay(
                attempt=attempt, retry_after_header=response.headers.get("Retry-After")
            )
            print(
                f"Retryable Pinecone response ({context}, status={response.status_code}, "
                f"attempt {attempt + 1}/{MAX_UPSERT_RETRIES + 1}). "
                f"Retrying in {delay_seconds:.2f}s..."
            )
            time.sleep(delay_seconds)
            continue

        return response

    raise RuntimeError(f"Pinecone request failed unexpectedly ({context}): {last_exception}")


def _post_batch_or_raise(
    client: httpx.Client,
    url: str,
    headers: Dict[str, str],
    batch: List[Dict[str, Any]],
    batch_idx: int,
    total_batches: int,
) -> None:
    """Send a batch of records as NDJSON to Pinecone. Raises on HTTP error."""
    response = _post_with_retry(
        client=client,
        url=url,
        headers=headers,
        body=_to_ndjson(batch),
        context=f"batch {batch_idx}/{total_batches}",
    )
    if response.status_code >= 400:
        body = _response_text_snippet(response)
        raise RuntimeError(
            "Pinecone bulk upsert failed "
            f"(batch {batch_idx}/{total_batches}, status={response.status_code}): {body}"
        )


def upsert_similarity_records(
    csv_path: Path,
    *,
    batch_size: int = MAX_TEXT_UPSERT_BATCH,
    start_batch: int = 1,
    end_batch: int | None = None,
    batch_delay_seconds: float = SINGLE_RECORD_DELAY_SECONDS,
) -> None:
    if not settings.pinecone_api_key:
        raise ValueError("PINECONE_API_KEY is required.")

    print(f"Loading dataset: {csv_path}")
    df = pd.read_csv(csv_path).fillna("")
    records = [_row_to_record(row) for row in df.to_dict(orient="records")]
    if not records:
        print("No records to upsert.")
        return

    headers = {
        "Api-Key": settings.pinecone_api_key,
        "X-Pinecone-Api-Version": settings.pinecone_api_version,
        "Accept": "application/json",
        "Content-Type": "application/x-ndjson",
    }
    url = _pinecone_upsert_url()
    if batch_size <= 0:
        raise ValueError(f"batch_size must be > 0, got {batch_size}")

    batches = _chunks(records, batch_size)
    total_batches = len(batches)
    if total_batches == 0:
        print("No records to upsert.")
        return
    if start_batch < 1:
        raise ValueError(f"start_batch must be >= 1, got {start_batch}")
    if start_batch > total_batches:
        raise ValueError(
            f"start_batch ({start_batch}) is greater than total batches ({total_batches})"
        )

    resolved_end_batch = end_batch if end_batch is not None else total_batches
    if resolved_end_batch < start_batch:
        raise ValueError(
            f"end_batch ({resolved_end_batch}) must be >= start_batch ({start_batch})"
        )
    resolved_end_batch = min(resolved_end_batch, total_batches)
    selected_batches = batches[start_batch - 1 : resolved_end_batch]

    print(
        f"Upserting {len(records)} records to Pinecone namespace "
        f"{settings.pinecone_index_namespace!r} in {total_batches} batches"
    )
    print(
        f"Processing batch range {start_batch}-{resolved_end_batch} "
        f"({len(selected_batches)} batches this run)"
    )

    timeout = httpx.Timeout(
        connect=UPSERT_CONNECT_TIMEOUT_SECONDS,
        read=UPSERT_READ_TIMEOUT_SECONDS,
        write=UPSERT_WRITE_TIMEOUT_SECONDS,
        pool=UPSERT_POOL_TIMEOUT_SECONDS,
    )
    with httpx.Client(timeout=timeout) as client:
        for run_idx, batch in enumerate(selected_batches, start=1):
            idx = start_batch + run_idx - 1
            _post_batch_or_raise(
                client=client,
                url=url,
                headers=headers,
                batch=batch,
                batch_idx=idx,
                total_batches=total_batches,
            )
            if idx % 20 == 0 or idx == resolved_end_batch:
                print(f"Completed batch {idx}/{total_batches}")
            if batch_delay_seconds > 0:
                time.sleep(batch_delay_seconds)

    print("Pinecone upsert complete.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Upsert similarity records to Pinecone integrated embedding index."
    )
    parser.add_argument("--csv", type=str, default="", help="Path to arXiv CSV file")
    parser.add_argument(
        "--batch-size",
        type=int,
        default=MAX_TEXT_UPSERT_BATCH,
        help=f"Number of records per batch attempt (default: {MAX_TEXT_UPSERT_BATCH})",
    )
    parser.add_argument(
        "--start-batch",
        type=int,
        default=1,
        help="1-indexed batch number to start from (default: 1)",
    )
    parser.add_argument(
        "--end-batch",
        type=int,
        default=0,
        help="1-indexed inclusive batch number to stop at; 0 means run to end",
    )
    parser.add_argument(
        "--batch-delay-seconds",
        type=float,
        default=SINGLE_RECORD_DELAY_SECONDS,
        help=f"Delay between batches to avoid rate limits (default: {SINGLE_RECORD_DELAY_SECONDS}s)",
    )
    args = parser.parse_args()
    csv_path = Path(args.csv) if args.csv else _latest_csv()
    upsert_similarity_records(
        csv_path=csv_path,
        batch_size=args.batch_size,
        start_batch=args.start_batch,
        end_batch=args.end_batch if args.end_batch > 0 else None,
        batch_delay_seconds=max(0.0, args.batch_delay_seconds),
    )


if __name__ == "__main__":
    main()
