///|
/// Row abstraction for reading query results.
/// Provides indexed access to column values.
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

/// Concrete Row handle wrapping a row of results.
pub struct Row {
  get_fn : (Int) -> String
}

pub fn Row::new(get_fn: (Int) -> String) -> Row {
  { get_fn: get_fn }
}

pub fn Row::get(self: Row, index: Int) -> String {
  (self.get_fn)(index)
}
