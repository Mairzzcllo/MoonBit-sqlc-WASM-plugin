<p align="center">
  <a href="README.md">English</a>
  ·
  <a href="README.zh.md">中文</a>
  ·
  <a href="README.ja.md"><b>日本語</b></a>
</p>

# サンプル

**ドキュメント：** [クイックスタート](../docs/quickstart.ja.md) · [Runtime API](../docs/runtime-api.ja.md) · [README](../README.ja.md) · [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) · [GitHub](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin)

---

## users — PostgreSQL 完全サンプル

SQL から MoonBit コードを生成する最小再現例。パス：`examples/users/`。

### ファイル

| ファイル | 説明 |
|----------|------|
| `schema.sql` | `users` テーブル DDL |
| `query.sql` | sqlc アノテーションクエリ（`:one` / `:many` / `:exec`） |
| `sqlc.yaml` | `_build/wasm/.../plugin.wasm` を参照（debug デフォルト） |
| `moon.pkg.example` | 業務プロジェクト統合用 runtime テンプレート |
| `types.mbt` | `sqlc generate` 出力（gitignore） |
| `queries.mbt` | `sqlc generate` 出力（gitignore） |

### クエリアノテーション

| アノテーション | 動作 | 例 |
|----------------|------|-----|
| `:one` | 単一行 | `GetUser` |
| `:many` | 複数行 | `ListUsers` |
| `:exec` | 行なし | `DeleteUser` |

---

## 再現手順

### ワンライナー（推奨）

```bash
# リポジトリルート
bash scripts/run-example.sh --release
```

```powershell
# Windows
.\scripts\run-example.ps1 -Release
```

### 手動

```bash
moon build --target wasm --release
cd examples/users
sqlc generate
ls types.mbt queries.mbt
```

> E2E / validate は build 後に `sha256` を sync。**platform-specific hash を git にコミットしない**。commit 態は debug url active + `sha256: ""`。

---

## 業務プロジェクトへの統合（mooncakes.io）

本ディレクトリに `moon.pkg` は**ありません**。独立 MoonBit プロジェクトへ統合する場合：

### 1. runtime インストール

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

| 項目 | 値 |
|------|-----|
| パッケージ | `Mairzzcllo/moonbit_sqlc_plugin` |
| バージョン | **0.1.4** |

### 2. 生成コードをコピー

`types.mbt`、`queries.mbt` をプロジェクトにコピー。

### 3. moon.pkg 設定

[`moon.pkg.example`](users/moon.pkg.example) を参照：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

### 4. コンパイル確認

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

### 5. スモークテスト（任意）

**プラグイン repo** ルートで：

```bash
bash scripts/setup-mooncakes.sh --version 0.1.4
```

---

## sqlc.yaml

commit 態の例：

```yaml
version: "2"
plugins:
  - name: "moonbit"
    wasm:
      url: "file://../../_build/wasm/debug/build/plugin/plugin.wasm"
      sha256: ""
sql:
  - schema: "schema.sql"
    queries: "query.sql"
    engine: "postgresql"
    codegen:
      - out: "."
        plugin: "moonbit"
        options:
          package_name: users
```

- **WASM プラグイン**：ローカル `_build/` または [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases)
- **Runtime**：[mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) の `moon add`

---

## 生成コード例

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

テストは `MockDB` / `MockDBBuilder`（`.strict(true)` 含む）— [Runtime API — MockDB](../docs/runtime-api.ja.md#mockdb)。

---

## 関連ドキュメント

| リソース | リンク |
|----------|--------|
| クイックスタート | [quickstart.ja.md](../docs/quickstart.ja.md) · [English](../docs/quickstart.md) · [中文](../docs/quickstart.zh.md) |
| Runtime API | [runtime-api.ja.md](../docs/runtime-api.ja.md) · [English](../docs/runtime-api.md) · [中文](../docs/runtime-api.zh.md) |
| README | [README.ja.md](../README.ja.md) · [English](../README.md) · [中文](../README.zh.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |
