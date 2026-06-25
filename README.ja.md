<p align="center">
  <img src="https://img.shields.io/badge/MoonBit-0.1.20260522-db6e2a?style=for-the-badge" alt="MoonBit"/>
  <img src="https://img.shields.io/badge/sqlc-v1_WASM_plugin-00b4d8?style=for-the-badge" alt="sqlc"/>
  <img src="https://img.shields.io/badge/mooncakes-0.1.4-orange?style=for-the-badge" alt="mooncakes"/>
  <img src="https://img.shields.io/badge/license-Apache--2.0-brightgreen?style=for-the-badge" alt="License"/>
</p>

<p align="center">
  <a href="README.md">English</a>
  ·
  <a href="README.zh.md">中文</a>
  ·
  <a href="README.ja.md"><b>日本語</b></a>
</p>

# MoonBit sqlc WASM Plugin

## 概要

**MoonBit sqlc WASM Plugin** は [sqlc](https://sqlc.dev) 用の [MoonBit](https://www.moonbitlang.com/) WASM コード生成プラグインです。`schema.sql` と `query.sql` を読み取り、コンパイル時に SQL と型を検証し、型安全な MoonBit ソース（`types.mbt` + `queries.mbt`）を生成します。

生成関数は `DB` / `Transaction` を直接受け取り、ORM やリフレクションは不要です。runtime は [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin) で公開されています。WASM プラグインはローカルビルドまたは [GitHub Releases](https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin/releases) から取得してください。

**現在の対応範囲：** PostgreSQL · sqlc v1.27+（検証済み v1.31.1）· MoonBit WASM (WASI preview1)

# 主な機能

## 型安全 Codegen

- クエリと decode パスで `Result[T, DBError]` を統一使用
- sqlc によるコンパイル時 SQL/型検証
- AST → Pretty Printer パイプライン（文字列連結禁止）

## 最小 Runtime

- `DB`、`Transaction`、`Row`、`RowIter`、`Value`、`MockDB`
- mooncakes パッケージ `Mairzzcllo/moonbit_sqlc_plugin/runtime` **0.1.4**
- 推奨ターゲット `wasm-gc` — 生成コードに native DB ドライバ不要

## プラグインとホストの分離

- WASM プラグインは codegen のみ担当
- WASI stdin/stdout protobuf I/O（インライン WAT FFI、外部 shim なし）
- デュアルファイル出力：`types.mbt` + `queries.mbt`

# クイックスタート

2 つのパス — 用途に合わせて選択：

| パス | 対象 | 必要なもの |
|------|------|------------|
| **A — mooncakes.io** | 生成された `types.mbt` / `queries.mbt` をアプリで使う | MoonBit + `moon add`（プラグイン repo の clone 不要） |
| **B — プラグイン repo** | WASM プラグインのビルド、サンプル実行、開発参加 | MoonBit + sqlc + 本リポジトリ |

---

## A. アプリ開発者 — [mooncakes.io](https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin)

生成コードは `Mairzzcllo/moonbit_sqlc_plugin/runtime` を import します。MoonBit パッケージレジストリからインストール — **WASM プラグイン本体は mooncakes にありません**。

| 項目 | 値 |
|------|-----|
| パッケージ | `Mairzzcllo/moonbit_sqlc_plugin` |
| バージョン | **0.1.4** |
| Import パス | `Mairzzcllo/moonbit_sqlc_plugin/runtime` |
| ドキュメント | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| ターゲット | `wasm-gc`（`native` は使用不可） |

### 既存プロジェクトに runtime を追加

MoonBit プロジェクトのルート（`moon.mod.json` あり）で：

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
moon check --target wasm-gc
```

`moon add` は `moon.mod.json` に書き込みます：

```json
{
  "deps": {
    "Mairzzcllo/moonbit_sqlc_plugin": "0.1.4"
  }
}
```

生成コードを置くパッケージの `moon.pkg` に：

```
import {
  "Mairzzcllo/moonbit_sqlc_plugin/runtime",
}
```

生成ファイル先頭には既に：

```moonbit
import "Mairzzcllo/moonbit_sqlc_plugin/runtime"
```

`sqlc generate` の `types.mbt` + `queries.mbt` をコピー後：

```bash
moon check --target wasm-gc
moon test --target wasm-gc
```

> `moon add` は [mooncakes.io](https://mooncakes.io/) から取得。**ログイン不要**（`moon publish` のみ要認証）。

### 最小プロジェクトを新規作成

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

続けて：

```bash
moon update
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4
# types.mbt + queries.mbt をコピー
moon check --target wasm-gc
```

### アップグレード / 削除

```bash
moon add Mairzzcllo/moonbit_sqlc_plugin@0.1.4   # アップグレード
moon remove Mairzzcllo/moonbit_sqlc_plugin       # 削除
```

スモークテスト（**本プラグイン repo** のルートで実行）：

```powershell
.\scripts\setup-mooncakes.ps1 -Version 0.1.4
```

```bash
bash scripts/setup-mooncakes.sh --version 0.1.4
```

---

## B. プラグイン開発者 — WASM ビルドとコード生成

### 必要環境

| ツール | バージョン | 説明 |
|--------|------------|------|
| [MoonBit](https://www.moonbitlang.com/download/) | ≥ 0.1.20260522 | ビルド、テスト、mooncakes |
| [sqlc](https://docs.sqlc.dev/en/latest/overview/install.html) | ≥ v1.27.0 | WASM プラグインの呼び出し |

PostgreSQL は sqlc による schema/query 検証にのみ使用されます。生成コード自体は DB に接続しません。

## リポジトリのクローン

```bash
git clone https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin.git
cd MoonBit-sqlc-WASM-plugin
moon check
moon test
```

## WASM プラグインのビルド

```bash
moon build --target wasm --release
```

| モード | パス |
|--------|------|
| release（推奨） | `_build/wasm/release/build/plugin/plugin.wasm` |
| debug | `_build/wasm/debug/build/plugin/plugin.wasm` |

## サンプルの実行

### Linux / macOS

```bash
chmod +x scripts/run-example.sh scripts/setup-mooncakes.sh
bash scripts/run-example.sh
bash scripts/run-example.sh --full --release --skip-build
```

### Windows（PowerShell）

```powershell
.\scripts\run-example.ps1
.\scripts\run-example.ps1 -Full -Release -SkipBuild
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
```

出力：`examples/users/types.mbt` と `examples/users/queries.mbt`。

## sqlc.yaml の設定と生成

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

```bash
sqlc generate
```

> **注意：** プラットフォーム固有の `sha256` を git にコミットしないでください。ローカルビルド後は `scripts/sync-sqlc-sha256.ps1` で同期します。

`sqlc generate` 後は **パス A** で mooncakes.io から runtime をインストール（`moon add`）。

# 使用例

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

`DB` はドライバアダプタ層で構築します。テストには `runtime/mock.mbt` の `MockDB` を使用できます。

# Plugin Options

| オプション | デフォルト | 説明 |
|------------|------------|------|
| `package_name` | `"main"` | 生成コードのパッケージ名 |
| `emit_sql_as_comment` | `true` | 関数上に SQL をコメントとして埋め込み |
| `emit_json_tags` | `false` | `@json.tag(...)` を生成 |
| `emit_empty_slices` | `false` | `:many` の空結果で `[]` を返す |
| `emit_exact_table_names` | `false` | `users` → `User`（単数形化） |
| `emit_methods_with_db_argument` | `false` | sqlc 互換；常に独立した `query_*` 関数を生成 |

詳細は [docs/quickstart.md](docs/quickstart.md)、[docs/runtime-api.md](docs/runtime-api.md) を参照。

# トラブルシューティング

| 現象 | 対処 |
|------|------|
| `moonbit_simd.h` が見つからない | `--target wasm-gc` を使用（`native` は不可） |
| `moon add` でパッケージが見つからない | 先に `moon update` で registry 索引を更新 |
| 生成コードに `DB` / `Row` がない | `moon.pkg` で `runtime` を import しているか確認 |
| WASM パスが見つからない | `target/` ではなく `_build/wasm/...` を使用 |
| sha256 不一致 | ローカル hash を git にコミットしない；`scripts/sync-sqlc-sha256.ps1` を実行 |
| Windows で文字化け | `$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8` |
| sqlc が plugin を見つけられない | 先に WASM をビルド；`file://` パスがビルドモードと一致しているか確認 |

# プロジェクト構成

```
plugin/           # WASM プラグイン（codegen + WASI I/O）
runtime/          # 生成コード用 runtime（mooncakes 公開済み）
examples/users/   # 再現可能なサンプル
tests/            # golden + integration テスト
docs/             # API とクイックスタート
scripts/          # run-example / setup-mooncakes / sync-sqlc-sha256
```

# テスト

```bash
moon check
moon test          # 925 個の inline test
moon build --target wasm --release
```

```powershell
tests/integration/wasm/validate_plugin.ps1 -TestSqlc -Release -SkipBuild
tests/integration/e2e/run_e2e.ps1 -SkipBuild -Release
```

# アーキテクチャ

```
sqlc (protobuf) → wasi_io → codec → adapter → ir
  → type_codegen / query_codegen → ast → emitter → types.mbt + queries.mbt
```

I/O はインライン WAT FFI で WASI `fd_read` / `fd_write` を呼び出します（外部 shim なし）。プロトコルは [sqlc-gen-greeter](https://github.com/sqlc-dev/sqlc-gen-greeter)（MIT）を参考。

# ドキュメントとリンク

| リソース | リンク |
|----------|--------|
| クイックスタート | [docs/quickstart.md](docs/quickstart.md) |
| Runtime API | [docs/runtime-api.md](docs/runtime-api.md) |
| サンプル | [examples/README.md](examples/README.md) |
| mooncakes | <https://mooncakes.io/docs/Mairzzcllo/moonbit_sqlc_plugin> |
| GitHub | <https://github.com/Mairzzcllo/MoonBit-sqlc-WASM-plugin> |

# ライセンス

本プロジェクトは **Apache License 2.0** の下で公開されています — 詳細は [LICENSE](LICENSE)。

> サードパーティ帰属は [NOTICE](NOTICE)。WASM I/O プロトコル参考：[sqlc-gen-greeter](https://github.com/sqlc-dev/sqlc-gen-greeter)（MIT）。
