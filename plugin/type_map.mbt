///|
/// Type Mapping Layer — P0-007.
/// PostgreSQL ↔ MoonBit type mapping table.
/// All mapping decisions inform ADR-004 (Naming Convention) and ADR-002 (Runtime Scope).

/// PostgreSQL canonical/common aliases → MoonBit type mapping.
/// Returns the MoonBit TypeExpr for the given PG type name.
fn map_pg_name(name: String) -> TypeExpr {
  match name {
    // Integers
    "int2" | "smallint" | "int4" | "integer" | "int" => Named("Int")
    "int8" | "bigint" => Named("Int64")
    // Floats
    "float4" | "real" => Named("Float")
    "float8" | "double" => Named("Double")
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
    "date" | "time" | "timetz" | "timestamp" | "timestamptz" => Named("String")
    // Interval
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
