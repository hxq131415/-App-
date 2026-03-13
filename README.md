# SEO 静态页自动化系统（简历模板 App）

这套系统用于为你的简历模板 App 自动生成可收录的静态 SEO 页面，并配套：

- 自动生成 HTML 页面
- 自动生成 sitemap.xml
- 自动生成站内内链
- 自动提交搜索引擎（支持 IndexNow、Baidu）

## 目录结构

```text
.
├── content/pages.json               # 关键词与页面数据源
├── scripts/seo_generate.py          # 静态页 + sitemap + robots + 内链生成
├── scripts/submit_search_engines.py # 搜索引擎自动提交
├── templates/page.html              # 页面模板
└── dist/                            # 生成产物
```

## 1) 配置页面数据

编辑 `content/pages.json`：

- `site`：站点级配置（域名、品牌名、下载地址等）
- `pages`：每个静态页面的 SEO 数据

> `slug` 会作为页面文件名，例如 `resume-template-for-students` -> `dist/resume-template-for-students.html`

## 2) 生成静态页面与 sitemap

```bash
python3 scripts/seo_generate.py --input content/pages.json --output dist
```

成功后会生成：

- `dist/*.html`
- `dist/sitemap.xml`
- `dist/robots.txt`
- `dist/search-engine-urls.txt`（用于批量提交 URL）

## 3) 自动提交搜索引擎

> 请先确保线上可访问 `https://你的域名/sitemap.xml`。

### 3.1 使用 IndexNow（推荐）

```bash
export INDEXNOW_KEY="your-indexnow-key"
python3 scripts/submit_search_engines.py \
  --site https://example.com \
  --urls-file dist/search-engine-urls.txt
```

### 3.2 使用 Baidu 主动推送

```bash
export BAIDU_SITE="example.com"
export BAIDU_TOKEN="your-baidu-token"
python3 scripts/submit_search_engines.py \
  --site https://example.com \
  --urls-file dist/search-engine-urls.txt
```

## 建议上线流程

1. 维护 `content/pages.json` 关键词库
2. 每次更新后运行生成脚本
3. 部署 `dist` 到静态托管/CDN
4. 运行提交脚本，主动推送 URL
5. 在 Google Search Console / Bing Webmaster / 百度站长平台验证收录



## 4) 生成 5-10 万关键词库（同结构 JSON）

如果你要批量扩展落地页关键词库，可运行：

```bash
python3 scripts/generate_keyword_library.py   --input content/pages.json   --output content/pages.100k.json   --target-count 100000
```

说明：
- 输出仍然是与你当前一致的结构：`{"site": {...}, "pages": [...]}`。
- 可把 `pages.100k.json` 直接喂给 `scripts/seo_generate.py` 生成静态页。
- 建议先用较小数量试跑（如 `--target-count 5000`）验证部署与构建耗时。
