#!/usr/bin/env python3
"""Generate docs/preview.svg, the animated preview shown at the top of the README.

The SVG is a mockup of the addon's two boxes, not a screenshot: a short
scripted fight where abilities are used, count down and drop out of the box.
It follows the addon's real rules so it stays honest:

- rows keep the whitelist order and a ready row is skipped, so the rows
  below it move up (ac_view hides it, abilities_cooldown skips it);
- text over a 7px line that drains (style = 'underline', the default);
- the line fades from colors.start to colors.ready by blending hue, like
  ac_view's fade().

The timeline is simulated in Python and baked into CSS keyframes, so the file
needs no script (GitHub strips scripts from images; CSS animation plays).
Standard library only. Usage:
    python3 scripts/make-readme-preview.py
Writes docs/preview.svg. Re-run it after changing the look.
"""
import colorsys
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "docs" / "preview.svg"

# The addon's defaults (ac_config.lua). Keep in step with it.
START = (230, 45, 35)
READY = (60, 220, 60)
TRACK_OPACITY = 200 / 255  # ac_view TRACK_ALPHA
LINE_H = 7
BAR_H = 22
ROW_SPACING = 2
BOX_W = 160  # the addon's minimum is 140; a little wider for longer labels
FONT_PX = 14  # font_size 11 (points) at the game's usual scale

LOOP_SECONDS = 24  # the whole scene repeats after this
SAMPLE = 0.5  # seconds between keyframes for the line; it is linear in between

# Two boxes of whitelist rows: (label, recast seconds, start times in the loop).
# Recasts are shortened so the loop stays short. A row's uses must leave a gap
# of at least a second, so its line can reset while it is hidden.
BOXES = [
    ("Main job", [
        ("Meditate", 14, [1]),
        ("Hasso", 5, [7, 19]),
        ("Sekkanoki", 10, [4, 16]),
        ("Third Eye", 8, [2, 13]),
    ]),
    ("Sub job", [
        ("Berserk", 12, [3]),
        ("Aggressor", 9, [6, 18]),
        ("Warcry", 7, [10]),
    ]),
]

PAD = 24
BOX_GAP = 44
CAPTION_H = 26
STEP = BAR_H + ROW_SPACING


def fade(progress):
    """Hex color for progress 0 (just used) to 1 (ready), blending HSV."""
    h1, s1, v1 = colorsys.rgb_to_hsv(*(c / 255 for c in START))
    h2, s2, v2 = colorsys.rgb_to_hsv(*(c / 255 for c in READY))
    t = max(0.0, min(1.0, progress))
    r, g, b = colorsys.hsv_to_rgb(h1 + (h2 - h1) * t, s1 + (s2 - s1) * t, v1 + (v2 - v1) * t)
    return "#%02x%02x%02x" % tuple(int(round(c * 255)) for c in (r, g, b))


def remaining(recast, uses, t):
    """Seconds left on the recast at loop time t (0 when ready). Wraps around
    the loop end so the animation repeats seamlessly."""
    best = 0.0
    for start in uses:
        since = (t - start) % LOOP_SECONDS
        if since < recast:
            best = max(best, recast - since)
    return best


def times(step):
    n = int(round(LOOP_SECONDS / step))
    return [i * step for i in range(n + 1)]  # includes the loop end (100%)


def pct(t):
    return "%.3f%%" % (100 * t / LOOP_SECONDS)


def stepped(name, samples):
    """Keyframes that hold each value until the next change (step-end).
    samples: [(t, css)]; consecutive repeats are dropped."""
    frames, last = [], None
    for t, css in samples:
        if css != last or t == LOOP_SECONDS:
            frames.append("%s{%s}" % (pct(t), css))
            last = css
    return "@keyframes %s{%s}" % (name, "".join(frames))


def main():
    css = []
    body = []
    x = PAD
    for b, (caption, rows) in enumerate(BOXES):
        top = PAD + CAPTION_H
        body.append('<text class="cap" x="%d" y="%d">%s</text>' % (x, PAD + 12, caption))
        body.append('<g transform="translate(%d %d)">' % (x, top))

        coarse = times(0.25)  # visibility, slots and digits change on whole seconds
        # slot[t] for every row: its position among the rows still on cooldown.
        def slot_of(i, t):
            return sum(1 for (_, r, u) in rows[:i] if remaining(r, u, t) > 0)

        for i, (label, recast, uses) in enumerate(rows):
            rid = "b%dr%d" % (b, i)

            # Row group: shown while on cooldown, moved to its slot.
            row_samples = []
            for t in coarse:
                if remaining(recast, uses, t) > 0:
                    row_samples.append((t, "opacity:1;transform:translateY(%dpx)" % (slot_of(i, t) * STEP)))
                else:
                    row_samples.append((t, "opacity:0;transform:translateY(%dpx)" % (slot_of(i, t) * STEP)))
            css.append(stepped(rid, row_samples))
            css.append("#%s{%s;animation-name:%s;animation-timing-function:step-end}"
                       % (rid, row_samples[0][1], rid))

            # The line: drains and changes color, linear between samples. A
            # hidden row stays empty, and refills only in the last sample
            # before its next use, so the refill never shows (uses are at
            # least a second apart, two samples).
            def line_fraction(t):
                left = remaining(recast, uses, t)
                if left > 0:
                    return left / recast
                return 1.0 if remaining(recast, uses, t + SAMPLE) > 0 else 0.0

            line = []
            for t in times(SAMPLE):
                fraction = line_fraction(t)
                line.append("%s{transform:scaleX(%.4f);fill:%s}" % (pct(t), fraction, fade(1 - fraction)))
            first_fraction = line_fraction(0)
            css.append("@keyframes %sf{%s}" % (rid, "".join(line)))
            css.append("#%sf{transform:scaleX(%.4f);fill:%s;animation-name:%sf;animation-timing-function:linear}"
                       % (rid, first_fraction, fade(1 - first_fraction), rid))

            # Countdown digits: one text per value, each shown only in its second.
            digits = []
            for value in range(recast, 0, -1):
                did = "%sd%d" % (rid, value)
                samples = [(t, "opacity:%d" % (1 if math.ceil(remaining(recast, uses, t)) == value
                                                 and remaining(recast, uses, t) > 0 else 0))
                           for t in coarse]
                css.append(stepped(did, samples))
                css.append("#%s{%s;animation-name:%s;animation-timing-function:step-end}"
                           % (did, samples[0][1], did))
                digits.append('<text id="%s" class="t" x="%d" y="%d" text-anchor="end">%d</text>'
                              % (did, BOX_W, BAR_H - LINE_H - 4, value))

            line_y = BAR_H - LINE_H
            body.append('<g id="%s" class="a">' % rid)
            body.append('<rect y="%d" width="%d" height="%d" fill="#000" fill-opacity="%.3f"/>'
                        % (line_y, BOX_W, LINE_H, TRACK_OPACITY))
            body.append('<g transform="translate(0 %d)"><rect id="%sf" class="a" width="%d" height="%d"/></g>'
                        % (line_y, rid, BOX_W, LINE_H))
            body.append('<text class="t" x="0" y="%d">%s</text>' % (BAR_H - LINE_H - 4, label))
            body.extend(digits)
            body.append("</g>")
        body.append("</g>")
        x += BOX_W + BOX_GAP

    width = x - BOX_GAP + PAD
    height = PAD + CAPTION_H + max(len(rows) for _, rows in BOXES) * STEP + PAD - ROW_SPACING

    # Digits share the row's class for timing; give every animated id the loop.
    css.insert(0, "*{animation-duration:%ds;animation-iteration-count:infinite}" % LOOP_SECONDS)
    css.insert(1, ".t{font:%dpx Arial,Helvetica,sans-serif;fill:#fff;stroke:#000;stroke-width:3px;"
                  "stroke-linejoin:round;paint-order:stroke}" % FONT_PX)
    css.insert(2, ".cap{font:italic 11px Arial,Helvetica,sans-serif;fill:#8a96a8;letter-spacing:.04em}")
    # Without motion, show the first frame of the scene as a still image.
    css.append("@media (prefers-reduced-motion:reduce){*{animation:none!important}}")

    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
        'role="img" aria-label="Animated preview: cooldown rows draining and fading from red to green">'
        "<title>abilities_cooldown preview</title>"
        "<defs><linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">"
        '<stop offset="0" stop-color="#2a3a4f"/><stop offset="1" stop-color="#121a24"/>'
        "</linearGradient></defs>"
        "<style>{css}</style>"
        '<rect width="{w}" height="{h}" rx="10" fill="url(#bg)"/>'
        "{body}</svg>\n"
    ).format(w=width, h=height, css="".join(css), body="".join(body))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(svg)
    print("%s (%d bytes, %dx%d)" % (OUT, len(svg), width, height))


if __name__ == "__main__":
    main()
