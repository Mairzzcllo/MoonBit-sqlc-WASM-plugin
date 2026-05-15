///|
/// sqlc WASM plugin entry point.
/// Implements the full protocol loop: read → decode → process → encode → write.

/// Entry point invoked by WASM runtime.
fn main {
  log_stderr("plugin: starting")
  main_loop()
  log_stderr("plugin: exiting")
}

/// Main protocol loop. Reads messages from stdin until EOF.
fn main_loop() -> Unit {
  match read_message() {
    None => ()
    Some(data) => {
      let req = decode_request(data)
      let resp = process_request(req)
      let out = encode_response(resp)
      write_message(out)
      main_loop()
    }
  }
}

/// Process a GenerateRequest and produce a GenerateResponse.
/// Converts the raw request through the adapter layer, then produces output.
fn process_request(req: GenerateRequest) -> GenerateResponse {
  let source = generate_source(req)
  { files: [] }
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
  let _ = fd_write(2, msg, msg.length())
}
