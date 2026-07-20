#!/usr/bin/env python3
"""policy-console.py — repo 別ポリシー正典 {store}/{project}/meta/policy.json の GUI（1 画面）。

閲覧と編集は同じ画面。変更はその場で自動保存され、policy.json を読む hook（policy-guard /
release-guard / prod-guard）には書いた瞬間から効く。store への commit + 同期は数秒の
デバウンス後に ai-context-sync.sh で自動実行する。

サーバは「設定中だけ」生きる:
  - 画面右上の「完了して閉じる」→ 未同期分を flush してサーバ終了 + ウィンドウを閉じる
  - タブを閉じる → beforeunload の beacon（/bye）で猶予 3 秒後に自動終了（リロードなら復帰）
  - 放置 → 15 分（--idle-timeout 秒で変更可、0 で無効）の無通信で自動終了

起動: `python3 policy-console.py`（--port 省略時は空きポート）。
stdout に `http://127.0.0.1:PORT/?t=TOKEN` を出力。トークン不一致は 403。
保存先は列挙済み project の meta/policy.json のみ（パストラバーサル不可）。

スキーマは policy-guard.sh / _ai-context-paths.sh (_ai_context_grant) と同一:
  {"grants": {"pr_create": "allow|confirm|deny" | {"value": "...", "until": "YYYY-MM-DD"}},
   "ignore": {"no_edit": ["glob", ...], "no_sync": ["glob", ...]}}
旧 grants.json のみの project は読み取りで fallback し、保存時に policy.json を新規作成する
（grants.json は残す）。

対象 store: ~/.claude/banto-ai-context-stores（1 行 1 store パス、# コメント可。
BANTO_STORES_LIST で差し替え可 — nightly-push と同じ規約）。無ければ ~/ai-context-store。

python3 stdlib のみ。
"""
import argparse
import hmac
import html
import json
import os
import secrets
import subprocess
import sys
import threading
import time
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

KNOWN_GRANTS = ("pr_create", "push_feature", "prod_ops")
GRANT_VALUES = ("allow", "confirm", "deny")
SYNC_DEBOUNCE_SEC = 4
BYE_GRACE_SEC = 3


# ---- store / project の列挙と読み取り ----

def discover_stores():
    lst = Path(os.environ.get(
        "BANTO_STORES_LIST", str(Path.home() / ".claude" / "banto-ai-context-stores")))
    stores = []
    if lst.is_file():
        for line in lst.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            p = Path(os.path.expanduser(line))
            if p.is_dir():
                stores.append(p.resolve())
    else:
        p = Path.home() / "ai-context-store"
        if p.is_dir():
            stores.append(p.resolve())
    return stores


def discover_projects(store):
    names = []
    try:
        children = sorted(store.iterdir())
    except OSError:
        return names
    for child in children:
        if child.name.startswith("."):
            continue
        meta = child / "meta"
        if not (child.is_dir() and meta.is_dir()):
            continue
        if (meta / "policy.json").is_file() or (meta / "grants.json").is_file():
            names.append(child.name)
    return names


def read_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else None
    except (OSError, ValueError):
        return None


def load_project(store, name):
    meta = store / name / "meta"
    policy = read_json(meta / "policy.json")
    legacy = policy is None
    source = policy if policy is not None else (read_json(meta / "grants.json") or {})
    grants = source.get("grants")
    grants = grants if isinstance(grants, dict) else {}
    ignore = policy.get("ignore") if policy is not None else None
    ignore = ignore if isinstance(ignore, dict) else {}

    def patterns(key):
        v = ignore.get(key)
        return [str(x) for x in v] if isinstance(v, list) else []

    return {
        "store": store,
        "name": name,
        "legacy": legacy,
        "policy": policy,
        "grants": grants,
        "no_edit": patterns("no_edit"),
        "no_sync": patterns("no_sync"),
    }


def collect():
    return [(store, [load_project(store, n) for n in discover_projects(store)])
            for store in discover_stores()]


def grant_view(raw):
    if isinstance(raw, str):
        return raw, None
    if isinstance(raw, dict):
        until = raw.get("until")
        return str(raw.get("value", "")), (str(until) if until is not None else None)
    return "", None


def grant_keys(project):
    keys = list(KNOWN_GRANTS)
    for k in project["grants"]:
        if k not in keys:
            keys.append(k)
    return keys


# ---- HTML レンダリング ----

CSS = """
* { box-sizing: border-box; }
body { margin: 0; padding: 32px 16px; background: #FAF7F1; color: #000000; line-height: 1.7;
       font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Noto Sans JP", sans-serif; }
main { max-width: 920px; margin: 0 auto; }
h1 { color: #113160; font-size: 1.5rem; margin: 0 0 4px; }
.lead { margin: 0 0 24px; font-size: .9rem; }
h2 { color: #113160; font-size: 1.05rem; border-bottom: 2px solid #113160;
     padding-bottom: 4px; margin: 32px 0 8px; overflow-wrap: anywhere; }
.card { background: #FFFFFF; border: 1px solid #E7E1D6; border-radius: 12px;
        padding: 20px 24px; margin: 16px 0; box-shadow: 0 1px 2px rgba(17, 49, 96, 0.05); }
.card h3 { margin: 0 0 12px; color: #113160; font-size: 1rem; }
.badge { display: inline-block; margin-left: 8px; padding: 2px 10px; border-radius: 999px;
         background: #EFEAE0; color: #113160; font-size: .75rem; font-weight: normal; }
.chip { float: right; font-size: .78rem; padding: 2px 12px; border-radius: 999px;
        background: #F2EEE6; color: #113160; }
.chip.ok { background: #E9F6EF; }
.chip.err { background: #FFEFEF; color: #B32800; }
table { border-collapse: collapse; width: 100%; margin: 8px 0 12px; }
th, td { text-align: left; padding: 6px 12px 6px 0; border-bottom: 1px solid #F0EBE1; font-size: .9rem; }
th { color: #113160; font-weight: 600; white-space: nowrap; width: 11em; }
.until { margin-left: 8px; font-size: .8rem; }
code { background: #F5F1E8; padding: 1px 6px; border-radius: 6px; font-size: .85rem; }
.klabel, label { display: block; margin: 12px 0 4px; font-size: .85rem;
                 color: #113160; font-weight: 600; }
textarea { width: 100%; min-height: 72px; border: 1px solid #D8D2C4; border-radius: 8px;
           padding: 8px 10px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
           font-size: .85rem; background: #FFFFFF; color: #000000; }
select { border: 1px solid #D8D2C4; border-radius: 8px; padding: 4px 8px;
         background: #FFFFFF; color: #000000; font-size: .9rem; }
.note { font-size: .8rem; margin: 4px 0 12px; }
#donebar { position: fixed; top: 16px; right: 16px; z-index: 10; }
#donebar button { background: #113160; color: #FFFFFF; border: none; border-radius: 8px;
                  padding: 10px 22px; font-size: .9rem; cursor: pointer;
                  box-shadow: 0 2px 8px rgba(17, 49, 96, 0.25); }
#donebar button:hover { opacity: .9; }
footer { margin-top: 32px; font-size: .75rem; }
"""


def esc(s):
    return html.escape(str(s), quote=True)


def page(title, body, script=""):
    return (
        '<!DOCTYPE html>\n<html lang="ja">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f'<title>{esc(title)}</title>\n<style>{CSS}</style>\n</head>\n<body>\n<main>\n'
        f'{body}\n</main>\n{script}</body>\n</html>\n'
    )


def legacy_badge(project):
    return '<span class="badge">旧形式（grants.json）</span>' if project["legacy"] else ""


def card_html(p):
    rows = []
    for key in grant_keys(p):
        cur = p["grants"].get(key)
        cur_val, until = grant_view(cur) if cur is not None else ("", None)
        opts = []
        sel = " selected" if cur_val == "" else ""
        opts.append(f'<option value=""{sel}>未設定（実効: confirm）</option>')
        for v in GRANT_VALUES:
            sel = " selected" if v == cur_val else ""
            opts.append(f'<option value="{esc(v)}"{sel}>{esc(v)}</option>')
        if cur_val and cur_val not in GRANT_VALUES:
            opts.append(f'<option value="{esc(cur_val)}" selected>{esc(cur_val)}</option>')
        until_html = (f'<span class="until">期限 {esc(until)}（値を変えなければ期限を保持します）</span>'
                      if until else "")
        rows.append(f'<tr><th>{esc(key)}</th><td>'
                    f'<select name="grant__{esc(key)}">{"".join(opts)}</select>'
                    f'{until_html}</td></tr>')
    legacy_note = ('<p class="note">変更すると policy.json を新規作成します'
                   '（grants.json は残します）。</p>' if p["legacy"] else "")
    return (
        f'<div class="card">\n'
        f'<h3>{esc(p["name"])}{legacy_badge(p)}<span class="chip">未変更</span></h3>\n{legacy_note}'
        f'<form data-policy data-store="{esc(p["store"])}" data-project="{esc(p["name"])}" '
        'onsubmit="return false">\n'
        f'<table><tbody>{"".join(rows)}</tbody></table>\n'
        '<label>ignore.no_edit（1 行 1 パターン / 一致するファイルの編集をブロック）</label>\n'
        f'<textarea name="no_edit" placeholder="例: *.env">{esc(chr(10).join(p["no_edit"]))}</textarea>\n'
        '<label>ignore.no_sync（1 行 1 パターン / store の .git/info/exclude へ反映）</label>\n'
        f'<textarea name="no_sync" placeholder="例: private/**">{esc(chr(10).join(p["no_sync"]))}</textarea>\n'
        '</form>\n</div>'
    )


def store_sections(data):
    parts = []
    if not data:
        parts.append('<div class="card"><p>対象の store が見つかりません。'
                     '<code>~/.claude/banto-ai-context-stores</code> または '
                     '<code>~/ai-context-store</code> を確認してください。</p></div>')
    for store, projects in data:
        parts.append(f"<h2>store: {esc(store)}</h2>")
        if not projects:
            parts.append('<div class="card"><p class="note">対象の project がありません'
                         '（meta/policy.json または meta/grants.json を持つ project が対象です）。'
                         '</p></div>')
        for p in projects:
            parts.append(card_html(p))
    return "\n".join(parts)


CLIENT_JS = """
<script>
(function () {
  var TOKEN = document.body.dataset.token;
  var timers = {};

  function chip(form, text, cls) {
    var c = form.closest(".card").querySelector(".chip");
    c.textContent = text;
    c.className = "chip" + (cls ? " " + cls : "");
  }

  function save(form) {
    var fd = new FormData(form);
    fd.append("t", TOKEN);
    fd.append("store", form.dataset.store);
    fd.append("project", form.dataset.project);
    chip(form, "保存中…", "");
    fetch("/save?t=" + encodeURIComponent(TOKEN), {
      method: "POST",
      headers: { "Accept": "application/json" },
      body: new URLSearchParams(fd)
    }).then(function (r) { return r.json(); }).then(function (d) {
      if (d.ok) {
        chip(form, "反映済み " + d.saved_at + "（store 同期は自動）", "ok");
      } else {
        chip(form, "エラー: " + (d.error || "保存に失敗しました"), "err");
      }
    }).catch(function () { chip(form, "エラー: サーバに接続できません", "err"); });
  }

  function schedule(form, delay) {
    var key = form.dataset.store + "/" + form.dataset.project;
    if (timers[key]) clearTimeout(timers[key]);
    timers[key] = setTimeout(function () { save(form); }, delay);
  }

  document.querySelectorAll("form[data-policy]").forEach(function (form) {
    form.querySelectorAll("select").forEach(function (el) {
      el.addEventListener("change", function () { schedule(form, 0); });
    });
    form.querySelectorAll("textarea").forEach(function (el) {
      el.addEventListener("input", function () { schedule(form, 800); });
      el.addEventListener("blur", function () { schedule(form, 0); });
    });
  });

  var done = false;
  document.getElementById("donebtn").addEventListener("click", function () {
    done = true;
    fetch("/shutdown?t=" + encodeURIComponent(TOKEN), { method: "POST" })
      .catch(function () {})
      .then(function () {
        document.getElementById("donebar").textContent = "完了しました。このウィンドウは閉じて構いません。";
        window.close();
      });
  });

  window.addEventListener("beforeunload", function () {
    if (!done && navigator.sendBeacon) {
      navigator.sendBeacon("/bye?t=" + encodeURIComponent(TOKEN));
    }
  });
})();
</script>
"""


def render_console(data, token):
    body = (
        '<div id="donebar"><button id="donebtn" type="button">完了して閉じる</button></div>\n'
        "<h1>Banto Policy Console</h1>\n"
        '<p class="lead">repo 別ポリシー正典（meta/policy.json）の一覧と編集です。'
        "変更はその場で自動保存され、hook には即時に効きます。store への commit + 同期は"
        "数秒後に自動で走ります。会話からの変更も同じファイルを編集します（同一正典）。</p>\n"
        + store_sections(data)
        + "\n<footer>このサーバは「完了して閉じる」・タブを閉じる・15 分の放置のいずれかで自動終了します。</footer>"
    )
    # token は JS からの保存に使う（URL と同一の使い捨て値）
    body_tag = page("Banto Policy Console", body, CLIENT_JS)
    return body_tag.replace("<body>", f'<body data-token="{esc(token)}">', 1)


def render_message(title, message):
    return page(title, f"<h1>{esc(title)}</h1>\n"
                       f'<div class="card"><p>{esc(message)}</p></div>')


# ---- 保存 ----

def apply_form(project, form):
    def field(name):
        return (form.get(name) or [""])[0]

    policy = project["policy"] if project["policy"] is not None else {"schema_version": 1}
    old_grants = policy.get("grants")
    old_grants = old_grants if isinstance(old_grants, dict) else {}
    if project["legacy"]:
        old_grants = dict(project["grants"])

    new_grants = {}
    form_keys = set()
    for key in grant_keys(project):
        form_keys.add(key)
        raw = field(f"grant__{key}").strip()
        cur = old_grants.get(key)
        cur_val, _ = grant_view(cur) if cur is not None else ("", None)
        if raw not in {"", cur_val, *GRANT_VALUES}:
            raise ValueError(f"grant {key} の値が不正です: {raw!r}")
        if raw == "":
            continue
        if raw == cur_val and isinstance(cur, dict):
            new_grants[key] = cur
        else:
            new_grants[key] = raw
    for k, v in old_grants.items():
        if k not in form_keys:
            new_grants[k] = v

    def parse_lines(name):
        return [ln.strip() for ln in field(name).splitlines() if ln.strip()]

    ignore = policy.get("ignore")
    ignore = ignore if isinstance(ignore, dict) else {}
    ignore["no_edit"] = parse_lines("no_edit")
    ignore["no_sync"] = parse_lines("no_sync")
    policy["grants"] = new_grants
    policy["ignore"] = ignore
    return policy


def write_policy(project, policy):
    path = project["store"] / project["name"] / "meta" / "policy.json"
    path.write_text(json.dumps(policy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


# ---- store 同期（デバウンス）と自動終了 ----

class SyncScheduler:
    """保存のたびに即 commit すると churn になるため、store ごとに静穏 N 秒後へ同期をまとめる。"""

    def __init__(self, debounce=SYNC_DEBOUNCE_SEC):
        self.debounce = debounce
        self._lock = threading.Lock()
        self._timers = {}

    def _run(self, store):
        script = Path(__file__).resolve().parent / "ai-context-sync.sh"
        if not script.is_file():
            print(f"[policy-console] sync script not found: {script}", file=sys.stderr, flush=True)
            return
        proc = subprocess.Popen(
            ["sh", str(script), str(store)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        print(f"[policy-console] sync launched (pid {proc.pid}): {store}", file=sys.stderr, flush=True)

    def schedule(self, store):
        key = str(store)
        with self._lock:
            if key in self._timers:
                self._timers[key].cancel()
            t = threading.Timer(self.debounce, self._fire, args=(key, store))
            t.daemon = True
            self._timers[key] = t
            t.start()

    def _fire(self, key, store):
        with self._lock:
            self._timers.pop(key, None)
        self._run(store)

    def flush(self):
        with self._lock:
            pending = list(self._timers.items())
            self._timers.clear()
        for key, t in pending:
            t.cancel()
        for key, _ in pending:
            self._run(Path(key))


SYNC = SyncScheduler()
STATE = {
    "last_request": time.time(),
    "bye_timer": None,
    "httpd": None,
}
STATE_LOCK = threading.Lock()


def request_shutdown(reason):
    httpd = STATE.get("httpd")
    print(f"[policy-console] shutting down ({reason})", file=sys.stderr, flush=True)
    SYNC.flush()
    if httpd is not None:
        threading.Thread(target=httpd.shutdown, daemon=True).start()


def touch_activity():
    with STATE_LOCK:
        STATE["last_request"] = time.time()
        t = STATE.get("bye_timer")
        if t is not None:
            t.cancel()
            STATE["bye_timer"] = None


def schedule_bye_shutdown():
    with STATE_LOCK:
        t = STATE.get("bye_timer")
        if t is not None:
            t.cancel()
        t = threading.Timer(BYE_GRACE_SEC, request_shutdown, args=("tab closed",))
        t.daemon = True
        STATE["bye_timer"] = t
        t.start()


def idle_watchdog(idle_timeout):
    if idle_timeout <= 0:
        return
    interval = max(1, min(30, idle_timeout // 3))
    while True:
        time.sleep(interval)
        with STATE_LOCK:
            idle = time.time() - STATE["last_request"]
        if idle >= idle_timeout:
            request_shutdown(f"idle {int(idle)}s")
            return


# ---- HTTP ハンドラ ----

class Handler(BaseHTTPRequestHandler):
    token = ""

    def _authorized(self, query, form=None):
        t = (query.get("t") or [""])[0]
        if not t and form is not None:
            t = (form.get("t") or [""])[0]
        return bool(t) and hmac.compare_digest(t, self.token)

    def _send(self, status, body, ctype="text/html; charset=utf-8"):
        data = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _json(self, status, obj):
        self._send(status, json.dumps(obj, ensure_ascii=False), "application/json; charset=utf-8")

    def _forbidden(self):
        self._send(403, render_message(
            "403 Forbidden",
            "アクセスできません（トークンが一致しません）。起動時に表示された URL を開いてください。"))

    def do_GET(self):
        url = urlsplit(self.path)
        query = parse_qs(url.query)
        if not self._authorized(query):
            self._forbidden()
            return
        touch_activity()
        if url.path != "/":
            self._send(404, render_message("404 Not Found", "ページが見つかりません。"))
            return
        self._send(200, render_console(collect(), self.token))

    def do_POST(self):
        url = urlsplit(self.path)
        query = parse_qs(url.query)
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(min(length, 1_000_000)).decode("utf-8", "replace")
        form = parse_qs(body, keep_blank_values=True)
        if not self._authorized(query, form):
            self._forbidden()
            return

        if url.path == "/bye":
            # タブが閉じられた（リロードなら直後の GET が touch_activity で猶予を取り消す）
            self._json(200, {"ok": True})
            schedule_bye_shutdown()
            return

        touch_activity()

        if url.path == "/shutdown":
            self._send(200, render_message(
                "完了", "保存と store 同期を開始しました。このウィンドウは閉じて構いません。"))
            request_shutdown("done button")
            return

        if url.path != "/save":
            self._send(404, render_message("404 Not Found", "ページが見つかりません。"))
            return

        store_arg = (form.get("store") or [""])[0]
        name = (form.get("project") or [""])[0]
        # パストラバーサル対策: 列挙済みの store × project に一致した場合のみ書き込む
        target = None
        for store in discover_stores():
            if str(store) == store_arg and name in discover_projects(store):
                target = load_project(store, name)
                break
        if target is None:
            self._json(400, {"ok": False, "error": "対象の project が見つかりません"})
            return
        try:
            policy = apply_form(target, form)
        except ValueError as e:
            self._json(400, {"ok": False, "error": str(e)})
            return
        path = write_policy(target, policy)
        print(f"[policy-console] wrote: {path}", file=sys.stderr, flush=True)
        SYNC.schedule(target["store"])
        self._json(200, {"ok": True, "saved_at": time.strftime("%H:%M:%S")})

    def log_message(self, fmt, *args):
        print("[policy-console] " + fmt % args, file=sys.stderr, flush=True)


# ---- エントリポイント ----

def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="policy-console.py",
        description="banto policy console（policy.json の一覧 + 編集を 1 画面で。自動保存・自動終了）")
    ap.add_argument("--port", type=int, default=0, help="ポート（既定 0 = 空きポート）")
    ap.add_argument("--idle-timeout", type=int, default=900,
                    help="無通信での自動終了秒数（既定 900 = 15 分。0 で無効）")
    args = ap.parse_args(argv)

    Handler.token = secrets.token_urlsafe(24)
    httpd = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    STATE["httpd"] = httpd
    print(f"http://127.0.0.1:{httpd.server_address[1]}/?t={Handler.token}", flush=True)

    threading.Thread(target=idle_watchdog, args=(args.idle_timeout,), daemon=True).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        SYNC.flush()
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
