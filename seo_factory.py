#!/usr/bin/env python3
"""SEO Factory: enterprise-style static SEO site generator.

Features:
- Massive page generation (1M+ pages)
- AI content generation (OpenAI-compatible API)
- Automatic internal links
- Automatic sitemap splitting + sitemap index
- Automatic search engine submission (sitemap ping + IndexNow)
- Multi-keyword Cartesian combinations (10M+ pages)

One-click run:
    python seo_factory.py
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
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
    indexnow_enabled: bool = False
    indexnow_host: str = ""
    indexnow_key: str = ""
    indexnow_key_location: str = ""


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
            ["企业", "跨境", "本地"],
            ["SEO", "AI营销", "内容自动化"],
            ["服务", "解决方案", "工具"],
        ]
    )
    ai: AIConfig = field(default_factory=AIConfig)
    submit: SubmitConfig = field(default_factory=SubmitConfig)


def safe_product(values: Sequence[int]) -> int:
    result = 1
    for value in values:
        result *= value
    return result


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
        if not self.config.enabled or not self.config.api_key:
            return self._fallback(combo, title)
        if self.config.provider != "openai":
            return self._fallback(combo, title)

        payload = {
            "model": self.config.model,
            "temperature": self.config.temperature,
            "max_tokens": self.config.max_tokens,
            "messages": [
                {
                    "role": "system",
                    "content": "你是企业SEO内容写作助手。输出结构化、可读、原创、避免夸张承诺。",
                },
                {
                    "role": "user",
                    "content": (
                        f"请围绕标题《{title}》写中文SEO落地页正文，关键词：{', '.join(combo)}。"
                        "要求：包含小标题、要点列表、FAQ（2条），总字数约700-900字。"
                    ),
                },
            ],
        }
        req = urllib.request.Request(
            self.config.endpoint,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.config.api_key}",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.config.timeout_seconds) as resp:
                body = json.loads(resp.read().decode("utf-8"))
            text = body["choices"][0]["message"]["content"].strip()
            if self.config.sleep_seconds > 0:
                time.sleep(self.config.sleep_seconds)
            return text
        except Exception as e:
            print(f"[WARN] AI 生成失败，使用模板兜底: {e}")
            return self._fallback(combo, title)

    @staticmethod
    def _fallback(combo: Sequence[str], title: str) -> str:
        keywords = "、".join(combo)
        return f"""
<h2>{html.escape(title)}：为什么值得投入？</h2>
<p>{html.escape(keywords)} 是当前企业获客中高价值的关键词组合，适合构建长期自然流量资产。</p>
<h2>实施路径</h2>
<ul>
  <li>关键词分层：品牌词、品类词、需求词并行布局。</li>
  <li>内容矩阵：以场景化内容覆盖用户全旅程。</li>
  <li>转化优化：落地页结构围绕咨询、留资、购买设计。</li>
</ul>
<h2>常见问题 FAQ</h2>
<p><strong>Q1:</strong> 多关键词页面会不会互相竞争？<br><strong>A:</strong> 通过 URL 结构、标题差异和内链策略可有效降低冲突。</p>
<p><strong>Q2:</strong> 新站多久能看到自然流量？<br><strong>A:</strong> 一般 4-12 周开始出现趋势，取决于行业竞争与更新频率。</p>
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
        loc = f"{self.base_url}/{path.lstrip('/')}"
        self.current_file.write(f"  <url><loc>{html.escape(loc)}</loc></url>\n")
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
        return self.default_page_template()

    @staticmethod
    def default_page_template() -> str:
        return """<!doctype html>
<html lang=\"{{lang}}\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" />
  <title>{{title}}</title>
  <meta name=\"description\" content=\"{{description}}\" />
  <link rel=\"canonical\" href=\"{{canonical_url}}\" />
</head>
<body>
  <main>
    <h1>{{headline}}</h1>
    {{content_html}}
    <section>
      <h2>相关推荐</h2>
      <ul>
        {{internal_links_html}}
      </ul>
    </section>
  </main>
</body>
</html>
"""

    @staticmethod
    def render_template(template: str, variables: dict) -> str:
        out = template
        for key, value in variables.items():
            out = out.replace("{{" + key + "}}", value)
        return out

    @staticmethod
    def slugify(text: str) -> str:
        s = text.lower().strip()
        s = re.sub(r"\s+", "-", s)
        s = re.sub(r"[^\w\-\u4e00-\u9fff]", "", s)
        s = re.sub(r"-+", "-", s)
        return s.strip("-") or "item"

    def path_for_combo(self, combo: Sequence[str]) -> str:
        joined = "-".join(combo)
        digest = hashlib.md5(joined.encode("utf-8")).hexdigest()[:8]
        return f"pages/{self.slugify(joined)}-{digest}.html"

    def internal_link_indices(self, idx: int) -> List[int]:
        n = self.total_pages
        if n <= 1:
            return []
        links = []
        for step in range(1, self.cfg.internal_links_per_page + 1):
            links.append((idx + step) % n)
        seed = int(hashlib.md5(str(idx).encode()).hexdigest()[:8], 16)
        links.append(seed % n)
        links = [x for x in dict.fromkeys(links) if x != idx]
        return links[: self.cfg.internal_links_per_page]

    def render_page(self, idx: int, combo: Sequence[str]) -> str:
        title = " | ".join(combo) + " - 专题页"
        desc = f"围绕 {'、'.join(combo)} 的企业级解决方案、实施路径与常见问题。"
        content = self.ai_writer.generate(combo, title)

        link_html = []
        for target in self.internal_link_indices(idx):
            t_combo = self.space.combo_by_index(target)
            t_path = self.path_for_combo(t_combo)
            t_title = " / ".join(t_combo)
            rel = os.path.relpath(self.out_dir / t_path, start=self.pages_dir)
            link_html.append(f'<li><a href="{html.escape(rel)}">{html.escape(t_title)}</a></li>')

        canonical_url = self.cfg.base_url.rstrip('/') + '/' + self.path_for_combo(combo)
        return self.render_template(
            self.page_template,
            {
                "lang": html.escape(self.cfg.language),
                "site_name": html.escape(self.cfg.site_name),
                "title": html.escape(title),
                "headline": html.escape(title),
                "description": html.escape(desc),
                "canonical_url": html.escape(canonical_url),
                "keywords": html.escape("、".join(combo)),
                "content_html": content,
                "internal_links_html": "".join(link_html),
            },
        )

    def write_robots(self):
        txt = (
            "User-agent: *\n"
            "Allow: /\n"
            f"Sitemap: {self.cfg.base_url.rstrip('/')}/sitemap.xml\n"
        )
        (self.out_dir / "robots.txt").write_text(txt, encoding="utf-8")

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

        if self.cfg.submit.indexnow_enabled:
            self.submit_indexnow()

    def submit_indexnow(self):
        c = self.cfg.submit
        if not (c.indexnow_host and c.indexnow_key and c.indexnow_key_location):
            print("[WARN] IndexNow 配置不完整，跳过")
            return
        payload = {
            "host": c.indexnow_host,
            "key": c.indexnow_key,
            "keyLocation": c.indexnow_key_location,
            "urlList": [f"{self.cfg.base_url.rstrip('/')}/sitemap.xml"],
        }
        req = urllib.request.Request(
            "https://api.indexnow.org/indexnow",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                print(f"[INFO] IndexNow 提交成功: {resp.status}")
        except Exception as e:
            print(f"[WARN] IndexNow 提交失败: {e}")

    def run(self):
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.pages_dir.mkdir(parents=True, exist_ok=True)

        sitemap = SitemapWriter(self.out_dir, self.cfg.base_url, self.cfg.sitemap_max_urls)
        started = time.time()

        for idx in range(self.total_pages):
            combo = self.space.combo_by_index(idx)
            rel_path = self.path_for_combo(combo)
            abs_path = self.out_dir / rel_path
            abs_path.parent.mkdir(parents=True, exist_ok=True)
            abs_path.write_text(self.render_page(idx, combo), encoding="utf-8")
            sitemap.add(rel_path)

            if (idx + 1) % 5000 == 0:
                elapsed = time.time() - started
                rate = (idx + 1) / max(elapsed, 1)
                print(f"[INFO] 已生成 {idx + 1}/{self.total_pages} 页, {rate:.1f} pages/s")

        sitemap.close()
        self.write_robots()
        self.submit_to_engines()
        elapsed = time.time() - started
        print(f"[DONE] 完成，共 {self.total_pages} 页，耗时 {elapsed:.1f}s，输出目录: {self.out_dir}")


def load_config(path: Optional[str]) -> SEOFactoryConfig:
    if not path:
        return SEOFactoryConfig()
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    ai = AIConfig(**data.get("ai", {}))
    submit = SubmitConfig(**data.get("submit", {}))
    kwargs = {k: v for k, v in data.items() if k not in {"ai", "submit"}}
    return SEOFactoryConfig(ai=ai, submit=submit, **kwargs)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Enterprise SEO static site factory")
    p.add_argument("--config", help="JSON配置文件路径")
    p.add_argument("--max-pages", type=int, help="覆盖配置中的 max_pages")
    p.add_argument("--base-url", help="覆盖配置中的 base_url")
    p.add_argument("--output-dir", help="覆盖配置中的 output_dir")
    return p.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    cfg = load_config(args.config)
    if args.max_pages is not None:
        cfg.max_pages = args.max_pages
    if args.base_url:
        cfg.base_url = args.base_url
    if args.output_dir:
        cfg.output_dir = args.output_dir

    if cfg.sitemap_max_urls <= 0 or cfg.sitemap_max_urls > 50000:
        raise ValueError("sitemap_max_urls 必须在 1-50000")
    if cfg.max_pages <= 0:
        raise ValueError("max_pages 必须 > 0")

    SEOFactory(cfg).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
