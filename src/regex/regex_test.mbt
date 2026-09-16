// 正则引擎的单元测试。
//
// 覆盖重点放在「和 ECMA-262 语义容易产生分歧」的地方：
// ASCII-only 的 `\d`/`\w`、按码点匹配、空匹配、回溯后的捕获回滚。

///|
test "literal and anchors" {
  let re = Regex::compile("^abc$")
  if !re.find("abc") {
    fail("abc should match ^abc$")
  }
  if re.find("xabc") {
    fail("xabc should not match ^abc$")
  }
  // 未锚定时是「搜索」而不是「整串匹配」
  let loose = Regex::compile("abc")
  if !loose.find("xxabcxx") {
    fail("unanchored search should look inside the string")
  }
}

///|
test "quantifiers" {
  if !Regex::compile("^a*$").find("") {
    fail("a* matches empty")
  }
  if !Regex::compile("^a*$").find("aaa") {
    fail("a* matches aaa")
  }
  if !Regex::compile("^a+$").find("aaa") {
    fail("a+ matches aaa")
  }
  if Regex::compile("^a+$").find("") {
    fail("a+ does not match empty")
  }
  if !Regex::compile("[0-9]{2,}").find("x123") {
    fail("{2,} should match three digits")
  }
  if Regex::compile("[0-9]{2,}").find("x1") {
    fail("{2,} should not match one digit")
  }
}

///|
test "dot does not match line terminators" {
  if !Regex::compile("f.o").find("foo") {
    fail("f.o matches foo")
  }
  if Regex::compile("^a.b$").find("a\nb") {
    fail(". must not match a line feed")
  }
}

///|
test "ascii-only shorthand classes" {
  // 关键分歧点：ECMA-262 的 \d 只认 ASCII，不能拿 Unicode 数字顶替
  if !Regex::compile("^\\d$").find("5") {
    fail("\\d matches an ASCII digit")
  }
  if Regex::compile("^\\d$").find("৪") {
    fail("\\d must not match a non-ASCII digit")
  }
  if !Regex::compile("^\\D$").find("৪") {
    fail("\\D matches a non-ASCII digit")
  }
  if !Regex::compile("^\\w$").find("_") {
    fail("\\w includes underscore")
  }
  if Regex::compile("^\\w$").find("π") {
    fail("\\w is ASCII-only")
  }
  if !Regex::compile("^\\s$").find(" ") {
    fail("\\s matches a space")
  }
  if !Regex::compile("^\\s$").find("\t") {
    fail("\\s matches a tab")
  }
}

///|
test "unicode property escapes" {
  // 官方套件里的 `\p{Letter}` / `\p{digit}`：这才是「按 Unicode 算」的入口
  if !Regex::compile("^\\p{Letter}+$").find("π") {
    fail("\\p{Letter} matches a Greek letter")
  }
  if Regex::compile("^\\p{Letter}+$").find("123") {
    fail("\\p{Letter} must not match digits")
  }
  if !Regex::compile("^\\p{Letter}+$").find("abcXYZ") {
    fail("\\p{Letter} matches ASCII letters")
  }
  if !Regex::compile("^\\p{digit}+$").find("৪২") {
    fail("\\p{digit} matches Bengali digits")
  }
  if Regex::compile("^\\p{digit}+$").find("-%#") {
    fail("\\p{digit} must not match punctuation")
  }
  if !Regex::compile("^\\P{Letter}$").find("7") {
    fail("\\P{Letter} is the negation")
  }
}

///|
test "code point matching for astral characters" {
  // 🐲 是一个码点（U+1F432），不是两个 UTF-16 码元；
  // 若按码元匹配，`^🐲*$` 会退化成一堆乱配。
  let re = Regex::compile("^🐲*$")
  if !re.find("") {
    fail("matches empty")
  }
  if !re.find("🐲") {
    fail("matches one dragon")
  }
  if !re.find("🐲🐲") {
    fail("matches two dragons")
  }
  if re.find("🐉") {
    fail("a different dragon must not match")
  }
  if re.find("DD") {
    fail("ASCII must not match")
  }
}

///|
test "alternation and groups" {
  if !Regex::compile("^(cat|dog)$").find("dog") {
    fail("alternation picks the second branch")
  }
  if Regex::compile("^(cat|dog)$").find("cow") {
    fail("alternation rejects")
  }
  // 非捕获组
  if !Regex::compile("^(?:ab)+$").find("abab") {
    fail("non-capturing group repeats")
  }
}

///|
test "backreferences" {
  if !Regex::compile("^(a+)\\1$").find("aaaa") {
    fail("backreference repeats the captured text")
  }
  if Regex::compile("^(a+)\\1$").find("aaa") {
    fail("aaa is not a doubled prefix")
  }
  // 命名组 + 命名反向引用
  if !Regex::compile("^(?<n>ab)\\k<n>$").find("abab") {
    fail("named backreference")
  }
}

///|
test "lookaround" {
  if !Regex::compile("foo(?=bar)").find("foobar") {
    fail("positive lookahead")
  }
  if Regex::compile("foo(?=bar)").find("foobaz") {
    fail("positive lookahead rejects")
  }
  if !Regex::compile("foo(?!bar)").find("foobaz") {
    fail("negative lookahead")
  }
  if !Regex::compile("(?<=a)b").find("ab") {
    fail("positive lookbehind")
  }
  if Regex::compile("(?<=a)b").find("cb") {
    fail("positive lookbehind rejects")
  }
}

///|
test "character classes" {
  if !Regex::compile("^[a-z]+$").find("hello") {
    fail("range in class")
  }
  if Regex::compile("^[a-z]+$").find("Hello") {
    fail("range is case sensitive")
  }
  if !Regex::compile("^[^a-z]+$").find("123") {
    fail("negated class")
  }
  if !Regex::compile("^[\\d]+$").find("123") {
    fail("shorthand inside class")
  }
  if !Regex::compile("^[\\p{Letter}]+$").find("π") {
    fail("property escape inside class")
  }
  // ECMAScript 特例：空类什么都不匹配，取反后什么都匹配
  if Regex::compile("^[]$").find("a") {
    fail("empty class matches nothing")
  }
  if !Regex::compile("^[^]$").find("a") {
    fail("negated empty class matches everything")
  }
}

///|
test "escapes" {
  if !Regex::compile("^\\t$").find("\t") {
    fail("\\t")
  }
  if !Regex::compile("^\\x41$").find("A") {
    fail("\\xHH")
  }
  if !Regex::compile("^\\u0041$").find("A") {
    fail("\\uHHHH")
  }
  if !Regex::compile("^\\u{1F432}$").find("🐲") {
    fail("\\u{...} code point escape")
  }
  if !Regex::compile("^\\cC$").find("\u{3}") {
    fail("\\cX control escape")
  }
  if !Regex::compile("^\\a$").find("a") {
    fail("identity escape \\a is just 'a'")
  }
}

///|
test "word boundaries" {
  if !Regex::compile("\\bfoo\\b").find("a foo b") {
    fail("\\b finds a whole word")
  }
  if Regex::compile("\\bfoo\\b").find("afoob") {
    fail("\\b must not match inside a word")
  }
  if !Regex::compile("\\Bfoo").find("afoob") {
    fail("\\B is the negation")
  }
}

///|
test "lazy quantifiers" {
  // 懒惰不等于「可以省略」：`+?` 仍然要求至少一个字符。
  if Regex::compile("^<.+?>$").find("<>") {
    fail("lazy + still requires at least one character")
  }
  if !Regex::compile("^<.+?>$").find("<a>") {
    fail("lazy + matches once there is one character")
  }
  // 懒惰量词必须愿意回溯：`a+?` 先只吃一个 a，被 `b` 挡住后再多吃。
  if !Regex::compile("^a+?b$").find("aab") {
    fail("lazy + backtracks to let b match")
  }
}

///|
test "syntax validation" {
  // 合法
  for
    pattern in [
      "(?<=a+)b", "(?<n>a)\\k<n>", "(?<name>x)", "([abc])+\\s+$", "[]", "[^]", "\\a",
      "\\cA", "a{2,3}", "a{2,}", "(?:x)",
    ] {
    if !Regex::is_valid(pattern) {
      fail("should be valid: " + pattern)
    }
  }
  // 非法
  for
    pattern in [
      "^(abc]", "(?#comment)a", "(?P<n>a)(?P=n)", "(?i)abc", "(?ims)abc", "a{3,1}",
      "\\p{NoSuchProperty}", "[z-a]",
    ] {
    if Regex::is_valid(pattern) {
      fail("should be invalid: " + pattern)
    }
  }
}

///|
test "exec returns captures and index" {
  // 整体匹配 + 多个捕获组 + 未参与组
  let m = match Regex::compile("(a+)(b)?c").exec("xxaac") {
    Some(x) => x
    None => {
      fail("should match")
      return
    }
  }
  assert_eq(m.matched, "aac")
  assert_eq(m.index, 2)
  assert_eq(m.captures.length(), 3)
  assert_eq(m.captures[0], Some("aac"))
  assert_eq(m.captures[1], Some("aa"))
  assert_eq(m.captures[2], None) // (b)? 未参与
}

///|
test "exec no match returns None" {
  let r = Regex::compile("^\\d+$")
  assert_true(r.exec("abc") is None)
}

///|
test "exec named group and lookahead capture" {
  // 对应 test262 S15.10.2.8_A1_T1: /(?=(a+))/.exec("baaabac") => ["", "aaa"], index 1
  let m = match Regex::compile("(?=(a+))").exec("baaabac") {
    Some(x) => x
    None => {
      fail("should match")
      return
    }
  }
  assert_eq(m.matched, "")
  assert_eq(m.index, 1)
  assert_eq(m.captures[1], Some("aaa"))
}

///|
test "exec captures astral (code point) correctly" {
  // emoji 按码点计，捕获组切出的内容也按码点
  let m = match Regex::compile("(🐲)(x)").exec("a🐲xb") {
    Some(x) => x
    None => {
      fail("should match")
      return
    }
  }
  assert_eq(m.index, 1)
  assert_eq(m.captures[1], Some("🐲"))
  assert_eq(m.captures[2], Some("x"))
}

///|
test "backtracking empty-match backreference" {
  // (a*) 匹配空串，\1+ 引用空串仍应成功（test262 S15.10.2.9_A1_T5）
  let m = match Regex::compile("(a*)b\\1+").exec("baaaac") {
    Some(x) => x
    None => {
      fail("无匹配")
      return
    }
  }
  assert_eq(m.matched, "b")
  assert_eq(m.captures[1], Some(""))
}

///|
test "alternation with negative lookahead" {
  // (\.(?!com|org)|\/) 分支 + 否定前瞻（test262 S15.10.2.8_A2_T6）
  let m = match Regex::compile("(\\.(?!com|org)|\\/)").exec("ah.info") {
    Some(x) => x
    None => {
      fail("无匹配")
      return
    }
  }
  assert_eq(m.matched, ".")
  assert_eq(m.index, 2)
  assert_eq(m.captures[1], Some("."))
}

///|
test "ignore-case flag: ASCII literal" {
  let re = Regex::compile_with_flags("abc", "i")
  if !re.find("ABC") {
    fail("i flag should match abc against ABC")
  }
  if !re.find("AbC") {
    fail("i flag should match abc against AbC")
  }
  // 无 i 时不应匹配
  let exact = Regex::compile("abc")
  if exact.find("ABC") {
    fail("without i, abc should not match ABC")
  }
}

///|
test "ignore-case flag: character class" {
  let re = Regex::compile_with_flags("^[a-z]+$", "i")
  if !re.matches_whole("HeLLo") {
    fail("i flag should make [a-z] match uppercase")
  }
  if re.matches_whole("123") {
    fail("[a-z] should not match digits")
  }
}

///|
test "ignore-case flag: unicode simple case folding" {
  // é (U+00E9) 和 É (U+00C9) 应互相匹配
  let re = Regex::compile_with_flags("café", "i")
  if !re.find("CAFÉ") {
    fail("i should fold é <-> É")
  }
  // ß (U+00DF) canonicalize 到 S，应和 s/S 匹配（ECMA-262 非 unicode 模式）
  let sharp_s = Regex::compile_with_flags("^ß$", "i")
  if !sharp_s.matches_whole("s") {
    fail("i should fold ß to S (matching s)")
  }
  if !sharp_s.matches_whole("S") {
    fail("i should fold ß to S (matching S)")
  }
}

///|
test "unsupported flag raises" {
  let raised = try {
    let _ = Regex::compile_with_flags("abc", "u")
    false
  } catch {
    _ => true
  }
  if !raised {
    fail("u flag should raise (unsupported)")
  }
}

///|
test "ignore-case flag: backreference folds too" {
  // (a)\1 在 i 下应匹配 aA（反向引用也忽略大小写）
  let re = Regex::compile_with_flags("^(a)\\1$", "i")
  if !re.matches_whole("aA") {
    fail("i should make backreference case-insensitive")
  }
  let exact = Regex::compile("^(a)\\1$")
  if exact.matches_whole("aA") {
    fail("without i, backreference should be case-sensitive")
  }
}

///|
test "quantifier iteration resets unparticipated groups" {
  // test262 S15.10.2.5_A1_T4：嵌套可选组在 * 的最后一次迭代里未参与，
  // 其捕获应为 undefined，而不是残留上一次迭代的值。
  let m = match Regex::compile("(z)((a+)?(b+)?(c))*").exec("zaacbbbcac") {
    Some(x) => x
    None => {
      fail("no match")
      return
    }
  }
  assert_eq(m.matched, "zaacbbbcac")
  assert_eq(m.captures[1], Some("z"))
  assert_eq(m.captures[2], Some("ac"))
  assert_eq(m.captures[3], Some("a"))
  assert_eq(m.captures[4], None) // (b+)? 最后一次迭代未参与
  assert_eq(m.captures[5], Some("c"))
}

///|
test "negative lookahead restores inner captures" {
  // test262 S15.10.2.8_A2_T1：否定前瞻 (?!...) 成功时，内部 (a+) 的捕获
  // 要恢复为未参与，前瞻外的 \2 才能按空串处理。
  let m = match Regex::compile("(.*?)a(?!(a+)b\\2c)\\2(.*)").exec("baaabaac") {
    Some(x) => x
    None => {
      fail("no match")
      return
    }
  }
  assert_eq(m.matched, "baaabaac")
  assert_eq(m.index, 0)
  assert_eq(m.captures[1], Some("ba"))
  assert_eq(m.captures[2], None) // 前瞻内的 (a+) 未参与
  assert_eq(m.captures[3], Some("abaac"))
}

///|
test "positive lookahead keeps inner captures" {
  // 正向前瞻 (?=...) 成功时，内部捕获要保留（可被前瞻外反向引用使用）。
  // test262 S15.10.2.8_A1_T1: /(?=(a+))/.exec("baaabac") => ["", "aaa"]
  let m = match Regex::compile("(?=(a+))").exec("baaabac") {
    Some(x) => x
    None => {
      fail("no match")
      return
    }
  }
  assert_eq(m.matched, "")
  assert_eq(m.index, 1)
  assert_eq(m.captures[1], Some("aaa"))
}

///|
test "lookbehind captures (test262 lookBehind/captures.js)" {
  // 后瞻内的捕获组正确记录（期望来自 test262，Node 验证）
  let m1 = match Regex::compile("(?<=(c))def").exec("abcdef") {
    Some(x) => x
    None => {
      fail("no match #1")
      return
    }
  }
  assert_eq(m1.matched, "def")
  assert_eq(m1.captures[1], Some("c"))

  let m2 = match Regex::compile("(?<=(\\w{2}))def").exec("abcdef") {
    Some(x) => x
    None => {
      fail("no match #2")
      return
    }
  }
  assert_eq(m2.captures[1], Some("bc"))

  // 嵌套后瞻捕获
  let m3 = match Regex::compile("(?<=(\\w(\\w)))def").exec("abcdef") {
    Some(x) => x
    None => {
      fail("no match #3")
      return
    }
  }
  assert_eq(m3.captures[1], Some("bc"))
  assert_eq(m3.captures[2], Some("c"))

  // 分支后瞻：未选中的分支组为未参与
  let m5 = match Regex::compile("(?<=(bc)|(cd)).").exec("abcdef") {
    Some(x) => x
    None => {
      fail("no match #5")
      return
    }
  }
  assert_eq(m5.matched, "d")
  assert_eq(m5.captures[1], Some("bc"))
  assert_eq(m5.captures[2], None)

  // 后瞻在模式中间 + 后续捕获组
  let m7 = match Regex::compile("\\D(?<=([ab]+))(\\w)").exec("abcdef") {
    Some(x) => x
    None => {
      fail("no match #7")
      return
    }
  }
  assert_eq(m7.matched, "ab")
  assert_eq(m7.captures[1], Some("a"))
  assert_eq(m7.captures[2], Some("b"))
}

///|
test "multiline flag: anchors match line boundaries" {
  // m 下 ^ 匹配行首，$ 匹配行尾
  let m = Regex::compile_with_flags("^a", "m")
  if !m.find("b\na") {
    fail("m: ^a should match line-start a")
  }
  let m2 = Regex::compile_with_flags("a$", "m")
  if !m2.find("a\nb") {
    fail("m: a$ should match line-end a")
  }
  // 无 m 时 ^ 不匹配内部行首
  let no_m = Regex::compile("^a")
  if no_m.find("b\na") {
    fail("without m, ^a should not match inner a")
  }
}

///|
test "dotall flag: dot matches line terminators" {
  let s = Regex::compile_with_flags("a.b", "s")
  if !s.find("a\nb") {
    fail("s: a.b should match a\\nb")
  }
  let no_s = Regex::compile("a.b")
  if no_s.find("a\nb") {
    fail("without s, a.b should not match a\\nb")
  }
}

///|
test "combined flags ims" {
  let re = Regex::compile_with_flags("^a.b$", "ims")
  if !re.find("A\nB") {
    fail("ims: ^a.b$ should match A\\nB (case-insensitive + dotall)")
  }
  // m 让 ^...$ 匹配单行
  let line = Regex::compile_with_flags("^x$", "m")
  if !line.find("y\nx\nz") {
    fail("m: ^x$ should match the middle line")
  }
}
