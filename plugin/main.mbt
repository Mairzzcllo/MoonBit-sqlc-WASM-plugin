///|
/// sqlc WASM plugin — pure codegen pipeline.
///
/// I/O is handled by WAT shim wrapper (shim/wasi_shim.wat). MoonBit only
/// exports `process_message` for the shim to call. See protocol.mbt.

/// Entry point. Minimal stub — the post-merged shim wrapper replaces _start.
fn main {
  // Reference process_message to prevent dead-code elimination.
  // The WAT shim calls process_message by its internal mangled name;
  // MoonBit --target wasm DCE removes unreferenced functions.
  let _ = process_message(b"")
  ()
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

/// Write a diagnostic message to stderr (fd 2).
fn log_stderr(msg: String) -> Unit {
  let _ = msg
  ()
}
