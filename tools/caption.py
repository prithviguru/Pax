#!/usr/bin/env python3
"""Print the caption and creator of a shared TikTok or Instagram link, as JSON.

  caption.py <url>   ->  {"url": "<full link>", "author": "...", "caption": "..."}

TikTok: follows short links (tiktok.com/t/...), tries oEmbed (works for videos), then falls back
to the "desc" in the page's embedded data (photo posts have no oEmbed caption).
Instagram: tries the page's og:description; Instagram often hides it, so the caption may be empty.
An empty caption means "couldn't read it", not "no caption".
"""
import html, json, re, sys, urllib.parse, urllib.request

UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "en-US"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.geturl(), r.read().decode("utf-8", "ignore")

def tiktok(url):
    full, page = fetch(url)
    full = full.split("?")[0]
    m = re.search(r"tiktok\.com/@([^/]+)/(?:video|photo)/(\d+)", full)
    author, caption = (m.group(1) if m else ""), ""
    if m:
        try:
            oe = json.loads(fetch("https://www.tiktok.com/oembed?url=" + urllib.parse.quote(f"https://www.tiktok.com/@{m.group(1)}/video/{m.group(2)}", safe=""))[1])
            caption, author = oe.get("title") or "", oe.get("author_name") or author
        except Exception:
            pass
    if not caption:
        d = re.search(r'"desc":"((?:[^"\\]|\\.)*)"', page)
        if d: caption = json.loads('"' + d.group(1) + '"')
    return {"url": full, "author": author, "caption": caption}

def instagram(url):
    full, page = fetch(url)
    m = re.search(r'<meta[^>]+(?:property|name)="og:description"[^>]+content="([^"]*)"', page)
    return {"url": full.split("?")[0], "author": "", "caption": html.unescape(m.group(1)) if m else ""}

if __name__ == "__main__":
    if len(sys.argv) != 2: print(__doc__); sys.exit(2)
    u = sys.argv[1]
    try:
        out = tiktok(u) if "tiktok.com" in u else instagram(u) if "instagram.com" in u else {"url": u, "author": "", "caption": ""}
    except Exception as e:
        out = {"url": u, "author": "", "caption": "", "error": str(e)[:200]}
    print(json.dumps(out, ensure_ascii=False))
