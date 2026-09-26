# Blur detection ("Wykryj rozmycie")

A second, independent cleanup tool alongside the ML delete flow. No training data, no
CoreML/Vision, no model — just a signal-processing heuristic run per photo.

## Algorithm

`BlurDetector.blurScore(for:)` (`App/Sources/Services/BlurDetector.swift`):

1. Draw the image into a fixed 256x256 grayscale `CGContext` (`analysisSide`). Downscaling
   first makes the raw variance scale roughly comparable across photos of any source
   resolution, and keeps the per-photo cost small and constant.
2. Convolve with the discrete Laplacian kernel `[[0,1,0],[1,-4,1],[0,1,0]]` via
   `vDSP_f3x3` (Accelerate). This is a standard second-derivative edge/high-frequency
   response: flat or smoothly-blurred regions respond near zero, sharp edges produce large
   positive/negative swings.
3. Take the variance of that response (`vDSP_meanv` / `vDSP_measqv`). This is the classic
   "variance of the Laplacian" sharpness measure — low variance means the image has few
   strong edges (blurry), high variance means lots of strong edges (sharp).

## Normalization

Raw Laplacian variance is unbounded and scene-dependent — a sharp photo of a plain wall
scores low, a slightly-soft photo of a busy scene can score high — so there is no universal
"variance > X = blurry" cutoff in absolute units, unlike a probability from a classifier.

To get something with the same shape as `ClassifiedAsset.confidence` (a thresholdable
0...1 "confidence of being blurry"), the variance is squashed with:

```
score = 1 / (1 + variance / varianceScale)
```

`varianceScale` (1500, at `analysisSide` 256) was picked empirically as roughly the
variance level that separated clearly-blurry from clearly-sharp photos in ad hoc testing.
It's a soft curve, not a hard cutoff — low variance pushes the score toward 1, high
variance pushes it toward 0, and the actual blurry/sharp split point is the user-tunable
`SettingsStore.blurThreshold` (default 50%, exposed as "Próg rozmycia" in Settings), not a
constant baked into the detector.

## Flow

`BlurFlow` (`App/Sources/Models/BlurFlow.swift`) mirrors `DeleteFlow`'s shape — batch
picking, progress, results, confirm-delete, done — without any training/model stage, since
there's nothing to train. It uses its own `BlurDecisionStore` (separate JSON file from the
ML flow's `AssetDecisionStore`) so a photo dismissed as "sharp" here doesn't disappear from
the ML delete flow's candidate pool, or vice versa — the two tools are independent.

`BlurReviewView` (`App/Sources/Views/BlurReviewView.swift`) is a small, deliberately
duplicated parallel of `ResultsView` (grid, tap-to-move, score bar) rather than a shared
component — this is a small app and the two flows' data types differ enough
(`ClassifiedAsset` vs `BlurredAsset`) that factoring out a generic version wasn't worth the
risk of touching `ResultsView`/`DeleteFlow` while other work is in flight on those files.

## Tradeoffs

- **Performance**: `PhotoLibraryService.requestImage` loads a full decoded image per asset,
  same constraint `ClassifierRunner` has — scoring is done in a fixed-size batch (picked via
  the same batch-size picker UI as the delete flow) rather than the whole library at once,
  and requests are sequential to keep memory bounded (see the `ponytail:` comment in
  `BlurFlow.runScoring`).
- **False positives on intentionally soft shots**: bokeh backgrounds, motion-blur art shots,
  and foggy/soft-focus photography will score high on this heuristic even though they're not
  "mistakes" — the heuristic has no notion of subject vs. background, so a shallow
  depth-of-field portrait with a sharp face and blurred background can score in between.
  This is why results are review-and-confirm (tap to move between tabs, plain
  confirmation dialog before delete) rather than an automatic silent delete.
- **False negatives on textureless sharp photos**: a genuinely sharp photo of a flat, low-
  detail subject (clear sky, blank wall) has little edge content and can score as blurry.
