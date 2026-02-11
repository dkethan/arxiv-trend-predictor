# Web App Parity Checklist (Android vs Web)

This doc confirms the Android app matches the web app (index.html + styles.css + app.js).

## API
- **Base URL:** `https://arxiv-trend-predictor-api.onrender.com` (same as web `data-api-base`)
- **Endpoint:** `POST /api/v1/advisor/advise` with `{ title, abstract }`
- **Headers:** `Accept: application/json`, `Content-Type: application/json`

## Colors (from web `:root`)
- Background: `#0a0b0f`
- Surface: `rgba(18, 20, 28, 0.85)`
- Surface elevated: `rgba(28, 31, 42, 0.9)`
- Border: `rgba(255, 255, 255, 0.06)`
- Text: `#f0f0f2`, muted: `#8b8d98`
- Accent: `#2ec4b6`, success: `#34d399`, error: `#f87171`

## Typography
- **Display (headings):** Syne (web `--font-display`)
- **Body:** Outfit (web `--font-sans`)
- **Numbers/code:** JetBrains Mono (web `--font-mono`)

## Layout & copy

| Section        | Web                          | Android match |
|----------------|------------------------------|---------------|
| Header title   | "arXiv Trend Advisor"        | ✓ Syne, gradient text |
| Tagline        | "See where your idea fits…" | ✓ Outfit, muted |
| Form labels    | "Title", "Abstract"          | ✓ |
| Placeholders   | Same as web                  | ✓ |
| Buttons        | "Get advice", "Ex 1 — Transformers", "Ex 2 — NeRF" | ✓ Same labels + primary/outline style |
| Form note      | "Click **Get advice**… **Ex 1 — Transformers** or **Ex 2 — NeRF**…" | ✓ Exact copy |
| Result heading | "Advice" (Syne, muted)        | ✓ |
| Insights title | "INSIGHTS" (uppercase)       | ✓ |
| Numbers block  | "NUMBERS AT A GLANCE" + list | ✓ VizNumbersCard |
| Domain card    | Domain + confidence, "ALSO CLOSE (COMPARE ALL FOUR)", table | ✓ DomainCard |
| Growth card    | Green pill label + "Growth score: X%" | ✓ GrowthCard |
| Keywords card  | Pills (accent soft bg, mono)  | ✓ KeywordsCard |
| Summary card   | "SUMMARY" + message (bold = accent) | ✓ _buildSummaryCard |
| Disclaimer     | Italic, muted, small         | ✓ |
| Footer         | "Powered by arxiv-trend-predictor API" | ✓ |
| Error          | Red soft bg, red text, 12px radius | ✓ |

## Cards (web `.card`)
- Background: surface, border, radius 12px, padding 1.25rem 1.5rem (20px 24px), shadow.
- Android: `appCardDecoration` used for Domain, Growth, Keywords, Summary, VizNumbers.

## Differences (intentional)
- **Charts:** Web has Chart.js (confidence bar, growth bar, scatter). Android shows the same data in "Numbers at a glance" only (no chart lib).
- **Background:** Web has grid + mesh + vignette; Android uses solid `#0a0b0f` and system status/nav bar colors.

## How to re-check
1. Open web app in browser and Android app side by side.
2. Use "Ex 1 — Transformers" on both, tap "Get advice".
3. Compare: header, form, result order (Advice → Insights → Numbers → Domain → Growth → Keywords → Summary → disclaimer), card styles, and copy.
