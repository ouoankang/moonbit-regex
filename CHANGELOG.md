# Changelog

本项目遵循「一个版本一个可验证的变更」的原则，不设严格语义化版本号——
它还未发布到 mooncakes.io，先按日期记录。

## 2026-09-14 · 重定位为正则引擎，补齐核心能力

项目核心从「JSON Schema 校验器」重定位为「ECMA-262 正则引擎」，校验器降级为
引擎的验证测试床。这是几轮评审打磨后的最终定位——严格 ECMA-262 语义这一层，
是官方 `moonbitlang/regexp` 未承诺、未验证的空白。

### 正则引擎（核心）

- **`exec` 捕获组提取**：返回整体匹配 + 各捕获组 + 位置，对齐 `RegExp.prototype.exec`。
- **`i` 忽略大小写**：ECMA-262 非 Unicode 模式的 simple case folding（`toUpperCase`
  首码点），`case_folding.mbt` 覆盖约 1600 个有大小写的码点（含 é↔É、ß→S 等非 ASCII）。
- **`m` 多行**：`^`/`$` 匹配行首/行尾。
- **`s` dotall**：`.` 匹配行终止符。
- **捕获组回溯修复**：量词「匹配 0 次」重置内部组；前瞻内部捕获组的前瞻结束回滚
  （正向前瞻成功保留、否定前瞻成功恢复，ECMA-262 §22.2.2.9）。

### 一致性证据

| 指标 | 结果 |
| --- | --- |
| test262（S15.10.2.x，i/m/s 子集） | **178 / 178（100.0%）** |
| `\d`/`\w`/`\s` 穷举验证 | U+0000..U+10FFFF 全码点与 test262 一致 |
| `i` case folding 穷举 | 全码点与 Node `toUpperCase` 一致（0 不一致） |
| 官方一致性套件 · 必测 | 1301 / 1301（100.0%，校验器测试床） |
| 单元测试 | 82 / 82（wasm + js） |
| `moon check --target all` | 0 警告 0 错误 |

### 工程化

- 整仓构建通过：4 个 cmd 声明 `supported_targets = "js"`，native 构建只编译纯
  MoonBit 的 `src` 库，不再需要 C 编译器。
- test262 归属补齐：`tests/test262/LICENSE`（BSD）、`README.md`（来源/提取说明）。
- CI 覆盖 test262 一致性 + `--target all` 类型检查。

## 2026-09-12 · 初版

首个完整版本，JSON Schema draft 2020-12 校验器从零实现（必测 1301/1301）。
含自研 ECMA-262 正则引擎（`\d`/`\w` 严格 ASCII、按码点匹配）、9 份官方元 schema
自校验、CLI 与浏览器试用页、`format` 断言（15 个格式）。
