#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass
from datetime import date
from html import escape
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring

BASE_KEYWORDS = [
    "简历模板",
    "个人简历模板",
    "求职简历模板",
    "应届生简历模板",
    "实习简历模板",
    "英文简历模板",
    "双语简历模板",
    "创意简历模板",
    "极简简历模板",
    "免费简历模板",
]

INDUSTRIES = [
    "互联网", "产品经理", "UI设计", "前端开发", "后端开发", "数据分析", "新媒体运营", "市场营销", "电商运营", "人力资源",
    "财务会计", "行政文员", "销售顾问", "客服专员", "项目管理", "机械工程", "土木工程", "生物医药", "教育培训", "外贸业务",
]

STYLE_TAGS = ["可编辑", "Word版", "PDF版", "一页式", "ATS友好"]
CITIES = ["北京", "上海", "深圳", "广州", "杭州", "成都", "南京", "武汉"]
NAMES = ["王志强", "刘思雨", "陈凯", "赵磊", "周雨晨", "林嘉宁", "孙博文", "何雅婷"]


@dataclass(frozen=True)
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


def build_keywords(total: int) -> list[tuple[str, str, str]]:
    combos: list[tuple[str, str, str]] = []
    while len(combos) < total:
        for base in BASE_KEYWORDS:
            for industry in INDUSTRIES:
                for style in STYLE_TAGS:
                    combos.append((industry, base, style))
                    if len(combos) >= total:
                        return combos
    return combos


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


def build_faq(page: PageData) -> list[tuple[str, str]]:
    return [
        (f"{page.keyword}适合哪些人？", f"适合目标岗位为{page.industry}的求职者，尤其适配{page.base}场景。"),
        (f"{page.industry}岗位该突出什么内容？", "建议突出可量化成果、业务目标与协作结果，避免只罗列职责。"),
        (f"{page.style}模板有什么优势？", style_hint(page.style) + "，同时支持继续扩展项目经历与技能模块。"),
        ("支持哪些文件格式？", "支持 Word 编辑与 PDF 导出，方便修改和投递。"),
        ("可以用于招聘网站投递吗？", "可以，页面结构遵循主流招聘系统识别逻辑。"),
    ]


def build_reviews(page: PageData) -> list[str]:
    roles = [page.industry, "产品经理", "运营", "开发工程师"]
    reviews: list[str] = []
    for i in range(8):
        name = NAMES[(page.idx + i) % len(NAMES)]
        city = CITIES[(page.idx + i) % len(CITIES)]
        role = roles[i % len(roles)]
        score_text = ["面试邀约明显增加", "排版很专业", "关键词更容易命中", "修改效率很高"][i % 4]
        reviews.append(f"★★★★★ {page.keyword}{score_text}。<br><strong>{name} · {role} · {city}</strong>")
    return reviews


def render_related_cards(pages: list[PageData], current_index: int, count: int = 8) -> str:
    total = len(pages)
    cards: list[str] = []
    for i in range(count):
        p = pages[(current_index + i + 1) % total]
        cards.append(
            f'<a class="card" href="./{p.slug}.html"><img src="images/template{(i % 8) + 1}.png" alt="{escape(p.keyword)}"><div class="card-title">{escape(p.keyword)}</div></a>'
        )
    return "\n".join(cards)


def render_page(page: PageData, pages: list[PageData], base_url: str) -> str:
    title = f"{page.keyword}免费下载 - {page.industry}高通过率简历模板"
    description = (
        f"{page.keyword}精选下载，面向{page.industry}岗位，提供{page.style}模板与可复用项目描述，"
        "支持Word编辑与PDF导出，快速生成专业简历。"
    )
    canonical = f"{base_url.rstrip('/')}/{page.slug}.html"
    keywords_meta = f"{page.keyword},{page.industry}简历模板,{page.style},简历模板下载,Word简历模板,免费简历模板"

    faq_html = "\n".join(f'<div class="faq-item"><h3>{escape(q)}</h3><p>{escape(a)}</p></div>' for q, a in build_faq(page))
    reviews_html = "\n".join(f'<div class="review-card">{r}</div>' for r in build_reviews(page))
    related_html = render_related_cards(pages, page.idx - 1)
    seo_p1, seo_p2 = seo_paragraphs(page)

    return f"""<!DOCTYPE html>
<html lang=\"zh\">...<title>{escape(title)}</title>
<meta name=\"description\" content=\"{escape(description)}\"> 
<meta name=\"keywords\" content=\"{escape(keywords_meta)}\"> 
<link rel=\"canonical\" href=\"{escape(canonical)}\"> 
<body>
<h1>{escape(page.keyword)}</h1>
<section>{related_html}</section>
<section>{reviews_html}</section>
<section>{faq_html}</section>
<p>{escape(seo_p1)}<br><br>{escape(seo_p2)}</p>
</body>
</html>
"""


def render_one(args: tuple[PageData, list[PageData], str]) -> tuple[str, str]:
    page, pages, base_url = args
    return page.slug, render_page(page, pages, base_url)


def write_index(pages: list[PageData], output_dir: Path, base_url: str) -> None:
    items = "\n".join(
        f'<li><a href="./{p.slug}.html">{p.idx:05d}. {escape(p.keyword)}</a> <small>({base_url.rstrip("/")}/{p.slug}.html)</small></li>'
        for p in pages
    )
    html = f"""<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"UTF-8\"/><title>SEO页面目录</title></head><body><ol>{items}</ol></body></html>"""
    (output_dir / "index.html").write_text(html, encoding="utf-8")


def write_keywords_csv(pages: list[PageData], output_dir: Path) -> None:
    with (output_dir / "keywords.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["id", "keyword", "slug", "industry", "base", "style"])
        writer.writerows((p.idx, p.keyword, p.slug, p.industry, p.base, p.style) for p in pages)


def write_sitemap(pages: list[PageData], output_dir: Path, base_url: str) -> None:
    urlset = Element("urlset", xmlns="http://www.sitemaps.org/schemas/sitemap/0.9")
    today = date.today().isoformat()
    for p in pages:
        url = SubElement(urlset, "url")
        SubElement(url, "loc").text = f"{base_url.rstrip('/')}/{p.slug}.html"
        SubElement(url, "lastmod").text = today
        SubElement(url, "changefreq").text = "weekly"
        SubElement(url, "priority").text = "0.8"
    ElementTreeBytes = tostring(urlset, encoding="utf-8", xml_declaration=True)
    (output_dir / "sitemap.xml").write_bytes(ElementTreeBytes)


def generate(output_dir: Path, base_url: str, total: int, workers: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for pattern in ("*.html", "keywords.csv", "sitemap.xml"):
        for old_file in output_dir.glob(pattern):
            old_file.unlink()

    pages = [
        PageData(idx, f"{industry}{base}{style}", slugify(f"{idx}-{industry}{base}{style}"), industry, base, style)
        for idx, (industry, base, style) in enumerate(build_keywords(total), start=1)
    ]

    if workers <= 1:
        for p in pages:
            (output_dir / f"{p.slug}.html").write_text(render_page(p, pages, base_url), encoding="utf-8")
    else:
        with ProcessPoolExecutor(max_workers=workers) as ex:
            for slug, html in ex.map(render_one, ((p, pages, base_url) for p in pages), chunksize=200):
                (output_dir / f"{slug}.html").write_text(html, encoding="utf-8")

    write_index(pages, output_dir, base_url)
    write_keywords_csv(pages, output_dir)
    write_sitemap(pages, output_dir, base_url)


def main() -> None:
    parser = argparse.ArgumentParser(description="批量生成简历模板 SEO 页面（5w级优化版）")
    parser.add_argument("--output", default="dist", help="输出目录")
    parser.add_argument("--base-url", default="https://example.com", help="站点基础 URL")
    parser.add_argument("--total", type=int, default=200, help="生成页面数量")
    parser.add_argument("--workers", type=int, default=1, help="并行进程数；CPU密集模板渲染建议 >1")
    args = parser.parse_args()
    generate(Path(args.output), args.base_url, args.total, args.workers)


if __name__ == "__main__":
    main()
