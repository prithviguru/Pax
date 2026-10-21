#!/usr/bin/env python3
"""Read and write Pax's shared database (Supabase) from the command line.

Needs two environment variables, set in the environment's settings, never in code:
  SUPABASE_URL               e.g. https://xzvsxgbsdzwvdmgmclut.supabase.co
  SUPABASE_SERVICE_ROLE_KEY  the secret key; it bypasses the members-only rules, so keep it out of chat and git

Documents use the same slash paths the app uses:
  weeks/2026-10-26            the week's plan
  weeks/2026-10-26/nights/mon what they changed on a night
  box/<key>, rejects/<key>, staples/list, checks/<week>, requests/<id>

Usage:
  paxdb.py get   <path>
  paxdb.py list  <collection>             all documents directly under a collection, as {id: data}
  paxdb.py set   <path> <file.json|->     replace a document
  paxdb.py merge <path> <file.json|->     deep-merge into a document (creates it if missing)
  paxdb.py delete <path>
"""
import json, os, sys, urllib.request, urllib.parse

def _req(method, url, body=None, prefer=None):
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    headers = {"apikey": key, "Authorization": "Bearer " + key, "Content-Type": "application/json"}
    if prefer: headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=30) as r:
        raw = r.read()
        return json.loads(raw) if raw else None

def _base(): return os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1"
def _q(v): return urllib.parse.quote(v, safe="")
def _parent(path): return path.rsplit("/", 1)[0]
def _read(arg): return json.load(sys.stdin if arg == "-" else open(arg))

def main(argv):
    if len(argv) < 3: print(__doc__); return 2
    cmd, path = argv[1], argv[2].strip("/")
    if cmd == "get":
        rows = _req("GET", f"{_base()}/docs?select=data&path=eq.{_q(path)}")
        print(json.dumps(rows[0]["data"] if rows else None, indent=2, ensure_ascii=False))
    elif cmd == "list":
        rows = _req("GET", f"{_base()}/docs?select=path,data&collection=eq.{_q(path)}&order=path")
        print(json.dumps({r["path"].rsplit("/", 1)[1]: r["data"] for r in rows}, indent=2, ensure_ascii=False))
    elif cmd == "set":
        _req("POST", f"{_base()}/docs?on_conflict=path", {"path": path, "collection": _parent(path), "data": _read(argv[3])}, prefer="resolution=merge-duplicates")
        print("set", path)
    elif cmd == "merge":
        out = _req("POST", f"{_base()}/rpc/merge_doc", {"p_path": path, "p_patch": _read(argv[3])})
        print(json.dumps(out, indent=2, ensure_ascii=False))
    elif cmd == "delete":
        _req("DELETE", f"{_base()}/docs?path=eq.{_q(path)}")
        print("deleted", path)
    else:
        print(__doc__); return 2
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
