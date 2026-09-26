# Future features

## Core (smart cleaning)
- Duplicate/near-duplicate detection (perceptual hash) — group view, pick keeper(s) per group
- Blur detection — separate screen, same keep/delete/uncertain review flow as the ML classifier, no training
- Screenshot-specific classifier or heuristic
- Video support in the same swipe/review flow, sorted by file size
- Propagate a delete decision across a detected duplicate cluster
- Size-first sort — surface largest photos/videos first
- Undo/trash review before permanent delete

## Quality of life
- Haptic feedback across swipe/tap/delete interactions, including a press-and-hold "confirm delete" gesture
- iCloud storage indicator ("you'll free up X GB")
- Home screen widget (storage freed / streak)
- Reminder notifications ("100 new photos since last cleanup")
- Export/import training data or model
- Album/date-range scoping
- Long-press photo preview (peek at full size) — **in progress, see below**

## In progress (parallel agents, separate worktrees)
1. **Haptics** — research + implement good haptic feedback (swipe, taps, press-and-hold delete confirm with progressive visual fill).
2. **Blur detection** — new home screen entry point, Laplacian-variance-style blur scoring, keep/delete/uncertain review like the ML flow but no training involved.
3. **Duplicate detection & review** — perceptual-hash clustering, one-group-at-a-time review UI, checkmark-based keep/discard selection.
4. **Long-press photo preview** — full-size zoomable preview on long-press, in Results/Uncertain review grids.

Each agent leaves a short doc under `docs/features/` describing what it built and any decisions/tradeoffs.
