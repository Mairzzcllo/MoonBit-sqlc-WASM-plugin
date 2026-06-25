///|
/// sqlc WASM plugin — pure codegen pipeline.
/// I/O protocol over WASI fd_read/fd_write via inline WAT FFI (wasi_io.mbt).
/// process_message is the pure computation entry point (protocol.mbt).
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

/// WASM _start entry point. Delegates to the I/O protocol loop.
fn main {
  run_io_loop()
}

/// Process a GenerateRequest and produce a GenerateResponse.
/// Uses codegen.out from sqlc config as the output directory prefix.
/// Produces two output files: types.mbt and queries.mbt.
fn process_request(req: GenerateRequest) -> GenerateResponse raise {
  validate_engine(req.settings.engine)
  let global_opts = parse_plugin_options(req.global_options)
  let plugin_opts = parse_plugin_options(req.plugin_options)
  let pkg = if plugin_opts.package_name.length() > 0 { plugin_opts.package_name } else { global_opts.package_name }
  let opts = {
    package_name: pkg,
    overrides: plugin_opts.overrides,
    emit_json_tags: plugin_opts.emit_json_tags,
    emit_db_tags: plugin_opts.emit_db_tags,
    renames: plugin_opts.renames,
    emit_sql_as_comment: plugin_opts.emit_sql_as_comment,
    omit_unused_structs: plugin_opts.omit_unused_structs,
    emit_empty_slices: plugin_opts.emit_empty_slices,
    initialisms: plugin_opts.initialisms,
    json_tags_case_style: plugin_opts.json_tags_case_style,
    emit_exact_table_names: plugin_opts.emit_exact_table_names,
    emit_methods_with_db_argument: plugin_opts.emit_methods_with_db_argument,
    column_overrides: plugin_opts.column_overrides,
    nullable_overrides: plugin_opts.nullable_overrides,
    strict_types: plugin_opts.strict_types,
  }
  let adapted = convert_request(req)
  validate_strict_types(adapted.catalog, adapted.queries, opts.overrides, opts.strict_types)
  let sources = generate_sources(req, opts)
  let out_name = req.settings.codegen.out
  // sqlc v2 commonly sends out="." for current directory; treat as empty prefix.
  let normalized_out = if out_name == "." { "" } else { out_name }
  let dir = if normalized_out.length() > 0 {
    validate_output_path(normalized_out)
    let dir_str = if normalized_out[normalized_out.length() - 1] == '/' {
      normalized_out[0 : normalized_out.length() - 1].to_owned()
    } else {
      normalized_out
    }
    if dir_str.length() == 0 {
      reject_absolute(normalized_out)
    }
    dir_str
  } else {
    ""
  }
  let files: Array[File] = []
  for s in sources {
    let fname = if dir.length() > 0 { dir + "/" + s.0 } else { s.0 }
    files.push({ name: fname, contents: @utf8.encode(s.1) })
  }
  { files: files }
}

/// Reject unsupported SQL engines at codegen entry (GAP-5: PostgreSQL only).
fn validate_engine(engine: String) -> Unit raise {
  let normalized = engine.trim().to_lower()
  if normalized.length() == 0 || normalized == "postgresql" {
    ()
  } else {
    raise Failure::Failure(
      "unsupported SQL engine: " + engine + " (only postgresql is supported)",
    )
  }
}

/// Validate an output directory path for path traversal and absolute path attacks.
/// Returns Unit on success, raises Failure error on invalid paths.
/// Rejects:
/// - Paths containing ".." as a complete path segment (path traversal)
/// - Paths starting with "/" or "\\" (Unix absolute paths)
/// - Windows drive-letter paths (e.g., C:\foo, D:/bar)
/// Note: ".." embedded in a filename (e.g. "foo..bar") is NOT traversal and is allowed.
fn validate_output_path(path: String) -> Unit raise {
  if path.length() == 0 { return () }
  // Reject Unix absolute paths
  if path[0] == '/' { reject_absolute(path) }
  if path[0] == '\\' { reject_absolute(path) }
  // Reject Windows drive-letter absolute paths (e.g., C:\foo, D:/bar)
  // path[1] == ':' catches X:... patterns. X:..\.. is also dangerous
  // (relative on Windows but traverses within the drive).
  if path.length() >= 2 && path[1] == ':' {
    reject_absolute(path)
  }
  // Reject path traversal via ".." as a complete path segment.
  // A ".." is a traversal segment only when it is a complete directory name
  // (bounded by path separators or string boundaries), not when it is
  // part of a larger filename like "foo..bar".
  if path == ".." {
    reject_traversal(path)
  }
  if path.has_prefix("../") || path.has_prefix("..\\") {
    reject_traversal(path)
  }
  if path.has_suffix("/..") || path.has_suffix("\\..") {
    reject_traversal(path)
  }
  if path.contains("/../") || path.contains("\\..\\") || path.contains("/..\\") || path.contains("\\../") {
    reject_traversal(path)
  }
  ()
}

/// Helper: raise absolute path rejection error.
fn reject_absolute(path: String) -> Unit raise {
  let msg = "output path must not be absolute: \{path}"
  raise Failure::Failure(msg)
}

/// Helper: raise path traversal rejection error.
fn reject_traversal(path: String) -> Unit raise {
  let msg = "output path contains traversal segment \"..\": \{path}"
  raise Failure::Failure(msg)
}



/// Deduplicate import items in a TopLevel array.
/// Keeps only the first import for each unique path.
/// Non-import items pass through unchanged.
fn dedup_imports(items: Array[TopLevel]) -> Array[TopLevel] {
  let seen: Array[String] = []
  let result: Array[TopLevel] = []
  for item in items {
    match item {
      Import(def) => {
        let mut is_dup = false
        for s in seen {
          if s == def.path {
            is_dup = true
            break
          }
        }
        if !is_dup {
          seen.push(def.path)
          result.push(item)
        }
      }
      _ => result.push(item)
    }
  }
  result
}

/// Run the full codegen pipeline: adapter → IR → type_gen → query_gen → emitter.
/// Returns an array of (filename, source_content) pairs for multi-file output.
/// Types (structs, enums, decode functions) go into "types.mbt".
/// Query functions go into "queries.mbt".
pub fn generate_sources(req: GenerateRequest, opts: PluginOptions) -> Array[(String, String)] {
  let adapted = convert_request(req)
  let ir = build_ir(adapted, opts.renames)
  let types = generate_types(adapted.catalog, ir, adapted.queries, opts.emit_json_tags, opts.emit_db_tags, opts.overrides, opts.column_overrides, opts.nullable_overrides, opts.renames, opts.omit_unused_structs, opts.emit_exact_table_names, opts.json_tags_case_style, opts.initialisms)
  let parsed_inits = parse_initialisms(opts.initialisms)
  let query_fns = generate_query_fns(ir, opts.overrides, opts.nullable_overrides, opts.emit_sql_as_comment, opts.emit_methods_with_db_argument, opts.emit_empty_slices, parsed_inits)

  // types.mbt: package decl + import + types (structs, enums, decode functions)
  let types_items: Array[TopLevel] = [Import({ path: "Mairzzcllo/moonbit_sqlc_plugin/runtime", import_alias: None })]
  for t in types { types_items.push(t) }
  let types_ast: SourceFile = { items: dedup_imports(types_items) }
  let types_source = emit_package_declaration(opts.package_name) + emit_source_file(types_ast)

  // queries.mbt: package decl + import + query functions
  let queries_items: Array[TopLevel] = [Import({ path: "Mairzzcllo/moonbit_sqlc_plugin/runtime", import_alias: None })]
  for f in query_fns { queries_items.push(f) }
  let queries_ast: SourceFile = { items: dedup_imports(queries_items) }
  let queries_source = emit_package_declaration(opts.package_name) + emit_source_file(queries_ast)

  [("types.mbt", types_source), ("queries.mbt", queries_source)]
}

/// Run the full codegen pipeline: adapter �?IR �?type_gen �?query_gen �?emitter.
/// Accepts parsed PluginOptions for codegen configuration (package_name, etc.).
pub fn generate_source(req: GenerateRequest, opts: PluginOptions) -> String {
  let adapted = convert_request(req)
  let ir = build_ir(adapted, opts.renames)
  let types = generate_types(adapted.catalog, ir, adapted.queries, opts.emit_json_tags, opts.emit_db_tags, opts.overrides, opts.column_overrides, opts.nullable_overrides, opts.renames, opts.omit_unused_structs, opts.emit_exact_table_names, opts.json_tags_case_style, opts.initialisms)
  let parsed_inits = parse_initialisms(opts.initialisms)
  let query_fns = generate_query_fns(ir, opts.overrides, opts.nullable_overrides, opts.emit_sql_as_comment, opts.emit_methods_with_db_argument, opts.emit_empty_slices, parsed_inits)
  let ast_items: Array[TopLevel] = [Import({ path: "Mairzzcllo/moonbit_sqlc_plugin/runtime", import_alias: None })]
  for t in types { ast_items.push(t) }
  for f in query_fns { ast_items.push(f) }
  let ast: SourceFile = { items: dedup_imports(ast_items) }
  emit_package_declaration(opts.package_name) + emit_source_file(ast)
}

test "dedup_imports: no duplicates passes through" {
  let items: Array[TopLevel] = []
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Import({ path: "moonbitlang/core/array", import_alias: Some("array") }))
  let result = dedup_imports(items)
  inspect(result.length(), content="2")
}

test "dedup_imports: duplicate import removed" {
  let items: Array[TopLevel] = []
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  let result = dedup_imports(items)
  inspect(result.length(), content="1")
}

test "dedup_imports: duplicate with different alias kept as one" {
  let items: Array[TopLevel] = []
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: Some("builtin") }))
  let result = dedup_imports(items)
  inspect(result.length(), content="1")
}

test "dedup_imports: non-import items preserved" {
  let s: StructDef = {
    name: "Foo", fields: [], doc: None, is_pub: true,
  }
  let items: Array[TopLevel] = []
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Struct(s))
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  let result = dedup_imports(items)
  inspect(result.length(), content="2")
}

test "dedup_imports: empty array returns empty" {
  let items: Array[TopLevel] = []
  let result = dedup_imports(items)
  inspect(result.length(), content="0")
}

test "dedup_imports: all identical imports returns one" {
  let items: Array[TopLevel] = []
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  let result = dedup_imports(items)
  inspect(result.length(), content="1")
}

test "dedup_imports: three duplicates with mixed non-import items preserved" {
  let s: StructDef = {
    name: "Foo", fields: [], doc: None, is_pub: true,
  }
  let f: FnDef = {
    name: "bar", params: [], return_ty: Named("Unit"),
    body: [Unit], doc: None, is_pub: false,
  }
  let items: Array[TopLevel] = []
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Struct(s))
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  items.push(Fn(f))
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  let result = dedup_imports(items)
  // Expected: 1 import + 1 struct + 1 fn = 3
  inspect(result.length(), content="3")
}

test "dedup_imports: non-consecutive duplicates removed" {
  let items: Array[TopLevel] = []
  items.push(Import({ path: "a", import_alias: None }))
  items.push(Import({ path: "b", import_alias: None }))
  items.push(Import({ path: "a", import_alias: None }))
  items.push(Import({ path: "b", import_alias: None }))
  let result = dedup_imports(items)
  inspect(result.length(), content="2")
}

test "dedup_imports: single import without duplicates" {
  let items: Array[TopLevel] = []
  items.push(Import({ path: "moonbitlang/core/builtin", import_alias: None }))
  let result = dedup_imports(items)
  inspect(result.length(), content="1")
}

test "dedup_imports: only non-import items pass through unchanged" {
  let s1: StructDef = { name: "A", fields: [], doc: None, is_pub: true }
  let s2: StructDef = { name: "B", fields: [], doc: None, is_pub: true }
  let items: Array[TopLevel] = [Struct(s1), Struct(s2)]
  let result = dedup_imports(items)
  inspect(result.length(), content="2")
}

test "dedup_imports: five imports with only two unique paths" {
  let items: Array[TopLevel] = []
  items.push(Import({ path: "x", import_alias: None }))
  items.push(Import({ path: "y", import_alias: None }))
  items.push(Import({ path: "x", import_alias: None }))
  items.push(Import({ path: "y", import_alias: None }))
  items.push(Import({ path: "x", import_alias: None }))
  let result = dedup_imports(items)
  inspect(result.length(), content="2")
}

test "process_request: global_options fallback when plugin_options empty" {
  let base = make_users_request()
  let req: GenerateRequest = {
    settings: base.settings,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"",
    global_options: b"package_name=fallback_test",
  }
  let resp = process_request(req)
  inspect(resp.files.length(), content="2")
  // First file is types.mbt �?check package declaration
  let source = @utf8.decode(resp.files[0].contents)
  inspect(source.contains("package fallback_test"), content="true")
}

test "process_request: plugin_options takes priority over global_options" {
  let base = make_users_request()
  let req: GenerateRequest = {
    settings: base.settings,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"package_name=plugin_opt",
    global_options: b"package_name=global_opt",
  }
  let resp = process_request(req)
  inspect(resp.files.length(), content="2")
  // Both files have the same package declaration; check types.mbt
  let source = @utf8.decode(resp.files[0].contents)
  inspect(source.contains("package plugin_opt"), content="true")
  inspect(source.contains("package global_opt"), content="false")
}

test "process_request: json plugin_options package_name (sqlc v1.31)" {
  let base = make_users_request()
  let req: GenerateRequest = {
    settings: base.settings,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"{\"package_name\":\"users\"}",
    global_options: b"",
  }
  let resp = process_request(req)
  inspect(resp.files.length(), content="2")
  let types_source = @utf8.decode(resp.files[0].contents)
  let queries_source = @utf8.decode(resp.files[1].contents)
  inspect(types_source.contains("package users"), content="true")
  inspect(types_source.contains("package main"), content="false")
  inspect(queries_source.contains("package users"), content="true")
}

test "process_request: both empty defaults to main package" {
  let base = make_users_request()
  let req: GenerateRequest = {
    settings: base.settings,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"",
    global_options: b"",
  }
  let resp = process_request(req)
  inspect(resp.files.length(), content="2")
  // Both files default to package main when options are empty
  let source = @utf8.decode(resp.files[0].contents)
  inspect(source.contains("package main"), content="true")
}

test "validate_output_path: empty path returns ok" {
  // Empty path is valid (no output directory specified)
  validate_output_path("")
  inspect("ok", content="ok")
}

test "validate_output_path: simple relative path returns ok" {
  validate_output_path("output")
  inspect("ok", content="ok")
}

test "validate_output_path: nested relative path returns ok" {
  validate_output_path("gen/moonbit")
  inspect("ok", content="ok")
}

test "validate_output_path: dotted directory name returns ok" {
  // Single dot in directory name (e.g. "foo.bar") is fine - not path traversal
  validate_output_path("foo.bar")
  inspect("ok", content="ok")
}

test "validate_output_path: absolute path starting with / is rejected" {
  let result = try {
    validate_output_path("/tmp/foo")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: absolute path starting with \\ is rejected" {
  let result = try {
    validate_output_path("\\Windows\\Temp")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: path traversal with .. is rejected" {
  let result = try {
    validate_output_path("../../etc")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: path traversal with .. in middle is rejected" {
  let result = try {
    validate_output_path("foo/../bar")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: path traversal with .. at start is rejected" {
  let result = try {
    validate_output_path("../out")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: path traversal with backslash .. is rejected" {
  let result = try {
    validate_output_path("..\\out")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: dots embedded in directory name passes" {
  // ".." as part of a filename (e.g. "foo..bar") is NOT path traversal
  validate_output_path("foo..bar")
  inspect("ok", content="ok")
}

test "validate_output_path: single dot segment passes" {
  // "." is the current directory, not traversal
  validate_output_path("foo/./bar")
  inspect("ok", content="ok")
}

test "validate_output_path: deeply nested relative path passes" {
  validate_output_path("a/b/c/d/e")
  inspect("ok", content="ok")
}

test "validate_output_path: normal forwardslash path passes" {
  validate_output_path("foo/bar/baz")
  inspect("ok", content="ok")
}

test "validate_output_path: path with only .. is rejected" {
  let result = try {
    validate_output_path("..")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: very long path passes" {
  // Build a long but valid relative path
  let path = "a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/1/2/3/4/5/6/7/8/9/0"
  validate_output_path(path)
  inspect("ok", content="ok")
}

test "validate_output_path: unicode characters in path passes" {
  validate_output_path("目录/文件/subdir")
  inspect("ok", content="ok")
}

test "process_request: path traversal in out name raises error" {
  let base = make_users_request()
  let settings_with_traversal = {
    version: base.settings.version,
    engine: base.settings.engine,
    schema: base.settings.schema,
    queries: base.settings.queries,
    codegen: {
      out: "../../etc",
      plugin: base.settings.codegen.plugin,
      options: base.settings.codegen.options,
      env: base.settings.codegen.env,
      process: base.settings.codegen.process,
      wasm: base.settings.codegen.wasm,
    },
  }
  let req: GenerateRequest = {
    settings: settings_with_traversal,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"package_name=test",
    global_options: b"",
  }
  let result = try {
    let _ = process_request(req)
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "process_request: absolute path in out name raises error" {
  let base = make_users_request()
  let settings_with_abs = {
    version: base.settings.version,
    engine: base.settings.engine,
    schema: base.settings.schema,
    queries: base.settings.queries,
    codegen: {
      out: "/tmp/foo",
      plugin: base.settings.codegen.plugin,
      options: base.settings.codegen.options,
      env: base.settings.codegen.env,
      process: base.settings.codegen.process,
      wasm: base.settings.codegen.wasm,
    },
  }
  let req: GenerateRequest = {
    settings: settings_with_abs,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"package_name=test",
    global_options: b"",
  }
  let result = try {
    let _ = process_request(req)
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: Windows drive-letter C:\\ is rejected" {
  let result = try {
    validate_output_path("C:\\Windows\\Temp")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: Windows drive-letter D:/ is rejected" {
  let result = try {
    validate_output_path("D:/home/user")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: lowercase drive-letter c:\\ is rejected" {
  let result = try {
    validate_output_path("c:\\users\\admin")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "validate_output_path: drive-letter with traversal is rejected" {
  let result = try {
    validate_output_path("C:..\\..\\etc")
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

test "process_request: root path / as out_name raises error" {
  let base = make_users_request()
  let settings_with_root = {
    version: base.settings.version,
    engine: base.settings.engine,
    schema: base.settings.schema,
    queries: base.settings.queries,
    codegen: {
      out: "/",
      plugin: base.settings.codegen.plugin,
      options: base.settings.codegen.options,
      env: base.settings.codegen.env,
      process: base.settings.codegen.process,
      wasm: base.settings.codegen.wasm,
    },
  }
  let req: GenerateRequest = {
    settings: settings_with_root,
    catalog: base.catalog,
    queries: base.queries,
    sqlc_version: base.sqlc_version,
    plugin_options: b"package_name=test",
    global_options: b"",
  }
  let result = try {
    let _ = process_request(req)
    "unexpected_ok"
  } catch {
    _ => "rejected"
  }
  inspect(result, content="rejected")
}

