///|
/// Database connection abstraction.
/// Generated code accepts DB as a parameter for each query function.
/// Real database drivers provide exec/execrows implementations via closures.
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
