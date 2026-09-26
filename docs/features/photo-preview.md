# Long-press photo preview

`ThumbnailCell` in `App/Sources/Views/ResultsView.swift` already used `.contextMenu` for
"mark as exception", so the long-press gesture recognizer for that menu was already present.
Rather than add a second, competing long-press recognizer, the fix uses SwiftUI's native
`.contextMenu(menuItems:preview:)` overload and supplies a `preview:` closure. Long-press now
peeks a large image (fetched via `PhotoLibraryService.requestImage` with `PHImageManagerMaximumSize`,
separate from the grid's own 200x200 request) before the menu items appear, exactly the standard
iOS peek pattern — release/tap outside dismisses it, no custom dismiss logic needed.

## Why not a custom overlay/zoom view
The task called for the native `contextMenu` preview when it fits, falling back to a custom
`fullScreenCover` + pinch/drag gesture only if needed. It fits here: the preview closure is
"just another View" so it can have its own `@State`/`.task` to load the full-size image, and the
system handles the peek/dismiss/coexistence-with-menu-items mechanics for free. No pinch-to-zoom
was added since the native preview isn't an interactive canvas — if closer inspection than the
system's default zoom level is requested later, that's the point to reach for the custom
`fullScreenCover` + `MagnificationGesture` fallback instead of retrofitting it onto this preview.

## Coexistence with existing gestures
- **Tap** (`onTapGesture`, moves the item between tabs) is untouched — a quick tap still fires it,
  since `contextMenu`'s recognizer only activates on long-press, same as before this change.
- **Context menu** ("mark as exception") is untouched — the preview is an additive parameter on
  the same modifier, not a new modifier, so there is no additional gesture recognizer to conflict
  with tap or with the menu itself.

`UncertainReviewView.swift` was left alone: it shows one photo at a time already at 800x800 in a
full-screen swipe card, not a grid of small thumbnails, so there's no analogous "peek for detail"
gap to fill there.
