// 生成 charclass_escape_wbtest.mbt：把 test262 CharacterClassEscapes 的
// 期望码点集合（\d \w \s 的正例）嵌入白盒测试，做全码点穷举验证。
// 用完可删（生成器一次性使用，产物 charclass_escape_wbtest.mbt 入库）。

import { readFileSync, writeFileSync } from "node:fs";

const data = JSON.parse(readFileSync("tests/test262/charclass-escapes.json", "utf8"));

function points(cls) {
  const d = data[cls];
  const pts = [];
  for (const p of d.lone) pts.push(p);
  for (const [a, b] of d.ranges) for (let i = a; i <= b; i++) pts.push(i);
  pts.sort((a, b) => a - b);
  return pts;
}

const digit = points("digit");
const word = points("word");
const whitespace = points("whitespace");

function fmtArr(pts) {
  return pts.map((x) => "0x" + x.toString(16).toUpperCase()).join(", ");
}

const out = `// 由 scripts/gen-charclass-escapes.mjs 从 test262 的 CharacterClassEscapes
// 生成的白盒测试数据：\\d \\w \\s 的「应该匹配」码点集合（ECMA-262 固定定义）。
//
// 这里做的是**全码点穷举验证**：对 U+0000..U+10FFFF 的每一个码点，
// 逐一确认引擎的判定与 test262 期望完全一致。因为 \\D \\W \\S 是补集，
// 只要三个正向类的集合正确，反类自动正确。

///|
test "\\\\d matches exactly the 10 ASCII digits (test262)" {
  let expected = [${fmtArr(digit)}]
  verify_exact(is_digit_cp, expected, "\\\\d")
}

///|
test "\\\\w matches exactly the 63 word characters (test262)" {
  let expected = [${fmtArr(word)}]
  verify_exact(is_word_cp, expected, "\\\\w")
}

///|
test "\\\\s matches exactly the 25 whitespace chars (test262)" {
  let expected = [${fmtArr(whitespace)}]
  verify_exact(is_ecma_space, expected, "\\\\s")
}

///|
/// 穷举 U+0000..U+10FFFF，确认 predicate 为 true 的码点集合与 expected 完全一致。
/// 用双指针：遍历全码点的同时推进 expected，任何一个不该命中或漏命中都报错。
fn verify_exact(
  predicate : (Int) -> Bool,
  expected : Array[Int],
  name : String,
) -> Unit {
  let mut ei = 0
  for cp = 0; cp <= 0x10FFFF; cp = cp + 1 {
    let hit = predicate(cp)
    let should = ei < expected.length() && expected[ei] == cp
    if hit != should {
      fail(
        name +
        " mismatch at U+" +
        fmt_hex(cp) +
        ": engine=" +
        hit.to_string() +
        " expected=" +
        should.to_string(),
      )
    }
    if should {
      ei = ei + 1
    }
  }
  // 期望集合里还有没被遍历到的（说明漏匹配了后半段）
  if ei != expected.length() {
    fail(
      name +
      " missed " +
      (expected.length() - ei).to_string() +
      " codepoints",
    )
  }
}

///|
fn fmt_hex(cp : Int) -> String {
  "0123456789ABCDEF"[(cp >> 28) & 0xF].to_string() +
  "0123456789ABCDEF"[(cp >> 24) & 0xF].to_string() +
  "0123456789ABCDEF"[(cp >> 20) & 0xF].to_string() +
  "0123456789ABCDEF"[(cp >> 16) & 0xF].to_string() +
  "0123456789ABCDEF"[(cp >> 12) & 0xF].to_string() +
  "0123456789ABCDEF"[(cp >> 8) & 0xF].to_string() +
  "0123456789ABCDEF"[(cp >> 4) & 0xF].to_string() +
  "0123456789ABCDEF"[cp & 0xF].to_string()
}
`;

writeFileSync("src/regex/charclass_escape_wbtest.mbt", out, "utf8");
console.log(`生成 src/regex/charclass_escape_wbtest.mbt`);
console.log(`  digit: ${digit.length} 码点, word: ${word.length}, whitespace: ${whitespace.length}`);
