# 简历模板 SEO 落地页生成脚本

按你给的方案实现：

- 批量生成简历模板落地页 HTML（含独立标题、描述、FAQ、评价、相关推荐、下载引导）
- 生成关键词词库 `keyword_library.csv`
- 生成页面关键词明细 `keywords.csv`
- 生成 `sitemap.xml` 和 `urls.txt`
- 生成目录页 `index.html`

## 使用方法

```bash
python3 seo_automation/generate_site.py \
  --output dist \
  --base-url https://example.com \
  --total 200
```

## 输出文件

- `dist/*.html`：每个落地页 + `index.html`
- `dist/keywords.csv`：已生成页面关键词
- `dist/keyword_library.csv`：完整词库（行业 × 基础词 × 风格词）
- `dist/sitemap.xml`
- `dist/urls.txt`

## 说明

- 脚本会先清理输出目录里旧的 html/csv/sitemap/urls 再重新生成。
- 当前为“简历模板”垂直场景，词库来源于脚本内置常量（基础词、行业、风格）。
