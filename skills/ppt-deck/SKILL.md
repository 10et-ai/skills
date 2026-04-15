---
name: ppt-deck
description: Generate McKinsey-quality PowerPoint (.pptx) decks programmatically using pptxgenjs — real files you can email, present, and edit in Keynote/PowerPoint/Google Slides
disable-model-invocation: true
---

# McKinsey PowerPoint Generator

Generate consulting-grade `.pptx` files programmatically. Produces real PowerPoint files — not HTML, not PDF. Recipients can open, edit, and present natively.

**Dependency:** `pptxgenjs` (Node.js, zero-dependency beyond that)

```bash
npm list pptxgenjs 2>/dev/null || npm install pptxgenjs
```

**File extension:** Always use `.cjs` if the project has `"type": "module"` in `package.json`. pptxgenjs uses CommonJS.

## Phase 1: Scope the Deck

Ask the user:

1. **Audience** -- Who is this for? (Board, investors, engineering, customers, internal strategy)
2. **Objective** -- What decision or action should the audience take after seeing this?
3. **Content source** -- Do you have existing material (PRD, notes, data) or starting from scratch?
4. **Slide count** -- Single one-pager or multi-slide deck?
5. **Brand** -- Use project brand guidelines if available (`knowledge/BRAND_GUIDELINES.md`, `templates/brand/global.css`), or default to McKinsey navy palette

## Phase 2: Structure with McKinsey Pyramid Principle

Structure the deck following the Pyramid Principle:

1. **Situation** -- Context the audience already knows (1-2 slides)
2. **Complication** -- The tension, problem, or opportunity (1-2 slides)
3. **Resolution** -- Your answer/recommendation (1 slide, the "so what")
4. **Supporting arguments** -- 3-5 pillars supporting the resolution, each with evidence
5. **Next steps** -- Clear actions with owners and timeline

Slide count targets:
- Executive one-pager: 1 slide (dense, everything visible at once)
- Executive summary: 8-12 slides
- Strategy deck: 15-25 slides

### Consulting Slide Design Rules

Each slide MUST have:
- **Action title** -- A complete sentence that states the takeaway (not a topic label). "Revenue grew 40% YoY driven by enterprise expansion" not "Revenue Growth"
- **One idea per slide** -- If you need "and" in the title, split the slide
- **Evidence** -- Every claim backed by data, diagram, or example
- **Source line** -- Bottom-left, cite data sources

Visual hierarchy:
- Title (action statement) at top
- Single supporting visual or structured text in body
- Source/footnotes at bottom
- Page number bottom-right

## Phase 3: Build the Presentation

### Scaffold

```javascript
const pptxgen = require("pptxgenjs");
const path = require("path");

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9"; // 10" x 5.625"
pres.author = "Your Name";
pres.title = "Deck Title";
```

### Color Palette

Define palette constants at the top. Two built-in options:

**McKinsey Navy (default for external/board decks):**
```javascript
const NAVY = "1B2A4A";
const WHITE = "FFFFFF";
const OFF_WHITE = "F7F8FA";
const LIGHT_BG = "EEF1F5";
const ACCENT = "0B8A8A";
const GOLD = "C8973E";
const DARK_TEXT = "1E2530";
const MID_TEXT = "4A5568";
const LIGHT_TEXT = "8899AA";
const DIVIDER = "D1D5DB";
```

**TENET Brand (for internal/product decks):**
```javascript
const DARK = "08080C";
const SURFACE = "111111";
const BONE = "FBFBFA";
const FOREST = "346538";
const FOREST_LIGHT = "4A9068";
const FOREST_DARK = "2D5A45";
const GOLD = "C8A050";
const TEXT_PRIMARY = "F5F5F5";
const TEXT_MUTED = "787774";
const RULE = "E5E4E1";
```

If the project has brand guidelines, extract the palette from those instead.

### Slide Patterns

#### Top Bar (branding strip)
```javascript
const s = pres.addSlide();
s.background = { color: WHITE };

s.addShape(pres.shapes.RECTANGLE, {
  x: 0, y: 0, w: 10, h: 0.65,
  fill: { color: NAVY }
});

s.addText("BRAND", {
  x: 0.5, y: 0.1, w: 3, h: 0.45,
  fontSize: 22, fontFace: "Arial", bold: true,
  color: WHITE, margin: 0
});

s.addText("Company  |  Date  |  Confidential", {
  x: 5.5, y: 0.1, w: 4.2, h: 0.45,
  fontSize: 9, fontFace: "Arial",
  color: "7A8DB0", align: "right", margin: 0
});
```

#### Action Title (the "so what")
```javascript
s.addText(
  "Complete sentence that states the key takeaway for this slide",
  {
    x: 0.5, y: 0.85, w: 9.0, h: 0.65,
    fontSize: 14, fontFace: "Arial", bold: true,
    color: NAVY, margin: 0, lineSpacingMultiple: 1.25
  }
);
```

#### Section Label (uppercase, tracked)
```javascript
s.addText("SECTION NAME", {
  x: 0.5, y: 1.8, w: 2.5, h: 0.28,
  fontSize: 9, fontFace: "Arial", bold: true,
  color: ACCENT, margin: 0, charSpacing: 2
});
```

#### Body Text (situation/context)
```javascript
s.addText([
  { text: "Bold lead-in. ", options: { bold: true } },
  { text: "Supporting detail that builds on the lead-in statement." },
], {
  x: 0.5, y: 2.1, w: 4.5, h: 0.7,
  fontSize: 10.5, fontFace: "Arial",
  color: DARK_TEXT, margin: 0, lineSpacingMultiple: 1.35, valign: "top"
});
```

#### Numbered Steps (1-2-3 pattern)
```javascript
const steps = [
  { num: "1", title: "Step One", desc: "What this step does", color: "E6F2F2" },
  { num: "2", title: "Step Two", desc: "What this step does", color: "EBF0F7" },
  { num: "3", title: "Step Three", desc: "What this step does", color: "F2EDE6" },
];

steps.forEach((step, i) => {
  const y = 3.3 + i * 0.65;

  s.addShape(pres.shapes.OVAL, {
    x: 0.5, y: y + 0.05, w: 0.3, h: 0.3,
    fill: { color: NAVY }
  });
  s.addText(step.num, {
    x: 0.5, y: y + 0.05, w: 0.3, h: 0.3,
    fontSize: 11, fontFace: "Arial", bold: true,
    color: WHITE, align: "center", valign: "middle", margin: 0
  });

  s.addText(step.title, {
    x: 0.92, y: y, w: 1.2, h: 0.22,
    fontSize: 11, fontFace: "Arial", bold: true,
    color: NAVY, margin: 0
  });
  s.addText(step.desc, {
    x: 0.92, y: y + 0.22, w: 4.0, h: 0.35,
    fontSize: 9, fontFace: "Arial",
    color: MID_TEXT, margin: 0, lineSpacingMultiple: 1.2
  });
});
```

#### Big Metric Cards (proof points)
```javascript
const metrics = [
  { num: "18x", label: "faster improvement", sub: "vs. baseline" },
  { num: "68%", label: "reach target", sub: "avg. 2.3 iterations" },
  { num: "$0.06", label: "per cycle", sub: "at production scale" },
];

metrics.forEach((m, i) => {
  const mx = 5.5 + i * 1.35;

  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: mx, y: 2.2, w: 1.25, h: 1.15,
    fill: { color: OFF_WHITE },
    rectRadius: 0.06
  });

  s.addText(m.num, {
    x: mx, y: 2.28, w: 1.25, h: 0.42,
    fontSize: 24, fontFace: "Arial", bold: true,
    color: NAVY, align: "center", margin: 0
  });

  s.addText(m.label, {
    x: mx + 0.06, y: 2.72, w: 1.13, h: 0.28,
    fontSize: 8.5, fontFace: "Arial", bold: true,
    color: ACCENT, align: "center", margin: 0
  });

  s.addText(m.sub, {
    x: mx + 0.06, y: 3.02, w: 1.13, h: 0.28,
    fontSize: 7.5, fontFace: "Arial",
    color: LIGHT_TEXT, align: "center", margin: 0
  });
});
```

#### Horizontal Tier Flow (knowledge network, value chain)
```javascript
const tiers = [
  { label: "Tier 1", desc: "Description\nof this tier" },
  { label: "Tier 2", desc: "Description\nof this tier" },
  { label: "Tier 3", desc: "Description\nof this tier" },
];

const tierW = 1.2;
tiers.forEach((t, i) => {
  const tx = 5.5 + i * (tierW + 0.24);

  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: tx, y: 3.9, w: tierW, h: 0.7,
    fill: { color: i === 2 ? NAVY : (i === 1 ? "3D5A80" : LIGHT_BG) },
    rectRadius: 0.05
  });

  s.addText(t.label, {
    x: tx, y: 3.96, w: tierW, h: 0.22,
    fontSize: 9.5, fontFace: "Arial", bold: true,
    color: i === 0 ? NAVY : WHITE, align: "center", margin: 0
  });

  s.addText(t.desc, {
    x: tx + 0.05, y: 4.2, w: tierW - 0.1, h: 0.35,
    fontSize: 7.5, fontFace: "Arial",
    color: i === 0 ? MID_TEXT : "B0C0D5", align: "center", margin: 0
  });

  if (i < 2) {
    s.addText("\u2192", {
      x: tx + tierW + 0.01, y: 4.08, w: 0.22, h: 0.25,
      fontSize: 14, fontFace: "Arial", bold: true,
      color: ACCENT, align: "center", margin: 0
    });
  }
});
```

#### Vertical Divider (two-column layout)
```javascript
s.addShape(pres.shapes.LINE, {
  x: 5.25, y: 1.8, w: 0, h: 3.2,
  line: { color: DIVIDER, width: 0.75 }
});
```

#### Bottom Bar (domain-agnostic footer)
```javascript
s.addShape(pres.shapes.RECTANGLE, {
  x: 0, y: 5.15, w: 10, h: 0.48,
  fill: { color: NAVY }
});

s.addText("Footer message here", {
  x: 0.5, y: 5.2, w: 9.0, h: 0.35,
  fontSize: 9, fontFace: "Arial",
  color: "7A8DB0", align: "center", margin: 0
});
```

### Embedding Images / SVGs

pptxgenjs supports image embedding. For D2 diagrams rendered to SVG, convert to PNG first:

```bash
d2 --theme 200 diagram.d2 diagram.png
```

Then embed:
```javascript
s.addImage({
  path: path.join(__dirname, "diagram.png"),
  x: 1.0, y: 1.5, w: 8.0, h: 3.5
});
```

## Phase 4: Write the File

```javascript
const outPath = path.join(__dirname, "Deck-Name.pptx");
pres.writeFile({ fileName: outPath }).then(() => {
  console.log("Created: " + outPath);
});
```

Run with:
```bash
node deck.cjs
```

## Phase 5: Polish Checklist

Before delivery:
- [ ] Every slide has an action title (complete sentence, not a topic label)
- [ ] No orphan slides (each connects to the narrative arc)
- [ ] Color palette is consistent -- use palette constants, never inline hex
- [ ] Data sources cited on every evidence slide
- [ ] Font sizes: titles 14pt, body 10-11pt, labels 9pt, sub-text 7.5-8pt
- [ ] Spacing: nothing touching edges, minimum 0.5" margins
- [ ] Text is in exec/business language, not technical or academic
- [ ] File opens cleanly in PowerPoint, Keynote, and Google Slides

Open when done:
```bash
open Deck-Name.pptx
```

## Quick Examples

### Executive One-Pager
"Build a single-slide McKinsey one-pager explaining our product. Audience: VP-level. Include three proof points and a value chain diagram."

### Board Deck
"Create an 8-slide board update. Revenue up 40%, 3 new customers, expanding APAC. Use the navy palette."

### Internal Strategy
"Generate a strategy deck for Nishant on TENET architecture. Use our brand guidelines. Include security & governance slide."

## Typography Rules

| Element | Size | Weight | Face |
|---------|------|--------|------|
| Brand mark | 22pt | Bold | Arial |
| Action title | 14pt | Bold | Arial |
| Section label | 9pt | Bold, charSpacing: 2 | Arial |
| Body text | 10-11pt | Regular | Arial |
| Card numbers | 24pt | Bold | Arial |
| Card labels | 8.5pt | Bold | Arial |
| Sub-labels | 7.5pt | Regular | Arial |
| Footer | 9pt | Regular | Arial |
| Confidential line | 9pt | Regular | Arial |

## Spacing Rules

| Element | Value |
|---------|-------|
| Page margins | 0.5" all sides |
| Top bar height | 0.65" |
| Bottom bar height | 0.48" |
| Card gap | 0.1" |
| Section gap | 0.15" |
| Line spacing (body) | 1.35x |
| Line spacing (cards) | 1.15x |
| lineSpacingMultiple (sub) | 1.1x |
