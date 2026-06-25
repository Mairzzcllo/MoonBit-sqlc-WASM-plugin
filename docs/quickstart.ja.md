<p align="center">
  <a href="quickstart.md">English</a>
  ·
  <a href="quickstart.zh.md">中文</a>
  ·
  <a href="quickstart.ja.md"><b>日本語</b></a>
</p>

# クイックスタート

> SQL から型安全な MoonBit データベースコードを生成。

**ドキュメント：** [README](../README.ja.md) · [Runtime API](runtime-api.ja.md) · [サンプル](../examples/README.ja.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## 必要環境

| ツール | バージョン | 説明 |
|--------|------------|------|
| [MoonBit](https://www.moonbitlang.com/download/) | ≥ 0.1.20260522 | ビルド、テスト、mooncakes |
| [sqlc](https://sqlc.dev) | ≥ v1.27.0 | 検証済み v1.31.1 |

PostgreSQL は sqlc による `schema.sql` / `query.sql` 検証にのみ使用。生成コードは DB に接続しません。

---

## パスの選択

| パス | 対象 | 必要なもの |
|------|------|------------|
| **A — mooncakes.io** | 生成コードをアプリで使用 | `moon add` のみ（プラグイン repo clone 不要） |
| **B — プラグイン repo** | WASM ビルド、サンプル実行 | 本 repo の clone + sqlc |

---

## パス A — [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) から Runtime をインストール

生成コードは `Mairzzcllo/moonbit_sqlc_plugin/runtime` を import。**WASM プラグインは mooncakes にありません** — ローカルビルド（パス B）または [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases) から取得。

| 項目 | 値 |
|------|-----|
| パッケージ | `Mairzzcllo/moonbit_sqlc_plugin` |
| バージョン | **0.1.6** |
| Import | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| ターゲット | `wasm-gc`（`native` 不可） |

### 既存プロジェクト

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.6
moon check --target wasm-gc
```

`moon add` 後の `moon.mod.json`：

```json
{
  "deps": {
    "Mairzzcllo/moonbit_sqlc_plugin": "0.1.6"
  }
}
```

生成コードを置くパッケージの `moon.pkg`：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

`sqlc generate` の `types.mbt` + `queries.mbt` をコピー後：

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

> `moon add` は mooncakes.io から取得。**ログイン不要**。

### 新規プロジェクト

```bash
mkdir myapp && cd myapp
```

`moon.mod.json`：

```json
{
  "name": "your_org/myapp",
  "version": "0.1.0",
  "preferred-target": "wasm-gc",
  "supported-targets": "+wasm+wasm-gc"
}
```

`moon.pkg`：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime" @runtime,
}
```

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.6
# types.mbt + queries.mbt をコピー
moon check --target wasm-gc
```

スモークテスト（**本プラグイン repo** ルート）：

```bash
bash scripts/setup-mooncakes.sh --version 0.1.6
# Windows: .\scripts\setup-mooncakes.ps1 -Version 0.1.6
```

---

## パス B — プラグインビルドとコード生成

### 1. クローンと WASM ビルド

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon build --target wasm --release
```

| モード | パス |
|--------|------|
| release（推奨） | `_build/wasm/release/build/plugin/plugin.wasm` |
| debug | `_build/wasm/debug/build/plugin/plugin.wasm` |

ワンライナー：

```bash
bash scripts/run-example.sh --release
# Windows: .\scripts\run-example.ps1 -Release
```

### 2. sqlc.yaml 設定

sqlc v2 形式：

```yaml
version: "2"
plugins:
  - name: moonbit
    wasm:
      url: file://./_build/wasm/release/build/plugin/plugin.wasm
      sha256: ""
sql:
  - engine: postgresql
    schema: schema.sql
    queries: query.sql
    codegen:
      - out: gen
        plugin: moonbit
        options:
          package_name: myapp
```

> platform-specific `sha256` を git にコミットしない。ビルド後：

```powershell
.\scripts\sync-sqlc-sha256.ps1 `
  -WasmPath _build\wasm\release\build\plugin\plugin.wasm `
  -YamlPath examples\users\sqlc.yaml
```

### 3. SQL 作成

`schema.sql`：

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

`query.sql`：

```sql
-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: ListUsers :many
SELECT * FROM users ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

### 4. 生成

```bash
sqlc generate
```

出力：`types.mbt`（型と decode）+ `queries.mbt`（クエリ関数）。

### 5. runtime リンク（パス A）

上記**パス A** で mooncakes.io から `moon add`。

---

## 生成コードの使用

```moonbit
import "Mairzzcllo/moonbit_sqlc_plugin/runtime"

fn example(db: DB) {
  match query_get_user(db, 42L) {
    Ok(user) => println(user.name)
    Err(NoRows) => println("not found")
    Err(e) => println("error: \{e}")
  }
}
```

ドライバアダプタで `DB` を構築。テストは `MockDB`（[Runtime API — MockDB](runtime-api.ja.md#mockdb) 参照）。

---

## MockDB テスト

基本プリセット：

```moonbit
test "query with mock" {
  let row = Row::new(fn(i) {
    if i == 0 { "1" } else if i == 1 { "Alice" } else { "" }
  })
  let mock = MockDB::new(
    Ok(1L), Ok(1L),
    Ok(RowIter::new(fn() { Ok(None) })),
    Ok(row),
  )
  let db = mock.build()
  let _ = query_get_user(db, 1L)
}
```

**strict モード**（未登録 SQL → `Err`）：

```moonbit
test "strict mock rejects unknown SQL" {
  let db = MockDBBuilder::new()
    .strict(true)
    .register_query_row(
      "SELECT * FROM users WHERE id = $1",
      Ok(row),
    )
    .build()
}
```

---

## トランザクション

`:one` / `:many` / `:exec` / `:execrows` には `Transaction` オーバーロードあり。`:copyfrom`、`:batch`、`:execlastid` は `DB` のみ。

```moonbit
fn transfer(db: DB) -> Result[Unit, DBError] {
  let tx = db.begin()?
  let _ = tx.exec("UPDATE accounts SET balance = balance - $1 WHERE id = $2", [...])?
  let _ = tx.exec("UPDATE accounts SET balance = balance + $1 WHERE id = $2", [...])?
  tx.commit()
}
```

---

## Plugin Options

| オプション | デフォルト | 説明 |
|------------|------------|------|
| `package_name` | `"main"` | 生成パッケージ名 |
| `emit_sql_as_comment` | `true` | 関数上に SQL を埋め込み |
| `emit_json_tags` | `false` | `@json.tag(...)` を生成 |
| `emit_empty_slices` | `false` | 空 `:many` で `[]` |
| `emit_exact_table_names` | `false` | 表名を単数形化 |
| `strict_types` | `true` | 未知 PG 型で fail（`override_<type>=` 可） |

未知 query cmd（`:typo` 等）や不正 plugin option も codegen 時に stderr で fail。

---

## トラブルシューティング

| 現象 | 対処 |
|------|------|
| `moonbit_simd.h` 不足 | `--target wasm-gc` を使用 |
| `moon add` 失敗 | 先に `moon update` |
| WASM パス誤り | `_build/wasm/...` を使用 |
| sha256 不一致 | ローカル hash をコミットしない |
| 未知 PG 型 | `override_<pgtype>=<MoonBitType>` を追加 |

---

## 次のステップ

- [Runtime API](runtime-api.ja.md) — 型リファレンス
- [examples/users/](../examples/users/) — 完全サンプル
- [examples/README.ja.md](../examples/README.ja.md) — サンプル解説
- [README.ja.md](../README.ja.md) — プロジェクト概要
