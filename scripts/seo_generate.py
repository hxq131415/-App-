#!/usr/bin/env python3
"""Generate SEO static pages, sitemap, robots and URL list."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SEO static pages")
    parser.add_argument("--input", required=True, help="Path to pages.json")
    parser.add_argument("--output", required=True, help="Output directory")
    parser.add_argument(
        "--template",
        default="templates/page.html",
        help="Path to HTML template",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def render(template: str, context: dict) -> str:
    out = template
    for key, value in context.items():
        out = out.replace("{{" + key + "}}", str(value))
    return out


def build_internal_links(pages: list[dict], current_slug: str) -> str:
    links = []
    for page in pages:
        if page["slug"] == current_slug:
            continue
        links.append(
            f'<li><a href="/{page["slug"]}.html">{page.get("h1", page["title"])}</a></li>'
        )
    return "\n".join(links)


def generate_pages(payload: dict, template: str, output_dir: Path) -> list[str]:
    site = payload["site"]
    pages = payload["pages"]
    base_url = site["base_url"].rstrip("/")
    urls = []

    for page in pages:
        slug = page["slug"]
        file_name = f"{slug}.html"
        canonical_url = f"{base_url}/{file_name}"
        urls.append(canonical_url)

        context = {
            "language": site.get("language", "zh-CN"),
            "title": page["title"],
            "description": page["description"],
            "keywords": ",".join(page.get("keywords", [])),
            "canonical_url": canonical_url,
            "h1": page.get("h1", page["title"]),
            "intro": page.get("intro", page["description"]),
            "download_url": page.get("download_url", site["default_download_url"]),
            "scan_text": site.get("default_scan_text", "扫码下载 App"),
            "app_name": site.get("app_name", "App"),
            "brand": site.get("brand", "Brand"),
            "internal_links_html": build_internal_links(pages, slug),
        }
        html = render(template, context)
        (output_dir / file_name).write_text(html, encoding="utf-8")

    return urls


def generate_sitemap(urls: list[str], output_dir: Path) -> None:
    lastmod = datetime.now(timezone.utc).date().isoformat()
    entries = "\n".join(
        [
            "  <url>\n"
            f"    <loc>{url}</loc>\n"
            f"    <lastmod>{lastmod}</lastmod>\n"
            "    <changefreq>weekly</changefreq>\n"
            "    <priority>0.8</priority>\n"
            "  </url>"
            for url in urls
        ]
    )

    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{entries}\n"
        "</urlset>\n"
    )
    (output_dir / "sitemap.xml").write_text(xml, encoding="utf-8")


def generate_robots(base_url: str, output_dir: Path) -> None:
    robots = (
        "User-agent: *\n"
        "Allow: /\n\n"
        f"Sitemap: {base_url.rstrip('/')}/sitemap.xml\n"
    )
    (output_dir / "robots.txt").write_text(robots, encoding="utf-8")


def write_url_list(urls: list[str], output_dir: Path) -> None:
    (output_dir / "search-engine-urls.txt").write_text("\n".join(urls) + "\n", encoding="utf-8")


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_dir = Path(args.output)
    template_path = Path(args.template)

    output_dir.mkdir(parents=True, exist_ok=True)

    payload = load_json(input_path)
    template = template_path.read_text(encoding="utf-8")

    urls = generate_pages(payload, template, output_dir)
    generate_sitemap(urls, output_dir)
    generate_robots(payload["site"]["base_url"], output_dir)
    write_url_list(urls, output_dir)

    print(f"Generated {len(urls)} pages into: {output_dir}")


if __name__ == "__main__":
    main()
