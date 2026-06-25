<p align="center">
  <a href="runtime-api.md">English</a>
  ·
  <a href="runtime-api.zh.md"><b>中文</b></a>
  ·
  <a href="runtime-api.ja.md">日本語</a>
</p>

# Runtime API 参考

`runtime` 包提供生成查询代码所依赖的类型与函数。

**文档导航：** [快速开始](quickstart.zh.md) · [README](../README.zh.md) · [示例](../examples/README.zh.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## 从 mooncakes.io 安装

| 项目 | 值 |
|------|-----|
| 包名 | `Mairzzcllo/moonbit_sqlc_plugin` |
| 版本 | **0.1.6** |
| 导入路径 | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| 文档 | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| 目标 | `wasm-gc` |

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.6
moon check --target wasm-gc
```

在 `moon.pkg` 中添加：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

生成的文件已包含 `import "Mairzzcllo/moonbit_sqlc_plugin/runtime"`。完整设置请参阅 [快速开始 — 路径 A](quickstart.zh.md#path-a--install-runtime-from-mooncakesio)。

---

## DBError

```moonbit
pub enum DBError {
  ConnectionError(String)
  QueryError(String)
  TypeError(String)
  NoRows
  ColumnNotFound(String)
  TooManyRows(Int, String)
}
```

所有数据库操作的错误类型。runtime 中的函数均返回 `Result[T, DBError]`。

| 变体 | 含义 |
|------|------|
| `ConnectionError(msg)` | 连接或传输失败 |
| `QueryError(msg)` | SQL 执行错误 |
| `TypeError(msg)` | 解码时类型不匹配 |
| `NoRows` | `:one` 查询未返回任何行 |
| `ColumnNotFound(name)` | 按列名查找时未找到该列 |
| `TooManyRows(count, query)` | `:one` 查询返回多行，或 `collect_limited` 超出上限 |

---

## Value

```moonbit
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
```

用于 SQL 查询参数绑定的类型化值。

| 变体 | SQL 类型 | 用途 |
|------|----------|------|
| `Null` | `NULL` | 省略参数 / NULL 值 |
| `Int64(n)` | `BIGINT`, `INT`, `SERIAL` | 整数参数 |
| `String(s)` | `TEXT`, `VARCHAR` | 字符串参数 |
| `Bool(b)` | `BOOLEAN`, `BOOL` | 布尔参数 |
| `Double(d)` | `FLOAT8`, `DOUBLE` | 浮点参数 |
| `Bytes(b)` | `BYTEA` | 二进制参数 |
| `Date(d)` | `DATE` | 日期参数 |
| `DateTime(dt)` | `TIMESTAMP`, `TIMESTAMPTZ` | 时间戳参数 |
| `JsonValue(j)` | `JSON`, `JSONB` | JSON 参数 |
| `Decimal(d)` | `NUMERIC`, `DECIMAL` | 精确数值参数 |
| `Uuid(u)` | `UUID` | UUID 参数 |
| `Duration(d)` | `INTERVAL` | 区间参数（微秒） |
| `Time(t)` | `TIME` | 时间参数（时、分、秒、微秒） |
| `TimeTZ(tz)` | `TIMETZ` | 带时区偏移的时间 |
| `IpAddr(ip)` | `INET`, `CIDR` | 网络地址参数 |

---

## DB

```moonbit
pub struct DB {
  // Driver-supplied closures (constructed via DB::new)
}
```

主数据库句柄。生成的查询函数将 `DB` 作为第一个参数。

### 方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `exec` | `(String, Array[Value]) -> Result[Int64, DBError]` | 执行 SQL 并返回受影响行数 |
| `execrows` | `(String, Array[Value]) -> Result[Int64, DBError]` | 执行 SQL 并返回受影响行数（`:execrows` 查询别名） |
| `query` | `(String, Array[Value]) -> Result[RowIter, DBError]` | 执行查询并返回行迭代器（`:many`） |
| `query_row` | `(String, Array[Value]) -> Result[Row, DBError]` | 执行查询并返回单行（`:one`） |
| `begin` | `() -> Result[Transaction, DBError]` | 开始新事务 |
| `copyfrom` | `(String, Array[Value]) -> Result[Int64, DBError]` | 执行 COPY FROM 语句 |
| `batch` | `(String, Array[Value]) -> Result[Int64, DBError]` | 执行批处理语句 |
| `execlastid` | `(String, Array[Value]) -> Result[Int64, DBError]` | 执行语句并返回最后插入行 ID |

### 构造函数

```moonbit
pub fn DB::new(
  exec_fn: (String, Array[Value]) -> Result[Int64, DBError],
  execrows_fn: (String, Array[Value]) -> Result[Int64, DBError],
  query_fn: (String, Array[Value]) -> Result[RowIter, DBError],
  query_row_fn: (String, Array[Value]) -> Result[Row, DBError],
  begin_fn: () -> Result[Transaction, DBError],
  copyfrom_fn: (String, Array[Value]) -> Result[Int64, DBError],
  batch_fn: (String, Array[Value]) -> Result[Int64, DBError],
  execlastid_fn: (String, Array[Value]) -> Result[Int64, DBError],
) -> DB
```

---

## Transaction

```moonbit
pub struct Transaction {
  // Driver-supplied closures (constructed via Transaction::new)
}
```

事务句柄。与 `DB` 共享相同的 `exec`/`execrows`/`query`/`query_row` 接口，并额外提供 `commit` 与 `rollback`。注意：`Transaction` **不支持** `copyfrom`、`batch` 和 `execlastid` — 生成代码仅会为这些命令产生 `db: DB` 变体（依据 `supports_transaction()` 逻辑）。

### 方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `exec` | `(String, Array[Value]) -> Result[Int64, DBError]` | 在事务内执行 |
| `execrows` | `(String, Array[Value]) -> Result[Int64, DBError]` | 在事务内执行 |
| `query` | `(String, Array[Value]) -> Result[RowIter, DBError]` | 在事务内查询 |
| `query_row` | `(String, Array[Value]) -> Result[Row, DBError]` | 在事务内查询单行 |
| `commit` | `() -> Result[Unit, DBError]` | 提交事务 |
| `rollback` | `() -> Result[Unit, DBError]` | 回滚事务 |

### 构造函数

```moonbit
pub fn Transaction::new(
  exec_fn: (...) -> Result[Int64, DBError],
  execrows_fn: (...) -> Result[Int64, DBError],
  query_fn: (...) -> Result[RowIter, DBError],
  query_row_fn: (...) -> Result[Row, DBError],
  commit_fn: () -> Result[Unit, DBError],
  rollback_fn: () -> Result[Unit, DBError],
) -> Transaction
```

---

## Row

```moonbit
pub struct Row {
  get_fn : (Int) -> String
  null_mask : Array[Bool]
  col_names : Array[String]
  num_cols : Int
}
```

单行查询结果。提供基于索引（从 0 开始）的列访问（含边界检查）以及按列名查找。

### 构造函数

| 构造函数 | 说明 |
|----------|------|
| `Row::new(get_fn, null_mask)` | 基础构造函数（`col_names` 为空，`num_cols` 取自 `null_mask`） |
| `Row::new_with_names(get_fn, null_mask, col_names)` | 带列名的构造函数，支持按名称查找 |

### 原始访问与元数据

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `get(index)` | `String` | 索引处的原始字符串值 |
| `is_null(index)` | `Bool` | 检查索引处列是否为 NULL |
| `column_count()` | `Int` | 本行的列数 |
| `check_bounds(index)` | `Result[Int, DBError]` | 校验索引是否在边界内；越界 → `Err(TypeError(...))` |
| `index_of(name)` | `Result[Int, DBError]` | 按列名查找索引（O(n) 扫描）；未找到 → `Err(ColumnNotFound(...))` |

### 类型化非空 Getter

各方法返回 `Result[T, DBError]`。所有 getter 内部会先调用 `check_bounds(index)`：

| 方法 | 返回类型 | 解析方式 |
|------|----------|----------|
| `get_int64(index)` | `Result[Int64, DBError]` | 整数字符串 |
| `get_string(index)` | `Result[String, DBError]` | 原始字符串 |
| `get_bool(index)` | `Result[Bool, DBError]` | `"true"`/`"false"` |
| `get_double(index)` | `Result[Double, DBError]` | 浮点字符串 |
| `get_bytes(index)` | `Result[Array[Byte], DBError]` | 从字符串构建字节数组（非 ASCII 安全） |
| `get_date(index)` | `Result[Date, DBError]` | 日期字符串包装 |
| `get_datetime(index)` | `Result[DateTime, DBError]` | DateTime 字符串包装 |
| `get_json(index)` | `Result[Json, DBError]` | JSON 字符串 → `@json.parse` |
| `get_decimal(index)` | `Result[Decimal, DBError]` | 数值字符串包装 |
| `get_uuid(index)` | `Result[Uuid, DBError]` | UUID 字符串包装 |
| `get_duration(index)` | `Result[Duration, DBError]` | 区间（微秒） |
| `get_time(index)` | `Result[Time, DBError]` | 时间（可变精度小数秒，0–6 位） |
| `get_timetz(index)` | `Result[TimeTZ, DBError]` | 带时区偏移的时间 |
| `get_ipaddr(index)` | `Result[IpAddr, DBError]` | INET/CIDR 字符串包装 |

### 类型化可空 Getter

各方法返回 `Result[Option[T], DBError]`。NULL 性由 `null_mask` 决定，而非空字符串：

| 方法 | 返回类型 |
|------|----------|
| `get_nullable_int64(index)` | `Result[Option[Int64], DBError]` |
| `get_nullable_string(index)` | `Result[Option[String], DBError]` |
| `get_nullable_bool(index)` | `Result[Option[Bool], DBError]` |
| `get_nullable_double(index)` | `Result[Option[Double], DBError]` |
| `get_nullable_bytes(index)` | `Result[Option[Array[Byte]], DBError]` |
| `get_nullable_date(index)` | `Result[Option[Date], DBError]` |
| `get_nullable_datetime(index)` | `Result[Option[DateTime], DBError]` |
| `get_nullable_json(index)` | `Result[Option[Json], DBError]` |
| `get_nullable_decimal(index)` | `Result[Option[Decimal], DBError]` |
| `get_nullable_uuid(index)` | `Result[Option[Uuid], DBError]` |
| `get_nullable_duration(index)` | `Result[Option[Duration], DBError]` |
| `get_nullable_time(index)` | `Result[Option[Time], DBError]` |
| `get_nullable_timetz(index)` | `Result[Option[TimeTZ], DBError]` |
| `get_nullable_ipaddr(index)` | `Result[Option[IpAddr], DBError]` |

### 数组解码器

用于 PostgreSQL 数组列（如 `TEXT[]`、`INT[]`），从 JSON 数组表示解码：

| 方法 | 返回类型 |
|------|----------|
| `decode_array_string(index)` | `Result[Array[String], DBError]` |
| `decode_array_int64(index)` | `Result[Array[Int64], DBError]` |
| `decode_array_bool(index)` | `Result[Array[Bool], DBError]` |
| `decode_array_double(index)` | `Result[Array[Double], DBError]` |
| `decode_array_date(index)` | `Result[Array[Date], DBError]` |
| `decode_array_datetime(index)` | `Result[Array[DateTime], DBError]` |
| `decode_array_decimal(index)` | `Result[Array[Decimal], DBError]` |
| `decode_array_bytes(index)` | `Result[Array[Array[Byte]], DBError]` |

### 可空数组解码器

各方法返回 `Result[Option[Array[T]], DBError]` — 列为 NULL 时返回 `None`：

| 方法 | 返回类型 |
|------|----------|
| `decode_nullable_array_string(index)` | `Result[Option[Array[String]], DBError]` |
| `decode_nullable_array_int64(index)` | `Result[Option[Array[Int64]], DBError]` |
| `decode_nullable_array_bool(index)` | `Result[Option[Array[Bool]], DBError]` |
| `decode_nullable_array_double(index)` | `Result[Option[Array[Double]], DBError]` |
| `decode_nullable_array_date(index)` | `Result[Option[Array[Date]], DBError]` |
| `decode_nullable_array_datetime(index)` | `Result[Option[Array[DateTime]], DBError]` |
| `decode_nullable_array_decimal(index)` | `Result[Option[Array[Decimal]], DBError]` |
| `decode_nullable_array_bytes(index)` | `Result[Option[Array[Array[Byte]]], DBError]` |

---

## RowIter

```moonbit
pub struct RowIter {
  next_fn : () -> Result[Option[Row], DBError]
}
```

`:many` 查询结果的流式行迭代器。

### 方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `next` | `() -> Result[Option[Row], DBError]` | 前进到下一行；耗尽时返回 `Ok(None)` |
| `collect` | `() -> Result[Array[Row], DBError]` | 收集所有行（最多 10,000；委托给 `collect_limited`） |
| `collect_limited` | `(Int) -> Result[Array[Row], DBError]` | 最多收集 `max_rows` 行；超出 → `Err(TooManyRows(count, query))` |

典型的生成 `:many` 函数模式：

```moonbit
pub fn query_users_list(db: DB) -> Result[Array[Users], DBError] {
  let iter = db.query("SELECT * FROM users", [])?
  let rows = iter.collect()?
  let mut result: Array[Users] = []
  for row in rows {
    result.push(Users::decode(row)?)
  }
  Ok(result)
}
```

---

## Value 包装类型

### Date / DateTime

```moonbit
pub struct Date { inner: String }
pub struct DateTime { inner: String }
```

SQL 日期/时间戳字符串的轻量包装。

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `Date::new(value)` | `Date` | 从字符串构造 |
| `Date::to_string()` | `String` | 返回内部值 |
| `DateTime::new(value)` | `DateTime` | 从字符串构造 |
| `DateTime::to_string()` | `String` | 返回内部值 |

### Decimal / Uuid / IpAddr

```moonbit
pub struct Decimal { inner: String }
pub struct Uuid { inner: String }
pub struct IpAddr { inner: String }
```

保留完整精度/格式的字符串包装。

| 结构体 | 构造函数 | 访问器 |
|--------|----------|--------|
| `Decimal` | `Decimal::new(value: String)` | `.to_string()` |
| `Uuid` | `Uuid::new(value: String)` | `.to_string()` |
| `IpAddr` | `IpAddr::new(value: String)` | `.to_string()` |

### Duration

```moonbit
pub struct Duration { microseconds: Int64 }
```

以总微秒表示的 SQL INTERVAL。

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `Duration::new(microseconds)` | `Duration` | 从 Int64 构造 |
| `Duration::to_int64()` | `Int64` | 返回微秒数 |

### Time

```moonbit
pub struct Time { hour: Int, min: Int, sec: Int, micros: Int }
```

分解为各分量的 SQL TIME 值。可变精度小数秒（0–6 位）由 `Row::get_time` 规范化。

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `Time::new(hour, min, sec, micros)` | `Time` | 从分量构造 |

### TimeTZ

```moonbit
pub struct TimeTZ { hour: Int, min: Int, sec: Int, micros: Int, tz_offset: Int }
```

SQL TIMETZ 值 — 带时区偏移的时间，偏移以秒为单位（例如 +8h = `28800`，-5h = `-18000`）。

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `TimeTZ::new(hour, min, sec, micros, tz_offset)` | `TimeTZ` | 从分量构造 |

### ExecResult

```moonbit
pub struct ExecResult { last_insert_id: Int64, rows_affected: Int64 }
```

`:execresult` 查询的双值结果（解决 GAP-2）。

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `ExecResult::new(last_insert_id, rows_affected)` | `ExecResult` | 构造 |

---

## MockDB

```moonbit
pub struct MockDB {
  exec_ok: Result[Int64, DBError]
  execrows_ok: Result[Int64, DBError]
  query_ok: Result[RowIter, DBError]
  query_row_ok: Result[Row, DBError]
  copyfrom_ok: Result[Int64, DBError]
  batch_ok: Result[Int64, DBError]
  execlastid_ok: Result[Int64, DBError]
  tx_fn: Option[() -> Result[Transaction, DBError]]
}
```

用于测试生成查询函数的预设 mock 数据库。

### 构造函数与构建器

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `MockDB::new(...)` | `MockDB` | 完整构造函数，包含全部 8 个预设结果 |
| `MockDB::default_ok()` | `MockDB` | 快捷构造：所有操作 → `Ok(0L)` / 空结果；`begin` → `Err` |
| `MockDB::build(self)` | `DB` | 转换为 `DB` 实例 |

### MockDBBuilder (P1-042)

流式构建器 API，支持按 SQL 精确匹配、重复检测以及可配置的事务工厂：

```moonbit
pub struct MockDBBuilder { ... }
```

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `MockDBBuilder::new()` | `MockDBBuilder` | 创建 builder，默认全部为 Ok |
| `.register_exec(sql, result)` | `MockDBBuilder` | 为精确 SQL 匹配注册 exec 结果 |
| `.register_execrows(sql, result)` | `MockDBBuilder` | 注册 execrows 结果 |
| `.register_query(sql, result)` | `MockDBBuilder` | 注册 query 结果 |
| `.register_query_row(sql, result)` | `MockDBBuilder` | 注册 query_row 结果 |
| `.register_copyfrom(sql, result)` | `MockDBBuilder` | 注册 copyfrom 结果 |
| `.register_batch(sql, result)` | `MockDBBuilder` | 注册 batch 结果 |
| `.register_execlastid(sql, result)` | `MockDBBuilder` | 注册 execlastid 结果 |
| `.with_tx(f)` | `MockDBBuilder` | 设置事务工厂 |
| `.strict(enabled)` | `MockDBBuilder` | 为 `true` 时，未注册的 SQL 返回 `Err` 而非默认 `Ok` |
| `.build()` | `DB` | 构建带已注册模式的 DB |

未匹配的 SQL 会回退到各操作的默认结果（`Ok(0L)` / 空结果），除非通过 `.strict(true)` 启用**严格模式**，此时未注册的 SQL 返回 `Err(QueryError(...))`。重复的 SQL 注册会 abort。

示例：

```moonbit
let db = MockDBBuilder::new()
  .strict(true)
  .register_query_row("SELECT * FROM users WHERE id = $1", Ok(row))
  .build()
```

---

## 类型映射参考

| PostgreSQL 列类型 | MoonBit 类型 | Row Getter |
|-------------------|-------------|------------|
| `BIGSERIAL`, `BIGINT`, `INT8` | `Int64` | `get_int64` |
| `INT`, `INT4`, `SERIAL` | `Int` | `get_int64` (cast) |
| `INT2`, `SMALLINT` | `Int` | `get_int64` (cast) |
| `TEXT`, `VARCHAR`, `CHAR` | `String` | `get_string` |
| `BOOLEAN`, `BOOL` | `Bool` | `get_bool` |
| `DOUBLE`, `FLOAT8` | `Double` | `get_double` |
| `FLOAT4`, `REAL` | `Double` | `get_double` |
| `NUMERIC`, `DECIMAL` | `Decimal` | `get_decimal` |
| `UUID` | `Uuid` | `get_uuid` |
| `INTERVAL` | `Duration` | `get_duration` |
| `TIME` | `Time` | `get_time` |
| `TIMETZ` | `TimeTZ` | `get_timetz` |
| `DATE` | `Date` | `get_date` |
| `TIMESTAMP`, `TIMESTAMPTZ` | `DateTime` | `get_datetime` |
| `JSON`, `JSONB` | `Json` | `get_json` |
| `BYTEA` | `Array[Byte]` | `get_bytes` |
| `INET`, `CIDR` | `IpAddr` | `get_ipaddr` |
| 数组类型（如 `TEXT[]`） | `Array[T]` | `decode_array_*` |
| 任意可空列 | `Option[T]` | `get_nullable_*` |

> **插件 codegen：** 未知的 PostgreSQL 类型会在 `sqlc generate` 阶段失败，除非通过 `override_<pgtype>=<MoonBitType>` 覆盖。上述 runtime getter 适用于插件成功映射的列。

---

## 相关文档

| 资源 | 链接 |
|------|------|
| 快速开始 | [quickstart.md](quickstart.md) · [中文](quickstart.zh.md) · [日本語](quickstart.ja.md) |
| 示例 | [examples/README.md](../examples/README.md) · [中文](../examples/README.zh.md) · [日本語](../examples/README.ja.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |
