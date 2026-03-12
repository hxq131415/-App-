# SEO Factory

企业级 SEO 自动站生成器（静态站），支持：

- 自动生成百万页面（受关键词组合与 `max_pages` 控制）
- 自动 AI 写内容（OpenAI 兼容接口）
- 自动内链
- 自动 sitemap 拆分（单文件最多 50000 URL）
- 自动提交搜索引擎（Google/Bing ping + IndexNow）
- 多关键词组合（笛卡尔积，可扩展至千万页面）

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

