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
  try run_io_loop() catch { _ => () }
}

/// Process a GenerateRequest and produce a GenerateResponse.
/// Uses codegen.out from sqlc config as the output directory prefix + "lib.mbt".
fn process_request(req: GenerateRequest) -> GenerateResponse raise {
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
    query_parameter_limit: plugin_opts.query_parameter_limit,
    emit_exact_table_names: plugin_opts.emit_exact_table_names,
    emit_methods_with_db_argument: plugin_opts.emit_methods_with_db_argument,
    column_overrides: plugin_opts.column_overrides,
    nullable_overrides: plugin_opts.nullable_overrides,
  }
  let source = generate_source(req, opts)
  let contents = @utf8.encode(source)
  let out_name = req.settings.codegen.out
  let filename = if out_name.length() > 0 {
    let dir = if out_name[out_name.length() - 1] == '/' { out_name[0:out_name.length() - 1].to_owned() } else { out_name }
    dir + "/lib.mbt"
  } else {
    "lib.mbt"
  }
  { files: [{ name: filename, contents: contents }] }
}

/// Run the full codegen pipeline: adapter → IR → type_gen → query_gen → emitter.
/// Accepts parsed PluginOptions for codegen configuration (package_name, etc.).
pub fn generate_source(req: GenerateRequest, opts: PluginOptions) -> String {
  let adapted = convert_request(req)
  let ir = build_ir(adapted, opts.renames)
  let types = generate_types(adapted.catalog, ir, adapted.queries, opts.emit_json_tags, opts.emit_db_tags, opts.overrides, opts.column_overrides, opts.nullable_overrides, opts.renames, opts.omit_unused_structs, opts.emit_exact_table_names, opts.json_tags_case_style, opts.initialisms)
  let parsed_inits = parse_initialisms(opts.initialisms)
  // TODO: query_parameter_limit is parsed but not yet consumed. Implementing query splitting
  // requires partitioning the query's IN(...) parameter list at the SQL level, which is
  // non-trivial — sqlc's own Go plugin handles this via post-processing of the query AST.
  // For now the option is accepted without error but has no effect. A future PR should:
  // 1. Detect oversized parameter lists in build_body
  // 2. Split INTO ... IN(...) clauses across multiple query invocations
  // 3. Merge results back into a single array
  let query_fns = generate_query_fns(ir, opts.overrides, opts.nullable_overrides, opts.emit_sql_as_comment, opts.emit_methods_with_db_argument, opts.emit_empty_slices, parsed_inits)
  let ast: SourceFile = { items: [] }
  ast.items.push(Import({ path: "Mairzzcllo/moonbit_sqlc_plugin/runtime", import_alias: None }))
  for t in types { ast.items.push(t) }
  for f in query_fns { ast.items.push(f) }
  emit_package_declaration(opts.package_name) + emit_source_file(ast)
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
  let source = @utf8.decode(resp.files[0].contents)
  inspect(source.contains("package plugin_opt"), content="true")
  inspect(source.contains("package global_opt"), content="false")
}

test "process_request: both empty uses default empty package" {
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
  let source = @utf8.decode(resp.files[0].contents)
  inspect(source.contains("package "), content="false")
}


