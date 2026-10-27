# Large videos ("Duże wideo")

Lists every video by real file size, largest first. Tap a row to watch it (`VideoPlayer`)
and hold-to-delete it; select candidates and compress them to HEVC 1080p.

## File size

`PhotoLibraryService.videoFileSize(of:)` reads `PHAssetResource`'s `fileSize` via KVC from
the `.fullSizeVideo` resource (edited) or `.video` (original). It's undocumented but has
been stable for years and needs no download. If it yields nothing, it falls back to
`duration × bitrate` (45 Mb/s for 4K, 17 Mb/s for 1080p, 8 Mb/s below).

`StatsStore` now uses the real size for videos instead of the pixel estimate. The video
screen records exact bytes: file size on delete, `before − after` on compression.

## Compression candidates

`VideoCompressor.isCandidate` excludes:
- slo-mo (`.videoHighFrameRate`) and cinematic (`.videoCinematic`). Re-encoding them
  flattens the variable-speed / depth edits.
- videos that are already small: < 20 Mb/s and long side ≤ 1920.
- anything in `DecisionStore.compressedVideos`. That holds our own outputs and originals that turned
  out "not worth it", so neither shows up again.

HDR / Dolby Vision videos are compressed too (HEVC presets keep HDR); verification rejects a copy
whose source had an HDR track (`.containsHDRVideo`) but whose output doesn't.

The estimated savings shown are `size − duration × 8 Mb/s`. That's a rough guess at the
output bitrate of `AVAssetExportPresetHEVC1920x1080`.

## Flow (`VideoFlow.runCompression`)

The videos are processed one at a time, with the idle timer disabled:

1. Free-space check first: `volumeAvailableCapacityForImportantUsage` must be at least
   2 × the largest selected video, which covers an iCloud download plus the output.
2. `requestAVAsset` (network allowed, `.current`, `.highQualityFormat`). Its
   `progressHandler` drives the "Pobieram z iCloud…" bar, and only fires when the file
   actually has to be downloaded.
3. Export to a temp `.mov` with metadata copied explicitly. The "Kompresuję…" bar polls
   `session.progress`.
4. Verification happens before anything is written to the library. The file must exist,
   be < 80% of the original (otherwise `notWorthIt`: the original is marked handled and
   skipped), match the original's duration within 0.5 s, and be `isPlayable`.
5. `PHAssetCreationRequest` (with `shouldMoveFile`) creates the copy. It carries over
   creationDate, location, isFavorite and isHidden, and adds the copy to every user album
   the original was in (where `canPerform(.addContent)`).
6. Any error skips to the next video.

All originals with a verified copy are deleted at the end in one
`PhotoLibraryService.delete` call, so there's one system prompt. Declining it leaves both
copies, so nothing is lost. "Przerwij po tym wideo" stops after the current video and still
goes to that prompt.

## Tradeoffs / to verify on device

- `fileSize` KVC is private API surface. If Apple removes the key, `value(forKey:)` would
  raise rather than return nil. Every shipping iOS still has it.
- `AVAssetExportSession.export()` is deprecated on iOS 18 in favour of `export(to:as:)`.
  It's kept because the deployment target is 17.
- Space is freed only after "Ostatnio usunięte" (Recently Deleted) is emptied. The screen
  says so.
