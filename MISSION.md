# Mission: Kody Operational Understanding

## Why
Kodyを動かし始める前に、KodyがHermesのどの部分を代替できそうで、どの部分は外部agent実行基盤に任せる候補かを判断できるようにする。最終的には、Kodyを安全に起動し、Cursor/Codex/GitHub連携をどこに実装するかを根拠を持って決められる状態にする。

## Success looks like
- Kodyを「MCP-native personal automation substrate」として説明できる
- Kody core capability、saved package、外部coding agentの責務を切り分けられる
- `start_coding_agent` をKody内のどこに置くのが妥当か判断できる
- Kodyをローカルで起動する前に、必要なsecret、host approval、mutation確認の境界を説明できる

## Constraints
- 実装に入る前の概念整理を短いレッスンで行う
- Hermesとの比較を軸にして、抽象論に寄せすぎない
- 参照元はKody公式repoと公式MCP資料を優先する

## Out of scope
- Hermes自体の再実装
- Kody coreへの本格的な機能追加
- Cursor Cloud Agents APIの詳細実装
