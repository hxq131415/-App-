# 简历模板 SEO 页面生成器

按“官网落地页风格模板”批量生成简历模板 SEO 页面，满足：

- 生成 **200 个简历模板 SEO 关键词**。
- 每页自动生成 SEO 信息（`title`、`description`、`keywords`、`canonical`、正文）。
- 批量生成 HTML 页面（页面结构与示例模板一致：Hero、热门模板、评价、FAQ、CTA、Footer）。
- 自动生成 `sitemap.xml`。

## 使用方式

```bash
python3 scripts/generate_resume_pages.py \
  --output dist \
  --base-url https://your-domain.com \
  --total 200
```

## 输出内容

默认输出到 `dist/`：

- `index.html`：200 个页面目录
- `keywords.csv`：关键词与 slug 映射
- `sitemap.xml`：自动站点地图
- `resume-*.html`：每个关键词对应一个落地页

## 资源说明

生成的页面使用以下静态资源路径（按你的模板约定）：

- `images/qrcode.png`
- `images/preview.png`
- `images/template1.png` ~ `images/template8.png`

部署时请确保这些图片资源可访问。
