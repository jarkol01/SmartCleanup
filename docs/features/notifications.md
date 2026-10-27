# Notifications

## What we take from Duolingo — and what we don't

Take:
- **Send when the user usually opens the app.** Duolingo's biggest win was timing, not copy.
- **Rotate copy, never repeat the last variant.** Their bandit with a recency penalty, minus
  the bandit (no analytics backend here) — the recency part alone does most of the work.
- **Back off when ignored, then stop with a goodbye.** "These reminders don't seem to be
  working, we'll stop for now" is their best-performing message — it respects the user and
  is often what brings them back.
- **Personality.** Light, a bit cheeky, never corporate.

Don't take:
- Daily streaks and streak-at-risk pings. Cleaning photos is a weekly/monthly chore; a daily
  streak would be fake pressure.
- Guilt and passive-aggression ("Duo is sad"). Meme-worthy, also the #1 reason people
  turn notifications off.
- App icon badge, sounds, Time Sensitive. Nothing here is urgent.

## Rules

1. **Max one notification per 7 days**, usually fewer. Never two in a row without an app open.
2. **Every notification deep-links to one tool.** Numbers only when exact (training progress)
   — no estimates in copy, a guessed count reads as fishy.
3. **Silent banner** (`sound = nil`, `.active` interruption level, no badge). Same
   `threadIdentifier` so they group.
4. **Nothing pending while the app is open**: `removeAllPendingNotificationRequests()` on
   `.active`, reschedule on `.background`.
5. **No photo thumbnails** in notifications — the Lock Screen is public, the gallery is not.

## When to ask for permission

Never at launch. Ask at the moment of value: after the first finished delete session, the
results screen shows a soft card:

> **Przypomnieć Ci, gdy uzbiera się nowa porcja?**
> Najwyżej raz w tygodniu, bez spamu.
> [Tak, przypominaj] [Nie teraz]

"Tak" → system prompt. "Nie teraz" → ask again after 30 days, at most twice total.
Settings get one toggle „Przypomnienia” (system-denied → button to iOS Settings).

## Scheduling (all local, no server, no BGTask)

On every `.background`, schedule a **chain of up to three requests**. Since nothing is
rescheduled until the app is opened again, the chain *is* the back-off — an ignoring user
gets three notifications total, then silence.

| # | When (from now) | Content |
|---|---|---|
| 1 | `interval` | reminder |
| 2 | `interval × 3` | reminder, different variant |
| 3 | `interval × 7` | goodbye |

- `interval = clamp(100 / photosPerDay, 7…30 days)` — aim for ~100 new photos, so a heavy
  shooter hears from us weekly, a light one monthly. `photosPerDay` = photos created in the
  last 30 days / 30 (one `PHAsset` fetch at background time).
- **Hour** = median hour of the last 10 app opens (store hours in `UserDefaults`), default
  19:00, clamped to 9–21. Fire date snaps to that hour.
- Tap → `userInfo["link"]` → existing `HomeView.open(_:)` via `DeepLink.url`.

## Types (priority order — only one chain is scheduled)

1. **Unfinished training** (model not ready, ≥1 sample given). One-shot, 1 day later, max 2 ever.
   → `train`
2. **Cleanup reminder** — the default chain above. Deep link rotates by what's most likely
   worth it: `delete` (model ready), else `duplicates`.
3. **Goodbye** — always the last link of the chain.

## Copy (PL; 3 rotating variants, never the previous one)

Unfinished training (`train`):
- „Zdjęcia do oznaczenia: {n}. Potem model zacznie sprzątać za Ciebie.” (avoids Polish plural forms)
- „Model jest w {pct}% gotowy. Dokończymy?”

Cleanup reminder (`delete` / `duplicates`):
- „Od ostatniego sprzątania trochę się nazbierało. 2 minuty i po sprawie?”
- „Galeria znowu rośnie. Szybki przegląd?”
- „Zrzuty ekranu same się nie usuną. No, chyba że pozwolisz modelowi.”
- „Kilka duplikatów pewnie już się namnożyło. Sprawdzimy?” (only for `duplicates`)

Goodbye (`delete`):
- „Wygląda na to, że przypomnienia nie pomagają, więc na razie przestajemy. Galeria poczeka 🙂”

Copy lives in the String Catalog like everything else (pl, en, de, fr, es). Last variant
index per type stored in `UserDefaults`.

## Not yet

- **Exact counts / low-storage alert** need `BGAppRefreshTask` (recount, replace the
  pending request with the same identifier, or cancel it). Add if exact „{n} nowych
  zdjęć” copy turns out to be worth it.
- **Monthly recap** („W październiku: 340 zdjęć, 60 zrzutów ekranu”) — same dependency.
- **Measuring effect** — log `didReceive` taps locally if we ever want to tune variants.
