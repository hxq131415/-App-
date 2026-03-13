# SEO 自动化站点生成系统

这套工具可一键完成：

1. 自动生成关键词
2. 按高质量落地页模板批量产出 HTML（独立标题、描述、差异化内容、示意图、相关推荐、二维码下载、清晰下载引导）
3. 自动生成 sitemap.xml
4. 自动生成站内内链
5. 自动提交搜索引擎（IndexNow / Baidu / Google）

## 快速开始

```bash
python3 seo_automation/generate_site.py \
  --site-url https://example.com \
  --brand-name "星云下载站" \
  --download-url "https://example.com/download" \
  --seed "AI写作" --seed "效率工具" --seed "PDF编辑"
```

生成结果默认输出到 `dist/`：

- `dist/pages/*.html`: 批量落地页
- `dist/index.html`: 导航首页
- `dist/sitemap.xml`: 站点地图
- `dist/keywords.csv`: 关键词列表
- `dist/urls.txt`: 页面 URL 列表（可用于 IndexNow）
- `dist/previews/*.svg`: 每页示意图

## 提交搜索引擎

```bash
# IndexNow（推荐）
python3 seo_automation/submit_search_engines.py \
  --engine indexnow \
  --site-url https://example.com \
  --key your-indexnow-key \
  --key-location https://example.com/your-indexnow-key.txt \
  --url-list dist/urls.txt

# Baidu 主动推送
python3 seo_automation/submit_search_engines.py \
  --engine baidu \
  --site-url https://example.com \
  --token your-baidu-token \
  --url-list dist/urls.txt

# Google（sitemap ping）
python3 seo_automation/submit_search_engines.py \
  --engine google \
  --site-url https://example.com \
  --sitemap-url https://example.com/sitemap.xml
```

> 说明：Google 已弱化 ping 机制，但该接口仍可用于轻量通知；更强收录能力建议结合 Search Console 与高质量外链。

## 参数建议

- `--count`: 关键词总量，默认 36
- `--related-count`: 每页相关推荐数量，默认 3
- `--language`: 页面语言标记，默认 `zh-CN`

## 目录结构

```text
seo_automation/
  generate_site.py
  submit_search_engines.py
dist/
  ...
```
