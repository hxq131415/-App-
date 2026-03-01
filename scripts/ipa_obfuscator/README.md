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

## 怎么调用要混淆的项目？

你有两种调用方式：

### 1) 在目标 iOS 工程仓库内直接调用（最常见）

```bash
bash scripts/ipa_obfuscator/build_obfuscated_ipa.sh \
  -s YourScheme \
  -c Release \
  -t YOUR_TEAM_ID \
  -p ExportOptions.plist
```

### 2) 在“工具仓库”里调用“外部目标工程”（用 `-P`）

```bash
bash scripts/ipa_obfuscator/build_obfuscated_ipa.sh \
  -P /path/to/TargetIOSProject \
  -s YourScheme \
  -c Release \
  -t YOUR_TEAM_ID \
  -p /path/to/TargetIOSProject/ExportOptions.plist \
  -o /path/to/output/dist
```

`-P` 会把该目录作为目标工程根目录：
- 自动在该目录查找 `Podfile` / `.xcworkspace` / `.xcodeproj`
- 在该目录生成 `Obfuscation/Generated/OBFBuildNoise.m`
- 默认扫描该目录源码生成符号扰动

## 参数说明

- `-w`: 指定 `.xcworkspace`
- `-x`: 指定 `.xcodeproj`
- `-r`: 指定源码扫描目录（可多次）
- `-k`: padding 大小（KB）
- `-n`: 构建 tag（默认时间戳）
- `-P`: 指定要混淆的目标工程根目录（默认当前仓库根目录）
- `-m`: 强制给 archive 中所有 bundle id 使用同一个 provisioning profile 名称（导出签名兜底）
- `-A`: 导出/归档时增加 `-allowProvisioningUpdates`（允许 xcodebuild 自动更新签名资源）

## 输出

- 随机 seed
- 链接顺序文件：`.obf_build/link.order`
- 自动生成噪声源码：`Obfuscation/Generated/OBFBuildNoise.m`
- 最终 IPA：`dist/<AppName>-<tag>.ipa`


## 常见报错与正确命令

你给的示例报错 `Invalid option: -P`，通常有两类原因：

1. **执行的不是最新脚本**（旧版本没有 `-P` 参数）。
2. **续行符 `\` 后面有空格**，导致下一行参数没有被拼接到同一条命令。

另外你原命令还有两个问题：
- `-t` 传的是邮箱（`tothhien1998@icloud.com`），但这里需要 **Apple Team ID**（例如 `ABCDE12345`）。
- `-p` 传的是目录结尾 `/`，应传 `ExportOptions.plist` 文件路径。

推荐这样执行：

```bash
bash scripts/ipa_obfuscator/build_obfuscated_ipa.sh \
  -P "/Users/qing2/Downloads/ResumeListProject_测试" \
  -s "ResumeListProject" \
  -c "Release" \
  -t "ABCDE12345" \
  -p "/Users/qing2/Downloads/ResumeListProject_测试/ExportOptions.plist" \
  -o "/Users/qing2/Downloads/ResumeListProject_测试/dist"
```

> 提示：脚本现在也支持 `-p` 直接传目录，会自动尝试拼接 `ExportOptions.plist`。


如果你看到：
- `The following build commands failed: Ld ...`

这只是 Xcode 的汇总提示，不是根因。请看脚本输出的日志路径：
- `.obf_build/obf_pass1.log`
- `.obf_build/obf_pass2.log`
- `.obf_build/obf_export.log`

其中 `obf_pass2.log` 里紧邻 `Ld` 前后的具体报错（如未定义符号、重复符号、链接参数格式错误）才是最终原因。



补充说明：
- 你贴出来的 `IPHONEOS_DEPLOYMENT_TARGET ... warning` 是 **警告**，一般不会直接导致 `ARCHIVE FAILED`。
- 真正失败点通常是后面的 `Ld ... failed`，常见是链接参数被覆盖导致三方库符号丢失。
- 本脚本已改为保留 `$(inherited)`，避免覆盖工程原有 `OTHER_LDFLAGS` / `OTHER_CFLAGS`。

- 若出现 `Undefined symbols ...`（例如 `SVProgressHUD`）且仅在混淆二次归档失败，通常是链接参数被错误覆盖/展开；脚本现已用 `\$(inherited)` 保留原工程链接参数并追加 `order_file`。

可快速检查：
```bash
grep -nE "Undefined symbols|duplicate symbol|ld:|clang: error|error:" .obf_build/obf_pass2.log | head -n 40
```


- 若出现 `error: Couldn't load -exportOptionsPlist ... isn't in the correct format`：
  - 说明 `-p` 指向的文件内容不是合法 plist。
  - 脚本现在会先自动规范化 `ExportOptions.plist`（支持 xml/binary plist，或 JSON 对象自动转 plist）。
  - 若仍失败，请直接改为标准 plist 格式（可用下方最小模板）。

最小可用 `ExportOptions.plist`：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```


- 若出现 `requires a provisioning profile with the iCloud feature`：
  - 这是导出签名能力不匹配：App 启用了 iCloud entitlement，但导出使用的 profile 没有 iCloud 能力。
  - 需要在开发者后台为同一 Bundle ID 重新生成带 iCloud 能力的 profile，并在 Xcode/ExportOptions 里使用该 profile。
- 若出现 `Command line name "development" is deprecated`：
  - Xcode 新版已弃用 `development`，应改为 `debugging`；脚本会自动把该字段规范化。
- 若出现 `No provisioning profile provider found for ... .mobileprovision.Entitlements.plist`：
  - 本地 `~/Library/MobileDevice/Provisioning Profiles` 目录里有异常文件，删除该类 `*.Entitlements.plist` 后重试。


- 如果你确认“profile 本身支持 iCloud”但仍报错：
  - 很可能是 `ExportOptions.plist` 的 `provisioningProfiles` 映射到了错误 profile 名称，或只给主 App 配置了 profile，遗漏了 `.appex` 扩展。
  - 新版脚本会在 export 失败时打印“有效 ExportOptions（method/signingStyle/teamID/provisioningProfiles）”和 archive 中所有 bundle id，方便逐个比对。


当你确认 profile 支持 iCloud，但 `provisioningProfiles mapping: <empty>` 仍失败时，可直接指定 profile 名称：

```bash
bash scripts/ipa_obfuscator/build_obfuscated_ipa.sh \
  -P "/path/to/TargetIOSProject" \
  -s "YourScheme" \
  -c "Release" \
  -t "ABCDE12345" \
  -p "/path/to/ExportOptions.plist" \
  -m "Your iCloud Enabled Profile Name"
```

脚本会自动读取 archive 里的主 App / `.appex` bundle id，并生成 `provisioningProfiles` 映射后再导出。

- 若出现 `Command line name "app-store" is deprecated`：脚本会自动把 `method: app-store` 规范化为 `app-store-connect`。
- 若出现 `No profiles for '<bundle id>' were found`：通常是本地 profile 缓存异常或映射缺失。可先清理 `~/Library/MobileDevice/Provisioning Profiles/*.Entitlements.plist`，再用 `-m "Profile Name"` + `-A` 重试。

- 若出现 `xcodebuild: error: Unknown build action "".`：通常是脚本参数展开传入了空 action；当前版本已修复该问题，请确保使用最新版脚本。


## 改为在 Xcode Run Script 里混淆（推荐你当前场景）

如果你希望“混淆在工程编译时做，IPA 手动导出”，可在 Xcode Target -> Build Phases 新增 **Run Script**，脚本内容：

```bash
bash "$SRCROOT/scripts/ipa_obfuscator/xcode_run_script_obfuscate.sh"
```

可选环境变量：
- `OBF_PADDING_KB`：padding 大小（默认 `64`）
- `OBF_BUILD_SEED`：指定固定 seed（不传则每次自动随机）

该脚本会生成：
- `Obfuscation/Generated/OBFBuildNoise.m`
- `Obfuscation/Generated/link.order`（Run Script 模式下仅占位，可用于后续自定义链接策略）
- `Obfuscation/Generated/.obf_seed`

然后你直接在 Xcode 里 `Archive` / `Distribute App` 手动导出 IPA 即可。
