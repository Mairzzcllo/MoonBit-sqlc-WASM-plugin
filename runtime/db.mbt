///|
/// Database connection abstraction.
/// Generated code accepts DB as a parameter for each query function.
/// Real database drivers provide exec/execrows implementations via closures.

/// Concrete DB handle wrapping driver-specific implementations.
pub struct DB {
  exec_fn : (String) -> Int
  execrows_fn : (String) -> Int64
}

pub fn DB::new(exec_fn: (String) -> Int, execrows_fn: (String) -> Int64) -> DB {
  { exec_fn: exec_fn, execrows_fn: execrows_fn }
}

pub fn DB::exec(self: DB, sql: String) -> Int {
  (self.exec_fn)(sql)
}

pub fn DB::execrows(self: DB, sql: String) -> Int64 {
  (self.execrows_fn)(sql)
}
