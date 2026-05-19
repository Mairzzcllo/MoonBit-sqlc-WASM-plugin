///|
/// MoonBit AST Definition — P0-005.
/// Pure MoonBit language structure types. No sqlc/IR/database semantics.
/// Used by code generators (P0-008, P0-009) to produce MoonBit source,
/// and by the emitter (P0-006) to render formatted output.
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

/// A type expression — used in struct fields, function signatures, etc.
pub enum TypeExpr {
  /// Simple named type: `Int`, `String`, `Bool`
  Named(String)
  /// Parameterized type: `Array[Int]`, `Map[String, Int]`
  Parameterized(String, Array[TypeExpr])
  /// Option type: `Option[Int]`
  Option(TypeExpr)
  /// Wildcard / inferred: `_`
  Wildcard
}

impl Show for TypeExpr with to_string(self) -> String {
  match self {
    Named(s) => "Named(\"" + s + "\")"
    Parameterized(n, args) => {
      let mut s = "Parameterized(\"" + n + "\", ["
      let mut first = true
      for a in args {
        if !first { s = s + ", " }
        s = s + a.to_string()
        first = false
      }
      s + "])"
    }
    Option(inner) => "Option(" + inner.to_string() + ")"
    Wildcard => "Wildcard"
  }
}

/// A struct field definition.
pub struct FieldDef {
  name : String
  ty : TypeExpr
  doc : Option[String]
}

/// Struct definition.
pub struct StructDef {
  name : String
  fields : Array[FieldDef]
  doc : Option[String]
  is_pub : Bool
}

/// Enum variant definition.
pub struct VariantDef {
  name : String
  doc : Option[String]
}

/// Enum definition.
pub struct EnumDef {
  name : String
  variants : Array[VariantDef]
  doc : Option[String]
  is_pub : Bool
}

/// Function parameter definition.
pub struct ParamDef {
  name : String
  ty : TypeExpr
}

/// Expression in generated function bodies.
pub enum Expr {
  /// Sequential block: `stmt1; stmt2`
  Block(Array[Expr])
  /// Variable reference: `sql`
  Ident(String)
  /// Function call: `db.query_many(sql, lambda)`
  Call(String, Array[Expr])
  /// Let binding: `let sql = "SELECT ..."`
  Let(String, Expr)
  /// String literal: `"SELECT ..."`
  StrLit(String)
  /// Integer literal: `0`, `42`
  IntLit(Int)
  /// Array literal: `[1, 2, 3]`
  ArrLit(Array[Expr])
  /// Array/slice index: `arr[i]`
  Index(Expr, Expr)
  /// Lambda: `{|row| Type::decode(row)}`
  Lambda(Array[ParamDef], Expr)
  /// Binary operation: `a > b`, `a != b`
  BinOp(String, Expr, Expr)
  /// If-else expression: `if cond { then } else { else }`
  If(Expr, Expr, Expr)
  /// Unit / noop
  Unit
}

/// Function definition.
pub struct FnDef {
  name : String
  params : Array[ParamDef]
  return_ty : TypeExpr
  body : Array[Expr]
  doc : Option[String]
  is_pub : Bool
}

/// Type alias definition.
pub struct TypeAliasDef {
  name : String
  underlying : TypeExpr
  doc : Option[String]
}

/// Import statement.
pub struct ImportDef {
  path : String
  import_alias : Option[String]
}

/// Top-level item in a MoonBit source file.
pub enum TopLevel {
  Struct(StructDef)
  Enum(EnumDef)
  Fn(FnDef)
  TypeAlias(TypeAliasDef)
  Import(ImportDef)
}

/// A MoonBit source file — ordered list of top-level items.
pub struct SourceFile {
  items : Array[TopLevel]
}

// === Tests ===

test "TypeExpr::Named construction" {
  let t: TypeExpr = Named("Int")
  inspect(t, content="Named(\"Int\")")
}

test "TypeExpr::Parameterized construction" {
  let t: TypeExpr = Parameterized("Array", [Named("Int")])
  inspect(t, content="Parameterized(\"Array\", [Named(\"Int\")])")
}

test "TypeExpr::Option construction" {
  let t: TypeExpr = Option(Named("String"))
  inspect(t, content="Option(Named(\"String\"))")
}

test "TypeExpr::Wildcard construction" {
  let t: TypeExpr = Wildcard
  inspect(t, content="Wildcard")
}

test "StructDef with fields" {
  let s: StructDef = {
    name: "User",
    fields: [
      { name: "id", ty: Named("Int"), doc: None },
      { name: "email", ty: Named("String"), doc: Some("user email") },
    ],
    doc: Some("A user record"),
    is_pub: true,
  }
  inspect(s.name, content="User")
  inspect(s.fields.length(), content="2")
  inspect(s.fields[0].name, content="id")
  inspect(s.fields[1].name, content="email")
  inspect(s.fields[1].doc, content="Some(user email)")
  inspect(s.is_pub, content="true")
}

test "EnumDef with variants" {
  let e: EnumDef = {
    name: "Color",
    variants: [
      { name: "Red", doc: None },
      { name: "Blue", doc: Some("the blue variant") },
    ],
    doc: None,
    is_pub: true,
  }
  inspect(e.name, content="Color")
  inspect(e.variants.length(), content="2")
  inspect(e.variants[0].name, content="Red")
  inspect(e.variants[1].name, content="Blue")
}

test "FnDef with body" {
  let f: FnDef = {
    name: "greet",
    params: [{ name: "name", ty: Named("String") }],
    return_ty: Named("String"),
    body: [Ident("name")],
    doc: Some("Greet someone"),
    is_pub: true,
  }
  inspect(f.name, content="greet")
  inspect(f.params.length(), content="1")
  inspect(f.params[0].name, content="name")
  inspect(f.is_pub, content="true")
}

test "ImportDef with alias" {
  let i: ImportDef = { path: "moonbitlang/core/builtin", import_alias: Some("builtin") }
  inspect(i.path, content="moonbitlang/core/builtin")
  inspect(i.import_alias, content="Some(builtin)")
}

test "ImportDef without alias" {
  let i: ImportDef = { path: "moonbitlang/core/array", import_alias: None }
  inspect(i.import_alias, content="None")
}

test "Construct Call expression" {
  let e: Expr = Call("query_many", [Ident("db"), Ident("sql")])
  let s = match e {
    Call(name, _) => name
    _ => ""
  }
  inspect(s, content="query_many")
}

test "Construct Let expression" {
  let e: Expr = Let("sql", StrLit("SELECT * FROM users"))
  let s = match e {
    Let(name, _) => name
    _ => ""
  }
  inspect(s, content="sql")
}

test "Lambda expression" {
  let call: Expr = Call("User::decode", [Ident("row")])
  let lambda: Expr = Lambda(
    [{ name: "row", ty: Named("Row") }],
    call,
  )
  let is_lambda = match lambda {
    Lambda(_, _) => true
    _ => false
  }
  inspect(is_lambda, content="true")
}

test "Block expression" {
  let e: Expr = Block([
    Let("sql", StrLit("SELECT 1")),
    Call("db.query_many", [Ident("sql")]),
  ])
  let count = match e {
    Block(exprs) => exprs.length()
    _ => 0
  }
  inspect(count, content="2")
}

test "TypeAliasDef with simple type" {
  let t: TypeAliasDef = {
    name: "Json",
    underlying: Named("String"),
    doc: Some("JSON encoded as string"),
  }
  inspect(t.name, content="Json")
  inspect(t.underlying, content="Named(\"String\")")
}

test "TopLevel::Fn wrapper" {
  let f: FnDef = {
    name: "f", params: [], return_ty: Named("Unit"),
    body: [Unit], doc: None, is_pub: false,
  }
  let top: TopLevel = Fn(f)
  let name = match top {
    Fn(fn_def) => fn_def.name
    _ => ""
  }
  inspect(name, content="f")
}

test "SourceFile with multiple items" {
  let s: StructDef = {
    name: "S", fields: [], doc: None, is_pub: true,
  }
  let f: FnDef = {
    name: "f", params: [], return_ty: Named("Unit"),
    body: [Unit], doc: None, is_pub: false,
  }
  let src: SourceFile = {
    items: [Struct(s), Fn(f)],
  }
  inspect(src.items.length(), content="2")
  let first_is_struct = match src.items[0] {
    Struct(_) => true
    _ => false
  }
  inspect(first_is_struct, content="true")
}
