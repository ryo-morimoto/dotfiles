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

- 関連設定は、一箇所で読める粒度の `home/<domain>/default.nix` に集約する。
- `home/default.nix` は import の集約に寄せ、過剰な submodule 分割は避ける。
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

- Shared skill / plugin / MCP 定義は `home/agents/default.nix` に集約し、各 agent module はそれを消費する。
- Tool 固有フォーマットへの変換は消費側 module/host で行う。
- APM の package、DSL、Home Manager module factory は `packages/apm.nix` に寄せる。
- Alias 追加より skill 化や config 化を優先し、shell alias と tool config の二重管理を避ける。

### Review And Planning

- 具体案に飛びつく前に、評価軸・判断基準・未確定論点を明確にする。
- Review は findings first。impact、correctness、ops、cleanup の観点を優先する。
- Commit は Conventional Commits を基本に、小さめの差分を高頻度で積む。

## Concrete Decisions

- Desktop stack は Niri + DankMaterialShell を継続し、置き換え済みの旧 desktop stack は repo に残さない。
- Playwright は Nix の Chromium-only `playwright-driver` を標準にし、`playwright install*` を使わない。
- OpenCode は Home Manager activation で `compound-engineering` を自動適用する。
- OpenCode には managed permission policy を注入せず、Home Manager の `settings.permission = "allow"` を既定にする。
- Claude Code は `permissions.defaultMode = "bypassPermissions"` と `sandbox.enabled = false` を標準にする。
- Claude Code の dangerous bypass flag は wrapper ではなく shell alias で付与する。
- Claude Code から Codex を使う入口は OpenAI の `codex-plugin-cc` marketplace を使う。
- `semgrep@claude-plugins-official` は自動 hook の副作用があるため、既定では無効化する。
- `semgrep` CLI は Home Manager に常設せず、必要時だけ一時導入または個別環境で使う。
- Neovim の日本語 Markdown では spell を無効化せず、`spelllang=en,cjk` で英単語チェックを残す。
- Repo 内に `worktrees/` は持たず、worktree は project 隣接の `{project}-wt/<name>` に置く。
- Hermes Agent は dashboard を常駐公開せず、Discord profile gateway を primary UI とする。Runtime service は managed mode を維持し、profile directory / config / Discord env / Codex auth は Nix activation と agenix secret で宣言管理する。

## 未確定ドメイン

- 既定ブラウザの方向性（Firefox 基準の維持 / Zen への移行）
