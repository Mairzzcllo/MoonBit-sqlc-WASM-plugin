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
