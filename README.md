# macOS Objective-C 混淆工具（可用于上架前保护）

这个工程提供一个**可集成到 CI / Xcode Build Phase** 的 Objective-C 源码混淆工具，重点是：

- 默认配置偏向 Apple 审核友好（保留常见系统生命周期 / 序列化方法）。
- 只处理项目内源码符号（类名、协议名、函数名），不触碰系统 API。
- 支持固定 seed，保证每次构建输出一致，便于回溯。

## 快速开始

```bash
bash scripts/run_obfuscation.sh
```

## 配置

编辑 `obfuscator.config.json`：

- `source_root`: 要混淆的源码根目录。
- `include_prefixes`: 只混淆这些前缀开头的符号（推荐内部统一前缀，例如 `APP`）。
- `exclude_symbols`: 强制排除。
- `seed`: 混淆种子（建议在 CI 用私密变量注入）。
- `output_map`: 原始符号到混淆符号的映射输出路径。

## 审核安全建议

1. 保留与系统协议相关的选择器（`initWithCoder`、`encodeWithCoder` 等）。
2. 不要混淆 Info.plist / URL Scheme / entitlement / storyboard 里引用的符号。
3. 混淆仅用于知识产权保护，不要用于隐藏违规行为。

## 在 Xcode 中接入

在 Target -> Build Phases 新增 Run Script：

```bash
bash "$SRCROOT/scripts/run_obfuscation.sh" "$SRCROOT/obfuscator.config.json"
```

建议只在 Release 配置执行。
