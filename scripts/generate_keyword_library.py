#!/usr/bin/env python3
"""Generate large keyword/page libraries for SEO landing pages.

Output JSON keeps the same structure as content/pages.json:
{
  "site": {...},
  "pages": [...]
}
"""

from __future__ import annotations

import argparse
import json
from itertools import product
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate 50k-100k SEO page entries")
    parser.add_argument("--input", required=True, help="Seed pages JSON path")
    parser.add_argument("--output", required=True, help="Output JSON path")
    parser.add_argument(
        "--target-count",
        type=int,
        default=50000,
        help="Total pages to generate. Recommended: 50000-100000",
    )
    parser.add_argument(
        "--keep-seed-pages",
        action="store_true",
        help="Keep original pages from input at the beginning",
    )
    return parser.parse_args()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def slugify(*tokens: str) -> str:
    return "-".join(t.strip().lower().replace(" ", "-") for t in tokens if t.strip())


def build_entry(
    role_zh: str,
    role_en: str,
    level_zh: str,
    level_en: str,
    style_zh: str,
    style_en: str,
    scenario_zh: str,
    scenario_en: str,
    city_zh: str,
    city_en: str,
    base_url: str,
) -> dict:
    keyword = f"{city_zh}{level_zh}{role_zh}{style_zh}"
    slug = slugify(city_en, level_en, role_en, style_en, scenario_en, "resume-template")

    return {
        "slug": slug,
        "title": f"{keyword}简历模板下载 - {scenario_zh}可用",
        "description": (
            f"精选{keyword}简历模板，覆盖{scenario_zh}场景，支持一键生成与导出，"
            f"适配校招/社招，提升投递效率。"
        ),
        "keywords": [
            f"{keyword}简历模板",
            f"{role_zh}简历模板",
            f"{scenario_zh}简历",
            f"{city_zh}{role_zh}求职",
        ],
        "h1": f"{keyword}简历模板",
        "intro": f"聚焦{scenario_zh}需求，突出项目成果与能力亮点，快速完成高质量简历。",
        "download_url": f"{base_url.rstrip('/')}/download?kw={slug}",
    }


def generate_pages(seed_payload: dict, target_count: int, keep_seed_pages: bool) -> list[dict]:
    if target_count <= 0:
        raise ValueError("--target-count must be > 0")

    site = seed_payload["site"]
    base_url = site["base_url"]
    seed_pages = seed_payload.get("pages", [])
    pages: list[dict] = list(seed_pages) if keep_seed_pages else []

    roles = [
        ("产品经理", "product-manager"),
        ("运营", "operations"),
        ("前端开发", "frontend-developer"),
        ("后端开发", "backend-developer"),
        ("测试工程师", "qa-engineer"),
        ("数据分析师", "data-analyst"),
        ("算法工程师", "algorithm-engineer"),
        ("UI设计师", "ui-designer"),
        ("平面设计师", "graphic-designer"),
        ("市场营销", "marketing"),
        ("销售", "sales"),
        ("人力资源", "hr"),
        ("财务", "finance"),
        ("行政", "administration"),
        ("新媒体运营", "social-media-operations"),
        ("跨境电商运营", "cross-border-ecommerce-operations"),
        ("项目经理", "project-manager"),
        ("Java开发", "java-developer"),
        ("Python开发", "python-developer"),
        ("全栈工程师", "fullstack-engineer"),
    ]
    levels = [
        ("应届生", "entry-level"),
        ("实习生", "intern"),
        ("初级", "junior"),
        ("中级", "mid"),
        ("高级", "senior"),
        ("资深", "staff"),
    ]
    styles = [
        ("通用", "general"),
        ("极简", "minimal"),
        ("专业", "professional"),
        ("创意", "creative"),
        ("ATS友好", "ats-friendly"),
    ]
    scenarios = [
        ("校招", "campus"),
        ("社招", "social"),
        ("跳槽", "job-change"),
        ("转行", "career-switch"),
        ("海外求职", "overseas"),
    ]
    cities = [
        ("北京", "beijing"),
        ("上海", "shanghai"),
        ("广州", "guangzhou"),
        ("深圳", "shenzhen"),
        ("杭州", "hangzhou"),
        ("成都", "chengdu"),
        ("武汉", "wuhan"),
        ("南京", "nanjing"),
        ("西安", "xian"),
        ("苏州", "suzhou"),
        ("重庆", "chongqing"),
        ("天津", "tianjin"),
        ("长沙", "changsha"),
        ("郑州", "zhengzhou"),
        ("青岛", "qingdao"),
        ("宁波", "ningbo"),
        ("无锡", "wuxi"),
        ("厦门", "xiamen"),
    ]

    existing_slugs = {p.get("slug", "") for p in pages}

    for (role_zh, role_en), (level_zh, level_en), (style_zh, style_en), (scenario_zh, scenario_en), (
        city_zh,
        city_en,
    ) in product(roles, levels, styles, scenarios, cities):
        if len(pages) >= target_count:
            break

        entry = build_entry(
            role_zh,
            role_en,
            level_zh,
            level_en,
            style_zh,
            style_en,
            scenario_zh,
            scenario_en,
            city_zh,
            city_en,
            base_url,
        )
        slug = entry["slug"]
        if slug in existing_slugs:
            continue

        existing_slugs.add(slug)
        pages.append(entry)

    if len(pages) < target_count:
        # Fallback to ensure target count even if combinations are exhausted.
        original = pages[:]
        idx = 1
        for item in original:
            if len(pages) >= target_count:
                break
            clone = dict(item)
            clone["slug"] = f"{item['slug']}-{idx}"
            clone["title"] = f"{item['title']} #{idx}"
            clone["h1"] = f"{item['h1']} #{idx}"
            clone["download_url"] = f"{site['base_url'].rstrip('/')}/download?kw={clone['slug']}"
            if clone["slug"] not in existing_slugs:
                existing_slugs.add(clone["slug"])
                pages.append(clone)
            idx += 1

    return pages[:target_count]


def main() -> None:
    args = parse_args()
    if args.target_count < 50000 or args.target_count > 100000:
        print("Warning: target-count is typically recommended between 50000 and 100000")

    payload = read_json(Path(args.input))
    pages = generate_pages(payload, args.target_count, args.keep_seed_pages)
    output_payload = {"site": payload["site"], "pages": pages}

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(output_payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"Generated {len(pages)} pages => {output_path}")


if __name__ == "__main__":
    main()
