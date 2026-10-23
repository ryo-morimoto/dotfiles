---- MODULE Rollback ----
\* D-V1: 更新と巻き戻し (ADR-0002)。REL-1 / REL-2 を守る設計のモデル。
\*
\* 何をモデルにしたか (出典は各行のコメント):
\*   - snap-pac: pacman のトランザクションごとに pre / post のスナップショットを取る。
\*       snap-pac 3.0.1 (Arch extra)、extra/snap-pac.ini の important_packages は既定で無効。
\*   - snapper の number cleanup: 新しい順に、最初の NUMBER_LIMIT 件と、important=yes の最初の
\*       NUMBER_LIMIT_IMPORTANT 件を残し、残りを消す。
\*       snapper commit a4fb1ef client/cleanup.cc:530-560 (NumberCleaner::calculate_candidates)。
\*   - limine-snapper-sync: 新しいスナップショットに起動エントリを足す。ESP の使用率が上限なら足さない。
\*       MAX_SNAPSHOT_ENTRIES を超えたら古いエントリから消す (important は見ない)。
\*       limine-snapper-sync commit b4c0da2 SnapshotManager.java:68-127、README の LIMIT_USAGE_PERCENT。
\*   - limine-snapper-restore: 選んだスナップショットを戻し、壊れた側を "backup" として残す。README:38。
\*   - 提案 (ADR-0002 への追加): ログインできたら、そのときの状態のスナップショットを important=yes と
\*       desktop_good=yes で作る (MarkGood)。pacman のフックが、更新すると最新の desktop_good の起動エントリが
\*       MAX_SNAPSHOT_ENTRIES で押し出される場合に更新を止める (GuardEviction)。
\*
\* 抽象化 (モデルが扱わないこと):
\*   - 時間 (15 分) は扱わない。機能テストで測る。
\*   - snapper の MIN_AGE と pre/post の組の扱いは省いた。どちらも実物は「より多く残す」方向にしか
\*     働かないので、このモデルで規則が成り立てば実物でも成り立つ (逆は言えない)。
\*   - ESP の容量はエントリの件数で数える (カーネルの重複排除は数えない。こちらも保守的)。
\*   - 「動いた」はログインできたことで判定する。ログインできるが一部が壊れている場合は扱わない。
\*   - スナップショットから起動している間は cleanup を走らせない (前提。機能テストで確かめる)。
\*   - ホームの設定の復元 (snapper -c home undochange) は常にできるとした。

EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Limit,              \* snapper NUMBER_LIMIT
    LimitImportant,     \* snapper NUMBER_LIMIT_IMPORTANT
    MaxEntries,         \* limine-snapper-sync MAX_SNAPSHOT_ENTRIES (数値で指定する)
    EspCap,             \* ESP が LIMIT_USAGE_PERCENT 未満で持てるエントリの数
    TxPerUpdate,        \* 1 回の decman の実行が呼ぶ pacman のトランザクション数
    MarkGood,           \* 提案: ログインできたら important=yes のスナップショットを作る
    GuardEviction,      \* 提案: 最新の desktop_good のエントリが押し出される更新を pacman のフックで止める
    ImportantOnUpdate,  \* snap-pac の important_packages を有効にする (既定は無効)
    PickOnlyMarked,     \* 提案: 復元は desktop_good の付いたスナップショットからだけ行う (復元用のラッパーが拒む)
    Bound               \* 探索の上限: スナップショットの数

VARIABLES
    sys,        \* "works" | "broken" | "settings" (旧版に戻ったが、設定が新しい形式のまま)
    booted,     \* "normal" | "snapshot" (ブートメニューでスナップショットを選んで起動した)
    picked,     \* 選んだスナップショットの位置 (0 = 選んでいない)
    healthy,    \* 直近の起動でログインできたか
    migrated,   \* 壊した新版が、ユーザー設定を新しい形式に移したか
    again,      \* 壊れたまま更新したか (図の状態を分けるためだけに使う)
    snaps       \* スナップショットの列。先頭が最も新しい

vars == <<sys, booted, picked, healthy, migrated, again, snaps>>

\* good: その状態で作業面が動く (モデルだけが知る真実)。important: snapper の userdata important=yes。
\* marked: 提案の userdata desktop_good=yes (ログインできた状態にだけ付く)。entry: 起動エントリがある。
Snap == [good : BOOLEAN, important : BOOLEAN, marked : BOOLEAN, entry : BOOLEAN]

Entries(s) == Cardinality({i \in 1..Len(s) : s[i].entry})

\* limine-snapper-sync: MAX_SNAPSHOT_ENTRIES を超えた古いエントリを消す (SnapshotManager.java:111-125)
Prune(s) == [i \in 1..Len(s) |->
                [s[i] EXCEPT !.entry = @ /\ Cardinality({j \in 1..i : s[j].entry}) <= MaxEntries]]

\* スナップショットを1つ作る。ESP が上限なら起動エントリは足さない (README: LIMIT_USAGE_PERCENT)
NewSnap(s, good, imp, mark) ==
    Prune(<<[good |-> good, important |-> imp, marked |-> mark, entry |-> Entries(s) < EspCap]>> \o s)

\* decman の1回の実行: トランザクション t = 1..n のそれぞれで pre と post を取る。
\* k 番目のトランザクションで壊れる (k = 0 なら壊れない)。g は実行前の状態が動いていたか。
RECURSIVE Run(_, _, _, _, _)
Run(s, t, n, g, k) ==
    IF t > n THEN s
    ELSE LET pre   == NewSnap(s, g, ImportantOnUpdate, FALSE)
             gNext == g /\ t # k
             post  == NewSnap(pre, gNext, ImportantOnUpdate, FALSE)
         IN Run(post, t + 1, n, gNext, k)

\* snapper の number cleanup (client/cleanup.cc:530-560)。新しい順に見て、
\* important で num_important < LimitImportant なら残す。num < Limit なら残す。
RECURSIVE KeepFrom(_, _, _, _)
KeepFrom(s, i, num, ni) ==
    IF i > Len(s) THEN <<>>
    ELSE LET byImp  == s[i].important /\ ni < LimitImportant
             byNum  == num < Limit
             rest   == KeepFrom(s, i + 1, IF byNum THEN num + 1 ELSE num,
                                          IF byImp THEN ni + 1 ELSE ni)
         IN IF byImp \/ byNum THEN <<s[i]>> \o rest ELSE rest

GoodEntryExists == \E i \in 1..Len(snaps) : snaps[i].good /\ snaps[i].entry

\* 提案のフック: 最新の desktop_good で起動エントリのあるスナップショットより新しいエントリの数に、
\* この更新で増える数 (2 * TxPerUpdate) を足しても MAX_SNAPSHOT_ENTRIES に収まるときだけ更新させる。
\* 該当するスナップショットが無ければ止める (fail-closed)。
MarkedEntries == {i \in 1..Len(snaps) : snaps[i].marked /\ snaps[i].entry}
GuardAllows ==
    /\ MarkedEntries # {}
    /\ LET i == CHOOSE j \in MarkedEntries : \A x \in MarkedEntries : j <= x
       IN Entries(SubSeq(snaps, 1, i - 1)) + 2 * TxPerUpdate < MaxEntries

CanUpdate ==
    /\ booted = "normal"
    /\ sys \in {"works", "broken"}
    /\ GuardEviction => GuardAllows

TypeOK ==
    /\ sys \in {"works", "broken", "settings"}
    /\ booted \in {"normal", "snapshot"}
    /\ picked \in 0..Bound + 3
    /\ healthy \in BOOLEAN
    /\ migrated \in BOOLEAN
    /\ again \in BOOLEAN
    /\ snaps \in Seq(Snap)

Init ==
    /\ sys = "works"
    /\ booted = "normal"
    /\ picked = 0
    /\ healthy = TRUE
    /\ migrated = FALSE
    /\ again = FALSE
    \* インストール直後のスナップショット。動いた状態で、起動エントリがある。
    /\ snaps = <<[good |-> TRUE, important |-> MarkGood, marked |-> MarkGood, entry |-> TRUE]>>

\* 更新して、問題なく動く (snap-pac の pre/post。壊れない)
UpdateSucceeds ==
    /\ CanUpdate /\ sys = "works"
    /\ snaps' = Run(snaps, 1, TxPerUpdate, TRUE, 0)
    /\ healthy' = FALSE
    /\ migrated' = FALSE
    /\ UNCHANGED <<sys, booted, picked, again>>

\* 更新して、壊れる (k 番目のトランザクションで壊れる。新版は設定を移すことがある)
UpdateBreaks ==
    /\ CanUpdate /\ sys = "works"
    /\ \E k \in 1..TxPerUpdate, m \in BOOLEAN :
          /\ snaps' = Run(snaps, 1, TxPerUpdate, TRUE, k)
          /\ migrated' = m
    /\ sys' = "broken"
    /\ healthy' = FALSE
    /\ UNCHANGED <<booted, picked, again>>

\* 更新の途中で電源が落ちる (k 番目の pre を取ったところで止まる)
PowerFails ==
    /\ CanUpdate /\ sys = "works"
    /\ \E k \in 1..TxPerUpdate :
          snaps' = NewSnap(Run(snaps, 1, k - 1, TRUE, 0), TRUE, ImportantOnUpdate, FALSE)
    /\ sys' = "broken"
    /\ healthy' = FALSE
    /\ UNCHANGED <<booted, picked, migrated, again>>

\* 壊れたまま、さらに更新する
UpdateAgainWhileBroken ==
    /\ CanUpdate /\ sys = "broken"
    /\ snaps' = Run(snaps, 1, TxPerUpdate, FALSE, 0)
    /\ again' = TRUE
    /\ UNCHANGED <<sys, booted, picked, healthy, migrated>>

\* ログインできた (提案: そのときの状態を important=yes、desktop_good=yes のスナップショットにする)
DesktopStarts ==
    /\ booted = "normal" /\ sys = "works" /\ ~healthy
    /\ healthy' = TRUE
    /\ snaps' = IF MarkGood THEN NewSnap(snaps, TRUE, TRUE, TRUE) ELSE snaps
    /\ UNCHANGED <<sys, booted, picked, migrated, again>>

\* snapper の cleanup のタイマー
Cleanup ==
    /\ booted = "normal"
    /\ snaps' = KeepFrom(snaps, 1, 0, 0)
    /\ snaps' # snaps
    /\ UNCHANGED <<sys, booted, picked, healthy, migrated, again>>

\* ブートメニューでスナップショットを選んで起動する。
\* PickOnlyMarked が偽なら、利用者は印の無いもの (壊れているかもしれない) も選びうる。
PickSnapshot ==
    /\ booted = "normal" /\ sys = "broken"
    /\ \E i \in 1..Len(snaps) :
          /\ snaps[i].entry
          /\ PickOnlyMarked => snaps[i].marked
          /\ picked' = i
    /\ booted' = "snapshot"
    /\ UNCHANGED <<sys, healthy, migrated, again, snaps>>

\* 復元して再起動する (limine-snapper-restore。壊れた側を backup として残す)
RestoreAndReboot ==
    /\ booted = "snapshot"
    /\ sys' = IF ~snaps[picked].good THEN "broken"
              ELSE IF migrated THEN "settings" ELSE "works"
    /\ booted' = "normal"
    /\ picked' = 0
    /\ healthy' = FALSE
    /\ snaps' = NewSnap(snaps, FALSE, FALSE, FALSE)
    /\ again' = FALSE
    /\ UNCHANGED migrated

\* ホームの指定したパスを戻す (snapper -c home undochange)
RestoreHomePaths ==
    /\ sys = "settings"
    /\ sys' = "works"
    /\ migrated' = FALSE
    /\ UNCHANGED <<booted, picked, healthy, again, snaps>>

Next ==
    \/ UpdateSucceeds \/ UpdateBreaks \/ PowerFails \/ UpdateAgainWhileBroken
    \/ DesktopStarts \/ Cleanup \/ PickSnapshot \/ RestoreAndReboot \/ RestoreHomePaths

Spec == Init /\ [][Next]_vars

\* 探索の上限 (スナップショットの数)
WithinBound == Len(snaps) <= Bound

\* 合意した規則 (2026-10-24): 作業面が壊れたとき、ブートメニューには必ず動いた状態のエントリが残っている。
\* handoff.md の名前では AlwaysAWorkingStateReachable にあたる。
NoWayBack == (sys = "broken" /\ booted = "normal") => GoodEntryExists

\* 押し出しを止めるフックが fail-closed なので、印が無いと更新が一切できなくなり、NoWayBack は空虚に成り立つ。
\* それを検出する規則: 作業面が動いていて、この起動でまだ更新していない (healthy) ときは、更新できる。
UpdatesStayPossible ==
    (sys = "works" /\ booted = "normal" /\ healthy) => (GuardEviction => GuardAllows)

====
