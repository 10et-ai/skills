---
name: pretext
description: "Creative engine for typographic web experiences using pure JS text measurement + impeccable design principles. Covers the FULL surface: pretext for typography effects, impeccable for design quality, taste for aesthetic direction. Use when building: website heroes, interactive typography, editorial layouts, brand experiences, product pages, or any web surface where quality matters."
---

# Pretext — Typographic Experience Engine

Pure JS text measurement by Cheng Lou. Zero DOM reads. 0.1ms full page reflow. Characters become a creative medium with width, weight, brightness, and physics.

## Before You Build ANYTHING

This skill orchestrates THREE capabilities. Read all of them:

1. **This file** — pretext techniques, creative framework, character palette
2. **`.claude/skills/impeccable/frontend-design/SKILL.md`** — design quality, AI slop avoidance, aesthetic direction
3. **`.claude/skills/impeccable/frontend-design/reference/`** — typography, color (OKLCH), spatial design, motion, interaction

**CRITICAL WORKFLOW:**
```
1. Read impeccable/frontend-design SKILL.md → understand aesthetic standards
2. Read this file → understand pretext techniques  
3. Articulate creative concept (mood, story, technique, colors, fonts)
4. Read relevant impeccable references (typography.md, color-and-contrast.md, motion-design.md)
5. Build
6. Run quality checklist (bottom of this file)
```

Do NOT skip steps 1 and 4. Pretext without design quality = a tech demo. Design quality without pretext = a static page. Both together = something nobody has seen before.

## Creative Standard

This is visual art. Proportional typography is the medium; cinema is the standard.

**Before writing code**, articulate:
- **Mood**: What should the viewer feel?
- **Story**: What happens over time/interaction?
- **Typography role**: Content? Texture? Structure? Physics?
- **Interaction model**: Mouse = gravity? disruption? focus? fluid source?
- **What makes this different**: If you can't answer, start over.
- **Weight as meaning**: How does 300→800 communicate something?

**"The catalog is vocabulary — you write the poem."** Don't fork demos. Invent.

## Setup

```bash
curl -o pretext.js https://raw.githubusercontent.com/somnai-dreams/pretext-demos/main/pretext.js
```

```html
<script type="module">
import { prepare, prepareWithSegments, layout, layoutWithLines, 
         layoutNextLine, walkLineRanges } from "./pretext.js";
</script>
```

## API (exact signatures — wrong = nothing renders)

| Function | Input | Output | Use for |
|----------|-------|--------|---------|
| `prepare(text, font)` | text, CSS font | opaque handle | height only |
| `prepareWithSegments(text, font)` | text, CSS font | handle + `.segments[]`, `.widths[]` | line access, char widths |
| `layout(prepared, maxWidth, lineHeight)` | handle, px, px | `{ lineCount, height }` | masonry, accordion |
| `layoutWithLines(prepared, maxWidth, lineHeight)` | handle, px, px | `{ lineCount, height, lines[] }` | columns, calligrams |
| `layoutNextLine(prepared, start, maxWidth)` | handle, cursor, px | `{ text, width, start, end }` or null | obstacle avoidance, gravity |
| `walkLineRanges(prepared, maxWidth, cb)` | handle, px, fn | lineCount | shrinkwrap, geometry |

- **Cursor**: `{ segmentIndex: 0, graphemeIndex: 0 }` initially. Pass `result.end` as next `start`.
- **Font**: must be named font, NOT `system-ui` (canvas/DOM resolve differently on macOS).
- **Cache**: `prepare()` is expensive (~19ms/500). `layout()` is cheap (~0.09ms). Cache handles.

## The Character Palette

Foundation for all visual/simulation techniques. Build once, reuse:

```javascript
import { prepareWithSegments } from "./pretext.js";

const CHARSET = ' .,:;!+-=*#@%&abcdefghijklmnopqrstuvwxyz0123456789';
const WEIGHTS = [300, 500, 800];
const STYLES = ['normal', 'italic'];

const palette = [];
for (const style of STYLES)
  for (const weight of WEIGHTS)
    for (const ch of CHARSET) {
      if (ch === ' ') continue;
      const font = `${style === 'italic' ? 'italic ' : ''}${weight} 14px Georgia, serif`;
      const p = prepareWithSegments(ch, font);
      palette.push({ char: ch, weight, style, font,
        width: p.widths[0] || 0, brightness: measureBrightness(ch, font) });
    }
palette.sort((a, b) => a.brightness - b.brightness);

function findBest(targetB, targetW) {
  // Binary search + width score — this is what makes proportional ASCII look organic
  let lo = 0, hi = palette.length - 1;
  while (lo < hi) { const m = (lo+hi)>>1; palette[m].brightness < targetB ? lo=m+1 : hi=m; }
  let best = palette[lo], bestS = Infinity;
  for (let i = Math.max(0,lo-15); i < Math.min(palette.length,lo+15); i++) {
    const s = Math.abs(palette[i].brightness-targetB)*2.5 + Math.abs(palette[i].width-targetW)/targetW;
    if (s < bestS) { bestS = s; best = palette[i]; }
  }
  return best;
}
```

## 14 Techniques

### SPECTACLE (full-screen immersive)
1. **Fluid Dynamics** → brightness field → proportional type (ref: `fluid-smoke.js`)
2. **3D Wireframe** → any mesh projected to weighted chars (ref: `wireframe-torus.js`)
3. **Particle Systems** → brightness field → char grid (ref: `variable-typographic-ascii.js`)

### EDITORIAL (content as interaction)
4. **Obstacle Avoidance Columns** → layoutNextLine + carveSlots (ref: `the-editorial-engine.js`)
5. **Hull Extraction Flow** → rasterize image → text flows around contour (ref: `dynamic-layout.ts`)
6. **Variable-Width Gravity** → layoutNextLine with per-line indent from cursor proximity

### PRECISION (impossible without pretext)
7. **Calligram** → SDF shape filled with measured chars (ref: `calligram-engine.js`)
8. **Shrinkwrap** → walkLineRanges finds exact minimum width (ref: `shrinkwrap-showdown.js`)
9. **Rich Inline Stream** → mixed fonts flowing together (ref: `rich-note.ts`)
10. **Pre-measured Animation** → layout for exact heights before transition

### NOVEL (nobody has built these)
11. **Weight Field Over Content** — readable text with weight varying by noise + proximity
12. **Force-Directed Type Graph** — network nodes as measured words with physics
13. **Text as Landscape** — characters form terrain, weight = elevation
14. **3D Extruded Type** — wireframe technique on extruded brand word

## Design Integration (from impeccable)

When building with pretext, ALSO apply these from impeccable:

### Typography (read: `reference/typography.md`)
- Use distinctive fonts — NOT Inter, Roboto, Open Sans
- Better choices: **Instrument Serif**, **Fraunces**, **Plus Jakarta Sans**, **Outfit**, **Newsreader**
- Modular type scale with fluid sizing (`clamp()`)
- Vertical rhythm: line-height as base unit for ALL spacing

### Color (read: `reference/color-and-contrast.md`)
- Use **OKLCH** not HSL — perceptually uniform
- Tint neutrals toward brand hue (even 0.01 chroma creates cohesion)
- Never pure black (#000) or pure white (#fff)
- 60-30-10 rule: 60% neutral, 30% secondary, 10% accent
- For pretext char grids, use `.a1` through `.a10` alpha classes

### Anti-Patterns (the AI slop test)
- ❌ Cyan-on-dark, purple-to-blue gradients (the AI color palette)
- ❌ Glassmorphism everywhere (blur, glass cards, glow borders)
- ❌ Gradient text for "impact"
- ❌ Cards inside cards
- ❌ Same spacing everywhere
- ❌ Dark mode with glowing accents as default
- ❌ Monospace typography as lazy "technical" shorthand
- ❌ Large icons with rounded corners above every heading

### Motion (read: `reference/motion-design.md`)
- Only animate `transform` and `opacity` (everything else = layout recalc)
- Use exponential easing: `cubic-bezier(0.16, 1, 0.3, 1)` for exits
- NO bounce or elastic — they feel dated
- Exit faster than entrance (75% of enter duration)
- Stagger cap: total stagger time < 500ms

## Compositional Techniques

### Layer Hierarchy
| Layer | Role | Weight | Opacity |
|-------|------|--------|---------|
| Background | Atmosphere | 300 | 0.05-0.15 |
| Content | Main idea | 400-600 | 0.3-0.7 |
| Accent | Highlights | 700-800 | 0.6-1.0 |

### Weight as Physics
- **Proximity** → heavier (gravity)
- **Density** → heavier (pressure)
- **Speed** → lighter (inertia)
- **Importance** → heavier (hierarchy)
- **Age** → heavier over time (maturation)

### Parameter Arcs
**Bad**: `weight = 500 + sin(t) * 200` — wobbles aimlessly
**Good**: `weight = 300 + progress * 500` — builds intentionally

## Quality Checklist

Before shipping:
- [ ] **Creative concept articulated** — mood, story, unique element in one sentence
- [ ] **One technique deep** — pushing one capability to its limit
- [ ] **Weight carries meaning** — 300→800 communicates something
- [ ] **Not a demo fork** — genuinely new combination or application
- [ ] **Looks good without interaction** — ambient state before user touches
- [ ] **Typography IS the design** — remove type effects, page would be empty
- [ ] **Impeccable typography** — fonts are distinctive, scale is modular, hierarchy is clear
- [ ] **Impeccable color** — OKLCH, tinted neutrals, no pure black/white, no AI palette
- [ ] **Impeccable motion** — exponential easing, no bounce, stagger capped, reduced-motion
- [ ] **AI slop test** — would someone say "AI made this"? If yes, redesign.
- [ ] **Performance** — hot path is pure arithmetic, zero DOM reads in render loop

## References

Pretext source: `.claude/skills/pretext/reference/` (7 demo implementations)
Impeccable design: `.claude/skills/impeccable/frontend-design/reference/` (7 reference docs)
Taste variants: `.claude/skills/taste-skill/` (soft, brutalist, minimalist, redesign)
Live demos: https://chenglou.me/pretext/ and https://somnai-dreams.github.io/pretext-demos/

## Learnings (auto-accumulated from usage)

### Performance
- Full charset (78 chars × 3 weights × 2 styles = 468 entries) takes 2-4 seconds to build palette
- For hero embeds, reduce to 62 chars × 2 weights × 1 style = 124 entries — **3.8x faster startup**
- `pretext.js` is 55KB — matters for hero sections. Consider lazy loading for below-fold content
- `estimateBrightness()` calls `getImageData()` per glyph — the main bottleneck

### Integration
- When embedding pretext in a page with overlay text, **disable the pretext overlay** — two overlapping text layers are always unreadable
- The `pointer-events: none` on iframe embeds prevents interaction — intentional for background use
- Scaffold and wireframe are best as **section breaks** between content, not as hero backgrounds (too busy for text overlay)

### Canvas Tips
- Always use `S/6` or `S/5.5` for grid spacing — **never hardcode pixel values** (breaks at different sizes)
- DPR scaling: set canvas.width = displaySize * DPR, then ctx.scale(DPR, DPR) — draw at logical pixels
- For breathing animation: `Math.sin(time * 0.6 + row * 0.5 + col * 0.7) * 0.08` is the sweet spot
