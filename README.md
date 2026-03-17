# 职有简历 App 推广文章批量生成脚本（可直接复制发布）

这个脚本用于批量生成更长、更实用的推广文章，并自动包含“职有简历 App”软引导内容。默认输出为**平台可直接复制**排版（txt）。

## 快速开始

```bash
python3 generate_promo_articles.py --count 12
```

输出目录默认是 `generated_articles/`。

## 常用参数

- `--count`：生成文章数量。
- `--output-dir`：输出目录。
- `--checklist-size`：每篇文章的自查清单条数（1~5）。
- `--copy-ready`：输出平台可直接复制版（默认开启）。
- `--no-copy-ready`：关闭可复制排版，输出 Markdown 长文结构。
- `--audiences`：受众列表（空格分隔）。
- `--channels`：渠道列表（空格分隔，支持小红书/公众号/知乎/B站）。
- `--keywords`：关键词列表（空格分隔）。
- `--tones`：文风列表（空格分隔）。
- `--seed`：随机种子。

## 示例

### 1) 直接生成平台可粘贴文案（推荐）

```bash
python3 generate_promo_articles.py \
  --count 6 \
  --output-dir out_articles \
  --channels 小红书 公众号 知乎 \
  --keywords 求职 简历优化 面试准备
```

### 2) 生成 Markdown 长文结构

```bash
python3 generate_promo_articles.py \
  --count 3 \
  --no-copy-ready \
  --output-dir out_markdown
```

## 说明

- 每篇文章默认会按渠道自动微调结构（例如：小红书使用短段 + 清单，公众号使用章节体，知乎使用问答体）。
- 文章末尾自动追加相关话题标签，方便发布时直接复制。
- 建议发布前补充你们真实案例/数据，可进一步提升转化。
