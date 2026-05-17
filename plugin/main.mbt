///|
/// sqlc WASM plugin — pure codegen pipeline.
/// I/O protocol over WASI fd_read/fd_write via inline WAT FFI (wasi_io.mbt).
/// process_message is the pure computation entry point (protocol.mbt).

/// WASM _start entry point. Delegates to the I/O protocol loop.
fn main {
  run_io_loop()
}

/// Process a GenerateRequest and produce a GenerateResponse.
/// Converts the raw request through the adapter layer, then produces output.
fn process_request(req: GenerateRequest) -> GenerateResponse {
  let source = generate_source(req)
  let contents = @utf8.encode(source)
  { files: [{ name: "lib.mbt", contents: contents }] }
}

/// Run the full codegen pipeline: adapter → IR → type_gen → query_gen → emitter.
pub fn generate_source(req: GenerateRequest) -> String {
  let adapted = convert_request(req)
  let ir = build_ir(adapted)
  let types = generate_types(adapted.catalog, ir)
  let query_fns = generate_query_fns(ir)
  let ast: SourceFile = { items: [] }
  for t in types { ast.items.push(t) }
  for f in query_fns { ast.items.push(f) }
  emit_source_file(ast)
}


