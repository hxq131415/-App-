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

### 证书与种子文件兼容项（修复你反馈的告警）

在 `keyword_harvest` 中可配置：

- `verify_ssl: false`：关闭联想词采集的 SSL 证书校验，避免本机缺少 CA 时报 `CERTIFICATE_VERIFY_FAILED`
- `seed_file_optional: true`：`--seed-file` 文件不存在时静默跳过，不再报警

如果你在线上环境证书完整，建议把 `verify_ssl` 改回 `true`。


## 落地页模板

已内置高转化下载页结构：首屏卖点 + CTA按钮 + 扫码下载区 + 模板预览图。


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
- `{{app_name}}`
- `{{app_tagline}}`
- `{{app_download_url}}`
- `{{qr_code_image_url}}`
- `{{preview_image_1}}`
- `{{preview_image_2}}`
- `{{preview_image_3}}`

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
