# 通用 SEO 自动化生成系统（可配置 5w+ 关键词库）

本项目用于批量生产可收录的专题落地页，适配 **简历App、字体、驾考App** 以及其它行业词。

## 能力清单

1. 自动生成关键词库（默认要求 5w+）
2. 高质量落地页模板（可选生成：每页独立标题/描述 + 差异内容 + 预览图 + 相关推荐 + 二维码下载 + 下载引导）
3. 根据关键词库批量生成页面数据（可选输出 HTML/SVG）
4. 自动生成 sitemap.xml
5. 自动生成站内内链
6. 自动提交搜索引擎（IndexNow / Baidu / Google）

---

## 1) 关键词库（可配置，默认通用）

默认配置文件：`seo_automation/keyword_library.json`

已内置以下维度并可自行扩展：
- 产品词：简历App、字体、驾考App、PDF、效率工具等
- 修饰词：免费、无广告、最新版、官方正版等
- 意图词：下载、官网、对比、评测、教程等
- 人群词：学生、应届生、设计师、司机等
- 场景词：面试、校招、驾照考试、办公等
- 平台词：安卓、iOS、Windows、Mac、网页版等
- 地域词：全国 + 多城市
- 年份词：2024~2027
- 问句词：怎么、如何、哪个、值不值得等

通过组合模式自动扩展到 5w+ 关键词。

---

## 2) 批量生成页面（通用场景）

```bash
python3 seo_automation/generate_site.py \
  --site-url https://example.com \
  --brand-name "通用下载站" \
  --download-url "https://example.com/download" \
  --seed "简历app" --seed "字体" --seed "驾考app" \
  --page-count 500 \
  --min-keyword-library 50000 \
  --clean-output
  # 默认仅生成关键词/URL/sitemap 等数据，不生成 html/svg
```


如需真正输出落地页 HTML/SVG（默认关闭），追加：

```bash
python3 seo_automation/generate_site.py \
  --site-url https://example.com \
  --brand-name "通用下载站" \
  --download-url "https://example.com/download" \
  --page-count 500 \
  --min-keyword-library 50000 \
  --clean-output \
  --generate-pages
```

生成结果默认输出到 `dist/`：
- `dist/pages/*.html`：落地页（仅 `--generate-pages` 时）
- `dist/index.html`：导航页（仅 `--generate-pages` 时）
- `dist/previews/*.svg`：每页示意图（仅 `--generate-pages` 时）
- `dist/sitemap.xml`：站点地图
- `dist/urls.txt`：URL 列表（可提交）
- `dist/keywords.csv`：已生成页面关键词
- `dist/keyword_library.csv`：完整关键词库（5w+）

---

## 3) 提交搜索引擎

```bash
# IndexNow
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

# Google sitemap ping
python3 seo_automation/submit_search_engines.py \
  --engine google \
  --site-url https://example.com \
  --sitemap-url https://example.com/sitemap.xml
```

---

## 参数说明（核心）

- `--keyword-config`：关键词配置 JSON
- `--min-keyword-library`：关键词库最小规模（默认 50000）
- `--page-count`：本次生成页面数（从关键词库中取前 N 条）
- `--related-count`：每页相关推荐内链数
- `--seed`：追加自定义业务词（可重复）
- `--clean-output`：生成前清理历史页面和示意图，避免旧文件残留
- `--generate-pages`：开启后才会生成 HTML/SVG 页面文件（默认不生成）

---

## 建议工作流

1. 先调整 `keyword_library.json` 贴合你的业务词池（如简历App/字体/驾考）。
2. 先生成 200~500 页上线测试抓取。
3. 观察收录后逐步扩到 2k/5k/1w 页。
4. 每周追加新词并重新生成、增量提交。
