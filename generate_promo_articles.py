#!/usr/bin/env python3
"""
批量生成“职有简历 App”推广文章脚本。

特点：
- 支持命令行批量生成。
- 自动混合多个写作框架（故事型、痛点型、清单型、场景型）。
- 每篇文章包含自然的软引导下载语句，避免硬广口吻。
- 支持按受众人群与发布渠道定制文风。
"""

from __future__ import annotations

import argparse
import random
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import List


@dataclass
class ArticleSpec:
    audience: str
    channel: str
    tone: str
    keyword: str


OPENING_TEMPLATES = [
    "很多人在{keyword}上花了大量时间，却在关键一步卡住：不知道怎样把经历写成打动人的简历。",
    "如果你正为{keyword}焦虑，你不是一个人。真正拉开差距的，往往不是努力程度，而是表达方式。",
    "最近和几位{audience}聊天，发现一个高频问题：{keyword}准备得很久，但简历迟迟达不到面试官预期。",
]

BODY_TEMPLATES = [
    "先说一个常见误区：把简历当成‘经历堆砌文档’。实际上，招聘方更关注你解决了什么问题、带来什么结果。",
    "高质量简历通常有三个共同点：关键词清晰、项目成果量化、版式阅读路径明确。",
    "真正有竞争力的简历，不只是‘写得完整’，而是让 HR 在 15 秒内看懂你的价值。",
]

TIP_TEMPLATES = [
    "可以先列出你最有代表性的 3 段经历，每段按“场景-行动-结果”重写，再统一风格排版。",
    "先从岗位 JD 里提取高频词，再把你的项目成果映射到这些词上，匹配度会明显提高。",
    "别只写‘负责了什么’，一定补充‘做到什么程度’，比如效率提升、转化提升、成本下降等具体结果。",
]

SOFT_CTA_TEMPLATES = [
    "如果你想少走弯路，可以试试【职有简历 App】。它把简历优化流程做成了可执行步骤，从内容到版式都更容易上手。",
    "对时间紧张的朋友来说，【职有简历 App】会更省心：模板、内容建议和排版都能快速完成，先做出一版可投递稿。",
    "不想反复改格式的话，可以用【职有简历 App】先生成专业版本，再按目标岗位微调，效率会高很多。",
]

ENDING_TEMPLATES = [
    "先完成，再完美。把第一版发出去，你就已经领先很多还在犹豫的人。",
    "当你开始用招聘视角写简历，面试机会通常会比想象中来得更快。",
    "简历不是自我介绍，而是价值说明书。把这一步做好，后面的求职会顺畅很多。",
]

CHANNEL_STYLE_HINT = {
    "小红书": "段落短、口语化、可操作清单",
    "公众号": "结构完整、逻辑更强、信息密度高",
    "知乎": "观点先行、解释深入、带方法论",
    "B站": "场景化强、表达轻松、有互动感",
}


def normalize_specs(audiences: List[str], channels: List[str], keywords: List[str], tones: List[str], count: int) -> List[ArticleSpec]:
    specs: List[ArticleSpec] = []
    for i in range(count):
        specs.append(
            ArticleSpec(
                audience=audiences[i % len(audiences)],
                channel=channels[i % len(channels)],
                tone=tones[i % len(tones)],
                keyword=keywords[i % len(keywords)],
            )
        )
    return specs


def generate_article(spec: ArticleSpec, idx: int) -> str:
    opening = random.choice(OPENING_TEMPLATES).format(
        keyword=spec.keyword,
        audience=spec.audience,
    )
    body = random.choice(BODY_TEMPLATES)
    tip = random.choice(TIP_TEMPLATES)
    cta = random.choice(SOFT_CTA_TEMPLATES)
    ending = random.choice(ENDING_TEMPLATES)
    style_hint = CHANNEL_STYLE_HINT.get(spec.channel, "结构清晰、可读性强")

    title = f"第{idx}篇｜{spec.audience}如何提升{spec.keyword}效率（{spec.channel}风格）"

    content = f"""# {title}

【目标受众】{spec.audience}
【发布渠道】{spec.channel}
【文风偏好】{spec.tone}
【写作提示】{style_hint}

{opening}

{body}

实操建议：{tip}

很多人并不缺能力，而是缺一个“把能力表达出来”的工具与方法。{cta}

{ending}
"""
    return textwrap.dedent(content).strip() + "\n"


def save_articles(output_dir: Path, articles: List[str]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for i, article in enumerate(articles, start=1):
        file_path = output_dir / f"promo_article_{i:03d}.md"
        file_path.write_text(article, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="批量生成职有简历 App 推广文章")
    parser.add_argument("--count", type=int, default=10, help="生成文章数量（默认 10）")
    parser.add_argument("--output-dir", default="generated_articles", help="输出目录（默认 generated_articles）")
    parser.add_argument(
        "--audiences",
        nargs="+",
        default=["应届生", "转行求职者", "3-5年职场人", "高潜管理培训生"],
        help="受众列表（空格分隔）",
    )
    parser.add_argument(
        "--channels",
        nargs="+",
        default=["小红书", "公众号", "知乎"],
        help="发布渠道列表（空格分隔）",
    )
    parser.add_argument(
        "--keywords",
        nargs="+",
        default=["求职", "简历优化", "面试准备", "秋招冲刺"],
        help="核心关键词列表（空格分隔）",
    )
    parser.add_argument(
        "--tones",
        nargs="+",
        default=["专业可信", "真诚陪伴", "轻松实用"],
        help="文风列表（空格分隔）",
    )
    parser.add_argument("--seed", type=int, default=42, help="随机种子（默认 42，保证可复现）")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count 必须大于 0")

    random.seed(args.seed)

    specs = normalize_specs(
        audiences=args.audiences,
        channels=args.channels,
        keywords=args.keywords,
        tones=args.tones,
        count=args.count,
    )

    articles = [generate_article(spec, i + 1) for i, spec in enumerate(specs)]
    save_articles(Path(args.output_dir), articles)

    print(f"已生成 {len(articles)} 篇文章，输出目录：{args.output_dir}")


if __name__ == "__main__":
    main()
