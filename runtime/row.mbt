///|
/// Row abstraction for reading query results.
/// Provides indexed access to column values with typed getters.
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

/// Get raw string value by column index.
pub fn Row::get(self: Row, index: Int) -> String {
  (self.get_fn)(index)
}

// === Array decoding functions ===

/// Decode a JSON array string into Array[String].
pub fn Row::decode_array_string(self: Row, index: Int) -> Result[Array[String], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, "")) }
  try {
    let j = @json.parse(raw[:])
    if j is Array(arr) {
      let result: Array[String] = Array::make(0, "")
      for elem in arr {
        if elem is String(s) {
          result.push(s)
        } else {
          return Err(TypeError("expected string element in array at position " + index.to_string()))
        }
      }
      Ok(result)
    } else {
      Err(TypeError("expected JSON array at position " + index.to_string()))
    }
  } catch { _ => Err(TypeError("expected string array at position " + index.to_string())) }
}

/// Decode a JSON array string into Array[Int64].
pub fn Row::decode_array_int64(self: Row, index: Int) -> Result[Array[Int64], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, 0L)) }
  try {
    let j = @json.parse(raw[:])
    if j is Array(arr) {
      let result: Array[Int64] = Array::make(0, 0L)
      for elem in arr {
        if elem is Number(n, ..) {
          result.push(n.to_int64())
        } else {
          return Err(TypeError("expected number element in array at position " + index.to_string()))
        }
      }
      Ok(result)
    } else {
      Err(TypeError("expected JSON array at position " + index.to_string()))
    }
  } catch { _ => Err(TypeError("expected int64 array at position " + index.to_string())) }
}

/// Decode a nullable JSON array string into Option[Array[String]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_string(self: Row, index: Int) -> Result[Option[Array[String]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  try {
    let j = @json.parse(raw[:])
    if j is Array(arr) {
      let result: Array[String] = Array::make(0, "")
      for elem in arr {
        if elem is String(s) {
          result.push(s)
        } else {
          return Err(TypeError("expected string element in array at position " + index.to_string()))
        }
      }
      Ok(Some(result))
    } else {
      Err(TypeError("expected JSON array at position " + index.to_string()))
    }
  } catch { _ => Err(TypeError("expected string array at position " + index.to_string())) }
}

/// Decode a nullable JSON array string into Option[Array[Int64]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_int64(self: Row, index: Int) -> Result[Option[Array[Int64]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  try {
    let j = @json.parse(raw[:])
    if j is Array(arr) {
      let result: Array[Int64] = Array::make(0, 0L)
      for elem in arr {
        if elem is Number(n, ..) {
          result.push(n.to_int64())
        } else {
          return Err(TypeError("expected number element in array at position " + index.to_string()))
        }
      }
      Ok(Some(result))
    } else {
      Err(TypeError("expected JSON array at position " + index.to_string()))
    }
  } catch { _ => Err(TypeError("expected int64 array at position " + index.to_string())) }
}

// === Typed non-nullable getters ===

/// Get an Int64 value by column index.
pub fn Row::get_int64(self: Row, index: Int) -> Result[Int64, DBError] {
  let raw = self.get(index)
  try { Ok(@string.parse_int64(raw)) } catch { _ => Err(TypeError("expected int64 at position " + index.to_string())) }
}

/// Get a String value by column index.
pub fn Row::get_string(self: Row, index: Int) -> Result[String, DBError] {
  Ok(self.get(index))
}

/// Get a Bool value by column index.
pub fn Row::get_bool(self: Row, index: Int) -> Result[Bool, DBError] {
  let raw = self.get(index)
  try { Ok(@string.parse_bool(raw)) } catch { _ => Err(TypeError("expected bool at position " + index.to_string())) }
}

/// Get a Double value by column index.
pub fn Row::get_double(self: Row, index: Int) -> Result[Double, DBError] {
  let raw = self.get(index)
  try { Ok(@string.parse_double(raw)) } catch { _ => Err(TypeError("expected double at position " + index.to_string())) }
}

/// Get a Bytes (Array[Byte]) value by column index.
pub fn Row::get_bytes(self: Row, index: Int) -> Result[Array[Byte], DBError] {
  let raw = self.get(index)
  let n = raw.length()
  let bytes: Array[Byte] = Array::make(n, (0).to_byte())
  for i in 0..<n {
    bytes[i] = raw[i].to_byte()
  }
  Ok(bytes)
}

/// Get a Date value by column index.
pub fn Row::get_date(self: Row, index: Int) -> Result[Date, DBError] {
  Ok(Date::new(self.get(index)))
}

/// Get a DateTime value by column index.
pub fn Row::get_datetime(self: Row, index: Int) -> Result[DateTime, DBError] {
  Ok(DateTime::new(self.get(index)))
}

/// Get a Json value by column index.
pub fn Row::get_json(self: Row, index: Int) -> Result[Json, DBError] {
  let raw = self.get(index)
  try { Ok(@json.parse(raw[:])) } catch { _ => Err(TypeError("expected json at position " + index.to_string())) }
}

/// Get a Decimal value by column index.
pub fn Row::get_decimal(self: Row, index: Int) -> Result[Decimal, DBError] {
  Ok(Decimal::new(self.get(index)))
}

/// Get a Uuid value by column index.
pub fn Row::get_uuid(self: Row, index: Int) -> Result[Uuid, DBError] {
  Ok(Uuid::new(self.get(index)))
}

/// Get a Duration value by column index.
pub fn Row::get_duration(self: Row, index: Int) -> Result[Duration, DBError] {
  let raw = self.get(index)
  try { Ok(Duration::new(@string.parse_int64(raw))) } catch { _ => Err(TypeError("expected duration (micros) at position " + index.to_string())) }
}

/// Get a Time value by column index.
/// Expects HH:MM:SS[.fraction] format with variable-precision fractional seconds.
/// The fractional part is right-padded or truncated to 6 digits (microseconds).
pub fn Row::get_time(self: Row, index: Int) -> Result[Time, DBError] {
  let raw = self.get(index)
  try {
    let parts = raw.split(":").to_array()
    let hour = @string.parse_int(parts[0].to_owned())
    let min = @string.parse_int(parts[1].to_owned())
    let sec_parts = parts[2].to_owned().split(".").to_array()
    let sec = @string.parse_int(sec_parts[0].to_owned())
    let micros = if sec_parts.length() > 1 {
      let frac = sec_parts[1].to_owned()
      if frac.length() >= 6 {
        @string.parse_int(frac[:6].to_owned())
      } else {
        // Pad right with zeros to 6 digits
        let mut padded = frac
        for _i = frac.length(); _i < 6; _i = _i + 1 {
          padded = padded + "0"
        }
        @string.parse_int(padded)
      }
    } else { 0 }
    Ok(Time::new(hour, min, sec, micros))
  } catch { _ => Err(TypeError("expected time (HH:MM:SS) at position " + index.to_string())) }
}

/// Get an IpAddr value by column index.
pub fn Row::get_ipaddr(self: Row, index: Int) -> Result[IpAddr, DBError] {
  Ok(IpAddr::new(self.get(index)))
}

// === Typed nullable getters ===

/// Get a nullable Int64 value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_int64(self: Row, index: Int) -> Result[Option[Int64], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else {
    try { Ok(Some(@string.parse_int64(raw))) } catch { _ => Err(TypeError("expected int64 at position " + index.to_string())) }
  }
}

/// Get a nullable String value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_string(self: Row, index: Int) -> Result[Option[String], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else { Ok(Some(raw)) }
}

/// Get a nullable Bool value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_bool(self: Row, index: Int) -> Result[Option[Bool], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else {
    try { Ok(Some(@string.parse_bool(raw))) } catch { _ => Err(TypeError("expected bool at position " + index.to_string())) }
  }
}

/// Get a nullable Double value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_double(self: Row, index: Int) -> Result[Option[Double], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else {
    try { Ok(Some(@string.parse_double(raw))) } catch { _ => Err(TypeError("expected double at position " + index.to_string())) }
  }
}

/// Get a nullable Bytes value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_bytes(self: Row, index: Int) -> Result[Option[Array[Byte]], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else {
    let n = raw.length()
    let bytes: Array[Byte] = Array::make(n, (0).to_byte())
    for i in 0..<n {
      bytes[i] = raw[i].to_byte()
    }
    Ok(Some(bytes))
  }
}

/// Get a nullable Date value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_date(self: Row, index: Int) -> Result[Option[Date], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else { Ok(Some(Date::new(raw))) }
}

/// Get a nullable DateTime value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_datetime(self: Row, index: Int) -> Result[Option[DateTime], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else { Ok(Some(DateTime::new(raw))) }
}

/// Get a nullable Json value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_json(self: Row, index: Int) -> Result[Option[Json], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else {
    try { Ok(Some(@json.parse(raw[:]))) } catch { _ => Err(TypeError("expected json at position " + index.to_string())) }
  }
}

/// Get a nullable Decimal value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_decimal(self: Row, index: Int) -> Result[Option[Decimal], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else { Ok(Some(Decimal::new(raw))) }
}

/// Get a nullable Uuid value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_uuid(self: Row, index: Int) -> Result[Option[Uuid], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else { Ok(Some(Uuid::new(raw))) }
}

/// Get a nullable Duration value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_duration(self: Row, index: Int) -> Result[Option[Duration], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else {
    try { Ok(Some(Duration::new(@string.parse_int64(raw)))) } catch { _ => Err(TypeError("expected duration at position " + index.to_string())) }
  }
}

/// Get a nullable Time value by column index.
/// Empty string is treated as NULL (None).
/// Expects HH:MM:SS[.fraction] format with variable-precision fractional seconds.
pub fn Row::get_nullable_time(self: Row, index: Int) -> Result[Option[Time], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else {
    try {
      let parts = raw.split(":").to_array()
      let hour = @string.parse_int(parts[0].to_owned())
      let min = @string.parse_int(parts[1].to_owned())
      let sec_parts = parts[2].to_owned().split(".").to_array()
      let sec = @string.parse_int(sec_parts[0].to_owned())
      let micros = if sec_parts.length() > 1 {
        let frac = sec_parts[1].to_owned()
        if frac.length() >= 6 {
          @string.parse_int(frac[:6].to_owned())
        } else {
          // Pad right with zeros to 6 digits
          let mut padded = frac
          for _i = frac.length(); _i < 6; _i = _i + 1 {
            padded = padded + "0"
          }
          @string.parse_int(padded)
        }
      } else { 0 }
      Ok(Some(Time::new(hour, min, sec, micros)))
    } catch { _ => Err(TypeError("expected time at position " + index.to_string())) }
  }
}

/// Get a nullable IpAddr value by column index.
/// Empty string is treated as NULL (None).
pub fn Row::get_nullable_ipaddr(self: Row, index: Int) -> Result[Option[IpAddr], DBError] {
  let raw = self.get(index)
  if raw == "" { Ok(None) } else { Ok(Some(IpAddr::new(raw))) }
}

// === Tests ===

test "Row::get_int64 parses valid int64" {
  let row = Row::new(fn(i) { if i == 0 { "42" } else { "" } })
  let val = row.get_int64(0)
  match val {
    Ok(n) => inspect(n, content="42")
    Err(_) => inspect("fail", content="42")
  }
}

test "Row::get_int64 returns TypeError on invalid" {
  let row = Row::new(fn(_i) { "not_a_number" })
  let val = row.get_int64(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}

test "Row::get_string returns raw value" {
  let row = Row::new(fn(_i) { "hello" })
  let val = row.get_string(0)
  match val {
    Ok(s) => inspect(s, content="hello")
    Err(_) => inspect("fail", content="hello")
  }
}

test "Row::get_bool parses valid bool" {
  let row = Row::new(fn(_i) { "true" })
  let val = row.get_bool(0)
  match val {
    Ok(b) => inspect(b, content="true")
    Err(_) => inspect("fail", content="true")
  }
}

test "Row::get_double parses valid double" {
  let row = Row::new(fn(_i) { "3.14" })
  let val = row.get_double(0)
  match val {
    Ok(d) => inspect(d, content="3.14")
    Err(_) => inspect("fail", content="3.14")
  }
}

test "Row::get_bytes returns byte array" {
  let row = Row::new(fn(_i) { "abc" })
  let val = row.get_bytes(0)
  match val {
    Ok(b) => inspect(b.length(), content="3")
    Err(_) => inspect(0, content="3")
  }
}

test "Row::get_date wraps string" {
  let row = Row::new(fn(_i) { "2026-01-15" })
  let val = row.get_date(0)
  match val {
    Ok(d) => inspect(d.to_string(), content="2026-01-15")
    Err(_) => inspect("fail", content="2026-01-15")
  }
}

test "Row::get_datetime wraps string" {
  let row = Row::new(fn(_i) { "2026-01-15T10:30:00Z" })
  let val = row.get_datetime(0)
  match val {
    Ok(dt) => inspect(dt.to_string(), content="2026-01-15T10:30:00Z")
    Err(_) => inspect("fail", content="2026-01-15T10:30:00Z")
  }
}

test "Row::get_nullable_int64: non-empty returns Some" {
  let row = Row::new(fn(_i) { "42" })
  let val = row.get_nullable_int64(0)
  match val {
    Ok(Some(n)) => inspect(n, content="42")
    _ => inspect(0L, content="42")
  }
}

test "Row::get_nullable_int64: empty string returns None" {
  let row = Row::new(fn(_i) { "" })
  let val = row.get_nullable_int64(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::get_nullable_string: empty string returns None" {
  let row = Row::new(fn(_i) { "" })
  let val = row.get_nullable_string(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::get_json parses valid json" {
  let row = Row::new(fn(_i) { "{\"key\": 42}" })
  let val = row.get_json(0)
  let is_ok = match val { Ok(_) => true; Err(_) => false }
  inspect(is_ok, content="true")
}

test "Row::get_nullable_json: empty returns None" {
  let row = Row::new(fn(_i) { "" })
  let val = row.get_nullable_json(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::get_time: HH:MM:SS (no fraction)" {
  let row = Row::new(fn(_i) { "10:30:45" })
  let val = row.get_time(0)
  match val {
    Ok(t) => {
      inspect(t.hour, content="10")
      inspect(t.min, content="30")
      inspect(t.sec, content="45")
      inspect(t.micros, content="0")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::get_time: HH:MM:SS.f (1-digit fraction pads to 100000 micros)" {
  let row = Row::new(fn(_i) { "10:30:45.1" })
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="100000")
    Err(_) => inspect(0, content="100000")
  }
}

test "Row::get_time: HH:MM:SS.123456 (6-digit fraction exact)" {
  let row = Row::new(fn(_i) { "10:30:45.123456" })
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="123456")
    Err(_) => inspect(0, content="123456")
  }
}

test "Row::get_time: HH:MM:SS.1234567 (7-digit fraction truncates to 123456)" {
  let row = Row::new(fn(_i) { "10:30:45.1234567" })
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="123456")
    Err(_) => inspect(0, content="123456")
  }
}

test "Row::get_time: HH:MM:SS.12 (2-digit fraction pads to 120000)" {
  let row = Row::new(fn(_i) { "10:30:45.12" })
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="120000")
    Err(_) => inspect(0, content="120000")
  }
}

test "Row::get_time: invalid format returns TypeError" {
  let row = Row::new(fn(_i) { "not_a_time" })
  let val = row.get_time(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}
