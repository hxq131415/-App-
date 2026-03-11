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
REVIEW_ITEMS = [
    "★★★★★ 模板设计很专业。<br><strong>王志强 · Java工程师 · 北京</strong>",
    "★★★★★ 应届生非常适合。<br><strong>刘思雨 · 应届毕业生 · 上海</strong>",
    "★★★★★ 简历通过率明显提高。<br><strong>陈凯 · 产品经理 · 深圳</strong>",
    "★★★★★ 模板很多很好用。<br><strong>赵磊 · 销售经理 · 广州</strong>",
]
FAQ_ITEMS = [
    ("简历模板怎么下载？", "扫码下载APP即可获取全部模板。"),
    ("模板可以免费使用吗？", "APP提供免费模板。"),
    ("支持哪些格式？", "支持 Word 和 PDF。"),
    ("适合应届生吗？", "提供应届生专用模板。"),
    ("模板可以编辑吗？", "所有模板均支持编辑。"),
    ("可以打印吗？", "支持导出PDF打印。"),
    ("适合哪些行业？", "覆盖互联网、销售、金融、教育等行业。"),
    ("多久更新模板？", "每月新增模板。"),
    ("手机可以编辑吗？", "APP支持手机编辑。"),
    ("支持招聘网站投递吗？", "支持各大招聘平台。"),
]


@dataclass
class PageData:
    idx: int
    keyword: str
    slug: str


def slugify(text: str) -> str:
    cleaned = text.replace(" ", "-").replace("/", "-")
    safe_chars: list[str] = []
    for ch in cleaned:
        if ch.isalnum() or ch in "-_":
            safe_chars.append(ch.lower())
        else:
            safe_chars.append(f"u{ord(ch):x}")
    return "resume-" + "".join(safe_chars)


def build_keywords(total: int = 200) -> list[str]:
    keywords: list[str] = []
    for base in BASE_KEYWORDS:
        for industry in INDUSTRIES:
            for style in STYLE_TAGS:
                keywords.append(f"{industry}{base}{style}")
                if len(keywords) >= total:
                    return keywords
    return keywords[:total]


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
    title = f"{page.keyword}免费下载 - 应届生简历模板APP"
    description = (
        f"{page.keyword}精选下载，包含应届生、程序员、产品经理等热门岗位模板，"
        "支持Word编辑与PDF导出，一键生成专业简历。"
    )
    canonical = f"{base_url.rstrip('/')}/{page.slug}.html"
    keywords_meta = f"{page.keyword},简历模板,简历模板下载,Word简历模板,免费简历模板"

    reviews = "\n".join([f'<div class="review-card">{item}</div>' for item in (REVIEW_ITEMS + REVIEW_ITEMS)])
    faqs = "\n".join(
        [f'<div class="faq-item"><h3>{escape(q)}</h3><p>{escape(a)}</p></div>' for q, a in FAQ_ITEMS]
    )
    related = render_related_cards(pages, page.idx - 1)

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
.review-track{{display:flex;gap:20px;width:max-content;animation:scrollReviews 40s linear infinite;}}
.review-card{{min-width:280px;background:#fff;padding:20px;border-radius:12px;box-shadow:0 10px 25px rgba(0,0,0,.08);line-height:1.6;}}
@keyframes scrollReviews{{0%{{transform:translateX(0);}}100%{{transform:translateX(-50%);}}}}
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
<section class="hero"><div class="container hero-inner"><div><h1>{escape(page.keyword)}</h1><p>1000+模板覆盖应届生 / 程序员 / 产品经理 / 护士等岗位，支持 Word 编辑与 PDF 导出，一键生成专业简历。</p><div class="download"><div class="qrcode"><img src="images/qrcode.png" alt="简历模板APP下载二维码"></div><div><p>扫码下载APP</p><p>免费获取全部模板</p></div></div></div><img src="images/preview.png" width="420" alt="简历模板APP界面预览"></div></section>
<section class="section"><div class="container"><h2 class="section-title">热门简历模板</h2><div class="templates">{related}</div></div></section>
<section class="section"><div class="container"><h2 class="section-title">用户真实评价</h2><div class="review-scroll"><div class="review-track">{reviews}</div></div></div></section>
<section class="section"><div class="container"><h2 class="section-title">常见问题</h2><div class="faq">{faqs}</div></div></section>
<section class="cta"><div class="container"><h2>立即下载简历模板APP</h2><p>1000+专业简历模板免费使用</p><img src="images/qrcode.png" alt="APP下载二维码"></div></section>
<section class="section"><div class="container"><h2 class="section-title">热门简历模板下载</h2><p style="max-width:900px;margin:auto;line-height:1.9;text-align:center;color:#555">本站提供超过1000套专业简历模板免费下载，包括应届生简历模板、程序员简历模板、产品经理简历模板、销售简历模板、教师简历模板、护士简历模板、设计师简历模板等热门岗位模板。所有简历模板均支持Word编辑与PDF导出，适用于校园招聘、社会招聘、互联网求职、金融行业求职等多种场景。你当前浏览的是“{escape(page.keyword)}”专题页，可直接下载或继续浏览相关推荐模板。</p></div></section>
<footer class="footer"><div class="container"><p>© 2026 简历模板库 Resume Template Hub 提供应届生简历模板、程序员简历模板、产品经理简历模板、销售简历模板、Word简历模板等免费下载资源。</p></div></footer>
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
        writer.writerow(["id", "keyword", "slug"])
        for p in pages:
            writer.writerow([p.idx, p.keyword, p.slug])


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


def generate(output_dir: Path, base_url: str, total: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for pattern in ("*.html", "keywords.csv", "sitemap.xml"):
        for old_file in output_dir.glob(pattern):
            old_file.unlink()

    pages: list[PageData] = []
    for idx, keyword in enumerate(build_keywords(total), start=1):
        pages.append(PageData(idx=idx, keyword=keyword, slug=slugify(f"{idx}-{keyword}")))

    for page in pages:
        html = render_page(page, pages, base_url)
        (output_dir / f"{page.slug}.html").write_text(html, encoding="utf-8")

    write_index(pages, output_dir, base_url)
    write_keywords_csv(pages, output_dir)
    write_sitemap(pages, output_dir, base_url)


def main() -> None:
    parser = argparse.ArgumentParser(description="批量生成简历模板 SEO 页面")
    parser.add_argument("--output", default="dist", help="输出目录，默认 dist")
    parser.add_argument("--base-url", default="https://example.com", help="站点基础 URL")
    parser.add_argument("--total", type=int, default=200, help="生成页面数量，默认 200")
    args = parser.parse_args()

    generate(Path(args.output), args.base_url, args.total)


if __name__ == "__main__":
    main()
