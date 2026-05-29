///|
/// Type Mapping Layer — P0-007.
/// PostgreSQL ↔ MoonBit type mapping table.
/// All mapping decisions inform ADR-004 (Naming Convention) and ADR-002 (Runtime Scope).
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

/// Map a PG type name to the corresponding Value constructor name string.
/// Returns the string name of the Value variant (e.g., "Int64", "Double", "String", etc.).
/// This is the SINGLE source of truth for PG type → MoonBit Value constructor mapping.
/// Normalizes input: case-insensitive (via to_lower), strips schema prefix.
pub fn map_pg_to_value_constructor_str(name: String) -> String {
  // Normalize: lowercase for case-insensitive matching, strip schema prefix
  let normalized = {
    let lower = name.to_lower()
    let dot_idx = lower.rev_find(".")
    match dot_idx {
      Some(pos) => lower[:][pos + 1:]
      None => lower
    }
  }
  match normalized {
    // Small/medium ints → Int64 (64-bit required, matches Value::Int64)
    "int2" | "smallint" | "smallserial" | "int4" | "integer" | "int" | "serial" => "Int64"
    // Large ints → Int64 (64-bit required)
    "int8" | "bigint" | "bigserial" => "Int64"
    // Floats — float4/real map to Double (runtime has get_double, not get_float)
    "float4" | "real" | "float8" | "double" | "double precision" => "Double"
    // numeric/decimal → Decimal (preserve full precision).
    "numeric" | "decimal" => "Decimal"
    // Boolean
    "bool" | "boolean" => "Bool"
    // String types
    "text" | "varchar" | "char" | "bpchar" | "name" | "character varying" => "String"
    // Binary
    "bytea" => "Bytes"
    // JSON
    "json" | "jsonb" => "JsonValue"
    // Network
    "inet" | "cidr" | "macaddr" => "IpAddr"
    // UUID
    "uuid" => "Uuid"
    // Date/Time — date→Date, timestamp→DateTime, time→Time
    "date" => "Date"
    "timestamp" | "timestamptz" | "timestamp with time zone" => "DateTime"
    "time" | "timetz" => "Time"
    // Interval → Duration (microseconds).
    "interval" => "Duration"
    // Arrays are handled by the caller via Arr(inner)
    // Fallback for unknown types
    _ => "String"
  }
}

/// Look up an override for a PG type name in the overrides list.
/// Strips schema prefix (e.g., "pg_catalog.int4" → "int4") before lookup.
/// Returns the mapped MoonBit type name if found, None otherwise.
fn lookup_override(name: String, overrides: Array[(String, String)]) -> Option[String] {
  let lower = name.to_lower()
  let base = match lower.rev_find(".") {
    Some(pos) => lower[:][pos + 1:].to_owned()
    None => lower
  }
  for o in overrides {
    if o.0 == base { return Some(o.1) }
  }
  None
}

/// PostgreSQL canonical/common aliases → MoonBit type mapping.
/// Returns the MoonBit TypeExpr for the given PG type name.
/// Delegates to map_pg_to_value_constructor_str for the canonical mapping.
fn map_pg_name(name: String, overrides: Array[(String, String)]) -> TypeExpr {
  match lookup_override(name, overrides) {
    Some(mapped) => Named(mapped)
    None => Named(map_pg_to_value_constructor_str(name))
  }
}

/// Map an IR InternalType to a MoonBit TypeExpr.
/// Handles Named types via the mapping table and Arr types recursively.
pub fn map_internal_type(ir_type: InternalType, overrides: Array[(String, String)]) -> TypeExpr {
  match ir_type {
    Named(name) => map_pg_name(name, overrides)
    Arr(elem) => Parameterized("Array", [map_internal_type(elem, overrides)])
  }
}

/// Map an IR InternalType to a MoonBit TypeExpr, considering nullability.
/// When `not_null` is false, wraps in `Option[...]`.
pub fn map_internal_type_nullable(
  ir_type: InternalType,
  not_null: Bool,
  overrides: Array[(String, String)],
) -> TypeExpr {
  let base = map_internal_type(ir_type, overrides)
  if not_null { base } else { Option(base) }
}

/// Map an IR InternalType to a Value constructor name, respecting overrides.
/// If an override is found, returns the override target as the constructor name.
pub fn type_to_value_constructor(ir_type: InternalType, overrides: Array[(String, String)]) -> String {
  match ir_type {
    Named(name) => match lookup_override(name, overrides) {
      Some(mapped) => mapped
      None => map_pg_to_value_constructor_str(name)
    }
    Arr(_) => "String"
  }
}

// === Tests ===

test "map_pg_name: int4 maps to Int64" {
  let t = map_pg_name("int4", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: int8 maps to Int64" {
  let t = map_pg_name("int8", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: int2 maps to Int64" {
  let t = map_pg_name("int2", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: float4 maps to Double" {
  let t = map_pg_name("float4", [])
  debug_inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: float8 maps to Double" {
  let t = map_pg_name("float8", [])
  debug_inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: bool maps to Bool" {
  let t = map_pg_name("bool", [])
  debug_inspect(t, content="Named(\"Bool\")")
}

test "map_pg_name: text maps to String" {
  let t = map_pg_name("text", [])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: varchar maps to String" {
  let t = map_pg_name("varchar", [])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: timestamptz maps to DateTime" {
  let t = map_pg_name("timestamptz", [])
  debug_inspect(t, content="Named(\"DateTime\")")
}

test "map_pg_name: jsonb maps to JsonValue" {
  let t = map_pg_name("jsonb", [])
  debug_inspect(t, content="Named(\"JsonValue\")")
}

test "map_pg_name: bytea maps to Bytes" {
  let t = map_pg_name("bytea", [])
  debug_inspect(t, content="Named(\"Bytes\")")
}

test "map_pg_name: uuid maps to Uuid" {
  let t = map_pg_name("uuid", [])
  debug_inspect(t, content="Named(\"Uuid\")")
}

test "map_pg_name: inet maps to IpAddr" {
  let t = map_pg_name("inet", [])
  debug_inspect(t, content="Named(\"IpAddr\")")
}

test "map_pg_name: date maps to Date" {
  let t = map_pg_name("date", [])
  debug_inspect(t, content="Named(\"Date\")")
}

test "map_pg_name: numeric maps to Decimal" {
  let t = map_pg_name("numeric", [])
  debug_inspect(t, content="Named(\"Decimal\")")
}

test "map_pg_name: unknown type falls back to String" {
  let t = map_pg_name("some_unknown_type", [])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: boolean alias" {
  let t = map_pg_name("boolean", [])
  debug_inspect(t, content="Named(\"Bool\")")
}

test "map_pg_name: smallint alias" {
  let t = map_pg_name("smallint", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: bigint alias" {
  let t = map_pg_name("bigint", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_internal_type: Named int4 maps to Int64" {
  let t = map_internal_type(Named("int4"), [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_internal_type: Arr of int4 maps to Array[Int64]" {
  let t = map_internal_type(Arr(Named("int4")), [])
  debug_inspect(t, content="Parameterized(\"Array\", [Named(\"Int64\")])")
}

test "map_internal_type: nested Arr maps to Array[Array[Int64]]" {
  let t = map_internal_type(Arr(Arr(Named("int4"))), [])
  debug_inspect(t, content="Parameterized(\"Array\", [Parameterized(\"Array\", [Named(\"Int64\")])])")
}

test "map_internal_type_nullable: not_null preserves type" {
  let t = map_internal_type_nullable(Named("int4"), true, [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_internal_type_nullable: nullable wraps in Option" {
  let t = map_internal_type_nullable(Named("int4"), false, [])
  debug_inspect(t, content="Option(Named(\"Int64\"))")
}

test "map_internal_type_nullable: nullable array wraps in Option" {
  let t = map_internal_type_nullable(Arr(Named("text")), false, [])
  debug_inspect(t, content="Option(Parameterized(\"Array\", [Named(\"String\")]))")
}

test "map_pg_name: real alias" {
  let t = map_pg_name("real", [])
  debug_inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: decimal alias" {
  let t = map_pg_name("decimal", [])
  debug_inspect(t, content="Named(\"Decimal\")")
}

test "map_pg_name: serial maps to Int64" {
  let t = map_pg_name("serial", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: bigserial maps to Int64" {
  let t = map_pg_name("bigserial", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: smallserial maps to Int64" {
  let t = map_pg_name("smallserial", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: INT4 uppercase maps to Int64" {
  let t = map_pg_name("INT4", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: BIGINT uppercase maps to Int64" {
  let t = map_pg_name("BIGINT", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: TEXT uppercase maps to String" {
  let t = map_pg_name("TEXT", [])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: pg_catalog.int4 strips schema prefix" {
  let t = map_pg_name("pg_catalog.int4", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: pg_catalog.int8 strips schema prefix" {
  let t = map_pg_name("pg_catalog.int8", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: pg_catalog.text strips schema prefix" {
  let t = map_pg_name("pg_catalog.text", [])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: pg_catalog.INT4 uppercase schema prefix strips correctly" {
  let t = map_pg_name("pg_catalog.INT4", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: pg_catalog.BIGSERIAL strips schema prefix" {
  let t = map_pg_name("pg_catalog.BIGSERIAL", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: timestamp with time zone maps to DateTime" {
  let t = map_pg_name("timestamp with time zone", [])
  debug_inspect(t, content="Named(\"DateTime\")")
}

test "map_pg_name: double precision maps to Double" {
  let t = map_pg_name("double precision", [])
  debug_inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: DOUBLE PRECISION uppercase maps to Double" {
  let t = map_pg_name("DOUBLE PRECISION", [])
  debug_inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: pg_catalog.float8 strips schema prefix" {
  let t = map_pg_name("pg_catalog.float8", [])
  debug_inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: serial type pg_catalog.SERIAL strips prefix" {
  let t = map_pg_name("pg_catalog.SERIAL", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

// === map_pg_to_value_constructor_str tests ===

test "map_pg_to_value_constructor_str: int4 maps to Int64" {
  let s = map_pg_to_value_constructor_str("int4")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: int8 maps to Int64" {
  let s = map_pg_to_value_constructor_str("int8")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: text maps to String" {
  let s = map_pg_to_value_constructor_str("text")
  debug_inspect(s, content="\"String\"")
}

test "map_pg_to_value_constructor_str: bool maps to Bool" {
  let s = map_pg_to_value_constructor_str("bool")
  debug_inspect(s, content="\"Bool\"")
}

test "map_pg_to_value_constructor_str: float8 maps to Double" {
  let s = map_pg_to_value_constructor_str("float8")
  debug_inspect(s, content="\"Double\"")
}

test "map_pg_to_value_constructor_str: jsonb maps to JsonValue" {
  let s = map_pg_to_value_constructor_str("jsonb")
  debug_inspect(s, content="\"JsonValue\"")
}

test "map_pg_to_value_constructor_str: bytea maps to Bytes" {
  let s = map_pg_to_value_constructor_str("bytea")
  debug_inspect(s, content="\"Bytes\"")
}

test "map_pg_to_value_constructor_str: uuid maps to Uuid" {
  let s = map_pg_to_value_constructor_str("uuid")
  debug_inspect(s, content="\"Uuid\"")
}

test "map_pg_to_value_constructor_str: inet maps to IpAddr" {
  let s = map_pg_to_value_constructor_str("inet")
  debug_inspect(s, content="\"IpAddr\"")
}

test "map_pg_to_value_constructor_str: date maps to Date" {
  let s = map_pg_to_value_constructor_str("date")
  debug_inspect(s, content="\"Date\"")
}

test "map_pg_to_value_constructor_str: numeric maps to Decimal" {
  let s = map_pg_to_value_constructor_str("numeric")
  debug_inspect(s, content="\"Decimal\"")
}

test "map_pg_to_value_constructor_str: unknown falls back to String" {
  let s = map_pg_to_value_constructor_str("some_unknown")
  debug_inspect(s, content="\"String\"")
}

test "map_pg_to_value_constructor_str: INT4 uppercase maps to Int64" {
  let s = map_pg_to_value_constructor_str("INT4")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: pg_catalog.int4 strips schema prefix" {
  let s = map_pg_to_value_constructor_str("pg_catalog.int4")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: timestamp with time zone maps to DateTime" {
  let s = map_pg_to_value_constructor_str("timestamp with time zone")
  debug_inspect(s, content="\"DateTime\"")
}

test "map_pg_to_value_constructor_str: double precision maps to Double" {
  let s = map_pg_to_value_constructor_str("double precision")
  debug_inspect(s, content="\"Double\"")
}

test "map_pg_to_value_constructor_str: time maps to Time" {
  let s = map_pg_to_value_constructor_str("time")
  debug_inspect(s, content="\"Time\"")
}

test "map_pg_to_value_constructor_str: interval maps to Duration" {
  let s = map_pg_to_value_constructor_str("interval")
  debug_inspect(s, content="\"Duration\"")
}

test "map_pg_to_value_constructor_str: macaddr maps to IpAddr" {
  let s = map_pg_to_value_constructor_str("macaddr")
  debug_inspect(s, content="\"IpAddr\"")
}

test "map_pg_to_value_constructor_str: char maps to String" {
  let s = map_pg_to_value_constructor_str("char")
  debug_inspect(s, content="\"String\"")
}

test "map_pg_to_value_constructor_str: bpchar maps to String" {
  let s = map_pg_to_value_constructor_str("bpchar")
  debug_inspect(s, content="\"String\"")
}

test "map_pg_to_value_constructor_str: smallint maps to Int64" {
  let s = map_pg_to_value_constructor_str("smallint")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: bigint maps to Int64" {
  let s = map_pg_to_value_constructor_str("bigint")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: real maps to Double" {
  let s = map_pg_to_value_constructor_str("real")
  debug_inspect(s, content="\"Double\"")
}

test "map_pg_to_value_constructor_str: varchar maps to String" {
  let s = map_pg_to_value_constructor_str("varchar")
  debug_inspect(s, content="\"String\"")
}

test "map_pg_to_value_constructor_str: timestamptz maps to DateTime" {
  let s = map_pg_to_value_constructor_str("timestamptz")
  debug_inspect(s, content="\"DateTime\"")
}

test "map_pg_to_value_constructor_str: cidr maps to IpAddr" {
  let s = map_pg_to_value_constructor_str("cidr")
  debug_inspect(s, content="\"IpAddr\"")
}

test "map_pg_to_value_constructor_str: serial maps to Int64" {
  let s = map_pg_to_value_constructor_str("serial")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: bigserial maps to Int64" {
  let s = map_pg_to_value_constructor_str("bigserial")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: smallserial maps to Int64" {
  let s = map_pg_to_value_constructor_str("smallserial")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: pg_catalog.int8 strips schema prefix" {
  let s = map_pg_to_value_constructor_str("pg_catalog.int8")
  debug_inspect(s, content="\"Int64\"")
}

test "map_pg_to_value_constructor_str: pg_catalog.text strips schema prefix" {
  let s = map_pg_to_value_constructor_str("pg_catalog.text")
  debug_inspect(s, content="\"String\"")
}

// === Override tests ===

test "map_pg_name: override numeric to Decimal" {
  let t = map_pg_name("numeric", [("numeric", "Decimal")])
  debug_inspect(t, content="Named(\"Decimal\")")
}

test "map_pg_name: override int4 to String" {
  let t = map_pg_name("int4", [("int4", "String")])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: override INT4 uppercase to String" {
  let t = map_pg_name("INT4", [("int4", "String")])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: override unknown type to custom type" {
  let t = map_pg_name("my_custom_type", [("my_custom_type", "MyCustomType")])
  debug_inspect(t, content="Named(\"MyCustomType\")")
}

test "map_pg_name: override with multiple entries picks first match" {
  let overrides: Array[(String, String)] = [("int4", "String"), ("int4", "Int64")]
  let t = map_pg_name("int4", overrides)
  debug_inspect(t, content="Named(\"String\")")
}

test "map_pg_name: empty overrides falls back to default" {
  let t = map_pg_name("int4", [])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: overrides with non-matching entry falls back to default" {
  let t = map_pg_name("int4", [("text", "MyString")])
  debug_inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: pg_catalog.int4 with override works with schema prefix" {
  let t = map_pg_name("pg_catalog.int4", [("int4", "String")])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_internal_type: override Named type" {
  let t = map_internal_type(Named("int4"), [("int4", "String")])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_internal_type: override in array element" {
  let t = map_internal_type(Arr(Named("int4")), [("int4", "String")])
  debug_inspect(t, content="Parameterized(\"Array\", [Named(\"String\")])")
}

test "map_internal_type_nullable: override with not_null" {
  let t = map_internal_type_nullable(Named("int4"), true, [("int4", "String")])
  debug_inspect(t, content="Named(\"String\")")
}

test "map_internal_type_nullable: override with nullable wraps in Option" {
  let t = map_internal_type_nullable(Named("int4"), false, [("int4", "String")])
  debug_inspect(t, content="Option(Named(\"String\"))")
}

test "type_to_value_constructor: override affects value constructor" {
  let t = type_to_value_constructor(Named("int4"), [("int4", "String")])
  debug_inspect(t, content="\"String\"")
}

test "type_to_value_constructor: empty overrides uses default" {
  let t = type_to_value_constructor(Named("int4"), [])
  debug_inspect(t, content="\"Int64\"")
}

test "type_to_value_constructor: array returns String regardless of override" {
  let t = type_to_value_constructor(Arr(Named("int4")), [("int4", "String")])
  debug_inspect(t, content="\"String\"")
}

test "lookup_override: finds matching entry" {
  let overrides: Array[(String, String)] = [("numeric", "Decimal"), ("int4", "String")]
  let r = lookup_override("numeric", overrides)
  debug_inspect(r, content="Some(\"Decimal\")")
}

test "lookup_override: case-insensitive match" {
  let overrides: Array[(String, String)] = [("int4", "String")]
  let r = lookup_override("INT4", overrides)
  debug_inspect(r, content="Some(\"String\")")
}

test "lookup_override: not found returns None" {
  let r = lookup_override("unknown", [("int4", "String")])
  debug_inspect(r, content="None")
}

test "lookup_override: empty overrides returns None" {
  let r = lookup_override("int4", [])
  debug_inspect(r, content="None")
}
