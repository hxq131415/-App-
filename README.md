## OC + CocoaPods 一键“最大化”混淆并导出 IPA

执行一次脚本即可：

1. `pod install`（可关闭）
2. 扫描项目并生成 `Confusion.h` 宏映射
3. 使用 `-include Confusion.h` 对全量编译单元注入重命名
4. 启用 strip/LTO/dead-strip 等参数归档
5. 导出混淆后的 IPA

> 注意：该方案是**激进混淆**。若你项目存在 Runtime 反射、字符串拼接类名/方法名、`NSSelectorFromString` 等场景，需先在 `INCLUDE_PREFIXES` 和排除策略中做白名单控制。

### 用法

```bash
cp obfuscation.env.example obfuscation.env
# 编辑 obfuscation.env
./obfuscate_and_package.sh obfuscation.env
```

输出目录：

- `build/<Scheme>.xcarchive`
- `build/export/*.ipa`
- `Obfuscation/Confusion.h`

### 让每次二进制都明显不同

- 每次构建使用新 `OBFUSCATION_SEED`
- 在 CI 里用时间戳或 commit hash 作为 seed

示例：

```bash
OBFUSCATION_SEED="$(date +%s)-$(git rev-parse --short HEAD)" ./obfuscate_and_package.sh obfuscation.env
```
