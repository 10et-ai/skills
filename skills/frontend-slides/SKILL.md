---
name: frontend-slides
description: Generate HTML/CSS slide decks — data-driven visual arguments, not text walls
disable-model-invocation: true
---

# Frontend Slides

Create presentation decks as pure HTML/CSS. Each slide is a visual argument — the data IS the content, text is annotation. Output renders in any browser, screenshots to PDF, or embeds in React.

## When to Use

- Executive strategy decks
- Product demos and walkthroughs
- Data presentations (metrics, comparisons, timelines)
- Investor/board updates
- Internal team briefs

## Output Format

A single `slides.html` file (or React component) with:
- 16:9 aspect ratio per slide (1280×720 viewport)
- Self-contained CSS (no external dependencies)
- Print-friendly (each slide is a page break)
- Dark and light theme support via CSS custom properties

## Process

### Phase 0: Data Extraction

Before designing anything, extract ALL quantitative data from the context:
1. Read all provided materials, briefs, and context
2. List every number, percentage, comparison, ratio, trend
3. Identify the audience and what data would make THEM act
4. Select 3-5 killer data points that pass the billboard test:
   - Would this work on a billboard with no context?
   - Would the presenter cite THIS number with only 10 seconds?
   - Would the audience remember it tomorrow?

**Gate**: Numbered list of data points. If you don't have data, ask for it — don't make text slides.

### Phase 1: Visual Argument Design

For each data point, pick the visual pattern that makes the argument without words:

**Proportional Comparison** — when two numbers have dramatic contrast:
```html
<div class="slide">
  <h2>Headline stating the argument</h2>
  <div style="display:flex; flex-direction:column; gap:24px;">
    <div>
      <span style="font-size:88px; font-weight:900; line-height:1;">74%</span>
      <span style="font-size:24px; font-weight:700;">Label</span>
      <div style="width:74%; height:16px; background:var(--accent); border-radius:8px;"></div>
    </div>
    <div>
      <span style="font-size:88px; font-weight:900; line-height:1; opacity:0.4;">8%</span>
      <span style="font-size:24px; font-weight:700;">Label</span>
      <div style="width:8%; height:16px; background:var(--muted); border-radius:8px;"></div>
    </div>
  </div>
</div>
```

**Stat Grid** — 3-4 supporting numbers that together tell a story:
```html
<div class="slide">
  <h2>Headline</h2>
  <div style="display:grid; grid-template-columns:repeat(3,1fr); gap:20px;">
    <div style="background:var(--card); border-radius:12px; padding:24px; text-align:center;">
      <div style="font-size:48px; font-weight:900; color:var(--accent);">NUMBER</div>
      <div style="font-size:16px; font-weight:700; margin-top:8px;">LABEL</div>
    </div>
  </div>
</div>
```

**Two-Panel Contrast** — us vs them, before/after, problem/solution:
```html
<div class="slide">
  <h2>Headline</h2>
  <div style="display:grid; grid-template-columns:1fr 1fr; gap:24px;">
    <div style="background:var(--card); border-radius:12px; padding:24px;">
      <!-- Light panel -->
    </div>
    <div style="background:var(--dark); border-radius:12px; padding:24px; color:#fff;">
      <!-- Dark panel -->
    </div>
  </div>
</div>
```

**Stage Progression** — timeline, evolution, funnel:
```html
<div class="slide">
  <h2>Headline</h2>
  <div style="display:flex; gap:0; align-items:stretch;">
    <div style="flex:1; background:var(--card); padding:22px; border-radius:12px 0 0 12px;">
      <!-- Stage 1 -->
    </div>
    <div style="display:flex; align-items:center; padding:0 8px;">→</div>
    <div style="flex:1; background:var(--dark); padding:22px; border-radius:0 12px 12px 0; color:#fff;">
      <!-- Final stage -->
    </div>
  </div>
</div>
```

### Phase 2: Minimal Text

For each slide write:
1. **Headline** (max 8 words): The argument the visual proves. A statement, not a label.
2. **Annotations** (max 2 per data point): One-line context for interpretation.
3. Total text per slide: ≤30 words (excluding headline).

Text style:
- No AI-speak (banned: leverage, optimize, ecosystem, holistic, innovative, cutting-edge, paradigm)
- Conversational — the presenter could say this headline as a sentence
- Specific: "Stripe is cited 9x more" not "competitive gap exists"
- Present tense, active voice

### Phase 3: Assemble

```html
<!DOCTYPE html>
<html>
<head>
<style>
  :root {
    --bg: #ffffff; --fg: #1a1a1a; --accent: #1434CB;
    --card: #f5f5f5; --dark: #0E2841; --muted: #999;
  }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #0a0a0a; --fg: #f0f0f0; --card: #1a1a1a; --muted: #666; }
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, system-ui, sans-serif; background: var(--bg); color: var(--fg); }
  .slide {
    width: 1280px; min-height: 720px; padding: 60px 80px;
    page-break-after: always; position: relative;
  }
  .slide h2 { font-size: 36px; font-weight: 800; margin-bottom: 40px; line-height: 1.2; }
  .slide-number { position: absolute; bottom: 30px; right: 40px; font-size: 14px; color: var(--muted); }
  @media print { .slide { break-after: page; } }
</style>
</head>
<body>

<div class="slide">
  <!-- Cover -->
  <div style="display:flex; flex-direction:column; justify-content:center; height:100%;">
    <h1 style="font-size:56px; font-weight:900; line-height:1.1;">Title</h1>
    <p style="font-size:24px; margin-top:16px; color:var(--muted);">Subtitle | Date</p>
  </div>
</div>

<!-- Content slides here -->

</body>
</html>
```

### Phase 4: Verify

- [ ] Can you understand each slide from 6 feet away?
- [ ] Is the visual the FIRST thing you notice? (not text)
- [ ] Are numbers the largest elements (48px min, 88px for primary)?
- [ ] Total text per slide ≤30 words?
- [ ] Zero AI-speak?
- [ ] All text ≥16px?
- [ ] Renders correctly at 1280×720?

## Anti-patterns

1. **Bullet point slides**: If a slide is just a list, it doesn't belong in this deck. Find the data or cut the slide.
2. **Text-primary slides**: If text is the main content, this skill isn't being followed.
3. **Equal-sized comparisons**: 74% bar should be visually 9x wider than 8% bar. The visual IS the argument.
4. **Decoration**: Icons or graphics that don't carry data are clutter. Remove them.
5. **Missing data**: Don't generate slides without data. Ask for metrics first.

## Customization

Override theme by setting CSS custom properties:
```css
:root {
  --accent: #635BFF;  /* Stripe purple */
  --dark: #1a1a2e;
  --card: #f8f8fc;
}
```

Brand fonts via `font-family` on body. Brand colors via custom properties. Layout patterns stay the same — they're designed around data legibility, not branding.
