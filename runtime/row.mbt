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
  null_mask : Array[Bool]
}

pub fn Row::new(get_fn: (Int) -> String, null_mask: Array[Bool]) -> Row {
  { get_fn: get_fn, null_mask: null_mask }
}

/// Get raw string value by column index.
pub fn Row::get(self: Row, index: Int) -> String {
  (self.get_fn)(index)
}

/// Check if the column at index is NULL.
pub fn Row::is_null(self: Row, index: Int) -> Bool {
  index >= 0 && index < self.null_mask.length() && self.null_mask[index]
}

// === Array decoding helpers ===

/// Parse a raw string as a JSON array. Returns the `Array[Json]` or a `DBError`.
fn parse_json_array(raw: String, index: Int, type_label: String) -> Result[Array[Json], DBError] {
  try {
    let j = @json.parse(raw[:])
    if j is Array(arr) {
      Ok(arr)
    } else {
      Err(TypeError("expected JSON array at position " + index.to_string()))
    }
  } catch { _ => Err(TypeError("expected " + type_label + " array at position " + index.to_string())) }
}

fn parse_array_str_elems(arr: Array[Json], index: Int) -> Result[Array[String], DBError] {
  let result: Array[String] = Array::make(0, "")
  for elem in arr {
    if elem is String(s) { result.push(s) } else { return Err(TypeError("expected string element in array at position " + index.to_string())) }
  }
  Ok(result)
}

fn parse_array_int64_elems(arr: Array[Json], index: Int) -> Result[Array[Int64], DBError] {
  let result: Array[Int64] = Array::make(0, 0L)
  for elem in arr {
    if elem is Number(n, ..) { result.push(n.to_int64()) } else { return Err(TypeError("expected number element in array at position " + index.to_string())) }
  }
  Ok(result)
}

fn parse_array_bool_elems(arr: Array[Json], index: Int) -> Result[Array[Bool], DBError] {
  let result: Array[Bool] = Array::make(0, false)
  for elem in arr {
    if elem is True { result.push(true) } else if elem is False { result.push(false) } else { return Err(TypeError("expected bool element in array at position " + index.to_string())) }
  }
  Ok(result)
}

fn parse_array_double_elems(arr: Array[Json], index: Int) -> Result[Array[Double], DBError] {
  let result: Array[Double] = Array::make(0, 0.0)
  for elem in arr {
    if elem is Number(n, ..) { result.push(n) } else { return Err(TypeError("expected number element in array at position " + index.to_string())) }
  }
  Ok(result)
}

fn parse_array_date_elems(arr: Array[Json], index: Int) -> Result[Array[Date], DBError] {
  let result: Array[Date] = Array::make(0, Date::new(""))
  for elem in arr {
    if elem is String(s) { result.push(Date::new(s)) } else { return Err(TypeError("expected string element in array at position " + index.to_string())) }
  }
  Ok(result)
}

fn parse_array_datetime_elems(arr: Array[Json], index: Int) -> Result[Array[DateTime], DBError] {
  let result: Array[DateTime] = Array::make(0, DateTime::new(""))
  for elem in arr {
    if elem is String(s) { result.push(DateTime::new(s)) } else { return Err(TypeError("expected string element in array at position " + index.to_string())) }
  }
  Ok(result)
}

fn parse_array_decimal_elems(arr: Array[Json], index: Int) -> Result[Array[Decimal], DBError] {
  let result: Array[Decimal] = Array::make(0, Decimal::new(""))
  for elem in arr {
    if elem is String(s) { result.push(Decimal::new(s)) } else { return Err(TypeError("expected string element in array at position " + index.to_string())) }
  }
  Ok(result)
}

fn parse_array_bytes_elems(arr: Array[Json], index: Int) -> Result[Array[Array[Byte]], DBError] {
  let result: Array[Array[Byte]] = Array::make(0, Array::make(0, (0).to_byte()))
  for elem in arr {
    if elem is String(s) {
      let n = s.length()
      let bytes: Array[Byte] = Array::make(n, (0).to_byte())
      for i in 0..<n { bytes[i] = (s[i].to_int() & 0xFF).to_byte() }
      result.push(bytes)
    } else {
      return Err(TypeError("expected string element in array at position " + index.to_string()))
    }
  }
  Ok(result)
}

// === Public array decoders ===

/// Decode a JSON array string into Array[String].
pub fn Row::decode_array_string(self: Row, index: Int) -> Result[Array[String], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, "")) }
  match parse_json_array(raw, index, "string") {
    Ok(arr) => parse_array_str_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a JSON array string into Array[Int64].
pub fn Row::decode_array_int64(self: Row, index: Int) -> Result[Array[Int64], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, 0L)) }
  match parse_json_array(raw, index, "int64") {
    Ok(arr) => parse_array_int64_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a JSON array string into Array[Bool].
pub fn Row::decode_array_bool(self: Row, index: Int) -> Result[Array[Bool], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, false)) }
  match parse_json_array(raw, index, "bool") {
    Ok(arr) => parse_array_bool_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a JSON array string into Array[Double].
pub fn Row::decode_array_double(self: Row, index: Int) -> Result[Array[Double], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, 0.0)) }
  match parse_json_array(raw, index, "double") {
    Ok(arr) => parse_array_double_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a JSON array string into Array[Date].
pub fn Row::decode_array_date(self: Row, index: Int) -> Result[Array[Date], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, Date::new(""))) }
  match parse_json_array(raw, index, "date") {
    Ok(arr) => parse_array_date_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a JSON array string into Array[DateTime].
pub fn Row::decode_array_datetime(self: Row, index: Int) -> Result[Array[DateTime], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, DateTime::new(""))) }
  match parse_json_array(raw, index, "datetime") {
    Ok(arr) => parse_array_datetime_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a JSON array string into Array[Decimal].
pub fn Row::decode_array_decimal(self: Row, index: Int) -> Result[Array[Decimal], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, Decimal::new(""))) }
  match parse_json_array(raw, index, "decimal") {
    Ok(arr) => parse_array_decimal_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a JSON array string into Array[Array[Byte]].
pub fn Row::decode_array_bytes(self: Row, index: Int) -> Result[Array[Array[Byte]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(Array::make(0, Array::make(0, (0).to_byte()))) }
  match parse_json_array(raw, index, "bytes") {
    Ok(arr) => parse_array_bytes_elems(arr, index)
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[String]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_string(self: Row, index: Int) -> Result[Option[Array[String]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "string") {
    Ok(arr) => match parse_array_str_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[Int64]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_int64(self: Row, index: Int) -> Result[Option[Array[Int64]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "int64") {
    Ok(arr) => match parse_array_int64_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[Bool]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_bool(self: Row, index: Int) -> Result[Option[Array[Bool]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "bool") {
    Ok(arr) => match parse_array_bool_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[Double]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_double(self: Row, index: Int) -> Result[Option[Array[Double]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "double") {
    Ok(arr) => match parse_array_double_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[Date]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_date(self: Row, index: Int) -> Result[Option[Array[Date]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "date") {
    Ok(arr) => match parse_array_date_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[DateTime]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_datetime(self: Row, index: Int) -> Result[Option[Array[DateTime]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "datetime") {
    Ok(arr) => match parse_array_datetime_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[Decimal]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_decimal(self: Row, index: Int) -> Result[Option[Array[Decimal]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "decimal") {
    Ok(arr) => match parse_array_decimal_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

/// Decode a nullable JSON array string into Option[Array[Array[Byte]]].
/// Empty string is treated as NULL (None).
pub fn Row::decode_nullable_array_bytes(self: Row, index: Int) -> Result[Option[Array[Array[Byte]]], DBError] {
  let raw = self.get(index)
  if raw == "" { return Ok(None) }
  match parse_json_array(raw, index, "bytes") {
    Ok(arr) => match parse_array_bytes_elems(arr, index) {
      Ok(result) => Ok(Some(result))
      Err(e) => Err(e)
    }
    Err(e) => Err(e)
  }
}

// === Typed non-nullable getters ===

/// Get an Int64 value by column index.
pub fn Row::get_int64(self: Row, index: Int) -> Result[Int64, DBError] {
  let raw = self.get(index)
  try { Ok(@string.parse_int64(raw)) } catch { _ => Err(TypeError("expected int64 at position " + index.to_string())) }
}

/// Get a String value by column index.
pub fn Row::get_string(self: Row, index: Int) -> Result[String, DBError] {
  let raw = self.get(index)
  if self.is_null(index) { return Err(TypeError("expected string at position " + index.to_string())) }
  Ok(raw)
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
    bytes[i] = (raw[i].to_int() & 0xFF).to_byte()
  }
  Ok(bytes)
}

/// Get a Date value by column index.
pub fn Row::get_date(self: Row, index: Int) -> Result[Date, DBError] {
  let raw = self.get(index)
  if self.is_null(index) { return Err(TypeError("expected date at position " + index.to_string())) }
  Ok(Date::new(raw))
}

/// Get a DateTime value by column index.
pub fn Row::get_datetime(self: Row, index: Int) -> Result[DateTime, DBError] {
  let raw = self.get(index)
  if self.is_null(index) { return Err(TypeError("expected datetime at position " + index.to_string())) }
  Ok(DateTime::new(raw))
}

/// Get a Json value by column index.
pub fn Row::get_json(self: Row, index: Int) -> Result[Json, DBError] {
  let raw = self.get(index)
  try { Ok(@json.parse(raw[:])) } catch { _ => Err(TypeError("expected json at position " + index.to_string())) }
}

/// Get a Decimal value by column index.
pub fn Row::get_decimal(self: Row, index: Int) -> Result[Decimal, DBError] {
  let raw = self.get(index)
  if self.is_null(index) { return Err(TypeError("expected decimal at position " + index.to_string())) }
  Ok(Decimal::new(raw))
}

/// Get a Uuid value by column index.
pub fn Row::get_uuid(self: Row, index: Int) -> Result[Uuid, DBError] {
  let raw = self.get(index)
  if self.is_null(index) { return Err(TypeError("expected uuid at position " + index.to_string())) }
  Ok(Uuid::new(raw))
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
    if parts.length() < 3 {
      return Err(TypeError("expected time (HH:MM:SS) at position " + index.to_string()))
    }
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
  let raw = self.get(index)
  if self.is_null(index) { return Err(TypeError("expected ipaddr at position " + index.to_string())) }
  Ok(IpAddr::new(raw))
}

// === Typed nullable getters ===

/// Get a nullable Int64 value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_int64(self: Row, index: Int) -> Result[Option[Int64], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else {
    try { Ok(Some(@string.parse_int64(raw))) } catch { _ => Err(TypeError("expected int64 at position " + index.to_string())) }
  }
}

/// Get a nullable String value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_string(self: Row, index: Int) -> Result[Option[String], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else { Ok(Some(raw)) }
}

/// Get a nullable Bool value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_bool(self: Row, index: Int) -> Result[Option[Bool], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else {
    try { Ok(Some(@string.parse_bool(raw))) } catch { _ => Err(TypeError("expected bool at position " + index.to_string())) }
  }
}

/// Get a nullable Double value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_double(self: Row, index: Int) -> Result[Option[Double], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else {
    try { Ok(Some(@string.parse_double(raw))) } catch { _ => Err(TypeError("expected double at position " + index.to_string())) }
  }
}

/// Get a nullable Bytes value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_bytes(self: Row, index: Int) -> Result[Option[Array[Byte]], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else {
    let n = raw.length()
    let bytes: Array[Byte] = Array::make(n, (0).to_byte())
    for i in 0..<n {
      bytes[i] = (raw[i].to_int() & 0xFF).to_byte()
    }
    Ok(Some(bytes))
  }
}

/// Get a nullable Date value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_date(self: Row, index: Int) -> Result[Option[Date], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else { Ok(Some(Date::new(raw))) }
}

/// Get a nullable DateTime value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_datetime(self: Row, index: Int) -> Result[Option[DateTime], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else { Ok(Some(DateTime::new(raw))) }
}

/// Get a nullable Json value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_json(self: Row, index: Int) -> Result[Option[Json], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else {
    try { Ok(Some(@json.parse(raw[:]))) } catch { _ => Err(TypeError("expected json at position " + index.to_string())) }
  }
}

/// Get a nullable Decimal value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_decimal(self: Row, index: Int) -> Result[Option[Decimal], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else { Ok(Some(Decimal::new(raw))) }
}

/// Get a nullable Uuid value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_uuid(self: Row, index: Int) -> Result[Option[Uuid], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else { Ok(Some(Uuid::new(raw))) }
}

/// Get a nullable Duration value by column index.
/// NULL is determined by null_mask.
pub fn Row::get_nullable_duration(self: Row, index: Int) -> Result[Option[Duration], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else {
    try { Ok(Some(Duration::new(@string.parse_int64(raw)))) } catch { _ => Err(TypeError("expected duration at position " + index.to_string())) }
  }
}

/// Get a nullable Time value by column index.
/// NULL is determined by null_mask.
/// Expects HH:MM:SS[.fraction] format with variable-precision fractional seconds.
pub fn Row::get_nullable_time(self: Row, index: Int) -> Result[Option[Time], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else {
    try {
      let parts = raw.split(":").to_array()
      if parts.length() < 3 {
        return Err(TypeError("expected time at position " + index.to_string()))
      }
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
/// NULL is determined by null_mask.
pub fn Row::get_nullable_ipaddr(self: Row, index: Int) -> Result[Option[IpAddr], DBError] {
  let raw = self.get(index)
  if self.is_null(index) { Ok(None) } else { Ok(Some(IpAddr::new(raw))) }
}

// === Tests ===

test "Row::get_int64 parses valid int64" {
  let row = Row::new(fn(i) { if i == 0 { "42" } else { "" } }, Array::make(1, false))
  let val = row.get_int64(0)
  match val {
    Ok(n) => inspect(n, content="42")
    Err(_) => inspect("fail", content="42")
  }
}

test "Row::get_int64 returns TypeError on invalid" {
  let row = Row::new(fn(_i) { "not_a_number" }, Array::make(1, false))
  let val = row.get_int64(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}

test "Row::get_string returns raw value" {
  let row = Row::new(fn(_i) { "hello" }, Array::make(1, false))
  let val = row.get_string(0)
  match val {
    Ok(s) => inspect(s, content="hello")
    Err(_) => inspect("fail", content="hello")
  }
}

test "Row::get_bool parses valid bool" {
  let row = Row::new(fn(_i) { "true" }, Array::make(1, false))
  let val = row.get_bool(0)
  match val {
    Ok(b) => inspect(b, content="true")
    Err(_) => inspect("fail", content="true")
  }
}

test "Row::get_double parses valid double" {
  let row = Row::new(fn(_i) { "3.14" }, Array::make(1, false))
  let val = row.get_double(0)
  match val {
    Ok(d) => inspect(d, content="3.14")
    Err(_) => inspect("fail", content="3.14")
  }
}

test "Row::get_bytes returns byte array" {
  let row = Row::new(fn(_i) { "abc" }, Array::make(1, false))
  let val = row.get_bytes(0)
  match val {
    Ok(b) => inspect(b.length(), content="3")
    Err(_) => inspect(0, content="3")
  }
}

test "Row::get_date wraps string" {
  let row = Row::new(fn(_i) { "2026-01-15" }, Array::make(1, false))
  let val = row.get_date(0)
  match val {
    Ok(d) => inspect(d.to_string(), content="2026-01-15")
    Err(_) => inspect("fail", content="2026-01-15")
  }
}

test "Row::get_datetime wraps string" {
  let row = Row::new(fn(_i) { "2026-01-15T10:30:00Z" }, Array::make(1, false))
  let val = row.get_datetime(0)
  match val {
    Ok(dt) => inspect(dt.to_string(), content="2026-01-15T10:30:00Z")
    Err(_) => inspect("fail", content="2026-01-15T10:30:00Z")
  }
}

test "Row::get_nullable_int64: non-empty returns Some" {
  let row = Row::new(fn(_i) { "42" }, Array::make(1, false))
  let val = row.get_nullable_int64(0)
  match val {
    Ok(Some(n)) => inspect(n, content="42")
    _ => inspect(0L, content="42")
  }
}

test "Row::get_nullable_int64: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, true))
  let val = row.get_nullable_int64(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::get_nullable_string: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, true))
  let val = row.get_nullable_string(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::get_json parses valid json" {
  let row = Row::new(fn(_i) { "{\"key\": 42}" }, Array::make(1, false))
  let val = row.get_json(0)
  let is_ok = match val { Ok(_) => true; Err(_) => false }
  inspect(is_ok, content="true")
}

test "Row::get_nullable_json: empty returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, true))
  let val = row.get_nullable_json(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::get_time: HH:MM:SS (no fraction)" {
  let row = Row::new(fn(_i) { "10:30:45" }, Array::make(1, false))
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
  let row = Row::new(fn(_i) { "10:30:45.1" }, Array::make(1, false))
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="100000")
    Err(_) => inspect(0, content="100000")
  }
}

test "Row::get_time: HH:MM:SS.123456 (6-digit fraction exact)" {
  let row = Row::new(fn(_i) { "10:30:45.123456" }, Array::make(1, false))
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="123456")
    Err(_) => inspect(0, content="123456")
  }
}

test "Row::get_time: HH:MM:SS.1234567 (7-digit fraction truncates to 123456)" {
  let row = Row::new(fn(_i) { "10:30:45.1234567" }, Array::make(1, false))
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="123456")
    Err(_) => inspect(0, content="123456")
  }
}

test "Row::get_time: HH:MM:SS.12 (2-digit fraction pads to 120000)" {
  let row = Row::new(fn(_i) { "10:30:45.12" }, Array::make(1, false))
  let val = row.get_time(0)
  match val {
    Ok(t) => inspect(t.micros, content="120000")
    Err(_) => inspect(0, content="120000")
  }
}

test "Row::get_time: invalid format returns TypeError" {
  let row = Row::new(fn(_i) { "not_a_time" }, Array::make(1, false))
  let val = row.get_time(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}

test "Row::decode_array_string: valid JSON array" {
  let row = Row::new(fn(_i) { "[\"a\",\"b\",\"c\"]" }, Array::make(1, false))
  let val = row.decode_array_string(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="3")
      inspect(arr[0], content="a")
      inspect(arr[2], content="c")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_string: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_string(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_array_int64: valid JSON array" {
  let row = Row::new(fn(_i) { "[1,2,3]" }, Array::make(1, false))
  let val = row.decode_array_int64(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="3")
      inspect(arr[0], content="1")
      inspect(arr[2], content="3")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_int64: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_int64(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_nullable_array_string: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[\"x\",\"y\"]" }, Array::make(1, false))
  let val = row.decode_nullable_array_string(0)
  match val {
    Ok(Some(arr)) => inspect(arr.length(), content="2")
    _ => inspect(-1, content="2")
  }
}

test "Row::decode_nullable_array_string: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_string(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_nullable_array_int64: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[10,20]" }, Array::make(1, false))
  let val = row.decode_nullable_array_int64(0)
  match val {
    Ok(Some(arr)) => {
      inspect(arr.length(), content="2")
      inspect(arr[0], content="10")
    }
    _ => inspect("fail", content="pass")
  }
}

test "Row::decode_nullable_array_int64: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_int64(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_array_bool: valid JSON array" {
  let row = Row::new(fn(_i) { "[true,false,true]" }, Array::make(1, false))
  let val = row.decode_array_bool(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="3")
      inspect(arr[0], content="true")
      inspect(arr[1], content="false")
      inspect(arr[2], content="true")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_bool: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_bool(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_array_bool: invalid element returns TypeError" {
  let row = Row::new(fn(_i) { "[\"not_bool\"]" }, Array::make(1, false))
  let val = row.decode_array_bool(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}

test "Row::decode_nullable_array_bool: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[false,true]" }, Array::make(1, false))
  let val = row.decode_nullable_array_bool(0)
  match val {
    Ok(Some(arr)) => inspect(arr.length(), content="2")
    _ => inspect(-1, content="2")
  }
}

test "Row::decode_nullable_array_bool: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_bool(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_array_double: valid JSON array" {
  let row = Row::new(fn(_i) { "[1.5,2.5,3.5]" }, Array::make(1, false))
  let val = row.decode_array_double(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="3")
      inspect(arr[0], content="1.5")
      inspect(arr[1], content="2.5")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_double: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_double(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_array_double: invalid element returns TypeError" {
  let row = Row::new(fn(_i) { "[\"not_a_number\"]" }, Array::make(1, false))
  let val = row.decode_array_double(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}

test "Row::decode_nullable_array_double: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[3.14,2.71]" }, Array::make(1, false))
  let val = row.decode_nullable_array_double(0)
  match val {
    Ok(Some(arr)) => inspect(arr.length(), content="2")
    _ => inspect(-1, content="2")
  }
}

test "Row::decode_nullable_array_double: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_double(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_array_date: valid JSON array" {
  let row = Row::new(fn(_i) { "[\"2026-01-15\",\"2026-06-15\"]" }, Array::make(1, false))
  let val = row.decode_array_date(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="2")
      inspect(arr[0].to_string(), content="2026-01-15")
      inspect(arr[1].to_string(), content="2026-06-15")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_date: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_date(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_nullable_array_date: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[\"2026-01-15\"]" }, Array::make(1, false))
  let val = row.decode_nullable_array_date(0)
  match val {
    Ok(Some(arr)) => inspect(arr.length(), content="1")
    _ => inspect(-1, content="1")
  }
}

test "Row::decode_nullable_array_date: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_date(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_array_datetime: valid JSON array" {
  let row = Row::new(fn(_i) { "[\"2026-01-15T10:30:00Z\",\"2026-06-15T12:00:00Z\"]" }, Array::make(1, false))
  let val = row.decode_array_datetime(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="2")
      inspect(arr[0].to_string(), content="2026-01-15T10:30:00Z")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_datetime: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_datetime(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_nullable_array_datetime: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[\"2026-01-15T10:30:00Z\"]" }, Array::make(1, false))
  let val = row.decode_nullable_array_datetime(0)
  match val {
    Ok(Some(arr)) => inspect(arr.length(), content="1")
    _ => inspect(-1, content="1")
  }
}

test "Row::decode_nullable_array_datetime: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_datetime(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_array_decimal: valid JSON array" {
  let row = Row::new(fn(_i) { "[\"123.45\",\"678.90\"]" }, Array::make(1, false))
  let val = row.decode_array_decimal(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="2")
      inspect(arr[0].to_string(), content="123.45")
      inspect(arr[1].to_string(), content="678.90")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_decimal: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_decimal(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_nullable_array_decimal: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[\"999.99\"]" }, Array::make(1, false))
  let val = row.decode_nullable_array_decimal(0)
  match val {
    Ok(Some(arr)) => inspect(arr.length(), content="1")
    _ => inspect(-1, content="1")
  }
}

test "Row::decode_nullable_array_decimal: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_decimal(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_array_bytes: valid JSON array" {
  let row = Row::new(fn(_i) { "[\"abc\",\"de\"]" }, Array::make(1, false))
  let val = row.decode_array_bytes(0)
  match val {
    Ok(arr) => {
      inspect(arr.length(), content="2")
      inspect(arr[0].length(), content="3")
      inspect(arr[1].length(), content="2")
    }
    Err(_) => inspect("fail", content="pass")
  }
}

test "Row::decode_array_bytes: empty string returns empty array" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_array_bytes(0)
  match val {
    Ok(arr) => inspect(arr.length(), content="0")
    Err(_) => inspect(-1, content="0")
  }
}

test "Row::decode_nullable_array_bytes: valid JSON returns Some" {
  let row = Row::new(fn(_i) { "[\"hello\"]" }, Array::make(1, false))
  let val = row.decode_nullable_array_bytes(0)
  match val {
    Ok(Some(arr)) => {
      inspect(arr.length(), content="1")
      inspect(arr[0].length(), content="5")
    }
    _ => inspect("fail", content="pass")
  }
}

test "Row::decode_nullable_array_bytes: empty string returns None" {
  let row = Row::new(fn(_i) { "" }, Array::make(1, false))
  let val = row.decode_nullable_array_bytes(0)
  match val {
    Ok(None) => inspect("null", content="null")
    _ => inspect("not_null", content="null")
  }
}

test "Row::decode_array_decimal: not a JSON array returns TypeError" {
  let row = Row::new(fn(_i) { "\"not_an_array\"" }, Array::make(1, false))
  let val = row.decode_array_decimal(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}

test "Row::decode_array_datetime: not a JSON array returns TypeError" {
  let row = Row::new(fn(_i) { "42" }, Array::make(1, false))
  let val = row.decode_array_datetime(0)
  let is_type_err = match val { Err(TypeError(_)) => true; _ => false }
  inspect(is_type_err, content="true")
}
