#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from datetime import date
from html import escape
from pathlib import Path
from xml.etree.ElementTree import Element, ElementTree, SubElement

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
CITIES = ["北京", "上海", "深圳", "广州", "杭州", "成都", "南京", "武汉"]
NAMES = ["王志强", "刘思雨", "陈凯", "赵磊", "周雨晨", "林嘉宁", "孙博文", "何雅婷"]


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


def build_keywords(total: int = 200) -> list[tuple[str, str, str]]:
    combos: list[tuple[str, str, str]] = []
    for base in BASE_KEYWORDS:
        for industry in INDUSTRIES:
            for style in STYLE_TAGS:
                combos.append((industry, base, style))
                if len(combos) >= total:
                    return combos
    return combos[:total]


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
    related: list[PageData] = []
    for offset in range(1, len(pages)):
        if len(related) >= count:
            break
        related.append(pages[(current_index + offset) % len(pages)])
    return "\n".join(
        f'<a class="card" href="./{p.slug}.html"><img src="images/template{(i % 8) + 1}.png" alt="{escape(p.keyword)}"><div class="card-title">{escape(p.keyword)}</div></a>'
        for i, p in enumerate(related)
    )


def render_page(page: PageData, pages: list[PageData], base_url: str) -> str:
    title = f"{page.keyword}免费下载 - {page.industry}高通过率简历模板"
    description = (
        f"{page.keyword}精选下载，面向{page.industry}岗位，提供{page.style}模板与可复用项目描述，"
        "支持Word编辑与PDF导出，快速生成专业简历。"
    )
    canonical = f"{base_url.rstrip('/')}/{page.slug}.html"
    keywords_meta = f"{page.keyword},{page.industry}简历模板,{page.style},简历模板下载,Word简历模板,免费简历模板"

    faq_html = "\n".join(
        f'<div class="faq-item"><h3>{escape(q)}</h3><p>{escape(a)}</p></div>' for q, a in build_faq(page)
    )
    reviews_html = "\n".join(f'<div class="review-card">{r}</div>' for r in build_reviews(page))
    related_html = render_related_cards(pages, page.idx - 1)
    seo_p1, seo_p2 = seo_paragraphs(page)

    return f"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<title>{escape(title)}</title>
<meta name="description" content="{escape(description)}">
<meta name="keywords" content="{escape(keywords_meta)}">
<meta name="robots" content="index,follow">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="canonical" href="{escape(canonical)}">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
<style>
*{{margin:0;padding:0;box-sizing:border-box;}}
body{{font-family:Inter,Arial;background:#f7f9fc;color:#333;}}
.container{{width:min(1200px,92%);margin:auto;}}
.header{{background:#fff;border-bottom:1px solid #eee;}}
.header-inner{{display:flex;align-items:center;justify-content:space-between;padding:20px 0;gap:16px;}}
.logo{{font-size:22px;font-weight:700;color:#2563eb;}}
.search{{width:min(420px,100%);padding:12px 16px;border-radius:30px;border:1px solid #ddd;background:#fafafa;}}
.hero{{padding:80px 0;background:linear-gradient(135deg,#2563eb,#4f46e5);color:#fff;}}
.hero-inner{{display:flex;align-items:center;justify-content:space-between;gap:28px;}}
.hero h1{{font-size:44px;margin-bottom:20px;line-height:1.25;}}
.hero p{{font-size:18px;opacity:0.95;margin-bottom:30px;line-height:1.7;}}
.download{{display:flex;align-items:center;gap:20px;}}
.qrcode{{background:#fff;padding:15px;border-radius:12px;}}
.qrcode img{{width:140px;}}
.section{{padding:70px 0;}}
.section-title{{font-size:32px;margin-bottom:40px;text-align:center;}}
.templates{{display:grid;grid-template-columns:repeat(4,1fr);gap:30px;}}
.card{{background:#fff;border-radius:14px;overflow:hidden;box-shadow:0 10px 30px rgba(0,0,0,.08);transition:all .3s;text-decoration:none;color:#333;display:block;}}
.card:hover{{transform:translateY(-6px);box-shadow:0 20px 40px rgba(0,0,0,.15);}}
.card img{{width:100%;}}
.card-title{{padding:16px;font-weight:600;text-align:center;}}
.review-scroll{{overflow:hidden;width:100%;}}
.review-track{{display:flex;gap:20px;width:max-content;animation:scrollReviews 45s linear infinite;}}
.review-card{{min-width:300px;background:#fff;padding:20px;border-radius:12px;box-shadow:0 10px 25px rgba(0,0,0,.08);line-height:1.6;}}
@keyframes scrollReviews{{0%{{transform:translateX(0);}}100%{{transform:translateX(-45%);}}}}
.faq{{max-width:900px;margin:auto;}}
.faq-item{{background:#fff;padding:20px;border-radius:12px;margin-bottom:15px;box-shadow:0 8px 20px rgba(0,0,0,.05);}}
.cta{{background:linear-gradient(135deg,#4f46e5,#2563eb);color:#fff;padding:80px 0;text-align:center;}}
.cta img{{width:160px;margin-top:20px;}}
.footer{{background:#111827;color:#9ca3af;padding:50px 0;margin-top:60px;}}
.footer p{{max-width:900px;margin:auto;text-align:center;line-height:1.8;}}
@media (max-width: 1024px){{.templates{{grid-template-columns:repeat(2,1fr);}}.hero h1{{font-size:34px;}}}}
@media (max-width: 700px){{.hero-inner{{flex-direction:column;}}.templates{{grid-template-columns:1fr;}}}}
</style>
</head>
<body>
<header class="header"><div class="container header-inner"><div class="logo">简历模板库</div><input class="search" placeholder="搜索简历模板，例如：程序员简历模板"></div></header>
<section class="hero"><div class="container hero-inner"><div><h1>{escape(page.keyword)}</h1><p>针对{escape(page.industry)}岗位优化的{escape(page.style)}专题页面，支持 Word 编辑 / PDF 导出，帮助你更快产出可投递简历。</p><div class="download"><div class="qrcode"><img src="images/qrcode.png" alt="简历模板APP下载二维码"></div><div><p>扫码下载APP</p><p>免费获取全部模板</p></div></div></div><img src="images/preview.png" width="420" alt="简历模板APP界面预览"></div></section>
<section class="section"><div class="container"><h2 class="section-title">热门简历模板</h2><div class="templates">{related_html}</div></div></section>
<section class="section"><div class="container"><h2 class="section-title">用户真实评价</h2><div class="review-scroll"><div class="review-track">{reviews_html}</div></div></div></section>
<section class="section"><div class="container"><h2 class="section-title">常见问题</h2><div class="faq">{faq_html}</div></div></section>
<section class="cta"><div class="container"><h2>立即下载简历模板APP</h2><p>{escape(page.keyword)} 一键套用，快速修改</p><img src="images/qrcode.png" alt="APP下载二维码"></div></section>
<section class="section"><div class="container"><h2 class="section-title">热门简历模板下载</h2><p style="max-width:900px;margin:auto;line-height:1.9;text-align:center;color:#555">{escape(seo_p1)}<br><br>{escape(seo_p2)}</p></div></section>
<footer class="footer"><div class="container"><p>© 2026 简历模板库 Resume Template Hub 提供{escape(page.industry)}岗位与多行业求职模板下载服务。</p></div></footer>
</body>
</html>
"""


def write_index(pages: list[PageData], output_dir: Path, base_url: str) -> None:
    items = "\n".join(
        f'<li><a href="./{p.slug}.html">{p.idx:03d}. {escape(p.keyword)}</a> <small>({base_url.rstrip("/")}/{p.slug}.html)</small></li>'
        for p in pages
    )
    html = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>200个简历模板SEO页面目录</title>
  <meta name="description" content="批量生成的200个简历模板SEO页面目录，可直接用于静态站点部署。" />
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
    with (output_dir / "keywords.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["id", "keyword", "slug", "industry", "base", "style"])
        for p in pages:
            writer.writerow([p.idx, p.keyword, p.slug, p.industry, p.base, p.style])


def write_keyword_library(output_dir: Path) -> None:
    with (output_dir / "keyword_library.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["industry", "base", "style", "keyword"])
        for base in BASE_KEYWORDS:
            for industry in INDUSTRIES:
                for style in STYLE_TAGS:
                    writer.writerow([industry, base, style, f"{industry}{base}{style}"])


def write_sitemap(pages: list[PageData], output_dir: Path, base_url: str) -> None:
    urlset = Element("urlset", xmlns="http://www.sitemaps.org/schemas/sitemap/0.9")
    today = date.today().isoformat()
    for p in pages:
        url = SubElement(urlset, "url")
        SubElement(url, "loc").text = f"{base_url.rstrip('/')}/{p.slug}.html"
        SubElement(url, "lastmod").text = today
        SubElement(url, "changefreq").text = "weekly"
        SubElement(url, "priority").text = "0.8"

    index_url = SubElement(urlset, "url")
    SubElement(index_url, "loc").text = f"{base_url.rstrip('/')}/index.html"
    SubElement(index_url, "lastmod").text = today
    SubElement(index_url, "changefreq").text = "daily"
    SubElement(index_url, "priority").text = "1.0"
    ElementTree(urlset).write(output_dir / "sitemap.xml", encoding="utf-8", xml_declaration=True)


def write_urls_txt(pages: list[PageData], output_dir: Path, base_url: str) -> None:
    lines = [f"{base_url.rstrip('/')}/{p.slug}.html" for p in pages]
    lines.append(f"{base_url.rstrip('/')}/index.html")
    (output_dir / "urls.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate(output_dir: Path, base_url: str, total: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for pattern in ("*.html", "keywords.csv", "keyword_library.csv", "sitemap.xml", "urls.txt"):
        for old_file in output_dir.glob(pattern):
            old_file.unlink()

    pages: list[PageData] = []
    for idx, (industry, base, style) in enumerate(build_keywords(total), start=1):
        keyword = f"{industry}{base}{style}"
        pages.append(PageData(idx, keyword, slugify(f"{idx}-{keyword}"), industry, base, style))

    for page in pages:
        (output_dir / f"{page.slug}.html").write_text(render_page(page, pages, base_url), encoding="utf-8")

    write_index(pages, output_dir, base_url)
    write_keywords_csv(pages, output_dir)
    write_keyword_library(output_dir)
    write_sitemap(pages, output_dir, base_url)
    write_urls_txt(pages, output_dir, base_url)


def main() -> None:
    parser = argparse.ArgumentParser(description="批量生成简历模板 SEO 页面")
    parser.add_argument("--output", default="dist", help="输出目录，默认 dist")
    parser.add_argument("--base-url", default="https://example.com", help="站点基础 URL")
    parser.add_argument("--total", type=int, default=200, help="生成页面数量，默认 200")
    args = parser.parse_args()
    generate(Path(args.output), args.base_url, args.total)


if __name__ == "__main__":
    main()
