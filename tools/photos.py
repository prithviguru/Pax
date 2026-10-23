#!/usr/bin/env python3
"""Give every recipe card in Pax a photo: the recipe page's og:image, saved as `image`.

Fills cards that have a link but no image, across the week plans (weeks/<Mon> options),
nights people changed (boxPick), the recipe tin (box/) and the Sunday decks (decks/<Mon>).
Run it after planning, or any time cards show up without pictures:

  python3 tools/photos.py            # fill in what's missing
  python3 tools/photos.py --dry-run  # just show what it would do
"""
import html, json, re, subprocess, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
DRY = "--dry-run" in sys.argv
_seen = {}

def db(*args, stdin=None):
    out = subprocess.run([sys.executable, os.path.join(HERE, "paxdb.py"), *args], input=stdin, capture_output=True, text=True, check=True).stdout
    return json.loads(out) if out.strip() else None

def og_image(link):
    if link in _seen: return _seen[link]
    img = ""
    try:
        # A plain user agent: some recipe sites refuse browser-like ones.
        page = subprocess.run(["curl", "-sL", "-A", "curl/8.5.0", "--max-time", "20", link], capture_output=True, text=True, errors="ignore").stdout
        for pat in (r'<meta[^>]+property=["\']og:image["\'][^>]*content=["\']([^"\']+)', r'<meta[^>]+content=["\']([^"\']+)["\'][^>]*property=["\']og:image'):
            m = re.search(pat, page)
            if m: img = html.unescape(m.group(1)).strip(); break
    except Exception:
        pass
    _seen[link] = img if img.startswith("https://") else ""
    return _seen[link]

def fill(card):
    """Adds an image to one card in place. True if it changed."""
    if not isinstance(card, dict) or card.get("image") or not str(card.get("link", "")).startswith("https://"): return False
    img = og_image(card["link"])
    print(("  + " if img else "  - ") + str(card.get("dish") or card["link"])[:50] + (" -> " + img[:70] if img else " (no photo on the page)"))
    if img: card["image"] = img
    return bool(img)

def save(path, patch):
    if DRY: print("  would update", path); return
    db("merge", path, "-", stdin=json.dumps(patch))

def main():
    for wid, w in sorted((db("list", "weeks") or {}).items()):
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", wid): continue
        nights = w.get("nights") or {}
        changed = {sl: n for sl, n in nights.items() if any([fill(o) for o in n.get("options") or []])}
        if changed: save(f"weeks/{wid}", {"nights": {sl: {"options": n["options"]} for sl, n in changed.items()}})
        for sl, st in (db("list", f"weeks/{wid}/nights") or {}).items():
            if fill(st.get("boxPick")): save(f"weeks/{wid}/nights/{sl}", {"boxPick": st["boxPick"]})
    for key, card in (db("list", "box") or {}).items():
        if fill(card): save(f"box/{key}", {"image": card["image"]})
    for wid, d in (db("list", "decks") or {}).items():
        people = d.get("people") or {}
        if any([fill(c) for p in people.values() for c in p.get("cards") or []]):
            save(f"decks/{wid}", {"people": {k: {"cards": p["cards"]} for k, p in people.items()}})

if __name__ == "__main__":
    main()
