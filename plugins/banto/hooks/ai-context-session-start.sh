#!/bin/sh
# AI Context SessionStart Hook
# セッション開始時（startup/resume/clear/compact後）にコンテキストを注入する。
# /clear でのコンテキスト消失を防ぐのが主目的。
# stdout がそのまま新セッションのコンテキストに追加される。
# POSIX互換: macOS / Linux / WSL

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // .matcher // empty' 2>/dev/null)

# --- コンテキスト上限警告（checkpoint-recommend.sh）の境界整合 ---
# checkpoint-recommend は token-monitor statusline が tmp に書く context% を読み 70/80/90 で警告する。
# compact / clear はコンテキストを解放する境界（多くの場合 session_id も切り替わる）。直後は
#   1) stale な pct 値を除去し、2) warned ベースラインを 90 に上げて全抑止する。
# statusline が解放後の実 % を書き直すと checkpoint-recommend が warned を現在地へ引き下げて再アーム
# するため、直後の誤発火を消しつつ、再びコンテキストが埋まれば正しく再警告できる。
# denylist より前・CWD 必須化より前に置く（token tmp は project 非依存の session ephemera のため）。
_TOKDIR="${TMPDIR:-/tmp}"
find "$_TOKDIR" -maxdepth 1 -name 'banto-token-*' -mtime +3 -delete 2>/dev/null  # 旧 session の無制限蓄積を掃除
case "$SOURCE" in
    compact|clear)
        _SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
        if [ -n "$_SID" ]; then
            rm -f "$_TOKDIR/banto-token-pct-$_SID" 2>/dev/null
            echo 90 > "$_TOKDIR/banto-token-warned-$_SID" 2>/dev/null
        fi
        ;;
esac

[ -z "$CWD" ] && exit 0

# scaffold 関数を source（denylist 判定にも使う）
SCRIPT_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/hooks"}
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -f "$SCRIPT_DIR/_ai-context-scaffold.sh" ]; then
    . "$SCRIPT_DIR/_ai-context-scaffold.sh"
    # denylist マッチなら hook 全体をサイレントスキップ
    if _ai_context_should_skip "$CWD"; then
        exit 0
    fi
fi

# --- ハーネス未セットアップの自動提案（自走ハーネス原則 v5.21.0 / setup の script 化 v5.45.0） ---
# code project らしく かつ CLAUDE.md 不在なら、ネイティブ /init（CLAUDE.md 生成）+ harness-setup.sh
# （rules / settings / store の決定論セットアップ）を提案する。「人間が起動を覚えておく」摩擦を消す
# （提案のみ）。旧 init-harness skill は撤去し、CLAUDE.md 生成は /init に委譲・残りは script に降ろした。
# denylist (_ai_context_should_skip) で抑止可能。
_is_proj=0
for _m in package.json pyproject.toml Cargo.toml go.mod pom.xml build.gradle Gemfile composer.json .git; do
    [ -e "$CWD/$_m" ] && _is_proj=1 && break
done
if [ "$_is_proj" = "1" ]; then
    # 提案を copy-paste / Claude 実行可能にするため、harness-setup.sh の絶対パスを解決して出す
    # （$CLAUDE_PLUGIN_ROOT は素の bash では未設定のため、ここで実体パスに展開する）。
    _HS=$(cd "$SCRIPT_DIR/../scripts" 2>/dev/null && pwd)/harness-setup.sh
    if [ ! -f "$CWD/CLAUDE.md" ] && [ ! -f "$CWD/.claude/CLAUDE.md" ]; then
        echo "[Harness not set up] This project has no CLAUDE.md."
        echo "  1) Run native /init to generate CLAUDE.md."
        echo "  2) Project rules:  sh \"$_HS\" --project"
        echo "  3) User-level harness (rules + settings + store, run once):  sh \"$_HS\""
        echo "  (Add this project to the denylist to suppress this notice.)"
        echo ""
    elif [ ! -d "$CWD/.claude/rules" ] && [ ! -d "$HOME/.claude/rules" ]; then
        echo "[Harness partially set up] CLAUDE.md exists but rules are missing. Run:  sh \"$_HS\" --project"
        echo ""
    fi
fi

# ai-context ベースdir を解決（central/legacy 透過・既定 legacy で挙動不変）
PATHS_DIR=${CLAUDE_PLUGIN_ROOT:+"$CLAUDE_PLUGIN_ROOT/scripts"}
[ -z "$PATHS_DIR" ] && PATHS_DIR=$(cd "$(dirname "$0")/../scripts" 2>/dev/null && pwd)
AI_BASE="$CWD/.ai-context"
if [ -f "$PATHS_DIR/_ai-context-paths.sh" ]; then
    AI_PATHS="$PATHS_DIR/_ai-context-paths.sh"
    . "$AI_PATHS"
    AI_BASE=$(_ai_context_base_dir "$CWD")
fi

# store-first: 常時 scaffold（冪等）。未登録の toplevel repo はここで store 登録 + skeleton 生成。
# subdir / denylist / 非 git / grandfather は scaffold 内部のガードで no-op（repo 側には一切書かない）。
if command -v _ai_context_scaffold >/dev/null 2>&1; then
    _ai_context_scaffold "$CWD"
    # 初回登録で解決先が flip するため再解決
    command -v _ai_context_base_dir >/dev/null 2>&1 && AI_BASE=$(_ai_context_base_dir "$CWD")
fi

# 個人状態（pending / consumed / learnings）を <author>/ で scope 化（複数人で衝突回避）。
# 1 回解決して使い回す。author 不明時は unknown にフォールバック。
if command -v _ai_context_author >/dev/null 2>&1; then
    AUTHOR=$(_ai_context_author "$CWD" 2>/dev/null)
elif [ -n "${AI_PATHS:-}" ]; then
    AUTHOR=$(sh "$AI_PATHS" --author "$CWD" 2>/dev/null)
fi
[ -z "${AUTHOR:-}" ] && AUTHOR="unknown"

# ベースの絶対パスを常時注入（モデル経由の相対 .ai-context/ 書き込みの根絶。
# 未登録 subdir でも derive 値を注入する＝書き込みは常に store 側へ向く）
# i18n: consumed-by skills/ai-context/references/central-store-guide.md, skills/status/SKILL.md,
#       skills/ai-context/references/doctor.md, skills/ai-context/references/status.md
#       （「ai-context ベース:」marker をドキュメントが逐語参照。T2.4/T4 で同時変更すること）
# store-first precedence（decision 2026-07-08 store-first-precedence-banner）: CLAUDE.md は静的な
# ベースライン、store（decisions / workspace / tasks）が現在の正。CLAUDE.md を汚さず（元リポジトリ
# 非改変の思想）hook 側で毎回この優先順を明示する。in-repo .ai-context は廃止済みなので grandfather 分岐は無い。
echo "[AI Context - store-first] 作業開始や CLAUDE.md の記述で動く前に、下の ai-context store（decisions / workspace / tasks）を必ず先に参照する。store が現在の正であり、CLAUDE.md の静的記述と食い違う場合は store の最新 decision を優先する。"
echo "[AI Context - 中央 store 運用] このプロジェクトの ai-context ベース: $AI_BASE"
echo "  Read/Write decisions / docs / tasks / sessions / workspaces under the base above (use the injected absolute path, not a relative .ai-context/)."
echo ""

# ベース未作成（未登録 repo の subdir 等）→ 注入内容なしで終了
[ ! -d "$AI_BASE" ] && exit 0

# banto 起動のヘッドレス fork（idle-checkpoint 等）にはベースパス注入のみ行い、
# checkpoint の消費（consumed/ への退避）・ダッシュボード・タスク注入はしない。
# fork が他セッション向けの pending checkpoint を横取り消費するのを防ぐ
[ "${BANTO_HEADLESS:-0}" = "1" ] && exit 0

DECISIONS="$AI_BASE/decisions"
SESSIONS="$AI_BASE/sessions"
# 実効 tasks: 新 layout（workspaces/<author>/<topic>/tasks.md）→ legacy active.md フォールバック
TASKS="$AI_BASE/tasks/active.md"
command -v _ai_context_active_tasks >/dev/null 2>&1 && TASKS=$(_ai_context_active_tasks "$AI_BASE" "$CWD")
TODAY=$(date +%Y-%m-%d)

# 何もなければ静かに終了
HAS_CONTENT=0
[ -d "$SESSIONS" ] && [ -n "$(ls "$SESSIONS"/checkpoint-*.md 2>/dev/null)" ] && HAS_CONTENT=1
[ -d "$DECISIONS" ] && [ -n "$(ls "$DECISIONS"/*.md 2>/dev/null)" ] && HAS_CONTENT=1
[ -f "$TASKS" ] && HAS_CONTENT=1
# pending（例外チャネル）に未解消 section があれば、他に content が無くても注入する
# （「例外は checkpoint のみ」を抑止しない。spec: harness-next-level P2）
# 新 per-user パス（sessions/pending/<author>.md）優先・旧フラット checkpoints/pending.md フォールバック
PENDING_FILE="$AI_BASE/sessions/pending/${AUTHOR}.md"
[ -f "$PENDING_FILE" ] || PENDING_FILE="$AI_BASE/checkpoints/pending.md"
[ -f "$PENDING_FILE" ] && grep -q 'PENDING:.*START' "$PENDING_FILE" 2>/dev/null && HAS_CONTENT=1
[ "$HAS_CONTENT" = "0" ] && exit 0

echo "[AI Context - SessionStart: context restored via ${SOURCE:-unknown}]"
echo ""

# --- チェックポイント配送（源別分岐 + workspace 宛先 + 有界化。decision 2026-07-08 idle-checkpoint-delivery） ---
# 消費（consumed/ 退避）するのは source=clear のときだけ。/clear は「文脈を意図的に落として
# 同じ作業を安く再開する」唯一の明示合図なので、そこを受け取り口に一本化する。
# resume/startup/compact は消費せずヒントのみ: 巨大な再ロード文脈へ重ねて注入せず、別作業の
# 空セッションへ dump もしない。これで「別セッション（startup/resume）が checkpoint を先に食う」
# レースを構造的に断つ（旧実装は source を問わず無条件に注入 + 消費していた）。
# 宛先キーは workspace トピック（/clear をまたいで安定。session_id は /clear で回るので不可）。
# writer（idle-checkpoint-watch.sh）が `<!-- banto-ws: <topic> -->` を先頭行に刻む。未マーカーの
# checkpoint は後方互換で「どの ws でも配送」。減衰: ≤24h=受動ヒスト表示 + /clear 配送 /
# 1〜3日=明示 /clear でのみ配送・受動ヒントなし / >3日=consumed/ へ GC 退避。
if [ -d "$SESSIONS" ]; then
    CHECKPOINT_FILES=$(ls -t "$SESSIONS"/checkpoint-*.md 2>/dev/null)
    CONSUMED="$SESSIONS/consumed/${AUTHOR}"
    if [ -n "$CHECKPOINT_FILES" ]; then
        # 現在の workspace キー（無ければ空 = 未マーカーのみ対象になる）
        WS_KEY=""
        command -v _ai_context_ws_key >/dev/null 2>&1 && WS_KEY=$(_ai_context_ws_key "$AI_BASE" "$CWD" 2>/dev/null)

        # このワークスペース宛て（マーカー一致）または未マーカーの checkpoint に絞る。ファイル名は
        # スペースを含まない規約だが、2026-06-05 監査の教訓に従い read -r で行単位処理する。
        _CK_MINE="${TMPDIR:-/tmp}/banto-ck-mine-$$"
        : > "$_CK_MINE"
        printf '%s\n' "$CHECKPOINT_FILES" | while IFS= read -r f; do
            [ -f "$f" ] || continue
            _m=$(grep -m1 '^<!-- banto-ws: ' "$f" 2>/dev/null | sed 's/^<!-- banto-ws: //; s/ -->$//')
            if [ -z "$_m" ] || [ "$_m" = "$WS_KEY" ]; then
                printf '%s\n' "$f" >> "$_CK_MINE"
            fi
        done
        MINE=$(cat "$_CK_MINE" 2>/dev/null)
        rm -f "$_CK_MINE" 2>/dev/null

        if [ -n "$MINE" ]; then
            if [ "$SOURCE" = "clear" ]; then
                # 受け取り: 全文注入 → consumed/ へ退避（このワークスペース宛てのみ・年齢不問）。
                # rm でなく退避（旧実装は無条件 rm で出力 drop 時に復元不能だった。14 日で自動掃除）。
                echo "=== Checkpoint (user-confirmed) ==="
                mkdir -p "$CONSUMED" 2>/dev/null
                printf '%s\n' "$MINE" | while IFS= read -r f; do
                    [ -f "$f" ] || continue
                    cat "$f"
                    echo ""
                    mv -f "$f" "$CONSUMED/" 2>/dev/null || rm -f "$f"
                done
                echo "[Note: checkpoints were moved to sessions/consumed/${AUTHOR}/ after injection (kept for 14 days)]"
                echo ""
            else
                # resume/startup/compact: 消費しない。24h 以内の新しいものがある時だけ 1 行ヒント。
                # 「resume で戻った → /clear すれば安い」という本来導線を見える化する。
                _now=$(date +%s 2>/dev/null)
                _fresh=0
                printf '%s\n' "$MINE" | while IFS= read -r f; do
                    _mt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)
                    case "$_mt" in ''|*[!0-9]*) echo Y; break ;; esac
                    { [ -z "$_now" ] || [ $(( _now - _mt )) -le 86400 ]; } && { echo Y; break; }
                done | grep -q Y && _fresh=1
                if [ "$_fresh" = "1" ]; then
                    echo "[idle-checkpoint あり: このプロジェクトに続きのセッションがあります。/clear すると checkpoint から軽い文脈で安く再開できます]"
                    echo ""
                fi
            fi
        fi

        # GC(1): mailbox 直下で未消費のまま保持日数を越えた checkpoint を consumed/ へ退避（有界化）。
        #        /clear で拾える「安く再開の窓」= この日数（既定 10 日）。別 ws 宛て・/clear されず
        #        古びたものを mailbox から回収する。受動ヒントは別枠（24h）なので延ばしても増えない。
        #        BANTO_IDLE_CHECKPOINT_RETAIN_DAYS で調整可（consumed 側 14 日削除より短くして復元余地を残す）。
        _RETAIN_DAYS=${BANTO_IDLE_CHECKPOINT_RETAIN_DAYS:-10}
        case "$_RETAIN_DAYS" in ''|*[!0-9]*) _RETAIN_DAYS=10 ;; esac
        mkdir -p "$CONSUMED" 2>/dev/null
        find "$SESSIONS" -maxdepth 1 -name 'checkpoint-*.md' -mtime +"$_RETAIN_DAYS" 2>/dev/null | while IFS= read -r f; do
            [ -f "$f" ] || continue
            mv -f "$f" "$CONSUMED/" 2>/dev/null || rm -f "$f"
        done
        # GC(2): 新 per-user パス + 旧フラット consumed/ 直下（移行前データ）を 14 日で削除
        find "$SESSIONS/consumed" -name 'checkpoint-*.md' -mtime +14 -delete 2>/dev/null
    fi
fi

# --- ダッシュボード（鳥瞰図・前回生成分）があれば注入 ---
if [ -f "$AI_BASE/DASHBOARD.md" ]; then
    echo "=== Dashboard (cross-workspace, auto-generated by hook) ==="
    cat "$AI_BASE/DASHBOARD.md"
    echo ""
fi

# --- North Star (CONCEPT): CLAUDE.md に @import 常駐していない場合のみ注入 ---
# store の concept/CONCEPT.md があり、かつ プロジェクトの CLAUDE.md が concept/CONCEPT.md を
# @import していない時だけ注入する（@import 済みなら二重注入を避ける）。20KB cap。
# fail-open: CONCEPT 不在・CLAUDE.md 不在で静かに skip。
CONCEPT_FILE="$AI_BASE/concept/CONCEPT.md"
if [ -f "$CONCEPT_FILE" ]; then
    _concept_imported=0
    _git_top=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
    for _cm in "$CWD/CLAUDE.md" "$CWD/.claude/CLAUDE.md" "$_git_top/CLAUDE.md" "$_git_top/.claude/CLAUDE.md"; do
        [ -f "$_cm" ] || continue
        if grep -q 'concept/CONCEPT.md' "$_cm" 2>/dev/null; then
            _concept_imported=1
            break
        fi
    done
    if [ "$_concept_imported" = "0" ]; then
        _concept_sz=$(wc -c < "$CONCEPT_FILE" | tr -d ' ')
        echo "=== North Star (CONCEPT) ==="
        if [ "$_concept_sz" -le 20000 ]; then
            cat "$CONCEPT_FILE"
        else
            head -c 20000 "$CONCEPT_FILE"
            echo ""
            echo "[CONCEPT over 20KB injection cap — Read $CONCEPT_FILE for full text]"
        fi
        echo ""
    fi
fi

# --- 例外チャネル（pending.md）: 日和見で再評価 → 集約 → 注入（spec: harness-next-level P2） ---
# 24h throttle（GC と同じ date marker 方式）。drift / 死蔵を pending-channel に集約してから
# 注入する。throttle 中は前回集約分をそのまま注入する（再計算しない＝軽量）。
HARNESS_MARKER="${TMPDIR:-/tmp}/banto-harness-check-$(date +%Y%m%d 2>/dev/null)"
if [ ! -f "$HARNESS_MARKER" ]; then
    touch "$HARNESS_MARKER" 2>/dev/null
    if [ -f "$PATHS_DIR/harness-drift-check.sh" ]; then
        sh "$PATHS_DIR/harness-drift-check.sh" "$CWD" 2>/dev/null \
            | sh "$SCRIPT_DIR/pending-channel.sh" drift "$CWD" 2>/dev/null
    fi
    if [ -f "$PATHS_DIR/dead-skill-report.sh" ]; then
        sh "$PATHS_DIR/dead-skill-report.sh" "$CWD" 2>/dev/null \
            | sh "$SCRIPT_DIR/pending-channel.sh" dead "$CWD" 2>/dev/null
    fi
    if [ -f "$PATHS_DIR/lexicon-distill.sh" ]; then
        sh "$PATHS_DIR/lexicon-distill.sh" "$CWD" 2>/dev/null \
            | sh "$SCRIPT_DIR/pending-channel.sh" lexicon "$CWD" 2>/dev/null
    fi
fi
# pending に未解消の section があれば注入（DASHBOARD の直後・最優先で目に入る位置）
# 新 per-user パス優先・旧フラットへフォールバック（上の harness 再評価で新パスが書かれた可能性を再解決）
PENDING_FILE="$AI_BASE/sessions/pending/${AUTHOR}.md"
[ -f "$PENDING_FILE" ] || PENDING_FILE="$AI_BASE/checkpoints/pending.md"
if [ -f "$PENDING_FILE" ] && grep -q 'PENDING:.*START' "$PENDING_FILE" 2>/dev/null; then
    echo "=== ⚠ Pending Checkpoints (action required; aggregated by hooks — exceptions are checkpoints only) ==="
    cat "$PENDING_FILE"
    echo ""
fi

# --- 進行中タスク（per-workspace tasks.md / legacy active.md）があれば全文注入 ---
if [ -f "$TASKS" ]; then
    echo "=== Tasks in progress (${TASKS#$AI_BASE/}) ==="
    cat "$TASKS"
    echo ""
fi

# --- 今日の設計判断: 全文注入（合計 20KB 上限） ---
# 多忙な日は全文注入が無上限に膨張し（42〜75KB 実績）、compact のたびに再注入されて
# コンテキストを圧迫する悪循環になるため、超過分はファイル名のみに降格する（2026-06-05 監査）。
# 注: while への入力は heredoc（パイプだと subshell になり _dec_used の加算が消える）。
if [ -d "$DECISIONS" ]; then
    TODAY_FILES=$(ls "$DECISIONS"/${TODAY}*.md 2>/dev/null)
    if [ -n "$TODAY_FILES" ]; then
        echo "=== Today's design decisions (full text, 20KB total cap) ==="
        _dec_budget=20000
        _dec_used=0
        while IFS= read -r f; do
            [ -f "$f" ] || continue
            _sz=$(wc -c < "$f" | tr -d ' ')
            if [ $((_dec_used + _sz)) -le "$_dec_budget" ]; then
                echo "--- $(basename "$f") ---"
                cat "$f"
                echo ""
                _dec_used=$((_dec_used + _sz))
            else
                echo "--- $(basename "$f") (over injection cap — Read for full text) ---"
            fi
        done <<TODAY_DECISIONS_EOF
$TODAY_FILES
TODAY_DECISIONS_EOF
    fi

    # --- 古い設計判断: ファイル名のみ（直近20件） ---
    OLD_FILES=$(ls -t "$DECISIONS"/*.md 2>/dev/null | grep -v "/${TODAY}" | head -20)
    if [ -n "$OLD_FILES" ]; then
        echo "=== Past design decisions (filenames only, latest 20 — Read them if needed) ==="
        for f in $OLD_FILES; do
            echo "  - $(basename "$f")"
        done
        echo ""
    fi
fi

# --- ワークスペース情報を注入（Claude は必ず参照し、必要なら更新する） ---
# 実効ポインタ: git-dir（per-checkout・並走独立）優先 → store の WORKSPACE.md フォールバック
WS_FILE="$AI_BASE/WORKSPACE.md"
command -v _ai_context_ws_pointer >/dev/null 2>&1 && WS_FILE=$(_ai_context_ws_pointer "$AI_BASE" "$CWD")
if [ -f "$WS_FILE" ]; then
    echo "=== Current workspace (always consult it; update it when needed) ==="
    cat "$WS_FILE"
    echo ""
    # 新 layout ならポインタの実体（workspace.md）も注入
    if command -v _ai_context_ws_dir >/dev/null 2>&1; then
        _WSD=$(_ai_context_ws_dir "$AI_BASE" "$CWD") || _WSD=""
        if [ -n "$_WSD" ] && [ -f "$_WSD/workspace.md" ]; then
            echo "--- workspace entity (${_WSD#$AI_BASE/}/workspace.md) ---"
            cat "$_WSD/workspace.md"
            echo ""
        fi
    fi
    echo "[Workspace rules]"
    echo "  1. If subsequent user messages fall outside the scope of the workspace above, suggest /ws switch or /ws new"
    echo "  2. When you create a new file under decisions/ or docs/, add it to the 「## 関連ドキュメント」 (related documents) section of WORKSPACE.md"  # i18n: consumed-by hooks/ai-context-auto.sh awk, skills/ws/SKILL.md (WORKSPACE.md format)
    echo "  3. Consult related files of other workspaces listed as dependencies when needed"
    echo ""
    # 利用可能なWS一覧（新 layout: workspaces/<author>/<topic>/ 優先、legacy: workspaces/*.md）
    WS_DIR="$AI_BASE/workspaces"
    _AUTHOR=""
    command -v _ai_context_author >/dev/null 2>&1 && _AUTHOR=$(_ai_context_author "$CWD")
    if [ -n "$_AUTHOR" ] && [ -d "$WS_DIR/$_AUTHOR" ]; then
        echo "=== Other workspaces (switch via /ws switch) ==="
        for d in "$WS_DIR/$_AUTHOR"/*/; do
            [ -d "$d" ] || continue
            WSNAME=$(basename "$d")
            [ "$WSNAME" = "old" ] && continue
            echo "  - $WSNAME"
        done
        echo ""
    elif [ -d "$WS_DIR" ] && [ -n "$(ls "$WS_DIR"/*.md 2>/dev/null)" ]; then
        echo "=== Other workspaces (switch via /ws switch) ==="
        for f in "$WS_DIR"/*.md; do
            WSNAME=$(basename "$f" .md)
            echo "  - $WSNAME"
        done
        echo ""
    fi
fi

# --- learnings/ にドラフトがあれば通知（Stop hook 自己改善ループの成果物） ---
# 新 per-user パス（learnings/<author>/）優先・旧フラット learnings/ フォールバック（既存データ救済）
LEARNINGS_DIR="$AI_BASE/learnings/${AUTHOR}"
[ -d "$LEARNINGS_DIR" ] || LEARNINGS_DIR="$AI_BASE/learnings"
if [ -d "$LEARNINGS_DIR" ]; then
    LEARNING_DRAFTS=$(ls "$LEARNINGS_DIR"/*_draft.md 2>/dev/null)
    if [ -n "$LEARNING_DRAFTS" ]; then
        echo "=== Unreviewed learning drafts (detected by the Stop-hook self-improvement loop) ==="
        for f in $LEARNING_DRAFTS; do
            echo "  - $(basename "$f")"
        done
        echo "[Read each draft and decide: promote to rules/, promote to decisions/, turn into a skill, or reject. Afterwards set status to ACCEPTED/REJECTED or delete the file]"
        echo ""
    fi
fi

# --- DASHBOARD.md（全 WS 横断の鳥瞰図）を再生成 ---
if [ -f "$SCRIPT_DIR/ai-context-dashboard.sh" ]; then
    sh "$SCRIPT_DIR/ai-context-dashboard.sh" "$CWD" 2>/dev/null
fi

# --- store-map: meta/store-map.md 再生成 + リンク腐敗チェック（日次・冪等） ---
# 正本マニフェスト templates/store-layout.json と「skill 宣言 / 実体 / directory-structure.md」の
# 四者一致を検証。ドリフト時だけ警告（クリーン時は静音）。地図は meta/store-map.md に冪等出力。
MAP_MARKER="${TMPDIR:-/tmp}/banto-store-map-$(date +%Y%m%d)"
if [ ! -f "$MAP_MARKER" ] && [ -f "$PATHS_DIR/store-map-gen.sh" ] && [ -n "$AI_BASE" ]; then
    touch "$MAP_MARKER"
    sh "$PATHS_DIR/store-map-gen.sh" --base "$AI_BASE" >/dev/null 2>&1
    if [ -f "$PATHS_DIR/store-map-lint.sh" ]; then
        MAP_DRIFT=$(sh "$PATHS_DIR/store-map-lint.sh" --base "$AI_BASE" --quiet 2>/dev/null)
        [ -n "$MAP_DRIFT" ] && { printf '%s\n\n' "$MAP_DRIFT"; }
    fi
fi

# --- repo-ontology: meta/ontology.{json,md} 再生成 + TBox 整合検証（生成/検証=日次・冪等） ---
# 層 0 ルーター（decision 2026-07-02-083746）: 注入は「質問タイプ → 手段」の小案内のみ・毎セッション。
# 台帳は query（jq）専用で wholesale read 禁止。生成 + lint は日次スロットル。
ONTO_MARKER="${TMPDIR:-/tmp}/banto-ontology-$(date +%Y%m%d)"
if [ ! -f "$ONTO_MARKER" ] && [ -f "$PATHS_DIR/ontology-gen.sh" ] && [ -n "$AI_BASE" ]; then
    touch "$ONTO_MARKER"
    sh "$PATHS_DIR/ontology-gen.sh" --base "$AI_BASE" >/dev/null 2>&1
    if [ -f "$PATHS_DIR/ontology-lint.sh" ]; then
        ONTO_DRIFT=$(sh "$PATHS_DIR/ontology-lint.sh" --base "$AI_BASE" 2>/dev/null | grep '^FAIL')
        [ -n "$ONTO_DRIFT" ] && printf '=== ⚠ Repo ontology drift (ontology-lint) ===\n%s\n\n' "$ONTO_DRIFT"
    fi
fi
ONTO_JSON="$AI_BASE/meta/ontology.json"
if [ -n "$AI_BASE" ] && [ -f "$ONTO_JSON" ] && command -v jq >/dev/null 2>&1; then
    ONTO_NE=$(jq '.entities|length' "$ONTO_JSON" 2>/dev/null)
    ONTO_NR=$(jq '.relations|length' "$ONTO_JSON" 2>/dev/null)
    printf '[Repo Ontology router] %s entities / %s relations at %s/meta/ontology.json (schema + jq examples in ontology.md).\nRoute by question type: counting / enumeration / existence / audit -> query the ledger with jq (never read it wholesale). Content investigation (why / how / root cause) -> search skill (full-text; cross-store FTS5 section index via scripts/store-query.sh when present). Cold file-walking without an index loses recall on weaker models -- go through the ledger or search first.\n\n' "$ONTO_NE" "$ONTO_NR" "$AI_BASE"
fi

# --- store 横断 FTS5 セクション索引（内容層・decision 2026-07-02-223134）---
# 鮮度スキップ・原子的差し替え・fail-open はスクリプト内蔵。非同期でセッション開始を妨げない。
# 索引はコミットしないローカル派生物（正本は md。decision 2026-07-02-215442）。
if [ -n "$AI_BASE" ] && [ -f "$PATHS_DIR/store_index_gen.py" ] && command -v python3 >/dev/null 2>&1; then
    ( python3 "$PATHS_DIR/store_index_gen.py" --base "$AI_BASE" >/dev/null 2>&1 & )
fi

# --- plugin cache GC（日次・非同期。update が旧版を掃除しない構造問題への自走対処） ---
# 決定論ルール: installed_plugins 参照版 + 直近2版を保持して削除（scripts/plugin-cache-gc.sh）
GC_MARKER="${TMPDIR:-/tmp}/banto-plugin-gc-$(date +%Y%m%d)"
if [ ! -f "$GC_MARKER" ] && [ -f "$PATHS_DIR/plugin-cache-gc.sh" ]; then
    touch "$GC_MARKER"
    ( sh "$PATHS_DIR/plugin-cache-gc.sh" --apply >/dev/null 2>&1 & )
fi

# --- full-combined.txt: 日次スロットル付きバックグラウンド再生成 ---
# 旧 project scope（廃止済み）畳み込み後、search ランキング（store-query.sh）は decisions/docs を
# 直接走査するため combined.txt を読まない。full-combined.txt は deep パス（会話履歴込み検索）
# 専用の唯一の combined 層として残り、write-time では再生成しない（ontology-gen と同型の
# 日次スロットル + 非同期実行。deep パス開始時のオンデマンド更新は search skill 側が担う）。
FULLCOMBINED_MARKER="${TMPDIR:-/tmp}/banto-full-combined-$(date +%Y%m%d)"
if [ ! -f "$FULLCOMBINED_MARKER" ] && [ -f "$PATHS_DIR/ai_context_combined.py" ] && command -v python3 >/dev/null 2>&1; then
    touch "$FULLCOMBINED_MARKER"
    ( python3 "$PATHS_DIR/ai_context_combined.py" --project-root "$CWD" --base "$AI_BASE" --scope full >/dev/null 2>&1 & )
fi

echo "[When a new design decision is made, save it to $AI_BASE/decisions/ immediately]"
echo "[DASHBOARD.md is a hook-managed local overview. Do not edit it manually (it is overwritten on the next regeneration)]"
exit 0
