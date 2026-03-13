#!/usr/bin/env python3
"""Submit generated URLs to IndexNow, Baidu, and Google sitemap ping."""

from __future__ import annotations

import argparse
import json
import pathlib
import urllib.parse
import urllib.request


def load_urls(url_list: pathlib.Path) -> list[str]:
    return [line.strip() for line in url_list.read_text(encoding="utf-8").splitlines() if line.strip()]


def submit_indexnow(site_url: str, key: str, key_location: str, urls: list[str]) -> dict:
    payload = {
        "host": urllib.parse.urlparse(site_url).netloc,
        "key": key,
        "keyLocation": key_location,
        "urlList": urls,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        "https://api.indexnow.org/indexnow",
        data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return {"status": resp.status, "body": resp.read().decode("utf-8", errors="ignore")}


def submit_baidu(site_url: str, token: str, urls: list[str]) -> dict:
    host = urllib.parse.urlparse(site_url).netloc
    endpoint = f"http://data.zz.baidu.com/urls?site={host}&token={token}"
    body = "\n".join(urls).encode("utf-8")
    req = urllib.request.Request(endpoint, data=body, method="POST")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return {"status": resp.status, "body": resp.read().decode("utf-8", errors="ignore")}


def submit_google_sitemap(sitemap_url: str) -> dict:
    ping = f"https://www.google.com/ping?sitemap={urllib.parse.quote_plus(sitemap_url)}"
    with urllib.request.urlopen(ping, timeout=30) as resp:
        return {"status": resp.status, "body": resp.read().decode("utf-8", errors="ignore")}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Submit URLs to search engines")
    parser.add_argument("--engine", choices=["indexnow", "baidu", "google"], required=True)
    parser.add_argument("--site-url", required=True, help="Site URL")
    parser.add_argument("--url-list", default="dist/urls.txt", help="Local URL list file")

    parser.add_argument("--key", help="IndexNow key")
    parser.add_argument("--key-location", help="IndexNow key location URL")

    parser.add_argument("--token", help="Baidu push token")

    parser.add_argument("--sitemap-url", help="Google sitemap URL")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.engine == "indexnow":
        if not args.key or not args.key_location:
            raise SystemExit("indexnow 需要 --key 和 --key-location")
        urls = load_urls(pathlib.Path(args.url_list))
        result = submit_indexnow(args.site_url, args.key, args.key_location, urls)

    elif args.engine == "baidu":
        if not args.token:
            raise SystemExit("baidu 需要 --token")
        urls = load_urls(pathlib.Path(args.url_list))
        result = submit_baidu(args.site_url, args.token, urls)

    else:  # google
        sitemap_url = args.sitemap_url or f"{args.site_url.rstrip('/')}/sitemap.xml"
        result = submit_google_sitemap(sitemap_url)

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
