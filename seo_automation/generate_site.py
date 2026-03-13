#!/usr/bin/env python3
"""Generate SEO landing pages, internal links, and sitemap.xml."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import pathlib
import random
import re
from dataclasses import dataclass
from typing import List
from urllib.parse import quote_plus


MODIFIERS = [
    "2026最新",
    "免费版",
    "电脑版",
    "手机版",
    "高速下载",
    "安装教程",
    "使用指南",
    "官方正版",
    "安全无毒",
]

INTENTS = [
    "下载",
    "官网入口",
    "怎么用",
    "替代方案",
    "评测",
    "功能对比",
]

CTA_BLOCKS = [
    "点击下方按钮立即下载，30 秒完成安装并开始使用。",
    "扫描二维码或直接点击下载链接，按页面步骤快速部署。",
    "建议先阅读安装提示，再进行一键下载，避免兼容性问题。",
]

CONTENT_VARIATIONS = [
    "本页面整理了核心功能、适用场景和安装路径，帮助你在最短时间内上手。",
    "我们提供实际使用建议、常见问题与版本说明，适合新手快速入门。",
    "结合真实业务场景，给出配置建议与使用技巧，减少试错成本。",
    "包含下载步骤、版本差异和推荐组合工具，适用于效率提升场景。",
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


def slugify(text: str) -> str:
    cleaned = re.sub(r"[^\w\u4e00-\u9fff\-\s]", "", text).strip().lower()
    cleaned = re.sub(r"\s+", "-", cleaned)
    return cleaned or "landing-page"


def generate_keywords(seeds: List[str], count: int) -> List[str]:
    combos = []
    for seed in seeds:
        for modifier in MODIFIERS:
            for intent in INTENTS:
                combos.append(f"{seed}{modifier}{intent}")
    random.shuffle(combos)
    unique = []
    seen = set()
    for kw in combos:
        if kw not in seen:
            unique.append(kw)
            seen.add(kw)
        if len(unique) >= count:
            break
    return unique


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
  <text x='80' y='250' fill='white' font-size='56' font-family='Arial, sans-serif' font-weight='bold'>精品下载专题</text>
  <text x='80' y='340' fill='#c7d2fe' font-size='38' font-family='Arial, sans-serif'>{escaped}</text>
  <text x='80' y='430' fill='#dbeafe' font-size='28' font-family='Arial, sans-serif'>高质量落地页 · SEO 自动生成</text>
</svg>"""


def build_pages(site_url: str, brand_name: str, download_url: str, keywords: List[str]) -> List[Page]:
    pages: List[Page] = []
    base = site_url.rstrip("/")
    for i, kw in enumerate(keywords):
        slug = slugify(kw)
        title = f"{kw} - {brand_name}高速安全下载"
        desc = f"{brand_name}提供{kw}专题页，含安装说明、功能亮点、相关推荐与二维码下载入口。"
        content = CONTENT_VARIATIONS[i % len(CONTENT_VARIATIONS)]
        cta = CTA_BLOCKS[i % len(CTA_BLOCKS)]
        preview_path = f"previews/{slug}.svg"
        qr_url = f"https://api.qrserver.com/v1/create-qr-code/?size=200x200&data={quote_plus(download_url)}"
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
            )
        )
    return pages


def render_page(page: Page, related: List[Page], language: str, download_url: str) -> str:
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
    .container {{max-width: 980px; margin: 0 auto; padding: 32px 20px 64px;}}
    .hero {{background: #fff; border-radius: 20px; padding: 28px; box-shadow: 0 10px 30px rgba(2,6,23,.08);}}
    .preview img {{width:100%; border-radius:16px; border:1px solid #e2e8f0;}}
    .grid {{display:grid; grid-template-columns:2fr 1fr; gap:20px; margin-top:20px;}}
    .card {{background:#fff; border-radius:16px; padding:20px; box-shadow: 0 6px 20px rgba(2,6,23,.06);}}
    .cta-btn {{display:inline-block; background:#2563eb; color:#fff; padding:12px 18px; border-radius:10px; text-decoration:none; font-weight:700;}}
    .muted {{color:#475569;}}
    ul {{padding-left: 18px;}}
  </style>
</head>
<body>
  <div class="container">
    <section class="hero">
      <h1>{html.escape(page.keyword)}</h1>
      <p class="muted">{html.escape(page.description)}</p>
      <div class="preview"><img src="../{page.preview_svg}" alt="{html.escape(page.keyword)} 预览图"/></div>
    </section>

    <div class="grid">
      <article class="card">
        <h2>核心介绍</h2>
        <p>{html.escape(page.content)}</p>
        <h3>下载引导</h3>
        <p>{html.escape(page.cta)}</p>
        <p><a class="cta-btn" href="{download_url}" rel="nofollow">立即下载</a></p>
      </article>

      <aside class="card">
        <h3>扫码下载</h3>
        <img src="{page.qr_url}" width="200" height="200" alt="扫码下载二维码"/>
        <p class="muted">扫码可在手机端直接访问下载页。</p>

        <h3>相关推荐</h3>
        <ul>
          {related_items}
        </ul>
      </aside>
    </div>
  </div>
</body>
</html>
"""


def render_index(site_url: str, brand_name: str, pages: List[Page], language: str) -> str:
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
  <meta name="description" content="{html.escape(brand_name)}自动生成的 SEO 专题导航页" />
  <link rel="canonical" href="{site_url.rstrip('/')}/index.html" />
</head>
<body>
  <main style="max-width:900px;margin:30px auto;font-family:Arial,sans-serif;line-height:1.6;">
    <h1>{html.escape(brand_name)} SEO 专题导航</h1>
    <p>以下页面由自动化系统生成，包含独立标题、描述、示意图、相关推荐与下载引导。</p>
    <ul>{links}</ul>
  </main>
</body>
</html>
"""


def build_sitemap(site_url: str, pages: List[Page]) -> str:
    now = dt.date.today().isoformat()
    urls = [f"{site_url.rstrip('/')}/index.html"] + [p.canonical_url for p in pages]
    nodes = "\n".join(
        f"  <url><loc>{u}</loc><lastmod>{now}</lastmod><changefreq>weekly</changefreq><priority>0.8</priority></url>"
        for u in urls
    )
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
{nodes}
</urlset>
"""


def write_outputs(output_dir: pathlib.Path, site_url: str, brand_name: str, download_url: str, pages: List[Page], related_count: int, language: str) -> None:
    pages_dir = output_dir / "pages"
    previews_dir = output_dir / "previews"
    pages_dir.mkdir(parents=True, exist_ok=True)
    previews_dir.mkdir(parents=True, exist_ok=True)

    for idx, page in enumerate(pages):
        pool = [p for p in pages if p.slug != page.slug]
        related = pool[idx % len(pool): idx % len(pool) + related_count] if pool else []
        if len(related) < related_count and pool:
            related.extend(pool[: related_count - len(related)])

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

    with (output_dir / "urls.txt").open("w", encoding="utf-8") as f:
        f.write(f"{site_url.rstrip('/')}/index.html\n")
        for p in pages:
            f.write(f"{p.canonical_url}\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="SEO landing pages generator")
    parser.add_argument("--site-url", required=True, help="Public site URL, e.g. https://example.com")
    parser.add_argument("--brand-name", required=True, help="Brand name used in title/description")
    parser.add_argument("--download-url", required=True, help="Primary download target URL")
    parser.add_argument("--seed", action="append", required=True, help="Seed keyword, can repeat")
    parser.add_argument("--count", type=int, default=36, help="Number of pages to generate")
    parser.add_argument("--related-count", type=int, default=3, help="Related links count per page")
    parser.add_argument("--language", default="zh-CN", help="HTML language tag")
    parser.add_argument("--output-dir", default="dist", help="Output directory")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    random.seed(42)
    keywords = generate_keywords(args.seed, args.count)
    pages = build_pages(args.site_url, args.brand_name, args.download_url, keywords)
    write_outputs(
        output_dir=pathlib.Path(args.output_dir),
        site_url=args.site_url,
        brand_name=args.brand_name,
        download_url=args.download_url,
        pages=pages,
        related_count=max(args.related_count, 1),
        language=args.language,
    )
    print(f"Generated {len(pages)} pages in {args.output_dir}")


if __name__ == "__main__":
    main()
