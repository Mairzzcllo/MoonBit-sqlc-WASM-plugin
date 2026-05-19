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

/// PostgreSQL canonical/common aliases → MoonBit type mapping.
/// Returns the MoonBit TypeExpr for the given PG type name.
/// Normalizes input: case-insensitive (via to_lower), strips schema prefix.
fn map_pg_name(name: String) -> TypeExpr {
  // Normalize: lowercase for case-insensitive matching, strip schema prefix
  let normalized = {
    let lower = name.to_lower()
    let dot_idx = lower.rev_find(".")
    match dot_idx {
      Some(pos) => lower.substring(start = pos + 1)
      None => lower
    }
  }
  match normalized {
    // Integers
    "int2" | "smallint" | "smallserial" | "int4" | "integer" | "int" | "serial" => Named("Int")
    "int8" | "bigint" | "bigserial" => Named("Int64")
    // Floats
    "float4" | "real" => Named("Float")
    "float8" | "double" | "double precision" => Named("Double")
    // numeric/decimal → Double (MVP).
    // WARNING: PostgreSQL numeric(1000,0) supports ~1000 significant digits
    // while Double only has 15-17 digits. Future: map to String or custom Decimal.
    "numeric" | "decimal" => Named("Double")
    // Boolean
    "bool" | "boolean" => Named("Bool")
    // String types
    "text" | "varchar" | "char" | "bpchar" | "name" | "character varying" => Named("String")
    // Binary
    "bytea" => Named("Bytes")
    // JSON
    "json" | "jsonb" => Named("JsonValue")
    // Network
    "inet" | "cidr" | "macaddr" => Named("String")
    // UUID
    "uuid" => Named("String")
    // Date/Time (encoded as String for MVP)
    "date" | "time" | "timetz" | "timestamp" | "timestamptz" | "timestamp with time zone" => Named("String")
    // Interval → String (MVP decision).
    // MVP uses String as placeholder. Future: map to Duration or Int64 (microseconds).
    "interval" => Named("String")
    // Arrays are handled by the caller via Arr(inner)
    // Fallback for unknown types
    _ => Named("String")
  }
}

/// Map an IR InternalType to a MoonBit TypeExpr.
/// Handles Named types via the mapping table and Arr types recursively.
pub fn map_internal_type(ir_type: InternalType) -> TypeExpr {
  match ir_type {
    Named(name) => map_pg_name(name)
    Arr(elem) => Parameterized("Array", [map_internal_type(elem)])
  }
}

/// Map an IR InternalType to a MoonBit TypeExpr, considering nullability.
/// When `not_null` is false, wraps in `Option[...]`.
pub fn map_internal_type_nullable(ir_type: InternalType, not_null: Bool) -> TypeExpr {
  let base = map_internal_type(ir_type)
  if not_null { base } else { Option(base) }
}

// === Tests ===

test "map_pg_name: int4 maps to Int" {
  let t = map_pg_name("int4")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: int8 maps to Int64" {
  let t = map_pg_name("int8")
  inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: int2 maps to Int" {
  let t = map_pg_name("int2")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: float4 maps to Float" {
  let t = map_pg_name("float4")
  inspect(t, content="Named(\"Float\")")
}

test "map_pg_name: float8 maps to Double" {
  let t = map_pg_name("float8")
  inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: bool maps to Bool" {
  let t = map_pg_name("bool")
  inspect(t, content="Named(\"Bool\")")
}

test "map_pg_name: text maps to String" {
  let t = map_pg_name("text")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: varchar maps to String" {
  let t = map_pg_name("varchar")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: timestamptz maps to String" {
  let t = map_pg_name("timestamptz")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: jsonb maps to JsonValue" {
  let t = map_pg_name("jsonb")
  inspect(t, content="Named(\"JsonValue\")")
}

test "map_pg_name: bytea maps to Bytes" {
  let t = map_pg_name("bytea")
  inspect(t, content="Named(\"Bytes\")")
}

test "map_pg_name: uuid maps to String" {
  let t = map_pg_name("uuid")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: inet maps to String" {
  let t = map_pg_name("inet")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: date maps to String" {
  let t = map_pg_name("date")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: numeric maps to Double" {
  let t = map_pg_name("numeric")
  inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: unknown type falls back to String" {
  let t = map_pg_name("some_unknown_type")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: boolean alias" {
  let t = map_pg_name("boolean")
  inspect(t, content="Named(\"Bool\")")
}

test "map_pg_name: smallint alias" {
  let t = map_pg_name("smallint")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: bigint alias" {
  let t = map_pg_name("bigint")
  inspect(t, content="Named(\"Int64\")")
}

test "map_internal_type: Named int4 maps to Int" {
  let t = map_internal_type(Named("int4"))
  inspect(t, content="Named(\"Int\")")
}

test "map_internal_type: Arr of int4 maps to Array[Int]" {
  let t = map_internal_type(Arr(Named("int4")))
  inspect(t, content="Parameterized(\"Array\", [Named(\"Int\")])")
}

test "map_internal_type: nested Arr maps to Array[Array[Int]]" {
  let t = map_internal_type(Arr(Arr(Named("int4"))))
  inspect(t, content="Parameterized(\"Array\", [Parameterized(\"Array\", [Named(\"Int\")])])")
}

test "map_internal_type_nullable: not_null preserves type" {
  let t = map_internal_type_nullable(Named("int4"), true)
  inspect(t, content="Named(\"Int\")")
}

test "map_internal_type_nullable: nullable wraps in Option" {
  let t = map_internal_type_nullable(Named("int4"), false)
  inspect(t, content="Option(Named(\"Int\"))")
}

test "map_internal_type_nullable: nullable array wraps in Option" {
  let t = map_internal_type_nullable(Arr(Named("text")), false)
  inspect(t, content="Option(Parameterized(\"Array\", [Named(\"String\")]))")
}

test "map_pg_name: real alias" {
  let t = map_pg_name("real")
  inspect(t, content="Named(\"Float\")")
}

test "map_pg_name: decimal alias" {
  let t = map_pg_name("decimal")
  inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: serial maps to Int" {
  let t = map_pg_name("serial")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: bigserial maps to Int64" {
  let t = map_pg_name("bigserial")
  inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: smallserial maps to Int" {
  let t = map_pg_name("smallserial")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: INT4 uppercase maps to Int" {
  let t = map_pg_name("INT4")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: BIGINT uppercase maps to Int64" {
  let t = map_pg_name("BIGINT")
  inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: TEXT uppercase maps to String" {
  let t = map_pg_name("TEXT")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: pg_catalog.int4 strips schema prefix" {
  let t = map_pg_name("pg_catalog.int4")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: pg_catalog.int8 strips schema prefix" {
  let t = map_pg_name("pg_catalog.int8")
  inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: pg_catalog.text strips schema prefix" {
  let t = map_pg_name("pg_catalog.text")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: pg_catalog.INT4 uppercase schema prefix strips correctly" {
  let t = map_pg_name("pg_catalog.INT4")
  inspect(t, content="Named(\"Int\")")
}

test "map_pg_name: pg_catalog.BIGSERIAL strips schema prefix" {
  let t = map_pg_name("pg_catalog.BIGSERIAL")
  inspect(t, content="Named(\"Int64\")")
}

test "map_pg_name: timestamp with time zone maps to String" {
  let t = map_pg_name("timestamp with time zone")
  inspect(t, content="Named(\"String\")")
}

test "map_pg_name: double precision maps to Double" {
  let t = map_pg_name("double precision")
  inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: DOUBLE PRECISION uppercase maps to Double" {
  let t = map_pg_name("DOUBLE PRECISION")
  inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: pg_catalog.float8 strips schema prefix" {
  let t = map_pg_name("pg_catalog.float8")
  inspect(t, content="Named(\"Double\")")
}

test "map_pg_name: serial type pg_catalog.SERIAL strips prefix" {
  let t = map_pg_name("pg_catalog.SERIAL")
  inspect(t, content="Named(\"Int\")")
}
