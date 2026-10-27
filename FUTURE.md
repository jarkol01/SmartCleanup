# Future features

## Core (smart cleaning)
- Screenshot-specific classifier or heuristic
- Video support in the same swipe/review flow, sorted by file size
- Propagate a delete decision across a detected duplicate cluster
- Size-first sort — surface largest photos/videos first
- Undo/trash review before permanent delete

## Quality of life
- iCloud storage indicator ("you'll free up X GB")
- Home screen widget (storage freed / streak) — needs an App Group so StatsStore moves to shared UserDefaults
- Reminder notifications ("100 new photos since last cleanup") — a local notification scheduled when the app goes to background, no BGTask needed
- Export/import training data or model
- Album/date-range scoping

## Done
Duplicates, blur detection, haptics, long-press preview, large videos + compression, storage bar — see `docs/features/`.
