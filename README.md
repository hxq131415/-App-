# SEO Factory（简历模板场景）

用于简历模板 App 的 SEO 页面工厂，支持：

- 自动采集关键词（百度/Bing 联想词）
- 关键词自动并入页面维度
- 自动生成大量落地页
- 模板化页面输出
- sitemap 拆分 + 搜索引擎提交（Google/Bing/Baidu/IndexNow）

## 一键运行

```bash
python seo_factory.py --config config.example.json
```

## 自动采集关键词（你当前最需要）

脚本会根据 `keyword_harvest.seed_keywords` 自动采集联想词，并写入：

- `keyword_harvest.output_file`（默认 `keywords.resume.txt`）

并可自动并入 `keyword_dimensions[0]` 参与页面生成（`append_to_keyword_dimensions=true`）。

### 仅采集关键词，不生成页面

```bash
python seo_factory.py --config config.example.json --collect-only
```

### 追加本地种子词文件（每行1个）

```bash
python seo_factory.py --config config.example.json --seed-file seeds.txt
```

## 落地页模板

默认模板：`landing_page.template.html`，支持占位符：

- `{{lang}}`
- `{{site_name}}`
- `{{title}}`
- `{{headline}}`
- `{{description}}`
- `{{canonical_url}}`
- `{{keywords}}`
- `{{content_html}}`
- `{{internal_links_html}}`

## 百度自动提交收录

在 `submit` 中配置：

- `enabled=true`
- `baidu_enabled=true`
- `baidu_site=你的域名`
- `baidu_token=你的token`

## 产物

- `dist/pages/*.html`
- `dist/sitemap-*.xml`
- `dist/sitemap.xml`
- `dist/robots.txt`
- `keywords.resume.txt`
