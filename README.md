# 简历模板 SEO 页面生成器

满足以下目标：

- 生成 **200 个简历模板 SEO 关键词**。
- 为每个页面自动生成 `title` / `description` / `h1` / 正文文案。
- 支持批量输出 HTML 页面。
- 自动生成 `sitemap.xml`。

## 使用方式

```bash
python3 scripts/generate_resume_pages.py \
  --output dist \
  --base-url https://your-domain.com \
  --total 200
```

## 输出内容

生成目录默认在 `dist/`：

- `index.html`：模板页面总目录
- `keywords.csv`：200个关键词及slug
- `sitemap.xml`：站点地图
- `resume-*.html`：每个关键词对应的SEO页面

适合直接部署到静态网站托管平台（Nginx、Vercel、Netlify、对象存储静态站点等）。
