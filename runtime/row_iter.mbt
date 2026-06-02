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
/// Uses a default max_rows limit of 10,000 to prevent memory exhaustion.
pub fn RowIter::collect(self: RowIter) -> Result[Array[Row], DBError] {
  self.collect_limited(10000)
}

/// Collect rows into an Array with a specified maximum row count.
/// Returns TooManyRows if the limit is exceeded.
pub fn RowIter::collect_limited(self: RowIter, max_rows: Int) -> Result[Array[Row], DBError] {
  let rows: Array[Row] = []
  let mut running = true
  let mut row_count = 0
  while running {
    match self.next() {
      Ok(Some(row)) => {
        row_count = row_count + 1
        if row_count > max_rows {
          return Err(TooManyRows(row_count, "collect limit exceeded"))
        }
        rows.push(row)
      }
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

test "RowIter::collect returns rows from non-empty iterator" {
  let mut count = 0
  let iter = RowIter::new(fn() {
    if count < 3 {
      count = count + 1
      Ok(Some(Row::new(fn(_i) { "" }, Array::make(1, false))))
    } else {
      Ok(None)
    }
  })
  let result = iter.collect()
  let len = match result { Ok(rows) => rows.length(); Err(_) => -1 }
  inspect(len, content="3")
}

test "RowIter::collect_limited returns rows within limit" {
  let mut count = 0
  let iter = RowIter::new(fn() {
    if count < 5 {
      count = count + 1
      Ok(Some(Row::new(fn(_i) { "" }, Array::make(1, false))))
    } else {
      Ok(None)
    }
  })
  let result = iter.collect_limited(10)
  let len = match result { Ok(rows) => rows.length(); Err(_) => -1 }
  inspect(len, content="5")
}

test "RowIter::collect_limited returns TooManyRows when limit exceeded" {
  let mut count = 0
  let iter = RowIter::new(fn() {
    if count < 10 {
      count = count + 1
      Ok(Some(Row::new(fn(_i) { "" }, Array::make(1, false))))
    } else {
      Ok(None)
    }
  })
  let result = iter.collect_limited(3)
  let is_too_many = match result { Err(TooManyRows(_, _)) => true; _ => false }
  inspect(is_too_many, content="true")
}

test "RowIter::collect_limited with limit 0 returns TooManyRows on first row" {
  let iter = RowIter::new(fn() {
    Ok(Some(Row::new(fn(_i) { "" }, Array::make(1, false))))
  })
  let result = iter.collect_limited(0)
  let is_too_many = match result { Err(TooManyRows(_, _)) => true; _ => false }
  inspect(is_too_many, content="true")
}

test "RowIter::collect_limited propagates DBError from next" {
  let iter = RowIter::new(fn() { Err(QueryError("fail")) })
  let result = iter.collect_limited(10)
  let is_query_err = match result { Err(QueryError(_)) => true; _ => false }
  inspect(is_query_err, content="true")
}

test "RowIter::collect default uses 10000 limit" {
  let mut count = 0
  let iter = RowIter::new(fn() {
    if count < 2 {
      count = count + 1
      Ok(Some(Row::new(fn(_i) { "" }, Array::make(1, false))))
    } else {
      Ok(None)
    }
  })
  let result = iter.collect()
  let len = match result { Ok(rows) => rows.length(); Err(_) => -1 }
  inspect(len, content="2")
}

