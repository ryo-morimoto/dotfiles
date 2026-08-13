# Agent Operating Principles

この文書は、dotfiles repo で繰り返し使う運用原則をまとめる。単発の好みや作業ログではなく、
次回以降の設計・実装判断を短くするための再利用可能な原則だけを置く。

## 更新基準

- 新しく書くのは、複数回使える判断基準・設計原則・運用原則が確定したときだけ。
- 単発の実装判断、明らかな既存ルール適用、作業履歴は追加しない。
- 具体的な tool 名や version は、原則の理解に必要な場合だけ例として書く。
- 未確定ドメインに触れる実装では、実装前に一つだけ probe を投げる。
- 未確定ドメインが解決したら、該当項目を削除し、必要なら確定した運用原則を追加する。

## Principles

### Source Of Truth

- 設定は宣言的な source から変更する。Home Manager / activation の出力先は直接編集しない。
- source か生成先か曖昧なときは、symlink target や module の参照元を確認してから編集する。
- secret は平文で置かず、暗号化された管理経路に寄せる。

### Configuration Shape

- 関連設定は、一箇所で読める粒度の `nix-config/home/<domain>/default.nix` か `dot-config/chezmoi/` の source に集約する。
- `nix-config/home/default.nix` は import の集約に寄せ、過剰な submodule 分割は避ける。
- package 定義や app 設定は、既存の責務境界に合わせて置く。境界をまたぐ場合は先に構造を確認する。

### Agent Instructions

- 常時ロードする agent 指示は短く、tool-neutral で、cross-project な行動原則に限定する。
- 詳細 workflow、tool 固有ルール、deterministic enforcement は skills、settings、hooks、focused docs に分離する。
- Root `AGENTS.md` は index に寄せ、詳細は `docs/agents/` の focused docs へ逃がす。
- Agent 回答は、明示的に別言語を求められない限り日本語を既定にする。

### Automation Boundary

- フォーマット、静的解析、リリースノート生成など機械的に処理できる作業は、LLM ではなく script / CI / hooks に委譲する。
- Permission、sandbox、secret access のような強制したい制約は、prompt ではなく tool settings や managed policy に寄せる。
- Agent は impact、correctness、ops、cleanup など判断が必要なレビューに使う。

### Local Development

- `.nix` 編集後は `nixfmt`、flake 変更時は `nix flake check` で検証する。
- Dependency update は小さく分け、lockfile 更新は独立した maintenance 作業として扱う。
- Python は system-wide ではなく Home Manager のユーザー環境に追加する。
- Browser automation は操作・観測と URL 安定化を分けて考える。操作は browser tool、stable local URL は port manager に寄せる。

### Agent Toolchain

- Codex、Claude Code、APM、MCP、skills、hooks、plugins は mutable runtime config を既定にする。
- Nix は agent tool の stable runtime prerequisite と config lifecycle を導入してよいが、live `~/.codex`、`~/.claude`、`~/.apm` config の内容は生成しない。
- Disposable AI tools は Nix の外に置く。1ヶ月以上繰り返し使い、rebuild-time 管理に見合うものだけ nixpkgs か maintained community package に昇格する。
- Agent の stable settings は `dot-config/chezmoi/` の source、operation notes と reviewed examples は `dot-config/agents/` に置く。単一の runtime file に stable config と host-local state が混在する場合は、chezmoi modify template で tracked base を live file へ merge し、tool-owned state を Git 管理から除外する。

### Review And Planning

- 具体案に飛びつく前に、評価軸・判断基準・未確定論点を明確にする。
- Review は findings first。impact、correctness、ops、cleanup の観点を優先する。
- Commit は Conventional Commits を基本に、小さめの差分を高頻度で積む。

## Concrete Decisions

- Desktop stack は Niri + DankMaterialShell を継続し、置き換え済みの旧 desktop stack は repo に残さない。
- Playwright は Nix の Chromium-only `playwright-driver` を標準にし、`playwright install*` を使わない。
- APM は MCP server の宣言管理に使う。all-in-one plugin は常時ロードの context コストが高いため使わない。
- OpenCode には managed permission policy を注入せず、Home Manager の `settings.permission = "allow"` を既定にする。
- Claude Code は `permissions.defaultMode = "bypassPermissions"` と `sandbox.enabled = false` を標準にする。
- Claude Code の dangerous bypass flag は wrapper ではなく shell alias で付与する。
- `semgrep@claude-plugins-official` は自動 hook の副作用があるため、既定では無効化する。
- `semgrep` CLI は Home Manager に常設し、この repo の Nix policy(`.semgrep/nix.yaml`)を pre-commit と CI で強制する。
- Neovim の日本語 Markdown では spell を無効化せず、`spelllang=en,cjk` で英単語チェックを残す。
- Repo 内に `worktrees/` は持たず、worktree は project 隣接の `{project}-wt/<name>` に置く。
- `$HOME` 配備は pure な標準 chezmoi 運用に従う。実体は source dir(`dot-config/chezmoi/`)に置き copy 配備、tool が書き換えた live の変更は `chezmoi re-add` で回収する。独自 wrapper・symlink shim は持たない。template は共有 AGENTS.md、Codex modify merge、skill symlink の homeDir 展開だけ。Home Manager は package 導入・`sourceDir` 設定生成・activation での `chezmoi apply --force` だけを担う。
- Machine-generated なファイル(DMS theme 出力等、ユーザー操作なしで tool が再生成するもの)は chezmoi 管理に含めない。rebuild の apply が tool 出力を巻き戻すため。lock file(lazy-lock、mise.lock、approvals)は reproducibility 入力として例外的に管理し、更新操作の後に `chezmoi re-add` で回収する。
- Self-authored な cross-tool agent skill は実体を `dot-config/config/skills/<name>/` に一箇所置き、chezmoi の `symlink_` エントリで各 tool の skill dir(`~/.claude/skills`、`~/.codex/skills`、`~/.config/opencode/skills`)から参照させる。copy 配備しないので編集は即時に全 tool へ反映される。OSS skill の APM 管理とは別経路。
- Config の内容検査は OSS hook(pre-commit-hooks の `check-toml` / `check-json` / `check-yaml`、gitleaks default rules)と diff review を基本にする。例外として Nix の再現性・スコープ制御ルールだけは self-maintained な `.semgrep/nix.yaml` で強制する。ルールは ERROR のみ(違反を fail させる価値がないルールは持たない)。

## 未確定ドメイン

- 既定ブラウザの方向性（Firefox 基準の維持 / Zen への移行）
- OSS agent skill の管理経路（APM 経由 / skill dir への直置き。現状 `module-design-optimization` が `~/.claude/skills` に管理外で直置きされている）
