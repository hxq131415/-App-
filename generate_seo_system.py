#!/usr/bin/env python3
"""One-click SEO page generator.

Generates:
- N SEO HTML pages
- sitemap.xml (with sitemap index support)
- robots.txt
- JSON data index
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


DEFAULT_COUNT = 50_000
SITEMAP_URL_LIMIT = 50_000


@dataclass
class PageRecord:
    id: int
    slug: str
    title: str
    description: str
    keywords: list[str]
    path: str
    url: str
    updated_at: str


def slug_for(index: int) -> str:
    return f"topic-{index:05d}"


def build_record(index: int, base_url: str, keyword_prefix: str, now_iso: str) -> PageRecord:
    slug = slug_for(index)
    title = f"{keyword_prefix} 页面 {index} | {keyword_prefix}指南"
    description = f"这是 {keyword_prefix} 第 {index} 个SEO落地页，提供结构化内容、问答和行动建议。"
    keywords = [keyword_prefix, f"{keyword_prefix}{index}", "SEO", "长尾关键词"]
    path = f"pages/{slug}.html"
    url = f"{base_url}/pages/{slug}.html"
    return PageRecord(
        id=index,
        slug=slug,
        title=title,
        description=description,
        keywords=keywords,
        path=path,
        url=url,
        updated_at=now_iso,
    )


def render_html_page(record: PageRecord, site_name: str) -> str:
    keywords = ", ".join(record.keywords)
    return f"""<!doctype html>
<html lang=\"zh-CN\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>{record.title}</title>
  <meta name=\"description\" content=\"{record.description}\" />
  <meta name=\"keywords\" content=\"{keywords}\" />
  <link rel=\"canonical\" href=\"{record.url}\" />
  <meta property=\"og:title\" content=\"{record.title}\" />
  <meta property=\"og:description\" content=\"{record.description}\" />
  <meta property=\"og:url\" content=\"{record.url}\" />
  <meta property=\"og:type\" content=\"article\" />
  <script type=\"application/ld+json\">\n{json.dumps({
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": record.title,
      "description": record.description,
      "dateModified": record.updated_at,
      "mainEntityOfPage": record.url,
      "inLanguage": "zh-CN",
      "author": {"@type": "Organization", "name": site_name},
  }, ensure_ascii=False, indent=2)}\n  </script>
</head>
<body>
  <main>
    <h1>{record.title}</h1>
    <p>{record.description}</p>
    <p><strong>关键词：</strong>{keywords}</p>
    <section>
      <h2>核心要点</h2>
      <ul>
        <li>页面ID：{record.id}</li>
        <li>Slug：{record.slug}</li>
        <li>最近更新：{record.updated_at}</li>
      </ul>
    </section>
  </main>
</body>
</html>
"""


def chunked(items: list[PageRecord], size: int) -> Iterable[list[PageRecord]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def write_sitemap_files(out_dir: Path, records: list[PageRecord], now_iso: str) -> list[str]:
    sitemap_files: list[str] = []
    chunks = list(chunked(records, SITEMAP_URL_LIMIT))

    if len(chunks) == 1:
        filename = "sitemap.xml"
        write_single_sitemap(out_dir / filename, chunks[0], now_iso)
        return [filename]

    for i, chunk in enumerate(chunks, start=1):
        filename = f"sitemap-{i}.xml"
        write_single_sitemap(out_dir / filename, chunk, now_iso)
        sitemap_files.append(filename)

    index_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for filename in sitemap_files:
        index_lines.append("  <sitemap>")
        index_lines.append(f"    <loc>{filename}</loc>")
        index_lines.append(f"    <lastmod>{now_iso}</lastmod>")
        index_lines.append("  </sitemap>")
    index_lines.append("</sitemapindex>")
    (out_dir / "sitemap.xml").write_text("\n".join(index_lines), encoding="utf-8")
    return ["sitemap.xml", *sitemap_files]


def write_single_sitemap(path: Path, records: list[PageRecord], now_iso: str) -> None:
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for rec in records:
        lines.extend(
            [
                "  <url>",
                f"    <loc>{rec.url}</loc>",
                f"    <lastmod>{now_iso}</lastmod>",
                "    <changefreq>weekly</changefreq>",
                "    <priority>0.6</priority>",
                "  </url>",
            ]
        )
    lines.append("</urlset>")
    path.write_text("\n".join(lines), encoding="utf-8")


def write_robots(out_dir: Path, base_url: str) -> None:
    content = "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            f"Sitemap: {base_url}/sitemap.xml",
        ]
    )
    (out_dir / "robots.txt").write_text(content + "\n", encoding="utf-8")


def run(args: argparse.Namespace) -> None:
    out_dir = Path(args.output).resolve()
    pages_dir = out_dir / "pages"
    out_dir.mkdir(parents=True, exist_ok=True)
    pages_dir.mkdir(parents=True, exist_ok=True)

    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    base_url = args.base_url.rstrip("/")

    records: list[PageRecord] = []
    for i in range(1, args.count + 1):
        record = build_record(i, base_url, args.keyword_prefix, now_iso)
        records.append(record)
        (out_dir / record.path).write_text(render_html_page(record, args.site_name), encoding="utf-8")

    write_sitemap_files(out_dir, records, now_iso)
    write_robots(out_dir, base_url)

    payload = {
        "site": {
            "name": args.site_name,
            "base_url": base_url,
            "generated_at": now_iso,
            "total_pages": args.count,
            "estimated_sitemap_parts": math.ceil(args.count / SITEMAP_URL_LIMIT),
        },
        "pages": [asdict(rec) for rec in records],
    }
    (out_dir / "pages-data.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"Done: generated {args.count} pages at {out_dir}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SEO pages + sitemap + robots + JSON")
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT, help="Number of HTML pages (default: 50000)")
    parser.add_argument("--base-url", default="https://example.com", help="Site base URL")
    parser.add_argument("--site-name", default="SEO自动化站点", help="Site name used in JSON-LD")
    parser.add_argument("--keyword-prefix", default="SEO专题", help="Keyword prefix for titles")
    parser.add_argument("--output", default="dist_seo", help="Output directory")
    return parser.parse_args()


if __name__ == "__main__":
    run(parse_args())
