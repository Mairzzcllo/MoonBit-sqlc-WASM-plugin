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

/// Decimal value wrapping a numeric/decimal string, preserving full precision.
pub struct Decimal {
  inner: String
}

pub fn Decimal::new(value: String) -> Decimal {
  { inner: value }
}

pub fn Decimal::to_string(self: Decimal) -> String {
  self.inner
}

/// Uuid value wrapping a UUID string.
pub struct Uuid {
  inner: String
}

pub fn Uuid::new(value: String) -> Uuid {
  { inner: value }
}

pub fn Uuid::to_string(self: Uuid) -> String {
  self.inner
}

/// Duration value representing an SQL interval in microseconds.
pub struct Duration {
  microseconds: Int64
}

pub fn Duration::new(microseconds: Int64) -> Duration {
  { microseconds: microseconds }
}

pub fn Duration::to_int64(self: Duration) -> Int64 {
  self.microseconds
}

/// Time value representing SQL time (hour, min, sec, micros).
pub struct Time {
  hour: Int
  min: Int
  sec: Int
  micros: Int
}

pub fn Time::new(hour: Int, min: Int, sec: Int, micros: Int) -> Time {
  { hour: hour, min: min, sec: sec, micros: micros }
}

/// IpAddr value wrapping an inet/cidr string.
pub struct IpAddr {
  inner: String
}

pub fn IpAddr::new(value: String) -> IpAddr {
  { inner: value }
}

pub fn IpAddr::to_string(self: IpAddr) -> String {
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
  Decimal(Decimal)
  Uuid(Uuid)
  Duration(Duration)
  Time(Time)
  IpAddr(IpAddr)
}

test "Value::Decimal construction" {
  let d = Decimal::new("12345.6789")
  let v: Value = Decimal(d)
  let val = match v { Decimal(dv) => dv.to_string(); _ => "" }
  inspect(val, content="12345.6789")
}

test "Value::Uuid construction" {
  let u = Uuid::new("550e8400-e29b-41d4-a716-446655440000")
  let v: Value = Uuid(u)
  let val = match v { Uuid(uv) => uv.to_string(); _ => "" }
  inspect(val, content="550e8400-e29b-41d4-a716-446655440000")
}

test "Value::Duration construction" {
  let d = Duration::new(3600000000L)
  let v: Value = Duration(d)
  let val = match v { Duration(dv) => dv.to_int64(); _ => 0L }
  inspect(val, content="3600000000")
}

test "Value::Time construction" {
  let t = Time::new(10, 30, 45, 123456)
  let v: Value = Time(t)
  let is_time_val = match v { Time(_) => true; _ => false }
  inspect(is_time_val, content="true")
  let tv = match v { Time(tv) => tv; _ => Time::new(0, 0, 0, 0) }
  inspect(tv.hour, content="10")
  inspect(tv.min, content="30")
  inspect(tv.sec, content="45")
  inspect(tv.micros, content="123456")
}

test "Value::IpAddr construction" {
  let ip = IpAddr::new("192.168.1.1")
  let v: Value = IpAddr(ip)
  let val = match v { IpAddr(ipv) => ipv.to_string(); _ => "" }
  inspect(val, content="192.168.1.1")
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

test "Decimal::new and to_string roundtrip" {
  let d = Decimal::new("12345.6789")
  inspect(d.to_string(), content="12345.6789")
}

test "Uuid::new and to_string roundtrip" {
  let u = Uuid::new("550e8400-e29b-41d4-a716-446655440000")
  inspect(u.to_string(), content="550e8400-e29b-41d4-a716-446655440000")
}

test "Duration::new and to_int64 roundtrip" {
  let d = Duration::new(3600000000L)
  inspect(d.to_int64(), content="3600000000")
}

test "Time::new and field access" {
  let t = Time::new(10, 30, 45, 123456)
  inspect(t.hour, content="10")
  inspect(t.min, content="30")
  inspect(t.sec, content="45")
  inspect(t.micros, content="123456")
}

test "IpAddr::new and to_string roundtrip" {
  let ip = IpAddr::new("192.168.1.1")
  inspect(ip.to_string(), content="192.168.1.1")
}
