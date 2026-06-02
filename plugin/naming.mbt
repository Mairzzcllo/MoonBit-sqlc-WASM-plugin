///|
/// Naming Conversion Utilities — P0-057.
/// Provides snake_case ↔ PascalCase/camelCase conversion with initialism support,
/// and case style application for JSON/db tags.
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

/// Capitalize the first ASCII lowercase character.
pub fn capitalize_first(s: String) -> String {
  if s.length() == 0 { return s }
  let first = s[0]
  if first >= 'a' && first <= 'z' {
    let upper = (first.to_int() - 32).unsafe_to_char()
    [upper] + s[1:].to_owned()
  } else {
    s
  }
}

/// Lowercase the first ASCII uppercase character.
pub fn lowercase_first(s: String) -> String {
  if s.length() == 0 { return s }
  let first = s[0]
  if first >= 'A' && first <= 'Z' {
    let lower = (first.to_int() + 32).unsafe_to_char()
    [lower] + s[1:].to_owned()
  } else {
    s
  }
}

/// Parse a comma-separated list of initialisms into an array.
/// e.g., "ID,URL,HTTP" → ["ID", "URL", "HTTP"]
pub fn parse_initialisms(s: String) -> Array[String] {
  if s.length() == 0 { return [] }
  let parts = s.split(",")
  let trimmed = parts.map(fn(p) { p.trim().to_owned() })
  let result: Array[String] = []
  for p in trimmed { if p.length() > 0 { result.push(p) } }
  result
}

/// Check if a word matches any initialism (case-insensitive).
/// Returns the canonical initialism form if found, None otherwise.
fn match_initialism(word: String, initialisms: Array[String]) -> Option[String] {
  let lower = word.to_lower()
  for init in initialisms {
    if init.to_lower() == lower { return Some(init) }
  }
  None
}

/// Convert snake_case to PascalCase with initialism support.
/// e.g., "get_user_by_id" with initialisms=["ID","URL"] → "GetUserByID"
///
/// ## Edge Case Behaviors (ADR-004 / P1-041)
///
/// The conversion is a pure algorithmic mapping with the following known edge cases.
/// These behaviors are intentionally preserved; callers should be aware of:
///
/// | Input           | Output       | Reason                                         |
/// |-----------------|--------------|------------------------------------------------|
/// | `"user__name"`  | `"UserName"` | Double underscore → empty split segment, silently dropped |
/// | `"_user"`       | `"User"`     | Leading underscore → empty first segment, dropped |
/// | `"user_name_"`  | `"UserName"` | Trailing underscore → empty last segment, dropped |
/// | `"USER_NAME"`   | `"USERNAME"` | All-caps input stays uppercase (capitalize_first is no-op on uppercase) |
/// | `"userName"`    | `"UserName"` | No underscore → only first letter capitalized |
/// | `"user_name"`   | `"UserName"` | Same output as `"UserName"` — collision risk |
/// | `"_"`           | `""`         | Single underscore → two empty segments → empty string |
/// | `""`            | `"Empty"`    | Empty input returns sentinel `"Empty"` |
///
/// **Collision warning**: Different snake_case inputs can produce identical
/// PascalCase output (e.g., `"user_name"` and `"UserName"` both → `"UserName"`).
/// The naming layer does not detect or prevent collisions — higher-level
/// codegen (e.g., `generate_types_from_catalog`) is responsible for avoiding
/// conflicts (e.g., enum name vs struct name generating the same type).
///
/// **Enum/Struct collision**: When a table and an enum share the same base name,
/// both generate the same PascalCase type (e.g., `"status"` table → `Status`
/// struct, `"status"` enum → `Status` enum). This is a known limitation tracked
/// in P1-041; future work may add disambiguation suffixes.
///
/// **Empty input**: Callers should ensure non-empty input; empty string returns
/// sentinel `"Empty"` which may collide with tables named 'empty'.
pub fn snake_to_pascal(s: String, initialisms: Array[String]) -> String {
  if s.length() == 0 { return "Empty" }
  let parts = s.split("_")
  let mut result = ""
  for part in parts {
    let word = part.to_owned()
    match match_initialism(word, initialisms) {
      Some(init) => result = result + init
      None => result = result + capitalize_first(word)
    }
  }
  result
}

/// Convert snake_case to camelCase with initialism support.
///
/// Callers should normalize input to lowercase before calling when case is
/// unknown, to avoid mixed-case output like `uSERNAME` from all-caps input.
pub fn snake_to_camel(s: String, initialisms: Array[String]) -> String {
  if s.length() == 0 { return "" }
  let pascal = snake_to_pascal(s, initialisms)
  lowercase_first(pascal)
}

/// Apply a case style to a string.
/// Supported styles: "snake" (no change), "camel", "pascal".
/// For "snake", the input is returned as-is (assumed to already be snake_case).
pub fn apply_case_style(s: String, style: String) -> String {
  match style {
    "snake" => s
    "camel" => snake_to_camel(s, [])
    "pascal" => snake_to_pascal(s, [])
    _ => s
  }
}

// === Tests ===

test "capitalize_first: lowercase letter" {
  inspect(capitalize_first("hello"), content="Hello")
}

test "capitalize_first: already uppercase" {
  inspect(capitalize_first("Hello"), content="Hello")
}

test "capitalize_first: empty string" {
  inspect(capitalize_first(""), content="")
}

test "lowercase_first: uppercase letter" {
  inspect(lowercase_first("Hello"), content="hello")
}

test "lowercase_first: already lowercase" {
  inspect(lowercase_first("hello"), content="hello")
}

test "lowercase_first: empty string" {
  inspect(lowercase_first(""), content="")
}

test "parse_initialisms: empty string returns empty array" {
  let inits = parse_initialisms("")
  inspect(inits.length(), content="0")
}

test "parse_initialisms: single initialism" {
  let inits = parse_initialisms("ID")
  inspect(inits.length(), content="1")
  inspect(inits[0], content="ID")
}

test "parse_initialisms: multiple initialisms" {
  let inits = parse_initialisms("ID,URL,HTTP")
  inspect(inits.length(), content="3")
  inspect(inits[0], content="ID")
  inspect(inits[1], content="URL")
  inspect(inits[2], content="HTTP")
}

test "parse_initialisms: with whitespace" {
  let inits = parse_initialisms(" ID , URL , HTTP ")
  inspect(inits.length(), content="3")
  inspect(inits[0], content="ID")
  inspect(inits[1], content="URL")
}

test "snake_to_pascal: without initialisms same as old behavior" {
  inspect(snake_to_pascal("user_profiles", []), content="UserProfiles")
}

test "snake_to_pascal: with initialisms applies init to matching words" {
  let inits = parse_initialisms("ID,URL,HTTP")
  inspect(snake_to_pascal("get_user_by_id", inits), content="GetUserByID")
}

test "snake_to_pascal: multiple initialisms in one name" {
  let inits = parse_initialisms("API,ID,URL,HTTP")
  inspect(snake_to_pascal("http_api_url", inits), content="HTTPAPIURL")
}

test "snake_to_pascal: initialism in middle of name" {
  let inits = parse_initialisms("ID,URL")
  inspect(snake_to_pascal("user_id_url", inits), content="UserIDURL")
}

test "snake_to_pascal: empty string returns Empty" {
  let inits = parse_initialisms("ID")
  inspect(snake_to_pascal("", inits), content="Empty")
}

test "snake_to_camel: basic conversion" {
  inspect(snake_to_camel("user_profiles", []), content="userProfiles")
}

test "snake_to_camel: with initialisms" {
  let inits = parse_initialisms("ID,URL")
  inspect(snake_to_camel("get_user_by_id", inits), content="getUserByID")
}

test "apply_case_style: snake returns as-is" {
  inspect(apply_case_style("user_id", "snake"), content="user_id")
}

test "apply_case_style: camel conversion" {
  inspect(apply_case_style("user_id", "camel"), content="userId")
}

test "apply_case_style: pascal conversion" {
  inspect(apply_case_style("user_id", "pascal"), content="UserId")
}

test "apply_case_style: unknown style returns as-is" {
  inspect(apply_case_style("user_id", "unknown"), content="user_id")
}

// === P1-041: 命名转换边缘情况测试 (ADR-004) ===

/// P1-041: Double underscore is folded — split produces an empty segment
/// between the two underscores, which is silently dropped.
test "P1-041: double underscore folds to single word boundary" {
  inspect(snake_to_pascal("user__name", []), content="UserName")
}

/// P1-041: Leading underscore produces empty first segment, silently dropped.
/// The result is as if the leading underscore were not present.
test "P1-041: leading underscore is stripped" {
  inspect(snake_to_pascal("_user", []), content="User")
}

/// P1-041: Trailing underscore produces empty last segment, silently dropped.
test "P1-041: trailing underscore is stripped" {
  inspect(snake_to_pascal("user_name_", []), content="UserName")
}

/// P1-041: Leading + trailing underscores both stripped.
test "P1-041: leading and trailing underscores both stripped" {
  inspect(snake_to_pascal("__user__", []), content="User")
}

/// P1-041: ALL CAPS input stays uppercase because capitalize_first is a no-op
/// when the first character is already uppercase. This is intentional —
/// callers should pre-normalize to lowercase before calling if needed.
test "P1-041: all-caps input stays uppercase (no case normalization)" {
  inspect(snake_to_pascal("USER_NAME", []), content="USERNAME")
}

/// P1-041: camelCase input with no underscore only gets the first letter
/// capitalized. No word-boundary detection for case transitions.
test "P1-041: camelCase input only capitalizes first letter" {
  inspect(snake_to_pascal("userName", []), content="UserName")
}

/// P1-041: Collision — two different snake_case inputs produce the same
/// PascalCase output. Callers MUST handle this at the codegen level.
test "P1-041: snake_case and PascalCase input collide to same output" {
  inspect(snake_to_pascal("user_name", []), content="UserName")
  inspect(snake_to_pascal("UserName", []), content="UserName")
}

/// P1-041: Mixed case with underscores — only the first letter of each
/// underscore-separated segment is uppercased.
test "P1-041: mixed case with underscore boundaries" {
  inspect(snake_to_pascal("user_Name", []), content="UserName")
}

/// P1-041: Single underscore input produces empty string (both segments empty).
test "P1-041: single underscore produces empty string" {
  inspect(snake_to_pascal("_", []), content="")
}

/// P1-041: Only underscores produces empty string (all segments empty).
test "P1-041: only underscores produces empty string" {
  inspect(snake_to_pascal("___", []), content="")
}

/// P1-041: Numbers within segments are preserved as-is.
test "P1-041: numbers are preserved in conversion" {
  inspect(snake_to_pascal("user_2_id", []), content="User2Id")
}

/// P1-041: snake_to_camel with same edge cases — camelCase output
test "P1-041: snake_to_camel handles double underscore" {
  inspect(snake_to_camel("user__name", []), content="userName")
}

/// P1-041: snake_to_camel with leading underscore
test "P1-041: snake_to_camel handles leading underscore" {
  inspect(snake_to_camel("_user", []), content="user")
}

/// P1-041: snake_to_camel with all-caps
test "P1-041: snake_to_camel handles all-caps" {
  inspect(snake_to_camel("USER_NAME", []), content="uSERNAME")
}

/// P1-041: snake_to_camel with camelCase input
test "P1-041: snake_to_camel handles camelCase input" {
  inspect(snake_to_camel("userName", []), content="userName")
}

/// P1-041: Collision potential between table name and enum name.
/// If a table is named "status" and an enum is also named "status",
/// both snake_to_pascal to "Status", causing a compile error.
/// This test documents the collision; disambiguation is tracked in P1-041.
test "P1-041: table name and enum name produce same PascalCase (collision)" {
  // Simulating: table "user_status" and enum "user_status" both → "UserStatus"
  let table_pascal = snake_to_pascal("user_status", [])
  let enum_pascal = snake_to_pascal("user_status", [])
  inspect(table_pascal, content="UserStatus")
  inspect(enum_pascal, content="UserStatus")
  inspect(table_pascal == enum_pascal, content="true")
}
