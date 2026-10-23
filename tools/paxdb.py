#!/usr/bin/env python3
"""Read and write Pax's shared database (Supabase) from the command line.

Each household's documents are walled off from the others (supabase/households.sql), so the planner
uses Supabase's secret key, which can read every household. The key is never in the repo or a
session: it's a network secret on the Claude environment (header `apikey` on
xzvsxgbsdzwvdmgmclut.supabase.co), added to requests on their way out. SUPABASE_SERVICE_ROLE_KEY,
if set, is used instead (for running it somewhere else). Every command works on one household:
--household <id>, or PAX_HOUSEHOLD, or by default Prithvi & Nihal's. SUPABASE_URL overrides the URL.

Documents use the same slash paths the app uses:
  household/profile           who's in the household, what they eat and like, their usual week
  weeks/2026-10-26            the week's plan
  weeks/2026-10-26/nights/mon what they changed on a night
  box/<key>, rejects/<key>, staples/list, checks/<week>, requests/<id>, decks/<week>

Usage:
  paxdb.py households                     every household: id, name, phones
  paxdb.py [--household ID] get   <path>
  paxdb.py [--household ID] list  <collection>          documents directly under it, as {id: data}
  paxdb.py [--household ID] set   <path> <file.json|->  replace a document
  paxdb.py [--household ID] merge <path> <file.json|->  deep-merge into a document (creates it if missing)
  paxdb.py [--household ID] delete <path>
"""
import json, os, re, sys, urllib.request, urllib.parse

PRITHVI_AND_NIHAL = "00000000-0000-4000-8000-000000000001"

def _config():
    src = open(os.path.join(os.path.dirname(__file__), "..", "docs", "config.js")).read()
    return dict(re.findall(r'(url|anonKey):\s*"([^"]+)"', src))

def _req(method, url, body=None, prefer=None):
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    headers = {"Content-Type": "application/json"}
    if key:  # otherwise the environment's network secret adds the apikey header
        headers["apikey"] = key
        if key.startswith("eyJ"):  # legacy JWT keys also go in Authorization; new sb_secret_ keys don't
            headers["Authorization"] = "Bearer " + key
    if prefer: headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")[:400]
        if e.code in (401, 403) and ("API key" in msg or "permission denied" in msg or "Invalid" in msg):
            sys.exit("Supabase refused: no planner key reached it. Prithvi needs to add the Supabase secret key as a "
                     "network secret on the Claude environment (header apikey, website xzvsxgbsdzwvdmgmclut.supabase.co). "
                     f"Supabase said {e.code}: {msg}")
        sys.exit(f"Supabase said {e.code}: {msg}")

def _base(): return (os.environ.get("SUPABASE_URL") or _config()["url"]).rstrip("/") + "/rest/v1"
def _q(v): return urllib.parse.quote(v, safe="")
def _parent(path): return path.rsplit("/", 1)[0]
def _read(arg): return json.load(sys.stdin if arg == "-" else open(arg))

def main(argv):
    argv = list(argv)
    household = os.environ.get("PAX_HOUSEHOLD") or PRITHVI_AND_NIHAL
    if "--household" in argv:
        i = argv.index("--household"); household = argv[i + 1]; del argv[i:i + 2]
    h = f"&household_id=eq.{_q(household)}"
    if len(argv) >= 2 and argv[1] == "households":
        hs = _req("GET", f"{_base()}/households?select=id,name&order=created_at")
        ms = _req("GET", f"{_base()}/household_members?select=household_id")
        for x in hs: x["phones"] = sum(1 for m in ms if m["household_id"] == x["id"])
        print(json.dumps(hs, indent=2, ensure_ascii=False)); return 0
    if len(argv) < 3: print(__doc__); return 2
    cmd, path = argv[1], argv[2].strip("/")
    if cmd == "get":
        rows = _req("GET", f"{_base()}/docs?select=data&path=eq.{_q(path)}{h}")
        print(json.dumps(rows[0]["data"] if rows else None, indent=2, ensure_ascii=False))
    elif cmd == "list":
        rows = _req("GET", f"{_base()}/docs?select=path,data&collection=eq.{_q(path)}{h}&order=path")
        print(json.dumps({r["path"].rsplit("/", 1)[1]: r["data"] for r in rows}, indent=2, ensure_ascii=False))
    elif cmd == "set":
        row = {"household_id": household, "path": path, "collection": _parent(path), "data": _read(argv[3])}
        _req("POST", f"{_base()}/docs?on_conflict=household_id,path", row, prefer="resolution=merge-duplicates")
        print("set", path)
    elif cmd == "merge":
        args = {"p_path": path, "p_patch": _read(argv[3]), "p_household": household}
        out = _req("POST", f"{_base()}/rpc/merge_doc", args)
        print(json.dumps(out, indent=2, ensure_ascii=False))
    elif cmd == "delete":
        _req("DELETE", f"{_base()}/docs?path=eq.{_q(path)}{h}")
        print("deleted", path)
    else:
        print(__doc__); return 2
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
