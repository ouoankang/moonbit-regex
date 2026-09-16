// 生成 src/regex/case_folding.mbt —— ECMA-262 非 Unicode 模式下 `i` 标志
// 的 simple case folding 表。
//
// 规则（ECMA-262 §22.2.2.5.1 Canonicalize，非 Unicode 模式）：
//   canonicalize(ch) = ToUpperCase(ch) 的首个码点（若结果为空则 ch 本身）。
// 两个字符在 `i` 下匹配，当且仅当它们的 canonicalize 结果相同。
//
// 为什么借 Node：ECMA-262 的 case folding 数据藏在引擎里，语言不暴露；
// MoonBit 核心库也没有。这里借 Node 的 toUpperCase 逐码点抽取，压成区间表，
// 编进项目——运行时零依赖。
//
// 输出格式：紧凑区间表。绝大多数码点的 fold key == 自身（无 case 变化），
// 只有约 3000 个码点有非平凡 fold，压成 [lo, hi, fold] 区间（fold == lo 表示
// 该区间码点 fold 到自身，可直接跳过）。
//
// 用法: node scripts/gen-case-folding.mjs

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const MAX_CP = 0x10ffff;

// 对每个有效码点算 fold key：toUpperCase() 的首个码点
function foldKey(cp) {
  const ch = String.fromCodePoint(cp);
  const up = ch.toUpperCase();
  if (up.length === 0) return cp;
  return up.codePointAt(0);
}

// 逐码点收集「fold key != 自身」的映射，压成区间
// 先算出每个码点的 fold key，找连续区间里 fold key 有规律的段
const runs = [];
let runStart = -1, runFold = -1;

for (let cp = 0; cp <= MAX_CP; cp++) {
  if (cp >= 0xd800 && cp <= 0xdfff) {
    // 代理区不是有效码点，跳过（不参与匹配）
    if (runStart !== -1) { runs.push([runStart, cp - 1, runFold]); runStart = -1; }
    continue;
  }
  const fk = foldKey(cp);
  if (fk === cp) {
    // 无 case 变化：不记录（fold 到自身）
    if (runStart !== -1) { runs.push([runStart, cp - 1, runFold]); runStart = -1; }
    continue;
  }
  // 有 case 变化
  if (runStart === -1 || runFold !== fk) {
    if (runStart !== -1) runs.push([runStart, cp - 1, runFold]);
    runStart = cp;
    runFold = fk;
  }
}
if (runStart !== -1) runs.push([runStart, MAX_CP, runFold]);

// 只保留「连续 fold 到同一个 key」的区间（上面已按 runFold 分段）
// 但还要合并相邻的、fold key 相同且码点也连续的情况——上面已经是了

let out = `// 由 scripts/gen-case-folding.mjs 生成：ECMA-262 非 Unicode 模式下
// \`i\` 标志的 simple case folding 表。
//
// 语义：canonicalize(ch) = ToUpperCase(ch) 的首个码点；两个字符在 \`i\` 下
// 匹配当且仅当 canonicalize 结果相同。这张表只记录「fold key != 自身」的
// 码点区间，其余码点 fold 到自身。
//
// 区间 [lo, hi, fold] 表示 lo..hi 的每个码点 canonicalize 到 fold。
// 区间按 lo 升序、无缝，可二分查找。

///|
let case_fold_runs : Array[(Int, Int, Int)] = [
`;

for (const [lo, hi, fold] of runs) {
  out += `  (0x${lo.toString(16)}, 0x${hi.toString(16)}, 0x${fold.toString(16)}),\n`;
}
out += `]

///|
/// 码点的 canonicalize（fold key）。无 case 变化时返回自身。
fn canonicalize_cp(cp : Int) -> Int {
  let runs = case_fold_runs
  let mut lo = 0
  let mut hi = runs.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (rlo, rhi, fold) = runs[mid]
    if cp < rlo {
      hi = mid - 1
    } else if cp > rhi {
      lo = mid + 1
    } else {
      return fold
    }
  }
  cp
}
`;

fs.writeFileSync(path.join(projectRoot, "src/regex/case_folding.mbt"), out, "utf8");
console.log(`生成 case_folding.mbt：${runs.length} 个非平凡 fold 区间`);
console.log(`  覆盖 ${runs.reduce((s, r) => s + (r[1] - r[0] + 1), 0)} 个有 case 变化的码点`);
