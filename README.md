# 5万 SEO 页面自动生成系统

按你的要求，结构已拆分为：

- **HTML 页面固定生成到 `pages/` 目录**
- **sitemap / robots / 词库与索引数据生成到 `dist/` 目录**（与 `pages/` 同级）
- **模板文件单独抽离**：`templates/page_template.html`
- **关键词和站点参数单独抽离**：`seo.config.json`

## 一键生成

```bash
python3 generate_seo_system.py
```

首次运行会自动创建：

- `templates/page_template.html`（可直接替换为你的页面模版）
- `seo.config.json`（可配置关键词、域名、站点名等）

## 配置文件示例（seo.config.json）

```json
{
  "site_name": "SEO自动化站点",
  "base_url": "https://example.com",
  "keyword_prefix": "SEO专题",
  "default_keywords": ["SEO", "长尾关键词", "内容营销"]
}
```

## 常用参数

```bash
python3 generate_seo_system.py \
  --count 50000 \
  --pages-dir pages \
  --meta-dir dist \
  --template templates/page_template.html \
  --config seo.config.json
```

## 输出结构

```text
.
├── pages/
│   ├── topic-00001.html
│   ├── ...
│   └── topic-50000.html
├── dist/
│   ├── sitemap.xml
│   ├── robots.txt
│   ├── pages-data.json
│   └── keywords.txt
├── templates/
│   └── page_template.html
└── seo.config.json
```

## 说明

- 模板变量支持：`${title}` `${description}` `${keywords}` `${url}` `${id}` `${slug}` `${updated_at}` `${json_ld}`。
- `dist/keywords.txt` 会输出本次生成的关键词词库。
- 当页面数超过 50,000 时，会自动拆分为 `sitemap-*.xml` 并生成 `sitemap.xml` 索引。
