///|
/// Value type and date/time wrappers for runtime parameter binding.
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

/// Date value wrapping a SQL DATE string.
pub struct Date {
  inner: String
}

pub fn Date::new(value: String) -> Date {
  { inner: value }
}

pub fn Date::to_string(self: Date) -> String {
  self.inner
}

/// DateTime value wrapping a SQL TIMESTAMP string.
pub struct DateTime {
  inner: String
}

pub fn DateTime::new(value: String) -> DateTime {
  { inner: value }
}

pub fn DateTime::to_string(self: DateTime) -> String {
  self.inner
}

/// Runtime value type for query parameter binding.
pub enum Value {
  Null
  Int64(Int64)
  String(String)
}

test "Date::new and to_string roundtrip" {
  let d = Date::new("2026-01-15")
  inspect(d.to_string(), content="2026-01-15")
}

test "DateTime::new and to_string roundtrip" {
  let dt = DateTime::new("2026-01-15T10:30:00Z")
  inspect(dt.to_string(), content="2026-01-15T10:30:00Z")
}

test "Value::Null construction" {
  let v: Value = Null
  let is_null = match v { Null => true; _ => false }
  inspect(is_null, content="true")
}

test "Value::Int64 construction" {
  let v: Value = Int64(42L)
  let val = match v { Int64(n) => n; _ => 0L }
  inspect(val, content="42")
}

test "Value::String construction" {
  let v: Value = String("hello")
  let val = match v { String(s) => s; _ => "" }
  inspect(val, content="hello")
}
