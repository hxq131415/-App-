# 5万 SEO 页面自动生成系统

一键生成以下内容：

- 50,000 个静态 SEO HTML 页面（默认）
- `sitemap.xml`（超量时自动拆分为 `sitemap-*.xml` 并生成索引）
- `robots.txt`
- `pages-data.json`（页面结构化数据索引）

## 快速开始

```bash
python3 generate_seo_system.py
```

默认输出目录为 `dist_seo/`。

## 常用参数

```bash
python3 generate_seo_system.py \
  --count 50000 \
  --base-url https://your-domain.com \
  --site-name "你的站点名" \
  --keyword-prefix "你的关键词" \
  --output dist_seo
```

## 输出结构

```text
dist_seo/
├── pages/
│   ├── topic-00001.html
│   ├── ...
│   └── topic-50000.html
├── sitemap.xml
├── robots.txt
└── pages-data.json
```

## 说明

- 生成的 HTML 内置基础 SEO 标签：`title`、`description`、`keywords`、canonical、OpenGraph、JSON-LD。
- `robots.txt` 自动写入 sitemap 地址。
- 可通过修改模板函数 `render_html_page` 定制页面样式与文案。
