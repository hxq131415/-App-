# 简历模板 SEO 生成器（模板与配置已分离）

按你的要求已调整为：

- **落地页模板单独文件**：`seo_automation/templates/landing_page.html`
- **关键词与参数配置单独文件**：`seo_automation/config/resume_config.json`
- **5w+ 关键词库配置文件**：`seo_automation/keyword_library.json`
- **生成的 HTML 放在 `pages/` 目录**
- **词库/站点数据放在 `dist/` 目录**（和 `pages/` 同级）

## 使用

```bash
python3 seo_automation/generate_site.py \
  --pages-output pages \
  --data-output dist \
  --base-url https://example.com \
  --total 50000 \
  --min-keyword-library 50000
```

> 说明：脚本会先校验词库规模（默认至少 50,000），再按 `--total` 生成页面与数据。若基础组合不足，会自动从 `keyword_library.json` 补齐，因此支持生成 5w+ 页面。

## 输出结构

- `pages/`
  - `index.html`
  - `resume-*.html`
- `dist/`
  - `keywords.csv`
  - `keyword_library.csv`
  - `sitemap.xml`
  - `urls.txt`

## 可替换模板

直接修改 `seo_automation/templates/landing_page.html` 即可替换页面结构；脚本会注入：
- `${title}` `${description}` `${keywords_meta}` `${canonical}`
- `${keyword}` `${industry}` `${style}`
- `${related_html}` `${reviews_html}` `${faq_html}`
- `${seo_p1}` `${seo_p2}`

## 可配置参数

在 `seo_automation/config/resume_config.json` 中维护：
- `base_keywords`
- `industries`
- `style_tags`
- `cities`
- `names`

在 `seo_automation/keyword_library.json` 中维护 5w+ 通用词库组合参数：
- `products` `modifiers` `intents`
- `audiences` `scenarios` `platforms`
- `regions` `question_prefixes` `years`
