#!/usr/bin/env python3
"""Generate the SnapSort app icon as a 1024×1024 PNG.

Renders an indigo-gradient rounded square with two slightly-rotated white
"screenshot" tiles and a corner sparkle — same composition as
SnapSortLogo.swift but as a real PNG so it can ship in Assets.xcassets.
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
OUT_PATH = os.path.join(os.path.dirname(__file__), "AppIcon-1024.png")

INDIGO_LIGHT = (107, 91, 247)   # #6B5BF7
INDIGO_DARK  = (69, 56, 214)    # #4538D6


def linear_gradient(size, c1, c2):
    img = Image.new("RGB", size, c1)
    px = img.load()
    w, h = size
    diag = math.hypot(w, h)
    for y in range(h):
        for x in range(w):
            # diagonal gradient top-left → bottom-right
            t = (x + y) / (w + h - 2)
            r = int(c1[0] + (c2[0] - c1[0]) * t)
            g = int(c1[1] + (c2[1] - c1[1]) * t)
            b = int(c1[2] + (c2[2] - c1[2]) * t)
            px[x, y] = (r, g, b)
    return img


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def make_tile(side, accent_dark):
    """Return an RGBA tile of size (side, side*1.4)-ish — white with subtle indigo bars."""
    w = side
    h = int(side * 1.32)
    radius = int(side * 0.18)

    tile = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tile)

    # White rounded body
    draw.rounded_rectangle((0, 0, w, h), radius=radius, fill=(255, 255, 255, 255))

    # Subtle indigo "content" bars
    bar_color_strong = (accent_dark[0], accent_dark[1], accent_dark[2], 60)
    bar_color_soft = (accent_dark[0], accent_dark[1], accent_dark[2], 38)

    pad_x = int(w * 0.16)
    bar_h = int(side * 0.06)
    spacing = int(side * 0.10)
    y = int(h * 0.20)
    widths = [0.45, 0.62, 0.30]
    for i, frac in enumerate(widths):
        bar_w = int((w - pad_x * 2) * frac)
        col = bar_color_strong if i == 0 else bar_color_soft
        draw.rounded_rectangle(
            (pad_x, y, pad_x + bar_w, y + bar_h),
            radius=bar_h // 2,
            fill=col,
        )
        y += bar_h + spacing

    # White stroke ring (subtle inner outline)
    stroke = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(stroke)
    sdraw.rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, outline=(255, 255, 255, 140), width=int(side * 0.025))
    tile = Image.alpha_composite(tile, stroke)

    return tile


def add_drop_shadow(layer, blur, opacity, offset):
    w, h = layer.size
    pad = blur * 4
    padded = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    padded.paste(layer, (pad, pad), layer)
    alpha = padded.split()[3]
    shadow = Image.new("RGBA", padded.size, (0, 0, 0, 0))
    shadow_alpha = alpha.point(lambda a: int(a * opacity))
    shadow.putalpha(shadow_alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", padded.size, (0, 0, 0, 0))
    out.paste(shadow, (offset[0], offset[1]), shadow)
    out = Image.alpha_composite(out, padded)
    return out, pad


def main():
    radius = int(SIZE * 0.225)

    # Background — indigo gradient masked to rounded square
    bg = linear_gradient((SIZE, SIZE), INDIGO_LIGHT, INDIGO_DARK).convert("RGBA")
    mask = rounded_mask((SIZE, SIZE), radius)
    bg.putalpha(mask)

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas = Image.alpha_composite(canvas, bg)

    # Build two tiles — each rotated and offset
    tile_side = int(SIZE * 0.36)

    def place_tile(rotation_deg, offset_x, offset_y):
        tile = make_tile(tile_side, INDIGO_DARK)
        tile = tile.rotate(rotation_deg, resample=Image.BICUBIC, expand=True)
        shadowed, pad = add_drop_shadow(tile, blur=int(SIZE * 0.025), opacity=0.30, offset=(0, int(SIZE * 0.012)))
        tw, th = shadowed.size
        x = (SIZE - tw) // 2 + offset_x
        y = (SIZE - th) // 2 + offset_y
        canvas.alpha_composite(shadowed, (x, y))

    # Back tile (slightly left, rotated CCW)
    place_tile(rotation_deg=10, offset_x=-int(SIZE * 0.10), offset_y=int(SIZE * 0.02))
    # Front tile (slightly right, rotated CW)
    place_tile(rotation_deg=-8, offset_x=int(SIZE * 0.06), offset_y=-int(SIZE * 0.03))

    # Sparkle in the top-right corner — drawn as 4-point star
    sx = int(SIZE * 0.78)
    sy = int(SIZE * 0.22)
    star = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(star)
    short = int(SIZE * 0.04)
    long_ = int(SIZE * 0.115)
    points = [
        (sx, sy - long_),  # top
        (sx + short, sy - short),
        (sx + long_, sy),  # right
        (sx + short, sy + short),
        (sx, sy + long_),  # bottom
        (sx - short, sy + short),
        (sx - long_, sy),  # left
        (sx - short, sy - short),
    ]
    sdraw.polygon(points, fill=(255, 255, 255, 255))
    star_shadow = star.filter(ImageFilter.GaussianBlur(int(SIZE * 0.012)))
    star_shadow_alpha = star_shadow.split()[3].point(lambda a: int(a * 0.35))
    sd = Image.new("RGBA", star.size, (0, 0, 0, 0))
    sd.putalpha(star_shadow_alpha)
    canvas.alpha_composite(sd)
    canvas.alpha_composite(star)

    # Re-mask to the rounded square so anything bleeding past gets clipped
    final_mask = rounded_mask((SIZE, SIZE), radius)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(canvas, (0, 0), final_mask)

    # iOS app icons must be opaque (no alpha channel) — flatten onto white-bg-of-mask
    # The rounded shape is preserved by Apple's display chrome. We'll save as RGB.
    flat = Image.new("RGB", (SIZE, SIZE), INDIGO_DARK)
    flat.paste(out, (0, 0), out)

    flat.save(OUT_PATH, format="PNG", optimize=True)
    print(f"Wrote {OUT_PATH} ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()
