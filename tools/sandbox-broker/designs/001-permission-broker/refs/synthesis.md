# Synthesis — Sandbox / Agent-Workspace Landscape

8 ツールを読んで横断的に抽出した設計パターンと、broker への適用案。

## 1. Layer Map

調査対象は明確に 3 層に分かれる。broker は L2 にいる。

| Layer | 役割 | 代表 |
|---|---|---|
| **L1 Process-level kernel sandbox** | 単一コマンドを Landlock/bwrap/Seatbelt+seccomp で wrap。daemon なし、per-invocation | landrun, sandbox-runtime (srt), Fence (の wrap モード) |
| **L2 In-process policy / hook engine** | agent runtime からの per-tool 決定を仲介 (hook / IPC) | **broker**, Codex CLI, Fence (の hook アダプタ), Claude Code |
| **L3 Workspace container / VM** | agent 全体を VM/container で隔離。trust boundary = 箱 | E2B, Daytona, agent-infra/sandbox, Windmill (NSJail per job) |

L1 と L3 は補完関係。broker は L2 として L1 を呼び、L3 とは互いに置き換え不要。

## 2. Convergent Patterns（複数ツールに現れた設計）

### 採用判断早見

| 観点 | パターン | 出典 | broker 採用 |
|---|---|---|---|
| 既定値 | **read=deny-then-allow / write=allow-only / net=allow-only** の非対称デフォルト | sandbox-runtime, Fence | ★ short |
| 安全網 | **policy 非依存の mandatory-deny 一覧** (`.bashrc`, `.git/hooks/**`, `.mcp.json`, `.claude/commands/**`) | sandbox-runtime, Fence | ★ short |
| 失敗 | **hook subprocess error は fail-open** + security-critical だけ fail-closed | Codex | ○ 設計 |
| 設定 | **`extends` 継承 + 同梱 starter テンプレ** (`code`, `code-strict` など) | Fence | ★ med |
| 構造 | **per-agent thin adapter + 共通 evaluator** (3 hook 入口、1 評価コア) | Fence | ★ short |
| 構造 | **静的 DSL (prefix_rule) と動的 hook を分離**、ask の昇格は別軸 | Codex | ★ med |
| DX | **prefix-rule に `match=` / `not_match=` を parse-time 検証** | Codex | ★ short |
| DX | **「次回も許可」が policy.toml への amendment 提案として diff 化** | Codex | ★ med |
| 起動 | **boot 時に primitive 検出してキャッシュ + fail-fast** (`nsjail --help`、bwrap 検査) | Windmill, Codex | ★ short |
| 起動 | **invalid policy は default-empty に fall back せず hard-fail** | (sandbox-runtime の anti-pattern) | ★ short |
| 多層 | **platform-baked + user-override の二段** (MDM / org / project) | E2B, Codex, Daytona, Fence | ○ med |
| 寿命 | **cleanup-stack (LIFO + priority)** で sock/PID/log/iptables を破棄 | E2B | ★ med |
| 寿命 | **desired-state reconciler ( cron + single-flight lock)** | Daytona | △ overkill |
| OOM | **`oom_score_adj=1000` を子に書いて kernel OOM kill を子に誘導** | Windmill | ★ short |
| 行動 | **hook で verdict だけでなく command rewrite** ( `fence -c "<orig>"`)、kernel sandbox を内側に nest | Fence | ○ 戦略次第 |
| 監査 | **violation を ring buffer に貯めて subscribe** (in-memory + log stream tap) | sandbox-runtime | ★ med |
| 監査 | **`explain <op>` / `policy show` 系の introspection サブコマンド** | agent-infra (MCP `list_*`), Daytona toolbox | ○ med |
| Net | **proxy ベースの egress + nftables/iptables の二層**。Landlock 単独では足りない | sandbox-runtime, Fence, E2B, Daytona | ○ long |

★=高 ROI / 短期、○=方針判断要 / 中期、△=不要

### 各パターンを深掘り

**非対称デフォルト** — `sandbox-runtime/sandbox-schemas.ts` の semantics: read は `denyRead` が `allowRead` を override (default は読める)、write/net は allowlist 必須。Fence の `code` template も同形。一律 deny より人間に優しく、危険なものだけ確実に止める。broker の `Policy::default()` は今は全 deny で escalate になり「policy 未設定 = 全部 ask」。これだと L2 の存在意義がない。

**Mandatory-deny** — `sandbox-runtime/sandbox-utils.ts:11-40` の `DANGEROUS_FILES`、Fence の `internal/sandbox/dangerous.go`。policy ファイルに何が書いてあろうと書き換えられない bedrock。agent が自分の policy / shell rc / git hook を書き換える攻撃を最低限防ぐ。

**Per-agent thin adapter + shared evaluator** — Fence の `cmd/fence/hooks_{claude,cursor,opencode}.go` がそれぞれ JSON shape を整形して `cmd/fence/hooks_runtime.go:81-104` の `evaluateShellHookRequest()` に集約。broker の現状は `claude-code-hook.sh` と `codex-hook.sh` がそれぞれ jq+curl ロジックを重複実装。bash の薄さで持ち過ぎ、共通化が望まれる。

**Codex の三段アーキ** — `SandboxPolicy` (kernel-level confinement)、`execpolicy` Starlark DSL (静的 prefix-rule 判定)、`approval_policy` (Prompt を人 or 自動拒否のどっちにルートするか)。broker は `prefixRules` を真似たが、execpolicy の `match=` / `not_match=` バリデーション、`proposed_execpolicy_amendment` (「次回も許可」を policy diff として返す) を取りこぼしている。

**Hook = rewrite** — Fence は許可した Bash を `fence -c "<orig>"` に書き換えて返す。`updatedInput` で hook が tool_input を変更できる Claude Code 仕様を活用し、許可後の実行も Fence の wrapper 下に置く。`FENCE_SANDBOX=1` env で再帰防止。L2 の broker でも `command` を `landrun --rw=. -- bash -c <orig>` に rewrite すれば、verdict-only より一段強い enforcement になる。Codex の場合 `permissionDecision: ask` が fails-open するため、rewrite アプローチの方が確実。

**Cleanup-stack** — `e2b/orchestrator/pkg/sandbox/cleanup.go`。リソースを取得した順に teardown closure を `Add` し、最後 LIFO で実行。`AddPriority` で「VM kill だけは最初」を保証。broker の daemon 終了時 sock 削除 / PID file unlink / log flush / iptables chain 解除を atomic に揃えるのに直接適用できる。

## 3. Anti-Patterns（避けるべき）

| アンチ | 出典 | 教訓 |
|---|---|---|
| Module-level singleton state (`let config`, `let httpProxyServer`) | sandbox-runtime | テスト不能、二重初期化不能。最初から struct に閉じる |
| Invalid config を silently default-empty にする | sandbox-runtime | typo で意図より緩い。**hard-fail** が正解 |
| security setup を fire-and-forget goroutine | Daytona (`create.go:159`) | 起動瞬間に網が無い窓ができる。fail-closed |
| 既定で sandbox **off** | Windmill (`DISABLE_NSJAIL` defaults true) | 無いと思わせる UX が一番危ない |
| Inside-jail で NOPASSWD sudo | Windmill AI image | 隔離は wrapper のみ。ESCAPE 一発で終わる |
| heavy infra (Postgres+Redis+N runners+...) | Daytona | personal machine の broker でこの形は誤り |
| 「container = boundary」前提で `seccomp=unconfined` | agent-infra/sandbox | per-tool decision が無く、tool 一つ抜かれたら全部抜かれる |
| Linux で violation telemetry を `strace` 任せ | sandbox-runtime | 自前で audit log を持つべき |
| `permissionDecision: ask` を parse して fail-open | Codex | broker は意図を明示する (どちらでも構わないが silent はダメ) |
| Templates 17 個を文字列重複 | Windmill nsjail | drift 不可避。共通 base + diff の構造に |

## 4. broker への具体的適用案（優先度付き）

### Phase 1 — short term（数日、現在の broker を「使える」状態に）

1. **`Policy::default()` を非対称に再定義**: read=allow-most + deny-secrets / write=deny-all + allow-CWD+/tmp / net=deny-all + allow-loopback
2. **Mandatory-deny ハードコード** (`broker.rs::evaluate` 先頭): `~/.bashrc`, `~/.zshrc`, `~/.gitconfig`, `**/.git/hooks/**`, `**/.mcp.json`, `**/.claude/commands/**`, `**/.codex/**`, `**/.sandbox/policy.toml` への write は user policy より先に deny
3. **共通 evaluator の bash 化** (or `sandbox-broker hook claude` / `sandbox-broker hook codex` サブコマンド化): jq+curl 重複を 1 箇所に。fence の `evaluateShellHookRequest` 構造をコピー
4. **Boot probe**: `cmd_start` の冒頭で Landlock / bwrap 存在 + kernel ABI を確認、`broker.toml` に書き戻してキャッシュ。要求 mode で primitive が無ければ即 error
5. **Invalid policy → hard-fail**: 現在 `Policy::default()` (deny-all) に fall back している箇所を全部 `Err(_)` に
6. **`init` template の中身を fence の `code.json` 相当に膨らます**: 現状 `examples/policy.toml` は薄い。AI agent 想定の allow-domains / deny-secrets / deny-mutating-commands を最初から
7. **Daemonize by default + PID file + log redirect** (前回議論の続き)
8. **prefix_rule に `examples = [["git", "status"], ...]` / `not_examples = [...]` を追加し parse 時に validate** (Codex `execpolicy` パターン)

### Phase 2 — medium term（数週、表現力と DX）

9. **`extends` 継承 in policy.toml**: `extends = ["code", "git-readonly"]` で同梱 template + `@base` で project ベース継承。merge は slice append-dedupe / bool OR / scalar override (Fence)
10. **Amendment proposal**: human approval 後に `proposed_amendment` フィールドで「次回も許可」のための新規 prefix_rule TOML 行を返す → CLI が diff として見せて user が `policy.toml` に append (Codex `amend.rs`)
11. **`sandbox-broker explain <op>`**: 「この op はどの rule で allow/deny されたか」を policy → session → programmatic → mandatory-deny の順に walk して表示。`session log` よりずっと debuggable
12. **Cleanup-stack 化**: 現在 `cmd_stop` は socket だけ消す。pid / log / 一時 iptables (将来) を `Cleanup::add` で集約
13. **Hook = command rewrite (オプション)**: `policy.toml` で `enforce.wrap_with = "landrun"` を opt-in にし、allow になった Bash command を `landrun --rwx=$cwd --connect-tcp=443 -- bash -c <orig>` に rewrite して返す
14. **Two-tier policy**: `~/.config/sandbox-broker/global.toml` (mandatory-deny の上書き禁止 + 全 project 共通) + `<base>/.sandbox/policy.toml` (override)

### Phase 3 — long term / 戦略判断

15. **Egress proxy の同梱** (sandbox-runtime / Fence と同形の HTTP+SOCKS proxy で domain allow-list)。broker daemon 内で listen、policy.toml の `network.allowed_domains` を渡す
16. **`--ldd` 自動 ELF deps walk**: `landrun` の ELF dependency walker をパクって、command allow-list を auto-derive
17. **PermissionRequest hook 対応** (Codex 二段): 「ask the LLM, not the human」を broker 側でも

## 5. broker の戦略的ポジション

8 ツールどれも broker の niche を直接埋めない:

- **Fence** が最も近い (L2+L1 multi-agent hook engine)。だが per-invocation で daemon 無し、policy DSL は JSONC、Nix declarative ではない。state は session 化されてない
- **Codex** は同じ「prefix-rule + hook + sandbox 三層」だが Codex CLI 専用
- **sandbox-runtime** は Anthropic 公式の per-invocation wrapper、daemon ではない
- **Landrun / Windmill / Daytona / E2B / agent-infra** は層が違う

broker が打ち出せる差別化:

> **declaratively-managed (Nix), per-project, multi-agent unified (Claude+Codex+future), 長寿命 daemon、project root-aware、audit log first-class**

具体的には: 「Fence の policy DSL ergonomics + Codex の三層アーキ + sandbox-runtime の non-対称 defaults + broker 独自の declarative deploy」が見えてくる。Phase 1 を片付ければそこに乗る。

## 6. Open Questions（ユーザに判断仰ぐべき）

1. broker は「verdict-only」で行くか、「verdict + rewrite-to-landrun」で deeper enforcement に行くか？ (Phase 2 の #13)
2. `mandatory-deny` の射程: agent config (`.claude/**`, `.codex/**`) を読み込み禁止にするか、書き込みだけ禁止か？ Codex/Claude は config 読み戻しが必要なので write-only deny が無難
3. 同梱 template をどこまで官姿勢に: `code` / `code-strict` / `git-readonly` / `local-dev-server` の四つ揃えるか、最初は `code` だけで様子見か
4. 二段 policy の「platform」層は `~/.config/...` に置くか、Nix 経由 (`/etc/sandbox-broker/policy.toml`) で declarative deploy するか
