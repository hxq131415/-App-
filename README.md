# SEO 简历模板页面生成器（高并发版）

用于批量生成静态 SEO 页面，支持生成 5 万级页面，并可通过多进程并行提升速度。

## 文件说明

- `seo_generator_optimized.py`：主脚本。

## 环境要求

- Python 3.9+
- 无第三方依赖（仅使用标准库）

## 快速开始

### 1) 查看参数

```bash
python3 seo_generator_optimized.py --help
```

### 2) 生成 200 个页面（默认）

```bash
python3 seo_generator_optimized.py --output dist --base-url https://example.com --total 200 --workers 1
```

### 3) 生成 50,000 个页面（推荐多进程）

```bash
python3 seo_generator_optimized.py --output dist --base-url https://example.com --total 50000 --workers 8
```

> `--workers` 建议设置为 CPU 核心数或核心数 - 1。

## 参数说明

- `--output`：输出目录，默认 `dist`
- `--base-url`：站点基础 URL（用于 canonical / sitemap）
- `--total`：生成页面数量，默认 `200`
- `--workers`：并行进程数，默认 `1`（单进程）

## 输出产物

在 `--output` 指定目录下会生成：

- `*.html`：每个关键词对应的页面
- `index.html`：页面目录索引
- `keywords.csv`：关键词与 slug 对照
- `sitemap.xml`：站点地图

## 性能建议（5 万页面）

1. 使用本地 SSD 目录作为输出路径。
2. 合理设置 `--workers`（过高会因进程切换导致收益下降）。
3. 先用 `--total 1000` 做小规模验证，再执行全量。
4. 生成完成后再做压缩/上传，避免边生成边同步影响写入性能。

## 常见问题

### Q1：为什么关键词会重复模式？
当 `--total` 大于基础组合数时，脚本会循环使用组合模板以满足目标数量。

### Q2：单机太慢怎么办？
- 提高 `--workers`
- 拆分任务（如分批生成到不同目录）
- 在更高 IOPS 的磁盘上执行

### Q3：如何验证是否生成成功？
可检查文件数量和关键文件是否存在，例如：

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('dist')
print('html_count=', len(list(p.glob('*.html'))))
print('has_keywords_csv=', (p / 'keywords.csv').exists())
print('has_sitemap=', (p / 'sitemap.xml').exists())
PY
```
