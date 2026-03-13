#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from datetime import date
from html import escape
from pathlib import Path
from string import Template
from xml.etree.ElementTree import Element, ElementTree, SubElement


@dataclass
class PageData:
    idx: int
    keyword: str
    slug: str
    industry: str
    base: str
    style: str


def slugify(text: str) -> str:
    cleaned = text.replace(" ", "-").replace("/", "-")
    safe_chars: list[str] = []
    for ch in cleaned:
        if ch.isalnum() or ch in "-_":
            safe_chars.append(ch.lower())
        else:
            safe_chars.append(f"u{ord(ch):x}")
    return "resume-" + "".join(safe_chars)


def style_hint(style: str) -> str:
    mapping = {
        "可编辑": "适合快速二次修改",
        "Word版": "便于在 Word 中细致排版",
        "PDF版": "适合直接投递，版式更稳定",
        "一页式": "信息更聚焦，适合校招与初筛",
        "ATS友好": "关键词命中率更高，更易通过筛选",
    }
    return mapping.get(style, "支持多场景求职")


def seo_paragraphs(page: PageData) -> tuple[str, str]:
    p1 = (
        f"{page.keyword}专题为 {page.industry} 方向求职者定制，覆盖个人优势、项目经历、成果数据与岗位关键词布局。"
        f"本页模板强调“{style_hint(page.style)}”，可用于校招、社招与转岗场景。"
    )
    p2 = (
        f"如果你正在准备 {page.industry} 岗位面试，建议优先补充与 JD 对齐的技能词，并用量化结果呈现价值。"
        f"例如“负责 A/B 测试后转化率提升 27%”“独立交付 3 个版本上线”。"
    )
    return p1, p2


def build_keywords(config: dict, total: int = 200) -> list[tuple[str, str, str]]:
    combos: list[tuple[str, str, str]] = []
    for base in config["base_keywords"]:
        for industry in config["industries"]:
            for style in config["style_tags"]:
                combos.append((industry, base, style))
                if len(combos) >= total:
                    return combos
    return combos[:total]


def build_faq(page: PageData) -> list[tuple[str, str]]:
    return [
        (f"{page.keyword}适合哪些人？", f"适合目标岗位为{page.industry}的求职者，尤其适配{page.base}场景。"),
        (f"{page.industry}岗位该突出什么内容？", "建议突出可量化成果、业务目标与协作结果，避免只罗列职责。"),
        (f"{page.style}模板有什么优势？", style_hint(page.style) + "，同时支持继续扩展项目经历与技能模块。"),
        ("支持哪些文件格式？", "支持 Word 编辑与 PDF 导出，方便修改和投递。"),
        ("可以用于招聘网站投递吗？", "可以，页面结构遵循主流招聘系统识别逻辑。"),
    ]


def build_reviews(page: PageData, config: dict) -> list[str]:
    roles = [page.industry, "产品经理", "运营", "开发工程师"]
    names = config["names"]
    cities = config["cities"]
    reviews: list[str] = []
    for i in range(8):
        name = names[(page.idx + i) % len(names)]
        city = cities[(page.idx + i) % len(cities)]
        role = roles[i % len(roles)]
        score_text = ["面试邀约明显增加", "排版很专业", "关键词更容易命中", "修改效率很高"][i % 4]
        reviews.append(f"★★★★★ {page.keyword}{score_text}。<br><strong>{name} · {role} · {city}</strong>")
    return reviews


def render_related_cards(pages: list[PageData], current_index: int, count: int = 8) -> str:
    related: list[PageData] = []
    for offset in range(1, len(pages)):
        if len(related) >= count:
            break
        related.append(pages[(current_index + offset) % len(pages)])
    return "\n".join(
        f'<a class="card" href="./{p.slug}.html"><img src="images/template{(i % 8) + 1}.png" alt="{escape(p.keyword)}"><div class="card-title">{escape(p.keyword)}</div></a>'
        for i, p in enumerate(related)
    )


def render_page(page: PageData, pages: list[PageData], base_url: str, template: Template, config: dict) -> str:
    title = f"{page.keyword}免费下载 - {page.industry}高通过率简历模板"
    description = (
        f"{page.keyword}精选下载，面向{page.industry}岗位，提供{page.style}模板与可复用项目描述，"
        "支持Word编辑与PDF导出，快速生成专业简历。"
    )
    canonical = f"{base_url.rstrip('/')}/pages/{page.slug}.html"
    keywords_meta = f"{page.keyword},{page.industry}简历模板,{page.style},简历模板下载,Word简历模板,免费简历模板"

    faq_html = "\n".join(
        f'<div class="faq-item"><h3>{escape(q)}</h3><p>{escape(a)}</p></div>' for q, a in build_faq(page)
    )
    reviews_html = "\n".join(f'<div class="review-card">{r}</div>' for r in build_reviews(page, config))
    related_html = render_related_cards(pages, page.idx - 1)
    seo_p1, seo_p2 = seo_paragraphs(page)

    return template.safe_substitute(
        title=escape(title),
        description=escape(description),
        keywords_meta=escape(keywords_meta),
        canonical=escape(canonical),
        keyword=escape(page.keyword),
        industry=escape(page.industry),
        style=escape(page.style),
        faq_html=faq_html,
        reviews_html=reviews_html,
        related_html=related_html,
        seo_p1=escape(seo_p1),
        seo_p2=escape(seo_p2),
    )


def write_index(pages: list[PageData], pages_output_dir: Path, base_url: str) -> None:
    items = "\n".join(
        f'<li><a href="./{p.slug}.html">{p.idx:03d}. {escape(p.keyword)}</a> <small>({base_url.rstrip("/")}/pages/{p.slug}.html)</small></li>'
        for p in pages
    )
    html = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>简历模板SEO页面目录</title>
  <meta name="description" content="批量生成的简历模板SEO页面目录，可直接用于静态站点部署。" />
</head>
<body>
  <main>
    <h1>简历模板SEO页面目录</h1>
    <ol>{items}</ol>
  </main>
</body>
</html>
"""
    (pages_output_dir / "index.html").write_text(html, encoding="utf-8")


def write_keywords_csv(pages: list[PageData], data_output_dir: Path) -> None:
    with (data_output_dir / "keywords.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["id", "keyword", "slug", "industry", "base", "style", "url"])
        for p in pages:
            writer.writerow([p.idx, p.keyword, p.slug, p.industry, p.base, p.style, f"/pages/{p.slug}.html"])


def write_keyword_library(data_output_dir: Path, config: dict) -> None:
    with (data_output_dir / "keyword_library.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["industry", "base", "style", "keyword"])
        for base in config["base_keywords"]:
            for industry in config["industries"]:
                for style in config["style_tags"]:
                    writer.writerow([industry, base, style, f"{industry}{base}{style}"])


def write_sitemap(pages: list[PageData], data_output_dir: Path, base_url: str) -> None:
    urlset = Element("urlset", xmlns="http://www.sitemaps.org/schemas/sitemap/0.9")
    today = date.today().isoformat()
    for p in pages:
        url = SubElement(urlset, "url")
        SubElement(url, "loc").text = f"{base_url.rstrip('/')}/pages/{p.slug}.html"
        SubElement(url, "lastmod").text = today
        SubElement(url, "changefreq").text = "weekly"
        SubElement(url, "priority").text = "0.8"

    index_url = SubElement(urlset, "url")
    SubElement(index_url, "loc").text = f"{base_url.rstrip('/')}/pages/index.html"
    SubElement(index_url, "lastmod").text = today
    SubElement(index_url, "changefreq").text = "daily"
    SubElement(index_url, "priority").text = "1.0"
    ElementTree(urlset).write(data_output_dir / "sitemap.xml", encoding="utf-8", xml_declaration=True)


def write_urls_txt(pages: list[PageData], data_output_dir: Path, base_url: str) -> None:
    lines = [f"{base_url.rstrip('/')}/pages/{p.slug}.html" for p in pages]
    lines.append(f"{base_url.rstrip('/')}/pages/index.html")
    (data_output_dir / "urls.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate(pages_output_dir: Path, data_output_dir: Path, base_url: str, total: int, config: dict, template: Template) -> None:
    pages_output_dir.mkdir(parents=True, exist_ok=True)
    data_output_dir.mkdir(parents=True, exist_ok=True)

    for old_file in pages_output_dir.glob("*.html"):
        old_file.unlink()

    for filename in ("keywords.csv", "keyword_library.csv", "sitemap.xml", "urls.txt"):
        p = data_output_dir / filename
        if p.exists():
            p.unlink()

    pages: list[PageData] = []
    for idx, (industry, base, style) in enumerate(build_keywords(config, total), start=1):
        keyword = f"{industry}{base}{style}"
        pages.append(PageData(idx, keyword, slugify(f"{idx}-{keyword}"), industry, base, style))

    for page in pages:
        (pages_output_dir / f"{page.slug}.html").write_text(
            render_page(page, pages, base_url, template, config), encoding="utf-8"
        )

    write_index(pages, pages_output_dir, base_url)
    write_keywords_csv(pages, data_output_dir)
    write_keyword_library(data_output_dir, config)
    write_sitemap(pages, data_output_dir, base_url)
    write_urls_txt(pages, data_output_dir, base_url)


def main() -> None:
    parser = argparse.ArgumentParser(description="批量生成简历模板 SEO 页面")
    parser.add_argument("--pages-output", default="pages", help="HTML输出目录，默认 pages")
    parser.add_argument("--data-output", default="dist", help="数据输出目录（csv/xml/txt），默认 dist")
    parser.add_argument("--base-url", default="https://example.com", help="站点基础 URL")
    parser.add_argument("--total", type=int, default=200, help="生成页面数量，默认 200")
    parser.add_argument("--config", default="seo_automation/config/resume_config.json", help="关键词与参数配置文件")
    parser.add_argument("--template", default="seo_automation/templates/landing_page.html", help="落地页HTML模板文件")
    args = parser.parse_args()

    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    template = Template(Path(args.template).read_text(encoding="utf-8"))

    generate(
        pages_output_dir=Path(args.pages_output),
        data_output_dir=Path(args.data_output),
        base_url=args.base_url,
        total=args.total,
        config=config,
        template=template,
    )


if __name__ == "__main__":
    main()
