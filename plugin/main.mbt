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
/// Currently returns an empty response (stub for P0-022).
fn process_request(_req: GenerateRequest) -> GenerateResponse {
  { files: [] }
}

/// Write a diagnostic message to stderr (fd 2).
fn log_stderr(msg: String) -> Unit {
  let _ = fd_write(2, msg, msg.length())
}
