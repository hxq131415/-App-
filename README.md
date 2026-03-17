# 职有简历 App 推广文章批量生成脚本

这个仓库提供一个可直接运行的 Python 脚本，用于批量生成高质量推广文章，并自然包含“职有简历 App”软引导下载内容。

## 快速开始

```bash
python3 generate_promo_articles.py --count 20
```

生成结果默认保存在 `generated_articles/` 目录下。

## 常用参数

- `--count`：生成文章数量。
- `--output-dir`：输出目录。
- `--audiences`：受众列表（空格分隔）。
- `--channels`：渠道列表（空格分隔）。
- `--keywords`：关键词列表（空格分隔）。
- `--tones`：文风列表（空格分隔）。
- `--seed`：随机种子，便于复现。

## 示例

```bash
python3 generate_promo_articles.py \
  --count 6 \
  --output-dir out_articles \
  --audiences 应届生 转行求职者 互联网产品经理 \
  --channels 小红书 公众号 知乎 \
  --keywords 求职 简历优化 面试准备 \
  --tones 专业可信 轻松实用 真诚陪伴
```

## 说明

- 每篇文章为 Markdown 格式，方便二次编辑。
- 文章默认包含：开头痛点、方法建议、场景化提示、软引导下载。
- 建议发布前根据你们品牌语气和真实案例做少量人工润色。
