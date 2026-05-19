///|
/// RowIter type for iterating over :many query results.
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

/// Row iterator providing streaming access to query results.
pub struct RowIter {
  next_fn : () -> Result[Option[Row], DBError]
}

pub fn RowIter::new(next_fn: () -> Result[Option[Row], DBError]) -> RowIter {
  { next_fn: next_fn }
}

/// Advance to the next row, returning Ok(None) when exhausted.
pub fn RowIter::next(self: RowIter) -> Result[Option[Row], DBError] {
  (self.next_fn)()
}

/// Collect all remaining rows into an Array.
pub fn RowIter::collect(self: RowIter) -> Result[Array[Row], DBError] {
  let rows: Array[Row] = []
  let mut running = true
  while running {
    match self.next() {
      Ok(Some(row)) => rows.push(row)
      Ok(None) => running = false
      Err(e) => return Err(e)
    }
  }
  Ok(rows)
}

test "RowIter::next returns Ok(None) from empty iterator" {
  let iter = RowIter::new(fn() { Ok(None) })
  let result = iter.next()
  let is_ok_none = match result { Ok(None) => true; _ => false }
  inspect(is_ok_none, content="true")
}

test "RowIter::collect returns empty array from empty iterator" {
  let iter = RowIter::new(fn() { Ok(None) })
  let result = iter.collect()
  let len = match result { Ok(rows) => rows.length(); Err(_) => -1 }
  inspect(len, content="0")
}
