#!/usr/bin/env python3
"""
批量生成“职有简历 App”推广文章脚本。

升级点：
- 支持“更长内容”输出，每篇含多个结构化段落。
- 自动混合写作框架（痛点、方法、案例、清单、行动引导）。
- 每篇文章包含自然软引导下载语句，避免硬广口吻。
- 支持按受众、渠道、关键词、文风做定制。
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

SCENE_TEMPLATES = [
    "一个典型场景是：投了 30 份简历，回复率却不到 10%。问题往往不是能力差，而是简历没有把“能创造的价值”说清楚。",
    "很多人明明做过不错的项目，但写进简历后只剩‘负责 XX 模块’，结果面试官看不到亮点。",
    "在招聘节奏很快的时候，HR 通常只会先扫一眼关键词与成果句，抓不到重点就很难进入下一轮。",
]

BODY_TEMPLATES = [
    "先说一个常见误区：把简历当成‘经历堆砌文档’。实际上，招聘方更关注你解决了什么问题、带来什么结果。",
    "高质量简历通常有三个共同点：关键词清晰、项目成果量化、版式阅读路径明确。",
    "真正有竞争力的简历，不只是‘写得完整’，而是让 HR 在 15 秒内看懂你的价值。",
]

METHOD_TEMPLATES = [
    "你可以用“岗位关键词映射法”：先提炼 JD 高频要求，再把个人经历按‘关键词-行动-结果’重写，让匹配关系一目了然。",
    "建议使用“STAR+数据”结构：背景（S）+任务（T）+行动（A）+结果（R），并补上可验证数字，可信度会明显提升。",
    "推荐先做“主简历”，再做“岗位微调版本”：主简历保证完整表达，微调版本保证投递匹配率。",
]

TIP_TEMPLATES = [
    "可以先列出你最有代表性的 3 段经历，每段按“场景-行动-结果”重写，再统一风格排版。",
    "先从岗位 JD 里提取高频词，再把你的项目成果映射到这些词上，匹配度会明显提高。",
    "别只写‘负责了什么’，一定补充‘做到什么程度’，比如效率提升、转化提升、成本下降等具体结果。",
]

CASE_TEMPLATES = [
    "比如一位转行用户，原本写“参与活动运营”，改写后变成“独立策划并落地 3 场活动，累计触达 1.2 万人，线索转化率提升 18%”，面试邀约一周内明显增加。",
    "再看一个应届生案例：把“协助导师完成课题”改为“负责数据清洗与可视化，输出 2 份分析报告，支持课题结题答辩”，表达完整度和专业度都会提高。",
    "很多同学改完简历后会反馈：不是经历变多了，而是表达方式变得更“像招聘语言”，因此回复率更高。",
]

PUBLISH_HINT_TEMPLATES = [
    "如果发在{channel}，建议把核心观点拆成 3-5 个小标题，读者更容易快速抓住重点并收藏。",
    "针对{channel}读者，建议在文末放一个“可复制模板”或“自查清单”，互动率通常更好。",
    "在{channel}发布时，可以先抛结论再讲过程，这样完读率和转化点击都会更稳定。",
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

CHECKLIST_ITEMS = [
    "标题是否明确岗位方向",
    "前 1/3 是否出现核心关键词",
    "每段经历是否有可量化结果",
    "是否删除了与岗位无关的冗余描述",
    "版式是否保证 15 秒内可快速扫读",
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


def _pick_checklist(n: int) -> List[str]:
    items = CHECKLIST_ITEMS[:]
    random.shuffle(items)
    return items[:n]


def generate_article(spec: ArticleSpec, idx: int, checklist_size: int) -> str:
    opening = random.choice(OPENING_TEMPLATES).format(keyword=spec.keyword, audience=spec.audience)
    scene = random.choice(SCENE_TEMPLATES)
    body = random.choice(BODY_TEMPLATES)
    method = random.choice(METHOD_TEMPLATES)
    tip = random.choice(TIP_TEMPLATES)
    case = random.choice(CASE_TEMPLATES)
    publish_hint = random.choice(PUBLISH_HINT_TEMPLATES).format(channel=spec.channel)
    cta = random.choice(SOFT_CTA_TEMPLATES)
    ending = random.choice(ENDING_TEMPLATES)
    style_hint = CHANNEL_STYLE_HINT.get(spec.channel, "结构清晰、可读性强")
    checklist = "\n".join(f"- {item}" for item in _pick_checklist(checklist_size))

    title = f"第{idx}篇｜{spec.audience}如何系统提升{spec.keyword}效率（{spec.channel}长文版）"

    content = f"""# {title}

【目标受众】{spec.audience}
【发布渠道】{spec.channel}
【文风偏好】{spec.tone}
【写作提示】{style_hint}

## 01｜你可能正在经历的真实问题
{opening}

{scene}

## 02｜为什么很多人努力了却没有结果
{body}

不少人把简历当“经历档案”，而不是“价值说明书”。一份真正有竞争力的简历，核心不是写满，而是写准：让对方迅速理解你“适配这个岗位”的理由。

## 03｜可直接套用的方法框架
{method}

实操建议：{tip}

你可以先用 30 分钟把现有简历做一次“信息分层”：
1. 第一层放岗位最关心的能力与成果；
2. 第二层放项目经历与角色贡献；
3. 第三层再补充基础信息与辅助经历。

## 04｜案例拆解（更容易理解）
{case}

很多时候，简历改完不只是“好看”，而是招聘方终于能在短时间内识别你的价值点，这才是拿到更多面试机会的关键。

## 05｜发布与转化建议（适配渠道）
{publish_hint}

文末可放一个“求职简历自查清单”，帮助读者立刻行动：
{checklist}

## 06｜软引导：如何更快做出可投递版本
很多人并不缺能力，而是缺一个“把能力表达出来”的工具与方法。{cta}

如果你正在准备{spec.keyword}，可以先用工具完成第一版，再结合目标岗位进行微调，这样既不拖延，也更容易持续优化。

## 07｜结尾
{ending}
"""
    return textwrap.dedent(content).strip() + "\n"


def save_articles(output_dir: Path, articles: List[str]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for i, article in enumerate(articles, start=1):
        file_path = output_dir / f"promo_article_{i:03d}.md"
        file_path.write_text(article, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="批量生成职有简历 App 推广文章（长文版）")
    parser.add_argument("--count", type=int, default=10, help="生成文章数量（默认 10）")
    parser.add_argument("--output-dir", default="generated_articles", help="输出目录（默认 generated_articles）")
    parser.add_argument(
        "--checklist-size",
        type=int,
        default=4,
        help="每篇文章自查清单条目数（默认 4，最大 5）",
    )
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
    if args.checklist_size <= 0 or args.checklist_size > len(CHECKLIST_ITEMS):
        raise ValueError(f"--checklist-size 必须在 1 到 {len(CHECKLIST_ITEMS)} 之间")

    random.seed(args.seed)

    specs = normalize_specs(
        audiences=args.audiences,
        channels=args.channels,
        keywords=args.keywords,
        tones=args.tones,
        count=args.count,
    )

    articles = [generate_article(spec, i + 1, args.checklist_size) for i, spec in enumerate(specs)]
    save_articles(Path(args.output_dir), articles)

    print(f"已生成 {len(articles)} 篇长文推广文章，输出目录：{args.output_dir}")


if __name__ == "__main__":
    main()
