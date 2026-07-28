# 命名・語彙を agent 指示に落とすための調査

- 調査日: 2026-07-28
- 目的: 「語彙の追加・変更、命名には極端までに執着する」という意図を、硬直した命名規則ではなく、設計判断の質を上げる agent 指示へ変換する
- 対象: t-wada（和田卓人）氏の公開情報、著名なプログラマー・書籍、言語/API の公式ガイド、命名に関する実証研究
- 出典方針: 本人・著者・公式プロジェクト・出版社・原著論文を優先し、二次資料は出典探索にだけ使う

## 結論

最も筋の良いルールは、**命名結果を一律の形式で縛ることではなく、語彙を設計・モデル・契約として扱い、意味の精度には妥協せず、名前自体は反復的に改善すること**である。

調査した資料には、次の強い合意がある。

1. 名前は装飾ではない。人間がコードを理解するためのモデルであり、責務・境界・抽象化を形作る設計要素である。
2. 良い名前は単独で決められない。定義だけでなく、呼び出し側、会話、文書、同じコンテクストの既存語彙で試す。
3. 命名しにくさは、単なる語彙力不足ではなく、理解不足、責務の混在、欠けた抽象化、または誤った抽象化のシグナルになり得る。
4. 最初から完璧な名前を要求すると停滞する。嘘のない名前から始め、理解が増えるたびに名前と構造を進化させる。
5. 長さ、接尾辞、略語などの正解は言語・スコープ・コンテクストによって変わる。グローバル指示では形式を固定せず、意味を吟味するプロセスを固定する。
6. 公開 API、schema、設定キー、永続化形式などの名前は利用者との契約であり、内部識別子の rename と同列に扱わない。

したがって「極端までに執着する」の対象は、文字数、命名会議、確認回数ではなく、次の4点にするべきである。

- 概念と名前の一致
- 同一コンテクスト内の一貫性
- 近接概念との区別
- 公開契約への影響

## t-wada 氏について

### 公開 AGENTS.md / CLAUDE.md

2026-07-28 時点で、本人が公開している現役 branch 上の `AGENTS.md` は確認できなかった。一方、本人名義の `CLAUDE.md` は2件確認できた。

- [`twada/benchmark-commits` の `CLAUDE.md`](https://github.com/twada/benchmark-commits/blob/main/CLAUDE.md) は TDD、lint、頻繁な test、小さな commit、`any` に逃げる前の相談などを定めるが、命名原則は明文化していない。[本人名義の追加 commit](https://github.com/twada/benchmark-commits/commit/7221c0cddaae6e90f941f56c4ac889f3bb174e45)
- [`twada/extract-git-treeish` の `CLAUDE.md`](https://github.com/twada/extract-git-treeish/blob/master/CLAUDE.md) は command、testing strategy、architecture、TypeScript 設定が中心で、命名原則はない。[本人名義の追加 commit](https://github.com/twada/extract-git-treeish/commit/68ad504ee8426993859f25eb663a2ff1ccc9aa78)

確認範囲は GitHub REST API 上の公開53 repository、全133 active public branch の recursive tree、公開 gist 15件、GitHub Code Search、本人 blog、Speaker Deck、検索エンジンである。`AGENTS.md`、`CLAUDE.md` のほか、Gemini、Copilot、Cursor、Windsurf 系の代表的な agent instruction 名と agent / prompt / instruction 系 path を検索した。したがって「公開されていない」と断定するのではなく、「この範囲では公開 `AGENTS.md` を確認できない」が正確である。private repository、local / global 設定、削除済み履歴、未 index の内容は対象外である。

### 公開情報から確認できる命名観

本人の公開情報からは、命名への強いこだわりを直接確認できる。

- 2025-06-18 の本人投稿では、Agentic Coding の価値として、設計について「納得いくまで食い下がる」「決まったことを蒸し返す」ことを挙げ、命名を妥協せず数日議論することで自分側にブレイクスルーが生まれる場合があると述べている。[Bluesky 投稿](https://bsky.app/profile/twada.bsky.social/post/3lrtsky4kdc2v)
- 2026-07-22 の本人投稿には、agent が「この人間は命名に異様にこだわる」と推測する画面と、`verify` という広い名前が CI job の内容と本当に対応するかを問い、固有価値が伝わる候補を比較する画面が添付されている。これは命名の好みを示す有力な公開事例だが、公開された AGENTS.md の証拠ではない。[Bluesky 投稿](https://bsky.app/profile/twada.bsky.social/post/3mr733exwrk2o)
- 本人執筆の「テストコードの認知負荷」では、テストコードで最も重要なのは名前であり、意図を説明的に書くべきだとする。「結果が正しいこと」のような名前は、書き手だけが「正しい」の意味を知り、読み手には自明でないためアンチパターンとしている。[技術評論社の記事](https://gihyo.jp/dev/serial/01/savanna-letter/0007)
- 2025-06-25 の本人投稿では、「TDD」「テスト駆動開発」という語の意味が普及によって希薄化し、LLM も曖昧に解釈する一方、人名を添えると具体的な参照点になる可能性を指摘している。[Bluesky 投稿](https://bsky.app/profile/twada.bsky.social/post/3lsfo3ah4722u)
- 翌日の投稿では、同じ問題を DDD にも当てはめ、「DDD」だけの場合と「エリック・エヴァンスの DDD」の場合で AI の解釈が異なると述べている。[Bluesky 投稿](https://bsky.app/profile/twada.bsky.social/post/3lshx36e5hs2u)
- 2026-07-10 の本人投稿では、詳細な設計書からコードを再生成する実験を経て、文書不要なほど明瞭なコードを書き、コードに書けない `Why` / `Why not` を文書に残すスタイルへ戻したとしている。[Bluesky 投稿](https://bsky.app/profile/twada.bsky.social/post/3mqbr6pnowc24)

ここから得られる実務上の示唆は次の通りである。

- 広すぎる名前は、対象との対応関係と固有価値を問い直す。
- 「正しい」「処理する」「検証する」など、読み手に意味の復元を委ねる語を具体化する。
- 意味が希薄化した流行語を agent に渡す場合は、出典、定義、具体例を併記する。
- agent を即答装置だけでなく、命名候補を何度でも反証できる議論相手として使う。
- ただし、命名議論をすべて人間確認にする必要はない。公開事例の agent 自身も「妥当なら確認なし」を想定しており、確認は曖昧さと契約影響に比例させるのが自然である。

## 一次資料から抽出した原則

### 1. 名前はドメインモデルを動かす共通言語である

Eric Evans は Ubiquitous Language を「ドメインモデルを中心に構成され、bounded context 内でチームの全活動とソフトウェアを結ぶ言語」と定義する。DDD の要約自体にも、明示的に境界づけられたコンテクスト内で Ubiquitous Language を話すことが含まれる。[Domain-Driven Design Reference](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)

Martin Fowler は、この言語は厳密である必要があり、ドメインエキスパートとの会話で試され、理解の深化に応じてモデルとともに進化すると整理している。[Ubiquitous Language](https://martinfowler.com/bliki/UbiquitousLanguage.html)

一方、大きなシステム全体で単語と意味を一意に統一するのは現実的でない。同じ `Customer` や `Product` が組織内の別領域で異なる意味を持ち得るため、意味を統一する単位は bounded context である。[Bounded Context](https://martinfowler.com/bliki/BoundedContext.html)

導出するルール:

- 同一コンテクストでは同じ概念に同じ語を、異なる概念に異なる語を使う。
- コンテクストをまたぐ同音異義語を一律に禁止せず、境界と変換を明示する。
- 語彙変更は識別子の置換だけで終えず、コード、テスト、文書、会話上のモデルが再び一致しているか確認する。

### 2. 名前は「どう実装するか」より「何を達成するか」を伝える

Kent Beck は Intention Revealing Message / Selector で、実装方法ではなく達成したいことに基づいてメソッドを命名する。異なる2つ目の実装を想像し、それにも同じ名前を付けるか問うことで、現時点で十分に抽象化された名前かを試す。[Smalltalk Best Practice Patterns 公式 sample](https://www.informit.com/content/images/9780134769042/samplepages/013476904X.pdf)

導出するルール:

- `linearSearchFor` のような手段名より、呼び出し側が求める `includes` のような意図を優先する。
- ただし低レベル API でアルゴリズム選択自体が契約なら、実装語が意図になり得る。機械的な禁止にはしない。
- 名前を評価するときは、異なる実装でも同じ意味を保つかを問う。

### 3. 正確さ、一貫性、スコープを同時に見る

John Ousterhout の Stanford 公式講義ノートは、名前の目的を読み手の頭に適切な像を作ることとし、精密かつ具体的に、同じ種類の対象には同じ名前を使い、異なる種類に同じ名前を使わないとする。一方、極めて局所的な用途では `i` のような短い名前を例外として認める。[Choosing Names](https://web.stanford.edu/~ouster/cgi-bin/cs190-winter18/lecture.php?topic=names)

導出するルール:

- 名前単体の長短ではなく、スコープと周辺コンテクストを含む情報量で判断する。
- 同じ語を使った対象を一覧し、同じ心像・契約を作るか確認する。
- 名前が曖昧なら、コメントで補修する前に名前と責務を見直す。

### 4. 良い名前は一発で発明せず、段階的に発見する

Arlo Belshee の Naming as a Process は、命名を一度のひらめきで解くのではなく、コードから洞察を1つ得て名前へ記録する反復として扱う。[Naming as a Process](https://www.digdeeproots.com/articles/naming-process/naming-as-a-process/)

その段階は概ね次のように進む。

1. Missing / Misleading を、嘘であることが誰にでも分かる Obvious Nonsense にする。[Get to Obvious Nonsense](https://www.digdeeproots.com/articles/naming-process/get-to-obvious-nonsense/)
2. まずコードが行うことを1つだけ正直に表す Honest な名前にする。[Get to Honest](https://www.digdeeproots.com/articles/naming-process/get-to-honest/)
3. 分かった責務をすべて含む Completely Honest な名前に近づける。この段階では長さより、名前を信頼できることを優先する。[Get to Completely Honest](https://www.digdeeproots.com/articles/naming-process/get-to-completely-honest/)
4. 不自然に長い名前が露呈した責務の混在を、構造的 refactoring で分ける。[Get to Does the Right Thing](https://www.digdeeproots.com/articles/naming-process/get-to-does-the-right-thing/)
5. 定義側だけでなく利用箇所を読み、実装の説明から利用目的を表す Intent Revealing な名前へ上げる。[Get to Intent Revealing](https://www.digdeeproots.com/articles/naming-process/get-to-intent-revealing/)
6. 複数の intent-revealing names に共通する Whole Value を発見し、domain abstraction にする。[Get to Domain Abstraction](https://www.digdeeproots.com/articles/naming-process/get-to-domain-abstraction/)

Belshee は、命名できないテストやメソッドは、ビジネス理解または ubiquitous language の穴を示す可能性があるとも述べる。[What makes a good test suite?](https://arlobelshee.com/what-makes-a-good-test-suite/arlo-belshee/)

導出するルール:

- 「完璧な名前が出るまで作業を止める」ことを命名への執着と取り違えない。
- polished だが嘘をつく名前より、暫定性や未知が分かる名前を選ぶ。
- 長い名前を即座に短縮せず、責務混在を可視化する診断情報として使う。
- 適切に命名できない場合は、責務、境界、抽象化、ドメイン理解を調べる。

### 5. 新語は思考を圧縮するが、語彙コストも生む

Fowler は、名前を付けた recurring solution が設計語彙となり、高い抽象度で議論するための hook になる一方、一度しか現れない解法に職業語彙上の名前を足す価値はないとする。[Writing Software Patterns](https://martinfowler.com/articles/writingPatterns.html)

また、new term は既存語との混同を避け、evocative で、適度に短いことを目指すが、完全な造語は本人もできれば避けたいとしている。専門語彙にはコミュニケーションを圧縮する利点と、知らない人を排除する欠点の両方がある。[Neologism](https://martinfowler.com/bliki/Neologism.html)

導出するルール:

- 新語を追加する前に、既存の domain term、業界標準語、言語・framework の慣用語を検索する。
- 新語には、定義だけでなく、適用例、非適用例、近接語との差を持たせる。
- 一度きりの都合に大きな抽象名を与えない。再発性を示せない場合は局所名に留める。
- 略語や jargon は共有理解を圧縮するときだけ使い、説明責任を省く道具にしない。

### 6. 既存の名前を守るために誤った抽象化を守らない

Sandi Metz は、重複をまとめて名前を付けた抽象化が、新しい要件に合わせて条件分岐と parameter を増やし始めた場合、その抽象化が現在は誤っている可能性を示すとする。sunk cost に拘束されず、一度 inline して重複へ戻し、現在の要求から抽象化を発見し直すことを勧める。[The Wrong Abstraction](https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction)

導出するルール:

- 既存の共有名に似せるために、異なる intent を1概念へ押し込まない。
- 同じ実装であることと同じ意味であることを分ける。
- 名前の説明に例外、mode、flag、条件節が増える場合は、rename だけでなく抽象化の解体を候補にする。

### 7. 命名は「概念・単語・構成」に分解すると改善できる

Feitelson らの査読済み研究は、334人を対象とした実験から、同じ対象に2人の開発者が同じ名前を選ぶ確率の中央値は 6.9% と低かったと報告する。一方、明示的に次の3段階を使った被験者の名前は、元の実験で自由に選ばれた名前より2対1の割合で優れていると判定された。[How Developers Choose Names](https://doi.org/10.1109/TSE.2020.2976920) / [著者公開 preprint](https://arxiv.org/abs/2103.07487)

1. 名前に含める概念を選ぶ。
2. 各概念を表す単語を選ぶ。
3. 単語から識別子を構成する。

追試でも、単に「長く詳しく」と指示するだけでは改善せず、このモデルを明示的に使う場合に改善した。[Reproducing, Extending, and Analyzing Naming Experiments](https://arxiv.org/abs/2402.10022)

導出するルール:

- 候補名の好みを直接争わず、「何の概念を含めるか」「どの単語がその概念に合うか」「この言語でどう構成するか」を分けてレビューする。
- 複数の妥当な候補が出ることを異常扱いしない。候補が作る意味の差と利用時の読み方で決める。
- 詳細さを文字数で代理評価しない。

### 8. 言語と ecosystem の慣用は意味の一部である

Go 公式ガイドは、package 名を利用側が prefix として読むことを前提に `bufio.Reader` のような簡潔さを得る。長い名前が自動的に読みやすいわけではなく、標準的な `Read`、`Write`、`String` には canonical な意味があるため、同じ意味・signature でのみ使うとしている。[Effective Go: Names](https://go.dev/doc/effective_go#names)

Go の review guide は `util`、`common`、`misc` のように意味を持たない package 名を避ける一方、`Reader`、`Writer` の `-er` は明確な慣用として使う。[Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)

Rust API Guidelines も、`as_`、`to_`、`into_` に cost と ownership の意味を割り当て、word order や getter、iterator の命名を ecosystem 全体で揃える。[Rust API Guidelines: Naming](https://rust-lang.github.io/api-guidelines/naming.html)

導出するルール:

- project / language の established convention を、一般書の命名原則より先に確認する。
- `Manager`、`Util`、`-er` などをグローバルに禁止しない。曖昧さの smell として問い、言語の canonical term なら使う。
- 名前が cost、ownership、副作用、失敗条件などの契約を convention 上伝える場合、それを崩さない。

### 9. 公開名の rename は互換性変更である

Cargo の公式 SemVer guide は、public item の rename、move、remove を major change と分類し、旧名を deprecated にして re-export するなどの移行策を示す。[Cargo SemVer Compatibility](https://doc.rust-lang.org/cargo/reference/semver.html)

導出するルール:

- rename 前に、local/private、repository-wide、external/public のどの契約層かを分類する。
- public name では利用者、versioning、alias/deprecation、移行期間、release notes を検討する。
- schema field、設定キー、CLI flag、環境変数、event type、metric/log field、保存済みデータも code symbol と同様に外部参照され得る。

## 著名書籍の位置づけ

### 強い根拠として採用

- Eric Evans, *Domain-Driven Design*: 語彙をモデルとチーム活動に結び付け、意味の有効範囲を bounded context で区切る。
- Kent Beck, *Smalltalk Best Practice Patterns* / *Implementation Patterns*: intention-revealing names と、読み手へ意図を伝えるコードを設計原則に置く。[Implementation Patterns 公式ページ](https://www.informit.com/store/implementation-patterns-9780132799973)
- John Ousterhout, *A Philosophy of Software Design*: 正確さ、一貫性、スコープに応じた名前を system complexity の問題として扱う。[著者公式ページ](https://web.stanford.edu/~ouster/cgi-bin/aposd.php)

### 補助的に採用

Robert C. Martin, *Clean Code* は Meaningful Names の章で intention-revealing、descriptive、appropriate level of abstraction、standard nomenclature、unambiguous、side-effects など多数の heuristic を整理している。[出版社公式 sample / 目次](https://www.informit.com/content/images/9780132350884/samplepages/9780132350884.pdf)

ただし、本調査のルールの中心には置かない。理由は次の通り。

- heuristic の列挙は有用だが、Belshee や Feitelson のような「名前をどう発見・改善するか」というプロセスが弱い。
- `Clean Code` を絶対規則にすると、言語固有の canonical naming や、理解途上の長い honest name と衝突し得る。
- Ousterhout 自身も、`Clean Code` とは method length や comments などで重要な意見の違いがあると明記している。[A Philosophy of Software Design 公式ページ](https://web.stanford.edu/~ouster/cgi-bin/aposd.php)

### Phil Karlton の有名な言葉

「Computer Science には難しいことが2つだけある。cache invalidation と naming things だ」という言葉は広く Phil Karlton に帰属される。Fowler は2009年時点で満足な原典 URL を見つけられず、最古の online 記録を Tim Bray の blog としている。[Two Hard Things](https://martinfowler.com/bliki/TwoHardThings.html)

Karlton の息子 David は、父が Netscape 時代にこの言葉を使っていたと本人 blog で証言している。[Naming things is hard](https://www.karlton.org/2017/12/naming-things-hard/)

したがって本人の発言だった可能性は高いが、日時が確定した一次の出版物や録音は確認できない。これは導入の警句には使えても、具体的ルールの根拠には使わない。

## 推奨する AGENTS.md ルール案

### 強い版

```markdown
## Naming And Vocabulary

- 命名と語彙を設計・モデル・契約として扱い、意味の曖昧さに妥協しない。
- 用語を追加・変更・意味拡張する前に、既存のコードと文書を検索し、その語が表す概念、適用コンテクスト、近接する既存語との差を確認する。
- 同一コンテクストでは同じ概念に同じ語、異なる概念に異なる語を使う。名前は実装手段より利用側の意図を表し、project と言語の既存慣用を尊重する。
- 適切に命名できない場合は言葉だけを磨かず、理解不足、責務の混在、境界の誤り、欠けた抽象化、誤った抽象化を疑う。
- 非自明な命名では、採用名、検討した代案、意味上の trade-off を短く示す。不確実な名前は暫定性を隠さず、理解が増えた時点で rename する。
- 公開 API、schema、設定、CLI、event、永続化形式の名称変更は互換性変更として扱い、利用箇所と移行方法を確認する。
```

### 短い版

```markdown
命名と語彙を設計として扱い、意味の曖昧さに妥協しない。用語の追加・変更・意味拡張前に既存語彙と利用箇所を検索し、概念、コンテクスト、近接語との差を確認する。同一コンテクストでは同じ概念に同じ語、異なる概念に異なる語を使い、適切に命名できない場合は責務・境界・抽象化を見直す。非自明な命名では採用名、代案、trade-off を短く示し、公開名の変更は互換性変更として扱う。
```

### さらに強い一文を足す場合

```markdown
「動けばよい」「仮の名前でよい」「既存の曖昧な名前に合わせればよい」を理由に、誤解を生む名前を完成扱いしない。
```

この一文は強いが、Belshee の incremental naming と衝突しないよう、「仮名を禁止する」のではなく「完成扱いしない」とする。

## 避けるべきアンチパターン

### 意味のアンチパターン

- `正しい`、`適切`、`処理`、`実行`、`検証` のように、何がどうなるかを読み手へ復元させる名前。
- 定義位置や lifecycle 上の時点だけを示し、目的を示さない `preLoad`、`afterInit` 型の名前。
- 型名をそのまま小文字にしただけで、同型の他インスタンスとの違いを示さない名前。
- 実際の副作用、cost、ownership、失敗条件を隠す名前。
- 同一コンテクストで1概念に複数の同義語を増やす、または異なる概念を同じ語へ押し込む。
- 意味が希薄化した buzzword を定義・出典なしで使う。

### 設計のアンチパターン

- `Manager`、`Util`、`Common`、`Misc` へ責務を集め、名前の問題を container で隠す。
- 同じ実装だからという理由だけで、異なる intent を同じ名前・抽象化へまとめる。
- 不自然に長い名前を、責務を分割せず略語で短くする。
- 一度きりの処理に壮大な domain term を作る。
- 既存名を守るために mode flag と条件分岐を増やし続ける。

### 運用のアンチパターン

- すべての identifier について人間確認を要求し、局所的な rename まで停止させる。
- 最初の命名を永久の正解として扱う。
- 名前の長さ、接尾辞、略語だけを lint し、意味をレビューしたつもりになる。
- `Manager` や `-er` を言語とコンテクストを無視して一律禁止する。
- code symbol だけ rename し、test、docs、schema、config、telemetry、保存済みデータの語彙を残す。
- 公開名を IDE rename と同じ感覚で変更し、利用者の移行を設計しない。

## 運用チェックリスト

### 導入・変更前

- [ ] この名前が表す概念を1文で説明できるか。
- [ ] 適用する bounded context / module / scope はどこか。
- [ ] `rg` 等で同義語、類義語、同名異義語、旧名、関連する test/docs を確認したか。
- [ ] project、言語、framework、業界に canonical term がないか。
- [ ] 名前に含める概念、概念を表す単語、識別子の構成を分けて考えたか。
- [ ] local/private か、repository-wide か、external/public contract か。

### 候補の評価

- [ ] 定義だけでなく、代表的な call site、文章、エラーメッセージ、テスト名で自然に読めるか。
- [ ] 実装方法ではなく、利用者が期待する意図・post-condition・責務を表しているか。
- [ ] 近接概念と区別でき、同じ概念の既存語と無理由に競合しないか。
- [ ] 副作用、cost、ownership、失敗条件など、利用判断に必要な契約を隠していないか。
- [ ] 異なる2つ目の実装を想像しても同じ名前が成立するか。
- [ ] 候補を長くしただけでなく、情報が増えたか。

### 命名が難しい場合

- [ ] 対象が複数責務を持っていないか。
- [ ] 呼び出し側ごとに intent が異ならないか。
- [ ] primitive obsession や欠けた Whole Value がないか。
- [ ] 誤った共通抽象化へ複数概念を押し込んでいないか。
- [ ] 現時点で分かったことだけを正直に表す暫定名へ進められないか。

### 変更後

- [ ] 旧名、新名、同義語を再検索し、意図しない残存・重複がないか。
- [ ] code、test、docs、schema、config、CLI、event、telemetry の語彙が揃っているか。
- [ ] public contract なら alias / deprecation / version / migration / release note を用意したか。
- [ ] typecheck、test、lint だけでなく、代表的な利用箇所を人間として読み直したか。
- [ ] 非自明な採否の `Why` / `Why not` を必要な場所へ残したか。

## Agent に命名規則を認識・反映させる設計

### 結論

前節の「短い版」だけでは、価値観は伝わっても、agent がいつ何をすべきかを一意に決めにくい。命名規則を行動へ変えるには、少なくとも次を明示する必要がある。

1. **Trigger:** 何をしたら命名レビューを開始するか。
2. **Decision procedure:** どの順序で調べ、定義し、候補を比較するか。
3. **Positive / negative examples:** 違反例だけでなく、許容例と例外を示す。
4. **Verification:** 変更後に何を検索し、何を確認すれば完了か。
5. **Scope / escalation:** 自律的に決めてよい範囲と、人間判断が必要な契約境界。
6. **Enforcement:** 自然言語上の判断と、lint / test / hook / CI で機械的に保証する部分を分ける。

重要なのは指示量そのものではない。**判断に必要な情報は増やし、常時不要な情報は progressive disclosure へ逃がす**。`AGENTS.md` には発火条件、非交渉の意味規則、最小の手順、例外を置き、詳細な候補生成やレビュー手順は skill、機械判定可能な規則は lint / hook / CI に置く。

### Codex が `AGENTS.md` を認識する仕組み

Codex の公式ドキュメントと実装は、次の探索・結合規則を持つ。

- global scope では `$CODEX_HOME` の `AGENTS.override.md` を優先し、なければ `AGENTS.md` を読む。最初の非空ファイルだけが使われる。
- project scope では project root から current working directory までを下り、各 directory で `AGENTS.override.md`、`AGENTS.md`、設定済み fallback filename の順に最初の1ファイルを採用する。
- root から current directory の順で連結されるため、後に置かれる近い directory の指示が優先される。
- project instructions の総量は `project_doc_max_bytes` で制限され、既定は 32 KiB。上限を超えた後方の内容は切り詰められ得る。
- instruction chain は run / TUI session の開始時に構築される。同一 session 中にファイルを書き換えた場合、確実に評価するには新しい session を開始する。

公式実装では、候補名の優先順位、root-to-cwd の探索、byte budget、global instructions と project instructions の連結がそのままコード化されている。[`agents_md.rs`](https://github.com/openai/codex/blob/61de0d8fe812137cec943d58309b26df1dd227b5/codex-rs/core/src/agents_md.rs) / [`codex-home/src/instructions/mod.rs`](https://github.com/openai/codex/blob/61de0d8fe812137cec943d58309b26df1dd227b5/codex-rs/codex-home/src/instructions/mod.rs) / [公式 AGENTS.md ガイド](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

ここから分かる実務上の制約は次の通り。

- `AGENTS.md` は model-visible instruction であって、意味規則を実行する policy engine ではない。強い語調だけで遵守は保証されない。
- 大きい root file へ詳細を集約すると、専門外の task にも常時競合する。領域固有語彙は nested `AGENTS.md`、手順は skill に寄せる。
- 参照先の path だけを書いても、いつ、なぜ読むかがないと agent は優先度を判断できない。参照には trigger と得られる情報を併記する。
- 更新を検証するときは、古い session での挙動を観察し続けず、新規 session で active instruction sources を確認する。

### Codex 公式 repository の改善履歴

#### 抽象的な developer instruction を判断可能な条件へ変更

2026-06-04 の [PR #26367](https://github.com/openai/codex/pull/26367) は、multi-agent 利用について「分割する本当の理由があるとき」「単純な task は直接行う」という抽象的な developer instruction を追加した。

4日後の [PR #27037](https://github.com/openai/codex/pull/27037) / [commit `f9a680b9`](https://github.com/openai/codex/commit/f9a680b9075562093ff78e45ff4fcb2e9a0348f9) はこれをさらに具体化した。変更後は次の情報を与えている。

- default: まず自分で行う。
- positive gate: concrete、bounded、independent、local work と並行可能で、完了時間を実質的に短縮する subtask のときだけ spawn する。
- negative cases: simple task、small edit、routine search、短時間で自分が終えられる作業は委譲しない。
- decision point: 背景 developer instruction だけでなく、`spawn_agent` tool description にも同じ gate を置く。

これは「real reason」「simple」のような評価語だけでは足りず、**default、必要条件、非適用例、行動を選択する直前の reminder** が必要だった実例である。命名規則にも同じ構造を使うべきである。

#### `if applicable` が誤った文書追加を誘発

[PR #21772](https://github.com/openai/codex/pull/21772) / [commit `0a0d09ad`](https://github.com/openai/codex/commit/0a0d09ad21d60c5fad7c61f0565347280e52f197) 以前の `AGENTS.md` は、API 変更時に `docs/` を「該当する場合」更新するよう求めていた。PR の説明では、この指示の下で Codex が一般的な product documentation を repository の `docs/` へ繰り返し追加していた。

改善後は次を明示した。

- prohibited target: 一般的な product / user-facing documentation は local `docs/` に追加しない。
- source of truth: 公式文書は別の場所にある。
- exception: app-server API documentation だけは対象。
- local positive instruction: app-server section で、更新すべき具体的文書を示す。

曖昧な適用条件を強い命令へ変えたのではなく、**対象外、source of truth、例外、正しい行き先**を定義した点が重要である。

#### 弱い preference を順序付き手順へ変更

[PR #2306](https://github.com/openai/codex/pull/2306) / [commit `8bdb4521`](https://github.com/openai/codex/commit/8bdb4521c96b386d299052263b0cd7d58b431bf1) は、「個別 file / project の test を先にする」という弱い preference を、次の decision procedure に置き換えた。

1. 変更 project の test を実行する。
2. `tui` を変えた場合の具体的 command を例示する。
3. それが通り、かつ common / core / protocol を変えた場合だけ full suite を実行する。

命名でも「良い名前を選ぶ」ではなく、「既存語検索 → 概念定義 → 候補比較 → call site 評価 → 全 surface 再検索」の順序を明示する必要がある。

#### 具体的でも、scope が広すぎれば逆効果

[PR #7957](https://github.com/openai/codex/pull/7957) / [commit `596fcd04`](https://github.com/openai/codex/commit/596fcd040fc371b540a4cb9219c13ea54b248515) は、「負にならない値にも unsigned integer を使わない」という blanket rule を削除した。PR は、この規則が自然に unsigned な値にも余分な clamp / conversion を発生させ、不要な複雑性を作ったと説明する。

したがって、具体性は次と組み合わせなければならない。

- 適用 scope。
- safe exception。
- 禁止理由と、代わりに守る invariant。
- 規則適用による局所的な複雑化を許すかどうか。

命名規則で `Manager`、`Util`、略語、短い変数を一律禁止すると、同じ問題が起こる。問うべきなのは spelling ではなく、名前が実際の意味を正直に伝えるかである。

#### 機械判定可能な規則を agent の負担から CI へ戻す

[PR #16375](https://github.com/openai/codex/pull/16375) / [commit `5cca5c00`](https://github.com/openai/codex/commit/5cca5c0093045051b400d2215bba2fb13e7c7443) は、必須だった local lint 実行を optional にし、通常は cross-platform CI に任せるよう変更した。理由は Codex が local lint の完了待ちに時間を使いすぎていたためである。

命名でも casing、format、import order、既知の禁止語、旧語の残存などを毎回自然言語で考えさせるべきではない。機械判定できるものは tool に移し、`AGENTS.md` の instruction budget は意味、境界、契約、例外に使う。

### OpenAI の repository rule 評価から分かる書き方

OpenAI は Codex Code Review の repository rule を eval suite で検証し、rule-guided variant が必要な custom finding の 98% を回収したのに対し、baseline は 58.3% だったと報告している。一方、broad instruction は noise を作りやすく、小さく scoped な rule set と explicit safe path が有効だった。[Custom Code Review rules for Codex](https://developers.openai.com/blog/custom-code-review-rules-for-codex)

公式の推奨する検証単位は次の3つである。

1. rule が発火すべき consequential violation。
2. rule に似ているが許容される safe counterexample。
3. 無関係な change。

最初だけ finding が出て、後二者で noise が出ないことを確認して rule を調整する。この評価は命名規則にも直接転用できる。

- trigger case: 新しい public term が既存 canonical term の同義語を増やす。
- safe counterexample: receiver / module context により `invoice.total()` が十分明確である。
- unrelated case: typo 修正や generated code の更新。

公式記事が示す良い rule の構造は、**consequential invariant、適用 scope、safe path、durability** である。formatting などの mechanical check は CI に残す。

### context file の効果に関する実証研究

#### 指示は無視されるとは限らない。無関係でも従われることが問題

Gloaguen らは4種類の coding agent と複数 model を SWE-bench と新規 task set で評価した。LLM-generated context file は task success を有意に改善せず、step と inference cost を平均 20–23% 増やした。developer-written file も平均 2.4% の改善は統計的に有意でなく、cost と step を増やした。

trace analysis では、agent は context file の指示に概ね従い、test、repository exploration、指定 tool の利用を増やしていた。つまり問題は「無視された」ことではなく、**守る必要の薄い instruction まで忠実に実行された**ことにある。研究の結論は、codebase から既に得られる一般情報ではなく、project 固有で追加的な instruction だけを置くべき、というものである。[Evaluating AGENTS.md](https://arxiv.org/abs/2602.11988)

この研究は Python task が中心で、命名品質そのものは測っていない。それでも、命名規則を長くするなら各行が観測可能な行動を変える必要がある、という強い注意になる。

#### 効率改善を示す研究もあるが、正しさは未評価

Lulla らは10 repository、124 PR task を1つの root `AGENTS.md` の有無で比較し、`AGENTS.md` ありでは median runtime が 28.64%、median output token が 16.58%減ったと報告する。一方、functional correctness の包括評価は行わず、50 task の manual sanity check に留まる。[On the Impact of AGENTS.md Files](https://arxiv.org/abs/2601.20404)

2研究は矛盾して見えるが、評価対象が異なる。前者は task success と behavior を複数 agent / model で測り、後者は1 agent / model の operational efficiency を測る。したがって「短ければ常に良い」「長ければ常に悪い」とは言えない。**命名上の失敗を実際に減らすか、cost と noise が増えないかを repository の representative task で eval する**必要がある。

#### `AGENTS.md` に置かない方がよい内容

Santos らは100の `AGENTS.md` / `CLAUDE.md` を調べ、Lint Leakage 62%、Context Bloat 42%、Skill Leakage 35%、Conflicting Instructions 28件を検出した。少なくとも1つの smell があった file は91件だった。[Configuration Smells in AGENTS.md Files](https://arxiv.org/abs/2606.15828)

この研究は grey literature と heuristic detection を含む preprint で、smell が performance を因果的に下げることを直接示したものではない。ただし、次の分担を設計する evidence として有用である。

- format / casing / import order: formatter / linter。
- 稀な専門 workflow: skill。
- 大きい glossary / reference: on-demand document。
- conflicting or stale instruction: review と eval。
- project 固有の invariant / trigger / safe path: `AGENTS.md`。

### 推奨する、単独で機能する `AGENTS.md` 案

以下は、命名 skill をまだ用意しない段階でも agent が判断できる standalone 版である。

```markdown
## Naming And Vocabulary

命名と語彙を設計、domain model、利用者との契約として扱う。動作することだけを理由に、意味が曖昧または誤解を招く名前を完成扱いしない。

### Trigger

次の場合は、実装前に必ずこの手順を適用する。

- domain term、略語、module、type、function、method、field、event、API / schema / config / CLI key、metric、error name を追加または rename する。
- 既存語の意味を拡大、縮小、転用、翻訳、複数形化する。
- 同じ概念に別の語、または別の概念に既存語を使おうとする。

generated / vendored code、言語・framework が固定する canonical name、意味が極小 scope から完全に明らかな慣用 local (`i` など) には候補比較を強制しない。ただし誤解を招く名前は許容しない。

### Required Procedure

1. **Search:** `rg` 等で exact term、旧名、語形変化、略語、同義語、近接概念を code、test、docs、schema、config、event、telemetry から検索する。宣言だけでなく代表的な利用箇所を読む。
2. **Define:** 「この語は何を意味し、何を含み、何を含まず、どの context で有効か」を1文で定義する。定義できない場合は命名前に責務と domain understanding を調べる。
3. **Classify:** local/private、repository-wide domain language、external/public/persisted contract のどれかを判定する。
4. **Choose concepts first:** 名前に含める概念、各概念を表す canonical word、言語上の識別子構成を分けて決める。既存語が同じ概念を正確に表すなら新語を作らない。
5. **Compare:** 新しい非自明な語では少なくとも2つの候補を比較する。宣言、代表的な call site、test name、error/document sentence に置き、利用側の意図と実際の振る舞いが最も自然に一致する名前を選ぶ。
6. **Treat difficulty as design feedback:** 正直な名前が長い、候補を定義できない、`Manager` / `Util` / `Data` / `Info` / `Item` / `Process` / `Handle` のような広い語に逃げたくなる場合は、略す前に責務混在、誤った境界、欠けた domain abstraction を調べる。
7. **Propagate:** 同一 context では1概念1語、1語1意味を code、test、API、schema、config、CLI、event、telemetry、docs で維持する。terms of art と ecosystem の canonical name は確立した意味を変えない。
8. **Verify:** 変更後に旧名、採用しなかった同義語、意味が競合する既存語を再検索する。public / persisted name では caller、compatibility、alias / deprecation、migration、release note への影響を確認する。

### Decision And Escalation

- local/private で reversible な命名は、上記手順から最も正確な名前を選んで進める。人間の承認待ちにしない。
- domain の意味が複数に分かれる、または public / persisted contract の rename で互換性方針が決まっていない場合だけ、概念定義、候補、差、migration impact を示して確認する。
- 名前が不自然な設計を露呈した場合、task scope 内の小さい refactoring は行う。API / schema / permission boundary を変える必要がある場合は先に確認する。

### Calibration Examples

- Reject: `processData()`。何を、どの状態へ変えるかが不明。
- Prefer when true: `captureAuthorizedPayment()`。対象、precondition、outcome が読める。
- Reject: `returnsCorrectResult`。`correct` の意味を読み手へ押し付ける。
- Prefer when true: `rejectsExpiredAccessToken`。
- Accept: `invoice.total()`。receiver が context を供給するため `calculateInvoiceTotal()` は冗長。
- Accept: 小さい loop の `i`。scope が意味を完全に制限する。
- Reject: public field の `userId` を意味の近い `accountId` へ一括置換するだけ。概念差と migration が未確認。

### Completion Evidence

非自明な新語または rename を行った場合、最終報告に採用名と1文の意味、重要な代案を退けた理由、検索した影響範囲、互換性影響を簡潔に含める。単純な慣用 local name ごとの報告は不要。
```

### 推奨する実装レイヤー

| Layer | 置くもの | 置かないもの |
|---|---|---|
| global `AGENTS.md` | universal trigger、意味上の invariant、最低限の procedure、escalation boundary | repository 固有 glossary、全言語の casing rule、長い書籍要約 |
| repository / nested `AGENTS.md` | bounded context、source of truth、外部契約、領域固有の safe path | 全 repository に不要な workflow |
| naming skill | 候補生成、Belshee の段階的 naming、review checklist、glossary 更新手順、言語別例 | 毎 task へ常時注入する必要のない説明 |
| glossary / domain docs | canonical term、definition、includes / excludes、context、避ける synonym、migration history | agent への発火命令だけ |
| formatter / linter / static check | casing、spelling、既知の旧語、禁止された wire name、schema parity | semantic truthfulness の最終判断 |
| hook | diff から機械的違反を検出し、修正が必要なら continuation を要求 | LLM を使わない script による domain meaning の断定 |
| CI / compatibility tool | public API / schema break、generated artifact、legacy term、test | 候補名の美的評価 |
| Code Review | semantic drift、近接語との衝突、safe exception、migration completeness | formatter と重複する finding |

Codex の skill は metadata の name / description を先に見て、request と一致したときに完全な instruction を読み込む。したがって skill description には「rename と明示された task」だけでなく、「新しい domain concept、public API / schema / event / config key、type / method の追加」も trigger として書く必要がある。[Skills](https://developers.openai.com/plugins/concepts/skills)

hook は `PreToolUse` で tool call の拒否または追加 context の注入、`Stop` で追加作業を求める continuation が可能である。ただし現行の command hook は deterministic script であり、semantic naming review 全体を任せる場所ではない。[Hooks](https://learn.chatgpt.com/docs/hooks)

### 導入後の eval

規則を追加して終わりにせず、まず次の小さい fixture set を同じ model / agent 設定で繰り返す。

| Case | Fixture | 期待する挙動 |
|---|---|---|
| Trigger | 既存 `Customer` と同じ概念へ `Client` を追加する変更 | 既存語を検索し、同義語増加を止める |
| Trigger | public event `order.created` を rename | consumer と migration を調べ、無計画な置換を止める |
| Design signal | 複数責務を持つ `DataManager` の追加 | 単なる言い換えでなく責務分割を検討する |
| Safe counterexample | `invoice.total()` または小 scope の `i` | 冗長 rename や finding を出さない |
| Safe counterexample | language / framework の canonical term | 一般規則で改名しない |
| Unrelated | generated file、typo、値だけの変更 | 命名 workflow を発火させない |

各 case では次を観測する。

- 必要な source search を行ったか。
- 概念と近接語の差を説明できたか。
- unsafe rename を止めたか。
- safe counterexample で余計な refactoring や質問を増やさなかったか。
- steps、token、wall-clock、findings の noise が増えすぎていないか。
- final diff と報告に旧語残存、互換性漏れ、語彙 drift がないか。

rule が無関係な task まで発火するなら文章を弱めるのではなく、trigger と exception を狭める。違反を見逃すなら「命名に執着する」をさらに強調するのではなく、欠けていた条件、search target、counterexample、verification を追加する。

### 改訂した最終推奨

前節の短い版をそのまま global `AGENTS.md` に入れる案は撤回する。価値観の宣言としては正しいが、agent の decision procedure と完了条件が不足している。

最初は上記 standalone 版で behavior を eval する。その後、挙動が安定した部分を次の形へ分割する。

1. global `AGENTS.md` に trigger、semantic invariant、scope / escalation を残す。
2. required procedure、候補比較、詳細 checklist を naming skill へ移す。
3. project 固有の canonical vocabulary を repository / nested instruction と glossary に置く。
4. deterministic check を lint / hook / CI に移す。
5. trigger、safe counterexample、unrelated change の regression fixture を維持する。

この構成なら、命名への執着を「長い精神論」ではなく、発火可能で検証可能な workflow として agent に認識させつつ、すべての task へ詳細を常時注入する副作用を避けられる。

## Codex repo の instruction / skill 改善履歴からの追加知見

2026-07-28 時点の `openai/codex` の merged PR、現行 source、公式 manual を再確認した。以下は一般論ではなく、Codex 自身が instruction と skill の失敗を受けて変更した履歴から抽出した知見である。

### AGENTS.md と developer instruction の改善パターン

| Source | 変更前の問題 | Codex が行った変更 | この命名規則への適用 |
|---|---|---|---|
| [PR #21772](https://github.com/openai/codex/pull/21772) | API 変更時に docs を「if applicable」で更新するという曖昧な指示により、誤った local `docs/` が増えた | 禁止対象、正しい source of truth、app-server 例外、正しい更新先を明記 | 「命名に注意」ではなく trigger、対象 surface、除外、fallback、migration safe path を列挙する |
| [PR #2306](https://github.com/openai/codex/pull/2306) | targeted tests を「prefer」するだけで順序と全体 test の条件が不明 | project test を先に実行し、shared/core/protocol 変更時だけ全 suite へ進む分岐に変更 | naming workflow を順序付き state machine にし、public/persisted surface のときだけ compatibility branch へ進む |
| [PR #7957](https://github.com/openai/codex/pull/7957) | unsigned integer の blanket ban が clamp / conversion を増やした | blanket rule 自体を削除 | `Manager`、`Data`、短い名前を禁止語にしない。設計調査を発火させる signal とし、正当な例外を残す |
| [PR #15910](https://github.com/openai/codex/pull/15910) | `codex-core` に機能が集中した | rationale、trigger、代替配置、新 crate という safe path、review behavior をまとめて追加 | 命名困難の理由と、責務分割・既存語再利用・新 abstraction という代替経路を同じ箇所に置く |
| [PR #16375](https://github.com/openai/codex/pull/16375) | 高コスト lint のローカル実行を常に要求し、agent 時間を浪費 | CI に任せる既定と、必要時の local command に分離 | semantic judgment は skill、spelling・旧語・schema parity は lint / CI に分離する |
| [PR #27037](https://github.com/openai/codex/pull/27037) | 「real reason」があれば sub-agent を使うという曖昧な発火条件 | default、必要条件、非対象例を developer prompt と `spawn_agent` tool description の decision point の両方へ配置 | trigger を `AGENTS.md` だけに置かず、skill name / description と skill body の最初にも同じ境界語を置く |
| [PR #29086](https://github.com/openai/codex/pull/29086) | experimental という分類が実 consumer の compatibility を隠した | `rawResponseItem/*` を exact surface として明記 | public / serialized / persisted / consumed name は experimental でも migration 対象とする |

ここから得られる instruction の基本形は、強い形容詞ではなく次の組である。

1. **Default:** 通常はどうするか。
2. **Trigger:** どの観測可能な変更で workflow を開始するか。
3. **Ordered action:** 最初に何をし、何を満たしたら次へ進むか。
4. **Branch condition:** local/private と public/persisted で何が変わるか。
5. **Negative example:** 何には適用しないか。
6. **Safe path:** 問題を見つけたとき、禁止だけで終わらず何を選べるか。
7. **Completion evidence:** agent が実施したと検証できる出力は何か。

### skill 調整履歴からの追加知見

| Source | 確認できる事実 | 設計への反映 |
|---|---|---|
| [Codex skills manual](https://learn.chatgpt.com/docs/build-skills) | implicit invocation は name / description から始まり、description は短縮され得る。name と locator を含む catalog 自体にも context budget がある | skill 名だけでも責務が分かるようにし、description 冒頭へ主要 trigger を置く。重複 skill を増やさない |
| [PR #29006](https://github.com/openai/codex/pull/29006) | full metadata は保持しつつ、model-visible description は1件あたり最大 1024 Unicode characters に制限 | 1024文字後へ重要 trigger を置かない。長さではなく先頭の識別力を最適化する |
| [PR #34626](https://github.com/openai/codex/pull/34626) | skill catalog は resolved context window の2%、最大4,000 tokens。window 情報がなければ8,000 characters | 常時 install する skill 数と metadata 総量も activation 設計の一部として扱う |
| [PR #34732](https://github.com/openai/codex/pull/34732)、[PR #34738](https://github.com/openai/codex/pull/34738) | budget pressure では description を均等に短縮し、極端な場合は description を落として name / locator を優先する | `rigorous-naming` のように name 単体で品質基準と task family が分かる形にする |
| [PR #34785](https://github.com/openai/codex/pull/34785)、[PR #34997](https://github.com/openai/codex/pull/34997) | truncated / omitted count を計測し、大きな短縮や omission を warning にした | eval では応答だけでなく catalog truncation warning と実際の skill visibility を記録する |
| [PR #34581](https://github.com/openai/codex/pull/34581)、[PR #35663](https://github.com/openai/codex/pull/35663) | shadow experiment は name、description、short description、tool dependencies、`agents/openai.yaml` の display name / default prompt などの routing field を評価している | 現行 production selection と断定はしないが、全 routing metadata で同じ canonical vocabulary を使う |
| [PR #27044](https://github.com/openai/codex/pull/27044) | 「read only enough」が後半の routing / verification 条件を落とすため、選択した `SKILL.md` の EOF までの完全読了と、必要 reference の main-agent 読了を必須化 | core workflow と Definition of Done は `SKILL.md` に置く。reference は明確な条件で選び、選んだ file は完全に読む |
| [PR #18818](https://github.com/openai/codex/pull/18818) | “Make sure to return every issue” を “You must return every single issue from every subagent” へ変更 | `consider` / `prefer` を使わず、必須 output と量化対象を `must` で示す |
| [PR #13600](https://github.com/openai/codex/pull/13600) | complex skill の forward test を追加し、期待解や診断を test agent に漏らさず raw artifact と realistic prompt を渡すよう明記 | activation test と workflow test を新規 session で分け、期待結果は prompt 外で採点する |
| [PR #35661](https://github.com/openai/codex/pull/35661) | host skills を permission instructions より前へ移動し、順序を regression test で固定 | prompt section の順序を behaviorally material とみなし、命名 router を global instruction の冒頭側へ置く。これは変更事実からの設計上の推論である |

`#34581` と `#35663` は shadow selection experiment であり、その scoring が現在の implicit invocation を直接決めているとは限らない。ここから採用するのは exact weight ではなく、name、description、UI metadata に同じ用語を通し、routing を golden prompt で測るという設計原則である。

### 改訂する hybrid architecture

前回案から次を変更する。

1. `AGENTS.md` は短くするが、単なる価値観ではなく **exact skill router + minimum fallback** とする。
2. upstream `evolutionary-naming` を残したまま類似 skill を追加しない。catalog 競合と advisory-only の衝突を避けるため、owned replacement へ差し替える。
3. skill 名は `rigorous-naming` とする。name だけで厳密な命名 workflow だと分かり、description が落ちても識別可能である。`design-names-and-vocabulary` は対象の列挙に寄り、実装中の検証・伝播・互換性確認までを担う厳密さが伝わりにくいため採用しない。
4. `SKILL.md` を単なる reference index にしない。default mode、ordered procedure、branch、escalation、Definition of Done は本体へ置く。
5. 詳細な evolutionary refactoring と calibration だけを conditional reference に分離する。
6. implicit activation と explicit workflow quality を別々に eval する。

### 改訂する AGENTS.md router preview

```markdown
## Rigorous Naming

Treat names and vocabulary as part of the design, domain model, and user-facing contract.

Before writing or changing any non-trivial identifier or domain term, load and follow the `$rigorous-naming` skill. Do this even when naming is incidental to a larger implementation task. The trigger includes adding, renaming, repurposing, translating, abbreviating, broadening, or narrowing modules, types, functions, fields, APIs, schemas, configuration or CLI keys, events, telemetry, errors, tests, and documentation terms.

Do not complete the task until the skill's Definition of Done is satisfied. If the skill cannot be loaded, say so and perform this minimum safe path: search existing and adjacent terms; define the concept and its exclusions; classify the contract surface; compare serious candidates at use sites; propagate the selected term; and verify stale terms and compatibility impact.

Skip the full workflow for generated or vendored code, mechanically prescribed names, established terms of art, and conventional tiny-scope locals. Never use an exception to preserve a misleading name. Ask only when the domain meaning is genuinely ambiguous, established concepts would be merged or split, or a public or persisted rename lacks a compatibility strategy.
```

この router は decision point を三重化する。

- global `AGENTS.md`: 通常実装でも発火させる。
- skill `name` / `description`: implicit routing と explicit invocation の両方を支える。
- `SKILL.md` 冒頭: file edit 前の naming gate と mode selection を再確認する。

詳細 procedure は重複させない。重複するのは trigger と境界だけにし、workflow の source of truth は skill とする。

### 改訂する skill metadata preview

```yaml
---
name: rigorous-naming
description: Apply rigorous naming to non-trivial identifiers and domain vocabulary during implementation, refactoring, review, and verification. Use before work adds, renames, repurposes, translates, abbreviates, broadens, or narrows names in modules, types, functions, fields, APIs, schemas, configuration or CLI keys, events, telemetry, errors, tests, or documentation, even when naming is incidental to a larger task. Use audit mode only for explicit report-only requests. Skip generated or vendored code, mechanically prescribed names, established terms of art, and conventional tiny-scope locals.
---
```

```yaml
interface:
  display_name: "Rigorous Naming"
  short_description: "Apply rigorous naming to identifiers and domain terms"
  default_prompt: "Use $rigorous-naming to design and verify every non-trivial name introduced by this change."
```

name、description、display name、short description、default prompt で `rigorous`、`naming`、`identifiers`、`domain terms` を意図的に揃える。これは同義語を大量に詰めるのではなく、ユーザーが使う主要な表現と canonical skill identity を一致させるためである。

### 改訂する skill body

`SKILL.md` は次の順序にする。

1. **Default mode:** ordinary implementation では `embedded`。advisory-only にせず、task が許可した edit を行う。
2. **Mode selection:** `embedded`、specific identifier の `improve`、明示的 report-only の `audit`。
3. **Pre-edit gate:** 非自明な名前を初めて file に書く前に search、definition、surface classification を済ませる。
4. **Decision procedure:** concepts → words → identifier、2候補比較、use-site evaluation、design feedback。
5. **Branch:** local/private は自律的に進め、public/persisted は compatibility plan を確認する。
6. **Propagation:** code、test、API、schema、config、CLI、event、telemetry、docs を更新する。
7. **Verification:** old term、rejected synonym、semantic collision、consumer を再検索する。
8. **Definition of Done:** chosen term、one-sentence definition、rejected alternative、searched surfaces、compatibility impact を final report に出す。

`references/evolutionary-refactoring.md` は、正直な名前が長い、複数責務が見える、missing domain abstraction が疑われる場合だけ読む。`references/calibration.md` は候補の優劣が拮抗する場合、audit、skill eval のときだけ読む。通常の embedded task で全 reference を常時ロードしない。

### activation と workflow を分離した eval

一つの end-to-end test だけでは、失敗が「skill が選ばれなかった」のか「選ばれたが手順が弱かった」のか判別できない。次の三層で測る。

1. **Activation suite:** skill 名を prompt に書かない。direct、indirect、incidental、negative prompt で実際に load されたかを測る。
2. **Workflow suite:** `$rigorous-naming` を明示し、routing を bypass して search、definition、candidate comparison、propagation、verification の質だけを測る。
3. **Integration suite:** global `AGENTS.md` router と installed catalog を含む新規 session で、通常実装中の incidental naming が end-to-end で守られるかを測る。

各 suite では次を記録する。

- selected / read skill と instruction source。
- skill catalog の description truncation / omitted warning。
- trigger coverage と negative-case restraint。
- required step retention。
- routine local change で不要な質問をしない actionability。
- public / persisted change の migration completeness。
- token、wall-clock、余計な search / refactor。

forward-test prompt には期待する skill 名、想定 diagnosis、正解候補を書かない。raw fixture と通常の user request だけを渡し、期待結果は外部 rubric で採点する。metadata の tuning では一度に一 field だけ変え、activation regression を再実行する。

### 改訂した導入順序

1. 現在の standalone `AGENTS.md` を baseline として fixture 結果を保存する。
2. `ryo-morimoto/skills` に `rigorous-naming` を作成し、explicit workflow suite を通す。
3. skill repo を commit / push して immutable commit id を得る。
4. dotfiles の APM dependency から `kawasima/evolutionary-naming` を外し、新 skill の pinned commit を追加する。
5. `apm install --global` で catalog と lockfile を再生成し、truncation / omission warning と skill visibility を確認する。
6. global `AGENTS.md` を router 版へ縮める。
7. activation suite と integration suite を新規 session で実行する。
8. failure が activation なら metadata、workflow なら `SKILL.md`、noise なら trigger / exception を一箇所ずつ変更する。
9. skills repo と dotfiles repo を別 commit として反映する。

これにより、AGENTS.md の常時ロードによる確実な発火と、skill の progressive disclosure を両立しつつ、Codex 自身が修正してきた曖昧指示、blanket rule、catalog pressure、不完全読了、汚染された eval の失敗を避けられる。
