---
name: web-builder
description: Build websites with brand consistency. Orchestrates tailwind-v4, react-best-practices, r3f-best-practices, and web-architect to create cohesive web experiences that match your brand guidelines.
license: MIT
metadata:
  author: jfl
  version: "1.0.0"
---

# Web Builder

Build websites that are fast, accessible, and perfectly aligned with your brand. This skill orchestrates all web-related skills and ensures consistency.

## When to Use

- Starting a new website or landing page
- Building React/Next.js components
- Creating 3D web experiences
- Ensuring brand consistency across pages
- Auditing existing code against best practices

## Required Context

Before building, this skill loads:

1. **Brand Decisions** - `knowledge/BRAND_DECISIONS.md` (what was chosen: colors, fonts, mark)
2. **Brand Guidelines** - `knowledge/BRAND_GUIDELINES.md` (how to use it: spacing, do's/don'ts, accessibility)
3. **Brand Brief** - `knowledge/BRAND_BRIEF.md` (inputs, if exists)
4. **Product Spec** - `product/SPEC.md` (if exists)

If brand docs don't exist yet, run `/brand-architect` first to create them.
Template available at `templates/brand/BRAND_GUIDELINES.md`.

## Commands

```
/web-builder                    # Show status and what's configured
/web-builder start [type]       # Start new project (landing, app, 3d)
/web-builder component [name]   # Create brand-consistent component
/web-builder page [name]        # Create new page with layout
/web-builder audit              # Audit code against all best practices
/web-builder fix                # Auto-fix common issues
```

## Workflow

### Step 1: Load Brand Context

```bash
# Read brand decisions
cat knowledge/BRAND_DECISIONS.md

# Check for additional context
cat knowledge/BRAND_BRIEF.md 2>/dev/null
cat product/SPEC.md 2>/dev/null
```

Extract and store:
- **Colors**: Primary, secondary, accent, neutrals
- **Typography**: Font families, sizes, weights
- **Spacing**: Scale and patterns
- **Voice**: Tone for microcopy

### Step 2: Select Tech Stack

Based on project type:

| Type | Stack |
|------|-------|
| **landing** | Next.js + Tailwind v4 + Framer Motion |
| **app** | Next.js + Tailwind v4 + React patterns |
| **3d** | Next.js + R3F + Drei + Tailwind v4 |

### Step 3: Apply Best Practices

Load relevant skills based on stack:

```
ALWAYS:
- /tailwind-v4          # CSS-first configuration
- /react-best-practices # Performance patterns

IF 3D:
- /r3f-best-practices   # R3F optimization

AFTER BUILD:
- /rams                 # Accessibility review
- /web-architect audit  # Asset completeness
```

### Step 4: Generate Code

All generated code MUST:

1. **Use brand tokens** from @theme
2. **Follow React patterns** from best practices
3. **Be accessible** (WCAG 2.1 AA minimum)
4. **Be performant** (no re-render issues)

---

## Project Setup

### Landing Page

```bash
# Create Next.js project
npx create-next-app@latest [name] --typescript --tailwind --app

# Install dependencies
npm install framer-motion
```

Then configure Tailwind v4 with brand tokens:

```css
/* app/globals.css */
@import "tailwindcss";

@theme {
  /* From BRAND_DECISIONS.md */
  --color-primary: {primary_color};
  --color-secondary: {secondary_color};
  --color-accent: {accent_color};

  --color-background: {background};
  --color-foreground: {foreground};
  --color-muted: {muted};

  --font-sans: "{font_family}", system-ui, sans-serif;
  --font-mono: "{mono_font}", monospace;

  --radius-default: {border_radius};
}
```

### 3D Experience

```bash
npx create-next-app@latest [name] --typescript --tailwind --app

npm install three @react-three/fiber @react-three/drei @react-three/postprocessing
npm install zustand leva  # State & debugging
```

---

## Component Patterns

### Brand-Aware Button

```tsx
// components/ui/button.tsx
import { cn } from '@/lib/utils'
import { forwardRef } from 'react'

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'primary', size = 'md', ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          // Base styles
          'inline-flex items-center justify-center font-medium transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
          'disabled:pointer-events-none disabled:opacity-50',

          // Variants (using brand tokens)
          {
            'bg-primary text-primary-foreground hover:bg-primary/90': variant === 'primary',
            'bg-secondary text-secondary-foreground hover:bg-secondary/90': variant === 'secondary',
            'hover:bg-accent hover:text-accent-foreground': variant === 'ghost',
          },

          // Sizes
          {
            'h-8 px-3 text-sm rounded-md': size === 'sm',
            'h-10 px-4 text-base rounded-md': size === 'md',
            'h-12 px-6 text-lg rounded-lg': size === 'lg',
          },

          className
        )}
        {...props}
      />
    )
  }
)
Button.displayName = 'Button'
```

### Brand-Aware Card

```tsx
// components/ui/card.tsx
export function Card({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={cn(
      'rounded-default bg-background border border-muted/20 p-6 shadow-sm',
      className
    )}>
      {children}
    </div>
  )
}
```

### 3D Scene with Brand Colors

```tsx
// components/scene/hero-scene.tsx
'use client'

import { Canvas } from '@react-three/fiber'
import { Environment, Float } from '@react-three/drei'
import { Suspense, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import type { Mesh } from 'three'

function BrandedMesh() {
  const meshRef = useRef<Mesh>(null)

  // Use brand color from CSS variable
  // Note: You'd extract this at build time or pass as prop
  const brandColor = '#3b82f6' // From BRAND_DECISIONS

  useFrame((_, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += delta * 0.5
    }
  })

  return (
    <Float speed={2} rotationIntensity={0.5}>
      <mesh ref={meshRef}>
        <torusKnotGeometry args={[1, 0.3, 128, 32]} />
        <meshStandardMaterial color={brandColor} metalness={0.8} roughness={0.2} />
      </mesh>
    </Float>
  )
}

export function HeroScene() {
  return (
    <div className="h-[60vh] w-full">
      <Canvas camera={{ position: [0, 0, 5] }}>
        <Suspense fallback={null}>
          <ambientLight intensity={0.5} />
          <spotLight position={[10, 10, 10]} angle={0.15} penumbra={1} />
          <BrandedMesh />
          <Environment preset="city" />
        </Suspense>
      </Canvas>
    </div>
  )
}
```

---

## Audit Checklist

When running `/web-builder audit`:

### Brand Consistency
- [ ] Colors match BRAND_DECISIONS.md
- [ ] Typography matches brand fonts
- [ ] Spacing uses consistent scale
- [ ] Tone matches brand voice

### Performance (from react-best-practices)
- [ ] No setState in useFrame (R3F)
- [ ] Zustand selectors used (not full store)
- [ ] Images optimized (next/image)
- [ ] Bundle size checked
- [ ] No waterfall fetches

### Accessibility (WCAG 2.1 AA)
- [ ] Color contrast ratios pass
- [ ] Focus states visible
- [ ] ARIA labels present
- [ ] Keyboard navigation works
- [ ] Screen reader tested

### Tailwind v4
- [ ] Using @theme for tokens
- [ ] No tailwind.config.js (unless legacy)
- [ ] Container queries where appropriate

### Assets (from web-architect)
- [ ] Favicons generated
- [ ] OG images created
- [ ] Social banners ready

---

## Integration with Other Skills

This skill automatically invokes:

| Skill | When |
|-------|------|
| `/tailwind-v4` | Always (CSS setup) |
| `/react-best-practices` | Always (React code) |
| `/r3f-best-practices` | When 3D components detected |
| `/web-architect` | Asset generation |
| `/rams` | Accessibility review |
| `/brand-architect` | If brand not defined |

---

## Common Patterns

### Page Layout

```tsx
// app/layout.tsx
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' })

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="bg-background text-foreground antialiased">
        {children}
      </body>
    </html>
  )
}
```

### Landing Page Structure

```tsx
// app/page.tsx
import { HeroSection } from '@/components/sections/hero'
import { FeaturesSection } from '@/components/sections/features'
import { CTASection } from '@/components/sections/cta'
import { Footer } from '@/components/layout/footer'

export default function HomePage() {
  return (
    <main>
      <HeroSection />
      <FeaturesSection />
      <CTASection />
      <Footer />
    </main>
  )
}
```

### Animation with Framer Motion

```tsx
'use client'

import { motion } from 'framer-motion'

export function FadeIn({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      {children}
    </motion.div>
  )
}
```

---

## Quick Reference

### Brand Token Mapping

| BRAND_DECISIONS | Tailwind @theme |
|-----------------|-----------------|
| Primary color | `--color-primary` |
| Secondary color | `--color-secondary` |
| Accent color | `--color-accent` |
| Background | `--color-background` |
| Text color | `--color-foreground` |
| Muted color | `--color-muted` |
| Font family | `--font-sans` |
| Mono font | `--font-mono` |
| Border radius | `--radius-default` |

### Class Naming

Use semantic names that reference brand tokens:

```html
<!-- Good: Uses brand tokens -->
<div class="bg-primary text-primary-foreground">

<!-- Avoid: Raw colors -->
<div class="bg-blue-500 text-white">
```
