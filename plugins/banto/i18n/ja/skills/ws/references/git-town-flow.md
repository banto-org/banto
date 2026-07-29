# git-town flow — 3 階層運用の詳細手順（epic / task / done / ship）

> 設計: git-town + `claude -w` の薄いラッパ。コマンド＝エイリアス、自然文＝主経路（intent-first。設計判断済み）。
> コマンド意味論は **Git Town 23.0.2 で実機検証済み**（2026-06-10）。

## 前提チェック（全操作の冒頭で 1 回）

```bash
command -v git-town >/dev/null 2>&1 && echo "git-town あり" || echo "git-town なし"
# main ブランチ設定が無ければ非対話で設定
git config git-town.main-branch >/dev/null 2>&1 || git config git-town.main-branch "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main)"
```

git-town **なし**の場合: 各操作の「fallback」を使い、初回のみ
「`brew install git-town` を入れると epic 更新の全 task への自動伝播（sync）が効くようになります」と 1 度だけ案内（毎回言わない）。

## epic — 大枠ブランチ作成（L2: 採用解釈つき提案）

発話例: 「決済リデザインを始める」「大きめの作業に入る」

1. **誤発火ガード**: 単発の小さな作業に epic を提案しない。目安 — 複数の独立サブタスクに分かれる / 数日以上かかる / 並走が予想される。迷ったら通常 feature ブランチで開始し、後から昇格を提案。
2. uncommitted changes チェック（あれば中止して報告）
3. ブランチ作成: `git town hack <epic-name>`（main から分岐・parent=main が記録される）
   - fallback: `git checkout main && git pull && git checkout -b <epic-name>`
4. WS 実体作成（`/ws new` と同じ手順。スコープは `[feat]` 既定）+ ポインタ更新
5. 報告: 「epic `<name>` を切りました（採用解釈: ○○。不要なら巻き戻せます）」

## task — 小枠 worktree 切り出し（epic 確立後は自走）

発話例: 「API は並行で」「これは別 worktree で進めて」

1. **必ず epic checkout 上で実行**（`git town append` は **current の子**を作るため。実機確認済み）。
   現在 epic 上にいなければ `git checkout <epic>` してから:
   ```bash
   git town append <task-name>          # epic の子として作成（parent=epic が記録される）
   git checkout <epic>                  # epic に戻る（worktree add のため task を空ける）
   git worktree add "../$(basename "$PWD")-wt-<task-name>" <task-name>
   ```
   - fallback: `git checkout -b <task-name> <epic>` + 同 worktree add（parent 追跡なし＝sync 不可、rebase 手動）
2. 案内: 「`../<repo>-wt-<task>` に物理分離しました。既定は banto が実行を駆動します（独立・非競合なら fan-out Agent、それ以外はこのセッションのまま worktree の作業を進めます）。真に独立した長時間の並走が必要なときだけ、there で素の `claude` を手動起動するオプションがあります（`claude -w` は新しい worktree を別途作る臨時分離のため、この task 並走では使わない）」。手動起動を選ぶ場合はフラグなしの素の `claude` を既定とする（モデル選定は都度の判断 — 処方的な既定は置かない）
3. 並走時は session-registry / 艦隊 dashboard に自動で載る（P4 core）。同一ブランチ衝突は pending で警告される

## sync — drift 伝播（帳簿系: 黙って自動）

- **いつ**: task セッションの開始時 / done の直前 / epic に直接コミットが入った後
- **何を**: `git town sync`（epic→全 task へ連鎖伝播。**worktree 内からも動作することを実証済み**）
- conflict が出たら止めて報告（自動解決しない）
- fallback（git-town なし）: sync は使えない。task worktree 内で `git merge <epic>`（または `git rebase <epic>`）で epic の更新を手動同期する。エラーではなく想定内の degraded 動作である旨を初回のみ明示する（毎回言わない）

## done — 小枠完了（L3: 自動実行・結果報告のみ）

発話例: 「この作業終わった」「task 完了」/ tasks.md の全項目チェックを検知した時に提案

1. テスト実行 → PASS 確認（FAIL なら done を中止して報告。連続失敗は TF カウンタで周回を止める）
2. **親確認（安全チェック・必須）**: マージ先が意図した epic か検証
   ```bash
   git config "git-town-branch.$(git branch --show-current).parent"   # → epic 名のはず
   ```
   親が main や別ブランチなら**中止して報告**（append を打つ場所を誤った可能性）
   - parent config が空の場合（git-town 不在 or plain-git で作成したブランチ）: この git-town 依存チェックをスキップし、現在ブランチの分岐元を口頭確認する代替に置き換える（空を「親不一致」と誤判定して中止しない）
3. task ブランチ上で: `git town merge`（**親 epic へマージ + task ブランチ自動削除**。実証済み。
   `git town ship` は使わない — main 行き専用で stacked 子では「親ごと ship」拒否になる）
   - マージ方式はツール既定（通常 merge）。squash が必要な場合のみ手動 `git checkout <epic> && git merge --squash <task>`
   - fallback（git-town なし）: `git checkout <epic> && git merge <task> && git branch -d <task>`
4. `git town sync` で他 task へ伝播 → worktree 掃除:
   ```bash
   git worktree remove "../<repo>-wt-<task>" 2>/dev/null || git worktree prune
   ```
5. 報告のみ: 「`<task>` を epic にマージし worktree を掃除しました。残 task: …」

## ship — epic → main（人間ゲート: PR 作成前に 1 回確認）

発話例: 「main に入れて」「リリースして」「これで出して」

1. 全 task が done か確認（残っていれば列挙して確認）
2. `git town sync` → テスト一式 PASS 確認
3. **確認（唯一の人間ゲート）**: 「epic `<name>` → main の PR を作成します。よろしいですか」
4. `git town propose`（forge 未設定なら fallback: `gh pr create --base main --head <epic>`）
5. main への直接 push は odd-kill-switch が block（escape 不可の構造ゲート）。dev/stg の CI ゲートは PR 側パイプラインに委譲

## トラブルシュート

| 症状 | 原因 | 対処 |
|---|---|---|
| `git town merge` が main に向かう | append を main 上で打った（parent=main） | done 手順 2 の親確認で検知 → `git town set-parent` で付け替え |
| `ship would ship epic as well` | stacked 子に `git town ship` を使った | 仕様。`git town merge` を使う |
| sync で conflict | epic と task が同一ファイルを編集 | 自動解決せず報告。AGENTS.md のファイル所有権マッピングを推奨 |
| worktree が消せない | uncommitted changes が残存 | 内容を報告し、ユーザー判断（force しない） |

## 実務上限・既知の注意

- worktree 並走は 4–8 が実務上限
- 長命 epic は 1–2 週サイクルで main に rebase + sync
- Agent `isolation: worktree`（サブエージェント worktree）はまだ不安定 — 重要タスクは手動確認
