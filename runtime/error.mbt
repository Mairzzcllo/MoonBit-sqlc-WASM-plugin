///|
/// DBError type for runtime query error handling.
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

/// Database error type for runtime operations.
pub enum DBError {
  ConnectionError(String)
  QueryError(String)
  TypeError(String)
  NoRows
  ColumnNotFound(String)
  TooManyRows(Int, String)
}

test "DBError::ConnectionError carries message" {
  let e: DBError = ConnectionError("connection refused")
  let msg = match e { ConnectionError(m) => m; _ => "" }
  inspect(msg, content="connection refused")
}

test "DBError::QueryError carries message" {
  let e: DBError = QueryError("syntax error")
  let msg = match e { QueryError(m) => m; _ => "" }
  inspect(msg, content="syntax error")
}

test "DBError::TypeError carries message" {
  let e: DBError = TypeError("expected int got string")
  let msg = match e { TypeError(m) => m; _ => "" }
  inspect(msg, content="expected int got string")
}

test "DBError::NoRows construction" {
  let e: DBError = NoRows
  let is_norows = match e { NoRows => true; _ => false }
  inspect(is_norows, content="true")
}

test "DBError::ColumnNotFound carries column name" {
  let e: DBError = ColumnNotFound("unknown_col")
  let msg = match e { ColumnNotFound(m) => m; _ => "" }
  inspect(msg, content="unknown_col")
}

test "DBError::TooManyRows carries count and query" {
  let e: DBError = TooManyRows(3, "SELECT * FROM users WHERE name = $1")
  let count = match e { TooManyRows(c, _) => c; _ => 0 }
  let query = match e { TooManyRows(_, q) => q; _ => "" }
  inspect(count, content="3")
  inspect(query, content="SELECT * FROM users WHERE name = $1")
}

test "DBError::TooManyRows with zero count" {
  let e: DBError = TooManyRows(0, "SELECT 1")
  let count = match e { TooManyRows(c, _) => c; _ => -1 }
  let query = match e { TooManyRows(_, q) => q; _ => "" }
  inspect(count, content="0")
  inspect(query, content="SELECT 1")
}

test "DBError::TooManyRows with large count" {
  let e: DBError = TooManyRows(9999999, "SELECT * FROM huge_table")
  let count = match e { TooManyRows(c, _) => c; _ => 0 }
  let query = match e { TooManyRows(_, q) => q; _ => "" }
  inspect(count, content="9999999")
  inspect(query, content="SELECT * FROM huge_table")
}

test "DBError::TooManyRows with empty query" {
  let e: DBError = TooManyRows(5, "")
  let count = match e { TooManyRows(c, _) => c; _ => 0 }
  let query = match e { TooManyRows(_, q) => q; _ => "" }
  inspect(count, content="5")
  inspect(query, content="")
}

test "DBError::ColumnNotFound with long column name" {
  let e: DBError = ColumnNotFound("very_long_column_name_that_exceeds_normal_length")
  let msg = match e { ColumnNotFound(m) => m; _ => "" }
  inspect(msg, content="very_long_column_name_that_exceeds_normal_length")
}

test "DBError::ColumnNotFound with qualified column name" {
  let e: DBError = ColumnNotFound("schema.table.column")
  let msg = match e { ColumnNotFound(m) => m; _ => "" }
  inspect(msg, content="schema.table.column")
}

test "DBError::ColumnNotFound with empty column name" {
  let e: DBError = ColumnNotFound("")
  let msg = match e { ColumnNotFound(m) => m; _ => "not_empty" }
  inspect(msg, content="")
}

test "DBError: all variants pattern match exhaustively" {
  let errors: Array[DBError] = [
    ConnectionError("conn"),
    QueryError("query"),
    TypeError("type"),
    NoRows,
    ColumnNotFound("col"),
    TooManyRows(1, "sql"),
  ]
  let mut count = 0
  for e in errors {
    match e {
      ConnectionError(m) => { inspect(m.contains("conn"), content="true"); count = count + 1 }
      QueryError(m) => { inspect(m.contains("query"), content="true"); count = count + 1 }
      TypeError(m) => { inspect(m.contains("type"), content="true"); count = count + 1 }
      NoRows => { count = count + 1 }
      ColumnNotFound(m) => { inspect(m.contains("col"), content="true"); count = count + 1 }
      TooManyRows(n, _) => { inspect(n, content="1"); count = count + 1 }
    }
  }
  inspect(count, content="6")
}
