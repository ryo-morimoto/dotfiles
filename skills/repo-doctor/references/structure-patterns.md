# Directory Structure Patterns

`tree --gitignore` を見て、構造が repo の規模・特性・言語に合っているかを判定するための基準。

## 判定の前提

- まず **言語/フレームワークの標準構造** に従っているかを見る
- 標準構造でなくても、`README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/architecture/` 等に **明示ルール** があり、それと `tree --gitignore` が一致するなら custom pattern として評価可能
- **想定規模より重い構造** は減点する
- **想定規模より軽すぎる構造** も減点する

## Pattern Catalog

### 1. Flat / Small Module

**Good fit**

- Tiny / Small の単一 deployable
- 小さな CLI / utility / one-package library
- Go の単一 package / 単一 command
- Rust の単一 package / 単一 crate

**High-score signals**

- root or `src/` が中心で、top-level が少ない
- feature 削除や rename で repo 全体を横断しなくてよい
- `README` か構造ルールに「小規模なので flat を維持する」理由がある

**Downgrade when**

- Medium+ なのに feature ごとの境界が読めない
- `shared/`, `common/`, `utils/` が肥大化している
- deep relative import や feature 横断 import が増えている

**Representative sources**

- Go module layout
- Cargo package layout

### 2. Go `cmd/` + `internal/`

**Good fit**

- Go の command/server repository
- 複数 binary や supporting package を持つ repo

**High-score signals**

- small package/command は flat、必要になったら `internal/` へ拡張している
- 複数 command は `cmd/<name>/main.go`
- export しない実装は `internal/` に寄せる

**Downgrade when**

- 小さな command なのに初手で過剰な `pkg/` / `service/` / `repository/` 分割
- `internal/` が何でも置き場になっている
- server repo なのに command と non-Go assets が混在して entrypoint が曖昧

### 3. Router-Based Co-Location

**Good fit**

- React Router / Remix など route module 中心の UI
- Small / Medium の product app
- loader/action/component を route 単位でまとめると理解しやすいアプリ

**High-score signals**

- `app/routes` 配下で route module と private helper が近接している
- route folder の中に `route.tsx` や private component/service を置く
- feature ごとの削除・移動が route directory 単位で完結する

**Downgrade when**

- Tiny app なのに route ごとの private subtree が乱立している
- UI routing と無関係な backend/domain まで route-centric にしている
- route naming と directory naming の対応が崩れている

### 4. Rust Crate / Package

**Good fit**

- 単一 crate の library / binary
- Cargo の標準 target layout (`src/lib.rs`, `src/main.rs`, `tests/`, `examples/`) に収まる規模

**High-score signals**

- Cargo conventions に従い、crate root と target placement が明快
- 単一 crate で十分な規模に留めている
- 複数 executable は `src/bin/`

**Downgrade when**

- 複数 crate に分ける必然が薄いのに workspace 化している
- 逆に多目的 repo なのに 1 crate に押し込んでいる

### 5. Workspace / Monorepo

**Good fit**

- 複数 app / package / service / crate を一緒に管理する必要がある
- shared library, tooling, docs app, design system, multiple deployables がある
- 将来 Large になる前提があり、境界・所有・依存制約を導入できる

**High-score signals**

- Nx / Turborepo は `apps/` と `packages/` のように役割で切れている
- Rust workspace は root `Cargo.toml` に `workspace.members` を持ち、member crate が明示されている
- package/crate ごとの entrypoint, ownership, dependency constraints がある

**Downgrade when**

- 単一 app しかなく、shared package もほぼ存在しない
- workspace を入れたが boundary rule がなく自由依存
- nested package / ambiguous package placement がある

### 6. DDD / Bounded Context / Layered Domain

**Good fit**

- business rule が重い backend / enterprise app
- bounded context や aggregate で分ける必要がある
- application / domain / infrastructure の責務分離が実益を持つ

**High-score signals**

- bounded context ごとに model と dependency ルールが明確
- domain layer が他 layer に依存しない
- complex business rule を rich domain model で扱う

**Downgrade when**

- Tiny / Small CRUD app や単純 CLI に最初から DDD を導入
- 各 layer のファイルが数行しかなく、横断移動コストだけ増えている
- `controllers/services/repositories/models/` がトップレベルに並ぶだけで、機能凝集が弱い

### 7. Custom Pattern With Explicit Rules

**Good fit**

- デファクトから外れる合理的理由がある
- repo 内に構造ルールが残されている
- `tree --gitignore` がそのルールを実際に反映している

**High-score signals**

- `ARCHITECTURE.md`, `docs/architecture/`, `README` の structure section, `AGENTS.md` などに明示ルールがある
- boundary enforcement が自動化されている
- naming / ownership / entrypoint の規則が説明可能

**Downgrade when**

- custom だが理由も規則も書かれていない
- 新規参加者が `tree --gitignore` を見ても説明できない

## Size/Pattern Fit Heuristics

| 規模/特性 | 高評価になりやすい | 下げやすい |
|----------|------------------|------------|
| Tiny CLI / utility | Flat, Go small command, Rust single crate | DDD, monorepo, 3層分離 |
| Small product app | Router-based co-location, Flat + clear feature folders | DDD, workspace overkill |
| Medium app | Feature folders, router-based co-location, moderate workspace | flat すぎる構造、曖昧な shared |
| Large multi-app | Nx/Turborepo/Cargo workspace, clear packages/services | single-app flat tree |
| Complex domain backend | DDD / bounded context, layered domain with dependency rules | route-centric UI patternの流用 |

## Improvement Levers

- **構造ルールを明示**: `README`, `ARCHITECTURE.md`, `docs/architecture/structure.md`, `AGENTS.md` などに「なぜこの構造か」「どの依存を許すか」を書く
- **JS/TS の境界を機械化**:
  - Nx は `@nx/enforce-module-boundaries` で tag ベースの `depConstraints` を定義し、`onlyDependOnLibsWithTags` / `notDependOnLibsWithTags` / `bannedExternalImports` で境界を固定する
  - dependency-cruiser は `.dependency-cruiser.*` に forbidden rules を置き、cross-folder import, test-only import, cycle, orphan を build で落とす
  - 単一 app なら ESLint `no-restricted-imports` の `patterns` / `group` で private path や deep import を禁止する
- **Python の境界を機械化**:
  - Import Linter の `forbidden`, `layers`, `independence`, `acyclic siblings` contract を使い、module 間 import ルールを repository policy として残す
- **Semgrep は補助**:
  - custom rule で deep relative import, 命名逸脱, 禁制 path, repo-specific anti-pattern を検出する
  - `semgrep --test` で rule 自体を回帰テストする
  - ただし構造全体の依存 graph 強制は dependency-cruiser / Nx / Import Linter の方が主役
- **tree の読みやすさを保つ**:
  - top-level の責務語彙を減らす
  - `shared/`, `common/`, `utils/` を無制限に増やさず、scope / feature / package に寄せる
  - 新しい subtree は entrypoint と ownership を同時に決める
- **feature 単位で移行**: big bang で tree を作り直さず、1 feature / 1 package / 1 bounded context ずつ寄せる

## Sources

- Go: `Organizing a Go module`
- Rust: Cargo `Package Layout`, Cargo `Workspaces`
- React Router: `File Route Conventions`, `routes.ts`
- Turborepo: `Structuring a repository`
- Nx: `Enforce Module Boundaries`
- dependency-cruiser: README / rules examples
- ESLint: `no-restricted-imports`
- Import Linter: `Contract types`, `Forbidden`
- Microsoft Learn: `Design a DDD-oriented microservice`
- Local knowledge: `colocation-functional-cohesion.md`
