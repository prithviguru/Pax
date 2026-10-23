#!/usr/bin/env python3
"""Read and write Pax's shared database (Supabase) from the command line.

Each household's documents are walled off from the others (supabase/households.sql). The planner
reads them with the service key, set as SUPABASE_SERVICE_ROLE_KEY in the environment's secrets;
every command then works on one household: --household <id>, or PAX_HOUSEHOLD, or by default
Prithvi & Nihal's. Without the service key (before households.sql was run) it uses the app's public
key from docs/config.js and the single shared household. SUPABASE_URL overrides the URL.

Documents use the same slash paths the app uses:
  household/profile           who's in the household, what they eat and like, their usual week
  weeks/2026-10-26            the week's plan
  weeks/2026-10-26/nights/mon what they changed on a night
  box/<key>, rejects/<key>, staples/list, checks/<week>, requests/<id>, decks/<week>

Usage:
  paxdb.py households                     every household: id, name, phones (service key only)
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

def _service_key(): return os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

def _req(method, url, body=None, prefer=None):
    key = _service_key() or _config()["anonKey"]
    headers = {"apikey": key, "Content-Type": "application/json"}
    if key.startswith("eyJ"):  # legacy JWT keys also go in Authorization; new sb_secret_ keys don't
        headers["Authorization"] = "Bearer " + key
    if prefer: headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        sys.exit(f"Supabase said {e.code}: {e.read().decode(errors='replace')[:400]}")

def _base(): return (os.environ.get("SUPABASE_URL") or _config()["url"]).rstrip("/") + "/rest/v1"
def _q(v): return urllib.parse.quote(v, safe="")
def _parent(path): return path.rsplit("/", 1)[0]
def _read(arg): return json.load(sys.stdin if arg == "-" else open(arg))

def main(argv):
    argv = list(argv)
    household = os.environ.get("PAX_HOUSEHOLD") or PRITHVI_AND_NIHAL
    if "--household" in argv:
        i = argv.index("--household"); household = argv[i + 1]; del argv[i:i + 2]
    scoped = bool(_service_key())  # households exist once the service key is in use
    h = f"&household_id=eq.{_q(household)}" if scoped else ""
    if len(argv) >= 2 and argv[1] == "households":
        if not scoped: sys.exit("Listing households needs SUPABASE_SERVICE_ROLE_KEY.")
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
        row = {"path": path, "collection": _parent(path), "data": _read(argv[3])}
        if scoped: row["household_id"] = household
        _req("POST", f"{_base()}/docs?on_conflict={'household_id,path' if scoped else 'path'}", row, prefer="resolution=merge-duplicates")
        print("set", path)
    elif cmd == "merge":
        args = {"p_path": path, "p_patch": _read(argv[3])}
        if scoped: args["p_household"] = household
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
