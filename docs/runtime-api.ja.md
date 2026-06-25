<p align="center">
  <a href="runtime-api.md">English</a>
  ·
  <a href="runtime-api.zh.md">中文</a>
  ·
  <a href="runtime-api.ja.md"><b>日本語</b></a>
</p>

# Runtime API リファレンス

`runtime` パッケージは、生成されたクエリコードが依存する型と関数を提供します。

**ドキュメント：** [クイックスタート](quickstart.ja.md) · [README](../README.ja.md) · [Examples](../examples/README.ja.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## mooncakes.io からのインストール

| 項目 | 値 |
|------|-----|
| パッケージ | `Mairzzcllo/moonbit_sqlc_plugin` |
| バージョン | **0.1.6** |
| インポートパス | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| ドキュメント | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| ターゲット | `wasm-gc` |

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.6
moon check --target wasm-gc
```

`moon.pkg` に追加：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

生成ファイルにはすでに `import "Mairzzcllo/moonbit_sqlc_plugin/runtime"` が含まれています。完全なセットアップは [クイックスタート — パス A](quickstart.ja.md#path-a--install-runtime-from-mooncakesio) を参照してください。

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

すべてのデータベース操作のエラー型。runtime の関数はすべて `Result[T, DBError]` を返します。

| バリアント | 意味 |
|-----------|------|
| `ConnectionError(msg)` | 接続またはトランスポートの失敗 |
| `QueryError(msg)` | SQL 実行エラー |
| `TypeError(msg)` | デコード時の型不一致 |
| `NoRows` | `:one` クエリで行が返されなかった |
| `ColumnNotFound(name)` | 名前ベースの検索で列が見つからない |
| `TooManyRows(count, query)` | `:one` クエリが複数行を返した、または `collect_limited` の上限超過 |

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

SQL クエリバインディング用の型付きパラメータ値。

| バリアント | SQL 型 | 用途 |
|-----------|--------|------|
| `Null` | `NULL` | 省略パラメータ / NULL 値 |
| `Int64(n)` | `BIGINT`, `INT`, `SERIAL` | 整数パラメータ |
| `String(s)` | `TEXT`, `VARCHAR` | 文字列パラメータ |
| `Bool(b)` | `BOOLEAN`, `BOOL` | ブールパラメータ |
| `Double(d)` | `FLOAT8`, `DOUBLE` | 浮動小数点パラメータ |
| `Bytes(b)` | `BYTEA` | バイナリパラメータ |
| `Date(d)` | `DATE` | 日付パラメータ |
| `DateTime(dt)` | `TIMESTAMP`, `TIMESTAMPTZ` | タイムスタンプパラメータ |
| `JsonValue(j)` | `JSON`, `JSONB` | JSON パラメータ |
| `Decimal(d)` | `NUMERIC`, `DECIMAL` | 正確な数値パラメータ |
| `Uuid(u)` | `UUID` | UUID パラメータ |
| `Duration(d)` | `INTERVAL` | インターバルパラメータ（マイクロ秒） |
| `Time(t)` | `TIME` | 時刻パラメータ（時、分、秒、マイクロ秒） |
| `TimeTZ(tz)` | `TIMETZ` | タイムゾーンオフセット付き時刻 |
| `IpAddr(ip)` | `INET`, `CIDR` | ネットワークアドレスパラメータ |

---

## DB

```moonbit
pub struct DB {
  // Driver-supplied closures (constructed via DB::new)
}
```

メインのデータベースハンドル。生成されたクエリ関数は最初の引数として `DB` を受け取ります。

### メソッド

| メソッド | シグネチャ | 説明 |
|---------|-----------|------|
| `exec` | `(String, Array[Value]) -> Result[Int64, DBError]` | 影響行数を返す SQL 実行 |
| `execrows` | `(String, Array[Value]) -> Result[Int64, DBError]` | 影響行数を返す SQL 実行（`:execrows` クエリのエイリアス） |
| `query` | `(String, Array[Value]) -> Result[RowIter, DBError]` | 行イテレータを返すクエリ実行（`:many`） |
| `query_row` | `(String, Array[Value]) -> Result[Row, DBError]` | 単一行を返すクエリ実行（`:one`） |
| `begin` | `() -> Result[Transaction, DBError]` | 新しいトランザクションを開始 |
| `copyfrom` | `(String, Array[Value]) -> Result[Int64, DBError]` | COPY FROM 文を実行 |
| `batch` | `(String, Array[Value]) -> Result[Int64, DBError]` | バッチ文を実行 |
| `execlastid` | `(String, Array[Value]) -> Result[Int64, DBError]` | 最終挿入行 ID を返す文を実行 |

### コンストラクタ

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

トランザクションハンドル。`DB` と同じ `exec`/`execrows`/`query`/`query_row` インターフェースを共有し、`commit` と `rollback` を追加提供します。注意：`Transaction` では `copyfrom`、`batch`、`execlastid` は**利用不可** — 生成コードはこれらのコマンドに対して `db: DB` バリアントのみを生成します（`supports_transaction()` ロジックに従う）。

### メソッド

| メソッド | シグネチャ | 説明 |
|---------|-----------|------|
| `exec` | `(String, Array[Value]) -> Result[Int64, DBError]` | トランザクション内で実行 |
| `execrows` | `(String, Array[Value]) -> Result[Int64, DBError]` | トランザクション内で実行 |
| `query` | `(String, Array[Value]) -> Result[RowIter, DBError]` | トランザクション内でクエリ |
| `query_row` | `(String, Array[Value]) -> Result[Row, DBError]` | トランザクション内で単一行クエリ |
| `commit` | `() -> Result[Unit, DBError]` | トランザクションをコミット |
| `rollback` | `() -> Result[Unit, DBError]` | トランザクションをロールバック |

### コンストラクタ

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

クエリ結果の単一行。境界チェック付きのインデックスベース（0 始まり）列アクセスと、名前ベースの検索を提供します。

### コンストラクタ

| コンストラクタ | 説明 |
|---------------|------|
| `Row::new(get_fn, null_mask)` | 基本コンストラクタ（`col_names` 空、`num_cols` は `null_mask` から） |
| `Row::new_with_names(get_fn, null_mask, col_names)` | 名前ベース検索用の列名付きコンストラクタ |

### 生アクセスとメタデータ

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `get(index)` | `String` | インデックス位置の生文字列値 |
| `is_null(index)` | `Bool` | インデックス位置の列が NULL か確認 |
| `column_count()` | `Int` | この行の列数 |
| `check_bounds(index)` | `Result[Int, DBError]` | インデックスが境界内か検証；範囲外 → `Err(TypeError(...))` |
| `index_of(name)` | `Result[Int, DBError]` | 列名でインデックスを検索（O(n) スキャン）；未検出 → `Err(ColumnNotFound(...))` |

### 型付き非 NULL Getter

各メソッドは `Result[T, DBError]` を返します。すべての getter は内部で最初に `check_bounds(index)` を呼び出します：

| メソッド | 戻り値 | 解析 |
|---------|--------|------|
| `get_int64(index)` | `Result[Int64, DBError]` | 整数文字列 |
| `get_string(index)` | `Result[String, DBError]` | 生文字列 |
| `get_bool(index)` | `Result[Bool, DBError]` | `"true"`/`"false"` |
| `get_double(index)` | `Result[Double, DBError]` | 浮動小数点文字列 |
| `get_bytes(index)` | `Result[Array[Byte], DBError]` | 文字列からバイト配列（非 ASCII 安全） |
| `get_date(index)` | `Result[Date, DBError]` | 日付文字列ラッパー |
| `get_datetime(index)` | `Result[DateTime, DBError]` | DateTime 文字列ラッパー |
| `get_json(index)` | `Result[Json, DBError]` | JSON 文字列 → `@json.parse` |
| `get_decimal(index)` | `Result[Decimal, DBError]` | 数値文字列ラッパー |
| `get_uuid(index)` | `Result[Uuid, DBError]` | UUID 文字列ラッパー |
| `get_duration(index)` | `Result[Duration, DBError]` | マイクロ秒単位のインターバル |
| `get_time(index)` | `Result[Time, DBError]` | 可変精度小数秒（0–6 桁）の時刻 |
| `get_timetz(index)` | `Result[TimeTZ, DBError]` | タイムゾーンオフセット付き時刻 |
| `get_ipaddr(index)` | `Result[IpAddr, DBError]` | INET/CIDR 文字列ラッパー |

### 型付き NULL 許容 Getter

各メソッドは `Result[Option[T], DBError]` を返します。NULL 性は空文字列ではなく `null_mask` で決定されます：

| メソッド | 戻り値 |
|---------|--------|
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

### 配列デコーダ

PostgreSQL 配列列（例：`TEXT[]`、`INT[]`）用。JSON 配列表現からデコード：

| メソッド | 戻り値 |
|---------|--------|
| `decode_array_string(index)` | `Result[Array[String], DBError]` |
| `decode_array_int64(index)` | `Result[Array[Int64], DBError]` |
| `decode_array_bool(index)` | `Result[Array[Bool], DBError]` |
| `decode_array_double(index)` | `Result[Array[Double], DBError]` |
| `decode_array_date(index)` | `Result[Array[Date], DBError]` |
| `decode_array_datetime(index)` | `Result[Array[DateTime], DBError]` |
| `decode_array_decimal(index)` | `Result[Array[Decimal], DBError]` |
| `decode_array_bytes(index)` | `Result[Array[Array[Byte]], DBError]` |

### NULL 許容配列デコーダ

各メソッドは `Result[Option[Array[T]], DBError]` を返します — 列が NULL の場合は `None`：

| メソッド | 戻り値 |
|---------|--------|
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

`:many` クエリ結果のストリーミング行イテレータ。

### メソッド

| メソッド | シグネチャ | 説明 |
|---------|-----------|------|
| `next` | `() -> Result[Option[Row], DBError]` | 次の行へ進む；終了時は `Ok(None)` |
| `collect` | `() -> Result[Array[Row], DBError]` | すべての行を収集（最大 10,000；`collect_limited` に委譲） |
| `collect_limited` | `(Int) -> Result[Array[Row], DBError]` | 最大 `max_rows` 行まで収集；超過 → `Err(TooManyRows(count, query))` |

典型的な生成 `:many` 関数パターン：

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

## Value ラッパー

### Date / DateTime

```moonbit
pub struct Date { inner: String }
pub struct DateTime { inner: String }
```

SQL 日付/タイムスタンプ文字列の薄いラッパー。

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `Date::new(value)` | `Date` | 文字列から構築 |
| `Date::to_string()` | `String` | 内部値を返す |
| `DateTime::new(value)` | `DateTime` | 文字列から構築 |
| `DateTime::to_string()` | `String` | 内部値を返す |

### Decimal / Uuid / IpAddr

```moonbit
pub struct Decimal { inner: String }
pub struct Uuid { inner: String }
pub struct IpAddr { inner: String }
```

完全な精度/書式を保持する文字列ラッパー。

| 構造体 | コンストラクタ | アクセサ |
|--------|---------------|---------|
| `Decimal` | `Decimal::new(value: String)` | `.to_string()` |
| `Uuid` | `Uuid::new(value: String)` | `.to_string()` |
| `IpAddr` | `IpAddr::new(value: String)` | `.to_string()` |

### Duration

```moonbit
pub struct Duration { microseconds: Int64 }
```

総マイクロ秒で表現される SQL INTERVAL。

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `Duration::new(microseconds)` | `Duration` | Int64 から構築 |
| `Duration::to_int64()` | `Int64` | マイクロ秒を返す |

### Time

```moonbit
pub struct Time { hour: Int, min: Int, sec: Int, micros: Int }
```

コンポーネントに分解された SQL TIME 値。可変精度小数秒（0–6 桁）は `Row::get_time` によって正規化されます。

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `Time::new(hour, min, sec, micros)` | `Time` | コンポーネントから構築 |

### TimeTZ

```moonbit
pub struct TimeTZ { hour: Int, min: Int, sec: Int, micros: Int, tz_offset: Int }
```

SQL TIMETZ 値 — 秒単位のタイムゾーンオフセット付き時刻（例：+8h = `28800`、-5h = `-18000`）。

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `TimeTZ::new(hour, min, sec, micros, tz_offset)` | `TimeTZ` | コンポーネントから構築 |

### ExecResult

```moonbit
pub struct ExecResult { last_insert_id: Int64, rows_affected: Int64 }
```

`:execresult` クエリの二値結果（GAP-2 を解決）。

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `ExecResult::new(last_insert_id, rows_affected)` | `ExecResult` | 構築 |

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

生成されたクエリ関数をテストするためのプリセット mock データベース。

### コンストラクタとビルダー

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `MockDB::new(...)` | `MockDB` | 8 つのプリセット結果すべてを含む完全コンストラクタ |
| `MockDB::default_ok()` | `MockDB` | クイックコンストラクタ：すべての操作 → `Ok(0L)` / 空結果；`begin` → `Err` |
| `MockDB::build(self)` | `DB` | `DB` インスタンスに変換 |

### MockDBBuilder (P1-042)

SQL 完全一致、重複検出、設定可能なトランザクションファクトリを備えた Fluent ビルダー API：

```moonbit
pub struct MockDBBuilder { ... }
```

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `MockDBBuilder::new()` | `MockDBBuilder` | すべて Ok デフォルトのビルダーを作成 |
| `.register_exec(sql, result)` | `MockDBBuilder` | 完全一致 SQL 用 exec 結果を登録 |
| `.register_execrows(sql, result)` | `MockDBBuilder` | execrows 結果を登録 |
| `.register_query(sql, result)` | `MockDBBuilder` | query 結果を登録 |
| `.register_query_row(sql, result)` | `MockDBBuilder` | query_row 結果を登録 |
| `.register_copyfrom(sql, result)` | `MockDBBuilder` | copyfrom 結果を登録 |
| `.register_batch(sql, result)` | `MockDBBuilder` | batch 結果を登録 |
| `.register_execlastid(sql, result)` | `MockDBBuilder` | execlastid 結果を登録 |
| `.with_tx(f)` | `MockDBBuilder` | トランザクションファクトリを設定 |
| `.strict(enabled)` | `MockDBBuilder` | `true` の場合、未登録 SQL はデフォルト `Ok` ではなく `Err` を返す |
| `.build()` | `DB` | 登録パターン付き DB を構築 |

一致しない SQL は各操作のデフォルト（`Ok(0L)` / 空結果）にフォールスルーします。**strict モード**（`.strict(true)`）を有効にした場合、未登録 SQL は `Err(QueryError(...))` を返します。重複 SQL 登録は abort します。

例：

```moonbit
let db = MockDBBuilder::new()
  .strict(true)
  .register_query_row("SELECT * FROM users WHERE id = $1", Ok(row))
  .build()
```

---

## 型マッピングリファレンス

| PostgreSQL 列型 | MoonBit 型 | Row Getter |
|----------------|------------|------------|
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
| 配列型（例：`TEXT[]`） | `Array[T]` | `decode_array_*` |
| 任意の NULL 許容列 | `Option[T]` | `get_nullable_*` |

> **プラグイン codegen：** 未知の PostgreSQL 型は、`override_<pgtype>=<MoonBitType>` で上書きしない限り `sqlc generate` 時に失敗します。上記の runtime getter は、プラグインが正常にマッピングした列に適用されます。

---

## 関連ドキュメント

| リソース | リンク |
|---------|--------|
| クイックスタート | [quickstart.md](quickstart.md) · [中文](quickstart.zh.md) · [日本語](quickstart.ja.md) |
| Examples | [examples/README.md](../examples/README.md) · [中文](../examples/README.zh.md) · [日本語](../examples/README.ja.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |
