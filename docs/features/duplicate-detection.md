# Duplicate detection ("Usuń duplikaty")

Finds near-duplicate photo clusters (typically burst shots) and lets the user review each
group as a single gallery, deciding which of its photos to keep. The tool opens on its intro
screen (`ToolIntroView`); the scan only starts when the user taps "Rozpocznij skanowanie".

## Files

- `App/Sources/Services/DuplicateDetector.swift` — hashing + clustering
- `App/Sources/Services/DuplicateDecisionStore.swift` — "already reviewed" persistence, own namespace
- `App/Sources/Models/DuplicateReviewFlow.swift` — stage machine driving the review
- `App/Sources/Views/DuplicateReviewView.swift` — top-level stage switch (mirrors `DeleteView`)
- `App/Sources/Views/DuplicateGroupView.swift` — one group's gallery + confirm

## Algorithm

**Hashing:** dHash (difference hash), not pHash — simpler to get right with plain Core Graphics
(no DCT), and accurate enough for near-identical burst frames:

1. Fetch a small (32x32) thumbnail per asset via `PhotoLibraryService.requestImage`.
2. Draw it into a 9x8 grayscale `CGContext` (no color, cheap).
3. For each of the 8 rows, compare each of the 8 adjacent horizontal pixel pairs
   (9 pixels → 8 comparisons): bit = 1 if left pixel is brighter than right.
4. That's a 64-bit fingerprint, robust to small compression/exposure differences between
   burst frames (unlike a plain checksum of pixel bytes).

Similarity = Hamming distance between two 64-bit hashes (`(a ^ b).nonzeroBitCount`).

**Clustering:** a single pass over assets sorted by `creationDate` ascending. A photo joins the
current open group if it is both:
- within `hammingThreshold` (10 bits, of 64) of the *previous* photo's hash, and
- within `timeWindow` (120s) of the *previous* photo's `creationDate`.

Otherwise the current group closes (kept only if it has 2+ members) and a new one starts.
Chaining against the *previous* asset only (not the group's first) is O(n) rather than O(n²)
and matches how bursts actually look (a smooth sequence of near-identical neighbors) — it can
occasionally chain two visually-drifting-but-related frames together where the true keeper
looks quite different from the group's first frame; not corrected for, see below.

Photos whose thumbnail failed to load are skipped (hash `nil` closes the current group, so a
transient load failure doesn't silently merge two unrelated clusters).

**Why time + hash, not hash alone:** comparing every asset's hash to every other asset's hash is
O(n²) and would flag visually-similar-but-unrelated photos (e.g. two plain blue skies taken a
year apart) as "duplicates". Requiring temporal proximity restricts comparisons to a single
linear pass and matches what a "duplicate" actually is in this app's context: burst shots.

**Scan scope:** capped at `DuplicateDetector.maxScanCount` (4000, newest-first) per run — full
thumbnail loads aren't free, and burst duplicates are rare far back in a huge library relative
to the cost of scanning it all up front. Assets already resolved by a previous run are excluded
via `DuplicateDecisionStore` (its own JSON file, separate from `AssetDecisionStore` used by the
ML delete flow, so the two flows can't interfere with each other's state).

## Which photo defaults to "keep"

Largest pixel dimensions (`asset.pixelWidth * asset.pixelHeight`), ties broken by newest
`creationDate`. Chosen over "sharpest" or "first in burst" because `PHAsset` exposes resolution
directly — no image decode needed — and resolution is a reasonable proxy for "least likely to be
a downsized/re-encoded duplicate" without the cost of a real sharpness heuristic (e.g. Laplacian
variance) over every asset in every group.

The rest of the group starts unmarked ("delete"), but nothing is forced: any number of assets
can be marked "keep", from all of them (the confirm button then just moves on, deleting nothing)
to none of them (the whole group is deleted, behind the same hold-to-confirm button as any other
deletion).

## Known tradeoffs / limitations

- **dHash can conflate different-but-similar-composition photos.** Two distinct but very
  similarly framed shots (e.g. same subject standing still, seconds apart on purpose) can land
  in the same group. This is an accepted false positive — the group review UI lets the user
  correct it by marking more than one photo "keep" — not something the hash tries to avoid.
- **Single-pass "compare to previous only" clustering** — a slow visual drift across a long
  burst could span two "hops", each under the threshold, that together move well past it,
  without technically re-triggering a false merge (this only under- rather than over-merges,
  i.e. it may split one real burst into two groups — safer failure mode than a bad merge).
- **Large bursts (10-20+ photos)** are handled by the group view's adaptive `LazyVGrid`, not a
  fixed layout, but there's no explicit UI limit — an unusually large burst (50+) is still shown
  in one scrollable grid.
- **Performance on big libraries:** hashing is sequential (one thumbnail request at a time) and
  capped at `maxScanCount`; scanning 4000 assets takes noticeably longer than the ML classify
  flow's batches. Not parallelized — ponytail: acceptable for a manual, user-triggered scan;
  revisit with a concurrent `TaskGroup` if scan time becomes annoying in practice.
- **No tunable threshold in Settings** — `hammingThreshold` and `timeWindow` are hardcoded
  constants in `DuplicateDetector.swift` with comments explaining the choice, per the "nice to
  have, not core ask" guidance; wiring one into `SettingsStore` (like `uncertaintyThreshold`) is
  a small, additive follow-up if false positives/negatives turn out to matter in practice.
