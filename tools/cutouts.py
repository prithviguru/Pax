"""Cut paper-cutout illustrations out of a sheet on a plain beige background, as transparent PNGs.

  python3 tools/cutouts.py SHEET.png docs/illustrations '{"names": [["noodles","rice","chili"], ...], "rows": [[0,358], [418,748], ...]}'

`names` is the grid, row by row; `rows` is each row's top and bottom in pixels, stopping above the labels.
Needs numpy, scipy and Pillow. Check the results on a dark background: very pale items (garlic, rice,
egg white) can need tighter PARAMS and CLOSE values below.
"""
import sys, numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as nd
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
W, H = im.size
import json
LAYOUT = json.loads(sys.argv[3])
names = LAYOUT["names"]
PARAMS = {'mushrooms': (5, 1.0), 'garlic': (5, 1.0), 'egg': (6, 1.4), 'rice': (5, 1.0), 'chickpeas': (5, 1.0), 'tofu': (6, 1.2)}
CLOSE = {'mushrooms': 6, 'garlic': 6, 'egg': 3, 'rice': 5, 'chickpeas': 5, 'tofu': 4}
rows = LAYOUT["rows"]   # art only; the labels sit below each row
NC = len(names[0])
for r, (y0, y1) in enumerate(rows):
    for c, name in enumerate(names[r]):
        x0, x1 = round(c * W / NC), round((c + 1) * W / NC)
        cell = im.crop((x0, y0, x1, y1))
        a = np.asarray(cell.filter(ImageFilter.GaussianBlur(1.6))).astype(float)
        # Background = texture-smooth beige reachable from the cell's edges.
        bg_col = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), axis=0)
        dist = np.sqrt(((a - bg_col) ** 2).sum(-1))
        gy, gx = np.gradient(a.mean(-1))
        grad = np.hypot(gx, gy)
        D, G = PARAMS.get(name, (9, 2.2))
        cand = (dist < D) & (grad < G)
        lab, _ = nd.label(cand)
        border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        bg = np.isin(lab, list(border))
        obj = nd.binary_fill_holes(~bg)
        obj = nd.binary_closing(obj, iterations=CLOSE.get(name, 0)) if CLOSE.get(name) else obj
        obj = nd.binary_fill_holes(obj)
        obj = nd.binary_opening(obj, iterations=2)
        lab2, n = nd.label(obj)
        if n > 1:
            sizes = nd.sum(obj, lab2, range(1, n + 1))
            keep = [i + 1 for i, s in enumerate(sizes) if s > 0.04 * sizes.max()]
            obj = np.isin(lab2, keep)
        alpha = Image.fromarray((obj * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(0.8))
        rgba = cell.copy(); rgba.putalpha(alpha)
        bbox = alpha.point(lambda v: 255 if v > 20 else 0).getbbox()
        rgba = rgba.crop(bbox)
        if max(rgba.size) > 520: rgba.thumbnail((520, 520))
        rgba.save(f"{out}/{name}.png", optimize=True)
        print(name, rgba.size)
