# IPA Obfuscation Build Script

`scripts/ipa_obfuscate.sh` 现在支持两种模式：

1. **源码构建混淆模式**：从 Xcode 工程构建后进行链接顺序扰动并导出 IPA。
2. **输入 IPA 二次处理模式**：直接对现有 IPA 解包注入噪声并重新打包（可选重签名）。

## 能力说明

### 模式1：源码构建混淆（推荐）

- Objective-C 类符号顺序打散（`_OBJC_CLASS_$_*`）
- Swift mangled 符号顺序打散（`$s` / `_$s`）
- selector 引用顺序打散（`OBJC_SELECTOR_REFERENCES` / `__objc_selrefs`）
- metadata / method list 相关符号打散（`__OBJC_$_*METHOD*`）
- `__objc_classlist` / `__objc_selrefs` 影响项通过符号噪声触发增强
- 函数物理地址通过 `-Wl,-order_file` 重布局
- 每次生成随机 `__DATA,__obfpad`，触发 Mach-O 体积变化
- 支持 CocoaPods：检测 `Podfile` 后自动 `pod install` 并优先使用 workspace

### 模式2：输入 IPA 二次处理

- 对现有 IPA 解包后注入随机噪声文件（`Payload/*.app/.obfnoise`）
- 更新 `Info.plist` 的 `ObfuscationNonce`，增加每次构建差异
- 重新打包输出新 IPA
- 支持可选重签名（`--resign --sign-identity --provisioning-profile`）

> 注意：二次处理后如果不重签名，IPA 不能用于安装/上架。

## 使用示例

### A. 从源码构建并混淆导出

```bash
./scripts/ipa_obfuscate.sh \
  --scheme MyApp \
  --export-options-plist ./ExportOptions.plist \
  --configuration Release \
  --clean
```

### B. 指定输入 IPA 做二次处理（重打包混淆）

```bash
./scripts/ipa_obfuscate.sh \
  --input-ipa ./MyApp.ipa \
  --output-ipa ./dist/MyApp_obf.ipa \
  --noise-files 16 \
  --noise-size-kb 32
```

### C. 二次处理后重签名（上架必须）

```bash
./scripts/ipa_obfuscate.sh \
  --input-ipa ./MyApp.ipa \
  --output-ipa ./dist/MyApp_obf_signed.ipa \
  --resign \
  --sign-identity "Apple Distribution: Your Company (TEAMID)" \
  --provisioning-profile ./AppStore.mobileprovision
```

默认输出目录：`./build/obfuscated`。
