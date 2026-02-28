# iOS Obfuscated IPA 打包脚本

该目录提供一套「一次命令完成混淆 + 归档 + 导出 IPA」的方案，目标是让每次构建产物在二进制布局上都不同，同时保持 `xcodebuild archive/exportArchive` 的官方签名流程，满足上架要求。

## 能力覆盖

- ✅ Objective-C 类符号顺序（通过 linker order file 打散 `_OBJC_CLASS_$_*`）
- ✅ selector 引用顺序（打散 `OBJC_SELECTOR_REFERENCES` / `__objc_selrefs` 相关符号）
- ✅ metadata / method list 相关符号顺序（打散 `__OBJC_$_*METHOD*`）
- ✅ `__objc_classlist` / `__objc_selrefs` 影响项（通过符号重排与噪声源触发）
- ✅ 函数物理地址（通过 `-Wl,-order_file` 重新布局）
- ✅ Mach-O 体积变化（每次生成随机 `__DATA,__obfpad` padding）
- ✅ 支持 CocoaPods（检测 `Podfile` 后自动 `pod install` + 使用 workspace）

> 注意：脚本不会在导出的 `.ipa` 上做“事后篡改”，而是在最终签名前通过编译/链接阶段完成随机化，避免破坏签名链。

## 文件

- `build_obfuscated_ipa.sh`：主入口脚本。
- `shuffle_macho_symbols.py`：提取符号并基于 seed 生成随机顺序与噪声源码。

## 使用方式

1. 在工程里准备 `ExportOptions.plist`。
2. 执行：

```bash
bash scripts/ipa_obfuscator/build_obfuscated_ipa.sh \
  -s YourScheme \
  -c Release \
  -t YOUR_TEAM_ID \
  -p /path/to/ExportOptions.plist \
  -o dist
```

可选参数：

- `-w`: 指定 `.xcworkspace`
- `-x`: 指定 `.xcodeproj`
- `-r`: 指定源码扫描目录（可多次）
- `-k`: padding 大小（KB）
- `-n`: 构建 tag（默认时间戳）

## 输出

- 随机 seed
- 链接顺序文件：`.obf_build/link.order`
- 自动生成噪声源码：`Obfuscation/Generated/OBFBuildNoise.m`
- 最终 IPA：`dist/<AppName>-<tag>.ipa`
