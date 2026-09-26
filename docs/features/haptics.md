# Haptic feedback

## Research (short)

- `UIImpactFeedbackGenerator` (light/medium/heavy/soft/rigid) is for a discrete physical
  event — something visibly moved, connected, or snapped into place. Intensity should
  scale with how consequential the event is, not just how big the tap target was.
- `UISelectionFeedbackGenerator` is for moving through a small set of discrete values
  (segmented control, picker) — a light "tick", never used for a one-off action.
- `UINotificationFeedbackGenerator` (success/warning/error) is for the outcome of an
  operation, not the input gesture — it reads as "this completed", so it belongs at the
  end of a flow, not on every tap along the way.
- Apple's own destructive hold patterns (Podcasts/Files "Clear cache", Mail "Empty
  Trash" on some surfaces, camera shutter hold-to-record on Snapchat/Instagram) share
  three properties: (1) a visible fill/progress synced to the hold so the user can see
  how close they are to the point of no return, (2) escalating feedback during the hold
  rather than one final buzz, so intent is felt building up, and (3) a clean, silent
  cancel on early release — no error state, no half-done side effect. This is the model
  used for the delete button below.
- General rule applied throughout: haptics mark *decisions and destinations*, not every
  tap — sprinkling a tick on every button teaches the user to ignore all of them.

## What was built

`App/Sources/Services/Haptics.swift` — thin wrapper (`impact`, `selection`,
`notification`) so call sites read as intent.

Applied:
- **SwipeView.decide / UncertainReviewView.decide** — `.impact(.light)` for Keep,
  `.impact(.medium)` for Delete once the drag crosses the threshold. Distinct but
  both "impact" since it's the same kind of event (a card committed off-screen).
- **ResultsView tap-to-move (`onTapMove`)** — `.selection()`. Moving a photo between
  Keep/Delete tabs is a lightweight, reversible flip, closest to a picker tick.
- **ResultsView mark-exception (context menu)** — `.notification(.success)`. This is a
  small "locked in" commitment (the item is excluded from future auto-classification),
  closer to a completed action than a simple selection change.
- **Tab switch (segmented Picker) and batch-size picker buttons** — `.selection()`.
  Kept deliberately minimal per the task's guidance to not overdo general button taps.

## Hold-to-confirm delete

`App/Sources/Views/HoldToConfirmButton.swift` — a generic, reusable
`HoldToConfirmButton<Label>` view (not a modifier, since it needs to own the fill
overlay under the label) built on `.onLongPressGesture(minimumDuration:pressing:perform:)`.

- Duration: **0.7s** — long enough to not fire on an accidental touch-and-drag, short
  enough to not feel like a chore.
- Visual: a white fill overlay growing left-to-right under the label, animated linearly
  over the hold duration, plus a small scale-down (0.97) while pressed for tactile
  "pressed" feedback. One treatment, not stacked with color shifts or bouncing.
- Haptics: 4 escalating `.impact` ticks spaced through the hold (light → light → light →
  medium), then `.notification(.success)` when the hold completes and the action fires.
- Cancel: releasing before `duration` resets the fill and scale with a quick ease-out
  and calls nothing — a `holdGeneration` counter invalidates any ticks still scheduled
  from that press so a late timer can't fire haptics after release or into a new press.

**Decision on the old `confirmationDialog`**: replaced it outright rather than keeping
it as a fallback. A deliberate hold with a visible fill is at least as hard to trigger
by accident as tap-then-confirm-in-a-sheet, and keeping both would mean maintaining two
confirmation UIs for one action. The non-destructive "Zakończ partię" path (no items to
delete) still uses a plain single tap — it's not applied there.

Used in `ResultsView.swift` for the "Usuń N zdjęć" button only.
