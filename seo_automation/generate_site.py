#!/usr/bin/env python3
"""Generate scalable SEO keyword library and landing pages."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import json
import pathlib
import random
import re
from dataclasses import dataclass
from typing import Iterable
from urllib.parse import quote_plus


CTA_BLOCKS = [
    "点击下方按钮立即下载，约 30 秒完成安装并开始使用。",
    "支持扫码下载或直接点击下载链接，按提示即可快速完成部署。",
    "建议先查看版本说明与兼容提示，再进行一键下载。",
    "本页提供稳定下载入口，推荐优先使用官方最新版。",
]

CONTENT_VARIATIONS = [
    "本页提供核心功能、安装流程与常见问题，帮助你快速上手。",
    "结合实际使用场景整理了版本差异、推荐配置和避坑建议。",
    "围绕新手与进阶用户需求，提供下载、安装和功能使用全流程指引。",
    "除了下载入口，还整理了相关工具推荐与替代方案，便于横向对比。",
]

FEATURE_TAGS = [
    "高质量模板", "多端同步", "稳定更新", "低门槛上手", "轻量流畅", "高兼容性", "快速导出", "隐私保护"
]


@dataclass
class Page:
    keyword: str
    slug: str
    title: str
    description: str
    content: str
    cta: str
    preview_svg: str
    qr_url: str
    canonical_url: str
    feature_line: str


def slugify(text: str) -> str:
    cleaned = re.sub(r"[^\w\u4e00-\u9fff\-\s]", "", text).strip().lower()
    cleaned = re.sub(r"\s+", "-", cleaned)
    return cleaned or "landing-page"


def load_keyword_config(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def unique_keep_order(seq: Iterable[str]) -> list[str]:
    out: list[str] = []
    seen = set()
    for item in seq:
        if item and item not in seen:
            out.append(item)
            seen.add(item)
    return out


def generate_keyword_library(config: dict, seeds: list[str]) -> list[str]:
    products = unique_keep_order((config.get("products") or []) + seeds)
    modifiers = unique_keep_order(config.get("modifiers") or [])
    intents = unique_keep_order(config.get("intents") or [])
    audiences = unique_keep_order(config.get("audiences") or [])
    scenarios = unique_keep_order(config.get("scenarios") or [])
    platforms = unique_keep_order(config.get("platforms") or [])
    regions = unique_keep_order(config.get("regions") or [])
    years = unique_keep_order(config.get("years") or [])
    question_prefixes = unique_keep_order(config.get("question_prefixes") or [])

    keywords: list[str] = []

    # Pattern A: 产品+修饰+意图
    for p in products:
        for m in modifiers:
            for i in intents:
                keywords.append(f"{p}{m}{i}")

    # Pattern B: 人群 + 产品 + 意图
    for a in audiences:
        for p in products:
            for i in intents:
                keywords.append(f"{a}{p}{i}")

    # Pattern C: 场景 + 产品 + 平台
    for s in scenarios:
        for p in products:
            for pf in platforms:
                keywords.append(f"{s}{p}{pf}")

    # Pattern D: 地域 + 产品 + 意图
    for r in regions:
        for p in products:
            for i in intents:
                keywords.append(f"{r}{p}{i}")

    # Pattern E: 年份 + 产品 + 意图 + 平台
    for y in years:
        for p in products:
            for i in intents:
                for pf in platforms:
                    keywords.append(f"{y}{p}{i}{pf}")

    # Pattern F: 问句意图
    for q in question_prefixes:
        for p in products:
            for i in intents[:10]:
                keywords.append(f"{q}选择{p}{i}")

    return unique_keep_order(keywords)


def preview_svg(keyword: str) -> str:
    escaped = html.escape(keyword)
    return f"""<svg xmlns='http://www.w3.org/2000/svg' width='1200' height='630'>
  <defs>
    <linearGradient id='g' x1='0' y1='0' x2='1' y2='1'>
      <stop offset='0%' stop-color='#0b1023'/>
      <stop offset='100%' stop-color='#1e40af'/>
    </linearGradient>
  </defs>
  <rect width='1200' height='630' fill='url(#g)'/>
  <text x='80' y='250' fill='white' font-size='56' font-family='Arial, sans-serif' font-weight='bold'>SEO 高质量专题页</text>
  <text x='80' y='340' fill='#c7d2fe' font-size='38' font-family='Arial, sans-serif'>{escaped}</text>
  <text x='80' y='430' fill='#dbeafe' font-size='28' font-family='Arial, sans-serif'>独立标题 · 独立描述 · 可收录结构</text>
</svg>"""


def build_pages(site_url: str, brand_name: str, download_url: str, keywords: list[str]) -> list[Page]:
    pages: list[Page] = []
    base = site_url.rstrip("/")

    for i, kw in enumerate(keywords):
        slug = slugify(kw)
        title = f"{kw} - {brand_name}下载与使用指南"
        desc = f"{brand_name}提供{kw}专题，含安装步骤、示意图、相关推荐、二维码下载与版本建议。"
        content = CONTENT_VARIATIONS[i % len(CONTENT_VARIATIONS)]
        cta = CTA_BLOCKS[i % len(CTA_BLOCKS)]
        feature_line = "、".join(random.sample(FEATURE_TAGS, 4))
        preview_path = f"previews/{slug}.svg"
        qr_url = f"https://api.qrserver.com/v1/create-qr-code/?size=220x220&data={quote_plus(download_url)}"
        canonical = f"{base}/pages/{slug}.html"

        pages.append(
            Page(
                keyword=kw,
                slug=slug,
                title=title,
                description=desc,
                content=content,
                cta=cta,
                preview_svg=preview_path,
                qr_url=qr_url,
                canonical_url=canonical,
                feature_line=feature_line,
            )
        )
    return pages


def related_pages(pages: list[Page], index: int, count: int) -> list[Page]:
    if len(pages) <= 1:
        return []
    out = []
    n = len(pages)
    step = 7
    cur = (index + step) % n
    while len(out) < count:
        if cur != index:
            out.append(pages[cur])
        cur = (cur + step) % n
    return out


def render_page(page: Page, related: list[Page], language: str, download_url: str) -> str:
    related_items = "\n".join(
        f'<li><a href="../pages/{r.slug}.html">{html.escape(r.keyword)}</a></li>' for r in related
    )
    return f"""<!doctype html>
<html lang="{language}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>{html.escape(page.title)}</title>
  <meta name="description" content="{html.escape(page.description)}" />
  <link rel="canonical" href="{page.canonical_url}" />
  <meta property="og:title" content="{html.escape(page.title)}" />
  <meta property="og:description" content="{html.escape(page.description)}" />
  <meta property="og:image" content="../{page.preview_svg}" />
  <style>
    body {{font-family: Inter, -apple-system, sans-serif; margin:0; background:#f7f9fc; color:#0f172a;}}
    .container {{max-width: 1040px; margin: 0 auto; padding: 32px 20px 64px;}}
    .hero,.card {{background: #fff; border-radius: 16px; padding: 24px; box-shadow: 0 10px 30px rgba(2,6,23,.08);}}
    .preview img {{width:100%; border-radius:14px; border:1px solid #e2e8f0;}}
    .grid {{display:grid; grid-template-columns:2fr 1fr; gap:20px; margin-top:20px;}}
    .cta-btn {{display:inline-block; background:#2563eb; color:#fff; padding:12px 18px; border-radius:10px; text-decoration:none; font-weight:700;}}
    .muted {{color:#475569;}}
    .chips span {{display:inline-block;padding:6px 10px;margin:4px;border-radius:999px;background:#eff6ff;color:#1e3a8a;font-size:13px;}}
    ul {{padding-left: 18px;}}
  </style>
</head>
<body>
  <div class="container">
    <section class="hero">
      <h1>{html.escape(page.keyword)}</h1>
      <p class="muted">{html.escape(page.description)}</p>
      <div class="chips">{''.join(f'<span>{html.escape(x)}</span>' for x in page.feature_line.split('、'))}</div>
      <div class="preview"><img src="../{page.preview_svg}" alt="{html.escape(page.keyword)} 预览图"/></div>
    </section>
    <div class="grid">
      <article class="card">
        <h2>内容导读</h2>
        <p>{html.escape(page.content)}</p>
        <h3>清晰下载引导</h3>
        <p>{html.escape(page.cta)}</p>
        <p><a class="cta-btn" href="{download_url}" rel="nofollow">立即下载</a></p>
      </article>
      <aside class="card">
        <h3>扫码下载</h3>
        <img src="{page.qr_url}" width="220" height="220" alt="扫码下载二维码"/>
        <p class="muted">扫码可在手机端直接访问下载地址。</p>
        <h3>相关推荐</h3>
        <ul>{related_items}</ul>
      </aside>
    </div>
  </div>
</body>
</html>
"""


def render_index(site_url: str, brand_name: str, pages: list[Page], language: str) -> str:
    links = "\n".join(
        f'<li><a href="pages/{p.slug}.html">{html.escape(p.keyword)}</a> <small>— {html.escape(p.description)}</small></li>'
        for p in pages
    )
    return f"""<!doctype html>
<html lang="{language}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>{html.escape(brand_name)}专题聚合页</title>
  <meta name="description" content="{html.escape(brand_name)}自动生成的SEO专题导航页" />
  <link rel="canonical" href="{site_url.rstrip('/')}/index.html" />
</head>
<body>
  <main style="max-width:980px;margin:30px auto;font-family:Arial,sans-serif;line-height:1.6;">
    <h1>{html.escape(brand_name)} SEO 专题导航</h1>
    <p>页面自动生成：独立标题、独立描述、差异内容、示意图、相关推荐、二维码下载与清晰下载引导。</p>
    <ul>{links}</ul>
  </main>
</body>
</html>
"""


def build_sitemap(site_url: str, pages: list[Page]) -> str:
    now = dt.date.today().isoformat()
    urls = [f"{site_url.rstrip('/')}/index.html"] + [p.canonical_url for p in pages]
    nodes = "\n".join(
        f"  <url><loc>{u}</loc><lastmod>{now}</lastmod><changefreq>daily</changefreq><priority>0.8</priority></url>"
        for u in urls
    )
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
{nodes}
</urlset>
"""


def write_outputs(output_dir: pathlib.Path, site_url: str, brand_name: str, download_url: str, pages: list[Page], related_count: int, language: str, keyword_library: list[str], clean_output: bool) -> None:
    pages_dir = output_dir / "pages"
    previews_dir = output_dir / "previews"
    output_dir.mkdir(parents=True, exist_ok=True)
    pages_dir.mkdir(parents=True, exist_ok=True)
    previews_dir.mkdir(parents=True, exist_ok=True)

    if clean_output:
        for old in pages_dir.glob("*.html"):
            old.unlink()
        for old in previews_dir.glob("*.svg"):
            old.unlink()

    for idx, page in enumerate(pages):
        related = related_pages(pages, idx, related_count)
        (pages_dir / f"{page.slug}.html").write_text(
            render_page(page, related, language, download_url), encoding="utf-8"
        )
        (output_dir / page.preview_svg).write_text(preview_svg(page.keyword), encoding="utf-8")

    (output_dir / "index.html").write_text(render_index(site_url, brand_name, pages, language), encoding="utf-8")
    (output_dir / "sitemap.xml").write_text(build_sitemap(site_url, pages), encoding="utf-8")

    with (output_dir / "keywords.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["keyword", "slug", "url", "title", "description"])
        for p in pages:
            writer.writerow([p.keyword, p.slug, p.canonical_url, p.title, p.description])

    with (output_dir / "keyword_library.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["keyword"])
        for kw in keyword_library:
            writer.writerow([kw])

    with (output_dir / "urls.txt").open("w", encoding="utf-8") as f:
        f.write(f"{site_url.rstrip('/')}/index.html\n")
        for p in pages:
            f.write(f"{p.canonical_url}\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="SEO landing pages generator")
    parser.add_argument("--site-url", required=True, help="Public site URL, e.g. https://example.com")
    parser.add_argument("--brand-name", required=True, help="Brand name used in title/description")
    parser.add_argument("--download-url", required=True, help="Primary download target URL")
    parser.add_argument("--seed", action="append", default=[], help="Custom seed keyword, can repeat")
    parser.add_argument("--keyword-config", default="seo_automation/keyword_library.json", help="Keyword library config json path")
    parser.add_argument("--min-keyword-library", type=int, default=50000, help="Minimum expected keyword library size")
    parser.add_argument("--page-count", type=int, default=200, help="Number of pages to generate from keyword library")
    parser.add_argument("--related-count", type=int, default=6, help="Related links count per page")
    parser.add_argument("--language", default="zh-CN", help="HTML language tag")
    parser.add_argument("--output-dir", default="dist", help="Output directory")
    parser.add_argument("--clean-output", action="store_true", help="Clean old pages/previews before generation")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    random.seed(42)

    config = load_keyword_config(pathlib.Path(args.keyword_config))
    keyword_library = generate_keyword_library(config, args.seed)
    if len(keyword_library) < args.min_keyword_library:
        raise SystemExit(
            f"关键词库规模不足：{len(keyword_library)}，低于 --min-keyword-library={args.min_keyword_library}"
        )

    chosen = keyword_library[: min(args.page_count, len(keyword_library))]
    pages = build_pages(args.site_url, args.brand_name, args.download_url, chosen)

    write_outputs(
        output_dir=pathlib.Path(args.output_dir),
        site_url=args.site_url,
        brand_name=args.brand_name,
        download_url=args.download_url,
        pages=pages,
        related_count=max(args.related_count, 1),
        language=args.language,
        keyword_library=keyword_library,
        clean_output=args.clean_output,
    )

    print(
        f"Keyword library size={len(keyword_library)}; generated pages={len(pages)} in {args.output_dir}"
    )


if __name__ == "__main__":
    main()
