"""Toolbar icons for the Hier-View buttons, drawn rather than sourced.

The rest of PNG/ is stock icon-pack art with gradients and bevels.  These three
are flat on purpose: they are generated, so they can be corrected by editing a
shape instead of being redrawn by hand, and they stay legible at 32px, which is
the size they are actually used at.

    python3 ETC/icons/make_toolbar_icons.py [outdir, default ../../PNG]

Everything is drawn 8x oversized and downscaled with Lanczos; drawing straight
at 32px gives stair-stepped diagonals on the arrowheads.
"""

import os
import sys

from PIL import Image, ImageDraw
OUT = sys.argv[1] if len(sys.argv) > 1 else \
      os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "PNG")

SS = 8                      # supersample, then downscale for clean edges
N  = 32

BLOCK  = (70, 110, 165, 255)   # steel blue, the "module"
BLOCK2 = (140, 175, 215, 255)
DOWN   = (40, 150, 70, 255)    # green: into the view
UP     = (190, 95, 35, 255)    # orange: back out
FLAT   = (120, 120, 130, 255)

def new():
    im = Image.new("RGBA", (N*SS, N*SS), (0,0,0,0))
    return im, ImageDraw.Draw(im)

def done(im, name):
    name = os.path.join(OUT, name)
    im = im.resize((N, N), Image.Resampling.LANCZOS)
    im.save(name)

def box(d, x0,y0,x1,y1, fill, outline=(30,50,80,255), w=2):
    d.rectangle([x0*SS,y0*SS,x1*SS,y1*SS], fill=fill, outline=outline, width=w*SS)

def arrow(d, cx, y0, y1, colour, half=6, shaft=4):
    """vertical arrow, head at y1"""
    down = y1 > y0
    tip = y1
    base = y1 - (7 if down else -7)
    d.polygon([(cx-half)*SS, base*SS, (cx+half)*SS, base*SS, cx*SS, tip*SS], fill=colour)
    a, b = sorted((y0, base))
    d.rectangle([(cx-shaft)*SS, a*SS, (cx+shaft)*SS, b*SS], fill=colour)

# --- Edit: arrow down INTO a module box ---
im, d = new()
box(d, 4, 18, 28, 29, BLOCK)
arrow(d, 16, 3, 16, DOWN)
done(im, "editMod_32.png")

# --- Commit: arrow up OUT of a module box ---
im, d = new()
box(d, 4, 18, 28, 29, BLOCK)
arrow(d, 16, 16, 3, UP)
done(im, "commitMod_32.png")

# --- Hier2Flat: a stack of blocks collapsing to one flat row ---
im, d = new()
box(d, 3, 3, 14, 9,  BLOCK)
box(d, 3, 11, 14, 17, BLOCK2)
box(d, 3, 19, 14, 25, BLOCK)
d.polygon([16*SS,11*SS, 16*SS,19*SS, 23*SS,15*SS], fill=FLAT)
box(d, 24, 12, 29, 18, FLAT, outline=(60,60,70,255), w=2)
done(im, "hier2flat_32.png")
print("wrote editMod_32.png commitMod_32.png hier2flat_32.png to " + os.path.normpath(OUT))
