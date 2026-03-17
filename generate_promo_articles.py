#!/usr/bin/env python3
"""
批量生成“职有简历 App”推广文章脚本。

升级点：
- 默认输出“可直接复制到平台”的排版。
- 按渠道自动微调结构（小红书/公众号/知乎/B站）。
- 自动混合写作框架（痛点、方法、案例、清单、行动引导）。
- 每篇文章包含自然软引导下载语句，避免硬广口吻。
"""

from __future__ import annotations

import argparse
import random
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

CHANNEL_TAGS = {
    "小红书": ["#求职", "#简历", "#职有简历APP", "#找工作"],
    "公众号": ["#求职方法", "#简历优化", "#职有简历APP"],
    "知乎": ["#求职", "#简历怎么写", "#职有简历APP"],
    "B站": ["#求职技巧", "#简历制作", "#职有简历APP"],
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


def _build_sections(spec: ArticleSpec, checklist_size: int) -> dict[str, str | List[str]]:
    return {
        "title": f"{spec.audience}如何系统提升{spec.keyword}效率（实操版）",
        "opening": random.choice(OPENING_TEMPLATES).format(keyword=spec.keyword, audience=spec.audience),
        "scene": random.choice(SCENE_TEMPLATES),
        "body": random.choice(BODY_TEMPLATES),
        "method": random.choice(METHOD_TEMPLATES),
        "tip": random.choice(TIP_TEMPLATES),
        "case": random.choice(CASE_TEMPLATES),
        "cta": random.choice(SOFT_CTA_TEMPLATES),
        "ending": random.choice(ENDING_TEMPLATES),
        "checklist": _pick_checklist(checklist_size),
        "tags": CHANNEL_TAGS.get(spec.channel, ["#求职", "#简历"]),
    }


def _render_markdown(spec: ArticleSpec, sections: dict[str, str | List[str]]) -> str:
    checklist_lines = "\n".join(f"- {item}" for item in sections["checklist"])
    tags_line = " ".join(sections["tags"])
    return (
        f"# {sections['title']}\n\n"
        f"{sections['opening']}\n\n{sections['scene']}\n\n"
        f"## 为什么很多人努力了却没有结果\n"
        f"{sections['body']}\n\n"
        "不少人把简历当“经历档案”，而不是“价值说明书”。一份真正有竞争力的简历，"
        "核心不是写满，而是写准：让对方迅速理解你“适配这个岗位”的理由。\n\n"
        f"## 可以直接套用的方法\n{sections['method']}\n\n"
        f"实操建议：{sections['tip']}\n\n"
        "30 分钟优化动作：\n"
        "1. 第一层放岗位最关心的能力与成果；\n"
        "2. 第二层放项目经历与角色贡献；\n"
        "3. 第三层补充基础信息与辅助经历。\n\n"
        f"## 案例拆解\n{sections['case']}\n\n"
        "很多时候，简历改完不只是“好看”，而是招聘方终于能在短时间内识别你的价值点。\n\n"
        "## 自查清单\n"
        f"{checklist_lines}\n\n"
        f"## 软引导\n{sections['cta']}\n\n"
        f"如果你正在准备{spec.keyword}，建议先完成一版可投递稿，再按岗位做微调。\n\n"
        f"{sections['ending']}\n\n"
        f"{tags_line}\n"
    )


def _render_copy_ready(spec: ArticleSpec, sections: dict[str, str | List[str]]) -> str:
    checklist_lines = "\n".join(f"✅ {item}" for item in sections["checklist"])
    tags_line = " ".join(sections["tags"])

    if spec.channel == "小红书":
        return (
            f"【{sections['title']}】\n\n"
            f"先说结论：{sections['body']}\n\n"
            f"{sections['opening']}\n{sections['scene']}\n\n"
            "📌 三步就能开始优化：\n"
            f"1）{sections['method']}\n"
            f"2）{sections['tip']}\n"
            "3）按岗位关键词微调后再投递\n\n"
            f"📌 一个真实改写思路：{sections['case']}\n\n"
            "📌 投递前自查：\n"
            f"{checklist_lines}\n\n"
            f"{sections['cta']}\n\n"
            f"{sections['ending']}\n\n"
            f"{tags_line}"
        )

    if spec.channel == "公众号":
        return (
            f"标题：{sections['title']}\n\n"
            "导语\n"
            f"{sections['opening']}\n\n"
            "一、问题为何反复出现\n"
            f"{sections['scene']}\n{sections['body']}\n\n"
            "二、可落地的方法\n"
            f"{sections['method']}\n"
            f"{sections['tip']}\n\n"
            "三、案例参考\n"
            f"{sections['case']}\n\n"
            "四、自查清单\n"
            f"{checklist_lines}\n\n"
            "五、工具建议\n"
            f"{sections['cta']}\n\n"
            f"结语：{sections['ending']}\n\n"
            f"话题：{tags_line}"
        )

    if spec.channel == "知乎":
        return (
            f"问题：{spec.audience}如何提升{spec.keyword}效率？\n\n"
            f"我的结论是：{sections['body']}\n\n"
            "下面按“问题—方法—案例—落地”展开：\n\n"
            f"1）问题本质\n{sections['opening']}\n{sections['scene']}\n\n"
            f"2）方法框架\n{sections['method']}\n{sections['tip']}\n\n"
            f"3）案例说明\n{sections['case']}\n\n"
            f"4）自查清单\n{checklist_lines}\n\n"
            f"最后补一句：{sections['cta']}\n\n"
            f"{sections['ending']}\n\n"
            f"相关话题：{tags_line}"
        )

    return _render_markdown(spec, sections)


def generate_article(spec: ArticleSpec, checklist_size: int, copy_ready: bool) -> str:
    sections = _build_sections(spec, checklist_size)
    if copy_ready:
        return _render_copy_ready(spec, sections).strip() + "\n"
    return _render_markdown(spec, sections).strip() + "\n"


def save_articles(output_dir: Path, articles: List[str]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for i, article in enumerate(articles, start=1):
        file_path = output_dir / f"promo_article_{i:03d}.txt"
        file_path.write_text(article, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="批量生成职有简历 App 推广文章（平台可直接复制版）")
    parser.add_argument("--count", type=int, default=10, help="生成文章数量（默认 10）")
    parser.add_argument("--output-dir", default="generated_articles", help="输出目录（默认 generated_articles）")
    parser.add_argument("--checklist-size", type=int, default=4, help="每篇文章自查清单条目数（默认 4，最大 5）")
    parser.add_argument("--copy-ready", dest="copy_ready", action="store_true", help="输出平台可直接复制排版")
    parser.add_argument("--no-copy-ready", dest="copy_ready", action="store_false", help="关闭可复制排版，改为 Markdown 长文")
    parser.set_defaults(copy_ready=True)
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
    parser.add_argument("--seed", type=int, default=42, help="随机种子（默认 42）")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count <= 0:
        raise ValueError("--count 必须大于 0")
    if args.checklist_size <= 0 or args.checklist_size > len(CHECKLIST_ITEMS):
        raise ValueError(f"--checklist-size 必须在 1 到 {len(CHECKLIST_ITEMS)} 之间")

    random.seed(args.seed)
    specs = normalize_specs(args.audiences, args.channels, args.keywords, args.tones, args.count)
    articles = [generate_article(spec, args.checklist_size, args.copy_ready) for spec in specs]
    save_articles(Path(args.output_dir), articles)

    print(f"已生成 {len(articles)} 篇可复制发布文章，输出目录：{args.output_dir}")


if __name__ == "__main__":
    main()
