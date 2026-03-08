#!/usr/bin/env python3
"""Submit URLs to search engines via IndexNow and Baidu APIs."""

from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Submit URLs to search engines")
    parser.add_argument("--site", required=True, help="Site base URL, e.g. https://example.com")
    parser.add_argument("--urls-file", required=True, help="A text file with one URL per line")
    parser.add_argument(
        "--engines",
        default="indexnow,baidu",
        help="Comma-separated engines: indexnow,baidu",
    )
    return parser.parse_args()


def load_urls(path: Path) -> list[str]:
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def post_json(url: str, payload: dict, headers: dict | None = None) -> tuple[int, str]:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    if headers:
        for key, value in headers.items():
            req.add_header(key, value)

    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.getcode(), resp.read().decode("utf-8", errors="ignore")


def post_text(url: str, payload: str) -> tuple[int, str]:
    req = urllib.request.Request(url, data=payload.encode("utf-8"), method="POST")
    req.add_header("Content-Type", "text/plain")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.getcode(), resp.read().decode("utf-8", errors="ignore")


def submit_indexnow(site: str, urls: list[str]) -> None:
    key = os.getenv("INDEXNOW_KEY")
    if not key:
        print("[IndexNow] Skip: INDEXNOW_KEY is not set")
        return

    host = site.replace("https://", "").replace("http://", "").split("/")[0]
    payload = {
        "host": host,
        "key": key,
        "urlList": urls,
    }

    try:
        status, body = post_json("https://api.indexnow.org/indexnow", payload)
        print(f"[IndexNow] status={status}, body={body[:300]}")
    except urllib.error.HTTPError as e:
        print(f"[IndexNow] HTTPError: {e.code} {e.read().decode('utf-8', errors='ignore')[:300]}")
    except Exception as e:
        print(f"[IndexNow] Error: {e}")


def submit_baidu(urls: list[str]) -> None:
    site = os.getenv("BAIDU_SITE")
    token = os.getenv("BAIDU_TOKEN")
    if not site or not token:
        print("[Baidu] Skip: BAIDU_SITE or BAIDU_TOKEN is not set")
        return

    endpoint = f"http://data.zz.baidu.com/urls?site={site}&token={token}"
    try:
        status, body = post_text(endpoint, "\n".join(urls))
        print(f"[Baidu] status={status}, body={body[:300]}")
    except urllib.error.HTTPError as e:
        print(f"[Baidu] HTTPError: {e.code} {e.read().decode('utf-8', errors='ignore')[:300]}")
    except Exception as e:
        print(f"[Baidu] Error: {e}")


def main() -> None:
    args = parse_args()
    urls = load_urls(Path(args.urls_file))
    engines = {e.strip().lower() for e in args.engines.split(",") if e.strip()}

    if not urls:
        print("No URLs found; nothing to submit")
        return

    if "indexnow" in engines:
        submit_indexnow(args.site, urls)
    if "baidu" in engines:
        submit_baidu(urls)


if __name__ == "__main__":
    main()
