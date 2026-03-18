# Reference: Visual Design

## Palette (Monochromatic Dark)

| Element | Color |
|---------|-------|
| Background | `#09090b` (Zinc 950) |
| Heading | `#e4e4e7` |
| Body text | `#d4d4d8` |
| Description | `#a1a1aa` |
| Tagline | `#71717a` |
| Muted labels | `#52525b` |
| Dividers | `#27272a` |

No accent colors. Luminance alone creates hierarchy.

## Typography

Serif font stack (Georgia). This is intentional — do not switch to sans-serif.

## Animations

- **Bubble lerp**: Position/size/opacity interpolate smoothly (`LERP_SPEED = 0.1`)
- **Breathe + shimmer**: Subtle radius oscillation + traveling perimeter highlight
- **Morph open/close**: Bubble → full-width detail header (`.5s cubic-bezier`), reverses on back
- **Onboarding fade-in**: Blur-to-clear on instruction overlay
- All respect `prefers-reduced-motion: reduce`

## Anti-Convention Choices (INTENTIONAL)

These look like mistakes to outsiders but are deliberate:
- Serif fonts (not sans-serif)
- No color (monochromatic)
- Plain text email (not HTML)
- No buttons (mailto: links)
- No tracking
- No exclamation marks

See `PROJECT_SPEC.md` sections: "The Anti-Convention Identity", "Design Is Not", "Design Reflects Values"

## Voice & Tone

Short, declarative, no hype. "Growing collective thought." — not "We're building an exciting platform!"

Em dashes over parentheses. Write like a thoughtful person, not a marketing team.
