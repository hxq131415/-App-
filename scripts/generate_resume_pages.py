#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, ElementTree

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
    "互联网",
    "产品经理",
    "UI设计",
    "前端开发",
    "后端开发",
    "数据分析",
    "新媒体运营",
    "市场营销",
    "电商运营",
    "人力资源",
    "财务会计",
    "行政文员",
    "销售顾问",
    "客服专员",
    "项目管理",
    "机械工程",
    "土木工程",
    "生物医药",
    "教育培训",
    "外贸业务",
]

STYLE_TAGS = ["可编辑", "Word版", "PDF版", "一页式", "ATS友好"]


@dataclass
class PageData:
    idx: int
    keyword: str
    slug: str


def slugify(text: str) -> str:
    cleaned = text.replace(" ", "-").replace("/", "-")
    ascii_safe = []
    for ch in cleaned:
        if ch.isalnum() or ch in "-_":
            ascii_safe.append(ch.lower())
        else:
            ascii_safe.append(f"{ord(ch):x}")
    return "resume-" + "".join(ascii_safe)


def build_keywords(total: int = 200) -> list[str]:
    keywords: list[str] = []
    for base in BASE_KEYWORDS:
        for industry in INDUSTRIES:
            for style in STYLE_TAGS:
                phrase = f"{industry}{base}{style}"
                keywords.append(phrase)
                if len(keywords) >= total:
                    return keywords
    return keywords[:total]


def seo_copy(keyword: str, idx: int) -> dict[str, str]:
    title = f"{keyword} - 第{idx}套高转化简历模板下载"
    description = (
        f"{keyword}精选示例，包含岗位亮点、项目经历、技能模块与自我评价结构。"
        "支持在线预览与一键下载，适配校招、社招与转行求职场景。"
    )
    intro = (
        f"这是一套围绕“{keyword}”构建的SEO优化页面，帮助用户快速匹配岗位关键词，"
        "并输出结构清晰、可读性高的简历内容。"
    )
    bullets = [
        "模块化结构：个人信息 / 求职意向 / 核心技能 / 工作经历 / 项目经历 / 教育背景。",
        "ATS关键词覆盖：提升招聘系统检索命中率，减少简历被忽略的概率。",
        "适配多场景：应届生、社招、转岗、跨行业求职都可直接复用。",
    ]
    return {
        "title": title,
        "description": description,
        "intro": intro,
        "bullets": "\n".join(f"<li>{b}</li>" for b in bullets),
    }


def render_html(page: PageData, base_url: str) -> str:
    seo = seo_copy(page.keyword, page.idx)
    canonical = f"{base_url.rstrip('/')}/{page.slug}.html"
    return f"""<!doctype html>
<html lang=\"zh-CN\">
<head>
  <meta charset=\"UTF-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>{seo['title']}</title>
  <meta name=\"description\" content=\"{seo['description']}\" />
  <meta name=\"keywords\" content=\"{page.keyword},简历模板,求职简历,个人简历\" />
  <link rel=\"canonical\" href=\"{canonical}\" />
</head>
<body>
  <main>
    <h1>{page.keyword}</h1>
    <p>{seo['intro']}</p>
    <h2>模板亮点</h2>
    <ul>
      {seo['bullets']}
    </ul>
    <h2>使用建议</h2>
    <p>建议根据目标岗位JD替换关键技能词，并用量化数据描述成果，例如“转化率提升32%”“独立负责3个项目上线”。</p>
    <p><a href=\"./index.html\">返回模板目录</a></p>
  </main>
</body>
</html>
"""


def write_sitemap(pages: list[PageData], output_dir: Path, base_url: str) -> None:
    urlset = Element("urlset", xmlns="http://www.sitemaps.org/schemas/sitemap/0.9")
    today = date.today().isoformat()

    for page in pages:
        url = SubElement(urlset, "url")
        SubElement(url, "loc").text = f"{base_url.rstrip('/')}/{page.slug}.html"
        SubElement(url, "lastmod").text = today
        SubElement(url, "changefreq").text = "weekly"
        SubElement(url, "priority").text = "0.8"

    root = SubElement(urlset, "url")
    SubElement(root, "loc").text = f"{base_url.rstrip('/')}/index.html"
    SubElement(root, "lastmod").text = today
    SubElement(root, "changefreq").text = "daily"
    SubElement(root, "priority").text = "1.0"

    ElementTree(urlset).write(output_dir / "sitemap.xml", encoding="utf-8", xml_declaration=True)


def write_index(pages: list[PageData], output_dir: Path) -> None:
    items = "\n".join(
        f'<li><a href="./{page.slug}.html">{page.idx:03d}. {page.keyword}</a></li>' for page in pages
    )
    html = f"""<!doctype html>
<html lang=\"zh-CN\">
<head>
  <meta charset=\"UTF-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>200个简历模板SEO页面目录</title>
  <meta name=\"description\" content=\"批量生成的200个简历模板SEO页面目录，可直接用于静态站点部署。\" />
</head>
<body>
  <main>
    <h1>200个简历模板SEO页面目录</h1>
    <ol>{items}</ol>
  </main>
</body>
</html>
"""
    (output_dir / "index.html").write_text(html, encoding="utf-8")


def write_keywords_csv(pages: list[PageData], output_dir: Path) -> None:
    with (output_dir / "keywords.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["id", "keyword", "slug"])
        for page in pages:
            writer.writerow([page.idx, page.keyword, page.slug])


def generate(output_dir: Path, base_url: str, total: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    keywords = build_keywords(total=total)
    pages: list[PageData] = []

    for i, keyword in enumerate(keywords, start=1):
        slug = slugify(f"{i}-{keyword}")
        page = PageData(idx=i, keyword=keyword, slug=slug)
        pages.append(page)
        (output_dir / f"{slug}.html").write_text(render_html(page, base_url), encoding="utf-8")

    write_index(pages, output_dir)
    write_keywords_csv(pages, output_dir)
    write_sitemap(pages, output_dir, base_url)


def main() -> None:
    parser = argparse.ArgumentParser(description="批量生成简历模板SEO HTML页面和sitemap")
    parser.add_argument("--output", default="dist", help="输出目录，默认 dist")
    parser.add_argument("--base-url", default="https://example.com", help="站点基础URL")
    parser.add_argument("--total", type=int, default=200, help="生成页面数量，默认200")
    args = parser.parse_args()
    generate(Path(args.output), args.base_url, args.total)


if __name__ == "__main__":
    main()
