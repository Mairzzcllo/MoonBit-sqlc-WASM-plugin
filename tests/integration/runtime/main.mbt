///|
/// Runtime integration test — generated code compiled against mooncakes runtime.
/// Verifies name-based Row decode using real `Row::index_of` (not stub Ok(0)).
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

fn main { () }

test "runtime integration: User::decode with named columns" {
  let row = @rt.Row::new_with_names(
    fn(i) {
      if i == 0 {
        "42"
      } else if i == 1 {
        "Alice"
      } else if i == 2 {
        "alice@test.com"
      } else {
        "2024-01-15T10:30:00"
      }
    },
    Array::make(4, false),
    ["id", "name", "email", "created_at"],
  )
  match User::decode(row) {
    Ok(user) => {
      inspect(user.id, content="42")
      inspect(user.name, content="Alice")
      inspect(user.email, content="alice@test.com")
    }
    Err(e) => inspect(match e { @rt.TypeError(s) => s; _ => "unexpected" }, content="unexpected")
  }
}

test "runtime integration: User::decode fails on missing column" {
  let row = @rt.Row::new_with_names(
    fn(_i) { "" },
    Array::make(1, false),
    ["id"],
  )
  match User::decode(row) {
    Ok(_) => inspect(false, content="true")
    Err(_) => inspect(true, content="true")
  }
}
