///|
/// Pretty Printer / Emitter — P0-006.
/// Converts MoonBit AST (P0-005) into formatted source code.
/// Pure mechanical transformation — no sqlc/IR/database semantics.
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

struct Emitter {
  buf: Array[String]
}

fn Emitter::new() -> Emitter {
  { buf: [] }
}

fn Emitter::push(self: Emitter, s: String) -> Unit {
  self.buf.push(s)
}

fn push_indent(em: Emitter, indent: Int) -> Unit {
  let mut i = 0
  while i < indent {
    em.push("  ")
    i = i + 1
  }
}

fn push_line(em: Emitter, indent: Int, s: String) -> Unit {
  push_indent(em, indent)
  em.push(s)
  em.push("\n")
}

fn Emitter::finish(self: Emitter) -> String {
  let mut result = ""
  for s in self.buf {
    result = result + s
  }
  result
}

/// Emit a package declaration line if package_name is non-empty.
pub fn emit_package_declaration(name: String) -> String {
  if name.length() > 0 {
    "package " + name + "\n\n"
  } else {
    ""
  }
}

/// Emit a SourceFile to a formatted MoonBit source string.
pub fn emit_source_file(file: SourceFile) -> String {
  let em = Emitter::new()
  let mut first = true
  for item in file.items {
    if !first { em.push("\n") }
    emit_top_level(em, 0, item)
    first = false
  }
  em.finish()
}

fn emit_top_level(em: Emitter, indent: Int, item: TopLevel) -> Unit {
  match item {
    Import(i) => emit_import(em, indent, i)
    Struct(s) => emit_struct_def(em, indent, s)
    Enum(e) => emit_enum_def(em, indent, e)
    Fn(f) => emit_fn_def(em, indent, f)
    TypeAlias(t) => emit_type_alias(em, indent, t)
  }
}

fn emit_doc_comment(em: Emitter, indent: Int, doc: Option[String]) -> Unit {
  match doc {
    Some(text) => {
      for line in text.split("\n") {
        push_line(em, indent, "/// " + line.to_owned())
      }
    }
    None => ()
  }
}

fn emit_import(em: Emitter, indent: Int, i: ImportDef) -> Unit {
  let mut s = "import \"" + i.path + "\""
  match i.import_alias {
    Some(a) => s = s + " @" + a
    None => ()
  }
  push_line(em, indent, s)
}

fn emit_struct_def(em: Emitter, indent: Int, s: StructDef) -> Unit {
  emit_doc_comment(em, indent, s.doc)
  let mut header = ""
  if s.is_pub { header = "pub " }
  header = header + "struct " + s.name
  if s.fields.length() == 0 {
    push_line(em, indent, header)
    return
  }
  push_line(em, indent, header + " {")
  for f in s.fields {
    emit_field_def(em, indent + 1, f)
  }
  push_line(em, indent, "}")
}

fn emit_field_def(em: Emitter, indent: Int, f: FieldDef) -> Unit {
  emit_doc_comment(em, indent, f.doc)
  push_indent(em, indent)
  // Emit @json.tag("name") annotation before field name
  match f.json_tag {
    Some(tag) => { em.push("@json.tag(\"" + escape_string(tag) + "\") ") }
    None => ()
  }
  // Emit @db.tag("name") annotation before field name
  match f.db_tag {
    Some(tag) => { em.push("@db.tag(\"" + escape_string(tag) + "\") ") }
    None => ()
  }
  em.push(f.name)
  em.push(": ")
  em.push(emit_type_expr(f.ty))
  em.push("\n")
}

fn emit_enum_def(em: Emitter, indent: Int, e: EnumDef) -> Unit {
  emit_doc_comment(em, indent, e.doc)
  let mut header = ""
  if e.is_pub { header = "pub " }
  header = header + "enum " + e.name
  if e.variants.length() == 0 {
    push_line(em, indent, header)
    return
  }
  push_line(em, indent, header + " {")
  for v in e.variants {
    emit_variant_def(em, indent + 1, v)
  }
  push_line(em, indent, "}")
}

fn emit_variant_def(em: Emitter, indent: Int, v: VariantDef) -> Unit {
  emit_doc_comment(em, indent, v.doc)
  push_line(em, indent, v.name)
}

fn emit_fn_def(em: Emitter, indent: Int, f: FnDef) -> Unit {
  emit_doc_comment(em, indent, f.doc)
  let mut header = ""
  if f.is_pub { header = "pub " }
  header = header + "fn " + f.name + "("
  let mut first = true
  for p in f.params {
    if !first { header = header + ", " }
    header = header + p.name + ": " + emit_type_expr(p.ty)
    first = false
  }
  header = header + ")"
  let ret = emit_type_expr(f.return_ty)
  if ret != "Unit" {
    header = header + " -> " + ret
  }
  if f.body.length() == 0 {
    push_line(em, indent, header)
    return
  }
  push_line(em, indent, header + " {")
  for expr in f.body {
    emit_expr(em, indent + 1, expr)
  }
  push_line(em, indent, "}")
}

fn emit_type_alias(em: Emitter, indent: Int, t: TypeAliasDef) -> Unit {
  emit_doc_comment(em, indent, t.doc)
  push_line(em, indent, "type " + t.name + " = " + emit_type_expr(t.underlying))
}

fn emit_type_expr(t: TypeExpr) -> String {
  match t {
    Named(s) => s
    Parameterized(name, args) => {
      let mut s = name + "["
      let mut first = true
      for a in args {
        if !first { s = s + ", " }
        s = s + emit_type_expr(a)
        first = false
      }
      s + "]"
    }
    Option(inner) => "Option[" + emit_type_expr(inner) + "]"
    Wildcard => "_"
  }
}

/// Escape special characters in string literals for MoonBit source output.
fn escape_string(s: String) -> String {
  let mut result = ""
  let mut i = 0
  while i < s.length() {
    let ch = s[i]
    if ch == '"' {
      result = result + "\\\""
    } else if ch == '\n' {
      result = result + "\\n"
    } else if ch == '\t' {
      result = result + "\\t"
    } else if ch == '\r' {
      result = result + "\\r"
    } else if ch == '\\' {
      result = result + "\\\\"
    } else if ch == '$' {
      result = result + "\\$"
    } else {
      result = result + s[i : i + 1].to_owned()
    }
    i = i + 1
  }
  result
}

/// Emit arms of a match expression.
/// Nested match bodies are emitted inline to keep formatting compact.
/// Block bodies are emitted with full multi-line formatting.
fn emit_match_arms(em: Emitter, arm_indent: Int, body_indent: Int, arms: Array[(String, Expr)]) -> Unit {
  let mut i = 0
  while i < arms.length() {
    let arm = arms[i]
    let pattern = arm.0
    let body = arm.1
    push_indent(em, arm_indent)
    match body {
      Match(_, _) => {
        em.push(pattern + " => ")
        emit_match_inline(em, body_indent, body)
        em.push("\n")
      }
      Block(exprs) => {
        em.push(pattern + " => {\n")
        for e in exprs {
          emit_expr(em, body_indent + 1, e)
        }
        push_indent(em, body_indent)
        em.push("}\n")
      }
      _ => {
        em.push(pattern + " => " + expr_to_string(body) + "\n")
      }
    }
    i = i + 1
  }
}

/// Emit a match expression inline (no leading newline/indent).
/// Used for nested match arms to keep compact formatting.
fn emit_match_inline(em: Emitter, indent: Int, m: Expr) -> Unit {
  match m {
    Match(scrutinee, arms) => {
      em.push("match " + expr_to_string(scrutinee) + " {\n")
      emit_match_arms(em, indent + 1, indent + 1, arms)
      push_indent(em, indent)
      em.push("}")
    }
    _ => em.push(expr_to_string(m))
  }
}

fn emit_expr(em: Emitter, indent: Int, expr: Expr) -> Unit {
  match expr {
    Ident(s) => push_line(em, indent, s)
    Call(name, args) => {
      let mut s = name + "("
      let mut first = true
      for a in args {
        if !first { s = s + ", " }
        s = s + expr_to_string(a)
        first = false
      }
      s = s + ")"
      push_line(em, indent, s)
    }
    Let(name, val) => {
      push_indent(em, indent)
      em.push("let " + name + " = " + expr_to_string(val) + "\n")
    }
    StrLit(s) => push_line(em, indent, "\"" + escape_string(s) + "\"")
    IntLit(n) => push_line(em, indent, n.to_string())
    ArrLit(args) => {
      let mut s = "["
      let mut first = true
      for a in args {
        if !first { s = s + ", " }
        s = s + expr_to_string(a)
        first = false
      }
      s = s + "]"
      push_line(em, indent, s)
    }
    Index(target, idx) => push_line(em, indent, expr_to_string(target) + "[" + expr_to_string(idx) + "]")
    Lambda(params, body) => {
      let mut s = "fn("
      let mut first = true
      for p in params {
        if !first { s = s + ", " }
        s = s + p.name + ": " + emit_type_expr(p.ty)
        first = false
      }
      s = s + ") { " + expr_to_string(body) + " }"
      push_line(em, indent, s)
    }
    BinOp(op, left, right) => push_line(em, indent, expr_to_string(left) + " " + op + " " + expr_to_string(right))
    If(cond, then_expr, else_expr) => {
      push_indent(em, indent)
      em.push("if " + expr_to_string(cond) + " {\n")
      emit_expr(em, indent + 1, then_expr)
      push_indent(em, indent)
      em.push("} else {\n")
      emit_expr(em, indent + 1, else_expr)
      push_indent(em, indent)
      em.push("}\n")
    }
    Return(val) => {
      push_line(em, indent, "return " + expr_to_string(val))
    }
    ForLoop(varname, iter, body) => {
      push_indent(em, indent)
      em.push("for " + varname + " in " + expr_to_string(iter) + " {\n")
      for stmt in body {
        emit_expr(em, indent + 1, stmt)
      }
      push_indent(em, indent)
      em.push("}\n")
    }
    Match(scrutinee, arms) => {
      push_indent(em, indent)
      em.push("match " + expr_to_string(scrutinee) + " {\n")
      emit_match_arms(em, indent + 1, indent + 1, arms)
      push_indent(em, indent)
      em.push("}\n")
    }
    Unit => push_line(em, indent, "()")
    Block(exprs) => {
      push_line(em, indent, "{")
      for e in exprs {
        emit_expr(em, indent + 1, e)
      }
      push_line(em, indent, "}")
    }
  }
}

fn expr_to_string(e: Expr) -> String {
  match e {
    Ident(s) => s
    Call(name, args) => {
      let mut s = name + "("
      let mut first = true
      for a in args {
        if !first { s = s + ", " }
        s = s + expr_to_string(a)
        first = false
      }
      s + ")"
    }
    Let(name, val) => "let " + name + " = " + expr_to_string(val)
    StrLit(s) => "\"" + escape_string(s) + "\""
    IntLit(n) => n.to_string()
    ArrLit(args) => {
      let mut s = "["
      let mut first = true
      for a in args {
        if !first { s = s + ", " }
        s = s + expr_to_string(a)
        first = false
      }
      s + "]"
    }
    Index(target, idx) => expr_to_string(target) + "[" + expr_to_string(idx) + "]"
    Unit => "()"
    Lambda(params, body) => {
      let mut s = "fn("
      let mut first = true
      for p in params {
        if !first { s = s + ", " }
        s = s + p.name + ": " + emit_type_expr(p.ty)
        first = false
      }
      s + ") { " + expr_to_string(body) + " }"
    }
    BinOp(op, left, right) => expr_to_string(left) + " " + op + " " + expr_to_string(right)
    If(cond, then_expr, else_expr) => {
      "if " + expr_to_string(cond) + " { " + expr_to_string(then_expr) + " } else { " + expr_to_string(else_expr) + " }"
    }
    Return(val) => "return " + expr_to_string(val)
    ForLoop(varname, iter, body) => {
      let mut s = "for " + varname + " in " + expr_to_string(iter) + " {\n"
      for stmt in body {
        s = s + "  " + expr_to_string(stmt) + "\n"
      }
      s + "}"
    }
    Match(scrutinee, arms) => {
      let mut s = "match " + expr_to_string(scrutinee) + " { "
      let mut i = 0
      while i < arms.length() {
        let arm = arms[i]
        let pattern = arm.0
        let body = arm.1
        s = s + pattern + " => " + expr_to_string(body) + "; "
        i = i + 1
      }
      s + "}"
    }
    Block(exprs) => {
      let mut s = "{\n"
      for e in exprs {
        s = s + "  " + expr_to_string(e) + "\n"
      }
      s + "}"
    }
  }
}

// === Tests ===

test "emit: empty source file" {
  let f: SourceFile = { items: [] }
  let result = emit_source_file(f)
  inspect(result, content="")
}

test "emit: import without alias" {
  let f: SourceFile = {
    items: [Import({ path: "moonbitlang/core/builtin", import_alias: None })]
  }
  let result = emit_source_file(f)
  inspect(result, content="import \"moonbitlang/core/builtin\"\n")
}

test "emit: import with alias" {
  let f: SourceFile = {
    items: [Import({ path: "moonbitlang/core/encoding/utf8", import_alias: Some("utf8") })]
  }
  let result = emit_source_file(f)
  inspect(result, content="import \"moonbitlang/core/encoding/utf8\" @utf8\n")
}

test "emit: public struct with fields" {
  let s: StructDef = {
    name: "User",
    fields: [
      { name: "id", ty: Named("Int"), doc: None, json_tag: None, db_tag: None },
      { name: "email", ty: Named("String"), doc: Some("user email"), json_tag: None, db_tag: None },
    ],
    doc: Some("A user record"),
    is_pub: true,
  }
  let f: SourceFile = { items: [Struct(s)] }
  let result = emit_source_file(f)
  inspect(result, content="/// A user record\npub struct User {\n  id: Int\n  /// user email\n  email: String\n}\n")
}

test "emit: private struct without fields" {
  let s: StructDef = {
    name: "Empty", fields: [], doc: None, is_pub: false,
  }
  let f: SourceFile = { items: [Struct(s)] }
  let result = emit_source_file(f)
  inspect(result, content="struct Empty\n")
}

test "emit: pub enum with variants" {
  let e: EnumDef = {
    name: "Color",
    variants: [
      { name: "Red", doc: None },
      { name: "Blue", doc: None },
    ],
    doc: None,
    is_pub: true,
  }
  let f: SourceFile = { items: [Enum(e)] }
  let result = emit_source_file(f)
  inspect(result, content="pub enum Color {\n  Red\n  Blue\n}\n")
}

test "emit: enum without variants" {
  let e: EnumDef = {
    name: "Empty", variants: [], doc: None, is_pub: false,
  }
  let f: SourceFile = { items: [Enum(e)] }
  let result = emit_source_file(f)
  inspect(result, content="enum Empty\n")
}

test "emit: function with parameters and body" {
  let f: FnDef = {
    name: "greet",
    params: [{ name: "name", ty: Named("String") }],
    return_ty: Named("String"),
    body: [
      Let("result", Call("format", [StrLit("Hello, "), Ident("name")])),
      Ident("result"),
    ],
    doc: Some("Greet someone"),
    is_pub: true,
  }
  let sf: SourceFile = { items: [Fn(f)] }
  let result = emit_source_file(sf)
  inspect(result, content="/// Greet someone\npub fn greet(name: String) -> String {\n  let result = format(\"Hello, \", name)\n  result\n}\n")
}

test "emit: function without return type (Unit)" {
  let f: FnDef = {
    name: "noop", params: [], return_ty: Named("Unit"),
    body: [Unit], doc: None, is_pub: false,
  }
  let sf: SourceFile = { items: [Fn(f)] }
  let result = emit_source_file(sf)
  inspect(result, content="fn noop() {\n  ()\n}\n")
}

test "emit: function without body" {
  let f: FnDef = {
    name: "placeholder", params: [], return_ty: Named("Int"),
    body: [], doc: None, is_pub: false,
  }
  let sf: SourceFile = { items: [Fn(f)] }
  let result = emit_source_file(sf)
  inspect(result, content="fn placeholder() -> Int\n")
}

test "emit: type alias" {
  let t: TypeAliasDef = {
    name: "Json", underlying: Named("String"),
    doc: None,
  }
  let sf: SourceFile = { items: [TypeAlias(t)] }
  let result = emit_source_file(sf)
  inspect(result, content="type Json = String\n")
}

test "emit: type alias with doc" {
  let t: TypeAliasDef = {
    name: "Json", underlying: Named("String"),
    doc: Some("JSON encoded as string"),
  }
  let sf: SourceFile = { items: [TypeAlias(t)] }
  let result = emit_source_file(sf)
  inspect(result, content="/// JSON encoded as string\ntype Json = String\n")
}

test "emit: parameterized type expr" {
  let t: TypeExpr = Parameterized("Array", [Named("Int")])
  let s = emit_type_expr(t)
  inspect(s, content="Array[Int]")
}

test "emit: nested parameterized type expr" {
  let t: TypeExpr = Parameterized("Map", [Named("String"), Named("Int")])
  let s = emit_type_expr(t)
  inspect(s, content="Map[String, Int]")
}

test "emit: option type expr" {
  let t: TypeExpr = Option(Named("String"))
  let s = emit_type_expr(t)
  inspect(s, content="Option[String]")
}

test "emit: wildcard type expr" {
  let t: TypeExpr = Wildcard
  let s = emit_type_expr(t)
  inspect(s, content="_")
}

test "emit: lambda expression" {
  let body: Expr = Ident("x")
  let lambda: Expr = Lambda(
    [{ name: "row", ty: Named("Row") }],
    body,
  )
  let em = Emitter::new()
  emit_expr(em, 0, lambda)
  let result = em.finish()
  inspect(result, content="fn(row: Row) { x }\n")
}

test "emit: block expression" {
  let block: Expr = Block([
    Let("x", StrLit("hello")),
    Ident("x"),
  ])
  let em = Emitter::new()
  emit_expr(em, 0, block)
  let result = em.finish()
  inspect(result, content="{\n  let x = \"hello\"\n  x\n}\n")
}

test "emit: full source file with multiple items" {
  let imp: ImportDef = { path: "moonbitlang/core/builtin", import_alias: None }
  let s: StructDef = {
    name: "Point", fields: [
      { name: "x", ty: Named("Int"), doc: None, json_tag: None, db_tag: None },
      { name: "y", ty: Named("Int"), doc: None, json_tag: None, db_tag: None },
    ], doc: None, is_pub: true,
  }
  let f: FnDef = {
    name: "origin", params: [], return_ty: Named("Point"),
    body: [Call("Point", [StrLit("0"), StrLit("0")])], doc: None, is_pub: true,
  }
  let sf: SourceFile = { items: [Import(imp), Struct(s), Fn(f)] }
  let result = emit_source_file(sf)
  inspect(result, content="import \"moonbitlang/core/builtin\"\n\npub struct Point {\n  x: Int\n  y: Int\n}\n\npub fn origin() -> Point {\n  Point(\"0\", \"0\")\n}\n")
}

test "emit: string literal expr" {
  let s: Expr = StrLit("SELECT * FROM users")
  let em = Emitter::new()
  emit_expr(em, 0, s)
  let result = em.finish()
  inspect(result, content="\"SELECT * FROM users\"\n")
}

test "emit: index expression" {
  let e: Expr = Index(Ident("arr"), IntLit(0))
  let em = Emitter::new()
  emit_expr(em, 0, e)
  let result = em.finish()
  inspect(result, content="arr[0]\n")
}

test "emit: binop expression" {
  let e: Expr = BinOp(">", Ident("a"), IntLit(5))
  let em = Emitter::new()
  emit_expr(em, 0, e)
  let result = em.finish()
  inspect(result, content="a > 5\n")
}

test "emit: if expression" {
  let e: Expr = If(BinOp(">", Ident("x"), IntLit(0)), Ident("x"), Ident("neg"))
  let em = Emitter::new()
  emit_expr(em, 0, e)
  let result = em.finish()
  inspect(result, content="if x > 0 {\n  x\n} else {\n  neg\n}\n")
}

test "emit: call expression with multiple args" {
  let call: Expr = Call("db.query_many", [Ident("db"), Ident("sql")])
  let em = Emitter::new()
  emit_expr(em, 0, call)
  let result = em.finish()
  inspect(result, content="db.query_many(db, sql)\n")
}

test "emit: lambda with typed params" {
  let body: Expr = Call("User::decode", [Ident("row")])
  let lambda: Expr = Lambda(
    [{ name: "row", ty: Named("Row") }],
    body,
  )
  let em = Emitter::new()
  emit_expr(em, 0, lambda)
  let result = em.finish()
  inspect(result, content="fn(row: Row) { User::decode(row) }\n")
}

test "emit: struct with doc comment and field doc comments" {
  let s: StructDef = {
    name: "User",
    fields: [
      { name: "id", ty: Named("Int"), doc: Some("primary key"), json_tag: None, db_tag: None },
      { name: "name", ty: Named("String"), doc: Some("full name"), json_tag: None, db_tag: None },
    ],
    doc: Some("Represents a user in the system"),
    is_pub: true,
  }
  let sf: SourceFile = { items: [Struct(s)] }
  let result = emit_source_file(sf)
  inspect(result, content="/// Represents a user in the system\npub struct User {\n  /// primary key\n  id: Int\n  /// full name\n  name: String\n}\n")
}

test "emit: function with parameterized return type" {
  let f: FnDef = {
    name: "get_user",
    params: [{ name: "id", ty: Named("Int") }],
    return_ty: Parameterized("Option", [Named("User")]),
    body: [Ident("None")],
    doc: None,
    is_pub: true,
  }
  let sf: SourceFile = { items: [Fn(f)] }
  let result = emit_source_file(sf)
  inspect(result, content="pub fn get_user(id: Int) -> Option[User] {\n  None\n}\n")
}

test "emit: array literal expr" {
  let e: Expr = ArrLit([StrLit("hello"), StrLit("world")])
  let em = Emitter::new()
  emit_expr(em, 0, e)
  let result = em.finish()
  inspect(result, content="[\"hello\", \"world\"]\n")
}

test "emit: empty array literal expr" {
  let e: Expr = ArrLit([])
  let em = Emitter::new()
  emit_expr(em, 0, e)
  let result = em.finish()
  inspect(result, content="[]\n")
}

test "escape_string: dollar sign alone is escaped" {
  let result = escape_string("$")
  inspect(result, content="\\$")
}

test "escape_string: multiple dollar signs are escaped" {
  let result = escape_string("$$x$y$")
  inspect(result, content="\\$\\$x\\$y\\$")
}

test "escape_string: dollar sign at start is escaped" {
  let result = escape_string("$hello")
  inspect(result, content="\\$hello")
}

test "escape_string: double quotes are escaped" {
  let result = escape_string("hello\"world")
  inspect(result, content="hello\\\"world")
}

test "escape_string: newline and tab are escaped" {
  let result = escape_string("line1\nline2\tcol")
  inspect(result, content="line1\\nline2\\tcol")
}

test "escape_string: backslash is escaped, dollar is escaped" {
  let result = escape_string("a\\b$c")
  inspect(result, content="a\\\\b\\$c")
}

test "emit: strlit with double quotes emits escaped" {
  let e: Expr = StrLit("SELECT \"id\" FROM users")
  let em = Emitter::new()
  emit_expr(em, 0, e)
  let result = em.finish()
  inspect(result, content="\"SELECT \\\"id\\\" FROM users\"\n")
}

test "emit: strlit with newline emits escaped" {
  let e: Expr = StrLit("multi\nline")
  let em = Emitter::new()
  emit_expr(em, 0, e)
  let result = em.finish()
  inspect(result, content="\"multi\\nline\"\n")
}

test "emit: field with json_tag outputs @json.tag annotation" {
  let s: StructDef = {
    name: "Tagged",
    fields: [
      { name: "user_id", ty: Named("Int64"), doc: None, json_tag: Some("user_id"), db_tag: None },
      { name: "email_addr", ty: Named("String"), doc: None, json_tag: None, db_tag: Some("email_addr") },
    ],
    doc: None,
    is_pub: true,
  }
  let sf: SourceFile = { items: [Struct(s)] }
  let result = emit_source_file(sf)
  inspect(result, content="pub struct Tagged {\n  @json.tag(\"user_id\") user_id: Int64\n  @db.tag(\"email_addr\") email_addr: String\n}\n")
}

test "emit: field with both json_tag and db_tag outputs both annotations" {
  let s: StructDef = {
    name: "Both",
    fields: [
      { name: "full_name", ty: Named("String"), doc: None, json_tag: Some("full_name"), db_tag: Some("full_name") },
    ],
    doc: None,
    is_pub: true,
  }
  let sf: SourceFile = { items: [Struct(s)] }
  let result = emit_source_file(sf)
  inspect(result, content="pub struct Both {\n  @json.tag(\"full_name\") @db.tag(\"full_name\") full_name: String\n}\n")
}

test "emit: field with no tags outputs no annotations" {
  let s: StructDef = {
    name: "Plain",
    fields: [
      { name: "id", ty: Named("Int64"), doc: None, json_tag: None, db_tag: None },
    ],
    doc: None,
    is_pub: true,
  }
  let sf: SourceFile = { items: [Struct(s)] }
  let result = emit_source_file(sf)
  inspect(result, content="pub struct Plain {\n  id: Int64\n}\n")
}
