///|
/// MoonBit Keyword Escaping — P0-065.
/// Provides escape_keyword() to prevent generated identifiers from colliding
/// with MoonBit reserved keywords, built-in types, and built-in values.
//
// Copyright 2026 Mairzzcllo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// Escape a MoonBit identifier that conflicts with a reserved keyword, built-in type,
/// or built-in value by appending "_".
///
/// Special case: "type" → "ty" (preserving existing convention from protobuf schema).
///
/// The keyword set includes:
/// - Reserved words: as, async, break, catch, continue, do, else, enum, extern,
///   false, fn, for, if, impl, import, let, loop, match, mut, package, pub,
///   raise, ref, return, struct, test, then, trait, true, try, type, var, while
/// - Additional reserved: self, Self, abort, panic, priv, priv, pure
/// - Built-in types: Int, Int64, Double, String, Bool, Char, Byte, Unit,
///   Float, Array, Map, Option, Result
/// - Built-in values: None, Some, Ok, Err
pub fn escape_keyword(name: String) -> String {
  // Special case: "type" → "ty" (existing convention)
  if name == "type" {
    return "ty"
  }
  
  let keywords: Array[String] = [
    // Reserved words (lowercase)
    "as", "async", "break", "catch", "continue", "do", "else", "enum",
    "extern", "false", "fn", "for", "if", "impl", "import",
    "let", "loop", "match", "mut", "package", "pub", "raise", "ref",
    "return", "struct", "test", "then", "trait", "true", "try",
    "var", "while",
    // Additional reserved identifiers
    "self", "Self",
    // Additional from MoonBit spec
    "abort", "panic", "priv", "pure",
    // Built-in types (prevents shadowing)
    "Int", "Int64", "Double", "String", "Bool", "Char", "Byte",
    "Unit", "Float", "Array", "Map", "Option", "Result",
    // Built-in values/constructors
    "None", "Some", "Ok", "Err",
  ]

  if keywords.contains(name) {
    name + "_"
  } else {
    name
  }
}

// === Tests ===

test "escape_keyword: non-keyword passes through" {
  inspect(escape_keyword("id"), content="id")
  inspect(escape_keyword("name"), content="name")
  inspect(escape_keyword("email"), content="email")
}

test "escape_keyword: type maps to ty (special case)" {
  inspect(escape_keyword("type"), content="ty")
}

test "escape_keyword: reserved word gets underscore suffix" {
  inspect(escape_keyword("fn"), content="fn_")
  inspect(escape_keyword("let"), content="let_")
  inspect(escape_keyword("if"), content="if_")
  inspect(escape_keyword("else"), content="else_")
  inspect(escape_keyword("match"), content="match_")
  inspect(escape_keyword("struct"), content="struct_")
  inspect(escape_keyword("enum"), content="enum_")
  inspect(escape_keyword("trait"), content="trait_")
  inspect(escape_keyword("for"), content="for_")
  inspect(escape_keyword("while"), content="while_")
  inspect(escape_keyword("loop"), content="loop_")
}

test "escape_keyword: boolean literals get underscore suffix" {
  inspect(escape_keyword("true"), content="true_")
  inspect(escape_keyword("false"), content="false_")
}

test "escape_keyword: self and Self get underscore suffix" {
  inspect(escape_keyword("self"), content="self_")
  inspect(escape_keyword("Self"), content="Self_")
}

test "escape_keyword: built-in types get underscore suffix" {
  inspect(escape_keyword("Int"), content="Int_")
  inspect(escape_keyword("Int64"), content="Int64_")
  inspect(escape_keyword("String"), content="String_")
  inspect(escape_keyword("Bool"), content="Bool_")
  inspect(escape_keyword("Array"), content="Array_")
  inspect(escape_keyword("Option"), content="Option_")
  inspect(escape_keyword("Result"), content="Result_")
}

test "escape_keyword: built-in values get underscore suffix" {
  inspect(escape_keyword("None"), content="None_")
  inspect(escape_keyword("Some"), content="Some_")
  inspect(escape_keyword("Ok"), content="Ok_")
  inspect(escape_keyword("Err"), content="Err_")
}

test "escape_keyword: other reserved words" {
  inspect(escape_keyword("pub"), content="pub_")
  inspect(escape_keyword("mut"), content="mut_")
  inspect(escape_keyword("ref"), content="ref_")
  inspect(escape_keyword("var"), content="var_")
  inspect(escape_keyword("async"), content="async_")
  inspect(escape_keyword("try"), content="try_")
  inspect(escape_keyword("catch"), content="catch_")
  inspect(escape_keyword("raise"), content="raise_")
  inspect(escape_keyword("import"), content="import_")
  inspect(escape_keyword("as"), content="as_")
  inspect(escape_keyword("return"), content="return_")
  inspect(escape_keyword("break"), content="break_")
  inspect(escape_keyword("continue"), content="continue_")
  inspect(escape_keyword("test"), content="test_")
  inspect(escape_keyword("impl"), content="impl_")
  inspect(escape_keyword("extern"), content="extern_")
  inspect(escape_keyword("then"), content="then_")
  inspect(escape_keyword("do"), content="do_")
}

test "escape_keyword: non-keyword PascalCase passes through" {
  inspect(escape_keyword("Type"), content="Type")
  inspect(escape_keyword("True"), content="True")
  inspect(escape_keyword("False"), content="False")
  inspect(escape_keyword("Match"), content="Match")
}

test "escape_keyword: empty string passes through (handled by other guards)" {
  inspect(escape_keyword(""), content="")
}

// === P0-065: Missing keyword spot-checks ===

test "escape_keyword: untested reserved word 'package' gets underscore" {
  inspect(escape_keyword("package"), content="package_")
}

test "escape_keyword: untested additional reserved words abort/panic/priv/pure" {
  inspect(escape_keyword("abort"), content="abort_")
  inspect(escape_keyword("panic"), content="panic_")
  inspect(escape_keyword("priv"), content="priv_")
  inspect(escape_keyword("pure"), content="pure_")
}

test "escape_keyword: untested built-in types Double/Char/Byte/Unit/Float/Map" {
  inspect(escape_keyword("Double"), content="Double_")
  inspect(escape_keyword("Char"), content="Char_")
  inspect(escape_keyword("Byte"), content="Byte_")
  inspect(escape_keyword("Unit"), content="Unit_")
  inspect(escape_keyword("Float"), content="Float_")
  inspect(escape_keyword("Map"), content="Map_")
}

// === P0-065: Case sensitivity tests ===

test "escape_keyword: uppercase variants of lowercase keywords pass through" {
  // MoonBit is case-sensitive — only lowercase keywords are reserved
  inspect(escape_keyword("As"), content="As")
  inspect(escape_keyword("Async"), content="Async")
  inspect(escape_keyword("Break"), content="Break")
  inspect(escape_keyword("Catch"), content="Catch")
  inspect(escape_keyword("Continue"), content="Continue")
  inspect(escape_keyword("Do"), content="Do")
  inspect(escape_keyword("Else"), content="Else")
  inspect(escape_keyword("Implements"), content="Implements")
  inspect(escape_keyword("Package"), content="Package")
  inspect(escape_keyword("Return"), content="Return")
  inspect(escape_keyword("Throw"), content="Throw")
}

test "escape_keyword: FN (all caps) passes through since 'fn' is keyword" {
  inspect(escape_keyword("FN"), content="FN")
}

test "escape_keyword: SELF (all caps) passes through since 'Self' is keyword" {
  inspect(escape_keyword("SELF"), content="SELF")
}

// === P0-065: Double-escaping and partial match tests ===

test "escape_keyword: already-escaped names with trailing underscore pass through (no double-escape)" {
  inspect(escape_keyword("fn_"), content="fn_")
  inspect(escape_keyword("let_"), content="let_")
  inspect(escape_keyword("self_"), content="self_")
  inspect(escape_keyword("Self_"), content="Self_")
  inspect(escape_keyword("Int_"), content="Int_")
  inspect(escape_keyword("Array_"), content="Array_")
  inspect(escape_keyword("None_"), content="None_")
  inspect(escape_keyword("Ok_"), content="Ok_")
}

test "escape_keyword: type_ passes through without double-escaping" {
  inspect(escape_keyword("type_"), content="type_")
}

test "escape_keyword: partial keyword matches (e.g. fnord) pass through" {
  inspect(escape_keyword("fnord"), content="fnord")
  inspect(escape_keyword("structuring"), content="structuring")
  inspect(escape_keyword("enumeration"), content="enumeration")
  inspect(escape_keyword("traitor"), content="traitor")
  inspect(escape_keyword("typeof"), content="typeof")
  inspect(escape_keyword("mutable"), content="mutable")
  inspect(escape_keyword("int8"), content="int8")
  inspect(escape_keyword("arraybuffer"), content="arraybuffer")
}

test "escape_keyword: keyword embedded in longer string passes through" {
  // "fn" inside "cfn" should not be escaped
  inspect(escape_keyword("cfn"), content="cfn")
  inspect(escape_keyword("_fn"), content="_fn")
  inspect(escape_keyword("lets"), content="lets")
  inspect(escape_keyword("selfless"), content="selfless")
}
