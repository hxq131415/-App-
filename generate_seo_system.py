#!/usr/bin/env python3
"""One-click SEO page generator with external template/config support."""

from __future__ import annotations

import argparse
import html
import json
import math
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from string import Template
from typing import Iterable

DEFAULT_COUNT = 50_000
SITEMAP_URL_LIMIT = 50_000

DEFAULT_CONFIG = {
    "site_name": "SEO自动化站点",
    "base_url": "https://example.com",
    "keyword_prefix": "SEO专题",
    "default_keywords": ["SEO", "长尾关键词", "内容营销"],
}

DEFAULT_TEMPLATE = """<!doctype html>
<html lang=\"zh-CN\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>${title}</title>
  <meta name=\"description\" content=\"${description}\" />
  <meta name=\"keywords\" content=\"${keywords}\" />
  <link rel=\"canonical\" href=\"${url}\" />
  <meta property=\"og:title\" content=\"${title}\" />
  <meta property=\"og:description\" content=\"${description}\" />
  <meta property=\"og:url\" content=\"${url}\" />
  <meta property=\"og:type\" content=\"article\" />
  <script type=\"application/ld+json\">${json_ld}</script>
</head>
<body>
  <main>
    <h1>${title}</h1>
    <p>${description}</p>
    <p><strong>关键词：</strong>${keywords}</p>
    <section>
      <h2>核心要点</h2>
      <ul>
        <li>页面ID：${id}</li>
        <li>Slug：${slug}</li>
        <li>最近更新：${updated_at}</li>
      </ul>
    </section>
  </main>
</body>
</html>
"""


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


def ensure_default_files(config_path: Path, template_path: Path) -> None:
    config_path.parent.mkdir(parents=True, exist_ok=True)
    template_path.parent.mkdir(parents=True, exist_ok=True)

    if not config_path.exists():
        config_path.write_text(json.dumps(DEFAULT_CONFIG, ensure_ascii=False, indent=2), encoding="utf-8")

    if not template_path.exists():
        template_path.write_text(DEFAULT_TEMPLATE, encoding="utf-8")


def load_config(config_path: Path) -> dict:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    missing = [k for k in ["site_name", "base_url", "keyword_prefix", "default_keywords"] if k not in config]
    if missing:
        raise ValueError(f"Missing keys in config: {', '.join(missing)}")
    return config


def slug_for(index: int) -> str:
    return f"topic-{index:05d}"


def build_record(index: int, base_url: str, keyword_prefix: str, common_keywords: list[str], now_iso: str) -> PageRecord:
    slug = slug_for(index)
    title = f"{keyword_prefix} 页面 {index} | {keyword_prefix}指南"
    description = f"这是 {keyword_prefix} 第 {index} 个SEO落地页，提供结构化内容、问答和行动建议。"
    keywords = [keyword_prefix, f"{keyword_prefix}{index}", *common_keywords]
    path = f"{slug}.html"
    url = f"{base_url}/pages/{slug}.html"
    return PageRecord(index, slug, title, description, keywords, path, url, now_iso)


def render_html_page(record: PageRecord, site_name: str, template_str: str) -> str:
    tpl = Template(template_str)
    json_ld = json.dumps(
        {
            "@context": "https://schema.org",
            "@type": "Article",
            "headline": record.title,
            "description": record.description,
            "dateModified": record.updated_at,
            "mainEntityOfPage": record.url,
            "inLanguage": "zh-CN",
            "author": {"@type": "Organization", "name": site_name},
        },
        ensure_ascii=False,
    )
    keywords = ", ".join(record.keywords)
    return tpl.safe_substitute(
        id=record.id,
        slug=record.slug,
        title=html.escape(record.title, quote=True),
        description=html.escape(record.description, quote=True),
        keywords=html.escape(keywords, quote=True),
        url=html.escape(record.url, quote=True),
        updated_at=record.updated_at,
        json_ld=json_ld,
    )


def chunked(items: list[PageRecord], size: int) -> Iterable[list[PageRecord]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


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


def write_sitemap_files(meta_dir: Path, records: list[PageRecord], now_iso: str, base_url: str) -> list[str]:
    sitemap_files: list[str] = []
    chunks = list(chunked(records, SITEMAP_URL_LIMIT))

    if len(chunks) == 1:
        filename = "sitemap.xml"
        write_single_sitemap(meta_dir / filename, chunks[0], now_iso)
        return [f"{base_url}/{filename}"]

    for i, chunk in enumerate(chunks, start=1):
        filename = f"sitemap-{i}.xml"
        write_single_sitemap(meta_dir / filename, chunk, now_iso)
        sitemap_files.append(filename)

    index_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for filename in sitemap_files:
        index_lines.append("  <sitemap>")
        index_lines.append(f"    <loc>{base_url}/{filename}</loc>")
        index_lines.append(f"    <lastmod>{now_iso}</lastmod>")
        index_lines.append("  </sitemap>")
    index_lines.append("</sitemapindex>")
    (meta_dir / "sitemap.xml").write_text("\n".join(index_lines), encoding="utf-8")
    return [f"{base_url}/sitemap.xml", *[f"{base_url}/{name}" for name in sitemap_files]]


def write_robots(meta_dir: Path, base_url: str) -> None:
    content = "\n".join(["User-agent: *", "Allow: /", f"Sitemap: {base_url}/sitemap.xml"])
    (meta_dir / "robots.txt").write_text(content + "\n", encoding="utf-8")


def run(args: argparse.Namespace) -> None:
    project_root = Path(args.project_root).resolve()
    pages_dir = (project_root / args.pages_dir).resolve()
    meta_dir = (project_root / args.meta_dir).resolve()
    config_path = (project_root / args.config).resolve()
    template_path = (project_root / args.template).resolve()

    ensure_default_files(config_path, template_path)
    config = load_config(config_path)
    template_str = template_path.read_text(encoding="utf-8")

    pages_dir.mkdir(parents=True, exist_ok=True)
    meta_dir.mkdir(parents=True, exist_ok=True)

    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    base_url = config["base_url"].rstrip("/")

    records: list[PageRecord] = []
    for i in range(1, args.count + 1):
        record = build_record(i, base_url, config["keyword_prefix"], config["default_keywords"], now_iso)
        records.append(record)
        (pages_dir / record.path).write_text(render_html_page(record, config["site_name"], template_str), encoding="utf-8")

    sitemap_files = write_sitemap_files(meta_dir, records, now_iso, base_url)
    write_robots(meta_dir, base_url)

    payload = {
        "site": {
            "name": config["site_name"],
            "base_url": base_url,
            "generated_at": now_iso,
            "total_pages": args.count,
            "estimated_sitemap_parts": math.ceil(args.count / SITEMAP_URL_LIMIT),
            "pages_dir": str(pages_dir.relative_to(project_root)),
            "meta_dir": str(meta_dir.relative_to(project_root)),
            "template": str(template_path.relative_to(project_root)),
            "config": str(config_path.relative_to(project_root)),
        },
        "sitemaps": sitemap_files,
        "pages": [asdict(rec) for rec in records],
    }
    (meta_dir / "pages-data.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    keywords_library = sorted({kw for rec in records for kw in rec.keywords})
    (meta_dir / "keywords.txt").write_text("\n".join(keywords_library) + "\n", encoding="utf-8")

    print(f"Done: generated {args.count} pages -> {pages_dir}")
    print(f"Meta files -> {meta_dir}")
    print(f"Template: {template_path}")
    print(f"Config: {config_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SEO pages + sitemap + robots + JSON with external template")
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT, help="Number of HTML pages (default: 50000)")
    parser.add_argument("--project-root", default=".", help="Project root directory")
    parser.add_argument("--pages-dir", default="pages", help="Directory for generated HTML pages")
    parser.add_argument("--meta-dir", default="dist", help="Directory for sitemap/robots/json/keywords")
    parser.add_argument("--config", default="seo.config.json", help="SEO config JSON path (relative to project root)")
    parser.add_argument("--template", default="templates/page_template.html", help="HTML template path (relative to project root)")
    return parser.parse_args()


if __name__ == "__main__":
    run(parse_args())
