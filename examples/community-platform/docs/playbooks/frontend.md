# Playbook: Frontend / Bubble Map

## Architecture

The entire frontend is **one file**: `website/index.html` (~1800 lines, all CSS and JS inline).

No component system, no build pipeline for the frontend. All changes require editing this monolith.

## Canvas Rendering

- Bubble physics: position lerping, alpha transitions
- Camera system: `camX/camY`, `targetCamX/targetCamY`, `detailLevel`
- Bubble state machine: layout targets, search alpha, fade states
- Rendering loop runs continuously via `requestAnimationFrame`

## URL Parameters

- `?thread={thread-id}` — Opens map centered on that thread's bubble
- This has been a recurring source of bugs — the interaction between bubble map initialization, camera positioning, and thread detail view is fragile

## Visual Testing

Use the **Ralph Wiggum technique** — iterative Puppeteer screenshot loop:
1. Take screenshot of live site
2. Review visually
3. Make change, push, wait for deploy
4. Screenshot again, compare

Tests use **live URL** (data is in S3/CloudFront), not a local server.

## Common Issues

- **Ghost bubbles on zoom out** — bubbles with `r < 1` stuck in dead zone
- **?thread= showing wrong view** — map-centered vs thread-only view confusion
- **Search feature** — keyboard-navigable, canvas dimming, dropdown results

## Design Rules

- Monochromatic dark palette (see `docs/reference/visual-design.md`)
- Serif fonts (Georgia) — intentional, do not change
- No accent colors, gradients, or decorative elements
- All animations respect `prefers-reduced-motion: reduce`
