// 由 scripts/gen-charclass-escapes.mjs 从 test262 的 CharacterClassEscapes
// 生成的白盒测试数据：\d \w \s 的「应该匹配」码点集合（ECMA-262 固定定义）。
//
// 这里做的是**全码点穷举验证**：对 U+0000..U+10FFFF 的每一个码点，
// 逐一确认引擎的判定与 test262 期望完全一致。因为 \D \W \S 是补集，
// 只要三个正向类的集合正确，反类自动正确。

///|
test "\\d matches exactly the 10 ASCII digits (test262)" {
  let expected = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]
  verify_exact(is_digit_cp, expected, "\\d")
}

///|
test "\\w matches exactly the 63 word characters (test262)" {
  let expected = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43,
    0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50,
    0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5F, 0x61, 0x62,
    0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A,
  ]
  verify_exact(is_word_cp, expected, "\\w")
}

///|
test "\\s matches exactly the 25 whitespace chars (test262)" {
  let expected = [
    0x9, 0xA, 0xB, 0xC, 0xD, 0x20, 0xA0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003,
    0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x2028, 0x2029, 0x202F,
    0x205F, 0x3000, 0xFEFF,
  ]
  verify_exact(is_ecma_space, expected, "\\s")
}

///|
/// 穷举 U+0000..U+10FFFF，确认 predicate 为 true 的码点集合与 expected 完全一致。
/// 用双指针：遍历全码点的同时推进 expected，任何一个不该命中或漏命中都报错。
fn verify_exact(
  predicate : (Int) -> Bool,
  expected : Array[Int],
  name : String,
) -> Unit raise {
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
      name + " missed " + (expected.length() - ei).to_string() + " codepoints",
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
