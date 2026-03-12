#!/usr/bin/env python3
"""SEO Factory: enterprise-style static SEO site generator."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Sequence, Tuple


@dataclass
class AIConfig:
    provider: str = "openai"
    enabled: bool = False
    api_key: str = ""
    endpoint: str = "https://api.openai.com/v1/chat/completions"
    model: str = "gpt-4o-mini"
    temperature: float = 0.6
    timeout_seconds: int = 30
    max_tokens: int = 700
    sleep_seconds: float = 0.0


@dataclass
class SubmitConfig:
    enabled: bool = False
    submit_google: bool = True
    submit_bing: bool = True
    baidu_enabled: bool = False
    baidu_site: str = ""
    baidu_token: str = ""
    baidu_batch_size: int = 2000
    indexnow_enabled: bool = False
    indexnow_host: str = ""
    indexnow_key: str = ""
    indexnow_key_location: str = ""


@dataclass
class KeywordHarvestConfig:
    enabled: bool = True
    collect_only: bool = False
    output_file: str = "keywords.resume.txt"
    provider_baidu: bool = True
    provider_bing: bool = True
    max_suggestions_per_seed: int = 20
    append_to_keyword_dimensions: bool = True
    verify_ssl: bool = False
    seed_file_optional: bool = True
    seed_keywords: List[str] = field(
        default_factory=lambda: [
            "简历模板",
            "个人简历模板",
            "应届生简历模板",
            "求职简历模板",
            "英文简历模板",
            "word简历模板",
        ]
    )


@dataclass
class SEOFactoryConfig:
    site_name: str = "SEO Factory Demo"
    base_url: str = "https://example.com"
    output_dir: str = "dist"
    language: str = "zh-CN"
    max_pages: int = 1000000
    internal_links_per_page: int = 8
    sitemap_max_urls: int = 50000
    page_template_file: str = "landing_page.template.html"
    keyword_dimensions: List[List[str]] = field(
        default_factory=lambda: [
            ["简历模板", "个人简历", "求职简历"],
            ["应届生", "实习生", "社招"],
            ["word", "pdf", "中英双语"],
        ]
    )
    ai: AIConfig = field(default_factory=AIConfig)
    submit: SubmitConfig = field(default_factory=SubmitConfig)
    keyword_harvest: KeywordHarvestConfig = field(default_factory=KeywordHarvestConfig)


def safe_product(values: Sequence[int]) -> int:
    result = 1
    for value in values:
        result *= value
    return result


class KeywordHarvester:
    def __init__(self, cfg: KeywordHarvestConfig):
        self.cfg = cfg
        self._printed_ssl_notice = False

    def _urlopen(self, url: str, timeout: int = 15):
        if self.cfg.verify_ssl:
            return urllib.request.urlopen(url, timeout=timeout)
        if not self._printed_ssl_notice:
            print("[INFO] 关键词采集已关闭 SSL 证书校验（verify_ssl=false），用于兼容本地证书环境")
            self._printed_ssl_notice = True
        context = ssl._create_unverified_context()
        return urllib.request.urlopen(url, timeout=timeout, context=context)

    def collect(self, extra_seeds: Optional[List[str]] = None) -> List[str]:
        seeds = list(dict.fromkeys([s.strip() for s in (self.cfg.seed_keywords + (extra_seeds or [])) if s.strip()]))
        keywords = set(seeds)

        for seed in seeds:
            if self.cfg.provider_baidu:
                keywords.update(self.fetch_baidu(seed))
            if self.cfg.provider_bing:
                keywords.update(self.fetch_bing(seed))

        ordered = sorted(k for k in keywords if k)
        Path(self.cfg.output_file).write_text("\n".join(ordered) + "\n", encoding="utf-8")
        print(f"[INFO] 关键词采集完成：{len(ordered)} 条 -> {self.cfg.output_file}")
        return ordered

    def fetch_baidu(self, query: str) -> List[str]:
        url = f"https://suggestion.baidu.com/su?wd={urllib.parse.quote(query)}&cb=cb"
        try:
            with self._urlopen(url, timeout=15) as resp:
                raw = resp.read().decode("utf-8", errors="ignore")
            m = re.search(r"\[(.*?)\]", raw)
            if not m:
                return []
            parts = re.findall(r'"(.*?)"', m.group(0))
            return [p.strip() for p in parts[: self.cfg.max_suggestions_per_seed] if p.strip()]
        except Exception as e:
            print(f"[WARN] 百度联想词采集失败 ({query}): {e}")
            return []

    def fetch_bing(self, query: str) -> List[str]:
        url = f"https://api.bing.com/osjson.aspx?query={urllib.parse.quote(query)}"
        try:
            with self._urlopen(url, timeout=15) as resp:
                raw = resp.read().decode("utf-8", errors="ignore")
            data = json.loads(raw)
            if len(data) < 2 or not isinstance(data[1], list):
                return []
            return [str(x).strip() for x in data[1][: self.cfg.max_suggestions_per_seed] if str(x).strip()]
        except Exception as e:
            print(f"[WARN] Bing 联想词采集失败 ({query}): {e}")
            return []


class KeywordSpace:
    def __init__(self, dimensions: Sequence[Sequence[str]]):
        if not dimensions:
            raise ValueError("keyword_dimensions 不能为空")
        normalized = []
        for i, dim in enumerate(dimensions):
            cleaned = [x.strip() for x in dim if x.strip()]
            if not cleaned:
                raise ValueError(f"第 {i + 1} 个关键词维度为空")
            normalized.append(cleaned)
        self.dimensions: List[List[str]] = normalized
        self.sizes = [len(d) for d in self.dimensions]
        self.total = safe_product(self.sizes)

    def combo_by_index(self, idx: int) -> Tuple[str, ...]:
        if idx < 0 or idx >= self.total:
            raise IndexError(idx)
        out = []
        base = self.total
        for size, values in zip(self.sizes, self.dimensions):
            base //= size
            pos = (idx // base) % size
            out.append(values[pos])
        return tuple(out)


class AIWriter:
    def __init__(self, config: AIConfig):
        self.config = config

    def generate(self, combo: Sequence[str], title: str) -> str:
        if not self.config.enabled or not self.config.api_key or self.config.provider != "openai":
            return self._fallback(combo, title)

        payload = {
            "model": self.config.model,
            "temperature": self.config.temperature,
            "max_tokens": self.config.max_tokens,
            "messages": [
                {"role": "system", "content": "你是简历模板站SEO内容写作助手。输出结构化、可读、原创内容。"},
                {
                    "role": "user",
                    "content": (
                        f"请围绕标题《{title}》写中文落地页正文，关键词：{', '.join(combo)}。"
                        "要求：含小标题、要点列表、FAQ（2条），总字数约700-900字。"
                    ),
                },
            ],
        }
        req = urllib.request.Request(
            self.config.endpoint,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {self.config.api_key}"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.config.timeout_seconds) as resp:
                body = json.loads(resp.read().decode("utf-8"))
            return body["choices"][0]["message"]["content"].strip()
        except Exception as e:
            print(f"[WARN] AI 生成失败，使用模板兜底: {e}")
            return self._fallback(combo, title)

    @staticmethod
    def _fallback(combo: Sequence[str], title: str) -> str:
        keywords = "、".join(combo)
        return f"""
<h2>{html.escape(title)}：快速找到合适简历模板</h2>
<p>围绕 {html.escape(keywords)}，我们提供可编辑、可下载、适配招聘场景的模板方案。</p>
<h2>模板使用建议</h2>
<ul>
  <li>按岗位选择：运营、产品、开发、设计等岗位结构不同。</li>
  <li>按经验选择：应届/1-3年/3-5年重点内容不同。</li>
  <li>按投递渠道调整：校招、社招、内推可采用不同版本。</li>
</ul>
""".strip()


class SitemapWriter:
    def __init__(self, out_dir: Path, base_url: str, max_urls: int):
        self.out_dir = out_dir
        self.base_url = base_url.rstrip("/")
        self.max_urls = max_urls
        self.file_idx = 0
        self.url_count = 0
        self.current_file = None
        self.generated: List[str] = []

    def _open_new(self):
        if self.current_file:
            self.current_file.write("</urlset>\n")
            self.current_file.close()
        self.file_idx += 1
        name = f"sitemap-{self.file_idx}.xml"
        self.generated.append(name)
        self.current_file = (self.out_dir / name).open("w", encoding="utf-8")
        self.current_file.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        self.current_file.write('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        self.url_count = 0

    def add(self, path: str):
        if not self.current_file or self.url_count >= self.max_urls:
            self._open_new()
        self.current_file.write(f"  <url><loc>{html.escape(self.base_url + '/' + path.lstrip('/'))}</loc></url>\n")
        self.url_count += 1

    def close(self):
        if self.current_file:
            self.current_file.write("</urlset>\n")
            self.current_file.close()
        idx = self.out_dir / "sitemap.xml"
        with idx.open("w", encoding="utf-8") as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
            f.write('<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
            for name in self.generated:
                f.write(f"  <sitemap><loc>{html.escape(self.base_url + '/' + name)}</loc></sitemap>\n")
            f.write("</sitemapindex>\n")


class SEOFactory:
    def __init__(self, cfg: SEOFactoryConfig):
        self.cfg = cfg
        self.space = KeywordSpace(cfg.keyword_dimensions)
        self.total_pages = min(cfg.max_pages, self.space.total)
        self.ai_writer = AIWriter(cfg.ai)
        self.out_dir = Path(cfg.output_dir)
        self.pages_dir = self.out_dir / "pages"
        self.page_template = self.load_page_template()

    def load_page_template(self) -> str:
        p = Path(self.cfg.page_template_file)
        if p.exists():
            return p.read_text(encoding="utf-8")
        return "<html><body><h1>{{headline}}</h1>{{content_html}}<ul>{{internal_links_html}}</ul></body></html>"

    @staticmethod
    def render_template(template: str, variables: dict) -> str:
        out = template
        for key, value in variables.items():
            out = out.replace("{{" + key + "}}", value)
        return out

    @staticmethod
    def slugify(text: str) -> str:
        s = re.sub(r"\s+", "-", text.lower().strip())
        s = re.sub(r"[^\w\-\u4e00-\u9fff]", "", s)
        return re.sub(r"-+", "-", s).strip("-") or "item"

    def path_for_combo(self, combo: Sequence[str]) -> str:
        joined = "-".join(combo)
        return f"pages/{self.slugify(joined)}-{hashlib.md5(joined.encode('utf-8')).hexdigest()[:8]}.html"

    def render_page(self, idx: int, combo: Sequence[str]) -> str:
        title = " | ".join(combo) + " - 简历模板专题页"
        desc = f"围绕 {'、'.join(combo)} 的简历模板下载、写作技巧与常见问题。"
        content = self.ai_writer.generate(combo, title)
        link_html = []
        for step in range(1, min(self.cfg.internal_links_per_page + 1, self.total_pages)):
            t_combo = self.space.combo_by_index((idx + step) % self.total_pages)
            rel = os.path.relpath(self.out_dir / self.path_for_combo(t_combo), start=self.pages_dir)
            link_html.append(f'<li><a href="{html.escape(rel)}">{html.escape(" / ".join(t_combo))}</a></li>')
        return self.render_template(
            self.page_template,
            {
                "lang": html.escape(self.cfg.language),
                "site_name": html.escape(self.cfg.site_name),
                "title": html.escape(title),
                "headline": html.escape(title),
                "description": html.escape(desc),
                "canonical_url": html.escape(self.cfg.base_url.rstrip("/") + "/" + self.path_for_combo(combo)),
                "keywords": html.escape("、".join(combo)),
                "content_html": content,
                "internal_links_html": "".join(link_html),
            },
        )

    def write_robots(self):
        (self.out_dir / "robots.txt").write_text(
            "User-agent: *\nAllow: /\n" + f"Sitemap: {self.cfg.base_url.rstrip('/')}/sitemap.xml\n",
            encoding="utf-8",
        )

    def submit_to_engines(self):
        if not self.cfg.submit.enabled:
            return
        sitemap_url = f"{self.cfg.base_url.rstrip('/')}/sitemap.xml"
        targets = []
        if self.cfg.submit.submit_google:
            targets.append(f"https://www.google.com/ping?sitemap={urllib.parse.quote(sitemap_url, safe=':/?=&')}")
        if self.cfg.submit.submit_bing:
            targets.append(f"https://www.bing.com/ping?sitemap={urllib.parse.quote(sitemap_url, safe=':/?=&')}")
        for url in targets:
            try:
                with urllib.request.urlopen(url, timeout=20) as resp:
                    print(f"[INFO] 提交成功: {url} ({resp.status})")
            except Exception as e:
                print(f"[WARN] 提交失败: {url} -> {e}")

    def run(self):
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.pages_dir.mkdir(parents=True, exist_ok=True)
        sitemap = SitemapWriter(self.out_dir, self.cfg.base_url, self.cfg.sitemap_max_urls)
        for idx in range(self.total_pages):
            combo = self.space.combo_by_index(idx)
            rel = self.path_for_combo(combo)
            abs_path = self.out_dir / rel
            abs_path.parent.mkdir(parents=True, exist_ok=True)
            abs_path.write_text(self.render_page(idx, combo), encoding="utf-8")
            sitemap.add(rel)
        sitemap.close()
        self.write_robots()
        self.submit_to_engines()
        print(f"[DONE] 完成，共 {self.total_pages} 页，输出目录: {self.out_dir}")


def load_config(path: Optional[str]) -> SEOFactoryConfig:
    if not path:
        return SEOFactoryConfig()
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    ai = AIConfig(**data.get("ai", {}))
    submit = SubmitConfig(**data.get("submit", {}))
    harvest = KeywordHarvestConfig(**data.get("keyword_harvest", {}))
    kwargs = {k: v for k, v in data.items() if k not in {"ai", "submit", "keyword_harvest"}}
    return SEOFactoryConfig(ai=ai, submit=submit, keyword_harvest=harvest, **kwargs)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Enterprise SEO static site factory")
    p.add_argument("--config", help="JSON配置文件路径")
    p.add_argument("--max-pages", type=int, help="覆盖配置中的 max_pages")
    p.add_argument("--base-url", help="覆盖配置中的 base_url")
    p.add_argument("--output-dir", help="覆盖配置中的 output_dir")
    p.add_argument("--collect-only", action="store_true", help="仅采集关键词，不生成页面")
    p.add_argument("--seed-file", help="额外种子词文件（每行1个关键词）")
    return p.parse_args(argv)


def load_seed_file(path: Optional[str], optional: bool = True) -> List[str]:
    if not path:
        return []
    p = Path(path)
    if not p.exists():
        if optional:
            return []
        print(f"[WARN] seed 文件不存在: {path}")
        return []
    return [x.strip() for x in p.read_text(encoding="utf-8").splitlines() if x.strip()]


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    cfg = load_config(args.config)
    if args.max_pages is not None:
        cfg.max_pages = args.max_pages
    if args.base_url:
        cfg.base_url = args.base_url
    if args.output_dir:
        cfg.output_dir = args.output_dir
    if args.collect_only:
        cfg.keyword_harvest.collect_only = True

    extra_seeds = load_seed_file(args.seed_file, optional=cfg.keyword_harvest.seed_file_optional)
    if cfg.keyword_harvest.enabled or cfg.keyword_harvest.collect_only:
        collected = KeywordHarvester(cfg.keyword_harvest).collect(extra_seeds)
        if cfg.keyword_harvest.append_to_keyword_dimensions and collected and cfg.keyword_dimensions:
            cfg.keyword_dimensions[0] = list(dict.fromkeys(cfg.keyword_dimensions[0] + collected))
        if cfg.keyword_harvest.collect_only:
            return 0

    if cfg.sitemap_max_urls <= 0 or cfg.sitemap_max_urls > 50000:
        raise ValueError("sitemap_max_urls 必须在 1-50000")
    if cfg.max_pages <= 0:
        raise ValueError("max_pages 必须 > 0")

    SEOFactory(cfg).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
