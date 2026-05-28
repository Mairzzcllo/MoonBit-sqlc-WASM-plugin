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
  let opts = { package_name: pkg }
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
  let ir = build_ir(adapted)
  let types = generate_types(adapted.catalog, ir)
  let query_fns = generate_query_fns(ir)
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


