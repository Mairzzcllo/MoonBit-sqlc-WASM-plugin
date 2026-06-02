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

/// TimeTZ value representing SQL timetz (time with timezone offset).
pub struct TimeTZ {
  hour: Int
  min: Int
  sec: Int
  micros: Int
  /// Timezone offset from UTC in seconds (e.g., +8h = 28800, -5h = -18000)
  tz_offset: Int
}

pub fn TimeTZ::new(hour: Int, min: Int, sec: Int, micros: Int, tz_offset: Int) -> TimeTZ {
  { hour: hour, min: min, sec: sec, micros: micros, tz_offset: tz_offset }
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

/// Result of an Exec operation, providing both last insert ID and rows affected.
pub struct ExecResult {
  last_insert_id : Int64
  rows_affected : Int64
}

pub fn ExecResult::new(last_insert_id: Int64, rows_affected: Int64) -> ExecResult {
  { last_insert_id: last_insert_id, rows_affected: rows_affected }
}

test "ExecResult::new and field access" {
  let r = ExecResult::new(42L, 7L)
  inspect(r.last_insert_id, content="42")
  inspect(r.rows_affected, content="7")
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
  TimeTZ(TimeTZ)
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

test "Value::TimeTZ construction" {
  let t = TimeTZ::new(10, 30, 45, 123456, 28800)
  let v: Value = TimeTZ(t)
  let is_timetz_val = match v { TimeTZ(_) => true; _ => false }
  inspect(is_timetz_val, content="true")
  let tv = match v { TimeTZ(tv) => tv; _ => TimeTZ::new(0, 0, 0, 0, 0) }
  inspect(tv.hour, content="10")
  inspect(tv.min, content="30")
  inspect(tv.sec, content="45")
  inspect(tv.micros, content="123456")
  inspect(tv.tz_offset, content="28800")
}

test "Value::TimeTZ negative offset" {
  let t = TimeTZ::new(10, 30, 45, 0, -18000)
  let v: Value = TimeTZ(t)
  let tv = match v { TimeTZ(tv) => tv; _ => TimeTZ::new(0, 0, 0, 0, 0) }
  inspect(tv.tz_offset, content="-18000")
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

test "TimeTZ::new and field access" {
  let t = TimeTZ::new(10, 30, 45, 123456, 28800)
  inspect(t.hour, content="10")
  inspect(t.min, content="30")
  inspect(t.sec, content="45")
  inspect(t.micros, content="123456")
  inspect(t.tz_offset, content="28800")
}

test "TimeTZ::new negative offset" {
  let t = TimeTZ::new(22, 15, 0, 500000, -18000)
  inspect(t.hour, content="22")
  inspect(t.min, content="15")
  inspect(t.sec, content="0")
  inspect(t.micros, content="500000")
  inspect(t.tz_offset, content="-18000")
}

test "IpAddr::new and to_string roundtrip" {
  let ip = IpAddr::new("192.168.1.1")
  inspect(ip.to_string(), content="192.168.1.1")
}

// === P1-040: Type format validation ===

/// Validate a Date string in YYYY-MM-DD format.
/// Returns Ok(Date) if the format is valid, Err(TypeError) otherwise.
///
/// This validates format only (YYYY-MM-DD), not calendar validity. Feb 30
/// passes format check. Semantic validation is the database's responsibility.
pub fn parse_date(s: String) -> Result[Date, DBError] {
  if s.length() != 10 {
    return Err(TypeError("invalid date: expected YYYY-MM-DD, got '" + s + "'"))
  }
  if s[4] != '-' || s[7] != '-' {
    return Err(TypeError("invalid date: expected YYYY-MM-DD, got '" + s + "'"))
  }
  let positions: Array[Int] = [0, 1, 2, 3, 5, 6, 8, 9]
  for i in positions {
    let c = s[i]
    if c < '0' || c > '9' {
      return Err(TypeError("invalid date: expected YYYY-MM-DD, got '" + s + "'"))
    }
  }
  try {
    let month_str = s[5:7].to_owned()
    let day_str = s[8:10].to_owned()
    let month = @string.parse_int(month_str)
    let day = @string.parse_int(day_str)
    if month < 1 || month > 12 {
      return Err(TypeError("invalid date: month out of range in '" + s + "'"))
    }
    if day < 1 || day > 31 {
      return Err(TypeError("invalid date: day out of range in '" + s + "'"))
    }
    Ok(Date::new(s))
  } catch { _ => Err(TypeError("invalid date: expected YYYY-MM-DD, got '" + s + "'")) }
}

/// Validate a Uuid string in 8-4-4-4-12 hex format.
/// Returns Ok(Uuid) if the format is valid, Err(TypeError) otherwise.
pub fn parse_uuid(s: String) -> Result[Uuid, DBError] {
  if s.length() != 36 {
    return Err(TypeError("invalid uuid: expected 36-char format, got '" + s + "'"))
  }
  // Check dashes at positions 8, 13, 18, 23
  if s[8] != '-' || s[13] != '-' || s[18] != '-' || s[23] != '-' {
    return Err(TypeError("invalid uuid: expected 8-4-4-4-12 hex format, got '" + s + "'"))
  }
  // Check hex digits at all other positions
  let non_dash_positions: Array[Int] = [
    0, 1, 2, 3, 4, 5, 6, 7,
    9, 10, 11, 12,
    14, 15, 16, 17,
    19, 20, 21, 22,
    24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35
  ]
  for i in non_dash_positions {
    let c = s[i]
    let is_hex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    if !is_hex {
      return Err(TypeError("invalid uuid: non-hex character at position " + i.to_string() + " in '" + s + "'"))
    }
  }
  Ok(Uuid::new(s))
}

/// Validate an IpAddr string (IPv4 or IPv6 basic format check).
/// Returns Ok(IpAddr) if the format looks valid, Err(TypeError) otherwise.
///
/// This is basic structural validation (IPv4 dot-count/octet range, IPv6
/// hex-group length). It is not a full IPv6 parser: it does not normalize
/// zero-compression, verify group count against :: placement, or validate
/// IPv4-mapped addresses. Full semantic validation is the database's
/// responsibility.
pub fn parse_ipaddr(s: String) -> Result[IpAddr, DBError] {
  if s.length() == 0 {
    return Err(TypeError("invalid ipaddr: empty string"))
  }
  // Check for IPv4 (contains dots)
  let mut has_dot = false
  let mut has_colon = false
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c == '.' { has_dot = true }
    if c == ':' { has_colon = true }
  }
  if has_dot {
    // IPv4: must have 3 dots, 4 octets
    let parts = s.split(".").to_array()
    if parts.length() != 4 {
      return Err(TypeError("invalid ipv4: expected 4 octets, got " + parts.length().to_string() + " in '" + s + "'"))
    }
    for i = 0; i < 4; i = i + 1 {
      let octet = parts[i].to_owned()
      if octet.length() == 0 || octet.length() > 3 {
        return Err(TypeError("invalid ipv4: bad octet '" + octet + "' in '" + s + "'"))
      }
      try {
        let val = @string.parse_int(octet)
        if val < 0 || val > 255 {
          return Err(TypeError("invalid ipv4: octet out of range '" + octet + "' in '" + s + "'"))
        }
      } catch { _ => return Err(TypeError("invalid ipv4: non-numeric octet '" + octet + "' in '" + s + "'")) }
    }
    Ok(IpAddr::new(s))
  } else if has_colon {
    // IPv6: basic structure check (at least 2 colons, valid hex groups)
    let parts = s.split(":").to_array()
    if parts.length() < 2 {
      return Err(TypeError("invalid ipv6: too few groups in '" + s + "'"))
    }
    for i = 0; i < parts.length(); i = i + 1 {
      let group = parts[i].to_owned()
      // Empty group is ok for :: compression
      if group.length() > 4 {
        return Err(TypeError("invalid ipv6: group too long '" + group + "' in '" + s + "'"))
      }
      for j = 0; j < group.length(); j = j + 1 {
        let c = group[j]
        let is_hex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
        if !is_hex {
          return Err(TypeError("invalid ipv6: non-hex in group '" + group + "' in '" + s + "'"))
        }
      }
    }
    Ok(IpAddr::new(s))
  } else {
    Err(TypeError("invalid ipaddr: neither IPv4 nor IPv6 format, got '" + s + "'"))
  }
}

/// Validate a DateTime string with simplified SQL TIMESTAMP structure.
/// Format: YYYY-MM-DDTHH:MM:SS (minimum 19 chars, hour 0-23).
/// Note: this is NOT full ISO 8601 compliance (rejects 24:00:00, leap seconds, timezone offsets).
pub fn parse_datetime(s: String) -> Result[DateTime, DBError] {
  if s.length() < 19 {
    return Err(TypeError("invalid datetime: too short, expected ISO 8601, got '" + s + "'"))
  }
  // Check basic structure: YYYY-MM-DDTHH:MM:SS
  if s[4] != '-' || s[7] != '-' || s[10] != 'T' || s[13] != ':' || s[16] != ':' {
    return Err(TypeError("invalid datetime: expected YYYY-MM-DDTHH:MM:SS structure, got '" + s + "'"))
  }
  // Check date portion digits
  let date_positions: Array[Int] = [0, 1, 2, 3, 5, 6, 8, 9]
  for i in date_positions {
    let c = s[i]
    if c < '0' || c > '9' {
      return Err(TypeError("invalid datetime: non-digit in date portion, got '" + s + "'"))
    }
  }
  // Check time portion digits
  let time_positions: Array[Int] = [11, 12, 14, 15, 17, 18]
  for i in time_positions {
    let c = s[i]
    if c < '0' || c > '9' {
      return Err(TypeError("invalid datetime: non-digit in time portion, got '" + s + "'"))
    }
  }
  // Validate ranges
  try {
    let month = @string.parse_int(s[5:7].to_owned())
    let day = @string.parse_int(s[8:10].to_owned())
    let hour = @string.parse_int(s[11:13].to_owned())
    let min = @string.parse_int(s[14:16].to_owned())
    let sec = @string.parse_int(s[17:19].to_owned())
    if month < 1 || month > 12 {
      return Err(TypeError("invalid datetime: month out of range in '" + s + "'"))
    }
    if day < 1 || day > 31 {
      return Err(TypeError("invalid datetime: day out of range in '" + s + "'"))
    }
    if hour < 0 || hour > 23 {
      return Err(TypeError("invalid datetime: hour out of range in '" + s + "'"))
    }
    if min < 0 || min > 59 {
      return Err(TypeError("invalid datetime: minute out of range in '" + s + "'"))
    }
    if sec < 0 || sec > 59 {
      return Err(TypeError("invalid datetime: second out of range in '" + s + "'"))
    }
    Ok(DateTime::new(s))
  } catch { _ => Err(TypeError("invalid datetime: expected ISO 8601, got '" + s + "'")) }
}

/// Validate a Decimal string (numeric with optional decimal point).
/// Accepts: optional leading minus, digits, optional decimal point with digits.
/// Returns Ok(Decimal) if valid, Err(TypeError) otherwise.
pub fn parse_decimal(s: String) -> Result[Decimal, DBError] {
  if s.length() == 0 {
    return Err(TypeError("invalid decimal: empty string"))
  }
  let mut has_digit = false
  let mut has_dot = false
  let mut start = 0
  // Optional leading minus
  if s[0] == '-' {
    if s.length() < 2 {
      return Err(TypeError("invalid decimal: lone minus sign"))
    }
    start = 1
  }
  for i = start; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      has_digit = true
    } else if c == '.' {
      if has_dot {
        return Err(TypeError("invalid decimal: multiple decimal points in '" + s + "'"))
      }
      has_dot = true
    } else {
      return Err(TypeError("invalid decimal: unexpected character '" + c.to_string() + "' in '" + s + "'"))
    }
  }
  if !has_digit {
    return Err(TypeError("invalid decimal: no digits in '" + s + "'"))
  }
  Ok(Decimal::new(s))
}

// === P1-040 format validation tests ===

// --- parse_date tests ---

test "parse_date: valid date YYYY-MM-DD returns Ok" {
  let result = parse_date("2026-06-15")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(d) => inspect(d.to_string(), content="2026-06-15")
    Err(_) => inspect("fail", content="2026-06-15")
  }
}

test "parse_date: valid date with min values" {
  let result = parse_date("0001-01-01")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(d) => inspect(d.to_string(), content="0001-01-01")
    Err(_) => inspect("fail", content="0001-01-01")
  }
}

test "parse_date: valid date with max values" {
  let result = parse_date("9999-12-31")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(d) => inspect(d.to_string(), content="9999-12-31")
    Err(_) => inspect("fail", content="9999-12-31")
  }
}

test "parse_date: too short string returns TypeError" {
  let result = parse_date("2026-06")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: too long string returns TypeError" {
  let result = parse_date("2026-06-15T00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: empty string returns TypeError" {
  let result = parse_date("")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: missing dashes returns TypeError" {
  let result = parse_date("20260615")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: wrong format with slashes returns TypeError" {
  let result = parse_date("2026/06/15")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: non-numeric month returns TypeError" {
  let result = parse_date("2026-XX-15")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: month out of range (00) returns TypeError" {
  let result = parse_date("2026-00-15")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: month out of range (13) returns TypeError" {
  let result = parse_date("2026-13-15")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: day out of range (00) returns TypeError" {
  let result = parse_date("2026-06-00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: day out of range (32) returns TypeError" {
  let result = parse_date("2026-06-32")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_date: completely invalid string returns TypeError" {
  let result = parse_date("not-a-date!")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

// --- parse_uuid tests ---

test "parse_uuid: valid UUID v4 returns Ok" {
  let result = parse_uuid("550e8400-e29b-41d4-a716-446655440000")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(u) => inspect(u.to_string(), content="550e8400-e29b-41d4-a716-446655440000")
    Err(_) => inspect("fail", content="550e8400-e29b-41d4-a716-446655440000")
  }
}

test "parse_uuid: valid UUID with mixed case hex returns Ok" {
  let result = parse_uuid("550E8400-E29B-41D4-A716-446655440000")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_uuid: valid UUID with uppercase returns Ok" {
  let result = parse_uuid("123E4567-E89B-12D3-A456-426614174000")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_uuid: too short returns TypeError" {
  let result = parse_uuid("550e8400-e29b-41d4-a716")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_uuid: too long returns TypeError" {
  let result = parse_uuid("550e8400-e29b-41d4-a716-44665544000000")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_uuid: empty string returns TypeError" {
  let result = parse_uuid("")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_uuid: missing dashes returns TypeError" {
  let result = parse_uuid("550e8400e29b41d4a716446655440000")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_uuid: wrong dash positions returns TypeError" {
  let result = parse_uuid("550e8400-e29b-41d4-a716-44665544-0000")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_uuid: non-hex character (g) returns TypeError" {
  let result = parse_uuid("550e8400-e29b-41d4-a716-44665544g000")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_uuid: non-hex character (z) returns TypeError" {
  let result = parse_uuid("zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

// --- parse_ipaddr tests ---

test "parse_ipaddr: valid IPv4 returns Ok" {
  let result = parse_ipaddr("192.168.1.1")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(ip) => inspect(ip.to_string(), content="192.168.1.1")
    Err(_) => inspect("fail", content="192.168.1.1")
  }
}

test "parse_ipaddr: valid IPv4 min values (0.0.0.0)" {
  let result = parse_ipaddr("0.0.0.0")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_ipaddr: valid IPv4 max values (255.255.255.255)" {
  let result = parse_ipaddr("255.255.255.255")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_ipaddr: valid IPv4 loopback (127.0.0.1)" {
  let result = parse_ipaddr("127.0.0.1")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_ipaddr: valid IPv4 private range (10.0.0.1)" {
  let result = parse_ipaddr("10.0.0.1")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_ipaddr: IPv4 octet > 255 returns TypeError" {
  let result = parse_ipaddr("256.0.0.1")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: IPv4 negative octet returns TypeError" {
  let result = parse_ipaddr("-1.0.0.1")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: IPv4 too few octets returns TypeError" {
  let result = parse_ipaddr("192.168.1")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: IPv4 too many octets returns TypeError" {
  let result = parse_ipaddr("192.168.1.1.1")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: IPv4 non-numeric octet returns TypeError" {
  let result = parse_ipaddr("192.168.abc.1")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: valid IPv6 basic returns Ok" {
  let result = parse_ipaddr("2001:db8:85a3:8d3:1319:8a2e:370:7348")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_ipaddr: valid IPv6 with :: compression returns Ok" {
  let result = parse_ipaddr("::1")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_ipaddr: valid IPv6 with mixed case returns Ok" {
  let result = parse_ipaddr("2001:DB8:85A3:8D3:1319:8A2E:370:7348")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_ipaddr: IPv6 non-hex character returns TypeError" {
  let result = parse_ipaddr("2001:db8:85g3:8d3:1319:8a2e:370:7348")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: IPv6 group too long returns TypeError" {
  // db850 has 5 hex chars (max is 4 per group)
  let result = parse_ipaddr("2001:db850:85a3:8d3:1319:8a2e:370:7348")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: empty string returns TypeError" {
  let result = parse_ipaddr("")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_ipaddr: completely invalid string returns TypeError" {
  let result = parse_ipaddr("not-an-ip")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

// --- parse_datetime tests ---

test "parse_datetime: valid ISO 8601 returns Ok" {
  let result = parse_datetime("2026-06-15T10:30:00Z")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(dt) => inspect(dt.to_string(), content="2026-06-15T10:30:00Z")
    Err(_) => inspect("fail", content="2026-06-15T10:30:00Z")
  }
}

test "parse_datetime: valid with fractional seconds returns Ok" {
  let result = parse_datetime("2026-06-15T10:30:00.123456")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_datetime: valid with timezone offset returns Ok" {
  let result = parse_datetime("2026-06-15T10:30:00+08:00")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_datetime: valid min values (midnight)" {
  let result = parse_datetime("2026-01-01T00:00:00")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_datetime: valid max time values" {
  let result = parse_datetime("2026-12-31T23:59:59")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_datetime: too short returns TypeError" {
  let result = parse_datetime("2026-06-15")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: empty string returns TypeError" {
  let result = parse_datetime("")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: missing T separator returns TypeError" {
  let result = parse_datetime("2026-06-15 10:30:00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: wrong date structure returns TypeError" {
  let result = parse_datetime("15-06-2026T10:30:00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: hour out of range (24) returns TypeError" {
  let result = parse_datetime("2026-06-15T24:00:00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: minute out of range (60) returns TypeError" {
  let result = parse_datetime("2026-06-15T10:60:00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: second out of range (60) returns TypeError" {
  let result = parse_datetime("2026-06-15T10:30:60")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: month out of range in datetime returns TypeError" {
  let result = parse_datetime("2026-13-15T10:30:00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: non-digit in time returns TypeError" {
  let result = parse_datetime("2026-06-15T1X:30:00")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_datetime: completely invalid string returns TypeError" {
  let result = parse_datetime("not-a-datetime")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

// --- parse_decimal tests ---

test "parse_decimal: valid integer decimal returns Ok" {
  let result = parse_decimal("12345")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(d) => inspect(d.to_string(), content="12345")
    Err(_) => inspect("fail", content="12345")
  }
}

test "parse_decimal: valid decimal with fraction returns Ok" {
  let result = parse_decimal("12345.6789")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(d) => inspect(d.to_string(), content="12345.6789")
    Err(_) => inspect("fail", content="12345.6789")
  }
}

test "parse_decimal: valid negative decimal returns Ok" {
  let result = parse_decimal("-42.5")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
  match result {
    Ok(d) => inspect(d.to_string(), content="-42.5")
    Err(_) => inspect("fail", content="-42.5")
  }
}

test "parse_decimal: valid zero returns Ok" {
  let result = parse_decimal("0")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_decimal: valid zero with fraction returns Ok" {
  let result = parse_decimal("0.00")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_decimal: valid single digit returns Ok" {
  let result = parse_decimal("5")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_decimal: valid large number returns Ok" {
  let result = parse_decimal("12345678901234567890.1234567890")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_decimal: empty string returns TypeError" {
  let result = parse_decimal("")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_decimal: lone minus sign returns TypeError" {
  let result = parse_decimal("-")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_decimal: multiple decimal points returns TypeError" {
  let result = parse_decimal("123.45.67")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_decimal: non-numeric characters returns TypeError" {
  let result = parse_decimal("12x45")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_decimal: only dots returns TypeError" {
  let result = parse_decimal(".")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}

test "parse_decimal: negative zero returns Ok" {
  let result = parse_decimal("-0")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_decimal: leading dot without integer part returns Ok" {
  let result = parse_decimal(".5")
  let is_ok = match result { Ok(_) => true; _ => false }
  inspect(is_ok, content="true")
}

test "parse_decimal: scientific notation not supported returns TypeError" {
  let result = parse_decimal("1.5e10")
  let is_err = match result { Err(TypeError(_)) => true; _ => false }
  inspect(is_err, content="true")
}
