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
  Bool(Bool)
  Double(Double)
  Bytes(Array[Byte])
  Date(Date)
  DateTime(DateTime)
  JsonValue(Json)
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

test "Value::Bool construction" {
  let v: Value = Bool(true)
  let val = match v { Bool(b) => b; _ => false }
  inspect(val, content="true")
}

test "Value::Double construction" {
  let v: Value = Double(3.14)
  let val = match v { Double(d) => d; _ => 0.0 }
  inspect(val, content="3.14")
}

test "Value::Bytes construction" {
  let bytes: Array[Byte] = Array::make(3, (0).to_byte())
  bytes[0] = (65).to_byte()
  bytes[1] = (66).to_byte()
  bytes[2] = (67).to_byte()
  let v: Value = Bytes(bytes)
  let val = match v { Bytes(b) => b.length(); _ => 0 }
  inspect(val, content="3")
  let first = match v { Bytes(b) => b[0].to_int(); _ => 0 }
  inspect(first, content="65")
}

test "Value::Date construction" {
  let d = Date::new("2026-06-15")
  let v: Value = Date(d)
  let val = match v { Date(dt) => dt.to_string(); _ => "" }
  inspect(val, content="2026-06-15")
}

test "Value::DateTime construction" {
  let dt = DateTime::new("2026-06-15T12:00:00Z")
  let v: Value = DateTime(dt)
  let val = match v { DateTime(dtz) => dtz.to_string(); _ => "" }
  inspect(val, content="2026-06-15T12:00:00Z")
}

test "Value::JsonValue construction" {
  let j = @json.parse("{\"key\": 42}")
  let v: Value = JsonValue(j)
  let is_json_val = match v { JsonValue(_) => true; _ => false }
  inspect(is_json_val, content="true")
}
