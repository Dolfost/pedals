#!/usr/bin/env -S freecadcmd
# Writes the case sketches in connectors.FCStd as SVG, one file per sketch,
# for the README:  FC_OUT=images/sketches freecadcmd gen-sketches.py
# Runs headless (FreeCAD's own importSVG exporter crashes without a GUI);
# 1 SVG user unit = 1 mm, construction geometry is drawn dashed grey.
import FreeCAD, os
out = os.environ.get("FC_OUT", "images/sketches")
doc = FreeCAD.openDocument(os.path.join(os.getcwd(), "connectors.FCStd"))
# sketch label -> (file name, title, subtitle)
names = {
  "top 2":   ("top",               "top", "12 LED holders Ø5 on a 20 × 25 mm grid, power LED Ø7"),
  "jacks 2": ("side",              "left and right side panels (final)", "6 jacks Ø9, 21 mm pitch, one row per case shell"),
  "bottom":  ("bottom",            "bottom", "opto board mounting, 4 × Ø3 on 45 × 65 mm"),
  "front":   ("front",             "front end panel", "controller PCB mounting, 2 × Ø3, 39.5 mm apart"),
  "back":    ("back",              "back end panel", "PG7 cable gland, Ø12.5"),
  "jacks":   ("side-first-layout", "side panel, first layout (not used)", "jacks Ø9 and LEDs Ø5 side by side, 2 rows of 3+3"),
  "labels":  ("label-study",       "label sizing study", "jack nut Ø18, label discs Ø12 and Ø6, LED bezel Ø4"),
}
for o in doc.Objects:
    if o.TypeId != "Sketcher::SketchObject": continue
    fname, t1, t2 = names.get(o.Label, (o.Label.replace(" ", "_"), o.Label, ""))
    circles, lines, ccircles, clines = [], [], [], []
    try: facades = [(f.Geometry, f.Construction) for f in o.GeometryFacadeList]
    except Exception: facades = [(g, False) for g in o.Geometry]
    for g, con in facades:
        if "Circle" in g.TypeId: (ccircles if con else circles).append((g.Center.x, g.Center.y, g.Radius))
        elif "LineSegment" in g.TypeId: (clines if con else lines).append((g.StartPoint.x, g.StartPoint.y, g.EndPoint.x, g.EndPoint.y))
    xs = [v for l in lines + clines for v in (l[0], l[2])] + [c[0] + s * c[2] for c in circles + ccircles for s in (-1, 1)]
    ys = [v for l in lines + clines for v in (l[1], l[3])] + [c[1] + s * c[2] for c in circles + ccircles for s in (-1, 1)]
    xmin, xmax, ymin, ymax = min(xs), max(xs), min(ys), max(ys)
    t2 = "%s, %.0f × %.0f mm" % (t2, xmax - xmin, ymax - ymin)
    m, top = 6.0, 16.0
    w = max(xmax - xmin + 2 * m, 0.6 * 4 * len(t1) + 2 * m, 0.55 * 3.2 * len(t2) + 2 * m)
    h = ymax - ymin + m + top
    X = lambda x: x - xmin + m
    Y = lambda y: ymax - y + top
    p = ['<svg xmlns="http://www.w3.org/2000/svg" width="%.1fmm" height="%.1fmm" viewBox="0 0 %.3f %.3f">' % (w * 1.5, h * 1.5, w, h),
         '<rect width="100%" height="100%" fill="white"/>',
         '<text x="%.1f" y="5.5" font-family="sans-serif" font-size="4" font-weight="bold" fill="#000">%s</text>' % (m, t1),
         '<text x="%.1f" y="10.5" font-family="sans-serif" font-size="3.2" fill="#444">%s</text>' % (m, t2),
         '<g fill="none" stroke="#999" stroke-width="0.2" stroke-dasharray="1.2 0.8">']
    p += ['<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f"/>' % (X(a), Y(b), X(c), Y(d)) for a, b, c, d in clines]
    p += ['<circle cx="%.3f" cy="%.3f" r="%.3f"/>' % (X(x), Y(y), r) for x, y, r in ccircles]
    p.append('</g><g fill="none" stroke="black" stroke-width="0.35" stroke-linecap="round">')
    p += ['<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f"/>' % (X(a), Y(b), X(c), Y(d)) for a, b, c, d in lines]
    for x, y, r in circles:
        p.append('<circle cx="%.3f" cy="%.3f" r="%.3f"/>' % (X(x), Y(y), r))
        p.append('<path d="M%.3f %.3f h%.3f M%.3f %.3f v%.3f" stroke-width="0.2"/>' % (X(x) - r * 0.6, Y(y), r * 1.2, X(x), Y(y) - r * 0.6, r * 1.2))
    p.append('</g></svg>')
    with open(os.path.join(out, fname + ".svg"), "w") as f: f.write("\n".join(p) + "\n")
