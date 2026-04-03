# Living Documentation

設計意図をどこかに残す仕組みがあり、その記録がコードと一緒に更新され続けているかを評価するための基準。

## 何を検出するか

1. **設計意図の保持機構** があるか
2. **コードとドキュメントの鮮度差分** が放置されていないか
3. **drift を減らす仕組み** が local + CI にあるか

## 設計意図を残す代表的な仕組み

- ADR / MADR (`docs/adr/`, `docs/decisions/`, `adr/`)
- `ARCHITECTURE.md`, `docs/architecture/`
- framework / workspace config 自体が設計意図を表すもの
  - `app/routes.ts`
  - `pnpm-workspace.yaml`
  - root `Cargo.toml [workspace]`
- reusable / single-source docs
- generated reference docs
- code から decision record を参照する仕組み（例: e-adr）

## 鮮度評価の手順

### 1. 候補ファイルの収集

優先対象:

- `README.md`
- `ARCHITECTURE.md`
- `CONTRIBUTING.md`
- `docs/architecture/**`
- `docs/decisions/**`, `docs/adr/**`, `adr/**`
- 構造ルールを定義しているファイル

### 2. oldest-5 サンプリング

候補ファイルの中から、最終更新が古い5件を選ぶ。

**Repo Doctor inference:** ここでいう「古い」は filesystem mtime ではなく git history ベースで見る方が良い。living documentation の鮮度は「最後に意味のある更新が入った時点」で判断したいから。

### 3. 文書と関連コードを対で読む

各文書について以下を確認する:

- 文書が参照する module / package / route / command / config path は今も存在するか
- 現在の entrypoint / tree / workspace member / route config と矛盾していないか
- 実装だけ残って docs が無い、または docs だけ残って実装が無い状態になっていないか
- architecture diagram / examples / commands がまだ実行可能・説明可能か

### 4. 判定

| 判定 | 条件 |
|------|------|
| 一致 | 文書とコードの対応が取れている |
| 部分 drift | path/command/feature 名の一部が古い |
| orphan doc | docs はあるが対応コードが消えている |
| orphan code | 重要 subsystem のコードはあるが設計意図を残す docs が無い |

## High-Score Signals

- ADR があり、status / date / decision-makers / confirmation を持つ
- docs の分類に Diataxis や content model のような明示構造がある
- reference のような揮発しやすい情報は generated / single-source に寄せている
- docs lint / validation が local + CI で実行される
- architecture docs は C4 context/container/component など durable abstraction を中心にしている
- docs と code の traceability がある
  - ADR から module へのリンク
  - code から ADR 参照
  - route/workspace config が docs と一致
- oldest-5 サンプルに対して `last-reviewed` / `Confirmation` / expiration のような再確認機構がある

## Antipatterns

- docs taxonomy だけ作って中身が空
- 同じ説明の copy-paste が複数箇所にある
- API reference 自動生成だけで「十分」としている
- 長期運用 docs に hand-written code-level diagram を置いている
- oldest-5 を読むと削除済み path や古い command が並ぶ
- major subsystem の code はあるが、設計意図を示す docs が無い
- docs はあるが local で lint / validate できない

## Improvement Methods

### 1. ADR / MADR を導入する

- decision log を `docs/adr/` か `docs/decisions/` に置く
- `status`, `date`, `decision-makers` などの metadata を持たせる
- `Confirmation` を追加して「いつ何で妥当性を再確認するか」を残す
- `Confirmation` は design review / code review / architecture test / lint rule など、実際の確認手段に結び付ける

### 2. docs model を決める

- Diataxis か content model を採用し、tutorial/how-to/reference/explanation など docs の役割を分ける
- ただし empty structure を先に作らない

### 3. volatile な docs を single-source / generated に寄せる

- reusable content
- versioned single-source docs
- generated reference / API docs
- 低レベル diagram は on-demand / generated を優先
- route/workspace/package/member 一覧のような揮発しやすい情報は config か manifest を source-of-truth にする

### 4. freshness check を自動化する

**Repo Doctor inference:** 公式 docs に「oldest-5 を読む」標準はないが、以下は実装しやすい改善策。

- oldest-5 docs を抽出する script を置く
- docs 内 path / command の存在検証を行う
- `last-reviewed` や review cadence を front matter / ADR metadata で持つ
- orphan doc / orphan code を semgrep / custom script / grep-based check で検出する
- local の docs lint を pre-commit / 手動 command で回し、CI は同じ command を再実行する
- expiration marker や review date を使い、古いまま放置される文書を warning にする

### 5. code と docs の距離を縮める

- e-adr のように code から decision record を参照する
- route/workspace/config を docs の source-of-truth に寄せる
- agent rules のように複数 consumer に配る内容は single-source 化する
- docs が説明する path / package / route / command は、できるだけ repo 内で自動検証可能な表現に寄せる

## 実装しやすい freshness 改善パターン

- **ADR Confirmation の運用**: ADR ごとに「何を見れば今も有効と言えるか」を書き、review や architecture test に結び付ける
- **oldest-5 bot / script**: docs 候補の git 更新日時を集計し、古い5件を定期的に issue / report 化する
- **path existence check**: docs 内の repo-relative path, workspace member, route file, command を抽出して存在確認する
- **orphan check**: major package / route / service / bounded context に対応する docs の有無を確認する
- **single-source for volatile facts**: package list, route list, workspace members, supported commands は config から生成する
- **local-first docs validation**: docs lint, link check, custom freshness check は local command を正とし、CI は mirror にする

## Sources

- ADR / MADR
- Diataxis `Foundations`, `How to use Diataxis`, `Reference`
- GitHub Docs `About the content model`, `Creating reusable content`, `Versioning documentation`, `Using the content linter`
- C4 model `Review checklist`, `Code diagram`
- arc42 documentation
- e-adr
- Semgrep `Write rules`, `How Semgrep works`, `Test rules`
- Local knowledge: `nix-agent-rules-single-source.md`
