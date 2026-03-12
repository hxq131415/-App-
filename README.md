# SEO Factory

企业级 SEO 自动站生成器（静态站），支持：

- 自动生成百万页面（受关键词组合与 `max_pages` 控制）
- 自动 AI 写内容（OpenAI 兼容接口）
- 自动内链
- 自动 sitemap 拆分（单文件最多 50000 URL）
- 自动提交搜索引擎（Google/Bing ping + 百度主动推送 + IndexNow）
- 多关键词组合（笛卡尔积，可扩展至千万页面）
- **支持按模板生成落地页 HTML**

## 一键运行

```bash
python seo_factory.py
```

默认会使用内置配置并输出到 `dist/`。

## 使用配置文件

```bash
python seo_factory.py --config config.example.json
```

也可以临时覆盖：

```bash
python seo_factory.py --config config.example.json --max-pages 1000000 --base-url https://seo.example.com
```

## 落地页模板用法

默认模板文件是：`landing_page.template.html`，可在配置里改 `page_template_file`。

模板可用占位符：

- `{{lang}}`
- `{{site_name}}`
- `{{title}}`
- `{{headline}}`
- `{{description}}`
- `{{canonical_url}}`
- `{{keywords}}`
- `{{content_html}}`（AI/模板正文 HTML）
- `{{internal_links_html}}`（自动内链 `<li>` 列表）

你只需要改模板结构，不用改 Python 代码。


## 百度自动推送

已支持百度主动推送 API（普通收录）。在配置文件 `submit` 中设置：

- `baidu_enabled = true`
- `baidu_site = "你的站点域名"`（例如 `seo.example.com`，不带协议）
- `baidu_token = "你的百度推送 token"`
- `baidu_batch_size = 2000`（单次推送 URL 条数，默认 2000）

脚本会在生成完成后按批次自动向百度提交全部生成 URL。

## 开启 AI 写作

在配置文件里设置：

- `ai.enabled = true`
- `ai.api_key = "你的API Key"`
- 如需兼容网关，改 `ai.endpoint`

> 若 AI 请求失败会自动降级为模板内容，避免任务中断。

## 输出结构

- `dist/pages/*.html` 页面文件
- `dist/sitemap-*.xml` 拆分 sitemap
- `dist/sitemap.xml` sitemap 索引
- `dist/robots.txt`

