# test262 提取数据说明

`data.json` 是从 [test262](https://github.com/tc39/test262)（ECMA-262 官方一致性
测试套件）的 `test/built-ins/RegExp/S15.10.2.x` 用例中提取出来的正则匹配判定
数据集，用于验证本仓库正则引擎（`src/regex`）的 ECMA-262 语义一致性。

## 来源与许可证

- 来源：<https://github.com/tc39/test262>（`test/built-ins/RegExp/S15.10.2.x`）
- 许可证：**BSD**（版权归 Ecma International），完整文本见本目录 `LICENSE`
- test262 用例本身带有各自的版权头（如 Sputnik 作者），随用例一并归属

## 提取方式

由 `scripts/gen-test262.mjs` 从 test262 原始用例中静态提取，输出 `data.json`：

- 提取 `var __executed = /pattern/.test("input")` 的布尔判定（28 条）
- 提取 `var __executed = /pattern/.exec("input")` 的捕获组对比（138 条）
- 只提取「无 flags」的用例（带 `u`/`i`/`m`/`s`/`g`/`y` 标志的跳过，因为本引擎
  不实现 flags）

原始文件缓存在 `raw/`（由 `gen-test262.mjs` 下载，不入库）。重新生成：

```sh
node scripts/gen-test262.mjs   # 需 GH_TOKEN，重新下载并提取
```

## 为什么不直接跑 test262

test262 是给「完整 JS RegExp 对象」设计的一致性套件，包含 flags、`lastIndex`、
构造器等运行时语义。本引擎实现的是「无 flags 的 pattern 匹配语义」子集，因此
只提取适配这一子集的用例，并如实报告 164/166 的通过率（剩余 2 条是嵌套可选组
捕获重置的精细语义，见 README「已知限制」）。

## 复现

```sh
moon run --target js cmd/test262
# test262 (S15.10.2.x, 无 flags 子集): 164/166
```
