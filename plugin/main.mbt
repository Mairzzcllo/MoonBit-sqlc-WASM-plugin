///|
/// sqlc WASM plugin entry point.
/// Implements the sqlc CodeGenRequest/CodeGenResponse protocol over WASI.
fn main {
  // TODO(P0-002): implement WASM plugin protocol
  // - read CodeGenRequest from stdin
  // - parse protobuf
  // - call codegen pipeline
  // - write CodeGenResponse to stdout
  abort("plugin: not implemented")
}
