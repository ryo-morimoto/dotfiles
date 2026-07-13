# Kody Operational Understanding Resources

## Knowledge

- [Kody README](https://github.com/kentcdodds/kody#readme)
  Kodyの技術スタック、Cloudflare Workers/MCP構成、quick startを確認する一次資料。Use for: Kodyが何として配布されているか。
- [Kody project intent](https://github.com/kentcdodds/kody/blob/main/docs/contributing/project-intent.md)
  Kodyの製品意図、multi-user personal assistant、compact MCP surface、per-user isolationを説明する一次資料。Use for: アーキテクチャ判断。
- [Kody first steps](https://github.com/kentcdodds/kody/blob/main/docs/use/first-steps.md)
  利用時の基本動線。`search` first、`execute`、packages、secrets、mutation確認がまとまっている。Use for: 実際に動かす順番。
- [Kody execute and workflows](https://github.com/kentcdodds/kody/blob/main/docs/use/execute.md)
  Code Mode、package runtime、agent turnsの扱い、storage、jobs/workflowsを確認する資料。Use for: agent実行基盤との境界。
- [Kody mutating actions](https://github.com/kentcdodds/kody/blob/main/docs/use/mutating-actions.md)
  GitHub、Cloudflare、Cursor Cloud Agentsなどのmutation前確認ルール。Use for: `start_coding_agent` の安全境界。
- [Model Context Protocol introduction](https://modelcontextprotocol.io/docs/getting-started/intro)
  MCPがAIアプリケーションと外部システムをつなぐ標準であることを確認する公式資料。Use for: KodyのMCP側の意味づけ。
- [MCP Tools specification](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)
  MCP serverがtoolを公開し、modelが呼び出す仕組みの公式仕様。Use for: Kodyが巨大tool catalogを避ける理由の理解。

## Wisdom (Communities)

- [GitHub Discussions / Issues for kentcdodds/kody](https://github.com/kentcdodds/kody/issues)
  実装意図が曖昧なときに、設計変更や現在の方向性を確認する場所。Use for: coreに入れるかpackageに入れるかの判断材料。

## Gaps

- Hermes側の一次資料はこのワークスペースにはまだ登録していない。Hermesとの厳密比較が必要になったら追加する。
