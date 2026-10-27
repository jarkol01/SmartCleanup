# Widgets

## Research (short)

- A widget is glanceable, not a mini app: one idea per size, the most important number
  biggest, and every tap lands somewhere useful (`widgetURL` for small, `Link` per target
  on medium and up). Destructive actions stay in the app.
- Reload budget: WidgetKit spreads a dynamic daily budget of reloads. Reloads requested
  while the app is in the foreground don't count, so the app calls
  `WidgetCenter.reloadAllTimelines()` only when shown data actually changed (stats
  recorded, sample counts changed).
- Data goes app → App Group `UserDefaults` → widget. The widget never touches Photos or
  the training folder; it only reads free space itself (`volumeAvailableCapacityForImportantUsage`).
- Rendering modes: on the tinted/clear Home Screen (and on the Lock Screen) the system
  tints content and removes the `containerBackground`. Opaque fills would turn into solid
  blocks, so tile/track fills switch to `.primary.opacity(0.15)` outside `.fullColor`, and
  the hero number is `widgetAccentable()`.
- Gallery preview (`context.isPreview`) shows sample data so the widget looks real before
  the user has cleaned anything.

## What ships

One widget, five families (design: Design canvas „Widgety — SmartCleanup”):

- **Small** — saved space, deleted count, free-space bar; "Mało miejsca" chip under 5 GB
  free (tap → large videos). Untrained model → "Zacznij tutaj" with 0/20 progress (tap → train).
- **Medium** — the same on the left, four tool links on the right.
- **Lock Screen** — rectangular (saved), circular (free GB gauge), inline (free space).

Deep links: `smartcleanup://delete|blur|duplicates|videos|train`. They open a tool only
from the home screen; if a tool is already open, the app just comes to the front so an
in-progress review isn't dropped. `delete` falls back to `train` until the model is ready.

## Not yet

Large widget and Control Center controls (iOS 18 `ControlWidget`) — see the canvas plan.
